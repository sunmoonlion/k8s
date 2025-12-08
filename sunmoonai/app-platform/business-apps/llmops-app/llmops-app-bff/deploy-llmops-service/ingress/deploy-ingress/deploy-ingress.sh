#!/bin/bash

# LLMOps Service HTTPS 路由部署脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
# 从 deploy-ingress/ -> ingress/ -> deploy-llmops-service/ -> llmops-service/ -> app-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../.." && pwd)"

# 导入统一部署模板（建立远程 k8s 连接）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INGRESS_FILE="$(dirname "$SCRIPT_DIR")/ingress.yaml"
MIDDLEWARE_FILE="$(dirname "$SCRIPT_DIR")/middleware.yaml"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# 加载配置
load_config() {
    # 尝试加载主配置文件（如果存在），以获取 LLMOPS_SERVICE_EXTERNAL_HOST、LLMOPS_SERVICE_EXTERNAL_PORT 等环境变量
    # 主配置文件路径：../../deploy-llmops-service.conf（相对于当前脚本目录）
    local main_config_file="$(cd "$SCRIPT_DIR/../.." && pwd)/deploy-llmops-service.conf"
    if [[ -f "$main_config_file" ]]; then
        # 临时禁用错误退出，因为主配置文件可能包含一些在当前上下文中不适用的配置
        set +e
        source "$main_config_file" 2>/dev/null
        set -e
        log_info "已加载主配置文件: $main_config_file"
    fi
    
    # 从主配置文件构建配置
    SERVICE_NAME="llmops-service"
    NAMESPACE="${LLMOPS_SERVICE_NAMESPACE:-app-platform-dev}"
    
    # 外部访问配置
    LLMOPS_SERVICE_UNIFIED_HOST="${LLMOPS_SERVICE_UNIFIED_HOST:-llmops.sunmoonai.com}"
    LLMOPS_SERVICE_NODE_IP="${LLMOPS_SERVICE_NODE_IP:-101.126.151.0}"
    LLMOPS_SERVICE_EXTERNAL_PORT="${LLMOPS_SERVICE_EXTERNAL_PORT:-30443}"
    
    # 从 Service 中获取端口（如果 Service 存在）
    if type get_service_port >/dev/null 2>&1; then
        local service_port
        service_port=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -n "$service_port" ]]; then
            SERVICE_PORT="$service_port"
            log_info "从 Service 获取 LLMOps Service 端口: $SERVICE_PORT"
        else
            log_warn "⚠️  无法从 Service 获取端口，使用默认端口 80"
            SERVICE_PORT="80"
        fi
    else
        log_warn "⚠️  get_service_port 函数不可用，使用默认端口 80"
        SERVICE_PORT="80"
    fi
    
    log_success "✅ 配置加载成功"
}

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

# 验证 LLMOps Service 是否存在（警告模式，不阻止部署）
verify_llmops_service() {
    local namespace="$1"
    local warn_only="${2:-false}"  # 如果为 true，服务不存在时只警告，不失败
    
    if kubectl get service -n "$namespace" "$SERVICE_NAME" >/dev/null 2>&1; then
        log_success "✅ LLMOps Service 存在: $SERVICE_NAME"
        return 0
    else
        if [[ "$warn_only" == "true" ]]; then
            log_warning "⚠️ LLMOps Service 不存在: $SERVICE_NAME（将在服务部署后自动生效）"
            return 0  # 返回成功，允许继续部署
        else
            log_error "❌ LLMOps Service 不存在: $SERVICE_NAME"
            return 1
        fi
    fi
}

# 部署 LLMOps Service HTTPS 路由
deploy_http_route() {
    local namespace="${1:-app-platform-dev}"
    
    log_info "部署 LLMOps Service HTTPS 路由..."
    log_info "命名空间: $namespace"
    
    # 加载配置（确保 SERVICE_PORT 等变量被正确设置）
    load_config
    
    # 检查命名空间是否存在
    check_namespace "$namespace"
    
    # 验证 LLMOps Service 是否存在（警告模式：服务不存在时只警告，不阻止部署）
    # 注意：在递归部署架构中，Ingress 可能在服务部署之前部署，这是正常的
    # Ingress 会在服务创建后自动生效
    verify_llmops_service "$namespace" "true" || {
        log_warning "⚠️ LLMOps Service 尚未创建，Ingress 将在服务部署后自动生效"
    }
    
    if [[ ! -f "$INGRESS_FILE" ]]; then
        log_error "Ingress 配置文件不存在: $INGRESS_FILE"
        return 1
    fi
    
    if [[ ! -f "$MIDDLEWARE_FILE" ]]; then
        log_error "Middleware 配置文件不存在: $MIDDLEWARE_FILE"
        return 1
    fi
    
    log_info "使用服务名称: $SERVICE_NAME"
    log_info "外部访问地址: $LLMOPS_SERVICE_UNIFIED_HOST:$LLMOPS_SERVICE_EXTERNAL_PORT"
    
    # 先部署 Middleware
    log_info "部署 Middleware..."
    local temp_middleware_file
    temp_middleware_file=$(mktemp)
    cp "$MIDDLEWARE_FILE" "$temp_middleware_file"
    
    # 使用 sed 替换模板变量
    sed -i "s/{{NAMESPACE}}/$namespace/g" "$temp_middleware_file"
    
    if kubectl apply -f "$temp_middleware_file"; then
        log_success "✅ Middleware 配置应用成功"
        rm -f "$temp_middleware_file"
    else
        log_error "❌ Middleware 配置应用失败"
        rm -f "$temp_middleware_file"
        return 1
    fi
    
    # 部署 IngressRoute
    log_info "部署 IngressRoute..."
    local temp_ingress_file
    temp_ingress_file=$(mktemp)
    cp "$INGRESS_FILE" "$temp_ingress_file"
    
    # 使用 sed 替换模板变量（与 redisinsight 对齐）
    sed -i "s/{{NAMESPACE}}/$namespace/g" "$temp_ingress_file"
    sed -i "s/{{SERVICE_NAME}}/$SERVICE_NAME/g" "$temp_ingress_file"
    sed -i "s/{{SERVICE_PORT}}/$SERVICE_PORT/g" "$temp_ingress_file"
    sed -i "s/{{UNIFIED_HOST}}/$LLMOPS_SERVICE_UNIFIED_HOST/g" "$temp_ingress_file"
    sed -i "s/{{NODE_IP}}/$LLMOPS_SERVICE_NODE_IP/g" "$temp_ingress_file"
    
    if kubectl apply -f "$temp_ingress_file"; then
        log_success "✅ IngressRoute 配置应用成功"
        rm -f "$temp_ingress_file"
    else
        log_error "❌ IngressRoute 配置应用失败"
        rm -f "$temp_ingress_file"
        return 1
    fi
    
    # 检查路由状态
    log_info "检查 LLMOps Service HTTPS 路由状态..."
    kubectl get ingressroute -n "$namespace" llmops-service-ingress || true
    
    log_success "✅ LLMOps Service HTTPS 路由部署完成！"
    return 0
}

# 检查部署状态
check_deployment_status() {
    log_info "检查 LLMOps Service HTTPS 路由部署状态..."
    
    echo ""
    echo "=== LLMOps Service IngressRoute 状态 ==="
    kubectl get ingressroute -n "$NAMESPACE" -l component=llmops-service 2>/dev/null || echo "IngressRoute 不存在"
    
    echo ""
    echo "=== LLMOps Service Middleware 状态 ==="
    kubectl get middleware -n "$NAMESPACE" -l component=llmops-service 2>/dev/null || echo "Middleware 不存在"
    
    echo ""
    echo "=== LLMOps Service 状态 ==="
    kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "LLMOps Service 不存在"
    
    echo ""
    echo "=== 访问信息 ==="
    echo "LLMOps Service API 地址: https://$LLMOPS_SERVICE_UNIFIED_HOST/api/v1"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 通过统一域名访问:"
    echo "   https://$LLMOPS_SERVICE_UNIFIED_HOST/api/v1"
    echo ""
    echo "2. 或使用 IP 地址访问:"
    echo "   https://$LLMOPS_SERVICE_NODE_IP:30443/api/v1"
    echo ""
    echo "3. 或使用外部访问域名:"
    echo "   https://$LLMOPS_SERVICE_UNIFIED_HOST/api/v1"
}

# 删除 LLMOps Service HTTPS 路由
delete_http_route() {
    local namespace="${1:-app-platform-dev}"
    
    log_info "删除 LLMOps Service HTTPS 路由..."
    log_info "命名空间: $namespace"
    
    # 删除 IngressRoute
    if kubectl delete ingressroute -n "$namespace" llmops-service-ingress 2>/dev/null; then
        log_success "✅ IngressRoute 删除成功"
    else
        log_warn "⚠️ IngressRoute 不存在或删除失败"
    fi
    
    # 删除 Middleware（注意：如果其他 IngressRoute 也在使用这些 Middleware，删除可能会影响它们）
    # 这里只删除 llmops-service 相关的 Middleware
    for middleware_name in llmops-service-stripprefix llmops-service-auth llmops-service-rate-limit llmops-service-monitoring; do
        if kubectl delete middleware -n "$namespace" "$middleware_name" 2>/dev/null; then
            log_success "✅ Middleware $middleware_name 删除成功"
        else
            log_warn "⚠️ Middleware $middleware_name 不存在或删除失败"
        fi
    done
    
    log_success "✅ LLMOps Service HTTPS 路由删除完成！"
    return 0
}

# 显示帮助信息
show_help() {
    echo "LLMOps Service HTTPS 路由部署脚本"
    echo ""
    echo "用法: $0 [命令] [项目ID] [命名空间] [环境]"
    echo ""
    echo "命令:"
    echo "  deploy <project_id> [namespace] [environment]    部署 LLMOps Service HTTPS 路由"
    echo "  uninstall <project_id> [namespace] [environment] 卸载 LLMOps Service HTTPS 路由"
    echo "  status    检查部署状态"
    echo "  help      显示帮助信息"
    echo ""
    echo "参数:"
    echo "  project_id   项目标识符 (必需)"
    echo "  namespace    命名空间 (默认: app-platform-dev)"
    echo "  environment  环境 (默认: development)"
    echo ""
    echo "示例:"
    echo "  $0 deploy sunmoonai app-platform-dev development  # 部署 LLMOps Service HTTPS 路由"
    echo "  $0 uninstall sunmoonai app-platform-dev development  # 卸载 LLMOps Service HTTPS 路由"
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
            
            log_info "开始部署 LLMOps Service HTTPS 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            
            load_config
            check_namespace "$NAMESPACE"
            # 注意：不在这里检查服务，因为 deploy_http_route 中已经使用警告模式检查
            # 在递归部署架构中，Ingress 可能在服务部署之前部署，这是正常的
            deploy_http_route "$namespace"
            check_deployment_status
            ;;
        uninstall)
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 uninstall <project_id> [namespace] [environment]"
                echo "示例: $0 uninstall sunmoonai app-platform-dev development"
                exit 1
            fi
            
            log_info "开始删除 LLMOps Service HTTPS 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            
            load_config
            delete_http_route "$namespace"
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

