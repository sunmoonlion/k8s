# 宿主 Harbor 的受管读写模式

目标：一套部署代码、两种建群方式。Harbor脱离KIND，沿用官方2.13.2及原PG17.6/Redis8.2.1。此处提供宿主服务运行和备份的统一接口；本地API适配器只访问候选18443；云端按配置访问独立仓库主机的私网IPv4:30443。两边共用配置生成、TLS与生命周期代码，云端分支**未经实机验证**。域名解析必须与明确的目标地址一致，不能隐式连接其他仓库。

## 模式、配置与数据

原 `host-config.json.runtime.write_enabled=false` 是创建/恢复时的初始策略，不能手改它晋升。实际已核模式只有 `runtime-state.json.service_mode` 一个运行状态源（缺省read-only），由 `host_mode.py` 明确转换；`host_runtime.py` 按这个状态选择容器。

- read-only：原registry/registryctl/core；registry文件挂载RO、API只读。
- writable：受管writer-v1的registry/registryctl/core；原固定官方镜像、同一宿主数据目录、registry挂载RW、API可写。另一套三个容器始终停止保留。PG/Redis/proxy/portal/扫描器和任务服务共用原实例，不复制数据。
- 原配置及配置摘要保留。`writer_config.py` 供推拉验收和持续运行共用，新增配置放私有writer-v1；权限、镜像、容器ID、环境和挂载继续硬校验。
- 每次转换先停两套容器、保存转换标记，再按目标模式启动；导出PG逻辑备份后设置并读取API模式，核registry挂载。可写模式随后启动受管任务服务并核就绪。完成清除标记；失败全停并保留标记。
- 模式回退只收回写权限，**不撤销已接受的数据**。跨版本回滚和迁移回旧仓仍须完整备份/数据同步，不能以模式切换冒充数据恢复。

普通start在writable模式自动含受管任务服务，在readonly模式默认不含任务；`--with-jobs`仍用于已验收的只读扫描场景。统一stop停止两套受管容器，低空间不阻止停服，不删除容器/卷。

## 命令

从k8s仓根执行。全部默认只打印；实际动作使用已批准范围内的 `--apply`。

```bash
# 第一次准备；只创建停止的可写容器，原服务/配置保留。
python3 -B sunmoonai/registry-platform/host_mode.py prepare \
  --config sunmoonai/registry-platform/config/harbor-main-local.json

# 切换后验证并停止。确认要保持服务运行时显式追加 --leave-running。
python3 -B sunmoonai/registry-platform/host_mode.py writable \
  --config sunmoonai/registry-platform/config/harbor-main-local.json \
  --docker-credentials /home/zymun/.docker/config.json
python3 -B sunmoonai/registry-platform/host_mode.py read-only \
  --config sunmoonai/registry-platform/config/harbor-main-local.json \
  --docker-credentials /home/zymun/.docker/config.json

# 按已核模式启动/停止，不隐式转换模式。
python3 -B sunmoonai/registry-platform/host_runtime.py start \
  --config sunmoonai/registry-platform/config/harbor-main-local.json
python3 -B sunmoonai/registry-platform/host_runtime.py stop \
  --config sunmoonai/registry-platform/config/harbor-main-local.json

# 统一备份：先容量准入，再停服/转只读/完整冷备份，最后恢复原模式及原运行状态。
python3 -B sunmoonai/registry-platform/host_mode.py backup \
  --config sunmoonai/registry-platform/config/harbor-main-local.json \
  --docker-credentials /home/zymun/.docker/config.json \
  --backup /var/backups/sunmoon-harbor/host-managed-next
```

`host_backup.py backup`底层只接受没有中断标记的只读实例，不能直接对可写实例调用。统一backup不盲目复用早期registry归档；创建目的地前先估计完整registry/runtime和22GiB余量，空间不足时不开始停服、不转换模式。

恢复时归档保留读写两套配置与扫描器数据。`restore-prepare`只改新实例的路径/部署名/网络，默认回到只读；`host_runtime create`创建两套停止的容器。完成数据库与完整目录恢复、扫描登记及推拉验收后，才能重新明确晋升可写。当前新增writer布局的完整备份/独立恢复仍须实际验收，不能沿用旧布局结果。

## 中断与保护

普通start遇到 `mode_transition_open` 拒绝；先核私有转换回执与容器身份，使用显式read-only转换恢复。若配置本身不完整，不跳过摘要门禁。prepare已写入writer描述但容器创建中断，可用 `host_mode.py create`：只对同一准备配置创建缺项，已有对象不重建。已有目录但尚未写入准备记录时保留现场，不自动覆盖。

这里不切30443、不停止旧KIND、不改全局Docker认证。当前旧仓仍为业务权威写端，候选的持久可写能力不代表正式切换准入已完成。还须最终停写同步、全目录核验、真实Docker/CI、入口窗口、正式集群与重建独立性。

规则：C-D1单一业务权威；C-D8固定数据库版本且不改schema；C-R1/R2保留部署/镜像/数据基线；C-I8中断或配置漂移拒绝启动；C-T5本地luna提交、不push。清理仍在最后，旧节点/卷和唯一备份全部保护。

## 100GiB数据盘下的备份位置

默认支持 `/data/harbor/backups/host-*`；本机另支持WSL系统盘 `/var/backups/sunmoon-harbor/host-*`（root私有目录）。本轮100GiB盘中保留了恢复副本/演练和旧备份，故新完整备份选择系统盘，不提前清理，也不扩大数据盘。

系统盘路径仅允许WSL环境：实时读取Windows C盘Free和 `C:\wsl-disks\sunmoon-data.vhdx` 文件长度，按 `C剩余 - 新备份内容 - 2GiB额外量 - 数据盘增长至100GiB的余量 >= 50GiB` 准入，同时核系统ext4的20GiB余量。读不到真实C容量即拒绝，不拿WSL虚拟上限代替真实容量。

本次预检：备份内容20845429722B，C剩余119238344704B，数据VHDX长度84628471808B；扣除新备份、额外量和数据盘预期长满后预计C余73499720742B（约68.45GiB），高于50GiB。数据盘目的地的负例在服务变化前拒绝，容器状态和运行状态文件SHA都未改变。

这是不同虚拟文件系统、同一块物理硬盘；不防物理盘故障，机器外备份仍待所有者定落点。容量是操作时快照，其他Windows/WSL进程后续消耗也须计入。旧备份/实例不搬移、不删除。完整新备份的独立恢复仍需另做，容量门槛继续生效。

首次上云还须核目标私网IP/DNS、CA/叶摘要、Docker/Compose钉版、独立存储UUID与可用量，再在独立候选完成读写/任务/备份恢复。这里仅实现共用代码，未执行SSH或远端动作；总控前置安装/完整离线工具闭包仍待接通。

## 本轮实测结果（2026-09-27）

read-only→writable、普通start按持久模式启动writer及scan-jobs、统一stop、writable→read-only均通过。原只读容器没有并行运行，统一create再次执行保留全部两套容器ID。最终共用本地客户端严格TLS/API只读核验通过；当前模式read-only，两套容器与全部候选均已停止，没有未闭合转换标记。

统一backup从“可写、已停止”开始，实际转只读并完成新冷备份后恢复“可写、已停止”；随后收尾主动切回只读。尚未实测“备份前运行、备份后恢复运行”分支，不扩大声明。

新备份 `/var/backups/sunmoon-harbor/host-managed-20260927-v1`：5项目（含两次专用验收）、66仓库、431含子清单制品、166tags；4416个registry文件；49表11216行。registry.tar 17868113920B，SHA256 `051b720a7def2b6aa41c2969e175011d5c4eed7302586688c7a3112070cbabc1`；runtime.tar 2996203520B，SHA256 `5ce7edca297ec028d3da31ccfe81393f52fccf6b7bd1d728cc82dbe4ebd26454`。完整归档和逐文件内容校验通过，包含scanner和writer配置；**restore_verified=false**，本轮尚未运行新增布局的独立恢复。

最终C实际剩98056019968B，预留数据盘增长至100GiB后剩75310309376B（约70.14GiB）；数据盘剩24355438592B。卷46个，运行容器仍只有旧/136的六个节点。旧入口、旧数据、原备份、所有试验副本均保留，无清理、无云端操作。六个Python文件AST、默认计划、git diff --check通过；没有运行应用测试套件。

完整脱敏回执：[受管模式与新备份结果](../../scripts/results/luna-harbor-managed-mode.20260927.json)。下一步仍需新备份独立恢复/容量安排、Docker与真实CI、正式入口窗口和main集群/重建独立性；不能据此通知整体迁移完成。
