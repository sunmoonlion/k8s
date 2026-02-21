#!/usr/bin/env bash
#
# 在 WSL 中安装并配置 NFS 服务，供 Kind 挂载（export /data/kind-nfs）
# 请在 WSL 终端中执行：bash wsl-setup-nfs-server.sh  或  chmod +x 后 ./wsl-setup-nfs-server.sh
# 需要 sudo 权限。
#
set -euo pipefail

NFS_EXPORT_DIR="${NFS_EXPORT_DIR:-/data/kind-nfs}"

echo "ℹ️  安装 nfs-kernel-server..."
sudo apt-get update
sudo apt-get install -y nfs-kernel-server

echo "ℹ️  创建导出目录: $NFS_EXPORT_DIR"
sudo mkdir -p "$NFS_EXPORT_DIR"
sudo chown nobody:nogroup "$NFS_EXPORT_DIR"
sudo chmod 777 "$NFS_EXPORT_DIR"

echo "ℹ️  配置 /etc/exports（追加一行，若已存在则跳过）..."
if grep -q "^${NFS_EXPORT_DIR} " /etc/exports 2>/dev/null; then
    echo "   已存在 ${NFS_EXPORT_DIR} 的导出，跳过"
else
    # insecure：允许客户端从高端口(>1024)挂载，kubelet 挂 NFS 需要
    echo "${NFS_EXPORT_DIR} *(rw,sync,no_subtree_check,no_root_squash,insecure)" | sudo tee -a /etc/exports
fi

echo "ℹ️  应用 exports 并启动服务..."
sudo exportfs -ra
if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null; then
    sudo systemctl start nfs-kernel-server
    sudo systemctl enable nfs-kernel-server 2>/dev/null || true
else
    sudo service nfs-kernel-server start 2>/dev/null || true
fi

echo "✅ NFS 服务已就绪"
echo "   导出路径: $NFS_EXPORT_DIR"
echo "   本机自测: sudo mount -t nfs 127.0.0.1:${NFS_EXPORT_DIR} /mnt && touch /mnt/test && ls /mnt && sudo umount /mnt"
echo "   Kind 使用: 在 Kind 集群就绪后执行 ./apply-nfs-existing-cluster.sh"
