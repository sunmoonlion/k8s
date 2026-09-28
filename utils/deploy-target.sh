#!/usr/bin/env bash
# Explicit deployment target shared by the root dispatcher and component libraries.
# Sourcing defines functions only; it does not contact Kubernetes or alter state.
# Shared cloud path: 未经实机验证.

sunmoon_deploy_target_required() {
    [[ -n "${SUNMOON_DEPLOY_TARGET_REQUIRED:-}${SUNMOON_DEPLOY_BOUND_CLUSTER:-}${SUNMOON_KUBECTL:-}${SUNMOON_EXPECTED_CLUSTER_UID:-}" ]]
}

sunmoon_deploy_target_error() {
    printf '%s\n' "[deploy-target] $*" >&2
    return 1
}

sunmoon_deploy_target_check() {
    local root="${1:?repository root required}" expected actual_uid actual_hash
    [[ "${SUNMOON_DEPLOY_TARGET_REQUIRED:-}" == 1 ]] || {
        sunmoon_deploy_target_error 'Explicit deployment target is not initialized'; return 1;
    }
    [[ "${CLUSTER:-}" =~ ^(KIND|C[1-9][0-9]*)$ && "${CLUSTER:-}" == "${SUNMOON_DEPLOY_BOUND_CLUSTER:-}" ]] || {
        sunmoon_deploy_target_error 'Cluster selection changed'; return 1;
    }
    [[ "${KUBECONFIG:-}" == /* && "$KUBECONFIG" != *:* && -f "$KUBECONFIG" &&
       "$KUBECONFIG" == "${SUNMOON_DEPLOY_BOUND_KUBECONFIG:-}" &&
       "${SUNMOON_KUBECTL:-}" == /* && -x "$SUNMOON_KUBECTL" &&
       "$SUNMOON_KUBECTL" == "${SUNMOON_DEPLOY_BOUND_KUBECTL:-}" &&
       "${SUNMOON_EXPECTED_CLUSTER_UID:-}" == "${SUNMOON_DEPLOY_BOUND_UID:-}" &&
       "${SUNMOON_EXPECTED_CLUSTER_UID:-}" =~ ^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$ ]] || {
        sunmoon_deploy_target_error 'Explicit kubeconfig/tool/UID is missing or changed'; return 1;
    }
    expected=$(python3 -B "$root/utils/kubeconfig_path.py" \
        "${UNIFIED_CONFIG_FILE:-$root/utils/k8s-admin.conf}" "$CLUSTER") || return 1
    [[ "$expected" == "$KUBECONFIG" ]] || {
        sunmoon_deploy_target_error 'Cluster mapping differs from the admitted kubeconfig'; return 1;
    }
    actual_hash=$(sha256sum -- "$KUBECONFIG") || return 1
    [[ "${actual_hash%% *}" == "${SUNMOON_DEPLOY_BOUND_CONFIG_SHA256:-}" ]] || {
        sunmoon_deploy_target_error 'Kubeconfig contents changed after admission'; return 1;
    }
    # Shared helpers may prepend other directories. Restore the selected binary
    # before a deployment boundary; do not install/download or guess a version.
    export PATH="$(dirname "$SUNMOON_KUBECTL"):$PATH"
    [[ "$(type -t kubectl)" == file && "$(readlink -f -- "$(command -v kubectl)")" == "$SUNMOON_KUBECTL" ]] || {
        sunmoon_deploy_target_error 'kubectl does not resolve to the selected executable'; return 1;
    }
    actual_uid=$(timeout 20s "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" \
        --request-timeout=10s get ns kube-system -o jsonpath='{.metadata.uid}') || {
        sunmoon_deploy_target_error 'Target unavailable; no reconnect or context fallback'; return 1;
    }
    [[ "$actual_uid" == "$SUNMOON_EXPECTED_CLUSTER_UID" ]] || {
        sunmoon_deploy_target_error 'Cluster UID differs'; return 1;
    }
    export DISABLE_AUTO_CLEANUP=true
}

sunmoon_deploy_target_init() {
    local root="${1:?repository root required}" actual_hash
    # Never replace an inherited binding when a nested entry initializes itself.
    if [[ -n "${SUNMOON_DEPLOY_BOUND_CLUSTER:-}" ]]; then
        sunmoon_deploy_target_check "$root"
        return $?
    fi
    [[ "${KUBECONFIG:-}" == /* && "$KUBECONFIG" != *:* && -f "$KUBECONFIG" &&
       "${SUNMOON_KUBECTL:-}" == /* && -x "$SUNMOON_KUBECTL" ]] || {
        sunmoon_deploy_target_error 'Explicit absolute kubeconfig and kubectl required'; return 1;
    }
    export KUBECONFIG="$(readlink -f -- "$KUBECONFIG")"
    export SUNMOON_KUBECTL="$(readlink -f -- "$SUNMOON_KUBECTL")"
    actual_hash=$(sha256sum -- "$KUBECONFIG") || return 1
    export SUNMOON_DEPLOY_TARGET_REQUIRED=1
    export SUNMOON_DEPLOY_BOUND_CLUSTER="${CLUSTER:-}"
    export SUNMOON_DEPLOY_BOUND_KUBECONFIG="$KUBECONFIG"
    export SUNMOON_DEPLOY_BOUND_KUBECTL="$SUNMOON_KUBECTL"
    export SUNMOON_DEPLOY_BOUND_UID="${SUNMOON_EXPECTED_CLUSTER_UID:-}"
    export SUNMOON_DEPLOY_BOUND_CONFIG_SHA256="${actual_hash%% *}"
    sunmoon_deploy_target_check "$root"
}
