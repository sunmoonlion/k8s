"""Investment four real logins, PostgreSQL checkpoints and original Agent paths.

Explicit disposable-only gate. Graphs are existing pure skeleton/pilot graphs;
provider drafts and external side effects are synthetic. No business services.
"""

from __future__ import annotations

import asyncio
import sys
import uuid
from contextlib import suppress
from pathlib import Path
from types import SimpleNamespace

import asyncpg
import pytest
import pytest_asyncio

WORKSPACE = Path(__file__).resolve().parents[5]
BACKEND = WORKSPACE / "investment-app/investment-backend/app"
TEMPLATE = WORKSPACE / "tpl-app/k8s-deployment"
sys.path[:0] = [
    str(BACKEND),
    str(BACKEND / "tests"),
    str(TEMPLATE),
    str(TEMPLATE / "integration"),
    str(Path(__file__).resolve().parents[2] / "investment-app/deployment"),
]
import investment_database_policy as policy
from app.application.agent.event_sink import DBEventSink
from app.application.agent.run_service import AgentRunService
from app.application.agent.side_effect_service import (
    DurableSideEffectService,
    UnknownSideEffect,
)
from app.domain.agent.commands import CreateRunCommand, ResumeRunCommand
from app.domain.agent.models import DomainEvent, RunLineage, UserInput
from app.infrastructure.agent.delivery import AgentDelivery
from app.infrastructure.agent.effects import EffectRepository
from app.infrastructure.agent.pilot_repository import PilotRepository
from app.infrastructure.agent.repositories import AgentRepository
from app.infrastructure.agent.transactions import LeaseLost
from app.infrastructure.graph import checkpointer
from app.infrastructure.storage.schema_readiness import verify_schema_revision
from app.tasks.agent_delivery import execute_command, pump
from permission_pg_support import denied, execute, inventory, provision_database
from test_agent_reliability_db import BlockingExecutor, phase0, pilot


@pytest_asyncio.fixture
async def database(monkeypatch):
    async with provision_database(
        BACKEND, policy.investment_grants, scope="b7r"
    ) as instance:
        # Keep the production URL conversion and saver factory; replace only the
        # connection setting with this fixture's authenticated WORKER identity.
        config = SimpleNamespace(
            database_url=instance.engines["worker"].url.render_as_string(
                hide_password=False
            )
        )
        monkeypatch.setattr(checkpointer, "get_settings", lambda: config)
        yield instance


async def command(database, key="start"):
    return await execute(
        database,
        "api",
        "SELECT id FROM outbox_message WHERE deduplication_key LIKE :key",
        {"key": key + ":%"},
    )


async def test_four_logins_schema_revision_and_real_saver_identity(database):
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
        == "20260911_0007"
    )
    assert (
        await execute(
            database,
            "migration",
            "SELECT bool_and(tableowner=current_user) FROM pg_tables WHERE schemaname='public'",
        )
        is True
    )
    with checkpointer.phase0_postgres_checkpointer() as saver:
        assert saver.conn.info.user == database.names["worker"]
        assert (
            saver.conn.execute("SELECT current_user").fetchone()["current_user"]
            == database.names["worker"]
        )


async def test_api_concurrent_run_create_is_idempotent(database):
    _, session_id, _ = await phase0(database.sessions["api"])

    async def create():
        async with database.sessions["api"]() as session:
            return await AgentRunService(AgentRepository(session)).create_run(
                CreateRunCommand(session_id=session_id, idempotency_key="request-1")
            )

    runs = await asyncio.gather(*(create() for _ in range(12)))
    assert len({str(run["run_id"]) for run in runs}) == 1
    assert await execute(database, "api", "SELECT count(*) FROM agent_runs") == 1
    assert (
        await execute(
            database,
            "api",
            "SELECT count(*) FROM outbox_message WHERE topic='agent.execution'",
        )
        == 1
    )


async def test_api_event_state_and_notification_rollback(database, monkeypatch):
    run_id, session_id, _ = await phase0(database.sessions["api"])
    before = await execute(database, "api", "SELECT count(*) FROM session_events")
    async with database.sessions["api"]() as session:
        repo = AgentRepository(session)
        original = repo.append_event

        async def fail_ui(event, category):
            if category == "ui":
                raise RuntimeError("synthetic UI write failure")
            return await original(event, category)

        monkeypatch.setattr(repo, "append_event", fail_ui)
        with pytest.raises(RuntimeError, match="synthetic UI write failure"):
            async with repo.transaction():
                await repo.set_run_status(
                    run_id=run_id, session_id=session_id, status="running"
                )
                await DBEventSink(repo).append(
                    DomainEvent(
                        type="RunStarted",
                        lineage=RunLineage(session_id=session_id, run_id=run_id),
                    )
                )
    assert (
        await execute(database, "api", "SELECT count(*) FROM session_events") == before
    )
    assert await execute(database, "api", "SELECT status FROM agent_runs") == "created"
    assert await execute(database, "api", "SELECT count(*) FROM outbox_message") == 3


async def test_real_postgres_graph_wait_resume_and_duplicate_delivery(database):
    run_id, _, mid = await phase0(database.sessions["api"])
    await execute_command(str(mid), sessions=database.sessions["worker"])
    assert await execute(database, "api", "SELECT status FROM agent_runs") == "waiting"
    token = await execute(database, "api", "SELECT resume_token FROM agent_runs")
    first_threads = await execute(
        database, "worker", "SELECT count(DISTINCT thread_id) FROM checkpoints"
    )
    assert first_threads == 1
    async with database.sessions["api"]() as session:
        await AgentRunService(AgentRepository(session)).resume_run(
            ResumeRunCommand(
                run_id=run_id,
                resume_token=token,
                user_input=UserInput(text="confirmed"),
            )
        )
    resume = await command(database, "resume")
    await asyncio.gather(
        *(
            execute_command(str(resume), sessions=database.sessions["worker"])
            for _ in range(2)
        )
    )
    await execute_command(str(mid), sessions=database.sessions["worker"])
    await execute_command(str(resume), sessions=database.sessions["worker"])
    assert (
        await execute(database, "api", "SELECT status FROM agent_runs") == "completed"
    )
    assert (
        await execute(database, "worker", "SELECT count(*) FROM tool_side_effects") == 1
    )
    assert await execute(database, "api", "SELECT count(*) FROM inbox_message") == 2
    assert (
        await execute(
            database, "worker", "SELECT count(DISTINCT thread_id) FROM checkpoints"
        )
        == 2
    )
    for table in ("checkpoint_blobs", "checkpoint_writes"):
        assert await execute(database, "worker", f'SELECT count(*) FROM "{table}"') > 0


async def prepare_pilot(run):
    return {
        "run_id": str(run["id"]),
        "user_input": run["user_input"],
        "draft": "synthetic cited answer",
        "citations": [
            {"evidence_id": str(uuid.uuid4()), "title": "synthetic evidence"}
        ],
    }


async def test_pilot_approval_owner_token_idempotency_and_event_replay(database):
    run, actor = await pilot(database.sessions["api"])
    mid = await command(database)
    await execute_command(
        str(mid), sessions=database.sessions["worker"], prepare_input=prepare_pilot
    )
    action = uuid.UUID(
        await execute(database, "api", "SELECT resume_token FROM agent_runs")
    )
    request_key = uuid.uuid4()
    async with database.sessions["api"]() as session:
        repo = PilotRepository(session)
        with pytest.raises(PermissionError):
            await repo.consume_resume(
                run_id=run["id"],
                owner_actor_id=uuid.uuid4(),
                action_id=action,
                idempotency_key=request_key,
                value="yes",
            )
        with pytest.raises(ValueError, match="stale"):
            await repo.consume_resume(
                run_id=run["id"],
                owner_actor_id=actor,
                action_id=uuid.uuid4(),
                idempotency_key=request_key,
                value="yes",
            )
        _, accepted = await repo.consume_resume(
            run_id=run["id"],
            owner_actor_id=actor,
            action_id=action,
            idempotency_key=request_key,
            value="yes",
        )
        assert accepted
        _, repeated = await repo.consume_resume(
            run_id=run["id"],
            owner_actor_id=actor,
            action_id=action,
            idempotency_key=request_key,
            value="yes",
        )
        assert repeated is False
        with pytest.raises(ValueError, match="different input"):
            await repo.consume_resume(
                run_id=run["id"],
                owner_actor_id=actor,
                action_id=action,
                idempotency_key=request_key,
                value="changed",
            )
    await execute_command(
        str(await command(database, "resume")),
        sessions=database.sessions["worker"],
        prepare_input=prepare_pilot,
    )
    assert (
        await execute(database, "api", "SELECT status FROM agent_runs") == "completed"
    )
    async with database.sessions["api"]() as session:
        repo = PilotRepository(session)
        events = await repo.list_browser_events(run_id=run["id"], owner_actor_id=actor)
        assert events[-1]["type"] == "completed"
        assert (
            await repo.list_browser_events(
                run_id=run["id"],
                owner_actor_id=actor,
                after_event_id=uuid.UUID(events[-1]["event_id"]),
            )
            == []
        )
        with pytest.raises(PermissionError):
            await repo.list_browser_events(
                run_id=run["id"], owner_actor_id=uuid.uuid4()
            )


async def test_pilot_resume_enqueue_failure_preserves_token(database, monkeypatch):
    run, actor = await pilot(database.sessions["api"])
    await execute_command(
        str(await command(database)),
        sessions=database.sessions["worker"],
        prepare_input=prepare_pilot,
    )
    action = uuid.UUID(
        await execute(database, "api", "SELECT resume_token FROM agent_runs")
    )
    async with database.sessions["api"]() as session:
        repo = PilotRepository(session)

        async def fail(**kwargs):
            raise RuntimeError("synthetic enqueue failure")

        monkeypatch.setattr(repo, "enqueue", fail)
        with pytest.raises(RuntimeError, match="synthetic enqueue failure"):
            await repo.consume_resume(
                run_id=run["id"],
                owner_actor_id=actor,
                action_id=action,
                idempotency_key=uuid.uuid4(),
                value="yes",
            )
    assert await execute(database, "api", "SELECT resume_token FROM agent_runs") == str(
        action
    )
    assert (
        await execute(
            database, "api", "SELECT resume_idempotency_key FROM agent_pilot_controls"
        )
        is None
    )
    assert await command(database, "resume") is None


async def test_api_cancellation_revokes_worker_and_rejects_late_result(database):
    run, actor = await pilot(database.sessions["api"])
    executor = BlockingExecutor()
    mid = await command(database)
    task = asyncio.create_task(
        execute_command(
            str(mid),
            sessions=database.sessions["worker"],
            executor=executor,
            prepare_input=prepare_pilot,
        )
    )
    try:
        await asyncio.wait_for(executor.started.wait(), timeout=5)
        async with database.sessions["api"]() as session:
            repo = PilotRepository(session)
            with pytest.raises(PermissionError):
                await repo.request_cancel(run_id=run["id"], owner_actor_id=uuid.uuid4())
            await repo.request_cancel(run_id=run["id"], owner_actor_id=actor)
        executor.release.set()
        with pytest.raises(LeaseLost):
            await task
    finally:
        executor.release.set()
        if not task.done():
            task.cancel()
        with suppress(asyncio.CancelledError, LeaseLost):
            await task
    assert executor.closed
    assert (
        await execute(database, "api", "SELECT status FROM agent_runs") == "cancelled"
    )
    assert (
        await execute(
            database,
            "api",
            "SELECT count(*) FROM session_events WHERE payload->>'type'='completed'",
        )
        == 0
    )
    assert await execute(database, "api", "SELECT count(*) FROM inbox_message") == 0
    assert (
        await execute(database, "api", "SELECT epoch FROM agent_execution_leases") == 2
    )


async def test_old_epoch_cannot_write_or_release_new_owner(database):
    run_id, session_id, mid = await phase0(database.sessions["api"])
    delivery = AgentDelivery(database.sessions["worker"])
    first, _ = await delivery.claim_execution(mid)
    await execute(
        database, "worker", "UPDATE agent_execution_leases SET expires_at='-infinity'"
    )
    second, _ = await delivery.claim_execution(mid)
    assert second.epoch == first.epoch + 1
    async with database.sessions["worker"]() as session:
        repo = AgentRepository(session, lease=first)
        with pytest.raises(LeaseLost):
            await repo.set_run_status(
                run_id=run_id, session_id=session_id, status="failed"
            )
    await delivery.release(first)
    await delivery.renew(second)
    assert await execute(database, "api", "SELECT status FROM agent_runs") == "created"


@pytest.mark.parametrize("recoverable", [True, False])
async def test_remote_effect_unknown_or_receipt_recovery_never_repeats(
    database, monkeypatch, recoverable
):
    run_id, _, mid = await phase0(database.sessions["api"])
    delivery = AgentDelivery(database.sessions["worker"])
    lease, _ = await delivery.claim_execution(mid)

    class Remote:
        calls = 0
        receipt = None

        async def execute(self, **kwargs):
            self.calls += 1
            self.receipt = {"id": "synthetic-remote-result"} if recoverable else None
            if not recoverable:
                raise TimeoutError("synthetic response lost")
            return self.receipt

        async def lookup(self, **kwargs):
            return self.receipt

    remote = Remote()
    async with database.sessions["worker"]() as session:
        repo = EffectRepository(session, lease=lease)
        if recoverable:

            async def crash(*args, **kwargs):
                raise LeaseLost("synthetic lost lease before receipt commit")

            monkeypatch.setattr(repo, "settle", crash)
        with pytest.raises(LeaseLost if recoverable else TimeoutError):
            await DurableSideEffectService(repo, remote).execute(
                key="effect-1", run_id=run_id, intent={"action": "synthetic"}
            )
    await execute(
        database, "worker", "UPDATE agent_execution_leases SET expires_at='-infinity'"
    )
    await delivery.reconcile()
    assert (
        await execute(database, "worker", "SELECT status FROM tool_side_effects")
        == "unknown"
    )
    replacement, _ = await delivery.claim_execution(mid)
    async with database.sessions["worker"]() as session:
        service = DurableSideEffectService(
            EffectRepository(session, lease=replacement), remote
        )
        if recoverable:
            assert (
                await service.execute(
                    key="effect-1", run_id=run_id, intent={"action": "synthetic"}
                )
                == remote.receipt
            )
        else:
            with pytest.raises(UnknownSideEffect):
                await service.execute(
                    key="effect-1", run_id=run_id, intent={"action": "synthetic"}
                )
    assert remote.calls == 1


async def test_worker_shared_pump_dead_letter_and_replay(database):
    await phase0(database.sessions["api"], initial="complete")
    delivery = AgentDelivery(database.sessions["worker"], max_attempts=1)
    item = await delivery.claim_delivery()
    await delivery.finish_delivery(item, error="synthetic broker failure")
    assert (
        await execute(
            database,
            "api",
            "SELECT count(*) FROM outbox_dead_letter WHERE replayed_at IS NULL",
        )
        == 1
    )
    await delivery.replay(item["id"])
    published = []

    async def publish(item):
        published.append(item["id"])

    await pump(sessions=database.sessions["worker"], publish=publish)
    assert item["id"] in published
    assert (
        await execute(
            database,
            "api",
            "SELECT count(*) FROM outbox_dead_letter WHERE replayed_at IS NULL",
        )
        == 0
    )


@pytest.mark.parametrize("role", ["api", "worker", "scheduler"])
async def test_version_ddl_legacy_and_all_deletions_denied(database, role):
    for sql in (
        "UPDATE public.alembic_version SET version_num='forged'",
        "SELECT * FROM public.checkpoint_migrations",
        "UPDATE public.checkpoint_migrations SET v=99",
        "SELECT * FROM public.agent_delivery_failures_legacy_0006",
        "UPDATE public.agent_delivery_failures_legacy_0006 SET error_code='forged'",
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
async def test_cross_role_and_append_only_denials(database, role):
    for sql in (
        "UPDATE public.session_events SET payload='{}'",
        "UPDATE public.agent_pilot_requests SET owner_actor_id=gen_random_uuid()",
        "UPDATE public.agent_sessions SET owner_actor_id=gen_random_uuid()",
        "UPDATE public.agent_runs SET graph_name='forged'",
        "UPDATE public.tool_side_effects SET intent='{}'",
        "UPDATE public.agent_execution_leases SET session_id=gen_random_uuid()",
    ):
        await denied(database, role, sql)
    if role == "api":
        statements = (
            "UPDATE public.agent_runs SET execution_state='{}'",
            "UPDATE public.agent_execution_leases SET owner='forged'",
            "INSERT INTO public.agent_execution_leases(session_id) VALUES (gen_random_uuid())",
            "SELECT * FROM public.tool_side_effects",
            "INSERT INTO public.tool_side_effects(tool_call_id) VALUES ('forged')",
            "UPDATE public.outbox_message SET status='consumed'",
            "INSERT INTO public.inbox_message(consumer,message_id) VALUES ('forged',gen_random_uuid())",
            "SELECT * FROM public.checkpoints",
            "INSERT INTO public.checkpoints(thread_id) VALUES ('forged')",
        )
    else:
        statements = (
            "SELECT * FROM public.auth_user",
            "INSERT INTO public.agent_runs(id) VALUES (gen_random_uuid())",
            "INSERT INTO public.agent_sessions(id) VALUES (gen_random_uuid())",
            "UPDATE public.agent_pilot_controls SET cancel_requested=true",
            "UPDATE public.agent_pilot_controls SET resume_action_id=gen_random_uuid()",
            "UPDATE public.checkpoints SET thread_id='forged'",
            "UPDATE public.checkpoint_blobs SET blob='forged'",
        )
    for sql in statements:
        await denied(database, role, sql)


async def test_scheduler_and_future_tables_fail_closed(database):
    for table in policy.TABLE_COLUMNS:
        await denied(database, "scheduler", f'SELECT * FROM public."{table}"')
    await execute(database, "migration", "CREATE TABLE public.future_domain(id int)")
    for role in ("api", "worker", "scheduler"):
        await denied(database, role, "SELECT * FROM public.future_domain")
        await denied(database, role, "INSERT INTO public.future_domain VALUES (1)")
    async with database.engines["migration"].connect() as connection:
        columns = await inventory(connection)
    with pytest.raises(policy.common.PolicyError):
        policy.investment_grants(
            schema="public", principals=database.names, columns=columns
        )


@pytest.mark.parametrize("role", ["api", "worker", "scheduler", "migration"])
async def test_other_database_denied(database, role):
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
