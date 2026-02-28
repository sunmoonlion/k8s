#!/usr/bin/env bash
#
# 将 tar 目录中的镜像全部推送到 Harbor。
# 对每个 .tar：docker load → 解析出镜像名 → tag 为 Harbor 地址 → docker push。
#
# 无参数时使用 conf 中 DEFAULT_TAR_DIR；指定 --tar-dir 后仅使用本次指定的目录（可逗号分隔多个）。
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
    DEFAULT_TAR_DIR=""
    if [[ -f "$CONF_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONF_FILE"
    fi
}

usage() {
    echo "用法: $0 [选项]"
    echo "  无参数：使用 conf 中 HARBOR_* 与 DEFAULT_TAR_DIR"
    echo "  指定 --tar-dir 后，仅使用本次指定的目录，不再读取 conf 默认 tar 目录。"
    echo ""
    echo "选项:"
    echo "  --tar-dir DIR   推送该目录内所有 .tar 中的镜像，多个目录用逗号分隔"
    echo "  -h, --help      显示此帮助"
    echo ""
    echo "环境变量: HARBOR_HOST HARBOR_PROJECT DRY_RUN(1 仅打印不推送)"
}

TAR_DIRS=()
DRY_RUN="${DRY_RUN:-0}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
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

# 无参时：使用 conf 默认 tar 目录（相对路径为相对本目录 push-to-harbor）
if [[ ${#TAR_DIRS[@]} -eq 0 ]]; then
    if [[ -n "${DEFAULT_TAR_DIR:-}" ]]; then
        local_tar_dir="${SCRIPT_DIR}/${DEFAULT_TAR_DIR}"
        [[ "$DEFAULT_TAR_DIR" == /* ]] && local_tar_dir="$DEFAULT_TAR_DIR"
        if [[ -d "$local_tar_dir" ]]; then
            TAR_DIRS+=("$local_tar_dir")
        else
            log_warn "conf 默认 tar 目录不存在: $local_tar_dir"
        fi
    fi
fi

if [[ ${#TAR_DIRS[@]} -eq 0 ]]; then
    log_error "未指定任何 tar 目录，请设置 conf 中 DEFAULT_TAR_DIR 或使用 --tar-dir <目录>"
    usage
    exit 1
fi

# 收集所有 .tar（与 load-kind-images 一致：每目录 maxdepth 1，再排序）
TAR_LIST=()
for dir in "${TAR_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' t; do
        TAR_LIST+=("$t")
    done < <(find "$dir" -maxdepth 1 -type f -name '*.tar' -print0 2>/dev/null | sort -z)
done

if [[ ${#TAR_LIST[@]} -eq 0 ]]; then
    log_error "未在任何目录中找到 .tar 文件，请检查: ${TAR_DIRS[*]}"
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
    log_warn "未从 tar 中解析到任何镜像"
    exit 1
fi
log_success "共推送 $count 个镜像到 ${HARBOR_HOST}/${HARBOR_PROJECT}"
