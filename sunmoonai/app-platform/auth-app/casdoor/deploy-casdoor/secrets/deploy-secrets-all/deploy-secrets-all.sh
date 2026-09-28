#!/bin/bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" deploy-project "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"
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
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

[[ -f "$CONF_FILE" ]] || { echo "[ERROR] 缺少 Secret 总控配置文件" >&2; exit 1; }
source "$CONF_FILE"

if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping
fi

[[ -n "${CLUSTER:-}" ]] && echo "[INFO] 🎯 当前集群: ${CLUSTER}"

set -- "${ORIGINAL_ARGS[@]}"
PROJECT_ID="${1:-${PROJECT_ID:-sunmoonai}}"
NAMESPACE="${2:-${NAMESPACE:-app-platform-dev}}"
ENVIRONMENT="${3:-${ENVIRONMENT:-development}}"
DRY_RUN="${4:-false}"

# 部署 Harbor Registry Secret
if [[ "${harbor_registry_secret_enabled:-true}" == "true" ]]; then
    HARBOR_SECRET_SCRIPT="$ROOT_DIR/harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh"
    if [[ -f "$HARBOR_SECRET_SCRIPT" ]]; then
        echo "[INFO] 部署 Harbor 镜像拉取密钥..."
        bash "$HARBOR_SECRET_SCRIPT" \
            "${PROJECT_ID:-sunmoonai}" \
            "${NAMESPACE:-app-platform-dev}" \
            "${ENVIRONMENT:-development}" \
            "$DRY_RUN"
    else
        echo "[ERROR] 启用的 Harbor Registry Secret 脚本不存在: $HARBOR_SECRET_SCRIPT" >&2
        exit 1
    fi
fi

echo "[OK] Casdoor Secrets 部署完成"
