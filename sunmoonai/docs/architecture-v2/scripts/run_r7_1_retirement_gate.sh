#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
NAMESPACE="${NAMESPACE:-app-platform-dev}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
EVIDENCE="$ROOT/sunmoonai/docs/architecture-v2/evidence/R7.1-retirement/result.json"
EVIDENCE_DIR="$(dirname "$EVIDENCE")"
BROWSER_GATE="$ROOT/sunmoonai/docs/architecture-v2/scripts/verify_r3_template_browser.mjs"
CROSS_APP_ATTEMPTS="${CROSS_APP_ATTEMPTS:-2}"

browser_gate() {
  local app="$1" tmp
  tmp="$(mktemp "$EVIDENCE_DIR/.${app}-browser.XXXXXX")"
  KUBECONFIG="$KUBECONFIG_PATH" \
  R3_NAMESPACE="$NAMESPACE" \
  R3_PROVIDER_NAMESPACE="$NAMESPACE" \
  R3_APP="${app}-r5" \
  R3_LOGICAL_APP="$app" \
  R3_BROWSER_TASK="architecture-v2-r7.1-${app}-browser" \
  R3_ADMIN_ORIGIN="https://${app}-admin.sunmoonai.com:30443" \
  R3_WEB_ORIGIN="https://${app}.sunmoonai.com:30443" \
  R3_OPERATOR_SECRET=architecture-v2-browser-operator \
  node "$BROWSER_GATE" >"$tmp"
  mv "$tmp" "$EVIDENCE_DIR/${app}-browser.json"
  jq -e '.result == "passed"' "$EVIDENCE_DIR/${app}-browser.json" >/dev/null
}

mkdir -p "$EVIDENCE_DIR"

bash "$ROOT/sunmoonai/docs/architecture-v2/scripts/provision_architecture_v2_browser_operator_kind.sh" \
  --kubeconfig "$KUBECONFIG_PATH" --namespace "$NAMESPACE"

"$PYTHON_BIN" "$ROOT/sunmoonai/docs/architecture-v2/scripts/retire_r7_legacy_kind.py" \
  --kubeconfig "$KUBECONFIG_PATH" --namespace "$NAMESPACE"

for app in info knowledge investment; do
  "$PYTHON_BIN" "$ROOT/sunmoonai/app-platform/${app}-app/deployment/deploy.py" \
    drift --kubeconfig "$KUBECONFIG_PATH"
done

for app in info knowledge investment; do
  browser_gate "$app"
done

cross_app_passed=false
for attempt in $(seq 1 "$CROSS_APP_ATTEMPTS"); do
  attempt_output="$EVIDENCE_DIR/cross-app-vertical-attempt-${attempt}.json"
  if "$PYTHON_BIN" "$ROOT/sunmoonai/docs/architecture-v2/scripts/verify_r6_cross_app_vertical_kind.py" \
    --kubeconfig "$KUBECONFIG_PATH" --namespace "$NAMESPACE" \
    --output "$attempt_output"; then
    cp "$attempt_output" "$EVIDENCE_DIR/cross-app-vertical.json"
    cross_app_passed=true
    break
  fi
  if [[ "$attempt" -lt "$CROSS_APP_ATTEMPTS" ]]; then
    echo "R7.1 cross-app vertical attempt $attempt failed; retrying after 10 seconds" >&2
    sleep 10
  fi
done

if [[ "$cross_app_passed" != true ]]; then
  echo "R7.1 cross-app vertical failed after $CROSS_APP_ATTEMPTS attempts" >&2
  exit 1
fi

"$PYTHON_BIN" "$ROOT/sunmoonai/docs/architecture-v2/scripts/verify_r7_1_retirement_kind.py" \
  --kubeconfig "$KUBECONFIG_PATH" --namespace "$NAMESPACE" --output "$EVIDENCE"
