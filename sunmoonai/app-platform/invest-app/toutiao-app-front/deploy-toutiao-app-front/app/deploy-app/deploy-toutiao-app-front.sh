#!/bin/bash
# toutiao-app-front 部署脚本
# 用法: ./deploy-toutiao-app-front.sh <deploy|uninstall|status> [project_id] [namespace] [environment]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"

TOUTIAO_FRONT_SCRIPT_DIR="$SCRIPT_DIR"

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
SCRIPT_DIR="$TOUTIAO_FRONT_SCRIPT_DIR"

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

TOUTIAO_FRONT_CONFIG_FILE="$SCRIPT_DIR/deploy-toutiao-app-front.conf"
if [[ -f "$TOUTIAO_FRONT_CONFIG_FILE" ]]; then
    source "$TOUTIAO_FRONT_CONFIG_FILE"
    if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
    fi
    log_info "已加载配置: $TOUTIAO_FRONT_CONFIG_FILE"
else
    log_warn "未找到配置文件: $TOUTIAO_FRONT_CONFIG_FILE"
fi

DEFAULT_PROJECT_ID="${TOUTIAO_FRONT_PROJECT_ID:-}"
DEFAULT_NAMESPACE="${TOUTIAO_FRONT_NAMESPACE:-}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-}"

main() {
    local action="${1:-deploy}"
    local project_id="${2:-${DEFAULT_PROJECT_ID}}"
    local namespace="${3:-${DEFAULT_NAMESPACE}}"
    local environment="${4:-${DEFAULT_ENVIRONMENT}}"

    export NAMESPACE="$namespace"
    export ENVIRONMENT="$environment"
    export ENV="${ENV:-dev}"

    local k8s_resource_dir="$APP_ROOT/resources/k8s-resource"
    local app_yaml="$k8s_resource_dir/custom-values/app/generate-app/toutiao-app-front-generated.yaml"
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
            log_success "toutiao-app-front 部署完成"
            ;;
        uninstall)
            kubectl delete -f "$app_yaml" -n "$namespace" --ignore-not-found
            log_success "toutiao-app-front 卸载完成"
            ;;
        status)
            kubectl get deployment toutiao-app-front -n "$namespace" 2>/dev/null || log_warn "Deployment 不存在"
            kubectl get service toutiao-app-front -n "$namespace" 2>/dev/null || log_warn "Service 不存在"
            ;;
        *)
            log_error "无效操作: $action"
            exit 1
            ;;
    esac
}

main "${ORIGINAL_ARGS[@]}"
