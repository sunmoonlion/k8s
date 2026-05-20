#!/bin/bash

# Harbor Registry Secret 部署脚本 — Casdoor

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"

# 动态向上查找包含 utils/cluster-arg-parser.sh 的 k8s 根目录
find_k8s_root_dir() {
    local search_dir="$1"
    while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir="$(dirname "$search_dir")"
    done
    return 1
}

PROJECT_ROOT="$(find_k8s_root_dir "$SCRIPT_DIR")" || {
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh）" >&2; exit 1; }

source "$PROJECT_ROOT/utils/cluster-arg-parser.sh"
source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"
source "$PROJECT_ROOT/utils/secret-management/lib/secret-data.sh"

declare -a PARSED_ARGS
ORIGINAL_ARGS=("$@")
[[ $# -gt 0 ]] && unified_parse_cluster_arg "$@" && ORIGINAL_ARGS=("${PARSED_ARGS[@]}")

# 加载主配置（获取 CASDOOR_IMAGE_REGISTRY 等变量）
MAIN_CONFIG_FILE="$(cd "$SCRIPT_DIR/../../.." && pwd)/deploy-casdoor.conf"
if [[ -f "$MAIN_CONFIG_FILE" ]]; then
    set +e; source "$MAIN_CONFIG_FILE" 2>/dev/null; set -e
fi

CONFIG_FILE="$SCRIPT_DIR/deploy-harbor-registry-secret.conf"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || { echo "[ERROR] 配置文件不存在: $CONFIG_FILE"; exit 1; }

if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
    source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping
fi

DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    [[ -n "${CLUSTER:-}" ]] && log_info "🎯 当前集群: ${CLUSTER}"

    local action="${1:-deploy}"
    [[ "$action" == "deploy" || "$action" == "uninstall" || "$action" == "status" ]] && shift

    local project_id="${1:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${2:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${3:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    local dry_run="${4:-false}"

    log_info "部署 Harbor Registry Secret → namespace: $namespace"

    local temp_data_dir
    temp_data_dir=$(prepare_docker_auth_secret_data \
        --server   "${DOCKER_SERVER:-harbor.sunmoonai.com}" \
        --username "$DOCKER_USERNAME" \
        --password "$DOCKER_PASSWORD")
    trap "rm -rf $temp_data_dir" EXIT

    local secret_yaml="$SECRET_DIR/harbor-registry-secret.yaml"
    generate_docker_secret_yaml \
        --name            "$SECRET_NAME" \
        --namespace       "$namespace" \
        --docker-server   "${DOCKER_SERVER:-harbor.sunmoonai.com}" \
        --docker-username "$DOCKER_USERNAME" \
        --docker-password "$DOCKER_PASSWORD" \
        --output          "$secret_yaml"

    if [[ "$dry_run" != "true" ]]; then
        kubectl get namespace "$namespace" >/dev/null 2>&1 || {
            log_error "命名空间不存在: $namespace"; exit 1; }
        kubectl apply -f "$secret_yaml"
        log_success "✅ harbor-registry-secret 已部署 (namespace: $namespace)"
    else
        log_info "[dry-run] 生成的 YAML: $secret_yaml"
    fi
}

main "$@"
