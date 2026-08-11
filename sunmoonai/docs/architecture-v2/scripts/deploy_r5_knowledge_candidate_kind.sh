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
Usage: deploy_r5_knowledge_candidate_kind.sh [plan|apply|cleanup] --bundle DIR

The candidate keeps Worker and Scheduler at zero replicas and does not execute
the formal migration Job. cleanup only removes resources labelled
sunmoonai.com/app=knowledge-r5 and leaves external Secrets and RAGFlow intact.
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
  env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" \
    --request-timeout=20s "$@"
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
  k get deployment knowledge-admin-backend -n "$NAMESPACE" >/dev/null
  k get deployment celeryworker-knowledge-admin-backend -n "$NAMESPACE" >/dev/null
}

python3 "$SCRIPT_DIR/verify_r5_knowledge_candidate_bundle.py" --bundle "$BUNDLE"
[[ "$(release_value namespace)" == "$NAMESPACE" ]] || {
  echo 'bundle namespace mismatch' >&2
  exit 3
}
[[ "$(release_value touches_v1_resources)" == "false" ]] || {
  echo 'bundle is not a non-mutating candidate' >&2
  exit 3
}

printf 'PLAN task=R5-K3 action=%s namespace=%s release=%s\n' \
  "$ACTION" "$NAMESPACE" "$(release_value release_id)"
printf 'PLAN v1_mutation=false migration_apply=false async_writers=0\n'

if [[ "$ACTION" == "plan" ]]; then
  exit 0
fi

if [[ "$ACTION" == "cleanup" ]]; then
  k delete \
    ingressroute,networkpolicy,horizontalpodautoscaler,poddisruptionbudget,deployment,service,configmap,serviceaccount,job \
    -n "$NAMESPACE" -l 'sunmoonai.com/app=knowledge-r5' \
    --ignore-not-found=true --wait=true
  printf '{"task":"R5-K3-knowledge-candidate","result":"cleaned","external_secrets_deleted":false,"ragflow_mutated":false}\n'
  exit 0
fi

for secret in \
  harbor-registry-secret knowledge-r5-tls \
  knowledge-backend-postgresql-conn knowledge-backend-migration-postgresql-conn \
  knowledge-r5-browser-identity knowledge-admin-backend-redis-conn \
  celeryworker-knowledge-admin-backend-secret knowledge-admin-backend-secret \
  knowledge-admin-backend-s3 knowledge-info-ingest-service-binding \
  knowledge-research-retrieval-service-binding; do
  k get secret "$secret" -n "$NAMESPACE" >/dev/null
done
for configmap in knowledge-admin-backend-config knowledge-admin-backend-s3; do
  k get configmap "$configmap" -n "$NAMESPACE" >/dev/null
done
for pair in \
  'knowledge-backend-postgresql-conn DATABASE_URL' \
  'knowledge-backend-migration-postgresql-conn MIGRATION_DATABASE_URL' \
  'knowledge-r5-browser-identity ADMIN_CLIENT_ID' \
  'knowledge-r5-browser-identity ADMIN_CLIENT_SECRET' \
  'knowledge-r5-browser-identity WEB_CLIENT_ID' \
  'knowledge-r5-browser-identity WEB_CLIENT_SECRET' \
  'knowledge-admin-backend-secret RAGFLOW_API_KEY' \
  'knowledge-admin-backend-s3 S3_ACCESS_KEY_ID' \
  'knowledge-admin-backend-s3 S3_SECRET_ACCESS_KEY'; do
  read -r secret key <<<"$pair"
  require_secret_key "$secret" "$key"
done

verify_v1_names_untouched
k apply -f "$BUNDLE/00-prerequisites.yaml"
k apply -f "$BUNDLE/30-network-policies.yaml"
k apply -f "$BUNDLE/20-runtime.yaml"
k apply -f "$BUNDLE/40-ingress.yaml"

for deployment in knowledge-r5-backend-api knowledge-r5-admin-frontend knowledge-r5-web-frontend; do
  k rollout status "deployment/$deployment" -n "$NAMESPACE" --timeout="${TIMEOUT}s"
done
test "$(k get deployment knowledge-r5-backend-worker -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')" = "0"
test "$(k get deployment knowledge-r5-backend-scheduler -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')" = "0"
verify_v1_names_untouched

python3 - "$BUNDLE/release.json" <<'PY'
import json, sys
release = json.load(open(sys.argv[1], encoding="utf-8"))
print(json.dumps({
    "task": "R5-K3-knowledge-candidate",
    "result": "deployed",
    "release_id": release["release_id"],
    "backend_image": release["images"]["backend"],
    "migration_applied": False,
    "candidate_async_writers": 0,
    "v1_resources_mutated": False,
    "ragflow_mutated": False,
    "credentials_printed": False,
}, ensure_ascii=False, indent=2))
PY
