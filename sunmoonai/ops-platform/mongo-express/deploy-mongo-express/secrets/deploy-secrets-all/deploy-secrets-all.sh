#!/bin/bash

# =============================================================================
# Mongo Express Secrets 总控部署脚本
# 文件名: deploy-secrets-all.sh
# 用途: 统一部署Mongo Express的所有Secret
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

# 自动定位 k8s 根目录（向上查找 utils/cluster-arg-parser.sh）
K8S_ROOT_DIR=""
search_dir="$SCRIPT_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
        K8S_ROOT_DIR="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
if [[ -z "$K8S_ROOT_DIR" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），SCRIPT_DIR=$SCRIPT_DIR" 1>&2
    exit 1
fi

# 集群参数解析（轻量，无连接副作用）
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"

# 日志函数
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# 解析命令行参数中的集群选择（下沉到统一模板）
declare -a PARSED_ARGS=()
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    log_info "原始参数数量: $#"
    log_info "原始参数: ${ORIGINAL_ARGS[@]}"
    if type unified_parse_cluster_arg >/dev/null 2>&1; then
        unified_parse_cluster_arg "$@"
        log_info "解析后参数数量: ${#PARSED_ARGS[@]}"
        log_info "解析后参数: ${PARSED_ARGS[@]}"
        # 注意：不要覆盖 ORIGINAL_ARGS，保留原始参数用于后续处理
        # PARSED_ARGS 包含已移除 --cluster 参数的参数列表
    else
        # 兜底：即使解析函数不可用，也保证 PARSED_ARGS 已定义，避免 set -u 下报错
        PARSED_ARGS=("$@")
    fi
fi

# 加载配置（现在可以使用已设置的 CLUSTER 值）
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
else
    log_error "错误: 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 部署子级组件（按优先级）
deploy_sub_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "🔧 开始部署子级组件..."
    
    # 定义组件部署信息（组件名:启用标志:优先级:描述:脚本路径）
    local components=(
        "harbor_registry_secret:${harbor_registry_secret_enabled:-true}:${harbor_registry_secret_priority:-800}:Harbor 镜像拉取密钥:$SCRIPT_DIR/../harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh"
        "mongo_express_secrets:${mongo_express_secrets_enabled:-true}:${mongo_express_secrets_priority:-1000}:Mongo Express 认证密钥:$SCRIPT_DIR/../mongo-express-secrets/deploy-mongo-express-secrets/deploy-mongo-express-secrets.sh"
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
        
        if [[ ${#enabled_components[@]} -gt 1 ]]; then
            log_info "🚀 部署 $description (优先级: $priority)..."
        else
            log_info "🚀 部署 $description..."
        fi
        
        if [[ -f "$script_path" ]]; then
            local original_dir="$(pwd)"
            cd "$(dirname "$script_path")"
            
            # 如果 CLUSTER 环境变量已设置且非空，传递给子脚本
            # 使用更严格的检查：确保 CLUSTER 不为空且不是空字符串
            local cluster_value_trimmed=$(echo "${CLUSTER:-}" | tr -d '[:space:]')
            if [[ -n "${CLUSTER:-}" ]] && [[ "${CLUSTER}" != "" ]] && [[ -n "$cluster_value_trimmed" ]]; then
                log_info "传递 CLUSTER 参数: --cluster $CLUSTER (trimmed: $cluster_value_trimmed)"
                if ./"$(basename "$script_path")" "$project_id" "$namespace" "$environment" "$dry_run" --cluster "$CLUSTER"; then
                    log_success "✅ $description 部署成功"
                else
                    log_error "❌ $description 部署失败"
                    cd "$original_dir"
                    return 1
                fi
            else
                log_info "未设置 CLUSTER 环境变量或 CLUSTER 为空，跳过 --cluster 参数"
                if ./"$(basename "$script_path")" "$project_id" "$namespace" "$environment" "$dry_run"; then
                    log_success "✅ $description 部署成功"
                else
                    log_error "❌ $description 部署失败"
                    cd "$original_dir"
                    return 1
                fi
            fi
            
            cd "$original_dir"
        else
            log_warn "⚠️  $description 部署脚本不存在: $script_path"
        fi
    done
    
    log_success "✅ 子级组件部署完成！"
}

# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    # 如果 PARSED_ARGS 有值，使用它（已移除 --cluster），否则使用原始参数
    if [[ ${#PARSED_ARGS[@]} -gt 0 ]]; then
        set -- "${PARSED_ARGS[@]}"
    else
        set -- "${ORIGINAL_ARGS[@]}"
    fi
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    # 调试：显示解析后的参数
    log_info "解析后的参数数量: $#"
    log_info "解析后的参数: $@"
    
    local project_id="${1:-${PROJECT_ID:-sunmoonai}}"
    local namespace="${2:-${NAMESPACE:-ops-platform-dev}}"
    local environment="${3:-${ENVIRONMENT:-development}}"
    local dry_run="${4:-false}"
    
    log_info "🚀 开始部署 Mongo Express Secrets..."
    log_info "  项目ID: $project_id"
    log_info "  命名空间: $namespace"
    log_info "  环境: $environment"
    log_info "  试运行: $dry_run"
    echo ""
    
    # 部署子级组件
    if deploy_sub_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"; then
        log_success "✅ Mongo Express Secrets 部署完成！"
        return 0
    else
        log_error "❌ Mongo Express Secrets 部署失败"
        return 1
    fi
}

# 显示帮助信息
show_help() {
    echo "Mongo Express Secrets 总控部署脚本"
    echo ""
    echo "用法:"
    echo "  $0 [项目ID] [命名空间] [环境] [试运行]"
    echo ""
    echo "参数:"
    echo "  项目ID     项目标识符 (默认: ${PROJECT_ID:-sunmoonai})"
    echo "  命名空间   Kubernetes 命名空间 (默认: ${NAMESPACE:-ops-platform-dev})"
    echo "  环境       部署环境 (默认: ${ENVIRONMENT:-development})"
    echo "  试运行     是否试运行 (默认: false)"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认参数"
    echo "  $0 sunmoonai ops-platform-dev dev   # 指定参数"
    echo "  $0 sunmoonai ops-platform-dev dev true # 试运行模式"
    echo ""
    echo "配置文件: $CONFIG_FILE"
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    main "$@"
fi
