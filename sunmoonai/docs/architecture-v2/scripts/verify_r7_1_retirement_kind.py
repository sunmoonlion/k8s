#!/usr/bin/env python3
"""Verify the current Architecture v2 tree and post-observation KIND runtime."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

from retire_r7_legacy_kind import APPS, FORMAL_DEPLOYMENTS, LEGACY, ROOT


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kubeconfig", type=Path, required=True)
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def k(args: argparse.Namespace, *items: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["kubectl", "--kubeconfig", str(args.kubeconfig), "--request-timeout=30s", *items],
        check=check, capture_output=True, text=True,
    )


def exists(args: argparse.Namespace, kind: str, name: str) -> bool:
    return k(args, "get", kind, name, "-n", args.namespace, check=False).returncode == 0


def all_names(args: argparse.Namespace) -> list[str]:
    kinds = ("deployment", "service", "configmap", "secret", "serviceaccount",
             "persistentvolumeclaim", "ingressroute", "cronjob")
    result: list[str] = []
    for kind in kinds:
        data = json.loads(k(args, "get", kind, "-n", args.namespace, "-o", "json").stdout)
        result.extend(f"{kind}/{item['metadata']['name']}" for item in data["items"])
    return sorted(result)


def main() -> int:
    args = parse_args()
    errors: list[str] = []
    evidence_dir = ROOT / "sunmoonai/docs/architecture-v2/evidence/R7.1-retirement"
    evidence_results: dict[str, str] = {}

    for filename in (
        "info-browser.json",
        "knowledge-browser.json",
        "investment-browser.json",
        "cross-app-vertical.json",
    ):
        path = evidence_dir / filename
        if not path.is_file():
            errors.append(f"required R7.1 evidence missing: {path.relative_to(ROOT)}")
            evidence_results[filename] = "missing"
            continue
        try:
            result = json.loads(path.read_text(encoding="utf-8")).get("result")
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"invalid R7.1 evidence {path.relative_to(ROOT)}: {exc}")
            evidence_results[filename] = "invalid"
            continue
        evidence_results[filename] = str(result)
        if result != "passed":
            errors.append(f"R7.1 evidence did not pass: {filename} result={result!r}")

    active_dirs = sorted(
        path.name for path in (ROOT / "sunmoonai/app-platform").glob("*-app")
        if path.is_dir()
    )
    for required in ("info-app", "knowledge-app", "investment-app"):
        if required not in active_dirs:
            errors.append(f"missing platform app directory: {required}")
    if "research-app" in active_dirs:
        errors.append("retired research-app directory still exists")

    config = (ROOT / "sunmoonai/app-platform/deploy-app-platform-all/deploy-app-platform-all.conf").read_text()
    if "research_app_enabled" in config or "research_app_priority" in config:
        errors.append("platform aggregate config still activates research_app")
    if "investment_app_enabled" not in config:
        errors.append("platform aggregate config lacks investment_app")

    for app in APPS:
        bundle = ROOT / f"sunmoonai/app-platform/{app}-app/deployment/bundle"
        gate = ROOT / "sunmoonai/app-platform/scripts/verify-formal-instance.py"
        result = subprocess.run([sys.executable, str(gate), "--bundle", str(bundle)],
                                capture_output=True, text=True)
        if result.returncode:
            errors.append(f"{app} static bundle gate failed: {result.stderr.strip()}")

    deployments = json.loads(k(args, "get", "deployment", "-n", args.namespace,
                               "-o", "json").stdout)["items"]
    deployment_map = {item["metadata"]["name"]: item for item in deployments}
    for name in sorted(FORMAL_DEPLOYMENTS):
        item = deployment_map.get(name)
        if not item:
            errors.append(f"formal deployment missing: {name}")
            continue
        wanted = item["spec"].get("replicas", 0)
        ready = item.get("status", {}).get("readyReplicas", 0)
        if wanted < 1 or ready != wanted:
            errors.append(f"formal deployment not ready: {name} {ready}/{wanted}")

    remaining = [f"{kind}/{name}" for kind, names in LEGACY.items() for name in names
                 if exists(args, kind, name)]
    if remaining:
        errors.append(f"legacy allowlist remains: {remaining}")

    names = all_names(args)
    active_research = [item for item in names if item.split("/", 1)[1].startswith("research")]
    if active_research:
        errors.append(f"research-prefixed runtime resources remain: {active_research}")

    required_resources = (
        ("secret", "architecture-v2-browser-operator"),
        ("secret", "info-backend-redis-conn"), ("secret", "info-backend-broker"),
        ("secret", "info-backend-s3"), ("configmap", "info-backend-s3"),
        ("secret", "info-backend-elasticsearch"), ("configmap", "info-backend-elasticsearch"),
        ("secret", "knowledge-backend-redis-conn"), ("secret", "knowledge-backend-broker"),
        ("secret", "knowledge-ragflow-provider"), ("secret", "knowledge-backend-s3"),
        ("deployment", "casdoor-sunmoonai"), ("deployment", "ragflow-sunmoonai"),
        ("persistentvolumeclaim", "casdoor-sunmoonai-dev-pvc"),
        ("persistentvolumeclaim", "ragflow-sunmoonai-mysql"),
        ("persistentvolumeclaim", "ragflow-sunmoonai-minio"),
        ("persistentvolumeclaim", "ragflow-sunmoonai-es-data"),
        ("persistentvolumeclaim", "redis-data-ragflow-sunmoonai-redis-0"),
    )
    missing = [f"{kind}/{name}" for kind, name in required_resources if not exists(args, kind, name)]
    if missing:
        errors.append(f"required formal/provider resources missing: {missing}")

    pods = json.loads(k(args, "get", "pod", "-n", args.namespace, "-o", "json").stdout)["items"]
    bad_pods = [item["metadata"]["name"] for item in pods
                if item.get("status", {}).get("phase") not in {"Running", "Succeeded"}]
    if bad_pods:
        errors.append(f"unhealthy pod phases: {bad_pods}")

    report: dict[str, Any] = {
        "task": "app-platform-v2-r7.1-retirement-gate",
        "result": "failed" if errors else "passed",
        "formal_deployments_ready": len(FORMAL_DEPLOYMENTS) if not errors else None,
        "retired_platform_directory_absent": "research-app" not in active_dirs,
        "research_prefixed_runtime_resources": active_research,
        "legacy_allowlist_remaining": remaining,
        "casdoor_and_ragflow_preserved": not missing,
        "required_evidence": evidence_results,
        "databases_deleted": False,
        "secret_values_printed": False,
        "errors": errors,
    }
    rendered = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
