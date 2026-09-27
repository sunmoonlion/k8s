# 集群外镜像仓库

目标：一套部署代码，两种建集群方式；本地与云上均使用集群外 Harbor，统一地址 `harbor.sunmoonai.com:30443`。具体部署/迁移约束见 [主方案](../kind-infrastructure/docs/storage-and-harbor-placement-decision.md)。

当前已完成官方 2.13.2 物料准备、PostgreSQL 17.6 逻辑恢复及候选 Harbor 只读恢复核对；候选服务停止保留，具体结果见 [宿主机恢复记录](docs/host-recovery-plan.md)。五年叶证书已签发并离线校验，统一证书消费入口已接本地与云端适配；正式启停、证书安装、入口代理、认证推拉、完整备份恢复接口仍待完成，不能把演练副本当作正式仓库。

云端 step11 已接入本模块 `lib/config.sh` 的独立主机配置，只处理节点信任、解析和原版本入口镜像；方法及首次上云清单见 [使用方](../infrastructure/docs/registry-consumer.md)。云端仓库主机安装与前置步骤仍待接通，**未经实机验证**；主闭包门禁继续关闭。下文早期准备记录保留其当时范围。

## 服务证书

[五年证书与消费方法](docs/certificates.md)：原 CA 保持，Harbor/入口分别用新叶密钥，有效期至 2031-09-27。批次保存在 Git 外私有目录，仅公有摘要入库。未替换在线证书、未重启服务；云端仍未经实机验证。

## 物料准备

```bash
python3 sunmoonai/registry-platform/prepare-artifacts.py
python3 sunmoonai/registry-platform/prepare-artifacts.py --apply
```

默认只打印计划；执行时仅在 `~/packages-to-be-installed/releases/registry-platform-2.13.2-linux-amd64` 下载，保留 20 GiB 空间。每次最多 3 次、每次 180 秒，HTTPS 断点续传，最终大小和 SHA256 都匹配才改为正式文件名。半文件、失败收据保留；不改代理或 TLS 校验，不安装/导入镜像/连接远程主机。重复执行会复核并复用完整文件。

来源固定在 [Harbor 官方 2.13.2 发布](https://github.com/goharbor/harbor/releases/tag/v2.13.2)，大小和 SHA256 来自 GitHub release asset 元数据并写入 `artifacts.lock.json`。不要用 MD5 替代 SHA256。

本次 670,694,110 字节安装包经过两次超时续传，第三次完成并核验；证据 [luna-registry-artifacts.20260927.json](../scripts/results/luna-registry-artifacts.20260927.json)。下载成功不代表家庭网络长期稳定。

随后只读遍历内嵌镜像归档，确认包含 12 个 `goharbor/*:v2.13.2` 镜像，均为 linux/amd64；[清单](../scripts/results/luna-registry-installer-inventory.20260927.json)。未执行 Docker 导入或安装。镜像环境字段没有披露内置 PostgreSQL 的主版本，因此不能据此宣称其可接收现有 PostgreSQL 17.6 的逻辑备份；该兼容性仍需准入核实。

## 后续准入与实施

1. 数据盘需在 PID 1 与 Docker 的挂载空间检查通过；管理员会话单独成功不够。见 [数据盘操作卡](../kind-infrastructure/docs/owner-data-disk-100g.md)。
2. 单独核实 PostgreSQL 17.6、Compose、入口代理及其依赖闭包；当前安装包锁不包含这些物料，不能宣称部署物料齐备。
3. 保留原 Harbor 2.13.2 版本，逻辑导出/导入数据库、复制镜像层、带走加密密钥与原证书。全目录摘要一致后才具备后续切换条件。
4. 本地/SSH 共用部署实现；云端只做打印命令的演练与静态检查，标注未经实机验证并附首次上云清单。
5. 清理统一放到迁移验收后，按已批准类别重新复核；禁止容器/卷清理，不删除旧节点及冷备份。

## 数据库恢复演练

入口 `database-rehearsal.py` 的 `run`/`stop` 默认只打印，`check` 只读；明确批准后才用 `--apply` 创建独立数据库副本和三个专属容器。具体命令、固定输入、验收与恢复见 [执行卡](docs/database-rehearsal-plan.md)。

新盘/固定镜像/归档 SHA256 与 PG_VERSION 预检通过；[准备证据](../scripts/results/luna-registry-database-rehearsal-preparation.20260927.json)。脚本覆盖镜像的自动建卷目录，使用 `--network=none`、无端口、只读根文件系统，结束只停止并保留本次容器。源备份不挂入容器，旧 Harbor 和原 Kubernetes 恢复副本不变。冷备份演练通过也不代表最新数据已经迁移。

## 规则核对

| 规则 | 本单元 |
| --- | --- |
| C-R1/C-R2：版本与摘要固定 | 官方安装包锁定版本、字节数和 SHA256；OCI 制品准入另做 |
| C-I8：错误配置拒绝执行 | 摘要/大小/路径异常中止，未实现的部署能力不自动启用 |
| C-T5：分支与提交交回 | 仅本地 luna 提交，不推送、不发外部消息 |

本次实际演练已获批准并通过：49 张表、10,364 行及结构/权限/序列等一致，3 个新容器已停止，原 7 个容器和 43 个卷未变，旧 Harbor healthy。[执行结果](../scripts/results/luna-registry-database-rehearsal.20260927.json)。使用原批次的 run --apply 会拒绝覆盖；实际步骤和限制见执行卡第 7 节。
