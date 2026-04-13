#!/bin/bash

# Celery Worker 镜像构建脚本
# 用法: ./build-image.sh [--tag TAG]
#   根据 build.conf 中的 PUSH_IMAGES_AFTER_BUILD 配置决定是否推送镜像

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# 加载构建配置
BUILD_CONF="${SCRIPT_DIR}/build.conf"
if [ -f "$BUILD_CONF" ]; then
    log_info "加载构建配置: $BUILD_CONF"
    # shellcheck source=/dev/null
    source "$BUILD_CONF"
else
    log_warn "构建配置文件不存在: $BUILD_CONF，使用默认配置"
fi

# 镜像配置（从 build.conf 读取，或使用默认值）
CELERY_WORKER_IMAGE="${CELERY_WORKER_IMAGE:-celeryworker}"
CELERY_WORKER_TAG="${CELERY_WORKER_TAG:-1.0.0}"

# 镜像仓库配置（从 build.conf 读取，或使用默认值）
CELERY_WORKER_IMAGE_REGISTRY="${CELERY_WORKER_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
CELERY_WORKER_IMAGE_PROJECT="${CELERY_WORKER_IMAGE_PROJECT:-k8s-images}"

# 构建选项
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
BUILD_CONTEXT="${BUILD_CONTEXT:-.}"

# 容器运行时配置（从 build.conf 读取，或使用默认值）
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"

# 根据配置设置运行时命令
if [[ "$CONTAINER_RUNTIME" == "sudo nerdctl" || "$CONTAINER_RUNTIME" == "nerdctl" ]]; then
    # nerdctl 命名空间配置（从 build.conf 读取）
    NERDCTL_NAMESPACE="${NERDCTL_NAMESPACE:-k8s.io}"
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

# 解析参数
CUSTOM_TAG=""

# 解析自定义标签
if [[ "$1" == "--tag" && -n "$2" ]]; then
    CUSTOM_TAG="$2"
    CELERY_WORKER_TAG="$CUSTOM_TAG"
    log_info "使用自定义标签: $CELERY_WORKER_TAG"
fi

# 镜像推送配置（从 build.conf 读取，或使用默认值）
PUSH_IMAGES_AFTER_BUILD="${PUSH_IMAGES_AFTER_BUILD:-false}"

# 检查 Dockerfile
if [ ! -f "$SCRIPT_DIR/$DOCKERFILE" ]; then
    log_error "Dockerfile 不存在: $SCRIPT_DIR/$DOCKERFILE"
    exit 1
fi

# 检查 worker-start.sh
if [ ! -f "$SCRIPT_DIR/worker-start.sh" ]; then
    log_error "worker-start.sh 不存在: $SCRIPT_DIR/worker-start.sh"
    exit 1
fi

# 构建镜像
build_image() {
    log_info "开始构建 Celery Worker 镜像..."
    log_info "镜像名称: ${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}"
    log_info "Dockerfile: $SCRIPT_DIR/$DOCKERFILE"
    log_info "构建上下文: $SCRIPT_DIR"
    
    # 切换到脚本目录（构建上下文）
    cd "$SCRIPT_DIR"
    
    # 构建镜像（构建上下文是 mybuild 目录，包含 Dockerfile 和 worker-start.sh）
    $RUNTIME_CMD build -f "$SCRIPT_DIR/$DOCKERFILE" \
        -t "${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}" \
        .
    
    if [ $? -eq 0 ]; then
        log_success "镜像构建完成: ${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}"
        echo ""
        log_info "镜像信息:"
        $RUNTIME_CMD images | grep "${CELERY_WORKER_IMAGE}" | grep "${CELERY_WORKER_TAG}" | head -1
        
        # 根据配置决定是否推送
        if [[ "${PUSH_IMAGES_AFTER_BUILD}" == "true" ]]; then
            log_info "PUSH_IMAGES_AFTER_BUILD=true，开始推送镜像..."
            push_image
            log_success "✅ 镜像构建并推送完成！"
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

# 推送镜像
push_image() {
    log_info "推送镜像到镜像仓库..."
    
    # 构建完整镜像名称
    CELERY_WORKER_FULL_IMAGE_NAME="${CELERY_WORKER_IMAGE_REGISTRY}/${CELERY_WORKER_IMAGE_PROJECT}/${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}"
    
    log_info "完整镜像名称: $CELERY_WORKER_FULL_IMAGE_NAME"
    
    # 检查本地镜像是否存在
    if ! $RUNTIME_CMD images | grep -q "${CELERY_WORKER_IMAGE}.*${CELERY_WORKER_TAG}"; then
        log_error "本地镜像不存在: ${CELERY_WORKER_IMAGE}:${CELERY_WORKER_TAG}"
        log_info "请先构建镜像: ./build-image.sh"
        exit 1
    fi
    
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
}

# 主函数
main() {
    log_info "Celery Worker 镜像构建脚本启动"
    log_info "推送配置: PUSH_IMAGES_AFTER_BUILD=${PUSH_IMAGES_AFTER_BUILD}"
    
    # 执行构建（根据配置决定是否推送）
    build_image
}

# 执行主函数
main "$@"

