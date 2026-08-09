#!/usr/bin/env python3
"""Fail-closed static gate for the rendered Info R5 candidate bundle."""

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
    "info-admin-backend",
    "celeryworker-info-admin-backend",
    "info-admin-frontend",
    "info-web-backend",
    "nodebullworker-info-web-backend",
    "info-web-frontend",
}


class VerifyError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True, type=Path)
    return parser.parse_args()


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


def secret_refs(container_spec: dict[str, Any]) -> set[tuple[str, str]]:
    refs: set[tuple[str, str]] = set()
    for item in container_spec.get("env", []):
        reference = item.get("valueFrom", {}).get("secretKeyRef")
        if reference:
            refs.add((reference["name"], reference["key"]))
    for item in container_spec.get("envFrom", []):
        reference = item.get("secretRef")
        if reference:
            refs.add((reference["name"], "*"))
    return refs


def main() -> int:
    args = parse_args()
    bundle = args.bundle.resolve()
    release = json.loads((bundle / "release.json").read_text())
    if release.get("architecture") != "app-platform-v2-r5-info-candidate":
        raise VerifyError("wrong bundle architecture")
    if release.get("logical_app") != "info" or release.get("resource_app") != "info-r5":
        raise VerifyError("logical/resource App identity is not isolated")
    if release.get("formal_release") or release.get("touches_v1_resources"):
        raise VerifyError("candidate is incorrectly marked formal or v1-mutating")
    for name, expected in release["sha256"].items():
        if hashlib.sha256((bundle / name).read_bytes()).hexdigest() != expected:
            raise VerifyError(f"hash mismatch: {name}")

    documents: list[dict[str, Any]] = []
    for name in release["resources"]:
        documents.extend(load_yaml(bundle / name))
    resources = index(documents)
    actual_names = {name for _, name in resources}
    collisions = sorted(actual_names & V1_NAMES)
    if collisions:
        raise VerifyError(f"candidate overwrites v1 resources: {collisions}")
    if any(item.get("kind") == "Namespace" for item in documents):
        raise VerifyError("candidate must not mutate the shared Namespace")
    if any(item["metadata"].get("namespace") != "app-platform-dev" for item in documents):
        raise VerifyError("candidate resource escaped app-platform-dev")

    expected_service_accounts = {
        "info-r5-backend-api",
        "info-r5-backend-worker",
        "info-r5-backend-scheduler",
        "info-r5-backend-migration",
        "info-r5-admin-frontend",
        "info-r5-web-frontend",
    }
    for name in expected_service_accounts:
        account = resources[("ServiceAccount", name)]
        if account.get("automountServiceAccountToken") is not False:
            raise VerifyError(f"ServiceAccount token is mounted: {name}")

    api = resources[("Deployment", "info-r5-backend-api")]
    worker = resources[("Deployment", "info-r5-backend-worker")]
    scheduler = resources[("Deployment", "info-r5-backend-scheduler")]
    admin = resources[("Deployment", "info-r5-admin-frontend")]
    web = resources[("Deployment", "info-r5-web-frontend")]
    migration = resources[
        ("Job", f"info-r5-backend-migration-{release['release_id']}")
    ]
    if worker["spec"].get("replicas") != 0 or scheduler["spec"].get("replicas") != 0:
        raise VerifyError("I3 candidate would create a second asynchronous writer")
    if ("HorizontalPodAutoscaler", "info-r5-backend-worker") in resources:
        raise VerifyError("I3 HPA could reactivate the zero-replica candidate Worker")
    role_containers = {
        "api": container(api, "api"),
        "worker": container(worker, "worker"),
        "scheduler": container(scheduler, "scheduler"),
        "migration": migration["spec"]["template"]["spec"]["containers"][0],
    }
    backend_images = {item["image"] for item in role_containers.values()}
    if backend_images != {release["images"]["backend"]}:
        raise VerifyError("Backend roles do not use the exact same image")
    if not all(IMMUTABLE_IMAGE.fullmatch(item) for item in backend_images):
        raise VerifyError("Backend image is mutable")
    for frontend, key, name in (
        (admin, "admin", "admin"),
        (web, "web", "web"),
    ):
        image = container(frontend, name)["image"]
        if image != release["images"][key] or not IMMUTABLE_IMAGE.fullmatch(image):
            raise VerifyError(f"{key} frontend image is not locked")

    refs = {name: secret_refs(spec) for name, spec in role_containers.items()}
    runtime_db = ("info-backend-postgresql-conn", "DATABASE_URL")
    migration_db = (
        "info-backend-migration-postgresql-conn",
        "MIGRATION_DATABASE_URL",
    )
    if runtime_db not in refs["api"] or runtime_db not in refs["worker"] or runtime_db not in refs["scheduler"]:
        raise VerifyError("runtime DB role is not shared by API/Worker/Scheduler")
    if migration_db not in refs["migration"]:
        raise VerifyError("Migration does not use the DDL-only Secret")
    for role in ("api", "worker", "scheduler"):
        if any(name == "info-backend-migration-postgresql-conn" for name, _ in refs[role]):
            raise VerifyError(f"{role} can see the Migration Secret")
    if ("info-knowledge-ingest-client", "*") not in refs["worker"]:
        raise VerifyError("Worker lacks its downstream service identity")
    for role in ("api", "scheduler", "migration"):
        if any(name == "info-knowledge-ingest-client" for name, _ in refs[role]):
            raise VerifyError(f"{role} can see the Worker downstream identity")
    if not {
        ("info-r5-browser-identity", "ADMIN_CLIENT_ID"),
        ("info-r5-browser-identity", "ADMIN_CLIENT_SECRET"),
        ("info-r5-browser-identity", "WEB_CLIENT_ID"),
        ("info-r5-browser-identity", "WEB_CLIENT_SECRET"),
    } <= refs["api"]:
        raise VerifyError("API lacks two isolated browser client identities")

    config = resources[("ConfigMap", "info-r5-backend-config")]["data"]
    if config.get("APP_SLUG") != "info" or config.get("ADMIN_AUTH_SCOPE_ALLOWLIST") != "info:admin":
        raise VerifyError("candidate leaked resource suffix into business identity")
    if config.get("CELERY_QUEUE") != "info.r5.candidate":
        raise VerifyError("candidate is not isolated from the v1 production queue")
    for surface in ("admin", "web"):
        frontend_config = resources[("ConfigMap", f"info-r5-{surface}-frontend-config")]["data"]
        if frontend_config.get("AUTH_APP") != "info":
            raise VerifyError(f"{surface} AUTH_APP mismatch")
        if frontend_config.get("BACKEND_INTERNAL_URL") != "http://info-r5-backend:8000":
            raise VerifyError(f"{surface} does not pair with the candidate Backend")

    api_policy = resources[("NetworkPolicy", "info-r5-backend-api-egress")]
    worker_policy = resources[("NetworkPolicy", "info-r5-backend-worker-egress")]
    scheduler_policy = resources[("NetworkPolicy", "info-r5-backend-scheduler-egress")]
    api_policy_text = json.dumps(api_policy, sort_keys=True)
    worker_policy_text = json.dumps(worker_policy, sort_keys=True)
    scheduler_policy_text = json.dumps(scheduler_policy, sort_keys=True)
    if "internal-provider" in api_policy_text or '"0.0.0.0/0"' in api_policy_text:
        raise VerifyError("API egress is broader than required")
    if "internal-provider" not in worker_policy_text or '"0.0.0.0/0"' not in worker_policy_text:
        raise VerifyError("Worker cannot reach required providers")
    if "casdoor-sunmoonai" in scheduler_policy_text or '"0.0.0.0/0"' in scheduler_policy_text:
        raise VerifyError("Scheduler egress is broader than required")

    ingress_hosts = json.dumps(
        [item for item in documents if item.get("kind") == "IngressRoute"]
    )
    if "info-admin-r5.sunmoonai.com" not in ingress_hosts or "info-web-r5.sunmoonai.com" not in ingress_hosts:
        raise VerifyError("candidate Ingress hosts are missing")
    if "Host(`info-admin.sunmoonai.com`)" in ingress_hosts or "Host(`info.sunmoonai.com`)" in ingress_hosts:
        raise VerifyError("candidate takes formal v1 hosts")

    raw = "\n".join((bundle / name).read_text() for name in release["resources"])
    if re.search(r"(?i)(password|client_secret)\s*:\s*['\"]?[A-Za-z0-9]{16,}", raw):
        raise VerifyError("credential-like literal found in rendered YAML")
    print(
        json.dumps(
            {
                "task": "R5-I2-info-candidate-bundle",
                "result": "passed",
                "v1_name_collisions": 0,
                "backend_role_count": 4,
                "browser_identity_count": 2,
                "worker_only_downstream_identity": True,
                "candidate_async_writers": 0,
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
