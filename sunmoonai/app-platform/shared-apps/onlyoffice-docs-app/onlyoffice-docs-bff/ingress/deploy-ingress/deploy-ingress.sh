#!/bin/bash

# ONLYOFFICE Docs Web 路由部署脚本

set -e

# 脚本目录（保存原始值，因为 unified-deployment-template.sh 会覆盖 SCRIPT_DIR）
ORIGINAL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"

# 计算项目根目录（k8s目录）
# 从 deploy-ingress/ -> ingress/ -> onlyoffice-docs/ -> app-platform/ -> sunmoonai/ -> k8s/
# 实际路径：/home/zym/k8s/sunmoonai/app-platform/shared-apps/onlyoffice-docs-app/onlyoffice-docs-bff/ingress/deploy-ingress
# 需要回到：/home/zym/k8s
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

# 计算应用根目录和资源路径（在 source 之前计算，避免 SCRIPT_DIR 被覆盖）
# 从 deploy-ingress/ -> ingress/ -> onlyoffice-docs-bff/
APP_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESOURCES_DIR="${APP_ROOT}/resources"
CUSTOM_VALUES_DIR="${RESOURCES_DIR}/custom-values"

# 导入统一部署模板（建立远程 k8s 连接）
source "$PROJECT_ROOT/../utils/unified-deployment-template.sh"

# 恢复原始的 SCRIPT_DIR
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"

# Ingress 配置文件（使用生成的 YAML 文件）
ONLYOFFICE_INGRESS_FILE="${CUSTOM_VALUES_DIR}/onlyoffice-docs-ingress-generated.yaml"

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
  
  # 自动生成 YAML 文件（如果不存在）
  if [[ ! -f "$ONLYOFFICE_INGRESS_FILE" ]]; then
    log_warn "生成的 Ingress YAML 文件不存在，自动运行生成脚本..."
    if [[ -f "$CUSTOM_VALUES_DIR/generate.sh" ]]; then
      if bash "$CUSTOM_VALUES_DIR/generate.sh"; then
        log_success "YAML 文件生成成功"
      else
        log_error "YAML 文件生成失败"
        return 1
      fi
    else
      log_error "生成脚本不存在: $CUSTOM_VALUES_DIR/generate.sh"
      return 1
    fi
  fi
  
  [[ -f "$ONLYOFFICE_INGRESS_FILE" ]] || { log_error "Ingress 不存在: $ONLYOFFICE_INGRESS_FILE"; return 1; }
  verify_svc "$ns" || return 1
  
  log_info "使用生成的 Ingress YAML: $ONLYOFFICE_INGRESS_FILE"
  
  # 直接使用生成的 YAML 文件（已经包含所有变量替换）
  kubectl apply -f "$ONLYOFFICE_INGRESS_FILE" -n "$ns" && log_success "✅ ONLYOFFICE Docs Ingress 部署成功" || { log_error "❌ ONLYOFFICE Docs Ingress 部署失败"; return 1; }
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

