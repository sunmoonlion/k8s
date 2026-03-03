#!/usr/bin/env bash
#
# 将镜像或 tar 推送到 Harbor。
# - 镜像列表：从 --img-file / conf 的 DEFAULT_IMAGE_FILES 读取，docker pull 后 tag 为 Harbor 地址并 push。
# - tar 目录：从 --tar-dir / conf 的 DEFAULT_TAR_DIR 读取，对每个 .tar docker load 后解析镜像名再 tag 并 push。
# 与 load-kind-images、build-kind-node-image 一致：支持「镜像列表文件」与「tar 目录」两种来源，可同时使用。
#
# 无参数时使用 conf 中 DEFAULT_IMAGE_FILES 与 DEFAULT_TAR_DIR；指定 --img-file/--tar-dir 后仅使用本次指定（可逗号分隔多个）。
# 使用前请先登录：docker login <HARBOR_HOST>
#
# 用法见本目录 README.md 或 ./push-images-to-harbor.sh --help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/push-images-to-harbor.conf"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

load_conf() {
    HARBOR_HOST="harbor.sunmoonai.com:30443"
    HARBOR_PROJECT="k8s-images"
    DEFAULT_IMAGE_FILES=""
    DEFAULT_TAR_DIR=""
    if [[ -f "$CONF_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONF_FILE"
    fi
}

usage() {
    echo "用法: $0 [选项]"
    echo "  无参数：使用 conf 中 HARBOR_*、DEFAULT_IMAGE_FILES、DEFAULT_TAR_DIR"
    echo "  指定 --img-file/--tar-dir 后，仅使用本次指定的内容，不再读 conf 默认。"
    echo ""
    echo "选项:"
    echo "  --img-file FILE  镜像列表文件（一行一个镜像名，# 注释），多个文件用逗号分隔"
    echo "  --tar-dir DIR    推送该目录内所有 .tar 中的镜像，多个目录用逗号分隔"
    echo "  -h, --help       显示此帮助"
    echo ""
    echo "环境变量: HARBOR_HOST HARBOR_PROJECT DRY_RUN(1 仅打印不推送)"
}

IMAGE_LIST=()
IMG_FILES=()
TAR_DIRS=()
DRY_RUN="${DRY_RUN:-0}"

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
                IFS="," read -r -a __tmp <<< "${2}"
                for __f in "${__tmp[@]}"; do
                    __f=$(echo "$__f" | tr -d ' \t')
                    [[ -n "${__f}" ]] && IMG_FILES+=("$__f")
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
                IFS="," read -r -a __tmp <<< "${2}"
                for __d in "${__tmp[@]}"; do
                    __d=$(echo "$__d" | tr -d ' \t')
                    [[ -n "${__d}" ]] && TAR_DIRS+=("$__d")
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

load_conf

# 无参时：从 conf 读默认（镜像列表文件 + tar 目录）
if [[ ${#IMG_FILES[@]} -eq 0 && ${#TAR_DIRS[@]} -eq 0 ]]; then
    if [[ -n "${DEFAULT_IMAGE_FILES:-}" ]]; then
        for f in ${DEFAULT_IMAGE_FILES}; do
            f=$(echo "$f" | tr -d ' \t')
            [[ -z "$f" ]] && continue
            [[ "$f" == /* ]] && IMG_FILES+=("$f") || IMG_FILES+=("${SCRIPT_DIR}/$f")
        done
    fi
    if [[ -n "${DEFAULT_TAR_DIR:-}" ]]; then
        local_tar_dir="${SCRIPT_DIR}/${DEFAULT_TAR_DIR}"
        [[ "$DEFAULT_TAR_DIR" == /* ]] && local_tar_dir="$DEFAULT_TAR_DIR"
        [[ -d "$local_tar_dir" ]] && TAR_DIRS+=("$local_tar_dir")
    fi
fi

# 从镜像列表文件读取镜像名（与 load-kind-images 一致：跳过空行与 # 注释）
for f in "${IMG_FILES[@]}"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line; do
        line="${line%%#*}"
        line=$(echo "$line" | tr -d ' \t\r')
        [[ -n "$line" ]] && IMAGE_LIST+=("$line")
    done < "$f"
done

# 收集所有 .tar（与 load-kind-images 一致：每目录 maxdepth 1，再排序）
TAR_LIST=()
for dir in "${TAR_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' t; do
        TAR_LIST+=("$t")
    done < <(find "$dir" -maxdepth 1 -type f -name '*.tar' -print0 2>/dev/null | sort -z)
done

if [[ ${#IMAGE_LIST[@]} -eq 0 && ${#TAR_LIST[@]} -eq 0 ]]; then
    log_error "未指定任何镜像来源，请设置 conf 中 DEFAULT_IMAGE_FILES 或 DEFAULT_TAR_DIR，或使用 --img-file/--tar-dir"
    usage
    exit 1
fi

push_one() {
    local img="$1"
    local repo_tag="${img#*/}"
    [[ "$repo_tag" == "$img" ]] && repo_tag="$img"
    local dest="${HARBOR_HOST}/${HARBOR_PROJECT}/${repo_tag}"
    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "[dry-run] tag $img -> $dest && push"
        return 0
    fi
    docker tag "$img" "$dest"
    docker push "$dest"
    log_success "pushed $dest"
}

count=0

# 1) 镜像列表：pull 后 tag 并 push
if [[ ${#IMAGE_LIST[@]} -gt 0 ]]; then
    log_info "从镜像列表拉取并推送 ${#IMAGE_LIST[@]} 个镜像"
    for img in "${IMAGE_LIST[@]}"; do
        if docker pull "$img" 2>/dev/null; then
            push_one "$img"
            ((count++)) || true
        else
            log_warn "docker pull 失败（跳过）: $img"
        fi
    done
fi

# 2) tar 目录：load 后解析镜像名并 push
for tar_path in "${TAR_LIST[@]}"; do
    log_info "加载并推送: $tar_path"
    while IFS= read -r line; do
        if [[ "$line" =~ Loaded\ image:\ (.+) ]]; then
            push_one "${BASH_REMATCH[1]}"
            ((count++)) || true
        fi
    done < <(docker load -i "$tar_path" 2>&1)
done

if [[ $count -eq 0 ]]; then
    log_warn "未推送任何镜像（镜像列表拉取失败或 tar 中无镜像）"
    exit 1
fi
log_success "共推送 $count 个镜像到 ${HARBOR_HOST}/${HARBOR_PROJECT}"
