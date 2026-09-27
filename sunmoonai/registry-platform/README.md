# 集群外镜像仓库

目标：一套部署代码，两种建集群方式；本地与云上均使用集群外 Harbor，统一地址 `harbor.sunmoonai.com:30443`。具体部署/迁移约束见 [主方案](../kind-infrastructure/docs/storage-and-harbor-placement-decision.md)。

当前只实现 **Harbor 官方 2.13.2 离线安装包准备**。本地部署、SSH 执行、备份恢复与入口代理尚未实现，云上未经实机验证。本目录存在不代表仓库已部署。

## 物料准备

```bash
python3 sunmoonai/registry-platform/prepare-artifacts.py
python3 sunmoonai/registry-platform/prepare-artifacts.py --apply
```

默认只打印计划；执行时仅在 `~/packages-to-be-installed/releases/registry-platform-2.13.2-linux-amd64` 下载，保留 20 GiB 空间。每次最多 3 次、每次 180 秒，HTTPS 断点续传，最终大小和 SHA256 都匹配才改为正式文件名。半文件、失败收据保留；不改代理或 TLS 校验，不安装/导入镜像/连接远程主机。重复执行会复核并复用完整文件。

来源固定在 [Harbor 官方 2.13.2 发布](https://github.com/goharbor/harbor/releases/tag/v2.13.2)，大小和 SHA256 来自 GitHub release asset 元数据并写入 `artifacts.lock.json`。不要用 MD5 替代 SHA256。

本次 670,694,110 字节安装包经过两次超时续传，第三次完成并核验；证据 [luna-registry-artifacts.20260927.json](../scripts/results/luna-registry-artifacts.20260927.json)。下载成功不代表家庭网络长期稳定。

## 后续准入与实施

1. 数据盘需在 PID 1 与 Docker 的挂载空间检查通过；管理员会话单独成功不够。见 [数据盘操作卡](../kind-infrastructure/docs/owner-data-disk-100g.md)。
2. 单独核实 PostgreSQL 17.6、Compose、入口代理及其依赖闭包；当前安装包锁不包含这些物料，不能宣称部署物料齐备。
3. 保留原 Harbor 2.13.2 版本，逻辑导出/导入数据库、复制镜像层、带走加密密钥与原证书。全目录摘要一致后才具备后续切换条件。
4. 本地/SSH 共用部署实现；云端只做打印命令的演练与静态检查，标注未经实机验证并附首次上云清单。
5. 清理统一放到迁移验收后，按已批准类别重新复核；禁止容器/卷清理，不删除旧节点及冷备份。

## 规则核对

| 规则 | 本单元 |
| --- | --- |
| C-R1/C-R2：版本与摘要固定 | 官方安装包锁定版本、字节数和 SHA256；OCI 制品准入另做 |
| C-I8：错误配置拒绝执行 | 摘要/大小/路径异常中止，未实现的部署能力不自动启用 |
| C-T5：分支与提交交回 | 仅本地 luna 提交，不推送、不发外部消息 |
