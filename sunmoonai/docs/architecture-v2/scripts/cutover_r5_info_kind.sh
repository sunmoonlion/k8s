#!/usr/bin/env bash

# Reversible Info R5 cutover for the long-lived development KIND cluster.
# No v1 Deployment, Secret, PVC, database or image is deleted.

set -euo pipefail
umask 077

ACTION="plan"
BUNDLE=""
OVERLAY=""
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
NAMESPACE="app-platform-dev"
CAPTURE_ID="r5-info-cutover-$(date -u +%Y%m%dT%H%M%SZ)"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="$(cd -- "$SCRIPT_DIR/../sql" && pwd)"
ROLLBACK_ARMED=false
IN_ROLLBACK=false

usage() {
  cat <<'EOF'
Usage: cutover_r5_info_kind.sh [plan|apply|rollback] --bundle DIR --overlay DIR

apply freezes all old writers, takes a private backup, transfers ownership,
starts one R5 Worker/Scheduler, switches the four formal IngressRoutes and then
scales the old frontends to zero. A failed apply attempts deterministic rollback.
rollback restores v1 grants, clients, routes and replicas while retaining the
additive 20260809_0005 migration.
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
BUNDLE="$(cd -- "$BUNDLE" && pwd)"
OVERLAY="$(cd -- "$OVERLAY" && pwd)"

k() { env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" --request-timeout=20s "$@"; }

postgres_value() {
  local sql="$1"
  k exec --quiet -n data-platform-dev postgresql-sunmoonai-0 -- sh -lc '
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
    exec /opt/bitnami/postgresql/bin/psql -U postgres -d info_admin -X -v ON_ERROR_STOP=1 -At -c "$1"
  ' sh "$sql"
}

postgres_file_db() {
  local database="$1" file="$2"
  k exec --quiet -i -n data-platform-dev postgresql-sunmoonai-0 -- sh -lc '
    export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
    exec /opt/bitnami/postgresql/bin/psql -U postgres -d "$1" -X
  ' sh "$database" <"$file"
}

postgres_file() {
  postgres_file_db info_admin "$1"
}

scale() {
  local replicas="$1"; shift
  local name
  for name in "$@"; do k scale deployment "$name" -n "$NAMESPACE" --replicas="$replicas" >/dev/null; done
}

wait_rollout() {
  local name
  for name in "$@"; do k rollout status "deployment/$name" -n "$NAMESPACE" --timeout=240s >/dev/null; done
}

reconcile_identity() {
  local mode="$1" admin_uri web_uri label
  if [[ "$mode" == formal ]]; then
    admin_uri="https://info-admin.sunmoonai.com:30443/api/auth/admin/callback"
    web_uri="https://info.sunmoonai.com:30443/api/auth/web/callback"
    label="architecture-v2-r5-info-formal"
  else
    admin_uri="https://info-admin-r5.sunmoonai.com:30443/api/auth/admin/callback"
    web_uri="https://info-web-r5.sunmoonai.com:30443/api/auth/web/callback"
    label="architecture-v2-r5-info-candidate"
  fi
  R3_IDENTITY_SECRET=info-r5-browser-identity \
  R3_ADMIN_APPLICATION=sunmoonai-info-r5-admin \
  R3_WEB_APPLICATION=sunmoonai-info-r5-web \
  R3_ADMIN_REDIRECT_URI="$admin_uri" \
  R3_WEB_REDIRECT_URI="$web_uri" \
  R3_ADMIN_DISPLAY_NAME="Info Architecture v2 Admin" \
  R3_WEB_DISPLAY_NAME="Info Architecture v2 Web" \
  R3_TASK_LABEL="$label" \
  R3_IDENTITY_JOB_PREFIX=architecture-v2-r5-info-identity \
    bash "$SCRIPT_DIR/provision_r3_template_identity.sh" --apply \
      --kubeconfig "$KUBECONFIG_PATH" --provider-namespace "$NAMESPACE"
}

patch_formal_ingress() {
  # The frontend origins are same-origin façades.  Their /api route must reach
  # the unified FastAPI backend before the catch-all Next.js route.  Replacing
  # the complete route array prevents a legacy one-route Ingress from silently
  # sending API requests to Next.js and returning its HTML 404 page.
  k patch ingressroute info-admin-frontend-ingress -n "$NAMESPACE" --type=merge -p='{
    "spec": {
      "routes": [
        {"kind":"Rule","match":"Host(`info-admin.sunmoonai.com`) && PathPrefix(`/api`)","priority":100,"services":[{"name":"info-r5-backend","port":8000}]},
        {"kind":"Rule","match":"Host(`info-admin.sunmoonai.com`) && PathPrefix(`/`)","priority":10,"services":[{"name":"info-r5-admin-frontend","port":3000}]}
      ],
      "tls":{"secretName":"info-r5-tls"}
    }
  }' >/dev/null
  k patch ingressroute info-web-frontend-ingress -n "$NAMESPACE" --type=merge -p='{
    "spec": {
      "routes": [
        {"kind":"Rule","match":"Host(`info.sunmoonai.com`) && PathPrefix(`/api`)","priority":100,"services":[{"name":"info-r5-backend","port":8000}]},
        {"kind":"Rule","match":"Host(`info.sunmoonai.com`) && PathPrefix(`/`)","priority":10,"services":[{"name":"info-r5-web-frontend","port":3000}]}
      ],
      "tls":{"secretName":"info-r5-tls"}
    }
  }' >/dev/null

  local spec
  for spec in \
    'info-admin-backend-ingress info-r5-backend 8000' \
    'info-web-backend-ingress info-r5-backend 8000'; do
    read -r route service port <<<"$spec"
    k patch ingressroute "$route" -n "$NAMESPACE" --type=json -p="[
      {\"op\":\"replace\",\"path\":\"/spec/routes/0/services/0/name\",\"value\":\"$service\"},
      {\"op\":\"replace\",\"path\":\"/spec/routes/0/services/0/port\",\"value\":$port},
      {\"op\":\"add\",\"path\":\"/spec/tls\",\"value\":{\"secretName\":\"info-r5-tls\"}}
    ]" >/dev/null
  done
}

patch_v1_ingress() {
  # Restore the exact pre-R5 single-route shapes; do not leave an /api route
  # pointing at a stopped R5 backend during rollback.
  k patch ingressroute info-admin-frontend-ingress -n "$NAMESPACE" --type=merge -p='{
    "spec":{"routes":[{"kind":"Rule","match":"Host(`info-admin.sunmoonai.com`) && PathPrefix(`/`)","services":[{"name":"info-admin-frontend","port":80}]}],"tls":null}
  }' >/dev/null
  k patch ingressroute info-web-frontend-ingress -n "$NAMESPACE" --type=merge -p='{
    "spec":{"routes":[{"kind":"Rule","match":"Host(`info.sunmoonai.com`) && PathPrefix(`/`)","services":[{"name":"info-web-frontend","port":3000}]}],"tls":null}
  }' >/dev/null
  k patch ingressroute info-admin-backend-ingress -n "$NAMESPACE" --type=merge -p='{
    "spec":{"routes":[{"kind":"Rule","match":"Host(`info-admin-api.sunmoonai.com`) && PathPrefix(`/`)","services":[{"name":"info-admin-backend","port":8000}]}],"tls":null}
  }' >/dev/null
  k patch ingressroute info-web-backend-ingress -n "$NAMESPACE" --type=merge -p='{
    "spec":{"routes":[{"kind":"Rule","match":"Host(`info-api.sunmoonai.com`) && PathPrefix(`/`)","services":[{"name":"info-web-backend","port":3000}]}],"tls":null}
  }' >/dev/null
}

rollback_core() {
  IN_ROLLBACK=true
  echo 'R5_INFO_ROLLBACK_STAGE=stop_v2'
  scale 0 info-r5-backend-worker info-r5-backend-scheduler info-r5-backend-api
  db_owner="$(postgres_value "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname=current_database();" 2>/dev/null)"
  if [[ "$db_owner" == info_backend_user_migration ]]; then
    echo 'R5_INFO_ROLLBACK_STAGE=database_roles'
    postgres_file "$SQL_DIR/r5-info-owner-rollback.sql"
  fi
  echo 'R5_INFO_ROLLBACK_STAGE=legacy_web_database_role'
  postgres_file_db info_web "$SQL_DIR/r5-info-web-seal-rollback.sql"
  echo 'R5_INFO_ROLLBACK_STAGE=identity_and_routes'
  reconcile_identity candidate
  k apply -f "$BUNDLE/00-prerequisites.yaml" >/dev/null
  patch_v1_ingress
  echo 'R5_INFO_ROLLBACK_STAGE=restore_v1'
  scale 1 \
    info-admin-backend celeryworker-info-admin-backend info-admin-frontend \
    info-web-backend nodebullworker-info-web-backend info-web-frontend
  wait_rollout \
    info-admin-backend celeryworker-info-admin-backend info-admin-frontend \
    info-web-backend nodebullworker-info-web-backend info-web-frontend
  IN_ROLLBACK=false
  printf '{"task":"R5-I5-info-rollback","result":"restored","migration_retained":"20260809_0005","v1_assets_deleted":false}\n'
}

on_exit() {
  local rc=$?
  if [[ $rc -ne 0 && "$ROLLBACK_ARMED" == true && "$IN_ROLLBACK" == false ]]; then
    echo "R5 Info cutover failed rc=$rc; attempting rollback" >&2
    rollback_core || true
  fi
  exit "$rc"
}
trap on_exit EXIT INT TERM HUP

python3 "$SCRIPT_DIR/verify_r5_info_candidate_bundle.py" --bundle "$BUNDLE" >/dev/null
jq -e '.result == "passed"' "$SCRIPT_DIR/../evidence/R5-info-baseline/candidate-browser-gate.json" >/dev/null
jq -e '.result == "passed"' "$SCRIPT_DIR/../evidence/R5-info-baseline/network-policy-calico-gate.json" >/dev/null
[[ "$(postgres_value "SELECT version_num FROM alembic_version;")" == 20260809_0005 ]] || {
  echo 'database head is not 20260809_0005' >&2; exit 3;
}

printf 'PLAN task=R5-I4-info action=%s namespace=%s capture=%s\n' "$ACTION" "$NAMESPACE" "$CAPTURE_ID"
printf 'PLAN delete_v1=false downgrade=false dual_writers=false automatic_rollback=true\n'
[[ "$ACTION" != plan ]] || exit 0
if [[ "$ACTION" == rollback ]]; then
  rollback_core
  ROLLBACK_ARMED=false
  exit 0
fi

ROLLBACK_ARMED=true
echo 'R5_INFO_CUTOVER_STAGE=formal_identity'
reconcile_identity formal

echo 'R5_INFO_CUTOVER_STAGE=freeze_writers'
scale 0 \
  info-r5-backend-api \
  info-admin-backend celeryworker-info-admin-backend \
  info-web-backend nodebullworker-info-web-backend
wait_rollout \
  info-r5-backend-api \
  info-admin-backend celeryworker-info-admin-backend \
  info-web-backend nodebullworker-info-web-backend
[[ "$(postgres_value "SELECT count(*) FROM delivery_outbox_message WHERE state <> 'completed';")" == 0 ]] || {
  echo 'delivery outbox is not drained' >&2; exit 4;
}

echo 'R5_INFO_CUTOVER_STAGE=private_backup'
R5_CAPTURE_ID="$CAPTURE_ID" KUBECONFIG="$KUBECONFIG_PATH" \
  bash "$SCRIPT_DIR/backup_r5_info_database_kind.sh"

echo 'R5_INFO_CUTOVER_STAGE=owner_forward'
postgres_file "$SQL_DIR/r5-info-owner-forward.sql"
postgres_file_db info_web "$SQL_DIR/r5-info-web-seal-forward.sql"

echo 'R5_INFO_CUTOVER_STAGE=start_v2_single_writer'
k apply -f "$OVERLAY/50-formal-config.yaml" >/dev/null
k rollout restart deployment/info-r5-admin-frontend deployment/info-r5-web-frontend \
  -n "$NAMESPACE" >/dev/null
scale 2 info-r5-backend-api
scale 1 info-r5-backend-worker info-r5-backend-scheduler
wait_rollout \
  info-r5-backend-api info-r5-backend-worker info-r5-backend-scheduler \
  info-r5-admin-frontend info-r5-web-frontend

echo 'R5_INFO_CUTOVER_STAGE=switch_ingress'
patch_formal_ingress
scale 0 info-admin-frontend info-web-frontend
wait_rollout info-admin-frontend info-web-frontend

ROLLBACK_ARMED=false
trap - EXIT INT TERM HUP
printf '{"task":"R5-I4-info-cutover","result":"cutover","single_writer":true,"backup_capture":"%s","v1_assets_deleted":false}\n' "$CAPTURE_ID"
