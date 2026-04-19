#!/usr/bin/env bash
#
# 将当前仓库中的 Harbor（Traefik）根 CA 同步到 WSL 本机 Docker certs.d 与系统 CA 存储。
# 解决：1) 磁盘 ca.crt 与 certs.d 不一致；2) 同主机多目录（如 :30443 与 :443）下旧根 CA 与
#       当前根 CA 同 CN 不同密钥，Docker 选错锚点导致 /service/token TLS 失败（RSA verification error）。
#
# 用法：
#   ./sync-docker-harbor-ca.sh
# 可选环境变量（与 wsl-setup-harbor-login.sh 一致）：
#   HARBOR_HOST HARBOR_PORT HARBOR_CA_PATH
#   SYNC_DOCKER_RESTART_DOCKER=true  在同步后重启 dockerd（会中断本机全部容器；仅建议在无 Kind/无关键负载时使用）
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${SCRIPT_DIR}/deploy-kind/deploy-kind.conf"

HARBOR_HOST="${HARBOR_HOST:-harbor.sunmoonai.com}"
HARBOR_PORT="${HARBOR_PORT:-30443}"
HARBOR_CA_DEFAULT="$HOME/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt"

if [[ -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  source "$CONF" 2>/dev/null || true
fi

HARBOR_HOST="${HARBOR_HOST:-harbor.sunmoonai.com}"
HARBOR_PORT="${HARBOR_PORT:-30443}"
HARBOR_CA_PATH="${HARBOR_CA_PATH:-$HARBOR_CA_DEFAULT}"

REGISTRY="${HARBOR_HOST}:${HARBOR_PORT}"
DOCKER_CA_DIR="/etc/docker/certs.d/${REGISTRY}"

if [[ ! -f "$HARBOR_CA_PATH" ]]; then
  echo "⚠️  未找到根 CA: $HARBOR_CA_PATH（跳过 Docker CA 同步）" >&2
  exit 0
fi

echo "ℹ️  同步 Harbor 根 CA 到本机 Docker/系统信任: $HARBOR_CA_PATH -> ${REGISTRY}"

# 覆盖本机已存在的所有「同一 Harbor 主机」的 certs.d 目录（含历史 :443 等），避免多份同 CN 根 CA 冲突
shopt -s nullglob
_ca_dirs=(/etc/docker/certs.d/"${HARBOR_HOST}"*)
shopt -u nullglob
if [[ ${#_ca_dirs[@]} -eq 0 ]]; then
  _ca_dirs=("$DOCKER_CA_DIR" "/etc/docker/certs.d/${HARBOR_HOST}")
fi
# 确保当前 registry 与无端口目录一定存在（glob 可能漏掉仅主机名目录的边界情况）
_extra=("$DOCKER_CA_DIR" "/etc/docker/certs.d/${HARBOR_HOST}" "/etc/docker/certs.d/${HARBOR_HOST}:443")
for _d in "${_extra[@]}"; do
  [[ " ${_ca_dirs[*]} " == *" ${_d} "* ]] || _ca_dirs+=("$_d")
done

for _dir in "${_ca_dirs[@]}"; do
  sudo mkdir -p "$_dir"
  sudo cp "$HARBOR_CA_PATH" "${_dir}/ca.crt"
  echo "✅ ${_dir}/ca.crt"
done

if [[ -d /usr/local/share/ca-certificates ]]; then
  _sys_ca="/usr/local/share/ca-certificates/sunmoonai-harbor-ca.crt"
  if sudo cp "$HARBOR_CA_PATH" "$_sys_ca" 2>/dev/null; then
    if command -v update-ca-certificates &>/dev/null; then
      sudo update-ca-certificates >/dev/null 2>&1 && echo "✅ 系统 CA 已更新（${_sys_ca}）"
    fi
  fi
fi

# dockerd 会缓存 certs.d / 系统信任；仅改文件后 docker push 仍可能报 TLS，需重载 daemon
if [[ "${SYNC_DOCKER_RESTART_DOCKER:-}" == "true" ]] && command -v systemctl &>/dev/null; then
  echo "ℹ️  SYNC_DOCKER_RESTART_DOCKER=true：正在重启 docker 以重读证书..."
  sudo systemctl restart docker
  echo "✅ docker 已重启"
else
  echo "ℹ️  若 docker push 仍报 TLS/x509，请执行: sudo systemctl restart docker（重读 /etc/docker/certs.d）"
fi

exit 0
