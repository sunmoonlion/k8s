#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OBJECT_STORAGE_SCRIPT_DIR="$SCRIPT_DIR"

source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"
SCRIPT_DIR="$OBJECT_STORAGE_SCRIPT_DIR"

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]] && type unified_parse_cluster_arg >/dev/null 2>&1; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

CONFIG_FILE="$SCRIPT_DIR/deploy-object-storage.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "缺少 Object Storage 配置文件: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
    source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping
fi

case "$(echo "${CLUSTER:-}" | tr '[:lower:]' '[:upper:]')" in
    KIND)
        export K8S_TARGET_MODE="kind"
        ;;
    C[0-9]*)
        export K8S_TARGET_MODE="remote"
        ;;
esac

DEFAULT_PROJECT_ID="${OBJECT_STORAGE_PROJECT_ID:-sunmoonai}"
DEFAULT_NAMESPACE="${OBJECT_STORAGE_NAMESPACE:-data-platform-dev}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-development}"

OPERATOR_CHART_DIR="$PROJECT_ROOT/resources/aistor-operator"
OBJECT_STORE_CHART_DIR="$PROJECT_ROOT/resources/aistor-objectstore"
CUSTOM_VALUES_DIR="$PROJECT_ROOT/resources/custom-values"

ensure_helm_version() {
    command -v helm >/dev/null 2>&1 || {
        log_error "未找到 helm 命令"
        return 1
    }

    local version
    version="$(helm version --template '{{.Version}}' | sed 's/^v//')"
    if ! printf '%s\n%s\n' "3.17.0" "$version" | sort -V -C; then
        log_error "AIStor 要求 Helm >= 3.17.0，当前版本: $version"
        return 1
    fi
}

ensure_cluster_connection() {
    if kubectl get nodes >/dev/null 2>&1; then
        return 0
    fi
    setup_kubectl_environment
    kubectl get nodes >/dev/null
}

ensure_namespace() {
    local namespace="$1"
    kubectl get namespace "$namespace" >/dev/null 2>&1 || {
        log_error "命名空间不存在: $namespace"
        return 1
    }
}

ensure_license_secret() {
    local namespace="$1"
    local secret_name="${AISTOR_LICENSE_SECRET_NAME:-minio-license}"

    if [[ ! -f "$AISTOR_LICENSE_FILE" ]]; then
        log_error "AIStor License 文件不存在: $AISTOR_LICENSE_FILE"
        log_error "请将许可证保存到默认位置，或通过 AISTOR_LICENSE_FILE 指定其他路径"
        return 1
    fi

    kubectl create secret generic "$secret_name" \
        --namespace "$namespace" \
        --from-file=minio.license="$AISTOR_LICENSE_FILE" \
        --dry-run=client -o yaml | kubectl apply -f -
}

ensure_root_secret() {
    local namespace="$1"
    local secret_name="${OBJECT_STORAGE_ROOT_SECRET_NAME:-object-storage-root-credentials}"
    local config_env
    config_env="export MINIO_ROOT_USER=${OBJECT_STORAGE_ROOT_USER}
export MINIO_ROOT_PASSWORD=${OBJECT_STORAGE_ROOT_PASSWORD}"

    kubectl create secret generic "$secret_name" \
        --namespace "$namespace" \
        --from-literal=config.env="$config_env" \
        --dry-run=client -o yaml | kubectl apply -f -
}

ensure_harbor_secret() {
    local namespace="$1"
    local secret_name="${OBJECT_STORAGE_IMAGE_PULL_SECRET_NAME:-harbor-registry-secret}"
    if ! kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
        log_error "缺少 Harbor 镜像拉取 Secret: $namespace/$secret_name"
        return 1
    fi
}

push_object_storage_images_to_harbor() {
    push_component_images_to_harbor "object-storage"
}

operator_release() {
    printf '%s\n' "${OBJECT_STORAGE_OPERATOR_RELEASE:-aistor-operator}"
}

object_store_release() {
    local project_id="$1"
    printf '%s-%s\n' "${OBJECT_STORAGE_RELEASE_PREFIX:-object-storage}" "$project_id"
}

prepare_kind_host_path() {
    local node="${OBJECT_STORAGE_KIND_NODE:-kind-worker}"
    local path="${OBJECT_STORAGE_KIND_HOST_PATH:-/data/kind-local-storage/object-storage}"

    command -v docker >/dev/null 2>&1 || {
        log_error "Kind hostPath 初始化需要 docker 命令"
        return 1
    }
    docker inspect "$node" >/dev/null 2>&1 || {
        log_error "未找到 Kind 节点容器: $node"
        return 1
    }

    log_info "准备 Kind Object Storage 数据目录: $node:$path"
    docker exec "$node" mkdir -p "$path"
    docker exec "$node" chown -R 1000:1000 "$path"
    docker exec "$node" chmod 0770 "$path"
}

deploy_operator() {
    local namespace="$1"
    local dry_run="$2"
    local args=(
        upgrade --install "$(operator_release)" "$OPERATOR_CHART_DIR"
        --namespace "$namespace"
        --values "$CUSTOM_VALUES_DIR/operator-values.yaml"
        --set "namespaceOverride=$namespace"
    )
    [[ "$dry_run" == "true" ]] && args+=(--dry-run)
    helm "${args[@]}"
}

wait_for_operator() {
    local namespace="$1"
    kubectl wait --for=condition=Established \
        crd/objectstores.aistor.min.io --timeout=180s
    kubectl rollout status deployment/object-store-operator \
        -n "$namespace" --timeout=300s
    kubectl rollout status deployment/object-store-webhook \
        -n "$namespace" --timeout=300s
}

deploy_object_store() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    local cluster_lower
    cluster_lower="$(echo "${CLUSTER:-}" | tr '[:upper:]' '[:lower:]')"

    if [[ "$environment" != "development" && "$environment" != "dev" ]]; then
        log_error "当前仅完成开发环境配置，拒绝部署 environment=$environment"
        return 1
    fi
    if [[ "$cluster_lower" != "kind" ]]; then
        log_error "当前步骤仅完成 Kind 配置，远程开发 values 尚未实施"
        return 1
    fi

    if [[ "$dry_run" != "true" ]]; then
        prepare_kind_host_path
        kubectl apply -f "$CUSTOM_VALUES_DIR/object-storage-kind-pv.yaml"
    fi

    local args=(
        upgrade --install "$(object_store_release "$project_id")" "$OBJECT_STORE_CHART_DIR"
        --namespace "$namespace"
        --values "$CUSTOM_VALUES_DIR/dev-values-kind.yaml"
        --set "namespaceOverride=$namespace"
    )
    [[ "$dry_run" == "true" ]] && args+=(--dry-run)
    helm "${args[@]}"
}

show_status() {
    local project_id="$1"
    local namespace="$2"
    helm status "$(operator_release)" -n "$namespace" || true
    helm status "$(object_store_release "$project_id")" -n "$namespace" || true
    kubectl get objectstore,pods,svc,pvc -n "$namespace" \
        -l 'app in (minio)' -o wide || true
    kubectl get pv "${OBJECT_STORAGE_KIND_PV_NAME:-object-storage-sunmoonai-dev-pv}" || true
}

open_console() {
    local namespace="$1"
    local service_name="${OBJECT_STORAGE_NAME:-platform-object-storage}-console"
    local address="${OBJECT_STORAGE_CONSOLE_LOCAL_ADDRESS:-127.0.0.1}"
    local local_port="${OBJECT_STORAGE_CONSOLE_LOCAL_PORT:-19090}"
    local service_port="${OBJECT_STORAGE_CONSOLE_SERVICE_PORT:-9090}"

    ensure_cluster_connection
    if ! kubectl get service "$service_name" -n "$namespace" >/dev/null 2>&1; then
        log_error "Console Service 不存在: $namespace/$service_name"
        return 1
    fi

    log_info "AIStor Console: http://${address}:${local_port}"
    log_info "仅在当前终端运行期间开放，按 Ctrl+C 关闭"
    kubectl port-forward \
        --namespace "$namespace" \
        --address "$address" \
        "service/$service_name" \
        "${local_port}:${service_port}"
}

deploy_all() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    ensure_helm_version
    ensure_cluster_connection
    ensure_namespace "$namespace"
    ensure_harbor_secret "$namespace"

    if [[ "$dry_run" != "true" ]]; then
        ensure_license_secret "$namespace"
        ensure_root_secret "$namespace"
        push_object_storage_images_to_harbor
    fi

    deploy_operator "$namespace" "$dry_run"
    if [[ "$dry_run" != "true" ]]; then
        wait_for_operator "$namespace"
    fi
    deploy_object_store "$project_id" "$namespace" "$environment" "$dry_run"

    if [[ "$dry_run" != "true" ]]; then
        show_status "$project_id" "$namespace"
    fi
}

uninstall_all() {
    local project_id="$1"
    local namespace="$2"

    ensure_cluster_connection
    helm uninstall "$(object_store_release "$project_id")" -n "$namespace" || true
    helm uninstall "$(operator_release)" -n "$namespace" || true
    log_warn "已保留 PV、PVC、License Secret 和根凭据 Secret"
}

main() {
    set -- "${ORIGINAL_ARGS[@]}"

    local action="${1:-deploy}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${5:-false}"

    case "$action" in
        deploy|upgrade)
            deploy_all "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        status)
            ensure_cluster_connection
            show_status "$project_id" "$namespace"
            ;;
        logs)
            ensure_cluster_connection
            kubectl logs -n "$namespace" deployment/object-store-operator --tail=200
            ;;
        console)
            open_console "$namespace"
            ;;
        uninstall)
            uninstall_all "$project_id" "$namespace"
            ;;
        *)
            echo "用法: $0 [--cluster KIND] {deploy|upgrade|status|logs|console|uninstall} [project_id] [namespace] [environment] [dry_run]"
            return 1
            ;;
    esac
}

main "$@"
