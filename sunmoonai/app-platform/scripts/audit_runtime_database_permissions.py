"""Read-only PostgreSQL 16+ catalog inventory using this Backend's own Settings.

Run with the Backend Python, optionally through kubectl exec -i ... python -.
No arguments, credential output, business-row reads, migrations or grants.
This is evidence collection, NOT a permission policy or deployment approval.
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
from datetime import datetime, timezone

MAX_ROWS = 2000
TOTAL_TIMEOUT = 15
SETUP = (
    "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY",
    "SET LOCAL statement_timeout = 3000",
    "SET LOCAL lock_timeout = 1000",
    "SET LOCAL search_path = pg_catalog",
)
# All names/functions below resolve through pg_catalog, never the App schema.
# No pg_authid/pg_shadow, function bodies, role settings, URLs or row contents.
USER_SCHEMA = "n.nspname !~ '^pg_' AND n.nspname <> 'information_schema'"
QUERIES = {
    "identity": """
        SELECT current_database() AS database, current_user AS principal,
               session_user AS session_principal,
               current_setting('server_version_num') AS server_version_num,
               current_setting('transaction_read_only') AS transaction_read_only,
               current_setting('transaction_isolation') AS transaction_isolation,
               r.rolsuper, r.rolcreatedb, r.rolcreaterole, r.rolreplication,
               r.rolbypassrls, r.rolinherit, r.rolcanlogin,
               pg_get_userbyid(d.datdba) AS database_owner,
               has_database_privilege(d.oid, 'CONNECT') AS can_connect,
               has_database_privilege(d.oid, 'CREATE') AS can_create_schema,
               has_database_privilege(d.oid, 'TEMPORARY') AS can_create_temp
        FROM pg_roles r CROSS JOIN pg_database d
        WHERE r.rolname = current_user AND d.datname = current_database()
    """,
    "reachable_roles": """
        SELECT rolname, pg_has_role(oid, 'MEMBER') AS member,
               pg_has_role(oid, 'USAGE') AS immediately_available,
               pg_has_role(oid, 'SET') AS can_set_role,
               rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls
        FROM pg_roles WHERE rolname <> current_user
          AND (pg_has_role(oid, 'MEMBER') OR pg_has_role(oid, 'USAGE')
               OR pg_has_role(oid, 'SET'))
        ORDER BY rolname
    """,
    "schemas": f"""
        SELECT n.nspname AS schema, pg_get_userbyid(n.nspowner) AS owner,
               has_schema_privilege(n.oid, 'USAGE') AS can_use,
               has_schema_privilege(n.oid, 'CREATE') AS can_create,
               pg_has_role(n.nspowner, 'USAGE') AS owner_available,
               pg_has_role(n.nspowner, 'SET') AS can_set_owner
        FROM pg_namespace n WHERE {USER_SCHEMA} ORDER BY n.nspname
    """,
    "relations": f"""
        SELECT n.nspname AS schema, c.relname AS name, c.relkind::text AS kind,
               pg_get_userbyid(c.relowner) AS owner,
               pg_has_role(c.relowner, 'USAGE') AS owner_available,
               pg_has_role(c.relowner, 'SET') AS can_set_owner,
               c.relrowsecurity AS rls_enabled, c.relforcerowsecurity AS rls_forced,
               has_table_privilege(c.oid, 'SELECT') AS can_select,
               has_table_privilege(c.oid, 'INSERT') AS can_insert,
               has_table_privilege(c.oid, 'UPDATE') AS can_update,
               has_table_privilege(c.oid, 'DELETE') AS can_delete,
               has_table_privilege(c.oid, 'TRUNCATE') AS can_truncate,
               has_table_privilege(c.oid, 'REFERENCES') AS can_reference,
               has_table_privilege(c.oid, 'TRIGGER') AS can_trigger,
               has_table_privilege(c.oid,
                   'SELECT WITH GRANT OPTION, INSERT WITH GRANT OPTION, '
                   'UPDATE WITH GRANT OPTION, DELETE WITH GRANT OPTION, '
                   'TRUNCATE WITH GRANT OPTION, REFERENCES WITH GRANT OPTION, '
                   'TRIGGER WITH GRANT OPTION') AS has_grant_option,
               has_any_column_privilege(c.oid, 'SELECT') AS any_column_select,
               has_any_column_privilege(c.oid, 'INSERT') AS any_column_insert,
               has_any_column_privilege(c.oid, 'UPDATE') AS any_column_update,
               has_any_column_privilege(c.oid, 'REFERENCES') AS any_column_reference
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE {USER_SCHEMA} AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
        ORDER BY n.nspname, c.relname
    """,
    "sequences": f"""
        SELECT n.nspname AS schema, c.relname AS name,
               pg_get_userbyid(c.relowner) AS owner,
               pg_has_role(c.relowner, 'USAGE') AS owner_available,
               pg_has_role(c.relowner, 'SET') AS can_set_owner,
               has_sequence_privilege(c.oid, 'USAGE') AS can_use,
               has_sequence_privilege(c.oid, 'SELECT') AS can_select,
               has_sequence_privilege(c.oid, 'UPDATE') AS can_update
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE {USER_SCHEMA} AND c.relkind = 'S'
        ORDER BY n.nspname, c.relname
    """,
    "functions": f"""
        SELECT n.nspname AS schema, p.proname AS name, p.oid AS oid,
               pg_get_userbyid(p.proowner) AS owner,
               p.prosecdef AS security_definer,
               has_function_privilege(p.oid, 'EXECUTE') AS can_execute
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE {USER_SCHEMA} ORDER BY n.nspname, p.proname, p.oid
    """,
    "default_acl": """
        SELECT pg_get_userbyid(d.defaclrole) AS creator,
               CASE WHEN d.defaclnamespace = 0 THEN '<global>'
                    ELSE n.nspname END AS schema,
               d.defaclobjtype::text AS object_type,
               CASE WHEN a.grantee = 0 THEN 'PUBLIC'
                    ELSE pg_get_userbyid(a.grantee) END AS grantee,
               a.privilege_type, a.is_grantable
        FROM pg_default_acl d
        LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace
        CROSS JOIN LATERAL aclexplode(d.defaclacl) a
        ORDER BY creator, schema, object_type, grantee, privilege_type
    """,
}


class AuditError(Exception):
    """No exception detail is safe for the CLI to print."""


class QueryError(AuditError):
    def __init__(self, section, error):
        super().__init__("catalog_query_failed")
        self.section = section if section in QUERIES else "setup"
        code = getattr(getattr(error, "orig", None), "sqlstate", None)
        self.sqlstate = (
            code
            if isinstance(code, str) and re.fullmatch(r"[0-9A-Z]{5}", code)
            else None
        )


async def execute(connection, statement, section="setup"):
    try:
        return await connection.exec_driver_sql(statement)
    except Exception as exc:  # noqa: BLE001 -- retain only fixed section and SQLSTATE.
        raise QueryError(section, exc) from None


async def collect(connection) -> dict:
    """Caller owns the transaction; fail closed on missing/oversized evidence."""
    for statement in SETUP:
        await execute(connection, statement)
    inventory = {}
    for section, sql in QUERIES.items():
        result = await execute(connection, f"{sql}\nLIMIT {MAX_ROWS + 1}", section)
        rows = [dict(row) for row in result.mappings().all()]
        if len(rows) > MAX_ROWS:
            raise AuditError("catalog_limit_exceeded")
        inventory[section] = rows
        if section == "identity":
            if len(rows) != 1:
                raise AuditError("identity_missing")
            identity = rows[0]
            if (
                int(identity["server_version_num"]) < 160000
                or identity["transaction_read_only"] != "on"
                or identity["transaction_isolation"] != "repeatable read"
                or identity["principal"] != identity["session_principal"]
            ):
                raise AuditError("audit_context_invalid")
    return {
        "format_version": 1,
        "status": "collected",
        "permission_acceptance": "not_evaluated",
        "captured_at_utc": datetime.now(timezone.utc).isoformat(),
        "inventory": inventory,
    }


async def audit() -> dict:
    # Import lazily: the platform unit suite needs no Backend dependencies.
    from core.config import get_settings
    from sqlalchemy.ext.asyncio import create_async_engine
    from sqlalchemy.pool import NullPool

    # Settings normalizes postgres:// to the installed asyncpg driver.
    engine = create_async_engine(
        get_settings().database_url,
        hide_parameters=True,
        echo=False,
        poolclass=NullPool,
        connect_args={"timeout": 5, "command_timeout": 3},
    )
    try:
        async with engine.connect() as connection, connection.begin():
            return await collect(connection)
    finally:
        await engine.dispose()


async def emit(run=audit) -> int:
    try:
        async with asyncio.timeout(TOTAL_TIMEOUT):
            report = await run()
        # Serialize before printing: no partial inventory on serialization error.
        encoded = json.dumps(report, ensure_ascii=True, sort_keys=True)
    except QueryError as exc:
        print(
            json.dumps(
                {
                    "status": "failed",
                    "reason": "catalog_query_failed",
                    "section": exc.section,
                    "sqlstate": exc.sqlstate,
                }
            )
        )
        return 1
    except Exception as exc:  # noqa: BLE001 -- CLI redaction boundary; never print driver errors.
        category = next(
            (
                name
                for cls, name in (
                    (AuditError, "invalid_inventory"),
                    (TimeoutError, "timeout"),
                    (TypeError, "type_error"),
                    (ValueError, "value_error"),
                    (ImportError, "import_error"),
                    (AttributeError, "attribute_error"),
                )
                if isinstance(exc, cls)
            ),
            "unclassified",
        )
        print(
            json.dumps(
                {
                    "status": "failed",
                    "reason": "permission_inventory_unavailable",
                    "category": category,
                }
            )
        )
        return 1
    print(encoded)
    return 0


if __name__ == "__main__":
    # Suppress dependency diagnostics which may contain connection information.
    logging.disable(logging.CRITICAL)
    raise SystemExit(asyncio.run(emit()))
