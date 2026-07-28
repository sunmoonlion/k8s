#!/usr/bin/env bash

# Reuse the accepted P0-007E isolated FastAPI Admin harness, then replace only
# its frontend workload with the Vue reference profile. No business App
# Deployment, image or traffic is mutated.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
NAMESPACE="app-platform-dev"
BACKEND_IMAGE=""
BOOTSTRAP_FRONTEND_IMAGE=""
VUE_FRONTEND_IMAGE=""
DEPLOYMENT_ID="b6-vue-reference-v1"
MODE="plan"

usage() {
  cat <<'EOF'
Usage: deploy_b6_vue_admin_pair_kind.sh [--apply|--cleanup] [options]
  --backend-image IMAGE@sha256:DIGEST
  --bootstrap-frontend-image IMAGE@sha256:DIGEST
  --vue-frontend-image IMAGE@sha256:DIGEST
  --deployment-id ID
  --kubeconfig PATH
  --namespace NAME

The accepted Next image is used only to let the immutable P0-007E harness
reach its stable bootstrap point. The script then changes only the isolated
frontend Deployment to the Vue/Nginx profile and verifies 2/2 readiness.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE="apply"; shift ;;
    --cleanup) MODE="cleanup"; shift ;;
    --backend-image) BACKEND_IMAGE="$2"; shift 2 ;;
    --bootstrap-frontend-image) BOOTSTRAP_FRONTEND_IMAGE="$2"; shift 2 ;;
    --vue-frontend-image) VUE_FRONTEND_IMAGE="$2"; shift 2 ;;
    --deployment-id) DEPLOYMENT_ID="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

k() {
  env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"
}

cleanup() {
  "$SCRIPT_DIR/deploy_p0_007e_kind.sh" \
    --cleanup \
    --kubeconfig "$KUBECONFIG_PATH" \
    --namespace "$NAMESPACE"
  "$SCRIPT_DIR/provision_p0_007e_identity.sh" \
    --cleanup \
    --kubeconfig "$KUBECONFIG_PATH" \
    --namespace "$NAMESPACE"
  printf 'V5-B6.2 Vue Admin reference pair cleaned\n'
}

if [[ "$MODE" == "cleanup" ]]; then
  cleanup
  exit 0
fi

printf 'PLAN isolated-pair=Vue-Admin+FastAPI-Admin namespace=%s deployment=%s\n' \
  "$NAMESPACE" "$DEPLOYMENT_ID"
[[ "$MODE" == "apply" ]] || exit 0

for image in "$BACKEND_IMAGE" "$BOOTSTRAP_FRONTEND_IMAGE" "$VUE_FRONTEND_IMAGE"; do
  [[ "$image" =~ @sha256:[a-f0-9]{64}$ ]] || {
    printf 'all images must be immutable digest references\n' >&2
    exit 1
  }
done

"$SCRIPT_DIR/provision_p0_007e_identity.sh" \
  --apply \
  --kubeconfig "$KUBECONFIG_PATH" \
  --namespace "$NAMESPACE"

"$SCRIPT_DIR/deploy_p0_007e_kind.sh" \
  --apply \
  --backend-image "$BACKEND_IMAGE" \
  --frontend-image "$BOOTSTRAP_FRONTEND_IMAGE" \
  --deployment-id "${DEPLOYMENT_ID}-bootstrap" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --namespace "$NAMESPACE"

k patch deployment tpl-admin-frontend-p0-007e \
  -n "$NAMESPACE" \
  --type=json \
  -p="[
    {\"op\":\"replace\",\"path\":\"/spec/template/metadata/annotations/sunmoonai.com~1deployment-id\",\"value\":\"${DEPLOYMENT_ID}\"},
    {\"op\":\"add\",\"path\":\"/spec/template/metadata/labels/sunmoonai.com~1profile\",\"value\":\"vue-reference\"},
    {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/image\",\"value\":\"${VUE_FRONTEND_IMAGE}\"},
    {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/ports/0/containerPort\",\"value\":8080},
    {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/readinessProbe/httpGet/path\",\"value\":\"/health\"},
    {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/livenessProbe/httpGet/path\",\"value\":\"/health\"},
    {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/securityContext/runAsUser\",\"value\":101}
  ]" >/dev/null

k rollout status deployment/tpl-admin-frontend-p0-007e \
  -n "$NAMESPACE" --timeout=240s

frontend_ready="$(k get deployment tpl-admin-frontend-p0-007e -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')"
backend_ready="$(k get deployment tpl-admin-backend-p0-007e -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')"
frontend_image="$(k get deployment tpl-admin-frontend-p0-007e -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')"
frontend_port="$(k get deployment tpl-admin-frontend-p0-007e -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}')"

[[ "$frontend_ready" == 2 && "$backend_ready" == 2 ]] || {
  printf 'B6.2 pair is not ready at frontend=2 backend=2\n' >&2
  exit 1
}
[[ "$frontend_image" == "$VUE_FRONTEND_IMAGE" && "$frontend_port" == 8080 ]] || {
  printf 'B6.2 Vue frontend tuple is not active\n' >&2
  exit 1
}

printf 'V5-B6.2 isolated Vue+FastAPI pair deployed frontend=%s backend=%s\n' \
  "$frontend_ready" "$backend_ready"
