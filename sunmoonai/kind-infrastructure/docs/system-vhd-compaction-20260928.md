# 2026-09-28 系统盘单独压缩维护提案

状态：所有者已安排Windows Cursor接手压缩，等待Luna的停机准备完成通知；Linux侧正在准备，尚未授权Cursor关闭WSL。
原决定是压缩与入口切换合并。当前入口切换尚未就绪，本提案将压缩提前为一次独立维护，恢复时仍使用原集群与原入口。

## 依据与范围

- 本次未使用构建缓存已清1845条，WSL文件系统用量减少179.15GiB；镜像219、容器89、卷46身份及容器状态前后一致。
- 清理后系统VHDX长度565997207552B（约527.13GiB），文件系统已用约324.84GiB；C可用约84.23GiB、使用率90.89%。这些差额不是保证可回收量。
- 仅压缩 `C:\Users\zymun\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\ext4.vhdx`。
- 保留100GiB数据盘、全部容器/卷/镜像及旧节点；不重建集群、不切30443、不启用自动收缩。关闭WSL会停止全部发行版，助手会话也会断开。

## 实施顺序

1. 助手先保存工作并提交本地luna，保存全部容器完整ID、运行状态、restart policy、卷/挂载、旧集群UID、Harbor状态及容量；复核现有Harbor完整备份。将恢复清单保存到持久化位置，不能只留在会话中。
2. 核实没有构建/推送/恢复任务正在写入；暂停相关写入任务。对当前旧Harbor及其他仍有写入的服务正常停写/停服，再按精确ID停止原本运行的节点与服务。停止失败则终止维护，禁止强删容器、卷或节点。
3. 创建维护标记并暂停Windows的 `sunmoon-data-mount` 任务，等待正在执行的任务结束；退出可能重新启动WSL的IDE/终端后台任务。执行sync及系统盘fstrim，记录实际结果；不进行写零填满磁盘。
4. 所有者在管理员PowerShell关闭WSL，确认无运行发行版、目标VHDX已脱离，再使用DiskPart compact。完整命令沿用[空间方案4.3](wsl-space-reclamation-plan.md#43-所有者执行的关闭压缩与大小记录)，自动任务暂停命令见[挂载维护](../mount/README.md#压缩维护先暂停自动任务完毕再恢复)。若任何检查失败，不强制分离正在使用的磁盘。
5. 记录压缩前后VHDX Length与C空闲量，检查DiskPart文本及退出码。预计预留30–60分钟，实际取决于磁盘；压缩运行中不强行中断。
6. 启动Ubuntu，先恢复并检查既有数据盘UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`、两处bind和PID1/Docker服务视图，核旧数据路径未改变。按第1步原状态恢复服务，原本停止的候选Harbor/SNI继续停止。复核旧集群UID、节点/卷身份、旧Harbor健康与实际镜像拉取；失败保留维护记录，停止新增写入并调查。
7. 核对通过后解除维护标记，恢复挂载任务及容量监控，重新测容量。继续原迁移任务。

这次只能记为“当前环境停机压缩与恢复”；外置Harbor尚未成为正式源，不能计为外置Harbor的WSL重启持久化验收通过。

动态VHD须脱离或只读附加才能压缩：[Microsoft compact vdisk](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/compact-vdisk)。实际Windows回收量以维护前后测量为准。

## 本次Linux准备与恢复入口

`mount/system_compaction.py` 是本次固定六个既有节点的维护工具，默认只打印；不是正式main的生命周期入口。
`prepare --apply` 保存全部容器身份/挂载/重启策略、保护镜像/卷及原入口；将Harbor只读、六节点restart暂设no，停止kubelet后按应用先于数据库、控制面最后的顺序停止CRI容器，再正常关闭节点，停止Docker及容量监控，最后sync/系统盘trim。不删除任何容器、卷或镜像，不修改工作负载副本数。

私有恢复日志固定为 `/var/lib/sunmoon/maintenance/precompact-20260928-v1/state.json`。失败会留在 `interrupted-needs-review`；只有 `ready_for_windows_shutdown=true` 且Luna明确通知才允许Windows关闭。

本次最新Harbor快照在 `/data/harbor/source-snapshots/precompact-20260928-v1`，包含PG逻辑导出/身份/清单；4400个镜像文件与保留完整镜像层备份逐项相同。该新逻辑快照未单独演练恢复，原完整备份已有恢复演练。另保存 `~/private` 的约9MiB同机副本 `/data/harbor/backups/precompact-private-20260928-v1.tar`，不是机器外备份。

Windows压缩后先启动Ubuntu，使用原v2 attach脚本恢复数据盘并核UUID/服务视图；不要运行磁盘初始化脚本或启动候选容器。随后交回Luna执行：

```bash
cd /home/zymun/worktrees/luna/k8s
sudo python3 -B sunmoonai/kind-infrastructure/mount/system_compaction.py restore --apply
```

restore先核实际挂载和原容器/卷/镜像，再仅启动维护前运行的六节点；原集群UID、Ready、Harbor全目录API清单核对后恢复Harbor原只读设置和节点原重启策略、监控。整个操作不切换入口。验证集群Ready和实际认证镜像拉取、前后磁盘比较由恢复后的验收补齐，不能用脚本退出0替代。
