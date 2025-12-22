#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-llmops-app-ssr-secret.conf"
# 计算项目根目录（应用根目录）
# 从 deploy-llmops-app-ssr-secret/ 向上 3 级到达应用根目录
# deploy-llmops-app-ssr-secret/ -> llmops-app-ssr-secret/ -> secrets/ -> deploy-llmops-ssr/ -> llmops-app-ssr/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
K8S_RESOURCE_DIR="$PROJECT_ROOT/resources/k8s-resource"
SECRET_YAML="$K8S_RESOURCE_DIR/custom-values/secret/llmops-app-ssr-secret/generate-llmops-app-ssr-secret/llmops-app-ssr-secret-generated.yaml"

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

# 自动生成 YAML 文件的辅助函数
auto_generate_yaml() {
    local yaml_file="$1"
    local k8s_resource_dir="$2"
    
    if [ ! -f "$yaml_file" ]; then
        log_warn "生成的 YAML 文件不存在: $yaml_file，自动运行生成脚本..."
        # 导出基础配置变量，供生成脚本使用（通过环境变量继承）
        export NAMESPACE="${NAMESPACE:-app-platform-dev}"
        export ENVIRONMENT="${ENVIRONMENT:-development}"
        export ENV="${ENV:-dev}"
        export PROJECT_ID="${PROJECT_ID:-sunmoonai}"
        
        local generate_script="$k8s_resource_dir/custom-values/secret/llmops-app-ssr-secret/generate-llmops-app-ssr-secret/generate-llmops-app-ssr-secret.sh"
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
  if ! auto_generate_yaml "$SECRET_YAML" "$K8S_RESOURCE_DIR"; then
    log_error "无法生成或找到 Secret YAML 文件"
    exit 1
  fi

  # 2. 部署或卸载
  case "$action" in
    deploy)
      kubectl apply -f "$SECRET_YAML" -n "$NAMESPACE"
      log_success "Secret 部署完成"
      ;;
    uninstall)
      kubectl delete -f "$SECRET_YAML" -n "$NAMESPACE" --ignore-not-found
      log_success "Secret 卸载完成"
      ;;
    status)
      log_info "检查 Secret 状态..."
      local secret_name="${LLMOPS_SSR_SECRET_NAME:-llmops-app-ssr-secret}"
      kubectl get secret "$secret_name" -n "$NAMESPACE" 2>/dev/null || log_warn "Secret 不存在: $secret_name"
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
