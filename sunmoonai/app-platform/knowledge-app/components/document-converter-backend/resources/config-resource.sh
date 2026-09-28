#!/usr/bin/env bash
# Selected local renderer and resource lifecycle for Document Converter.
# Cloud execution 未经实机验证. No automatic connection/credential recovery.
dc_render_resource() (
    set -euo pipefail
    set +x
    local app="$1" kind="$2" directory="$3" name="$4"
    shift 4
    local output='' template='' incoming_namespace="${NAMESPACE:-}" incoming_environment="${ENVIRONMENT:-}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) echo 'Local render plan only; no config or files read/written'; return 0 ;;
            --help|-h) echo 'Local selected resource renderer [--dry-run]'; return 0 ;;
            *) echo 'Unsupported renderer option' >&2; return 2 ;;
        esac
    done
    case "${SUNMOON_DEPLOY_DRY_RUN:-false}" in
        true) echo 'Inherited render plan only'; return 0 ;;
        false) ;;
        *) echo 'Invalid inherited dry-run' >&2; return 2 ;;
    esac
    local config="$directory/$(basename "$directory").conf"
    [[ -f "$config" && ! -L "$config" ]] || { echo 'Resource generation config missing' >&2; return 1; }
    local main_config="$app/deploy-document-converter-backend/app/deploy-app/deploy-document-converter-backend.conf"
    [[ -f "$main_config" ]] || { echo 'Document Converter config missing' >&2; return 1; }
    local -a variables=(SENTRY_DSN PROJECT_NAME SERVER_NAME SERVER_HOST BACKEND_CORS_ORIGINS
        DOCUMENT_CONVERTER_SERVICE_PORT DOCUMENT_CONVERTER_UNIFIED_HOST SENTRY_ENVIRONMENT
        SENTRY_RELEASE SENTRY_TRACES_SAMPLE_RATE SENTRY_PROFILES_SAMPLE_RATE
        DOCUMENT_CONVERTER_IMAGE_REGISTRY DOCUMENT_CONVERTER_IMAGE_PROJECT DOCUMENT_CONVERTER_IMAGE
        DOCUMENT_CONVERTER_TAG IMAGE_PULL_POLICY DOCUMENT_CONVERTER_IMAGE_PULL_SECRET_NAME
        DOCUMENT_CONVERTER_SECRET_NAME DOCUMENT_CONVERTER_CONFIGMAP_NAME DOCUMENT_CONVERTER_REPLICAS
        DOCUMENT_CONVERTER_CPU_REQUEST DOCUMENT_CONVERTER_CPU_LIMIT DOCUMENT_CONVERTER_MEMORY_REQUEST
        DOCUMENT_CONVERTER_MEMORY_LIMIT PVC_NAME PVC_STORAGE_CLASS PVC_ACCESS_MODE PVC_STORAGE_SIZE
        SERVICE_NAME SERVICE_PORT UNIFIED_HOST USE_STRIP_PREFIX USE_RATE_LIMIT)
    local variable
    local -A supplied=()
    for variable in "${variables[@]}"; do
        if [[ -v "$variable" ]]; then supplied[$variable]="${!variable}"; fi
    done
    source "$main_config" >/dev/null 2>&1 || { echo "Required configuration/library failed" >&2; return 1; }
    local default_namespace="${DOCUMENT_CONVERTER_BFF_NAMESPACE:-}" default_environment="${ENVIRONMENT:-development}"
    source "$config" >/dev/null 2>&1 || { echo "Required configuration/library failed" >&2; return 1; }
    for variable in "${!supplied[@]}"; do printf -v "$variable" '%s' "${supplied[$variable]}"; done
    [[ "${ENABLED:-true}" == true ]] || { echo 'Selected resource generation disabled; refusing stale output' >&2; return 1; }
    export NAMESPACE="${incoming_namespace:-${NAMESPACE:-$default_namespace}}"
    export ENVIRONMENT="${incoming_environment:-${ENVIRONMENT:-$default_environment}}" ENV="${ENV:-dev}"
    case "$kind" in
        Namespace) name="$NAMESPACE" ;;
        PersistentVolumeClaim) name="${PVC_NAME:?PVC_NAME required}" ;;
        App) export DOCUMENT_CONVERTER_FULL_IMAGE_NAME="${DOCUMENT_CONVERTER_IMAGE_REGISTRY}/${DOCUMENT_CONVERTER_IMAGE_PROJECT}/${DOCUMENT_CONVERTER_IMAGE}:${DOCUMENT_CONVERTER_TAG}" ;;
        Middleware) OUTPUT_FILE="${MIDDLEWARE_OUTPUT_FILE:?Middleware output filename required}" ;;
    esac
    [[ -n "${OUTPUT_FILE:-}" && "$OUTPUT_FILE" != */* && "$OUTPUT_FILE" != .* ]] || { echo 'Invalid resource output filename' >&2; return 1; }
    output="$directory/$OUTPUT_FILE"
    template="${TEMPLATE_FILE:?Resource template required}"
    [[ "$template" == /* ]] || template="$app/resources/k8s-resource/$template"
    for variable in "${variables[@]}"; do export "$variable=${!variable:-}"; done
    python3 -B "$app/resources/render_config_resource.py" "$kind" "$template" "$output" "$NAMESPACE" "$name" || return 1
    printf '%s\n' "$output"
)

dc_config_resource_entry() (
    set -euo pipefail
    set +x
    local root="$1" app="$2" config="$3" kind="$4" generator_dir="$5" name="$6"
    shift 6
    source "$root/utils/cluster-arg-parser.sh" || { echo "Required configuration/library failed" >&2; return 1; }
    unified_parse_cluster_arg "$@"
    set -- "${PARSED_ARGS[@]}"
    [[ $# -le 5 ]] || { echo 'Too many resource arguments' >&2; return 2; }
    local action="${1:-deploy}" project="${2:-}" namespace="${3:-}" environment="${4:-}"
    local requested_cluster="${CLUSTER:-}"
    case "$action" in
        help|-h|--help) echo 'action [project namespace environment dry_run]; deploy/status/uninstall/generate'; return 0 ;;
        deploy|status|uninstall|generate) ;;
        *) echo 'Unsupported resource action' >&2; return 2 ;;
    esac
    [[ -f "$config" && ! -L "$config" ]] || { echo 'Resource deployment config missing' >&2; return 1; }
    source "$config" >/dev/null 2>&1 || { echo "Required configuration/library failed" >&2; return 1; }
    if [[ "$action" != generate ]]; then
        [[ "$requested_cluster" =~ ^(KIND|C[1-9][0-9]*)$ && "${CLUSTER:-}" == "$requested_cluster" ]] || {
            echo 'Explicit CLUSTER required; configuration must not change it' >&2; return 1;
        }
    fi
    source "$root/utils/cluster-config-mapping.sh" || { echo "Required configuration/library failed" >&2; return 1; }
    apply_cluster_config_mapping || return 1
    export PROJECT_ID="${project:-${PROJECT_ID:-sunmoonai}}"
    export NAMESPACE="${namespace:-${NAMESPACE:-${DOCUMENT_CONVERTER_BFF_NAMESPACE:-app-platform-dev}}}"
    export ENVIRONMENT="${environment:-${ENVIRONMENT:-development}}"
    [[ "$NAMESPACE" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ && ${#NAMESPACE} -le 63 ]] || { echo 'Invalid namespace' >&2; return 1; }
    case "$kind" in
        Namespace) name="$NAMESPACE" ;;
        PersistentVolumeClaim)
            # Preserve the existing generation config as the PVC identity source,
            # including status/uninstall, without generating any output.
            local identity_config="$generator_dir/$(basename "$generator_dir").conf"
            [[ -f "$identity_config" && ! -L "$identity_config" ]] || return 1
            name=$(
                source "$identity_config" >/dev/null 2>&1 || exit 1
                printf '%s' "${PVC_NAME:?PVC_NAME required}"
            ) || { echo 'PVC identity configuration failed' >&2; return 1; }
            export PVC_NAME="$name" ;;
    esac
    [[ "$name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ && ${#name} -le 63 ]] || { echo 'Invalid resource name' >&2; return 1; }
    if [[ "$action" != generate ]]; then
        source "$root/utils/deploy-target.sh" || return 1
        sunmoon_deploy_target_init "$root" || return 1
    fi
    local -a kube=(timeout 25s "${SUNMOON_KUBECTL:-}" --kubeconfig "${KUBECONFIG:-}" --request-timeout=10s)
    local api_kind="$kind"
    [[ "$kind" != Ingress ]] || api_kind=ingressroute.traefik.io
    [[ "$kind" != Middleware ]] || api_kind=middleware.traefik.io
    local -a scope=(-n "$NAMESPACE")
    [[ "$kind" != Namespace ]] || scope=()
    case "$action" in
        status) "${kube[@]}" get "$api_kind" "$name" "${scope[@]}"; return $? ;;
        uninstall)
            sunmoon_deploy_target_check "$root" || return 1
            "${kube[@]}" delete "$api_kind" "$name" "${scope[@]}" --ignore-not-found --wait=false || return 1
            if [[ "$kind" == Ingress ]]; then
                sunmoon_deploy_target_check "$root" || return 1
                "${kube[@]}" delete middleware.traefik.io document-converter-stripprefix -n "$NAMESPACE" --ignore-not-found --wait=false || return 1
            fi
            return 0 ;;
    esac
    local rendered_file
    rendered_file=$(dc_render_resource "$app" "$kind" "$generator_dir" "$name") || return 1
    if [[ "$action" == generate ]]; then printf '%s\n' "$rendered_file"; return 0; fi
    local admitted_namespace="$NAMESPACE"
    if [[ "$kind" == Ingress ]]; then
        # Read only selected backend names from the fresh local JSON; not shell config values.
        local dependencies resource object
        dependencies=$(python3 -B "$app/resources/resource_metadata.py" dependencies "$rendered_file") || return 1
        while IFS=: read -r resource object; do
            [[ -n "$resource" ]] || continue
            "${kube[@]}" get "$resource" "$object" -n "$admitted_namespace" >/dev/null || return 1
        done <<< "$dependencies"
    fi
    sunmoon_deploy_target_check "$root" || return 1
    if ! "${kube[@]}" apply --server-side --field-manager=sunmoon-document-converter \
        "${scope[@]}" -f "$rendered_file" >/dev/null 2>&1; then
        echo 'Resource apply failed; check access/target/field ownership. Private API output suppressed.' >&2
        return 1
    fi
    printf 'Selected %s applied: %s/%s\n' "$kind" "$admitted_namespace" "$name"
)
