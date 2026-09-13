"""Knowledge services and provider journal on real independent PostgreSQL logins.

Explicit disposable-only gate. Backend test helpers supply synthetic artifacts and
the in-memory provider; no RAGFlow, S3, broker or business database is contacted.
Run in its own Python process, never alongside another App's integration module.
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

import asyncpg
import pytest
import pytest_asyncio

WORKSPACE = Path(__file__).resolve().parents[5]
BACKEND = WORKSPACE / "knowledge-app/knowledge-backend/app"
TEMPLATE = WORKSPACE / "tpl-app/k8s-deployment"
sys.path[:0] = [
    str(BACKEND),
    str(BACKEND / "tests"),
    str(TEMPLATE),
    str(TEMPLATE / "integration"),
    str(Path(__file__).resolve().parents[2] / "knowledge-app/deployment"),
]
import knowledge_database_policy as policy
from app.application.errors.exceptions import ForbiddenError
from app.application.services import ingestion_execution as execution
from app.application.services import knowledge_ingestion_service as service
from app.application.services import knowledge_retrieval_service as retrieval
from app.application.services import ragflow_delivery as provider
from app.application.services.durable_tasks import DurableTasks
from app.infrastructure.external.ragflow import ArtifactContent, RAGFlowRetrievalResult
from app.infrastructure.messaging.delivery_handlers import get_delivery_handlers
from app.infrastructure.storage.schema_readiness import verify_schema_revision
from permission_pg_support import denied, execute, inventory, provision_database
from test_ingestion_polling_db import SlowProvider
from test_knowledge_delivery_db import (
    CONTENT,
    Provider,
    authorized_settings,
    configure,
    payload,
)
from test_knowledge_retrieval import _principal, _request


@pytest_asyncio.fixture
async def database():
    async with provision_database(
        BACKEND, policy.knowledge_grants, scope="b7q"
    ) as instance:
        yield instance


@pytest.fixture(autouse=True)
def settings(monkeypatch):
    monkeypatch.setattr(service, "get_settings", authorized_settings)


def configured(monkeypatch, fake=None):
    fake = fake or Provider()
    configure(monkeypatch, fake)
    # This gate tests permissions, not a one-second parse deadline race.
    config = service.get_settings().model_copy(
        update={
            "ragflow_parse_timeout_seconds": 120,
            "ragflow_parse_poll_interval_seconds": 1,
        }
    )
    monkeypatch.setattr(service, "get_settings", lambda: config)
    return fake


async def submit(database, request=None):
    async with database.sessions["api"]() as session:
        job = await service.submit_ingestion(session, request or payload())
        return job.id


def runtime(database):
    return DurableTasks(database.sessions["worker"], handlers=get_delivery_handlers())


async def message(database, *, step=0, generation=0):
    return await execute(
        database,
        "api",
        "SELECT id FROM outbox_message WHERE payload->>'step'=:step AND payload->>'generation'=:generation",
        {"step": str(step), "generation": str(generation)},
    )


async def make_due(database, mid):
    # Synthetic transport timer only; do not change the persisted parse deadline.
    await execute(
        database,
        "worker",
        "UPDATE outbox_message SET available_at='2000-01-01', headers=jsonb_set(headers, '{sunmoonai.not_before.v1}', to_jsonb('2000-01-01T00:00:00Z'::text)) WHERE id=:id",
        {"id": mid},
    )


async def state(database):
    value = await execute(
        database,
        "api",
        "SELECT metadata_json->'ingestion_execution_v1' FROM knowledge_ingestion_job",
    )
    return execution.IngestionExecution.model_validate(value)


async def test_logins_revision_owner_and_readiness(database):
    assert len(set(database.passwords.values())) == 4
    for password in database.passwords.values():
        assert password not in repr(database)
    for role, name in database.names.items():
        assert await execute(database, role, "SELECT current_user") == name
        assert await execute(database, role, "SELECT session_user") == name
        if role in ("api", "worker"):
            async with database.sessions[role]() as session:
                await verify_schema_revision(session)
    assert (
        await execute(
            database, "migration", "SELECT version_num FROM public.alembic_version"
        )
        == "20260911_0006"
    )
    assert (
        await execute(
            database,
            "migration",
            "SELECT bool_and(tableowner=current_user) FROM pg_tables WHERE schemaname='public'",
        )
        is True
    )


async def test_concurrent_acceptance_immutable_intent_and_request(database):
    request = payload()
    ids = await asyncio.gather(*(submit(database, request) for _ in range(12)))
    assert len(set(ids)) == 1
    assert (
        await execute(database, "api", "SELECT count(*) FROM knowledge_ingestion_job")
        == 1
    )
    assert await execute(database, "api", "SELECT count(*) FROM outbox_message") == 1
    with pytest.raises(ValueError, match="another ingestion intent"):
        await submit(database, request.model_copy(update={"dataset_key": "different"}))
    async with database.sessions["api"]() as session:
        await service.request_ingestion_job(session, ingestion_id=ids[0])
    assert await execute(database, "api", "SELECT count(*) FROM outbox_message") == 1


async def test_acceptance_intent_failure_rolls_back(database, monkeypatch):
    async def fail(*args, **kwargs):
        raise RuntimeError("synthetic outbox failure")

    monkeypatch.setattr(service, "enqueue_task", fail)
    with pytest.raises(RuntimeError, match="synthetic outbox failure"):
        await submit(database)
    assert (
        await execute(database, "api", "SELECT count(*) FROM knowledge_ingestion_job")
        == 0
    )
    assert await execute(database, "api", "SELECT count(*) FROM outbox_message") == 0


async def test_artifact_only_consume_commits_without_provider_journal(
    database, monkeypatch
):
    async def artifact(**kwargs):
        return ArtifactContent("clean.md", CONTENT, "text/markdown")

    monkeypatch.setattr(service, "resolve_artifact_content", artifact)
    await submit(database)
    mid = await message(database)
    assert await runtime(database).consume(mid)
    assert await runtime(database).consume(mid) is False
    assert (
        await execute(database, "api", "SELECT status FROM knowledge_ingestion_job")
        == "artifact_verified"
    )
    assert (
        await execute(
            database, "worker", "SELECT count(*) FROM knowledge_provider_operation"
        )
        == 0
    )
    assert (
        await execute(
            database, "api", "SELECT count(*) FROM knowledge_document_version"
        )
        == 0
    )


@pytest.mark.parametrize("fault", [None, "upload", "parse"])
async def test_provider_receipt_response_loss_recovers_without_duplicate_effect(
    database, monkeypatch, fault
):
    fake = configured(monkeypatch, Provider(fault))
    await submit(database)
    mid = await message(database)
    if fault:
        with pytest.raises(provider.RAGFlowOutcomeUnknown):
            await runtime(database).consume(mid)
        assert await execute(database, "api", "SELECT count(*) FROM inbox_message") == 0
        assert (
            await execute(database, "api", "SELECT status FROM knowledge_ingestion_job")
            == "reconciliation_required"
        )
    assert await runtime(database).consume(mid)
    assert await runtime(database).consume(mid) is False
    assert (fake.creates, fake.uploads, fake.parses) == (0, 1, 1)
    assert (
        await execute(database, "api", "SELECT status FROM knowledge_ingestion_job")
        == "succeeded"
    )
    assert (
        await execute(database, "api", "SELECT count(*) FROM knowledge_document") == 1
    )
    assert (
        await execute(
            database, "api", "SELECT count(*) FROM knowledge_document_version"
        )
        == 1
    )
    assert (
        await execute(
            database,
            "worker",
            "SELECT count(*) FROM knowledge_provider_operation WHERE state='confirmed'",
        )
        == 3
    )


async def test_worker_upsert_same_source_version_keeps_domain_identity(
    database, monkeypatch
):
    fake = configured(monkeypatch)
    request = payload()
    first = await submit(database, request)
    assert await runtime(database).consume(await message(database))
    original = await execute(
        database, "api", "SELECT id FROM knowledge_document_version"
    )
    second = await submit(
        database,
        request.model_copy(update={"idempotency_key": "second-acceptance-same-source"}),
    )
    assert second != first
    mid = await execute(
        database,
        "api",
        "SELECT id FROM outbox_message WHERE payload->>'ingestion_id'=:job",
        {"job": str(second)},
    )
    assert await runtime(database).consume(mid)
    assert (
        await execute(database, "api", "SELECT id FROM knowledge_document_version")
        == original
    )
    assert (
        await execute(
            database, "api", "SELECT ingestion_id FROM knowledge_document_version"
        )
        == second
    )
    assert (
        await execute(database, "api", "SELECT count(*) FROM knowledge_document") == 1
    )
    assert (fake.uploads, fake.parses) == (1, 1)


async def test_final_domain_write_failure_rolls_back_then_recovers(
    database, monkeypatch
):
    fake = configured(monkeypatch)
    await submit(database)
    mid = await message(database)
    complete = service.complete_ragflow_ingestion

    async def fail_after_domain_writes(*args, **kwargs):
        assert kwargs["commit"] is False
        await complete(*args, **kwargs)
        raise RuntimeError("synthetic crash before final commit")

    monkeypatch.setattr(service, "complete_ragflow_ingestion", fail_after_domain_writes)
    with pytest.raises(RuntimeError, match="synthetic crash before final commit"):
        await runtime(database).consume(mid)
    for table in ("knowledge_document", "knowledge_document_version", "inbox_message"):
        assert await execute(database, "api", f'SELECT count(*) FROM "{table}"') == 0
    assert (
        await execute(database, "api", "SELECT status FROM knowledge_ingestion_job")
        == "running"
    )
    # Already committed external-effect receipts survive local final rollback.
    assert (
        await execute(
            database,
            "worker",
            "SELECT count(*) FROM knowledge_provider_operation WHERE state='confirmed'",
        )
        == 3
    )
    monkeypatch.setattr(service, "complete_ragflow_ingestion", complete)
    assert await runtime(database).consume(mid)
    assert (
        await execute(
            database, "api", "SELECT count(*) FROM knowledge_document_version"
        )
        == 1
    )
    assert await execute(database, "api", "SELECT count(*) FROM inbox_message") == 1
    assert (fake.uploads, fake.parses) == (1, 1)


async def test_worker_operator_receipt_recovery_uses_no_new_remote_write(
    database, monkeypatch
):
    fake = configured(monkeypatch, Provider("upload"))
    job_id = await submit(database)
    mid = await message(database)
    with pytest.raises(provider.RAGFlowOutcomeUnknown):
        await runtime(database).consume(mid)
    fake.hide_upload = True
    async with database.sessions["worker"]() as session:
        job = await service.get_ingestion_job(session, job_id)
        recovered = await provider.recover_upload_receipt(
            session, job=job, settings=service.get_settings(), document_id="document-1"
        )
    assert recovered["id"] == "document-1"
    assert (fake.uploads, fake.parses) == (1, 0)
    assert (
        await execute(database, "api", "SELECT status FROM knowledge_ingestion_job")
        == "reconciliation_required"
    )
    assert await execute(database, "api", "SELECT count(*) FROM inbox_message") == 0
    assert await runtime(database).consume(mid)
    assert (fake.uploads, fake.parses) == (1, 1)


async def test_poll_cursor_successor_inbox_and_retry_generation(database, monkeypatch):
    fake = configured(monkeypatch, SlowProvider())
    job_id = await submit(database)
    first = await message(database)
    assert await runtime(database).consume(first)
    before = await state(database)
    assert before.step == 1
    poll = await message(database, step=1)
    reads = fake.reads
    assert await runtime(database).consume(poll) is False
    assert fake.reads == reads
    assert await execute(database, "api", "SELECT count(*) FROM inbox_message") == 1
    # Existing Admin use case must remain functional with the API login.
    async with database.sessions["api"]() as session:
        await service.update_ingestion_status(
            session,
            ingestion_id=job_id,
            status="ragflow_parse_failed",
            last_error="synthetic operator test",
            metadata={},
            knowledge_document_id=None,
            ragflow_document_id=None,
        )
        retried = await service.retry_ingestion_job(
            session, ingestion_id=job_id, reason="retry"
        )
        assert retried.id == job_id
    after = await state(database)
    assert after.generation == 1 and after.step == 0
    assert after.upload == before.upload
    await make_due(database, poll)
    assert await runtime(database).consume(poll)
    assert fake.reads == reads  # Obsolete generation is acknowledged, never executed.
    fake.documents[0]["run"] = "DONE"
    assert await runtime(database).consume(await message(database, generation=1))
    assert (
        await execute(database, "api", "SELECT status FROM knowledge_ingestion_job")
        == "succeeded"
    )
    assert (fake.creates, fake.uploads, fake.parses) == (0, 1, 1)


async def test_poll_read_and_domain_completion(database, monkeypatch):
    fake = configured(monkeypatch, SlowProvider())
    await submit(database)
    assert await runtime(database).consume(await message(database))
    before = await state(database)
    mid = await message(database, step=1)
    await make_due(database, mid)
    reads = fake.reads
    assert await runtime(database).consume(mid)
    assert fake.reads == reads + 1
    after = await state(database)
    assert after.deadline == before.deadline and after.step == 2
    fake.documents[0]["run"] = "DONE"
    following = await message(database, step=2)
    await make_due(database, following)
    assert await runtime(database).consume(following)
    assert await execute(database, "api", "SELECT count(*) FROM inbox_message") == 3
    assert (
        await execute(
            database, "api", "SELECT count(*) FROM knowledge_document_version"
        )
        == 1
    )
    assert (fake.uploads, fake.parses) == (1, 1)


async def test_revoked_binding_rejected_before_artifact_or_provider(
    database, monkeypatch
):
    fake = configured(monkeypatch)
    await submit(database)
    config = service.get_settings().model_copy(
        update={"ingestion_dataset_bindings": "{}"}
    )
    monkeypatch.setattr(service, "get_settings", lambda: config)

    async def forbidden(*args, **kwargs):
        raise AssertionError("artifact read before authorization")

    monkeypatch.setattr(provider, "prepare_artifact", forbidden)
    with pytest.raises(ForbiddenError):
        await runtime(database).consume(await message(database))
    assert (fake.creates, fake.uploads, fake.parses) == (0, 0, 0)
    assert (
        await execute(
            database, "worker", "SELECT count(*) FROM knowledge_provider_operation"
        )
        == 0
    )
    assert await execute(database, "api", "SELECT count(*) FROM inbox_message") == 0


async def test_api_retrieval_reads_worker_written_domain_without_journal_access(
    database, monkeypatch
):
    configured(monkeypatch)
    await submit(database)
    assert await runtime(database).consume(await message(database))
    config = service.get_settings().model_copy(
        update={"retrieval_dataset_allowlist": "market-news"}
    )
    monkeypatch.setattr(retrieval, "get_settings", lambda: config)
    calls = []

    class Search:
        async def retrieve(self, **kwargs):
            calls.append(kwargs)
            return RAGFlowRetrievalResult(
                chunks=[
                    {
                        "id": "chunk-1",
                        "dataset_id": "dataset-1",
                        "document_id": "document-1",
                        "content": "verified evidence",
                        "similarity": 0.9,
                    }
                ],
                total=1,
            )

        async def close(self):
            pass

    monkeypatch.setattr(retrieval, "RAGFlowClient", lambda *args, **kwargs: Search())
    request = _request(filters={})
    async with database.sessions["api"]() as session:
        response = await retrieval.retrieve_knowledge(
            session, request, service_principal=_principal()
        )
    assert len(response.evidence) == 1
    assert calls[0]["document_ids"] == ["document-1"]
    assert calls[0]["dataset_ids"] == ["dataset-1"]
    await denied(database, "api", "SELECT * FROM public.knowledge_provider_operation")


@pytest.mark.parametrize("role", ["api", "worker", "scheduler"])
async def test_version_ddl_role_and_all_table_deletion_denials(database, role):
    for sql in (
        "UPDATE public.alembic_version SET version_num='forged'",
        "CREATE TABLE public.forbidden(id int)",
        "CREATE SCHEMA forbidden",
        "CREATE TEMP TABLE forbidden(id int)",
        f'SET ROLE "{database.names["migration"]}"',
    ):
        await denied(database, role, sql)
    for table in policy.TABLE_COLUMNS:
        await denied(database, role, f'DELETE FROM public."{table}"')
        await denied(database, role, f'TRUNCATE public."{table}"')


@pytest.mark.parametrize("role", ["api", "worker"])
async def test_domain_identity_and_cross_role_write_denials(database, role):
    for sql in (
        "UPDATE public.knowledge_ingestion_job SET target_dataset='forged'",
        "UPDATE public.knowledge_ingestion_job SET payload='{}'",
        "UPDATE public.knowledge_ingestion_job SET source_artifact_refs='[]'",
        "UPDATE public.knowledge_ingestion_job SET idempotency_key='forged'",
        "UPDATE public.knowledge_document SET dataset_key='forged'",
        "UPDATE public.knowledge_document_version SET source_document_id=gen_random_uuid()",
        "UPDATE public.knowledge_provider_operation SET intent='{}'",
        "UPDATE public.knowledge_provider_operation SET operation_key='forged'",
    ):
        await denied(database, role, sql)
    if role == "api":
        statements = (
            "SELECT * FROM public.knowledge_provider_operation",
            "INSERT INTO public.knowledge_provider_operation(operation_key,intent,state) VALUES ('bad','{}','confirmed')",
            "UPDATE public.knowledge_provider_operation SET receipt='{}'",
            "INSERT INTO public.knowledge_document(id) VALUES (gen_random_uuid())",
            "UPDATE public.knowledge_document_version SET provider_document_id='forged'",
            "UPDATE public.outbox_message SET status='consumed'",
            "INSERT INTO public.inbox_message(consumer,message_id) VALUES ('forged',gen_random_uuid())",
        )
    else:
        statements = (
            "SELECT * FROM public.auth_user",
            "INSERT INTO public.knowledge_ingestion_job(id) VALUES (gen_random_uuid())",
        )
    for sql in statements:
        await denied(database, role, sql)


async def test_scheduler_reads_and_future_table_closed(database):
    for table in policy.TABLE_COLUMNS:
        await denied(database, "scheduler", f'SELECT * FROM public."{table}"')
    await execute(database, "migration", "CREATE TABLE public.future_domain(id int)")
    for role in ("api", "worker", "scheduler"):
        await denied(database, role, "SELECT * FROM public.future_domain")
        await denied(database, role, "INSERT INTO public.future_domain VALUES (1)")
    async with database.engines["migration"].connect() as connection:
        columns = await inventory(connection)
    with pytest.raises(policy.common.PolicyError):
        policy.knowledge_grants(
            schema="public", principals=database.names, columns=columns
        )


@pytest.mark.parametrize("role", ["api", "worker", "scheduler", "migration"])
async def test_other_database_connection_denied(database, role):
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
