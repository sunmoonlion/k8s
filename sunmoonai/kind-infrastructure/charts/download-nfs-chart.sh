#!/usr/bin/env bash
# 下载 NFS Provisioner chart 到当前目录，供 apply-nfs-existing-cluster.sh 离线使用。
# 有代理时可先 export HTTPS_PROXY=... 再执行。
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION="${1:-4.0.2}"
TGZ="nfs-subdir-external-provisioner-${VERSION}.tgz"
URL="https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/releases/download/nfs-subdir-external-provisioner-${VERSION}/nfs-subdir-external-provisioner-${VERSION}.tgz"

if [[ -f "$TGZ" ]]; then
    echo "已存在 $TGZ，跳过下载。删除该文件可重新下载。"
    exit 0
fi

echo "下载 $TGZ ..."
curl -L -f -o "$TGZ" "$URL"
echo "✅ 已保存到 $SCRIPT_DIR/$TGZ"
