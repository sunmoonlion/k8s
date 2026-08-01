#!/usr/bin/env python3
"""KIND verification for V5-P0-005 identity boundaries.

The script never reads service credentials into the local process and never
prints access tokens or client secrets. It checks anonymous fail-closed
behavior for the three Admin APIs and executes the real Info distribution
worker code inside its Pod. An empty ingestion payload must reach Knowledge's
schema validation as HTTP 422, proving that the workload obtained a real
client-credentials token and crossed the service-auth boundary. Research
traffic is enabled only for the duration of the check and restored in
``finally``.
"""

from __future__ import annotations

import argparse
import http.client
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


class VerificationError(RuntimeError):
    pass


class HttpFailure(VerificationError):
    def __init__(self, status: int, body: str = "") -> None:
        super().__init__(f"HTTP {status}: {body[:240]}")
        self.status = status
        self.body = body


def kubectl(args: list[str], *, kubeconfig: str, capture: bool = False) -> str:
    result = subprocess.run(
        ["kubectl", "--kubeconfig", kubeconfig, *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )
    return result.stdout if capture else ""


def request_json(
    base_url: str,
    path: str,
    *,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
) -> Any:
    data = None if payload is None else json.dumps(payload).encode()
    request_headers = {"Accept": "application/json"}
    if data is not None:
        request_headers["Content-Type"] = "application/json"
    if headers:
        request_headers.update(headers)
    request = urllib.request.Request(
        f"{base_url}{path}", data=data, method=method, headers=request_headers
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            body = response.read().decode()
            return json.loads(body) if body else None
    except urllib.error.HTTPError as exc:
        raise HttpFailure(exc.code, exc.read().decode(errors="replace")) from exc
    except (
        urllib.error.URLError,
        TimeoutError,
        ConnectionResetError,
        http.client.RemoteDisconnected,
    ) as exc:
        raise VerificationError(f"request failed for {path}: {exc}") from exc


def expect_status(
    base_url: str,
    path: str,
    expected: set[int],
    *,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
) -> int:
    try:
        request_json(base_url, path, method=method, payload=payload, headers=headers)
    except HttpFailure as exc:
        if exc.status in expected:
            return exc.status
        raise VerificationError(
            f"{path}: expected HTTP {sorted(expected)}, got HTTP {exc.status}"
        ) from exc
    raise VerificationError(f"{path}: expected HTTP {sorted(expected)}, got 2xx")


def start_port_forward(
    *, kubeconfig: str, namespace: str, target: str, local_port: int, remote_port: int = 8000
) -> subprocess.Popen[bytes]:
    return subprocess.Popen(
        [
            "kubectl",
            "--kubeconfig",
            kubeconfig,
            "port-forward",
            "-n",
            namespace,
            target,
            f"{local_port}:{remote_port}",
            "--address=127.0.0.1",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def wait_for_reachable(base_url: str, path: str, *, timeout: float = 30) -> None:
    deadline = time.monotonic() + timeout
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            request_json(base_url, path)
            return
        except HttpFailure:
            # A protected endpoint returning 401/404 is still reachable.
            return
        except VerificationError as exc:
            last_error = exc
            time.sleep(0.5)
    raise VerificationError(f"timed out waiting for {base_url}{path}: {last_error}")


def assert_no_explicit_research_traffic_override(
    *, kubeconfig: str, namespace: str
) -> None:
    raw = kubectl(
        [
            "get",
            "deployment/research-admin-backend",
            "-n",
            namespace,
            "-o",
            "json",
        ],
        kubeconfig=kubeconfig,
        capture=True,
    )
    deployment = json.loads(raw)
    env = deployment["spec"]["template"]["spec"]["containers"][0].get("env", [])
    explicit = [
        item
        for item in env
        if item.get("name") == "AGENT_V4_TRAFFIC_ENABLED"
    ]
    # The declarative deployment now carries an explicit fail-closed value in
    # some generated manifests.  It is safe to replace that exact value for
    # the duration of this internal verification; an explicit true or an
    # indeterminate value must still fail closed.
    for item in explicit:
        if item.get("value") != "false" or "valueFrom" in item:
            raise VerificationError(
                "refusing to overwrite non-false AGENT_V4_TRAFFIC_ENABLED deployment env"
            )


def verify_service_workload_binding(*, kubeconfig: str, namespace: str) -> dict[str, bool]:
    raw = kubectl(
        [
            "get",
            "deployment/info-admin-backend",
            "deployment/celeryworker-info-admin-backend",
            "deployment/knowledge-admin-backend",
            "-n",
            namespace,
            "-o",
            "json",
        ],
        kubeconfig=kubeconfig,
        capture=True,
    )
    items = {item["metadata"]["name"]: item for item in json.loads(raw)["items"]}

    def pod_spec(name: str) -> dict[str, Any]:
        return items[name]["spec"]["template"]["spec"]

    def secret_refs(name: str) -> set[str]:
        container = pod_spec(name)["containers"][0]
        return {
            entry["secretRef"]["name"]
            for entry in container.get("envFrom", [])
            if "secretRef" in entry
        }

    worker = pod_spec("celeryworker-info-admin-backend")
    checks = {
        "caller_secret_only_on_worker": (
            "info-knowledge-ingest-client"
            in secret_refs("celeryworker-info-admin-backend")
            and "info-knowledge-ingest-client" not in secret_refs("info-admin-backend")
        ),
        "resource_binding_on_knowledge": (
            "knowledge-info-ingest-service-binding"
            in secret_refs("knowledge-admin-backend")
        ),
        "dedicated_service_account": (
            worker.get("serviceAccountName") == "info-distribution-worker"
        ),
        "service_account_token_not_mounted": (
            worker.get("automountServiceAccountToken") is False
        ),
    }
    if not all(checks.values()):
        raise VerificationError("service workload binding does not match the P0 contract")
    return checks


def verify_info_worker_service_call(*, kubeconfig: str, namespace: str) -> int:
    probe = r'''
import asyncio
import json

import httpx

from app.infrastructure.external.knowledge_app import get_knowledge_app_client


async def main() -> None:
    client = get_knowledge_app_client()
    if not client.enabled:
        raise RuntimeError("service client is disabled")
    try:
        await client.ingest_document({})
    except httpx.HTTPStatusError as exc:
        status = exc.response.status_code
        if status != 422:
            raise RuntimeError(f"unexpected Knowledge response status: {status}") from None
        print(json.dumps({
            "with_real_worker_client_credentials": status,
            "token_printed": False,
            "credentials_read_by_local_process": False,
        }, separators=(",", ":")))
        return
    raise RuntimeError("empty ingestion unexpectedly returned success")


asyncio.run(main())
'''
    result = subprocess.run(
        [
            "kubectl",
            "--kubeconfig",
            kubeconfig,
            "exec",
            "-i",
            "-n",
            namespace,
            "deployment/celeryworker-info-admin-backend",
            "--",
            "sh",
            "-lc",
            "cd /app && .venv/bin/python -",
        ],
        input=probe,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise VerificationError("Info worker service-call probe failed")
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    if not lines:
        raise VerificationError("Info worker service-call probe returned no result")
    try:
        payload = json.loads(lines[-1])
    except json.JSONDecodeError as exc:
        raise VerificationError("Info worker service-call probe returned invalid JSON") from exc
    if payload != {
        "with_real_worker_client_credentials": 422,
        "token_printed": False,
        "credentials_read_by_local_process": False,
    }:
        raise VerificationError("Info worker service-call probe result mismatch")
    return 422


def set_research_traffic(*, kubeconfig: str, namespace: str, enabled: bool) -> None:
    value = "true" if enabled else "AGENT_V4_TRAFFIC_ENABLED-"
    kubectl(
        [
            "set",
            "env",
            "deployment/research-admin-backend",
            "-n",
            namespace,
            f"AGENT_V4_TRAFFIC_ENABLED={value}" if enabled else value,
        ],
        kubeconfig=kubeconfig,
    )
    kubectl(
        [
            "rollout",
            "status",
            "deployment/research-admin-backend",
            "-n",
            namespace,
            "--timeout=120s",
        ],
        kubeconfig=kubeconfig,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--kubeconfig",
        default=os.environ.get("KUBECONFIG", str(Path.home() / ".kube/kind-config")),
    )
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--info-port", type=int, default=18082)
    parser.add_argument("--knowledge-port", type=int, default=18083)
    parser.add_argument("--research-port", type=int, default=18084)
    args = parser.parse_args()

    kubeconfig = str(Path(args.kubeconfig).expanduser())
    info_url = f"http://127.0.0.1:{args.info_port}"
    knowledge_url = f"http://127.0.0.1:{args.knowledge_port}"
    research_url = f"http://127.0.0.1:{args.research_port}"
    forwards: list[subprocess.Popen[bytes]] = []
    research_overridden = False
    summary: dict[str, Any] = {"task": "V5-P0-005", "result": "failed"}
    try:
        # Enabling Research replaces its Pod. Complete that rollout before
        # binding a port-forward, otherwise the tunnel may stay attached to
        # the terminating Pod and fail mid-request.
        assert_no_explicit_research_traffic_override(
            kubeconfig=kubeconfig, namespace=args.namespace
        )
        set_research_traffic(kubeconfig=kubeconfig, namespace=args.namespace, enabled=True)
        research_overridden = True

        forwards = [
            start_port_forward(
                kubeconfig=kubeconfig,
                namespace=args.namespace,
                target="service/info-admin-backend",
                local_port=args.info_port,
            ),
            start_port_forward(
                kubeconfig=kubeconfig,
                namespace=args.namespace,
                target="service/knowledge-admin-backend",
                local_port=args.knowledge_port,
            ),
            start_port_forward(
                kubeconfig=kubeconfig,
                namespace=args.namespace,
                target="service/research-admin-backend",
                local_port=args.research_port,
            ),
        ]
        wait_for_reachable(info_url, "/api/documents")
        wait_for_reachable(knowledge_url, "/api/knowledge/ingestions")
        wait_for_reachable(research_url, "/api/agent/sessions")

        anonymous = {
            "info_documents": expect_status(info_url, "/api/documents", {401}),
            "knowledge_ingestions": expect_status(
                knowledge_url, "/api/knowledge/ingestions", {401}
            ),
            "research_sessions": expect_status(
                research_url, "/api/agent/sessions", {401}, method="POST", payload={}
            ),
        }

        workload_binding = verify_service_workload_binding(
            kubeconfig=kubeconfig, namespace=args.namespace
        )
        internal_unauthenticated = expect_status(
            knowledge_url,
            "/api/internal/v1/knowledge/ingestions",
            {401},
            method="POST",
            payload={},
        )
        # The probe runs the production Info worker client. Empty JSON reaches
        # Pydantic only after Knowledge validates the real service token.
        internal_authenticated = verify_info_worker_service_call(
            kubeconfig=kubeconfig, namespace=args.namespace
        )
        summary = {
            "task": "V5-P0-005",
            "result": "passed",
            "anonymous": anonymous,
            "internal_route": {
                "without_service_token": internal_unauthenticated,
                "with_real_worker_client_credentials": internal_authenticated,
                "token_printed": False,
                "credentials_read_by_local_process": False,
            },
            "workload_binding": workload_binding,
            "browser_pkce_matrix": "not_automated_by_this_script",
        }
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0
    except (VerificationError, subprocess.CalledProcessError) as exc:
        summary["error"] = str(exc)
        print(json.dumps(summary, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    finally:
        if research_overridden:
            try:
                set_research_traffic(
                    kubeconfig=kubeconfig, namespace=args.namespace, enabled=False
                )
            except subprocess.CalledProcessError as exc:
                print(
                    json.dumps(
                        {"warning": "failed to restore research traffic flag", "error": str(exc)},
                        ensure_ascii=False,
                    ),
                    file=sys.stderr,
                )
        for process in forwards:
            process.terminate()
        for process in forwards:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()


if __name__ == "__main__":
    raise SystemExit(main())
