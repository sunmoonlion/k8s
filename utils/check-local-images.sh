#!/bin/bash

# 在 Kubernetes 节点上检查本地 Docker/containerd 镜像
# 用法: 在节点上直接运行: ./check-local-images.sh [镜像名称模式]
# 示例: ./check-local-images.sh "incubator-app-bff\|llmops-app-bff"

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 参数
IMAGE_PATTERN="${1:-incubator-app-bff|llmops-app-bff}"

log_info "检查本地 Docker/containerd 镜像"
log_info "镜像模式: $IMAGE_PATTERN"
log_info "主机名: $(hostname)"
echo ""

# 检查 Docker
if command -v docker &> /dev/null; then
    log_info "=========================================="
    log_info "Docker 镜像列表"
    log_info "=========================================="
    echo ""
    
    DOCKER_IMAGES=$(docker images 2>/dev/null | grep -E "$IMAGE_PATTERN" || echo "")
    
    if [ -z "$DOCKER_IMAGES" ]; then
        log_warn "未找到匹配的 Docker 镜像"
    else
        echo "$DOCKER_IMAGES"
        echo ""
        
        # 统计信息
        IMAGE_COUNT=$(echo "$DOCKER_IMAGES" | wc -l)
        log_info "找到 $IMAGE_COUNT 个匹配的镜像"
        
        # 列出所有匹配的镜像（包括标签）
        echo ""
        log_info "详细镜像信息:"
        docker images 2>/dev/null | grep -E "$IMAGE_PATTERN" | while read -r line; do
            REPO=$(echo "$line" | awk '{print $1}')
            TAG=$(echo "$line" | awk '{print $2}')
            IMAGE_ID=$(echo "$line" | awk '{print $3}')
            SIZE=$(echo "$line" | awk '{print $7}')
            CREATED=$(echo "$line" | awk '{print $4, $5, $6}')
            
            log_info "  仓库: $REPO"
            log_info "  标签: $TAG"
            log_info "  镜像ID: $IMAGE_ID"
            log_info "  大小: $SIZE"
            log_info "  创建时间: $CREATED"
            echo ""
        done
    fi
else
    log_warn "Docker 未安装或不在 PATH 中"
fi

# 检查 containerd/crictl
if command -v crictl &> /dev/null; then
    log_info "=========================================="
    log_info "containerd 镜像列表 (crictl)"
    log_info "=========================================="
    echo ""
    
    # 设置 crictl 运行时端点（如果需要）
    export CONTAINER_RUNTIME_ENDPOINT="${CONTAINER_RUNTIME_ENDPOINT:-unix:///run/containerd/containerd.sock}"
    
    CRICTL_IMAGES=$(crictl images 2>/dev/null | grep -E "$IMAGE_PATTERN" || echo "")
    
    if [ -z "$CRICTL_IMAGES" ]; then
        log_warn "未找到匹配的 containerd 镜像"
    else
        echo "$CRICTL_IMAGES"
        echo ""
        
        # 统计信息
        IMAGE_COUNT=$(echo "$CRICTL_IMAGES" | wc -l)
        log_info "找到 $IMAGE_COUNT 个匹配的镜像"
        
        # 列出所有匹配的镜像（包括标签）
        echo ""
        log_info "详细镜像信息:"
        crictl images 2>/dev/null | grep -E "$IMAGE_PATTERN" | while read -r line; do
            REPO=$(echo "$line" | awk '{print $1}')
            TAG=$(echo "$line" | awk '{print $2}')
            IMAGE_ID=$(echo "$line" | awk '{print $3}')
            SIZE=$(echo "$line" | awk '{print $4}')
            
            log_info "  仓库: $REPO"
            log_info "  标签: $TAG"
            log_info "  镜像ID: $IMAGE_ID"
            log_info "  大小: $SIZE"
            echo ""
        done
    fi
else
    log_warn "crictl 未安装或不在 PATH 中"
fi

# 检查 nerdctl（如果使用）
if command -v nerdctl &> /dev/null; then
    log_info "=========================================="
    log_info "nerdctl 镜像列表"
    log_info "=========================================="
    echo ""
    
    NERDCTL_IMAGES=$(nerdctl images 2>/dev/null | grep -E "$IMAGE_PATTERN" || echo "")
    
    if [ -z "$NERDCTL_IMAGES" ]; then
        log_warn "未找到匹配的 nerdctl 镜像"
    else
        echo "$NERDCTL_IMAGES"
        echo ""
        
        # 统计信息
        IMAGE_COUNT=$(echo "$NERDCTL_IMAGES" | wc -l)
        log_info "找到 $IMAGE_COUNT 个匹配的镜像"
    fi
fi

# 清理建议
log_info "=========================================="
log_info "清理旧镜像建议"
log_info "=========================================="
echo ""

log_info "如果发现旧版本镜像，可以删除:"
log_info ""
log_info "Docker:"
log_info "  docker rmi <image-id> 或 docker rmi <repo>:<tag>"
log_info "  docker image prune -a  # 删除所有未使用的镜像"
log_info ""
log_info "containerd (crictl):"
log_info "  crictl rmi <image-id>"
log_info "  crictl rmi <repo>:<tag>"
log_info ""
log_info "containerd (nerdctl):"
log_info "  nerdctl rmi <image-id>"
log_info "  nerdctl rmi <repo>:<tag>"

echo ""
log_success "检查完成"
