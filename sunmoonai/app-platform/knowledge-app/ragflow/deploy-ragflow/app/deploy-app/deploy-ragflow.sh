#!/usr/bin/env bash
set -euo pipefail

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

source "$K8S_ROOT_DIR/utils/unified-deployment-template.sh"
SCRIPT_DIR="$RAGFLOW_SCRIPT_DIR"

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

source "$SCRIPT_DIR/deploy-ragflow.conf"
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

load_registry_secret_defaults() {
    local registry_conf="$K8S_ROOT_DIR/utils/registry-push-management/loadimage.conf"
    [[ -f "$registry_conf" ]] || return 0

    local current_registry_username="${REGISTRY_USERNAME:-}"
    local current_registry_password="${REGISTRY_PASSWORD:-}"
    # shellcheck disable=SC1090
    source "$registry_conf"
    [[ -n "$current_registry_username" ]] && REGISTRY_USERNAME="$current_registry_username"
    [[ -n "$current_registry_password" ]] && REGISTRY_PASSWORD="$current_registry_password"
}

ensure_harbor_registry_secret() {
    local namespace="$1"
    local dry_run="${2:-false}"
    local secret_name="${RAGFLOW_IMAGE_PULL_SECRET:-harbor-registry-secret}"
    local docker_server docker_username docker_password

    if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
        log_success "复用命名空间现有 Harbor Registry Secret: $namespace/$secret_name"
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_info "dry-run 模式跳过 Harbor Registry Secret 创建: $namespace/$secret_name"
        return 0
    fi

    load_registry_secret_defaults

    if declare -F get_cluster_harbor_registry >/dev/null 2>&1; then
        docker_server="${DOCKER_SERVER:-${RAGFLOW_IMAGE_REGISTRY:-$(get_cluster_harbor_registry)}}"
    else
        docker_server="${DOCKER_SERVER:-${RAGFLOW_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}}"
    fi
    docker_username="${DOCKER_USERNAME:-${HARBOR_ADMIN_USER:-${HARBOR_USERNAME:-${REGISTRY_USERNAME:-admin}}}}"
    docker_password="${DOCKER_PASSWORD:-${HARBOR_ADMIN_PASSWORD:-${HARBOR_PASSWORD:-${REGISTRY_PASSWORD:-}}}}"

    if [[ -z "$docker_password" || "$docker_password" == "TODO_FILL_IN_HARBOR_PASSWORD" ]]; then
        log_error "Harbor Registry Secret 不存在，且未配置 Harbor 密码。请设置 DOCKER_PASSWORD/HARBOR_ADMIN_PASSWORD/HARBOR_PASSWORD/REGISTRY_PASSWORD"
        return 1
    fi

    log_info "创建 Harbor Registry Secret: $namespace/$secret_name"
    kubectl create secret docker-registry "$secret_name" \
        --namespace "$namespace" \
        --docker-server="$docker_server" \
        --docker-username="$docker_username" \
        --docker-password="$docker_password" \
        --dry-run=client -o yaml | kubectl apply -f -
}

required_images() {
    local registry="${RAGFLOW_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
    local project="${RAGFLOW_IMAGE_PROJECT:-app-images}"
    cat <<EOF
$registry/$project/ragflow:v0.25.4-sunmoonai.1
$registry/$project/mysql:8.0.39
$registry/$project/elasticsearch:8.11.3
$registry/$project/minio:RELEASE.2026-03-25T00-00-00Z
$registry/$project/valkey:8
$registry/$project/alpine:latest
$registry/$project/busybox:latest
EOF
}

check_prerequisites() {
    local namespace="$1"
    local dry_run="${2:-false}"

    command -v helm >/dev/null || { log_error "helm 未安装"; return 1; }
    [[ -d "$CHART_DIR" ]] || { log_error "Helm Chart 不存在: $CHART_DIR"; return 1; }
    [[ -f "$SECRET_VALUES" ]] || { log_error "开发密码 values 不存在: $SECRET_VALUES"; return 1; }

    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_error "RAGFlow 前置检查失败: 命名空间不存在 $namespace"
        return 1
    fi

    if ! kubectl get storageclass local-path >/dev/null 2>&1; then
        log_error "RAGFlow 前置检查失败: StorageClass 不存在 local-path"
        return 1
    fi

    ensure_harbor_registry_secret "$namespace" "$dry_run" || {
        log_error "RAGFlow 前置检查失败: Harbor Registry Secret 未就绪"
        return 1
    }

    if ! kubectl get crd ingressroutes.traefik.io >/dev/null 2>&1; then
        log_error "RAGFlow 前置检查失败: Traefik IngressRoute CRD 不存在 ingressroutes.traefik.io"
        return 1
    fi
}

check_images() {
    ensure_component_images_in_harbor "ragflow" "${RAGFLOW_IMAGE_PROJECT:-app-images}"
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

    helm lint "$CHART_DIR" "${values_args[@]}"

    if [[ "$dry_run" == "true" ]]; then
        helm template "$release_name" "$CHART_DIR" -n "$namespace" \
            "${values_args[@]}" >/dev/null
        log_success "✅ RAGFlow Helm 渲染校验通过"
        return
    fi

    helm upgrade --install "$release_name" "$CHART_DIR" \
        --namespace "$namespace" \
        "${values_args[@]}" \
        --atomic --wait --timeout "$RAGFLOW_HELM_TIMEOUT"

    if [[ "$RAGFLOW_INGRESS_ENABLED" == "true" ]]; then
        run_ingress deploy "$project_id" "$namespace" "$environment"
    fi
}

show_status() {
    local project_id="$1"
    local namespace="$2"
    local release_name="${RAGFLOW_RELEASE_PREFIX}-${project_id}"
    helm status "$release_name" -n "$namespace"
    kubectl get pods,svc,pvc -n "$namespace" -l "app.kubernetes.io/instance=$release_name" -o wide
    if [[ "$RAGFLOW_INGRESS_ENABLED" == "true" ]]; then
        kubectl get ingressroute ragflow-ingress -n "$namespace"
    fi
}

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    local action="${1:-deploy}"
    local project_id="${2:-${RAGFLOW_PROJECT_ID}}"
    local namespace="${3:-${RAGFLOW_NAMESPACE}}"
    local environment="${4:-${ENVIRONMENT}}"
    local dry_run="${5:-false}"
    local release_name="${RAGFLOW_RELEASE_PREFIX}-${project_id}"

    read_k8s_config
    setup_kubectl_environment

    case "$action" in
        deploy)
            check_prerequisites "$namespace" "$dry_run"
            check_images "$namespace"
            deploy_release "$project_id" "$namespace" "$environment" "$dry_run"
            [[ "$dry_run" == "true" ]] || show_status "$project_id" "$namespace"
            ;;
        uninstall)
            if [[ "$RAGFLOW_INGRESS_ENABLED" == "true" ]]; then
                run_ingress uninstall "$project_id" "$namespace" "$environment" || true
            fi
            helm uninstall "$release_name" -n "$namespace" --wait || true
            ;;
        purge-data)
            helm uninstall "$release_name" -n "$namespace" --wait || true
            kubectl delete pvc -n "$namespace" -l "app.kubernetes.io/instance=$release_name" --ignore-not-found
            ;;
        status)
            show_status "$project_id" "$namespace"
            ;;
        logs)
            kubectl logs -n "$namespace" deployment/"$release_name" -c ragflow --tail=200 -f
            ;;
        *)
            echo "用法: $0 [--cluster KIND] <deploy|uninstall|purge-data|status|logs> [project_id] [namespace] [environment] [dry_run]" >&2
            exit 1
            ;;
    esac
}

main "$@"
