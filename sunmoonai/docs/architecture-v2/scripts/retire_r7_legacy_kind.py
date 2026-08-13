#!/usr/bin/env python3
"""Retire the exact R7 legacy KIND surface after formal workloads are healthy.

The script is intentionally closed over immutable allowlists.  It never accepts
arbitrary resource names and never prints Secret data.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[4]
APPS = ("info", "knowledge", "investment")
FORMAL_DEPLOYMENTS = {
    f"{app}-r5-{component}"
    for app in APPS
    for component in (
        "backend-api", "backend-worker", "backend-scheduler",
        "admin-frontend", "web-frontend",
    )
}

COPY_RESOURCES: tuple[tuple[str, str, str, tuple[str, ...] | None], ...] = (
    ("secret", "info-admin-backend-redis-conn", "info-backend-redis-conn", None),
    ("secret", "celeryworker-info-admin-backend-secret", "info-backend-broker", None),
    ("secret", "info-admin-backend-s3", "info-backend-s3", None),
    ("configmap", "info-admin-backend-s3", "info-backend-s3", None),
    ("secret", "info-admin-backend-elasticsearch", "info-backend-elasticsearch", None),
    ("configmap", "info-admin-backend-elasticsearch", "info-backend-elasticsearch", None),
    ("secret", "knowledge-admin-backend-redis-conn", "knowledge-backend-redis-conn", None),
    ("secret", "celeryworker-knowledge-admin-backend-secret", "knowledge-backend-broker", None),
    ("secret", "knowledge-admin-backend-secret", "knowledge-ragflow-provider", ("RAGFLOW_API_KEY",)),
    ("secret", "knowledge-admin-backend-s3", "knowledge-backend-s3", None),
)

LEGACY: dict[str, tuple[str, ...]] = {
    "deployment": (
        "celeryworker-info-admin-backend", "info-admin-backend", "info-admin-frontend",
        "info-web-backend", "info-web-frontend", "nodebullworker-info-web-backend",
        "celeryworker-knowledge-admin-backend", "knowledge-admin-backend",
        "celeryworker-research-admin-backend", "nodebullworker-research-web-backend",
        "research-admin-backend", "research-admin-frontend",
        "research-web-backend", "research-web-frontend",
    ),
    "service": (
        "info-admin-backend", "info-admin-frontend", "info-web-backend", "info-web-frontend",
        "knowledge-admin-backend", "research-admin-backend", "research-admin-frontend",
        "research-web-backend", "research-web-frontend",
    ),
    "configmap": (
        "celeryworker-info-admin-backend-config", "info-admin-backend-config",
        "info-admin-backend-elasticsearch", "info-admin-backend-s3",
        "info-web-backend-config", "info-web-backend-elasticsearch", "info-web-backend-s3",
        "info-web-frontend-config", "nodebullworker-info-web-backend-config",
        "celeryworker-knowledge-admin-backend-config", "knowledge-admin-backend-config",
        "knowledge-admin-backend-elasticsearch", "knowledge-admin-backend-s3",
        "celeryworker-research-admin-backend-config", "nodebullworker-research-web-backend-config",
        "research-admin-backend-config", "research-admin-backend-elasticsearch",
        "research-admin-backend-s3", "research-web-backend-config",
        "research-web-backend-elasticsearch", "research-web-backend-s3",
        "research-web-frontend-config",
    ),
    "secret": (
        "celeryworker-info-admin-backend-secret", "info-admin-backend-browser-oidc",
        "info-admin-backend-elasticsearch", "info-admin-backend-migration-postgresql-conn",
        "info-admin-backend-postgresql-conn", "info-admin-backend-redis-conn",
        "info-admin-backend-s3", "info-admin-backend-secret", "info-admin-frontend-secret",
        "info-web-backend-elasticsearch", "info-web-backend-nodebull-redis-conn",
        "info-web-backend-postgresql-conn", "info-web-backend-redis-conn",
        "info-web-backend-s3", "info-web-backend-secret", "info-web-frontend-secret",
        "nodebullworker-info-web-backend-secret",
        "celeryworker-knowledge-admin-backend-secret", "knowledge-admin-backend-browser-oidc",
        "knowledge-admin-backend-elasticsearch", "knowledge-admin-backend-migration-postgresql-conn",
        "knowledge-admin-backend-postgresql-conn", "knowledge-admin-backend-redis-conn",
        "knowledge-admin-backend-s3", "knowledge-admin-backend-secret",
        "knowledge-research-retrieval-service-binding",
        "celeryworker-research-admin-backend-secret", "nodebullworker-research-web-backend-secret",
        "research-admin-backend-browser-oidc", "research-admin-backend-elasticsearch",
        "research-admin-backend-migration-postgresql-conn", "research-admin-backend-postgresql-conn",
        "research-admin-backend-redis-conn", "research-admin-backend-s3",
        "research-admin-backend-secret", "research-admin-frontend-secret",
        "research-knowledge-retrieval-client", "research-web-backend-elasticsearch",
        "research-web-backend-nodebull-redis-conn", "research-web-backend-postgresql-conn",
        "research-web-backend-redis-conn", "research-web-backend-s3",
        "research-web-backend-secret", "research-web-frontend-secret",
        "sunmoonai-p0-004-retrieval-identity", "sunmoonai-p0-005-browser-identity",
        "sunmoonai-p0-005-service-identity", "sunmoonai-r5-investment-retrieval-identity",
    ),
    "serviceaccount": ("research-knowledge-retrieval-worker",),
    "ingressroute": (
        "info-admin-backend-ingress", "info-admin-frontend-ingress",
        "info-web-backend-ingress", "info-web-frontend-ingress",
        "knowledge-admin-backend-ingress", "knowledge-admin-frontend-ingress",
        "knowledge-web-frontend-ingress",
        "investment-admin-backend-ingress", "investment-admin-frontend-ingress",
        "investment-web-backend-ingress", "investment-web-frontend-ingress",
    ),
    "persistentvolumeclaim": (
        "celeryworker-info-admin-backend-pvc", "info-admin-backend-pvc",
        "info-admin-frontend-pvc", "info-web-backend-pvc", "info-web-frontend-pvc",
        "nodebullworker-info-web-backend-pvc", "knowledge-admin-backend-pvc",
        "celeryworker-research-admin-backend-pvc", "nodebullworker-research-web-backend-pvc",
        "research-admin-backend-pvc", "research-admin-frontend-pvc",
        "research-web-backend-pvc", "research-web-frontend-pvc",
    ),
}


class RetirementError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kubeconfig", type=Path, required=True)
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--timeout", type=int, default=360)
    return parser.parse_args()


def kubectl(args: argparse.Namespace, *items: str, check: bool = True,
            capture: bool = False, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.pop("DEBUG", None)
    return subprocess.run(
        ["kubectl", "--kubeconfig", str(args.kubeconfig), "--request-timeout=30s", *items],
        check=check, capture_output=capture, text=True, input=input_text, env=env,
    )


def get_json(args: argparse.Namespace, kind: str, name: str) -> dict[str, Any]:
    result = kubectl(args, "get", kind, name, "-n", args.namespace, "-o", "json", capture=True)
    return json.loads(result.stdout)


def assert_formal_ready(args: argparse.Namespace) -> None:
    data = json.loads(kubectl(args, "get", "deployment", "-n", args.namespace,
                              "-o", "json", capture=True).stdout)
    actual = {item["metadata"]["name"]: item for item in data["items"]}
    failures: list[str] = []
    for name in sorted(FORMAL_DEPLOYMENTS):
        item = actual.get(name)
        if not item:
            failures.append(f"{name}:missing")
            continue
        wanted = item["spec"].get("replicas", 0)
        ready = item.get("status", {}).get("readyReplicas", 0)
        if wanted < 1 or ready != wanted:
            failures.append(f"{name}:{ready}/{wanted}")
    if failures:
        raise RetirementError(f"formal deployments are not ready: {failures}")


def clone_resource(args: argparse.Namespace, kind: str, source: str, target: str,
                   selected_keys: tuple[str, ...] | None) -> None:
    source_result = kubectl(
        args, "get", kind, source, "-n", args.namespace, "-o", "json",
        check=False, capture=True,
    )
    if source_result.returncode:
        target_item = get_json(args, kind, target)
        if selected_keys is not None:
            missing = sorted(set(selected_keys) - set(target_item.get("data", {})))
            if missing:
                raise RetirementError(f"target {kind}/{target} lacks required keys: {missing}")
        print(f"retained {kind}/{target}; legacy source is already absent")
        return
    item = json.loads(source_result.stdout)
    clone = {
        "apiVersion": item["apiVersion"],
        "kind": item["kind"],
        "metadata": {
            "name": target,
            "namespace": args.namespace,
            "labels": {
                "sunmoonai.com/managed-by": "architecture-v2",
                "sunmoonai.com/retirement-migration": "r7-1",
            },
        },
    }
    if kind == "secret":
        source_data = item.get("data", {})
        if selected_keys is not None:
            missing = sorted(set(selected_keys) - set(source_data))
            if missing:
                raise RetirementError(f"source secret {source} lacks required keys: {missing}")
            source_data = {key: source_data[key] for key in selected_keys}
        clone["type"] = item.get("type", "Opaque")
        clone["data"] = copy.deepcopy(source_data)
    else:
        clone["data"] = copy.deepcopy(item.get("data", {}))
        if item.get("binaryData"):
            clone["binaryData"] = copy.deepcopy(item["binaryData"])
    kubectl(args, "apply", "-f", "-", input_text=json.dumps(clone))
    verified = get_json(args, kind, target)
    if verified.get("data", {}) != clone.get("data", {}):
        raise RetirementError(f"{kind}/{target} verification failed")
    print(f"prepared {kind}/{target}")


def reconcile_formal(args: argparse.Namespace) -> None:
    for app in APPS:
        deployer = ROOT / f"sunmoonai/app-platform/{app}-app/architecture-v2/deploy-formal.py"
        subprocess.run(
            [sys.executable, str(deployer), "apply", "--kubeconfig", str(args.kubeconfig),
             "--timeout", str(args.timeout)],
            check=True,
            env={key: value for key, value in os.environ.items() if key != "DEBUG"},
        )


def delete_legacy(args: argparse.Namespace) -> None:
    for kind, names in LEGACY.items():
        kubectl(args, "delete", kind, *names, "-n", args.namespace,
                "--ignore-not-found=true", "--wait=true")


def main() -> int:
    args = parse_args()
    try:
        release_evidence = ROOT / "sunmoonai/docs/architecture-v2/evidence/R7-release/result.json"
        if json.loads(release_evidence.read_text(encoding="utf-8")).get("result") != "passed":
            raise RetirementError("R7 release evidence is not passed")
        assert_formal_ready(args)
        protected_before = {
            (kind, name): get_json(args, kind, name)["metadata"]["uid"]
            for kind, name in (
                ("deployment", "casdoor-sunmoonai"),
                ("deployment", "ragflow-sunmoonai"),
                ("persistentvolumeclaim", "casdoor-sunmoonai-dev-pvc"),
                ("persistentvolumeclaim", "ragflow-sunmoonai-mysql"),
                ("persistentvolumeclaim", "ragflow-sunmoonai-minio"),
                ("persistentvolumeclaim", "ragflow-sunmoonai-es-data"),
                ("persistentvolumeclaim", "redis-data-ragflow-sunmoonai-redis-0"),
            )
        }
        for spec in COPY_RESOURCES:
            clone_resource(args, *spec)
        reconcile_formal(args)
        assert_formal_ready(args)
        delete_legacy(args)
        assert_formal_ready(args)
        protected_after = {
            key: get_json(args, *key)["metadata"]["uid"] for key in protected_before
        }
        if protected_before != protected_after:
            raise RetirementError("a protected Casdoor/RAGFlow resource was replaced")
        print(json.dumps({
            "task": "architecture-v2-r7.1-legacy-retirement",
            "result": "passed",
            "formal_deployments_ready": len(FORMAL_DEPLOYMENTS),
            "legacy_allowlist_deleted": sum(len(names) for names in LEGACY.values()),
            "protected_provider_uids_unchanged": True,
            "databases_deleted": False,
            "secret_values_printed": False,
        }, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, KeyError, RetirementError, subprocess.CalledProcessError) as exc:
        print(json.dumps({"result": "failed", "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
