#!/bin/bash

# Investment Web Frontend HTTP 路由部署脚本

set -e

# 脚本目录（保存原始值，因为 unified-deployment-template.sh 会覆盖 SCRIPT_DIR）
ORIGINAL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"

# 计算应用根目录和资源路径（在 source 之前计算，避免 SCRIPT_DIR 被覆盖）
# 从 deploy-ingress/ -> investment-web-frontend-ingress/ -> ingress/ -> deploy-investment-web-frontend/ -> investment-web-frontend/
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
source "$K8S_ROOT_DIR/utils/unified-deployment-template.sh"

# 恢复原始的 SCRIPT_DIR
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"

# Ingress 配置文件（使用生成的 YAML 文件）
INGRESS_FILE="${K8S_RESOURCE_DIR}/custom-values/ingress/investment-web-frontend-ingress/generate-ingress/investment-web-frontend-ingress-generated.yaml"

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
        return 1
    fi
}

# 验证 Investment Web Frontend 服务是否存在（警告模式）
verify_service() {
    local namespace="$1"
    local service_name="$2"
    local warn_only="${3:-false}"

    if kubectl get service -n "$namespace" "$service_name" >/dev/null 2>&1; then
        log_success "✅ Investment Web Frontend 服务存在: $service_name"
        return 0
    else
        if [[ "$warn_only" == "true" ]]; then
            log_warning "⚠️ Investment Web Frontend 服务不存在: $service_name（将在服务部署后自动生效）"
            return 0
        else
            log_error "❌ Investment Web Frontend 服务不存在: $service_name"
            return 1
        fi
    fi
}

# 加载配置
load_config() {
    local main_config_file="$(cd "$SCRIPT_DIR/../../../app/deploy-app" && pwd)/deploy-investment-web-frontend.conf"
    if [[ -f "$main_config_file" ]]; then
        set +e
        source "$main_config_file" 2>/dev/null
        set -e
        log_info "已加载主配置文件: $main_config_file"
    fi

    SERVICE_NAME="investment-web-frontend"
    NAMESPACE="${NAMESPACE:-${INVESTMENT_WEB_FRONTEND_NAMESPACE:-app-platform-dev}}"
    UNIFIED_HOST="${INVESTMENT_WEB_FRONTEND_UNIFIED_HOST:-}"
    NODE_IP="${INVESTMENT_WEB_FRONTEND_NODE_IP:-}"
    EXTERNAL_PORT="${INVESTMENT_WEB_FRONTEND_EXTERNAL_PORT:-}"

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

    log_info "部署 Investment Web Frontend HTTP 路由..."
    log_info "命名空间: $namespace"

    check_namespace "$namespace"

    SERVICE_NAME="investment-web-frontend"
    NAMESPACE="${INVESTMENT_WEB_FRONTEND_NAMESPACE:-}"
    UNIFIED_HOST="${INVESTMENT_WEB_FRONTEND_UNIFIED_HOST:-}"
    NODE_IP="${INVESTMENT_WEB_FRONTEND_NODE_IP:-}"

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

    if [[ ! -f "$INGRESS_FILE" ]]; then
        log_warn "生成的 Ingress YAML 文件不存在，自动运行生成脚本..."
        export NAMESPACE="${NAMESPACE:-}"
        export ENVIRONMENT="${ENVIRONMENT:-}"
        export ENV="${ENV:-}"

        local generate_script="$K8S_RESOURCE_DIR/custom-values/ingress/investment-web-frontend-ingress/generate-ingress/generate-ingress.sh"
        if [[ -f "$generate_script" ]]; then
            if bash "$generate_script"; then
                log_success "Ingress YAML 文件生成成功"
            else
                log_error "Ingress YAML 文件生成失败"
                return 1
            fi
        else
            log_error "生成脚本不存在: $generate_script"
            return 1
        fi
    fi

    if [[ ! -f "$INGRESS_FILE" ]]; then
        log_error "Ingress 配置文件不存在: $INGRESS_FILE"
        return 1
    fi

    verify_service "$namespace" "$SERVICE_NAME" "true" || {
        log_warning "⚠️ Investment Web Frontend 服务尚未创建，Ingress 将在服务部署后自动生效"
    }

    log_info "使用服务名称: $SERVICE_NAME"
    log_info "服务端口: $SERVICE_PORT"
    log_info "统一域名: $UNIFIED_HOST"
    log_info "节点 IP: $NODE_IP"
    log_info "使用生成的 Ingress YAML: $INGRESS_FILE"

    if kubectl apply -f "$INGRESS_FILE" -n "$namespace"; then
        log_success "✅ Investment Web Frontend HTTP 路由配置应用成功"
    else
        log_error "❌ Investment Web Frontend HTTP 路由配置应用失败"
        return 1
    fi

    log_info "检查 Investment Web Frontend HTTP 路由状态..."
    kubectl get ingressroute -n "$namespace" investment-web-frontend-ingress 2>/dev/null || log_warn "IngressRoute 尚未创建"
    kubectl get middleware -n "$namespace" investment-web-frontend-rate-limit 2>/dev/null || log_warn "Middleware 尚未创建"

    log_success "✅ Investment Web Frontend HTTP 路由部署完成！"
    return 0
}

# 检查部署状态
check_deployment_status() {
    log_info "检查 Investment Web Frontend HTTP 路由部署状态..."

    echo ""
    echo "=== Investment Web Frontend HTTP 路由状态 ==="
    kubectl get ingressroute -n "$NAMESPACE" -l component=investment-web-frontend 2>/dev/null || echo "IngressRoute 不存在"

    echo ""
    echo "=== Middleware 状态 ==="
    kubectl get middleware -n "$NAMESPACE" -l component=investment-web-frontend 2>/dev/null || echo "Middleware 不存在"

    echo ""
    echo "=== Investment Web Frontend 服务状态 ==="
    kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "Investment Web Frontend 服务不存在"
}

# 删除 HTTP 路由
delete_http_route() {
    local namespace="${1:-}"

    log_info "删除 Investment Web Frontend HTTP 路由..."
    log_info "命名空间: $namespace"

    if [[ ! -f "$INGRESS_FILE" ]]; then
        log_warn "Ingress 配置文件不存在: $INGRESS_FILE"
        return 0
    fi

    if kubectl delete -f "$INGRESS_FILE" -n "$namespace" 2>/dev/null; then
        log_success "✅ Investment Web Frontend HTTP 路由配置删除成功"
    else
        log_warn "⚠️ Investment Web Frontend HTTP 路由配置不存在或删除失败"
    fi
    log_success "✅ Investment Web Frontend HTTP 路由删除完成！"
    return 0
}

# 显示帮助信息
show_help() {
    echo "Investment Web Frontend HTTP 路由部署脚本"
    echo ""
    echo "用法: $0 [命令] [项目ID] [命名空间] [环境]"
    echo ""
    echo "命令:"
    echo "  deploy <project_id> [namespace] [environment]    部署 Investment Web Frontend HTTP 路由"
    echo "  uninstall <project_id> [namespace] [environment] 卸载 Investment Web Frontend HTTP 路由"
    echo "  status    检查部署状态"
    echo "  help      显示帮助信息"
}

# 主函数
main() {
    setup_kubectl_environment

    local action="${1:-help}"
    local project_id="${2:-}"
    local namespace="${3:-}"
    local environment="${4:-}"

    case "$action" in
        deploy)
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                exit 1
            fi

            log_info "开始部署 Investment Web Frontend HTTP 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"

            export NAMESPACE="$namespace"
            export ENVIRONMENT="$environment"

            load_config
            check_namespace "$NAMESPACE"
            deploy_http_route
            check_deployment_status
            ;;
        uninstall)
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                exit 1
            fi

            log_info "开始删除 Investment Web Frontend HTTP 路由..."

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
