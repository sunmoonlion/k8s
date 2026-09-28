#!/usr/bin/env bash
# Shared explicit-target calls for manual database access tools. Cloud: 未经实机验证.
# Source only defines functions; no connection or cleanup hooks.
provisioner_kube() (
    set +x
    sunmoon_deploy_target_check "$PROVISIONER_K8S_ROOT" || return 1
    local request=10s deadline=25s
    case "${1:-}" in
        wait|rollout) request=330s; deadline=350s ;;
        port-forward)
            exec "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" --request-timeout=0 "$@" ;;
    esac
    # API diagnostics may contain submitted Secret values.
    exec timeout "$deadline" "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" \
        --request-timeout="$request" "$@" 2>/dev/null
)

provisioner_secret() {
    python3 -B "$PROVISIONER_K8S_ROOT/utils/secret-management/lib/opaque_secret.py" "$@" --apply
}

log_info() { printf '%s\n' "[INFO] $*" >&2; }
log_warn() { printf '%s\n' "[WARN] $*" >&2; }
log_error() { printf '%s\n' "[ERROR] $*" >&2; }
log_success() { printf '%s\n' "[OK] $*" >&2; }
