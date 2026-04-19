#!/bin/bash

# LLMOps App BFF HTTP 路由部署脚本

set -e

# 脚本目录（保存原始值，因为 unified-deployment-template.sh 会覆盖 SCRIPT_DIR）
ORIGINAL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"

# 计算应用根目录和资源路径（在 source 之前计算，避免 SCRIPT_DIR 被覆盖）
# 从 deploy-ingress/ -> llmops-backend-ingress/ -> ingress/ -> deploy-llmops-backend/ -> llmops-app-backend/
APP_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
RESOURCES_DIR="${APP_ROOT}/resources"
K8S_RESOURCE_DIR="${RESOURCES_DIR}/k8s-resource"

# 计算 k8s 根目录（向上搜索 utils/cluster-arg-parser.sh）
find_k8s_root_dir() {
    local search_dir="$1"
    while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir="$(dirname "$search_dir")"
    done
    return 1
}
K8S_ROOT_DIR="$(find_k8s_root_dir "$APP_ROOT")"
if [[ -z "${K8S_ROOT_DIR:-}" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），APP_ROOT=$APP_ROOT" 1>&2
    exit 1
fi

# 导入统一部署模板（建立远程 k8s 连接）
# 注意：unified-deployment-template.sh 会覆盖 SCRIPT_DIR，所以我们在 source 之前已经计算好路径
source "$K8S_ROOT_DIR/utils/unified-deployment-template.sh"

# 恢复原始的 SCRIPT_DIR（如果需要的话）
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"

# Ingress 配置文件（使用生成的 YAML 文件，由各组件自己的 generate-*.sh 生成）
INGRESS_FILE="${K8S_RESOURCE_DIR}/custom-values/ingress/llmops-backend-ingress/generate-ingress/llmops-app-backend-ingress-generated.yaml"

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

# 验证 LLMOps App BFF 是否存在（警告模式，不阻止部署）
verify_service() {
    local namespace="$1"
    local service_name="$2"
    local warn_only="${3:-false}"  # 如果为 true，服务不存在时只警告，不失败
    
    if kubectl get service -n "$namespace" "$service_name" >/dev/null 2>&1; then
        log_success "✅ LLMOps App BFF 存在: $service_name"
        return 0
    else
        if [[ "$warn_only" == "true" ]]; then
            log_warning "⚠️ LLMOps App BFF 不存在: $service_name（将在服务部署后自动生效）"
            return 0  # 返回成功，允许继续部署
        else
            log_error "❌ LLMOps App BFF 不存在: $service_name"
            return 1
        fi
    fi
}

# 加载配置
load_config() {
    # 尝试加载主配置文件（如果存在），以获取 LLMOPS_BFF_NAMESPACE、LLMOPS_BFF_UNIFIED_HOST 等环境变量
    # 主配置文件路径：从 deploy-ingress/ -> ingress/ -> deploy-llmops-backend/ -> app/deploy-app/
    local main_config_file="$(cd "$SCRIPT_DIR/../../../app/deploy-app" && pwd)/deploy-llmops-backend.conf"
    if [[ -f "$main_config_file" ]]; then
        # 临时禁用错误退出，因为主配置文件可能包含一些在当前上下文中不适用的配置
        set +e
        source "$main_config_file" 2>/dev/null
        set -e
        log_info "已加载主配置文件: $main_config_file"
    fi
    
    # 从主配置文件构建配置（所有默认值应在配置文件中定义）
    # 优先使用环境变量（从命令行参数传入），其次使用配置文件中的值
    SERVICE_NAME="llmops-app-backend"
    NAMESPACE="${NAMESPACE:-${LLMOPS_BFF_NAMESPACE:-app-platform-dev}}"
    UNIFIED_HOST="${LLMOPS_BFF_UNIFIED_HOST:-}"
    NODE_IP="${LLMOPS_BFF_NODE_IP:-}"
    EXTERNAL_PORT="${LLMOPS_BFF_EXTERNAL_PORT:-}"
    
    # 从 Service 中获取端口（如果 Service 存在）
    if type get_service_port >/dev/null 2>&1; then
        local service_port
        service_port=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -n "$service_port" ]]; then
            SERVICE_PORT="$service_port"
            log_info "从 Service 获取端口: $SERVICE_PORT"
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

# 部署 HTTP 路由
deploy_http_route() {
    local namespace="${1:-app-platform-dev}"
    
    log_info "部署 LLMOps App BFF HTTP 路由..."
    log_info "命名空间: $namespace"
    
    # 检查命名空间是否存在
    check_namespace "$namespace"
    
    # 从主配置文件构建配置
    SERVICE_NAME="llmops-app-backend"
    NAMESPACE="${LLMOPS_BFF_NAMESPACE:-app-platform-dev}"
    UNIFIED_HOST="${LLMOPS_BFF_UNIFIED_HOST:-www.sunmoonai.com}"
    NODE_IP="${LLMOPS_BFF_NODE_IP:-101.126.151.0}"
    
    # 从 Service 中获取端口（如果 Service 存在）
    if type get_service_port >/dev/null 2>&1; then
        local service_port
        service_port=$(get_service_port "$SERVICE_NAME" "$namespace")
        if [[ -n "$service_port" ]]; then
            SERVICE_PORT="$service_port"
            log_info "从 Service 获取端口: $SERVICE_PORT"
        else
            log_warn "⚠️  无法从 Service 获取端口，使用默认端口 80"
            SERVICE_PORT="80"
        fi
    else
        log_warn "⚠️  get_service_port 函数不可用，使用默认端口 80"
        SERVICE_PORT="80"
    fi
    
    # 自动生成 YAML 文件（总是重新生成，确保使用最新的模板）
    log_info "重新生成 Ingress YAML 文件（确保使用最新的模板）..."
    # 导出基础配置变量，供生成脚本使用（通过环境变量继承）
    export NAMESPACE="$namespace"
    export ENVIRONMENT="${ENVIRONMENT:-development}"
    export ENV="${ENV:-dev}"
    export PROJECT_ID="${PROJECT_ID:-sunmoonai}"
    
    local generate_script="$K8S_RESOURCE_DIR/custom-values/ingress/llmops-backend-ingress/generate-ingress/generate-ingress.sh"
    if [ -f "$generate_script" ]; then
        if bash "$generate_script"; then
            log_success "YAML 文件生成成功"
        else
            log_error "YAML 文件生成失败"
            return 1
        fi
    else
        log_error "生成脚本不存在: $generate_script"
        return 1
    fi
    
    if [[ ! -f "$INGRESS_FILE" ]]; then
        log_error "Ingress 配置文件不存在: $INGRESS_FILE"
        return 1
    fi
    
    # 验证服务是否存在（警告模式：服务不存在时只警告，不阻止部署）
    # 注意：在递归部署架构中，Ingress 可能在服务部署之前部署，这是正常的
    # Ingress 会在服务创建后自动生效
    verify_service "$namespace" "$SERVICE_NAME" "true" || {
        log_warning "⚠️ LLMOps App BFF 尚未创建，Ingress 将在服务部署后自动生效"
    }
    
    log_info "使用服务名称: $SERVICE_NAME"
    log_info "服务端口: $SERVICE_PORT"
    log_info "统一域名: $UNIFIED_HOST"
    log_info "节点 IP: $NODE_IP"
    log_info "使用生成的 Ingress YAML: $INGRESS_FILE"
    
    # 直接使用生成的 YAML 文件（已经包含所有变量替换）
    log_info "应用 LLMOps App BFF HTTP 路由配置..."
    if kubectl apply -f "$INGRESS_FILE" -n "$namespace"; then
        log_success "✅ LLMOps App BFF HTTP 路由配置应用成功"
    else
        log_error "❌ LLMOps App BFF HTTP 路由配置应用失败"
        return 1
    fi
    
    # 检查路由状态
    log_info "检查 LLMOps App BFF HTTP 路由状态..."
    kubectl get ingressroute -n "$namespace" llmops-app-backend-ingress 2>/dev/null || log_warn "IngressRoute 尚未创建"
    kubectl get middleware -n "$namespace" llmops-app-backend-stripprefix 2>/dev/null || log_warn "Middleware 尚未创建"
    
    log_success "✅ LLMOps App BFF HTTP 路由部署完成！"
    return 0
}

# 检查部署状态
check_deployment_status() {
    log_info "检查 LLMOps App BFF HTTP 路由部署状态..."
    
    echo ""
    echo "=== LLMOps App BFF HTTP 路由状态 ==="
    kubectl get ingressroute -n "$NAMESPACE" -l component=llmops-app-backend 2>/dev/null || echo "IngressRoute 不存在"
    
    echo ""
    echo "=== Middleware 状态 ==="
    kubectl get middleware -n "$NAMESPACE" -l component=llmops-app-backend 2>/dev/null || echo "Middleware 不存在"
    
    echo ""
    echo "=== LLMOps App BFF 服务状态 ==="
    kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "LLMOps App BFF 服务不存在"
    
    echo ""
    echo "=== 访问信息 ==="
    echo "统一域名访问: https://${UNIFIED_HOST}/api/v1"
    echo "节点 IP 访问: https://${NODE_IP}:${EXTERNAL_PORT}/api/v1"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 通过 curl 访问:"
    echo "   curl -k https://${UNIFIED_HOST}/api/v1/health"
    echo "   curl -k https://${NODE_IP}:${EXTERNAL_PORT}/api/v1/health"
    echo ""
    echo "2. 注意：需要在 /etc/hosts 中添加域名映射："
    echo "   ${NODE_IP}  ${UNIFIED_HOST}"
}

# 删除 HTTP 路由
delete_http_route() {
    local namespace="${1:-app-platform-dev}"
    
    log_info "删除 LLMOps App BFF HTTP 路由..."
    log_info "命名空间: $namespace"
    
    if [[ ! -f "$INGRESS_FILE" ]]; then
        log_warn "Ingress 配置文件不存在: $INGRESS_FILE"
        return 0
    fi
    
    # 直接使用生成的 YAML 文件删除
    if kubectl delete -f "$INGRESS_FILE" -n "$namespace" 2>/dev/null; then
        log_success "✅ LLMOps App BFF HTTP 路由配置删除成功"
    else
        log_warn "⚠️ LLMOps App BFF HTTP 路由配置不存在或删除失败"
    fi
    log_success "✅ LLMOps App BFF HTTP 路由删除完成！"
    return 0
}

# 显示帮助信息
show_help() {
    echo "LLMOps App BFF HTTP 路由部署脚本"
    echo ""
    echo "用法: $0 [命令] [项目ID] [命名空间] [环境]"
    echo ""
    echo "命令:"
    echo "  deploy <project_id> [namespace] [environment]    部署 LLMOps App BFF HTTP 路由"
    echo "  uninstall <project_id> [namespace] [environment] 卸载 LLMOps App BFF HTTP 路由"
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
            
            log_info "开始部署 LLMOps App BFF HTTP 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            
            # 导出命名空间和环境变量，供 load_config 使用
            export NAMESPACE="$namespace"
            export ENVIRONMENT="$environment"
            
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
            
            log_info "开始删除 LLMOps App BFF HTTP 路由..."
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
