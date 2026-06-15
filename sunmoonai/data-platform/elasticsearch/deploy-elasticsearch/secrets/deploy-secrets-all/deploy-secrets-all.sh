#!/bin/bash
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

# 加载配置文件（现在可以使用已设置的 CLUSTER 值）
[[ -f "$CONF_FILE" ]] && source "$CONF_FILE"

# 加载集群配置映射函数（使用 utils 中的通用函数）
if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
    apply_cluster_config_mapping
fi

if [[ -n "${CLUSTER:-}" ]]; then
    echo "[INFO] 🎯 当前集群配置: ${CLUSTER}"
fi

NAMESPACE="${NAMESPACE:-data-platform-dev}"

apply_yaml() {
  local file="$1"
  if [[ -f "$file" ]]; then
    echo "[INFO] kubectl apply -f $file -n $NAMESPACE"
    kubectl apply -f "$file" -n "$NAMESPACE"
  fi
}

# 部署 Elasticsearch 管理员认证 Secret
if [[ "${elasticsearch_admin_secret_enabled:-true}" == "true" ]]; then
    admin_secret_script="$ROOT_DIR/elasticsearch-secrets/deploy-elasticsearch-secrets/deploy-elasticsearch-secrets.sh"
    if [[ ! -x "$admin_secret_script" ]]; then
        echo "[ERROR] Elasticsearch 管理员 Secret 脚本不存在或不可执行: $admin_secret_script" >&2
        exit 1
    fi
    echo "[INFO] 部署 Elasticsearch 管理员认证 Secret..."
    "$admin_secret_script" deploy "$NAMESPACE"
fi

# 部署 Harbor Registry Secret（如果启用）
if [[ "${harbor_registry_secret_enabled:-true}" == "true" ]]; then
    if [[ -f "$ROOT_DIR/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh" ]]; then
        echo "[INFO] 部署 Harbor 镜像拉取密钥..."
        "$ROOT_DIR/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh" \
            "${PROJECT_ID:-sunmoonai}" \
            "${NAMESPACE:-data-platform-dev}" \
            "${ENVIRONMENT:-development}" \
            "false"
    else
        echo "[WARN] Harbor Registry Secret 部署脚本不存在，跳过"
    fi
fi

# 部署 Elasticsearch MyApp Secret（如果启用）
if [[ "${elasticsearch_myapp_secret_enabled:-true}" == "true" ]]; then
    echo "[INFO] 部署 Elasticsearch MyApp Secret..."
    [[ "${APPLY_ELASTICSEARCH_MYAPP_SECRET:-false}" == "true" ]] && apply_yaml "$ROOT_DIR/elasticsearch-myapp-secret/elasticsearch-myapp-secret.yaml.example"
fi

echo "[OK] Completed"
