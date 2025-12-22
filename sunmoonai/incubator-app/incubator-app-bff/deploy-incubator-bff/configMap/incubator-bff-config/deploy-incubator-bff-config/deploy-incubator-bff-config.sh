#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-incubator-bff-config.conf"
# 计算项目根目录（应用根目录）
# 从 deploy-incubator-bff-config/ 向上 3 级到达应用根目录
# deploy-incubator-bff-config/ -> incubator-bff-config/ -> configMap/ -> deploy-incubator-bff/ -> incubator-app-bff/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
K8S_RESOURCE_DIR="$PROJECT_ROOT/resources/k8s-resource"
CONFIGMAP_YAML="$K8S_RESOURCE_DIR/custom-values/configMap/incubator-bff-config/generate-incubator-bff-config/incubator-app-bff-config-generated.yaml"

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# 加载配置
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
  log_info "已加载配置: $CONFIG_FILE"
else
  log_warn "未找到配置文件: $CONFIG_FILE，使用默认配置"
fi

# 默认配置从配置文件读取（deploy-incubator-bff-config.conf）
# 如果配置文件未设置，则使用空值（由函数参数默认值处理）
DEFAULT_PROJECT_ID="${PROJECT_ID:-}"
DEFAULT_NAMESPACE="${NAMESPACE:-}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-}"

# 自动生成 YAML 文件的辅助函数（已废弃，使用组件自己的生成脚本）
# 注意：此函数已不再使用，保留仅为兼容性
auto_generate_yaml() {
    local yaml_file="$1"
    local k8s_resource_dir="$2"
    
    if [ ! -f "$yaml_file" ]; then
        log_warn "生成的 YAML 文件不存在: $yaml_file，自动运行生成脚本..."
        local generate_script="$k8s_resource_dir/custom-values/configMap/incubator-bff-config/generate-incubator-bff-config/generate-incubator-bff-config.sh"
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
    fi
    return 0
}

main() {
  local action="${1:-deploy}"
  local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
  local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
  local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"

  export PROJECT_ID="$project_id" NAMESPACE="$namespace" ENVIRONMENT="$environment"

  # 1. 自动生成 YAML 文件（如果不存在）
  # 导出基础配置变量，供生成脚本使用（通过环境变量继承）
  export NAMESPACE="$namespace"
  export ENVIRONMENT="$environment"
  export ENV="${ENV:-dev}"
  export PROJECT_ID="$project_id"
  
  local generate_script="$PROJECT_ROOT/resources/k8s-resource/custom-values/configMap/incubator-bff-config/generate-incubator-bff-config/generate-incubator-bff-config.sh"
  if [ -f "$generate_script" ]; then
    if bash "$generate_script"; then
      log_success "ConfigMap YAML 文件生成成功"
    else
      log_error "ConfigMap YAML 文件生成失败"
      exit 1
    fi
  else
    log_error "生成脚本不存在: $generate_script"
    exit 1
  fi

  # 2. 部署或卸载
  case "$action" in
    deploy)
      kubectl apply -f "$CONFIGMAP_YAML" -n "$NAMESPACE"
      log_success "ConfigMap 部署完成"
      ;;
    uninstall)
      kubectl delete -f "$CONFIGMAP_YAML" -n "$NAMESPACE" --ignore-not-found
      log_success "ConfigMap 卸载完成"
      ;;
    status)
      log_info "检查 ConfigMap 状态..."
      local configmap_name="${INCUBATOR_BFF_CONFIGMAP_NAME:-incubator-bff-config}"
      kubectl get configmap "$configmap_name" -n "$NAMESPACE" 2>/dev/null || log_warn "ConfigMap 不存在: $configmap_name"
      ;;
    generate)
      log_success "仅生成 YAML 文件，未部署"
      ;;
    *)
      log_error "无效操作: $action"
      echo "用法: $0 <deploy|uninstall|status|generate> [project_id] [namespace] [environment]"
      exit 1
      ;;
  esac
}

main "$@"
