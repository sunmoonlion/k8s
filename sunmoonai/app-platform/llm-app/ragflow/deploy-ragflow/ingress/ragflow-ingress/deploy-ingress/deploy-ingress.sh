#!/usr/bin/env bash
set -euo pipefail

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

source "$K8S_ROOT_DIR/utils/unified-deployment-template.sh"
SCRIPT_DIR="$RAGFLOW_INGRESS_SCRIPT_DIR"

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

RAGFLOW_CONFIG_FILE="$APP_ROOT/deploy-ragflow/app/deploy-app/deploy-ragflow.conf"
source "$RAGFLOW_CONFIG_FILE"
if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping
fi

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    local action="${1:-deploy}"
    local project_id="${2:-${RAGFLOW_PROJECT_ID}}"
    local namespace="${3:-${RAGFLOW_NAMESPACE}}"
    local release_name="${RAGFLOW_RELEASE_PREFIX}-${project_id}"
    local template="$APP_ROOT/resources/k8s-resource/templates/ingress/ingress.yaml"
    local output="$APP_ROOT/resources/k8s-resource/custom-values/ingress/ragflow-ingress/ragflow-ingress-generated.yaml"

    read_k8s_config
    setup_kubectl_environment

    case "$action" in
        deploy)
            export NAMESPACE="$namespace"
            export UNIFIED_HOST="$RAGFLOW_UNIFIED_HOST"
            export SERVICE_NAME="$release_name"
            sed -e 's/{{\([^}]*\)}}/${\1}/g' "$template" | envsubst > "$output"
            kubectl apply -f "$output"
            ;;
        uninstall)
            kubectl delete ingressroute ragflow-ingress -n "$namespace" --ignore-not-found
            ;;
        status)
            kubectl get ingressroute ragflow-ingress -n "$namespace"
            ;;
        *)
            echo "用法: $0 [--cluster KIND] <deploy|uninstall|status> [project_id] [namespace]" >&2
            exit 1
            ;;
    esac
}

main "$@"
