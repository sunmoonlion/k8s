# 导入统一部署模板（建立远程 k8s 连接）
source "$(dirname "$0")/../../../../../../../utils/unified-deployment-template.sh"

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 配置文件路径
PGADMIN_STRIPPREFIX_CONFIG_FILE="$SCRIPT_DIR/deploy-pgadmin-stripprefix.conf"
# YAML 文件路径（相对于脚本目录的父目录）
PGADMIN_STRIPPREFIX_FILE="$(dirname "$SCRIPT_DIR")/pgadmin-stripprefix.yaml"

# 解析命令行参数中的集群选择（下沉到统一模板）
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    if type unified_parse_cluster_arg >/dev/null 2>&1; then
        unified_parse_cluster_arg "$@"
        ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
    fi
fi

# 加载配置
load_config() {
    if [[ ! -f "$PGADMIN_STRIPPREFIX_CONFIG_FILE" ]]; then
        log_error "Pgadmin StripPrefix 中间件配置文件不存在: $PGADMIN_STRIPPREFIX_CONFIG_FILE"
        exit 1
    fi
    
    source "$PGADMIN_STRIPPREFIX_CONFIG_FILE"
    log_success "✅ Pgadmin StripPrefix 中间件配置加载成功"
}

# 部署 Pgadmin StripPrefix 中间件
deploy_pgadmin_stripprefix() {
    local namespace="${1:-ops-platform-dev}"
    
    log_info "部署 Pgadmin StripPrefix 中间件..."
    log_info "命名空间: $namespace"
    
    # 检查配置文件是否存在
    if [[ ! -f "$PGADMIN_STRIPPREFIX_FILE" ]]; then
        log_error "Pgadmin StripPrefix 中间件配置文件不存在: $PGADMIN_STRIPPREFIX_FILE"
        return 1
    fi
    
    # 应用中间件配置
    log_info "应用 Pgadmin StripPrefix 中间件配置..."
    if kubectl apply -f "$PGADMIN_STRIPPREFIX_FILE" -n "$namespace"; then
        log_success "✅ Pgadmin StripPrefix 中间件配置应用成功"
    else
        log_error "❌ Pgadmin StripPrefix 中间件配置应用失败"
        return 1
    fi
    
    # 检查中间件状态
    log_info "检查 Pgadmin StripPrefix 中间件状态..."
    kubectl get middleware -n "$namespace" pgadmin-stripprefix
    
    log_success "✅ Pgadmin StripPrefix 中间件部署完成！"
    return 0
}

# 删除 Pgadmin StripPrefix 中间件
delete_pgadmin_stripprefix() {
    local namespace="${1:-ops-platform-dev}"
    
    log_info "删除 Pgadmin StripPrefix 中间件..."
    log_info "命名空间: $namespace"
    
    if kubectl delete -f "$PGADMIN_STRIPPREFIX_FILE" 2>/dev/null; then
        log_success "✅ Pgadmin StripPrefix 中间件配置删除成功"
    else
        log_warn "⚠️ Pgadmin StripPrefix 中间件配置不存在或删除失败"
    fi
    
    log_success "✅ Pgadmin StripPrefix 中间件删除完成！"
    return 0
}

# 检查中间件状态
check_stripprefix_status() {
    local namespace="${1:-ops-platform-dev}"
    
    log_info "检查 Pgadmin StripPrefix 中间件状态..."
    
    # 检查中间件是否存在
    if kubectl get middleware -n "$namespace" pgadmin-stripprefix >/dev/null 2>&1; then
        log_success "✅ Pgadmin StripPrefix 中间件存在"
        kubectl get middleware -n "$namespace" pgadmin-stripprefix
    else
        log_error "❌ Pgadmin StripPrefix 中间件不存在"
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
    local project_id="${2:-sunmoonai}"
    local namespace="${3:-ops-platform-dev}"
    local environment="${4:-development}"
    
    # 建立远程 k8s 连接
    setup_kubectl_environment
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_pgadmin_stripprefix "$namespace"
            ;;
        "uninstall")
            delete_pgadmin_stripprefix "$namespace"
            ;;
        "status")
            check_stripprefix_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Pgadmin StripPrefix 中间件（默认）"
            echo "  uninstall        删除 Pgadmin StripPrefix 中间件"
            echo "  status           检查中间件状态"
            echo "  help             显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  namespace 命名空间（默认: ops-platform-dev）"
            echo ""
            echo "示例:"
            echo "  $0 deploy"
            echo "  $0 deploy ops-platform-dev"
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

