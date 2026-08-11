#!/usr/bin/env python3
"""Fail-closed static gate for the Investment R5 candidate bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

import yaml

IMMUTABLE = re.compile(r"^[^\s]+@sha256:[0-9a-f]{64}$")
LEGACY_NAMES = {
    "research-admin-backend",
    "celeryworker-research-admin-backend",
    "research-admin-frontend",
    "research-web-backend",
    "nodebullworker-research-web-backend",
    "research-web-frontend",
}


class GateError(RuntimeError):
    pass


def documents(path: Path) -> list[dict[str, Any]]:
    return [item for item in yaml.safe_load_all(path.read_text()) if item]


def resources(items: list[dict[str, Any]]) -> dict[tuple[str, str], dict[str, Any]]:
    result: dict[tuple[str, str], dict[str, Any]] = {}
    for item in items:
        key = (item["kind"], item["metadata"]["name"])
        if key in result:
            raise GateError(f"duplicate resource: {key}")
        result[key] = item
    return result


def container(deployment: dict[str, Any], name: str) -> dict[str, Any]:
    found = [c for c in deployment["spec"]["template"]["spec"]["containers"] if c["name"] == name]
    if len(found) != 1:
        raise GateError(f"container mismatch: {name}")
    return found[0]


def refs(spec: dict[str, Any]) -> set[tuple[str, str]]:
    result: set[tuple[str, str]] = set()
    for item in spec.get("env", []):
        ref = item.get("valueFrom", {}).get("secretKeyRef")
        if ref:
            result.add((ref["name"], ref["key"]))
    for item in spec.get("envFrom", []):
        ref = item.get("secretRef")
        if ref:
            result.add((ref["name"], "*"))
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True, type=Path)
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    release = json.loads((bundle / "release.json").read_text())
    if release.get("architecture") != "app-platform-v2-r5-investment-candidate":
        raise GateError("wrong architecture")
    if release.get("logical_app") != "investment" or release.get("resource_app") != "investment-r5":
        raise GateError("wrong logical/resource App identity")
    if release.get("formal_release") or release.get("touches_v1_resources"):
        raise GateError("candidate is formal or legacy-mutating")
    for name, expected in release["sha256"].items():
        if hashlib.sha256((bundle / name).read_bytes()).hexdigest() != expected:
            raise GateError(f"hash mismatch: {name}")

    items: list[dict[str, Any]] = []
    for name in release["resources"]:
        items.extend(documents(bundle / name))
    index = resources(items)
    if {name for _, name in index} & LEGACY_NAMES:
        raise GateError("candidate collides with legacy Research names")
    if any(item["kind"] == "Namespace" for item in items):
        raise GateError("candidate mutates shared Namespace")
    if any(item["metadata"].get("namespace") != "app-platform-dev" for item in items):
        raise GateError("candidate escaped app-platform-dev")

    accounts = {
        "investment-r5-backend-api", "investment-r5-backend-worker",
        "investment-r5-backend-scheduler", "investment-r5-backend-migration",
        "investment-r5-admin-frontend", "investment-r5-web-frontend",
    }
    for name in accounts:
        if index[("ServiceAccount", name)].get("automountServiceAccountToken") is not False:
            raise GateError(f"ServiceAccount token mounted: {name}")

    api = index[("Deployment", "investment-r5-backend-api")]
    worker = index[("Deployment", "investment-r5-backend-worker")]
    scheduler = index[("Deployment", "investment-r5-backend-scheduler")]
    admin = index[("Deployment", "investment-r5-admin-frontend")]
    web = index[("Deployment", "investment-r5-web-frontend")]
    migration = index[("Job", f"investment-r5-backend-migration-{release['release_id']}")]
    if api["spec"].get("replicas") != 2 or admin["spec"].get("replicas") != 2 or web["spec"].get("replicas") != 2:
        raise GateError("candidate synchronous replicas differ from 2")
    if worker["spec"].get("replicas") != 0 or scheduler["spec"].get("replicas") != 0:
        raise GateError("candidate activates an asynchronous writer")
    if ("HorizontalPodAutoscaler", "investment-r5-backend-worker") in index:
        raise GateError("Worker HPA can reactivate candidate writer")

    roles = {
        "api": container(api, "api"), "worker": container(worker, "worker"),
        "scheduler": container(scheduler, "scheduler"),
        "migration": migration["spec"]["template"]["spec"]["containers"][0],
    }
    if {c["image"] for c in roles.values()} != {release["images"]["backend"]}:
        raise GateError("Backend role image drift")
    if not IMMUTABLE.fullmatch(release["images"]["backend"]):
        raise GateError("Backend image is mutable")
    for dep, cname, key in ((admin, "admin", "admin"), (web, "web", "web")):
        image = container(dep, cname)["image"]
        if image != release["images"][key] or not IMMUTABLE.fullmatch(image):
            raise GateError(f"{key} image drift or mutable tag")

    role_refs = {name: refs(spec) for name, spec in roles.items()}
    runtime = ("investment-backend-postgresql-conn", "DATABASE_URL")
    migration_ref = ("investment-backend-migration-postgresql-conn", "MIGRATION_DATABASE_URL")
    for name in ("api", "worker", "scheduler"):
        if runtime not in role_refs[name]:
            raise GateError(f"{name} lacks runtime DB identity")
        if any(secret == migration_ref[0] for secret, _ in role_refs[name]):
            raise GateError(f"{name} can see migration DB identity")
    if migration_ref not in role_refs["migration"]:
        raise GateError("Migration lacks DDL identity")
    browser = {
        ("investment-r5-browser-identity", "ADMIN_CLIENT_ID"),
        ("investment-r5-browser-identity", "ADMIN_CLIENT_SECRET"),
        ("investment-r5-browser-identity", "WEB_CLIENT_ID"),
        ("investment-r5-browser-identity", "WEB_CLIENT_SECRET"),
    }
    if not browser <= role_refs["api"]:
        raise GateError("API lacks isolated browser identities")
    if any(browser & role_refs[name] for name in ("worker", "scheduler", "migration")):
        raise GateError("non-API role can see browser identities")
    if ("investment-knowledge-retrieval-client", "*") not in role_refs["worker"]:
        raise GateError("Worker lacks Investment retrieval identity")
    for name in ("api", "scheduler", "migration"):
        if any(secret == "investment-knowledge-retrieval-client" for secret, _ in role_refs[name]):
            raise GateError(f"{name} can see retrieval caller credentials")

    config = index[("ConfigMap", "investment-r5-backend-config")]["data"]
    expected = {
        "APP_SLUG": "investment", "CELERY_QUEUE": "investment.r5.candidate",
        "AGENT_V4_TRAFFIC_ENABLED": "false", "AGENT_PILOT_ENABLED": "false",
        "KNOWLEDGE_RETRIEVAL_SERVICE_APPLICATION": "sunmoonai-investment-knowledge-retrieve",
    }
    for key, value in expected.items():
        if config.get(key) != value:
            raise GateError(f"configuration drift: {key}")
    for surface in ("admin", "web"):
        cfg = index[("ConfigMap", f"investment-r5-{surface}-frontend-config")]["data"]
        if cfg.get("AUTH_APP") != "investment" or cfg.get("BACKEND_INTERNAL_URL") != "http://investment-r5-backend:8000":
            raise GateError(f"{surface} pairing drift")

    ingress = json.dumps([i for i in items if i["kind"] == "IngressRoute"])
    for host in ("investment-admin-r5.sunmoonai.com", "investment-web-r5.sunmoonai.com"):
        if host not in ingress:
            raise GateError(f"candidate host absent: {host}")
    policies = json.dumps([i for i in items if i["kind"] == "NetworkPolicy"], sort_keys=True)
    if '"0.0.0.0/0"' in policies or "knowledge-r5" not in policies:
        raise GateError("egress is unrestricted or Knowledge target is not explicit")
    raw = "\n".join((bundle / n).read_text() for n in release["resources"])
    if re.search(r"(?i)(password|client_secret)\s*:\s*['\"]?[A-Za-z0-9]{16,}", raw):
        raise GateError("credential-like literal found")

    print(json.dumps({
        "task": "R5-V2-investment-candidate-bundle", "result": "passed",
        "release_id": release["release_id"], "resources": len(index),
        "candidate_async_writers": 0, "legacy_name_collisions": 0,
        "immutable_images": True, "credentials_printed": False,
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (GateError, KeyError, OSError, ValueError, yaml.YAMLError) as exc:
        print(json.dumps({"task": "R5-V2-investment-candidate-bundle", "result": "failed", "error": str(exc)}))
        raise SystemExit(1)
