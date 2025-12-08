#!/bin/bash

# LLMOps Service 部署脚本
# 用法: ./deploy-llmops-service.sh [deploy|undeploy|status] [env] [namespace]
# 注意: 镜像构建请使用 build/build-image.sh 脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 默认参数
ACTION="${1:-deploy}"
ENV="${2:-dev}"  # 环境：dev 或 prod
NAMESPACE="${3:-app-platform-${ENV}}"  # 根据环境自动设置命名空间

# 颜色定义（需要在日志函数之前定义）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数（需要在加载配置文件之前定义，以便在配置加载时使用）
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# 加载部署配置文件
LLMOPS_SERVICE_CONFIG_FILE="$SCRIPT_DIR/deploy-llmops-service.conf"
if [[ -f "$LLMOPS_SERVICE_CONFIG_FILE" ]]; then
    source "$LLMOPS_SERVICE_CONFIG_FILE"
    log_info "已加载 LLMOps Service 配置文件: $LLMOPS_SERVICE_CONFIG_FILE"
else
    log_warn "未找到 LLMOps Service 配置文件: $LLMOPS_SERVICE_CONFIG_FILE，使用默认配置"
fi

# 镜像配置（从部署配置文件读取，用于部署时指定镜像）
# 镜像名称和标签应该与 build/build.conf 中的配置保持一致
LLMOPS_SERVICE_IMAGE="${LLMOPS_SERVICE_IMAGE:-llmops-service}"
LLMOPS_SERVICE_TAG="${LLMOPS_SERVICE_TAG:-1.0.0}"

# 项目ID（从配置文件读取，如果未设置则使用默认值）
PROJECT_ID="${LLMOPS_SERVICE_PROJECT_ID:-${PROJECT_ID:-sunmoonai}}"

# 资源文件路径（对齐 PostgreSQL 结构，统一使用 llmops-service.yaml）
RESOURCES_DIR="../resources"
LLMOPS_SERVICE_YAML="${RESOURCES_DIR}/llmops-service.yaml"

# Secrets 和 ConfigMaps 路径（对齐项目架构，放在 deploy-llmops-service/secrets/ 下）
SECRETS_DIR="./secrets"
LLMOPS_SERVICE_CONFIGMAP="${SECRETS_DIR}/llmops-service-config/llmops-service-config.yaml"
LLMOPS_SERVICE_SECRET="${SECRETS_DIR}/llmops-service-secret/llmops-service-secret.yaml"
DEPLOY_SECRETS_ALL="${SECRETS_DIR}/deploy-secrets-all/deploy-secrets-all.sh"

# 检查 kubectl 是否可用
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在 PATH 中"
        exit 1
    fi
}

# 检查命名空间是否存在
check_namespace() {
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_success "命名空间 $NAMESPACE 已存在"
        return 0
    else
        log_error "命名空间 $NAMESPACE 不存在！"
        echo ""
        log_info "请先使用 namespace-platform 部署所需的命名空间："
        echo "  cd ../../namespace-platform"
        echo "  ./scripts/deploy.sh --env dev"
        echo ""
        log_info "或者手动创建命名空间："
        echo "  kubectl create namespace $NAMESPACE"
        echo ""
        exit 1
    fi
}

# 检查环境配置
check_env_config() {
    if [ ! -f "$LLMOPS_SERVICE_YAML" ]; then
        log_error "配置文件不存在: $LLMOPS_SERVICE_YAML"
        log_info "请确保资源文件存在: $RESOURCES_DIR/llmops-service.yaml"
        exit 1
    fi
    if [ ! -f "$LLMOPS_SERVICE_CONFIGMAP" ]; then
        log_error "ConfigMap 文件不存在: $LLMOPS_SERVICE_CONFIGMAP"
        log_info "请确保 secrets 目录存在: $SECRETS_DIR"
        exit 1
    fi
    if [ ! -f "$LLMOPS_SERVICE_SECRET" ]; then
        log_error "Secret 文件不存在: $LLMOPS_SERVICE_SECRET"
        log_info "请确保 secrets 目录存在: $SECRETS_DIR"
        exit 1
    fi
    
    # 检查 envsubst 是否可用
    if ! command -v envsubst &> /dev/null; then
        log_error "envsubst 命令未找到，请安装 gettext 包"
        log_info "Ubuntu/Debian: sudo apt-get install gettext-base"
        log_info "CentOS/RHEL: sudo yum install gettext"
        exit 1
    fi
}

# 部署 Web API
deploy_web_api() {
    log_info "开始部署 LLMOps Service..."
    log_info "环境: $ENV, 命名空间: $NAMESPACE"
    
    # 检查环境配置
    check_env_config
    
    # deploy 命令：使用 Harbor 镜像部署
    # 注意：部署前请确保镜像已构建并推送到 Harbor
    # 构建镜像请使用: cd ../../../../../sunmoonai-llmops-service/build && ./build-image.sh build-push
    LLMOPS_SERVICE_FULL_IMAGE_NAME="${LLMOPS_SERVICE_IMAGE_REGISTRY}/${LLMOPS_SERVICE_IMAGE_PROJECT}/${LLMOPS_SERVICE_IMAGE}:${LLMOPS_SERVICE_TAG}"
    IMAGE_PULL_POLICY="IfNotPresent"  # 如果本地有则使用，否则从仓库拉取
    log_info "使用 Harbor 镜像部署: $LLMOPS_SERVICE_FULL_IMAGE_NAME"
    log_info "Kubernetes 将从镜像仓库拉取镜像"
    log_warn "⚠️  请确保该镜像已存在于 Harbor 仓库中"
    
    # 部署 Secrets 和 ConfigMaps（使用统一部署脚本）
    if [[ -f "$DEPLOY_SECRETS_ALL" ]]; then
        log_info "使用统一部署脚本部署 Secrets 和 ConfigMaps..."
        bash "$DEPLOY_SECRETS_ALL" deploy "$PROJECT_ID" "$NAMESPACE" "$ENV" || {
            log_error "Secrets 和 ConfigMaps 部署失败"
            exit 1
        }
    else
        log_warn "统一部署脚本不存在，使用直接部署方式..."
        # 部署 ConfigMap（使用 envsubst 替换环境变量）
        log_info "部署 ConfigMap (环境: $ENV, 命名空间: $NAMESPACE)..."
        TEMP_CONFIGMAP=$(mktemp)
        export NAMESPACE ENV
        envsubst < "$LLMOPS_SERVICE_CONFIGMAP" > "$TEMP_CONFIGMAP"
        kubectl apply -f "$TEMP_CONFIGMAP" -n "$NAMESPACE"
        rm -f "$TEMP_CONFIGMAP"
        
        # 部署 Secret（使用 envsubst 替换环境变量）
        log_info "部署 Secret (环境: $ENV, 命名空间: $NAMESPACE)..."
        TEMP_SECRET=$(mktemp)
        export NAMESPACE ENV
        envsubst < "$LLMOPS_SERVICE_SECRET" > "$TEMP_SECRET"
        kubectl apply -f "$TEMP_SECRET" -n "$NAMESPACE"
        rm -f "$TEMP_SECRET"
    fi
    
    # 部署 LLMOps Service（动态替换镜像名称和命名空间）
    log_info "部署 LLMOps Service (环境: $ENV, 镜像: $LLMOPS_SERVICE_FULL_IMAGE_NAME, 拉取策略: ${IMAGE_PULL_POLICY:-IfNotPresent}, 命名空间: $NAMESPACE)..."
    # 创建临时文件并替换环境变量（包括镜像名称、拉取策略和命名空间）
    TEMP_YAML=$(mktemp)
    export NAMESPACE ENV LLMOPS_SERVICE_IMAGE LLMOPS_SERVICE_TAG LLMOPS_SERVICE_IMAGE_REGISTRY LLMOPS_SERVICE_IMAGE_PROJECT LLMOPS_SERVICE_FULL_IMAGE_NAME IMAGE_PULL_POLICY
    envsubst < "$LLMOPS_SERVICE_YAML" > "$TEMP_YAML"
    kubectl apply -f "$TEMP_YAML" -n "$NAMESPACE"
    rm -f "$TEMP_YAML"
    
    log_success "LLMOps Service 部署完成！"
    
    # 部署 Ingress（如果启用）
    if [[ "${ingress_enabled:-true}" == "true" ]]; then
        log_info "部署 LLMOps Service Ingress..."
        local ingress_script="$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
        if [[ -f "$ingress_script" ]]; then
            if bash "$ingress_script" deploy "$PROJECT_ID" "$NAMESPACE" "$ENV"; then
                log_success "✅ LLMOps Service Ingress 部署成功"
            else
                log_warn "⚠️ LLMOps Service Ingress 部署失败（可能已存在）"
            fi
        else
            log_warn "⚠️ Ingress 部署脚本不存在: $ingress_script"
        fi
    else
        log_info "Ingress 部署已禁用，跳过"
    fi
    
    # 显示访问信息
    echo ""
    log_info "访问信息:"
    echo "  🌐 域名: ${LLMOPS_SERVICE_UNIFIED_HOST:-llmops.sunmoonai.com}"
    echo "  🔗 端口: ${LLMOPS_SERVICE_EXTERNAL_PORT:-30443} (HTTPS)"
    echo "  📍 完整URL: https://${LLMOPS_SERVICE_UNIFIED_HOST:-llmops.sunmoonai.com}:${LLMOPS_SERVICE_EXTERNAL_PORT:-30443}/api/v1"
    echo ""
    log_info "检查部署状态:"
    echo "  kubectl get pods -n $NAMESPACE -l app=llmops-service"
    echo "  kubectl get svc -n $NAMESPACE -l app=llmops-service"
    echo "  kubectl get ingressroute -n $NAMESPACE"
    echo ""
    log_info "查看 Pod 日志:"
    echo "  kubectl logs -n $NAMESPACE -l app=llmops-service -f"
}

# 卸载 Web API
undeploy_web_api() {
    log_info "开始卸载 LLMOps Service..."
    log_info "环境: $ENV, 命名空间: $NAMESPACE"
    
    # 检查环境配置
    check_env_config
    
    # 卸载时使用原始 YAML（删除时不需要替换镜像，但需要替换命名空间）
    TEMP_YAML=$(mktemp)
    export NAMESPACE ENV
    envsubst < "$LLMOPS_SERVICE_YAML" > "$TEMP_YAML"
    kubectl delete -f "$TEMP_YAML" -n "$NAMESPACE" --ignore-not-found=true
    rm -f "$TEMP_YAML"
    
    # 卸载 Ingress（如果启用）
    if [[ "${ingress_enabled:-true}" == "true" ]]; then
        log_info "卸载 LLMOps Service Ingress..."
        local ingress_script="$SCRIPT_DIR/ingress/deploy-ingress/deploy-ingress.sh"
        if [[ -f "$ingress_script" ]]; then
            if bash "$ingress_script" uninstall "$PROJECT_ID" "$NAMESPACE" "$ENV"; then
                log_success "✅ LLMOps Service Ingress 卸载成功"
            else
                log_warn "⚠️ LLMOps Service Ingress 卸载失败（可能不存在）"
            fi
        else
            log_warn "⚠️ Ingress 部署脚本不存在: $ingress_script"
        fi
    fi
    
    # 卸载 Secrets 和 ConfigMaps（使用统一部署脚本）
    if [[ -f "$DEPLOY_SECRETS_ALL" ]]; then
        log_info "使用统一部署脚本卸载 Secrets 和 ConfigMaps..."
        bash "$DEPLOY_SECRETS_ALL" uninstall "$PROJECT_ID" "$NAMESPACE" "$ENV" || {
            log_warn "Secrets 和 ConfigMaps 卸载失败（可能不存在）"
        }
    else
        log_warn "统一部署脚本不存在，使用直接卸载方式..."
        # 卸载 Secret 和 ConfigMap（使用 envsubst 替换环境变量）
        TEMP_SECRET=$(mktemp)
        TEMP_CONFIGMAP=$(mktemp)
        export NAMESPACE ENV
        envsubst < "$LLMOPS_SERVICE_SECRET" > "$TEMP_SECRET"
        envsubst < "$LLMOPS_SERVICE_CONFIGMAP" > "$TEMP_CONFIGMAP"
        kubectl delete -f "$TEMP_SECRET" -n "$NAMESPACE" --ignore-not-found=true
        kubectl delete -f "$TEMP_CONFIGMAP" -n "$NAMESPACE" --ignore-not-found=true
        rm -f "$TEMP_SECRET" "$TEMP_CONFIGMAP"
    fi
    
    log_success "LLMOps Service 卸载完成！"
}

# 显示状态
show_status() {
    log_info "LLMOps Service 状态:"
    echo ""
    echo "📦 Pods:"
    kubectl get pods -n "$NAMESPACE" -l app=llmops-service 2>/dev/null || echo "  无 Pod 运行"
    echo ""
    echo "🌐 Services:"
    kubectl get svc -n "$NAMESPACE" -l app=llmops-service 2>/dev/null || echo "  无 Service"
    echo ""
    echo "📋 ConfigMaps:"
    kubectl get configmap -n "$NAMESPACE" -l app=llmops-service 2>/dev/null || echo "  无 ConfigMap"
    echo ""
    echo "🔐 Secrets:"
    kubectl get secret -n "$NAMESPACE" -l app=llmops-service 2>/dev/null || echo "  无 Secret"
}

# 主函数
main() {
    log_info "LLMOps Service 部署脚本启动"
    log_info "操作: $ACTION, 环境: $ENV, 命名空间: $NAMESPACE"
    
    # 验证环境参数
    if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
        log_error "无效的环境参数: $ENV"
        log_info "环境必须是 'dev' 或 'prod'"
        exit 1
    fi
    
    check_kubectl
    
    case "$ACTION" in
        "deploy")
            # deploy 命令：部署到 Kubernetes（假设镜像已构建并推送到 Harbor）
            log_info "deploy 命令将执行：从 Harbor 拉取镜像 → 部署到 Kubernetes"
            log_info "提示: 如需构建镜像，请先运行: cd ../../../../../sunmoonai-llmops-service/build && ./build-image.sh build-push"
            
            check_namespace
            deploy_web_api
            show_status
            ;;
        "undeploy")
            undeploy_web_api
            ;;
        "status")
            show_status
            ;;
        *)
            log_error "无效的操作: $ACTION"
            echo "用法: $0 [deploy|undeploy|status] [env] [namespace]"
            echo ""
            echo "参数说明:"
            echo "  env         - 环境 (dev|prod)，默认: dev"
            echo "  namespace   - Kubernetes 命名空间，默认: app-platform-\${env}"
            echo ""
            echo "操作说明:"
            echo "  deploy       - 部署到 Kubernetes（从 Harbor 拉取镜像）"
            echo "                注意: 部署前请确保镜像已构建并推送到 Harbor"
            echo "                构建镜像: cd ../../../../../sunmoonai-llmops-service/build && ./build-image.sh build-push"
            echo "  undeploy     - 卸载 LLMOps Service"
            echo "  status       - 查看 LLMOps Service 状态"
            echo ""
            echo "示例:"
            echo "  $0 deploy dev                    # 部署到 dev 环境"
            echo "  $0 deploy prod app-platform-prod # 部署到 prod 环境"
            echo ""
            echo "完整流程示例:"
            echo "  # 1. 构建并推送镜像"
            echo "  cd ../../../../../sunmoonai-llmops-service/build"
            echo "  ./build-image.sh build-push"
            echo ""
            echo "  # 2. 部署服务"
            echo "  cd ../../k8s/sunmoonai/app-platform/business-apps/llmops-app/llmops-app-bff/deploy-llmops-service"
            echo "  ./deploy-llmops-service.sh deploy dev"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
