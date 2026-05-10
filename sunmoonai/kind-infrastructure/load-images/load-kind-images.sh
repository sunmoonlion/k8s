#!/usr/bin/env bash
#
# 将镜像或 tar 加载到 Kind 集群所有节点。
# - 镜像：docker pull 后 kind load（失败则兜底 save + 各节点 ctr import）
# - tar：直接将 tar 导入各节点 ctr。
# 镜像来源：--img-file（镜像列表文件）。tar 来源：仅目录（conf 的 DEFAULT_TAR_DIR 或 --tar-dir）。
# 无参数时使用 conf 默认；指定任意参数后不再使用 conf 默认（仅使用本次指定的内容）。
#
# 用法见同目录 README.md 或 ./load-kind-images.sh --help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/load-kind-images.conf"
K8S_ADMIN_CONF="${SCRIPT_DIR}/../../../utils/k8s-admin.conf"
INFRA_CONF="${SCRIPT_DIR}/../../infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf"
# shellcheck source=../kind-cli.sh
source "${SCRIPT_DIR}/../kind-cli.sh"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

read_kind_config() {
    if [[ ! -f "$K8S_ADMIN_CONF" ]]; then
        KIND_CLUSTER_NAME=kind
        return
    fi
    local section
    section=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$K8S_ADMIN_CONF")
    KIND_CLUSTER_NAME=$(echo "$section" | grep "^cluster_name=" | head -1 | cut -d'=' -f2- | tr -d ' ')
    KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-kind}
}

# 从 conf 读取默认列表与可选 KIND_CLUSTER_NAME（覆盖 read_kind_config）
load_conf() {
    DEFAULT_IMAGE_FILES=""
    DEFAULT_TAR_DIR=""
    if [[ -f "$CONF_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONF_FILE"
    fi
}

# 将单个 tar 导入集群所有节点
load_tar_to_kind_nodes() {
    local tar_path="$1"
    if [[ ! -f "$tar_path" ]]; then
        log_warn "tar 不存在: $tar_path"
        return 1
    fi
    local nodes
    # 兼容旧版 kind：部分版本不支持 "kind get nodes -o name"
    nodes=$(kind get nodes --name "$KIND_CLUSTER_NAME" -o name 2>/dev/null | sed 's|node/||')
    if [[ -z "$nodes" ]]; then
        nodes=$(kind get nodes --name "$KIND_CLUSTER_NAME" 2>/dev/null | sed 's|node/||')
    fi
    if [[ -z "$nodes" ]]; then
        log_warn "未能获取 Kind 集群 $KIND_CLUSTER_NAME 的节点列表，跳过 tar: $tar_path"
        return 1
    fi
    # 为每个 tar 计算唯一 hash，用于在节点内做幂等标记
    local tar_hash
    tar_hash=$(sha256sum "$tar_path" 2>/dev/null | awk '{print $1}')
    local stamp_dir="/var/lib/kind-image-stamps"
    local ok=0
    local total_nodes
    total_nodes=$(echo "$nodes" | sed '/^$/d' | wc -l)
    for node in $nodes; do
        [[ -z "$node" ]] && continue
        if [[ -n "$tar_hash" ]]; then
            if docker exec "$node" test -f "${stamp_dir}/${tar_hash}" 2>/dev/null; then
                log_info "节点 $node 已导入过该 tar（hash=$tar_hash），跳过: $tar_path"
                ((ok++)) || true
                continue
            fi
        fi
        if cat "$tar_path" | docker exec -i "$node" ctr -n k8s.io images import --digests --snapshotter=overlayfs - 2>/dev/null; then
            if [[ -n "$tar_hash" ]]; then
                docker exec "$node" mkdir -p "$stamp_dir" 2>/dev/null || true
                docker exec "$node" sh -c "touch '${stamp_dir}/${tar_hash}'" 2>/dev/null || true
            fi
            ((ok++)) || true
        else
            log_warn "节点 $node 导入失败: $tar_path"
        fi
    done
    if [[ $ok -eq $total_nodes && $total_nodes -gt 0 ]]; then
        return 0
    fi
    return 1
}

fallback_load_image_to_kind() {
    local img="$1"
    local tar_file
    tar_file=$(mktemp -u /tmp/kind-load-fallback-XXXXXX.tar)
    if ! docker save -o "$tar_file" "$img" 2>/dev/null; then
        log_warn "兜底失败: docker save 失败: $img"
        rm -f "$tar_file"
        return 1
    fi
    if load_tar_to_kind_nodes "$tar_file"; then
        rm -f "$tar_file"
        return 0
    fi
    rm -f "$tar_file"
    return 1
}

# 从文件读行到数组，跳过空行和 # 注释
read_list_file() {
    local f="$1"
    local list=()
    if [[ -f "$f" ]]; then
        while IFS= read -r line; do
            line="${line%%#*}"
            line=$(echo "$line" | tr -d ' \t\r')
            [[ -n "$line" ]] && list+=("$line")
        done < "$f"
    fi
    printf '%s\n' "${list[@]}"
}

usage() {
    echo "用法: $0 [选项]"
    echo "  无参数：使用 conf 中 DEFAULT_IMAGE_FILES + DEFAULT_TAR_DIR 目录内全部 .tar"
    echo "  指定任意参数后，仅使用本次指定的内容，不再读取 conf 默认。"
    echo ""
    echo "选项:"
    echo "  --img-file FILE  镜像列表文件（一行一个镜像名），多个文件用逗号分隔"
    echo "  --tar-dir DIR    加载该目录内所有 .tar 文件，多个目录用逗号分隔"
    echo "  -h, --help       显示此帮助"
}

IMAGE_LIST=()
TAR_LIST=()
IMG_FILES=()
TAR_DIRS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --img-file)
            if [[ ${#IMG_FILES[@]} -ne 0 ]]; then
                log_error "--img-file 只能指定一次，请用逗号分隔多个文件"
                usage
                exit 1
            fi
            if [[ -n "${2:-}" ]]; then
                IFS="," read -r -a __tmp_img <<< "${2}"
                for __f in "${__tmp_img[@]}"; do
                    [[ -n "${__f}" ]] && IMG_FILES+=("${__f}")
                done
                shift
            fi
            shift
            ;;
        --tar-dir)
            if [[ ${#TAR_DIRS[@]} -ne 0 ]]; then
                log_error "--tar-dir 只能指定一次，请用逗号分隔多个目录"
                usage
                exit 1
            fi
            if [[ -n "${2:-}" ]]; then
                IFS="," read -r -a __tmp_dir <<< "${2}"
                for __d in "${__tmp_dir[@]}"; do
                    [[ -n "${__d}" ]] && TAR_DIRS+=("${__d}")
                done
                shift
            fi
            shift
            ;;
        *)
            log_error "不支持的位置参数或未知选项: $1"
            usage
            exit 1
            ;;
    esac
done

read_kind_config
load_conf

prepend_kind_to_path_if_needed || true
if ! kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
    log_error "Kind 集群 ${KIND_CLUSTER_NAME} 不存在，请先执行 ../kind-up.sh 创建集群"
    exit 1
fi

# 无任何输入时：从 conf 读默认（镜像列表文件 + tar 目录）
if [[ ${#IMAGE_LIST[@]} -eq 0 && ${#IMG_FILES[@]} -eq 0 && ${#TAR_DIRS[@]} -eq 0 ]]; then
    if [[ -f "$CONF_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONF_FILE"
        for f in ${DEFAULT_IMAGE_FILES:-}; do
            [[ -n "$f" ]] && IMG_FILES+=("${SCRIPT_DIR}/$f")
        done
        if [[ -n "${DEFAULT_TAR_DIR:-}" ]]; then
            local_tar_dir="${SCRIPT_DIR}/${DEFAULT_TAR_DIR}"
            [[ "$DEFAULT_TAR_DIR" == /* ]] && local_tar_dir="$DEFAULT_TAR_DIR"
            [[ -d "$local_tar_dir" ]] && TAR_DIRS+=("$local_tar_dir")
        fi
    fi
fi

# --tar-dir：将指定目录内所有 .tar 加入 TAR_LIST
for dir in "${TAR_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' t; do
        TAR_LIST+=("$t")
    done < <(find "$dir" -maxdepth 1 -type f -name '*.tar' -print0 2>/dev/null | sort -z)
done

# 从 --img-file 指明的文件中读取镜像名（支持多个文件）
for f in "${IMG_FILES[@]}"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line; do
        line="${line%%#*}"
        line=$(echo "$line" | tr -d ' \t\r')
        [[ -n "$line" ]] && IMAGE_LIST+=("$line")
    done < "$f"
done

ok=0
fail=0

# 1) 加载 tar
if [[ ${#TAR_LIST[@]} -gt 0 ]]; then
    log_info "加载 ${#TAR_LIST[@]} 个 tar 到集群 ${KIND_CLUSTER_NAME}"
    for tar_path in "${TAR_LIST[@]}"; do
        if load_tar_to_kind_nodes "$tar_path"; then
            log_success "已加载 tar: $tar_path"
            ((ok++)) || true
        else
            log_warn "tar 加载失败: $tar_path"
            ((fail++)) || true
        fi
    done
fi

# 2) 加载镜像
if [[ ${#IMAGE_LIST[@]} -gt 0 ]]; then
    log_info "拉取并加载 ${#IMAGE_LIST[@]} 个镜像到集群 ${KIND_CLUSTER_NAME}"
    for img in "${IMAGE_LIST[@]}"; do
        if docker pull "$img" 2>/dev/null; then
            if kind load docker-image "$img" --name "$KIND_CLUSTER_NAME" 2>/dev/null; then
                log_success "已加载: $img"
                ((ok++)) || true
            elif fallback_load_image_to_kind "$img"; then
                log_success "已加载（兜底）: $img"
                ((ok++)) || true
            else
                log_warn "kind load 与兜底均失败: $img"
                ((fail++)) || true
            fi
        else
            log_warn "docker pull 失败（跳过）: $img"
            ((fail++)) || true
        fi
    done
fi

if [[ $ok -eq 0 && $fail -eq 0 ]]; then
    log_warn "未指定任何镜像或 tar，请使用 --img-file/--tar-dir，或无参使用 conf 默认"
fi

log_info "完成: 成功 $ok, 失败/跳过 $fail"
[[ $fail -gt 0 ]] && exit 1
exit 0
