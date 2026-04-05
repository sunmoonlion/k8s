#!/bin/bash
# toutiao-app-backend 部署脚本
# 用法: ./deploy-toutiao-app-backend.sh <deploy|uninstall|status> [project_id] [namespace] [environment]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 从 app/deploy-app/ 向上 2 级到达 deploy-toutiao-app-backend/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# 从 deploy-toutiao-app-backend/ 向上 1 级到达 toutiao-app-backend/
APP_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"

TOUTIAO_BACKEND_SCRIPT_DIR="$SCRIPT_DIR"

find_k8s_root_dir() {
    local search_dir="$1"
    while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir="$(dirname "$search_dir")"
    done
    return 1
}

K8S_ROOT_DIR="$(find_k8s_root_dir "$APP_ROOT")"
if [[ -z "${K8S_ROOT_DIR:-}" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh）" 1>&2
    exit 1
fi

source "$K8S_ROOT_DIR/utils/unified-deployment-template.sh"
SCRIPT_DIR="$TOUTIAO_BACKEND_SCRIPT_DIR"

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

TOUTIAO_BACKEND_CONFIG_FILE="$SCRIPT_DIR/deploy-toutiao-app-backend.conf"
if [[ -f "$TOUTIAO_BACKEND_CONFIG_FILE" ]]; then
    source "$TOUTIAO_BACKEND_CONFIG_FILE"
    if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
    fi
    log_info "已加载配置: $TOUTIAO_BACKEND_CONFIG_FILE"
else
    log_warn "未找到配置文件: $TOUTIAO_BACKEND_CONFIG_FILE"
fi

DEFAULT_PROJECT_ID="${TOUTIAO_BACKEND_PROJECT_ID:-}"
DEFAULT_NAMESPACE="${TOUTIAO_BACKEND_NAMESPACE:-}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-}"

# 部署顺序: Namespace → Secret → ConfigMap → Ingress → App
deploy_all_components() {
    local action="$1"
    local project_id="$2"
    local namespace="$3"
    local environment="$4"

    export NAMESPACE="$namespace"
    export ENVIRONMENT="$environment"
    export PROJECT_ID="$project_id"

    # Namespace
    if [[ "${namespace_enabled:-true}" == "true" ]]; then
        local ns_script="$PROJECT_ROOT/namespace/toutiao-app-backend-namespace/deploy-toutiao-app-backend-namespace/deploy-toutiao-app-backend-namespace.sh"
        [[ -f "$ns_script" ]] && bash "$ns_script" "$action" "$project_id" "$namespace" "$environment"
    fi

    # Secrets
    if [[ "${secrets_enabled:-true}" == "true" ]]; then
        for secret_script in "$PROJECT_ROOT"/secret/*/deploy-*/deploy-*.sh; do
            [[ -f "$secret_script" ]] && bash "$secret_script" "$action" "$project_id" "$namespace" "$environment"
        done
    fi

    # ConfigMap
    if [[ "${configmap_enabled:-true}" == "true" ]]; then
        for cm_script in "$PROJECT_ROOT"/configMap/*/deploy-*/deploy-*.sh; do
            [[ -f "$cm_script" ]] && bash "$cm_script" "$action" "$project_id" "$namespace" "$environment"
        done
    fi

    # Ingress
    if [[ "${ingress_enabled:-true}" == "true" ]]; then
        local ingress_script="$PROJECT_ROOT/ingress/deploy-ingress/deploy-ingress.sh"
        [[ -f "$ingress_script" ]] && bash "$ingress_script" "$action" "$project_id" "$namespace" "$environment"
    fi

    # App (Deployment + Service)
    local app_script="$SCRIPT_DIR/deploy-toutiao-app-backend.sh"
    # App 部署由当前脚本自身处理（下方 main 函数）
}

main() {
    local action="${1:-deploy}"
    local project_id="${2:-${DEFAULT_PROJECT_ID}}"
    local namespace="${3:-${DEFAULT_NAMESPACE}}"
    local environment="${4:-${DEFAULT_ENVIRONMENT}}"

    export NAMESPACE="$namespace"
    export ENVIRONMENT="$environment"
    export ENV="${ENV:-dev}"

    local k8s_resource_dir="$APP_ROOT/resources/k8s-resource"
    local app_yaml="$k8s_resource_dir/custom-values/app/generate-app/toutiao-app-backend-generated.yaml"
    local generate_script="$k8s_resource_dir/custom-values/app/generate-app/generate-app.sh"

    if [[ -f "$generate_script" ]]; then
        bash "$generate_script"
    else
        log_error "生成脚本不存在: $generate_script"
        exit 1
    fi

    case "$action" in
        deploy)
            kubectl apply -f "$app_yaml" -n "$namespace"
            log_success "toutiao-app-backend 部署完成"
            ;;
        uninstall)
            kubectl delete -f "$app_yaml" -n "$namespace" --ignore-not-found
            log_success "toutiao-app-backend 卸载完成"
            ;;
        status)
            kubectl get deployment toutiao-app-backend -n "$namespace" 2>/dev/null || log_warn "Deployment 不存在"
            kubectl get service toutiao-app-backend -n "$namespace" 2>/dev/null || log_warn "Service 不存在"
            ;;
        *)
            log_error "无效操作: $action"
            echo "用法: $0 <deploy|uninstall|status> [project_id] [namespace] [environment]"
            exit 1
            ;;
    esac
}

main "${ORIGINAL_ARGS[@]}"
