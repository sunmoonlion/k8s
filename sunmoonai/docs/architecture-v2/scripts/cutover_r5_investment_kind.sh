#!/usr/bin/env bash

# Reversible Research-v1 -> Investment R5 cutover. The source research_admin
# database and all legacy declarations/Secrets remain intact for native rollback.
set -euo pipefail
umask 077

ACTION=plan
BUNDLE=""
OVERLAY=""
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
NAMESPACE=app-platform-dev
CAPTURE_ID="r5-investment-cutover-$(date -u +%Y%m%dT%H%M%SZ)"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_PLATFORM_SCRIPTS="$(cd -- "$SCRIPT_DIR/../../../app-platform/scripts" && pwd)"
ROLLBACK_ARMED=false
IN_ROLLBACK=false

usage() { echo "usage: $0 [plan|apply|rollback] --bundle DIR --overlay DIR" >&2; }
if [[ $# -gt 0 && "$1" =~ ^(plan|apply|rollback)$ ]]; then ACTION="$1"; shift; fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle) BUNDLE="$2"; shift 2 ;;
    --overlay) OVERLAY="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --capture-id) CAPTURE_ID="$2"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
[[ -f "$BUNDLE/release.json" && -f "$OVERLAY/50-formal-config.yaml" ]] || { usage; exit 2; }
[[ "$NAMESPACE" == app-platform-dev ]] || { echo 'formal namespace mismatch' >&2; exit 2; }
BUNDLE="$(cd -- "$BUNDLE" && pwd)"; OVERLAY="$(cd -- "$OVERLAY" && pwd)"
k() { env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" --request-timeout=30s "$@"; }

scale() { local replicas="$1"; shift; for name in "$@"; do k scale deployment "$name" -n "$NAMESPACE" --replicas="$replicas" >/dev/null; done; }
wait_rollout() { for name in "$@"; do k rollout status "deployment/$name" -n "$NAMESPACE" --timeout=300s >/dev/null; done; }
postgres() {
  local database="$1" sql="$2"
  k exec --quiet -n data-platform-dev postgresql-sunmoonai-0 -- sh -lc '
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
    exec /opt/bitnami/postgresql/bin/psql -U postgres -d "$1" -X -v ON_ERROR_STOP=1 -At -c "$2"
  ' sh "$database" "$sql"
}
queue_counts() {
  k exec --quiet -n messaging-platform-dev rabbitmq-sunmoonai-0 -c rabbitmq -- sh -lc '
    curl --fail --silent --show-error --user "$RABBITMQ_USERNAME:$(cat "$RABBITMQ_PASSWORD_FILE")" http://127.0.0.1:15672/api/queues/research-development/research.admin.default
  ' | jq -c '{messages_ready,messages_unacknowledged,consumers}'
}
wait_queue_empty() {
  local deadline=$((SECONDS+120)) value
  while (( SECONDS < deadline )); do
    value="$(queue_counts)"
    if [[ "$(jq -r '.messages_ready' <<<"$value")" == 0 && "$(jq -r '.messages_unacknowledged' <<<"$value")" == 0 ]]; then
      printf 'R5_INVESTMENT_LEGACY_QUEUE=%s\n' "$value"; return 0
    fi
    sleep 2
  done
  echo 'legacy Research queue did not drain' >&2; return 1
}
reconcile_identity() {
  local mode="$1" admin web label
  if [[ "$mode" == formal ]]; then
    admin=https://investment-admin.sunmoonai.com:30443/api/auth/admin/callback
    web=https://investment.sunmoonai.com:30443/api/auth/web/callback
    label=architecture-v2-r5-investment-formal
  else
    admin=https://investment-admin-r5.sunmoonai.com:30443/api/auth/admin/callback
    web=https://investment-web-r5.sunmoonai.com:30443/api/auth/web/callback
    label=architecture-v2-r5-investment-candidate
  fi
  R3_IDENTITY_SECRET=investment-r5-browser-identity \
  R3_ADMIN_APPLICATION=sunmoonai-investment-r5-admin \
  R3_WEB_APPLICATION=sunmoonai-investment-r5-web \
  R3_ADMIN_REDIRECT_URI="$admin" R3_WEB_REDIRECT_URI="$web" \
  R3_ADMIN_DISPLAY_NAME='Investment Architecture v2 Admin' \
  R3_WEB_DISPLAY_NAME='Investment Architecture v2 Web' \
  R3_TASK_LABEL="$label" R3_IDENTITY_JOB_PREFIX=architecture-v2-r5-investment-identity \
    bash "$SCRIPT_DIR/provision_r3_template_identity.sh" --apply --kubeconfig "$KUBECONFIG_PATH" --provider-namespace "$NAMESPACE"
}
reconcile_knowledge_binding() {
  bash "$APP_PLATFORM_SCRIPTS/reconcile-knowledge-active-retrieval-binding-kind.sh" \
    --caller "$1" --kubeconfig "$KUBECONFIG_PATH" --namespace "$NAMESPACE"
}
formal_ingress() {
  cat <<'EOF' | k apply -f - >/dev/null
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata: {name: investment-admin-frontend-ingress, namespace: app-platform-dev, labels: {sunmoonai.com/app: investment-r5, sunmoonai.com/managed-by: app-platform-v2}}
spec:
  entryPoints: [websecure]
  routes:
  - {kind: Rule, match: 'Host(`investment-admin.sunmoonai.com`) && PathPrefix(`/api`)', priority: 100, services: [{name: investment-r5-backend, port: 8000}]}
  - {kind: Rule, match: 'Host(`investment-admin.sunmoonai.com`) && PathPrefix(`/`)', priority: 10, services: [{name: investment-r5-admin-frontend, port: 3000}]}
  tls: {secretName: investment-r5-tls}
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata: {name: investment-web-frontend-ingress, namespace: app-platform-dev, labels: {sunmoonai.com/app: investment-r5, sunmoonai.com/managed-by: app-platform-v2}}
spec:
  entryPoints: [websecure]
  routes:
  - {kind: Rule, match: 'Host(`investment.sunmoonai.com`) && PathPrefix(`/api`)', priority: 100, services: [{name: investment-r5-backend, port: 8000}]}
  - {kind: Rule, match: 'Host(`investment.sunmoonai.com`) && PathPrefix(`/`)', priority: 10, services: [{name: investment-r5-web-frontend, port: 3000}]}
  tls: {secretName: investment-r5-tls}
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata: {name: investment-admin-backend-ingress, namespace: app-platform-dev, labels: {sunmoonai.com/app: investment-r5, sunmoonai.com/managed-by: app-platform-v2}}
spec: {entryPoints: [websecure], routes: [{kind: Rule, match: 'Host(`investment-admin-api.sunmoonai.com`) && PathPrefix(`/`)', services: [{name: investment-r5-backend, port: 8000}]}], tls: {secretName: investment-r5-tls}}
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata: {name: investment-web-backend-ingress, namespace: app-platform-dev, labels: {sunmoonai.com/app: investment-r5, sunmoonai.com/managed-by: app-platform-v2}}
spec: {entryPoints: [websecure], routes: [{kind: Rule, match: 'Host(`investment-api.sunmoonai.com`) && PathPrefix(`/`)', services: [{name: investment-r5-backend, port: 8000}]}], tls: {secretName: investment-r5-tls}}
EOF
}
delete_formal_ingress() {
  k delete ingressroute investment-admin-frontend-ingress investment-web-frontend-ingress investment-admin-backend-ingress investment-web-backend-ingress -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
}
set_roles() {
  local state="$1"
  if [[ "$state" == formal ]]; then
    postgres postgres 'ALTER ROLE investment_backend_user LOGIN; ALTER ROLE investment_backend_user_migration LOGIN; ALTER ROLE research_admin_user NOLOGIN; ALTER ROLE research_admin_user_migration NOLOGIN; ALTER ROLE research_web_user NOLOGIN; ALTER ROLE investment_admin_user NOLOGIN; ALTER ROLE investment_web_user NOLOGIN;'
  else
    postgres postgres 'ALTER ROLE investment_backend_user NOLOGIN; ALTER ROLE investment_backend_user_migration NOLOGIN; ALTER ROLE research_admin_user LOGIN; ALTER ROLE research_admin_user_migration LOGIN; ALTER ROLE research_web_user LOGIN; ALTER ROLE investment_admin_user LOGIN; ALTER ROLE investment_web_user LOGIN;'
  fi
}
annotate_secrets() { k annotate secret investment-backend-postgresql-conn investment-backend-migration-postgresql-conn -n "$NAMESPACE" "architecture.sunmoonai.com/state=$1" --overwrite >/dev/null; }
run_migration() {
  local job="investment-r5-backend-migration-$(jq -r .release_id "$BUNDLE/release.json")"
  k delete job "$job" -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
  k apply -f "$BUNDLE/10-migration.yaml" >/dev/null
  if ! k wait --for=condition=complete "job/$job" -n "$NAMESPACE" --timeout=300s; then k logs "job/$job" -n "$NAMESPACE" --tail=120 >&2 || true; return 1; fi
  [[ "$(postgres investment_admin 'SELECT version_num FROM alembic_version;')" == 20260809_0004 ]]
}
rollback_core() {
  IN_ROLLBACK=true
  echo R5_INVESTMENT_ROLLBACK_STAGE=stop_investment
  scale 0 investment-r5-backend-worker investment-r5-backend-scheduler investment-r5-backend-api
  set_roles legacy
  reconcile_identity candidate
  reconcile_knowledge_binding research
  delete_formal_ingress
  annotate_secrets prepared-not-active
  echo R5_INVESTMENT_ROLLBACK_STAGE=restore_research
  scale 1 research-admin-backend celeryworker-research-admin-backend research-admin-frontend research-web-backend nodebullworker-research-web-backend research-web-frontend
  wait_rollout research-admin-backend celeryworker-research-admin-backend research-admin-frontend research-web-backend nodebullworker-research-web-backend research-web-frontend
  IN_ROLLBACK=false
  printf '{"task":"R5-V5-investment-rollback","result":"restored","source_database":"research_admin","target_retained":true,"legacy_assets_deleted":false}\n'
}
on_exit() { local rc=$?; trap - EXIT INT TERM HUP; if [[ $rc -ne 0 && "$ROLLBACK_ARMED" == true && "$IN_ROLLBACK" == false ]]; then rollback_core || true; fi; exit "$rc"; }
trap on_exit EXIT INT TERM HUP

python3 "$SCRIPT_DIR/verify_r5_investment_candidate_bundle.py" --bundle "$BUNDLE" >/dev/null
for file in candidate-runtime-gate.json candidate-browser-gate.json; do jq -e '.result=="passed"' "$SCRIPT_DIR/../evidence/R5-investment-baseline/$file" >/dev/null; done
grep -q '"result":"passed"' "$SCRIPT_DIR/../evidence/R5-investment-baseline/network-policy-calico-gate.txt"
printf 'PLAN task=R5-V4-investment action=%s capture=%s delete_legacy=false source_mutation=false automatic_rollback=true\n' "$ACTION" "$CAPTURE_ID"
[[ "$ACTION" != plan ]] || exit 0
if [[ "$ACTION" == rollback ]]; then rollback_core; trap - EXIT INT TERM HUP; exit 0; fi

ROLLBACK_ARMED=true
echo R5_INVESTMENT_CUTOVER_STAGE=formal_identity
reconcile_identity formal
echo R5_INVESTMENT_CUTOVER_STAGE=activate_investment_knowledge_binding
reconcile_knowledge_binding investment
echo R5_INVESTMENT_CUTOVER_STAGE=freeze_legacy_producers
scale 0 research-admin-backend research-admin-frontend research-web-backend research-web-frontend
wait_rollout research-admin-backend research-admin-frontend research-web-backend research-web-frontend
wait_queue_empty
scale 0 celeryworker-research-admin-backend nodebullworker-research-web-backend
wait_rollout celeryworker-research-admin-backend nodebullworker-research-web-backend
scale 0 investment-r5-backend-api

echo R5_INVESTMENT_CUTOVER_STAGE=final_private_backup
backup_json="$(R5_CAPTURE_ID="$CAPTURE_ID" KUBECONFIG="$KUBECONFIG_PATH" bash "$SCRIPT_DIR/backup_r5_investment_database_kind.sh")"
backup_file="$(jq -r .backup_file <<<"$backup_json")"
printf '%s\n' "$backup_json"

echo R5_INVESTMENT_CUTOVER_STAGE=rebuild_target
bash "$SCRIPT_DIR/prepare_r5_investment_target_kind.sh" "$backup_file" --apply --rebuild --kubeconfig "$KUBECONFIG_PATH"
echo R5_INVESTMENT_CUTOVER_STAGE=migrate_target
run_migration
echo R5_INVESTMENT_CUTOVER_STAGE=seal_legacy_roles
set_roles formal
annotate_secrets active-formal

echo R5_INVESTMENT_CUTOVER_STAGE=start_investment
k apply -f "$OVERLAY/50-formal-config.yaml" >/dev/null
k rollout restart deployment/investment-r5-admin-frontend deployment/investment-r5-web-frontend -n "$NAMESPACE" >/dev/null
scale 2 investment-r5-backend-api
scale 1 investment-r5-backend-worker investment-r5-backend-scheduler
k rollout restart deployment/investment-r5-backend-api deployment/investment-r5-backend-worker deployment/investment-r5-backend-scheduler -n "$NAMESPACE" >/dev/null
wait_rollout investment-r5-backend-api investment-r5-backend-worker investment-r5-backend-scheduler investment-r5-admin-frontend investment-r5-web-frontend
echo R5_INVESTMENT_CUTOVER_STAGE=switch_formal_routes
formal_ingress

ROLLBACK_ARMED=false; trap - EXIT INT TERM HUP
printf '{"task":"R5-V4-investment-cutover","result":"cutover","single_writer":true,"source_database_mutated":false,"backup_capture":"%s","migration":"20260809_0004","legacy_assets_deleted":false}\n' "$CAPTURE_ID"
