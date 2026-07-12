#!/usr/bin/env python3
"""Repeatable KIND verification for V5-P0-003.

The script uses only internal Info/Knowledge APIs and kubectl port-forward. It
temporarily forces the Knowledge worker into artifact-verification mode and
adds one existing but unauthorized bucket to the application allowlist so a
real S3 403 can be observed. Both overrides are removed in a finally block.
No object body or credential is printed.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from typing import Any, Callable


TERMINAL_KNOWLEDGE_STATUSES = {
    "artifact_verified",
    "succeeded",
    "failed",
    "ragflow_config_error",
    "ragflow_parse_failed",
    "artifact_unreadable",
    "external_api_error",
}


class VerificationError(RuntimeError):
    pass


class ApiError(VerificationError):
    def __init__(self, status: int, body: str) -> None:
        super().__init__(f"HTTP {status}: {body[:500]}")
        self.status = status


def kubectl(args: list[str], *, kubeconfig: str, capture: bool = False) -> str:
    command = ["kubectl", "--kubeconfig", kubeconfig, *args]
    result = subprocess.run(
        command,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )
    return result.stdout if capture else ""


def api_json(
    base_url: str,
    path: str,
    *,
    method: str = "GET",
    query: dict[str, Any] | None = None,
    payload: dict[str, Any] | None = None,
) -> Any:
    url = f"{base_url}{path}"
    if query:
        url = f"{url}?{urllib.parse.urlencode(query)}"
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"} if data is not None else {},
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        raise ApiError(exc.code, body) from exc
    except (urllib.error.URLError, TimeoutError) as exc:
        raise VerificationError(f"request failed for {path}: {exc}") from exc


def wait_until(
    description: str,
    read: Callable[[], Any],
    done: Callable[[Any], bool],
    *,
    timeout: float,
) -> Any:
    deadline = time.monotonic() + timeout
    last: Any = None
    while time.monotonic() < deadline:
        try:
            last = read()
            if done(last):
                return last
        except VerificationError:
            pass
        time.sleep(1)
    raise VerificationError(f"timed out waiting for {description}; last={last!r}")


def start_port_forward(
    *, kubeconfig: str, namespace: str, service: str, local_port: int
) -> subprocess.Popen[bytes]:
    return subprocess.Popen(
        [
            "kubectl",
            "--kubeconfig",
            kubeconfig,
            "port-forward",
            "-n",
            namespace,
            f"service/{service}",
            f"{local_port}:8000",
            "--address=127.0.0.1",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def assert_no_explicit_worker_overrides(*, kubeconfig: str, namespace: str) -> None:
    raw = kubectl(
        [
            "get",
            "deployment/celeryworker-knowledge-admin-backend",
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
    names = {item.get("name") for item in env}
    managed = {"RAGFLOW_API_KEY", "ARTIFACT_S3_ALLOWED_BUCKETS"}
    conflict = sorted(name for name in managed if name in names)
    if conflict:
        raise VerificationError(
            "refusing to overwrite existing explicit worker env: " + ", ".join(conflict)
        )


def configure_isolated_verifier(*, kubeconfig: str, namespace: str) -> None:
    kubectl(
        [
            "set",
            "env",
            "deployment/celeryworker-knowledge-admin-backend",
            "-n",
            namespace,
            "RAGFLOW_API_KEY=",
            (
                "ARTIFACT_S3_ALLOWED_BUCKETS=development-info-originals,"
                "development-research-admin-assets"
            ),
        ],
        kubeconfig=kubeconfig,
    )
    kubectl(
        [
            "rollout",
            "status",
            "deployment/celeryworker-knowledge-admin-backend",
            "-n",
            namespace,
            "--timeout=120s",
        ],
        kubeconfig=kubeconfig,
    )


def restore_worker(*, kubeconfig: str, namespace: str) -> None:
    kubectl(
        [
            "set",
            "env",
            "deployment/celeryworker-knowledge-admin-backend",
            "-n",
            namespace,
            "RAGFLOW_API_KEY-",
            "ARTIFACT_S3_ALLOWED_BUCKETS-",
        ],
        kubeconfig=kubeconfig,
    )
    kubectl(
        [
            "rollout",
            "status",
            "deployment/celeryworker-knowledge-admin-backend",
            "-n",
            namespace,
            "--timeout=120s",
        ],
        kubeconfig=kubeconfig,
    )


def create_real_distribution(info_url: str, dataset_key: str) -> dict[str, Any]:
    documents = api_json(info_url, "/api/documents", query={"limit": 200})
    for document in documents:
        document_id = document["id"]
        versions = api_json(info_url, f"/api/documents/{document_id}/versions")
        versions = sorted(versions, key=lambda item: item.get("version_no", 0), reverse=True)
        for version in versions:
            version_id = version["id"]
            artifacts = api_json(
                info_url,
                f"/api/documents/{document_id}/versions/{version_id}/artifacts",
            )
            usable = any(
                artifact.get("artifact_type") in {"clean_markdown", "text_plain"}
                and artifact.get("storage_state") == "available"
                and artifact.get("version_id") not in {None, "", "null"}
                for artifact in artifacts
            )
            if not usable:
                continue
            try:
                return api_json(
                    info_url,
                    "/api/admin/distributions/knowledge",
                    method="POST",
                    payload={
                        "document_version_id": version_id,
                        "target_dataset": dataset_key,
                        "dispatch": True,
                    },
                )
            except ApiError as exc:
                if exc.status == 409:
                    continue
                raise
    raise VerificationError("no distributable versioned Info artifact was found")


def wait_for_distribution(info_url: str, distribution_id: str) -> dict[str, Any]:
    return wait_until(
        "Info distribution",
        lambda: api_json(info_url, f"/api/admin/distributions/{distribution_id}"),
        lambda record: record.get("status") in {"succeeded", "failed"},
        timeout=120,
    )


def wait_for_ingestion_by_key(knowledge_url: str, key: str) -> dict[str, Any]:
    jobs = wait_until(
        f"Knowledge job for {key}",
        lambda: api_json(
            knowledge_url,
            "/api/knowledge/ingestions",
            query={"idempotency_key": key},
        ),
        lambda items: bool(items),
        timeout=60,
    )
    job_id = jobs[0]["id"]
    return wait_until(
        f"Knowledge ingestion {job_id}",
        lambda: api_json(knowledge_url, f"/api/knowledge/ingestions/{job_id}"),
        lambda job: job.get("status") in TERMINAL_KNOWLEDGE_STATUSES,
        timeout=180,
    )


def submit_fault(
    knowledge_url: str,
    base_payload: dict[str, Any],
    *,
    fault: str,
) -> dict[str, Any]:
    payload = copy.deepcopy(base_payload)
    operation_id = str(uuid.uuid4())
    payload["distribution_id"] = operation_id
    payload["correlation_id"] = operation_id
    payload["idempotency_key"] = f"p0-artifact-{fault}-{operation_id}"
    artifact = payload["artifact"]
    if fault == "hash-mismatch":
        artifact["sha256"] = "0" * 64
    elif fault == "missing-object":
        artifact["uri"] = (
            "s3://development-info-originals/info/original/"
            f"p0-missing-{operation_id}.md"
        )
        # MinIO version IDs are UUID-shaped. A made-up textual prefix is
        # rejected as malformed (400) before object lookup, so use a valid but
        # nonexistent version ID to exercise the intended NoSuchKey path.
        artifact["storage_version"] = operation_id
    elif fault == "permission-denied":
        artifact["uri"] = (
            "s3://development-research-admin-assets/info/original/"
            f"p0-denied-{operation_id}.md"
        )
        artifact["storage_version"] = operation_id
    else:
        raise AssertionError(f"unknown fault: {fault}")
    api_json(
        knowledge_url,
        "/api/knowledge/ingestions",
        method="POST",
        payload=payload,
    )
    return wait_for_ingestion_by_key(knowledge_url, payload["idempotency_key"])


def error_summary(job: dict[str, Any]) -> str:
    return str(job.get("last_error") or "")[:240]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--kubeconfig",
        default=os.environ.get("KUBECONFIG", str(Path.home() / ".kube/kind-config")),
    )
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--info-port", type=int, default=18082)
    parser.add_argument("--knowledge-port", type=int, default=18083)
    args = parser.parse_args()

    kubeconfig = str(Path(args.kubeconfig).expanduser())
    info_url = f"http://127.0.0.1:{args.info_port}"
    knowledge_url = f"http://127.0.0.1:{args.knowledge_port}"
    forwards: list[subprocess.Popen[bytes]] = []
    worker_overridden = False
    summary: dict[str, Any] = {"task": "V5-P0-003", "result": "failed"}
    try:
        assert_no_explicit_worker_overrides(
            kubeconfig=kubeconfig, namespace=args.namespace
        )
        worker_overridden = True
        configure_isolated_verifier(kubeconfig=kubeconfig, namespace=args.namespace)

        forwards = [
            start_port_forward(
                kubeconfig=kubeconfig,
                namespace=args.namespace,
                service="info-admin-backend",
                local_port=args.info_port,
            ),
            start_port_forward(
                kubeconfig=kubeconfig,
                namespace=args.namespace,
                service="knowledge-admin-backend",
                local_port=args.knowledge_port,
            ),
        ]
        wait_until(
            "Info port-forward",
            lambda: api_json(info_url, "/api/documents", query={"limit": 1}),
            lambda _: True,
            timeout=30,
        )
        wait_until(
            "Knowledge port-forward",
            lambda: api_json(
                knowledge_url, "/api/knowledge/ingestions", query={"limit": 1}
            ),
            lambda _: True,
            timeout=30,
        )

        suffix = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
        dataset_key = f"p0-artifact-smoke-{suffix}"
        distribution = create_real_distribution(info_url, dataset_key)
        distribution = wait_for_distribution(info_url, distribution["id"])
        if distribution.get("status") != "succeeded":
            raise VerificationError(
                "Info distribution failed: " + str(distribution.get("last_error"))[:240]
            )
        internal_distribution_keys = {
            "status_history",
            "last_status_update",
            "retry_history",
            "last_retry",
        }
        contract_payload = {
            key: value
            for key, value in distribution["payload"].items()
            if key not in internal_distribution_keys
        }
        success = wait_for_ingestion_by_key(
            knowledge_url, contract_payload["idempotency_key"]
        )
        if success.get("status") != "artifact_verified":
            raise VerificationError(
                f"expected artifact_verified, got {success.get('status')}: "
                + error_summary(success)
            )

        faults: dict[str, dict[str, Any]] = {}
        expectations = {
            "hash-mismatch": "sha256 mismatch",
            "missing-object": "HTTP 404",
            "permission-denied": "HTTP 403",
        }
        for fault, expected_error in expectations.items():
            job = submit_fault(
                knowledge_url,
                contract_payload,
                fault=fault,
            )
            actual_error = error_summary(job)
            if job.get("status") != "artifact_unreadable":
                raise VerificationError(
                    f"{fault}: expected artifact_unreadable, got {job.get('status')}"
                )
            if expected_error.lower() not in actual_error.lower():
                raise VerificationError(
                    f"{fault}: expected error containing {expected_error!r}, got "
                    f"{actual_error!r}"
                )
            faults[fault] = {
                "ingestion_id": job["id"],
                "status": job["status"],
                "error": actual_error,
            }

        summary = {
            "task": "V5-P0-003",
            "result": "passed",
            "contract_version": contract_payload["contract_version"],
            "distribution_id": distribution["id"],
            "source_document_version_id": contract_payload[
                "source_document_version_id"
            ],
            "dataset_key": contract_payload["dataset_key"],
            "success": {
                "ingestion_id": success["id"],
                "status": success["status"],
                "verified_size_bytes": success["status_history"][-1]
                .get("metadata", {})
                .get("verified_size_bytes"),
            },
            "faults": faults,
            "database_callback_used": False,
        }
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0
    except (VerificationError, subprocess.CalledProcessError) as exc:
        summary["error"] = str(exc)
        print(json.dumps(summary, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    finally:
        for process in forwards:
            process.terminate()
        for process in forwards:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        if worker_overridden:
            try:
                restore_worker(kubeconfig=kubeconfig, namespace=args.namespace)
            except subprocess.CalledProcessError as exc:
                print(
                    json.dumps(
                        {
                            "warning": "failed to restore temporary worker env",
                            "error": str(exc),
                        },
                        ensure_ascii=False,
                    ),
                    file=sys.stderr,
                )


if __name__ == "__main__":
    raise SystemExit(main())
