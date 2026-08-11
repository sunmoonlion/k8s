#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 BACKUP_FILE IMAGE_DIGEST_REFERENCE" >&2
  exit 2
fi

BACKUP_FILE="$1"
IMAGE="$2"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="${APP_NAMESPACE:-app-platform-dev}"
POSTGRES_NAMESPACE="${POSTGRES_NAMESPACE:-data-platform-dev}"
POSTGRES_POD="${POSTGRES_POD:-postgresql-sunmoonai-0}"
RESTORE_DATABASE="${RESTORE_DATABASE:-investment_r5_restore_roundtrip_20260811}"
SOURCE_MIGRATION_SECRET="${SOURCE_MIGRATION_SECRET:-research-admin-backend-migration-postgresql-conn}"
ROUNDTRIP_SECRET="r5-investment-migration-roundtrip-db"
IMAGE_PULL_SECRET="${IMAGE_PULL_SECRET:-harbor-registry-secret}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d /tmp/r5-investment-roundtrip.XXXXXX)"

if [[ "$IMAGE" != *@sha256:* ]]; then
  echo "IMAGE_DIGEST_REFERENCE must use an immutable sha256 digest" >&2
  exit 3
fi

if [[ ! -s "$BACKUP_FILE" ]]; then
  echo "backup file is missing or empty: $BACKUP_FILE" >&2
  exit 4
fi

kubectl_cmd() {
  env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"
}

postgres_sql() {
  local sql="$1"

  kubectl_cmd exec --quiet -n "$POSTGRES_NAMESPACE" "$POSTGRES_POD" -- sh -lc '
    sql="$1"
    psql_bin=/opt/bitnami/postgresql/bin/psql
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
    exec "$psql_bin" -U postgres -d postgres -X -v ON_ERROR_STOP=1 -At -c "$sql"
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

cleanup() {
  local exit_code=$?

  kubectl_cmd delete job -n "$APP_NAMESPACE" \
    -l architecture.sunmoonai.com/r5-investment-roundtrip=true \
    --ignore-not-found --wait=true >/dev/null 2>&1 || true
  kubectl_cmd delete secret "$ROUNDTRIP_SECRET" -n "$APP_NAMESPACE" \
    --ignore-not-found >/dev/null 2>&1 || true
  drop_restore_database >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
  return "$exit_code"
}
trap cleanup EXIT INT TERM HUP

extract_section_json() {
  local file="$1"
  local section="$2"

  awk -v marker="section=$section" '
    $0 == marker {getline; print; exit}
  ' "$file"
}

run_migration_job() {
  local suffix="$1"
  shift
  local job_name="r5-investment-migration-$suffix"
  local command_json

  command_json="$(printf '%s\n' "$@" | jq -R . | jq -sc .)"
  kubectl_cmd delete job "$job_name" -n "$APP_NAMESPACE" \
    --ignore-not-found --wait=true >/dev/null

  jq -n \
    --arg namespace "$APP_NAMESPACE" \
    --arg name "$job_name" \
    --arg image "$IMAGE" \
    --arg image_pull_secret "$IMAGE_PULL_SECRET" \
    --arg secret "$ROUNDTRIP_SECRET" \
    --argjson command "$command_json" \
    '{
      apiVersion: "batch/v1",
      kind: "Job",
      metadata: {
        namespace: $namespace,
        name: $name,
        labels: {"architecture.sunmoonai.com/r5-investment-roundtrip": "true"}
      },
      spec: {
        backoffLimit: 0,
        template: {
          metadata: {
            labels: {"architecture.sunmoonai.com/r5-investment-roundtrip": "true"}
          },
          spec: {
            automountServiceAccountToken: false,
            restartPolicy: "Never",
            imagePullSecrets: [{name: $image_pull_secret}],
            securityContext: {
              runAsNonRoot: true,
              runAsUser: 1001,
              runAsGroup: 1001,
              fsGroup: 1001,
              seccompProfile: {type: "RuntimeDefault"}
            },
            containers: [{
              name: "migration",
              image: $image,
              imagePullPolicy: "IfNotPresent",
              command: $command,
              envFrom: [{secretRef: {name: $secret}}],
              securityContext: {
                allowPrivilegeEscalation: false,
                capabilities: {drop: ["ALL"]},
                runAsNonRoot: true,
                runAsUser: 1001,
                runAsGroup: 1001,
                readOnlyRootFilesystem: true
              }
            }]
          }
        }
      }
    }' | kubectl_cmd apply -f - >/dev/null

  if ! kubectl_cmd wait --for=condition=complete "job/$job_name" \
    -n "$APP_NAMESPACE" --timeout=180s >/dev/null; then
    kubectl_cmd describe job "$job_name" -n "$APP_NAMESPACE" >&2 || true
    kubectl_cmd logs "job/$job_name" -n "$APP_NAMESPACE" >&2 || true
    return 1
  fi

  kubectl_cmd logs "job/$job_name" -n "$APP_NAMESPACE"
  kubectl_cmd delete job "$job_name" -n "$APP_NAMESPACE" --wait=true >/dev/null
}

KEEP_RESTORE_DATABASE=true \
  KUBECONFIG="$KUBECONFIG_PATH" \
  "$SCRIPT_DIR/restore_r5_investment_database_kind.sh" \
  "$BACKUP_FILE" "$RESTORE_DATABASE" >"$WORK_DIR/baseline.txt"

source_url_b64="$(
  kubectl_cmd get secret "$SOURCE_MIGRATION_SECRET" -n "$APP_NAMESPACE" \
    -o jsonpath='{.data.MIGRATION_DATABASE_URL}'
)"
source_url="$(printf '%s' "$source_url_b64" | base64 --decode)"
target_url="$(
  SOURCE_URL="$source_url" TARGET_DATABASE="$RESTORE_DATABASE" python3 -c '
import os
from urllib.parse import urlsplit, urlunsplit

source = urlsplit(os.environ["SOURCE_URL"])
target = os.environ["TARGET_DATABASE"]
print(urlunsplit((source.scheme, source.netloc, f"/{target}", source.query, source.fragment)))
'
)"
unset source_url source_url_b64

target_url_b64="$(printf '%s' "$target_url" | base64 --wrap=0)"
unset target_url

jq -n \
  --arg namespace "$APP_NAMESPACE" \
  --arg name "$ROUNDTRIP_SECRET" \
  --arg database_url "$target_url_b64" \
  '{
    apiVersion: "v1",
    kind: "Secret",
    metadata: {namespace: $namespace, name: $name},
    type: "Opaque",
    data: {
      DATABASE_URL: $database_url,
      MIGRATION_DATABASE_URL: $database_url
    }
  }' | kubectl_cmd apply -f - >/dev/null
unset target_url_b64

run_migration_job upgrade \
  /app/.venv/bin/python -m app.bootstrap.migration upgrade head \
  >"$WORK_DIR/upgrade.log"
"$SCRIPT_DIR/audit_r5_investment_database_kind.sh" "$RESTORE_DATABASE" \
  >"$WORK_DIR/after-upgrade.txt"

run_migration_job downgrade \
  /app/.venv/bin/alembic -c /app/alembic.ini downgrade 20260712_0002 \
  >"$WORK_DIR/downgrade.log"
"$SCRIPT_DIR/audit_r5_investment_database_kind.sh" "$RESTORE_DATABASE" \
  >"$WORK_DIR/after-downgrade.txt"

run_migration_job reupgrade \
  /app/.venv/bin/python -m app.bootstrap.migration upgrade head \
  >"$WORK_DIR/reupgrade.log"
"$SCRIPT_DIR/audit_r5_investment_database_kind.sh" "$RESTORE_DATABASE" \
  >"$WORK_DIR/after-reupgrade.txt"

baseline_counts="$(extract_section_json "$WORK_DIR/baseline.txt" table_counts)"
upgrade_counts="$(extract_section_json "$WORK_DIR/after-upgrade.txt" table_counts)"
downgrade_counts="$(extract_section_json "$WORK_DIR/after-downgrade.txt" table_counts)"
reupgrade_counts="$(extract_section_json "$WORK_DIR/after-reupgrade.txt" table_counts)"

business_filter='del(.agent_pilot_requests, .agent_pilot_controls, .outbox_message, .inbox_message)'
baseline_business="$(printf '%s' "$baseline_counts" | jq -cS "$business_filter")"
upgrade_business="$(printf '%s' "$upgrade_counts" | jq -cS "$business_filter")"
downgrade_business="$(printf '%s' "$downgrade_counts" | jq -cS "$business_filter")"
reupgrade_business="$(printf '%s' "$reupgrade_counts" | jq -cS "$business_filter")"

test "$baseline_business" = "$upgrade_business"
test "$baseline_business" = "$downgrade_business"
test "$baseline_business" = "$reupgrade_business"
test "$(printf '%s' "$upgrade_counts" | jq -r '.outbox_message')" = "0"
test "$(printf '%s' "$upgrade_counts" | jq -r '.inbox_message')" = "0"
test "$(printf '%s' "$upgrade_counts" | jq -r '.agent_pilot_requests')" = "0"
test "$(printf '%s' "$upgrade_counts" | jq -r '.agent_pilot_controls')" = "0"
test "$(printf '%s' "$downgrade_counts" | jq -r 'has("outbox_message")')" = "false"
test "$(printf '%s' "$downgrade_counts" | jq -r 'has("inbox_message")')" = "false"
test "$(printf '%s' "$downgrade_counts" | jq -r 'has("agent_pilot_requests")')" = "false"
test "$(printf '%s' "$downgrade_counts" | jq -r 'has("agent_pilot_controls")')" = "false"
test "$(printf '%s' "$reupgrade_counts" | jq -r '.outbox_message')" = "0"
test "$(printf '%s' "$reupgrade_counts" | jq -r '.inbox_message')" = "0"
test "$(printf '%s' "$reupgrade_counts" | jq -r '.agent_pilot_requests')" = "0"
test "$(printf '%s' "$reupgrade_counts" | jq -r '.agent_pilot_controls')" = "0"

test "$(extract_section_json "$WORK_DIR/after-upgrade.txt" alembic_heads)" = '["20260809_0004"]'
test "$(extract_section_json "$WORK_DIR/after-downgrade.txt" alembic_heads)" = '["20260712_0002"]'
test "$(extract_section_json "$WORK_DIR/after-reupgrade.txt" alembic_heads)" = '["20260809_0004"]'

for phase in after-upgrade after-downgrade after-reupgrade; do
  invariants="$(extract_section_json "$WORK_DIR/$phase.txt" investment_invariants)"
  test "$(printf '%s' "$invariants" | jq '[.[]] | add')" = "0"
done

echo "section=result"
jq -n \
  --arg task "R5-INVESTMENT-MIGRATION-ROUNDTRIP" \
  --arg result "passed" \
  --arg image "$IMAGE" \
  --arg backup_sha256 "$(sha256sum "$BACKUP_FILE" | awk '{print $1}')" \
  --argjson baseline_counts "$baseline_counts" \
  --argjson upgraded_counts "$upgrade_counts" \
  --argjson downgraded_counts "$downgrade_counts" \
  --argjson reupgraded_counts "$reupgrade_counts" \
  '{
    task: $task,
    result: $result,
    image: $image,
    backup_sha256: $backup_sha256,
    heads: {
      baseline: "20260712_0002",
      upgraded: "20260809_0004",
      downgraded: "20260712_0002",
      reupgraded: "20260809_0004"
    },
    counts: {
      baseline: $baseline_counts,
      upgraded: $upgraded_counts,
      downgraded: $downgraded_counts,
      reupgraded: $reupgraded_counts
    },
    business_counts_unchanged: true,
    invariant_failures: 0,
    temporary_database_cleanup: "on-exit",
    temporary_secret_cleanup: "on-exit",
    temporary_jobs_cleanup: "on-exit"
  }'

drop_restore_database
kubectl_cmd delete secret "$ROUNDTRIP_SECRET" -n "$APP_NAMESPACE" \
  --ignore-not-found >/dev/null
rm -rf "$WORK_DIR"
trap - EXIT INT TERM HUP

echo "section=cleanup"
jq -n \
  --arg database "$RESTORE_DATABASE" \
  --arg database_exists "$(postgres_sql "SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = '$RESTORE_DATABASE');")" \
  --arg secret_exists "$(kubectl_cmd get secret "$ROUNDTRIP_SECRET" -n "$APP_NAMESPACE" --ignore-not-found -o name)" \
  --arg jobs "$(kubectl_cmd get job -n "$APP_NAMESPACE" -l architecture.sunmoonai.com/r5-investment-roundtrip=true -o name)" \
  '{
    restore_database: $database,
    restore_database_exists: ($database_exists == "t"),
    temporary_secret_exists: ($secret_exists != ""),
    temporary_jobs_exist: ($jobs != "")
  }'
