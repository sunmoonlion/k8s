#!/usr/bin/env bash

# Build the canonical Investment target database from a verified Research
# backup. The source research_admin database is never mutated by this command.

set -euo pipefail
umask 077

MODE=plan
REBUILD=false
BACKUP_FILE=""
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="${APP_NAMESPACE:-app-platform-dev}"
DATA_NAMESPACE="${DATA_NAMESPACE:-data-platform-dev}"
POSTGRES_POD="${POSTGRES_POD:-postgresql-sunmoonai-0}"
SOURCE_SECRET="${SOURCE_SECRET:-research-admin-backend-postgresql-conn}"
TARGET_DATABASE="${TARGET_DATABASE:-investment_admin}"
RUNTIME_ROLE="${RUNTIME_ROLE:-investment_backend_user}"
MIGRATION_ROLE="${MIGRATION_ROLE:-investment_backend_user_migration}"
RUNTIME_SECRET="${RUNTIME_SECRET:-investment-backend-postgresql-conn}"
MIGRATION_SECRET="${MIGRATION_SECRET:-investment-backend-migration-postgresql-conn}"
TEMP_SECRET="${TEMP_SECRET:-r5-investment-target-provisioner}"

usage() {
  cat <<'EOF'
Usage: prepare_r5_investment_target_kind.sh BACKUP_FILE [--apply] [--rebuild]

Default is a read-only plan. --apply creates roles/Secrets and restores the
backup into investment_admin. A non-empty target is rejected unless --rebuild
is explicit. research_admin is never changed.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE=apply; shift ;;
    --rebuild) REBUILD=true; shift ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --app-namespace) APP_NAMESPACE="$2"; shift 2 ;;
    --data-namespace) DATA_NAMESPACE="$2"; shift 2 ;;
    --postgres-pod) POSTGRES_POD="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      [[ -z "$BACKUP_FILE" ]] || { echo "multiple backup files supplied" >&2; exit 2; }
      BACKUP_FILE="$1"
      shift
      ;;
  esac
done

[[ -s "$BACKUP_FILE" ]] || { echo "backup file is missing or empty" >&2; exit 3; }
[[ "$TARGET_DATABASE" == "investment_admin" ]] || { echo "unsafe target database" >&2; exit 3; }
for identifier in "$RUNTIME_ROLE" "$MIGRATION_ROLE"; do
  [[ "$identifier" =~ ^[a-z_][a-z0-9_]{0,62}$ ]] || { echo "unsafe PostgreSQL role" >&2; exit 3; }
done

k() {
  env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" --request-timeout=30s "$@"
}

decode() {
  local secret="$1" key="$2"
  k get secret "$secret" -n "$APP_NAMESPACE" -o "jsonpath={.data.${key}}" \
    | base64 --decode
}

postgres_sql() {
  local database="$1" sql="$2"
  k exec --quiet -n "$DATA_NAMESPACE" "$POSTGRES_POD" -- sh -lc '
    database="$1"; sql="$2"
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
    exec /opt/bitnami/postgresql/bin/psql -U postgres -d "$database" -X -At -v ON_ERROR_STOP=1 -c "$sql"
  ' sh "$database" "$sql"
}

target_exists="$(postgres_sql postgres "SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = '$TARGET_DATABASE');")"
target_tables=0
if [[ "$target_exists" == t ]]; then
  target_tables="$(postgres_sql "$TARGET_DATABASE" "SELECT count(*) FROM pg_tables WHERE schemaname='public';")"
fi

printf 'PLAN source_database=research_admin source_mutation=false\n'
printf 'PLAN target_database=%s exists=%s tables=%s rebuild=%s\n' "$TARGET_DATABASE" "$target_exists" "$target_tables" "$REBUILD"
printf 'PLAN backup_sha256=%s\n' "$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
printf 'PLAN runtime_role=%s migration_role=%s\n' "$RUNTIME_ROLE" "$MIGRATION_ROLE"
printf 'PLAN worker_enable=false deployment_change=false route_change=false\n'

if [[ "$MODE" != apply ]]; then
  echo 'PLAN ONLY: rerun with --apply after review'
  exit 0
fi

if (( target_tables > 0 )) && [[ "$REBUILD" != true ]]; then
  echo "non-empty target requires --rebuild" >&2
  exit 4
fi

db_host="$(decode "$SOURCE_SECRET" DB_HOST)"
db_port="$(decode "$SOURCE_SECRET" DB_PORT)"
environment="$(decode "$SOURCE_SECRET" ENVIRONMENT)"
db_engine="$(decode "$SOURCE_SECRET" DB_ENGINE)"
[[ "$db_engine" == postgresql ]] || { echo "source database engine is not PostgreSQL" >&2; exit 5; }

runtime_secret_exists=false
migration_secret_exists=false
k get secret "$RUNTIME_SECRET" -n "$APP_NAMESPACE" >/dev/null 2>&1 && runtime_secret_exists=true
k get secret "$MIGRATION_SECRET" -n "$APP_NAMESPACE" >/dev/null 2>&1 && migration_secret_exists=true

if [[ "$runtime_secret_exists" == true ]]; then
  [[ "$(decode "$RUNTIME_SECRET" APP_DB_USER)" == "$RUNTIME_ROLE" ]] || { echo "runtime Secret role mismatch" >&2; exit 6; }
  runtime_password="$(decode "$RUNTIME_SECRET" APP_DB_PASSWORD)"
else
  runtime_password="$(openssl rand -hex 32)"
fi

if [[ "$migration_secret_exists" == true ]]; then
  [[ "$(decode "$MIGRATION_SECRET" MIGRATION_DATABASE_USER)" == "$MIGRATION_ROLE" ]] || { echo "migration Secret role mismatch" >&2; exit 6; }
  migration_url_existing="$(decode "$MIGRATION_SECRET" MIGRATION_DATABASE_URL)"
  migration_password="$(MIGRATION_URL="$migration_url_existing" python3 -c 'import os; from urllib.parse import urlsplit; print(urlsplit(os.environ["MIGRATION_URL"]).password or "")')"
  unset migration_url_existing
else
  migration_password="$(openssl rand -hex 32)"
fi

[[ "$runtime_password" =~ ^[a-f0-9]{64}$ ]] || { echo "invalid runtime password shape" >&2; exit 7; }
[[ "$migration_password" =~ ^[a-f0-9]{64}$ ]] || { echo "invalid migration password shape" >&2; exit 7; }

cleanup() {
  local rc=$?
  k delete secret "$TEMP_SECRET" -n "$DATA_NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true
  unset runtime_password migration_password runtime_url migration_url
  return "$rc"
}
trap cleanup EXIT INT TERM HUP

k delete secret "$TEMP_SECRET" -n "$DATA_NAMESPACE" --ignore-not-found >/dev/null
k create secret generic "$TEMP_SECRET" -n "$DATA_NAMESPACE" \
  --from-literal=RUNTIME_PASSWORD="$runtime_password" \
  --from-literal=MIGRATION_PASSWORD="$migration_password" >/dev/null

{
  printf "R5_RUNTIME_PASSWORD='%s'\n" "$(k get secret "$TEMP_SECRET" -n "$DATA_NAMESPACE" -o jsonpath='{.data.RUNTIME_PASSWORD}' | base64 --decode)"
  printf "R5_MIGRATION_PASSWORD='%s'\n" "$(k get secret "$TEMP_SECRET" -n "$DATA_NAMESPACE" -o jsonpath='{.data.MIGRATION_PASSWORD}' | base64 --decode)"
  cat <<'REMOTE'
set -eu
runtime_role="$1"; migration_role="$2"; database="$3"
export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
psql=/opt/bitnami/postgresql/bin/psql
"$psql" -U postgres -d postgres -X -v ON_ERROR_STOP=1 <<SQL
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION', '$runtime_role', '$R5_RUNTIME_PASSWORD')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$runtime_role') \gexec
ALTER ROLE $runtime_role LOGIN PASSWORD '$R5_RUNTIME_PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION', '$migration_role', '$R5_MIGRATION_PASSWORD')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$migration_role') \gexec
ALTER ROLE $migration_role LOGIN PASSWORD '$R5_MIGRATION_PASSWORD' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$database' AND pid<>pg_backend_pid();
DROP DATABASE IF EXISTS $database;
CREATE DATABASE $database OWNER $migration_role;
SQL
REMOTE
} | k exec --quiet -i -n "$DATA_NAMESPACE" "$POSTGRES_POD" -- sh -s -- \
  "$RUNTIME_ROLE" "$MIGRATION_ROLE" "$TARGET_DATABASE" >/dev/null

k exec --quiet -i -n "$DATA_NAMESPACE" "$POSTGRES_POD" -- sh -lc '
  database="$1"
  export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
  exec /opt/bitnami/postgresql/bin/pg_restore -U postgres -d "$database" --exit-on-error --no-owner --no-acl
' sh "$TARGET_DATABASE" <"$BACKUP_FILE"

postgres_sql "$TARGET_DATABASE" "
  ALTER SCHEMA public OWNER TO $MIGRATION_ROLE;
  DO \$body\$
  DECLARE item record;
  BEGIN
    FOR item IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
      EXECUTE format('ALTER TABLE public.%I OWNER TO $MIGRATION_ROLE', item.tablename);
    END LOOP;
    FOR item IN SELECT sequencename FROM pg_sequences WHERE schemaname='public' LOOP
      EXECUTE format('ALTER SEQUENCE public.%I OWNER TO $MIGRATION_ROLE', item.sequencename);
    END LOOP;
  END
  \$body\$;
  GRANT CONNECT ON DATABASE $TARGET_DATABASE TO $RUNTIME_ROLE;
  GRANT CONNECT, CREATE, TEMPORARY ON DATABASE $TARGET_DATABASE TO $MIGRATION_ROLE;
  GRANT USAGE ON SCHEMA public TO $RUNTIME_ROLE;
  REVOKE CREATE ON SCHEMA public FROM $RUNTIME_ROLE;
  GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $RUNTIME_ROLE;
  GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO $RUNTIME_ROLE;
  ALTER DEFAULT PRIVILEGES FOR ROLE $MIGRATION_ROLE IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $RUNTIME_ROLE;
  ALTER DEFAULT PRIVILEGES FOR ROLE $MIGRATION_ROLE IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO $RUNTIME_ROLE;
" >/dev/null

runtime_url="postgresql://${RUNTIME_ROLE}:${runtime_password}@${db_host}:${db_port}/${TARGET_DATABASE}?sslmode=disable"
migration_url="postgresql://${MIGRATION_ROLE}:${migration_password}@${db_host}:${db_port}/${TARGET_DATABASE}?sslmode=disable"

k create secret generic "$RUNTIME_SECRET" -n "$APP_NAMESPACE" \
  --from-literal=SERVICE_NAME=investment-backend \
  --from-literal=ENVIRONMENT="$environment" \
  --from-literal=DB_ENGINE=postgresql \
  --from-literal=DB_HOST="$db_host" \
  --from-literal=DB_PORT="$db_port" \
  --from-literal=APP_DB_NAME="$TARGET_DATABASE" \
  --from-literal=APP_DB_USER="$RUNTIME_ROLE" \
  --from-literal=APP_DB_PASSWORD="$runtime_password" \
  --from-literal=APP_DB_URI="$runtime_url" \
  --from-literal=DATABASE_URL="$runtime_url" \
  --dry-run=client -o yaml | k apply -f - >/dev/null

k create secret generic "$MIGRATION_SECRET" -n "$APP_NAMESPACE" \
  --from-literal=MIGRATION_DATABASE_USER="$MIGRATION_ROLE" \
  --from-literal=MIGRATION_DATABASE_URL="$migration_url" \
  --dry-run=client -o yaml | k apply -f - >/dev/null

k annotate secret "$RUNTIME_SECRET" "$MIGRATION_SECRET" -n "$APP_NAMESPACE" \
  architecture.sunmoonai.com/state=prepared-not-active --overwrite >/dev/null
k label secret "$RUNTIME_SECRET" "$MIGRATION_SECRET" -n "$APP_NAMESPACE" \
  architecture.sunmoonai.com/task=r5-investment --overwrite >/dev/null

runtime_probe="$(PGPASSWORD="$runtime_password" k run r5-investment-runtime-probe -n "$APP_NAMESPACE" --rm -i --restart=Never \
  --image=harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4 \
  --env="PGPASSWORD=$runtime_password" --command -- sh -lc \
  "/opt/bitnami/postgresql/bin/psql -h '$db_host' -p '$db_port' -U '$RUNTIME_ROLE' -d '$TARGET_DATABASE' -X -At -v ON_ERROR_STOP=1 -c 'select current_user, count(*) from agent_sessions group by current_user;'" 2>/dev/null \
  | grep -E "^${RUNTIME_ROLE}\\|[0-9]+$" | tail -n 1)"
[[ "$runtime_probe" == "$RUNTIME_ROLE|29" ]] || { echo "runtime principal/data probe failed" >&2; exit 8; }

k delete secret "$TEMP_SECRET" -n "$DATA_NAMESPACE" --ignore-not-found >/dev/null
trap - EXIT INT TERM HUP
unset runtime_password migration_password runtime_url migration_url

jq -n \
  --arg task R5-INVESTMENT-TARGET-PREPARE \
  --arg result passed \
  --arg database "$TARGET_DATABASE" \
  --arg runtime_role "$RUNTIME_ROLE" \
  --arg migration_role "$MIGRATION_ROLE" \
  --arg backup_sha256 "$(sha256sum "$BACKUP_FILE" | awk '{print $1}')" \
  --argjson rebuild "$REBUILD" \
  '{task:$task,result:$result,database:$database,runtime_role:$runtime_role,migration_role:$migration_role,backup_sha256:$backup_sha256,rebuild:$rebuild,source_database_mutated:false,worker_enabled:false,secrets_printed:false}'
