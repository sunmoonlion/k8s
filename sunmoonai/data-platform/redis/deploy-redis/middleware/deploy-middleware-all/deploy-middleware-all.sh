#!/bin/bash

# Redis 中间件总控部署脚本
# 注意：Redis 使用 TCP 路由，仅支持 policy（rateLimit），不支持 stripprefix

set -e

# 脚本目录（保存为变量，防止被统一部署模板覆盖）
REDIS_MIDDLEWARE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
# 从 deploy-middleware-all/ -> middleware/ -> deploy-redis/ -> redis/ -> data-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$REDIS_MIDDLEWARE_SCRIPT_DIR/../../../../../.." && pwd)"

# 导入统一部署模板（可能会覆盖 SCRIPT_DIR，所以我们已经保存了）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 使用保存的脚本目录
REDIS_MIDDLEWARE_CONFIG_FILE="$REDIS_MIDDLEWARE_SCRIPT_DIR/deploy-middleware-all.conf"

# 加载配置
load_config() {
    # 使用保存的脚本目录确保路径正确
    local config_file="${REDIS_MIDDLEWARE_CONFIG_FILE:-$REDIS_MIDDLEWARE_SCRIPT_DIR/deploy-middleware-all.conf}"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Redis 中间件总控配置文件不存在: $config_file"
        log_error "REDIS_MIDDLEWARE_SCRIPT_DIR: $REDIS_MIDDLEWARE_SCRIPT_DIR"
        log_error "REDIS_MIDDLEWARE_CONFIG_FILE: ${REDIS_MIDDLEWARE_CONFIG_FILE:-未设置}"
        exit 1
    fi

    source "$config_file"
    log_success "✅ Redis 中间件总控配置加载成功"
}

# 部署所有中间件组件
deploy_all_middleware() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "开始部署 Redis 中间件组件..."
    log_info "命名空间: $namespace"
    log_warn "⚠️ 注意：Redis 使用 TCP 路由，仅支持 policy（rateLimit）"
    
    local components=(
        "policy:${redis_policy_enabled:-true}:${redis_policy_priority:-100}:Redis Policy:$REDIS_MIDDLEWARE_SCRIPT_DIR/../redis-policy/deploy-redis-policy/deploy-redis-policy.sh"
    )
    
    # 过滤启用的组件
    local enabled=()
    for c in "${components[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        [[ "$en" == "true" ]] && enabled+=("$c")
    done
    
    # 按优先级部署
    for c in "${enabled[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        log_info "🚀 部署 $desc (优先级: $pr) ..."
        if [[ -f "$path" ]]; then
            if "$path" deploy "$namespace"; then
                log_success "✅ $desc 部署成功"
            else
                log_error "❌ $desc 部署失败"
                return 1
            fi
        else
            log_error "❌ $desc 部署脚本不存在: $path"
            return 1
        fi
    done
    
    log_success "✅ Redis 所有中间件组件部署完成！"
    return 0
}

# 删除所有中间件组件
delete_all_middleware() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "开始删除 Redis 所有中间件组件..."
    log_info "命名空间: $namespace"
    
    local components=(
        "policy:${redis_policy_enabled:-true}:${redis_policy_priority:-100}:Redis Policy:$REDIS_MIDDLEWARE_SCRIPT_DIR/../redis-policy/deploy-redis-policy/deploy-redis-policy.sh"
    )
    
    # 过滤启用的组件
    local enabled=()
    for c in "${components[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        [[ "$en" == "true" ]] && enabled+=("$c")
    done
    
    # 按逆序删除
    for c in "${enabled[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        log_info "卸载 $desc (优先级: $pr) ..."
        if [[ -f "$path" ]]; then
            "$path" uninstall "$namespace" || log_warn "⚠️ $desc 卸载失败或不存在"
        else
            log_warn "⚠️ $desc 部署脚本不存在，跳过删除"
        fi
    done
    
    log_success "✅ Redis 所有中间件组件删除完成！"
    return 0
}

# 检查所有中间件状态
check_all_middleware_status() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "检查 Redis 所有中间件组件状态..."
    log_info "命名空间: $namespace"
    
    local components=(
        "policy:${redis_policy_enabled:-true}:${redis_policy_priority:-100}:Redis Policy:$REDIS_MIDDLEWARE_SCRIPT_DIR/../redis-policy/deploy-redis-policy/deploy-redis-policy.sh"
    )
    
    for c in "${components[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        log_info "检查 $desc (优先级: $pr) ..."
        if [[ -f "$path" ]]; then
            "$path" status "$namespace" || log_warn "⚠️ $desc 状态检查失败或不存在"
        else
            log_warn "⚠️ $desc 部署脚本不存在"
        fi
    done
    
    log_success "✅ Redis 所有中间件组件状态检查完成！"
    return 0
}

# 主函数
main() {
    local action="${1:-deploy}"
    local project_id="${2:-sunmoonai}"      # 父级传递的项目ID（虽然不使用，但保持接口一致）
    local namespace="${3:-data-platform-dev}"  # 父级传递的命名空间
    local environment="${4:-development}"    # 父级传递的环境（虽然不使用，但保持接口一致）
    local dry_run="${5:-false}"             # 父级传递的 dry_run（虽然不使用，但保持接口一致）
    
    # 建立远程 k8s 连接
    setup_connection
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_all_middleware "$namespace"
            ;;
        "uninstall")
            delete_all_middleware "$namespace"
            ;;
        "status")
            check_all_middleware_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Redis 所有中间件组件（默认）"
            echo "  uninstall        删除 Redis 所有中间件组件"
            echo "  status           检查所有中间件状态"
            echo "  help             显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  action        操作类型（deploy/uninstall/status）"
            echo "  project_id    项目ID（可选，保持接口一致性）"
            echo "  namespace     命名空间（默认: data-platform-dev）"
            echo "  environment   环境（可选，保持接口一致性）"
            echo "  dry_run       试运行模式（可选，保持接口一致性）"
            echo ""
            echo "注意：Redis 使用 TCP 路由，仅支持 policy（rateLimit），不支持 stripprefix"
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
