#!/bin/bash

# Logstash Web 路由部署脚本

set -e

# 脚本目录（保存为变量，防止被统一部署模板覆盖）
LOGSTASH_INGRESS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
# 从 deploy-ingress/ -> ingress/ -> deploy-logstash/ -> logstash/ -> data-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../.." && pwd)"

# 导入统一部署模板（建立远程 k8s 连接）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 恢复原始的脚本目录（unified-deployment-template.sh 会重新定义 SCRIPT_DIR）
SCRIPT_DIR="$LOGSTASH_INGRESS_SCRIPT_DIR"
LS_INGRESS_FILE="$(dirname "$SCRIPT_DIR")/ingress.yaml"
# 主配置文件路径（相对于脚本目录）
# 从 deploy-ingress/ -> ingress/ -> deploy-logstash/ (向上2级)
LOGSTASH_MAIN_CONFIG_FILE="$(dirname "$(dirname "$SCRIPT_DIR")")/deploy-logstash.conf"

log_info() { echo -e "[INFO] $(date '+%F %T') $1"; }
log_success() { echo -e "[SUCCESS] $(date '+%F %T') $1"; }
log_warn() { echo -e "[WARN] $(date '+%F %T') $1"; }
log_error() { echo -e "[ERROR] $(date '+%F %T') $1"; }

# 加载配置
load_config() {
    if [[ ! -f "$LOGSTASH_MAIN_CONFIG_FILE" ]]; then
        log_error "主配置文件不存在: $LOGSTASH_MAIN_CONFIG_FILE"
        exit 1
    fi
    
    # 加载主配置
    source "$LOGSTASH_MAIN_CONFIG_FILE"
    
    # 动态获取配置值
    # SERVICE_NAME: 从 PROJECT_ID 构建（格式：logstash-{project_id}）
    if [[ -z "${SERVICE_NAME:-}" ]]; then
        SERVICE_NAME="logstash-${LOGSTASH_PROJECT_ID}"
    fi
    
    # NAMESPACE: 从主配置获取
    NAMESPACE="${LOGSTASH_NAMESPACE:-data-platform-dev}"
    
    # LOGSTASH_PORT: 从 Kubernetes Service 动态获取
    if [[ -z "${LOGSTASH_PORT:-}" ]]; then
        LOGSTASH_PORT=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -z "$LOGSTASH_PORT" ]]; then
            log_warn "⚠️ 无法从 Service 获取端口，使用默认值 9600"
            LOGSTASH_PORT="9600"
        fi
    fi
    
    # UNIFIED_HOST: 从主配置的统一域名获取
    UNIFIED_HOST="${LOGSTASH_UNIFIED_HOST:-llmops.sunmoonai.com}"
    
    # 固定配置（不需要动态获取）
    ENTRY_POINT="web"
    APP_LABEL="data-platform-ingress"
    COMPONENT_LABEL="logstash-web"
    
    log_success "✅ 配置加载成功"
    log_info "服务名称: $SERVICE_NAME"
    log_info "命名空间: $NAMESPACE"
    log_info "服务端口: $LOGSTASH_PORT"
    log_info "统一域名: $UNIFIED_HOST"
}
check_ns() { kubectl get namespace "$1" >/dev/null 2>&1 || { log_error "命名空间不存在: $1"; return 1; }; }
verify_svc() { kubectl get svc -n "$1" "$SERVICE_NAME" >/dev/null 2>&1 || { log_error "服务不存在: $SERVICE_NAME"; return 1; }; }

deploy_web() {
  local ns="${1:-$NAMESPACE}"
  check_ns "$ns" || return 1
  [[ -f "$LS_INGRESS_FILE" ]] || { log_error "Ingress 不存在: $LS_INGRESS_FILE"; return 1; }
  verify_svc "$ns" || return 1
  local tmp=$(mktemp); cp "$LS_INGRESS_FILE" "$tmp"
  # 使用 sed 替换占位符
  sed -i "s|{{NAMESPACE}}|$NAMESPACE|g" "$tmp"
  sed -i "s|{{SERVICE_NAME}}|$SERVICE_NAME|g" "$tmp"
  sed -i "s|{{SERVICE_PORT}}|$LOGSTASH_PORT|g" "$tmp"
  sed -i "s|{{UNIFIED_HOST}}|$UNIFIED_HOST|g" "$tmp"
  kubectl apply -f "$tmp" && log_success "Logstash Web 路由应用成功" || { log_error "应用失败"; rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

delete_web() { local ns="${1:-$NAMESPACE}"; kubectl delete -f "$LS_INGRESS_FILE" -n "$ns" 2>/dev/null || true; log_success "Logstash Web 路由删除完成"; }
status() { kubectl get ingressroute -n "$NAMESPACE" -l component=$COMPONENT_LABEL 2>/dev/null || echo 无 IngressRoute; kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo 无 Service; }

main() {
  local action="${1:-deploy}"; local project_id="${2:-sunmoonai}"; local ns="${3:-$NAMESPACE}"; local env="${4:-development}"
  setup_kubectl_environment; load_config
  case "$action" in
    deploy) deploy_web "$ns" && status;;
    uninstall|delete) delete_web "$ns";;
    status) status;;
    *) echo "用法: $0 [deploy|uninstall|status] [project_id] [namespace] [environment]";;
  esac
}

main "$@"


