#!/usr/bin/env bash
# Locked OS/runtime/Kubernetes node adapter. 云上未经实机验证。
# Defaults to print-only; --apply is still subject to full closure and identity gates.
set -euo pipefail
NODE_STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$NODE_STEP_DIR/common.sh"

node_step_main() {
    local phase="$1" prefix="$2" action="--dry-run" argument
    shift 2
    for argument in "$@"; do
        case "$argument" in
            --dry-run|--apply)
                [[ $# -eq 1 ]] || { log_error 'Specify one action only'; return 1; }
                action="$argument" ;;
            *) log_error 'Supported actions: --dry-run (default), --apply'; return 1 ;;
        esac
    done
    load_config_file || return 1
    local target_var="${prefix}_TARGET" target
    target="${!target_var:-all}"
    case "$target" in all|ALL|All|master|MASTER|worker|WORKER) ;; *) log_error 'Unknown node target'; return 1 ;; esac
    local idx host user port identity remote hostname machine_id count=0
    local -a args indices
    mapfile -t indices < <(get_defined_server_indices)
    for idx in "${indices[@]}"; do
        node_should_run "$idx" "$target" || continue
        host="$(get_server_var "$idx" PUBLIC_IP)"
        [[ -n "$host" ]] || host="$(get_server_var "$idx" LOCAL_IP)"
        user="$(get_server_var "$idx" USER)"
        port="$(get_server_var "$idx" SSH_PORT)"
        identity="$(get_server_var "$idx" SECRET)"
        remote="$(get_server_var "$idx" DIR)"
        # Identity is recorded out-of-band, not learned and accepted during apply.
        hostname="$(get_server_var "$idx" EXPECTED_HOSTNAME)"
        machine_id="$(get_server_var "$idx" MACHINE_ID)"
        args=(--phase "$phase" --root "${INFRA_MATERIAL_ROOT:-$HOME/packages-to-be-installed}"
              --host "$user@$host" --port "${port:-22}"
              --remote-root "${remote:-packages-to-be-installed}"
              --hostname "$hostname" --machine-id "$machine_id"
              --expected-kubernetes "${STEP03_K8S_VERSION:-${CLUSTER_VERSION:-unset}}")
        [[ -z "$identity" ]] || args+=(--identity "$identity")
        [[ "$action" != --apply ]] || args+=(--apply)
        python3 "$PROJECT_ROOT/materials/node_control.py" "${args[@]}" || return 1
        count=$((count + 1))
    done
    (( count > 0 )) || { log_error 'No nodes selected'; return 1; }
}
