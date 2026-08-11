#!/usr/bin/env bash

# Reversible Knowledge R5 cutover for the long-lived development KIND cluster.
# No v1 asset, Secret, database, provider entity or protected image is deleted.

set -euo pipefail
umask 077

ACTION="plan"
BUNDLE=""
OVERLAY=""
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
NAMESPACE="app-platform-dev"
CAPTURE_ID="r5-knowledge-cutover-$(date -u +%Y%m%dT%H%M%SZ)"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="$(cd -- "$SCRIPT_DIR/../sql" && pwd)"
ROLLBACK_ARMED=false
IN_ROLLBACK=false

usage() {
  cat <<'EOF'
Usage: cutover_r5_knowledge_kind.sh [plan|apply|rollback] --bundle DIR --overlay DIR

apply freezes the legacy API/Worker, verifies the production queue is empty,
takes a private backup, applies additive migration 0004, transfers ownership,
starts one R5 Worker/Scheduler and switches the formal Admin/Web routes.
rollback restores legacy identities, ingress and workloads while retaining 0004.
EOF
}

if [[ $# -gt 0 && "$1" =~ ^(plan|apply|rollback)$ ]]; then ACTION="$1"; shift; fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle) BUNDLE="$2"; shift 2 ;;
    --overlay) OVERLAY="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --capture-id) CAPTURE_ID="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ -n "$BUNDLE" && -f "$BUNDLE/release.json" ]] || { usage >&2; exit 2; }
[[ -n "$OVERLAY" && -f "$OVERLAY/50-formal-config.yaml" ]] || { usage >&2; exit 2; }
[[ "$NAMESPACE" == "app-platform-dev" ]] || {
  echo "Knowledge R5 formal manifests are pinned to namespace app-platform-dev; got: $NAMESPACE" >&2
  exit 2
}
BUNDLE="$(cd -- "$BUNDLE" && pwd)"
OVERLAY="$(cd -- "$OVERLAY" && pwd)"

k() {
  env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" \
    --request-timeout=20s "$@"
}

postgres_value() {
  local sql="$1"
  k exec --quiet -n data-platform-dev postgresql-sunmoonai-0 -- sh -lc '
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
    exec /opt/bitnami/postgresql/bin/psql \
      -U postgres -d knowledge_admin -X -v ON_ERROR_STOP=1 -At -c "$1"
  ' sh "$sql"
}

postgres_file() {
  local file="$1"
  k exec --quiet -i -n data-platform-dev postgresql-sunmoonai-0 -- sh -lc '
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
    exec /opt/bitnami/postgresql/bin/psql -U postgres -d knowledge_admin -X
  ' <"$file"
}

scale() {
  local replicas="$1"; shift
  local name
  for name in "$@"; do
    k scale deployment "$name" -n "$NAMESPACE" --replicas="$replicas" >/dev/null
  done
}

wait_rollout() {
  local name
  for name in "$@"; do
    k rollout status "deployment/$name" -n "$NAMESPACE" --timeout=240s >/dev/null
  done
}

queue_counts() {
  k exec --quiet -n messaging-platform-dev rabbitmq-sunmoonai-0 \
    -c rabbitmq -- sh -lc '
      curl --fail --silent --show-error \
        --user "$RABBITMQ_USERNAME:$(cat "$RABBITMQ_PASSWORD_FILE")" \
        http://127.0.0.1:15672/api/queues/knowledge-development/knowledge.admin.default
    ' | jq -c '{messages_ready, messages_unacknowledged, consumers}'
}

wait_queue_empty() {
  local deadline=$((SECONDS + 120)) counts ready unack
  while [[ $SECONDS -lt $deadline ]]; do
    counts="$(queue_counts)"
    ready="$(jq -r '.messages_ready' <<<"$counts")"
    unack="$(jq -r '.messages_unacknowledged' <<<"$counts")"
    if [[ "$ready" == 0 && "$unack" == 0 ]]; then
      printf 'R5_KNOWLEDGE_QUEUE_STATE=%s\n' "$counts"
      return 0
    fi
    sleep 2
  done
  echo 'Knowledge production queue did not drain' >&2
  return 1
}

reconcile_identity() {
  local mode="$1" admin_uri web_uri label
  if [[ "$mode" == formal ]]; then
    admin_uri="https://knowledge-admin.sunmoonai.com:30443/api/auth/admin/callback"
    web_uri="https://knowledge.sunmoonai.com:30443/api/auth/web/callback"
    label="architecture-v2-r5-knowledge-formal"
  else
    admin_uri="https://knowledge-admin-r5.sunmoonai.com:30443/api/auth/admin/callback"
    web_uri="https://knowledge-web-r5.sunmoonai.com:30443/api/auth/web/callback"
    label="architecture-v2-r5-knowledge-candidate"
  fi
  R3_IDENTITY_SECRET=knowledge-r5-browser-identity \
  R3_ADMIN_APPLICATION=sunmoonai-knowledge-r5-admin \
  R3_WEB_APPLICATION=sunmoonai-knowledge-r5-web \
  R3_ADMIN_REDIRECT_URI="$admin_uri" \
  R3_WEB_REDIRECT_URI="$web_uri" \
  R3_ADMIN_DISPLAY_NAME="Knowledge Architecture v2 Admin" \
  R3_WEB_DISPLAY_NAME="Knowledge Architecture v2 Web" \
  R3_TASK_LABEL="$label" \
  R3_IDENTITY_JOB_PREFIX=architecture-v2-r5-knowledge-identity \
    bash "$SCRIPT_DIR/provision_r3_template_identity.sh" --apply \
      --kubeconfig "$KUBECONFIG_PATH" --provider-namespace "$NAMESPACE"
}

apply_formal_ingress() {
  cat <<'EOF' | k apply -f - >/dev/null
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: knowledge-admin-frontend-ingress
  namespace: app-platform-dev
  labels: {sunmoonai.com/app: knowledge-r5, sunmoonai.com/managed-by: architecture-v2}
spec:
  entryPoints: [websecure]
  routes:
  - kind: Rule
    match: Host(`knowledge-admin.sunmoonai.com`) && PathPrefix(`/api`)
    priority: 100
    services: [{name: knowledge-r5-backend, port: 8000}]
  - kind: Rule
    match: Host(`knowledge-admin.sunmoonai.com`) && PathPrefix(`/`)
    priority: 10
    services: [{name: knowledge-r5-admin-frontend, port: 3000}]
  tls: {secretName: knowledge-r5-tls}
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: knowledge-web-frontend-ingress
  namespace: app-platform-dev
  labels: {sunmoonai.com/app: knowledge-r5, sunmoonai.com/managed-by: architecture-v2}
spec:
  entryPoints: [websecure]
  routes:
  - kind: Rule
    match: Host(`knowledge.sunmoonai.com`) && PathPrefix(`/api`)
    priority: 100
    services: [{name: knowledge-r5-backend, port: 8000}]
  - kind: Rule
    match: Host(`knowledge.sunmoonai.com`) && PathPrefix(`/`)
    priority: 10
    services: [{name: knowledge-r5-web-frontend, port: 3000}]
  tls: {secretName: knowledge-r5-tls}
EOF
  k patch ingressroute knowledge-admin-backend-ingress -n "$NAMESPACE" \
    --type=merge -p='{
      "spec":{
        "routes":[{
          "kind":"Rule",
          "match":"Host(`knowledge-admin-api.sunmoonai.com`) && PathPrefix(`/`)",
          "services":[{"name":"knowledge-r5-backend","port":8000}]
        }],
        "tls":{"secretName":"knowledge-r5-tls"}
      }
    }' >/dev/null
}

restore_v1_ingress() {
  k delete ingressroute knowledge-admin-frontend-ingress \
    knowledge-web-frontend-ingress -n "$NAMESPACE" \
    --ignore-not-found=true --wait=true >/dev/null
  k patch ingressroute knowledge-admin-backend-ingress -n "$NAMESPACE" \
    --type=merge -p='{
      "spec":{
        "routes":[{
          "kind":"Rule",
          "match":"Host(`knowledge-admin-api.sunmoonai.com`) && PathPrefix(`/`)",
          "services":[{"name":"knowledge-admin-backend","port":8000}]
        }],
        "tls":null
      }
    }' >/dev/null
}

annotate_database_secrets() {
  local state="$1"
  k annotate secret knowledge-backend-postgresql-conn \
    knowledge-backend-migration-postgresql-conn -n "$NAMESPACE" \
    "architecture.sunmoonai.com/state=$state" --overwrite >/dev/null
}

run_formal_migration() {
  local job="knowledge-r5-backend-migration-r5-knowledge-001" head
  head="$(postgres_value 'SELECT version_num FROM alembic_version;')"
  if [[ "$head" == 20260808_0004 ]]; then
    echo 'R5_KNOWLEDGE_MIGRATION=already-at-0004'
    return 0
  fi
  [[ "$head" == 20260715_0003 ]] || {
    echo "unsupported Knowledge head before migration: $head" >&2
    return 1
  }
  k delete job "$job" -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
  k apply -f "$BUNDLE/10-migration.yaml" >/dev/null
  k wait --for=condition=complete "job/$job" -n "$NAMESPACE" --timeout=240s >/dev/null
  [[ "$(postgres_value 'SELECT version_num FROM alembic_version;')" == 20260808_0004 ]]
}

rollback_core() {
  IN_ROLLBACK=true
  echo 'R5_KNOWLEDGE_ROLLBACK_STAGE=stop_v2'
  scale 0 knowledge-r5-backend-worker knowledge-r5-backend-scheduler \
    knowledge-r5-backend-api
  db_owner="$(postgres_value \
    "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname=current_database();" \
    2>/dev/null)"
  if [[ "$db_owner" == knowledge_backend_user_migration ]]; then
    echo 'R5_KNOWLEDGE_ROLLBACK_STAGE=database_roles'
    postgres_file "$SQL_DIR/r5-knowledge-owner-rollback.sql"
  fi
  echo 'R5_KNOWLEDGE_ROLLBACK_STAGE=identity_and_routes'
  reconcile_identity candidate
  k apply -f "$BUNDLE/00-prerequisites.yaml" >/dev/null
  restore_v1_ingress
  annotate_database_secrets prepared-not-active
  echo 'R5_KNOWLEDGE_ROLLBACK_STAGE=restore_v1'
  scale 1 knowledge-admin-backend celeryworker-knowledge-admin-backend
  wait_rollout knowledge-admin-backend celeryworker-knowledge-admin-backend
  IN_ROLLBACK=false
  printf '{"task":"R5-K5-knowledge-rollback","result":"restored","migration_retained":"20260808_0004","v1_assets_deleted":false,"ragflow_mutated":false}\n'
}

on_exit() {
  local rc=$?
  if [[ $rc -ne 0 && "$ROLLBACK_ARMED" == true && "$IN_ROLLBACK" == false ]]; then
    echo "R5 Knowledge cutover failed rc=$rc; attempting rollback" >&2
    rollback_core || true
  fi
  exit "$rc"
}
trap on_exit EXIT INT TERM HUP

python3 "$SCRIPT_DIR/verify_r5_knowledge_candidate_bundle.py" --bundle "$BUNDLE" >/dev/null
for gate in browser-gate service-contract-gate provider-gate network-policy-gate; do
  jq -e '.result == "passed"' \
    "$SCRIPT_DIR/../evidence/R5-knowledge-candidate/${gate}.json" >/dev/null
done
head="$(postgres_value 'SELECT version_num FROM alembic_version;')"
[[ "$head" == 20260715_0003 || "$head" == 20260808_0004 ]] || {
  echo "unsupported Knowledge database head: $head" >&2
  exit 3
}

printf 'PLAN task=R5-K4-knowledge action=%s namespace=%s capture=%s\n' \
  "$ACTION" "$NAMESPACE" "$CAPTURE_ID"
printf 'PLAN delete_v1=false downgrade=false dual_writers=false automatic_rollback=true ragflow_mutation=false\n'
[[ "$ACTION" != plan ]] || exit 0
if [[ "$ACTION" == rollback ]]; then
  rollback_core
  ROLLBACK_ARMED=false
  exit 0
fi

ROLLBACK_ARMED=true
echo 'R5_KNOWLEDGE_CUTOVER_STAGE=formal_identity'
reconcile_identity formal

echo 'R5_KNOWLEDGE_CUTOVER_STAGE=freeze_producers'
scale 0 knowledge-r5-backend-api knowledge-admin-backend
wait_rollout knowledge-r5-backend-api knowledge-admin-backend
wait_queue_empty
scale 0 celeryworker-knowledge-admin-backend
wait_rollout celeryworker-knowledge-admin-backend

echo 'R5_KNOWLEDGE_CUTOVER_STAGE=private_backup'
R5_CAPTURE_ID="$CAPTURE_ID" KUBECONFIG="$KUBECONFIG_PATH" \
  bash "$SCRIPT_DIR/backup_r5_knowledge_database_kind.sh"

echo 'R5_KNOWLEDGE_CUTOVER_STAGE=migration_0004'
run_formal_migration

echo 'R5_KNOWLEDGE_CUTOVER_STAGE=owner_forward'
postgres_file "$SQL_DIR/r5-knowledge-owner-forward.sql"
annotate_database_secrets active-formal

echo 'R5_KNOWLEDGE_CUTOVER_STAGE=start_v2_single_writer'
k apply -f "$OVERLAY/50-formal-config.yaml" >/dev/null
k rollout restart deployment/knowledge-r5-admin-frontend \
  deployment/knowledge-r5-web-frontend -n "$NAMESPACE" >/dev/null
scale 2 knowledge-r5-backend-api
scale 1 knowledge-r5-backend-worker knowledge-r5-backend-scheduler
wait_rollout knowledge-r5-backend-api knowledge-r5-backend-worker \
  knowledge-r5-backend-scheduler knowledge-r5-admin-frontend \
  knowledge-r5-web-frontend

echo 'R5_KNOWLEDGE_CUTOVER_STAGE=switch_ingress'
apply_formal_ingress

ROLLBACK_ARMED=false
trap - EXIT INT TERM HUP
printf '{"task":"R5-K4-knowledge-cutover","result":"cutover","single_writer":true,"backup_capture":"%s","migration":"20260808_0004","v1_assets_deleted":false,"ragflow_mutated":false}\n' "$CAPTURE_ID"
