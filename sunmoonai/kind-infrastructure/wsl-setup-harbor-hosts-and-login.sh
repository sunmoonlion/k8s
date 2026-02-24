#!/usr/bin/env bash
#
# 在 WSL 宿主机配置 Harbor：① /etc/hosts 解析 ②（可选）docker/nerdctl 登录。
# Harbor 未部署时也可执行，仅做 hosts；部署后可用 --login 或 HARBOR_ADMIN_PASSWORD 再运行以配置拉取/推送。
#
# 用法：
#   ./wsl-setup-harbor-hosts-and-login.sh              # 仅 hosts（deploy-kind 默认）
#   ./wsl-setup-harbor-hosts-and-login.sh --login      # hosts + 尝试登录（交互输密码或设 HARBOR_ADMIN_PASSWORD）
#   HARBOR_ADMIN_PASSWORD=xxx ./wsl-setup-harbor-hosts-and-login.sh --login
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${SCRIPT_DIR}/deploy-kind/deploy-kind.conf"
HARBOR_HOST="harbor.sunmoonai.com"
HARBOR_IP="127.0.0.1"
HARBOR_PORT="30443"
HARBOR_USER="${HARBOR_ADMIN_USER:-admin}"

if [[ -f "$CONF" ]]; then
    # shellcheck disable=SC1090
    source "$CONF" 2>/dev/null || true
fi
HARBOR_HOST="${HARBOR_HOST:-harbor.sunmoonai.com}"
HARBOR_IP="${HARBOR_IP:-127.0.0.1}"
HARBOR_PORT="${HARBOR_PORT:-30443}"

# ---------- 1. /etc/hosts（始终执行，Harbor 未部署也可先写好）
if ! grep -q "[[:space:]]${HARBOR_HOST}[[:space:]]*$" /etc/hosts 2>/dev/null && \
   ! grep -q "[[:space:]]${HARBOR_HOST}$" /etc/hosts 2>/dev/null; then
    echo "添加 ${HARBOR_IP} ${HARBOR_HOST} 到 /etc/hosts"
    echo "${HARBOR_IP} ${HARBOR_HOST}" | sudo tee -a /etc/hosts
else
    echo "已存在 ${HARBOR_HOST} 解析，跳过"
fi

# ---------- 2. 可选：docker/nerdctl 登录（仅在使用 --login 或已设密码时执行）
DO_LOGIN=false
for arg in "$@"; do
    if [[ "$arg" == "--login" ]]; then DO_LOGIN=true; break; fi
done
[[ -n "${HARBOR_ADMIN_PASSWORD:-}" ]] && DO_LOGIN=true

if ! $DO_LOGIN; then
    echo "未传 --login 且未设 HARBOR_ADMIN_PASSWORD，跳过登录。Harbor 部署后可执行: $0 --login"
    exit 0
fi

REGISTRY="${HARBOR_HOST}:${HARBOR_PORT}"
echo "配置 WSL 登录 Harbor: ${REGISTRY}"

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

echo "之后可在 WSL 执行: docker pull ${REGISTRY}/<项目>/<镜像> && kind load docker-image <镜像> --name kind"
