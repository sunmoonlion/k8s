#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/build-push-app-images.conf}"

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
)

for var_name in "${CONFIGURABLE_VARS[@]}"; do
    if [[ -v "$var_name" ]]; then
        printf -v "ENV_OVERRIDE_${var_name}" '%s' "${!var_name}"
    fi
done

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

for var_name in "${CONFIGURABLE_VARS[@]}"; do
    override_name="ENV_OVERRIDE_${var_name}"
    if [[ -v "$override_name" ]]; then
        printf -v "$var_name" '%s' "${!override_name}"
    fi
done

[[ -v ENV_OVERRIDE_TARGET_REGISTRY ]] && TARGET_REGISTRY_SET_BY_ENV="true"
[[ -v ENV_OVERRIDE_BASE_REGISTRY ]] && BASE_REGISTRY_SET_BY_ENV="true"
[[ -v ENV_OVERRIDE_TAG ]] && TAG_SET_BY_ENV="true"

CLUSTER="${CLUSTER:-${DEFAULT_CLUSTER:-KIND}}"
TAG="${TAG:-1.0.0}"
TARGET_REGISTRY="${TARGET_REGISTRY:-harbor.sunmoonai.com:30443/app-images}"
BASE_REGISTRY="${BASE_REGISTRY:-harbor.sunmoonai.com:30443/k8s-images}"
PLATFORM="${PLATFORM:-linux/amd64}"
PROGRESS="${PROGRESS:-auto}"
NO_CACHE="${NO_CACHE:-true}"
START_FROM="${START_FROM:-}"
DRY_RUN="${DRY_RUN:-false}"

PYPI_INDEX_URL="${PYPI_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
DEBIAN_MIRROR="${DEBIAN_MIRROR:-http://mirrors.tuna.tsinghua.edu.cn/debian}"
DEBIAN_SECURITY_MIRROR="${DEBIAN_SECURITY_MIRROR:-http://mirrors.tuna.tsinghua.edu.cn/debian-security}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"
SOURCE_ROOT="${SOURCE_ROOT:-${HOME}}"

APPS=(${APPS:-info research knowledge})
COMPONENTS=(${COMPONENTS:-admin-backend admin-frontend web-backend web-frontend})

log() {
    printf '\033[0;34m[INFO]\033[0m %s\n' "$*"
}

success() {
    printf '\033[0;32m[SUCCESS]\033[0m %s\n' "$*"
}

apply_cluster_registry_defaults() {
    local cluster_upper="${CLUSTER^^}"
    local target_var="${cluster_upper}_TARGET_REGISTRY"
    local base_var="${cluster_upper}_BASE_REGISTRY"
    local tag_var="${cluster_upper}_TAG"

    if [[ -z "${TARGET_REGISTRY_SET_BY_ENV:-}" && -n "${!target_var:-}" ]]; then
        TARGET_REGISTRY="${!target_var}"
    fi
    if [[ -z "${BASE_REGISTRY_SET_BY_ENV:-}" && -n "${!base_var:-}" ]]; then
        BASE_REGISTRY="${!base_var}"
    fi
    if [[ -z "${TAG_SET_BY_ENV:-}" && -n "${!tag_var:-}" ]]; then
        TAG="${!tag_var}"
    fi
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

build_component() {
    local app="$1"
    local component="$2"
    local key="${app}/${component}"
    local root="${SOURCE_ROOT}/${app}-app/${app}-${component}"
    local dockerfile="${root}/mybuild/Dockerfile"
    local image="${TARGET_REGISTRY}/${app}-${component}:${TAG}"
    local -a args=(
        docker build
        --platform "$PLATFORM"
        --progress "$PROGRESS"
        -f "$dockerfile"
        -t "$image"
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
        admin-backend)
            args+=(
                --build-arg "PYPI_INDEX_URL=${PYPI_INDEX_URL}"
                --build-arg "DEBIAN_MIRROR=${DEBIAN_MIRROR}"
                --build-arg "DEBIAN_SECURITY_MIRROR=${DEBIAN_SECURITY_MIRROR}"
            )
            ;;
        admin-frontend)
            args+=(--build-arg "NPM_CONFIG_REGISTRY=${NPM_REGISTRY}")
            ;;
        web-backend)
            args+=(--build-arg "NPM_REGISTRY=${NPM_REGISTRY}")
            ;;
        web-frontend)
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

    log "===== ${key} -> ${image} ====="
    run "${args[@]}"
    run docker push "$image"
    success "$image"
}

main() {
    command -v docker >/dev/null 2>&1 || {
        echo "未找到 docker" >&2
        exit 1
    }

    apply_cluster_registry_defaults

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
    local app component key
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
    success "${processed} 个 App 镜像处理完成，版本: ${TAG}"
}

main "$@"
