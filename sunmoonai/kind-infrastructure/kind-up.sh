#!/usr/bin/env bash
#
# 一键：创建 Kind 集群 + 平台初始化（仅命名空间）。
# 存储使用 Kind 内置 local-path-provisioner（SC 名：local-path），数据目录通过 extraMounts 持久化到 WSL 宿主机。
# 使用 k8s-admin.conf 中 [KIND] 的 cluster_name、kubeconfig；集群配置固定使用 deploy-kind/kind-cluster.yaml。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ADMIN_CONF="${SCRIPT_DIR}/../../utils/k8s-admin.conf"
DEFAULT_CONFIG="${SCRIPT_DIR}/deploy-kind/kind-cluster.yaml"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

# 从 k8s-admin.conf 读取 [KIND] 段
read_kind_config() {
    if [[ ! -f "$K8S_ADMIN_CONF" ]]; then
        KIND_CLUSTER_NAME=kind
        KIND_KUBECONFIG="${HOME}/.kube/kind-config"
        KIND_IMAGE=""
        return
    fi
    local section
    section=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$K8S_ADMIN_CONF")
    KIND_CLUSTER_NAME=$(echo "$section" | grep "^cluster_name=" | head -1 | cut -d'=' -f2- | tr -d ' ')
    KIND_KUBECONFIG=$(echo "$section" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2- | tr -d ' ')
    KIND_IMAGE=$(echo "$section" | grep "^kind_image=" | head -1 | cut -d'=' -f2- | tr -d ' ')
    KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-kind}
    KIND_KUBECONFIG="${KIND_KUBECONFIG/#\~/$HOME}"
}

# 创建 Kind 集群（使用同目录 kind-cluster.yaml）
create_kind_cluster() {
    read_kind_config
    # 从 deploy-kind.conf 读取集群重建策略（env > conf > 默认 false）
    local deploy_conf="$SCRIPT_DIR/deploy-kind/deploy-kind.conf"
    if [[ -z "${KIND_RECREATE_IF_EXISTS:-}" ]]; then
        if [[ -f "$deploy_conf" ]]; then
            local recreate_conf
            recreate_conf=$(grep -E '^RECREATE_KIND_CLUSTER_IF_EXISTS=' "$deploy_conf" | head -1 | cut -d'=' -f2- | tr -d ' \"')
            KIND_RECREATE_IF_EXISTS="${recreate_conf:-false}"
        else
            KIND_RECREATE_IF_EXISTS="false"
        fi
    fi
    if [[ ! -f "$DEFAULT_CONFIG" ]]; then
        log_error "未找到 Kind 配置: $DEFAULT_CONFIG"
        return 1
    fi
    if kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
        if [[ "${KIND_RECREATE_IF_EXISTS:-false}" == "true" ]]; then
            log_warn "集群 $KIND_CLUSTER_NAME 已存在，按配置先删除再重建（KIND_RECREATE_IF_EXISTS=true）"
            if ! kind delete cluster --name "$KIND_CLUSTER_NAME"; then
                log_error "删除 Kind 集群 $KIND_CLUSTER_NAME 失败"
                return 1
            fi
        else
            log_warn "集群 $KIND_CLUSTER_NAME 已存在，跳过创建（KIND_RECREATE_IF_EXISTS=false）"
            kind export kubeconfig --name "$KIND_CLUSTER_NAME" --kubeconfig "$KIND_KUBECONFIG"
            return 0
        fi
    fi
    log_info "使用配置文件: $DEFAULT_CONFIG"
    log_info "创建 Kind 集群: $KIND_CLUSTER_NAME"
    create_cmd="kind create cluster --name $KIND_CLUSTER_NAME --config $DEFAULT_CONFIG"
    [[ -n "$KIND_IMAGE" ]] && create_cmd="$create_cmd --image $KIND_IMAGE"
    if ! eval "$create_cmd"; then
        log_error "集群创建失败"
        return 1
    fi
    log_success "集群创建成功"
    kind export kubeconfig --name "$KIND_CLUSTER_NAME" --kubeconfig "$KIND_KUBECONFIG"
    log_info "Kubeconfig 已写入: $KIND_KUBECONFIG"
}

log_info "1/3 创建 Kind 集群（已存在则跳过）"
create_kind_cluster

read_kind_config
if [[ ! -f "$KIND_KUBECONFIG" ]]; then
    log_warn "未找到 $KIND_KUBECONFIG，跳过平台初始化"
    exit 0
fi

export KUBECONFIG="$KIND_KUBECONFIG"
log_info "2/3 KUBECONFIG=$KUBECONFIG"

log_info "3/3 平台初始化：命名空间"
"$SCRIPT_DIR/apply-namespaces-existing-cluster.sh"

log_success "Kind 已就绪，可直接部署应用（本终端已设置 KUBECONFIG）"
log_info "新开终端时请先运行连接管理器或: export KUBECONFIG=$KIND_KUBECONFIG"
