#!/bin/bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" namespace "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"

# Shared target and one enabled-component list for all actions.
# Cloud execution: 未经实机验证.
set -euo pipefail
set +x
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../.." && pwd)"
source "$PROJECT_ROOT/utils/cluster-arg-parser.sh"
unified_parse_cluster_arg "$@"
set -- "${PARSED_ARGS[@]}"
[[ $# -le 3 && "${3:-false}" == false ]] || { echo 'Expected action namespace false' >&2; exit 2; }
action="${1:-deploy}"
case "$action" in deploy|status|uninstall) ;; *) echo 'Unsupported Redis Secret action' >&2; exit 2 ;; esac
[[ "${CLUSTER:-}" =~ ^(KIND|C[1-9][0-9]*)$ ]] || { echo 'Explicit CLUSTER required' >&2; exit 1; }
selected_cluster="$CLUSTER"
positional_namespace="${2:-}"
CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"
[[ -f "$CONFIG_FILE" && ! -L "$CONFIG_FILE" ]] || { echo 'Redis Secret controller configuration missing' >&2; exit 1; }
source "$CONFIG_FILE" >/dev/null 2>&1 || { echo 'Redis Secret configuration failed' >&2; exit 1; }
[[ "$CLUSTER" == "$selected_cluster" ]] || { echo 'Configuration changed cluster' >&2; exit 1; }
source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
apply_cluster_config_mapping >/dev/null 2>&1 || { echo 'Redis Secret mapping failed' >&2; exit 1; }
[[ "$CLUSTER" == "$selected_cluster" ]] || { echo 'Mapping changed cluster' >&2; exit 1; }
namespace="${positional_namespace:-${NAMESPACE:-data-platform-dev}}"

# priority:profile. Larger priorities deploy first; uninstall reverses this order.
components=(
    "${redis_auth_secret_enabled:-true}:${redis_auth_secret_priority:-1000}:redis-auth-secret"
    "${harbor_registry_secret_enabled:-false}:${harbor_registry_secret_priority:-800}:harbor-registry-secret"
    "${redis_myapp_secret_enabled:-true}:${redis_myapp_secret_priority:-600}:redis-myapp-secret"
    "${redis_llmopsservice_secret_enabled:-true}:${redis_llmopsservice_secret_priority:-500}:redis-llmopsservice-secret"
)
enabled_components=()
for item in "${components[@]}"; do
    IFS=: read -r enabled priority profile <<< "$item"
    [[ "$enabled" == true || "$enabled" == false ]] || { echo 'Invalid Secret enabled switch' >&2; exit 1; }
    [[ "$priority" =~ ^[0-9]{1,6}$ ]] || { echo 'Invalid Secret priority' >&2; exit 1; }
    [[ "$enabled" == true ]] || continue
    component_dir="$SCRIPT_DIR/../$profile/deploy-$profile"
    [[ -f "$component_dir/deploy-$profile.sh" && -f "$component_dir/deploy-$profile.conf" ]] || {
        echo 'Enabled Redis Secret entry/configuration missing' >&2; exit 1;
    }
    enabled_components+=("$priority:$profile")
done
if [[ ${#enabled_components[@]} == 0 ]]; then
    echo 'No Redis Secret components enabled'
    exit 0
fi
sort_args=(-t: -k1,1nr -k2,2)
[[ "$action" != uninstall ]] || sort_args=(-t: -k1,1n -k2,2r)
sorted_components=$(printf '%s\n' "${enabled_components[@]}" | sort "${sort_args[@]}")
mapfile -t ordered_components <<< "$sorted_components"
source "$PROJECT_ROOT/utils/deploy-target.sh"
sunmoon_deploy_target_init "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/utils/secret-management/lib/opaque-deploy.sh"
source "$PROJECT_ROOT/sunmoonai/registry-platform/lib/pull-secret.sh"
for item in "${ordered_components[@]}"; do
    profile="${item#*:}"
    component_dir="$SCRIPT_DIR/../$profile/deploy-$profile"
    if [[ "$action" == deploy ]]; then
        bash "$component_dir/deploy-$profile.sh" --cluster "$CLUSTER" \
            "${PROJECT_ID:-sunmoonai}" "$namespace" "${ENVIRONMENT:-development}" false || exit $?
    elif [[ "$profile" == harbor-registry-secret ]]; then
        if [[ "$action" == uninstall ]]; then
            echo 'Preserved shared Harbor pull Secret; other workloads may use it'
            continue
        fi
        registry_secret_entry "$PROJECT_ROOT" "$component_dir/deploy-$profile.conf" namespace \
            data-platform-dev --cluster "$CLUSTER" status "$namespace" false || exit $?
    else
        opaque_secret_lifecycle_entry "$PROJECT_ROOT" "$component_dir/deploy-$profile.conf" "$profile" \
            data-platform-dev --cluster "$CLUSTER" "$action" "$namespace" false || exit $?
    fi
done
case "$action" in
    deploy) echo 'Enabled Redis Secrets submitted/read back; workload readiness not checked' ;;
    status) echo 'Enabled Redis Secrets present; database login not checked' ;;
    uninstall) echo 'Enabled Redis business Secret deletion requested; shared pull Secret preserved' ;;
esac
