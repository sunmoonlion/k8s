#!/usr/bin/env bash
# 下载 NFS Provisioner chart 到当前目录，供 apply-nfs-existing-cluster.sh 离线使用。
# WSL 下会自动从 deploy-kind.conf 读取 HTTP_PROXY_WSL/HTTPS_PROXY_WSL 作为代理；也可手动 export HTTPS_PROXY=... 后执行。
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# WSL 下使用 deploy-kind.conf 中的代理（与 apply-nfs-existing-cluster.sh 一致）
KIND_CONF="${SCRIPT_DIR}/../deploy-kind/deploy-kind.conf"
if [[ -f "$KIND_CONF" ]]; then
    # shellcheck source=/dev/null
    source "$KIND_CONF" 2>/dev/null || true
    if [[ -n "${HTTP_PROXY_WSL:-}" ]]; then
        export HTTP_PROXY="${HTTP_PROXY_WSL}"
        export HTTPS_PROXY="${HTTPS_PROXY_WSL:-$HTTP_PROXY_WSL}"
        echo "使用 WSL 代理: HTTPS_PROXY=$HTTPS_PROXY"
    fi
fi

VERSION="${1:-4.0.18}"
TGZ="nfs-subdir-external-provisioner-${VERSION}.tgz"
URL="https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/releases/download/nfs-subdir-external-provisioner-${VERSION}/nfs-subdir-external-provisioner-${VERSION}.tgz"

if [[ -f "$TGZ" ]]; then
    echo "已存在 $TGZ，跳过下载。删除该文件可重新下载。"
    exit 0
fi

echo "下载 $TGZ ..."
curl -L -f -o "$TGZ" "$URL"
echo "✅ 已保存到 $SCRIPT_DIR/$TGZ"
