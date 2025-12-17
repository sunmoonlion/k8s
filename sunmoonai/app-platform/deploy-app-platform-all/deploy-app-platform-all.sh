#!/usr/bin/env bash

# ============================================================================
# App Platform 统一部署脚本
# 用途: 统一部署 App Platform 下的所有应用组件
# 说明: 支持 shared-apps 和 business-apps 下的多个组件
# ============================================================================

# 脚本目录配置
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$THIS_DIR")"

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

# 解析命令行参数
parse_cluster_arg() {
    local args=("$@")
    PARSED_ARGS=()
    local cluster_value=""
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        shopt -s nocasematch
        case "${args[$i]}" in
            --[cC][lL][uU][sS][tT][eE][rR]=*)
                cluster_value="${args[$i]#*=}"
                cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                export CLUSTER="$cluster_value"
                log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    cluster_value="${args[$((i+1))]}"
                    cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                    export CLUSTER="$cluster_value"
                    log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                    i=$((i+1))
                else
                    log_error "❌ --cluster 参数需要指定值"
                    exit 1
                fi
                ;;
            *)
                PARSED_ARGS+=("${args[$i]}")
                ;;
        esac
        shopt -u nocasematch
        i=$((i+1))
    done
    
    if [[ -n "$cluster_value" ]]; then
        if [[ -f "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

# 先解析命令行参数
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

APP_PLATFORM_CONFIG_FILE="$THIS_DIR/deploy-app-platform-all.conf"
if [[ -f "$APP_PLATFORM_CONFIG_FILE" ]]; then
  source "$APP_PLATFORM_CONFIG_FILE"
  
  # 加载集群配置映射函数（使用 utils 中的通用函数）
  if [[ -f "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh" ]]; then
    source "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
    apply_cluster_config_mapping
  fi
  
  log_info "已加载 App Platform 配置: $APP_PLATFORM_CONFIG_FILE"
else
  log_error "缺少 App Platform 配置文件: $APP_PLATFORM_CONFIG_FILE"; exit 1
fi

# 默认参数
DEFAULT_PROJECT_ID="${APP_PLATFORM_PROJECT_ID:-sunmoonai}"
DEFAULT_NAMESPACE="${APP_PLATFORM_NAMESPACE:-app-platform-dev}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-development}"

# 调用子级脚本并传递集群参数
call_subscript() {
    local script_path="$1"
    shift
    local args=("$@")
    
    if [[ -n "${CLUSTER:-}" ]]; then
        "$script_path" --cluster "$CLUSTER" "${args[@]}"
    else
        "$script_path" "${args[@]}"
    fi
}

# 定义组件路径映射（硬编码，确保准确）
declare -A COMPONENT_PATHS=(
    # 共享应用 (shared-apps)
    ["celeryworker_bff"]="shared-apps/celeryworker-app/celeryworker-bff/deploy-celeryworker-bff/deploy-multi-celeryworker.sh"
    ["document_converter_bff"]="shared-apps/document-converter-app/document-converter-bff/deploy-document-converter-bff/deploy-document-converter.sh"
    ["onlyoffice_docs_bff"]="shared-apps/onlyoffice-docs-app/onlyoffice-docs-bff/deploy-onlyoffice-docs/deploy-onlyoffice-docs.sh"
    
    # 业务应用 (business-apps)
    ["incubator_bff"]="business-apps/incubator-app/incubator-app-bff/deploy-incubator-bff/deploy-incubator-bff.sh"
    ["incubator_ssr"]="business-apps/incubator-app/incubator-app-ssr/deploy-incubator-ssr/deploy-incubator-ssr.sh"
    ["llmops_bff"]="business-apps/llmops-app/llmops-app-bff/deploy-llmops-bff/deploy-llmops-service.sh"
    ["llmops_ssr"]="business-apps/llmops-app/llmops-app-ssr/deploy-llmops-ssr/deploy-llmops-ssr.sh"
)

# 部署子级组件（按优先级）
deploy_sub_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始部署子级组件..."
    
    local components=()
    
    # 遍历所有组件路径映射，检查是否启用
    for component_id in "${!COMPONENT_PATHS[@]}"; do
        enabled_var="${component_id}_enabled"
        priority_var="${component_id}_priority"
        
        if [[ "${!enabled_var:-false}" == "true" ]]; then
            script_path="$PROJECT_ROOT/${COMPONENT_PATHS[$component_id]}"
            priority="${!priority_var:-500}"
            components+=("$priority:$component_id:$script_path")
        fi
    done
    
    # 按优先级排序（数值越大越先部署）
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

# 卸载子级组件（按优先级，逆序）
uninstall_sub_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始卸载子级组件..."
    
    local components=()
    
    # 遍历所有组件路径映射，检查是否启用
    for component_id in "${!COMPONENT_PATHS[@]}"; do
        enabled_var="${component_id}_enabled"
        priority_var="${component_id}_priority"
        
        if [[ "${!enabled_var:-false}" == "true" ]]; then
            script_path="$PROJECT_ROOT/${COMPONENT_PATHS[$component_id]}"
            priority="${!priority_var:-500}"
            components+=("$priority:$component_id:$script_path")
        fi
    done
    
    # 按优先级排序（数值越大越先部署）
    IFS=$'\n' sorted_components=($(sort -nr <<<"${components[*]}"))
    unset IFS
    
    if [[ ${#sorted_components[@]} -eq 0 ]]; then
        log_warn "⚠️  没有启用的子级组件"
        return 0
    fi
    
    log_info "📋 子级组件卸载顺序（逆序）："
    for component_info in "${sorted_components[@]}"; do
        local priority="${component_info%%:*}"
        local component=$(echo "$component_info" | cut -d: -f2)
        log_info "  🗑️  $component (优先级: $priority)"
    done
    
    # 逆序卸载（从低优先级到高优先级）
    for ((idx=${#sorted_components[@]}-1; idx>=0; idx--)); do
        local component_info="${sorted_components[$idx]}"
        local priority="${component_info%%:*}"
        local component=$(echo "$component_info" | cut -d: -f2)
        local script_path=$(echo "$component_info" | cut -d: -f3)
        
        log_info "🗑️  卸载 $component..."
        
        if [[ -f "$script_path" ]]; then
            # 调用子级脚本的 uninstall 操作
            if call_subscript "$script_path" uninstall; then
                log_success "✅ $component 卸载成功"
            else
                log_warn "⚠️  $component 卸载失败或已不存在"
            fi
        else
            log_warn "⚠️  $component 部署脚本不存在: $script_path"
        fi
    done
    
    log_success "✅ 所有子级组件卸载完成！"
}

# 主部署函数
deploy_app_platform() {
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "开始部署 App Platform..."
    log_info "项目: $project_id, 命名空间: $namespace, 环境: $environment"
    
    deploy_sub_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"
    
    log_success "✅ App Platform 部署完成！"
}

# 主卸载函数
uninstall_app_platform() {
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "开始卸载 App Platform..."
    log_info "项目: $project_id, 命名空间: $namespace, 环境: $environment"
    
    uninstall_sub_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"
    
    log_success "✅ App Platform 卸载完成！"
}

# 主函数
main() {
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    if [[ "$action" == "deploy" || "$action" == "uninstall" || "$action" == "status" ]]; then
        shift
    fi
    
    local project_id="${1:-${APP_PLATFORM_PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${2:-${APP_PLATFORM_NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${3:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    local dry_run="${4:-false}"
    
    case "$action" in
        deploy)
            deploy_app_platform "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        uninstall)
            uninstall_app_platform "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        status)
            log_info "状态查询功能待实现"
            ;;
        *)
            log_error "❌ 未知操作: $action"
            log_info "支持的操作: deploy, uninstall, status"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

