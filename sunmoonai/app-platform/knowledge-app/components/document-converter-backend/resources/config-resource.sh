#!/usr/bin/env bash
# Local renderer and lifecycle for the two Document Converter configuration resources.
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
    local -a variables=(SENTRY_DSN PROJECT_NAME SERVER_NAME SERVER_HOST BACKEND_CORS_ORIGINS DOCUMENT_CONVERTER_SERVICE_PORT DOCUMENT_CONVERTER_UNIFIED_HOST SENTRY_ENVIRONMENT SENTRY_RELEASE SENTRY_TRACES_SAMPLE_RATE SENTRY_PROFILES_SAMPLE_RATE)
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
    export NAMESPACE="${namespace:-${NAMESPACE:-app-platform-dev}}"
    export ENVIRONMENT="${environment:-${ENVIRONMENT:-development}}"
    [[ "$NAMESPACE" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ && ${#NAMESPACE} -le 63 ]] || { echo 'Invalid namespace' >&2; return 1; }
    if [[ "$action" != generate ]]; then
        source "$root/utils/deploy-target.sh" || return 1
        sunmoon_deploy_target_init "$root" || return 1
    fi
    local -a kube=(timeout 25s "${SUNMOON_KUBECTL:-}" --kubeconfig "${KUBECONFIG:-}" --request-timeout=10s)
    case "$action" in
        status) "${kube[@]}" get "$kind" "$name" -n "$NAMESPACE"; return $? ;;
        uninstall) "${kube[@]}" delete "$kind" "$name" -n "$NAMESPACE" --ignore-not-found --wait=false; return $? ;;
    esac
    local rendered_file
    rendered_file=$(dc_render_resource "$app" "$kind" "$generator_dir" "$name") || return 1
    if [[ "$action" == generate ]]; then printf '%s\n' "$rendered_file"; return 0; fi
    local admitted_namespace="$NAMESPACE"
    sunmoon_deploy_target_check "$root" || return 1
    if ! "${kube[@]}" apply --server-side --field-manager=sunmoon-document-converter \
        -n "$admitted_namespace" -f "$rendered_file" >/dev/null 2>&1; then
        echo 'Resource apply failed; check access/target/field ownership. Private API output suppressed.' >&2
        return 1
    fi
    printf 'Selected %s applied: %s/%s\n' "$kind" "$admitted_namespace" "$name"
)
