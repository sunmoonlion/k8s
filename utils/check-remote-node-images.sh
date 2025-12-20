#!/bin/bash

# 检查远程 Kubernetes 节点上的镜像版本
# 用法: ./check-remote-node-images.sh [镜像名称模式] [命名空间]
# 示例: ./check-remote-node-images.sh "incubator-app-bff|llmops-app-bff" app-platform-dev

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
NAMESPACE="${2:-app-platform-dev}"

log_info "检查远程 Kubernetes 节点上的镜像"
log_info "镜像模式: $IMAGE_PATTERN"
log_info "命名空间: $NAMESPACE"
echo ""

# 检查 kubectl 和集群连接
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl 未安装"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    log_error "无法连接到 Kubernetes 集群"
    exit 1
fi

# 方法1: 通过 Pod 的镜像ID检查节点上实际使用的镜像
log_info "=========================================="
log_info "方法1: 通过运行中的 Pod 检查节点上的镜像"
log_info "=========================================="
echo ""

# 获取所有相关 Pod
PODS=$(kubectl get pods -n "$NAMESPACE" -o json 2>/dev/null | \
    jq -r --arg pattern "$IMAGE_PATTERN" '.items[] | 
        select(.spec.containers[0].image | test($pattern)) | 
        "\(.metadata.name)|\(.spec.nodeName)|\(.spec.containers[0].image)|\(.spec.containers[0].imagePullPolicy)|\(.status.containerStatuses[0].imageID // "N/A")|\(.status.phase)"' 2>/dev/null || \
    kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.spec.nodeName}{"|"}{.spec.containers[0].image}{"|"}{.spec.containers[0].imagePullPolicy}{"|"}{.status.containerStatuses[0].imageID}{"|"}{.status.phase}{"\n"}{end}' | \
    grep -E "$IMAGE_PATTERN")

if [ -z "$PODS" ]; then
    log_warn "未找到匹配的 Pod"
else
    echo "$PODS" | while IFS='|' read -r pod_name node_name image pull_policy image_id phase; do
        log_info "Pod: $pod_name"
        log_info "  节点: $node_name"
        log_info "  配置镜像: $image"
        log_info "  实际镜像ID: ${image_id:-未拉取}"
        log_info "  拉取策略: $pull_policy"
        log_info "  状态: $phase"
        
        # 提取镜像摘要（SHA256）
        if echo "$image_id" | grep -q "sha256:"; then
            SHA256=$(echo "$image_id" | grep -o "sha256:[a-f0-9]\{64\}" | head -1)
            log_info "  镜像摘要: $SHA256"
        fi
        echo ""
    done
fi

# 方法2: 按节点分组显示
log_info "=========================================="
log_info "方法2: 按节点分组显示镜像信息"
log_info "=========================================="
echo ""

NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$NODES" ]; then
    log_warn "无法获取节点列表"
else
    for node in $NODES; do
        NODE_IP=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "unknown")
        log_info "节点: $node (IP: $NODE_IP)"
        
        # 获取该节点上的相关 Pod
        NODE_PODS=$(kubectl get pods -n "$NAMESPACE" -o wide --field-selector spec.nodeName="$node" 2>/dev/null | \
            grep -E "$IMAGE_PATTERN" || echo "")
        
        if [ -z "$NODE_PODS" ]; then
            log_info "  无相关 Pod"
        else
            echo "$NODE_PODS" | while read -r line; do
                POD_NAME=$(echo "$line" | awk '{print $1}')
                IMAGE=$(echo "$line" | awk '{print $(NF-1)}')
                STATUS=$(echo "$line" | awk '{print $3}')
                log_info "  - $POD_NAME: $IMAGE (状态: $STATUS)"
            done
        fi
        echo ""
    done
fi

# 方法3: 检查镜像版本一致性
log_info "=========================================="
log_info "方法3: 检查镜像版本一致性"
log_info "=========================================="
echo ""

# 获取 Deployment 配置的镜像
DEPLOYMENT_IMAGE=$(kubectl get deployment -n "$NAMESPACE" -o json 2>/dev/null | \
    jq -r --arg pattern "$IMAGE_PATTERN" '.items[] | 
        select(.spec.template.spec.containers[0].image | test($pattern)) | 
        .spec.template.spec.containers[0].image' 2>/dev/null | head -1)

if [ -n "$DEPLOYMENT_IMAGE" ]; then
    log_info "Deployment 配置的镜像: $DEPLOYMENT_IMAGE"
    
    # 检查所有 Pod 使用的镜像是否一致
    UNIQUE_IMAGES=$(echo "$PODS" | cut -d'|' -f3 | sort -u)
    UNIQUE_IMAGE_IDS=$(echo "$PODS" | cut -d'|' -f5 | grep -v "N/A" | grep -v "^$" | sort -u)
    
    IMAGE_COUNT=$(echo "$UNIQUE_IMAGES" | wc -l)
    IMAGE_ID_COUNT=$(echo "$UNIQUE_IMAGE_IDS" | wc -l)
    
    if [ "$IMAGE_COUNT" -gt 1 ]; then
        log_warn "发现多个不同的镜像标签:"
        echo "$UNIQUE_IMAGES" | while read -r img; do
            log_warn "  - $img"
        done
    else
        log_success "所有 Pod 使用相同的镜像标签"
    fi
    
    if [ "$IMAGE_ID_COUNT" -gt 1 ]; then
        log_warn "发现多个不同的镜像ID（可能节点上有旧版本缓存）:"
        echo "$UNIQUE_IMAGE_IDS" | while read -r img_id; do
            log_warn "  - $img_id"
        done
    elif [ "$IMAGE_ID_COUNT" -eq 1 ]; then
        log_success "所有 Pod 使用相同的镜像ID"
    fi
else
    log_warn "未找到匹配的 Deployment"
fi

echo ""
log_info "=========================================="
log_info "手动检查建议（如果需要直接访问节点）"
log_info "=========================================="
echo ""

log_info "如果需要直接检查节点上的镜像缓存，可以："
log_info "1. SSH 到节点后执行:"
for node in $NODES; do
    NODE_IP=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "unknown")
    log_info "   ssh user@$NODE_IP 'crictl images | grep -E \"$IMAGE_PATTERN\"'"
done

log_info ""
log_info "2. 或者使用 kubectl debug（如果支持）:"
log_info "   kubectl debug node/<node-name> -it --image=busybox --rm -- sh -c 'crictl images | grep -E \"$IMAGE_PATTERN\"'"

echo ""
log_success "检查完成"
