#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_CONFIG_FILE="$(cd "$SCRIPT_DIR/../.." && pwd)/deploy-llmops-ssr.conf"

# 计算应用根目录和资源路径
# 从 deploy-ingress/ -> ingress/ -> deploy-llmops-ssr/ -> llmops-app-ssr/
APP_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RESOURCES_DIR="${APP_ROOT}/resources"
CUSTOM_VALUES_DIR="${RESOURCES_DIR}/custom-values"

# 使用生成的 YAML 文件
INGRESS_FILE="${CUSTOM_VALUES_DIR}/llmops-app-ssr-ingress-generated.yaml"
# 注意：middleware 可能也在生成的 YAML 中，或者需要单独处理
MIDDLEWARE_FILE="$(dirname "$SCRIPT_DIR")/middleware.yaml"

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
  local yaml_file="$1"
  
  # 如果是生成的 YAML 文件，直接使用（无需变量替换）
  if [[ "$yaml_file" == *"-generated.yaml" ]]; then
    # 自动生成 YAML 文件（总是重新生成，确保使用最新的模板）
    log_info "重新生成 YAML 文件（确保使用最新的模板）..."
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
    kubectl apply -f "$yaml_file" -n "$NAMESPACE"
  else
    # 旧模板文件，使用变量替换
    local tmp=$(mktemp)
    cp "$yaml_file" "$tmp"
    sed -i "s/{{NAMESPACE}}/$NAMESPACE/g" "$tmp"
    sed -i "s/{{SERVICE_NAME}}/$SERVICE_NAME/g" "$tmp"
    sed -i "s/{{SERVICE_PORT}}/$SERVICE_PORT/g" "$tmp"
    sed -i "s/{{UNIFIED_HOST}}/$UNIFIED_HOST/g" "$tmp"
    sed -i "s/{{NODE_IP}}/$NODE_IP/g" "$tmp"
    kubectl apply -f "$tmp" -n "$NAMESPACE"
    rm -f "$tmp"
  fi
}

delete_file(){
  local yaml_file="$1"
  
  # 如果是生成的 YAML 文件，直接使用（无需变量替换）
  if [[ "$yaml_file" == *"-generated.yaml" ]]; then
    kubectl delete -f "$yaml_file" -n "$NAMESPACE" --ignore-not-found
  else
    # 旧模板文件，使用变量替换
    local tmp=$(mktemp)
    cp "$yaml_file" "$tmp"
    sed -i "s/{{NAMESPACE}}/$NAMESPACE/g" "$tmp"
    sed -i "s/{{SERVICE_NAME}}/$SERVICE_NAME/g" "$tmp"
    sed -i "s/{{SERVICE_PORT}}/$SERVICE_PORT/g" "$tmp"
    sed -i "s/{{UNIFIED_HOST}}/$UNIFIED_HOST/g" "$tmp"
    sed -i "s/{{NODE_IP}}/$NODE_IP/g" "$tmp"
    kubectl delete -f "$tmp" -n "$NAMESPACE" --ignore-not-found
    rm -f "$tmp"
  fi
}

deploy(){
  load_config
  check_namespace
  
  # 自动生成 YAML 文件（如果不存在）
  if [[ ! -f "$INGRESS_FILE" ]]; then
    log_warn "生成的 Ingress YAML 文件不存在，自动运行生成脚本..."
    if [[ -f "$CUSTOM_VALUES_DIR/generate.sh" ]]; then
      if bash "$CUSTOM_VALUES_DIR/generate.sh"; then
        log_success "YAML 文件生成成功"
      else
        log_error "YAML 文件生成失败"
        exit 1
      fi
    else
      log_error "生成脚本不存在: $CUSTOM_VALUES_DIR/generate.sh"
      exit 1
    fi
  fi
  
  [[ -f "$INGRESS_FILE" ]] || { log_error "缺少 ingress YAML 文件: $INGRESS_FILE"; exit 1; }
  
  # Middleware 可能也在生成的 YAML 中，或者需要单独处理
  if [[ -f "$MIDDLEWARE_FILE" ]]; then
    log_info "部署 Middleware..."
    apply_file "$MIDDLEWARE_FILE"
  fi
  
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
