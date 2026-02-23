#!/usr/bin/env bash
#
# 在 Kind 各节点内写入 /etc/hosts：harbor.sunmoonai.com -> 指定 IP。
# 因 kind v1alpha4 不支持节点 extraHosts，建集群后通过本脚本补上，供 containerd 拉镜像时解析。
# 应在 kind-up.sh 之后、apply-kind-registry-config.sh 之前执行。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ADMIN_CONF="${SCRIPT_DIR}/../../utils/k8s-admin.conf"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

# 集群名与节点内 Harbor 解析 IP（任一节点均可；实测 control-plane=172.18.0.2, worker=172.18.0.3, worker2=172.18.0.4）
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"
HARBOR_HOST="${HARBOR_HOST:-harbor.sunmoonai.com}"
HARBOR_NODE_IP="${HARBOR_NODE_IP:-172.18.0.2}"

if [[ -f "$K8S_ADMIN_CONF" ]]; then
    section=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$K8S_ADMIN_CONF" 2>/dev/null || true)
    [[ -n "${section}" ]] && KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-$(echo "$section" | grep "^cluster_name=" | head -1 | cut -d'=' -f2- | tr -d ' ')}"
fi
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"

if ! command -v kind &>/dev/null; then
    log_error "未找到 kind 命令"
    exit 1
fi

nodes=$(kind get nodes --name "$KIND_CLUSTER_NAME" 2>/dev/null || true)
if [[ -z "$nodes" ]]; then
    log_error "未找到 Kind 集群节点: $KIND_CLUSTER_NAME"
    exit 1
fi

log_info "在 Kind 各节点 /etc/hosts 中添加 ${HARBOR_HOST} -> ${HARBOR_NODE_IP}（集群: $KIND_CLUSTER_NAME）"
count=0
while IFS= read -r node; do
    [[ -z "$node" ]] && continue
    if docker exec "$node" sh -c "grep -q '${HARBOR_HOST}' /etc/hosts 2>/dev/null"; then
        log_info "  节点 $node 已存在 ${HARBOR_HOST}，跳过"
    else
        docker exec "$node" sh -c "echo '${HARBOR_NODE_IP} ${HARBOR_HOST}' >> /etc/hosts"
        log_info "  节点 $node: 已添加 ${HARBOR_HOST} -> ${HARBOR_NODE_IP}"
    fi
    ((count++)) || true
done <<< "$nodes"

if [[ $count -eq 0 ]]; then
    log_warn "未处理任何节点"
    exit 1
fi
log_success "已在 $count 个节点配置 ${HARBOR_HOST} 解析"
