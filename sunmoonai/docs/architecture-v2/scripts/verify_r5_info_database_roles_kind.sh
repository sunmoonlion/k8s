#!/usr/bin/env bash

# Verify the R5 Info prepared database identities without exposing credentials.
# The only DDL probes are either expected to fail or are rolled back.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="${APP_NAMESPACE:-app-platform-dev}"
DATA_NAMESPACE="${DATA_NAMESPACE:-data-platform-dev}"
POSTGRES_POD="${POSTGRES_POD:-postgresql-sunmoonai-0}"
RUNTIME_SECRET="${RUNTIME_SECRET:-info-backend-postgresql-conn}"
MIGRATION_SECRET="${MIGRATION_SECRET:-info-backend-migration-postgresql-conn}"
RUNTIME_ROLE="${RUNTIME_ROLE:-info_backend_user}"
MIGRATION_ROLE="${MIGRATION_ROLE:-info_backend_user_migration}"
LEGACY_OWNER_ROLE="${LEGACY_OWNER_ROLE:-info_admin_user_migration}"
DATABASE_NAME="${DATABASE_NAME:-info_admin}"
PROBE_TABLE="${PROBE_TABLE:-r5_info_role_probe}"
TASK_ID="${TASK_ID:-R5-I2}"
MIN_TABLE_COUNT="${MIN_TABLE_COUNT:-11}"

k() {
  env -u DEBUG kubectl \
    --kubeconfig "$KUBECONFIG_PATH" \
    --request-timeout=15s \
    "$@"
}

decode_secret_key() {
  local namespace="$1" secret="$2" key="$3" encoded
  encoded="$(k get secret "$secret" -n "$namespace" -o "jsonpath={.data.${key}}")"
  [[ -n "$encoded" ]] || return 1
  printf '%s' "$encoded" | base64 --decode
}

runtime_url="$(decode_secret_key "$APP_NAMESPACE" "$RUNTIME_SECRET" DATABASE_URL)"
migration_url="$(decode_secret_key "$APP_NAMESPACE" "$MIGRATION_SECRET" MIGRATION_DATABASE_URL)"

[[ "$runtime_url" == postgresql://* ]] || {
  echo 'runtime URL must use the PostgreSQL URI scheme' >&2
  exit 2
}
[[ "$migration_url" == postgresql://* ]] || {
  echo 'migration URL must use the PostgreSQL URI scheme' >&2
  exit 2
}

runtime_keys="$(
  k get secret "$RUNTIME_SECRET" -n "$APP_NAMESPACE" -o json \
    | jq -cS '[.data | keys[]]'
)"
migration_keys="$(
  k get secret "$MIGRATION_SECRET" -n "$APP_NAMESPACE" -o json \
    | jq -cS '[.data | keys[]]'
)"
runtime_state="$(
  k get secret "$RUNTIME_SECRET" -n "$APP_NAMESPACE" \
    -o 'jsonpath={.metadata.annotations.architecture\.sunmoonai\.com/state}'
)"
migration_state="$(
  k get secret "$MIGRATION_SECRET" -n "$APP_NAMESPACE" \
    -o 'jsonpath={.metadata.annotations.architecture\.sunmoonai\.com/state}'
)"

remote_result="$({
  printf "RUNTIME_URL='%s'\n" "$runtime_url"
  printf "MIGRATION_URL='%s'\n" "$migration_url"
  cat <<'REMOTE_SCRIPT'
set -eu
runtime_role="$1"
migration_role="$2"
legacy_owner_role="$3"
probe_table="$4"
psql_bin=/opt/bitnami/postgresql/bin/psql
admin_password="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"

export PGPASSWORD="$admin_password"
"$psql_bin" -U postgres -d "$5" -X -v ON_ERROR_STOP=1 \
  -c "DROP TABLE IF EXISTS public.$probe_table" >/dev/null

runtime_principal="$(
  "$psql_bin" "$RUNTIME_URL" -X -v ON_ERROR_STOP=1 -At \
    -c 'SELECT current_user'
)"
test "$runtime_principal" = "$runtime_role"
"$psql_bin" "$RUNTIME_URL" -X -v ON_ERROR_STOP=1 >/dev/null <<'SQL'
BEGIN;
SELECT count(*) FROM auth_user;
UPDATE auth_user SET id = id WHERE false;
DELETE FROM auth_user WHERE false;
ROLLBACK;
SQL

runtime_ddl_denied=false
if "$psql_bin" "$RUNTIME_URL" -X -v ON_ERROR_STOP=1 \
  -c "CREATE TABLE public.$probe_table(id bigint)" \
  >/tmp/r5-runtime-ddl.out 2>/tmp/r5-runtime-ddl.err; then
  "$psql_bin" "$RUNTIME_URL" -X -v ON_ERROR_STOP=1 \
    -c "DROP TABLE IF EXISTS public.$probe_table" >/dev/null 2>&1 || true
else
  runtime_ddl_denied=true
fi
rm -f /tmp/r5-runtime-ddl.out /tmp/r5-runtime-ddl.err
test "$runtime_ddl_denied" = true

migration_principal="$(
  "$psql_bin" "$MIGRATION_URL" -X -v ON_ERROR_STOP=1 -At \
    -c 'SELECT current_user'
)"
test "$migration_principal" = "$migration_role"
"$psql_bin" "$MIGRATION_URL" -X -v ON_ERROR_STOP=1 >/dev/null <<SQL
BEGIN;
CREATE TABLE public.$probe_table(id bigint);
ROLLBACK;
SQL

export PGPASSWORD="$admin_password"
"$psql_bin" -U postgres -d "$5" -X -v ON_ERROR_STOP=1 -At \
  --set=runtime_role="$runtime_role" \
  --set=migration_role="$migration_role" \
  --set=legacy_owner_role="$legacy_owner_role" \
  --set=probe_table="$probe_table" \
  --set=runtime_ddl_denied="$runtime_ddl_denied" <<'SQL'
WITH public_tables AS (
  SELECT format('%I.%I', schemaname, tablename) AS relation
  FROM pg_tables
  WHERE schemaname = 'public'
), role_state AS (
  SELECT
    rolname,
    rolcanlogin,
    rolsuper,
    rolcreatedb,
    rolcreaterole,
    rolreplication
  FROM pg_roles
  WHERE rolname IN (:'runtime_role', :'migration_role')
)
SELECT jsonb_build_object(
  'runtime_principal', :'runtime_role',
  'runtime_login', (SELECT rolcanlogin FROM role_state WHERE rolname = :'runtime_role'),
  'runtime_superuser', (SELECT rolsuper FROM role_state WHERE rolname = :'runtime_role'),
  'runtime_create_db', (SELECT rolcreatedb FROM role_state WHERE rolname = :'runtime_role'),
  'runtime_create_role', (SELECT rolcreaterole FROM role_state WHERE rolname = :'runtime_role'),
  'runtime_replication', (SELECT rolreplication FROM role_state WHERE rolname = :'runtime_role'),
  'runtime_schema_create', has_schema_privilege(:'runtime_role', 'public', 'CREATE'),
  'runtime_select_tables', (
    SELECT count(*) FROM public_tables
    WHERE has_table_privilege(:'runtime_role', relation, 'SELECT')
  ),
  'runtime_insert_tables', (
    SELECT count(*) FROM public_tables
    WHERE has_table_privilege(:'runtime_role', relation, 'INSERT')
  ),
  'runtime_update_tables', (
    SELECT count(*) FROM public_tables
    WHERE has_table_privilege(:'runtime_role', relation, 'UPDATE')
  ),
  'runtime_delete_tables', (
    SELECT count(*) FROM public_tables
    WHERE has_table_privilege(:'runtime_role', relation, 'DELETE')
  ),
  'runtime_ddl_denied', :'runtime_ddl_denied'::boolean,
  'migration_principal', :'migration_role',
  'migration_login', (SELECT rolcanlogin FROM role_state WHERE rolname = :'migration_role'),
  'migration_superuser', (SELECT rolsuper FROM role_state WHERE rolname = :'migration_role'),
  'migration_create_db', (SELECT rolcreatedb FROM role_state WHERE rolname = :'migration_role'),
  'migration_create_role', (SELECT rolcreaterole FROM role_state WHERE rolname = :'migration_role'),
  'migration_replication', (SELECT rolreplication FROM role_state WHERE rolname = :'migration_role'),
  'migration_schema_create', has_schema_privilege(:'migration_role', 'public', 'CREATE'),
  'legacy_owner_tables', (
    SELECT count(*) FROM pg_tables
    WHERE schemaname = 'public' AND tableowner = :'legacy_owner_role'
  ),
  'probe_table_absent', to_regclass(format('public.%I', :'probe_table')) IS NULL
);
SQL
REMOTE_SCRIPT
} | k exec --quiet -i -n "$DATA_NAMESPACE" "$POSTGRES_POD" -- \
  sh -s -- "$RUNTIME_ROLE" "$MIGRATION_ROLE" "$LEGACY_OWNER_ROLE" "$PROBE_TABLE" "$DATABASE_NAME")"

unset runtime_url migration_url

printf '%s\n' "$remote_result" | jq -e \
  --argjson minimum "$MIN_TABLE_COUNT" '
  .runtime_login == true and
  .runtime_superuser == false and
  .runtime_create_db == false and
  .runtime_create_role == false and
  .runtime_replication == false and
  .runtime_schema_create == false and
  .runtime_ddl_denied == true and
  .runtime_select_tables >= $minimum and
  .runtime_insert_tables >= $minimum and
  .runtime_update_tables >= $minimum and
  .runtime_delete_tables >= $minimum and
  .migration_login == true and
  .migration_superuser == false and
  .migration_create_db == false and
  .migration_create_role == false and
  .migration_replication == false and
  .migration_schema_create == true and
  .legacy_owner_tables >= $minimum and
  .probe_table_absent == true
' >/dev/null

jq -n \
  --arg task "$TASK_ID" \
  --arg result 'passed' \
  --argjson runtime_secret_keys "$runtime_keys" \
  --argjson migration_secret_keys "$migration_keys" \
  --arg runtime_secret_state "$runtime_state" \
  --arg migration_secret_state "$migration_state" \
  --argjson database "$remote_result" \
  '{
    task: $task,
    result: $result,
    runtime_secret_keys: $runtime_secret_keys,
    migration_secret_keys: $migration_secret_keys,
    runtime_secret_state: $runtime_secret_state,
    migration_secret_state: $migration_secret_state,
    database: $database,
    credentials_printed: false,
    owner_transfer: false,
    legacy_revoke: false,
    deployment_change: false
  }'
