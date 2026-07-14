#!/usr/bin/env bash

# Read-only Casdoor runtime/UI readiness gate.
# It deliberately checks the same invariants used by the deployment scripts,
# without printing environment variables, Secret values, cookies or tokens.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-${HOME}/.kube/kind-config}"
NAMESPACE="${P0_NAMESPACE:-app-platform-dev}"
RELEASE="${P0_CASDOOR_RELEASE:-casdoor-sunmoonai}"

usage() {
    echo "Usage: $0 [--kubeconfig PATH] [--namespace NAME] [--release NAME]" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
        --namespace) NAMESPACE="$2"; shift 2 ;;
        --release) RELEASE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

export KUBECONFIG="$KUBECONFIG_PATH"

kubectl rollout status "deployment/${RELEASE}" -n "$NAMESPACE" --timeout=180s >/dev/null
POD="$(kubectl get pods -n "$NAMESPACE" \
    -l "app.kubernetes.io/instance=${RELEASE}" \
    -o jsonpath='{range .items[?(@.status.containerStatuses[0].ready==true)]}{.metadata.name}{"\n"}{end}' \
    | head -n 1)"
[[ -n "$POD" ]] || { echo '{"result":"failed","reason":"no_ready_pod"}'; exit 1; }

kubectl exec -n "$NAMESPACE" "$POD" -- sh -ec '
    set -eu
    test -f /conf/app.conf
    grep -Eq "^[[:space:]]*runmode[[:space:]]*=[[:space:]]*prod[[:space:]]*$" /conf/app.conf
    grep -Eq "^[[:space:]]*copyrequestbody[[:space:]]*=[[:space:]]*true[[:space:]]*$" /conf/app.conf
    test -s /web/build/index.html
    test -d /web/build/static/js
    test -d /web/build/static/css
    ! grep -qE "fonts\\.googleapis\\.com|cdn\\.casbin\\.org|cdn\\.casdoor\\.com" /web/build/index.html
    ! grep -Rql "fonts\\.googleapis\\.com" /web/build/static/css
    test -z "$(find /web/build/static/js -type f -name '*.js' -exec grep -l "cdn\\.casdoor\\.com" {} + 2>/dev/null)"
    probe() {
      path="$1"
      if command -v curl >/dev/null 2>&1; then
        code="$(curl -fsS -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:8000${path}")"
      elif command -v wget >/dev/null 2>&1; then
        wget -q -O /dev/null --timeout=5 "http://127.0.0.1:8000${path}"
        code=200
      else
        return 1
      fi
      case "$code" in 2??) ;; *) echo "${path}:HTTP_${code}" >&2; return 1 ;; esac
    }
    probe /
    probe /.well-known/openid-configuration
    probe /api/get-account
' >/dev/null

printf '{"task":"V5-P0-005-casdoor-runtime","result":"passed","namespace":"%s","release":"%s","pod":"%s","config":"declared","static_assets":"local_no_external_font_or_cdn","http":"root_oidc_account_2xx"}\n' \
    "$NAMESPACE" "$RELEASE" "$POD"
