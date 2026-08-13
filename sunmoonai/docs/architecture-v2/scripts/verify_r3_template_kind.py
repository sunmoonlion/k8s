#!/usr/bin/env python3
"""Runtime and policy gate for the Architecture v2 R3 template deployment."""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urlsplit


class GateError(RuntimeError):
    pass


def run(
    command: list[str],
    *,
    check: bool = True,
    capture: bool = True,
    timeout: int = 60,
) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment.pop("DEBUG", None)
    return subprocess.run(
        command,
        check=check,
        capture_output=capture,
        text=True,
        timeout=timeout,
        env=environment,
    )


def k(args: argparse.Namespace, *items: str, **kwargs) -> subprocess.CompletedProcess[str]:
    command = [args.kubectl]
    if args.kubeconfig:
        command.extend(("--kubeconfig", str(args.kubeconfig)))
    command.extend(items)
    return run(command, **kwargs)


def resource(args: argparse.Namespace, kind: str, name: str) -> dict[str, object]:
    return json.loads(
        k(args, "get", f"{kind}/{name}", "-n", args.namespace, "-o", "json").stdout
    )


def assert_hardened(name: str, deployment: dict[str, object], replicas: int) -> str:
    spec = deployment["spec"]
    status = deployment.get("status", {})
    if spec.get("replicas") != replicas or status.get("readyReplicas") != replicas:
        raise GateError(f"{name} is not ready at {replicas}/{replicas}")
    pod = spec["template"]["spec"]
    container = pod["containers"][0]
    pod_security = pod.get("securityContext", {})
    security = container.get("securityContext", {})
    if (
        pod.get("automountServiceAccountToken") is not False
        or pod_security.get("runAsNonRoot") is not True
        or pod_security.get("runAsUser") != 1001
        or pod_security.get("runAsGroup") != 1001
        or security.get("allowPrivilegeEscalation") is not False
        or security.get("readOnlyRootFilesystem") is not True
        or "ALL" not in security.get("capabilities", {}).get("drop", [])
    ):
        raise GateError(f"{name} hardening contract is incomplete")
    image = str(container.get("image", ""))
    if "@sha256:" not in image:
        raise GateError(f"{name} is not pinned by immutable digest")
    for entry in container.get("env", []):
        if str(entry.get("name", "")).upper() in {
            "HTTP_PROXY",
            "HTTPS_PROXY",
            "ALL_PROXY",
        }:
            raise GateError(f"{name} contains a runtime proxy variable")
    return image


def env_secret_mapping(deployment: dict[str, object]) -> dict[str, tuple[str, str]]:
    container = deployment["spec"]["template"]["spec"]["containers"][0]
    result: dict[str, tuple[str, str]] = {}
    for entry in container.get("env", []):
        reference = entry.get("valueFrom", {}).get("secretKeyRef")
        if reference:
            result[str(entry["name"])] = (
                str(reference.get("name", "")),
                str(reference.get("key", "")),
            )
    return result


def secret_values(args: argparse.Namespace, name: str) -> dict[str, str]:
    value = resource(args, "secret", name)
    return {
        key: base64.b64decode(encoded).decode("utf-8")
        for key, encoded in value.get("data", {}).items()
    }


def assert_structure(args: argparse.Namespace, release: dict[str, object]) -> dict[str, object]:
    app = args.app
    expected = {
        f"{app}-backend-api": 2,
        f"{app}-backend-worker": 1,
        f"{app}-backend-scheduler": 1,
        f"{app}-admin-frontend": 2,
        f"{app}-web-frontend": 2,
    }
    deployments = {
        name: resource(args, "deployment", name) for name in expected
    }
    images = {
        name: assert_hardened(name, deployment, expected[name])
        for name, deployment in deployments.items()
    }
    locked_images = release["images"]
    if not all(
        images[name] == locked_images["backend"]
        for name in (
            f"{app}-backend-api",
            f"{app}-backend-worker",
            f"{app}-backend-scheduler",
        )
    ):
        raise GateError("Backend roles do not use one locked image digest")
    if images[f"{app}-admin-frontend"] != locked_images["admin"]:
        raise GateError("Admin image differs from release.json")
    if images[f"{app}-web-frontend"] != locked_images["web"]:
        raise GateError("Web image differs from release.json")

    commands = {
        name: tuple(
            deployments[name]["spec"]["template"]["spec"]["containers"][0].get(
                "command", []
            )
        )
        for name in (
            f"{app}-backend-api",
            f"{app}-backend-worker",
            f"{app}-backend-scheduler",
        )
    }
    if len(set(commands.values())) != 3:
        raise GateError("Backend roles do not have distinct entrypoints")

    expected_secret_refs = {
        f"{app}-backend-api": {
            "DATABASE_URL": "API_DATABASE_URL",
            "CELERY_BROKER_URL": "API_CELERY_BROKER_URL",
            "ADMIN_CASDOOR_CLIENT_SECRET": "ADMIN_CASDOOR_CLIENT_SECRET",
            "WEB_CASDOOR_CLIENT_SECRET": "WEB_CASDOOR_CLIENT_SECRET",
        },
        f"{app}-backend-worker": {
            "DATABASE_URL": "WORKER_DATABASE_URL",
            "CELERY_BROKER_URL": "WORKER_CELERY_BROKER_URL",
        },
        f"{app}-backend-scheduler": {
            "DATABASE_URL": "SCHEDULER_DATABASE_URL",
            "CELERY_BROKER_URL": "SCHEDULER_CELERY_BROKER_URL",
        },
    }
    for name, mapping in expected_secret_refs.items():
        actual = env_secret_mapping(deployments[name])
        for env_name, key in mapping.items():
            if actual.get(env_name) != (f"{app}-backend-runtime", key):
                raise GateError(f"{name} does not use the expected role secret key")

    services = json.loads(
        k(
            args,
            "get",
            "services",
            "-n",
            args.namespace,
            "-l",
            f"sunmoonai.com/app={app}",
            "-o",
            "json",
        ).stdout
    )["items"]
    backend_services = [
        item for item in services if item["metadata"]["name"] == f"{app}-backend"
    ]
    if len(backend_services) != 1:
        raise GateError("deployment must expose exactly one Backend Service")

    config = resource(args, "configmap", f"{app}-backend-config")["data"]
    if config["ADMIN_CASDOOR_CLIENT_ID"] == config["WEB_CASDOOR_CLIENT_ID"]:
        raise GateError("Admin and Web OIDC client IDs are not isolated")
    if config["ADMIN_CASDOOR_REDIRECT_URI"] == config["WEB_CASDOOR_REDIRECT_URI"]:
        raise GateError("Admin and Web redirect URIs are not isolated")
    if config["ADMIN_AUTH_POLICY_VERSION"] == config["WEB_AUTH_POLICY_VERSION"]:
        raise GateError("Admin and Web policy namespaces are not isolated")

    values = secret_values(args, f"{app}-backend-runtime")
    users = {
        urlsplit(values[key]).username
        for key in (
            "MIGRATION_DATABASE_URL",
            "API_DATABASE_URL",
            "WORKER_DATABASE_URL",
            "SCHEDULER_DATABASE_URL",
        )
    }
    if len(users) != 4 or None in users:
        raise GateError("database roles are not represented by four distinct principals")
    if values["ADMIN_CASDOOR_CLIENT_SECRET"] == values["WEB_CASDOOR_CLIENT_SECRET"]:
        raise GateError("Admin and Web client secrets are not isolated")

    hpas = json.loads(
        k(args, "get", "hpa", "-n", args.namespace, "-o", "json").stdout
    )["items"]
    pdbs = json.loads(
        k(args, "get", "pdb", "-n", args.namespace, "-o", "json").stdout
    )["items"]
    if len(hpas) != 4 or len(pdbs) != 4:
        raise GateError("expected four HPA and four PDB resources")
    jobs = json.loads(
        k(args, "get", "jobs", "-n", args.namespace, "-o", "json").stdout
    )["items"]
    if any(
        item.get("metadata", {}).get("labels", {}).get("sunmoonai.com/app") == app
        for item in jobs
    ):
        raise GateError("completed Architecture v2 migration Job was not cleaned")

    policies = json.loads(
        k(args, "get", "networkpolicies", "-n", args.namespace, "-o", "json").stdout
    )["items"]
    policy_names = {item["metadata"]["name"] for item in policies}
    expected_policies = {
        f"{app}-default-deny",
        f"{app}-dns-egress",
        f"{app}-frontend-ingress",
        f"{app}-frontend-egress",
        f"{app}-backend-ingress",
        f"{app}-backend-api-egress",
        f"{app}-backend-worker-egress",
        f"{app}-backend-scheduler-egress",
        f"{app}-backend-migration-egress",
    }
    if not expected_policies <= policy_names:
        raise GateError("NetworkPolicy set is incomplete")
    api_policy = next(
        item
        for item in policies
        if item["metadata"]["name"] == f"{app}-backend-api-egress"
    )
    encoded_policy = json.dumps(api_policy, separators=(",", ":"))
    if (
        '"kubernetes.io/metadata.name":"app-platform-dev"' not in encoded_policy
        or '"app":"casdoor-sunmoonai"' not in encoded_policy
    ):
        raise GateError("Casdoor cross-namespace egress policy is absent")
    worker_policy = next(
        item
        for item in policies
        if item["metadata"]["name"] == f"{app}-backend-worker-egress"
    )
    encoded_worker_policy = json.dumps(worker_policy, separators=(",", ":"))
    if '"sunmoonai.com/internal-provider":"true"' not in encoded_worker_policy:
        raise GateError("Worker internal-provider egress policy is absent")
    if '"sunmoonai.com/internal-provider":"true"' in encoded_policy:
        raise GateError("API unexpectedly inherits Worker provider egress")

    for surface in ("admin", "web"):
        route = resource(args, "ingressroute", f"{app}-{surface}")
        rules = route["spec"]["routes"]
        if rules[0].get("priority") != 100 or rules[0]["services"][0]["name"] != f"{app}-backend":
            raise GateError(f"{surface} /api ingress does not target the canonical Backend")
        if route["spec"].get("tls", {}).get("secretName") != args.tls_secret:
            raise GateError(f"{surface} ingress does not use the strict TLS Secret")

    return {
        "backend_digest_shared": True,
        "database_principals": 4,
        "oidc_clients_isolated": True,
        "hpa_count": len(hpas),
        "pdb_count": len(pdbs),
        "network_policy_count": len(policies),
        "migration_job_cleaned": True,
    }


def network_probe(
    args: argparse.Namespace,
    *,
    name: str,
    image: str,
    allowed: bool,
) -> int:
    labels = f"sunmoonai.com/r3-probe={name}"
    if allowed:
        labels += f",sunmoonai.com/allow-{args.app}-internal=true"
    k(
        args,
        "delete",
        "pod",
        name,
        "-n",
        args.namespace,
        "--ignore-not-found=true",
        "--wait=true",
    )
    command = (
        "import urllib.request; "
        f"r=urllib.request.urlopen('http://{args.app}-backend:8000/health/live',timeout=5); "
        "raise SystemExit(0 if r.status==200 else 2)"
    )
    k(
        args,
        "run",
        name,
        "-n",
        args.namespace,
        "--restart=Never",
        f"--image={image}",
        "--image-pull-policy=IfNotPresent",
        f"--labels={labels}",
        "--overrides",
        json.dumps(
            {
                "spec": {
                    "automountServiceAccountToken": False,
                    "imagePullSecrets": [{"name": "harbor-registry-secret"}],
                    "securityContext": {
                        "runAsNonRoot": True,
                        "runAsUser": 1001,
                        "runAsGroup": 1001,
                        "seccompProfile": {"type": "RuntimeDefault"},
                    },
                }
            },
            separators=(",", ":"),
        ),
        "--command",
        "--",
        "python",
        "-c",
        command,
    )
    deadline = time.monotonic() + 45
    phase = ""
    while time.monotonic() < deadline:
        pod = resource(args, "pod", name)
        phase = str(pod.get("status", {}).get("phase", ""))
        if phase in {"Succeeded", "Failed"}:
            break
        time.sleep(1)
    k(
        args,
        "delete",
        "pod",
        name,
        "-n",
        args.namespace,
        "--ignore-not-found=true",
        "--wait=true",
    )
    if allowed and phase != "Succeeded":
        raise GateError("explicit internal caller could not reach Backend")
    if not allowed and phase != "Failed":
        raise GateError("unlabelled caller unexpectedly reached Backend")
    return 200 if allowed else 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--namespace", default="tpl-architecture-v2-r3")
    parser.add_argument("--app", default="tpl")
    parser.add_argument("--tls-secret", default="tpl-r3-tls")
    parser.add_argument("--task", default="architecture-v2-r3-kind")
    parser.add_argument("--kubeconfig", type=Path)
    parser.add_argument("--kubectl", default="kubectl")
    parser.add_argument(
        "--skip-network-runtime",
        action="store_true",
        help=(
            "verify NetworkPolicy objects structurally but delegate packet-level "
            "enforcement to the dedicated Calico KIND gate"
        ),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        release = json.loads((args.bundle / "release.json").read_text())
        if release.get("namespace") != args.namespace or release.get("app") != args.app:
            raise GateError("bundle identity does not match the requested runtime")
        summary = assert_structure(args, release)
        if args.skip_network_runtime:
            positive: int | str = "delegated_to_calico_gate"
            negative: int | str = "delegated_to_calico_gate"
            network_runtime_gate = "delegated"
        else:
            backend_image = str(release["images"]["backend"])
            positive = network_probe(
                args,
                name="r3-allowed-client",
                image=backend_image,
                allowed=True,
            )
            negative = network_probe(
                args,
                name="r3-denied-client",
                image=backend_image,
                allowed=False,
            )
            network_runtime_gate = "passed"
        print(
            json.dumps(
                {
                    "task": args.task,
                    "result": "passed",
                    **summary,
                    "network_runtime_gate": network_runtime_gate,
                    "network_positive": positive,
                    "network_negative": negative,
                    "credentials_printed": False,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0
    except (GateError, OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        print(
            json.dumps(
                {
                    "task": args.task,
                    "result": "failed",
                    "error": str(exc),
                },
                ensure_ascii=False,
            ),
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
