#!/usr/bin/env bash
#
# sync-ca-from-k8s.sh — 从 K8s secret 同步 CA 到本地归档
#
# 用途：当本地归档 CA 与 K8s 部署的 CA 不一致时（Step12 分发前校验报错），
#       用此脚本从 K8s secret 拉取权威 CA 覆盖本地归档。
#
# 使用方式：
#   bash sync-ca-from-k8s.sh [--combo COMBO] [--cluster CLUSTER]
#
# 示例：
#   bash sync-ca-from-k8s.sh                          # 默认 combo=TRAEFIK_K1_K1
#   bash sync-ca-from-k8s.sh --combo TRAEFIK_K1_K1
#   CLUSTER=C2 bash sync-ca-from-k8s.sh
#
# 注意：此脚本只更新 ca.crt（公钥），不更新 ca.key（私钥）。
#       同步后如需重新签发服务器证书，需要配合 deploy-server.sh 使用。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/ssh.sh"

COMBO="${COMBO:-TRAEFIK_K1_K1}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --combo) COMBO="$2"; shift 2 ;;
        --cluster) export CLUSTER="$2"; shift 2 ;;
        *) log_error "未知参数: $1"; exit 1 ;;
    esac
done

# 加载 cert-secret.conf
CONF_FILE="$PROJECT_ROOT/cert-secret.conf"
[[ -f "$CONF_FILE" ]] && source "$CONF_FILE"

# 应用集群配置映射
K8S_ROOT="$(cd "$PROJECT_ROOT/../.." && pwd)"
if [[ -f "$K8S_ROOT/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT/utils/cluster-config-mapping.sh"
    command -v apply_cluster_config_mapping &>/dev/null && apply_cluster_config_mapping
fi

log_info "Combo: $COMBO${CLUSTER:+（集群: $CLUSTER）}"

# 读取 K8s secret 配置
secret_name=$(get_five_layer_config "$COMBO" "CA_VALIDATE_SECRET_NAME" 2>/dev/null || echo "")
if [[ -z "$secret_name" ]]; then
    log_error "未配置 ${COMBO}_CA_VALIDATE_SECRET_NAME，无法从 K8s 同步 CA"
    exit 1
fi
secret_namespace=$(get_five_layer_config "$COMBO" "CA_VALIDATE_SECRET_NAMESPACE" 2>/dev/null || echo "")
secret_key=$(get_five_layer_config "$COMBO" "CA_VALIDATE_SECRET_KEY" 2>/dev/null || echo "ca.crt")

# 读取服务端 SSH 信息
server_prefix=$(echo "$COMBO" | sed 's/_[KDN][0-9]*$//')
server_host=$(get_five_layer_config "${server_prefix}_K1" "SERVER_HOST" 2>/dev/null || get_five_layer_config "$COMBO" "SERVER_HOST" 2>/dev/null || echo "")
server_port=$(get_five_layer_config "${server_prefix}_K1" "SERVER_PORT" 2>/dev/null || echo "22")
server_username=$(get_five_layer_config "${server_prefix}_K1" "SERVER_USERNAME" 2>/dev/null || echo "root")
server_ssh_key=$(get_five_layer_config "${server_prefix}_K1" "SERVER_SSH_KEY" 2>/dev/null || echo "")
server_ssh_key="${server_ssh_key/#\~/$HOME}"

if [[ -z "$server_host" ]]; then
    log_error "未找到服务端 SSH 配置（SERVER_HOST）"
    exit 1
fi

# 读取本地归档目录
local_ca_cert_dir=$(get_five_layer_config "$COMBO" "LOCAL_CA_CERT_DIR" 2>/dev/null || echo "")
local_ca_cert_dir="${local_ca_cert_dir/#\~/$HOME}"
if [[ -z "$local_ca_cert_dir" ]]; then
    log_error "未配置 LOCAL_CA_CERT_DIR"
    exit 1
fi

log_info "从 K8s 获取 CA: ${server_username}@${server_host}:${server_port} → ${secret_namespace}/${secret_name}[${secret_key}]"

# 从 K8s secret 拉取 CA
k8s_ca_content=$(ssh -i "$server_ssh_key" -p "$server_port" \
    -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
    "${server_username}@${server_host}" \
    "kubectl get secret ${secret_name} -n ${secret_namespace} -o jsonpath='{.data.${secret_key}}' 2>/dev/null | base64 -d" 2>/dev/null || echo "")

if [[ -z "$k8s_ca_content" ]]; then
    log_error "无法从 K8s 获取 CA（secret 不存在或 kubectl 不可用）"
    exit 1
fi

k8s_fp=$(echo "$k8s_ca_content" | openssl x509 -noout -fingerprint -sha256 2>/dev/null || echo "")
log_info "K8s CA 指纹: $k8s_fp"

# 显示本地现有 CA（如果有）
local_ca_path="$local_ca_cert_dir/ca.crt"
if [[ -f "$local_ca_path" ]]; then
    local_fp=$(openssl x509 -noout -fingerprint -sha256 -in "$local_ca_path" 2>/dev/null || echo "")
    if [[ "$local_fp" == "$k8s_fp" ]]; then
        log_info "本地归档已与 K8s 一致，无需同步"
        exit 0
    fi
    log_warn "本地归档指纹: $local_fp（与 K8s 不一致，将被覆盖）"
else
    log_warn "本地归档不存在，将从 K8s 创建"
fi

# 备份旧 CA
if [[ -f "$local_ca_path" ]]; then
    backup_path="${local_ca_path}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$local_ca_path" "$backup_path"
    log_info "旧 CA 已备份: $backup_path"
fi

# 写入新 CA
mkdir -p "$local_ca_cert_dir"
echo "$k8s_ca_content" > "$local_ca_path"
chmod 644 "$local_ca_path"

log_success "本地归档已同步: $local_ca_path"
log_info "指纹: $(openssl x509 -noout -fingerprint -sha256 -in "$local_ca_path" 2>/dev/null)"
log_warn "注意：ca.key 未同步（私钥不存储于 K8s）。若需重新签发服务器证书，原私钥必须仍在 ${local_ca_cert_dir}/ca.key"
