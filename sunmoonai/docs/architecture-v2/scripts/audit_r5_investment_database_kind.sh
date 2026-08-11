#!/usr/bin/env bash

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
POSTGRES_NAMESPACE="${POSTGRES_NAMESPACE:-data-platform-dev}"
POSTGRES_POD="${POSTGRES_POD:-postgresql-sunmoonai-0}"
DATABASE_NAME="${1:-research_admin}"

case "$DATABASE_NAME" in
  research_admin | investment_admin | investment_r5_restore_*) ;;
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
  WHERE rolname LIKE 'research%'
     OR rolname LIKE 'investment%';
"

echo "section=role_privileges"
run_sql "
  WITH app_roles AS (
    SELECT rolname
    FROM pg_roles
    WHERE rolname LIKE 'research%'
       OR rolname LIKE 'investment%'
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
  FROM app_roles AS r;
"

has_business_schema="$(run_sql "SELECT to_regclass('public.agent_sessions') IS NOT NULL;")"

echo "section=session_states"
if [[ "$has_business_schema" == "t" ]]; then
  run_sql "
    SELECT COALESCE(jsonb_object_agg(status, row_count ORDER BY status), '{}'::jsonb)
    FROM (
      SELECT status, count(*) AS row_count
      FROM agent_sessions
      GROUP BY status
    ) AS states;
  "
else
  echo '{}'
fi

echo "section=run_states"
if [[ "$has_business_schema" == "t" ]]; then
  run_sql "
    SELECT COALESCE(jsonb_object_agg(status, row_count ORDER BY status), '{}'::jsonb)
    FROM (
      SELECT status, count(*) AS row_count
      FROM agent_runs
      GROUP BY status
    ) AS states;
  "
else
  echo '{}'
fi

echo "section=side_effect_states"
if [[ "$has_business_schema" == "t" ]]; then
  run_sql "
    SELECT COALESCE(jsonb_object_agg(status, row_count ORDER BY status), '{}'::jsonb)
    FROM (
      SELECT status, count(*) AS row_count
      FROM tool_side_effects
      GROUP BY status
    ) AS states;
  "
else
  echo '{}'
fi

echo "section=investment_invariants"
if [[ "$has_business_schema" == "t" ]]; then
  run_sql "
  SELECT jsonb_build_object(
    'duplicate_run_idempotency_keys', (
      SELECT count(*)
      FROM (
        SELECT session_id, idempotency_key
        FROM agent_runs
        WHERE idempotency_key IS NOT NULL
        GROUP BY session_id, idempotency_key
        HAVING count(*) > 1
      ) AS duplicates
    ),
    'duplicate_session_sequences', (
      SELECT count(*)
      FROM (
        SELECT session_id, sequence_no
        FROM session_events
        GROUP BY session_id, sequence_no
        HAVING count(*) > 1
      ) AS duplicates
    ),
    'orphan_runs', (
      SELECT count(*)
      FROM agent_runs AS run
      LEFT JOIN agent_sessions AS session ON session.id = run.session_id
      WHERE session.id IS NULL
    ),
    'orphan_events', (
      SELECT count(*)
      FROM session_events AS event
      LEFT JOIN agent_sessions AS session ON session.id = event.session_id
      LEFT JOIN agent_runs AS run ON run.id = event.run_id
      WHERE session.id IS NULL OR run.id IS NULL
    ),
    'event_session_run_mismatch', (
      SELECT count(*)
      FROM session_events AS event
      JOIN agent_runs AS run ON run.id = event.run_id
      WHERE event.session_id <> run.session_id
    ),
    'orphan_side_effects', (
      SELECT count(*)
      FROM tool_side_effects AS side_effect
      LEFT JOIN agent_runs AS run ON run.id = side_effect.run_id
      WHERE run.id IS NULL
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
else
  echo '{}'
fi

echo "section=template_outbox_presence"
run_sql "
  SELECT jsonb_build_object(
    'outbox_message', to_regclass('public.outbox_message') IS NOT NULL,
    'inbox_message', to_regclass('public.inbox_message') IS NOT NULL
  );
"
