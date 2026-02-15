#!/usr/bin/env bash
#
# 创建 Kind 集群（多 worker，与 k8s-admin.conf [KIND] 一致）
# Worker 数量：环境变量 KIND_WORKER_COUNT 或第一个参数，如 KIND_WORKER_COUNT=6 或 ./create-kind-cluster.sh 6
# 未指定时使用同目录 kind-cluster.yaml（默认 2 workers）。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIND_CONFIG_YAML="${SCRIPT_DIR}/kind-cluster.yaml"
KIND_CONFIG_GENERATED=""
# k8s-admin.conf 在 k8s/utils/
K8S_ADMIN_CONF="${SCRIPT_DIR}/../../utils/k8s-admin.conf"

# Worker 数量：参数 > 环境变量 > 默认用 yaml 文件
if [[ -n "${1:-}" && "$1" =~ ^[0-9]+$ ]]; then
    KIND_WORKER_COUNT="$1"
elif [[ -n "${KIND_WORKER_COUNT:-}" && "$KIND_WORKER_COUNT" =~ ^[0-9]+$ ]]; then
    :
else
    KIND_WORKER_COUNT=""
fi

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

read_kind_config() {
    if [[ ! -f "$K8S_ADMIN_CONF" ]]; then
        log_warn "未找到 $K8S_ADMIN_CONF，使用默认集群名与 kubeconfig 路径"
        KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"
        KIND_KUBECONFIG="${KIND_KUBECONFIG:-$HOME/.kube/kind-config}"
        return
    fi
    KIND_CLUSTER_NAME=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$K8S_ADMIN_CONF" | grep "^cluster_name=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    KIND_KUBECONFIG=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$K8S_ADMIN_CONF" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"
    KIND_KUBECONFIG="${KIND_KUBECONFIG:-$HOME/.kube/kind-config}"
    KIND_KUBECONFIG="${KIND_KUBECONFIG/#\~/$HOME}"
}

check_deps() {
    if ! command -v kind &>/dev/null; then
        log_error "未安装 kind，请先安装：https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        exit 1
    fi
    if ! docker info &>/dev/null; then
        log_error "Docker 未运行，请先启动 Docker"
        exit 1
    fi
    log_success "kind $(kind version 2>/dev/null | head -1), Docker 可用"
}

build_config_yaml() {
    if [[ -z "${KIND_WORKER_COUNT:-}" ]]; then
        [[ -f "$KIND_CONFIG_YAML" ]] || { log_error "未找到集群配置: $KIND_CONFIG_YAML"; exit 1; }
        return
    fi
    KIND_CONFIG_GENERATED="${SCRIPT_DIR}/.kind-cluster-generated.yaml"
    {
        echo "kind: Cluster"
        echo "apiVersion: kind.x-k8s.io/v1alpha4"
        echo "nodes:"
        echo "  - role: control-plane"
        for ((i=0; i<KIND_WORKER_COUNT; i++)); do echo "  - role: worker"; done
    } > "$KIND_CONFIG_GENERATED"
    KIND_CONFIG_YAML="$KIND_CONFIG_GENERATED"
    log_info "Worker 数量: $KIND_WORKER_COUNT（使用生成配置）"
}

create_cluster() {
    read_kind_config
    build_config_yaml

    if kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
        log_warn "集群 $KIND_CLUSTER_NAME 已存在"
        read -rp "是否删除并重新创建? (y/N): " confirm
        if [[ "${confirm:-}" =~ ^[Yy]$ ]]; then
            kind delete cluster --name "$KIND_CLUSTER_NAME"
        else
            log_info "取消创建"
            return 0
        fi
    fi

    log_info "创建 Kind 集群: $KIND_CLUSTER_NAME（配置: $KIND_CONFIG_YAML）"
    kind create cluster --name "$KIND_CLUSTER_NAME" --config "$KIND_CONFIG_YAML"
    [[ -z "${KIND_CONFIG_GENERATED:-}" ]] || rm -f "$KIND_CONFIG_GENERATED"

    mkdir -p "$(dirname "$KIND_KUBECONFIG")"
    kind get kubeconfig --name "$KIND_CLUSTER_NAME" > "$KIND_KUBECONFIG"
    log_success "集群已创建，kubeconfig 已写入: $KIND_KUBECONFIG"
    log_info "使用: export KUBECONFIG=$KIND_KUBECONFIG"
    echo ""
    kind get nodes --name "$KIND_CLUSTER_NAME"
}

check_deps
create_cluster "$@"
