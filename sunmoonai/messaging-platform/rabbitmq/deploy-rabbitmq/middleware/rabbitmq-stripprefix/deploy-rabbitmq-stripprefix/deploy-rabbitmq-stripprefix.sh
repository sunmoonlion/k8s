
#!/bin/bash

# 脚本目录（在 source unified-deployment-template.sh 之前保存，因为它会覆盖 SCRIPT_DIR）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（相对于 deploy-rabbitmq 目录）
# 从 deploy-rabbitmq-stripprefix/ -> rabbitmq-stripprefix/ -> middleware/ -> deploy-rabbitmq/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# 导入统一部署模板（提供日志函数和 Kubernetes 连接函数）
# 从 deploy-rabbitmq/ -> rabbitmq/ -> messaging-platform/ -> sunmoonai/ -> k8s/
source "$PROJECT_ROOT/../../../../utils/unified-deployment-template.sh"

# 恢复脚本目录路径（unified-deployment-template.sh 会覆盖 SCRIPT_DIR，需要恢复）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RABBITMQ_STRIPPREFIX_CONFIG_FILE="$SCRIPT_DIR/deploy-rabbitmq-stripprefix.conf"
# rabbitmq-stripprefix.yaml 在上一级目录（rabbitmq-stripprefix/）
RABBITMQ_STRIPPREFIX_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/rabbitmq-stripprefix.yaml"

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

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
# 只有在参数中包含 --cluster 时才解析，避免误判
if [[ $# -gt 0 ]] && echo "$@" | grep -qE '(--cluster|-c|-C)'; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载配置
load_config() {
    if [[ ! -f "$RABBITMQ_STRIPPREFIX_CONFIG_FILE" ]]; then
        log_error "RabbitMQ StripPrefix 中间件配置文件不存在: $RABBITMQ_STRIPPREFIX_CONFIG_FILE"
        exit 1
    fi
    
    source "$RABBITMQ_STRIPPREFIX_CONFIG_FILE"
    log_success "✅ RabbitMQ StripPrefix 中间件配置加载成功"
}

# 部署 RabbitMQ StripPrefix 中间件
deploy_rabbitmq_stripprefix() {
    local namespace="${1:-messaging-platform-dev}"
    
    log_info "部署 RabbitMQ StripPrefix 中间件..."
    log_info "命名空间: $namespace"
    
    # 检查配置文件是否存在
    if [[ ! -f "$RABBITMQ_STRIPPREFIX_FILE" ]]; then
        log_error "RabbitMQ StripPrefix 中间件配置文件不存在: $RABBITMQ_STRIPPREFIX_FILE"
        return 1
    fi
    
    # 应用中间件配置
    log_info "应用 RabbitMQ StripPrefix 中间件配置..."
    if kubectl apply -f "$RABBITMQ_STRIPPREFIX_FILE" -n "$namespace"; then
        log_success "✅ RabbitMQ StripPrefix 中间件配置应用成功"
    else
        log_error "❌ RabbitMQ StripPrefix 中间件配置应用失败"
        return 1
    fi
    
    # 检查中间件状态
    log_info "检查 RabbitMQ StripPrefix 中间件状态..."
    kubectl get middleware -n "$namespace" rabbitmq-stripprefix
    
    log_success "✅ RabbitMQ StripPrefix 中间件部署完成！"
    return 0
}

# 删除 RabbitMQ StripPrefix 中间件
delete_rabbitmq_stripprefix() {
    local namespace="${1:-messaging-platform-dev}"
    
    log_info "删除 RabbitMQ StripPrefix 中间件..."
    log_info "命名空间: $namespace"
    
    if kubectl delete -f "$RABBITMQ_STRIPPREFIX_FILE" 2>/dev/null; then
        log_success "✅ RabbitMQ StripPrefix 中间件配置删除成功"
    else
        log_warn "⚠️ RabbitMQ StripPrefix 中间件配置不存在或删除失败"
    fi
    
    log_success "✅ RabbitMQ StripPrefix 中间件删除完成！"
    return 0
}

# 检查中间件状态
check_stripprefix_status() {
    local namespace="${1:-messaging-platform-dev}"
    
    log_info "检查 RabbitMQ StripPrefix 中间件状态..."
    
    # 检查中间件是否存在
    if kubectl get middleware -n "$namespace" rabbitmq-stripprefix >/dev/null 2>&1; then
        log_success "✅ RabbitMQ StripPrefix 中间件存在"
        kubectl get middleware -n "$namespace" rabbitmq-stripprefix
    else
        log_error "❌ RabbitMQ StripPrefix 中间件不存在"
        return 1
    fi
}

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS


# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    local namespace="${2:-messaging-platform-dev}"
    
    # 建立远程 k8s 连接
    setup_connection
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_rabbitmq_stripprefix "$namespace"
            ;;
        "uninstall")
            delete_rabbitmq_stripprefix "$namespace"
            ;;
        "status")
            check_stripprefix_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 RabbitMQ StripPrefix 中间件（默认）"
            echo "  uninstall        删除 RabbitMQ StripPrefix 中间件"
            echo "  status           检查中间件状态"
            echo "  help             显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  namespace 命名空间（默认: messaging-platform-dev）"
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

