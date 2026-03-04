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
HARBOR_IP="172.18.0.2"
HARBOR_PORT="30443"
HARBOR_USER="${HARBOR_ADMIN_USER:-admin}"
# 默认根 CA 位置（Kind 场景）：与 TRAEFIK_KIND_KIND_LOCAL_CA_CERT_DIR 一致
# 由 kind-infrastructure/ensure-kind-ca.sh 通过 unified-cert-secret-management 生成
HARBOR_CA_DEFAULT="$HOME/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt"

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

# ---------- 1. /etc/hosts（始终执行，Harbor 未部署也可先写好；若已存在但 IP 与配置不符则更新）
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

# ---------- 2. 可选：分发 CA 并 docker/nerdctl 登录（仅在使用 --login 或已设密码时执行）
DO_LOGIN=false
for arg in "$@"; do
    if [[ "$arg" == "--login" ]]; then DO_LOGIN=true; break; fi
done
[[ -n "${HARBOR_ADMIN_PASSWORD:-}" ]] && DO_LOGIN=true

if ! $DO_LOGIN; then
    echo "未传 --login 且未设 HARBOR_ADMIN_PASSWORD，跳过登录。Harbor 部署后可执行: $0 --login"
    exit 0
fi

# 先尝试将根 CA 分发到本机 docker 证书目录，便于 docker 信任 Harbor 自签名证书
REGISTRY="${HARBOR_HOST}:${HARBOR_PORT}"
DOCKER_CA_DIR="/etc/docker/certs.d/${REGISTRY}"
HARBOR_CA_PATH="${HARBOR_CA_PATH:-$HARBOR_CA_DEFAULT}"

if [[ -f "$HARBOR_CA_PATH" ]]; then
    echo "检测到根 CA: $HARBOR_CA_PATH"
    # Docker 按「主机:端口」查找证书：带端口用 REGISTRY 目录，不带端口(443)用仅主机名目录
    for _dir in "$DOCKER_CA_DIR" "/etc/docker/certs.d/${HARBOR_HOST}"; do
        echo "准备分发到本机 docker 证书目录: ${_dir}/ca.crt"
        sudo mkdir -p "$_dir"
        if sudo cp "$HARBOR_CA_PATH" "${_dir}/ca.crt"; then
            echo "✅ 已将 CA 证书复制到 ${_dir}/ca.crt"
        else
            echo "⚠️  无法复制 CA 证书到 ${_dir}，后续 docker login 可能出现证书相关错误"
        fi
    done
    # 同时加入系统信任存储，避免 dockerd/containerd 校验证书时 EOF（Docker 29+ 拉取可能走 containerd）
    if [[ -d /usr/local/share/ca-certificates ]]; then
        _sys_ca="/usr/local/share/ca-certificates/sunmoonai-harbor-ca.crt"
        if sudo cp "$HARBOR_CA_PATH" "$_sys_ca" 2>/dev/null; then
            if command -v update-ca-certificates &>/dev/null; then
                sudo update-ca-certificates 2>/dev/null && echo "✅ 已将根 CA 加入系统信任存储（${_sys_ca}）"
            fi
        fi
    fi
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

echo "之后可在 WSL 执行: docker pull ${REGISTRY}/<项目>/<镜像> && kind load docker-image <镜像> --name kind"
