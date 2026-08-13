#!/usr/bin/env bash

# Reconcile and verify the three formal Architecture v2 instances as one
# release operation.  External broker/Redis/service bindings are part of the
# formal apply path, so a data-platform restart cannot leave the read-only R7
# verifier observing stale runtime credentials.

set -euo pipefail
umask 077

ROOT="${ARCH_V2_WORKSPACE_ROOT:-/home/zymun}"
K8S_ROOT="${ROOT}/k8s"
KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/kind-config}"
NAMESPACE="${ARCH_V2_NAMESPACE:-app-platform-dev}"
EVIDENCE_DIR="${K8S_ROOT}/sunmoonai/docs/architecture-v2/evidence/R7-release"
SCRIPTS="${K8S_ROOT}/sunmoonai/docs/architecture-v2/scripts"
BROWSER_GATE="${SCRIPTS}/verify_r3_template_browser.mjs"
BROWSER_OPERATOR_SECRET="${ARCH_V2_BROWSER_OPERATOR_SECRET:-architecture-v2-browser-operator}"

stage() {
  printf 'R7_INSTANCE_STAGE=%s\n' "$1" >&2
}

browser_gate() {
  local app="$1" resource_app="${1}-r5"
  local admin_origin="https://${app}-admin.sunmoonai.com:30443"
  local web_origin="https://${app}.sunmoonai.com:30443"
  local output="${EVIDENCE_DIR}/${app}-browser.json"
  local temporary

  temporary="$(mktemp "${EVIDENCE_DIR}/.${app}-browser.XXXXXX")"
  if ! KUBECONFIG="$KUBECONFIG_PATH" \
    R3_NAMESPACE="$NAMESPACE" \
    R3_PROVIDER_NAMESPACE="$NAMESPACE" \
    R3_APP="$resource_app" \
    R3_LOGICAL_APP="$app" \
    R3_BROWSER_TASK="architecture-v2-r7-${app}-browser" \
    R3_ADMIN_ORIGIN="$admin_origin" \
    R3_WEB_ORIGIN="$web_origin" \
    R3_OPERATOR_SECRET="$BROWSER_OPERATOR_SECRET" \
    node "$BROWSER_GATE" >"$temporary"; then
    rm -f "$temporary"
    return 1
  fi
  mv "$temporary" "$output"
  python3 -m json.tool "$output"
}

mkdir -p "$EVIDENCE_DIR"
cd "$K8S_ROOT"

stage template_evidence
jq -e '.result == "passed"' \
  "$EVIDENCE_DIR/template/result.json" >/dev/null

for app in info knowledge investment; do
  formal="sunmoonai/app-platform/${app}-app/deployment/deploy.py"
  stage "${app}_formal_apply"
  python3 "$formal" apply --kubeconfig "$KUBECONFIG_PATH"
  stage "${app}_zero_drift"
  python3 "$formal" drift --kubeconfig "$KUBECONFIG_PATH"
done

for app in info knowledge investment; do
  stage "${app}_strict_tls_browser"
  browser_gate "$app"
done

stage cross_app_vertical
python3 "$SCRIPTS/verify_r6_cross_app_vertical_kind.py" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --namespace "$NAMESPACE" \
  --output "$EVIDENCE_DIR/cross-app-vertical.json"

stage final_machine_gate
python3 "$SCRIPTS/verify_r7_release_kind.py" \
  --workspace-root "$ROOT" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --namespace "$NAMESPACE" \
  --output "$EVIDENCE_DIR/result.json"

stage passed
