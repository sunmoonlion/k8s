#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  log_error "配置文件不存在: $CONFIG_FILE"
  exit 1
fi

DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

check_namespace() {
  local ns="$1"
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    log_success "命名空间存在: $ns"
  else
    log_error "命名空间不存在: $ns"
    return 1
  fi
}

deploy_components() {
  local action="$1" project_id="$2" namespace="$3" environment="$4"

  # 定义组件部署信息（组件名:启用标志:优先级:描述:脚本路径）
  local components=(
    "harbor_registry_secret:${harbor_registry_secret_enabled:-true}:${harbor_registry_secret_priority:-700}:Harbor Registry Secret:$SCRIPT_DIR/../harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh"
    "incubator_bff_secret:${incubator_bff_secret_enabled:-true}:${incubator_bff_secret_priority:-600}:BFF Secret:$SCRIPT_DIR/../incubator-app-bff-secret/deploy-incubator-app-bff-secret/deploy-incubator-app-bff-secret.sh"
    "incubator_bff_config:${incubator_bff_config_enabled:-true}:${incubator_bff_config_priority:-500}:BFF ConfigMap:$SCRIPT_DIR/../incubator-app-bff-config/deploy-incubator-app-bff-config/deploy-incubator-app-bff-config.sh"
  )

  # 先过滤出启用的组件
  local enabled_components=()
  local disabled_components=()
  
  for c in "${components[@]}"; do
    IFS=':' read -r name enabled_flag priority desc script <<< "$c"
    if [[ "$enabled_flag" == "true" ]]; then
      enabled_components+=("$c")
    else
      disabled_components+=("$c")
      log_info "⏭️  跳过组件(禁用): $desc"
    fi
  done

  # 按优先级排序（数值越大优先级越高）
  if [[ ${#enabled_components[@]} -gt 1 ]]; then
    IFS=$'\n' sorted_enabled=($(printf '%s\n' "${enabled_components[@]}" | sort -t: -k3 -nr))
    log_info "📋 子级组件部署顺序（按优先级排序）："
    for c in "${sorted_enabled[@]}"; do
      IFS=':' read -r name enabled_flag priority desc script <<< "$c"
      log_info "  🚀 $priority - $desc"
    done
  elif [[ ${#enabled_components[@]} -eq 1 ]]; then
    sorted_enabled=("${enabled_components[@]}")
    IFS=':' read -r name enabled_flag priority desc script <<< "${enabled_components[0]}"
    log_info "📋 子级组件部署顺序（单个组件）："
    log_info "  🚀 $desc"
  else
    sorted_enabled=()
    log_info "📋 子级组件部署顺序：无启用的组件"
  fi

  # 显示禁用的组件
  if [[ ${#disabled_components[@]} -gt 0 ]]; then
    log_info "  ⏭️  禁用的组件："
    for c in "${disabled_components[@]}"; do
      IFS=':' read -r name enabled_flag priority desc script <<< "$c"
      log_info "    $desc (${name}_enabled=false)"
    done
  fi

  # 部署启用的组件
  for c in "${sorted_enabled[@]}"; do
    IFS=':' read -r name enabled_flag priority desc script <<< "$c"
    
    if [[ ${#enabled_components[@]} -gt 1 ]]; then
      log_info "🚀 部署 $desc (优先级: $priority)..."
    else
      log_info "🚀 部署 $desc..."
    fi
    
    if [[ -f "$script" ]]; then
      local original_dir="$(pwd)"
      cd "$(dirname "$script")"
      
      if ./"$(basename "$script")" "$action" "$project_id" "$namespace" "$environment"; then
        log_success "✅ $desc 部署成功"
      else
        log_error "❌ $desc 部署失败"
        cd "$original_dir"
        return 1
      fi
      
      cd "$original_dir"
    else
      log_warn "⚠️  $desc 部署脚本不存在: $script"
    fi
  done
  
  log_success "✅ 子级组件部署完成！"
}

main() {
  local action="${1:-deploy}"
  local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
  local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
  local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"

  log_info "🚀 开始部署 Incubator App BFF Secrets..."
  log_info "📋 部署参数："
  log_info "  - 项目ID: $project_id"
  log_info "  - 命名空间: $namespace"
  log_info "  - 环境: $environment"
  log_info "  - 操作: $action"
  echo ""

  if [[ "$action" != "status" && "$action" != "generate" ]]; then
    check_namespace "$namespace" || exit 1
  fi

  deploy_components "$action" "$project_id" "$namespace" "$environment"
  
  echo ""
  log_success "🎉 Incubator App BFF Secrets 部署完成！"
  log_info "📋 部署信息："
  log_info "  - 项目ID: $project_id"
  log_info "  - 命名空间: $namespace"
  log_info "  - 环境: $environment"
  log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

main "$@"

