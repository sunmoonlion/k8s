#!/usr/bin/env bash

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
POSTGRES_NAMESPACE="${POSTGRES_NAMESPACE:-data-platform-dev}"
POSTGRES_POD="${POSTGRES_POD:-postgresql-sunmoonai-0}"
DATABASE_NAME="${DATABASE_NAME:-info_admin}"
STATE_ROOT="${R5_STATE_ROOT:-$HOME/.local/state/sunmoonai/architecture-v2/r5-info}"
CAPTURE_ID="${R5_CAPTURE_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
BACKUP_DIR="$STATE_ROOT/$CAPTURE_ID"
BACKUP_FILE="$BACKUP_DIR/${DATABASE_NAME}.dump"
PARTIAL_FILE="$BACKUP_FILE.partial"

if [[ "$DATABASE_NAME" != "info_admin" ]]; then
  echo "R5 Info backup only accepts DATABASE_NAME=info_admin" >&2
  exit 2
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$STATE_ROOT" "$BACKUP_DIR"

if [[ -e "$BACKUP_FILE" || -e "$PARTIAL_FILE" ]]; then
  echo "backup target already exists: $BACKUP_FILE" >&2
  exit 3
fi

cleanup_partial() {
  rm -f "$PARTIAL_FILE"
}
trap cleanup_partial EXIT INT TERM HUP

env -u DEBUG kubectl \
  --kubeconfig "$KUBECONFIG_PATH" \
  exec \
  --quiet \
  -n "$POSTGRES_NAMESPACE" \
  "$POSTGRES_POD" \
  -- sh -lc '
    database_name="$1"
    pg_dump_bin=/opt/bitnami/postgresql/bin/pg_dump
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
    exec "$pg_dump_bin" \
      -U postgres \
      -d "$database_name" \
      --format=custom \
      --compress=9 \
      --no-comments
  ' sh "$DATABASE_NAME" >"$PARTIAL_FILE"

test -s "$PARTIAL_FILE"
chmod 600 "$PARTIAL_FILE"
mv "$PARTIAL_FILE" "$BACKUP_FILE"
trap - EXIT INT TERM HUP

backup_sha256="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
backup_bytes="$(stat -c '%s' "$BACKUP_FILE")"

jq -n \
  --arg task "R5-INFO-BACKUP" \
  --arg result "passed" \
  --arg database "$DATABASE_NAME" \
  --arg capture_id "$CAPTURE_ID" \
  --arg backup_file "$BACKUP_FILE" \
  --arg sha256 "$backup_sha256" \
  --argjson bytes "$backup_bytes" \
  '{
    task: $task,
    result: $result,
    database: $database,
    capture_id: $capture_id,
    backup_file: $backup_file,
    sha256: $sha256,
    bytes: $bytes,
    contains_secrets_or_business_data: true,
    commit_to_git: false
  }'
