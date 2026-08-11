#!/usr/bin/env bash

# Prepare the canonical Info Backend PostgreSQL identities for Architecture v2
# R5. The default mode is read-only planning. Mutations require --apply.
#
# This is deliberately a PRE-CUTOVER operation:
# - it does not transfer database/schema/table ownership;
# - it does not revoke any legacy role or Secret;
# - it does not change any Deployment;
# - it never prints passwords or connection URLs.

set -euo pipefail

MODE="plan"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="${APP_NAMESPACE:-app-platform-dev}"
DATA_NAMESPACE="${DATA_NAMESPACE:-data-platform-dev}"
POSTGRES_POD="${POSTGRES_POD:-postgresql-sunmoonai-0}"
SOURCE_RUNTIME_SECRET="${SOURCE_RUNTIME_SECRET:-info-admin-backend-postgresql-conn}"
RUNTIME_SECRET="${RUNTIME_SECRET:-info-backend-postgresql-conn}"
MIGRATION_SECRET="${MIGRATION_SECRET:-info-backend-migration-postgresql-conn}"
RUNTIME_ROLE="${RUNTIME_ROLE:-info_backend_user}"
MIGRATION_ROLE="${MIGRATION_ROLE:-info_backend_user_migration}"
LEGACY_OWNER_ROLE="${LEGACY_OWNER_ROLE:-info_admin_user_migration}"
SERVICE_NAME="${SERVICE_NAME:-info-backend}"
TASK_ID="${TASK_ID:-R5-I2}"
TASK_LABEL="${TASK_LABEL:-r5-info}"
APP_ID="${APP_ID:-info}"
TEMP_SECRET="${TEMP_SECRET:-r5-info-role-provisioner}"

usage() {
  cat <<'EOF'
Usage: provision_r5_info_database_roles_kind.sh [--apply] [options]

Default mode is a read-only plan. --apply is required for every mutation.

Options:
  --apply                         Create/reconcile the two roles and Secrets
  --kubeconfig PATH               Kubeconfig path
  --app-namespace NAME            Application namespace
  --data-namespace NAME           PostgreSQL namespace
  --postgres-pod NAME             PostgreSQL primary Pod
  --source-runtime-secret NAME    Existing Info runtime Secret used for topology
  --runtime-secret NAME           New canonical runtime Secret
  --migration-secret NAME         New canonical migration Secret
  -h, --help                      Show this help

This preparation command does not transfer ownership or revoke legacy access.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE="apply"; shift ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --app-namespace) APP_NAMESPACE="$2"; shift 2 ;;
    --data-namespace) DATA_NAMESPACE="$2"; shift 2 ;;
    --postgres-pod) POSTGRES_POD="$2"; shift 2 ;;
    --source-runtime-secret) SOURCE_RUNTIME_SECRET="$2"; shift 2 ;;
    --runtime-secret) RUNTIME_SECRET="$2"; shift 2 ;;
    --migration-secret) MIGRATION_SECRET="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

k() {
  env -u DEBUG kubectl \
    --kubeconfig "$KUBECONFIG_PATH" \
    --request-timeout=15s \
    "$@"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 3
  }
}

require_identifier() {
  local label="$1" value="$2"
  if [[ ! "$value" =~ ^[a-z_][a-z0-9_]{0,62}$ ]]; then
    printf '%s is not a safe PostgreSQL identifier\n' "$label" >&2
    exit 4
  fi
}

decode_secret_key() {
  local namespace="$1" secret="$2" key="$3" encoded
  encoded="$(
    k get secret "$secret" \
      -n "$namespace" \
      -o "jsonpath={.data.${key}}" 2>/dev/null || true
  )"
  [[ -n "$encoded" ]] || return 1
  printf '%s' "$encoded" | base64 --decode
}

secret_keys() {
  local namespace="$1" secret="$2"
  k get secret "$secret" -n "$namespace" -o json \
    | jq -c '[.data | keys[]]'
}

postgres_sql() {
  local database="$1" sql="$2"
  k exec --quiet -n "$DATA_NAMESPACE" "$POSTGRES_POD" -- sh -lc '
    database="$1"
    sql="$2"
    psql_bin=/opt/bitnami/postgresql/bin/psql
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
    exec "$psql_bin" \
      -U postgres \
      -d "$database" \
      -X \
      -v ON_ERROR_STOP=1 \
      -At \
      -c "$sql"
  ' sh "$database" "$sql"
}

cleanup_temp_secret() {
  k delete secret "$TEMP_SECRET" \
    -n "$DATA_NAMESPACE" \
    --ignore-not-found >/dev/null 2>&1 || true
}

cleanup() {
  local exit_code=$?
  cleanup_temp_secret
  unset runtime_password migration_password app_db_uri database_url migration_url
  return "$exit_code"
}

for command in kubectl jq base64 openssl python3; do
  require_command "$command"
done
require_identifier RUNTIME_ROLE "$RUNTIME_ROLE"
require_identifier MIGRATION_ROLE "$MIGRATION_ROLE"
require_identifier LEGACY_OWNER_ROLE "$LEGACY_OWNER_ROLE"
[[ "$RUNTIME_ROLE" != "$MIGRATION_ROLE" ]] || {
  echo 'runtime and migration roles must differ' >&2
  exit 4
}

k get namespace "$APP_NAMESPACE" >/dev/null
k get namespace "$DATA_NAMESPACE" >/dev/null
k get pod "$POSTGRES_POD" -n "$DATA_NAMESPACE" >/dev/null
k get secret "$SOURCE_RUNTIME_SECRET" -n "$APP_NAMESPACE" >/dev/null

db_host="$(decode_secret_key "$APP_NAMESPACE" "$SOURCE_RUNTIME_SECRET" DB_HOST)"
db_port="$(decode_secret_key "$APP_NAMESPACE" "$SOURCE_RUNTIME_SECRET" DB_PORT)"
db_name="$(decode_secret_key "$APP_NAMESPACE" "$SOURCE_RUNTIME_SECRET" APP_DB_NAME)"
db_engine="$(decode_secret_key "$APP_NAMESPACE" "$SOURCE_RUNTIME_SECRET" DB_ENGINE)"
environment="$(decode_secret_key "$APP_NAMESPACE" "$SOURCE_RUNTIME_SECRET" ENVIRONMENT)"

require_identifier APP_DB_NAME "$db_name"
[[ "$db_port" =~ ^[0-9]{2,5}$ ]] || {
  echo 'source DB_PORT is invalid' >&2
  exit 5
}
[[ "$db_engine" == "postgresql" ]] || {
  echo 'source DB_ENGINE is not postgresql' >&2
  exit 5
}
[[ -n "$db_host" && -n "$environment" ]] || {
  echo 'source database topology is incomplete' >&2
  exit 5
}

legacy_owner_exists="$(postgres_sql "$db_name" "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$LEGACY_OWNER_ROLE');")"
[[ "$legacy_owner_exists" == "t" ]] || {
  echo 'legacy owner role is missing; refusing to prepare R5 identities' >&2
  exit 6
}

runtime_exists="$(postgres_sql "$db_name" "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$RUNTIME_ROLE');")"
migration_exists="$(postgres_sql "$db_name" "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$MIGRATION_ROLE');")"
runtime_secret_exists=false
migration_secret_exists=false
k get secret "$RUNTIME_SECRET" -n "$APP_NAMESPACE" >/dev/null 2>&1 && runtime_secret_exists=true
k get secret "$MIGRATION_SECRET" -n "$APP_NAMESPACE" >/dev/null 2>&1 && migration_secret_exists=true

printf 'PLAN task=%s app=%s database=%s\n' "$TASK_ID" "$APP_ID" "$db_name"
printf 'PLAN role=%s exists=%s purpose=api-worker-scheduler\n' "$RUNTIME_ROLE" "$runtime_exists"
printf 'PLAN role=%s exists=%s purpose=migration-only\n' "$MIGRATION_ROLE" "$migration_exists"
printf 'PLAN secret=%s/%s exists=%s purpose=runtime\n' "$APP_NAMESPACE" "$RUNTIME_SECRET" "$runtime_secret_exists"
printf 'PLAN secret=%s/%s exists=%s purpose=migration\n' "$APP_NAMESPACE" "$MIGRATION_SECRET" "$migration_secret_exists"
printf 'PLAN owner_transfer=false legacy_revoke=false deployment_change=false\n'

if [[ "$MODE" != "apply" ]]; then
  echo 'PLAN ONLY: rerun with --apply after review'
  exit 0
fi

trap cleanup EXIT INT TERM HUP
umask 077

if [[ "$runtime_secret_exists" == "true" ]]; then
  runtime_secret_user="$(decode_secret_key "$APP_NAMESPACE" "$RUNTIME_SECRET" APP_DB_USER)"
  [[ "$runtime_secret_user" == "$RUNTIME_ROLE" ]] || {
    echo 'existing runtime Secret names a different role' >&2
    exit 7
  }
  runtime_password="$(decode_secret_key "$APP_NAMESPACE" "$RUNTIME_SECRET" APP_DB_PASSWORD)"
else
  runtime_password="$(openssl rand -hex 32)"
fi

if [[ "$migration_secret_exists" == "true" ]]; then
  migration_secret_user="$(decode_secret_key "$APP_NAMESPACE" "$MIGRATION_SECRET" MIGRATION_DATABASE_USER)"
  [[ "$migration_secret_user" == "$MIGRATION_ROLE" ]] || {
    echo 'existing migration Secret names a different role' >&2
    exit 7
  }
  migration_url_existing="$(decode_secret_key "$APP_NAMESPACE" "$MIGRATION_SECRET" MIGRATION_DATABASE_URL)"
  migration_password="$(
    MIGRATION_URL="$migration_url_existing" python3 -c '
import os
from urllib.parse import urlsplit

password = urlsplit(os.environ["MIGRATION_URL"]).password
if not password:
    raise SystemExit("migration URL has no password")
print(password)
'
  )"
  unset migration_url_existing
else
  migration_password="$(openssl rand -hex 32)"
fi

[[ "$runtime_password" =~ ^[a-f0-9]{64}$ ]] || {
  echo 'runtime password must be a 64-character hex value' >&2
  exit 8
}
[[ "$migration_password" =~ ^[a-f0-9]{64}$ ]] || {
  echo 'migration password must be a 64-character hex value' >&2
  exit 8
}

cleanup_temp_secret
jq -n \
  --arg namespace "$DATA_NAMESPACE" \
  --arg name "$TEMP_SECRET" \
  --arg task_label "$TASK_LABEL" \
  --arg runtime_password "$(printf '%s' "$runtime_password" | base64 --wrap=0)" \
  --arg migration_password "$(printf '%s' "$migration_password" | base64 --wrap=0)" \
  '{
    apiVersion: "v1",
    kind: "Secret",
    metadata: {
      namespace: $namespace,
      name: $name,
      labels: {"architecture.sunmoonai.com/task": $task_label}
    },
    type: "Opaque",
    data: {
      RUNTIME_PASSWORD: $runtime_password,
      MIGRATION_PASSWORD: $migration_password
    }
  }' | k apply -f - >/dev/null

{
  printf "R5_RUNTIME_PASSWORD='%s'\n" \
    "$(decode_secret_key "$DATA_NAMESPACE" "$TEMP_SECRET" RUNTIME_PASSWORD)"
  printf "R5_MIGRATION_PASSWORD='%s'\n" \
    "$(decode_secret_key "$DATA_NAMESPACE" "$TEMP_SECRET" MIGRATION_PASSWORD)"
  cat <<'REMOTE_SCRIPT'
set -eu
(
    runtime_role="$1"
    migration_role="$2"
    legacy_owner_role="$3"
    database="$4"
    psql_bin=/opt/bitnami/postgresql/bin/psql
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"

    "$psql_bin" -U postgres -d postgres -X -v ON_ERROR_STOP=1 \
      --set=runtime_role="$runtime_role" \
      --set=runtime_password="$R5_RUNTIME_PASSWORD" \
      --set=migration_role="$migration_role" \
      --set=migration_password="$R5_MIGRATION_PASSWORD" \
      --set=database="$database" <<'SQL'
    SELECT format(
      'CREATE ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION',
      :'runtime_role', :'runtime_password'
    )
    WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'runtime_role') \gexec
    SELECT format(
      'ALTER ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION',
      :'runtime_role', :'runtime_password'
    ) \gexec
    SELECT format(
      'CREATE ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION',
      :'migration_role', :'migration_password'
    )
    WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'migration_role') \gexec
    SELECT format(
      'ALTER ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION',
      :'migration_role', :'migration_password'
    ) \gexec
    SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'database', :'runtime_role') \gexec
    SELECT format('GRANT CONNECT, CREATE, TEMPORARY ON DATABASE %I TO %I', :'database', :'migration_role') \gexec
SQL

    "$psql_bin" -U postgres -d "$database" -X -v ON_ERROR_STOP=1 \
      --set=runtime_role="$runtime_role" \
      --set=migration_role="$migration_role" \
      --set=legacy_owner_role="$legacy_owner_role" <<'SQL'
    SELECT format('GRANT USAGE ON SCHEMA public TO %I', :'runtime_role') \gexec
    SELECT format('REVOKE CREATE ON SCHEMA public FROM %I', :'runtime_role') \gexec
    SELECT format(
      'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO %I',
      :'runtime_role'
    ) \gexec
    SELECT format(
      'GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO %I',
      :'runtime_role'
    ) \gexec

    SELECT format('GRANT USAGE, CREATE ON SCHEMA public TO %I', :'migration_role') \gexec
    SELECT format(
      'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO %I',
      :'migration_role'
    ) \gexec
    SELECT format(
      'GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO %I',
      :'migration_role'
    ) \gexec
    SELECT format(
      'GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO %I',
      :'migration_role'
    ) \gexec

    SELECT format(
      'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I',
      :'legacy_owner_role', :'runtime_role'
    ) \gexec
    SELECT format(
      'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO %I',
      :'legacy_owner_role', :'runtime_role'
    ) \gexec
    SELECT format(
      'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I',
      :'migration_role', :'runtime_role'
    ) \gexec
    SELECT format(
      'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO %I',
      :'migration_role', :'runtime_role'
    ) \gexec
SQL
)
REMOTE_SCRIPT
} | k exec --quiet -i -n "$DATA_NAMESPACE" "$POSTGRES_POD" \
  -- sh -s -- "$RUNTIME_ROLE" "$MIGRATION_ROLE" "$LEGACY_OWNER_ROLE" "$db_name" \
  >/dev/null

app_db_uri="postgresql://${RUNTIME_ROLE}:${runtime_password}@${db_host}:${db_port}/${db_name}?sslmode=disable"
database_url="$app_db_uri"
migration_url="postgresql://${MIGRATION_ROLE}:${migration_password}@${db_host}:${db_port}/${db_name}?sslmode=disable"

jq -n \
  --arg namespace "$APP_NAMESPACE" \
  --arg name "$RUNTIME_SECRET" \
  --arg service_name "$SERVICE_NAME" \
  --arg task_label "$TASK_LABEL" \
  --arg environment "$environment" \
  --arg db_engine "$db_engine" \
  --arg db_host "$db_host" \
  --arg db_port "$db_port" \
  --arg db_name "$db_name" \
  --arg db_user "$RUNTIME_ROLE" \
  --arg db_password "$runtime_password" \
  --arg db_uri "$app_db_uri" \
  --arg database_url "$database_url" \
  'def b64: @base64;
  {
    apiVersion: "v1",
    kind: "Secret",
    metadata: {
      namespace: $namespace,
      name: $name,
      labels: {
        "app.kubernetes.io/name": $service_name,
        "app.kubernetes.io/component": "database-runtime",
        "architecture.sunmoonai.com/task": $task_label
      },
      annotations: {"architecture.sunmoonai.com/state": "prepared-not-active"}
    },
    type: "Opaque",
    data: {
      SERVICE_NAME: ($service_name | b64),
      ENVIRONMENT: ($environment | b64),
      DB_ENGINE: ($db_engine | b64),
      DB_HOST: ($db_host | b64),
      DB_PORT: ($db_port | b64),
      APP_DB_NAME: ($db_name | b64),
      APP_DB_USER: ($db_user | b64),
      APP_DB_PASSWORD: ($db_password | b64),
      APP_DB_URI: ($db_uri | b64),
      DATABASE_URL: ($database_url | b64)
    }
  }' | k apply -f - >/dev/null

jq -n \
  --arg namespace "$APP_NAMESPACE" \
  --arg name "$MIGRATION_SECRET" \
  --arg service_name "$SERVICE_NAME" \
  --arg task_label "$TASK_LABEL" \
  --arg migration_user "$MIGRATION_ROLE" \
  --arg migration_url "$migration_url" \
  'def b64: @base64;
  {
    apiVersion: "v1",
    kind: "Secret",
    metadata: {
      namespace: $namespace,
      name: $name,
      labels: {
        "app.kubernetes.io/name": $service_name,
        "app.kubernetes.io/component": "database-migration",
        "architecture.sunmoonai.com/task": $task_label
      },
      annotations: {"architecture.sunmoonai.com/state": "prepared-not-active"}
    },
    type: "Opaque",
    data: {
      MIGRATION_DATABASE_USER: ($migration_user | b64),
      MIGRATION_DATABASE_URL: ($migration_url | b64)
    }
  }' | k apply -f - >/dev/null

cleanup_temp_secret

role_audit="$(postgres_sql "$db_name" "
  WITH public_tables AS (
    SELECT format('%I.%I', schemaname, tablename) AS relation
    FROM pg_tables
    WHERE schemaname = 'public'
  )
  SELECT jsonb_build_object(
    'runtime_role', '$RUNTIME_ROLE',
    'runtime_login', (SELECT rolcanlogin FROM pg_roles WHERE rolname = '$RUNTIME_ROLE'),
    'runtime_superuser', (SELECT rolsuper FROM pg_roles WHERE rolname = '$RUNTIME_ROLE'),
    'runtime_schema_create', has_schema_privilege('$RUNTIME_ROLE', 'public', 'CREATE'),
    'runtime_select_tables', (SELECT count(*) FROM public_tables WHERE has_table_privilege('$RUNTIME_ROLE', relation, 'SELECT')),
    'migration_role', '$MIGRATION_ROLE',
    'migration_login', (SELECT rolcanlogin FROM pg_roles WHERE rolname = '$MIGRATION_ROLE'),
    'migration_superuser', (SELECT rolsuper FROM pg_roles WHERE rolname = '$MIGRATION_ROLE'),
    'migration_schema_create', has_schema_privilege('$MIGRATION_ROLE', 'public', 'CREATE'),
    'legacy_owner_preserved', NOT EXISTS (
      SELECT 1 FROM pg_tables
      WHERE schemaname = 'public' AND tableowner <> '$LEGACY_OWNER_ROLE'
    )
  );
")"

printf 'APPLIED task=%s state=prepared-not-active\n' "$TASK_ID"
printf 'runtime_secret_keys=%s\n' "$(secret_keys "$APP_NAMESPACE" "$RUNTIME_SECRET")"
printf 'migration_secret_keys=%s\n' "$(secret_keys "$APP_NAMESPACE" "$MIGRATION_SECRET")"
printf 'role_audit=%s\n' "$role_audit"
printf 'owner_transfer=false legacy_revoke=false deployment_change=false\n'
