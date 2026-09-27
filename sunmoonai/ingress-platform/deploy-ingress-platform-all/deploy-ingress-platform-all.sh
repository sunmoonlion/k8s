#!/usr/bin/env bash
# One ingress implementation; KIND/local and cloud adapters. Cloud 未经实机验证.
# Default prints only. No implicit kubeconfig, uninstall, CA renewal or host NAT.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUNMOON_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cluster="${CLUSTER:-}"
action="--dry-run"
action_set=false
local_args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cluster)
            [[ $# -ge 2 ]] || { echo '--cluster requires C1, C2 or KIND' >&2; exit 1; }
            cluster="$2"; shift 2 ;;
        --dry-run|--apply|--verify|deploy|status)
            [[ "$action_set" == false ]] || { echo 'Specify one action only' >&2; exit 1; }
            action_set=true
            case "$1" in deploy) action=--apply ;; status) action=--verify ;; *) action="$1" ;; esac
            shift ;;
        --profile|--root|--kubectl|--kubeconfig|--expected-uid|--ca-file|--ca-sha256|--timeout)
            [[ $# -ge 2 ]] || { echo 'Missing local adapter argument' >&2; exit 1; }
            local_args+=("$1" "$2"); shift 2 ;;
        *) echo 'Unsupported ingress action/argument; automatic removal and legacy options are disabled' >&2; exit 1 ;;
    esac
done
case "${cluster^^}" in
    KIND) exec python3 "$SUNMOON_ROOT/infrastructure/materials/ingress_local.py" "$action" "${local_args[@]}" ;;
    C1|C2)
        [[ ${#local_args[@]} -eq 0 ]] || { echo 'Cloud parameters must come from the explicit infrastructure profile' >&2; exit 1; }
        export CLUSTER="${cluster^^}"
        exec bash "$SUNMOON_ROOT/infrastructure/steps/step13_ingress_and_harbor.sh" "$action" ;;
    *) echo 'Specify --cluster C1, C2 or KIND; no implicit target' >&2; exit 1 ;;
esac
