#!/usr/bin/env bash
# 按 components-images 清单导出缺失的离线镜像 tar，并可选同步到集群节点。
set -euo pipefail

export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/packages.conf"

COMPONENT_IMAGES_DIR="${COMPONENT_IMAGES_DIR:-$K8S_ROOT/utils/components-images}"
IMAGE_DIR="${IMAGE_DIR:-$HOME/packages-to-be-installed/images}"
SYNC_TO_NODES=false
DRY_RUN=false
COMPONENTS=()

usage() {
    cat <<'EOF'
用法:
  export-component-image-tars.sh [选项] <component> [component2 ...]

选项:
  --all-object-storage   等价于 object-storage
  --sync-nodes           导出后 rsync 缺失 tar 到 packages.conf 中配置的所有节点
  --dry-run              只检查/打印，不 pull/save/sync
  -h, --help             显示帮助

示例:
  ./export-component-image-tars.sh object-storage
  ./export-component-image-tars.sh object-storage --sync-nodes
  CLUSTER=C1 ./export-component-image-tars.sh object-storage --sync-nodes
EOF
}

log() { echo "[export-tars] $(date '+%H:%M:%S') $*"; }

_safe_image_name() {
    echo "$1" | sed 's#[/:]#_#g'
}

_find_local_tar() {
    local img_ref="$1"
    local dir="$2"
    local safe candidate
    safe="$(_safe_image_name "$img_ref")"
    for candidate in \
        "$dir/${img_ref}.tar" \
        "$dir/${safe}.tar" \
        "$dir/${img_ref}.tar.gz" \
        "$dir/${safe}.tar.gz"; do
        [[ -f "$candidate" ]] && { echo "$candidate"; return 0; }
    done
    return 1
}

export_one_image() {
    local img_ref="$1"
    local existing tar_path safe_name

    if existing=$(_find_local_tar "$img_ref" "$IMAGE_DIR"); then
        log "已存在，跳过: $(basename "$existing")"
        return 0
    fi

    safe_name="$(_safe_image_name "$img_ref")"
    tar_path="$IMAGE_DIR/${safe_name}.tar"

    if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] 将导出: $img_ref -> $(basename "$tar_path")"
        return 0
    fi

    mkdir -p "$IMAGE_DIR"
    log "拉取: $img_ref"
    docker pull "$img_ref"
    log "保存: $tar_path"
    docker save -o "$tar_path" "$img_ref"
    log "完成: $(basename "$tar_path") ($(du -h "$tar_path" | cut -f1))"
}

read_component_images() {
    local component="$1"
    local list_file="$COMPONENT_IMAGES_DIR/${component}-images.txt"
    [[ -f "$list_file" ]] || { log "缺少清单: $list_file"; return 1; }
    sed '/^\s*#/d;/^\s*$/d' "$list_file"
}

export_component() {
    local component="$1"
    local img
    log "处理组件: $component"
    while IFS= read -r img; do
        [[ -z "$img" ]] && continue
        export_one_image "$img"
    done < <(read_component_images "$component")
}

sync_missing_tars_to_nodes() {
    local component="$1"
    local img tar_path safe host user port secret pass rdir ssh_opts

    [[ "$DRY_RUN" == true ]] && { log "[dry-run] 跳过节点同步"; return 0; }

    local idx=0
    while true; do
        idx=$((idx + 1))
        host_var="SERVER_${idx}_PUBLIC_IP"
        [[ -n "${!host_var:-}" ]] || break

        eval "host=\${SERVER_${idx}_PUBLIC_IP}"
        eval "user=\${SERVER_${idx}_USER:-root}"
        eval "port=\${SERVER_${idx}_SSH_PORT:-22}"
        eval "secret=\${SERVER_${idx}_SECRET:-}"
        eval "pass=\${SERVER_${idx}_PASS:-}"
        eval "rdir=\${SERVER_${idx}_DIR:-~/packages-to-be-installed}"

        ssh_opts=(-o StrictHostKeyChecking=no -o LogLevel=ERROR -p "$port")
        [[ -n "$secret" && -f "$secret" ]] && ssh_opts=(-i "$secret" "${ssh_opts[@]}")

        log "同步到节点 $idx ($user@$host)..."
        while IFS= read -r img; do
            [[ -z "$img" ]] && continue
            tar_path=$(_find_local_tar "$img" "$IMAGE_DIR" || true)
            [[ -n "$tar_path" ]] || continue
            rsync -az "${ssh_opts[@]}" "$tar_path" "$user@$host:${rdir}/images/"
        done < <(read_component_images "$component")
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sync-nodes) SYNC_TO_NODES=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --all-object-storage) COMPONENTS+=(object-storage); shift ;;
        -h|--help) usage; exit 0 ;;
        --*) log "未知选项: $1"; usage; exit 1 ;;
        *) COMPONENTS+=("$1"); shift ;;
    esac
done

[[ ${#COMPONENTS[@]} -gt 0 ]] || { usage; exit 1; }

for component in "${COMPONENTS[@]}"; do
    export_component "$component"
    if [[ "$SYNC_TO_NODES" == true ]]; then
        sync_missing_tars_to_nodes "$component"
    fi
done

log "全部完成"
