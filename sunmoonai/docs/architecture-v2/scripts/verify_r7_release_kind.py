#!/usr/bin/env python3
"""Verify the final Architecture v2 release state in KIND without exposing secrets."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

APPS = ("info", "knowledge", "investment")
EXPECTED_HEADS = {
    "info": "20260811_0006",
    "knowledge": "20260811_0005",
    "investment": "20260811_0005",
}
EVIDENCE_FILES = {
    "info_browser": "info-browser.json",
    "knowledge_browser": "knowledge-browser.json",
    "investment_browser": "investment-browser.json",
    "cross_app_vertical": "cross-app-vertical.json",
}
TEMP_MARKERS = ("candidate", "-r3", "-r4", "-r5", "-b4", "smoke")
TEMP_RESOURCE_TYPES = (
    "deployments",
    "statefulsets",
    "daemonsets",
    "services",
    "configmaps",
    "secrets",
    "serviceaccounts",
    "networkpolicies",
    "ingressroutes.traefik.io",
    "poddisruptionbudgets",
    "horizontalpodautoscalers",
    "jobs",
    "cronjobs",
    "persistentvolumeclaims",
)
LEGACY_RESEARCH_INGRESSES = {
    "research-admin-frontend-ingress",
    "research-web-frontend-ingress",
    "research-admin-backend-ingress",
    "research-web-backend-ingress",
}


class GateError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise GateError(message)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class Kubectl:
    def __init__(self, executable: str, kubeconfig: Path, namespace: str):
        self.command = [
            executable,
            "--kubeconfig",
            str(kubeconfig),
            "--namespace",
            namespace,
        ]

    def run(self, *args: str) -> str:
        result = subprocess.run(
            [*self.command, *args],
            check=True,
            text=True,
            capture_output=True,
            timeout=60,
        )
        return result.stdout

    def json(self, *args: str) -> dict[str, Any]:
        return json.loads(self.run(*args, "-o", "json"))


def deployment_image(item: dict[str, Any]) -> str:
    containers = item["spec"]["template"]["spec"].get("containers", [])
    require(
        len(containers) == 1, f"deployment {item['metadata']['name']} container drift"
    )
    return containers[0]["image"]


def verify_bundle_files(bundle: Path, release: dict[str, Any]) -> dict[str, str]:
    observed: dict[str, str] = {}
    for filename, expected in release["sha256"].items():
        path = bundle / filename
        require(path.is_file(), f"missing formal bundle file: {path}")
        actual = sha256(path)
        require(actual == expected, f"formal bundle hash drift: {path}")
        observed[filename] = actual
    return observed


def verify_database_head(kubectl: Kubectl, deployment: str, expected: str) -> str:
    output = kubectl.run(
        "exec",
        f"deployment/{deployment}",
        "--",
        "/app/.venv/bin/python",
        "-m",
        "app.bootstrap.migration",
        "current",
    )
    require(
        re.search(rf"\b{re.escape(expected)}\b", output) is not None,
        f"{deployment} migration head drift",
    )
    return expected


def verify_info_outbox(kubectl: Kubectl) -> dict[str, int]:
    program = """import asyncio, json
from sqlalchemy import text
from app.infrastructure.storage.postgres import get_postgres
async def main():
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            delivery = (await session.execute(text(\"SELECT count(*) FROM delivery_outbox_message WHERE state <> 'completed'\"))).scalar_one()
            transport = (await session.execute(text(\"SELECT count(*) FROM outbox_message WHERE status NOT IN ('published', 'completed')\"))).scalar_one()
            print(json.dumps({\"delivery_active\": int(delivery), \"transport_active\": int(transport)}, sort_keys=True))
    finally:
        await postgres.shutdown()
asyncio.run(main())"""
    output = kubectl.run(
        "exec",
        "deployment/info-backend-api",
        "--",
        "/app/.venv/bin/python",
        "-c",
        program,
    )
    payload = json.loads(output.strip().splitlines()[-1])
    require(
        payload == {"delivery_active": 0, "transport_active": 0},
        "Info outbox is not quiescent",
    )
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace-root", type=Path, default=Path("/home/zymun"))
    parser.add_argument(
        "--kubeconfig", type=Path, default=Path.home() / ".kube/kind-config"
    )
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--kubectl", default="kubectl")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    workspace = args.workspace_root.resolve()
    k8s = workspace / "k8s"
    evidence_dir = k8s / "sunmoonai/docs/architecture-v2/evidence/R7-release"
    kubectl = Kubectl(
        args.kubectl, args.kubeconfig.expanduser().resolve(), args.namespace
    )
    result: dict[str, Any] = {
        "task": "app-platform-v2-r7-release",
        "result": "failed",
        "namespace": args.namespace,
        "apps": {},
        "credentials_printed": False,
        "tokens_printed": False,
    }

    try:
        deployments = kubectl.json("get", "deployments")["items"]
        deployment_by_name = {item["metadata"]["name"]: item for item in deployments}
        formal_names: set[str] = set()
        legacy_names: set[str] = set()
        formal_ingresses: set[str] = set()

        for app in APPS:
            bundle = k8s / f"sunmoonai/app-platform/{app}-app/deployment/bundle"
            release_path = bundle / "release.json"
            release = load_json(release_path)
            require(
                release.get("formal_release") is True, f"{app} is not a formal release"
            )
            require(release.get("logical_app") == app, f"{app} release identity drift")
            require(
                release.get("namespace") == args.namespace, f"{app} namespace drift"
            )
            hashes = verify_bundle_files(bundle, release)

            app_result: dict[str, Any] = {
                "release_id": release["release_id"],
                "release_sha256": sha256(release_path),
                "bundle_sha256": hashes,
                "deployments": {},
            }
            for name, replicas in release["deployment_replicas"].items():
                formal_names.add(name)
                item = deployment_by_name.get(name)
                require(item is not None, f"formal deployment absent: {name}")
                spec_replicas = item["spec"].get("replicas", 0)
                ready = item.get("status", {}).get("readyReplicas", 0)
                require(spec_replicas == replicas, f"{name} desired replica drift")
                require(ready == replicas, f"{name} is not fully ready")
                expected_image = (
                    release["images"]["backend"]
                    if "backend-" in name
                    else release["images"]["admin"]
                    if "admin-frontend" in name
                    else release["images"]["web"]
                )
                actual_image = deployment_image(item)
                require(actual_image == expected_image, f"{name} image drift")
                require("@sha256:" in actual_image, f"{name} uses a mutable image")
                config_sha = (
                    item["spec"]["template"]["metadata"]
                    .get("annotations", {})
                    .get("sunmoonai.com/config-sha256")
                )
                require(
                    bool(config_sha and re.fullmatch(r"[0-9a-f]{64}", config_sha)),
                    f"{name} config fingerprint absent",
                )
                app_result["deployments"][name] = {
                    "replicas": replicas,
                    "image": actual_image,
                    "config_sha256": config_sha,
                }

            for name in release["legacy_deployments"]:
                legacy_names.add(name)
                item = deployment_by_name.get(name)
                require(item is not None, f"protected legacy deployment absent: {name}")
                require(
                    item["spec"].get("replicas", 0) == 0,
                    f"legacy deployment is active: {name}",
                )

            formal_ingresses.update(release["ingress_routes"])
            app_result["migration_head"] = verify_database_head(
                kubectl, f"{app}-backend-api", EXPECTED_HEADS[app]
            )
            result["apps"][app] = app_result

        jobs = kubectl.json("get", "jobs")["items"]
        active_jobs = [
            item["metadata"]["name"]
            for item in jobs
            if item.get("status", {}).get("active", 0)
        ]
        require(not active_jobs, f"active Jobs remain: {active_jobs}")

        ingress_items = kubectl.json("get", "ingressroutes.traefik.io")["items"]
        ingress_names = {item["metadata"]["name"] for item in ingress_items}
        require(
            formal_ingresses.issubset(ingress_names),
            "formal IngressRoute set is incomplete",
        )
        require(
            not (LEGACY_RESEARCH_INGRESSES & ingress_names),
            "legacy Research IngressRoutes remain active",
        )
        require(
            "tpl-admin-frontend-b4" not in ingress_names,
            "temporary tpl B4 IngressRoute remains",
        )

        namespace_resources = kubectl.json(
            "get", ",".join(TEMP_RESOURCE_TYPES)
        )["items"]
        temporary = sorted(
            f"{item['kind']}/{item['metadata']['name']}"
            for item in namespace_resources
            if any(
                marker in item["metadata"]["name"] for marker in TEMP_MARKERS
            )
        )
        require(not temporary, f"temporary/candidate resources remain: {temporary}")

        evidence: dict[str, Any] = {}
        for key, filename in EVIDENCE_FILES.items():
            path = evidence_dir / filename
            require(path.is_file(), f"R7 evidence absent: {path}")
            payload = load_json(path)
            require(
                payload.get("result") == "passed",
                f"R7 evidence did not pass: {filename}",
            )
            if key.endswith("browser"):
                require(
                    payload.get("strict_tls") is True, f"strict TLS absent: {filename}"
                )
            if key == "cross_app_vertical":
                require(
                    payload.get("mock_provider_used") is False,
                    "R7 vertical used a mock provider",
                )
                require(
                    payload.get("database_cross_read_used") is False,
                    "R7 vertical used cross-database reads",
                )
                require(
                    payload.get("replay", {}).get("same_distribution") is True,
                    "R7 replay did not preserve identity",
                )
            evidence[key] = {"path": str(path.relative_to(k8s)), "sha256": sha256(path)}

        result["outbox"] = verify_info_outbox(kubectl)
        result["formal_deployments"] = sorted(formal_names)
        result["protected_legacy_deployments"] = sorted(legacy_names)
        result["formal_ingress_routes"] = sorted(formal_ingresses)
        result["active_jobs"] = []
        result["temporary_resources"] = []
        result["evidence"] = evidence
        result["result"] = "passed"
    except (
        GateError,
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        json.JSONDecodeError,
    ) as exc:
        result["error"] = f"{type(exc).__name__}: {exc}"

    rendered = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if result["result"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
