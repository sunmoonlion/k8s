# 宿主 Harbor 的备份与独立恢复

本地与云上使用同一份Harbor运行配置，集群只是使用方。本入口先覆盖本次本地**已对账、只读、起始停止**的宿主实例。生产可写仓库的冻结/恢复写入、定时备份、远程SSH、云端实机均未在此入口实现，不能拿它直接停线上写库。

## 备什么、如何保持一致

`host_backup.py`默认只打印；显式执行时，持有与Harbor/入口生命周期相同的主机文件锁。已存在批次拒绝覆盖，失败文件保留。

1. 检查独立盘UUID、PID1/Docker可见性、镜像/配置/容器身份、此前恢复对账和只读验收。源8服务必须全部停止。
2. 暂启这个只读副本，通过严格TLS和原凭据取得当前全项目/仓库/制品目录；停止全部源服务。原入口/原仓库不参与此步骤。
3. 仅启动源PG17.6，核pg_dump/pg_dumpall同为17.6，导出globals.sql和custom格式registry.dump。前后分别核全部用户表、行数/行SHA、角色、结构、序列及is_called、扩展、数据库属性、大对象；不一致即拒绝完成。finally停止PG和其余源服务。
4. 全部停止后归档registry目录，以及明确列出的运行配置、TLS叶/信任CA、令牌签名/加密密钥、core-data、Redis持久数据和job-logs。不会复制Docker卷、数据库物理目录、无关实验日志或原CA私钥。
5. tar只允许目录/普通文件，拒绝软链、特殊文件、重复/越界路径、嵌套文件系统；保留数值UID/GID和mode。每个文件源SHA与归档重新读出的SHA一致，blob文件还必须与内容摘要路径一致。归档本身另存大小/SHA。
6. 所有步骤成功才写`backup.json complete=true`。`restore_verified`初始仍为false；备份文件存在不代表恢复成功。

每个备份目录root0700，导出、密钥/配置归档、目录清单和收据root0600。**整份备份按凭据保管**，不要贴内容或入Git。公开结果只记数量、大小、摘要和状态。Redis原样保留，但本次没有运行Jobservice；未来备份可写实例必须先明确队列在途任务及恢复去重策略，不能直接宣称已验证。

## 本次操作入口

从k8s仓根执行；无`--apply`时不访问Docker或私有源。实际示例路径绑定本机和本批次，不能覆盖重跑：

```sh
sudo -n python3 -B sunmoonai/registry-platform/host_backup.py backup \
  --backup /data/harbor/backups/host-main-20260927-v1 \
  --config /home/zymun/worktrees/luna/k8s/sunmoonai/registry-platform/config/harbor-main-local.json \
  --docker-credentials /home/zymun/.docker/config.json --apply

sudo -n python3 -B sunmoonai/registry-platform/host_backup.py verify \
  --backup /data/harbor/backups/host-main-20260927-v1 --apply

sudo -n python3 -B sunmoonai/registry-platform/host_backup.py restore-prepare \
  --backup /data/harbor/backups/host-main-20260927-v1 \
  --deployment sunmoon-harbor-backup-20260927 --apply
```

恢复准备要求**新实例目录**，镜像已离线准入，容器名无冲突，空间足够。镜像层完整复制后再次逐文件读取验SHA；私有配置和身份来自备份，不依赖原生成器重新生成密码/密钥。Compose仅更改project、network、container名字及宿主目录前缀，保留原路径版本作为证据；host-config改为引用这份备份的逻辑导出和registry归档。恢复准备不会创建或启动服务。

随后复用现有生命周期、逻辑恢复和只读HTTP验收：

```sh
sudo -n python3 -B sunmoonai/registry-platform/host_runtime.py create \
  --config /data/harbor/instances/sunmoon-harbor-backup-20260927/host-config.json --apply
sudo -n python3 -B sunmoonai/registry-platform/host_restore.py \
  --config /data/harbor/instances/sunmoon-harbor-backup-20260927/host-config.json --apply
sudo -n python3 -B sunmoonai/registry-platform/host_verify.py \
  --config /data/harbor/instances/sunmoon-harbor-backup-20260927/host-config.json \
  --docker-credentials /home/zymun/.docker/config.json --apply
sudo -n python3 -B sunmoonai/registry-platform/host_backup.py record-restore \
  --backup /data/harbor/backups/host-main-20260927-v1 \
  --config /data/harbor/instances/sunmoon-harbor-backup-20260927/host-config.json --apply
```

`record-restore`要求恢复实例确实引用同一备份、PG已对账、全目录及HTTP摘要验收已通过、所有容器再次停止，才记录`restore_verified=true`。此记录不表示重启WSL、重建KIND、Jobservice、push、CI/CD或云上已验收。

两个本地宿主副本都使用回环18443，必须逐个操作，不得同时启动。失败保留新目标供分析，停止仅针对受管容器ID；原备份和源实例不覆盖。磁盘空间不足时停止动作仍可执行。强制杀进程/断电可能跳过finally，恢复后先check/stop核对源和目标，不做任何容器/卷清理。

## 容量和保留

本次开始时100GiB数据盘可用66,187,816,960B，新源registry占用17,890,086,912B、PG物理目录72,540,160B。备份/恢复均按实际文件总量预检，另留20GiB常驻余量和2GiB数据库/元数据额度；这不是100GiB盘可以无限保存历史的承诺。每次执行重新统计，不以本次空间作为永久事实。

同盘备份防误删、部署升级失败，**同一块C盘物理硬盘故障仍会同时丢源和备份**。数据盘与系统盘分开VHDX也不改变这一点。最终清理必须最后执行并记录真实回收量；禁止清容器/卷、禁止删唯一可恢复备份。自动保留策略尚未启用，应先确定保留代数/天数和机器外副本后再设计删除入口。

机器外备份范围按所有者决定仅数据库、对象存储及`~/private`。本模块留下`database/`逻辑导出与`runtime.tar`密钥/配置的明确边界；镜像层归档位于`volumes/registry.tar`，不自动对外上传。落点（移动硬盘或加密对象存储）和保留期未定，**当前没有任何外传命令**。后续传输适配器须显式输入目的地、加密配置及允许的源集合，记录远端完整性/实际恢复证据；不能把内部只读下载服务器当备份目的地。

规则：C-D1源只读、候选不接正式写入；C-I8完整性或身份异常中止；C-R1/R2备份绑定版本/镜像和源实例；云端未经实机验证。

## 本次备份与最初导入基线的差异

本次宿主副本备份实际为49表、10,792行；最初从旧冷备份恢复为10,364行。逐表数量比较只发现`public.audit_log_ext`3478→3907（+429）和`public.scanner_registration`1→0，净增加428。前者是在验证期间产生的审计记录；后者与隔离配置关闭Trivy一致。[Harbor2.13.2的registerScanners实现](https://raw.githubusercontent.com/goharbor/harbor/v2.13.2/src/core/main.go)在WithTrivy=false时移除不可变Trivy登记，即使实例用于只读镜像验收，启动过程也不是数据库零写入。

因此，原先“恢复前后49表完全相同”只描述**启动Core之前**的逻辑恢复对账，不能扩大为Core运行后全部数据库数据仍与旧快照一致。本次备份和恢复以新副本当前状态为基线，不掩盖已少一条扫描器登记。旧仓库、最初数据库备份及原扫描器配置仍保留，正式迁移必须从最新冻结源保留/映射原扫描器与项目配置，并补扫描器/Jobservice验收；未完成不得因目录摘要通过就开放正式写入。未以原始SQL修改数据库来消除差异。

随后直接只读查询旧Harbor，仍healthy，扫描器`Trivy`登记仍在、disabled=false、is_default=true、URL为`http://sunmoonai-harbor-trivy:8080`。API未返回adapter/vendor/version/health，不能据此声称当前扫描器Pod或扫描任务健康。宿主副本实际`WITH_TRIVY=False`。后续须核旧扫描器精确镜像/任务状态，按原版本迁移并调整内部服务地址；禁用扫描器的当前8服务只读副本不能直接晋升为正式全功能实例。


## 已执行结果（2026-09-27）

`host-main-20260927-v1`备份完成，独立目标`sunmoon-harbor-backup-20260927`恢复通过并停止。registry归档17,868,021,760B，SHA`db2fad362a3e9b5d205e55764dc3ad8a675025e7a666ec759e53a5e8c9fbea3c`；4400文件共17,850,816,895B，全文件SHA通过。私有runtime归档1,116,160B，SHA`886b76caa15fa15412050ce8d001effc67e8665aee387eb2df01f4cf06ffc738`；原加密/签名/TLS叶身份随配置恢复。

PG17.6逻辑恢复49表10,792行与这份备份逐项一致。随后实际Harbor严格TLS、3projects/64repositories/429reachable/164tags目录一致；429manifest原始字节SHA及匿名拒绝通过，流式读取121,690,112B层SHA`ba9916be9d18f219a90a7eedd7d6a179dd9aecd3b38dc87d5ea85fbac2e18a2a`一致。record-restore再次核完整备份后登记restore_verified=true。Jobservice未启动、push未验。

源/恢复各9个容器均停止（含initializer；jobservice为created），候选SNI也停止；旧/验证6个KIND节点继续运行、旧Harbor健康，Docker卷仍46（包含此前SNI模块检查新增3卷，本单元未新增卷）。独立盘可用30,350,438,400B，约28.27GiB；后续不得盲目再复制一整套镜像数据挤破预留空间。备份与恢复副本保留，不清理。

一个Python文件AST、4个默认计划及git diff --check通过；没有新增/执行测试套件，以上是本次已授权真实备份恢复验收。脱敏证据：`sunmoonai/scripts/results/luna-harbor-host-backup.20260927.json`。没有机器外备份、云操作、30443切换、KIND重建或最终清理。

## 扫描器接入后的备份范围

带受管扫描器的实例，runtime归档增加整个 `scanner/`：配置、离线数据库、任务日志、登记验收收据及其变更前逻辑导出。主数据库的新逻辑导出包含受管默认登记；完整恢复沿用同一代码转换Compose宿主路径，服务内别名不变。此代码变更不等于已经再次完成整套独立恢复，具体批次必须以 `restore_verified` 为准。

可选 `--registry-from-backup` 仅接收已经完整核验并独立恢复过的备份。源全停后重新计算全部镜像文件SHA、大小、所有权与权限，与旧归档清单完全相同才硬链接旧的完整 `registry.tar`。不会链接运行目录；新备份中仍有完整文件入口，可按普通文件整份外传。数据库/runtime始终新建备份，任何镜像内容变化则拒绝复用。空间预检按新增实际内容计算，仍保留20GiB及2GiB数据库/元数据预留；不得降低门槛以绕过失败。

```bash
python3 -B sunmoonai/registry-platform/host_backup.py backup \
  --backup /data/harbor/backups/host-scanner-20260927-v1 \
  --config sunmoonai/registry-platform/config/harbor-main-local.json \
  --registry-from-backup /data/harbor/backups/host-main-20260927-v1
```

实际执行还需显式私有凭据路径与 `--apply`。清理时按inode引用计算释放量，不能把两个硬链接都计为能释放约17GB。所有旧备份继续保留。

新增受管扫描器备份 `host-scanner-20260927-v1` 已完成（registry归档复用、runtime全新归档），独立恢复尚未执行，详见[实测结果与空间门槛](host-scanner.md#本次实测收尾2026-09-27)。不得把旧布局 restore_verified=true 沿用到新备份。

## 受管模式和系统盘备份根

新增[host_mode.py backup](host-mode.md)负责停服前容量准入、切到只读、调用本冷备份、恢复原模式/运行状态。底层cold_backup对可写或未闭合转换拒绝执行。runtime归档包含writer-v1与scanner；恢复默认只读，重写新部署的两套Compose路径与身份，统一create创建两套停止容器。

WSL允许显式选择 `/var/backups/sunmoon-harbor/host-*`，用于100GiB数据盘保留演练副本时的新完整备份。必须另核C物理空间，预留数据盘长满100GiB的增长量、备份量及2GiB额外量，C剩余不得低于50GiB；路径不用于云默认值。该备份仍在同一物理盘，不是机器外灾备。先前备份和恢复记录保留，新writer布局恢复不能宣称已验收。
