#!/bin/bash

# Redis TCP 路由部署脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 保存原始的脚本目录（unified-deployment-template.sh 会重新定义 SCRIPT_DIR）
REDIS_INGRESS_SCRIPT_DIR="$SCRIPT_DIR"

# 计算项目根目录（k8s目录）
# 从 deploy-ingress/ -> ingress/ -> deploy-redis/ -> redis/ -> data-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../.." && pwd)"

# 导入统一部署模板（建立远程 k8s 连接）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 恢复原始的脚本目录（unified-deployment-template.sh 会重新定义 SCRIPT_DIR）
SCRIPT_DIR="$REDIS_INGRESS_SCRIPT_DIR"

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

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

REDIS_TCP_FILE="$(dirname "$SCRIPT_DIR")/ingress.yaml"

# 验证 Redis 服务是否存在
verify_redis_service() {
    local namespace="$1"
    
    if kubectl get service -n "$namespace" "$SERVICE_NAME" >/dev/null 2>&1; then
        log_success "✅ Redis 服务存在: $SERVICE_NAME"
        return 0
    else
        log_warn "⚠️  Redis 服务不存在: $SERVICE_NAME"
        log_info "   这是正常情况：路由配置在服务部署之前执行（按部署优先级顺序）"
        log_info "   服务将在后续阶段部署，路由配置会在服务就绪后自动生效"
        return 0  # 改为返回 0，允许继续部署路由
    fi
}

# 加载配置
load_config() {
    # 尝试加载主配置文件（如果存在），以获取 REDIS_PROJECT_ID、REDIS_NAMESPACE 等环境变量
    # 主配置文件路径：../../deploy-redis.conf（相对于当前脚本目录）
    local main_config_file="$(cd "$SCRIPT_DIR/../.." && pwd)/deploy-redis.conf"
    if [[ -f "$main_config_file" ]]; then
        # 临时禁用错误退出，因为主配置文件可能包含一些在当前上下文中不适用的配置
        set +e
        source "$main_config_file" 2>/dev/null
        set -e
        log_info "已加载主配置文件: $main_config_file"
    fi
    
    # 从主配置文件构建配置（现在可以使用主配置文件中的环境变量）
    # Redis 服务名称格式：redis-{project_id}-master
    SERVICE_NAME="redis-${REDIS_PROJECT_ID:-sunmoonai}-master"
    NAMESPACE="${REDIS_NAMESPACE:-data-platform-dev}"
    
    # 从 Service 中获取端口（如果 Service 存在）
    if type get_service_port >/dev/null 2>&1; then
        local service_port
        service_port=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -n "$service_port" ]]; then
            REDIS_PORT="$service_port"
            log_info "从 Service 获取 Redis 端口: $REDIS_PORT"
        else
            log_warn "⚠️  无法从 Service 获取端口，使用默认端口 6379"
            REDIS_PORT="6379"
        fi
    else
        log_warn "⚠️  get_service_port 函数不可用，使用默认端口 6379"
        REDIS_PORT="6379"
    fi
    
    # 如果 REDIS_EXTERNAL_PORT 未设置，从 Traefik Service 中动态获取
    if [[ -z "${REDIS_EXTERNAL_PORT:-}" ]]; then
        if type get_redis_external_port >/dev/null 2>&1; then
            REDIS_EXTERNAL_PORT=$(get_redis_external_port)
            log_info "从 Traefik Service 获取 Redis 外部端口: $REDIS_EXTERNAL_PORT"
        else
            log_warn "⚠️  get_redis_external_port 函数不可用，使用默认端口 30446"
            REDIS_EXTERNAL_PORT="30446"
        fi
    fi
    
    # 统一使用 REDIS_EXTERNAL_HOST（从主配置文件继承）
    if [[ -z "${HOST:-}" ]]; then
        HOST="${REDIS_EXTERNAL_HOST:-www.sunmoonai.com}"
    fi
    
    log_success "✅ 配置加载成功"
}

# 检查 Redis 服务是否存在
check_redis_service() {
    if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_warn "⚠️  Redis 服务不存在: $SERVICE_NAME"
        log_info "   这是正常情况：路由配置在服务部署之前执行（按部署优先级顺序）"
        log_info "   服务将在后续阶段部署，路由配置会在服务就绪后自动生效"
        echo ""
        return 0  # 改为返回 0，允许继续执行
    fi
    
    log_success "✅ Redis 服务检查通过: $SERVICE_NAME"
    return 0
}

# 部署 Redis TCP 路由
deploy_tcp_route() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "部署 Redis TCP 路由..."
    log_info "命名空间: $namespace"
    
    # 检查命名空间是否存在
    check_namespace "$namespace"
    
    # 从主配置文件构建配置（如果尚未设置）
    # Redis 服务名称格式：redis-{project_id}-master
    if [[ -z "${SERVICE_NAME:-}" ]]; then
        SERVICE_NAME="redis-${REDIS_PROJECT_ID:-sunmoonai}-master"
    fi
    if [[ -z "${NAMESPACE:-}" ]]; then
        NAMESPACE="${REDIS_NAMESPACE:-data-platform-dev}"
    fi
    
    # 从 Service 中获取端口（如果 Service 存在且尚未设置）
    if [[ -z "${REDIS_PORT:-}" ]]; then
        if type get_service_port >/dev/null 2>&1; then
            local service_port
            service_port=$(get_service_port "$SERVICE_NAME" "$namespace")
            if [[ -n "$service_port" ]]; then
                REDIS_PORT="$service_port"
                log_info "从 Service 获取 Redis 端口: $REDIS_PORT"
            else
                log_warn "⚠️  无法从 Service 获取端口，使用默认端口 6379"
                REDIS_PORT="6379"
            fi
        else
            log_warn "⚠️  get_service_port 函数不可用，使用默认端口 6379"
            REDIS_PORT="6379"
        fi
    fi
    
    if [[ ! -f "$REDIS_TCP_FILE" ]]; then
        log_error "Redis TCP 配置文件不存在: $REDIS_TCP_FILE"
        return 1
    fi
    
    # 验证 Redis 服务是否存在
    if ! verify_redis_service "$namespace"; then
        return 1
    fi
    
    log_info "使用服务名称: $SERVICE_NAME"
    log_info "Redis 端口: $REDIS_PORT"
    
    # 创建临时文件并替换服务名称和端口
    local temp_file
    temp_file=$(mktemp)
    cp "$REDIS_TCP_FILE" "$temp_file"
    
    # 使用 sed 替换服务名称、端口、命名空间和域名
    sed -i "s/name: {{SERVICE_NAME}}/name: $SERVICE_NAME/g" "$temp_file"
    sed -i "s/port: {{SERVICE_PORT}}/port: $REDIS_PORT/g" "$temp_file"
    sed -i "s/namespace: {{NAMESPACE}}/namespace: $namespace/g" "$temp_file"
    # 替换域名占位符
    local external_host="${REDIS_EXTERNAL_HOST:-www.sunmoonai.com}"
    sed -i "s/{{REDIS_EXTERNAL_HOST}}/$external_host/g" "$temp_file"
    # 兼容旧格式（如果配置文件中没有使用模板变量）
    sed -i "/services:/,/port:/ s/name: redis-sunmoonai-master/name: $SERVICE_NAME/g" "$temp_file"
    sed -i "/services:/,/name:/ s/port: 6379/port: $REDIS_PORT/g" "$temp_file"
    sed -i "/services:/,/name:/ s/port: {{REDIS_PORT}}/port: $REDIS_PORT/g" "$temp_file"
    
    # 应用 TCP 路由配置
    log_info "应用 Redis TCP 路由配置..."
    if kubectl apply -f "$temp_file"; then
        log_success "✅ Redis TCP 路由配置应用成功"
        rm -f "$temp_file"
    else
        log_error "❌ Redis TCP 路由配置应用失败"
        rm -f "$temp_file"
        return 1
    fi
    
    # 检查路由状态
    log_info "检查 Redis TCP 路由状态..."
    kubectl get ingressroutetcp -n "$namespace" redis-tcp
    
    log_success "✅ Redis TCP 路由部署完成！"
    return 0
}

# 检查部署状态
check_deployment_status() {
    log_info "检查 Redis TCP 路由部署状态..."
    
    echo ""
    echo "=== Redis TCP 路由状态 ==="
    kubectl get ingressroutetcp -n "$NAMESPACE" -l component=redis-tcp 2>/dev/null || echo "IngressRouteTCP 不存在"
    
    echo ""
    echo "=== Redis 服务状态 ==="
    kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "Redis 服务不存在"
    
    echo ""
    echo "=== 访问信息 ==="
    echo "Redis 数据库地址: ${HOST:-${REDIS_EXTERNAL_HOST:-www.sunmoonai.com}}:$REDIS_EXTERNAL_PORT"
    echo "Redis 内部端口: $REDIS_PORT"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 通过 redis-cli 客户端连接:"
    echo "   redis-cli -h ${HOST:-${REDIS_EXTERNAL_HOST:-www.sunmoonai.com}} -p $REDIS_EXTERNAL_PORT"
    echo ""
    echo "2. 在应用程序连接字符串中使用:"
    echo "   redis://${HOST:-${REDIS_EXTERNAL_HOST:-www.sunmoonai.com}}:$REDIS_EXTERNAL_PORT/0"
    echo ""
    echo "3. 注意：Redis Web UI 管理界面请通过 RedisInsight 访问："
    echo "   http://www.sunmoonai.com/redisinsight"
}

# 删除 Redis TCP 路由
delete_tcp_route() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "删除 Redis TCP 路由..."
    log_info "命名空间: $namespace"
    
    if kubectl delete -f "$REDIS_TCP_FILE" 2>/dev/null; then
        log_success "✅ Redis TCP 路由配置删除成功"
    else
        log_warn "⚠️ Redis TCP 路由配置不存在或删除失败"
    fi
    
    log_success "✅ Redis TCP 路由删除完成！"
    return 0
}

# 显示帮助信息
show_help() {
    echo "Redis TCP 路由部署脚本"
    echo ""
    echo "用法: $0 [命令] [项目ID] [命名空间] [环境]"
    echo ""
    echo "命令:"
    echo "  deploy <project_id> [namespace] [environment]    部署 Redis TCP 路由"
    echo "  uninstall <project_id> [namespace] [environment] 卸载 Redis TCP 路由"
    echo "  status    检查部署状态"
    echo "  help      显示帮助信息"
    echo ""
    echo "参数:"
    echo "  project_id   项目标识符 (必需)"
    echo "  namespace    命名空间 (默认: data-platform-dev)"
    echo "  environment  环境 (默认: development)"
    echo ""
    echo "示例:"
    echo "  $0 deploy sunmoonai data-platform-dev development  # 部署 Redis TCP 路由"
    echo "  $0 uninstall sunmoonai data-platform-dev development  # 卸载 Redis TCP 路由"
    echo "  $0 status    # 检查状态"
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
            
            log_info "开始部署 Redis TCP 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            
            load_config
            check_namespace "$NAMESPACE"
            check_redis_service
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
            
            log_info "开始删除 Redis TCP 路由..."
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

