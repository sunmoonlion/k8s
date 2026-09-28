# 本机存储、自动挂载与清理入口

更新：2026-09-28。这里是功能索引，实际代码继续共用 `../deploy-kind/`，不维护第二套实现。所有者提到的“永久功能”，本次按重启后自动挂载、集群数据持久化两部分核对。

## 当前磁盘在哪里

电脑已重新格式化，原来的 C/D/E 分区和旧 `docker-pv` 计划任务属于历史环境。目前只有 C 盘。

| 对象 | Linux 路径 | Windows 上的落点 | 当前作用 |
| --- | --- | --- | --- |
| 原 Harbor、原 KIND 静态数据 | `/data/kind-local-storage` | Ubuntu 系统 VHDX，位于 C 盘 | 原集群仍对外服务；禁止在此覆盖挂载或清空 |
| 新独立数据盘 | `/mnt/sunmoon-data` | `C:\wsl-disks\sunmoon-data.vhdx`，动态上限 100 GiB | ext4，UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0` |
| 新宿主 Harbor | `/data/harbor` | 新盘的 `harbor/` 子目录 | 已恢复候选，尚未切换公开入口 |
| 正式 KIND 节点数据 | `/data/kind-clusters` | 新盘的 `kind-clusters/` 子目录 | 预留给 `sunmoon-kind-main`，尚未建群 |

两份 VHDX 都占用 C 盘，分开管理不等于两块物理硬盘，不防同盘硬件故障。旧 `kind-worker2` 的容器内部卷也必须保留。

## 功能都在哪里，还能不能用

| 功能 | 实现/说明 | 本次结论 |
| --- | --- | --- |
| 手动附加现有新盘、恢复三处挂载 | [attach-vhds.ps1](../deploy-kind/attach-vhds.ps1) | 可用；默认计划，`-Apply` 才执行。当前目录同名文件只是转发入口 |
| 检查 UUID、bind、PID1/Docker 可见性 | [check-storage-mounts.sh](../deploy-kind/check-storage-mounts.sh) | 可用；新盘必须显式选 `--layout sunmoon-data`，无参数的旧 native 检查不能代替 |
| 首次创建、格式化新盘 | [initialize-sunmoon-data.ps1](../deploy-kind/initialize-sunmoon-data.ps1) | 已完成；已有盘禁止重跑初始化 |
| 自动挂载、重启后检查 | [ensure-sunmoon-data.ps1](../deploy-kind/ensure-sunmoon-data.ps1)、[任务注册器](../deploy-kind/register-sunmoon-data-task.ps1) | 新任务 `sunmoon-data-mount` 已注册，首次和后续定时检查通过；完整重启验收留维护窗口 |
| 节点重建后保留数据 | [formal/README.md](../formal/README.md) | 正式配置三节点各两条独立宿主挂载；创建器/生命周期代码已准备，真实重建仍待验 |
| 回收构建缓存、重复物料、可恢复应用镜像 | [空间回收方案](../docs/wsl-space-reclamation-plan.md)、[批次回收脚本](../../cicd-platform/materials/space_reclaim_20260927.py) | 功能保留，按候选清单/摘要/引用关系逐项执行；剩余回收仍放迁移最后，不能直接重放旧批次 |
| 把释放空间返还给 C 盘 | [空间方案第 4 节](../docs/wsl-space-reclamation-plan.md#4-wsl-vhdx-压缩维护窗口) | `fstrim` 与关闭 WSL 后的 VHDX 压缩步骤；不是普通文件删除，也不是自动执行功能 |
| Harbor 数据备份、独立恢复 | [host-backup.md](../../registry-platform/docs/host-backup.md) | 已有完整备份与真实恢复证据；机器外备份落点仍待定 |
| Harbor 镜像保留策略、GC，构建后清缓存 | [空间方案第 5 节](../docs/wsl-space-reclamation-plan.md#5-长期措施同样待批准后实施) | 作为长期功能保留；当前没有启用自动删除策略 |
| 云节点定时清镜像/安装包 | [image-cleanup/README.md](../../infrastructure/utils/image-cleanup/README.md) | 历史代码仍在；实际两个总开关均 `false`。有全量 `nerdctl image prune -a` 和通配包删除，不能套用本机或当前回退环境 |
| KIND 重建时清空 PV | [kind-up.sh](../kind-up.sh) 的 `clean_pv_data_if_configured` | 历史代码仍在，`CLEAN_PV_DATA_ON_RECREATE=false`；这是删除业务数据，不是安全腾空间。正式流程不调用 |
| 交互式存储管理菜单 | [storage-manager-README.md](../../../utils/storage-manager-README.md) | 只有旧说明，本仓查不到其声称的 `storage-manager.sh`，不能当成可用工具 |

旧 [WSL VHDX 文档](../docs/wsl的vhdx挂载.md)里的“清理后重挂”，指卸载叠加挂载，并非删除缓存或压缩磁盘。它会碰旧 `/data/kind-local-storage`，本机不能照做。`utils/` 其他连接脚本的 cleanup 通常是关闭 SSH 隧道、清连接状态，不是磁盘回收。

## 自动挂载的实际规则

2026-09-28 管理员查询到 271 个原计划任务，未发现旧 `docker-pv` 或新 `sunmoon-data-mount`。新盘当时根本未附加，`fstab` 有记录也不能自行把 Windows 的 VHDX 接进来。所有者明确授权助手执行，已通过管理员 PowerShell 调用核对摘要后的既有 v2 脚本恢复挂载，随后注册新任务。

- 发布位置：`C:\wsl-disks\scripts\storage-automation-20260928-v1`，不依赖 worktree；新发布目录限制为 Administrators/SYSTEM 可写、当前用户可读执行。
- 任务以 Ubuntu 所属用户 `ZYMUN\zymun` 的最高权限 Interactive token 运行，不使用 SYSTEM，不保存密码。
- **仅登录时触发，已取消每分钟检查。** 2026-09-28 所有者报告弹窗并质疑轮询频率；根因是原任务每分钟直接启动可见的 PowerShell。现使用 `wscript.exe //B //Nologo` 启动受限目录下的 `run-sunmoon-data-hidden.vbs`，内部 PowerShell 使用 Hidden 模式，等结束并向任务返回退出码。
- 先检查维护标记，再查询 Ubuntu 是否正在运行；未运行则跳过。已挂载时只读检查，不重复挂载，不启动服务。未登录时不保证运行。**登录时 Ubuntu 未启动、登录后单独重启 WSL，都不能靠这一次触发覆盖；统一服务启动前按需附盘接线仍待完成。**
- 每次校验 runner、v2 attach、Linux helper 的固定 SHA256。UUID/挂载异常拒绝，绝不自动创建或格式化盘。
- 最近状态：`C:\wsl-disks\sunmoon-data-automation-status.json`；注册回执：`C:\wsl-disks\sunmoon-data-task-registration.json`。
- 无窗口入口发布于 `storage-automation-20260928-v2`，SHA256 `131877883b2ac97a9bd0220b444ef3433792a035ad36e289b5be59e5b66c3b8e`；只调用原 v1 runner，每次核原 SHA。任务修复器最终发布在 v4，v2/v3 修复器因 Windows 简写账号解析失败，在修改任务之前停止，保留原发布不覆盖。
- 修改后 11:46:07 实际运行 `LastTaskResult=0`、`already-mounted`，任务回读只剩一个登录触发器。修复回执 `C:\wsl-disks\sunmoon-data-task-hidden.json`，公开副本见 [结果](../../scripts/results/luna-storage-task-hidden.20260928.json)。没有为验收关闭 WSL；整机重启、未附盘修复、登录触发端到端均尚未实测。
- Ubuntu 运行检查和后续命令之间不是原子操作；维护时必须按下节暂停任务并等待已运行实例结束，避免与 WSL 关闭竞态。

日常可以只读查看 JSON 状态；准备启动新 Harbor/KIND 时仍必须通过服务挂载门禁，不能只看计划任务返回 0（维护跳过、Ubuntu 停止跳过也返回 0）。注册器拒绝覆盖已有任务；升级发布须新目录、新摘要和明确的任务更新步骤。

## 压缩维护：先暂停自动任务，完毕再恢复

以下仅用于已约定维护窗口，当前没有执行关闭 WSL或压缩。管理员 PowerShell：

```powershell
$ErrorActionPreference = 'Stop'
$Marker = 'C:\wsl-disks\sunmoon-data.maintenance'
New-Item -ItemType File -Path $Marker -Force | Out-Null
Disable-ScheduledTask -TaskName 'sunmoon-data-mount' | Out-Null
$Deadline = (Get-Date).AddMinutes(4)
while ((Get-ScheduledTask -TaskName 'sunmoon-data-mount').State -eq 'Running') {
    if ((Get-Date) -gt $Deadline) { throw '附盘任务仍运行；不要关闭 WSL，先调查' }
    Start-Sleep -Seconds 2
}
```

然后才按空间方案保存服务状态、备份、sync/trim、关闭 WSL与压缩。完成后，先启动 Ubuntu并通过固定 v2 脚本恢复挂载、核 UUID/服务可见性，再解除维护：

```powershell
# 必须先确认本次维护完成，且既有 v2 挂载检查通过。
Remove-Item -LiteralPath 'C:\wsl-disks\sunmoon-data.maintenance'
Enable-ScheduledTask -TaskName 'sunmoon-data-mount' | Out-Null
Start-ScheduledTask -TaskName 'sunmoon-data-mount'
```

这处 `Remove-Item` 只删除维护标记。任何失败都保留标记和任务暂停状态，不在 `finally` 中无条件恢复。撤销自动挂载只需先 Disable 这个新任务；不影响已挂载数据，不执行卸载或清理。

## 清理功能的保留边界

挂载、自动挂载、存储持久化、备份恢复、可审计的空间回收和维护压缩都保留。自动挂载绝不顺便清理；旧清理工具保留作历史参考，不因目录相邻就启用。

目前旧/验证 KIND 节点与全部 Docker 卷继续受保护；禁止 system/container/volume prune、清理停止容器/卷以及清空旧 PV。R3 节点镜像清理已取消；本次没有删除文件、镜像、容器或卷。对指定 cron 目录的只读检查未发现旧 image-cleanup/prune 条目；这不是所有系统任务的全面审计。`fstrim.timer` 当前 enabled/inactive，未运行 trim；trim 也不等于磁盘文件已经压缩。
