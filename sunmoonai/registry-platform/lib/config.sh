#!/usr/bin/env bash
# Shared registry consumer configuration. Cloud execution 未经实机验证.
# Loading configuration has no network, service or filesystem mutation.
registry_load_config() {
    local module_dir profile
    module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    profile="${REGISTRY_CONFIG_FILE:-}"
    if [[ -z "$profile" ]]; then
        case "${CLUSTER:-}" in
            KIND|kind) profile="$module_dir/config/local-wsl.conf" ;;
            *) echo 'REGISTRY_CONFIG_FILE must name the independent cloud registry configuration' >&2; return 1 ;;
        esac
    fi
    if [[ ! -f "$profile" || -L "$profile" ]]; then
        echo 'Registry configuration file is missing' >&2; return 1
    fi
    # Trusted, owner-managed configuration; never accept a downloaded arbitrary script.
    # shellcheck disable=SC1090
    source "$profile"
    if [[ "${REGISTRY_ADDRESS:-}" != 'harbor.sunmoonai.com:30443' || "${REGISTRY_VERSION:-}" != '2.13.2' ]]; then
        echo 'Registry address/version differs from the approved deployment' >&2; return 1
    fi
    if [[ "${REGISTRY_TRANSPORT:-}" != local && "${REGISTRY_TRANSPORT:-}" != ssh ]]; then
        echo 'Registry transport must be local or ssh' >&2; return 1
    fi
    export REGISTRY_CONFIG_FILE="$profile" REGISTRY_ADDRESS REGISTRY_VERSION REGISTRY_TRANSPORT
    export HARBOR_HOST='harbor.sunmoonai.com' HARBOR_PORT=30443
    export HARBOR_CA_PATH="${REGISTRY_CA_FILE:?Registry CA file reference required}"
    export HARBOR_REGISTRY="$REGISTRY_ADDRESS"
    # Host clients and cluster nodes intentionally have different route addresses.
    export HARBOR_IP="${REGISTRY_CLIENT_ADDRESS:-}"
    export HARBOR_USE_NODE_INTERNAL_IP=false
}

registry_require_cloud_host() {
    [[ "${REGISTRY_TRANSPORT:-}" == ssh && -n "${REGISTRY_PRIVATE_IP:-}" && -n "${REGISTRY_SSH_HOST:-}" && -n "${REGISTRY_MACHINE_ID:-}" ]] || {
        echo 'Independent registry private IP and SSH host are required; refusing master-IP fallback' >&2
        return 1
    }
}

# Allowlisted public consumer fields only. Installation credentials, signing
# keys, registry passwords and the full configuration must not be exported.
registry_export_consumer() {
    registry_load_config || return 1
    export SM_REGISTRY_ADDRESS="$REGISTRY_ADDRESS" SM_REGISTRY_VERSION="$REGISTRY_VERSION"
    export SM_REGISTRY_TRANSPORT="$REGISTRY_TRANSPORT" SM_REGISTRY_IP="${REGISTRY_PRIVATE_IP:-}"
    export SM_REGISTRY_CA_FILE="$REGISTRY_CA_FILE" SM_REGISTRY_CA_SHA256="${REGISTRY_CA_SHA256:-}"
    export SM_REGISTRY_MACHINE_ID="${REGISTRY_MACHINE_ID:-}" SM_REGISTRY_SSH_HOST="${REGISTRY_SSH_HOST:-}"
    export SM_REGISTRY_SNI_PROXY="${REGISTRY_LOCAL_SNI_PROXY:-}"
}
