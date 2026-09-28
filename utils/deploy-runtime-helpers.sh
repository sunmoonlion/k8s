#!/usr/bin/env bash
# Shared helpers for deploy orchestration scripts (app-platform / *-app-all).
# shellcheck source=deploy-target.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy-target.sh"

inherit_deploy_kubeconfig() {
    local k8s_root="${1:-}"
    if sunmoon_deploy_target_required; then
        [[ -n "$k8s_root" ]] || k8s_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
        sunmoon_deploy_target_check "$k8s_root"
        return $?
    fi

    if [[ -n "${KUBECONFIG:-}" ]] && kubectl get ns default >/dev/null 2>&1; then
        return 0
    fi

    [[ -n "$k8s_root" ]] || k8s_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local status_file="$k8s_root/utils/.k8s-status"
    if [[ ! -f "$status_file" && -f "$k8s_root/.k8s-status" ]]; then
        status_file="$k8s_root/.k8s-status"
    fi
    [[ -f "$status_file" ]] || return 0

    # shellcheck disable=SC1090
    source "$status_file"
    if [[ -n "${CURRENT_KUBECONFIG:-}" && -f "$CURRENT_KUBECONFIG" ]]; then
        export KUBECONFIG="$CURRENT_KUBECONFIG"
    fi
}

call_deploy_subscript() {
    local k8s_root="$1"
    local script_path="$2"
    shift 2

    inherit_deploy_kubeconfig "$k8s_root" || return 1
    if [[ -n "${CLUSTER:-}" ]]; then
        DISABLE_AUTO_CLEANUP=true "$script_path" --cluster "$CLUSTER" "$@"
    else
        DISABLE_AUTO_CLEANUP=true "$script_path" "$@"
    fi
}
