# 2026-09-28 系统盘单独压缩维护提案

## 最新决定：数据盘扩至230 GiB，尚未执行

所有者最终改为**230 GiB**，替代240/260。以Windows Cursor 2026-09-28T14:41:36Z实际分配读数计算：C空闲253.01GiB、数据VHDX已分配86.66GiB；230长满后C约109.67GiB，另预留22后87.67GiB，仍保留50GiB底线。当前物理盘未变，仍为100GiB；后续执行使用[数据盘扩容操作卡](data-disk-expand.md)。下列260内容是历史预算，不能作为执行参数。

所有者在压缩完成后提出扩容，随后明确将240改为**260 GiB**；此值替代原100 GiB上限，240 GiB不实施。下文停机准备内容是历史记录。

压缩后只读复核：系统VHDX长度395217731584B（约368.08GiB），C空闲271587725312B（约252.94GiB），数据VHDX长度93050634240B（约86.66GiB）。按文件长度估算，数据盘长满260GiB后C约剩79.6GiB；文件长度不等于物理分配，实施前必须核Windows实际分配、备份/临时空间和系统盘增长预算，仍须保留至少50GiB。

原Harbor目录4400文件/17850816895B已全量SHA核对一致，原镜像/容器/卷身份一致。WSL重启使设备号变化，核对原系统盘UUID和目录inode后完成比对，原快照未改写。六节点仍停止，restore命令被打断前未执行，维护标记保留；服务尚未恢复，外置Harbor持久化验收尚未通过。

实施顺序：核验数据盘现有内容的备份覆盖及摘要；准备并发布容量相关脚本、自动挂载与监控配置及操作卡；停止使用者并解除数据盘绑定和主挂载，Windows分离VHDX后扩容；重新附加后按固定UUID唯一识别原设备，核260GiB块设备容量，在未挂载状态检查并扩展ext4；恢复挂载、服务可见性和全量镜像摘要核对，再恢复六节点/Harbor并实际拉取。失败保留维护状态，不格式化或缩容，不删除旧节点/卷，不在/data/kind-local-storage挂盘。

必须同步调整：sunmoon-data-storage.py的mount/setup容量100GiB限制；initialize-sunmoon-data.ps1的创建参数与预算；operations/space/policy.json的data_maximum_gib；已发布Linux/Windows副本摘要及引用、计划任务引用和监控副本。新版本单独发布，不覆盖固定摘要旧副本，不对现有盘运行初始化。扩容操作卡准备和复核完成前，不向Windows助手发出执行放行。

依据：[Microsoft expand vdisk](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/expand-vdisk)要求扩展时虚拟盘已分离；[resize2fs](https://man7.org/linux/man-pages/man8/resize2fs.8.html)负责扩展ext4文件系统，扩大VHDX本身不能代替这一步。

状态：**2026-09-28 21:46北京时间Linux停机准备完成，可交Windows Cursor关闭WSL并压缩。** 六节点均已退出，Docker/socket/containerd/监控均inactive，全部89容器保留且停止，219镜像和46卷身份未变。停服后4400个Harbor文件与保留备份全摘要一致。系统盘trim成功；尚未执行Windows压缩或入口切换。详见[公开准备结果](../../scripts/results/luna-system-compaction-preparation.20260928.json)。
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

本次遇到验证集群的 `sleep 3600` 探针不处理停止信号，标准CRI停止宽限期结束后退出137。已逐项确认是 `sunmoon-infra-check` 的验证探针；`pvc-reader` 仅休眠，PVC和节点卷均保留。另有旧RAGFlow entrypoint在120秒宽限期结束后退出137，逐挂载确认只有只读配置/令牌及kubelet的hosts/termination-log，没有可写数据卷；外部数据库随后单独停止。这些退出如实记录，不写成全部优雅退出，RAGFlow信号转发问题保留为后续整改项。

旧local-path-provisioner也在宽限期后退出137；其挂载仅只读ConfigMap/令牌及hosts/termination-log，不包含任何业务PV数据目录，卷及数据由节点保留。维护工具可显式 `resume-prepare --apply` 接续；仅这些逐项复核过的范围可接受退出137，其他工作负载仍拒绝继续，不把应用/控制器超时当作数据库正常关闭的证据。

六个节点本次均退出130；已逐节点核实本次停止后的systemd文件系统卸载/Shutdown完成标记，Docker stop使用无限宽限期，没有其超时SIGKILL回退。不同systemd版本关机文本有差异，不能只按退出码0或某一版文本判断；每节点日志摘要已登记。系统trim报告658.5GiB，是提交discard的范围，不是Windows已回收的空间。

本次最新Harbor快照在 `/data/harbor/source-snapshots/precompact-20260928-v1`，包含PG逻辑导出/身份/清单；4400个镜像文件与保留完整镜像层备份逐项相同。该新逻辑快照未单独演练恢复，原完整备份已有恢复演练。另保存 `~/private` 的约9MiB同机副本 `/data/harbor/backups/precompact-private-20260928-v1.tar`，不是机器外备份。

Windows压缩后先启动Ubuntu，使用原v2 attach脚本恢复数据盘并核UUID/服务视图；不要运行磁盘初始化脚本或启动候选容器。随后交回Luna执行：

```bash
cd /home/zymun/worktrees/luna/k8s
sudo python3 -B sunmoonai/kind-infrastructure/mount/system_compaction.py restore --apply
```

restore先核实际挂载和原容器/卷/镜像，再仅启动维护前运行的六节点；原集群UID、Ready、Harbor全目录API清单核对后恢复Harbor原只读设置和节点原重启策略、监控。整个操作不切换入口。验证集群Ready和实际认证镜像拉取、前后磁盘比较由恢复后的验收补齐，不能用脚本退出0替代。

## Windows Cursor 接手约定

Windows侧已确认只有Ubuntu/WSL2，DiskPart存在，系统VHDX约527.13GiB，数据VHDX约86.66GiB，C空闲约83.79GiB；原会话不是管理员。`sunmoon-data-mount` 原状态Enabled/Ready，上次结果0；这些是停机前快照，执行前仍需复核。

收到Luna明确放行后，先提权并将本操作卡、空间方案4.3及挂载恢复命令保存到 **Windows本地目录**，让Windows Cursor在C盘目录工作；压缩期间不要读取WSL的UNC路径，也不要保留会自动重启Ubuntu的远程IDE连接。

恢复既有数据盘用固定v2脚本，不创建新盘。管理员PowerShell：

```powershell
$ErrorActionPreference = 'Stop'
$Attach = 'C:\wsl-disks\scripts\storage-20260927-v2\attach-vhds.ps1'
if ((Get-FileHash -LiteralPath $Attach -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'dc65e5f02495fac2054fd1ce3464229ce476447468571c7e243e00d33a2ab4e0') { throw '附盘脚本摘要不符' }
$DataUuid = (Get-Content -LiteralPath 'C:\wsl-disks\sunmoon-data.uuid' -Raw).Trim()
if ($DataUuid -ne 'a28de356-4ba1-4a21-93f5-744b9b9d8be0') { throw '数据盘UUID不符' }
$CheckScript = '/opt/sunmoon/admin/storage/storage-20260927-v2/check-storage-mounts.sh'
# Docker通常随Ubuntu启动；六个节点已暂设restart=no，不能自动抢先启动。
wsl.exe -d Ubuntu -u root -- systemctl start docker.service
if ($LASTEXITCODE -ne 0) { throw 'Docker启动失败，停止并交回Luna' }
& $Attach -Mode SunmoonData -Distro Ubuntu -ExpectedUuid $DataUuid -CheckScript $CheckScript -Apply
if (-not $?) { throw '数据盘恢复失败，保留维护标记并交回Luna' }
```

挂载检查通过后回报压缩前后字节数、C空闲量、UUID/挂载结果，交Luna恢复六节点和核验服务。正式应用、旧Harbor以及inbox在Luna恢复前不可用；外置Harbor候选和SNI代理继续停止。解除Windows维护标记和恢复挂载任务放在Luna确认恢复通过之后。
