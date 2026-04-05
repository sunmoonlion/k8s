#!/bin/bash
set -e
source "$(dirname "$0")/../../../../../../utils/unified-deployment-template.sh"

# 脚本目录
RABBITMQ_INGRESS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ING="$(dirname "$SCRIPT_DIR")/ingress.yaml"
# 主配置文件路径（相对于脚本目录）
# 从 deploy-ingress/ -> ingress/ -> deploy-rabbitmq/ -> deploy-rabbitmq.conf
RABBITMQ_MAIN_CONFIG_FILE="$(dirname "$(dirname "$SCRIPT_DIR")")/deploy-rabbitmq.conf"

log(){ echo -e "[INFO] $(date '+%F %T') $*"; }
ok(){ echo -e "[SUCCESS] $(date '+%F %T') $*"; }
err(){ echo -e "[ERROR] $(date '+%F %T') $*"; }

# 加载配置
load(){
    if [[ ! -f "$RABBITMQ_MAIN_CONFIG_FILE" ]]; then
        err "主配置文件不存在: $RABBITMQ_MAIN_CONFIG_FILE"
        exit 1
    fi
    
    # 加载主配置
    source "$RABBITMQ_MAIN_CONFIG_FILE"
    
    # 动态获取配置值
    # SERVICE_NAME: 从 PROJECT_ID 构建（格式：rabbitmq-{project_id}）
    if [[ -z "${SERVICE_NAME:-}" ]]; then
        SERVICE_NAME="rabbitmq-${RABBITMQ_PROJECT_ID}"
    fi
    
    # NAMESPACE: 从主配置获取
    NAMESPACE="${RABBITMQ_NAMESPACE:-messaging-platform-dev}"
    
    # RABBITMQ_MGMT_PORT: 从 Kubernetes Service 动态获取 management 端口
    if [[ -z "${RABBITMQ_MGMT_PORT:-}" ]]; then
        # 尝试从 Service 中获取名为 management 的端口
        RABBITMQ_MGMT_PORT=$(kubectl get svc -n "$NAMESPACE" "$SERVICE_NAME" -o jsonpath='{.spec.ports[?(@.name=="management")].port}' 2>/dev/null)
        if [[ -z "$RABBITMQ_MGMT_PORT" ]]; then
            # 如果获取失败，使用默认值
            log "⚠️ 无法从 Service 获取 management 端口，使用默认值 15672"
            RABBITMQ_MGMT_PORT="15672"
        fi
    fi
    
    # UNIFIED_HOST: 从主配置的统一域名获取
    UNIFIED_HOST="${RABBITMQ_UNIFIED_HOST:-www.sunmoonai.com}"
    
    # NODE_IP: 从主配置的节点 IP 获取（如果没有配置，使用默认值）
    NODE_IP="${RABBITMQ_NODE_IP:-115.190.153.150}"
    
    # 固定配置（不需要动态获取）
    ENTRY_POINT="web"
    APP_LABEL="messaging-platform-ingress"
    COMPONENT_LABEL="rabbitmq-web"
    
    ok "配置加载成功"
    log "服务名称: $SERVICE_NAME"
    log "命名空间: $NAMESPACE"
    log "服务端口: $RABBITMQ_MGMT_PORT"
    log "统一域名: $UNIFIED_HOST"
    log "节点 IP: $NODE_IP"
}
chk_ns(){ kubectl get ns "$1" >/dev/null 2>&1 || { err "命名空间不存在: $1"; return 1; }; }
svc_ok(){ kubectl get svc -n "$1" "$SERVICE_NAME" >/dev/null 2>&1; }
apply(){
  local ns="${1:-$NAMESPACE}"; load; chk_ns "$ns" || return 1; [[ -f "$ING" ]] || { err "缺少 ingress: $ING"; return 1; }
  local t=$(mktemp); cp "$ING" "$t"
  # 使用 sed 替换占位符
  sed -i "s|{{NAMESPACE}}|$NAMESPACE|g" "$t"
  sed -i "s|{{SERVICE_NAME}}|$SERVICE_NAME|g" "$t"
  sed -i "s|{{SERVICE_PORT}}|$RABBITMQ_MGMT_PORT|g" "$t"
  sed -i "s|{{UNIFIED_HOST}}|$UNIFIED_HOST|g" "$t"
  sed -i "s|{{NODE_IP}}|$NODE_IP|g" "$t"
  kubectl apply -f "$t" && ok "RabbitMQ Web Ingress 已应用" || { err "应用失败"; rm -f "$t"; return 1; }
  rm -f "$t"
}
rm_ing(){ local ns="${1:-messaging-platform-dev}"; load; ns="${ns:-$NAMESPACE}"; kubectl delete -f "$ING" -n "$ns" 2>/dev/null || true; ok "RabbitMQ Web Ingress 已删除"; }
show(){ load; kubectl get ingressroute -n "$NAMESPACE" -l component=$COMPONENT_LABEL 2>/dev/null || echo 无; kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo 无; }
main(){
  local a="${1:-deploy}"
  # 支持两种调用方式：
  # 1. deploy <namespace> （直接调用）
  # 2. deploy <project_id> <namespace> <environment> （由主部署脚本调用）
  local ns="${2:-$NAMESPACE}"
  # 如果第二个参数看起来像 project_id（不是命名空间格式），则使用第三个参数作为 namespace
  if [[ "$ns" != *"-"* ]] && [[ -n "${3:-}" ]] && [[ "$3" == *"-"* ]]; then
    ns="$3"
  fi
  
  # 先建立 Kubernetes 连接
  if ! setup_kubectl_environment; then
    err "无法建立 Kubernetes 连接"
    exit 1
  fi
  
  case "$a" in 
    deploy) 
      apply "$ns"
      show
      ;; 
    uninstall|delete) 
      rm_ing "$ns"
      ;; 
    status) 
      show
      ;; 
    *) 
      echo "用法: $0 [deploy|uninstall|status] [namespace] 或 $0 deploy <project_id> <namespace> <environment>"
      ;;
  esac
}
main "$@"
