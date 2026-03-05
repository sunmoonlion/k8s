#!/bin/bash

# RabbitMQ 中间件总控部署脚本
# 统一部署所有 RabbitMQ 中间件组件（stripprefix + policy）

set -e

# 脚本目录（保存为变量，防止被统一部署模板覆盖）
RABBITMQ_MIDDLEWARE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（相对于 deploy-rabbitmq 目录）
# 从 deploy-middleware-all/ -> middleware/ -> deploy-rabbitmq/
PROJECT_ROOT="$(cd "$RABBITMQ_MIDDLEWARE_SCRIPT_DIR/../.." && pwd)"

# 导入统一部署模板（提供日志函数和 Kubernetes 连接函数）
# 从 deploy-rabbitmq/ -> rabbitmq/ -> messaging-platform/ -> sunmoonai/ -> k8s/
source "$PROJECT_ROOT/../../../../utils/unified-deployment-template.sh"

# 恢复 RabbitMQ 中间件脚本的目录路径
SCRIPT_DIR="$RABBITMQ_MIDDLEWARE_SCRIPT_DIR"
RABBITMQ_MIDDLEWARE_CONFIG_FILE="$SCRIPT_DIR/deploy-middleware-all.conf"

# 建立远程 k8s 连接（封装 setup_kubectl_environment）
setup_connection() {
    log_info "建立远程 Kubernetes 连接..."
    
    # 读取 Kubernetes 配置
    if ! read_k8s_config; then
        log_error "无法读取 Kubernetes 配置文件"
        return 1
    fi
    
    # 设置 Kubernetes 环境（建立远程连接）
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        return 1
    fi
    
    log_success "远程 Kubernetes 连接建立成功"
    return 0
}

# 加载配置
load_config() {
    if [[ ! -f "$RABBITMQ_MIDDLEWARE_CONFIG_FILE" ]]; then
        log_error "RabbitMQ 中间件总控配置文件不存在: $RABBITMQ_MIDDLEWARE_CONFIG_FILE"
        exit 1
    fi

    source "$RABBITMQ_MIDDLEWARE_CONFIG_FILE"
    log_success "✅ RabbitMQ 中间件总控配置加载成功"
}

# 部署所有中间件组件（按优先级）
deploy_all_middleware() {
    local namespace="${1:-messaging-platform-dev}"
    
    log_info "开始基于优先级的 RabbitMQ 中间件组件部署..."
    log_info "命名空间: $namespace"
    
    local components=(
        "stripprefix:${rabbitmq_stripprefix_enabled:-true}:${rabbitmq_stripprefix_priority:-200}:RabbitMQ StripPrefix:$SCRIPT_DIR/../rabbitmq-stripprefix/deploy-rabbitmq-stripprefix/deploy-rabbitmq-stripprefix.sh"
        "policy:${rabbitmq_policy_enabled:-true}:${rabbitmq_policy_priority:-100}:RabbitMQ Policy:$SCRIPT_DIR/../rabbitmq-policy/deploy-rabbitmq-policy/deploy-rabbitmq-policy.sh"
    )
    
    # 过滤启用的组件并按优先级排序
    local enabled=()
    for c in "${components[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        [[ "$en" == "true" ]] && enabled+=("$c")
    done
    
    # 按优先级降序排序（数值越大越先部署）
    if [[ ${#enabled[@]} -gt 1 ]]; then
        IFS=$'\n' enabled=($(printf '%s\n' "${enabled[@]}" | sort -t: -k3 -nr))
    fi
    
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
    
    log_success "✅ RabbitMQ 所有中间件组件部署完成！"
    return 0
}

# 删除所有中间件组件（按优先级逆序）
delete_all_middleware() {
    local namespace="${1:-messaging-platform-dev}"
    
    log_info "开始删除 RabbitMQ 所有中间件组件（按优先级逆序）..."
    log_info "命名空间: $namespace"
    
    local components=(
        "stripprefix:${rabbitmq_stripprefix_enabled:-true}:${rabbitmq_stripprefix_priority:-200}:RabbitMQ StripPrefix:$SCRIPT_DIR/../rabbitmq-stripprefix/deploy-rabbitmq-stripprefix/deploy-rabbitmq-stripprefix.sh"
        "policy:${rabbitmq_policy_enabled:-true}:${rabbitmq_policy_priority:-100}:RabbitMQ Policy:$SCRIPT_DIR/../rabbitmq-policy/deploy-rabbitmq-policy/deploy-rabbitmq-policy.sh"
    )
    
    # 过滤启用的组件并按优先级升序排序（卸载时逆序）
    local enabled=()
    for c in "${components[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        [[ "$en" == "true" ]] && enabled+=("$c")
    done
    
    # 按优先级升序排序（数值越小越先删除，逆序卸载）
    if [[ ${#enabled[@]} -gt 1 ]]; then
        IFS=$'\n' enabled=($(printf '%s\n' "${enabled[@]}" | sort -t: -k3 -n))
    fi
    
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
    
    log_success "✅ RabbitMQ 所有中间件组件删除完成！"
    return 0
}

# 检查所有中间件状态
check_all_middleware_status() {
    local namespace="${1:-messaging-platform-dev}"
    
    log_info "检查 RabbitMQ 所有中间件组件状态..."
    log_info "命名空间: $namespace"
    
    local components=(
        "stripprefix:${rabbitmq_stripprefix_enabled:-true}:${rabbitmq_stripprefix_priority:-200}:RabbitMQ StripPrefix:$SCRIPT_DIR/../rabbitmq-stripprefix/deploy-rabbitmq-stripprefix/deploy-rabbitmq-stripprefix.sh"
        "policy:${rabbitmq_policy_enabled:-true}:${rabbitmq_policy_priority:-100}:RabbitMQ Policy:$SCRIPT_DIR/../rabbitmq-policy/deploy-rabbitmq-policy/deploy-rabbitmq-policy.sh"
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
    
    log_success "✅ RabbitMQ 所有中间件组件状态检查完成！"
    return 0
}

# 主函数
main() {
    local action="${1:-deploy}"
    local project_id="${2:-sunmoonai}"      # 父级传递的项目ID（虽然不使用，但保持接口一致）
    local namespace="${3:-messaging-platform-dev}"  # 父级传递的命名空间
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
            echo "  deploy           部署 RabbitMQ 所有中间件组件（默认）"
            echo "  uninstall        删除 RabbitMQ 所有中间件组件"
            echo "  status           检查所有中间件状态"
            echo "  help             显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  action        操作类型（deploy/uninstall/status）"
            echo "  project_id    项目ID（可选，保持接口一致性）"
            echo "  namespace     命名空间（默认: messaging-platform-dev）"
            echo "  environment   环境（可选，保持接口一致性）"
            echo "  dry_run       试运行模式（可选，保持接口一致性）"
            echo ""
            echo "示例:"
            echo "  $0 deploy"
            echo "  $0 deploy messaging-platform-dev"
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

