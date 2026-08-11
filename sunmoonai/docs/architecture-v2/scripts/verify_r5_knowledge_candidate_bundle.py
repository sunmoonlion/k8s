#!/usr/bin/env python3
"""Fail-closed static verifier for the Knowledge R5 candidate bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

import yaml

IMMUTABLE_IMAGE = re.compile(r"^[^\s]+@sha256:[0-9a-f]{64}$")
V1_NAMES = {
    "knowledge-admin-backend",
    "celeryworker-knowledge-admin-backend",
    "knowledge-admin-frontend",
    "knowledge-web-backend",
    "nodebullworker-knowledge-web-backend",
    "knowledge-web-frontend",
}


class VerifyError(RuntimeError):
    pass


def load_yaml(path: Path) -> list[dict[str, Any]]:
    return [item for item in yaml.safe_load_all(path.read_text()) if item]


def index(documents: list[dict[str, Any]]) -> dict[tuple[str, str], dict[str, Any]]:
    result: dict[tuple[str, str], dict[str, Any]] = {}
    for item in documents:
        key = (item["kind"], item["metadata"]["name"])
        if key in result:
            raise VerifyError(f"duplicate resource: {key[0]}/{key[1]}")
        result[key] = item
    return result


def container(deployment: dict[str, Any], name: str) -> dict[str, Any]:
    matches = [
        item
        for item in deployment["spec"]["template"]["spec"]["containers"]
        if item["name"] == name
    ]
    if len(matches) != 1:
        raise VerifyError(f"container mismatch: {name}")
    return matches[0]


def secret_refs(spec: dict[str, Any]) -> set[tuple[str, str]]:
    refs: set[tuple[str, str]] = set()
    for item in spec.get("env", []):
        ref = item.get("valueFrom", {}).get("secretKeyRef")
        if ref:
            refs.add((ref["name"], ref["key"]))
    for item in spec.get("envFrom", []):
        ref = item.get("secretRef")
        if ref:
            refs.add((ref["name"], "*"))
    return refs


def literal_env(spec: dict[str, Any], name: str) -> str | None:
    matches = [item for item in spec.get("env", []) if item.get("name") == name]
    if len(matches) != 1:
        return None
    value = matches[0].get("value")
    return value if isinstance(value, str) else None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True, type=Path)
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    release = json.loads((bundle / "release.json").read_text())
    if release.get("architecture") != "app-platform-v2-r5-knowledge-candidate":
        raise VerifyError("wrong bundle architecture")
    if release.get("logical_app") != "knowledge":
        raise VerifyError("logical App identity mismatch")
    if release.get("resource_app") != "knowledge-r5":
        raise VerifyError("candidate resource identity mismatch")
    if release.get("formal_release") or release.get("touches_v1_resources"):
        raise VerifyError("candidate is incorrectly formal or v1-mutating")
    for name, expected in release["sha256"].items():
        if hashlib.sha256((bundle / name).read_bytes()).hexdigest() != expected:
            raise VerifyError(f"hash mismatch: {name}")

    documents: list[dict[str, Any]] = []
    for name in release["resources"]:
        documents.extend(load_yaml(bundle / name))
    resources = index(documents)
    collisions = sorted({name for _, name in resources} & V1_NAMES)
    if collisions:
        raise VerifyError(f"candidate overwrites v1 resources: {collisions}")
    if any(item.get("kind") == "Namespace" for item in documents):
        raise VerifyError("candidate must not mutate the shared Namespace")
    if any(
        item["metadata"].get("namespace") != "app-platform-dev" for item in documents
    ):
        raise VerifyError("candidate resource escaped app-platform-dev")

    expected_accounts = {
        "knowledge-r5-backend-api",
        "knowledge-r5-backend-worker",
        "knowledge-r5-backend-scheduler",
        "knowledge-r5-backend-migration",
        "knowledge-r5-admin-frontend",
        "knowledge-r5-web-frontend",
    }
    for name in expected_accounts:
        if (
            resources[("ServiceAccount", name)].get("automountServiceAccountToken")
            is not False
        ):
            raise VerifyError(f"ServiceAccount token is mounted: {name}")

    api = resources[("Deployment", "knowledge-r5-backend-api")]
    worker = resources[("Deployment", "knowledge-r5-backend-worker")]
    scheduler = resources[("Deployment", "knowledge-r5-backend-scheduler")]
    admin = resources[("Deployment", "knowledge-r5-admin-frontend")]
    web = resources[("Deployment", "knowledge-r5-web-frontend")]
    migration = resources[
        ("Job", f"knowledge-r5-backend-migration-{release['release_id']}")
    ]
    if worker["spec"].get("replicas") != 0 or scheduler["spec"].get("replicas") != 0:
        raise VerifyError("candidate creates an extra asynchronous writer")
    if ("HorizontalPodAutoscaler", "knowledge-r5-backend-worker") in resources:
        raise VerifyError("candidate Worker HPA can reactivate a writer")

    role_specs = {
        "api": container(api, "api"),
        "worker": container(worker, "worker"),
        "scheduler": container(scheduler, "scheduler"),
        "migration": migration["spec"]["template"]["spec"]["containers"][0],
    }
    backend_images = {item["image"] for item in role_specs.values()}
    if backend_images != {release["images"]["backend"]}:
        raise VerifyError("Backend role images differ")
    if not all(IMMUTABLE_IMAGE.fullmatch(item) for item in backend_images):
        raise VerifyError("Backend image is mutable")
    for deployment, name, image_key in (
        (admin, "admin", "admin"),
        (web, "web", "web"),
    ):
        image = container(deployment, name)["image"]
        if image != release["images"][image_key] or not IMMUTABLE_IMAGE.fullmatch(
            image
        ):
            raise VerifyError(f"{image_key} image is not locked")

    refs = {name: secret_refs(spec) for name, spec in role_specs.items()}
    retrieval_allowlist = release.get("retrieval_dataset_allowlist")
    if (
        not isinstance(retrieval_allowlist, str)
        or not retrieval_allowlist.strip()
        or "*" in retrieval_allowlist.split(",")
    ):
        raise VerifyError("retrieval dataset allowlist is absent or unrestricted")
    for role in ("api", "worker"):
        if (
            literal_env(role_specs[role], "RETRIEVAL_DATASET_ALLOWLIST")
            != retrieval_allowlist
        ):
            raise VerifyError(f"{role} retrieval dataset allowlist diverged")
    runtime = ("knowledge-backend-postgresql-conn", "DATABASE_URL")
    migration_ref = (
        "knowledge-backend-migration-postgresql-conn",
        "MIGRATION_DATABASE_URL",
    )
    for role in ("api", "worker", "scheduler"):
        if runtime not in refs[role]:
            raise VerifyError(f"{role} lacks the runtime DB identity")
        if any(name == migration_ref[0] for name, _ in refs[role]):
            raise VerifyError(f"{role} can see the migration identity")
    if migration_ref not in refs["migration"]:
        raise VerifyError("Migration lacks its DDL identity")
    browser_refs = {
        ("knowledge-r5-browser-identity", "ADMIN_CLIENT_ID"),
        ("knowledge-r5-browser-identity", "ADMIN_CLIENT_SECRET"),
        ("knowledge-r5-browser-identity", "WEB_CLIENT_ID"),
        ("knowledge-r5-browser-identity", "WEB_CLIENT_SECRET"),
    }
    if not browser_refs <= refs["api"]:
        raise VerifyError("API lacks isolated Admin/Web clients")
    if any(browser_refs & refs[role] for role in ("worker", "scheduler", "migration")):
        raise VerifyError("non-API role can see browser identity")
    if ("knowledge-admin-backend-s3", "S3_SECRET_ACCESS_KEY") not in refs["worker"]:
        raise VerifyError("Worker lacks Artifact access")
    for role in ("api", "scheduler", "migration"):
        if any(name == "knowledge-admin-backend-s3" for name, _ in refs[role]):
            raise VerifyError(f"{role} can see S3 credentials")
    if ("knowledge-admin-backend-secret", "RAGFLOW_API_KEY") not in refs["api"]:
        raise VerifyError("API lacks retrieval Provider access")
    if ("knowledge-admin-backend-secret", "RAGFLOW_API_KEY") not in refs["worker"]:
        raise VerifyError("Worker lacks ingestion Provider access")
    for role in ("scheduler", "migration"):
        if any(name == "knowledge-admin-backend-secret" for name, _ in refs[role]):
            raise VerifyError(f"{role} can see Provider credentials")
    if (
        not {
            ("knowledge-info-ingest-service-binding", "*"),
            ("knowledge-research-retrieval-service-binding", "*"),
        }
        <= refs["api"]
    ):
        raise VerifyError("API lacks cross-App resource bindings")
    for role in ("worker", "scheduler", "migration"):
        if any("service-binding" in name for name, _ in refs[role]):
            raise VerifyError(f"{role} can see caller bindings")

    config = resources[("ConfigMap", "knowledge-r5-backend-config")]["data"]
    if config.get("APP_SLUG") != "knowledge":
        raise VerifyError("candidate leaked resource suffix into business identity")
    if config.get("CELERY_QUEUE") != "knowledge.r5.candidate":
        raise VerifyError("candidate shares the production queue")
    for surface in ("admin", "web"):
        frontend_config = resources[
            ("ConfigMap", f"knowledge-r5-{surface}-frontend-config")
        ]["data"]
        if frontend_config.get("AUTH_APP") != "knowledge":
            raise VerifyError(f"{surface} AUTH_APP mismatch")
        if (
            frontend_config.get("BACKEND_INTERNAL_URL")
            != "http://knowledge-r5-backend:8000"
        ):
            raise VerifyError(f"{surface} is not paired with the candidate Backend")

    policy_text = json.dumps(
        [item for item in documents if item.get("kind") == "NetworkPolicy"],
        sort_keys=True,
    )
    if '"0.0.0.0/0"' in policy_text:
        raise VerifyError("candidate contains unrestricted egress")
    if "ragflow-sunmoonai" not in policy_text:
        raise VerifyError("RAGFlow egress is not explicit")
    if '"port": 9380' not in policy_text:
        raise VerifyError("RAGFlow egress does not use the Pod target port")
    ingress_text = json.dumps(
        [item for item in documents if item.get("kind") == "IngressRoute"]
    )
    if "knowledge-admin-r5.sunmoonai.com" not in ingress_text:
        raise VerifyError("Admin candidate host missing")
    if "knowledge-web-r5.sunmoonai.com" not in ingress_text:
        raise VerifyError("Web candidate host missing")

    raw = "\n".join((bundle / name).read_text() for name in release["resources"])
    if re.search(r"(?i)(password|client_secret)\s*:\s*['\"]?[A-Za-z0-9]{16,}", raw):
        raise VerifyError("credential-like literal found in YAML")
    print(
        json.dumps(
            {
                "task": "R5-K2-knowledge-candidate-bundle",
                "result": "passed",
                "v1_name_collisions": 0,
                "backend_role_count": 4,
                "browser_identity_count": 2,
                "candidate_async_writers": 0,
                "provider_secret_roles": ["api", "worker"],
                "artifact_secret_roles": ["worker"],
                "immutable_images": True,
                "credentials_printed": False,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, KeyError, TypeError, VerifyError, yaml.YAMLError) as exc:
        print(json.dumps({"result": "failed", "error": str(exc)}), file=sys.stderr)
        raise SystemExit(1)
