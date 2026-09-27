# 集群外镜像仓库

目标：一套部署代码，两种建集群方式；本地与云上均使用集群外 Harbor，统一地址 `harbor.sunmoonai.com:30443`。具体部署/迁移约束见 [主方案](../kind-infrastructure/docs/storage-and-harbor-placement-decision.md)。

当前已完成官方2.13.2物料准备、原候选恢复，以及独立新宿主实例的准备/逻辑恢复/只读启停验收；新实例的五年证书已实际握手通过。[新实例操作与结果](docs/host-instance.md)是当前入口，早期[恢复演练记录](docs/host-recovery-plan.md)保留。两套副本均停止保留，旧30443未切换；本地SNI候选代理也已通过只读验收并停止，见[入口操作](docs/sni-entry.md)；正式写入、30443切换、Jobservice/CI-CD推拉、生产可写备份冻结与自动启动仍待完成。[宿主只读实例备份/独立恢复](docs/host-backup.md)已实测通过；发现扫描器登记未被隔离副本保留，正式迁移须先补齐。

云端 step11 已接入本模块 `lib/config.sh` 的独立主机配置，只处理节点信任、解析和原版本入口镜像；方法及首次上云清单见 [使用方](../infrastructure/docs/registry-consumer.md)。云端仓库主机安装与前置步骤仍待接通，**未经实机验证**；主闭包门禁继续关闭。下文早期准备记录保留其当时范围。

## 共用运行配置

[正式配置生成与已核对范围](docs/runtime-rendering.md)：本地/云端共用官方2.13.2输出转换，固定PG17.6/Redis8.2.1，纳入Jobservice认证及显式数据挂载。四组配置通过只读渲染/Compose解析；随后已完成[本地新实例](docs/host-instance.md)的数据复制和只读生命周期验收；全新主机安装、正式写入与云端SSH仍需继续。

## 服务证书

[五年证书与消费方法](docs/certificates.md)：原 CA 保持，Harbor/入口分别用新叶密钥，有效期至 2031-09-27。批次保存在 Git 外私有目录，仅公有摘要入库。新宿主实例已使用新证书短暂运行并验收后停止；原30443服务证书不变，云端仍未经实机验证。

## 物料准备

原 Trivy 镜像与漏洞数据库分开准备，复用方法与验收边界见 [扫描器离线物料](docs/scanner-offline.md)。原镜像保持2.13.2包装/Trivy0.64.1；旧缓存为空，补齐当日数据库后已通过断网rootfs扫描，识别954包。自身镜像报告严重漏洞，尚未获正式镜像准入，需核适用性与最小修复版本。新宿主的扫描器登记、Jobservice与私有镜像扫描接线仍待完成。

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
