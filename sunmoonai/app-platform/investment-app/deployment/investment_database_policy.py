"""Investment process-role grants for a reviewed schema, not live provisioning.

Fresh independent roles, trusted owner and closed inherited/PUBLIC/default ACLs
are external prerequisites. API cancellation revokes leases; worker execution
owns side effects and LangGraph checkpoints. ACLs do not enforce row predicates.
"""

from __future__ import annotations

import sys
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parents[5] / "tpl-app/k8s-deployment"
sys.path.insert(0, str(TEMPLATE))
import runtime_database_policy as common

# Exact pg_get_functiondef for the 0007 archive write barrier. This is not a
# runtime EXECUTE grant and does not disable or replace the archive trigger.
REVIEWED_DATABASE_FUNCTIONS = {
    "agent_delivery_archive_readonly": (
        "CREATE OR REPLACE FUNCTION public.agent_delivery_archive_readonly()\n"
        " RETURNS trigger\n LANGUAGE plpgsql\nAS $function$\n"
        "        BEGIN\n"
        "            RAISE EXCEPTION 'Agent delivery archive is read-only; use outbox_dead_letter';\n"
        "        END;\n        $function$\n"
    )
}


def _fields(names):
    return frozenset(names.split())


DOMAIN_COLUMNS = {
    "checkpoint_migrations": _fields("v"),
    "checkpoints": _fields(
        "thread_id checkpoint_ns checkpoint_id parent_checkpoint_id type checkpoint metadata"
    ),
    "checkpoint_blobs": _fields("thread_id checkpoint_ns channel version type blob"),
    "checkpoint_writes": _fields(
        "thread_id checkpoint_ns checkpoint_id task_id idx channel type blob task_path"
    ),
    "agent_sessions": _fields("id status owner_actor_id created_at updated_at"),
    "agent_runs": _fields(
        "id session_id graph_name graph_version agent_profile_key agent_profile_version "
        "thread_id idempotency_key status resume_token error started_at completed_at "
        "created_at updated_at execution_state"
    ),
    "session_events": _fields(
        "id session_id run_id sequence_no category event_type payload_schema_version "
        "lineage payload metadata created_at"
    ),
    "tool_side_effects": _fields(
        "tool_call_id run_id status result intent execution_epoch receipt created_at updated_at"
    ),
    "agent_pilot_requests": _fields(
        "id owner_actor_id idempotency_key run_id title user_input created_at"
    ),
    "agent_pilot_controls": _fields(
        "run_id cancel_requested resume_action_id resume_idempotency_key updated_at"
    ),
    "agent_execution_leases": _fields("session_id command_id owner epoch expires_at"),
    "agent_delivery_failures_legacy_0006": _fields(
        "message_id error_code failed_at replayed_at"
    ),
}
# 0001-workbench (migrations 20260924_0008/0009). The api process and the runner
# (same identity) own these tables; the worker never touches them.
WORKBENCH_COLUMNS = {
    "workbench_approval_log": _fields(
        "id session_id task_id request_id method summary decision source interaction_id created_at"
    ),
    "workbench_artifacts": _fields(
        "id task_id attempt_id name version kind content content_ref digest workspace_path created_at"
    ),
    "workbench_attempts": _fields(
        "id task_id session_id thread_id environment_id role arm step_id step_version "
        "input_artifact_versions turn_ids status codex_version agent_version model model_provider "
        "budget_allocated budget_consumed failure_code retryable output_artifacts refs started_at "
        "ended_at created_at updated_at"
    ),
    "workbench_budget_ledger": _fields(
        "id task_id attempt_id entry amount tokens note actor_id created_at"
    ),
    "workbench_commands": _fields(
        "id session_id sandbox_id kind payload status claimed_by claimed_at finished_at error created_at"
    ),
    "workbench_credentials": _fields(
        "id owner_actor_id sandbox_id provider ciphertext hint status created_at revoked_at"
    ),
    "workbench_environments": _fields(
        "id owner_actor_id name agent_version codex_version roots ceiling status last_seen_at created_at updated_at"
    ),
    "workbench_interactions": _fields(
        "id session_id task_id attempt_id kind audience prompt subject_digest token_hash "
        "target_state_version expires_at status response consumed_at responded_by created_at"
    ),
    "workbench_sandboxes": _fields(
        "id owner_actor_id app_server_url token_ref codex_version status created_at updated_at relay_user provisioned"
    ),
    "workbench_session_events": _fields(
        "id session_id cursor kind event_type payload task_id attempt_id schema_version created_at"
    ),
    "workbench_sessions": _fields(
        "id owner_actor_id environment_id sandbox_id project_root thread_id wheel state_version "
        "active_task_id thread_settings created_at last_active_at"
    ),
    "workbench_tasks": _fields(
        "id session_id owner_actor_id tenant idempotency_key request_digest profile_id profile_version "
        "expert_pack_version original_input normalized_goal thread_id environment_id project_root state "
        "state_version workflow_version current_step acceptance_contract execution_policy budget "
        "active_attempt_id terminal_result_ref waiting_reason active_interaction_id rejection "
        "cancel_requested_at cancel_requested_by created_at updated_at"
    ),
    "workbench_user_prefs": _fields("owner_actor_id model approval_policy updated_at"),
    "workbench_relay_identities": _fields(
        "owner_actor_id relay_user agent_token_ciphertext sandbox_token_ciphertext created_at registered_at"
    ),
    "workbench_sandbox_leases": _fields("sandbox_id runner_id expires_at acquired_at updated_at"),
}
TABLE_COLUMNS = {**common.TABLE_COLUMNS, **DOMAIN_COLUMNS, **WORKBENCH_COLUMNS}
# Immutable identity/audit columns the api never rewrites. Every other column of a
# workbench table is insertable and updatable by the api (append-only tables list
# no updatable columns at all).
WORKBENCH_UPDATES = {
    "workbench_environments": "name agent_version codex_version roots ceiling status last_seen_at updated_at",
    "workbench_sandboxes": "app_server_url token_ref codex_version status updated_at relay_user provisioned",
    "workbench_sessions": "thread_id wheel state_version active_task_id thread_settings last_active_at",
    "workbench_tasks": (
        "profile_version expert_pack_version normalized_goal thread_id environment_id project_root state "
        "state_version workflow_version current_step acceptance_contract execution_policy budget "
        "active_attempt_id terminal_result_ref waiting_reason active_interaction_id rejection "
        "cancel_requested_at cancel_requested_by updated_at"
    ),
    "workbench_attempts": (
        "turn_ids status codex_version agent_version model model_provider budget_allocated budget_consumed "
        "failure_code retryable output_artifacts refs started_at ended_at updated_at"
    ),
    "workbench_interactions": "status response consumed_at responded_by",
    "workbench_credentials": "sandbox_id ciphertext hint status revoked_at",
    "workbench_commands": "status claimed_by claimed_at finished_at error",
    "workbench_user_prefs": "model approval_policy updated_at",
    "workbench_relay_identities": "agent_token_ciphertext sandbox_token_ciphertext registered_at",
    "workbench_sandbox_leases": "runner_id expires_at acquired_at updated_at",
}
API_READS = (
    "agent_sessions",
    "agent_runs",
    "session_events",
    "agent_pilot_requests",
    "agent_pilot_controls",
    "agent_execution_leases",
)
WORKER_READS = API_READS + (
    "tool_side_effects",
    "checkpoints",
    "checkpoint_blobs",
    "checkpoint_writes",
)
EVENT_INSERT = "id session_id run_id sequence_no category event_type payload_schema_version lineage payload metadata"
API_INSERTS = {
    "agent_sessions": "id status owner_actor_id",
    "agent_runs": "id session_id graph_name graph_version agent_profile_key agent_profile_version thread_id idempotency_key status",
    "agent_pilot_requests": "id owner_actor_id idempotency_key run_id title user_input",
    "agent_pilot_controls": "run_id",
    "session_events": EVENT_INSERT,
}
WORKER_INSERTS = {
    "session_events": EVENT_INSERT,
    "agent_execution_leases": "session_id command_id owner epoch expires_at",
    "tool_side_effects": "tool_call_id run_id status result intent execution_epoch receipt",
    "checkpoints": "thread_id checkpoint_ns checkpoint_id parent_checkpoint_id checkpoint metadata",
    "checkpoint_blobs": "thread_id checkpoint_ns channel version type blob",
    "checkpoint_writes": "thread_id checkpoint_ns checkpoint_id task_id task_path idx channel type blob",
}
API_UPDATES = {
    "agent_sessions": "status updated_at",
    "agent_runs": "status resume_token error updated_at",
    "agent_pilot_controls": "cancel_requested resume_action_id resume_idempotency_key updated_at",
    "agent_execution_leases": "epoch expires_at",
}
WORKER_UPDATES = {
    "agent_sessions": "status updated_at",
    "agent_runs": "status resume_token error updated_at execution_state",
    "agent_execution_leases": "command_id owner epoch expires_at",
    "tool_side_effects": "status result receipt execution_epoch updated_at",
    "checkpoints": "checkpoint metadata",
    "checkpoint_writes": "channel type blob",
}


def investment_grants(*, schema, principals, columns):
    if dict(columns) != TABLE_COLUMNS:
        raise common.PolicyError("unreviewed Investment table or column inventory")
    statements = list(
        common.template_grants(
            schema=schema,
            principals=principals,
            columns={table: columns[table] for table in common.TABLE_COLUMNS},
        )
    )
    schema_sql = '"public"' if schema == "public" else common.identifier(schema)

    def grant(role, table, privilege, names=""):
        names_sql = (
            " (" + ", ".join(common.identifier(n) for n in names.split()) + ")"
            if names
            else ""
        )
        statements.append(
            f"GRANT {privilege}{names_sql} ON TABLE {schema_sql}.{common.identifier(table)} "
            f"TO {common.identifier(principals[role])}"
        )

    for role, reads, inserts, updates in (
        ("api", API_READS, API_INSERTS, API_UPDATES),
        ("worker", WORKER_READS, WORKER_INSERTS, WORKER_UPDATES),
    ):
        for table in reads:
            grant(role, table, "SELECT")
        for table, names in inserts.items():
            grant(role, table, "INSERT", names)
        for table, names in updates.items():
            grant(role, table, "UPDATE", names)
    # Workbench: api reads, inserts and updates its own tables; worker has nothing.
    for table, names in WORKBENCH_COLUMNS.items():
        grant("api", table, "SELECT")
        grant("api", table, "INSERT", " ".join(sorted(names)))
        if table in WORKBENCH_UPDATES:
            grant("api", table, "UPDATE", WORKBENCH_UPDATES[table])
    # No runtime access to the checkpoint migration ledger or legacy failures.
    return tuple(statements)
