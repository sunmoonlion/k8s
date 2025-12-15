#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INGRESS_FILE="$(dirname "$SCRIPT_DIR")/ingress.yaml"
MIDDLEWARE_FILE="$(dirname "$SCRIPT_DIR")/middleware.yaml"
MAIN_CONFIG_FILE="$(cd "$SCRIPT_DIR/../.." && pwd)/deploy-llmops-ssr.conf"

log_info(){ echo -e "\033[0;34m[INFO]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_success(){ echo -e "\033[0;32m[SUCCESS]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_warn(){ echo -e "\033[1;33m[WARN]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_error(){ echo -e "\033[0;31m[ERROR]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*" 1>&2; }

load_config(){
  [[ -f "$MAIN_CONFIG_FILE" ]] && source "$MAIN_CONFIG_FILE"
  SERVICE_NAME="llmops-app-ssr"
  NAMESPACE="${LLMOPS_SSR_NAMESPACE:-app-platform-dev}"
  UNIFIED_HOST="${LLMOPS_SSR_UNIFIED_HOST:-llmops-ssr.sunmoonai.com}"
  NODE_IP="${LLMOPS_SSR_NODE_IP:-101.126.151.0}"
  EXTERNAL_PORT="${LLMOPS_SSR_EXTERNAL_PORT:-30443}"
  SERVICE_PORT="${SERVICE_PORT:-3000}"
}

check_namespace(){ kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || { log_error "命名空间不存在: $NAMESPACE"; exit 1; }; }

apply_file(){
  local tpl="$1"; local tmp=$(mktemp)
  cp "$tpl" "$tmp"
  sed -i "s/{{NAMESPACE}}/$NAMESPACE/g" "$tmp"
  sed -i "s/{{SERVICE_NAME}}/$SERVICE_NAME/g" "$tmp"
  sed -i "s/{{SERVICE_PORT}}/$SERVICE_PORT/g" "$tmp"
  sed -i "s/{{UNIFIED_HOST}}/$UNIFIED_HOST/g" "$tmp"
  sed -i "s/{{NODE_IP}}/$NODE_IP/g" "$tmp"
  kubectl apply -f "$tmp"
  rm -f "$tmp"
}

delete_file(){
  local tpl="$1"; local tmp=$(mktemp)
  cp "$tpl" "$tmp"
  sed -i "s/{{NAMESPACE}}/$NAMESPACE/g" "$tmp"
  sed -i "s/{{SERVICE_NAME}}/$SERVICE_NAME/g" "$tmp"
  sed -i "s/{{SERVICE_PORT}}/$SERVICE_PORT/g" "$tmp"
  sed -i "s/{{UNIFIED_HOST}}/$UNIFIED_HOST/g" "$tmp"
  sed -i "s/{{NODE_IP}}/$NODE_IP/g" "$tmp"
  kubectl delete -f "$tmp" --ignore-not-found
  rm -f "$tmp"
}

deploy(){
  load_config
  check_namespace
  [[ -f "$INGRESS_FILE" ]] || { log_error "缺少 ingress.yaml"; exit 1; }
  [[ -f "$MIDDLEWARE_FILE" ]] || { log_error "缺少 middleware.yaml"; exit 1; }
  log_info "部署 Middleware..."
  apply_file "$MIDDLEWARE_FILE"
  log_info "部署 IngressRoute..."
  apply_file "$INGRESS_FILE"
  log_success "Ingress 部署完成"
}

uninstall(){
  load_config
  check_namespace
  log_info "删除 IngressRoute 和 Middleware..."
  delete_file "$INGRESS_FILE"
  delete_file "$MIDDLEWARE_FILE"
  log_success "Ingress 删除完成"
}

status(){
  load_config
  log_info "IngressRoute:"
  kubectl get ingressroute -n "$NAMESPACE" -l component=llmops-app-ssr 2>/dev/null || true
  log_info "Middleware:"
  kubectl get middleware -n "$NAMESPACE" -l component=llmops-app-ssr 2>/dev/null || true
}

action="${1:-deploy}"
case "$action" in
  deploy) deploy ;;
  uninstall) uninstall ;;
  status) status ;;
  *) echo "用法: $0 {deploy|uninstall|status}"; exit 1;;
esac
