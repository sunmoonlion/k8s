#!/usr/bin/env python3
"""Run the Architecture v2 Info -> Knowledge -> Investment real vertical.

Every database read is executed inside the owning App's formal pod.  The host
process receives only explicit safe markers: stable domain IDs, state/counts
and boolean proofs.  Artifact bodies, credentials, tokens and provider IDs are
never emitted.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any, Callable


class GateError(RuntimeError):
    pass


def kubectl(
    args: list[str], *, kubeconfig: str, capture: bool = False
) -> str:
    result = subprocess.run(
        ["kubectl", "--kubeconfig", kubeconfig, *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        timeout=240,
    )
    if result.returncode != 0:
        raise GateError(f"kubectl command failed with exit {result.returncode}")
    return result.stdout if capture else ""


def pod_marker(
    *,
    kubeconfig: str,
    namespace: str,
    deployment: str,
    program: str,
    args: list[str],
    marker: str,
    label: str,
) -> Any:
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
            *args,
        ],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=240,
    )
    if result.returncode != 0:
        safe = next(
            (
                line.removeprefix("R6_SAFE_FAILURE=")
                for line in result.stdout.splitlines()
                if line.startswith("R6_SAFE_FAILURE=")
            ),
            None,
        )
        suffix = f" safe={safe}" if safe else ""
        raise GateError(f"{label} failed with exit {result.returncode}.{suffix}")
    prefix = f"{marker}="
    for line in result.stdout.splitlines():
        if line.startswith(prefix):
            return json.loads(line.removeprefix(prefix))
    raise GateError(f"{label} did not emit {marker}")


def wait_for(
    label: str,
    reader: Callable[[], Any],
    predicate: Callable[[Any], bool],
    *,
    timeout: float,
) -> Any:
    deadline = time.monotonic() + timeout
    last: Any = None
    while time.monotonic() < deadline:
        try:
            last = reader()
            if predicate(last):
                return last
        except GateError:
            pass
        time.sleep(2)
    raise GateError(f"timed out waiting for {label}; last={last!r}")


def assert_ready(*, kubeconfig: str, namespace: str) -> dict[str, int]:
    expected = {
        "info-backend-api": 2,
        "info-backend-worker": 1,
        "info-backend-scheduler": 1,
        "knowledge-backend-api": 2,
        "knowledge-backend-worker": 1,
        "knowledge-backend-scheduler": 1,
        "investment-backend-api": 2,
        "investment-backend-worker": 1,
        "investment-backend-scheduler": 1,
        "ragflow-sunmoonai": 1,
    }
    raw = kubectl(
        ["get", "deployment", *expected, "-n", namespace, "-o", "json"],
        kubeconfig=kubeconfig,
        capture=True,
    )
    items = {item["metadata"]["name"]: item for item in json.loads(raw)["items"]}
    for name, replicas in expected.items():
        item = items.get(name)
        if item is None:
            raise GateError(f"missing formal Deployment/{name}")
        status = item.get("status", {})
        if item["spec"].get("replicas") != replicas or status.get("readyReplicas", 0) != replicas:
            raise GateError(f"Deployment/{name} is not ready at {replicas} replicas")
        image = item["spec"]["template"]["spec"]["containers"][0]["image"]
        if name != "ragflow-sunmoonai" and "@sha256:" not in image:
            raise GateError(f"Deployment/{name} is not digest pinned")

    info_config = json.loads(
        kubectl(
            ["get", "configmap/info-backend-config", "-n", namespace, "-o", "json"],
            kubeconfig=kubeconfig,
            capture=True,
        )
    )
    expected_url = (
        "http://knowledge-backend:8000/"
        "api/internal/v1/knowledge/ingestions"
    )
    if info_config.get("data", {}).get("KNOWLEDGE_APP_INGEST_URL") != expected_url:
        raise GateError("Info formal ingest URL does not target Knowledge R5")
    return expected


CREATE_INFO = r'''
import asyncio
import json
import sys

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from app.application.services.delivery_outbox import (
    TOPIC_DISTRIBUTION_DISPATCH_V1,
    dispatch_due_delivery_outbox,
)
from app.application.services.info_crawl_service import (
    create_knowledge_distribution,
    ingest_uploaded_file,
)
from app.infrastructure.messaging.celery_producer import get_celery_producer
from app.infrastructure.models.info import DeliveryOutboxMessage, InfoDocument
from app.infrastructure.storage.postgres import get_postgres
from core.config import get_settings


async def main():
    marker, dataset, filename, title = sys.argv[1:5]
    expected_url = "http://knowledge-backend:8000/api/internal/v1/knowledge/ingestions"
    settings = get_settings()
    if settings.knowledge_app_ingest_url != expected_url:
        raise RuntimeError("formal-ingest-url")
    content = (
        f"# {title}\n\n"
        f"Architecture v2 governed cross application evidence marker {marker}. "
        "This document validates reliable information delivery, knowledge indexing, "
        "investment retrieval, stable lineage and citation provenance.\n"
    ).encode()
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            active = int((await session.scalar(
                select(func.count(DeliveryOutboxMessage.id)).where(
                    DeliveryOutboxMessage.topic == TOPIC_DISTRIBUTION_DISPATCH_V1,
                    DeliveryOutboxMessage.state != "completed",
                )
            )) or 0)
            if active:
                raise RuntimeError("active-outbox-precondition")
            version = await ingest_uploaded_file(
                session,
                filename=filename,
                content=content,
                content_type="text/markdown",
                title=title,
            )
            document = await session.get(InfoDocument, version.document_id)
            if document is None:
                raise RuntimeError("info-document-missing")
            document_id = str(document.id)
            version_id = str(version.id)
            content_hash = version.content_hash
            distribution = await create_knowledge_distribution(
                session,
                document_version_id=version.id,
                target_dataset=dataset,
                dispatch=True,
            )
            distribution_id = str(distribution.id)
            idempotency_key = distribution.payload["idempotency_key"]
            artifact_versioned = bool(
                distribution.payload["artifact"]["storage_version"]
            )
            artifact_hash_bound = (
                distribution.payload["artifact"]["sha256"] == content_hash
            )
            producer = get_celery_producer()
            if not producer.enabled:
                raise RuntimeError("outbox-publisher-disabled")
            summary = await dispatch_due_delivery_outbox(session, publisher=producer)
            if summary.published != 1 or summary.broker_failures:
                raise RuntimeError("outbox-initial-publish")
            print("R6_INFO_CREATED=" + json.dumps({
                "document_id": document_id,
                "document_version_id": version_id,
                "distribution_id": distribution_id,
                "content_hash": content_hash,
                "idempotency_key": idempotency_key,
                "dataset_key": dataset,
                "artifact_versioned": artifact_versioned,
                "artifact_hash_bound": artifact_hash_bound,
                "outbox_published": summary.published,
                "content_printed": False,
            }, sort_keys=True))
    finally:
        await postgres.shutdown()


try:
    asyncio.run(main())
except Exception as exc:
    if isinstance(exc, RuntimeError):
        stage = str(exc)
    elif isinstance(exc, IntegrityError):
        original = getattr(exc, "orig", None)
        diagnostic = getattr(original, "diag", None)
        constraint = (
            getattr(diagnostic, "constraint_name", None)
            or getattr(original, "constraint_name", None)
            or getattr(getattr(original, "__cause__", None), "constraint_name", None)
        )
        sqlstate = (
            getattr(original, "sqlstate", None)
            or getattr(original, "pgcode", None)
            or getattr(getattr(original, "__cause__", None), "sqlstate", None)
        )
        source = getattr(original, "__cause__", None) or original
        table = getattr(source, "table_name", None)
        column = getattr(source, "column_name", None)
        stage = (
            f"IntegrityError:{constraint or 'unknown-constraint'}:"
            f"{sqlstate or 'unknown-sqlstate'}:"
            f"{table or 'unknown-table'}:{column or 'unknown-column'}"
        )
    else:
        stage = type(exc).__name__
    print("R6_SAFE_FAILURE=" + json.dumps({"stage": stage}))
    raise SystemExit(1) from None
'''


READ_INFO = r'''
import asyncio
import json
import sys
import uuid

from sqlalchemy import select

from app.infrastructure.models.info import DeliveryOutboxMessage, DistributionRecord
from app.infrastructure.storage.postgres import get_postgres


async def main():
    distribution_id = uuid.UUID(sys.argv[1])
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            distribution = await session.get(DistributionRecord, distribution_id)
            rows = list((await session.execute(
                select(DeliveryOutboxMessage).where(
                    DeliveryOutboxMessage.aggregate_id == distribution_id
                )
            )).scalars())
            if distribution is None or len(rows) != 1:
                raise RuntimeError("info-state-cardinality")
            outbox = rows[0]
            print("R6_INFO_STATE=" + json.dumps({
                "distribution_status": distribution.status,
                "outbox_state": outbox.state,
                "outbox_count": len(rows),
                "outbox_attempt_count": outbox.attempt_count,
                "broker_message_bound": bool(outbox.broker_message_id),
                "has_error": bool(distribution.last_error or outbox.last_error),
            }, sort_keys=True))
    finally:
        await postgres.shutdown()


try:
    asyncio.run(main())
except Exception as exc:
    print("R6_SAFE_FAILURE=" + json.dumps({"stage": str(exc) if type(exc) is RuntimeError else type(exc).__name__}))
    raise SystemExit(1) from None
'''


READ_KNOWLEDGE = r'''
import asyncio
import json
import sys
import uuid

from sqlalchemy import func, select

from app.infrastructure.models.knowledge import (
    KnowledgeDocumentVersion,
    KnowledgeIngestionJob,
)
from app.infrastructure.storage.postgres import get_postgres


async def main():
    key, source_version, expected_hash = sys.argv[1:4]
    source_version_id = uuid.UUID(source_version)
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            jobs = list((await session.execute(
                select(KnowledgeIngestionJob).where(
                    KnowledgeIngestionJob.idempotency_key == key
                )
            )).scalars())
            versions = list((await session.execute(
                select(KnowledgeDocumentVersion).where(
                    KnowledgeDocumentVersion.source_document_version_id == source_version_id,
                    KnowledgeDocumentVersion.dataset_key == "codex-smoke",
                )
            )).scalars())
            job = jobs[0] if len(jobs) == 1 else None
            version = versions[0] if len(versions) == 1 else None
            print("R6_KNOWLEDGE_STATE=" + json.dumps({
                "ingestion_count": len(jobs),
                "ingestion_status": job.status if job else None,
                "knowledge_document_id": str(version.knowledge_document_id) if version else None,
                "knowledge_document_version_id": str(version.id) if version else None,
                "version_count": len(versions),
                "version_status": version.status if version else None,
                "content_hash_matches": bool(version and version.content_hash == expected_hash),
                "source_version_matches": bool(version and version.source_document_version_id == source_version_id),
                "provider_binding_count": int((await session.scalar(
                    select(func.count(func.distinct(KnowledgeDocumentVersion.provider_document_id))).where(
                        KnowledgeDocumentVersion.source_document_version_id == source_version_id,
                        KnowledgeDocumentVersion.dataset_key == "codex-smoke",
                    )
                )) or 0),
                "provider_ids_printed": False,
                "content_printed": False,
            }, sort_keys=True))
    finally:
        await postgres.shutdown()


try:
    asyncio.run(main())
except Exception as exc:
    print("R6_SAFE_FAILURE=" + json.dumps({"stage": str(exc) if type(exc) is RuntimeError else type(exc).__name__}))
    raise SystemExit(1) from None
'''


INVESTMENT_RETRIEVE = r'''
import asyncio
import json
import sys
import uuid

from app.domain.agent.knowledge import (
    Citation,
    KnowledgeFilters,
    KnowledgeQuery,
    RetrievalSecurityContext,
)
from app.infrastructure.external.knowledge_retrieval import get_knowledge_retrieval_client


async def main():
    marker, dataset, source_document, source_version, expected_hash = sys.argv[1:6]
    source_document_id = uuid.UUID(source_document)
    source_version_id = uuid.UUID(source_version)
    client = get_knowledge_retrieval_client()
    response = await client.retrieve(KnowledgeQuery(
        request_id=uuid.uuid4(),
        query=marker,
        dataset_keys=[dataset],
        filters=KnowledgeFilters(source_document_version_ids=[source_version_id]),
        top_k=5,
        token_budget=4000,
        security_context=RetrievalSecurityContext(
            tenant_id="sunmoonai",
            actor_id=uuid.uuid4(),
            actor_type="service",
            policy_version="architecture-v2-r6",
        ),
    ))
    matches = [
        item for item in response.evidence
        if item.source_document_id == source_document_id
        and item.source_document_version_id == source_version_id
        and item.content_hash == expected_hash
    ]
    if not matches:
        raise RuntimeError("governed-evidence-missing")
    evidence = matches[0]
    citation = Citation.from_evidence(evidence)
    payload = citation.model_dump(mode="json")
    forbidden = {
        key for key in payload
        if key in {"source_uri", "provider", "provider_metadata"}
        or key.startswith(("provider_", "ragflow_"))
    }
    if forbidden:
        raise RuntimeError("citation-provider-leak")
    print("R6_INVESTMENT_RESULT=" + json.dumps({
        "evidence_count": len(response.evidence),
        "evidence_id": str(evidence.evidence_id),
        "knowledge_document_id": str(evidence.knowledge_document_id),
        "knowledge_document_version_id": str(evidence.knowledge_document_version_id),
        "source_document_id": str(evidence.source_document_id),
        "source_document_version_id": str(evidence.source_document_version_id),
        "content_hash_matches": evidence.content_hash == expected_hash,
        "citation_source_href": citation.source_href,
        "citation_provider_fields_absent": True,
        "content_printed": False,
        "provider_ids_printed": False,
        "token_printed": False,
    }, sort_keys=True))


try:
    asyncio.run(main())
except Exception as exc:
    print("R6_SAFE_FAILURE=" + json.dumps({"stage": str(exc) if type(exc) is RuntimeError else type(exc).__name__}))
    raise SystemExit(1) from None
'''


REPLAY_INFO = r'''
import asyncio
import json
import sys
import uuid

from app.application.services.delivery_outbox import (
    dispatch_due_delivery_outbox,
    ensure_distribution_dispatch_outbox,
)
from app.infrastructure.messaging.celery_producer import get_celery_producer
from app.infrastructure.models.info import DistributionRecord
from app.infrastructure.storage.postgres import get_postgres


async def main():
    distribution_id = uuid.UUID(sys.argv[1])
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            record = await session.get(DistributionRecord, distribution_id)
            if record is None or record.status != "succeeded":
                raise RuntimeError("replay-precondition")
            record.status = "pending"
            record.last_error = None
            await ensure_distribution_dispatch_outbox(
                session, distribution_id=distribution_id
            )
            await session.commit()
            producer = get_celery_producer()
            summary = await dispatch_due_delivery_outbox(session, publisher=producer)
            if summary.published != 1 or summary.broker_failures:
                raise RuntimeError("replay-publish")
            print("R6_REPLAY=" + json.dumps({
                "same_distribution": True,
                "published": summary.published,
                "broker_failures": summary.broker_failures,
            }, sort_keys=True))
    finally:
        await postgres.shutdown()


try:
    asyncio.run(main())
except Exception as exc:
    print("R6_SAFE_FAILURE=" + json.dumps({"stage": str(exc) if type(exc) is RuntimeError else type(exc).__name__}))
    raise SystemExit(1) from None
'''


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kubeconfig", required=True)
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    kubeconfig = str(Path(args.kubeconfig).expanduser())
    operation = uuid.uuid4()
    short = operation.hex[:12]
    marker = f"r6vertical-{short}"
    dataset = "codex-smoke"
    filename = f"{marker}.md"
    title = f"Architecture v2 R6 vertical {short}"
    result: dict[str, Any] = {
        "task": "architecture-v2-r6-cross-app-vertical",
        "result": "failed",
    }
    try:
        topology = assert_ready(
            kubeconfig=kubeconfig, namespace=args.namespace
        )
        created = pod_marker(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            deployment="info-backend-api",
            program=CREATE_INFO,
            args=[marker, dataset, filename, title],
            marker="R6_INFO_CREATED",
            label="Info fact/outbox creation",
        )
        if not created["artifact_versioned"] or not created["artifact_hash_bound"]:
            raise GateError("Info artifact is not immutable and hash bound")

        def info_state() -> dict[str, Any]:
            return pod_marker(
                kubeconfig=kubeconfig,
                namespace=args.namespace,
                deployment="info-backend-api",
                program=READ_INFO,
                args=[created["distribution_id"]],
                marker="R6_INFO_STATE",
                label="Info delivery state",
            )

        first_delivery = wait_for(
            "first Info delivery",
            info_state,
            lambda value: value["distribution_status"] == "succeeded"
            and value["outbox_state"] == "completed",
            timeout=180,
        )

        def knowledge_state() -> dict[str, Any]:
            return pod_marker(
                kubeconfig=kubeconfig,
                namespace=args.namespace,
                deployment="knowledge-backend-api",
                program=READ_KNOWLEDGE,
                args=[
                    created["idempotency_key"],
                    created["document_version_id"],
                    created["content_hash"],
                ],
                marker="R6_KNOWLEDGE_STATE",
                label="Knowledge ingestion/index state",
            )

        first_knowledge = wait_for(
            "Knowledge real RAGFlow indexing",
            knowledge_state,
            lambda value: value["ingestion_count"] == 1
            and value["ingestion_status"] == "succeeded"
            and value["version_count"] == 1
            and value["version_status"] == "indexed"
            and value["content_hash_matches"]
            and value["source_version_matches"]
            and value["provider_binding_count"] == 1,
            timeout=240,
        )

        investment = pod_marker(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            deployment="investment-backend-worker",
            program=INVESTMENT_RETRIEVE,
            args=[
                marker,
                dataset,
                created["document_id"],
                created["document_version_id"],
                created["content_hash"],
            ],
            marker="R6_INVESTMENT_RESULT",
            label="Investment governed retrieval/citation",
        )

        replay = pod_marker(
            kubeconfig=kubeconfig,
            namespace=args.namespace,
            deployment="info-backend-api",
            program=REPLAY_INFO,
            args=[created["distribution_id"]],
            marker="R6_REPLAY",
            label="Info at-least-once replay",
        )
        replay_delivery = wait_for(
            "replayed Info delivery",
            info_state,
            lambda value: value["distribution_status"] == "succeeded"
            and value["outbox_state"] == "completed"
            and value["outbox_attempt_count"] >= 2,
            timeout=180,
        )
        replay_knowledge = knowledge_state()
        if not (
            replay_knowledge["ingestion_count"] == 1
            and replay_knowledge["version_count"] == 1
            and replay_knowledge["provider_binding_count"] == 1
            and replay_knowledge["ingestion_status"] == "succeeded"
        ):
            raise GateError("Knowledge idempotency failed after replay")

        result = {
            "task": "architecture-v2-r6-cross-app-vertical",
            "result": "passed",
            "topology_ready": topology,
            "info": created | {"first_delivery": first_delivery},
            "knowledge": first_knowledge,
            "investment": investment,
            "replay": replay
            | {
                "delivery": replay_delivery,
                "knowledge_ingestion_count": replay_knowledge["ingestion_count"],
                "knowledge_version_count": replay_knowledge["version_count"],
                "provider_binding_count": replay_knowledge["provider_binding_count"],
            },
            "database_cross_read_used": False,
            "mock_provider_used": False,
            "credentials_printed": False,
            "token_printed": False,
            "artifact_content_printed": False,
            "provider_ids_printed": False,
        }
        rendered = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(rendered, encoding="utf-8")
        print(rendered, end="")
        return 0
    except (GateError, subprocess.SubprocessError) as exc:
        result["error"] = str(exc)
        print(json.dumps(result, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
