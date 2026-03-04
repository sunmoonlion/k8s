#!/bin/bash

# Neo4j Web 路由部署脚本

set -e

# 导入统一部署模板（使用 BASH_SOURCE 确保路径相对脚本文件）
NEO4J_INGRESS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$NEO4J_INGRESS_SCRIPT_DIR/../../../../../../../utils/unified-deployment-template.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO4J_WEB_FILE="$(dirname "$SCRIPT_DIR")/neo4j-web-route.yaml"
# 主配置文件路径（相对于脚本目录）
NEO4J_MAIN_CONFIG_FILE="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")/deploy-neo4j.conf"

# 加载配置
load_config() {
    if [[ ! -f "$NEO4J_MAIN_CONFIG_FILE" ]]; then
        log_error "主配置文件不存在: $NEO4J_MAIN_CONFIG_FILE"
        exit 1
    fi
    
    # 加载主配置
    source "$NEO4J_MAIN_CONFIG_FILE"
    
    # 动态获取配置值
    # SERVICE_NAME: 从 PROJECT_ID 构建（格式：neo4j-{project_id}）
    if [[ -z "${SERVICE_NAME:-}" ]]; then
        SERVICE_NAME="neo4j-${NEO4J_PROJECT_ID}"
    fi
    
    # NAMESPACE: 从主配置获取
    NAMESPACE="${NEO4J_NAMESPACE:-data-platform-dev}"
    
    # NEO4J_PORT: 从 Kubernetes Service 动态获取（Neo4j Browser 端口 7474）
    if [[ -z "${NEO4J_PORT:-}" ]]; then
        NEO4J_PORT=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -z "$NEO4J_PORT" ]]; then
            log_warn "⚠️ 无法从 Service 获取端口，使用默认值 7474"
            NEO4J_PORT="7474"
        fi
    fi
    
    # UNIFIED_HOST: 从主配置的统一域名获取
    UNIFIED_HOST="${NEO4J_UNIFIED_HOST:-llmops.sunmoonai.com}"
    
    # 固定配置（不需要动态获取）
    APP_LABEL="data-platform-ingress"
    COMPONENT_LABEL="neo4j-web"
    
    log_success "✅ 配置加载成功"
    log_info "服务名称: $SERVICE_NAME"
    log_info "命名空间: $NAMESPACE"
    log_info "服务端口: $NEO4J_PORT"
    log_info "统一域名: $UNIFIED_HOST"
}

# 部署 Neo4j Web 路由
deploy_neo4j_web() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "部署 Neo4j Web 路由..."
    log_info "命名空间: $namespace"
    
    # 加载配置
    load_config

    # 检查配置文件是否存在
    if [[ ! -f "$NEO4J_WEB_FILE" ]]; then
        log_error "Neo4j Web 路由配置文件不存在: $NEO4J_WEB_FILE"
        return 1
    fi
    
    # 生成临时文件并动态替换占位符
    local tmp
    tmp=$(mktemp)
    cp "$NEO4J_WEB_FILE" "$tmp"

    # 使用 sed 替换占位符
    sed -i "s|{{NAMESPACE}}|$NAMESPACE|g" "$tmp"
    sed -i "s|{{SERVICE_NAME}}|$SERVICE_NAME|g" "$tmp"
    sed -i "s|{{SERVICE_PORT}}|$NEO4J_PORT|g" "$tmp"
    sed -i "s|{{UNIFIED_HOST}}|$UNIFIED_HOST|g" "$tmp"

    # 应用 Web 路由配置
    log_info "应用 Neo4j Web 路由配置..."
    if kubectl apply -f "$tmp" -n "$namespace"; then
        log_success "✅ Neo4j Web 路由配置应用成功"
        rm -f "$tmp"
    else
        log_error "❌ Neo4j Web 路由配置应用失败"
        rm -f "$tmp"
        return 1
    fi
    
    # 检查路由状态
    log_info "检查 Neo4j Web 路由状态..."
    kubectl get ingressroute -n "$namespace" neo4j-web-route
    
    log_success "✅ Neo4j Web 路由部署完成！"
    return 0
}

# 删除 Neo4j Web 路由
delete_neo4j_web() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "删除 Neo4j Web 路由..."
    log_info "命名空间: $namespace"
    
    if kubectl delete -f "$NEO4J_WEB_FILE" 2>/dev/null; then
        log_success "✅ Neo4j Web 路由配置删除成功"
    else
        log_warn "⚠️ Neo4j Web 路由配置不存在或删除失败"
    fi
    
    log_success "✅ Neo4j Web 路由删除完成！"
    return 0
}

# 检查路由状态
check_web_status() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "检查 Neo4j Web 路由状态..."
    
    # 检查路由是否存在
    if kubectl get ingressroute -n "$namespace" neo4j-web-route >/dev/null 2>&1; then
        log_success "✅ Neo4j Web 路由存在"
        kubectl get ingressroute -n "$namespace" neo4j-web-route
    else
        log_error "❌ Neo4j Web 路由不存在"
        return 1
    fi
}

# 主函数
main() {
    local action="${1:-deploy}"
    local namespace="${2:-data-platform-dev}"
    
    # 建立远程 k8s 连接
    setup_kubectl_environment
    
    case "$action" in
        "deploy")
            deploy_neo4j_web "$namespace"
            ;;
        "uninstall")
            delete_neo4j_web "$namespace"
            ;;
        "status")
            check_web_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Neo4j Web 路由（默认）"
            echo "  uninstall        删除 Neo4j Web 路由"
            echo "  status           检查路由状态"
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
