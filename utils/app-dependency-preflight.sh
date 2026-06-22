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

app_dependency_get_component_dependency_flags() {
    local component="$1"
    local var_base

    var_base="${component//-/_}"

    eval "APP_DEP_COMPONENT_ENABLED=\${${var_base}_enabled:-false}"
    eval "APP_DEP_DATABASE_ENABLED=\${${var_base}_database_access_enabled:-false}"
    eval "APP_DEP_REDIS_ENABLED=\${${var_base}_redis_access_enabled:-$APP_DEP_DATABASE_ENABLED}"
    eval "APP_DEP_MONGODB_ENABLED=\${${var_base}_mongodb_access_enabled:-false}"
    eval "APP_DEP_STORAGE_ENABLED=\${${var_base}_storage_access_enabled:-false}"
    eval "APP_DEP_SEARCH_ENABLED=\${${var_base}_search_access_enabled:-false}"
}

app_dependency_export_component_secret_overrides_from_config() {
    local component="$1"

    app_dependency_get_component_dependency_flags "$component"
    app_dependency_export_component_secret_overrides \
        "$component" \
        "$APP_DEP_DATABASE_ENABLED" \
        "$APP_DEP_REDIS_ENABLED" \
        "$APP_DEP_MONGODB_ENABLED" \
        "$APP_DEP_STORAGE_ENABLED" \
        "$APP_DEP_SEARCH_ENABLED"
}

app_dependency_validate_empty_after_source() {
    local var_name="$1"
    local description="$2"

    if [[ -n "${!var_name:-}" ]]; then
        app_dep_log_error "$description 已关闭，但生成配置仍设置了 $var_name=${!var_name}"
        return 1
    fi
}

app_dependency_validate_component_generate_config() {
    local component="$1"
    local component_dir="$2"
    local prefix conf_file

    conf_file="$component_dir/resources/k8s-resource/custom-values/app/generate-app/generate-app.conf"
    [[ -f "$conf_file" ]] || return 0

    prefix="$(echo "$component" | tr '[:lower:]-' '[:upper:]_')"
    app_dependency_get_component_dependency_flags "$component"

    (
        set -euo pipefail

        app_dep_enabled "$APP_DEP_DATABASE_ENABLED" || export "${prefix}_POSTGRESQL_SECRET_NAME="
        app_dep_enabled "$APP_DEP_REDIS_ENABLED" || export "${prefix}_REDIS_SECRET_NAME="
        app_dep_enabled "$APP_DEP_MONGODB_ENABLED" || export "${prefix}_MONGODB_SECRET_NAME="
        if ! app_dep_enabled "$APP_DEP_STORAGE_ENABLED"; then
            export "${prefix}_OBJECT_STORAGE_CONFIGMAP_NAME="
            export "${prefix}_OBJECT_STORAGE_SECRET_NAME="
        fi
        if ! app_dep_enabled "$APP_DEP_SEARCH_ENABLED"; then
            export "${prefix}_ELASTICSEARCH_CONFIGMAP_NAME="
            export "${prefix}_ELASTICSEARCH_SECRET_NAME="
        fi

        # generate-app.conf must treat an explicitly empty variable as disabled.
        # Use ${VAR-default}, not ${VAR:-default}, for dependency names.
        source "$conf_file"

        app_dep_enabled "$APP_DEP_DATABASE_ENABLED" || \
            app_dependency_validate_empty_after_source "${prefix}_POSTGRESQL_SECRET_NAME" "$component PostgreSQL"
        app_dep_enabled "$APP_DEP_REDIS_ENABLED" || \
            app_dependency_validate_empty_after_source "${prefix}_REDIS_SECRET_NAME" "$component Redis"
        app_dep_enabled "$APP_DEP_MONGODB_ENABLED" || \
            app_dependency_validate_empty_after_source "${prefix}_MONGODB_SECRET_NAME" "$component MongoDB"
        if ! app_dep_enabled "$APP_DEP_STORAGE_ENABLED"; then
            app_dependency_validate_empty_after_source "${prefix}_OBJECT_STORAGE_CONFIGMAP_NAME" "$component S3"
            app_dependency_validate_empty_after_source "${prefix}_OBJECT_STORAGE_SECRET_NAME" "$component S3"
        fi
        if ! app_dep_enabled "$APP_DEP_SEARCH_ENABLED"; then
            app_dependency_validate_empty_after_source "${prefix}_ELASTICSEARCH_CONFIGMAP_NAME" "$component Elasticsearch"
            app_dependency_validate_empty_after_source "${prefix}_ELASTICSEARCH_SECRET_NAME" "$component Elasticsearch"
        fi
    )
}

app_dependency_install_db_switch_source_guard() {
    source() {
        local env_file="${1:-}"
        local -A caller_values=()
        local var

        for var in ENABLE_POSTGRESQL ENABLE_REDIS ENABLE_NODEBULL_REDIS ENABLE_MONGODB; do
            if [[ ${!var+x} ]]; then
                caller_values["$var"]="${!var}"
            fi
        done

        builtin source "$@"

        case "$env_file" in
            */common.env|common.env)
                for var in "${!caller_values[@]}"; do
                    export "$var=${caller_values[$var]}"
                done
                ;;
        esac
    }
    export -f source
}

app_dependency_uninstall_db_switch_source_guard() {
    unset -f source 2>/dev/null || true
    export -nf source 2>/dev/null || true
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

app_dependency_ensure_kubectl_environment() {
    if ! command -v kubectl >/dev/null 2>&1; then
        APP_DEP_LAST_ERROR="kubectl 不存在，无法检查应用依赖"
        return 1
    fi

    if kubectl get nodes >/dev/null 2>&1; then
        return 0
    fi

    if ! declare -F setup_kubectl_environment >/dev/null 2>&1; then
        local script_dir template_file previous_disable_cleanup
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        template_file="$script_dir/unified-deployment-template.sh"
        if [[ -f "$template_file" ]]; then
            previous_disable_cleanup="${DISABLE_AUTO_CLEANUP:-}"
            export DISABLE_AUTO_CLEANUP=true
            # shellcheck source=unified-deployment-template.sh
            source "$template_file"
            if [[ -n "$previous_disable_cleanup" ]]; then
                export DISABLE_AUTO_CLEANUP="$previous_disable_cleanup"
            fi
        fi
    fi

    if declare -F setup_kubectl_environment >/dev/null 2>&1; then
        if setup_kubectl_environment >/dev/null 2>&1 && kubectl get nodes >/dev/null 2>&1; then
            return 0
        fi
    fi

    APP_DEP_LAST_ERROR="kubectl 连接不可用，无法检查应用依赖"
    return 1
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

app_dependency_probe_ready() {
    local dependency="$1"
    local target namespace service

    APP_DEP_LAST_ERROR=""
    target="$(app_dependency_resolve_target "$dependency")" || return 1
    namespace="${target%%:*}"
    service="${target#*:}"

    if ! app_dependency_ensure_kubectl_environment; then
        APP_DEP_LAST_ERROR="${APP_DEP_LAST_ERROR}: $dependency"
        return 1
    fi

    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        APP_DEP_LAST_ERROR="命名空间不存在 $namespace"
        return 1
    fi

    if ! kubectl get svc "$service" -n "$namespace" >/dev/null 2>&1; then
        APP_DEP_LAST_ERROR="Service 不存在 $namespace/$service"
        return 1
    fi

    if ! app_dependency_has_ready_endpoint "$namespace" "$service"; then
        APP_DEP_LAST_ERROR="Service 没有 ready endpoint $namespace/$service"
        return 1
    fi

    return 0
}

check_app_dependency_ready() {
    local dependency="$1"
    local target namespace service

    if ! app_dependency_probe_ready "$dependency"; then
        app_dep_log_error "应用依赖 $dependency 未就绪: ${APP_DEP_LAST_ERROR:-unknown}"
        return 1
    fi

    target="$(app_dependency_resolve_target "$dependency")" || return 1
    namespace="${target%%:*}"
    service="${target#*:}"
    app_dep_log_success "应用依赖 $dependency 已就绪: $namespace/$service"
}

wait_app_dependency_ready() {
    local owner="$1"
    local dependency="$2"
    local timeout="${APP_DEPENDENCY_WAIT_TIMEOUT_SECONDS:-300}"
    local interval="${APP_DEPENDENCY_WAIT_INTERVAL_SECONDS:-5}"
    local elapsed=0

    while true; do
        if app_dependency_probe_ready "$dependency"; then
            check_app_dependency_ready "$dependency"
            return 0
        fi

        if (( elapsed >= timeout )); then
            app_dep_log_error "等待 $owner 依赖 $dependency 超时: ${timeout}s (${APP_DEP_LAST_ERROR:-unknown})"
            return 1
        fi

        app_dep_log_info "等待 $owner 依赖 $dependency 就绪... (${elapsed}/${timeout}s, ${APP_DEP_LAST_ERROR:-unknown})"
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
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
        wait_app_dependency_ready "$owner" "$dependency" || return 1
    done
}
