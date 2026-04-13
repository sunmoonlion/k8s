#!/bin/bash
set -e
source "$(dirname "$0")/../../../../../../utils/unified-deployment-template.sh"

# 脚本目录
JENKINS_INGRESS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ING="$(dirname "$SCRIPT_DIR")/ingress.yaml"
# 主配置文件路径：基于 Jenkins 项目根目录计算，指向 deploy-jenkins/deploy-jenkins.conf
JENKINS_MAIN_CONFIG_FILE="$(cd "$SCRIPT_DIR/../../.." && pwd)/deploy-jenkins/deploy-jenkins.conf"

log(){ echo -e "[INFO] $(date '+%F %T') $*"; }
ok(){ echo -e "[SUCCESS] $(date '+%F %T') $*"; }
err(){ echo -e "[ERROR] $(date '+%F %T') $*"; }

# 加载配置
load(){
    if [[ ! -f "$JENKINS_MAIN_CONFIG_FILE" ]]; then
        err "主配置文件不存在: $JENKINS_MAIN_CONFIG_FILE"
        exit 1
    fi
    
    # 加载主配置
    source "$JENKINS_MAIN_CONFIG_FILE"
    
    # 动态获取配置值
    # SERVICE_NAME: 从 PROJECT_ID 构建（格式：jenkins-{project_id}）
    if [[ -z "${SERVICE_NAME:-}" ]]; then
        SERVICE_NAME="jenkins-${JENKINS_PROJECT_ID}"
    fi
    
    # NAMESPACE: 从主配置获取
    NAMESPACE="${JENKINS_NAMESPACE:-cicd-platform-dev}"
    
    # JENKINS_PORT: 从 Kubernetes Service 动态获取
    if [[ -z "${JENKINS_PORT:-}" ]]; then
        JENKINS_PORT=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -z "$JENKINS_PORT" ]]; then
            log "⚠️ 无法从 Service 获取端口，使用默认值 8080"
            JENKINS_PORT="8080"
        fi
    fi
    
    # UNIFIED_HOST: 从主配置的统一域名获取
    UNIFIED_HOST="${JENKINS_UNIFIED_HOST:-www.sunmoonai.com}"
    
    # 固定配置（不需要动态获取）
    ENTRY_POINT="web"
    APP_LABEL="cicd-platform-ingress"
    COMPONENT_LABEL="jenkins-web"
    
    ok "配置加载成功"
    log "服务名称: $SERVICE_NAME"
    log "命名空间: $NAMESPACE"
    log "服务端口: $JENKINS_PORT"
    log "统一域名: $UNIFIED_HOST"
}
chk_ns(){ kubectl get ns "$1" >/dev/null 2>&1 || { err "命名空间不存在: $1"; return 1; }; }
svc_ok(){ kubectl get svc -n "$1" "$SERVICE_NAME" >/dev/null 2>&1; }
apply(){
  local ns="${1:-$NAMESPACE}"; chk_ns "$ns" || return 1; [[ -f "$ING" ]] || { err "缺少 ingress: $ING"; return 1; }
  svc_ok "$ns" || err "警告: Service $SERVICE_NAME 不存在，仍将应用 Ingress"
  local t=$(mktemp); cp "$ING" "$t"
  # 使用 sed 替换占位符
  sed -i "s|{{NAMESPACE}}|$NAMESPACE|g" "$t"
  sed -i "s|{{SERVICE_NAME}}|$SERVICE_NAME|g" "$t"
  sed -i "s|{{SERVICE_PORT}}|$JENKINS_PORT|g" "$t"
  sed -i "s|{{UNIFIED_HOST}}|$UNIFIED_HOST|g" "$t"
  
  # 检查资源是否已存在，如果存在则使用 replace，否则使用 apply
  if kubectl get ingressroute jenkins-web-route -n "$ns" >/dev/null 2>&1; then
    # 资源已存在，使用 replace（会自动处理 resourceVersion）
    kubectl replace -f "$t" && ok "Jenkins Web Ingress 已更新" || { err "更新失败"; rm -f "$t"; return 1; }
  else
    # 资源不存在，使用 apply 创建
    kubectl apply -f "$t" && ok "Jenkins Web Ingress 已创建" || { err "创建失败"; rm -f "$t"; return 1; }
  fi
  rm -f "$t"
}
rm_ing(){ local ns="${1:-$NAMESPACE}"; kubectl delete -f "$ING" -n "$ns" 2>/dev/null || true; ok "Jenkins Web Ingress 已删除"; }
show(){ kubectl get ingressroute -n "$NAMESPACE" -l component=$COMPONENT_LABEL 2>/dev/null || echo 无; kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo 无; }
main(){
  setup_kubectl_environment
  load
  local a="${1:-deploy}"
  local ns="${2:-$NAMESPACE}"
  case "$a" in 
    deploy) apply "$ns"; show;; 
    uninstall|delete) rm_ing "$ns";; 
    status) show;; 
    *) echo "用法: $0 [deploy|uninstall|status] [namespace]";; 
  esac
}
main "$@"
