#!/usr/bin/env bash
set -euo pipefail
# Local/cloud hosts share this build/export path; cloud execution 未经实机验证.
# Default plan only. Real builds prepare OCI batches; publication is separate.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/build-push-app-images.conf}"
REGISTRY_MODULE="$(cd "${SCRIPT_DIR}/../../registry-platform" && pwd)"

CONFIGURABLE_VARS=(
    CLUSTER
    TAG
    TARGET_REGISTRY
    BASE_REGISTRY
    PLATFORM
    PROGRESS
    NO_CACHE
    START_FROM
    DRY_RUN
    PYPI_INDEX_URL
    DEBIAN_MIRROR
    DEBIAN_SECURITY_MIRROR
    NPM_REGISTRY
    SOURCE_ROOT
    APPS
    COMPONENTS
    ARTIFACT_ROOT
    PUBLICATION_SETTINGS
)

for var_name in "${CONFIGURABLE_VARS[@]}"; do
    if [[ -v "$var_name" ]]; then
        printf -v "ENV_OVERRIDE_${var_name}" '%s' "${!var_name}"
    fi
done

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    echo '构建配置不存在，停止。' >&2
    exit 1
fi

for var_name in "${CONFIGURABLE_VARS[@]}"; do
    override_name="ENV_OVERRIDE_${var_name}"
    if [[ -v "$override_name" ]]; then
        printf -v "$var_name" '%s' "${!override_name}"
    fi
done

CLUSTER="${CLUSTER:-${DEFAULT_CLUSTER:-KIND}}"
TAG="${TAG:-architecture-v2-dev}"
TARGET_REGISTRY="${TARGET_REGISTRY:-harbor.sunmoonai.com:30443/app-images}"
BASE_REGISTRY="${BASE_REGISTRY:-harbor.sunmoonai.com:30443/k8s-images}"
PLATFORM="${PLATFORM:-linux/amd64}"
PROGRESS="${PROGRESS:-auto}"
NO_CACHE="${NO_CACHE:-true}"
START_FROM="${START_FROM:-}"
DRY_RUN="${DRY_RUN:-true}"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-}"
PUBLICATION_SETTINGS="${PUBLICATION_SETTINGS:-${REGISTRY_MODULE}/config/build-publication.local.json}"

PYPI_INDEX_URL="${PYPI_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
DEBIAN_MIRROR="${DEBIAN_MIRROR:-http://mirrors.tuna.tsinghua.edu.cn/debian}"
DEBIAN_SECURITY_MIRROR="${DEBIAN_SECURITY_MIRROR:-http://mirrors.tuna.tsinghua.edu.cn/debian-security}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"
SOURCE_ROOT="${SOURCE_ROOT:-$(cd "${SCRIPT_DIR}/../../../.." && pwd)}"

# v2 形态：四个 App，每个三个组件（ADR-0007 把 admin-backend/web-backend
# 并成了单一 backend；research 已退役）。
read -r -a APPS <<< "${APPS:-tpl info knowledge investment}"
read -r -a COMPONENTS <<< "${COMPONENTS:-backend admin-frontend web-frontend}"

log() {
    printf '\033[0;34m[INFO]\033[0m %s\n' "$*"
}

success() {
    printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"
}

run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        printf '  '
        printf '%q ' "$@"
        printf '\n'
        return 0
    fi
    "$@"
}

# 有两个 tag 不能被本脚本覆盖，它们指向已发布、已验证的制品：
#
#   1.0.0  v1 的正式发布。tpl-app/template-release-manifest.json 的
#          release_policy.overwrite_v1_1_0_0 明确写着 false
#   2.0.0  v2 的正式发布别名。发布采用 exact-digest-alias（不重建镜像，给已过
#          R7 门禁的 digest 打别名），所以这个 tag 必须一直指向
#          历史 R7 release-manifest.json 里记的那些 digest，固定 Git 查询入口见
#          docs/project-guide/topics/v5-history.md。本脚本推上去就会覆盖已验收制品
#
# 本脚本只准备本地候选制品，不创建远端 tag；受保护名字仍拒绝。
PROTECTED_TAGS=(1.0.0 2.0.0)

assert_tag_is_not_protected() {
    local protected
    for protected in "${PROTECTED_TAGS[@]}"; do
        [[ "$TAG" == "$protected" ]] || continue
        cat >&2 <<MSG
拒绝使用受保护的候选标识: ${TAG}

  1.0.0 是 v1 正式发布（manifest 的 overwrite_v1_1_0_0: false）
  2.0.0 是 v2 正式发布别名，必须指向 R7 门禁通过的 digest

本脚本产出的是未经门禁的本地构建，不该占用发布 tag。
换一个 tag，例如：TAG=architecture-v2-dev $0
MSG
        exit 1
    done
}

build_component() {
    local app="$1"
    local component="$2"
    local key="${app}/${component}"
    local root="${SOURCE_ROOT}/${app}-app/${app}-${component}"
    local dockerfile="${root}/mybuild/Dockerfile"
    local repository="${TARGET_REGISTRY}/${app}-${component}"
    local output="${RUN_DIRECTORY}/${app}-${component}"
    local commit_before parent_commit_before
    parent_commit_before="$(source_commit "${SOURCE_ROOT}/${app}-app")"
    commit_before="$(source_commit "$root")"
    local dockerfile_sha
    dockerfile_sha="$(sha256sum "$dockerfile")"
    dockerfile_sha="${dockerfile_sha%% *}"
    local -a args=(
        docker build
        --platform "$PLATFORM"
        --progress "$PROGRESS"
        -f "$dockerfile"
        --iidfile "${output}/image-id"
        --build-arg "REGISTRY=${BASE_REGISTRY}"
    )

    [[ -d "$root" ]] || {
        echo "源码目录不存在: $root" >&2
        return 1
    }
    [[ -f "$dockerfile" ]] || {
        echo "Dockerfile 不存在: $dockerfile" >&2
        return 1
    }
    [[ "$NO_CACHE" == "true" ]] && args+=(--no-cache)

    case "$component" in
        backend)
            args+=(
                --build-arg "PYPI_INDEX_URL=${PYPI_INDEX_URL}"
                --build-arg "DEBIAN_MIRROR=${DEBIAN_MIRROR}"
                --build-arg "DEBIAN_SECURITY_MIRROR=${DEBIAN_SECURITY_MIRROR}"
            )
            ;;
        admin-frontend | web-frontend)
            args+=(
                --build-arg "NPM_CONFIG_REGISTRY=${NPM_REGISTRY}"
                --build-arg "NEXT_PUBLIC_APP_NAME=${app}"
            )
            ;;
        *)
            echo "未知组件: $component" >&2
            return 1
            ;;
    esac

    args+=("$root")

    log "===== ${key} -> ${repository}（候选标识 ${TAG}） ====="
    run mkdir -m 0700 "$output"
    run "${args[@]}"
    if [[ "$DRY_RUN" == "true" ]]; then
        printf '  构建后按 image-id 导出 docker.tar，转换 OCI，记录源码提交与 publication.json；不推送。\n'
        return
    fi
    [[ "$(source_commit "${SOURCE_ROOT}/${app}-app")" == "$parent_commit_before" && \
       "$(source_commit "$root")" == "$commit_before" ]] || {
        echo '构建期间源码提交改变；停止，保留制品用于排查。' >&2; return 1;
    }
    local image_id archive_sha
    image_id="$(cat "${output}/image-id")"
    [[ "$image_id" =~ ^sha256:[a-f0-9]{64}$ ]] || { echo '构建未返回有效 image ID' >&2; return 1; }
    local image_size
    image_size="$(docker image inspect --format '{{.Size}}' "$image_id")"
    [[ "$image_size" =~ ^[0-9]+$ ]] || { echo '无法核实镜像导出空间' >&2; return 1; }
    python3 -B - "$REGISTRY_MODULE" "$PUBLICATION_SETTINGS" "$output" "$image_size" <<'PY'
import pathlib, shutil, sys
sys.path.insert(0, sys.argv[1])
from prepare_image import settings
data = settings(pathlib.Path(sys.argv[2]))
if shutil.disk_usage(sys.argv[3]).free < 2 * int(sys.argv[4]) + data['minimum_free_gib'] * 1024**3:
    raise SystemExit('导出空间不足；保留已构建镜像，不清理任何缓存/镜像')
PY
    docker image save --output "${output}/docker.tar" "$image_id"
    archive_sha="$(sha256sum "${output}/docker.tar")"
    archive_sha="${archive_sha%% *}"
    python3 -B "${REGISTRY_MODULE}/prepare_image.py" --settings "$PUBLICATION_SETTINGS" \
        --archive "${output}/docker.tar" --archive-sha256 "$archive_sha" \
        --repository "$repository" --output-directory "${output}/oci" --apply
    [[ "$(source_commit "${SOURCE_ROOT}/${app}-app")" == "$parent_commit_before" && \
       "$(source_commit "$root")" == "$commit_before" ]] || {
        echo '制品准备期间源码发生改变，停止。' >&2; return 1;
    }
    python3 -B - "$output" "$commit_before" "$root" "$TAG" "$PLATFORM" "$image_id" "$dockerfile_sha" "$parent_commit_before" <<'PY'
import json, pathlib, sys
output, commit, context, label, platform, image_id, dockerfile_sha, parent_commit = sys.argv[1:]
with (pathlib.Path(output) / 'build.json').open('x') as stream:
    json.dump({'source_commit': commit, 'parent_commit': parent_commit,
               'source_context': context, 'candidate_label': label,
               'platform': platform, 'docker_image_id': image_id,
               'dockerfile_sha256': dockerfile_sha,
               'tracked_tree_clean': True, 'reproducibility_verified': False,
               'published': False}, stream, indent=2)
    stream.write('\n')
PY
    success "已准备 ${output}/oci/publication.json；尚未发布"
}

source_commit() {
    local repository="$1"
    local top expected changes commit
    top="$(git -C "$repository" rev-parse --show-toplevel)" || return 1
    expected="$(realpath "$repository")" || return 1
    [[ "$top" == "$expected" ]] || {
        echo '应用必须是独立 Git 仓库' >&2; return 1;
    }
    changes="$(git -C "$repository" status --porcelain --untracked-files=all --ignore-submodules=none)" || return 1
    [[ -z "$changes" ]] || {
        echo "源码仓有未提交改动：${repository}" >&2; return 1;
    }
    commit="$(git -C "$repository" rev-parse HEAD)" || return 1
    [[ "$commit" =~ ^[a-f0-9]{40,64}$ ]] || return 1
    printf '%s\n' "$commit"
}

main() {
    [[ $# == 0 ]] || { echo '本入口使用 .conf / 环境变量，不接受位置参数。' >&2; exit 1; }
    [[ "$DRY_RUN" == true || "$DRY_RUN" == false ]] || { echo 'DRY_RUN 必须为 true/false' >&2; exit 1; }
    [[ "$NO_CACHE" == true || "$NO_CACHE" == false ]] || { echo 'NO_CACHE 必须为 true/false' >&2; exit 1; }
    [[ "$CLUSTER" =~ ^(KIND|C[1-9][0-9]*)$ ]] || { echo '无效 CLUSTER' >&2; exit 1; }
    [[ "$TAG" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]] || { echo '无效候选标识 TAG' >&2; exit 1; }
    [[ "$PLATFORM" == linux/amd64 ]] || { echo '当前只准入 linux/amd64；多架构另行准备' >&2; exit 1; }
    [[ "$TARGET_REGISTRY" == harbor.sunmoonai.com:30443/app-images && \
       "$BASE_REGISTRY" == harbor.sunmoonai.com:30443/k8s-images ]] || {
        echo '请使用统一独立 Harbor 地址；不再按集群选择别名仓库。' >&2; exit 1;
    }
    local name
    for name in $(compgen -v); do
        if [[ "$name" =~ ^(KIND|C[0-9]+)_(TARGET_REGISTRY|BASE_REGISTRY|TAG)$ ]]; then
            echo "已退役的按集群构建配置：${name}；请更新配置。" >&2; exit 1
        fi
    done
    assert_tag_is_not_protected
    local app component key
    for app in "${APPS[@]}"; do
        [[ "$app" =~ ^(tpl|info|knowledge|investment)$ ]] || { echo '未知应用' >&2; exit 1; }
        for component in "${COMPONENTS[@]}"; do
            [[ "$component" =~ ^(backend|admin-frontend|web-frontend)$ ]] || { echo '未知组件' >&2; exit 1; }
            [[ -f "${SOURCE_ROOT}/${app}-app/${app}-${component}/mybuild/Dockerfile" ]] || {
                echo "Dockerfile 不存在：${app}/${component}" >&2; exit 1;
            }
        done
    done
    if [[ -n "$START_FROM" ]]; then
        local found=false
        for app in "${APPS[@]}"; do
            for component in "${COMPONENTS[@]}"; do
                [[ "$START_FROM" != "$app/$component" ]] || found=true
            done
        done
        [[ "$found" == true ]] || { echo 'START_FROM 不匹配组件' >&2; exit 1; }
    fi
    RUN_DIRECTORY="${ARTIFACT_ROOT:-/absolute/artifact-root}/PLAN-ONLY"
    if [[ "$DRY_RUN" == false ]]; then
        command -v docker >/dev/null || { echo '未找到 docker' >&2; exit 1; }
        # Read settings and tool bytes before building. Never create a shared root implicitly.
        python3 -B - "$REGISTRY_MODULE" "$PUBLICATION_SETTINGS" "$ARTIFACT_ROOT" <<'PY'
import os, pathlib, shutil, sys
sys.path.insert(0, sys.argv[1])
from prepare_image import settings
from publish import absolute, verify_file
data = settings(pathlib.Path(sys.argv[2]))
root = absolute(sys.argv[3])
work = absolute(data['work_root'])
tool = absolute(data['tool']['path'])
verify_file(tool, data['tool']['sha256'])
if not os.access(tool, os.X_OK) or not root.is_dir() or not work.is_dir():
    raise SystemExit('工具/制品根目录/临时根目录未准备')
for path in (root, work):
    if shutil.disk_usage(path).free < data['minimum_free_gib'] * 1024**3:
        raise SystemExit('制品/临时目录可用空间不足')
PY
        for app in "${APPS[@]}"; do source_commit "${SOURCE_ROOT}/${app}-app" >/dev/null; done
        RUN_DIRECTORY="$(mktemp -d "${ARTIFACT_ROOT}/app-build.XXXXXXXX")"
    fi

    log "配置文件: ${CONFIG_FILE}"
    log "集群配置: ${CLUSTER}"
    log "镜像版本: ${TAG}"
    log "目标仓库: ${TARGET_REGISTRY}"
    log "基础镜像仓库: ${BASE_REGISTRY}"
    log "源码根目录: ${SOURCE_ROOT}"
    log "应用列表: ${APPS[*]}"
    log "组件列表: ${COMPONENTS[*]}"

    local started="false"
    [[ -z "$START_FROM" ]] && started="true"
    local processed=0

    for app in "${APPS[@]}"; do
        for component in "${COMPONENTS[@]}"; do
            key="${app}/${component}"
            if [[ "$started" != "true" ]]; then
                [[ "$key" == "$START_FROM" ]] || continue
                started="true"
            fi
            build_component "$app" "$component"
            processed=$((processed + 1))
        done
    done

    [[ "$started" == "true" ]] || {
        echo "START_FROM 不匹配任何组件: $START_FROM" >&2
        exit 1
    }
    if [[ "$DRY_RUN" == true ]]; then
        log "${processed} 个组件计划已输出；未构建或发布"
    else
        success "${processed} 个组件制品已准备；目录 ${RUN_DIRECTORY}；尚未发布"
    fi
}

main "$@"
