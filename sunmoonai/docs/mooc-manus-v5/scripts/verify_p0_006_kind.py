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
import signal
import subprocess
import sys
import time
import uuid
from datetime import UTC, datetime, timedelta
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
            "lease_expires_at": row.lease_expires_at.isoformat() if row.lease_expires_at else None,
            "published_at": row.published_at.isoformat() if row.published_at else None,
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
    *,
    namespace: str,
    name: str,
    image: str,
    broken_broker: bool,
    ack_timeout_seconds: int | None = None,
) -> str:
    extra_env: list[tuple[str, str]] = []
    if broken_broker:
        # Deliberately non-routable test endpoint; no real credential is used.
        extra_env.append(("CELERY_BROKER_URL", "amqp://127.0.0.1:1/p0"))
    if ack_timeout_seconds is not None:
        extra_env.append(("DELIVERY_OUTBOX_ACK_TIMEOUT_SECONDS", str(ack_timeout_seconds)))
    env_override = ""
    if extra_env:
        env_override = "\n        env:\n" + "".join(
            f"        - name: {name}\n          value: {value}\n"
            for name, value in extra_env
        )
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
{env_override}"""


def create_scanner_job(
    *,
    kubeconfig: str,
    namespace: str,
    name: str,
    image: str,
    broken_broker: bool,
    ack_timeout_seconds: int | None = None,
) -> None:
    kubectl(
        ["apply", "-f", "-"],
        kubeconfig=kubeconfig,
        input_text=scanner_job_yaml(
            namespace=namespace,
            name=name,
            image=image,
            broken_broker=broken_broker,
            ack_timeout_seconds=ack_timeout_seconds,
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


def deployment_python_expect_exit(
    *,
    kubeconfig: str,
    namespace: str,
    deployment: str,
    program: str,
    program_args: list[str],
    expected_exit: int,
    label: str,
) -> None:
    """Run a bounded, credential-silent fault process inside an existing pod."""
    try:
        result = subprocess.run(
            [
                "kubectl",
                "--kubeconfig",
                kubeconfig,
                "exec",
                "-n",
                namespace,
                f"deploy/{deployment}",
                "--",
                ".venv/bin/python",
                "-c",
                program,
                *program_args,
            ],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=180,
        )
    except subprocess.TimeoutExpired as exc:
        raise VerificationError(f"{label} timed out") from exc
    if result.returncode != expected_exit:
        # Do not surface captured process output: it can contain infrastructure
        # details and is not needed to explain a deterministic verifier failure.
        raise VerificationError(
            f"{label} exited {result.returncode}, expected {expected_exit}"
        )


_PUBLISH_THEN_EXIT = r"""
import asyncio
import os
import sys
import uuid
from datetime import timedelta

os.environ["CELERY_QUEUE"] = sys.argv[2]

from sqlalchemy import select
from app.application.services.delivery_outbox import STATE_LEASED, STATE_PENDING, _now
from app.infrastructure.messaging.celery_producer import get_celery_producer
from app.infrastructure.models.info import DeliveryOutboxMessage
from app.infrastructure.storage.postgres import get_postgres
from core.config import get_settings

async def main():
    distribution_id = uuid.UUID(sys.argv[1])
    postgres = get_postgres()
    await postgres.init()
    async with postgres.session_factory() as session:
        result = await session.execute(
            select(DeliveryOutboxMessage)
            .where(DeliveryOutboxMessage.aggregate_id == distribution_id)
            .with_for_update()
        )
        row = result.scalar_one()
        now = _now()
        if row.state != STATE_PENDING or row.available_at > now:
            raise RuntimeError("fault message is not due and pending")
        row.state = STATE_LEASED
        row.lease_token = uuid.uuid4()
        row.lease_expires_at = now + timedelta(
            seconds=get_settings().delivery_outbox_lease_seconds
        )
        row.attempt_count += 1
        await session.commit()
        get_celery_producer().dispatch_distribution(
            distribution_id, outbox_message_id=row.id
        )
        # Intentionally skip mark_delivery_outbox_published.  The parent
        # verifier expects this process to disappear at this exact window.
        os._exit(86)

asyncio.run(main())
"""


_FORCE_PUBLISHED = r"""
import asyncio
import sys
import uuid

from sqlalchemy import select
from app.application.services.delivery_outbox import STATE_PENDING, STATE_PUBLISHED, _now
from app.infrastructure.models.info import DeliveryOutboxMessage
from app.infrastructure.storage.postgres import get_postgres

async def main():
    distribution_id = uuid.UUID(sys.argv[1])
    postgres = get_postgres()
    await postgres.init()
    async with postgres.session_factory() as session:
        result = await session.execute(
            select(DeliveryOutboxMessage)
            .where(DeliveryOutboxMessage.aggregate_id == distribution_id)
            .with_for_update()
        )
        row = result.scalar_one()
        now = _now()
        if row.state != STATE_PENDING or row.available_at > now:
            raise RuntimeError("provider fault message is not due and pending")
        row.state = STATE_PUBLISHED
        row.attempt_count += 1
        row.lease_token = None
        row.lease_expires_at = None
        row.broker_message_id = "p0-provider-effect-control"
        row.published_at = now
        row.last_error = None
        await session.commit()
    await postgres.shutdown()

asyncio.run(main())
"""


_WORKER_EFFECT_THEN_EXIT = r"""
import asyncio
import os
import sys
import uuid

from app.application.services.info_crawl_service import dispatch_distribution
from app.infrastructure.storage.postgres import get_postgres

async def main():
    postgres = get_postgres()
    await postgres.init()
    async with postgres.session_factory() as session:
        record = await dispatch_distribution(
            session, distribution_id=uuid.UUID(sys.argv[1])
        )
        if record.status != "succeeded":
            raise RuntimeError("provider effect did not reach succeeded state")
        # Simulate a worker process loss after the downstream side effect and
        # before task code can acknowledge the durable outbox operation.
        os._exit(87)

asyncio.run(main())
"""


_DELETE_FAULT_QUEUE = r"""
import os
import sys

os.environ["CELERY_QUEUE"] = sys.argv[1]

from app.worker import celery_app, configure_celery

configure_celery(require_broker=True)
with celery_app.connection_for_write() as connection:
    channel = connection.channel()
    try:
        channel.queue_delete(queue=sys.argv[1])
    finally:
        channel.close()
"""


def force_broker_accept_then_exit(
    *, kubeconfig: str, namespace: str, distribution_id: str, queue: str
) -> None:
    """Publish to a unique unconsumed queue, then exit before published is saved."""
    deployment_python_expect_exit(
        kubeconfig=kubeconfig,
        namespace=namespace,
        deployment="info-admin-backend",
        program=_PUBLISH_THEN_EXIT,
        program_args=[distribution_id, queue],
        expected_exit=86,
        label="broker accept-before-published fault process",
    )


def force_published_for_provider_fault(
    *, kubeconfig: str, namespace: str, distribution_id: str
) -> None:
    """Isolate the provider/acknowledgement window after broker semantics are tested."""
    deployment_python_expect_exit(
        kubeconfig=kubeconfig,
        namespace=namespace,
        deployment="info-admin-backend",
        program=_FORCE_PUBLISHED,
        program_args=[distribution_id],
        expected_exit=0,
        label="provider acknowledgement control setup",
    )


def force_provider_effect_then_exit(
    *, kubeconfig: str, namespace: str, distribution_id: str
) -> None:
    deployment_python_expect_exit(
        kubeconfig=kubeconfig,
        namespace=namespace,
        deployment="celeryworker-info-admin-backend",
        program=_WORKER_EFFECT_THEN_EXIT,
        program_args=[distribution_id],
        expected_exit=87,
        label="provider effect-before-outbox-ack fault process",
    )


def delete_fault_queue(*, kubeconfig: str, namespace: str, queue: str) -> None:
    deployment_python_expect_exit(
        kubeconfig=kubeconfig,
        namespace=namespace,
        deployment="info-admin-backend",
        program=_DELETE_FAULT_QUEUE,
        program_args=[queue],
        expected_exit=0,
        label="temporary broker queue cleanup",
    )


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


def running_candidate_image_ids(*, kubeconfig: str, namespace: str) -> dict[str, str]:
    """Capture the pulled digests that back the two candidate Deployments."""
    values: dict[str, str] = {}
    for app_name in ("info-admin-backend", "celeryworker-info-admin-backend"):
        raw = kubectl(
            ["get", "pods", "-n", namespace, "-l", f"app={app_name}", "-o", "json"],
            kubeconfig=kubeconfig,
            capture=True,
        )
        items = json.loads(raw).get("items", [])
        ready = [
            item
            for item in items
            if item.get("status", {}).get("phase") == "Running"
            and item.get("status", {}).get("containerStatuses")
            and item["status"]["containerStatuses"][0].get("ready") is True
        ]
        if len(ready) != 1:
            raise VerificationError(
                f"expected one ready {app_name} candidate pod, got {len(ready)}"
            )
        image_id = ready[0]["status"]["containerStatuses"][0].get("imageID")
        if not image_id or "@sha256:" not in image_id:
            raise VerificationError(f"{app_name} does not expose a pulled image digest")
        values[app_name] = image_id
    return values


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
    changed = False
    try:
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
        changed = broken
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
    except subprocess.CalledProcessError as exc:
        # `kubectl set env` succeeds before the rollout can fail.  Keep this
        # rollback inside the helper: callers cannot safely set their cleanup
        # flag until this function returns, which previously left a broken
        # broker URL behind on a rollout error.
        if changed:
            try:
                kubectl(
                    [
                        "set",
                        "env",
                        "deployment/info-admin-backend",
                        "-n",
                        namespace,
                        "CELERY_BROKER_URL-",
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
            except subprocess.CalledProcessError as rollback_exc:
                raise VerificationError(
                    "Info API broker fault setup failed and automatic rollback failed; "
                    "remove explicit CELERY_BROKER_URL before retrying"
                ) from rollback_exc
        raise exc


def wait_until_timestamp(
    value: str | None, *, description: str, after_seconds: int = 0
) -> None:
    if not value:
        raise VerificationError(f"{description} did not contain a timestamp")
    due_at = datetime.fromisoformat(str(value).replace("Z", "+00:00")) + timedelta(
        seconds=after_seconds
    )
    remaining = (due_at - datetime.now(UTC)).total_seconds()
    if remaining > 0:
        time.sleep(remaining + 1)


def wait_until_outbox_due(row: dict[str, Any]) -> None:
    """Wait for the configured retry deadline instead of assuming five seconds."""
    wait_until_timestamp(
        row.get("available_at"), description="recovered outbox row available_at"
    )


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
    parser.add_argument(
        "--image",
        required=True,
        help="unique P0 candidate image tag; pulled image IDs are captured in the result",
    )
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
    fault_queue = f"p0-006-publish-window-{suffix}"
    fault_queue_created = False
    summary: dict[str, Any] = {"task": "V5-P0-006", "result": "failed"}
    previous_signal_handlers = {
        sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)
    }

    def request_cleanup(signum: int, _frame: Any) -> None:
        raise VerificationError(
            f"received signal {signum}; restoring temporary verifier state"
        )

    for sig in previous_signal_handlers:
        signal.signal(sig, request_cleanup)
    try:
        assert_candidate_images(
            kubeconfig=kubeconfig, namespace=args.namespace, image=args.image
        )
        candidate_image_ids = running_candidate_image_ids(
            kubeconfig=kubeconfig, namespace=args.namespace
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
        for sig, handler in previous_signal_handlers.items():
            signal.signal(sig, handler)
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

        # Broker accepted / published-write interruption.  The API first
        # creates a real durable request while its wake-up is blocked.  A
        # bounded process then publishes to a unique queue and exits before it
        # can record `published`; no normal worker consumes that unique queue.
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
            "Info port-forward for broker accepted fault",
            lambda: api_json(info_url, "/api/documents", query={"limit": 1}),
            lambda _: True,
            timeout=30,
        )
        publish_window_distribution = create_real_distribution(
            info_url, f"p0-outbox-published-window-{suffix}"
        )
        publish_window_id = publish_window_distribution["id"]
        publish_window_pending = wait_for_outbox(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=publish_window_id,
            done=lambda row: row is not None
            and row["state"] == "pending"
            and row["attempt_count"] >= 1
            and row["has_last_error"],
            description="broker-window durable pending work",
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
            "Info port-forward before broker accepted fault process",
            lambda: api_json(info_url, "/api/documents", query={"limit": 1}),
            lambda _: True,
            timeout=30,
        )
        wait_until_outbox_due(publish_window_pending)
        fault_queue_created = True
        force_broker_accept_then_exit(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=publish_window_id,
            queue=fault_queue,
        )
        publish_window_leased = wait_for_outbox(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=publish_window_id,
            done=lambda row: row is not None
            and row["state"] == "leased"
            and row["attempt_count"] >= 2,
            description="broker accepted before published write",
        )
        wait_until_timestamp(
            publish_window_leased.get("lease_expires_at"),
            description="broker accepted lease expiry",
        )
        publish_recovery_job = f"p0-006-publish-recovery-{suffix}"
        temp_jobs.append(publish_recovery_job)
        create_scanner_job(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            name=publish_recovery_job,
            image=args.image,
            broken_broker=False,
        )
        publish_recovery_summary = scanner_job_summary(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            name=publish_recovery_job,
        )
        if publish_recovery_summary["claimed"] != 1:
            raise VerificationError("expired broker-window lease was not recovered once")
        publish_window_done = wait_for_distribution(info_url, publish_window_id)
        if publish_window_done.get("status") != "succeeded":
            raise VerificationError("broker-window distribution did not succeed")
        publish_window_outbox = wait_for_outbox(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=publish_window_id,
            done=lambda row: row is not None
            and row["state"] == "completed"
            and row["attempt_count"] >= 3,
            description="broker-window outbox completion",
        )
        publish_window_ingestion = assert_one_ingestion(
            knowledge_url, contract_payload(publish_window_done)["idempotency_key"]
        )
        if publish_window_ingestion.get("status") not in {"artifact_verified", "succeeded"}:
            raise VerificationError("Knowledge did not finish broker-window recovery")
        delete_fault_queue(
            kubeconfig=kubeconfig, namespace=args.namespace, queue=fault_queue
        )
        fault_queue_created = False

        # Provider side effect / acknowledgement interruption.  This uses a
        # real worker credential path to make Knowledge succeed, exits before
        # `complete_delivery_outbox`, then lets a scanner recover `published`
        # with a short test-only acknowledgement threshold.
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
            "Info port-forward for provider acknowledgement fault",
            lambda: api_json(info_url, "/api/documents", query={"limit": 1}),
            lambda _: True,
            timeout=30,
        )
        provider_distribution = create_real_distribution(
            info_url, f"p0-outbox-provider-window-{suffix}"
        )
        provider_id = provider_distribution["id"]
        provider_pending = wait_for_outbox(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=provider_id,
            done=lambda row: row is not None
            and row["state"] == "pending"
            and row["attempt_count"] >= 1
            and row["has_last_error"],
            description="provider-window durable pending work",
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
            "Info port-forward before provider acknowledgement fault process",
            lambda: api_json(info_url, "/api/documents", query={"limit": 1}),
            lambda _: True,
            timeout=30,
        )
        wait_until_outbox_due(provider_pending)
        force_published_for_provider_fault(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=provider_id,
        )
        provider_published = wait_for_outbox(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=provider_id,
            done=lambda row: row is not None
            and row["state"] == "published"
            and row["attempt_count"] >= 2,
            description="provider effect published control",
        )
        force_provider_effect_then_exit(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=provider_id,
        )
        provider_done = wait_for_distribution(info_url, provider_id)
        if provider_done.get("status") != "succeeded":
            raise VerificationError("provider effect did not leave a succeeded distribution")
        wait_until_timestamp(
            provider_published.get("published_at"),
            description="provider acknowledgement timeout",
            after_seconds=5,
        )
        provider_recovery_job = f"p0-006-provider-recovery-{suffix}"
        temp_jobs.append(provider_recovery_job)
        create_scanner_job(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            name=provider_recovery_job,
            image=args.image,
            broken_broker=False,
            ack_timeout_seconds=5,
        )
        provider_recovery_summary = scanner_job_summary(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            name=provider_recovery_job,
        )
        if provider_recovery_summary["claimed"] != 1:
            raise VerificationError("expired provider acknowledgement was not recovered once")
        provider_outbox = wait_for_outbox(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            distribution_id=provider_id,
            done=lambda row: row is not None and row["state"] == "completed",
            description="provider acknowledgement outbox completion",
        )
        provider_ingestion = assert_one_ingestion(
            knowledge_url, contract_payload(provider_done)["idempotency_key"]
        )
        if provider_ingestion.get("status") not in {"artifact_verified", "succeeded"}:
            raise VerificationError("Knowledge did not finish provider acknowledgement recovery")

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
            "candidate_image_ids": candidate_image_ids,
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
            "broker_accept_before_published": {
                "distribution_id": publish_window_id,
                "outbox_id": publish_window_outbox["id"],
                "recovery_claimed": publish_recovery_summary["claimed"],
                "final_state": publish_window_outbox["state"],
                "business_effects": 1,
            },
            "provider_effect_before_ack": {
                "distribution_id": provider_id,
                "outbox_id": provider_outbox["id"],
                "recovery_claimed": provider_recovery_summary["claimed"],
                "final_state": provider_outbox["state"],
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
        if fault_queue_created:
            try:
                delete_fault_queue(
                    kubeconfig=kubeconfig, namespace=args.namespace, queue=fault_queue
                )
            except VerificationError:
                print(
                    json.dumps(
                        {
                            "warning": "failed to delete temporary P0 broker queue",
                            "manual_action": "delete only the unique p0-006-publish-window queue created by this verifier",
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
