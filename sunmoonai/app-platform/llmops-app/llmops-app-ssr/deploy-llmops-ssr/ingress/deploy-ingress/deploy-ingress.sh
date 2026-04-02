#!/bin/bash
set -e

# 脚本目录（保存原始值，因为 unified-deployment-template.sh 会覆盖 SCRIPT_DIR）
ORIGINAL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"
# 主配置文件路径：从 deploy-ingress/ -> ingress/ -> deploy-llmops-ssr/ -> app/deploy-app/
MAIN_CONFIG_FILE="$(cd "$SCRIPT_DIR/../../../app/deploy-app" && pwd)/deploy-llmops-ssr.conf"

# 计算应用根目录和资源路径（在 source 之前计算，避免 SCRIPT_DIR 被覆盖）
# 从 deploy-ingress/ -> ingress/ -> deploy-llmops-ssr/ -> llmops-app-ssr/
APP_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RESOURCES_DIR="${APP_ROOT}/resources"
K8S_RESOURCE_DIR="${RESOURCES_DIR}/k8s-resource"

# 计算 k8s 根目录（向上搜索 utils/cluster-arg-parser.sh）
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
  echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），APP_ROOT=$APP_ROOT" 1>&2
  exit 1
fi

# 导入统一部署模板（建立远程 k8s 连接）
# 注意：unified-deployment-template.sh 会覆盖 SCRIPT_DIR，所以我们在 source 之前已经计算好路径
source "$K8S_ROOT_DIR/utils/unified-deployment-template.sh"

# 恢复原始的 SCRIPT_DIR（如果需要的话）
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"

# Ingress 配置文件（使用生成的 YAML 文件，由各组件自己的 generate-*.sh 生成）
INGRESS_FILE="${K8S_RESOURCE_DIR}/custom-values/ingress/llmops-ssr-ingress/generate-ingress/llmops-app-ssr-ingress-generated.yaml"
# 注意：middleware 可能也在生成的 YAML 中，或者需要单独处理
MIDDLEWARE_FILE="$(dirname "$SCRIPT_DIR")/middleware.yaml"

log_info(){ echo -e "\033[0;34m[INFO]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_success(){ echo -e "\033[0;32m[SUCCESS]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_warn(){ echo -e "\033[1;33m[WARN]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_error(){ echo -e "\033[0;31m[ERROR]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*" 1>&2; }

load_config(){
  if [[ -f "$MAIN_CONFIG_FILE" ]]; then
    # 临时禁用错误退出，因为主配置文件可能包含一些在当前上下文中不适用的配置
    set +e
    source "$MAIN_CONFIG_FILE" 2>/dev/null
    set -e
    log_info "已加载主配置文件: $MAIN_CONFIG_FILE"
  fi
  
  # 从主配置文件构建配置（所有默认值应在配置文件中定义）
  # 优先使用环境变量（从命令行参数传入），其次使用配置文件中的值
  SERVICE_NAME="llmops-app-ssr"
  NAMESPACE="${NAMESPACE:-${LLMOPS_SSR_NAMESPACE:-app-platform-dev}}"
  UNIFIED_HOST="${LLMOPS_SSR_UNIFIED_HOST:-}"
  NODE_IP="${LLMOPS_SSR_NODE_IP:-}"
  EXTERNAL_PORT="${LLMOPS_SSR_EXTERNAL_PORT:-}"
  SERVICE_PORT="${SERVICE_PORT:-3000}"
}

check_namespace(){ kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || { log_error "命名空间不存在: $NAMESPACE"; exit 1; }; }

apply_file(){
  local yaml_file="$1"
  
  # 如果是生成的 YAML 文件，直接使用（无需变量替换）
  if [[ "$yaml_file" == *"-generated.yaml" ]]; then
    # 自动生成 YAML 文件（总是重新生成，确保使用最新的模板）
    log_info "重新生成 YAML 文件（确保使用最新的模板）..."
    # 导出基础配置变量，供生成脚本使用（通过环境变量继承）
    export NAMESPACE="$NAMESPACE"
    export ENVIRONMENT="${ENVIRONMENT:-development}"
    export ENV="${ENV:-dev}"
    export PROJECT_ID="${PROJECT_ID:-sunmoonai}"
    
    local generate_script="$K8S_RESOURCE_DIR/custom-values/ingress/llmops-ssr-ingress/generate-ingress/generate-ingress.sh"
    if [ -f "$generate_script" ]; then
      if bash "$generate_script"; then
        log_success "YAML 文件生成成功"
      else
        log_error "YAML 文件生成失败"
        return 1
      fi
    else
      log_error "生成脚本不存在: $generate_script"
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
  
  # 自动生成 YAML 文件（总是重新生成，确保使用最新的模板）
  log_info "重新生成 Ingress YAML 文件（确保使用最新的模板）..."
  # 导出基础配置变量，供生成脚本使用（通过环境变量继承）
  export NAMESPACE="$NAMESPACE"
  export ENVIRONMENT="${ENVIRONMENT:-development}"
  export ENV="${ENV:-dev}"
  export PROJECT_ID="${PROJECT_ID:-sunmoonai}"
  
  local generate_script="$K8S_RESOURCE_DIR/custom-values/ingress/llmops-ssr-ingress/generate-ingress/generate-ingress.sh"
  if [ -f "$generate_script" ]; then
    if bash "$generate_script"; then
      log_success "YAML 文件生成成功"
    else
      log_error "YAML 文件生成失败"
      exit 1
    fi
  else
    log_error "生成脚本不存在: $generate_script"
    exit 1
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
