#!/bin/bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" action "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"
# Shared local/cloud consumer. Cloud execution 未经实机验证.
set -euo pipefail
set +x
export DISABLE_AUTO_CLEANUP=true
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
K8S_ROOT_DIR="$(cd "$SCRIPT_DIR/../../../../../../../.." && pwd)"
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"
source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
source "$K8S_ROOT_DIR/utils/deploy-target.sh"
source "$APP_ROOT/resources/config-resource.sh"
log_info() { printf '%s\n' "$*"; }
log_error() { printf '%s\n' "$*" >&2; }

scan_and_deploy_components() {
    local component_type="$1" project_id="$2" namespace="$3" environment="$4"
    local dry_run="${5:-false}" operation="${6:-deploy}" base_dir="$PROJECT_ROOT/$1"
    local script_file conf_file dirname prefix settings enabled priority
    local -a components=() sorted_components=()
    case "$operation" in deploy|status|uninstall) ;; *) return 2 ;; esac
    # These categories have a direct entry, rather than a nested per-resource directory.
    case "$component_type" in
        ingress) script_file="$base_dir/deploy-ingress/deploy-ingress.sh" ;;
        middleware) script_file="$base_dir/deploy-middleware-all/deploy-middleware-all.sh" ;;
        *) script_file='' ;;
    esac
    if [[ -n "$script_file" ]]; then
        [[ -f "$script_file" ]] || { log_error "启用的组件入口缺失: $component_type"; return 1; }
        DISABLE_AUTO_CLEANUP=true bash "$script_file" "$operation" "$project_id" "$namespace" "$environment" "$dry_run"
        return $?
    fi
    [[ -d "$base_dir" ]] || { log_error "启用的组件目录缺失: $component_type"; return 1; }
    local subdir
    for subdir in "$base_dir"/*/; do
        [[ -d "$subdir" ]] || continue
        dirname="$(basename "$subdir")"
        [[ "$dirname" != deploy-*-all ]] || continue
        script_file="$subdir/deploy-$dirname/deploy-$dirname.sh"
        conf_file="$subdir/deploy-$dirname/deploy-$dirname.conf"
        case "$dirname" in
            dc-secret) prefix=document_converter_secret ;;
            dc-config) prefix=document_converter_config ;;
            dc-backend-ns) prefix=document_converter_bff_namespace ;;
            *) prefix="${dirname//-/_}" ;;
        esac
        [[ "$prefix" =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ && -f "$conf_file" ]] || { log_error '子组件配置缺失或名字不合法'; return 1; }
        # Read controls in a subshell: child NAMESPACE/PROJECT_ID must not overwrite the parent target.
        settings=$(
            set +x
            source "$conf_file" >/dev/null 2>&1 || exit 1
            apply_cluster_config_mapping >/dev/null || exit 1
            enabled_var="${prefix}_enabled"; priority_var="${prefix}_priority"
            printf '%s %s' "${!enabled_var:-true}" "${!priority_var:-100}"
        ) || { log_error '子组件配置读取失败'; return 1; }
        read -r enabled priority <<< "$settings"
        [[ "$enabled" == true || "$enabled" == false ]] || { log_error '组件 enabled 必须为 true/false'; return 1; }
        [[ "$priority" =~ ^[0-9]+$ ]] || { log_error '组件 priority 必须为非负整数'; return 1; }
        [[ "$enabled" == true ]] || { log_info "跳过已禁用组件: $dirname"; continue; }
        [[ -f "$script_file" ]] || { log_error "启用的组件脚本缺失: $dirname"; return 1; }
        components+=("$priority"$'\t'"$dirname"$'\t'"$script_file")
    done
    [[ ${#components[@]} -gt 0 ]] || { log_info "没有启用的 $component_type 子组件"; return 0; }
    local order=-nr sorted line
    [[ "$operation" != uninstall ]] || order=-n
    sorted=$(printf '%s\n' "${components[@]}" | LC_ALL=C sort -t $'\t' -k1,1 "$order") || return 1
    mapfile -t sorted_components <<< "$sorted"
    for line in "${sorted_components[@]}"; do
        IFS=$'\t' read -r priority dirname script_file <<< "$line"
        log_info "$operation $dirname (priority=$priority)"
        DISABLE_AUTO_CLEANUP=true bash "$script_file" "$operation" "$project_id" "$namespace" "$environment" "$dry_run" || return $?
    done
}

# Check/apply always use the explicitly selected binary and kubeconfig.
dc_kube() {
    timeout 25s "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" --request-timeout=10s "$@"
}

main() {
    unified_parse_cluster_arg "$@"
    set -- "${PARSED_ARGS[@]}"
    [[ $# -le 5 ]] || { log_error 'Too many arguments'; return 2; }
    local action="${1:-deploy}" project="${2:-}" namespace="${3:-}" environment="${4:-}"
    local requested_cluster="${CLUSTER:-}" config="$SCRIPT_DIR/deploy-document-converter-backend.conf"
    case "$action" in deploy|status|uninstall) ;; *) log_error 'Use deploy/status/uninstall'; return 2 ;; esac
    [[ -f "$config" && ! -L "$config" ]] || { log_error 'Required deployment config missing'; return 1; }
    source "$config" >/dev/null 2>&1 || { log_error 'Deployment configuration failed'; return 1; }
    [[ "$requested_cluster" =~ ^(KIND|C[1-9][0-9]*)$ && "${CLUSTER:-}" == "$requested_cluster" ]] || {
        log_error 'Explicit cluster required; configuration must not replace it'; return 1;
    }
    apply_cluster_config_mapping || return 1
    export PROJECT_ID="${project:-${DOCUMENT_CONVERTER_BFF_PROJECT_ID:-}}"
    export NAMESPACE="${namespace:-${DOCUMENT_CONVERTER_BFF_NAMESPACE:-}}"
    export ENVIRONMENT="${environment:-${ENVIRONMENT:-}}"
    [[ "$NAMESPACE" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ && ${#NAMESPACE} -le 63 ]] || { log_error 'Invalid namespace'; return 1; }
    local flag category enabled
    for flag in namespace_enabled secrets_enabled configmap_enabled pvc_enabled middleware_enabled ingress_enabled; do
        [[ -v "$flag" && ( "${!flag}" == true || "${!flag}" == false ) ]] || {
            log_error 'All component switches must explicitly be true/false'; return 1;
        }
    done
    sunmoon_deploy_target_init "$K8S_ROOT_DIR" || return 1
    if [[ "$action" == status ]]; then
        dc_kube get deployment/document-converter service/document-converter -n "$NAMESPACE" || return 1
        dc_kube get pods,pvc,configmap,secret -n "$NAMESPACE" -l app=document-converter || return 1
        for category in namespace pvc secret configMap middleware ingress; do
            case "$category" in
                namespace) enabled="$namespace_enabled" ;; pvc) enabled="$pvc_enabled" ;;
                secret) enabled="$secrets_enabled" ;; configMap) enabled="$configmap_enabled" ;;
                middleware) enabled="$middleware_enabled" ;; ingress) enabled="$ingress_enabled" ;;
            esac
            [[ "$enabled" == true ]] || continue
            scan_and_deploy_components "$category" "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false status || return 1
        done
        return 0
    fi
    if [[ "$action" == uninstall ]]; then
        # Remove routing first; PVC and namespace are never removed by this parent.
        for category in ingress middleware; do
            flag="${category}_enabled"
            [[ "${!flag}" == true ]] || continue
            scan_and_deploy_components "$category" "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false uninstall || return 1
        done
        sunmoon_deploy_target_check "$K8S_ROOT_DIR" || return 1
        dc_kube delete deployment/document-converter service/document-converter -n "$NAMESPACE" --ignore-not-found --wait=false || return 1
        for category in configMap secret; do
            case "$category" in configMap) enabled="$configmap_enabled" ;; secret) enabled="$secrets_enabled" ;; esac
            [[ "$enabled" == true ]] || continue
            scan_and_deploy_components "$category" "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false uninstall || return 1
        done
        log_info 'Uninstall requests submitted; namespace/PVC retained. Completion not awaited.'
        return 0
    fi
    local rendered image manifest_result
    rendered=$(dc_render_resource "$APP_ROOT" App "$APP_ROOT/resources/k8s-resource/custom-values/app/generate-app" document-converter) || return 1
    image=$(python3 -B "$APP_ROOT/resources/resource_metadata.py" image "$rendered") || return 1
    manifest_result=$(python3 -B "$K8S_ROOT_DIR/sunmoonai/registry-platform/images.py" check --image "$image" --apply) || return 1
    python3 -B "$APP_ROOT/resources/resource_metadata.py" pin-image "$rendered" <<< "$manifest_result" || return 1
    # The core Service must exist before Ingress dependency validation.
    for category in namespace pvc secret configMap middleware; do
        case "$category" in
            namespace) enabled="$namespace_enabled" ;; pvc) enabled="$pvc_enabled" ;;
            secret) enabled="$secrets_enabled" ;; configMap) enabled="$configmap_enabled" ;;
            middleware) enabled="$middleware_enabled" ;;
        esac
        [[ "$enabled" == true ]] || continue
        scan_and_deploy_components "$category" "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false || return 1
    done
    dc_kube get namespace "$NAMESPACE" >/dev/null || return 1
    sunmoon_deploy_target_check "$K8S_ROOT_DIR" || return 1
    dc_kube apply --server-side --field-manager=sunmoon-document-converter -n "$NAMESPACE" -f "$rendered" || return 1
    if [[ "$ingress_enabled" == true ]]; then
        scan_and_deploy_components ingress "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" false || return 1
    fi
    log_info 'Document Converter submitted with verified manifest digest; rollout/service acceptance still required.'
}
main "$@"
