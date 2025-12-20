#!/bin/bash

# ============================================================================
# LLMOps Service Secrets All 部署脚本
# 文件名: deploy-secrets-all.sh
# 用途: 统一部署所有 LLMOps Service 相关的 Secrets 和 ConfigMaps
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

# 计算项目根目录（k8s目录）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 日志函数
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 加载配置文件
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    log_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 检查命名空间
check_namespace() {
    local namespace="$1"
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    else
        log_error "❌ 命名空间 $namespace 不存在！"
        echo ""
        log_info "请先创建命名空间："
        echo "  kubectl create namespace $namespace"
        echo ""
        return 1
    fi
}

# 部署子级组件（按优先级）
deploy_sub_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local action="$4"
    
    log_info "🔧 开始部署子级组件..."
    
    # 定义组件部署信息（组件名:启用标志:优先级:描述:脚本路径）
    local components=(
        "harbor_registry_secret:${harbor_registry_secret_enabled:-true}:${harbor_registry_secret_priority:-700}:Harbor Registry Secret:$SCRIPT_DIR/../harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh"
        "llmops_service_secret:${llmops_service_secret_enabled:-true}:${llmops_service_secret_priority:-600}:LLMOps Service Secret:$SCRIPT_DIR/../llmops-service-secret/deploy-llmops-service-secret/deploy-llmops-service-secret.sh"
        "llmops_service_config:${llmops_service_config_enabled:-true}:${llmops_service_config_priority:-500}:LLMOps Service ConfigMap:$SCRIPT_DIR/../llmops-service-config/deploy-llmops-service-config/deploy-llmops-service-config.sh"
    )
    
    # 先过滤出启用的组件，然后按优先级排序
    local enabled_components=()
    local disabled_components=()
    
    for component_info in "${components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            enabled_components+=("$component_info")
        else
            disabled_components+=("$component_info")
        fi
    done
    
    # 根据启用组件数量决定是否进行优先级排序
    if [[ ${#enabled_components[@]} -gt 1 ]]; then
        # 多个组件启用时，按优先级排序（数值越大优先级越高）
        IFS=$'\n' sorted_enabled_components=($(printf '%s\n' "${enabled_components[@]}" | sort -t: -k3 -nr))
        log_info "📋 子级组件部署顺序（按优先级排序）："
        
        for component_info in "${sorted_enabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "  🚀 $priority - $description"
        done
    elif [[ ${#enabled_components[@]} -eq 1 ]]; then
        # 只有一个组件启用时，直接使用，无需排序
        sorted_enabled_components=("${enabled_components[@]}")
        IFS=':' read -r name enabled priority description script_path <<< "${enabled_components[0]}"
        log_info "📋 子级组件部署顺序（单个组件，无需排序）："
        log_info "  🚀 $description"
    else
        # 没有启用的组件
        sorted_enabled_components=()
        log_info "📋 子级组件部署顺序：无启用的组件"
    fi
    
    # 显示禁用的组件
    if [[ ${#disabled_components[@]} -gt 0 ]]; then
        log_info "  ⏭️  禁用的组件："
        for component_info in "${disabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "    $description (${name}_enabled=false)"
        done
    fi
    
    # 部署启用的组件
    for component_info in "${sorted_enabled_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        
        if [[ ! -f "$script_path" ]]; then
            log_warn "⚠️  脚本不存在，跳过: $script_path"
            continue
        fi
        
        log_info ""
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "📦 部署组件: $description"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if bash "$script_path" "$action" "$project_id" "$namespace" "$environment"; then
            log_success "✅ $description 部署成功"
        else
            log_error "❌ $description 部署失败"
            return 1
        fi
    done
    
    log_success "🎉 所有子级组件部署完成！"
}

main() {
    local action="${1:-deploy}"
    local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    
    log_info "🚀 开始部署 LLMOps App BFF Secrets..."
    log_info "📋 部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 操作: $action"
    echo ""

    if [[ "$action" != "status" && "$action" != "generate" ]]; then
      check_namespace "$namespace" || exit 1
    fi

    deploy_sub_components_by_priority "$project_id" "$namespace" "$environment" "$action"
    
    echo ""
    log_success "🎉 LLMOps App BFF Secrets 部署完成！"
    log_info "📋 部署信息："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

main "$@"

