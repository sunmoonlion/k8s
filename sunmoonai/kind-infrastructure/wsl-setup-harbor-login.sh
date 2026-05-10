#!/usr/bin/env bash
#
# 在 WSL 宿主机执行 Harbor 登录（docker/nerdctl），假定 /etc/hosts 中的 Harbor 解析已正确配置。
# 该脚本同时负责分发 Harbor 根 CA 到 docker certs.d 与系统 CA（若可用），以支持自签名证书。
#
# 用法：
#   ./wsl-setup-harbor-login.sh
#   HARBOR_ADMIN_PASSWORD=xxx ./wsl-setup-harbor-login.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${SCRIPT_DIR}/deploy-kind/deploy-kind.conf"

HARBOR_HOST="harbor.sunmoonai.com"
HARBOR_IP="127.0.0.1"
HARBOR_PORT="30443"
HARBOR_USER="${HARBOR_ADMIN_USER:-admin}"
# 默认根 CA 位置（Kind 场景）：与 TRAEFIK_KIND_KIND_LOCAL_CA_CERT_DIR 一致
HARBOR_CA_DEFAULT="$HOME/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt"

if [[ -f "$CONF" ]]; then
    # shellcheck disable=SC1090
    source "$CONF" 2>/dev/null || true
fi

HARBOR_HOST="${HARBOR_HOST:-harbor.sunmoonai.com}"
HARBOR_PORT="${HARBOR_PORT:-30443}"
if [[ "${HARBOR_USE_NODE_INTERNAL_IP:-false}" == "true" ]] && [[ -z "${HARBOR_IP:-}" ]]; then
    HARBOR_IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
fi
HARBOR_IP="${HARBOR_IP:-127.0.0.1}"

# 确保 hosts 已配置（重用新的 hosts 脚本，幂等）
"${SCRIPT_DIR}/wsl-setup-harbor-hosts.sh"

# 分发 CA（与 push-to-harbor 等共用脚本，避免 Traefik 续签后 Docker 仍信任旧 CA）
REGISTRY="${HARBOR_HOST}:${HARBOR_PORT}"
export HARBOR_HOST HARBOR_PORT HARBOR_CA_PATH="${HARBOR_CA_PATH:-$HARBOR_CA_DEFAULT}"
if [[ -f "${HARBOR_CA_PATH}" ]]; then
    echo "检测到根 CA: $HARBOR_CA_PATH"
    "${SCRIPT_DIR}/sync-docker-harbor-ca.sh"
else
    echo "⚠️  未找到根 CA 证书: $HARBOR_CA_PATH"
    echo "    如为 Kind 场景，请先在 WSL 中生成本地根 CA："
    echo "      cd ~/k8s/sunmoonai/kind-infrastructure"
    echo "      ./ensure-kind-ca.sh"
    echo "    或在一键部署中启用 DEPLOY_KIND_RUN_CA_INIT，再重跑 deploy-kind.sh。"
fi

echo "配置 WSL 登录 Harbor: ${REGISTRY}（${HARBOR_HOST} -> ${HARBOR_IP}）"

if [[ -z "${HARBOR_ADMIN_PASSWORD:-}" ]]; then
    echo "请输入 Harbor 管理员密码（或 export HARBOR_ADMIN_PASSWORD 后重试）："
    if docker login "${REGISTRY}" -u "${HARBOR_USER}"; then
        echo "✅ docker login 成功"
    else
        echo "⚠️  docker login 失败，Harbor 可能尚未部署或端口不可达，可稍后重试"
        exit 0
    fi
else
    if docker login "${REGISTRY}" -u "${HARBOR_USER}" -p "${HARBOR_ADMIN_PASSWORD}" 2>/dev/null; then
        echo "✅ docker login 成功"
    else
        echo "⚠️  docker login 失败，Harbor 可能尚未部署或密码错误，可稍后重试"
    fi
fi

if command -v nerdctl &>/dev/null; then
    if [[ -n "${HARBOR_ADMIN_PASSWORD:-}" ]]; then
        if sudo nerdctl -n k8s.io login "${REGISTRY}" -u "${HARBOR_USER}" -p "${HARBOR_ADMIN_PASSWORD}" 2>/dev/null; then
            echo "✅ nerdctl login 成功"
        else
            echo "⚠️  nerdctl login 失败（可忽略若只用 docker）"
        fi
    else
        echo "nerdctl 登录（需 sudo，请输入密码）："
        sudo nerdctl -n k8s.io login "${REGISTRY}" -u "${HARBOR_USER}" 2>/dev/null || true
    fi
fi

echo "Harbor 登录流程完成，可在 WSL 执行: docker pull ${REGISTRY}/<项目>/<镜像>"

