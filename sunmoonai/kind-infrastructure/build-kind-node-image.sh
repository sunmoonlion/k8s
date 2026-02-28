#!/usr/bin/env bash
#
# 构建“带预装镜像”的 Kind 节点镜像，便于重建集群时无需再加载镜像。
# 步骤：确保集群存在 → 用 load-kind-images.sh 加载所有 tar → 将 control-plane 节点 commit 为新镜像
#       → 在 kind-cluster.yaml 中使用该镜像后，新建集群即自带这些镜像。
#
# 使用前请确保 deploy-kind/images-init-dir（或 conf 中配置的 tar 目录）内已有全部 .tar。
#
set -euo pipefail

KIND_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOAD_IMAGES="${KIND_ROOT}/load-images/load-kind-images.sh"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"
CUSTOM_SUFFIX="${CUSTOM_NODE_SUFFIX:-sunmoonai}"
# 生成的自定义镜像名，例如 kindest/node:v1.27.3-sunmoonai
CUSTOM_IMAGE=""

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

if [[ ! -x "$LOAD_IMAGES" ]]; then
    log_error "未找到可执行脚本: $LOAD_IMAGES"
    exit 1
fi

# 若集群不存在，用当前 kind-cluster.yaml 创建（此时尚未指定自定义镜像，用默认节点镜像）
if ! kind get clusters -q 2>/dev/null | grep -qx "$KIND_CLUSTER_NAME"; then
    log_info "集群 $KIND_CLUSTER_NAME 不存在，正在创建..."
    kind create cluster --name "$KIND_CLUSTER_NAME" --config "${KIND_ROOT}/kind-cluster.yaml"
fi

# 加载所有镜像到集群节点
log_info "向集群加载镜像（tar 目录以 load-kind-images 配置为准）..."
"$LOAD_IMAGES"

CP_NODE="${KIND_CLUSTER_NAME}-control-plane"
if ! docker ps -q -f "name=^${CP_NODE}$" | grep -q .; then
    log_error "未找到节点容器: $CP_NODE"
    exit 1
fi

BASE_IMAGE=$(docker inspect "$CP_NODE" --format '{{.Config.Image}}')
if [[ -z "$BASE_IMAGE" ]]; then
    log_error "无法读取节点镜像名"
    exit 1
fi
# 例如 kindest/node:v1.27.3 → kindest/node:v1.27.3-sunmoonai
CUSTOM_IMAGE="${BASE_IMAGE}-${CUSTOM_SUFFIX}"

log_info "将节点 $CP_NODE 提交为镜像: $CUSTOM_IMAGE"
docker commit "$CP_NODE" "$CUSTOM_IMAGE"
log_success "已生成自定义节点镜像: $CUSTOM_IMAGE"

echo ""
echo "后续操作："
echo "  1) 在 kind-cluster.yaml 中为每个 node 指定: image: $CUSTOM_IMAGE"
echo "  2) 删除当前集群: kind delete cluster --name $KIND_CLUSTER_NAME"
echo "  3) 使用新配置创建集群: kind create cluster --name $KIND_CLUSTER_NAME --config ${KIND_ROOT}/kind-cluster.yaml"
echo "  新集群将直接使用已预装镜像，无需再执行 load-kind-images.sh。"
