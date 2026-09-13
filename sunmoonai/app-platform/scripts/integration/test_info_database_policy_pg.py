"""Explicit disposable-PG gate for Info, in a separate process from other Apps.

Only external HTTP/object storage/search/provider transports are synthetic.
Application services, migrations, SQL, delivery handlers and four logins are real.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import sys
from pathlib import Path

import asyncpg
import httpx
import pytest
import pytest_asyncio

WORKSPACE = Path(__file__).resolve().parents[5]
BACKEND = WORKSPACE / "info-app/info-backend/app"
TEMPLATE = WORKSPACE / "tpl-app/k8s-deployment"
sys.path[:0] = [
    str(BACKEND),
    str(TEMPLATE),
    str(TEMPLATE / "integration"),
    str(Path(__file__).resolve().parents[2] / "info-app/deployment"),
]
import info_database_policy as policy
from app.application.collectors.base import CollectedLink
from app.application.services import info_crawl_service as service
from app.application.services.durable_tasks import DurableTasks
from app.infrastructure.messaging.delivery_handlers import get_delivery_handlers
from app.infrastructure.storage.object_storage import StoredObject
from app.infrastructure.storage.schema_readiness import verify_schema_revision
from permission_pg_support import denied, execute, inventory, provision_database


@pytest_asyncio.fixture
async def database():
    async with provision_database(
        BACKEND, policy.info_grants, scope="b7p", uuid_extension=True
    ) as instance:
        yield instance


class MemoryStorage:
    def put_bytes(self, *, object_key, data, content_type, **kwargs):
        return StoredObject(
            "test-bucket",
            object_key,
            "immutable-version",
            hashlib.sha256(data).hexdigest(),
            len(data),
            content_type,
        )

    def put_json(self, *, object_key, payload):
        return self.put_bytes(
            object_key=object_key,
            data=json.dumps(payload).encode(),
            content_type="application/json",
        )


async def upload(
    database, monkeypatch, *, filename="test.md", content=b"# Title\n\nReliable content"
):
    monkeypatch.setattr(service, "get_object_storage", MemoryStorage)
    async with database.sessions["api"]() as session:
        return await service.ingest_uploaded_file(
            session,
            filename=filename,
            content=content,
            content_type="application/octet-stream"
            if filename.endswith(".bin")
            else "text/markdown",
        )


def runtime(database):
    return DurableTasks(database.sessions["worker"], handlers=get_delivery_handlers())


async def test_real_logins_owner_revision_and_readiness(database):
    assert len(set(database.passwords.values())) == 4
    for password in database.passwords.values():
        assert password not in repr(database)
    for role, name in database.names.items():
        assert await execute(database, role, "SELECT current_user") == name
        assert await execute(database, role, "SELECT session_user") == name
        assert (
            await execute(
                database,
                role,
                "SELECT rolsuper FROM pg_roles WHERE rolname=current_user",
            )
            is False
        )
        if role in ("api", "worker"):
            async with database.sessions[role]() as session:
                await verify_schema_revision(session)
    assert (
        await execute(
            database, "migration", "SELECT version_num FROM public.alembic_version"
        )
        == "20260913_0009"
    )
    assert (
        await execute(
            database,
            "migration",
            "SELECT bool_and(tableowner=current_user) FROM pg_tables WHERE schemaname='public'",
        )
        is True
    )


async def test_source_collector_discovery_and_crawl_request(database, monkeypatch):
    class Adapter:
        async def discover(self, **kwargs):
            return [CollectedLink("https://example.test/article", title="Article")]

    monkeypatch.setattr(service, "get_collector_adapter", lambda kind: Adapter())
    async with database.sessions["api"]() as session:
        source = await service.create_source(
            session,
            code="source",
            name="Source",
            source_type="website",
            base_url="https://example.test",
        )
        collector = await service.create_collector(
            session,
            code="collector",
            name="Collector",
            collector_type="http",
            source_id=source.id,
            config={"url": "https://example.test"},
        )
        assert len(await service.list_sources(session)) == 1
        assert len(await service.list_collectors(session)) == 1
        jobs = await service.run_collector_discovery(session, collector_id=collector.id)
        assert len(jobs) == 1
        await service.request_crawl_job(session, jobs[0].id)
        await service.request_crawl_job(session, jobs[0].id)
    assert await execute(database, "api", "SELECT count(*) FROM outbox_message") == 1


@pytest.mark.parametrize("filename", ["test.md", "test.bin"])
async def test_upload_versions_review_and_metadata(database, monkeypatch, filename):
    first = await upload(database, monkeypatch, filename=filename)
    second = await upload(
        database, monkeypatch, filename=filename, content=b"new content"
    )
    assert first.document_id == second.document_id
    assert (first.version_no, second.version_no) == (1, 2)
    async with database.sessions["api"]() as session:
        document = await service.review_document(
            session,
            document_id=first.document_id,
            status="reviewed",
            reviewer="test",
            reason="synthetic",
        )
        await service.update_document_summary_profile(
            session,
            document_id=document.id,
            summary="summary",
            tags=["test"],
            importance_score=0.5,
            importance_reason="test",
            reviewer="test",
            reason=None,
        )
        await service.update_document_entity_links(
            session,
            document_id=document.id,
            companies=["synthetic"],
            securities=[],
            industries=[],
            topics=[],
            reviewer="test",
            reason=None,
        )
        reviewed = await service.review_document_version(
            session,
            document_id=document.id,
            version_id=second.id,
            extraction_status="reviewed",
            reviewer="test",
            reason=None,
        )
        assert reviewed.extraction_status == "reviewed"
        assert len(await service.list_document_versions(session, document.id)) == 2
    assert (
        await execute(
            database,
            "api",
            "SELECT count(*) FROM outbox_message WHERE topic='info.index.v1'",
        )
        == 2
    )
    expected = 4 if filename.endswith(".md") else 0
    assert (
        await execute(database, "api", "SELECT count(*) FROM extracted_content")
        == expected
    )


@pytest.mark.parametrize("operation", ["upload", "crawl"])
async def test_api_intent_failure_rolls_back_domain_writes(
    database, monkeypatch, operation
):
    async def fail(*args, **kwargs):
        raise RuntimeError("synthetic enqueue failure")

    monkeypatch.setattr(service, "enqueue_task", fail)
    with pytest.raises(RuntimeError, match="synthetic enqueue failure"):
        if operation == "upload":
            await upload(database, monkeypatch)
        else:
            async with database.sessions["api"]() as session:
                await service.create_crawl_job(
                    session,
                    target_url="https://example.test",
                    source_id=None,
                    enqueue=True,
                )
    for table in (
        "crawl_job",
        "info_document",
        "info_document_version",
        "raw_artifact",
        "extracted_content",
        "outbox_message",
    ):
        assert await execute(database, "api", f'SELECT count(*) FROM "{table}"') == 0


@pytest.mark.parametrize("outcome", ["success", "http_failure", "extraction_failure"])
async def test_worker_real_crawl_domain_writes_and_followup(
    database, monkeypatch, outcome
):
    calls = []

    async def fetch(url, **kwargs):
        calls.append(url)
        return httpx.Response(
            503 if outcome == "http_failure" else 200,
            content=b"<html><title>Title</title><body><p>Reliable article content.</p></body></html>",
            headers={"content-type": "text/html"},
            request=httpx.Request("GET", url),
        )

    monkeypatch.setattr(service, "fetch_crawl_url", fetch)
    monkeypatch.setattr(service, "get_object_storage", MemoryStorage)
    if outcome == "extraction_failure":

        def extraction_fail(*args):
            raise ValueError("synthetic extraction failure")

        monkeypatch.setattr(service, "_extract_html", extraction_fail)
    async with database.sessions["api"]() as session:
        job = await service.create_crawl_job(
            session,
            target_url="https://example.test/article",
            source_id=None,
            enqueue=True,
        )
    message = await execute(
        database, "api", "SELECT id FROM outbox_message WHERE topic='info.crawl.v1'"
    )
    assert await runtime(database).consume(message)
    assert await runtime(database).consume(message) is False
    assert len(calls) == 1
    assert await execute(database, "api", "SELECT status FROM crawl_job") == (
        "succeeded" if outcome == "success" else "failed"
    )
    expected = 0 if outcome == "http_failure" else 1
    assert (
        await execute(database, "api", "SELECT count(*) FROM info_document_version")
        == expected
    )
    assert (
        await execute(
            database,
            "api",
            "SELECT count(*) FROM outbox_message WHERE topic='info.index.v1'",
        )
        == expected
    )
    if outcome != "success":
        async with database.sessions["api"]() as session:
            await service.request_crawl_job(session, job.id)
        assert (
            await execute(database, "api", "SELECT status FROM crawl_job") == "pending"
        )
        assert (
            await execute(
                database,
                "api",
                "SELECT count(*) FROM outbox_message WHERE topic='info.crawl.v1'",
            )
            == 2
        )


async def test_distribution_concurrent_create_explicit_retry_and_recovery(
    database, monkeypatch
):
    version = await upload(database, monkeypatch)

    async def create(dataset):
        async with database.sessions["api"]() as session:
            record = await service.create_knowledge_distribution(
                session,
                document_version_id=version.id,
                target_dataset=dataset,
                dispatch=True,
            )
            return record.id

    ids = await asyncio.gather(
        *(create(dataset) for dataset in [None, "", "default"] * 4)
    )
    assert len(set(ids)) == 1
    assert (
        await execute(database, "api", "SELECT count(*) FROM distribution_record") == 1
    )
    assert (
        await execute(
            database,
            "api",
            "SELECT count(*) FROM outbox_message WHERE topic='info.distribution.dispatch.v1'",
        )
        == 1
    )
    async with database.sessions["api"]() as session:
        await service.update_distribution_status(
            session, distribution_id=ids[0], status="failed", last_error="synthetic"
        )
        retried = await service.retry_distribution(session, distribution_id=ids[0])
        assert retried.id == ids[0]
        await service.request_distribution_dispatch(session, distribution_id=ids[0])
    assert (
        await execute(
            database,
            "api",
            "SELECT count(*) FROM outbox_message WHERE topic='info.distribution.dispatch.v1'",
        )
        == 2
    )
    message = await execute(
        database,
        "api",
        "SELECT id FROM outbox_message WHERE topic='info.distribution.dispatch.v1' ORDER BY created_at DESC LIMIT 1",
    )
    calls = []

    class Client:
        async def ingest_document(self, payload):
            calls.append(payload)
            if len(calls) == 1:
                raise ConnectionError("response lost after remote accept")
            return {"id": "synthetic-same-remote-ingestion"}

    monkeypatch.setattr(service, "get_knowledge_app_client", Client)
    with pytest.raises(RuntimeError, match="not_acknowledged"):
        await runtime(database).consume(message)
    assert await execute(database, "api", "SELECT count(*) FROM inbox_message") == 0
    assert await runtime(database).consume(message)
    assert calls[0] == calls[1]
    assert await runtime(database).consume(message) is False
    assert len(calls) == 2
    assert (
        await execute(database, "api", "SELECT status FROM distribution_record")
        == "succeeded"
    )


async def test_worker_search_reads_and_inbox(database, monkeypatch):
    version = await upload(database, monkeypatch)
    indexed = []

    class Search:
        enabled = True
        index_name = "synthetic"

        async def ensure_index(self):
            return True

        async def index_document(self, **kwargs):
            indexed.append(kwargs)

    monkeypatch.setattr(service, "get_info_search_index", Search)
    message = await execute(
        database, "api", "SELECT id FROM outbox_message WHERE topic='info.index.v1'"
    )
    assert await runtime(database).consume(message)
    assert await runtime(database).consume(message) is False
    assert len(indexed) == 1
    assert indexed[0]["document_id"] == str(version.id)


@pytest.mark.parametrize("role", ["api", "worker", "scheduler"])
async def test_runtime_version_ddl_legacy_delete_and_role_denials(database, role):
    statements = [
        "UPDATE public.alembic_version SET version_num='forged'",
        "CREATE TABLE public.forbidden(id int)",
        "CREATE SCHEMA forbidden",
        "CREATE TEMP TABLE forbidden(id int)",
        f'SET ROLE "{database.names["migration"]}"',
        "SELECT * FROM public.delivery_outbox_message_legacy",
        "UPDATE public.delivery_outbox_message_legacy SET state='pending'",
    ]
    statements += [f'DELETE FROM public."{table}"' for table in policy.TABLE_COLUMNS]
    statements += [f'TRUNCATE public."{table}"' for table in policy.TABLE_COLUMNS]
    for statement in statements:
        await denied(database, role, statement)


@pytest.mark.parametrize("role", ["api", "worker"])
async def test_runtime_identity_and_artifact_integrity_denials(database, role):
    for statement in (
        "UPDATE public.info_document SET canonical_url='forged'",
        "UPDATE public.info_document SET canonical_identity=repeat('a',64)",
        "UPDATE public.info_document_version SET content_hash=repeat('a',64)",
        "UPDATE public.info_document_version SET write_protocol_version=0",
        "UPDATE public.distribution_record SET target_dataset='other'",
        "UPDATE public.distribution_record SET document_version_id=NULL",
        "UPDATE public.raw_artifact SET object_key='forged'",
        "UPDATE public.extracted_content SET object_key='forged'",
    ):
        await denied(database, role, statement)
    if role == "api":
        for statement in (
            "UPDATE public.outbox_message SET status='consumed'",
            "UPDATE public.outbox_message SET payload='{}'",
            "INSERT INTO public.inbox_message(consumer,message_id) VALUES ('forged', gen_random_uuid())",
            "UPDATE public.crawl_job SET attempt_count=99",
        ):
            await denied(database, role, statement)
    else:
        for statement in (
            "SELECT * FROM public.auth_user",
            "UPDATE public.info_source SET crawl_policy='{}'",
            "INSERT INTO public.info_source(code,name) VALUES ('bad','bad')",
            "UPDATE public.info_collector SET config='{}'",
            "UPDATE public.info_document SET status='reviewed'",
            "UPDATE public.info_document_version SET extraction_status='reviewed'",
        ):
            await denied(database, role, statement)


async def test_scheduler_has_no_schema_or_table_access(database):
    for table in policy.TABLE_COLUMNS:
        await denied(database, "scheduler", f'SELECT * FROM public."{table}"')


@pytest.mark.parametrize("role", ["api", "worker", "scheduler", "migration"])
async def test_other_database_connection_is_denied(database, role):
    with pytest.raises(asyncpg.InsufficientPrivilegeError) as caught:
        await asyncpg.connect(
            host="127.0.0.1",
            port=55439,
            database=database.other,
            user=database.names[role],
            password=database.passwords[role],
            timeout=5,
        )
    assert caught.value.sqlstate == "42501"


@pytest.mark.parametrize("role", ["api", "worker", "scheduler"])
async def test_runtime_password_cannot_authenticate_migration(database, role):
    with pytest.raises(asyncpg.InvalidPasswordError) as caught:
        await asyncpg.connect(
            host="127.0.0.1",
            port=55439,
            database=database.database,
            user=database.names["migration"],
            password=database.passwords[role],
            timeout=5,
        )
    assert caught.value.sqlstate == "28P01"


async def test_new_table_is_closed_and_inventory_rejected(database):
    await execute(database, "migration", "CREATE TABLE public.future_domain(id int)")
    for role in ("api", "worker", "scheduler"):
        await denied(database, role, "SELECT * FROM public.future_domain")
        await denied(database, role, "INSERT INTO public.future_domain VALUES (1)")
    async with database.engines["migration"].connect() as connection:
        columns = await inventory(connection)
    with pytest.raises(policy.common.PolicyError):
        policy.info_grants(schema="public", principals=database.names, columns=columns)
