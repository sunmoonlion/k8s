"""Info-only additive grant candidate, not an existing-role reconciler.

Requires the same fresh-role/ownership/PUBLIC/default-ACL preconditions as the
template. Domain inventory is deliberately frozen, never inferred from models.
No connection, provisioning, revocation, migration or deployment entry point.
"""

from __future__ import annotations

import sys
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parents[5] / "tpl-app/k8s-deployment"
sys.path.insert(0, str(TEMPLATE))
import runtime_database_policy as common

# Exact PostgreSQL definitions reviewed against migrations 0008/0009. These
# protect immutable business identities; accepting them does not grant EXECUTE.
REVIEWED_DATABASE_FUNCTIONS = {
    "info_guard_canonical_identity_v1": (
        "CREATE OR REPLACE FUNCTION public.info_guard_canonical_identity_v1()\n"
        " RETURNS trigger\n LANGUAGE plpgsql\nAS $function$ BEGIN\n"
        "            IF NEW.canonical_url IS DISTINCT FROM OLD.canonical_url\n"
        "               OR NEW.canonical_identity IS DISTINCT FROM OLD.canonical_identity THEN\n"
        "                RAISE EXCEPTION 'canonical_identity_is_immutable' USING ERRCODE='23514';\n"
        "            END IF;\n            RETURN NEW;\n        END $function$\n"
    ),
    "info_guard_distribution_identity_v1": (
        "CREATE OR REPLACE FUNCTION public.info_guard_distribution_identity_v1()\n"
        " RETURNS trigger\n LANGUAGE plpgsql\nAS $function$ BEGIN\n"
        "            IF NEW.document_id IS DISTINCT FROM OLD.document_id\n"
        "               OR NEW.document_version_id IS DISTINCT FROM OLD.document_version_id\n"
        "               OR NEW.target_app IS DISTINCT FROM OLD.target_app\n"
        "               OR NEW.target_dataset IS DISTINCT FROM OLD.target_dataset\n"
        "               OR NEW.content_hash IS DISTINCT FROM OLD.content_hash THEN\n"
        "                RAISE EXCEPTION 'distribution_identity_is_immutable' USING ERRCODE='23514';\n"
        "            END IF;\n            RETURN NEW;\n        END $function$\n"
    ),
}


def _columns(names):
    return frozenset(("id created_at updated_at " + names).split())


DOMAIN_COLUMNS = {
    "info_source": _columns(
        "code name source_type base_url status trust_level copyright_status "
        "license_url terms_url crawl_policy description"
    ),
    "info_collector": _columns("source_id code name collector_type config status"),
    "crawl_job": _columns(
        "source_id collector_id document_id document_version_id job_type target_url "
        "status http_status final_url error_code error_message attempt_count "
        "duration_ms started_at finished_at request response_metadata"
    ),
    "raw_artifact": _columns(
        "crawl_job_id document_id document_version_id artifact_type bucket object_key "
        "version_id sha256 size_bytes content_type storage_state metadata_json"
    ),
    "info_document": _columns(
        "source_id canonical_url canonical_identity title source_name published_at "
        "status current_version_id content_hash metadata_json"
    ),
    "info_document_version": _columns(
        "document_id version_no write_protocol_version source_url title content_hash "
        "raw_artifact_id clean_artifact_id text_artifact_id extraction_status "
        "extractor_name extractor_version metadata_json"
    ),
    "extracted_content": _columns(
        "document_version_id content_format bucket object_key sha256 size_bytes "
        "extractor_name metadata_json"
    ),
    "distribution_record": _columns(
        "document_id document_version_id target_app target_dataset content_hash "
        "status payload last_error write_protocol_version"
    ),
    "delivery_outbox_message_legacy": _columns(
        "topic aggregate_type aggregate_id idempotency_key payload state attempt_count "
        "available_at lease_token lease_expires_at broker_message_id published_at "
        "completed_at last_error"
    ),
}
TABLE_COLUMNS = {**common.TABLE_COLUMNS, **DOMAIN_COLUMNS}
ACTIVE_TABLES = tuple(
    t for t in DOMAIN_COLUMNS if t != "delivery_outbox_message_legacy"
)
WORKER_INSERT_TABLES = (
    "raw_artifact",
    "info_document",
    "info_document_version",
    "extracted_content",
)
API_UPDATES = {
    "crawl_job": "request status document_id document_version_id updated_at",
    "raw_artifact": "document_id document_version_id updated_at",
    "info_document": "metadata_json status current_version_id content_hash updated_at",
    "info_document_version": "extraction_status metadata_json updated_at",
    "distribution_record": "status payload last_error updated_at",
}
WORKER_UPDATES = {
    "crawl_job": (
        "status started_at attempt_count http_status final_url response_metadata "
        "document_id document_version_id finished_at duration_ms error_code error_message updated_at"
    ),
    "raw_artifact": "document_id document_version_id updated_at",
    "info_document": "title published_at metadata_json current_version_id content_hash updated_at",
    "distribution_record": "status payload last_error updated_at",
}


def info_grants(*, schema, principals, columns):
    if dict(columns) != TABLE_COLUMNS:
        raise common.PolicyError("unreviewed Info table or column inventory")
    # The overlay cannot substitute different grants for common delivery/auth.
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
        for table in ACTIVE_TABLES:
            grant(role, table, "SELECT")
        for table in ACTIVE_TABLES if role == "api" else WORKER_INSERT_TABLES:
            grant(
                role,
                table,
                "INSERT",
                sorted(DOMAIN_COLUMNS[table] - {"created_at", "updated_at"}),
            )
        for table, names in (API_UPDATES if role == "api" else WORKER_UPDATES).items():
            grant(role, table, "UPDATE", names.split())
    # The archive is migration/audit-only: no current runtime reader or writer.
    return tuple(statements)
