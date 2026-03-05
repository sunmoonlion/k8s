#!/usr/bin/env bash
#
# 将镜像或 tar 推送到 Harbor。
# - 镜像列表（--img-file）：对每个镜像，先到 --tar-dir 指定目录按文件名找 tar（见下），找到则 load 后 push；
#   找不到或未指定 tar-dir 则 docker pull 后 push。tar 命名约定与 registry-push-management 一致：镜像名将 / : 换成 _，如 bitnami_postgresql_17.6.0-debian-12-r4.tar。
# - tar 目录（--tar-dir）：除供列表查找外，也可单独使用：对该目录内所有 .tar 执行 load 后解析镜像名并 push。
# 可同时使用 --img-file 与 --tar-dir；列表项优先从 tar-dir 查找，再 fallback 到 pull。
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

# 基本配置校验：确保 Harbor 项目已配置，避免推送到空项目路径
if [[ -z "${HARBOR_PROJECT:-}" ]]; then
    log_error "未配置 HARBOR_PROJECT：请在 push-images-to-harbor.conf 中设置 Harbor 项目名（例如 k8s-images），否则无法推送镜像。"
    exit 1
fi

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

# 镜像引用转成文件名（与 registry-push-management 一致：/ 和 : 换成 _）
find_tar_for_image() {
    local img="$1"
    local dir="$2"
    local safe; safe=$(echo "$img" | sed 's#[/:]#_#g')
    for candidate in "${dir}/${img}.tar" "${dir}/${safe}.tar" "${dir}/${img}.tar.gz" "${dir}/${safe}.tar.gz"; do
        [[ -f "$candidate" ]] && { echo "$candidate"; return 0; }
    done
    return 1
}

# 1) 镜像列表：先到 tar 目录找对应 tar（若有）load 后 push，否则 pull 后 push
if [[ ${#IMAGE_LIST[@]} -gt 0 ]]; then
    log_info "从镜像列表处理 ${#IMAGE_LIST[@]} 个镜像（优先本地 tar 目录，否则 pull）"
    for img in "${IMAGE_LIST[@]}"; do
        pushed=false
        if [[ ${#TAR_DIRS[@]} -gt 0 ]]; then
            for dir in "${TAR_DIRS[@]}"; do
                [[ -d "$dir" ]] || continue
                tar_path=""
                tar_path=$(find_tar_for_image "$img" "$dir") || true
                if [[ -n "$tar_path" && -f "$tar_path" ]]; then
                    log_info "从本地 tar 加载: $tar_path"
                    loaded_ref=""
                    while IFS= read -r line; do
                        if [[ "$line" =~ Loaded\ image:\ (.+) ]]; then
                            loaded_ref="${BASH_REMATCH[1]}"
                            break
                        fi
                    done < <(docker load -i "$tar_path" 2>&1)
                    if [[ -n "$loaded_ref" ]]; then
                        push_one "$loaded_ref"
                        ((count++)) || true
                        pushed=true
                    fi
                    break
                fi
            done
        fi
        if [[ "$pushed" != "true" ]]; then
            if docker pull "$img" 2>/dev/null; then
                push_one "$img"
                ((count++)) || true
            else
                log_warn "docker pull 失败（跳过）: $img（可放对应 tar 到 --tar-dir 目录，如 ${img}.tar 或 $(echo "$img" | sed 's#[/:]#_#g').tar）"
            fi
        fi
    done
fi

# 2) tar 目录：仅在未提供镜像列表时，遍历目录内所有 tar
if [[ ${#IMAGE_LIST[@]} -eq 0 ]]; then
    for tar_path in "${TAR_LIST[@]}"; do
        log_info "加载并推送: $tar_path"
        while IFS= read -r line; do
            if [[ "$line" =~ Loaded\ image:\ (.+) ]]; then
                push_one "${BASH_REMATCH[1]}"
                ((count++)) || true
            fi
        done < <(docker load -i "$tar_path" 2>&1)
    done
fi

if [[ $count -eq 0 ]]; then
    log_warn "未推送任何镜像（镜像列表拉取失败或 tar 中无镜像）"
    exit 1
fi
log_success "共推送 $count 个镜像到 ${HARBOR_HOST}/${HARBOR_PROJECT}"
