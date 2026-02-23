# 本地 Helm Chart（离线/弱网安装 NFS Provisioner）

当从 repo 或 curl 下载 chart 失败时，可将 chart 放到本目录，脚本会优先使用本地文件。

## 获取 chart

脚本默认使用 **4.0.2**（与最初成功版本一致）。在能访问 GitHub 的环境（或开代理）执行：

```bash
cd "$(dirname "$0")"
# 默认版本 4.0.2
curl -L -f -o nfs-subdir-external-provisioner-4.0.2.tgz \
  "https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/releases/download/nfs-subdir-external-provisioner-4.0.2/nfs-subdir-external-provisioner-4.0.2.tgz"
# 或备用 4.0.18
curl -L -f -o nfs-subdir-external-provisioner-4.0.18.tgz \
  "https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/releases/download/nfs-subdir-external-provisioner-4.0.18/nfs-subdir-external-provisioner-4.0.18.tgz"
```

将下载好的 `nfs-subdir-external-provisioner-4.0.2.tgz`（或 4.0.18）放到本目录。

## 使用

- 脚本默认查找：`charts/nfs-subdir-external-provisioner-4.0.2.tgz`（版本见 `apply-nfs-existing-cluster.sh` 中 `NFS_CHART_VERSION`）。
- 也可通过环境变量：`NFS_CHART_TGZ=/path/to/xxx.tgz ./apply-nfs-existing-cluster.sh`，或配置 `STEP09_NFS_CHART_VERSION=4.0.18`。
