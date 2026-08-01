#!/usr/bin/env bash
# Verify the generated, default-suspended Info delivery-outbox scanner manifest.
# This is deliberately a dry-run only; it never creates a CronJob.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: verify_p0_006_scanner_manifest.sh [--kubeconfig PATH] [--validate-cluster]

Without --validate-cluster the script verifies generation and the
least-privilege manifest structure locally.  --validate-cluster additionally
runs kubectl apply --dry-run=client --validate=false; it does not modify the
cluster.
EOF
}

VALIDATE_CLUSTER=false
KUBECONFIG_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kubeconfig)
      KUBECONFIG_PATH="${2:?--kubeconfig requires a path}"
      shift 2
      ;;
    --validate-cluster)
      VALIDATE_CLUSTER=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKER_ROOT="$K8S_ROOT/app-platform/info-app/celeryworker-info-admin-backend"
GENERATOR="$WORKER_ROOT/resources/k8s-resource/custom-values/app/generate-app/generate-app.sh"
GENERATED="$WORKER_ROOT/resources/k8s-resource/custom-values/app/generate-app/celeryworker-info-admin-backend-generated.yaml"

test -x "$GENERATOR"

(
  cd "$WORKER_ROOT"
  NAMESPACE="${P0_NAMESPACE:-app-platform-dev}" \
  ENVIRONMENT=development \
  ENV=dev \
  CELERYWORKER_INFO_ADMIN_BACKEND_TAG="${P0_INFO_OUTBOX_TAG:-1.0.1}" \
  INFO_DELIVERY_OUTBOX_SCANNER_SUSPEND=true \
  bash "$GENERATOR"
)

test -f "$GENERATED"
grep -q '^kind: CronJob$' "$GENERATED"
grep -q '^  suspend: true$' "$GENERATED"
test "$(grep -c '^automountServiceAccountToken: false$' "$GENERATED")" -ge 2

SCANNER_SECTION="$(awk '/^kind: CronJob$/{enabled=1} enabled {print}' "$GENERATED")"
grep -q '^  name: info-delivery-outbox-scanner$' <<<"$SCANNER_SECTION"
grep -q 'app.cli.drain_delivery_outbox' <<<"$SCANNER_SECTION"
grep -q 'celeryworker-info-admin-backend-secret' <<<"$SCANNER_SECTION"
grep -q 'info-admin-backend-postgresql-conn' <<<"$SCANNER_SECTION"
if grep -Eq '^                name: (info-knowledge-ingest-client|info-admin-backend-secret)$' <<<"$SCANNER_SECTION"; then
  echo "scanner manifest received a forbidden credential secret" >&2
  exit 1
fi

if [[ "$VALIDATE_CLUSTER" == true ]]; then
  KUBECTL=(kubectl)
  if [[ -n "$KUBECONFIG_PATH" ]]; then
    KUBECTL+=(--kubeconfig "$KUBECONFIG_PATH")
  fi
  "${KUBECTL[@]}" apply --dry-run=client --validate=false -f "$GENERATED" >/dev/null
fi

echo '{"task":"V5-P0-006-scanner-manifest","result":"passed","scanner_default_suspended":true,"service_account_token_mounted":false,"knowledge_service_credential_mounted":false}'
