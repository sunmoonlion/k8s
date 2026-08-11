#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 BACKUP_FILE [RESTORE_DATABASE]" >&2
  exit 2
fi

BACKUP_FILE="$1"
RESTORE_DATABASE="${2:-investment_r5_restore_$(date -u +%Y%m%d%H%M%S)}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
POSTGRES_NAMESPACE="${POSTGRES_NAMESPACE:-data-platform-dev}"
POSTGRES_POD="${POSTGRES_POD:-postgresql-sunmoonai-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEEP_RESTORE_DATABASE="${KEEP_RESTORE_DATABASE:-false}"

if [[ ! -s "$BACKUP_FILE" ]]; then
  echo "backup file is missing or empty: $BACKUP_FILE" >&2
  exit 3
fi

if [[ ! "$RESTORE_DATABASE" =~ ^investment_r5_restore_[a-zA-Z0-9_]+$ ]]; then
  echo "unsafe restore database name: $RESTORE_DATABASE" >&2
  exit 4
fi

postgres_sql() {
  local sql="$1"

  env -u DEBUG kubectl \
    --kubeconfig "$KUBECONFIG_PATH" \
    exec \
    --quiet \
    -n "$POSTGRES_NAMESPACE" \
    "$POSTGRES_POD" \
    -- sh -lc '
      sql="$1"
      psql_bin=/opt/bitnami/postgresql/bin/psql
      export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
      exec "$psql_bin" \
        -U postgres \
        -d postgres \
        -X \
        -v ON_ERROR_STOP=1 \
        -At \
        -c "$sql"
    ' sh "$sql"
}

drop_restore_database() {
  postgres_sql "
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = '$RESTORE_DATABASE'
      AND pid <> pg_backend_pid();
  " >/dev/null
  postgres_sql "DROP DATABASE IF EXISTS \"$RESTORE_DATABASE\";" >/dev/null
}

trap drop_restore_database EXIT INT TERM HUP

drop_restore_database
postgres_sql "CREATE DATABASE \"$RESTORE_DATABASE\" OWNER research_admin_user_migration;" >/dev/null

env -u DEBUG kubectl \
  --kubeconfig "$KUBECONFIG_PATH" \
  exec \
  --quiet \
  -i \
  -n "$POSTGRES_NAMESPACE" \
  "$POSTGRES_POD" \
  -- sh -lc '
    database_name="$1"
    pg_restore_bin=/opt/bitnami/postgresql/bin/pg_restore
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
    exec "$pg_restore_bin" \
      -U postgres \
      -d "$database_name" \
      --exit-on-error
  ' sh "$RESTORE_DATABASE" <"$BACKUP_FILE"

echo "section=restore_result"
jq -n \
  --arg task "R5-INVESTMENT-RESTORE" \
  --arg result "passed" \
  --arg database "$RESTORE_DATABASE" \
  --arg backup_sha256 "$(sha256sum "$BACKUP_FILE" | awk '{print $1}')" \
  '{
    task: $task,
    result: $result,
    restore_database: $database,
    backup_sha256: $backup_sha256,
    cleanup_on_exit: true
  }'

"$SCRIPT_DIR/audit_r5_investment_database_kind.sh" "$RESTORE_DATABASE"

if [[ "$KEEP_RESTORE_DATABASE" == "true" ]]; then
  trap - EXIT INT TERM HUP
  echo "section=cleanup"
  jq -n \
    --arg database "$RESTORE_DATABASE" \
    '{restore_database: $database, cleanup_deferred_to_caller: true}'
else
  drop_restore_database
  trap - EXIT INT TERM HUP

  echo "section=cleanup"
  jq -n \
    --arg database "$RESTORE_DATABASE" \
    --arg exists "$(postgres_sql "SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = '$RESTORE_DATABASE');")" \
    '{restore_database: $database, exists_after_cleanup: ($exists == "t")}'
fi
