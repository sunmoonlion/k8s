#!/usr/bin/env bash
#
# 在 WSL 宿主机配置 Harbor 域名解析（仅 /etc/hosts 部分，不做登录）。
# Harbor 未部署时也可执行，用于提前写好解析记录。
#
# 用法：
#   ./wsl-setup-harbor-hosts.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${SCRIPT_DIR}/deploy-kind/deploy-kind.conf"

# 默认值，与 wsl-setup-harbor-hosts-and-login.sh 保持一致
HARBOR_HOST="harbor.sunmoonai.com"
HARBOR_IP="172.18.0.2"
HARBOR_PORT="30443"

if [[ -f "$CONF" ]]; then
    # shellcheck disable=SC1090
    source "$CONF" 2>/dev/null || true
fi

HARBOR_HOST="${HARBOR_HOST:-harbor.sunmoonai.com}"
HARBOR_PORT="${HARBOR_PORT:-30443}"

# 未显式配置 HARBOR_IP 时，从当前 kubeconfig 的 Kind control-plane 节点自动检测，集群重建后仍可用
if [[ -z "${HARBOR_IP:-}" ]]; then
    HARBOR_IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
fi
HARBOR_IP="${HARBOR_IP:-${HARBOR_NODE_IP:-172.18.0.2}}"

# 在 /etc/hosts 中维护 harbor.sunmoonai.com → HARBOR_IP
if grep -q "[[:space:]]${HARBOR_HOST}[[:space:]]*$" /etc/hosts 2>/dev/null || grep -q "[[:space:]]${HARBOR_HOST}$" /etc/hosts 2>/dev/null; then
    _cur=$(grep -E "^[0-9.]+[[:space:]]+${HARBOR_HOST}[[:space:]]*$" /etc/hosts 2>/dev/null | head -1)
    if [[ -n "${_cur}" && "${_cur}" != "${HARBOR_IP}"* ]]; then
        echo "更新 /etc/hosts：${HARBOR_HOST} -> ${HARBOR_IP}（原 IP 与配置不符）"
        sudo sed -i -E "s/^[0-9.]+[[:space:]]+${HARBOR_HOST}[[:space:]]*$/${HARBOR_IP} ${HARBOR_HOST}/" /etc/hosts
    else
        echo "已存在 ${HARBOR_HOST} 解析，跳过"
    fi
else
    echo "添加 ${HARBOR_IP} ${HARBOR_HOST} 到 /etc/hosts"
    echo "${HARBOR_IP} ${HARBOR_HOST}" | sudo tee -a /etc/hosts
fi

echo "WSL Harbor hosts 配置完成：${HARBOR_HOST} -> ${HARBOR_IP}"

