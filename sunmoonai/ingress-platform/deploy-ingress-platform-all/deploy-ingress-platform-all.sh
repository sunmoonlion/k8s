#!/usr/bin/env bash

# =============================================================================
# Ingress 平台总部署脚本
# - 管理 Ingress 平台组件的部署
# - 支持优先级控制和依赖管理
# - 支持多集群配置
# =============================================================================

# 脚本目录配置
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$THIS_DIR")"
# k8s 根目录：.../k8s（用于引用 utils 下的通用脚本）
# 使用向上搜索，避免相对路径在不同调用方式下失效
K8S_ROOT_DIR=""
search_dir="$THIS_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
        K8S_ROOT_DIR="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
if [[ -z "$K8S_ROOT_DIR" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），THIS_DIR=$THIS_DIR" 1>&2
    exit 1
fi

# 集群参数解析（轻量，无连接副作用）
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"


# 颜色输出函数
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }
bold() { echo -e "\033[1m$*\033[0m"; }

# 日志函数
log_info() { echo "ℹ️  $*"; }
log_success() { green "✅ $*"; }
log_warn() { yellow "⚠️  $*"; }
log_error() { red "❌ $*"; }

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

INGRESS_PLATFORM_CONFIG_FILE="$THIS_DIR/deploy-ingress-platform-all.conf"
if [[ -f "$INGRESS_PLATFORM_CONFIG_FILE" ]]; then
    source "$INGRESS_PLATFORM_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Ingress 平台配置文件: $INGRESS_PLATFORM_CONFIG_FILE"
else
    log_error "缺少 Ingress 平台配置文件: $INGRESS_PLATFORM_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="ingress-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 调用子级脚本并传递集群参数
call_subscript() {
    local script_path="$1"
    shift
    local args=("$@")
    
    # 如果设置了 CLUSTER 环境变量，添加 --cluster 参数
    if [[ -n "${CLUSTER:-}" ]]; then
        "$script_path" --cluster "$CLUSTER" "${args[@]}"
    else
        "$script_path" "${args[@]}"
    fi
}

# 部署子级组件（按优先级）
deploy_sub_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始部署子级组件..."
    
    # 获取所有启用的组件及其优先级
    local components=()
    
    # 检查 Traefik
    if [[ "${traefik_enabled:-false}" == "true" ]]; then
        local priority="${traefik_priority:-1000}"
        components+=("$priority:traefik:$PROJECT_ROOT/traefik/deploy-traefik/deploy-traefik.sh")
    fi
    
    # 按优先级排序（数值大的先部署）
    IFS=$'\n' sorted_components=($(sort -nr <<<"${components[*]}"))
    unset IFS
    
    if [[ ${#sorted_components[@]} -eq 0 ]]; then
        log_warn "⚠️  没有启用的子级组件"
        return 0
    fi
    
    log_info "📋 子级组件部署顺序："
    for component_info in "${sorted_components[@]}"; do
        local priority="${component_info%%:*}"
        local component=$(echo "$component_info" | cut -d: -f2)
        log_info "  🚀 $component (优先级: $priority)"
    done
    
    # 部署子级组件
    for component_info in "${sorted_components[@]}"; do
        local priority="${component_info%%:*}"
        local component=$(echo "$component_info" | cut -d: -f2)
        local script_path=$(echo "$component_info" | cut -d: -f3)
        
        log_info "🚀 部署 $component..."
        
        if [[ -f "$script_path" ]]; then
            if call_subscript "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_success "✅ $component 部署成功"
            else
                log_error "❌ $component 部署失败"
                return 1
            fi
        else
            log_warn "⚠️  $component 部署脚本不存在: $script_path"
        fi
    done
    
    log_success "✅ 所有子级组件部署完成！"
}

# 主部署函数
deploy_ingress_platform() {
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "开始部署 Ingress 平台..."
    log_info "项目: $project_id, 命名空间: $namespace, 环境: $environment"
    
    # 部署子级组件（按优先级）
    deploy_sub_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"
    
    log_success "✅ Ingress 平台部署完成！"
}

# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    # 处理参数：如果第一个参数是 action（如 deploy），则跳过
    local action="${1:-deploy}"
    if [[ "$action" == "deploy" || "$action" == "uninstall" || "$action" == "status" ]]; then
        shift
    fi
    
    local project_id="${1:-${INGRESS_PLATFORM_PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${2:-${INGRESS_PLATFORM_NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${3:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    local dry_run="${4:-false}"
    
    # 执行部署
    deploy_ingress_platform "$project_id" "$namespace" "$environment" "$dry_run"
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
