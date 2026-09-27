#!/usr/bin/env bash
# kubeadm cluster adapter; 云上未经实机验证. Default prints only.
set -euo pipefail
CLUSTER_STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$CLUSTER_STEP_DIR/common.sh"

cluster_step_main() {
    local phase="$1" argument action="--dry-run" idx field name
    shift
    for argument in "$@"; do
        [[ $# -eq 1 ]] || { log_error 'Specify one action only'; return 1; }
        case "$argument" in --apply|--dry-run|--verify) action="$argument" ;; *) log_error 'Expected --dry-run, --apply or --verify'; return 1 ;; esac
    done
    if [[ "$action" == --verify && "$phase" != registry ]]; then
        log_error '--verify is only supported by the registry consumer'; return 1
    fi
    load_config_file || return 1
    if [[ "$phase" == registry ]]; then
        # shellcheck source=/dev/null
        source "$PROJECT_ROOT/../registry-platform/lib/config.sh"
        # Empty example permits planning only; actual use requires explicit host fields.
        REGISTRY_CONFIG_FILE="${REGISTRY_CONFIG_FILE:-$PROJECT_ROOT/../registry-platform/config/cloud.example.conf}"
        registry_export_consumer || return 1
    fi
    # Only these topology fields enter Python; never export the whole config.
    while IFS= read -r name; do unset "$name"; done < <(compgen -v SM_NODE_)
    SM_NODE_INDICES="$(get_defined_server_indices)"
    export SM_NODE_INDICES
    for idx in $SM_NODE_INDICES; do
        for field in TYPE PUBLIC_IP LOCAL_IP USER SECRET SSH_PORT DIR EXPECTED_HOSTNAME MACHINE_ID CLUSTER_HOSTNAME; do
            name="SM_NODE_${idx}_${field}"
            printf -v "$name" '%s' "$(get_server_var "$idx" "$field")"
            export "${name?}"
        done
        name="SM_NODE_${idx}_TAINTS"
        field="STEP10_NODE_${idx}_TAINTS"
        printf -v "$name" '%s' "${!field:-}"
        export "${name?}"
        for field in ENABLED UUID; do
            name="SM_NODE_${idx}_STORAGE_${field}"
            local source_name="STEP09_LOCAL_STORAGE_SERVER_${idx}_${field}"
            printf -v "$name" '%s' "${!source_name:-}"
            export "${name?}"
        done
    done
    export SM_POD_CIDR="${STEP04_POD_CIDR:-}" SM_SERVICE_CIDR="${STEP04_SERVICE_CIDR:-}"
    export SM_ENDPOINT="${STEP04_CONTROLPLANE_ENDPOINT:-}" SM_API_SANS="${STEP04_APISERVER_CERT_SANS:-}"
    export SM_KUBERNETES="${STEP03_K8S_VERSION:-${CLUSTER_VERSION:-}}"
    export SM_CALICO="${STEP05_CALICO_CHART_VERSION:-}" SM_CNI="${STEP05_CNI:-}"
    export SM_PROXY_MODE="${STEP04_KUBE_PROXY_MODE:-}" SM_CALICO_AUTODETECTION="${STEP05_CALICO_IP_AUTODETECTION:-auto}"
    export INFRA_MATERIAL_ROOT="${INFRA_MATERIAL_ROOT:-$HOME/packages-to-be-installed}"
    export SM_NAMESPACE_ENVIRONMENTS="${NAMESPACE_PLATFORM_ENVIRONMENTS:-}"
    export SM_NAMESPACE_PLATFORMS="${NAMESPACE_PLATFORM_PLATFORMS:-}"
    export SM_NAMESPACE_POLICIES="${NAMESPACE_PLATFORM_APPLY_POLICIES:-false}"
    export SM_NAMESPACE_ENABLED="${NAMESPACE_PLATFORM_ENABLE:-false}"
    local resource_timeout="${STEP08_WAIT_TIMEOUT:-300}"
    [[ "$phase" != storage ]] || resource_timeout="${STEP09_WAIT_TIMEOUT:-300}"
    export SM_RESOURCE_TIMEOUT="$resource_timeout" SM_EXPECTED_NODE_COUNT="${STEP08_EXPECTED_NODE_COUNT:-}"
    for idx in 07 08 09 10 11; do
        for field in ENABLED TARGET REMOTE_KUBECONFIG; do
            name="STEP${idx}_${field}"
            export "SM_${name}=${!name:-}"
        done
    done
    for field in LOCAL_STORAGE_ENABLED CLOUD_STORAGE_ENABLED LOCAL_STORAGE_PATH LOCAL_STORAGE_MOUNTPOINT LOCAL_STORAGE_VERSION HELPER_IMAGE HELPER_IMAGE_PULL_POLICY LOCAL_STORAGE_CLASS_NAME LOCAL_STORAGE_DEFAULT_CLASS LOCAL_STORAGE_RECLAIM_POLICY LOCAL_STORAGE_VOLUME_BINDING_MODE; do
        name="STEP09_${field}"
        export "SM_STORAGE_${field}=${!name:-}"
    done
    local -a args=(--phase "$phase")
    [[ "$action" == --dry-run ]] || args+=("$action")
    python3 "$PROJECT_ROOT/materials/cluster_control.py" "${args[@]}"
}
