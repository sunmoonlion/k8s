#!/usr/bin/env bash

# Common preflight checks for app-level dependencies.

app_dep_log_info() {
    if declare -F log_info >/dev/null 2>&1; then
        log_info "$@"
    else
        echo "[INFO] $*"
    fi
}

app_dep_log_success() {
    if declare -F log_success >/dev/null 2>&1; then
        log_success "$@"
    else
        echo "[SUCCESS] $*"
    fi
}

app_dep_log_error() {
    if declare -F log_error >/dev/null 2>&1; then
        log_error "$@"
    else
        echo "[ERROR] $*" >&2
    fi
}

app_dep_enabled() {
    [[ "${1:-false}" == "true" ]]
}

app_dependency_export_component_secret_overrides() {
    local component="$1"
    local database_enabled="${2:-false}"
    local redis_enabled="${3:-false}"
    local mongodb_enabled="${4:-false}"
    local storage_enabled="${5:-false}"
    local search_enabled="${6:-false}"
    local prefix

    prefix="$(echo "$component" | tr '[:lower:]-' '[:upper:]_')"

    app_dep_enabled "$database_enabled" || export "${prefix}_POSTGRESQL_SECRET_NAME="
    app_dep_enabled "$redis_enabled" || export "${prefix}_REDIS_SECRET_NAME="
    if app_dep_enabled "$mongodb_enabled"; then
        eval "[[ -n \"\${${prefix}_MONGODB_SECRET_NAME:-}\" ]]" || \
            export "${prefix}_MONGODB_SECRET_NAME=${component}-mongodb-conn"
    else
        export "${prefix}_MONGODB_SECRET_NAME="
    fi

    if ! app_dep_enabled "$storage_enabled"; then
        export "${prefix}_OBJECT_STORAGE_CONFIGMAP_NAME="
        export "${prefix}_OBJECT_STORAGE_SECRET_NAME="
    fi

    if ! app_dep_enabled "$search_enabled"; then
        export "${prefix}_ELASTICSEARCH_CONFIGMAP_NAME="
        export "${prefix}_ELASTICSEARCH_SECRET_NAME="
    fi
}

app_dependency_component_should_deploy() {
    local component="$1"
    local enabled="${2:-false}"
    local parent_backend=""
    local parent_enabled redis_enabled database_enabled

    app_dep_enabled "$enabled" || return 1

    case "$component" in
        celeryworker-*)
            parent_backend="${component#celeryworker-}"
            ;;
        nodebullworker-*)
            parent_backend="${component#nodebullworker-}"
            ;;
    esac

    [[ -n "$parent_backend" ]] || return 0

    eval "parent_enabled=\${${parent_backend//-/_}_enabled:-false}"
    app_dep_enabled "$parent_enabled" || return 1

    if [[ "$component" == nodebullworker-* ]]; then
        eval "database_enabled=\${${parent_backend//-/_}_database_access_enabled:-false}"
        eval "redis_enabled=\${${parent_backend//-/_}_redis_access_enabled:-$database_enabled}"
        app_dep_enabled "$redis_enabled" || return 1
    fi

    return 0
}

app_dependency_action_requires_check() {
    case "${1:-}" in
        deploy|provision|validate) return 0 ;;
        *) return 1 ;;
    esac
}

app_dependency_has_ready_endpoint() {
    local namespace="$1"
    local service="$2"
    local addresses=""

    addresses="$(kubectl get endpoints "$service" -n "$namespace" \
        -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
    if [[ -n "$addresses" ]]; then
        return 0
    fi

    addresses="$(kubectl get endpointslice -n "$namespace" \
        -l "kubernetes.io/service-name=$service" \
        -o jsonpath='{.items[*].endpoints[?(@.conditions.ready==true)].addresses[*]}' 2>/dev/null || true)"
    [[ -n "$addresses" ]]
}

app_dependency_resolve_target() {
    local dependency="$1"
    local project_id namespace service

    case "$dependency" in
        postgresql)
            project_id="${POSTGRESQL_PROJECT_ID:-sunmoonai}"
            namespace="${POSTGRESQL_NAMESPACE:-data-platform-dev}"
            service="${POSTGRESQL_SERVICE_NAME:-postgresql-${project_id}}"
            ;;
        redis)
            project_id="${REDIS_PROJECT_ID:-sunmoonai}"
            namespace="${REDIS_NAMESPACE:-data-platform-dev}"
            service="${REDIS_SERVICE_NAME:-redis-${project_id}-master}"
            ;;
        mongodb)
            project_id="${MONGODB_PROJECT_ID:-sunmoonai}"
            namespace="${MONGODB_NAMESPACE:-data-platform-dev}"
            service="${MONGODB_SERVICE_NAME:-mongodb-${project_id}}"
            ;;
        elasticsearch)
            project_id="${ELASTICSEARCH_PROJECT_ID:-sunmoonai}"
            namespace="${ELASTICSEARCH_NAMESPACE:-data-platform-dev}"
            service="${ELASTICSEARCH_SERVICE_NAME:-elasticsearch-${project_id}}"
            ;;
        *)
            app_dep_log_error "未知应用依赖类型: $dependency"
            return 1
            ;;
    esac

    printf '%s:%s\n' "$namespace" "$service"
}

check_app_dependency_ready() {
    local dependency="$1"
    local target namespace service

    target="$(app_dependency_resolve_target "$dependency")" || return 1
    namespace="${target%%:*}"
    service="${target#*:}"

    if ! command -v kubectl >/dev/null 2>&1; then
        app_dep_log_error "kubectl 不存在，无法检查应用依赖: $dependency"
        return 1
    fi

    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        app_dep_log_error "应用依赖 $dependency 未就绪: 命名空间不存在 $namespace"
        return 1
    fi

    if ! kubectl get svc "$service" -n "$namespace" >/dev/null 2>&1; then
        app_dep_log_error "应用依赖 $dependency 未就绪: Service 不存在 $namespace/$service"
        return 1
    fi

    if ! app_dependency_has_ready_endpoint "$namespace" "$service"; then
        app_dep_log_error "应用依赖 $dependency 未就绪: Service 没有 ready endpoint $namespace/$service"
        return 1
    fi

    app_dep_log_success "应用依赖 $dependency 已就绪: $namespace/$service"
}

preflight_app_dependencies() {
    local owner="$1"
    local action="$2"
    shift 2

    app_dependency_action_requires_check "$action" || return 0

    local dependency
    for dependency in "$@"; do
        [[ -n "$dependency" ]] || continue
        app_dep_log_info "检查 $owner 依赖: $dependency"
        check_app_dependency_ready "$dependency" || return 1
    done
}
