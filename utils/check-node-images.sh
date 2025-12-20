#!/bin/bash

# 检查 Kubernetes 节点上的 Docker 镜像
# 用法: ./check-node-images.sh [镜像名称模式] [命名空间]
# 示例: ./check-node-images.sh "incubator-app-bff\|llmops-app-bff" app-platform-dev

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

log_info "检查 Kubernetes 节点上的镜像"
log_info "镜像模式: $IMAGE_PATTERN"
log_info "命名空间: $NAMESPACE"
echo ""

# 检查 kubectl 是否可用
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl 未安装或不在 PATH 中"
    exit 1
fi

# 检查集群连接
if ! kubectl cluster-info &> /dev/null; then
    log_error "无法连接到 Kubernetes 集群"
    exit 1
fi

# 方法1: 检查运行中的 Pod 使用的镜像
log_info "=========================================="
log_info "方法1: 检查运行中的 Pod 使用的镜像"
log_info "=========================================="
echo ""

PODS=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' 2>/dev/null || echo "")

if [ -z "$PODS" ]; then
    log_warn "命名空间 $NAMESPACE 中没有找到 Pod"
else
    echo "$PODS" | while IFS=$'\t' read -r pod_name images; do
        if echo "$images" | grep -qE "$IMAGE_PATTERN"; then
            echo "$images" | tr ' ' '\n' | grep -E "$IMAGE_PATTERN" | while read -r image; do
                log_info "Pod: $pod_name"
                log_info "  镜像: $image"
                
                # 获取 Pod 的详细信息
                POD_STATUS=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
                POD_NODE=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "Unknown")
                IMAGE_PULL_POLICY=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].imagePullPolicy}' 2>/dev/null || echo "Unknown")
                
                log_info "  状态: $POD_STATUS"
                log_info "  节点: $POD_NODE"
                log_info "  拉取策略: $IMAGE_PULL_POLICY"
                echo ""
            done
        fi
    done
fi

# 方法2: 检查所有节点上的镜像（需要节点访问权限）
log_info "=========================================="
log_info "方法2: 检查节点上的本地镜像缓存"
log_info "=========================================="
log_warn "注意: 这需要在每个节点上执行命令，可能需要节点访问权限"
echo ""

NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$NODES" ]; then
    log_warn "无法获取节点列表"
else
    for node in $NODES; do
        log_info "检查节点: $node"
        
        # 获取节点 IP
        NODE_IP=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "unknown")
        log_info "  节点 IP: $NODE_IP"
        
        # 方法2a: 使用 kubectl debug（如果支持）
        log_info "  尝试使用 kubectl debug 检查..."
        DEBUG_OUTPUT=$(kubectl debug "node/$node" -it --image=busybox --rm -- sh -c "crictl images 2>/dev/null | grep -E '$IMAGE_PATTERN' || echo 'NO_IMAGES'" 2>&1)
        
        if echo "$DEBUG_OUTPUT" | grep -qE "$IMAGE_PATTERN"; then
            log_info "  找到镜像:"
            echo "$DEBUG_OUTPUT" | grep -E "$IMAGE_PATTERN" | while read -r line; do
                log_info "    $line"
            done
        elif echo "$DEBUG_OUTPUT" | grep -q "NO_IMAGES"; then
            log_warn "  节点上未找到匹配的镜像"
        else
            log_warn "  无法在节点 $node 上检查镜像（可能需要手动 SSH 到节点执行）"
            log_info "  手动检查命令（如果节点可 SSH 访问）:"
            log_info "    ssh $node 'crictl images | grep -E \"$IMAGE_PATTERN\"'"
            log_info "    或: ssh $node 'docker images | grep -E \"$IMAGE_PATTERN\"'"
        fi
        echo ""
    done
fi

# 方法3: 检查 Deployment 配置的镜像版本
log_info "=========================================="
log_info "方法3: 检查 Deployment 配置的镜像版本"
log_info "=========================================="
echo ""

DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || echo "")

if [ -z "$DEPLOYMENTS" ]; then
    log_warn "命名空间 $NAMESPACE 中没有找到 Deployment"
else
    for deploy in $DEPLOYMENTS; do
        if echo "$deploy" | grep -qE "$IMAGE_PATTERN"; then
            log_info "Deployment: $deploy"
            
            # 获取镜像信息
            IMAGES=$(kubectl get deployment "$deploy" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[*].image}' 2>/dev/null || echo "")
            IMAGE_PULL_POLICY=$(kubectl get deployment "$deploy" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}' 2>/dev/null || echo "Unknown")
            
            if [ -n "$IMAGES" ]; then
                echo "$IMAGES" | tr ' ' '\n' | while read -r image; do
                    if echo "$image" | grep -qE "$IMAGE_PATTERN"; then
                        log_info "  镜像: $image"
                        log_info "  拉取策略: $IMAGE_PULL_POLICY"
                    fi
                done
            fi
            echo ""
        fi
    done
fi

# 方法4: 提供清理建议
log_info "=========================================="
log_info "清理建议"
log_info "=========================================="
echo ""

log_info "如果发现节点上有旧版本镜像，可以："
log_info "1. 确保 Deployment 的 imagePullPolicy 设置为 Always（已设置）"
log_info "2. 删除旧 Pod 强制重新拉取:"
log_info "   kubectl delete pod -n $NAMESPACE -l app=<app-name>"
log_info "3. 在节点上手动删除旧镜像（需要节点访问权限）:"
log_info "   ssh <node> 'docker rmi <old-image>'"
log_info "   或: ssh <node> 'crictl rmi <old-image>'"
log_info "4. 重启 Deployment 强制重新拉取:"
log_info "   kubectl rollout restart deployment/<deployment-name> -n $NAMESPACE"

echo ""
log_success "检查完成"
