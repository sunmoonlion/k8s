# 本地 Helm Chart（离线/弱网安装 NFS Provisioner）

当从 repo 或 curl 下载 chart 失败时，可将 chart 放到本目录，脚本会优先使用本地文件。

## 获取 chart

**方式一：用脚本下载（推荐）**

在能访问 GitHub 的环境（或开代理，如 `export HTTPS_PROXY=http://172.28.32.1:7890`）执行：

```bash
cd /path/to/kind-infrastructure/charts
./download-nfs-chart.sh        # 默认下载 4.0.18
./download-nfs-chart.sh 4.0.2  # 指定版本
```

**方式二：手动 curl**

```bash
cd charts
curl -L -f -o nfs-subdir-external-provisioner-4.0.18.tgz \
  "https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/releases/download/nfs-subdir-external-provisioner-4.0.18/nfs-subdir-external-provisioner-4.0.18.tgz"
```

将下载好的 `nfs-subdir-external-provisioner-4.0.18.tgz` 放在本目录即可。

## 使用

- 脚本默认查找：`charts/nfs-subdir-external-provisioner-4.0.18.tgz`（版本见 `apply-nfs-existing-cluster.sh` 中 `NFS_CHART_VERSION`）。
- 也可通过环境变量：`NFS_CHART_TGZ=/path/to/xxx.tgz ./apply-nfs-existing-cluster.sh`，或配置 `STEP09_NFS_CHART_VERSION=4.0.2` 等。
