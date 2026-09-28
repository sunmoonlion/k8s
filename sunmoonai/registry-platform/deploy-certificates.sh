#!/usr/bin/env bash
# Shared signed-certificate entry. Cloud 未经实机验证; default prints only.
# Consumes leaves only. No CA generation, rotation or implicit cluster selection.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cluster="${CLUSTER:-}"
action=--dry-run
action_set=false
local_args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cluster)
            [[ $# -ge 2 ]] || { echo '--cluster requires C1, C2 or KIND' >&2; exit 1; }
            cluster="$2"; shift 2 ;;
        --dry-run|--apply|--verify)
            [[ "$action_set" == false ]] || { echo 'Specify one action only' >&2; exit 1; }
            action_set=true; action="$1"; shift ;;
        --root|--kubectl|--kubeconfig|--expected-uid|--ca-file|--ca-sha256|--tls-bundle)
            [[ $# -ge 2 ]] || { echo 'Missing local certificate argument' >&2; exit 1; }
            local_args+=("$1" "$2"); shift 2 ;;
        *) echo 'Unsupported certificate argument' >&2; exit 1 ;;
    esac
done
case "${SUNMOON_DEPLOY_DRY_RUN:-false}" in
    true) [[ "$action" == --dry-run ]] || { echo 'Cannot disable inherited dry-run' >&2; exit 1; } ;;
    false) ;;
    *) echo 'SUNMOON_DEPLOY_DRY_RUN must be true/false' >&2; exit 1 ;;
esac
export CLUSTER="${cluster^^}"
case "$CLUSTER" in
    KIND)
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/lib/config.sh"
        registry_load_config
        [[ "$REGISTRY_TRANSPORT" == local ]] || { echo 'KIND requires an explicit local registry profile' >&2; exit 1; }
        exec python3 -B "$SCRIPT_DIR/../infrastructure/materials/tls_local.py" "$action" \
            --ca-file "$REGISTRY_CA_FILE" --ca-sha256 "${REGISTRY_CA_SHA256:-}" \
            --tls-bundle "${REGISTRY_TLS_BUNDLE_FILE:-}" "${local_args[@]}" ;;
    C1|C2)
        [[ ${#local_args[@]} -eq 0 ]] || { echo 'Cloud inputs must come from the infrastructure/registry profiles' >&2; exit 1; }
        exec bash "$SCRIPT_DIR/../infrastructure/steps/step12_ca_generation.sh" "$action" ;;
    *) echo 'Specify --cluster C1, C2 or KIND; no implicit target' >&2; exit 1 ;;
esac
