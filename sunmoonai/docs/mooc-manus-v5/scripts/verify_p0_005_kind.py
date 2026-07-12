#!/usr/bin/env python3
"""KIND verification for V5-P0-005 identity boundaries.

The script never prints access tokens or client secrets. It checks anonymous
fail-closed behavior for the three Admin APIs and, when service credentials are
provided through the environment, checks that the Info -> Knowledge internal
route accepts a real client-credentials token while rejecting an unauthenticated
request. Research traffic is enabled only for the duration of the check and is
restored in ``finally``.

Required environment for the service-token check::

    CASDOOR_SERVICE_CLIENT_ID
    CASDOOR_SERVICE_CLIENT_SECRET

The Casdoor application, audience, and subject binding must already be present
in the Knowledge deployment configuration. No browser login is automated here;
the browser PKCE/session matrix remains an interactive or Playwright evidence
task after the real Casdoor applications are provisioned.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
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
    except (urllib.error.URLError, TimeoutError) as exc:
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


def request_absolute_json(url: str, *, method: str = "GET", form: bytes | None = None) -> Any:
    request = urllib.request.Request(
        url,
        data=form,
        method=method,
        headers={
            "Accept": "application/json",
            **({"Content-Type": "application/x-www-form-urlencoded"} if form else {}),
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as exc:
        raise HttpFailure(exc.code, exc.read().decode(errors="replace")) from exc
    except (urllib.error.URLError, TimeoutError) as exc:
        raise VerificationError(f"request failed: {exc}") from exc


def get_service_token(casdoor_url: str, application: str) -> str:
    client_id = os.environ.get("CASDOOR_SERVICE_CLIENT_ID", "")
    client_secret = os.environ.get("CASDOOR_SERVICE_CLIENT_SECRET", "")
    if not client_id or not client_secret:
        raise VerificationError(
            "CASDOOR_SERVICE_CLIENT_ID and CASDOOR_SERVICE_CLIENT_SECRET are required"
        )
    discovery_url = (
        f"{casdoor_url.rstrip('/')}/.well-known/{application}/openid-configuration"
    )
    try:
        metadata = request_absolute_json(discovery_url)
    except Exception as exc:
        raise VerificationError("Casdoor service discovery failed") from exc
    token_endpoint = metadata.get("token_endpoint") if isinstance(metadata, dict) else None
    if not isinstance(token_endpoint, str) or not token_endpoint:
        raise VerificationError("Casdoor discovery did not provide token_endpoint")
    body = urllib.parse.urlencode(
        {
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": client_secret,
            "scope": "openid",
        }
    ).encode()
    # Discovery may advertise the cluster/external hostname. Use the local
    # port-forward while preserving its path and query.
    advertised = urllib.parse.urlsplit(token_endpoint)
    token_url = urllib.parse.urlunsplit(
        (urllib.parse.urlsplit(casdoor_url).scheme, urllib.parse.urlsplit(casdoor_url).netloc,
         advertised.path, advertised.query, "")
    )
    try:
        payload = request_absolute_json(token_url, method="POST", form=body)
    except Exception as exc:
        raise VerificationError("Casdoor client-credentials request failed") from exc
    token = payload.get("access_token") if isinstance(payload, dict) else None
    if not isinstance(token, str) or not token:
        raise VerificationError("Casdoor token response did not contain access_token")
    return token


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
    parser.add_argument("--casdoor-port", type=int, default=18081)
    parser.add_argument("--casdoor-service", default="service/casdoor-sunmoonai")
    parser.add_argument(
        "--casdoor-application", default="sunmoonai-info-knowledge-ingest"
    )
    args = parser.parse_args()

    kubeconfig = str(Path(args.kubeconfig).expanduser())
    info_url = f"http://127.0.0.1:{args.info_port}"
    knowledge_url = f"http://127.0.0.1:{args.knowledge_port}"
    research_url = f"http://127.0.0.1:{args.research_port}"
    casdoor_url = f"http://127.0.0.1:{args.casdoor_port}"
    forwards: list[subprocess.Popen[bytes]] = []
    research_overridden = False
    summary: dict[str, Any] = {"task": "V5-P0-005", "result": "failed"}
    try:
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
            start_port_forward(
                kubeconfig=kubeconfig,
                namespace=args.namespace,
                target=args.casdoor_service,
                local_port=args.casdoor_port,
            ),
        ]
        time.sleep(2)

        # Research is traffic-off by default; enable only to verify its auth boundary.
        set_research_traffic(kubeconfig=kubeconfig, namespace=args.namespace, enabled=True)
        research_overridden = True

        anonymous = {
            "info_documents": expect_status(info_url, "/api/documents", {401}),
            "knowledge_ingestions": expect_status(
                knowledge_url, "/api/knowledge/ingestions", {401}
            ),
            "research_sessions": expect_status(
                research_url, "/api/agent/sessions", {401}, method="POST", payload={}
            ),
        }

        service_token = get_service_token(casdoor_url, args.casdoor_application)
        service_headers = {"Authorization": f"Bearer {service_token}"}
        internal_unauthenticated = expect_status(
            knowledge_url,
            "/api/internal/v1/knowledge/ingestions",
            {401},
            method="POST",
            payload={},
        )
        # Empty JSON reaches Pydantic only after the service dependency succeeds;
        # 422 therefore proves the real service token crossed the auth boundary.
        internal_authenticated = expect_status(
            knowledge_url,
            "/api/internal/v1/knowledge/ingestions",
            {422},
            method="POST",
            payload={},
            headers=service_headers,
        )
        summary = {
            "task": "V5-P0-005",
            "result": "passed",
            "anonymous": anonymous,
            "internal_route": {
                "without_service_token": internal_unauthenticated,
                "with_real_client_credentials": internal_authenticated,
                "token_printed": False,
            },
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
