#!/usr/bin/env bash
#
# 一键：创建 Kind 集群 + 平台初始化（命名空间、NFS）
# 前置：首次使用前需在 WSL 安装 NFS 服务：./wsl-setup-nfs-server.sh（仅需一次）
# 使用 k8s-admin.conf 中 [KIND] 的 cluster_name、kubeconfig 路径。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ADMIN_CONF="${SCRIPT_DIR}/../../utils/k8s-admin.conf"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

get_kind_kubeconfig() {
    if [[ ! -f "$K8S_ADMIN_CONF" ]]; then
        echo ""
        return
    fi
    local path
    path=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$K8S_ADMIN_CONF" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    path="${path/#\~/$HOME}"
    echo "$path"
}

log_info "1/3 创建 Kind 集群（已存在则跳过）"
"$SCRIPT_DIR/create-kind-cluster.sh"

KIND_KUBECONFIG=$(get_kind_kubeconfig)
if [[ -z "$KIND_KUBECONFIG" ]] || [[ ! -f "$KIND_KUBECONFIG" ]]; then
    log_warn "未从 k8s-admin.conf 读到 Kind kubeconfig 路径，尝试默认: ~/.kube/kind-config"
    KIND_KUBECONFIG="${HOME}/.kube/kind-config"
fi
if [[ ! -f "$KIND_KUBECONFIG" ]]; then
    log_warn "未找到 $KIND_KUBECONFIG，跳过平台初始化；请检查 create-kind-cluster.sh 是否成功"
    exit 0
fi

export KUBECONFIG="$KIND_KUBECONFIG"
log_info "2/3 KUBECONFIG=$KUBECONFIG"

# 检测 NFS 是否已安装并导出（与 wsl-setup-nfs-server.sh 一致）
NFS_EXPORT_DIR="${NFS_EXPORT_DIR:-/data/kind-nfs}"
if ! [[ -f /etc/exports ]] || ! grep -qE "^${NFS_EXPORT_DIR}[[:space:]]" /etc/exports 2>/dev/null; then
    log_error "未检测到 NFS 服务导出（/etc/exports 中无 ${NFS_EXPORT_DIR}）"
    log_error "请先在 WSL 执行: $SCRIPT_DIR/wsl-setup-nfs-server.sh"
    exit 1
fi

log_info "3/3 平台初始化：命名空间 + NFS"
"$SCRIPT_DIR/apply-namespaces-existing-cluster.sh"
"$SCRIPT_DIR/apply-nfs-existing-cluster.sh"

log_success "Kind 已就绪，可直接部署应用（本终端已设置 KUBECONFIG）"
log_info "新开终端时请先运行连接管理器或: export KUBECONFIG=$KIND_KUBECONFIG"
