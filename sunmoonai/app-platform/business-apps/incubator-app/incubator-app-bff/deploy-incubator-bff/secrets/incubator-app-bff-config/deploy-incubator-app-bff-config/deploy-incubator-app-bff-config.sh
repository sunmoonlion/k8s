#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-incubator-app-bff-config.conf"
# 计算项目根目录（应用根目录）
# 从 deploy-incubator-app-bff-config/ 向上 3 级到达应用根目录
# deploy-incubator-app-bff-config/ -> incubator-app-bff-config/ -> secrets/ -> deploy-incubator-bff/ -> incubator-app-bff/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 使用生成的 YAML 文件（由 resources/custom-values/generate.sh 生成）
CUSTOM_VALUES_DIR="$PROJECT_ROOT/resources/custom-values"
CONFIGMAP_YAML="$CUSTOM_VALUES_DIR/incubator-app-bff-config-generated.yaml"

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

DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 自动生成 YAML 文件的辅助函数（与主部署脚本保持一致）
auto_generate_yaml() {
    local yaml_file="$1"
    local custom_values_dir="$2"
    
    if [ ! -f "$yaml_file" ]; then
        log_warn "生成的 YAML 文件不存在: $yaml_file，自动运行生成脚本..."
        if [ -f "$custom_values_dir/generate.sh" ]; then
            if bash "$custom_values_dir/generate.sh"; then
                log_success "YAML 文件生成成功"
            else
                log_error "YAML 文件生成失败"
                return 1
            fi
        else
            log_error "生成脚本不存在: $custom_values_dir/generate.sh"
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
  if ! auto_generate_yaml "$CONFIGMAP_YAML" "$CUSTOM_VALUES_DIR"; then
    log_error "无法生成或找到 ConfigMap YAML 文件"
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
      local configmap_name="${INCUBATOR_BFF_CONFIGMAP_NAME:-incubator-app-bff-config}"
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
