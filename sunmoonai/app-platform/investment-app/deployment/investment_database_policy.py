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
TABLE_COLUMNS = {**common.TABLE_COLUMNS, **DOMAIN_COLUMNS}
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
    # No runtime access to the checkpoint migration ledger or legacy failures.
    return tuple(statements)
