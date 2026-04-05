#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"   # deploy-casdoor/secrets/
CONF_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

# 动态定位 k8s 根目录
K8S_ROOT_DIR=""
search_dir="$SCRIPT_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
        K8S_ROOT_DIR="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
[[ -z "$K8S_ROOT_DIR" ]] && { echo "[ERROR] 无法定位 k8s 根目录"; exit 1; }

source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"

declare -a PARSED_ARGS
ORIGINAL_ARGS=("$@")
[[ $# -gt 0 ]] && unified_parse_cluster_arg "$@" && ORIGINAL_ARGS=("${PARSED_ARGS[@]}")

[[ -f "$CONF_FILE" ]] && source "$CONF_FILE"

if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping
fi

[[ -n "${CLUSTER:-}" ]] && echo "[INFO] 🎯 当前集群: ${CLUSTER}"

NAMESPACE="${NAMESPACE:-app-platform-dev}"

# 部署 Harbor Registry Secret
if [[ "${harbor_registry_secret_enabled:-true}" == "true" ]]; then
    HARBOR_SECRET_SCRIPT="$ROOT_DIR/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh"
    if [[ -f "$HARBOR_SECRET_SCRIPT" ]]; then
        echo "[INFO] 部署 Harbor 镜像拉取密钥..."
        bash "$HARBOR_SECRET_SCRIPT" \
            "${PROJECT_ID:-sunmoonai}" \
            "${NAMESPACE:-app-platform-dev}" \
            "${ENVIRONMENT:-development}" \
            "false"
    else
        echo "[WARN] Harbor Registry Secret 脚本不存在，跳过: $HARBOR_SECRET_SCRIPT"
    fi
fi

echo "[OK] Casdoor Secrets 部署完成"
