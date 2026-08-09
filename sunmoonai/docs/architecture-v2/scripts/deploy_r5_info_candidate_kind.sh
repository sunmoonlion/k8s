#!/usr/bin/env bash

# Plan, apply or clean the Info R5 candidate bundle. This command never changes
# v1 resource names and never creates or copies credentials.

set -euo pipefail

ACTION="plan"
BUNDLE=""
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
NAMESPACE="app-platform-dev"
TIMEOUT="300"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: deploy_r5_info_candidate_kind.sh [plan|apply|cleanup] --bundle DIR [options]

Options:
  --bundle DIR          Rendered bundle directory (required)
  --kubeconfig PATH     KIND kubeconfig
  --namespace NAME      Must match release.json (default app-platform-dev)
  --timeout SECONDS     Rollout/Job timeout (default 300)

apply requires the database roles, browser clients, TLS and legacy domain
dependency Secrets to have been provisioned independently. cleanup deletes only
resources labelled sunmoonai.com/app=info-r5; it does not delete external Secrets.
EOF
}

if [[ $# -gt 0 && "$1" =~ ^(plan|apply|cleanup)$ ]]; then
  ACTION="$1"
  shift
fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle) BUNDLE="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$BUNDLE" ]] || { usage >&2; exit 2; }
[[ "$TIMEOUT" =~ ^[1-9][0-9]{0,3}$ ]] || { echo 'invalid timeout' >&2; exit 2; }
BUNDLE="$(cd -- "$BUNDLE" && pwd)"

k() {
  env -u DEBUG kubectl \
    --kubeconfig "$KUBECONFIG_PATH" \
    --request-timeout=20s \
    "$@"
}

release_value() {
  python3 - "$BUNDLE/release.json" "$1" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
for part in sys.argv[2].split("."):
    value = value[part]
print(str(value).lower() if isinstance(value, bool) else value)
PY
}

require_secret_key() {
  local secret="$1" key="$2" encoded
  encoded="$(k get secret "$secret" -n "$NAMESPACE" -o "jsonpath={.data.${key}}")"
  [[ -n "$encoded" ]] || {
    printf 'required Secret key is empty or absent: %s/%s\n' "$secret" "$key" >&2
    exit 4
  }
}

verify_v1_names_untouched() {
  local name
  for name in \
    info-admin-backend celeryworker-info-admin-backend info-admin-frontend \
    info-web-backend nodebullworker-info-web-backend info-web-frontend; do
    k get deployment "$name" -n "$NAMESPACE" >/dev/null
  done
}

python3 "$SCRIPT_DIR/verify_r5_info_candidate_bundle.py" --bundle "$BUNDLE"
[[ "$(release_value namespace)" == "$NAMESPACE" ]] || {
  echo 'bundle namespace mismatch' >&2
  exit 3
}
[[ "$(release_value touches_v1_resources)" == "false" ]] || {
  echo 'bundle is not a non-mutating candidate' >&2
  exit 3
}

printf 'PLAN task=R5-I3 action=%s namespace=%s release=%s\n' \
  "$ACTION" "$NAMESPACE" "$(release_value release_id)"
printf 'PLAN v1_mutation=false formal_release=false credential_copy=false\n'

if [[ "$ACTION" == "plan" ]]; then
  exit 0
fi

if [[ "$ACTION" == "cleanup" ]]; then
  k delete \
    ingressroute,networkpolicy,horizontalpodautoscaler,poddisruptionbudget,deployment,service,configmap,serviceaccount,job \
    -n "$NAMESPACE" \
    -l 'sunmoonai.com/app=info-r5' \
    --ignore-not-found=true \
    --wait=true
  printf '{"task":"R5-I3-info-candidate","result":"cleaned","external_secrets_deleted":false}\n'
  exit 0
fi

for secret in \
  harbor-registry-secret info-r5-tls \
  info-backend-postgresql-conn info-backend-migration-postgresql-conn \
  info-r5-browser-identity info-admin-backend-redis-conn \
  celeryworker-info-admin-backend-secret info-admin-backend-s3 \
  info-admin-backend-elasticsearch info-knowledge-ingest-client; do
  k get secret "$secret" -n "$NAMESPACE" >/dev/null
done
for pair in \
  'info-backend-postgresql-conn DATABASE_URL' \
  'info-backend-migration-postgresql-conn MIGRATION_DATABASE_URL' \
  'info-r5-browser-identity ADMIN_CLIENT_ID' \
  'info-r5-browser-identity ADMIN_CLIENT_SECRET' \
  'info-r5-browser-identity WEB_CLIENT_ID' \
  'info-r5-browser-identity WEB_CLIENT_SECRET' \
  'info-knowledge-ingest-client KNOWLEDGE_APP_SERVICE_CLIENT_SECRET'; do
  read -r secret key <<<"$pair"
  require_secret_key "$secret" "$key"
done

verify_v1_names_untouched
k apply -f "$BUNDLE/00-prerequisites.yaml"
k apply -f "$BUNDLE/30-network-policies.yaml"
k delete job "info-r5-backend-migration-$(release_value release_id)" \
  -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
k apply -f "$BUNDLE/10-migration.yaml"
if ! k wait --for=condition=complete \
  "job/info-r5-backend-migration-$(release_value release_id)" \
  -n "$NAMESPACE" --timeout="${TIMEOUT}s"; then
  k logs "job/info-r5-backend-migration-$(release_value release_id)" \
    -n "$NAMESPACE" --tail=100 >&2 || true
  exit 5
fi
k logs "job/info-r5-backend-migration-$(release_value release_id)" \
  -n "$NAMESPACE" --tail=100
k apply -f "$BUNDLE/20-runtime.yaml"
k apply -f "$BUNDLE/40-ingress.yaml"

for deployment in \
  info-r5-backend-api info-r5-backend-worker info-r5-backend-scheduler \
  info-r5-admin-frontend info-r5-web-frontend; do
  k rollout status "deployment/$deployment" -n "$NAMESPACE" --timeout="${TIMEOUT}s"
done
verify_v1_names_untouched

python3 - "$BUNDLE/release.json" <<'PY'
import json, sys
release = json.load(open(sys.argv[1], encoding="utf-8"))
print(json.dumps({
    "task": "R5-I3-info-candidate",
    "result": "deployed",
    "release_id": release["release_id"],
    "backend_image": release["images"]["backend"],
    "v1_resources_mutated": False,
    "credentials_printed": False,
}, ensure_ascii=False, indent=2))
PY
