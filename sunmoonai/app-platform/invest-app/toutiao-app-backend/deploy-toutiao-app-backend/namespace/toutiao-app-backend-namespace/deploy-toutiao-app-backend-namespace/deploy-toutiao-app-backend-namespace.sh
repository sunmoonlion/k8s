#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-toutiao-app-backend-namespace.conf"
# deploy-toutiao-app-backend-namespace/ -> toutiao-app-backend-namespace/ -> namespace/ -> deploy-toutiao-app-backend/ -> toutiao-app-backend/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
K8S_RESOURCE_DIR="$PROJECT_ROOT/resources/k8s-resource"
NS_YAML="$K8S_RESOURCE_DIR/custom-values/namespace/toutiao-app-backend-namespace/generate-toutiao-app-backend-namespace/toutiao-app-backend-namespace-generated.yaml"

log_info()    { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error()   { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn()    { echo -e "\033[33m[WARN]\033[0m $*"; }

[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

main() {
    local action="${1:-deploy}"
    local namespace="${3:-${NAMESPACE:-invest-app-dev}}"
    export NAMESPACE="$namespace" ENVIRONMENT="${4:-${ENVIRONMENT:-development}}" ENV="${ENV:-dev}"

    local generate_script="$K8S_RESOURCE_DIR/custom-values/namespace/toutiao-app-backend-namespace/generate-toutiao-app-backend-namespace/generate-toutiao-app-backend-namespace.sh"
    [[ -f "$generate_script" ]] && bash "$generate_script" || { log_error "生成脚本不存在: $generate_script"; exit 1; }

    case "$action" in
        deploy)   kubectl apply -f "$NS_YAML"; log_success "Namespace 部署完成" ;;
        uninstall) kubectl delete -f "$NS_YAML" --ignore-not-found; log_success "Namespace 卸载完成" ;;
        status)   kubectl get namespace "$namespace" 2>/dev/null || log_warn "Namespace 不存在: $namespace" ;;
        generate) log_success "仅生成 YAML，未部署" ;;
        *) log_error "无效操作: $action"; exit 1 ;;
    esac
}

main "$@"
