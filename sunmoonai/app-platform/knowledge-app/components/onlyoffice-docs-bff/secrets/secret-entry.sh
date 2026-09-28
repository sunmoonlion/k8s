#!/usr/bin/env bash
# ONLYOFFICE Opaque Secrets: one selected resource, existing positional API.
# No random credentials; cloud execution 未经实机验证.
onlyoffice_secret_entry() (
    set -euo pipefail
    set +x
    local root="$1" app="$2" config="$3" resource="$4" value_var="$5"
    shift 5
    source "$root/utils/cluster-arg-parser.sh"
    unified_parse_cluster_arg "$@"
    set -- "${PARSED_ARGS[@]}"
    [[ $# -le 5 ]] || { echo 'Too many Secret arguments' >&2; return 2; }
    local action="${1:-deploy}" project="${2:-sunmoonai}"
    local requested_namespace="${3:-}" environment="${4:-development}"
    case "$action" in
        help|-h|--help)
            echo 'action [project namespace environment dry_run]; actions: deploy/status/uninstall/generate'
            echo 'generate renders only this Secret locally; deploy requires an explicit existing credential.'
            return 0 ;;
        deploy|status|uninstall|generate) ;;
        *) echo 'Unsupported ONLYOFFICE Secret action' >&2; return 2 ;;
    esac
    if [[ "$action" != generate && ! "${CLUSTER:-}" =~ ^(KIND|C[1-9][0-9]*)$ ]]; then
        echo 'Explicit CLUSTER required for cluster operations' >&2; return 1
    fi
    [[ -f "$config" && ! -L "$config" ]] || { echo 'Secret configuration missing' >&2; return 1; }
    source "$config" >/dev/null 2>&1
    source "$root/utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping
    local namespace="${requested_namespace:-${SECRET_NAMESPACE:-app-platform-dev}}"
    [[ "$namespace" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ && ${#namespace} -le 63 &&
       "${SECRET_NAME:-}" =~ ^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$ &&
       "${SECRET_TYPE:-Opaque}" == Opaque ]] || { echo 'Invalid Secret target/type' >&2; return 1; }
    local yaml_file="$app/resources/custom-values/$resource"
    if [[ "$action" != generate ]]; then
        source "$root/utils/deploy-target.sh"
        sunmoon_deploy_target_init "$root" || return 1
    fi
    # Read/delete by explicit name. Neither action needs a generated file or secret value.
    case "$action" in
        status)
            timeout 25s "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" --request-timeout=10s \
                get secret "$SECRET_NAME" -n "$namespace" || return 1
            return 0 ;;
        uninstall)
            timeout 25s "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" --request-timeout=10s \
                delete secret "$SECRET_NAME" -n "$namespace" --ignore-not-found --wait=false || return 1
            return 0 ;;
    esac
    [[ -n "${!value_var:-}" ]] || { echo 'Explicit Secret value required; automatic credential rotation is disabled' >&2; return 1; }
    export PROJECT_ID="$project" NAMESPACE="$namespace" ENVIRONMENT="$environment"
    export SECRET_NAME TARGET_SECRET_KEY
    export "$value_var=${!value_var}"
    bash "$app/resources/custom-values/generate.sh" --resource "$resource" || return 1
    [[ "$action" == deploy ]] || return 0
    sunmoon_deploy_target_check "$root" || return 1
    # Raw API diagnostics can contain submitted Secret data; suppress them.
    if ! timeout 25s "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" --request-timeout=10s \
        apply --server-side --field-manager=sunmoon-onlyoffice -f "$yaml_file" >/dev/null 2>&1; then
        echo 'Secret apply failed; check target/access/field ownership. Private API output suppressed.' >&2
        return 1
    fi
    printf 'Selected Secret applied: %s/%s\n' "$namespace" "$SECRET_NAME"
)
