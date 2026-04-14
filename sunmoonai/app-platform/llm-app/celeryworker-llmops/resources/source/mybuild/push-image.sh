#!/bin/bash

# 通用镜像推送脚本
# 用法: ./push-image.sh [--tag TAG]
#   从 build.conf 读取配置，将本地镜像推送到 Harbor 仓库

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
if [ ! -f "$BUILD_CONF" ]; then
    log_error "构建配置文件不存在: $BUILD_CONF"
    exit 1
fi

log_info "加载构建配置: $BUILD_CONF"
# shellcheck source=/dev/null
source "$BUILD_CONF"

# 自动检测镜像配置变量名
# 支持多种命名格式：CELERY_WORKER_IMAGE, INCUBATOR_BFF_IMAGE, LLMOPS_BFF_IMAGE, BACKEND_IMAGE 等
detect_image_config() {
    # 尝试常见的变量名模式
    if [ -n "${CELERY_WORKER_IMAGE:-}" ]; then
        IMAGE_VAR="CELERY_WORKER_IMAGE"
        TAG_VAR="CELERY_WORKER_TAG"
        REGISTRY_VAR="CELERY_WORKER_IMAGE_REGISTRY"
        PROJECT_VAR="CELERY_WORKER_IMAGE_PROJECT"
    elif [ -n "${INCUBATOR_BFF_IMAGE:-}" ]; then
        IMAGE_VAR="INCUBATOR_BFF_IMAGE"
        TAG_VAR="INCUBATOR_BFF_TAG"
        REGISTRY_VAR="INCUBATOR_BFF_IMAGE_REGISTRY"
        PROJECT_VAR="INCUBATOR_BFF_IMAGE_PROJECT"
    elif [ -n "${LLMOPS_BFF_IMAGE:-}" ]; then
        IMAGE_VAR="LLMOPS_BFF_IMAGE"
        TAG_VAR="LLMOPS_BFF_TAG"
        REGISTRY_VAR="LLMOPS_BFF_IMAGE_REGISTRY"
        PROJECT_VAR="LLMOPS_BFF_IMAGE_PROJECT"
    elif [ -n "${BACKEND_IMAGE:-}" ]; then
        IMAGE_VAR="BACKEND_IMAGE"
        TAG_VAR="BACKEND_TAG"
        REGISTRY_VAR="BACKEND_IMAGE_REGISTRY"
        PROJECT_VAR="BACKEND_IMAGE_PROJECT"
    else
        log_error "无法检测镜像配置变量，请确保 build.conf 中包含以下变量之一："
        log_error "  - CELERY_WORKER_IMAGE / INCUBATOR_BFF_IMAGE / LLMOPS_BFF_IMAGE / BACKEND_IMAGE"
        exit 1
    fi
    
    # 获取变量值
    IMAGE_NAME=$(eval echo \$${IMAGE_VAR})
    IMAGE_TAG=$(eval echo \$${TAG_VAR})
    IMAGE_REGISTRY=$(eval echo \$${REGISTRY_VAR})
    IMAGE_PROJECT=$(eval echo \$${PROJECT_VAR})
    
    log_info "检测到镜像配置:"
    log_info "  镜像名称变量: $IMAGE_VAR = $IMAGE_NAME"
    log_info "  镜像标签变量: $TAG_VAR = $IMAGE_TAG"
    log_info "  镜像仓库变量: $REGISTRY_VAR = $IMAGE_REGISTRY"
    log_info "  镜像项目变量: $PROJECT_VAR = $IMAGE_PROJECT"
}

# 容器运行时配置（从 build.conf 读取）
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
if [[ "$1" == "--tag" && -n "$2" ]]; then
    CUSTOM_TAG="$2"
    log_info "使用自定义标签: $CUSTOM_TAG"
fi

# 检测镜像配置
detect_image_config

# 如果提供了自定义标签，使用自定义标签
if [ -n "$CUSTOM_TAG" ]; then
    IMAGE_TAG="$CUSTOM_TAG"
fi

# 验证配置
if [ -z "$IMAGE_NAME" ] || [ -z "$IMAGE_TAG" ] || [ -z "$IMAGE_REGISTRY" ] || [ -z "$IMAGE_PROJECT" ]; then
    log_error "镜像配置不完整，请检查 build.conf"
    log_error "  镜像名称: ${IMAGE_NAME:-未设置}"
    log_error "  镜像标签: ${IMAGE_TAG:-未设置}"
    log_error "  镜像仓库: ${IMAGE_REGISTRY:-未设置}"
    log_error "  镜像项目: ${IMAGE_PROJECT:-未设置}"
    exit 1
fi

# 构建完整镜像名称
FULL_IMAGE_NAME="${IMAGE_REGISTRY}/${IMAGE_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"
LOCAL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# 推送镜像
push_image() {
    log_info "开始推送镜像..."
    log_info "本地镜像: ${LOCAL_IMAGE_NAME}"
    log_info "目标镜像: ${FULL_IMAGE_NAME}"
    
    # 检查本地镜像是否存在
    if ! $RUNTIME_CMD images | grep -q "${IMAGE_NAME}.*${IMAGE_TAG}"; then
        log_error "本地镜像不存在: ${LOCAL_IMAGE_NAME}"
        log_info "请先构建镜像:"
        log_info "  ./build-image.sh"
        log_info "  或"
        log_info "  ./rebuild-and-run.sh"
        exit 1
    fi
    
    # 标记镜像
    log_info "标记镜像..."
    if $RUNTIME_CMD tag "${LOCAL_IMAGE_NAME}" "$FULL_IMAGE_NAME"; then
        log_success "镜像标记成功: ${LOCAL_IMAGE_NAME} -> ${FULL_IMAGE_NAME}"
    else
        log_error "镜像标记失败"
        exit 1
    fi
    
    # 推送镜像
    log_info "推送镜像到 Harbor 仓库..."
    if $RUNTIME_CMD push "$FULL_IMAGE_NAME"; then
        log_success "✅ 镜像推送成功: $FULL_IMAGE_NAME"
        echo ""
        log_info "镜像信息:"
        $RUNTIME_CMD images | grep "${IMAGE_NAME}" | grep "${IMAGE_TAG}" | head -1
        echo ""
        log_info "推送完成！镜像已推送到 Harbor 仓库"
        log_info "完整镜像路径: $FULL_IMAGE_NAME"
    else
        log_error "❌ 镜像推送失败: $FULL_IMAGE_NAME"
        echo ""
        log_info "请检查："
        log_info "  1. 镜像仓库配置是否正确"
        if [[ "$RUNTIME_CMD" == "docker" ]]; then
            log_info "  2. 是否已登录镜像仓库："
            log_info "     docker login ${IMAGE_REGISTRY}"
        else
            log_info "  2. 是否已登录镜像仓库："
            log_info "     sudo nerdctl login ${IMAGE_REGISTRY}"
        fi
        log_info "  3. 网络连接是否正常"
        log_info "  4. 镜像仓库权限是否足够"
        exit 1
    fi
}

# 主函数
main() {
    log_info "镜像推送脚本启动"
    log_info "容器运行时: $CONTAINER_RUNTIME"
    
    # 执行推送
    push_image
}

# 执行主函数
main "$@"

