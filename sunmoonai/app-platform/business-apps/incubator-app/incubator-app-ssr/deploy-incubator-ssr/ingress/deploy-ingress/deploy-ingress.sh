#!/bin/bash

# Incubator App SSR HTTP 路由部署脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
# 从 deploy-ingress/ -> ingress/ -> deploy-incubator-ssr/ -> incubator-app-ssr/ -> incubator-app/ -> business-apps/ -> app-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 导入统一部署模板（建立远程 k8s 连接）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    else
        log_error "❌ 命名空间 $namespace 不存在！"
        echo ""
        log_info "请先使用 namespace-platform 部署所需的命名空间："
        echo "  cd ../../../../../../../namespace-platform"
        echo "  ./scripts/deploy.sh --env dev"
        echo ""
        log_info "或者手动创建命名空间："
        echo "  kubectl create namespace $namespace"
        echo ""
        return 1
    fi
}

# Ingress 配置文件
INGRESS_FILE="$(dirname "$SCRIPT_DIR")/ingress.yaml"

# 验证 Incubator App SSR 服务是否存在（警告模式，不阻止部署）
verify_service() {
    local namespace="$1"
    local service_name="$2"
    local warn_only="${3:-false}"  # 如果为 true，服务不存在时只警告，不失败
    
    if kubectl get service -n "$namespace" "$service_name" >/dev/null 2>&1; then
        log_success "✅ Incubator App SSR 服务存在: $service_name"
        return 0
    else
        if [[ "$warn_only" == "true" ]]; then
            log_warning "⚠️ Incubator App SSR 服务不存在: $service_name（将在服务部署后自动生效）"
            return 0  # 返回成功，允许继续部署
        else
            log_error "❌ Incubator App SSR 服务不存在: $service_name"
            return 1
        fi
    fi
}

# 加载配置
load_config() {
    # 尝试加载主配置文件（如果存在），以获取 INCUBATOR_SSR_NAMESPACE、INCUBATOR_SSR_UNIFIED_HOST 等环境变量
    # 主配置文件路径：../../deploy-incubator-ssr.conf（相对于当前脚本目录）
    local main_config_file="$(cd "$SCRIPT_DIR/../.." && pwd)/deploy-incubator-ssr.conf"
    if [[ -f "$main_config_file" ]]; then
        # 临时禁用错误退出，因为主配置文件可能包含一些在当前上下文中不适用的配置
        set +e
        source "$main_config_file" 2>/dev/null
        set -e
        log_info "已加载主配置文件: $main_config_file"
    fi
    
    # 从主配置文件构建配置
    SERVICE_NAME="incubator-app-ssr"
    NAMESPACE="${INCUBATOR_SSR_NAMESPACE:-app-platform-dev}"
    UNIFIED_HOST="${INCUBATOR_SSR_UNIFIED_HOST:-incubator-ssr.sunmoonai.com}"
    NODE_IP="${INCUBATOR_SSR_NODE_IP:-101.126.151.0}"
    EXTERNAL_PORT="${INCUBATOR_SSR_EXTERNAL_PORT:-30443}"
    
    # 从 Service 中获取端口（如果 Service 存在）
    if type get_service_port >/dev/null 2>&1; then
        local service_port
        service_port=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -n "$service_port" ]]; then
            SERVICE_PORT="$service_port"
            log_info "从 Service 获取端口: $SERVICE_PORT"
        else
            log_warn "⚠️  无法从 Service 获取端口，使用默认端口 3000"
            SERVICE_PORT="3000"
        fi
    else
        log_warn "⚠️  get_service_port 函数不可用，使用默认端口 3000"
        SERVICE_PORT="3000"
    fi
    
    log_success "✅ 配置加载成功"
}

# 部署 HTTP 路由
deploy_http_route() {
    local namespace="${1:-app-platform-dev}"
    
    log_info "部署 Incubator App SSR HTTP 路由..."
    log_info "命名空间: $namespace"
    
    # 检查命名空间是否存在
    check_namespace "$namespace"
    
    # 从主配置文件构建配置
    SERVICE_NAME="incubator-app-ssr"
    NAMESPACE="${INCUBATOR_SSR_NAMESPACE:-app-platform-dev}"
    UNIFIED_HOST="${INCUBATOR_SSR_UNIFIED_HOST:-incubator-ssr.sunmoonai.com}"
    NODE_IP="${INCUBATOR_SSR_NODE_IP:-101.126.151.0}"
    
    # 从 Service 中获取端口（如果 Service 存在）
    if type get_service_port >/dev/null 2>&1; then
        local service_port
        service_port=$(get_service_port "$SERVICE_NAME" "$namespace")
        if [[ -n "$service_port" ]]; then
            SERVICE_PORT="$service_port"
            log_info "从 Service 获取端口: $SERVICE_PORT"
        else
            log_warn "⚠️  无法从 Service 获取端口，使用默认端口 3000"
            SERVICE_PORT="3000"
        fi
    else
        log_warn "⚠️  get_service_port 函数不可用，使用默认端口 3000"
        SERVICE_PORT="3000"
    fi
    
    if [[ ! -f "$INGRESS_FILE" ]]; then
        log_error "Ingress 配置文件不存在: $INGRESS_FILE"
        return 1
    fi
    
    # 验证服务是否存在（警告模式：服务不存在时只警告，不阻止部署）
    # 注意：在递归部署架构中，Ingress 可能在服务部署之前部署，这是正常的
    # Ingress 会在服务创建后自动生效
    verify_service "$namespace" "$SERVICE_NAME" "true" || {
        log_warning "⚠️ Incubator App SSR 服务尚未创建，Ingress 将在服务部署后自动生效"
    }
    
    log_info "使用服务名称: $SERVICE_NAME"
    log_info "服务端口: $SERVICE_PORT"
    log_info "统一域名: $UNIFIED_HOST"
    log_info "节点 IP: $NODE_IP"
    
    # 创建临时文件并替换变量
    local temp_file
    temp_file=$(mktemp)
    cp "$INGRESS_FILE" "$temp_file"
    
    # 使用 sed 替换模板变量
    sed -i "s/{{NAMESPACE}}/$NAMESPACE/g" "$temp_file"
    sed -i "s/{{SERVICE_NAME}}/$SERVICE_NAME/g" "$temp_file"
    sed -i "s/{{SERVICE_PORT}}/$SERVICE_PORT/g" "$temp_file"
    sed -i "s/{{UNIFIED_HOST}}/$UNIFIED_HOST/g" "$temp_file"
    sed -i "s/{{NODE_IP}}/$NODE_IP/g" "$temp_file"
    
    # 应用 Ingress 配置（包括 Middleware 和 IngressRoute）
    log_info "应用 Incubator App SSR HTTP 路由配置..."
    if kubectl apply -f "$temp_file"; then
        log_success "✅ Incubator App SSR HTTP 路由配置应用成功"
        rm -f "$temp_file"
    else
        log_error "❌ Incubator App SSR HTTP 路由配置应用失败"
        rm -f "$temp_file"
        return 1
    fi
    
    # 检查路由状态
    log_info "检查 Incubator App SSR HTTP 路由状态..."
    kubectl get ingressroute -n "$namespace" incubator-app-ssr-ingress 2>/dev/null || log_warn "IngressRoute 尚未创建"
    kubectl get middleware -n "$namespace" incubator-app-ssr-headers 2>/dev/null || log_warn "Middleware 尚未创建"
    
    log_success "✅ Incubator App SSR HTTP 路由部署完成！"
    return 0
}

# 检查部署状态
check_deployment_status() {
    log_info "检查 Incubator App SSR HTTP 路由部署状态..."
    
    echo ""
    echo "=== Incubator App SSR HTTP 路由状态 ==="
    kubectl get ingressroute -n "$NAMESPACE" -l component=incubator-app-ssr 2>/dev/null || echo "IngressRoute 不存在"
    
    echo ""
    echo "=== Middleware 状态 ==="
    kubectl get middleware -n "$NAMESPACE" -l component=incubator-app-ssr 2>/dev/null || echo "Middleware 不存在"
    
    echo ""
    echo "=== Incubator App SSR 服务状态 ==="
    kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "Incubator App SSR 服务不存在"
    
    echo ""
    echo "=== 访问信息 ==="
    echo "统一域名访问: https://${UNIFIED_HOST}/"
    echo "节点 IP 访问: https://${NODE_IP}:${EXTERNAL_PORT}/"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 通过浏览器访问:"
    echo "   https://${UNIFIED_HOST}/"
    echo "   https://${NODE_IP}:${EXTERNAL_PORT}/"
    echo ""
    echo "2. 注意：需要在 /etc/hosts 中添加域名映射："
    echo "   ${NODE_IP}  ${UNIFIED_HOST}"
}

# 删除 HTTP 路由
delete_http_route() {
    local namespace="${1:-app-platform-dev}"
    
    log_info "删除 Incubator App SSR HTTP 路由..."
    log_info "命名空间: $namespace"
    
    if [[ ! -f "$INGRESS_FILE" ]]; then
        log_warn "Ingress 配置文件不存在: $INGRESS_FILE"
        return 0
    fi
    
    # 创建临时文件并替换变量（用于删除）
    local temp_file
    temp_file=$(mktemp)
    cp "$INGRESS_FILE" "$temp_file"
    
    # 使用 sed 替换模板变量
    sed -i "s/{{NAMESPACE}}/$namespace/g" "$temp_file"
    sed -i "s/{{SERVICE_NAME}}/incubator-app-ssr/g" "$temp_file"
    sed -i "s/{{SERVICE_PORT}}/3000/g" "$temp_file"
    sed -i "s/{{UNIFIED_HOST}}/incubator-ssr.sunmoonai.com/g" "$temp_file"
    sed -i "s/{{NODE_IP}}/101.126.151.0/g" "$temp_file"
    
    if kubectl delete -f "$temp_file" 2>/dev/null; then
        log_success "✅ Incubator App SSR HTTP 路由配置删除成功"
    else
        log_warn "⚠️ Incubator App SSR HTTP 路由配置不存在或删除失败"
    fi
    
    rm -f "$temp_file"
    log_success "✅ Incubator App SSR HTTP 路由删除完成！"
    return 0
}

# 显示帮助信息
show_help() {
    echo "Incubator App SSR HTTP 路由部署脚本"
    echo ""
    echo "用法: $0 [命令] [项目ID] [命名空间] [环境]"
    echo ""
    echo "命令:"
    echo "  deploy <project_id> [namespace] [environment]    部署 Incubator App SSR HTTP 路由"
    echo "  uninstall <project_id> [namespace] [environment] 卸载 Incubator App SSR HTTP 路由"
    echo "  status    检查部署状态"
    echo "  help      显示帮助信息"
    echo ""
    echo "参数:"
    echo "  project_id   项目标识符 (必需)"
    echo "  namespace    命名空间 (默认: app-platform-dev)"
    echo "  environment  环境 (默认: development)"
    echo ""
    echo "示例:"
    echo "  $0 deploy sunmoonai app-platform-dev development  # 部署 HTTP 路由"
    echo "  $0 uninstall sunmoonai app-platform-dev development  # 卸载 HTTP 路由"
    echo "  $0 status    # 检查状态"
}

# 主函数
main() {
    # 建立 Kubernetes 连接
    setup_kubectl_environment
    
    local action="${1:-help}"
    local project_id="${2:-}"
    local namespace="${3:-app-platform-dev}"
    local environment="${4:-development}"
    
    case "$action" in
        deploy)
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 deploy <project_id> [namespace] [environment]"
                echo "示例: $0 deploy sunmoonai app-platform-dev development"
                exit 1
            fi
            
            log_info "开始部署 Incubator App SSR HTTP 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            
            load_config
            check_namespace "$NAMESPACE"
            # 注意：不在这里检查服务，因为 deploy_http_route 中已经使用警告模式检查
            # 在递归部署架构中，Ingress 可能在服务部署之前部署，这是正常的
            deploy_http_route
            check_deployment_status
            ;;
        uninstall)
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 uninstall <project_id> [namespace] [environment]"
                echo "示例: $0 uninstall sunmoonai app-platform-dev development"
                exit 1
            fi
            
            log_info "开始删除 Incubator App SSR HTTP 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            
            load_config
            delete_http_route
            ;;
        status)
            load_config
            check_deployment_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
