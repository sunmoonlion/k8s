#!/usr/bin/env bash
# Shared infrastructure configuration; no network or service operations.
# Cloud execution 未经实机验证. All callers must explicitly select a cluster.

infra_load_config() {
    local infra_selected="${CLUSTER:-}" infra_config_path infra_private_path
    local infra_name infra_base infra_declaration
    infra_selected="${infra_selected^^}"
    [[ "$infra_selected" =~ ^C[0-9]+$ ]] || {
        echo 'Infrastructure requires an explicit CLUSTER=Cn or --cluster Cn' >&2
        return 1
    }
    infra_config_path="${INFRA_CONFIG_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/deploy-infrastructure-all/deploy-infrastructure-all.conf}"
    [[ -f "$infra_config_path" && ! -L "$infra_config_path" ]] || {
        echo 'Infrastructure configuration missing or symlinked' >&2; return 1;
    }
    # Each process uses one target/configuration. Repeated reads of the same target
    # are permitted; changing target mid-process must start a fresh invocation.
    if [[ -n "${INFRA_LOADED_CLUSTER:-}" && ( "$INFRA_LOADED_CLUSTER" != "$infra_selected" || "$INFRA_LOADED_CONFIG" != "$infra_config_path" ) ]]; then
        echo 'Changing infrastructure target/configuration within one process is refused' >&2
        return 1
    fi
    # Clear node fields so empty overrides and sparse node indices cannot inherit
    # values from another loader. Values are never evaluated a second time.
    while IFS= read -r infra_name; do
        [[ "$infra_name" =~ ^SERVER_[0-9]+_ ]] && unset "$infra_name"
    done < <(compgen -v)
    # Trusted owner-controlled Shell configuration, not downloaded input.
    # shellcheck source=/dev/null
    source "$infra_config_path"
    infra_private_path="${INFRA_PRIVATE_CONFIG_FILE:-}"
    if [[ -n "$infra_private_path" ]]; then
        [[ -f "$infra_private_path" && ! -L "$infra_private_path" ]] || {
            echo 'Explicit private infrastructure configuration is missing or symlinked' >&2; return 1;
        }
        # shellcheck source=/dev/null
        source "$infra_private_path"
    fi
    export CLUSTER="$infra_selected"
    while IFS= read -r infra_name; do
        [[ "$infra_name" == "${infra_selected}_"* ]] || continue
        infra_base="${infra_name#"${infra_selected}_"}"
        [[ "$infra_base" == CLUSTER ]] && continue
        [[ "$infra_base" =~ ^[A-Z][A-Z0-9_]*$ || "$infra_base" == packages_deploy_mode ]] || {
            echo "Invalid infrastructure override name: $infra_base" >&2; return 1;
        }
        infra_declaration="$(declare -p "$infra_name")"
        if [[ "$infra_declaration" =~ ^declare\ -[^\ ]*[aA] ]]; then
            echo "Array cluster override is unsupported: $infra_name" >&2; return 1
        fi
        printf -v "$infra_base" '%s' "${!infra_name}"
    done < <(compgen -v)
    export INFRA_CONFIG_FILE="$infra_config_path"
    export INFRA_PRIVATE_CONFIG_FILE="$infra_private_path"
    INFRA_LOADED_CLUSTER="$infra_selected"
    INFRA_LOADED_CONFIG="$infra_config_path"
    [[ -n "$(infra_server_indices)" ]] || {
        echo 'Selected cluster has no nodes' >&2; return 1;
    }
}

infra_server_indices() {
    local infra_name infra_index
    while IFS= read -r infra_name; do
        if [[ "$infra_name" =~ ^SERVER_([1-9][0-9]*)_(PUBLIC_IP|LOCAL_IP)$ && -n "${!infra_name}" ]]; then
            infra_index="${BASH_REMATCH[1]}"
            printf '%s\n' "$infra_index"
        fi
    done < <(compgen -v) | sort -nu
}

infra_server_value() {
    local infra_index="$1" infra_key="$2" infra_name
    [[ "$infra_index" =~ ^[1-9][0-9]*$ && "$infra_key" =~ ^[A-Z][A-Z0-9_]*$ ]] || return 1
    infra_name="SERVER_${infra_index}_${infra_key}"
    printf '%s\n' "${!infra_name-}"
}
