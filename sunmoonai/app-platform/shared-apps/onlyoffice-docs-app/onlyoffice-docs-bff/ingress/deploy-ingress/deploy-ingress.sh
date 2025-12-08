#!/bin/bash

# ONLYOFFICE Docs Web 路由部署脚本

set -e

# 脚本目录（保存为变量，防止被统一部署模板覆盖）
ONLYOFFICE_INGRESS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
# 从 deploy-ingress/ -> ingress/ -> onlyoffice-docs/ -> app-platform/ -> sunmoonai/ -> k8s/
# 实际路径：/home/zym/k8s/sunmoonai/app-platform/shared-apps/onlyoffice-docs-app/onlyoffice-docs-bff/ingress/deploy-ingress
# 需要回到：/home/zym/k8s
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

# 导入统一部署模板（建立远程 k8s 连接）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 恢复原始的脚本目录（unified-deployment-template.sh 会重新定义 SCRIPT_DIR）
SCRIPT_DIR="$ONLYOFFICE_INGRESS_SCRIPT_DIR"
ONLYOFFICE_INGRESS_FILE="$(dirname "$SCRIPT_DIR")/ingress.yaml"
# 主配置文件路径（相对于脚本目录）
# 从 deploy-ingress/ -> ingress/ -> onlyoffice-docs/ -> deploy-onlyoffice-docs/ (向上2级)
ONLYOFFICE_MAIN_CONFIG_FILE="$(dirname "$(dirname "$SCRIPT_DIR")")/deploy-onlyoffice-docs/deploy-onlyoffice-docs.conf"

# 加载配置
load_config() {
    if [[ ! -f "$ONLYOFFICE_MAIN_CONFIG_FILE" ]]; then
        log_error "主配置文件不存在: $ONLYOFFICE_MAIN_CONFIG_FILE"
        exit 1
    fi
    
    # 加载主配置
    source "$ONLYOFFICE_MAIN_CONFIG_FILE"
    
    # 动态获取配置值
    # SERVICE_NAME: 从 PROJECT_ID 构建（格式：onlyoffice-docs-{project_id}）
    if [[ -z "${SERVICE_NAME:-}" ]]; then
        SERVICE_NAME="onlyoffice-docs-${ONLYOFFICE_PROJECT_ID:-sunmoonai}"
    fi
    
    # NAMESPACE: 从主配置获取
    NAMESPACE="${ONLYOFFICE_NAMESPACE:-app-platform-dev}"
    
    # SERVICE_PORT: 从主配置获取
    SERVICE_PORT="${ONLYOFFICE_SERVICE_PORT:-8888}"
    
    # UNIFIED_HOST: 从主配置的统一域名获取
    UNIFIED_HOST="${ONLYOFFICE_UNIFIED_HOST:-www.sunmoonai.com}"
    
    log_success "✅ 配置加载成功"
    log_info "服务名称: $SERVICE_NAME"
    log_info "命名空间: $NAMESPACE"
    log_info "服务端口: $SERVICE_PORT"
    log_info "统一域名: $UNIFIED_HOST"
}

check_ns() { kubectl get namespace "$1" >/dev/null 2>&1 || { log_error "命名空间不存在: $1"; return 1; }; }
verify_svc() { kubectl get svc -n "$1" "$SERVICE_NAME" >/dev/null 2>&1 || { log_error "服务不存在: $SERVICE_NAME"; return 1; }; }

deploy_web() {
  local ns="${1:-$NAMESPACE}"
  check_ns "$ns" || return 1
  [[ -f "$ONLYOFFICE_INGRESS_FILE" ]] || { log_error "Ingress 不存在: $ONLYOFFICE_INGRESS_FILE"; return 1; }
  verify_svc "$ns" || return 1
  local tmp=$(mktemp); cp "$ONLYOFFICE_INGRESS_FILE" "$tmp"
  sed -i "s|{{NAMESPACE}}|$ns|g; s|{{SERVICE_NAME}}|$SERVICE_NAME|g; s|{{SERVICE_PORT}}|$SERVICE_PORT|g; s|{{UNIFIED_HOST}}|$UNIFIED_HOST|g" "$tmp"
  kubectl apply -f "$tmp" && log_success "✅ ONLYOFFICE Docs Ingress 部署成功" || { log_error "❌ ONLYOFFICE Docs Ingress 部署失败"; rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

# 主函数
main() {
    local action="${1:-deploy}"
    local project_id="${2:-sunmoonai}"
    local namespace="${3:-app-platform-dev}"
    local environment="${4:-development}"
    
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        exit 1
    fi
    
    load_config
    
    case "$action" in
        "deploy")
            deploy_web "$namespace"
            ;;
        *)
            echo "用法: $0 deploy [project_id] [namespace] [environment]"
            exit 1
            ;;
    esac
}

main "$@"

