#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR") )"
CONF_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

# 计算项目根目录（k8s目录）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
declare -a PARSED_ARGS

parse_cluster_arg() {
    local args=("$@")
    PARSED_ARGS=()
    local cluster_value=""
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        # 启用大小写不敏感匹配
        shopt -s nocasematch
        case "${args[$i]}" in
            --[cC][lL][uU][sS][tT][eE][rR]=*)
                # 支持等号形式：--cluster=C1 或 --CLUSTER=C1（大小写不敏感）
                cluster_value="${args[$i]#*=}"
                cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                export CLUSTER="$cluster_value"
                log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
                # 支持空格形式：--cluster C1 或 -c C1（大小写不敏感）
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    cluster_value="${args[$((i+1))]}"
                    cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                    export CLUSTER="$cluster_value"
                    log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                    i=$((i+1))
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    exit 1
                fi
                ;;
            *)
                PARSED_ARGS+=("${args[$i]}")
                ;;
        esac
        # 恢复大小写敏感匹配
        shopt -u nocasematch
        i=$((i+1))
    done
    
    if [[ -n "$cluster_value" ]]; then
        if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

# 先解析命令行参数（如果提供）
# 保存原始参数，以便后续使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载配置文件（现在可以使用已设置的 CLUSTER 值）
[[ -f "$CONF_FILE" ]] && source "$CONF_FILE"

# 加载集群配置映射函数（使用 utils 中的通用函数）
if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
    source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
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
    [[ "${APPLY_ELASTICSEARCH_MYAPP_SECRET:-false}" == "true" ]] && apply_yaml "$ROOT_DIR/elasticsearch-myapp-secret/elasticsearch-myapp-secret.sample.yaml"
fi

echo "[OK] Completed"

