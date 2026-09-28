#!/usr/bin/env bash
# Shared cluster consumer; cloud execution 未经实机验证.

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" action "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"
set -euo pipefail
set +x
export DISABLE_AUTO_CLEANUP=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAGFLOW_INGRESS_SCRIPT_DIR="$SCRIPT_DIR"
APP_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
K8S_ROOT_DIR="$APP_ROOT"
while [[ "$K8S_ROOT_DIR" != "/" && ! -f "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh" ]]; do
    K8S_ROOT_DIR="$(dirname "$K8S_ROOT_DIR")"
done
[[ -f "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh" ]] || {
    echo "[ERROR] 无法定位 k8s 根目录" >&2
    exit 1
}

source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"
source "$K8S_ROOT_DIR/utils/deploy-target.sh"
log_info() { printf '%s\n' "$*"; }
log_success() { printf '%s\n' "$*"; }
log_error() { printf '%s\n' "$*" >&2; }
ragflow_kube() {
    timeout 25s "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" --request-timeout=10s "$@"
}
SCRIPT_DIR="$RAGFLOW_INGRESS_SCRIPT_DIR"

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

RAGFLOW_CONFIG_FILE="$APP_ROOT/deploy-ragflow/app/deploy-app/deploy-ragflow.conf"
REQUESTED_CLUSTER="${CLUSTER:-}"
[[ -f "$RAGFLOW_CONFIG_FILE" && ! -L "$RAGFLOW_CONFIG_FILE" ]] || { log_error 'RAGFlow configuration missing'; exit 1; }
source "$RAGFLOW_CONFIG_FILE" >/dev/null 2>&1 || { log_error 'RAGFlow configuration failed'; exit 1; }
if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping
fi

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    [[ $# -le 5 ]] || { log_error 'Too many arguments'; return 2; }
    local action="${1:-deploy}"
    local project_id="${2:-${RAGFLOW_PROJECT_ID}}"
    local namespace="${3:-${RAGFLOW_NAMESPACE}}"
    local release_name="${RAGFLOW_RELEASE_PREFIX}-${project_id}"
    local template="$APP_ROOT/resources/k8s-resource/templates/ingress/ingress.yaml"
    local output="$APP_ROOT/resources/k8s-resource/custom-values/ingress/ragflow-ingress/ragflow-ingress-generated.yaml"
    case "$action" in deploy|status|uninstall) ;; *) log_error 'Use deploy/status/uninstall'; return 2 ;; esac

    [[ "$REQUESTED_CLUSTER" =~ ^(KIND|C[1-9][0-9]*)$ && "${CLUSTER:-}" == "$REQUESTED_CLUSTER" ]] || {
        log_error 'Explicit cluster required; configuration must not replace it'; return 1;
    }
    [[ "$namespace" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ && ${#namespace} -le 63 &&
       "$release_name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ && ${#release_name} -le 53 ]] || {
        log_error 'Invalid namespace or Helm release name'; return 1;
    }
    sunmoon_deploy_target_init "$K8S_ROOT_DIR" || return 1

    case "$action" in
        deploy)
            python3 -B "$APP_ROOT/resources/render_ingress.py" "$template" "$output" \
                "$namespace" "$RAGFLOW_UNIFIED_HOST" "$release_name" || return 1
            ragflow_kube get service "$release_name" -n "$namespace" >/dev/null || return 1
            sunmoon_deploy_target_check "$K8S_ROOT_DIR" || return 1
            ragflow_kube apply --server-side --field-manager=sunmoon-ragflow -f "$output" -n "$namespace" || return 1
            ;;
        uninstall)
            sunmoon_deploy_target_check "$K8S_ROOT_DIR" || return 1
            ragflow_kube delete ingressroute ragflow-ingress -n "$namespace" --ignore-not-found --wait=false || return 1
            ;;
        status)
            ragflow_kube get ingressroute ragflow-ingress -n "$namespace"
            ;;
        *)
            echo "用法: $0 [--cluster KIND] <deploy|uninstall|status> [project_id] [namespace]" >&2
            exit 1
            ;;
    esac
}

main "$@"
