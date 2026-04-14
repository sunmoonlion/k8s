#!/bin/bash

set -e

# 脚本目录（保存为变量，防止被统一部署模板覆盖）
REDIS_SECRETS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 自动定位 k8s 根目录（向上查找 utils/unified-deployment-template.sh）
PROJECT_ROOT=""
search_dir="$REDIS_SECRETS_SCRIPT_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/unified-deployment-template.sh" ]]; then
        PROJECT_ROOT="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
if [[ -z "$PROJECT_ROOT" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/unified-deployment-template.sh），SCRIPT_DIR=$REDIS_SECRETS_SCRIPT_DIR" 1>&2
    exit 1
fi

# 导入统一部署模板（提供日志函数和 Kubernetes 连接函数）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 恢复 Redis Secrets 脚本的目录路径
SCRIPT_DIR="$REDIS_SECRETS_SCRIPT_DIR"

# 配置文件路径
REDIS_SECRETS_CONFIG_FILE="$REDIS_SECRETS_SCRIPT_DIR/deploy-secrets-all.conf"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载配置
load_config() {
    # 使用保存的脚本目录确保路径正确
    local config_file="${REDIS_SECRETS_CONFIG_FILE:-$REDIS_SECRETS_SCRIPT_DIR/deploy-secrets-all.conf}"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Redis 密钥总控配置文件不存在: $config_file"
        exit 1
    fi
    
    source "$config_file"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_success "✅ Redis 密钥总控配置加载成功"
}

# 部署所有密钥组件（按优先级）
deploy_all_secrets() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "开始部署 Redis 所有密钥组件..."
    log_info "命名空间: $namespace"
    
    # 定义组件部署信息（组件名:启用标志:优先级:描述:脚本路径）
    local components=(
        "redis_auth_secret:${redis_auth_secret_enabled:-true}:${redis_auth_secret_priority:-1000}:Redis 认证密钥:$REDIS_SECRETS_SCRIPT_DIR/../redis-auth-secret/deploy-redis-auth-secret/deploy-redis-auth-secret.sh"
        "harbor_registry_secret:${harbor_registry_secret_enabled:-false}:${harbor_registry_secret_priority:-800}:Harbor 镜像拉取密钥:$REDIS_SECRETS_SCRIPT_DIR/../harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh"
        "redis_myapp_secret:${redis_myapp_secret_enabled:-true}:${redis_myapp_secret_priority:-600}:Redis 应用连接密钥:$REDIS_SECRETS_SCRIPT_DIR/../redis-myapp-secret/deploy-redis-myapp-secret/deploy-redis-myapp-secret.sh"
        "redis_llmopsservice_secret:${redis_llmopsservice_secret_enabled:-true}:${redis_llmopsservice_secret_priority:-500}:LLMOps Service Redis 连接密钥:$REDIS_SECRETS_SCRIPT_DIR/../redis-llmopsservice-secret/deploy-redis-llmopsservice-secret/deploy-redis-llmopsservice-secret.sh"
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
        log_info "📋 密钥组件部署顺序（按优先级排序）："
        
        for component_info in "${sorted_enabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "  🚀 $priority - $description"
        done
    elif [[ ${#enabled_components[@]} -eq 1 ]]; then
        # 只有一个组件启用时，直接使用，无需排序
        sorted_enabled_components=("${enabled_components[@]}")
        IFS=':' read -r name enabled priority description script_path <<< "${enabled_components[0]}"
        log_info "📋 密钥组件部署顺序（单个组件，无需排序）："
        log_info "  🚀 $description"
    else
        # 没有启用的组件
        sorted_enabled_components=()
        log_info "📋 密钥组件部署顺序：无启用的组件"
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
            # deploy-redis-auth-secret.sh 期望的参数是: project_id namespace environment dry_run
            # 但我们现在只有 namespace，需要传递默认值
            local project_id="${PROJECT_ID:-sunmoonai}"
            local environment="${ENVIRONMENT:-development}"
            local dry_run="false"
            
            if bash "$script_path" "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_success "✅ $description 部署成功"
            else
                log_error "❌ $description 部署失败"
                return 1
            fi
        else
            log_warn "⚠️  $description 部署脚本不存在: $script_path"
        fi
    done
    
    log_success "✅ Redis 所有密钥组件部署完成！"
    return 0
}

# 删除所有密钥组件
delete_all_secrets() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "开始删除 Redis 所有密钥组件..."
    log_info "命名空间: $namespace"
    
    # 删除 Redis 密钥
    if [[ -f "$SCRIPT_DIR/../redis-secrets/deploy-redis-secrets/deploy-redis-secrets.sh" ]]; then
        "$SCRIPT_DIR/../redis-secrets/deploy-redis-secrets/deploy-redis-secrets.sh" uninstall "$namespace"
    else
        log_warn "⚠️ Redis 密钥部署脚本不存在，跳过删除"
    fi
    
    log_success "✅ Redis 所有密钥组件删除完成！"
    return 0
}

# 检查所有密钥状态
check_all_secrets_status() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "检查 Redis 所有密钥组件状态..."
    log_info "命名空间: $namespace"
    
    # 检查 Redis 密钥
    if [[ -f "$SCRIPT_DIR/../redis-secrets/deploy-redis-secrets/deploy-redis-secrets.sh" ]]; then
        "$SCRIPT_DIR/../redis-secrets/deploy-redis-secrets/deploy-redis-secrets.sh" status "$namespace"
    else
        log_warn "⚠️ Redis 密钥部署脚本不存在"
    fi
    
    log_success "✅ Redis 所有密钥组件状态检查完成！"
    return 0
}

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS


# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    local namespace="${2:-data-platform-dev}"
    
    # 建立远程 k8s 连接（使用统一部署模板的函数）
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        return 1
    fi
    
    # 确保配置文件路径正确（使用保存的脚本目录，防止被覆盖）
    REDIS_SECRETS_CONFIG_FILE="$REDIS_SECRETS_SCRIPT_DIR/deploy-secrets-all.conf"
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_all_secrets "$namespace"
            ;;
        "uninstall")
            delete_all_secrets "$namespace"
            ;;
        "status")
            check_all_secrets_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Redis 所有密钥组件（默认）"
            echo "  uninstall        删除 Redis 所有密钥组件"
            echo "  status           检查所有密钥状态"
            echo "  help             显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  namespace 命名空间（默认: data-platform-dev）"
            echo ""
            echo "示例:"
            echo "  $0 deploy"
            echo "  $0 deploy data-platform-dev"
            echo "  $0 uninstall"
            echo "  $0 status"
            exit 0
            ;;
        *)
            log_error "未知操作: $action"
            echo "使用 '$0 help' 查看帮助信息"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
