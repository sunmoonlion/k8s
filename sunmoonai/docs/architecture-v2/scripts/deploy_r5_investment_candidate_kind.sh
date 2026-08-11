#!/usr/bin/env bash

set -euo pipefail

ACTION="plan"
BUNDLE=""
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
NAMESPACE="app-platform-dev"
TIMEOUT="300"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: deploy_r5_investment_candidate_kind.sh [plan|apply|cleanup] --bundle DIR

The candidate migrates the isolated investment_admin target, starts only API
and the two frontends, and keeps Worker/Scheduler at zero. cleanup removes only
resources labelled sunmoonai.com/app=investment-r5; external Secrets, the
research_admin rollback source and legacy Research resources are retained.
EOF
}

if [[ $# -gt 0 && "$1" =~ ^(plan|apply|cleanup)$ ]]; then ACTION="$1"; shift; fi
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

k() { env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" --request-timeout=20s "$@"; }
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
  [[ -n "$encoded" ]] || { printf 'required Secret key absent: %s/%s\n' "$secret" "$key" >&2; exit 4; }
}
legacy_snapshot() {
  k get deployment \
    research-admin-backend celeryworker-research-admin-backend research-admin-frontend \
    research-web-backend nodebullworker-research-web-backend research-web-frontend \
    -n "$NAMESPACE" -o json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({i["metadata"]["name"]:{"replicas":i["spec"].get("replicas",1),"image":i["spec"]["template"]["spec"]["containers"][0]["image"]} for i in d["items"]},sort_keys=True,separators=(",",":")))'
}

python3 "$SCRIPT_DIR/verify_r5_investment_candidate_bundle.py" --bundle "$BUNDLE"
[[ "$(release_value namespace)" == "$NAMESPACE" ]] || { echo 'bundle namespace mismatch' >&2; exit 3; }
[[ "$(release_value touches_v1_resources)" == "false" ]] || { echo 'bundle mutates legacy resources' >&2; exit 3; }

printf 'PLAN task=R5-V3 action=%s namespace=%s release=%s\n' "$ACTION" "$NAMESPACE" "$(release_value release_id)"
printf 'PLAN legacy_research_mutation=false candidate_async_writers=0 target_migration=true\n'
[[ "$ACTION" != plan ]] || exit 0

if [[ "$ACTION" == cleanup ]]; then
  k delete ingressroute,networkpolicy,horizontalpodautoscaler,poddisruptionbudget,deployment,service,configmap,serviceaccount,job \
    -n "$NAMESPACE" -l 'sunmoonai.com/app=investment-r5' --ignore-not-found=true --wait=true
  printf '{"task":"R5-V3-investment-candidate","result":"cleaned","external_secrets_deleted":false,"research_source_mutated":false}\n'
  exit 0
fi

for secret in harbor-registry-secret investment-r5-tls \
  investment-backend-postgresql-conn investment-backend-migration-postgresql-conn \
  investment-r5-browser-identity investment-backend-redis-conn investment-backend-broker \
  investment-knowledge-retrieval-client; do
  k get secret "$secret" -n "$NAMESPACE" >/dev/null
done
for pair in \
  'investment-backend-postgresql-conn DATABASE_URL' \
  'investment-backend-migration-postgresql-conn MIGRATION_DATABASE_URL' \
  'investment-r5-browser-identity ADMIN_CLIENT_ID' \
  'investment-r5-browser-identity ADMIN_CLIENT_SECRET' \
  'investment-r5-browser-identity WEB_CLIENT_ID' \
  'investment-r5-browser-identity WEB_CLIENT_SECRET' \
  'investment-backend-broker CELERY_BROKER_URL' \
  'investment-knowledge-retrieval-client KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_ID' \
  'investment-knowledge-retrieval-client KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_SECRET'; do
  read -r secret key <<<"$pair"; require_secret_key "$secret" "$key"
done

before="$(legacy_snapshot)"
k apply -f "$BUNDLE/00-prerequisites.yaml"
k apply -f "$BUNDLE/30-network-policies.yaml"
k delete job "investment-r5-backend-migration-$(release_value release_id)" -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
k apply -f "$BUNDLE/10-migration.yaml"
if ! k wait --for=condition=complete "job/investment-r5-backend-migration-$(release_value release_id)" -n "$NAMESPACE" --timeout="${TIMEOUT}s"; then
  k logs "job/investment-r5-backend-migration-$(release_value release_id)" -n "$NAMESPACE" --tail=120 >&2 || true
  exit 5
fi
k logs "job/investment-r5-backend-migration-$(release_value release_id)" -n "$NAMESPACE" --tail=20
k apply -f "$BUNDLE/20-runtime.yaml"
k apply -f "$BUNDLE/40-ingress.yaml"

for deployment in investment-r5-backend-api investment-r5-admin-frontend investment-r5-web-frontend; do
  k rollout status "deployment/$deployment" -n "$NAMESPACE" --timeout="${TIMEOUT}s"
done
test "$(k get deployment investment-r5-backend-worker -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')" = 0
test "$(k get deployment investment-r5-backend-scheduler -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')" = 0
after="$(legacy_snapshot)"
[[ "$before" == "$after" ]] || { echo 'legacy Research topology mutated' >&2; exit 6; }

python3 - "$BUNDLE/release.json" <<'PY'
import json, sys
r=json.load(open(sys.argv[1],encoding="utf-8"))
print(json.dumps({"task":"R5-V3-investment-candidate","result":"deployed","release_id":r["release_id"],"backend_image":r["images"]["backend"],"migration_applied":True,"candidate_async_writers":0,"legacy_research_mutated":False,"credentials_printed":False},ensure_ascii=False,indent=2))
PY
