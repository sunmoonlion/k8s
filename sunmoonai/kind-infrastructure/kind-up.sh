#!/usr/bin/env bash
#
# 一键：创建 Kind 集群 + 平台初始化（仅命名空间）。
# 存储：默认 KIND_PV_STORAGE_MODE=native，PV 数据在 WSL 发行版内 KIND_PV_HOST_PATH（见 deploy-kind.conf）；
# 可选 vhd 模式使用独立盘挂载。数据目录通过 kind-cluster.yaml extraMounts 挂入 worker。
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

# shellcheck source=kind-cli.sh
source "${SCRIPT_DIR}/kind-cli.sh"

ensure_kind_cli() {
    if prepend_kind_to_path_if_needed; then
        return 0
    fi
    log_error "未找到 kind 命令（创建 Kind 集群需要安装 Kind CLI）。"
    log_error "安装示例：mkdir -p ~/.local/bin && curl -fsSL -o ~/.local/bin/kind 'https://github.com/kubernetes-sigs/kind/releases/download/v0.27.0/kind-linux-amd64' && chmod +x ~/.local/bin/kind"
    log_error "并确保 ~/.local/bin 在 PATH 中（可写入 ~/.zshrc：export PATH=\"\$HOME/.local/bin:\$PATH\"）。"
    exit 1
}

# 从 deploy-kind.conf 读取 PV 存储模式（环境变量已设置时不覆盖）
read_deploy_kind_pv_storage() {
    local f="${SCRIPT_DIR}/deploy-kind/deploy-kind.conf"
    if [[ ! -f "$f" ]]; then
        KIND_PV_STORAGE_MODE="${KIND_PV_STORAGE_MODE:-native}"
        KIND_PV_HOST_PATH="${KIND_PV_HOST_PATH:-/data/kind-local-storage}"
        return 0
    fi
    if [[ ! -v KIND_PV_STORAGE_MODE ]]; then
        local fm
        fm=$(grep -E '^KIND_PV_STORAGE_MODE=' "$f" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d ' "' || true)
        KIND_PV_STORAGE_MODE="${fm:-native}"
    fi
    if [[ ! -v KIND_PV_HOST_PATH ]]; then
        local fp
        fp=$(grep -E '^KIND_PV_HOST_PATH=' "$f" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d ' "' || true)
        KIND_PV_HOST_PATH="${fp:-/data/kind-local-storage}"
    fi
}

ensure_storage_check_hook_installed() {
    local hook_script="$SCRIPT_DIR/deploy-kind/check-storage-mounts.sh"
    local zshrc="$HOME/.zshrc"
    local begin_tag="# >>> kind storage check >>>"
    local end_tag="# <<< kind storage check <<<"

    if [[ ! -x "$hook_script" ]]; then
        log_warn "未找到可执行检查脚本: $hook_script，跳过 zsh 钩子安装"
        return 0
    fi

    if [[ ! -f "$zshrc" ]]; then
        touch "$zshrc"
    fi

    if grep -qF "$begin_tag" "$zshrc"; then
        return 0
    fi

    {
        echo ""
        echo "$begin_tag"
        echo "if [[ \$- == *i* ]] && [[ -x \"$hook_script\" ]]; then"
        echo "  \"$hook_script\" || true"
        echo "fi"
        echo "$end_tag"
    } >> "$zshrc"

    log_info "已写入挂载检查钩子到 ~/.zshrc（新终端生效）"
}

# 存储守门：native 仅确保目录存在；vhd 校验独立盘挂载（旧方案）
ensure_storage_mounts_ready() {
    read_deploy_kind_pv_storage

    if [[ "${KIND_PV_STORAGE_MODE:-native}" == "native" ]]; then
        local mp="${KIND_PV_HOST_PATH:-/data/kind-local-storage}"
        log_info "存储模式 native：准备 PV 宿主目录 $mp（与 WSL 发行版同盘，无独立 vhdx）"
        if ! sudo mkdir -p "$mp"; then
            log_error "无法创建目录 $mp"
            return 1
        fi
        sudo chmod 777 "$mp" 2>/dev/null || true
        if ! sudo test -w "$mp"; then
            log_error "目录不可写: $mp"
            return 1
        fi
        log_success "native 存储就绪：$mp"
        return 0
    fi

    local docker_mp="/mnt/docker-ext4"
    local pv_mp="/mnt/pv-kind-ext4"
    local bind_mp="${KIND_PV_HOST_PATH:-/data/kind-local-storage}"

    local docker_uuid pv_uuid
    docker_uuid=$(awk '!/^[[:space:]]*#/ && $2=="/mnt/docker-ext4" && $1 ~ /^UUID=/{sub(/^UUID=/,"",$1); print $1; exit}' /etc/fstab 2>/dev/null || true)
    pv_uuid=$(awk '!/^[[:space:]]*#/ && $2=="/mnt/pv-kind-ext4" && $1 ~ /^UUID=/{sub(/^UUID=/,"",$1); print $1; exit}' /etc/fstab 2>/dev/null || true)

    if [[ -z "$docker_uuid" || -z "$pv_uuid" ]]; then
        log_error "vhd 模式：未在 /etc/fstab 找到 $docker_mp 或 $pv_mp 的 UUID（若已改 native，请在 deploy-kind.conf 设 KIND_PV_STORAGE_MODE=native）"
        return 1
    fi

    local docker_dev pv_dev docker_src pv_src bind_src
    docker_dev=$(blkid -U "$docker_uuid" 2>/dev/null || true)
    pv_dev=$(blkid -U "$pv_uuid" 2>/dev/null || true)

    if [[ -z "$docker_dev" || -z "$pv_dev" ]]; then
        log_error "未找到 fstab UUID 对应块设备（VHD 可能未 attach）"
        log_error "请先在 Windows 管理员 PowerShell 执行 wsl --mount，再回 WSL 执行 mount -a"
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

    log_success "vhd 挂载检查通过：Docker=$docker_src, PV=$pv_src, bind=$bind_src"
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

read_deploy_kind_pv_storage
PV_DATA_ROOT="${KIND_PV_HOST_PATH:-/data/kind-local-storage}"

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
    # 注意：bash 的 rm "$dir"/* 不会删除以 . 开头的隐藏文件（如 .user_scripts_initialized），
    # 会导致「日志显示已清理但数据仍在」。用 find -mindepth 1 -delete 递归清空各子目录内容。
    for subdir in "$PV_DATA_ROOT"/*/; do
        [[ -d "$subdir" ]] || continue
        local comp_name
        comp_name=$(basename "$subdir")
        if sudo find "${subdir%/}" -mindepth 1 -delete 2>/dev/null; then
            log_info "  已清理 $comp_name"
        else
            log_warn "  清理 $comp_name 失败（可忽略，权限不足时手动: sudo find $subdir -mindepth 1 -delete）"
        fi
    done
    # 历史 local-path 若曾把卷落在 hostPath 根下（pvc-* 目录），一并清掉
    for pvc_dir in "$PV_DATA_ROOT"/pvc-*/; do
        [[ -d "$pvc_dir" ]] || continue
        local pvc_name
        pvc_name=$(basename "$pvc_dir")
        if sudo rm -rf "${pvc_dir:?}" 2>/dev/null; then
            log_info "  已删除遗留动态卷目录 $pvc_name"
        fi
    done
    sudo chmod -R 777 "$PV_DATA_ROOT" 2>/dev/null || true
    # Harbor 静态 hostPath 空目录默认 root:root，Bitnami PG/Redis(uid=1001) 会 Permission denied
    sudo mkdir -p "$PV_DATA_ROOT/harbor"/{registry,database,redis,jobservice}
    sudo chown -R 1001:1001 "$PV_DATA_ROOT/harbor" 2>/dev/null || true
    log_success "PV 数据已清理，组件将全量初始化"
}

# 创建 Kind 集群（使用同目录 kind-cluster.yaml）
create_kind_cluster() {
    ensure_kind_cli
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

configure_kind_node_runtime() {
    local node
    local inotify_instances="${KIND_INOTIFY_MAX_USER_INSTANCES:-8192}"
    local inotify_watches="${KIND_INOTIFY_MAX_USER_WATCHES:-1048576}"

    log_info "初始化 Kind 节点运行时：清理非法 DNS search 条目并提高 inotify 限额"
    while IFS= read -r node; do
        [[ -n "$node" ]] || continue
        if ! docker exec "$node" sh -c "
            awk '
                /^search[[:space:]]/ {
                    line = \"search\"
                    for (i = 2; i <= NF; i++) {
                        if (\$i !~ /\\//) {
                            line = line \" \" \$i
                        }
                    }
                    if (line != \"search\") {
                        print line
                    }
                    next
                }
                { print }
            ' /etc/resolv.conf > /tmp/resolv.conf.clean &&
            cat /tmp/resolv.conf.clean > /etc/resolv.conf &&
            sysctl -w \
                fs.inotify.max_user_instances=$inotify_instances \
                fs.inotify.max_user_watches=$inotify_watches >/dev/null
        "; then
            log_error "Kind 节点运行时初始化失败: $node"
            return 1
        fi
        log_info "  已初始化 $node"
    done < <(kind get nodes --name "$KIND_CLUSTER_NAME")
    log_success "Kind 节点运行时初始化完成"
}

ensure_storage_check_hook_installed

log_info "0/3 存储检查（native：目录就绪；vhd：独立盘挂载）"
ensure_storage_mounts_ready

log_info "1/3 创建 Kind 集群（已存在则跳过）"
create_kind_cluster
configure_kind_node_runtime

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
