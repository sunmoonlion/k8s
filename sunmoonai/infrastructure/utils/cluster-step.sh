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
        case "$argument" in --apply|--dry-run) action="$argument" ;; *) log_error 'Expected --dry-run or --apply'; return 1 ;; esac
    done
    load_config_file || return 1
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
    done
    export SM_POD_CIDR="${STEP04_POD_CIDR:-}" SM_SERVICE_CIDR="${STEP04_SERVICE_CIDR:-}"
    export SM_ENDPOINT="${STEP04_CONTROLPLANE_ENDPOINT:-}" SM_API_SANS="${STEP04_APISERVER_CERT_SANS:-}"
    export SM_KUBERNETES="${STEP03_K8S_VERSION:-${CLUSTER_VERSION:-}}"
    export SM_CALICO="${STEP05_CALICO_CHART_VERSION:-}" SM_CNI="${STEP05_CNI:-}"
    export SM_PROXY_MODE="${STEP04_KUBE_PROXY_MODE:-}" SM_CALICO_AUTODETECTION="${STEP05_CALICO_IP_AUTODETECTION:-auto}"
    export INFRA_MATERIAL_ROOT="${INFRA_MATERIAL_ROOT:-$HOME/packages-to-be-installed}"
    local -a args=(--phase "$phase")
    [[ "$action" != --apply ]] || args+=(--apply)
    python3 "$PROJECT_ROOT/materials/cluster_control.py" "${args[@]}"
}
