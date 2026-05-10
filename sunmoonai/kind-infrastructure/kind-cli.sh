#!/usr/bin/env bash
# 供 kind-infrastructure 下各脚本 source：保证 kind 在 PATH 中（与 k8s/utils/prepend-dev-cli-path 一致）
# 用法：source "${SCRIPT_DIR}/kind-cli.sh" 后调用 prepend_kind_to_path_if_needed

_KIND_INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_K8S_ROOT="$(cd "${_KIND_INFRA_DIR}/../.." && pwd)"
# shellcheck source=../../utils/prepend-dev-cli-path.sh
source "${_K8S_ROOT}/utils/prepend-dev-cli-path.sh"

prepend_kind_to_path_if_needed() {
    prepend_dev_cli_to_path
    if command -v kind &>/dev/null; then
        return 0
    fi
    local p
    for p in "${HOME}/.local/bin/kind" /usr/local/bin/kind; do
        if [[ -x "$p" ]]; then
            export PATH="$(dirname "$p"):${PATH}"
            return 0
        fi
    done
    return 1
}

# -----------------------------------------------------------------------------
# Kind 节点 containerd (k8s.io) 导入：与 load-kind-images 中「docker save + ctr import」兜底同源。
# 解决部分镜像 kind load docker-image 报 content digest not found 等问题（如部分 Bitnami OCI 层）。
# -----------------------------------------------------------------------------

# 将 docker save 生成的 OCI tar（文件路径）导入集群全部节点的 k8s.io 命名空间。
# 参数：$1=tar 路径，$2=kind 集群名（默认 kind）
kind_ctr_import_tar_to_all_nodes() {
    local tar_path="$1"
    local cluster_name="${2:-kind}"
    if [[ ! -f "$tar_path" ]]; then
        echo "⚠️  tar 不存在: $tar_path" >&2
        return 1
    fi
    prepend_kind_to_path_if_needed || true
    local nodes
    nodes=$(kind get nodes --name "$cluster_name" -o name 2>/dev/null | sed 's|node/||')
    if [[ -z "$nodes" ]]; then
        nodes=$(kind get nodes --name "$cluster_name" 2>/dev/null | sed 's|node/||')
    fi
    if [[ -z "$nodes" ]]; then
        echo "⚠️  未能获取 Kind 集群 $cluster_name 的节点列表" >&2
        return 1
    fi
    local tar_hash stamp_dir="/var/lib/kind-image-stamps"
    tar_hash=$(sha256sum "$tar_path" 2>/dev/null | awk '{print $1}')
    local ok=0 total_nodes
    total_nodes=$(echo "$nodes" | sed '/^$/d' | wc -l)
    for node in $nodes; do
        [[ -z "$node" ]] && continue
        if [[ -n "$tar_hash" ]] && docker exec "$node" test -f "${stamp_dir}/${tar_hash}" 2>/dev/null; then
            ((ok++)) || true
            continue
        fi
        if cat "$tar_path" | docker exec -i "$node" ctr -n k8s.io images import --digests --snapshotter=overlayfs - 2>/dev/null; then
            if [[ -n "$tar_hash" ]]; then
                docker exec "$node" mkdir -p "$stamp_dir" 2>/dev/null || true
                docker exec "$node" sh -c "touch '${stamp_dir}/${tar_hash}'" 2>/dev/null || true
            fi
            ((ok++)) || true
        else
            echo "⚠️  节点 $node ctr import 失败: $tar_path" >&2
        fi
    done
    if [[ $ok -eq $total_nodes && $total_nodes -gt 0 ]]; then
        return 0
    fi
    return 1
}

# 宿主机 docker 已有镜像引用 → docker save → 各节点 ctr import（kind load 失败时的可靠兜底）
kind_docker_save_and_ctr_import_all_nodes() {
    local image_ref="$1"
    local cluster_name="${2:-kind}"
    local tf
    tf=$(mktemp /tmp/kind-ctr-import-XXXXXX.tar)
    if ! docker save -o "$tf" "$image_ref" 2>/dev/null; then
        echo "⚠️  docker save 失败: $image_ref" >&2
        rm -f "$tf"
        return 1
    fi
    local rc=0
    kind_ctr_import_tar_to_all_nodes "$tf" "$cluster_name" || rc=1
    rm -f "$tf"
    return $rc
}
