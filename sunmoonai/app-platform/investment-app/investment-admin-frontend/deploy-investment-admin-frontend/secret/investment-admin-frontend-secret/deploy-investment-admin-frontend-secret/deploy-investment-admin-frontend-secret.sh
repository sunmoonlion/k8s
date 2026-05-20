#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-investment-admin-frontend-secret.conf"
# 计算项目根目录（应用根目录）
# 从 deploy-investment-admin-frontend-secret/ 向上 3 级到达应用根目录
# deploy-investment-admin-frontend-secret/ -> investment-admin-frontend-secret/ -> secret/ -> deploy-investment-admin-frontend/ -> investment-admin-frontend/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
K8S_RESOURCE_DIR="$PROJECT_ROOT/resources/k8s-resource"
SECRET_YAML="$K8S_RESOURCE_DIR/custom-values/secret/investment-admin-frontend-secret/generate-investment-admin-frontend-secret/investment-admin-frontend-secret-generated.yaml"

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

DEFAULT_PROJECT_ID="${PROJECT_ID:-}"
DEFAULT_NAMESPACE="${NAMESPACE:-}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-}"

main() {
  local action="${1:-deploy}"
  local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
  local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
  local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"

  export PROJECT_ID="$project_id" NAMESPACE="$namespace" ENVIRONMENT="$environment"

  export NAMESPACE="$namespace"
  export ENVIRONMENT="$environment"
  export ENV="${ENV:-dev}"
  export PROJECT_ID="$project_id"

  local generate_script="$PROJECT_ROOT/resources/k8s-resource/custom-values/secret/investment-admin-frontend-secret/generate-investment-admin-frontend-secret/generate-investment-admin-frontend-secret.sh"
  if [ -f "$generate_script" ]; then
    if bash "$generate_script"; then
      log_success "Secret YAML 文件生成成功"
    else
      log_error "Secret YAML 文件生成失败"
      exit 1
    fi
  else
    log_error "生成脚本不存在: $generate_script"
    exit 1
  fi

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
      local secret_name="${INVESTMENT_ADMIN_FRONTEND_SECRET_NAME:-investment-admin-frontend-secret}"
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
