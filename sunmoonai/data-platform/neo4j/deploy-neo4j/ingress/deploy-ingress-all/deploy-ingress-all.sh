#!/bin/bash

# Neo4j Ingress 总控部署脚本

set -e

# 导入统一部署模板（使用 BASH_SOURCE 确保路径相对脚本文件）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../../../../../utils/unified-deployment-template.sh"
NEO4J_INGRESS_CONFIG_FILE="$SCRIPT_DIR/deploy-ingress-all.conf"

# 加载配置
load_config() {
    if [[ ! -f "$NEO4J_INGRESS_CONFIG_FILE" ]]; then
        log_error "Neo4j Ingress 总控配置文件不存在: $NEO4J_INGRESS_CONFIG_FILE"
        exit 1
    fi
    
    source "$NEO4J_INGRESS_CONFIG_FILE"
    log_success "✅ Neo4j Ingress 总控配置加载成功"
}

# 部署所有 Ingress 组件
deploy_all_ingress() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "开始部署 Neo4j 所有 Ingress 组件..."
    log_info "命名空间: $namespace"
    
    # 部署 Web 路由
    if [[ "${web_routes_enabled:-true}" == "true" ]]; then
        log_info "部署 Neo4j Web 路由..."
        if [[ -f "$SCRIPT_DIR/../web-routes/deploy-web-routes/deploy-web-routes.sh" ]]; then
            "$SCRIPT_DIR/../web-routes/deploy-web-routes/deploy-web-routes.sh" deploy "$namespace"
        else
            log_error "❌ Neo4j Web 路由部署脚本不存在"
            return 1
        fi
    else
        log_info "跳过 Neo4j Web 路由部署（已禁用）"
    fi
    
    # 部署 TCP 路由
    if [[ "${tcp_routes_enabled:-true}" == "true" ]]; then
        log_info "部署 Neo4j TCP 路由..."
        if [[ -f "$SCRIPT_DIR/../tcp-routes/deploy-tcp-routes/deploy-tcp-routes.sh" ]]; then
            "$SCRIPT_DIR/../tcp-routes/deploy-tcp-routes/deploy-tcp-routes.sh" deploy "$namespace"
        else
            log_error "❌ Neo4j TCP 路由部署脚本不存在"
            return 1
        fi
    else
        log_info "跳过 Neo4j TCP 路由部署（已禁用）"
    fi
    
    log_success "✅ Neo4j 所有 Ingress 组件部署完成！"
    return 0
}

# 删除所有 Ingress 组件
delete_all_ingress() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "开始删除 Neo4j 所有 Ingress 组件..."
    log_info "命名空间: $namespace"
    
    # 删除 Web 路由
    if [[ -f "$SCRIPT_DIR/../web-routes/deploy-web-routes/deploy-web-routes.sh" ]]; then
        "$SCRIPT_DIR/../web-routes/deploy-web-routes/deploy-web-routes.sh" uninstall "$namespace"
    else
        log_warn "⚠️ Neo4j Web 路由部署脚本不存在，跳过删除"
    fi
    
    # 删除 TCP 路由
    if [[ -f "$SCRIPT_DIR/../tcp-routes/deploy-tcp-routes/deploy-tcp-routes.sh" ]]; then
        "$SCRIPT_DIR/../tcp-routes/deploy-tcp-routes/deploy-tcp-routes.sh" uninstall "$namespace"
    else
        log_warn "⚠️ Neo4j TCP 路由部署脚本不存在，跳过删除"
    fi
    
    log_success "✅ Neo4j 所有 Ingress 组件删除完成！"
    return 0
}

# 检查所有 Ingress 状态
check_all_ingress_status() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "检查 Neo4j 所有 Ingress 组件状态..."
    log_info "命名空间: $namespace"
    
    # 检查 Web 路由
    if [[ -f "$SCRIPT_DIR/../web-routes/deploy-web-routes/deploy-web-routes.sh" ]]; then
        "$SCRIPT_DIR/../web-routes/deploy-web-routes/deploy-web-routes.sh" status "$namespace"
    else
        log_warn "⚠️ Neo4j Web 路由部署脚本不存在"
    fi
    
    # 检查 TCP 路由
    if [[ -f "$SCRIPT_DIR/../tcp-routes/deploy-tcp-routes/deploy-tcp-routes.sh" ]]; then
        "$SCRIPT_DIR/../tcp-routes/deploy-tcp-routes/deploy-tcp-routes.sh" status "$namespace"
    else
        log_warn "⚠️ Neo4j TCP 路由部署脚本不存在"
    fi
    
    log_success "✅ Neo4j 所有 Ingress 组件状态检查完成！"
    return 0
}

# 主函数
main() {
    local action="${1:-deploy}"
    local namespace="${2:-data-platform-dev}"
    
    # 建立远程 k8s 连接
    setup_connection
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_all_ingress "$namespace"
            ;;
        "uninstall")
            delete_all_ingress "$namespace"
            ;;
        "status")
            check_all_ingress_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Neo4j 所有 Ingress 组件（默认）"
            echo "  uninstall        删除 Neo4j 所有 Ingress 组件"
            echo "  status           检查所有 Ingress 状态"
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
