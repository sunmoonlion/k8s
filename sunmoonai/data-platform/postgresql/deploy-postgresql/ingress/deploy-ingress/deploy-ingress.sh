#!/bin/bash

# PostgreSQL TCP 路由部署脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
# 从 deploy-ingress/ -> ingress/ -> deploy-postgresql/ -> postgresql/ -> data-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../.." && pwd)"

# 导入统一部署模板（建立远程 k8s 连接）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    local _ns_err
    _ns_err=$(kubectl get namespace "$namespace" 2>&1)
    if [[ $? -eq 0 ]]; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    elif echo "$_ns_err" | grep -qiE "not.?found|NotFound"; then
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
    else
        log_warn "kubectl 连接失败，尝试自动重连后重试（${_ns_err%%$'\n'*}）"
        if command -v setup_kubectl_environment >/dev/null 2>&1 && setup_kubectl_environment >/dev/null 2>&1; then
            if kubectl get namespace "$namespace" >/dev/null 2>&1; then
                log_success "✅ 重连后命名空间 $namespace 已存在"
                return 0
            fi
        fi
        log_error "❌ kubectl 连接失败，无法验证命名空间 $namespace（${_ns_err%%$'\n'*}）"
        log_error "请检查 KUBECONFIG 和集群连接状态"
        return 1
    fi
}

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POSTGRESQL_TCP_FILE="$(dirname "$SCRIPT_DIR")/ingress.yaml"


# 验证 PostgreSQL 服务是否存在（警告模式，不阻止部署）
verify_postgresql_service() {
    local namespace="$1"
    local warn_only="${2:-false}"  # 如果为 true，服务不存在时只警告，不失败
    
    if kubectl get service -n "$namespace" "$SERVICE_NAME" >/dev/null 2>&1; then
        log_success "✅ PostgreSQL 服务存在: $SERVICE_NAME"
        return 0
    else
        if [[ "$warn_only" == "true" ]]; then
            log_warning "⚠️ PostgreSQL 服务不存在: $SERVICE_NAME（将在服务部署后自动生效）"
            return 0  # 返回成功，允许继续部署
        else
            log_error "❌ PostgreSQL 服务不存在: $SERVICE_NAME"
            return 1
        fi
    fi
}

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
    # 尝试加载主配置文件（如果存在），以获取 POSTGRESQL_PROJECT_ID、POSTGRESQL_NAMESPACE 等环境变量
    # 主配置文件路径：../../deploy-postgresql.conf（相对于当前脚本目录）
    local main_config_file="$(cd "$SCRIPT_DIR/../.." && pwd)/deploy-postgresql.conf"
    if [[ -f "$main_config_file" ]]; then
        # 临时禁用错误退出，因为主配置文件可能包含一些在当前上下文中不适用的配置
        set +e
        source "$main_config_file" 2>/dev/null
        set -e
        log_info "已加载主配置文件: $main_config_file"
    fi
    
    # 从主配置文件构建配置（现在可以使用主配置文件中的环境变量）
    SERVICE_NAME="postgresql-${POSTGRESQL_PROJECT_ID:-sunmoonai}"
    NAMESPACE="${POSTGRESQL_NAMESPACE:-data-platform-dev}"
    
    # 从 Service 中获取端口（如果 Service 存在）
    if type get_service_port >/dev/null 2>&1; then
        local service_port
        service_port=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -n "$service_port" ]]; then
            POSTGRESQL_PORT="$service_port"
            log_info "从 Service 获取 PostgreSQL 端口: $POSTGRESQL_PORT"
        else
            log_warn "⚠️  无法从 Service 获取端口，使用默认端口 5432"
            POSTGRESQL_PORT="5432"
        fi
    else
        log_warn "⚠️  get_service_port 函数不可用，使用默认端口 5432"
        POSTGRESQL_PORT="5432"
    fi
    
    # 如果 POSTGRESQL_EXTERNAL_PORT 未设置，从 Traefik Service 中动态获取
    if [[ -z "${POSTGRESQL_EXTERNAL_PORT:-}" ]]; then
        if type get_postgresql_external_port >/dev/null 2>&1; then
            POSTGRESQL_EXTERNAL_PORT=$(get_postgresql_external_port)
            log_info "从 Traefik Service 获取 PostgreSQL 外部端口: $POSTGRESQL_EXTERNAL_PORT"
        else
            log_warn "⚠️  get_postgresql_external_port 函数不可用，使用默认端口 30444"
            POSTGRESQL_EXTERNAL_PORT="30444"
        fi
    fi
    
    # 统一使用 POSTGRESQL_EXTERNAL_HOST（从主配置文件继承）
    if [[ -z "${HOST:-}" ]]; then
        HOST="${POSTGRESQL_EXTERNAL_HOST:-www.sunmoonai.com}"
    fi
    
    log_success "✅ 配置加载成功"
}

# 检查 PostgreSQL 服务是否存在
check_postgresql_service() {
    if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_error "❌ PostgreSQL 服务不存在: $SERVICE_NAME"
        echo ""
        log_info "请先部署 PostgreSQL 服务："
        echo "  cd ../../../../../../../data-platform/postgresql/deploy-postgresql"
        echo "  ./deploy-postgresql.sh deploy sunmoonai data-platform-dev development false"
        echo ""
        return 1
    fi
    
    log_success "✅ PostgreSQL 服务检查通过: $SERVICE_NAME"
    return 0
}

# 部署 PostgreSQL TCP 路由
deploy_tcp_route() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "部署 PostgreSQL TCP 路由..."
    log_info "命名空间: $namespace"
    
    # 检查命名空间是否存在
    check_namespace "$namespace"
    
    # 从主配置文件构建配置
    SERVICE_NAME="postgresql-${POSTGRESQL_PROJECT_ID:-sunmoonai}"
    NAMESPACE="${POSTGRESQL_NAMESPACE:-data-platform-dev}"
    
    # 从 Service 中获取端口（如果 Service 存在）
    if type get_service_port >/dev/null 2>&1; then
        local service_port
        service_port=$(get_service_port "$SERVICE_NAME" "$namespace")
        if [[ -n "$service_port" ]]; then
            POSTGRESQL_PORT="$service_port"
            log_info "从 Service 获取 PostgreSQL 端口: $POSTGRESQL_PORT"
        else
            log_warn "⚠️  无法从 Service 获取端口，使用默认端口 5432"
            POSTGRESQL_PORT="5432"
        fi
    else
        log_warn "⚠️  get_service_port 函数不可用，使用默认端口 5432"
        POSTGRESQL_PORT="5432"
    fi
    
    if [[ ! -f "$POSTGRESQL_TCP_FILE" ]]; then
        log_error "PostgreSQL TCP 配置文件不存在: $POSTGRESQL_TCP_FILE"
        return 1
    fi
    
    # 验证 PostgreSQL 服务是否存在（警告模式：服务不存在时只警告，不阻止部署）
    # 注意：在递归部署架构中，Ingress 可能在服务部署之前部署，这是正常的
    # Ingress 会在服务创建后自动生效
    verify_postgresql_service "$namespace" "true" || {
        log_warning "⚠️ PostgreSQL 服务尚未创建，Ingress 将在服务部署后自动生效"
    }
    
    log_info "使用服务名称: $SERVICE_NAME"
    log_info "PostgreSQL 端口: $POSTGRESQL_PORT"
    
    # 创建临时文件并替换服务名称和端口
    local temp_file
    temp_file=$(mktemp)
    cp "$POSTGRESQL_TCP_FILE" "$temp_file"
    
    # 使用 sed 替换模板变量
    # 注意：只替换 services[].name，不替换 metadata.name
    # 使用更精确的匹配模式，只替换 services 下的 name 和 port
    sed -i "s/name: {{SERVICE_NAME}}/name: $SERVICE_NAME/g" "$temp_file"
    sed -i "s/port: {{SERVICE_PORT}}/port: $POSTGRESQL_PORT/g" "$temp_file"
    sed -i "s/namespace: {{NAMESPACE}}/namespace: $namespace/g" "$temp_file"
    # 替换域名占位符
    local external_host="${POSTGRESQL_EXTERNAL_HOST:-www.sunmoonai.com}"
    sed -i "s/{{POSTGRESQL_EXTERNAL_HOST}}/$external_host/g" "$temp_file"
    # 兼容旧格式（如果配置文件中没有使用模板变量）
    sed -i "/services:/,/port:/ s/name: postgresql-sunmoonai/name: $SERVICE_NAME/g" "$temp_file"
    sed -i "/services:/,/name:/ s/port: 5432/port: $POSTGRESQL_PORT/g" "$temp_file"
    sed -i "/services:/,/name:/ s/port: {{POSTGRESQL_PORT}}/port: $POSTGRESQL_PORT/g" "$temp_file"
    
    # 应用 TCP 路由配置
    log_info "应用 PostgreSQL TCP 路由配置..."
    if kubectl apply -f "$temp_file"; then
        log_success "✅ PostgreSQL TCP 路由配置应用成功"
        rm -f "$temp_file"
    else
        log_error "❌ PostgreSQL TCP 路由配置应用失败"
        rm -f "$temp_file"
        return 1
    fi
    
    # 检查路由状态
    log_info "检查 PostgreSQL TCP 路由状态..."
    kubectl get ingressroutetcp -n "$namespace" postgresql-tcp
    
    log_success "✅ PostgreSQL TCP 路由部署完成！"
    return 0
}

# 检查部署状态
check_deployment_status() {
    log_info "检查 PostgreSQL TCP 路由部署状态..."
    
    echo ""
    echo "=== PostgreSQL TCP 路由状态 ==="
    kubectl get ingressroutetcp -n "$NAMESPACE" -l component=postgresql-tcp 2>/dev/null || echo "IngressRouteTCP 不存在"
    
    echo ""
    echo "=== PostgreSQL 服务状态 ==="
    kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "PostgreSQL 服务不存在"
    
    echo ""
    echo "=== 访问信息 ==="
    echo "PostgreSQL 数据库地址: ${HOST:-${POSTGRESQL_EXTERNAL_HOST:-www.sunmoonai.com}}:$POSTGRESQL_EXTERNAL_PORT"
    echo "PostgreSQL 内部端口: $POSTGRESQL_PORT"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 通过 psql 客户端连接:"
    echo "   psql -h ${HOST:-${POSTGRESQL_EXTERNAL_HOST:-www.sunmoonai.com}} -p $POSTGRESQL_EXTERNAL_PORT -U username -d database"
    echo ""
    echo "2. 在应用程序连接字符串中使用:"
    echo "   postgresql://${HOST:-${POSTGRESQL_EXTERNAL_HOST:-www.sunmoonai.com}}:$POSTGRESQL_EXTERNAL_PORT/database?user=username&password=password"
    echo ""
    echo "3. 注意：PostgreSQL Web UI 管理界面请通过 pgAdmin 访问："
    echo "   http://www.sunmoonai.com/pgadmin"
}

# 删除 PostgreSQL TCP 路由
delete_tcp_route() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "删除 PostgreSQL TCP 路由..."
    log_info "命名空间: $namespace"
    
    if kubectl delete -f "$POSTGRESQL_TCP_FILE" 2>/dev/null; then
        log_success "✅ PostgreSQL TCP 路由配置删除成功"
    else
        log_warn "⚠️ PostgreSQL TCP 路由配置不存在或删除失败"
    fi
    
    log_success "✅ PostgreSQL TCP 路由删除完成！"
    return 0
}

# 显示帮助信息
show_help() {
    echo "PostgreSQL TCP 路由部署脚本"
    echo ""
    echo "用法: $0 [命令] [项目ID] [命名空间] [环境]"
    echo ""
    echo "命令:"
    echo "  deploy <project_id> [namespace] [environment]    部署 PostgreSQL TCP 路由"
    echo "  uninstall <project_id> [namespace] [environment] 卸载 PostgreSQL TCP 路由"
    echo "  status    检查部署状态"
    echo "  help      显示帮助信息"
    echo ""
    echo "参数:"
    echo "  project_id   项目标识符 (必需)"
    echo "  namespace    命名空间 (默认: data-platform-dev)"
    echo "  environment  环境 (默认: development)"
    echo ""
    echo "示例:"
    echo "  $0 deploy sunmoonai data-platform-dev development  # 部署 PostgreSQL TCP 路由"
    echo "  $0 uninstall sunmoonai data-platform-dev development  # 卸载 PostgreSQL TCP 路由"
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
            
            log_info "开始部署 PostgreSQL TCP 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            
            load_config
            check_namespace "$NAMESPACE"
            # 注意：不在这里检查服务，因为 deploy_tcp_route 中已经使用警告模式检查
            # 在递归部署架构中，Ingress 可能在服务部署之前部署，这是正常的
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
            
            log_info "开始删除 PostgreSQL TCP 路由..."
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
