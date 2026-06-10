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
source "$K8S_ROOT_DIR/utils/harbor-image-check.sh"
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
RUNTIME_DIR="$APP_ROOT/.runtime"
SECRET_VALUES="$RUNTIME_DIR/secrets-values.yaml"
INGRESS_SCRIPT="$DEPLOY_ROOT/ingress/ragflow-ingress/deploy-ingress/deploy-ingress.sh"

run_ingress() {
    if [[ -n "${CLUSTER:-}" ]]; then
        DISABLE_AUTO_CLEANUP=true bash "$INGRESS_SCRIPT" --cluster "$CLUSTER" "$@"
    else
        DISABLE_AUTO_CLEANUP=true bash "$INGRESS_SCRIPT" "$@"
    fi
}

generate_secret_values() {
    if [[ -f "$SECRET_VALUES" ]]; then
        chmod 600 "$SECRET_VALUES"
        return
    fi
    mkdir -p "$RUNTIME_DIR"
    umask 077
    local mysql_password minio_password redis_password elastic_password
    mysql_password="$(openssl rand -hex 24)"
    minio_password="$(openssl rand -hex 24)"
    redis_password="$(openssl rand -hex 24)"
    elastic_password="$(openssl rand -hex 24)"
    cat > "$SECRET_VALUES" <<EOF
env:
  MYSQL_PASSWORD: "$mysql_password"
  MINIO_ROOT_USER: "rag_flow"
  MINIO_PASSWORD: "$minio_password"
  REDIS_PASSWORD: "$redis_password"
  ELASTIC_PASSWORD: "$elastic_password"
EOF
    chmod 600 "$SECRET_VALUES"
    log_success "✅ 已生成 RAGFlow 运行时密码: $SECRET_VALUES"
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
    command -v helm >/dev/null || { log_error "helm 未安装"; return 1; }
    command -v openssl >/dev/null || { log_error "openssl 未安装"; return 1; }
    [[ -d "$CHART_DIR" ]] || { log_error "Helm Chart 不存在: $CHART_DIR"; return 1; }
    kubectl get namespace "$1" >/dev/null
    kubectl get storageclass local-path >/dev/null
    kubectl get secret "$RAGFLOW_IMAGE_PULL_SECRET" -n "$1" >/dev/null
    kubectl get crd ingressroutes.traefik.io >/dev/null
}

check_images() {
    local namespace="$1"
    local image
    while IFS= read -r image; do
        check_harbor_image_exists "$image" "$namespace" "$RAGFLOW_IMAGE_PULL_SECRET"
    done < <(required_images)
}

deploy_release() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    local release_name="${RAGFLOW_RELEASE_PREFIX}-${project_id}"
    local values_file="$VALUES_DIR/dev-values.yaml"
    local cluster_values=""

    case "$environment" in
        development|dev) ;;
        *) log_error "当前仅提供 development values，收到: $environment"; return 1 ;;
    esac
    if [[ "${CLUSTER:-}" == "KIND" ]]; then
        cluster_values="$VALUES_DIR/dev-values-kind.yaml"
    fi

    generate_secret_values
    helm lint "$CHART_DIR" -f "$values_file" ${cluster_values:+-f "$cluster_values"} -f "$SECRET_VALUES"

    if [[ "$dry_run" == "true" ]]; then
        helm template "$release_name" "$CHART_DIR" -n "$namespace" \
            -f "$values_file" ${cluster_values:+-f "$cluster_values"} -f "$SECRET_VALUES" >/dev/null
        log_success "✅ RAGFlow Helm 渲染校验通过"
        return
    fi

    helm upgrade --install "$release_name" "$CHART_DIR" \
        --namespace "$namespace" \
        -f "$values_file" \
        ${cluster_values:+-f "$cluster_values"} \
        -f "$SECRET_VALUES" \
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
            check_prerequisites "$namespace"
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
