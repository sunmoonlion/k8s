#!/bin/bash

# Celery Worker 部署脚本
# 用法: ./deploy-celeryworker.sh [build|deploy|undeploy|status] [env] [namespace]
# 注意: build 仅构建镜像，deploy 根据 BUILD_IMAGE_BEFORE_DEPLOY 决定是否构建镜像

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 默认参数
ACTION="${1:-deploy}"
ENV="${2:-dev}"  # 环境：dev 或 prod
# 命名空间：优先使用命令行参数，其次使用配置文件，最后使用默认值
NAMESPACE="${3:-app-platform-${ENV}}"  # 根据环境自动设置命名空间（临时默认值，加载配置后可能被覆盖）

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
CELERY_WORKER_CONFIG_FILE="$SCRIPT_DIR/deploy-celeryworker.conf"
if [[ -f "$CELERY_WORKER_CONFIG_FILE" ]]; then
    source "$CELERY_WORKER_CONFIG_FILE"
    log_info "已加载 Celery Worker 配置文件: $CELERY_WORKER_CONFIG_FILE"
    # 如果命令行未明确指定命名空间（第三个参数为空），且配置文件中定义了命名空间，则使用配置文件中的命名空间
    if [[ -z "${3}" && -n "${CELERY_WORKER_NAMESPACE}" ]]; then
        NAMESPACE="${CELERY_WORKER_NAMESPACE}"
        log_info "使用配置文件中的命名空间: $NAMESPACE"
    fi
else
    log_warn "未找到 Celery Worker 配置文件: $CELERY_WORKER_CONFIG_FILE，使用默认配置"
fi

# 构建配置目录
BUILD_DIR="../build"
BUILD_CONF="${BUILD_DIR}/build.conf"

# 加载构建配置（如果存在）
if [ -f "$BUILD_CONF" ]; then
    log_info "加载构建配置: $BUILD_CONF"
    # shellcheck source=/dev/null
    source "$BUILD_CONF"
fi

# 镜像配置（从 build.conf 读取）
CELERY_WORKER_IMAGE="${CELERY_WORKER_IMAGE:-celeryworker}"
CELERY_WORKER_TAG="${CELERY_WORKER_TAG:-1.0.0}"

# 镜像仓库配置（从 build.conf 读取）
CELERY_WORKER_IMAGE_REGISTRY="${CELERY_WORKER_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
CELERY_WORKER_IMAGE_PROJECT="${CELERY_WORKER_IMAGE_PROJECT:-k8s-images}"

# 镜像推送配置（从 build.conf 读取）
PUSH_IMAGES_AFTER_BUILD="${PUSH_IMAGES_AFTER_BUILD:-false}"

# 容器运行时配置（从 build.conf 读取）
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
NERDCTL_NAMESPACE="${NERDCTL_NAMESPACE:-k8s.io}"

# Backend 镜像配置（从 deploy-celeryworker.conf 读取）
BACKEND_IMAGE="${BACKEND_IMAGE:-llmops-service}"
BACKEND_TAG="${BACKEND_TAG:-1.0.0}"

# 资源文件路径（统一使用 celeryworker.yaml）
RESOURCES_DIR="../resources"
CELERYWORKER_YAML="${RESOURCES_DIR}/celeryworker.yaml"


# 检查 kubectl 是否可用
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在 PATH 中"
        exit 1
    fi
    
    # 如果 KUBECONFIG 未设置，尝试使用默认配置文件
    if [[ -z "${KUBECONFIG}" ]]; then
        DEFAULT_KUBECONFIG="$HOME/.kube/cluster-c2-admin.conf"
        if [[ -f "$DEFAULT_KUBECONFIG" ]]; then
            export KUBECONFIG="$DEFAULT_KUBECONFIG"
            log_info "自动设置 KUBECONFIG: $KUBECONFIG"
        else
            log_warn "KUBECONFIG 未设置，且未找到默认配置文件: $DEFAULT_KUBECONFIG"
            log_info "请设置 KUBECONFIG 环境变量，例如："
            log_info "  export KUBECONFIG=$HOME/.kube/cluster-c2-admin.conf"
        fi
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

# 构建 Celery Worker 镜像
build_celeryworker_image() {
    log_info "开始构建 Celery Worker 镜像..."
    
    if [ ! -d "$BUILD_DIR" ]; then
        log_error "构建目录不存在: $BUILD_DIR"
        exit 1
    fi
    
    # 从 build.conf 读取 Dockerfile 名称（如果配置了）
    DOCKERFILE="${DOCKERFILE:-Dockerfile}"
    
    if [ ! -f "$BUILD_DIR/$DOCKERFILE" ]; then
        log_error "Dockerfile 不存在: $BUILD_DIR/$DOCKERFILE"
        exit 1
    fi
    
    # 根据配置设置运行时命令
    if [[ "$CONTAINER_RUNTIME" == "sudo nerdctl" || "$CONTAINER_RUNTIME" == "nerdctl" ]]; then
        RUNTIME_CMD="sudo nerdctl -n ${NERDCTL_NAMESPACE}"
        log_info "使用容器运行时: sudo nerdctl"
        log_info "nerdctl 命名空间: ${NERDCTL_NAMESPACE}"
        # 检查 nerdctl 是否可用
        if ! command -v nerdctl &> /dev/null; then
            log_error "nerdctl 未安装或不在 PATH 中"
            exit 1
        fi
    else
        RUNTIME_CMD="docker"
        log_info "使用容器运行时: docker"
        # 检查 docker 是否可用
        if ! command -v docker &> /dev/null; then
            log_error "docker 未安装或不在 PATH 中"
            exit 1
        fi
    fi
    
    log_info "构建镜像: ${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}"
    cd "$BUILD_DIR"
    
    $RUNTIME_CMD build -f "$DOCKERFILE" \
        -t "${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}" \
        .
    
    if [ $? -eq 0 ]; then
        log_success "镜像构建完成: ${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}"
        echo ""
        log_info "镜像信息:"
        $RUNTIME_CMD images | grep "${CELERY_WORKER_IMAGE}" | grep "${CELERY_WORKER_TAG}" | head -1
        
        # build 命令：根据配置决定是否推送
        if [[ "${PUSH_IMAGES_AFTER_BUILD}" == "true" ]]; then
            log_info "PUSH_IMAGES_AFTER_BUILD=true，开始推送镜像..."
            CELERY_WORKER_FULL_IMAGE_NAME="${CELERY_WORKER_IMAGE_REGISTRY}/${CELERY_WORKER_IMAGE_PROJECT}/${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}"
            
            log_info "完整镜像名称: $CELERY_WORKER_FULL_IMAGE_NAME"
            
            # 标记镜像
            $RUNTIME_CMD tag "${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}" "$CELERY_WORKER_FULL_IMAGE_NAME"
            
            # 推送镜像
            if $RUNTIME_CMD push "$CELERY_WORKER_FULL_IMAGE_NAME"; then
                log_success "✅ 镜像推送成功: $CELERY_WORKER_FULL_IMAGE_NAME"
            else
                log_error "❌ 镜像推送失败: $CELERY_WORKER_FULL_IMAGE_NAME"
                log_info "请检查："
                log_info "  1. 镜像仓库配置是否正确"
                if [[ "$RUNTIME_CMD" == "docker" ]]; then
                    log_info "  2. 是否已登录镜像仓库（docker login ${CELERY_WORKER_IMAGE_REGISTRY}）"
                else
                    log_info "  2. 是否已登录镜像仓库（sudo nerdctl login ${CELERY_WORKER_IMAGE_REGISTRY}）"
                fi
                log_info "  3. 网络连接是否正常"
                exit 1
            fi
        else
            log_info "PUSH_IMAGES_AFTER_BUILD=false，跳过推送"
            log_info "提示: 如需推送镜像，请在 build.conf 中设置 PUSH_IMAGES_AFTER_BUILD=true"
        fi
    else
        log_error "镜像构建失败"
        exit 1
    fi
    
    cd - > /dev/null
}

# 检查环境配置
check_env_config() {
    if [ ! -f "$CELERYWORKER_YAML" ]; then
        log_error "配置文件不存在: $CELERYWORKER_YAML"
        log_info "请确保资源文件存在: $RESOURCES_DIR/celeryworker.yaml"
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

# 部署 Celery Worker
deploy_celeryworker() {
    log_info "开始部署 Celery Worker..."
    log_info "环境: $ENV, 命名空间: $NAMESPACE"
    
    # 检查环境配置
    check_env_config
    
    # 检查是否需要构建镜像
    BUILD_IMAGE_BEFORE_DEPLOY="${BUILD_IMAGE_BEFORE_DEPLOY:-false}"
    if [[ "$BUILD_IMAGE_BEFORE_DEPLOY" == "true" ]]; then
        log_info "BUILD_IMAGE_BEFORE_DEPLOY=true，先构建镜像..."
        build_celeryworker_image
    fi
    
    # 准备环境变量
    export NAMESPACE="$NAMESPACE"
    export CELERY_WORKER_IMAGE_REGISTRY="${CELERY_WORKER_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
    export CELERY_WORKER_IMAGE_PROJECT="${CELERY_WORKER_IMAGE_PROJECT:-k8s-images}"
    export CELERY_WORKER_IMAGE="${CELERY_WORKER_IMAGE}"
    export CELERY_WORKER_TAG="${CELERY_WORKER_TAG}"
    export IMAGE_PULL_POLICY="${IMAGE_PULL_POLICY:-IfNotPresent}"
    
    # Backend 镜像配置（llmops-service）
    export BACKEND_IMAGE_REGISTRY="${BACKEND_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
    export BACKEND_IMAGE_PROJECT="${BACKEND_IMAGE_PROJECT:-k8s-images}"
    export BACKEND_IMAGE="${BACKEND_IMAGE:-llmops-service}"
    export BACKEND_TAG="${BACKEND_TAG:-1.0.0}"
    
    # 代码提取配置（从 deploy-celeryworker.conf 读取）
    export CODE_EXTRACT_SOURCE_DIR="${CODE_EXTRACT_SOURCE_DIR:-/app/app}"
    export CODE_EXTRACT_TARGET_DIR="${CODE_EXTRACT_TARGET_DIR:-/shared/app}"
    export CODE_EXTRACT_DIRS="${CODE_EXTRACT_DIRS:-worker core services db models schemas crud}"
    export CODE_EXTRACT_FILES="${CODE_EXTRACT_FILES:-__init__.py celeryworker_pre_start.py}"
    
    # 从配置文件读取环境变量
    export CELERY_BROKER_URL="${CELERY_BROKER_URL:-amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//}"
    export CELERY_RESULT_BACKEND="${CELERY_RESULT_BACKEND:-redis://redis-service.data-platform:6379}"
    export CELERY_QUEUE="${CELERY_QUEUE:-llmops-queue}"
    export CELERY_CONCURRENCY="${CELERY_CONCURRENCY:-1}"
    export REDIS_URL="${REDIS_URL:-redis://redis-service.data-platform:6379}"
    
    # 使用 envsubst 替换 YAML 中的变量
    log_info "应用配置到 YAML 文件..."
    envsubst < "$CELERYWORKER_YAML" | kubectl apply -f -
    
    if [ $? -eq 0 ]; then
        log_success "Celery Worker 部署完成"
    else
        log_error "Celery Worker 部署失败"
        exit 1
    fi
}

# 卸载 Celery Worker
undeploy_celeryworker() {
    log_info "开始卸载 Celery Worker..."
    log_info "环境: $ENV, 命名空间: $NAMESPACE"
    
    check_env_config
    
    export NAMESPACE="$NAMESPACE"
    envsubst < "$CELERYWORKER_YAML" | kubectl delete -f - || true
    
    log_success "Celery Worker 卸载完成"
}

# 查看状态
status_celeryworker() {
    log_info "查看 Celery Worker 状态..."
    log_info "环境: $ENV, 命名空间: $NAMESPACE"
    
    check_kubectl
    check_namespace
    
    echo ""
    log_info "Deployment 状态:"
    kubectl get deployment celeryworker -n "$NAMESPACE" || log_warn "Deployment 不存在"
    
    echo ""
    log_info "Pod 状态:"
    kubectl get pods -n "$NAMESPACE" -l app=celeryworker
    
    echo ""
    log_info "Service 状态:"
    kubectl get service celeryworker-service -n "$NAMESPACE" || log_warn "Service 不存在"
}

# 主函数
main() {
    check_kubectl
    
    case "$ACTION" in
        build)
            build_celeryworker_image
            ;;
        deploy)
            check_namespace
            deploy_celeryworker
            ;;
        undeploy)
            check_namespace
            undeploy_celeryworker
            ;;
        status)
            check_namespace
            status_celeryworker
            ;;
        *)
            log_error "未知操作: $ACTION"
            echo ""
            echo "用法: $0 [build|deploy|undeploy|status] [env] [namespace]"
            echo ""
            echo "操作:"
            echo "  build     - 构建镜像"
            echo "  deploy    - 部署到 Kubernetes（根据 BUILD_IMAGE_BEFORE_DEPLOY 决定是否构建）"
            echo "  undeploy  - 卸载"
            echo "  status    - 查看状态"
            echo ""
            echo "示例:"
            echo "  $0 build"
            echo "  $0 deploy dev app-platform-dev"
            echo "  $0 status dev app-platform-dev"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
