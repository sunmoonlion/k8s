#!/bin/bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" deploy-project "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONF_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

# 自动定位 k8s 根目录（向上查找 utils/cluster-arg-parser.sh）
K8S_ROOT_DIR=""
search_dir="$SCRIPT_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
        K8S_ROOT_DIR="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
if [[ -z "$K8S_ROOT_DIR" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），SCRIPT_DIR=$SCRIPT_DIR" 1>&2
    exit 1
fi

# 集群参数解析（轻量，无连接副作用）
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"


# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
declare -a PARSED_ARGS

# 先解析命令行参数（如果提供）
# 保存原始参数，以便后续使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi
[[ "${CLUSTER:-}" =~ ^(KIND|C[1-9][0-9]*)$ ]] || { echo '[ERROR] Explicit CLUSTER required' >&2; exit 1; }
selected_cluster="$CLUSTER"

# 加载配置文件（现在可以使用已设置的 CLUSTER 值）
[[ -f "$CONF_FILE" ]] || { echo "[ERROR] 缺少 Secret 总控配置文件" >&2; exit 1; }
source "$CONF_FILE"
[[ "$CLUSTER" == "$selected_cluster" ]] || { echo '[ERROR] Configuration changed cluster' >&2; exit 1; }

# 加载集群配置映射函数（使用 utils 中的通用函数）
if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
    apply_cluster_config_mapping
fi
[[ "$CLUSTER" == "$selected_cluster" ]] || { echo '[ERROR] Mapping changed cluster' >&2; exit 1; }

if [[ -n "${CLUSTER:-}" ]]; then
    echo "[INFO] 🎯 当前集群配置: ${CLUSTER}"
fi

set -- "${ORIGINAL_ARGS[@]}"
PROJECT_ID="${1:-${PROJECT_ID:-sunmoonai}}"
NAMESPACE="${2:-${NAMESPACE:-data-platform-dev}}"
ENVIRONMENT="${3:-${ENVIRONMENT:-development}}"
DRY_RUN="${4:-false}"

for flag in elasticsearch_admin_secret_enabled harbor_registry_secret_enabled elasticsearch_myapp_secret_enabled; do
    [[ "${!flag:-true}" == true || "${!flag:-true}" == false ]] || { echo '[ERROR] Invalid Secret switch' >&2; exit 1; }
done
[[ "${APPLY_ELASTICSEARCH_MYAPP_SECRET:-false}" == true || "${APPLY_ELASTICSEARCH_MYAPP_SECRET:-false}" == false ]] || {
    echo '[ERROR] Invalid APPLY_ELASTICSEARCH_MYAPP_SECRET' >&2; exit 1;
}
source "$K8S_ROOT_DIR/utils/deploy-target.sh"
sunmoon_deploy_target_init "$K8S_ROOT_DIR" || exit 1

# 部署 Elasticsearch 管理员认证 Secret
if [[ "${elasticsearch_admin_secret_enabled:-true}" == "true" ]]; then
    admin_secret_script="$ROOT_DIR/elasticsearch-secrets/deploy-elasticsearch-secrets/deploy-elasticsearch-secrets.sh"
    if [[ ! -f "$admin_secret_script" ]]; then
        echo "[ERROR] Elasticsearch 管理员 Secret 脚本不存在: $admin_secret_script" >&2
        exit 1
    fi
    echo "[INFO] 部署 Elasticsearch 管理员认证 Secret..."
    bash "$admin_secret_script" --cluster "$CLUSTER" deploy "$NAMESPACE" || exit $?
fi

# 部署 Harbor Registry Secret（如果启用）
if [[ "${harbor_registry_secret_enabled:-true}" == "true" ]]; then
    if [[ -f "$ROOT_DIR/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh" ]]; then
        echo "[INFO] 部署 Harbor 镜像拉取密钥..."
        bash "$ROOT_DIR/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh" --cluster "$CLUSTER" \
            "${PROJECT_ID:-sunmoonai}" \
            "${NAMESPACE:-data-platform-dev}" \
            "${ENVIRONMENT:-development}" \
            "$DRY_RUN" || exit $?
    else
        echo "[ERROR] 启用的 Harbor Registry Secret 部署脚本不存在" >&2
        exit 1
    fi
fi

# 部署 Elasticsearch MyApp Secret（如果启用）
if [[ "${elasticsearch_myapp_secret_enabled:-true}" == "true" ]]; then
    echo "[INFO] 部署 Elasticsearch MyApp Secret..."
    if [[ "${APPLY_ELASTICSEARCH_MYAPP_SECRET:-false}" == "true" ]]; then
        # The same configuration-backed entry as direct deployment; no stale YAML input.
        myapp_script="$ROOT_DIR/elasticsearch-myapp-secret/deploy-elasticsearch-myapp-secret/deploy-elasticsearch-myapp-secret.sh"
        [[ -f "$myapp_script" ]] || { echo '[ERROR] MyApp Secret entry missing' >&2; exit 1; }
        bash "$myapp_script" --cluster "$CLUSTER" "$PROJECT_ID" "$NAMESPACE" "$ENVIRONMENT" "$DRY_RUN" || exit $?
    fi
fi

echo "[OK] Completed"
