#!/bin/bash

# Mongo Express Web 路由部署脚本

set -e

# 导入统一部署模板（建立远程 k8s 连接）
source "$(dirname "$0")/../../../../../../utils/unified-deployment-template.sh"

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
MONGO_EXPRESS_INGRESS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONGO_EXPRESS_INGRESS_FILE="$(dirname "$SCRIPT_DIR")/ingress.yaml"
# 主配置文件路径（相对于脚本目录）
# 脚本位置: deploy-mongo-express/ingress/deploy-ingress/deploy-ingress.sh
# 配置文件位置: deploy-mongo-express/deploy-mongo-express.conf
# 从 deploy-ingress/ 目录向上2级到 deploy-mongo-express/ 目录
MONGO_EXPRESS_MAIN_CONFIG_FILE="$(dirname "$(dirname "$SCRIPT_DIR")")/deploy-mongo-express.conf"

# 验证 Mongo Express 服务是否存在
verify_mongo_express_service() {
    local namespace="$1"
    
    if kubectl get service -n "$namespace" "$SERVICE_NAME" >/dev/null 2>&1; then
        log_success "✅ Mongo Express 服务存在: $SERVICE_NAME"
        return 0
    else
        log_error "❌ Mongo Express 服务不存在: $SERVICE_NAME"
        return 1
    fi
}

# 加载配置
load_config() {
    if [[ ! -f "$MONGO_EXPRESS_MAIN_CONFIG_FILE" ]]; then
        log_error "主配置文件不存在: $MONGO_EXPRESS_MAIN_CONFIG_FILE"
        exit 1
    fi
    
    # 加载主配置
    source "$MONGO_EXPRESS_MAIN_CONFIG_FILE"
    
    # 动态获取配置值
    # SERVICE_NAME: 从 PROJECT_ID 构建（格式：mongo-express-{project_id}）
    if [[ -z "${SERVICE_NAME:-}" ]]; then
        SERVICE_NAME="mongo-express-${MONGO_EXPRESS_PROJECT_ID}"
    fi
    
    # NAMESPACE: 从主配置获取
    NAMESPACE="${MONGO_EXPRESS_NAMESPACE:-ops-platform-dev}"
    
    # MONGO_EXPRESS_PORT: 从 Kubernetes Service 动态获取
    if [[ -z "${MONGO_EXPRESS_PORT:-}" ]]; then
        MONGO_EXPRESS_PORT=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -z "$MONGO_EXPRESS_PORT" ]]; then
            log_warn "⚠️ 无法从 Service 获取端口，使用默认值 8081"
            MONGO_EXPRESS_PORT="8081"
        fi
    fi
    
    # UNIFIED_HOST: 从主配置的统一域名获取
    UNIFIED_HOST="${MONGO_EXPRESS_UNIFIED_HOST:-www.sunmoonai.com}"
    
    # NODE_IP: 从主配置的节点 IP 获取
    NODE_IP="${MONGO_EXPRESS_NODE_IP:-115.190.153.150}"
    
    # 固定配置（不需要动态获取）
    MONGO_EXPRESS_ENTRY_POINT="web"
    APP_LABEL="ops-platform-ingress"
    COMPONENT_LABEL="mongo-express-web"
    
    log_success "✅ 配置加载成功"
    log_info "服务名称: $SERVICE_NAME"
    log_info "命名空间: $NAMESPACE"
    log_info "服务端口: $MONGO_EXPRESS_PORT"
    log_info "统一域名: $UNIFIED_HOST"
    log_info "节点 IP: $NODE_IP"
}

# 检查 Mongo Express 服务是否存在
check_mongo_express_service() {
    if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_error "❌ Mongo Express 服务不存在: $SERVICE_NAME"
        echo ""
        log_info "请先部署 Mongo Express 服务："
        echo "  cd ../../../../../../../ops-platform/mongo-express/deploy-mongo-express"
        echo "  ./deploy-mongo-express.sh deploy sunmoonai ops-platform-dev development false"
        echo ""
        return 1
    fi
    
    log_success "✅ Mongo Express 服务检查通过: $SERVICE_NAME"
    return 0
}

# 部署 Mongo Express Web 路由
deploy_web_route() {
    local namespace="${1:-ops-platform-dev}"
    
    log_info "部署 Mongo Express Web 路由..."
    log_info "命名空间: $namespace"
    
    # 检查命名空间是否存在
    check_namespace "$namespace"
    
    # 检查配置文件是否存在
    if [[ ! -f "$MONGO_EXPRESS_INGRESS_FILE" ]]; then
        log_error "Mongo Express Ingress 配置文件不存在: $MONGO_EXPRESS_INGRESS_FILE"
        return 1
    fi
    
    # 验证 Mongo Express 服务是否存在
    if ! verify_mongo_express_service "$namespace"; then
        return 1
    fi
    
    log_info "使用服务名称: $SERVICE_NAME"
    log_info "Mongo Express 端口: $MONGO_EXPRESS_PORT"
    log_info "统一域名: $UNIFIED_HOST"
    
    # 创建临时文件并替换服务名称和域名
    local temp_file
    temp_file=$(mktemp)
    cp "$MONGO_EXPRESS_INGRESS_FILE" "$temp_file"
    
    # 使用 sed 替换占位符
    sed -i "s|{{NAMESPACE}}|$NAMESPACE|g" "$temp_file"
    sed -i "s|{{SERVICE_NAME}}|$SERVICE_NAME|g" "$temp_file"
    sed -i "s|{{SERVICE_PORT}}|$MONGO_EXPRESS_PORT|g" "$temp_file"
    sed -i "s|{{UNIFIED_HOST}}|$UNIFIED_HOST|g" "$temp_file"
    sed -i "s|{{NODE_IP}}|$NODE_IP|g" "$temp_file"
    
    # 应用 Web 路由配置
    log_info "应用 Mongo Express Web 路由配置..."
    if kubectl apply -f "$temp_file"; then
        log_success "✅ Mongo Express Web 路由配置应用成功"
        rm -f "$temp_file"
    else
        log_error "❌ Mongo Express Web 路由配置应用失败"
        rm -f "$temp_file"
        return 1
    fi
    
    # 检查路由状态
    log_info "检查 Mongo Express Web 路由状态..."
    kubectl get ingressroute -n "$namespace" mongo-express-web-route
    
    log_success "✅ Mongo Express Web 路由部署完成！"
    return 0
}

# 检查部署状态
check_deployment_status() {
    log_info "检查 Mongo Express Web 路由部署状态..."
    
    echo ""
    echo "=== Mongo Express Web 路由状态 ==="
    kubectl get ingressroute -n "$NAMESPACE" -l component=mongo-express-web 2>/dev/null || echo "IngressRoute 不存在"
    
    echo ""
    echo "=== Mongo Express 服务状态 ==="
    kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "Mongo Express 服务不存在"
    
    echo ""
    echo "=== 访问信息 ==="
    echo "Mongo Express Web UI: https://$UNIFIED_HOST/mongo-express"
    echo ""
    echo "=== 使用说明 ==="
    echo "1. 在浏览器中访问:"
    echo "   https://$UNIFIED_HOST/mongo-express"
    echo ""
    echo "2. 注意：Mongo Express 用于管理 MongoDB 数据库"
    echo "   MongoDB TCP 连接地址: www.sunmoonai.com:30093"
}

# 删除 Mongo Express Web 路由
delete_web_route() {
    local namespace="${1:-ops-platform-dev}"
    
    log_info "删除 Mongo Express Web 路由..."
    log_info "命名空间: $namespace"
    
    if kubectl delete -f "$MONGO_EXPRESS_INGRESS_FILE" 2>/dev/null; then
        log_success "✅ Mongo Express Web 路由配置删除成功"
    else
        log_warn "⚠️ Mongo Express Web 路由配置不存在或删除失败"
    fi
    
    log_success "✅ Mongo Express Web 路由删除完成！"
    return 0
}

# 显示帮助信息
show_help() {
    echo "Mongo Express Web 路由部署脚本"
    echo ""
    echo "用法: $0 [命令] [项目ID] [命名空间] [环境]"
    echo ""
    echo "命令:"
    echo "  deploy <project_id> [namespace] [environment]    部署 Mongo Express Web 路由"
    echo "  uninstall <project_id> [namespace] [environment] 卸载 Mongo Express Web 路由"
    echo "  status    检查部署状态"
    echo "  help      显示帮助信息"
    echo ""
    echo "参数:"
    echo "  project_id   项目标识符 (必需)"
    echo "  namespace    命名空间 (默认: ops-platform-dev)"
    echo "  environment  环境 (默认: development)"
    echo ""
    echo "示例:"
    echo "  $0 deploy sunmoonai ops-platform-dev development  # 部署 Mongo Express Web 路由"
    echo "  $0 uninstall sunmoonai ops-platform-dev development  # 卸载 Mongo Express Web 路由"
    echo "  $0 status    # 检查状态"
}

# 主函数
main() {
    local action="${1:-help}"
    local project_id="${2:-}"
    local namespace="${3:-ops-platform-dev}"
    local environment="${4:-development}"
    
    # 先加载配置（在建立 Kubernetes 连接之前）
    if [[ "$action" == "deploy" ]] || [[ "$action" == "uninstall" ]]; then
        if [[ ! -f "$MONGO_EXPRESS_MAIN_CONFIG_FILE" ]]; then
            log_error "主配置文件不存在: $MONGO_EXPRESS_MAIN_CONFIG_FILE"
            log_info "当前脚本目录: $SCRIPT_DIR"
            log_info "期望配置文件路径: $MONGO_EXPRESS_MAIN_CONFIG_FILE"
            exit 1
        fi
        load_config
    fi
    
    # 建立 Kubernetes 连接
    setup_kubectl_environment
    
    case "$action" in
        deploy)
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 deploy <project_id> [namespace] [environment]"
                echo "示例: $0 deploy sunmoonai ops-platform-dev development"
                exit 1
            fi
            
            log_info "开始部署 Mongo Express Web 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            
            load_config
            check_namespace "$NAMESPACE"
            check_mongo_express_service
            deploy_web_route
            check_deployment_status
            ;;
        uninstall)
            if [[ -z "$project_id" ]]; then
                log_error "请提供项目ID"
                echo "用法: $0 uninstall <project_id> [namespace] [environment]"
                echo "示例: $0 uninstall sunmoonai ops-platform-dev development"
                exit 1
            fi
            
            log_info "开始删除 Mongo Express Web 路由..."
            log_info "项目: $project_id"
            log_info "命名空间: $namespace"
            log_info "环境: $environment"
            
            load_config
            delete_web_route
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

