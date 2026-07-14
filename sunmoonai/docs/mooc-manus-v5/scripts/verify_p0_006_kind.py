#!/usr/bin/env python3
"""Fault verification for the Info transactional-outbox P0 prototype.

The verifier creates only new, uniquely named Info distributions and temporary
scanner Jobs.  It never prints credentials, object contents or broker URLs.
The suspended CronJob is always returned to suspend=true in ``finally``.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Callable

from verify_p0_003_kind import (
    ApiError,
    VerificationError,
    api_json,
    assert_no_explicit_worker_overrides,
    configure_isolated_verifier,
    create_real_distribution,
    restore_worker,
    start_port_forward,
    wait_for_distribution,
    wait_for_ingestion_by_key,
    wait_until,
)


def kubectl(
    args: list[str], *, kubeconfig: str, capture: bool = False, input_text: str | None = None
) -> str:
    result = subprocess.run(
        ["kubectl", "--kubeconfig", kubeconfig, *args],
        input=input_text,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )
    return result.stdout if capture else ""


def read_outbox(
    *, kubeconfig: str, namespace: str, distribution_id: str
) -> dict[str, Any] | None:
    # The query runs in the existing backend container, so DATABASE_URL never
    # leaves Kubernetes and the verifier only receives safe state metadata.
    query = """
import asyncio
import json
import sys
import uuid
from sqlalchemy import select
from app.infrastructure.models.info import DeliveryOutboxMessage
from app.infrastructure.storage.postgres import get_postgres

async def main():
    postgres = get_postgres()
    await postgres.init()
    async with postgres.session_factory() as session:
        result = await session.execute(
            select(DeliveryOutboxMessage).where(
                DeliveryOutboxMessage.aggregate_id == uuid.UUID(sys.argv[1])
            )
        )
        rows = list(result.scalars())
        if len(rows) > 1:
            raise RuntimeError("expected no more than one outbox operation")
        if not rows:
            print("P0_OUTBOX_STATE=null")
            return
        row = rows[0]
        print("P0_OUTBOX_STATE=" + json.dumps({
            "id": str(row.id),
            "state": row.state,
            "attempt_count": row.attempt_count,
            "available_at": row.available_at.isoformat() if row.available_at else None,
            "has_broker_message_id": bool(row.broker_message_id),
            "has_last_error": bool(row.last_error),
        }, sort_keys=True))

asyncio.run(main())
"""
    output = kubectl(
        [
            "exec",
            "-n",
            namespace,
            "deploy/info-admin-backend",
            "--",
            ".venv/bin/python",
            "-c",
            query,
            distribution_id,
        ],
        kubeconfig=kubeconfig,
        capture=True,
    )
    for line in output.splitlines():
        if line.startswith("P0_OUTBOX_STATE="):
            value = line.removeprefix("P0_OUTBOX_STATE=")
            return None if value == "null" else json.loads(value)
    raise VerificationError("outbox query did not return its safe state marker")


def wait_for_outbox(
    *,
    kubeconfig: str,
    namespace: str,
    distribution_id: str,
    done: Callable[[dict[str, Any] | None], bool],
    description: str,
    timeout: float = 150,
) -> dict[str, Any]:
    value = wait_until(
        description,
        lambda: read_outbox(
            kubeconfig=kubeconfig,
            namespace=namespace,
            distribution_id=distribution_id,
        ),
        done,
        timeout=timeout,
    )
    if value is None:
        raise VerificationError(f"{description}: outbox row was not found")
    return value


def scanner_job_yaml(
    *, namespace: str, name: str, image: str, broken_broker: bool
) -> str:
    broker_override = ""
    if broken_broker:
        # Deliberately non-routable test endpoint; no real credential is used.
        broker_override = """
        env:
        - name: CELERY_BROKER_URL
          value: amqp://127.0.0.1:1/p0
"""
    return f"""apiVersion: batch/v1
kind: Job
metadata:
  name: {name}
  namespace: {namespace}
  labels:
    app: celeryworker-info-admin-backend
    component: delivery-outbox-scanner
    sunmoonai.com/p0-verifier: "true"
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 300
  template:
    metadata:
      labels:
        app: celeryworker-info-admin-backend
        component: delivery-outbox-scanner
        sunmoonai.com/p0-verifier: "true"
    spec:
      serviceAccountName: info-delivery-outbox-scanner
      automountServiceAccountToken: false
      restartPolicy: Never
      imagePullSecrets:
      - name: harbor-registry-secret
      containers:
      - name: delivery-outbox-scanner
        image: {image}
        imagePullPolicy: Always
        command: [".venv/bin/python", "-m", "app.cli.drain_delivery_outbox"]
        args: ["--limit", "50"]
        envFrom:
        - configMapRef:
            name: info-admin-backend-config
        - configMapRef:
            name: celeryworker-info-admin-backend-config
        - secretRef:
            name: celeryworker-info-admin-backend-secret
        - secretRef:
            name: info-admin-backend-postgresql-conn
{broker_override}"""


def create_scanner_job(
    *, kubeconfig: str, namespace: str, name: str, image: str, broken_broker: bool
) -> None:
    kubectl(
        ["apply", "-f", "-"],
        kubeconfig=kubeconfig,
        input_text=scanner_job_yaml(
            namespace=namespace,
            name=name,
            image=image,
            broken_broker=broken_broker,
        ),
    )
    kubectl(
        [
            "wait",
            "--for=condition=complete",
            f"job/{name}",
            "-n",
            namespace,
            "--timeout=150s",
        ],
        kubeconfig=kubeconfig,
    )


def scanner_job_summary(*, kubeconfig: str, namespace: str, name: str) -> dict[str, Any]:
    """Read only the scanner's count summary; it never includes credentials."""
    output = kubectl(
        ["logs", f"job/{name}", "-n", namespace],
        kubeconfig=kubeconfig,
        capture=True,
    )
    for line in reversed(output.splitlines()):
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if value.get("task") == "info-delivery-outbox":
            return {
                "claimed": int(value.get("claimed", 0)),
                "published": int(value.get("published", 0)),
                "broker_failures": int(value.get("broker_failures", 0)),
            }
    raise VerificationError(f"scanner job {name} did not emit a count summary")


def assert_candidate_images(*, kubeconfig: str, namespace: str, image: str) -> None:
    raw = kubectl(
        [
            "get",
            "deployment/info-admin-backend",
            "deployment/celeryworker-info-admin-backend",
            "-n",
            namespace,
            "-o",
            "json",
        ],
        kubeconfig=kubeconfig,
        capture=True,
    )
    deployments = json.loads(raw)["items"]
    actual = {
        item["metadata"]["name"]: item["spec"]["template"]["spec"]["containers"][0][
            "image"
        ]
        for item in deployments
    }
    if set(actual.values()) != {image}:
        raise VerificationError(f"candidate image mismatch: {actual}")

    cronjob = json.loads(
        kubectl(
            [
                "get",
                "cronjob/info-delivery-outbox-scanner",
                "-n",
                namespace,
                "-o",
                "json",
            ],
            kubeconfig=kubeconfig,
            capture=True,
        )
    )
    scanner_image = cronjob["spec"]["jobTemplate"]["spec"]["template"]["spec"][
        "containers"
    ][0]["image"]
    if scanner_image != image or cronjob["spec"].get("suspend") is not True:
        raise VerificationError("scanner CronJob must use candidate image and start suspended")


def set_cronjob_suspend(*, kubeconfig: str, namespace: str, value: bool) -> None:
    kubectl(
        [
            "patch",
            "cronjob/info-delivery-outbox-scanner",
            "-n",
            namespace,
            "--type=merge",
            "-p",
            json.dumps({"spec": {"suspend": value}}),
        ],
        kubeconfig=kubeconfig,
    )


def assert_no_explicit_info_api_broker_override(*, kubeconfig: str, namespace: str) -> None:
    """Do not hide an operator-owned API broker override during verification."""
    raw = kubectl(
        [
            "get",
            "deployment/info-admin-backend",
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
    if any(item.get("name") == "CELERY_BROKER_URL" for item in env):
        raise VerificationError(
            "refusing to overwrite an existing explicit Info API CELERY_BROKER_URL"
        )


def set_info_api_broker_override(
    *, kubeconfig: str, namespace: str, broken: bool
) -> None:
    """Temporarily make the API's immediate wake-up fail, then restore envFrom."""
    value = "CELERY_BROKER_URL=amqp://127.0.0.1:1/p0" if broken else "CELERY_BROKER_URL-"
    kubectl(
        [
            "set",
            "env",
            "deployment/info-admin-backend",
            "-n",
            namespace,
            value,
        ],
        kubeconfig=kubeconfig,
    )
    kubectl(
        [
            "rollout",
            "status",
            "deployment/info-admin-backend",
            "-n",
            namespace,
            "--timeout=120s",
        ],
        kubeconfig=kubeconfig,
    )


def wait_until_outbox_due(row: dict[str, Any]) -> None:
    """Wait for the configured retry deadline instead of assuming five seconds."""
    available_at = row.get("available_at")
    if not available_at:
        raise VerificationError("recovered outbox row did not contain available_at")
    due_at = datetime.fromisoformat(str(available_at).replace("Z", "+00:00"))
    remaining = (due_at - datetime.now(UTC)).total_seconds()
    if remaining > 0:
        time.sleep(remaining + 1)


def assert_one_ingestion(knowledge_url: str, idempotency_key: str) -> dict[str, Any]:
    job = wait_for_ingestion_by_key(knowledge_url, idempotency_key)
    jobs = api_json(
        knowledge_url,
        "/api/knowledge/ingestions",
        query={"idempotency_key": idempotency_key},
    )
    if len(jobs) != 1:
        raise VerificationError(f"expected one Knowledge ingestion operation, got {len(jobs)}")
    return job


def contract_payload(distribution: dict[str, Any]) -> dict[str, Any]:
    internal_keys = {
        "status_history",
        "last_status_update",
        "retry_history",
        "last_retry",
        "audit_log",
        "last_audit",
    }
    return {
        key: value
        for key, value in distribution["payload"].items()
        if key not in internal_keys
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", required=True, help="immutable P0 candidate image reference")
    parser.add_argument(
        "--kubeconfig",
        default=os.environ.get("KUBECONFIG", str(Path.home() / ".kube/kind-config")),
    )
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--info-port", type=int, default=18086)
    parser.add_argument("--knowledge-port", type=int, default=18087)
    args = parser.parse_args()

    kubeconfig = str(Path(args.kubeconfig).expanduser())
    suffix = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
    info_url = f"http://127.0.0.1:{args.info_port}"
    knowledge_url = f"http://127.0.0.1:{args.knowledge_port}"
    forwards: list[subprocess.Popen[bytes]] = []
    cronjob_unsuspended = False
    knowledge_worker_overridden = False
    info_api_broker_overridden = False
    temp_jobs: list[str] = []
    summary: dict[str, Any] = {"task": "V5-P0-006", "result": "failed"}
    try:
        assert_candidate_images(
            kubeconfig=kubeconfig, namespace=args.namespace, image=args.image
        )
        assert_no_explicit_worker_overrides(
            kubeconfig=kubeconfig, namespace=args.namespace
        )
        assert_no_explicit_info_api_broker_override(
            kubeconfig=kubeconfig, namespace=args.namespace
        )
        configure_isolated_verifier(kubeconfig=kubeconfig, namespace=args.namespace)
        knowledge_worker_overridden = True
        set_info_api_broker_override(
            kubeconfig=kubeconfig, namespace=args.namespace, broken=True
        )
        info_api_broker_overridden = True
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

        failed_distribution = create_real_distribution(
            info_url, f"p0-outbox-broker-{suffix}"
        )
        failed_id = failed_distribution["id"]
        recovered_pending = wait_for_outbox(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=failed_id,
            done=lambda row: row is not None
            and row["state"] == "pending"
            and row["attempt_count"] >= 1
            and row["has_last_error"],
            description="API broker failure retained as pending outbox work",
        )

        # Restore the normal envFrom-provided broker before exercising scanner
        # recovery.  Restart port-forwards because an API rollout replaces the
        # selected service endpoint.
        for process in forwards:
            process.terminate()
        for process in forwards:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        forwards = []
        set_info_api_broker_override(
            kubeconfig=kubeconfig, namespace=args.namespace, broken=False
        )
        info_api_broker_overridden = False
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
            "Info port-forward after API broker restore",
            lambda: api_json(info_url, "/api/documents", query={"limit": 1}),
            lambda _: True,
            timeout=30,
        )
        wait_until_outbox_due(recovered_pending)

        # Two independent scanners race for the same due row.  SKIP LOCKED
        # permits only one current lease and the downstream idempotency key
        # permits a safe retry after any acknowledgement ambiguity.
        scanner_jobs = [f"p0-006-scan-a-{suffix}", f"p0-006-scan-b-{suffix}"]
        temp_jobs.extend(scanner_jobs)
        kubectl(
            ["apply", "-f", "-"],
            kubeconfig=kubeconfig,
            input_text="---\n".join(
                scanner_job_yaml(
                    namespace=args.namespace,
                    name=job_name,
                    image=args.image,
                    broken_broker=False,
                )
                for job_name in scanner_jobs
            ),
        )
        for job_name in scanner_jobs:
            kubectl(
                [
                    "wait",
                    "--for=condition=complete",
                    f"job/{job_name}",
                    "-n",
                    args.namespace,
                    "--timeout=150s",
                ],
                kubeconfig=kubeconfig,
            )
        scanner_summaries = [
            scanner_job_summary(
                kubeconfig=kubeconfig, namespace=args.namespace, name=job_name
            )
            for job_name in scanner_jobs
        ]
        if sum(item["claimed"] for item in scanner_summaries) != 1:
            raise VerificationError(
                "scanner competition must claim the recovered operation exactly once"
            )

        completed_distribution = wait_for_distribution(info_url, failed_id)
        if completed_distribution.get("status") != "succeeded":
            raise VerificationError("recovered distribution did not succeed")
        completed_outbox = wait_for_outbox(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=failed_id,
            done=lambda row: row is not None and row["state"] == "completed" and row["attempt_count"] >= 2,
            description="recovered outbox completion",
        )
        ingestion = assert_one_ingestion(
            knowledge_url, contract_payload(completed_distribution)["idempotency_key"]
        )
        if ingestion.get("status") not in {"artifact_verified", "succeeded"}:
            raise VerificationError("Knowledge did not finish recovered ingestion")

        # Finally exercise the scheduler, rather than only one-off jobs.  Use
        # the same API-side broker fault so the normal immediate wake-up cannot
        # consume the record before the suspended CronJob gets its turn.
        for process in forwards:
            process.terminate()
        for process in forwards:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        forwards = []
        set_info_api_broker_override(
            kubeconfig=kubeconfig, namespace=args.namespace, broken=True
        )
        info_api_broker_overridden = True
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
            "Info port-forward for scheduled scanner fault",
            lambda: api_json(info_url, "/api/documents", query={"limit": 1}),
            lambda _: True,
            timeout=30,
        )
        scheduled_distribution = create_real_distribution(
            info_url, f"p0-outbox-schedule-{suffix}"
        )
        scheduled_pending = wait_for_outbox(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=scheduled_distribution["id"],
            done=lambda row: row is not None
            and row["state"] == "pending"
            and row["attempt_count"] >= 1
            and row["has_last_error"],
            description="scheduled scanner durable pending outbox work",
        )
        for process in forwards:
            process.terminate()
        for process in forwards:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        forwards = []
        set_info_api_broker_override(
            kubeconfig=kubeconfig, namespace=args.namespace, broken=False
        )
        info_api_broker_overridden = False
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
            "Info port-forward before scheduled scanner",
            lambda: api_json(info_url, "/api/documents", query={"limit": 1}),
            lambda _: True,
            timeout=30,
        )
        wait_until_outbox_due(scheduled_pending)
        set_cronjob_suspend(
            kubeconfig=kubeconfig, namespace=args.namespace, value=False
        )
        cronjob_unsuspended = True
        scheduled_done = wait_for_distribution(info_url, scheduled_distribution["id"])
        if scheduled_done.get("status") != "succeeded":
            raise VerificationError("CronJob scanner did not finish distribution")
        scheduled_outbox = wait_for_outbox(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=scheduled_distribution["id"],
            done=lambda row: row is not None and row["state"] == "completed",
            description="CronJob outbox completion",
            timeout=150,
        )
        scheduled_ingestion = assert_one_ingestion(
            knowledge_url, contract_payload(scheduled_done)["idempotency_key"]
        )
        if scheduled_ingestion.get("status") not in {"artifact_verified", "succeeded"}:
            raise VerificationError("Knowledge did not finish scheduled ingestion")

        summary = {
            "task": "V5-P0-006",
            "result": "passed",
            "broker_failure": {
                "distribution_id": failed_id,
                "outbox_id": recovered_pending["id"],
                "attempts_after_block": recovered_pending["attempt_count"],
                "attempts_after_recovery": completed_outbox["attempt_count"],
                "final_state": completed_outbox["state"],
            },
            "scanner_competition": {
                "jobs": 2,
                "claimed": sum(item["claimed"] for item in scanner_summaries),
                "business_effects": 1,
            },
            "scheduled_scanner": {
                "distribution_id": scheduled_distribution["id"],
                "outbox_id": scheduled_outbox["id"],
                "final_state": scheduled_outbox["state"],
            },
            "credentials_printed": False,
        }
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0
    except (ApiError, VerificationError, subprocess.CalledProcessError) as exc:
        summary["error"] = str(exc)[:500]
        print(json.dumps(summary, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    finally:
        if cronjob_unsuspended:
            try:
                set_cronjob_suspend(
                    kubeconfig=kubeconfig, namespace=args.namespace, value=True
                )
            except subprocess.CalledProcessError:
                print(
                    json.dumps(
                        {
                            "warning": "failed to restore scanner CronJob suspension",
                            "manual_action": "patch info-delivery-outbox-scanner spec.suspend=true",
                        }
                    ),
                    file=sys.stderr,
                )
        if info_api_broker_overridden:
            try:
                set_info_api_broker_override(
                    kubeconfig=kubeconfig, namespace=args.namespace, broken=False
                )
            except subprocess.CalledProcessError:
                print(
                    json.dumps(
                        {
                            "warning": "failed to restore Info API broker envFrom configuration",
                            "manual_action": "remove explicit CELERY_BROKER_URL from info-admin-backend and wait for rollout",
                        }
                    ),
                    file=sys.stderr,
                )
        if knowledge_worker_overridden:
            try:
                restore_worker(kubeconfig=kubeconfig, namespace=args.namespace)
            except subprocess.CalledProcessError:
                print(
                    json.dumps(
                        {
                            "warning": "failed to restore temporary Knowledge worker verifier overrides",
                            "manual_action": "remove RAGFLOW_API_KEY and ARTIFACT_S3_ALLOWED_BUCKETS deployment overrides",
                        }
                    ),
                    file=sys.stderr,
                )
        for job_name in temp_jobs:
            try:
                kubectl(
                    ["delete", "job", job_name, "-n", args.namespace, "--ignore-not-found=true"],
                    kubeconfig=kubeconfig,
                )
            except subprocess.CalledProcessError:
                pass
        for process in forwards:
            process.terminate()
        for process in forwards:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()


if __name__ == "__main__":
    raise SystemExit(main())
