#!/usr/bin/env bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" action "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"

set -euo pipefail
set +x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OBJECT_STORAGE_SCRIPT_DIR="$SCRIPT_DIR"
OBJECT_STORAGE_K8S_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Admit the explicit target before the legacy common library can choose a context.
source "$OBJECT_STORAGE_K8S_ROOT/utils/cluster-arg-parser.sh"
unified_parse_cluster_arg "$@"
ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
[[ "${CLUSTER:-}" =~ ^(KIND|C[1-9][0-9]*)$ ]] || { echo 'Explicit CLUSTER required' >&2; exit 1; }
source "$OBJECT_STORAGE_K8S_ROOT/utils/deploy-target.sh"
sunmoon_deploy_target_init "$OBJECT_STORAGE_K8S_ROOT" || exit 1

source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"
SCRIPT_DIR="$OBJECT_STORAGE_SCRIPT_DIR"

OBJECT_STORAGE_CONFIG_FILE="$SCRIPT_DIR/deploy-object-storage.conf"
if [[ ! -f "$OBJECT_STORAGE_CONFIG_FILE" ]]; then
    log_error "缺少 Object Storage 配置文件: $OBJECT_STORAGE_CONFIG_FILE"
    exit 1
fi
source "$OBJECT_STORAGE_CONFIG_FILE" >/dev/null 2>&1 || { echo 'Object storage configuration failed' >&2; exit 1; }

if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
    source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping
fi
sunmoon_deploy_target_check "$OBJECT_STORAGE_K8S_ROOT" || exit 1

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

object_storage_kube() (
    sunmoon_deploy_target_check "$OBJECT_STORAGE_K8S_ROOT" || return 1
    local limit=25s request=10s
    case "${1:-}" in
        wait|rollout) limit=350s; request=330s ;;
        port-forward) exec "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" --request-timeout=0 "$@" ;;
    esac
    exec timeout "$limit" "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" --request-timeout="$request" "$@"
)

object_storage_helm() {
    sunmoon_deploy_target_check "$OBJECT_STORAGE_K8S_ROOT" || return 1
    timeout 360s helm --kubeconfig "$KUBECONFIG" "$@" 2>/dev/null || {
        log_error 'Helm operation failed; private diagnostics suppressed'; return 1;
    }
}

ensure_helm_version() {
    command -v helm >/dev/null 2>&1 || {
        log_error "未找到 helm 命令"
        return 1
    }

    local version
    version="$(helm version --template '{{.Version}}' | sed 's/^v//')" || return 1
    if ! printf '%s\n%s\n' "3.17.0" "$version" | sort -V -C; then
        log_error "AIStor 要求 Helm >= 3.17.0，当前版本: $version"
        return 1
    fi
}

ensure_cluster_connection() {
    sunmoon_deploy_target_check "$OBJECT_STORAGE_K8S_ROOT"
}

ensure_namespace() {
    local namespace="$1"
    object_storage_kube get namespace "$namespace" >/dev/null 2>&1 || {
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

    sunmoon_deploy_target_check "$OBJECT_STORAGE_K8S_ROOT" || return 1
    python3 -B "$OBJECT_STORAGE_K8S_ROOT/utils/secret-management/lib/opaque_secret.py" \
        --namespace "$namespace" --name "$secret_name" \
        --data-file "$AISTOR_LICENSE_FILE" --data-file-key minio.license --apply
}

ensure_root_secret() {
    local namespace="$1"
    local secret_name="${OBJECT_STORAGE_ROOT_SECRET_NAME:-object-storage-root-credentials}"
    [[ -n "${OBJECT_STORAGE_ROOT_USER:-}" && -n "${OBJECT_STORAGE_ROOT_PASSWORD:-}" ]] || {
        log_error 'Object storage root credentials must be explicitly configured'; return 1;
    }
    local config_env
    # config.env is also sourced by the administrative /bin/sh Job. Preserve
    # values literally; reject characters that cannot use this single-quote form.
    local value
    for value in "$OBJECT_STORAGE_ROOT_USER" "$OBJECT_STORAGE_ROOT_PASSWORD"; do
        [[ "$value" != *"'"* && "$value" != *$'\n'* && "$value" != *$'\r'* ]] || {
            log_error 'Root credential contains an unsupported config.env character'; return 1;
        }
    done
    config_env="export MINIO_ROOT_USER='${OBJECT_STORAGE_ROOT_USER}'
export MINIO_ROOT_PASSWORD='${OBJECT_STORAGE_ROOT_PASSWORD}'"

    sunmoon_deploy_target_check "$OBJECT_STORAGE_K8S_ROOT" || return 1
    builtin printf '%s\0' config.env "$config_env" | \
        python3 -B "$OBJECT_STORAGE_K8S_ROOT/utils/secret-management/lib/opaque_secret.py" \
            --namespace "$namespace" --name "$secret_name" --apply
}

ensure_harbor_secret() (
    local namespace="$1"
    local secret_name="${OBJECT_STORAGE_IMAGE_PULL_SECRET_NAME:-harbor-registry-secret}"
    source "$OBJECT_STORAGE_K8S_ROOT/sunmoonai/registry-platform/lib/config.sh"
    registry_load_config || return 1
    sunmoon_deploy_target_check "$OBJECT_STORAGE_K8S_ROOT" || return 1
    python3 -B "$OBJECT_STORAGE_K8S_ROOT/sunmoonai/registry-platform/pull_secret.py" deploy \
        --namespace "$namespace" --name "$secret_name" --apply
)

push_object_storage_images_to_harbor() {
    push_component_images_to_harbor "object-storage" "" "${1:-false}" || {
        log_error "Object Storage 镜像未全部进入 Harbor（含 minio/aistor/mc），中止部署"
        return 1
    }
}

operator_release() {
    printf '%s\n' "${OBJECT_STORAGE_OPERATOR_RELEASE:-aistor-operator}"
}

object_store_release() {
    local project_id="$1"
    printf '%s-%s\n' "${OBJECT_STORAGE_RELEASE_PREFIX:-object-storage}" "$project_id"
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
    object_storage_helm "${args[@]}" --wait --timeout 300s >/dev/null
}

wait_for_operator() {
    local namespace="$1"
    object_storage_kube wait --for=condition=Established \
        crd/objectstores.aistor.min.io --timeout=180s || return 1
    object_storage_kube rollout status deployment/object-store-operator \
        -n "$namespace" --timeout=300s || return 1
    object_storage_kube rollout status deployment/object-store-webhook \
        -n "$namespace" --timeout=300s
}

deploy_object_store() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    local cluster_lower
    local values_file
    local storage_node=""
    cluster_lower="$(echo "${CLUSTER:-}" | tr '[:upper:]' '[:lower:]')"

    if [[ "$environment" != "development" && "$environment" != "dev" ]]; then
        log_error "当前仅完成开发环境配置，拒绝部署 environment=$environment"
        return 1
    fi

    case "$cluster_lower" in
        kind)
            values_file="$CUSTOM_VALUES_DIR/dev-values-kind.yaml"
            storage_node=$(unified_kind_static_node object-storage "$namespace") || return 1
            unified_kind_static_storage object-storage "$namespace" "$dry_run" >&2 || return 1
            ;;
        c[0-9]*)
            values_file="$CUSTOM_VALUES_DIR/dev-values.yaml"
            log_info "远程开发集群：使用动态 StorageClass values: $values_file"
            ;;
        *)
            log_error "不支持的集群: ${CLUSTER:-未设置}，当前仅支持 KIND 和 C1/C2/C3 这类远程开发集群"
            return 1
            ;;
    esac

    if [[ ! -f "$values_file" ]]; then
        log_error "环境配置文件不存在: $values_file"
        return 1
    fi

    local args=(
        upgrade --install "$(object_store_release "$project_id")" "$OBJECT_STORE_CHART_DIR"
        --namespace "$namespace"
        --values "$values_file"
        --set "namespaceOverride=$namespace"
    )
    if [[ -n "$storage_node" ]]; then
        args+=(--set-string "objectStore.pools[0].nodeSelector.kubernetes\.io/hostname=$storage_node")
    fi
    [[ "$dry_run" == "true" ]] && args+=(--dry-run)
    object_storage_helm "${args[@]}" --wait --timeout 300s >/dev/null
}

show_status() {
    local project_id="$1"
    local namespace="$2"
    local cluster_lower
    cluster_lower="$(echo "${CLUSTER:-}" | tr '[:upper:]' '[:lower:]')"

    local release
    for release in "$(operator_release)" "$(object_store_release "$project_id")"; do
        object_storage_helm status "$release" -n "$namespace" -o json | python3 -B -c '
import json,sys
x=json.load(sys.stdin); print(json.dumps({k:x.get(k) for k in ("name","namespace","version")} | {"status":x.get("info",{}).get("status")}))
' || return 1
    done
    object_storage_kube get objectstore,pods,svc,pvc -n "$namespace" \
        -l 'app in (minio)' -o wide || return 1
    if [[ "$cluster_lower" == kind ]]; then
        object_storage_kube get pv "${OBJECT_STORAGE_KIND_PV_NAME:-object-storage-sunmoonai-dev-pv}" || return 1
    fi
}

open_console() {
    local namespace="$1"
    local service_name="${OBJECT_STORAGE_NAME:-platform-object-storage}-console"
    local address="${OBJECT_STORAGE_CONSOLE_LOCAL_ADDRESS:-127.0.0.1}"
    local local_port="${OBJECT_STORAGE_CONSOLE_LOCAL_PORT:-19090}"
    local service_port="${OBJECT_STORAGE_CONSOLE_SERVICE_PORT:-9090}"

    ensure_cluster_connection
    if ! object_storage_kube get service "$service_name" -n "$namespace" >/dev/null 2>&1; then
        log_error "Console Service 不存在: $namespace/$service_name"
        return 1
    fi

    log_info "AIStor Console: http://${address}:${local_port}"
    log_info "仅在当前终端运行期间开放，按 Ctrl+C 关闭"
    object_storage_kube port-forward \
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

    ensure_helm_version || return 1
    ensure_cluster_connection || return 1
    ensure_namespace "$namespace" || return 1
    ensure_harbor_secret "$namespace" || return 1

    if [[ "$dry_run" != "true" ]]; then
        ensure_license_secret "$namespace" || return 1
        ensure_root_secret "$namespace" || return 1
        push_object_storage_images_to_harbor "$dry_run" || return 1
    fi

    deploy_operator "$namespace" "$dry_run" || return 1
    if [[ "$dry_run" != "true" ]]; then
        wait_for_operator "$namespace" || return 1
    fi
    deploy_object_store "$project_id" "$namespace" "$environment" "$dry_run" || return 1

    if [[ "$dry_run" != "true" ]]; then
        python3 -B "$OBJECT_STORAGE_SCRIPT_DIR/wait_ready.py" --namespace "$namespace" \
            --name "${OBJECT_STORAGE_NAME:-platform-object-storage}" --timeout 300 || return 1
        show_status "$project_id" "$namespace"
    fi
}

uninstall_all() {
    local project_id="$1"
    local namespace="$2"

    ensure_cluster_connection || return 1
    object_storage_helm uninstall "$(object_store_release "$project_id")" -n "$namespace" --ignore-not-found --wait --timeout 300s >/dev/null || return 1
    object_storage_helm uninstall "$(operator_release)" -n "$namespace" --ignore-not-found --wait --timeout 300s >/dev/null || return 1
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
            object_storage_kube logs -n "$namespace" deployment/object-store-operator --tail=200
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
