#!/usr/bin/env bash
#
# 一键：创建 Kind 集群 + 平台初始化（仅命名空间）。
# 存储使用 Kind 内置 rancher.io/local-path-provisioner（默认 SC 名为 standard；kind-up 会通过 apply-namespaces 追加别名为 local-path，与平台 Helm values 一致）。数据目录可通过 extraMounts 持久化到 WSL 宿主机。
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

# 挂载守门：防止 VHD 未挂好时把数据写回 WSL 系统盘
ensure_storage_mounts_ready() {
    local docker_mp="/mnt/docker-ext4"
    local pv_mp="/mnt/pv-kind-ext4"
    local bind_mp="/data/kind-local-storage"

    local docker_uuid pv_uuid
    docker_uuid=$(awk '!/^[[:space:]]*#/ && $2=="/mnt/docker-ext4" && $1 ~ /^UUID=/{sub(/^UUID=/,"",$1); print $1; exit}' /etc/fstab 2>/dev/null || true)
    pv_uuid=$(awk '!/^[[:space:]]*#/ && $2=="/mnt/pv-kind-ext4" && $1 ~ /^UUID=/{sub(/^UUID=/,"",$1); print $1; exit}' /etc/fstab 2>/dev/null || true)

    if [[ -z "$docker_uuid" || -z "$pv_uuid" ]]; then
        log_error "未在 /etc/fstab 找到 $docker_mp 或 $pv_mp 的 UUID 配置，拒绝继续（避免写偏到系统盘）"
        return 1
    fi

    local docker_dev pv_dev docker_src pv_src bind_src
    docker_dev=$(blkid -U "$docker_uuid" 2>/dev/null || true)
    pv_dev=$(blkid -U "$pv_uuid" 2>/dev/null || true)

    if [[ -z "$docker_dev" || -z "$pv_dev" ]]; then
        log_error "未找到 fstab UUID 对应块设备（VHD 可能未 attach）"
        log_error "请先在 Windows 管理员 PowerShell 执行两条 wsl --mount，再回 WSL 执行 mount -a"
        return 1
    fi

    docker_src=$(findmnt -n -o SOURCE "$docker_mp" 2>/dev/null || true)
    pv_src=$(findmnt -n -o SOURCE "$pv_mp" 2>/dev/null || true)
    bind_src=$(findmnt -n -o SOURCE "$bind_mp" 2>/dev/null || true)

    if [[ "$docker_src" != "$docker_dev" ]]; then
        log_error "$docker_mp 挂载异常：当前=$docker_src, 期望=$docker_dev"
        return 1
    fi
    if [[ "$pv_src" != "$pv_dev" ]]; then
        log_error "$pv_mp 挂载异常：当前=$pv_src, 期望=$pv_dev"
        return 1
    fi
    if [[ "$bind_src" != "$pv_dev" ]]; then
        log_error "$bind_mp 挂载异常：当前=$bind_src, 期望=$pv_dev"
        return 1
    fi

    log_success "挂载检查通过：Docker=$docker_src, PV=$pv_src, bind=$bind_src"
    return 0
}

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

PV_DATA_ROOT="/data/kind-local-storage"

clean_pv_data_if_configured() {
    local deploy_conf="${1:-}"
    local clean_pv="false"
    if [[ -n "${KIND_CLEAN_PV_DATA_ON_RECREATE:-}" ]]; then
        clean_pv="$KIND_CLEAN_PV_DATA_ON_RECREATE"
    elif [[ -f "$deploy_conf" ]]; then
        clean_pv=$(grep -E '^CLEAN_PV_DATA_ON_RECREATE=' "$deploy_conf" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d ' "' || true)
        clean_pv="${clean_pv:-false}"
    else
        clean_pv="false"
    fi
    if [[ "$clean_pv" != "true" ]]; then
        log_info "保留 PV 数据（CLEAN_PV_DATA_ON_RECREATE=false）"
        return 0
    fi
    if [[ ! -d "$PV_DATA_ROOT" ]]; then
        log_info "PV 数据目录不存在，跳过清理"
        return 0
    fi
    log_warn "清理 PV 持久化数据：$PV_DATA_ROOT/*（集群重建，确保组件从零初始化）"
    for subdir in "$PV_DATA_ROOT"/*/; do
        [[ -d "$subdir" ]] || continue
        local comp_name
        comp_name=$(basename "$subdir")
        if sudo rm -rf "${subdir:?}"/* 2>/dev/null; then
            log_info "  已清理 $comp_name"
        else
            log_warn "  清理 $comp_name 失败（可忽略，权限不足时手动 sudo rm -rf $subdir/*）"
        fi
    done
    sudo chmod -R 777 "$PV_DATA_ROOT" 2>/dev/null || true
    log_success "PV 数据已清理，组件将全量初始化"
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
            clean_pv_data_if_configured "$deploy_conf"
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

log_info "0/3 挂载守门检查（避免 D/E 混写）"
ensure_storage_mounts_ready

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
