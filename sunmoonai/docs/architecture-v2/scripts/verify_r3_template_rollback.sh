#!/usr/bin/env bash

# Verify that the R3 Web candidate can roll back to the accepted R2 digest with
# Kubernetes native rollout history, and can then be reconciled forward from the
# locked R3 manifest. No mutable tag is used.

set -euo pipefail
umask 077

KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
NAMESPACE="${R3_NAMESPACE:-tpl-architecture-v2-r3}"
APP="tpl"
BUNDLE=""
R2_IMAGE=""
WEB_ORIGIN="${R3_WEB_ORIGIN:-https://tpl-web-r3.sunmoonai.com:30443}"
CA_CERT="${R3_CA_CERT:-$HOME/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt}"

usage() {
  printf 'usage: %s --bundle DIR --r2-image REPOSITORY@sha256:DIGEST\n' "$0" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle)
      BUNDLE="${2:-}"
      shift 2
      ;;
    --r2-image)
      R2_IMAGE="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

[[ -f "${BUNDLE}/20-runtime.yaml" && -f "${BUNDLE}/release.json" ]] || {
  usage
  exit 2
}
[[ "$R2_IMAGE" =~ @sha256:[0-9a-f]{64}$ ]] || {
  printf 'R2 image must use an immutable digest\n' >&2
  exit 2
}
[[ -f "$CA_CERT" ]] || {
  printf 'strict TLS CA certificate is absent: %s\n' "$CA_CERT" >&2
  exit 1
}

k() { env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"; }

candidate_image="$(python3 - "$BUNDLE" <<'PY'
import json, pathlib, sys
release = json.loads((pathlib.Path(sys.argv[1]) / "release.json").read_text())
print(release["images"]["web"])
PY
)"
deployment="${APP}-web-frontend"

assert_deployment() {
  local expected_image="$1" expected_probe="$2" actual
  actual="$(k get deployment "$deployment" -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}{"|"}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"|"}{.status.readyReplicas}{"|"}{.status.replicas}')"
  [[ "$actual" == "${expected_image}|${expected_probe}|2|2" ]] || {
    printf 'rollback deployment mismatch expected=%s|%s|2|2 actual=%s\n' \
      "$expected_image" "$expected_probe" "$actual" >&2
    exit 1
  }
}

strict_get() {
  local endpoint="$1"
  curl --fail --silent --show-error --noproxy '*' \
    --cacert "$CA_CERT" \
    --resolve "$(python3 - "$WEB_ORIGIN" <<'PY'
from urllib.parse import urlsplit
import sys
value = urlsplit(sys.argv[1])
print(f"{value.hostname}:{value.port or 443}:127.0.0.1")
PY
)" \
    "${WEB_ORIGIN}${endpoint}" >/dev/null
}

printf 'R3_ROLLBACK_STAGE=seed_r2_revision\n'
k patch deployment "$deployment" -n "$NAMESPACE" --type=strategic -p "$(python3 - "$R2_IMAGE" <<'PY'
import json, sys
image = sys.argv[1]
print(json.dumps({
    "spec": {"template": {
        "metadata": {"annotations": {"sunmoonai.com/release-id": "r2-rollback"}},
        "spec": {"containers": [{
            "name": "web",
            "image": image,
            "startupProbe": {"httpGet": {"path": "/zh-CN"}},
            "readinessProbe": {"httpGet": {"path": "/zh-CN"}},
            "livenessProbe": {"httpGet": {"path": "/zh-CN"}},
        }]},
    }}
}, separators=(",", ":")))
PY
)" >/dev/null
k rollout status "deployment/${deployment}" -n "$NAMESPACE" --timeout=300s >/dev/null
assert_deployment "$R2_IMAGE" /zh-CN

printf 'R3_ROLLBACK_STAGE=seed_r3_revision\n'
k apply -f "${BUNDLE}/20-runtime.yaml" >/dev/null
k rollout status "deployment/${deployment}" -n "$NAMESPACE" --timeout=300s >/dev/null
assert_deployment "$candidate_image" /healthz

printf 'R3_ROLLBACK_STAGE=native_undo\n'
k rollout undo "deployment/${deployment}" -n "$NAMESPACE" >/dev/null
k rollout status "deployment/${deployment}" -n "$NAMESPACE" --timeout=300s >/dev/null
assert_deployment "$R2_IMAGE" /zh-CN
strict_get /zh-CN

printf 'R3_ROLLBACK_STAGE=forward_reconcile\n'
k apply -f "${BUNDLE}/20-runtime.yaml" >/dev/null
k rollout status "deployment/${deployment}" -n "$NAMESPACE" --timeout=300s >/dev/null
assert_deployment "$candidate_image" /healthz
strict_get /healthz

printf '{"task":"architecture-v2-r3-rollback","result":"passed","native_undo":true,"strict_tls_r2":200,"forward_reconcile":true,"strict_tls_r3_health":200,"credentials_printed":false}\n'
