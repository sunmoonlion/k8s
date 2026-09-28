#!/usr/bin/env bash
# Shared cluster consumer; cloud execution 未经实机验证.

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" action "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"
set -euo pipefail
set +x
export DISABLE_AUTO_CLEANUP=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAGFLOW_SCRIPT_DIR="$SCRIPT_DIR"
DEPLOY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_ROOT="$(cd "$DEPLOY_ROOT/.." && pwd)"
K8S_ROOT_DIR="$APP_ROOT"
while [[ "$K8S_ROOT_DIR" != "/" && ! -f "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh" ]]; do
    K8S_ROOT_DIR="$(dirname "$K8S_ROOT_DIR")"
done
[[ -f "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh" ]] || {
    echo "[ERROR] 无法定位 k8s 根目录" >&2
    exit 1
}

source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"
source "$K8S_ROOT_DIR/utils/deploy-target.sh"
log_info() { printf '%s\n' "$*"; }
log_success() { printf '%s\n' "$*"; }
log_error() { printf '%s\n' "$*" >&2; }
ragflow_kube() {
    timeout 25s "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" --request-timeout=10s "$@"
}
SCRIPT_DIR="$RAGFLOW_SCRIPT_DIR"

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

REQUESTED_CLUSTER="${CLUSTER:-}"
[[ -f "$SCRIPT_DIR/deploy-ragflow.conf" && ! -L "$SCRIPT_DIR/deploy-ragflow.conf" ]] || { log_error 'RAGFlow configuration missing'; exit 1; }
source "$SCRIPT_DIR/deploy-ragflow.conf" >/dev/null 2>&1 || { log_error 'RAGFlow configuration failed'; exit 1; }
if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping
fi

CHART_DIR="$APP_ROOT/resources/ragflow"
VALUES_DIR="$APP_ROOT/resources/custom-values"
SECRET_VALUES="$VALUES_DIR/dev-secrets-values.yaml"
INGRESS_SCRIPT="$DEPLOY_ROOT/ingress/ragflow-ingress/deploy-ingress/deploy-ingress.sh"

run_ingress() {
    if [[ -n "${CLUSTER:-}" ]]; then
        DISABLE_AUTO_CLEANUP=true bash "$INGRESS_SCRIPT" --cluster "$CLUSTER" "$@"
    else
        DISABLE_AUTO_CLEANUP=true bash "$INGRESS_SCRIPT" "$@"
    fi
}

ensure_harbor_registry_secret() (
    local namespace="$1"
    source "$K8S_ROOT_DIR/sunmoonai/registry-platform/lib/config.sh" || return 1
    registry_load_config || return 1
    sunmoon_deploy_target_check "$K8S_ROOT_DIR" || return 1
    python3 -B "$K8S_ROOT_DIR/sunmoonai/registry-platform/pull_secret.py" deploy \
        --namespace "$namespace" --name "${RAGFLOW_IMAGE_PULL_SECRET:-harbor-registry-secret}" --apply
)

check_prerequisites() {
    local namespace="$1"
    local dry_run="${2:-false}"

    command -v helm >/dev/null || { log_error "helm 未安装"; return 1; }
    [[ -d "$CHART_DIR" ]] || { log_error "Helm Chart 不存在: $CHART_DIR"; return 1; }
    [[ -f "$SECRET_VALUES" ]] || { log_error "开发密码 values 不存在: $SECRET_VALUES"; return 1; }

    if ! ragflow_kube get namespace "$namespace" >/dev/null 2>&1; then
        log_error "RAGFlow 前置检查失败: 命名空间不存在 $namespace"
        return 1
    fi

    if ! ragflow_kube get storageclass local-path >/dev/null 2>&1; then
        log_error "RAGFlow 前置检查失败: StorageClass 不存在 local-path"
        return 1
    fi

    ensure_harbor_registry_secret "$namespace" "$dry_run" || {
        log_error "RAGFlow 前置检查失败: Harbor Registry Secret 未就绪"
        return 1
    }

    if [[ "$RAGFLOW_INGRESS_ENABLED" == true ]] && ! ragflow_kube get crd ingressroutes.traefik.io >/dev/null 2>&1; then
        log_error "RAGFlow 前置检查失败: Traefik IngressRoute CRD 不存在 ingressroutes.traefik.io"
        return 1
    fi
}

deploy_release() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    local release_name="${RAGFLOW_RELEASE_PREFIX}-${project_id}"
    local values_file="$VALUES_DIR/dev-values.yaml"
    local cluster_values=""
    local proxy_url="${RAGFLOW_KIND_EGRESS_PROXY_URL:-}"
    local proxy_no_proxy="${RAGFLOW_KIND_EGRESS_NO_PROXY:-}"
    local proxy_no_proxy_helm=""
    local -a values_args=(-f "$values_file")

    case "$environment" in
        development|dev) ;;
        *) log_error "当前仅提供 development values，收到: $environment"; return 1 ;;
    esac
    if [[ "${CLUSTER:-}" == "KIND" ]]; then
        cluster_values="$VALUES_DIR/dev-values-kind.yaml"
        values_args+=(-f "$cluster_values")
    fi
    values_args+=(-f "$SECRET_VALUES")

    if [[ -n "$proxy_url" ]]; then
        if [[ "${CLUSTER:-}" != "KIND" ]]; then
            log_error "RAGFLOW_KIND_EGRESS_PROXY_URL 仅允许用于 KIND"
            return 1
        fi
        if [[ "$proxy_url" == *"@"* || ! "$proxy_url" =~ ^https?://[^[:space:]/]+:[0-9]+$ ]]; then
            log_error "KIND egress proxy 必须是无凭据的 http(s)://host:port"
            return 1
        fi
        if [[ -z "$proxy_no_proxy" ]]; then
            log_error "启用 KIND egress proxy 时 RAGFLOW_KIND_EGRESS_NO_PROXY 不能为空"
            return 1
        fi
        # Helm's --set parser treats commas as value separators unless escaped.
        proxy_no_proxy_helm="${proxy_no_proxy//,/\\,}"
        values_args+=(
            --set ragflow.egressProxy.enabled=true
            --set-string "ragflow.egressProxy.httpProxy=$proxy_url"
            --set-string "ragflow.egressProxy.httpsProxy=$proxy_url"
            --set-string "ragflow.egressProxy.noProxy=$proxy_no_proxy_helm"
        )
        log_info "为 KIND RAGFlow 启用显式 egress proxy（无凭据，内部地址直连）"
    fi

    if ! helm lint "$CHART_DIR" "${values_args[@]}" >/dev/null 2>&1; then
        log_error 'Helm lint failed; private values diagnostics suppressed'; return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        helm template "$release_name" "$CHART_DIR" -n "$namespace" \
            "${values_args[@]}" >/dev/null
        log_success "✅ RAGFlow Helm 渲染校验通过"
        return
    fi

    if ! helm template "$release_name" "$CHART_DIR" -n "$namespace" "${values_args[@]}" 2>/dev/null | \
        python3 -B "$APP_ROOT/resources/check_rendered_images.py"; then
        log_error 'Rendered chart image admission failed; no Helm upgrade'; return 1
    fi
    sunmoon_deploy_target_check "$K8S_ROOT_DIR" || return 1
    if ! helm --kubeconfig "$KUBECONFIG" upgrade --install "$release_name" "$CHART_DIR" \
        --namespace "$namespace" \
        "${values_args[@]}" \
        --atomic --wait --timeout "$RAGFLOW_HELM_TIMEOUT" >/dev/null 2>&1; then
        log_error 'Helm upgrade failed; inspect private diagnostics and release state'; return 1
    fi

    if [[ "$RAGFLOW_INGRESS_ENABLED" == "true" ]]; then
        run_ingress deploy "$project_id" "$namespace" "$environment" || return 1
    fi
}

show_status() {
    local project_id="$1"
    local namespace="$2"
    local release_name="${RAGFLOW_RELEASE_PREFIX}-${project_id}"
    timeout 25s helm --kubeconfig "$KUBECONFIG" status "$release_name" -n "$namespace" -o json | \
        python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({k:d[k] for k in ("name","namespace","version")})); print(d["info"]["status"])' || return 1
    ragflow_kube get pods,svc,pvc -n "$namespace" -l "app.kubernetes.io/instance=$release_name" -o wide || return 1
    if [[ "$RAGFLOW_INGRESS_ENABLED" == "true" ]]; then
        ragflow_kube get ingressroute ragflow-ingress -n "$namespace" || return 1
    fi
}

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    [[ $# -le 5 ]] || { log_error 'Too many arguments'; return 2; }
    local action="${1:-deploy}"
    local project_id="${2:-${RAGFLOW_PROJECT_ID}}"
    local namespace="${3:-${RAGFLOW_NAMESPACE}}"
    local environment="${4:-${ENVIRONMENT}}"
    local dry_run="${5:-false}"
    local release_name="${RAGFLOW_RELEASE_PREFIX}-${project_id}"
    case "$action" in
        deploy|uninstall|status|logs) ;;
        purge-data) log_error 'Data purge is not admitted by this deployment entry; use the approved final cleanup plan'; return 2 ;;
        *) log_error 'Use deploy/uninstall/status/logs'; return 2 ;;
    esac
    if [[ "$action" == deploy && "$environment" != development && "$environment" != dev ]]; then
        log_error 'Only development values are currently provisioned'; return 1
    fi
    [[ "$RAGFLOW_INGRESS_ENABLED" == true || "$RAGFLOW_INGRESS_ENABLED" == false ]] || return 1
    command -v helm >/dev/null || { log_error 'helm required'; return 1; }

    [[ "$REQUESTED_CLUSTER" =~ ^(KIND|C[1-9][0-9]*)$ && "${CLUSTER:-}" == "$REQUESTED_CLUSTER" ]] || {
        log_error 'Explicit cluster required; configuration must not replace it'; return 1;
    }
    [[ "$namespace" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ && ${#namespace} -le 63 &&
       "$release_name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ && ${#release_name} -le 53 ]] || {
        log_error 'Invalid namespace or Helm release name'; return 1;
    }
    sunmoon_deploy_target_init "$K8S_ROOT_DIR" || return 1

    case "$action" in
        deploy)
            check_prerequisites "$namespace" "$dry_run" || return 1
            deploy_release "$project_id" "$namespace" "$environment" "$dry_run" || return 1
            [[ "$dry_run" == "true" ]] || show_status "$project_id" "$namespace"
            ;;
        uninstall)
            if [[ "$RAGFLOW_INGRESS_ENABLED" == "true" ]]; then
                run_ingress uninstall "$project_id" "$namespace" "$environment" || return 1
            fi
            sunmoon_deploy_target_check "$K8S_ROOT_DIR" || return 1
            helm --kubeconfig "$KUBECONFIG" uninstall "$release_name" -n "$namespace" --wait --ignore-not-found --timeout "$RAGFLOW_HELM_TIMEOUT" || return 1
            ;;
        status)
            show_status "$project_id" "$namespace"
            ;;
        logs)
            ragflow_kube logs -n "$namespace" deployment/"$release_name" -c ragflow --tail=200 -f
            ;;
        *)
            echo "用法: $0 [--cluster KIND] <deploy|uninstall|status|logs> [project_id] [namespace] [environment] [dry_run]" >&2
            exit 1
            ;;
    esac
}

main "$@"
