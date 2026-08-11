#!/usr/bin/env bash

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
POSTGRES_NAMESPACE="${POSTGRES_NAMESPACE:-data-platform-dev}"
POSTGRES_POD="${POSTGRES_POD:-postgresql-sunmoonai-0}"
DATABASE_NAME="${1:-knowledge_admin}"

case "$DATABASE_NAME" in
  knowledge_admin | knowledge_r5_restore_*) ;;
  *)
    echo "unsupported database: $DATABASE_NAME" >&2
    exit 2
    ;;
esac

run_sql() {
  local sql="$1"

  env -u DEBUG kubectl \
    --kubeconfig "$KUBECONFIG_PATH" \
    exec \
    --quiet \
    -n "$POSTGRES_NAMESPACE" \
    "$POSTGRES_POD" \
    -- sh -lc '
      database_name="$1"
      sql="$2"
      psql_bin=/opt/bitnami/postgresql/bin/psql
      export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
      exec "$psql_bin" \
        -U postgres \
        -d "$database_name" \
        -X \
        -v ON_ERROR_STOP=1 \
        -At \
        -c "$sql"
    ' sh "$DATABASE_NAME" "$sql"
}

echo "section=database"
run_sql "
  SELECT jsonb_build_object(
    'database', current_database(),
    'session_user', session_user,
    'database_owner', pg_get_userbyid(d.datdba),
    'server_version', current_setting('server_version'),
    'captured_at', clock_timestamp()
  )
  FROM pg_database AS d
  WHERE d.datname = current_database();
"

echo "section=alembic_heads"
if [[ "$(run_sql "SELECT to_regclass('public.alembic_version') IS NOT NULL;")" == "t" ]]; then
  run_sql "SELECT COALESCE(jsonb_agg(version_num ORDER BY version_num), '[]'::jsonb) FROM alembic_version;"
else
  echo '[]'
fi

echo "section=table_counts"
run_sql "
  WITH tables AS (
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename <> 'alembic_version'
  ), counts AS (
    SELECT
      tablename,
      ((xpath(
        '/row/count/text()',
        query_to_xml(
          format('SELECT count(*) AS count FROM public.%I', tablename),
          false,
          true,
          ''
        )
      ))[1]::text)::bigint AS row_count
    FROM tables
  )
  SELECT COALESCE(jsonb_object_agg(tablename, row_count ORDER BY tablename), '{}'::jsonb)
  FROM counts;
"

echo "section=constraints"
run_sql "
  SELECT jsonb_build_object(
    'primary_keys', count(*) FILTER (WHERE contype = 'p'),
    'foreign_keys', count(*) FILTER (WHERE contype = 'f'),
    'unique_constraints', count(*) FILTER (WHERE contype = 'u'),
    'check_constraints', count(*) FILTER (WHERE contype = 'c'),
    'not_valid', count(*) FILTER (WHERE NOT convalidated)
  )
  FROM pg_constraint
  WHERE connamespace = 'public'::regnamespace;
"

echo "section=table_owners"
run_sql "
  SELECT COALESCE(jsonb_object_agg(tableowner, table_count ORDER BY tableowner), '{}'::jsonb)
  FROM (
    SELECT tableowner, count(*) AS table_count
    FROM pg_tables
    WHERE schemaname = 'public'
    GROUP BY tableowner
  ) AS owners;
"

echo "section=roles"
run_sql "
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'role', rolname,
        'can_login', rolcanlogin,
        'is_superuser', rolsuper,
        'can_create_db', rolcreatedb,
        'can_create_role', rolcreaterole
      )
      ORDER BY rolname
    ),
    '[]'::jsonb
  )
  FROM pg_roles
  WHERE rolname LIKE 'knowledge%';
"

echo "section=role_privileges"
run_sql "
  WITH knowledge_roles AS (
    SELECT rolname
    FROM pg_roles
    WHERE rolname LIKE 'knowledge%'
  ), public_tables AS (
    SELECT format('%I.%I', schemaname, tablename) AS qualified_name
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename <> 'alembic_version'
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'role', r.rolname,
        'database_connect', has_database_privilege(r.rolname, current_database(), 'CONNECT'),
        'database_create', has_database_privilege(r.rolname, current_database(), 'CREATE'),
        'schema_usage', has_schema_privilege(r.rolname, 'public', 'USAGE'),
        'schema_create', has_schema_privilege(r.rolname, 'public', 'CREATE'),
        'select_tables', (
          SELECT count(*) FROM public_tables AS t
          WHERE has_table_privilege(r.rolname, t.qualified_name, 'SELECT')
        ),
        'insert_tables', (
          SELECT count(*) FROM public_tables AS t
          WHERE has_table_privilege(r.rolname, t.qualified_name, 'INSERT')
        ),
        'update_tables', (
          SELECT count(*) FROM public_tables AS t
          WHERE has_table_privilege(r.rolname, t.qualified_name, 'UPDATE')
        ),
        'delete_tables', (
          SELECT count(*) FROM public_tables AS t
          WHERE has_table_privilege(r.rolname, t.qualified_name, 'DELETE')
        )
      )
      ORDER BY r.rolname
    ),
    '[]'::jsonb
  )
  FROM knowledge_roles AS r;
"

echo "section=ingestion_states"
run_sql "
  SELECT COALESCE(jsonb_object_agg(status, row_count ORDER BY status), '{}'::jsonb)
  FROM (
    SELECT status, count(*) AS row_count
    FROM knowledge_ingestion_job
    GROUP BY status
  ) AS states;
"

echo "section=document_states"
run_sql "
  SELECT COALESCE(jsonb_object_agg(status, row_count ORDER BY status), '{}'::jsonb)
  FROM (
    SELECT status, count(*) AS row_count
    FROM knowledge_document
    GROUP BY status
  ) AS states;
"

echo "section=version_states"
run_sql "
  SELECT COALESCE(jsonb_object_agg(status, row_count ORDER BY status), '{}'::jsonb)
  FROM (
    SELECT status, count(*) AS row_count
    FROM knowledge_document_version
    GROUP BY status
  ) AS states;
"

echo "section=knowledge_invariants"
run_sql "
  SELECT jsonb_build_object(
    'duplicate_ingestion_idempotency_keys', (
      SELECT count(*)
      FROM (
        SELECT idempotency_key
        FROM knowledge_ingestion_job
        GROUP BY idempotency_key
        HAVING count(*) > 1
      ) AS duplicates
    ),
    'duplicate_document_source_dataset', (
      SELECT count(*)
      FROM (
        SELECT source_app, source_document_id, dataset_key
        FROM knowledge_document
        GROUP BY source_app, source_document_id, dataset_key
        HAVING count(*) > 1
      ) AS duplicates
    ),
    'duplicate_version_source', (
      SELECT count(*)
      FROM (
        SELECT knowledge_document_id, source_document_version_id
        FROM knowledge_document_version
        GROUP BY knowledge_document_id, source_document_version_id
        HAVING count(*) > 1
      ) AS duplicates
    ),
    'version_document_identity_mismatch', (
      SELECT count(*)
      FROM knowledge_document_version AS version
      JOIN knowledge_document AS document ON document.id = version.knowledge_document_id
      WHERE version.source_app <> document.source_app
         OR version.source_document_id <> document.source_document_id
         OR version.dataset_key <> document.dataset_key
    ),
    'indexed_version_missing_provider_binding', (
      SELECT count(*)
      FROM knowledge_document_version
      WHERE status = 'indexed'
        AND (
          provider = ''
          OR provider_dataset_id = ''
          OR provider_document_id = ''
        )
    ),
    'ingestion_document_binding_mismatch', (
      SELECT count(*)
      FROM knowledge_ingestion_job AS ingestion
      JOIN knowledge_document_version AS version ON version.ingestion_id = ingestion.id
      WHERE ingestion.knowledge_document_id IS NULL
         OR ingestion.knowledge_document_id <> version.knowledge_document_id::text
    ),
    'duplicate_auth_identities', (
      SELECT count(*)
      FROM (
        SELECT issuer, subject
        FROM auth_user
        GROUP BY issuer, subject
        HAVING count(*) > 1
      ) AS duplicates
    )
  );
"

echo "section=template_outbox_presence"
run_sql "
  SELECT jsonb_build_object(
    'outbox_message', to_regclass('public.outbox_message') IS NOT NULL,
    'inbox_message', to_regclass('public.inbox_message') IS NOT NULL
  );
"
