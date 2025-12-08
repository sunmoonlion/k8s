#!/bin/bash

# MongoDB TCP 路由部署脚本

set -e

# 脚本目录（保存为变量，防止被统一部署模板覆盖）
MONGODB_INGRESS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
# 从 deploy-ingress/ -> ingress/ -> deploy-mongodb/ -> mongodb/ -> data-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$MONGODB_INGRESS_SCRIPT_DIR/../../../../../.." && pwd)"

# 导入统一部署模板（建立远程 k8s 连接，可能会覆盖 SCRIPT_DIR）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 使用保存的脚本目录（统一部署模板可能会覆盖 SCRIPT_DIR）
SCRIPT_DIR="$MONGODB_INGRESS_SCRIPT_DIR"

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

# Ingress YAML 文件路径
MONGODB_TCP_FILE="$(dirname "$MONGODB_INGRESS_SCRIPT_DIR")/ingress.yaml"

# 验证 MongoDB 服务是否存在
verify_mongodb_service() {
    local namespace="$1"
    local warn_only="${2:-false}"  # 如果为 true，服务不存在时只警告，不失败
    
    if kubectl get service -n "$namespace" "$SERVICE_NAME" >/dev/null 2>&1; then
        log_success "✅ MongoDB 服务存在: $SERVICE_NAME"
        return 0
    else
        if [[ "$warn_only" == "true" ]]; then
            log_warning "⚠️ MongoDB 服务不存在: $SERVICE_NAME（将在服务部署后自动生效）"
            return 0  # 返回成功，允许继续部署
        else
            log_error "❌ MongoDB 服务不存在: $SERVICE_NAME"
            return 1
        fi
    fi
}

# 加载配置
load_config() {
    # 尝试加载主配置文件（如果存在），以获取 MONGODB_PROJECT_ID、MONGODB_NAMESPACE 等环境变量
    # 主配置文件路径：../../deploy-mongodb.conf（相对于当前脚本目录）
    local main_config_file="$(cd "$SCRIPT_DIR/../.." && pwd)/deploy-mongodb.conf"
    if [[ -f "$main_config_file" ]]; then
        # 临时禁用错误退出，因为主配置文件可能包含一些在当前上下文中不适用的配置
        set +e
        source "$main_config_file" 2>/dev/null
        set -e
        log_info "已加载主配置文件: $main_config_file"
    fi
    
    # 从主配置文件构建配置（现在可以使用主配置文件中的环境变量）
    SERVICE_NAME="mongodb-${MONGODB_PROJECT_ID:-sunmoonai}"
    NAMESPACE="${MONGODB_NAMESPACE:-data-platform-dev}"
    
    # 从 Service 中获取端口（如果 Service 存在）
    if type get_service_port >/dev/null 2>&1; then
        local service_port
        service_port=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -n "$service_port" ]]; then
            MONGODB_PORT="$service_port"
            log_info "从 Service 获取 MongoDB 端口: $MONGODB_PORT"
        else
            log_warn "⚠️  无法从 Service 获取端口，使用默认端口 27017"
            MONGODB_PORT="27017"
        fi
    else
        log_warn "⚠️  get_service_port 函数不可用，使用默认端口 27017"
        MONGODB_PORT="27017"
    fi
    
    # 如果 MONGODB_EXTERNAL_PORT 未设置，从 Traefik Service 中动态获取
    if [[ -z "${MONGODB_EXTERNAL_PORT:-}" ]]; then
        if type get_mongodb_external_port >/dev/null 2>&1; then
            MONGODB_EXTERNAL_PORT=$(get_mongodb_external_port)
            log_info "从 Traefik Service 获取 MongoDB 外部端口: $MONGODB_EXTERNAL_PORT"
        else
            log_warn "⚠️  get_mongodb_external_port 函数不可用，使用默认端口 30445"
            MONGODB_EXTERNAL_PORT="30445"
        fi
    fi
    
    # 统一使用 MONGODB_EXTERNAL_HOST（从主配置文件继承）
    # 如果 ingress 配置文件中定义了 HOST，优先使用 HOST（向后兼容）
    # 否则使用主配置文件中的 MONGODB_EXTERNAL_HOST
    if [[ -z "${HOST:-}" ]]; then
        HOST="${MONGODB_EXTERNAL_HOST:-llmops.sunmoonai.com}"
    fi
    
    log_success "✅ 配置加载成功"
}

# 检查 MongoDB 服务是否存在
check_mongodb_service() {
    if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_error "❌ MongoDB 服务不存在: $SERVICE_NAME"
        echo ""
        log_info "请先部署 MongoDB 服务："
        echo "  cd ../../../../../../../data-platform/mongodb/deploy-mongodb"
        echo "  ./deploy-mongodb.sh deploy sunmoonai data-platform-dev development false"
        echo ""
        return 1
    fi
    
    log_success "✅ MongoDB 服务检查通过: $SERVICE_NAME"
    return 0
}

# 部署 MongoDB TCP 路由
deploy_tcp_route() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "部署 MongoDB TCP 路由..."
    log_info "命名空间: $namespace"
    
    # 检查命名空间是否存在
    check_namespace "$namespace"
    
    # 从主配置文件构建配置
    SERVICE_NAME="mongodb-${MONGODB_PROJECT_ID:-sunmoonai}"
    NAMESPACE="${MONGODB_NAMESPACE:-data-platform-dev}"
    
    # 从 Service 中获取端口（如果 Service 存在）
    if type get_service_port >/dev/null 2>&1; then
        local service_port
        service_port=$(get_service_port "$SERVICE_NAME" "$namespace")
        if [[ -n "$service_port" ]]; then
            MONGODB_PORT="$service_port"
            log_info "从 Service 获取 MongoDB 端口: $MONGODB_PORT"
        else
            log_warn "⚠️  无法从 Service 获取端口，使用默认端口 27017"
            MONGODB_PORT="27017"
        fi
    else
        log_warn "⚠️  get_service_port 函数不可用，使用默认端口 27017"
        MONGODB_PORT="27017"
    fi
    
    if [[ ! -f "$MONGODB_TCP_FILE" ]]; then
        log_error "MongoDB TCP 配置文件不存在: $MONGODB_TCP_FILE"
        return 1
    fi
    
    # 验证 MongoDB 服务是否存在（警告模式：服务不存在时只警告，不阻止部署）
    # 注意：在递归部署架构中，Ingress 可能在服务部署之前部署，这是正常的
    # Ingress 会在服务创建后自动生效
    verify_mongodb_service "$namespace" "true" || {
        log_warning "⚠️ MongoDB 服务尚未创建，Ingress 将在服务部署后自动生效"
    }
    
    log_info "使用服务名称: $SERVICE_NAME"
    log_info "MongoDB 端口: $MONGODB_PORT"
    
    # 创建临时文件并替换服务名称和端口
    local temp_file
    temp_file=$(mktemp)
    cp "$MONGODB_TCP_FILE" "$temp_file"
    
    # 使用 sed 替换服务名称、端口、命名空间和域名
    sed -i "s/name: {{SERVICE_NAME}}/name: $SERVICE_NAME/g" "$temp_file"
    sed -i "s/port: {{SERVICE_PORT}}/port: $MONGODB_PORT/g" "$temp_file"
    sed -i "s/namespace: {{NAMESPACE}}/namespace: $namespace/g" "$temp_file"
    # 替换域名占位符
    local external_host="${MONGODB_EXTERNAL_HOST:-llmops.sunmoonai.com}"
    sed -i "s/{{MONGODB_EXTERNAL_HOST}}/$external_host/g" "$temp_file"
    # 兼容旧格式（如果配置文件中没有使用模板变量）
    sed -i "/services:/,/port:/ s/name: mongodb-sunmoonai/name: $SERVICE_NAME/g" "$temp_file"
    sed -i "/services:/,/name:/ s/port: 27017/port: $MONGODB_PORT/g" "$temp_file"
    sed -i "/services:/,/name:/ s/port: {{MONGODB_PORT}}/port: $MONGODB_PORT/g" "$temp_file"
    
    # 应用 TCP 路由配置
    log_info "应用 MongoDB TCP 路由配置..."
    if kubectl apply -f "$temp_file"; then
        log_success "✅ MongoDB TCP 路由配置应用成功"
        rm -f "$temp_file"
    else
        log_error "❌ MongoDB TCP 路由配置应用失败"
        rm -f "$temp_file"
        return 1
    fi
    
    # 检查路由状态
    log_info "检查 MongoDB TCP 路由状态..."
    kubectl get ingressroutetcp -n "$namespace" mongodb-tcp
    
    log_success "✅ MongoDB TCP 路由部署完成！"
    return 0
}

# 检查部署状态
check_deployment_status() {
    log_info "检查 MongoDB TCP 路由部署状态..."
    
    echo ""
    echo "=== MongoDB TCP 路由状态 ==="
    kubectl get ingressroutetcp -n "$NAMESPACE" -l component=mongodb-tcp 2>/dev/null || echo "IngressRouteTCP 不存在"
    
    echo ""
    echo "=== MongoDB 服务状态 ==="
    kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "MongoDB 服务不存在"
    
    echo ""
    echo "=== 访问信息 ==="
    echo "MongoDB 数据库地址: ${HOST:-${MONGODB_EXTERNAL_HOST:-llmops.sunmoonai.com}}:$MONGODB_EXTERNAL_PORT"
    echo "MongoDB 内部端口: $MONGODB_PORT"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 通过 mongosh 客户端连接:"
    echo "   mongosh mongodb://${HOST:-${MONGODB_EXTERNAL_HOST:-llmops.sunmoonai.com}}:$MONGODB_EXTERNAL_PORT/database"
    echo ""
    echo "2. 在应用程序连接字符串中使用:"
    echo "   mongodb://${HOST:-${MONGODB_EXTERNAL_HOST:-llmops.sunmoonai.com}}:$MONGODB_EXTERNAL_PORT/database"
    echo ""
    echo "3. 注意：MongoDB Web UI 管理界面请通过 Mongo Express 访问："
    echo "   http://llmops.sunmoonai.com/mongo-express"
}

# 删除 MongoDB TCP 路由
delete_tcp_route() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "删除 MongoDB TCP 路由..."
    log_info "命名空间: $namespace"
    
    if kubectl delete -f "$MONGODB_TCP_FILE" 2>/dev/null; then
        log_success "✅ MongoDB TCP 路由配置删除成功"
    else
        log_warn "⚠️ MongoDB TCP 路由配置不存在或删除失败"
    fi
    
    log_success "✅ MongoDB TCP 路由删除完成！"
    return 0
}

# 显示帮助信息
show_help() {
    echo "MongoDB TCP 路由部署脚本"
    echo ""
    echo "用法: $0 [命令] [项目ID] [命名空间] [环境]"
    echo ""
    echo "命令:"
    echo "  deploy <project_id> [namespace] [environment]    部署 MongoDB TCP 路由"
    echo "  uninstall <project_id> [namespace] [environment] 卸载 MongoDB TCP 路由"
    echo "  status    检查部署状态"
    echo "  help      显示帮助信息"
    echo ""
    echo "参数:"
    echo "  project_id   项目标识符 (必需)"
    echo "  namespace    命名空间 (默认: data-platform-dev)"
    echo "  environment  环境 (默认: development)"
    echo ""
    echo "示例:"
    echo "  $0 deploy sunmoonai data-platform-dev development  # 部署 MongoDB TCP 路由"
    echo "  $0 uninstall sunmoonai data-platform-dev development  # 卸载 MongoDB TCP 路由"
    echo "  $0 status    # 检查状态"
}

# 主函数
main() {
    # 建立 Kubernetes 连接
    setup_kubectl_environment
    
    local action="${1:-help}"
    local project_id="${2:-}"
    local namespace="${3:-data-platform-dev}"
    local environment="${4:-development}"
    
    case "$action" in
        deploy)
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 deploy <project_id> [namespace] [environment]"
                echo "示例: $0 deploy sunmoonai data-platform-dev development"
                exit 1
            fi
            
            log_info "开始部署 MongoDB TCP 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            
            load_config
            check_namespace "$NAMESPACE"
            # 使用警告模式检查 MongoDB 服务（允许服务不存在时继续部署）
            # 注意：在递归部署架构中，Ingress 可能在服务部署之前部署，这是正常的
            verify_mongodb_service "$NAMESPACE" "true" || {
                log_warning "⚠️ MongoDB 服务尚未创建，Ingress 将在服务部署后自动生效"
            }
            deploy_tcp_route
            check_deployment_status
            ;;
        uninstall)
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 uninstall <project_id> [namespace] [environment]"
                echo "示例: $0 uninstall sunmoonai data-platform-dev development"
                exit 1
            fi
            
            log_info "开始删除 MongoDB TCP 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            
            load_config
            delete_tcp_route
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

