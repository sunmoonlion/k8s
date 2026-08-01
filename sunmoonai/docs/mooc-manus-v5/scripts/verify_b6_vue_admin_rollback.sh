#!/usr/bin/env bash

# Prove an independent recovery path for the non-default Vue reference profile:
# Vue -> accepted Next Admin -> Vue, while the canonical FastAPI Admin and all
# business App Deployments remain unchanged.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
NAMESPACE="app-platform-dev"
NEXT_IMAGE=""
VUE_IMAGE=""

usage() {
  cat <<'EOF'
Usage: verify_b6_vue_admin_rollback.sh [options]
  --next-image IMAGE@sha256:DIGEST
  --vue-image IMAGE@sha256:DIGEST
  --kubeconfig PATH
  --namespace NAME
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --next-image) NEXT_IMAGE="$2"; shift 2 ;;
    --vue-image) VUE_IMAGE="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

for image in "$NEXT_IMAGE" "$VUE_IMAGE"; do
  [[ "$image" =~ @sha256:[a-f0-9]{64}$ ]] || {
    printf 'both frontend images must be immutable digest references\n' >&2
    exit 1
  }
done

k() {
  env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"
}

business_snapshot() {
  k get deployments -n "$NAMESPACE" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}' \
    | grep -E '^(info|knowledge|research)-' \
    | sort
}

patch_frontend() {
  local image="$1"
  local port="$2"
  local health="$3"
  local uid="$4"
  local profile="$5"
  local deployment_id="$6"
  k patch deployment tpl-admin-frontend-p0-007e \
    -n "$NAMESPACE" \
    --type=json \
    -p="[
      {\"op\":\"replace\",\"path\":\"/spec/template/metadata/annotations/sunmoonai.com~1deployment-id\",\"value\":\"${deployment_id}\"},
      {\"op\":\"replace\",\"path\":\"/spec/template/metadata/labels/sunmoonai.com~1profile\",\"value\":\"${profile}\"},
      {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/image\",\"value\":\"${image}\"},
      {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/ports/0/containerPort\",\"value\":${port}},
      {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/readinessProbe/httpGet/path\",\"value\":\"${health}\"},
      {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/livenessProbe/httpGet/path\",\"value\":\"${health}\"},
      {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/securityContext/runAsUser\",\"value\":${uid}}
    ]" >/dev/null
  k rollout status deployment/tpl-admin-frontend-p0-007e \
    -n "$NAMESPACE" --timeout=240s
}

backend_before="$(k get deployment tpl-admin-backend-p0-007e -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')"
business_before="$(business_snapshot)"
restored=0

restore_vue() {
  if [[ "$restored" == 0 ]]; then
    patch_frontend \
      "$VUE_IMAGE" 8080 /health 101 vue-reference \
      b6-vue-reference-restored
    restored=1
  fi
}
trap restore_vue EXIT INT TERM HUP

printf 'B6.2 rollback stage=accepted-next\n'
patch_frontend \
  "$NEXT_IMAGE" 3000 /healthz 1001 next-default \
  b6-vue-rollback-next
KUBECONFIG="$KUBECONFIG_PATH" \
  P0_007E_NAMESPACE="$NAMESPACE" \
  node "$SCRIPT_DIR/verify_p0_007e_browser.mjs"

printf 'B6.2 rollback stage=restore-vue\n'
restore_vue
KUBECONFIG="$KUBECONFIG_PATH" \
  B6_VUE_NAMESPACE="$NAMESPACE" \
  node "$SCRIPT_DIR/verify_b6_vue_admin_pair.mjs"

backend_after="$(k get deployment tpl-admin-backend-p0-007e -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')"
business_after="$(business_snapshot)"
[[ "$backend_before" == "$backend_after" ]] || {
  printf 'backend image changed during frontend recovery test\n' >&2
  exit 1
}
[[ "$business_before" == "$business_after" ]] || {
  printf 'business App Deployments changed during frontend recovery test\n' >&2
  exit 1
}

printf '%s\n' \
  '{"task":"V5-P0-008B-B6.2-vue-admin-rollback","result":"passed","path":"vue->next->vue","backend_unchanged":true,"business_deployments_unchanged":true,"credentials_printed":false,"tokens_printed":false}'
