"""Knowledge-only additive grants for fresh roles, never a live reconciler.

Requires trusted ownership, closed PUBLIC/default ACLs and no inherited access.
The API owns acceptance/retry, the worker owns provider receipts and indexing.
This is process-level narrowing, not tenant, JSON-field or approval enforcement.
"""

from __future__ import annotations

import sys
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parents[5] / "tpl-app/k8s-deployment"
sys.path.insert(0, str(TEMPLATE))
import runtime_database_policy as common


def _columns(names):
    return frozenset(("id created_at updated_at " + names).split())


DOMAIN_COLUMNS = {
    "knowledge_ingestion_job": _columns(
        "source_app source_document_id source_document_version_id target_dataset "
        "profile_key idempotency_key title canonical_url source_name content_hash "
        "source_artifact_refs metadata_json payload status last_error status_history "
        "knowledge_document_id ragflow_document_id completed_at"
    ),
    "knowledge_provider_operation": frozenset(
        {"operation_key", "intent", "state", "receipt", "created_at", "updated_at"}
    ),
    "knowledge_document": _columns("source_app source_document_id dataset_key status"),
    "knowledge_document_version": _columns(
        "knowledge_document_id source_app source_document_id source_document_version_id "
        "ingestion_id dataset_key content_hash title source_uri source_name access_scope "
        "status provider provider_dataset_id provider_document_id indexed_at"
    ),
}
TABLE_COLUMNS = {**common.TABLE_COLUMNS, **DOMAIN_COLUMNS}
JOB_UPDATES = (
    "status",
    "last_error",
    "status_history",
    "knowledge_document_id",
    "ragflow_document_id",
    "completed_at",
    "metadata_json",
    "updated_at",
)
VERSION_UPDATES = (
    "ingestion_id",
    "content_hash",
    "title",
    "source_uri",
    "source_name",
    "access_scope",
    "status",
    "provider",
    "provider_dataset_id",
    "provider_document_id",
    "indexed_at",
    "updated_at",
)


def knowledge_grants(*, schema, principals, columns):
    if dict(columns) != TABLE_COLUMNS:
        raise common.PolicyError("unreviewed Knowledge table or column inventory")
    statements = list(
        common.template_grants(
            schema=schema,
            principals=principals,
            columns={table: columns[table] for table in common.TABLE_COLUMNS},
        )
    )
    schema_sql = '"public"' if schema == "public" else common.identifier(schema)

    def grant(role, table, privilege, names=()):
        names_sql = (
            " (" + ", ".join(common.identifier(n) for n in names) + ")" if names else ""
        )
        statements.append(
            f"GRANT {privilege}{names_sql} ON TABLE {schema_sql}.{common.identifier(table)} "
            f"TO {common.identifier(principals[role])}"
        )

    for role in ("api", "worker"):
        for table in DOMAIN_COLUMNS:
            if role == "api" and table == "knowledge_provider_operation":
                continue
            grant(role, table, "SELECT")
        grant(role, "knowledge_ingestion_job", "UPDATE", JOB_UPDATES)
        inserts = (
            ("knowledge_ingestion_job",)
            if role == "api"
            else (
                "knowledge_provider_operation",
                "knowledge_document",
                "knowledge_document_version",
            )
        )
        for table in inserts:
            grant(
                role,
                table,
                "INSERT",
                sorted(DOMAIN_COLUMNS[table] - {"created_at", "updated_at"}),
            )
    grant(
        "worker",
        "knowledge_provider_operation",
        "UPDATE",
        ("state", "receipt", "updated_at"),
    )
    grant("worker", "knowledge_document_version", "UPDATE", VERSION_UPDATES)
    return tuple(statements)
