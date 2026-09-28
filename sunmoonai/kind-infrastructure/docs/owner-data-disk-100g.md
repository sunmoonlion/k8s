# 所有者操作：创建并挂载 100 GiB 数据盘

状态（2026-09-28）：100 GiB 数据盘已创建。此次 WSL 启动后盘未附加；所有者新增授权“我授权你自己执行”，助手已使用管理员 PowerShell 调用原 v2 固定脚本恢复挂载，通过 UUID、PID1/Docker 可见性及旧路径检查。新 `sunmoon-data-mount` 计划任务已注册，首次与后续定时检查成功。完整重启验收留维护窗口。UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`；当前可用约 36.48 GiB，旧路径设备/inode 未变。**不要再次创建/格式化。** 原 Harbor 仍在旧 KIND，新 Harbor 候选停止；本次挂载操作没有启动服务。

本文件对应已确定的[主方案](storage-and-harbor-placement-decision.md)。整块虚拟盘为 ext4，同一物理 C 盘不能防硬件故障。旧 `/data/kind-local-storage` 不被挂载、卸载或改写。

## 1. 先发布固定脚本副本

由所有者本人打开 **Windows 管理员 PowerShell**。下列代码将本次可审阅脚本发布到固定版本目录，逐文件 SHA256 校验；不改变 PowerShell 执行策略。现有 CurrentUser=RemoteSigned 拒绝直接运行 UNC 上的未签名脚本，因此先复制到本机管理目录。若本地副本仍被策略拒绝，停止，由所有者处理签名策略，不加 Bypass/Unrestricted。

```powershell
$ErrorActionPreference = 'Stop'
$Source = '\\wsl.localhost\Ubuntu\home\zymun\worktrees\luna\k8s\sunmoonai\kind-infrastructure\deploy-kind'
$Published = 'C:\wsl-disks\scripts\storage-20260927-v2'
$LinuxPublished = '/opt/sunmoon/admin/storage/storage-20260927-v2'
$WindowsInWsl = '/mnt/c/wsl-disks/scripts/storage-20260927-v2'
$Expected = @{
    'attach-vhds.ps1' = 'dc65e5f02495fac2054fd1ce3464229ce476447468571c7e243e00d33a2ab4e0'
    'initialize-sunmoon-data.ps1' = 'e78e8ee47f0a8a685bd8a5b8c21dd317309ed5043ab194c2c5d6528bd7b590c9'
    'check-storage-mounts.sh' = 'be63dddb1ce85d7de949d35b2a439c25aae8b27d6c3f7e5cc8ef748105515407'
    'sunmoon-data-storage.py' = 'e542c9cdbc68abe291d5ab47af466540e632627201d7ac0d1e9e04e30fab99c5'
}
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) { throw '请使用管理员 PowerShell' }
# 已存在发布目录时只复核相同字节，不覆盖旧版本。
foreach ($Name in $Expected.Keys) {
    $InputFile = Join-Path $Source $Name
    if ((Get-FileHash -LiteralPath $InputFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Expected[$Name]) { throw "源文件摘要不符：$Name" }
}
New-Item -ItemType Directory -Path $Published -Force | Out-Null
foreach ($Name in $Expected.Keys) {
    $OutputFile = Join-Path $Published $Name
    if (-not (Test-Path -LiteralPath $OutputFile)) { Copy-Item -LiteralPath (Join-Path $Source $Name) -Destination $OutputFile }
    if ((Get-FileHash -LiteralPath $OutputFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Expected[$Name]) { throw "管理副本摘要不符，停止：$Name" }
}
wsl.exe -d Ubuntu -u root -- install -d -m 0755 $LinuxPublished
if ($LASTEXITCODE -ne 0) { throw 'Linux 管理目录创建失败' }
foreach ($Name in @('check-storage-mounts.sh','sunmoon-data-storage.py')) {
    wsl.exe -d Ubuntu -u root -- test -e "$LinuxPublished/$Name"
    if ($LASTEXITCODE -eq 1) {
        wsl.exe -d Ubuntu -u root -- install -m 0755 "$WindowsInWsl/$Name" "$LinuxPublished/$Name"
        if ($LASTEXITCODE -ne 0) { throw 'Linux 管理副本复制失败' }
    } elseif ($LASTEXITCODE -ne 0) { throw 'Linux 管理副本状态无法判断' }
    $Actual = (wsl.exe -d Ubuntu -u root -- sha256sum "$LinuxPublished/$Name")
    if ($LASTEXITCODE -ne 0 -or $Actual.Split()[0] -ne $Expected[$Name]) { throw 'Linux 管理副本摘要不符' }
}
```

## 2. 创建、格式化、挂载（仅首次）

继续同一管理员窗口，先看计划，再执行。此处 **100 GiB 是动态扩展上限，不会立即占满 C 盘**。脚本只对新创建 VHDX 产生的唯一新增、大小正确、无分区/签名/挂载的块设备格式化；发现已有 VHDX 或 UUID 收据就停止。

```powershell
$Create = Join-Path $Published 'initialize-sunmoon-data.ps1'
& $Create -Distro Ubuntu -LinuxScriptDirectory $LinuxPublished
& $Create -Distro Ubuntu -LinuxScriptDirectory $LinuxPublished -Apply
$DataUuid = (Get-Content -LiteralPath 'C:\wsl-disks\sunmoon-data.uuid' -Raw).Trim()
$CheckScript = "$LinuxPublished/check-storage-mounts.sh"
wsl.exe -d Ubuntu -u root -- nsenter --target 1 --mount -- bash $CheckScript --layout sunmoon-data --expected-uuid $DataUuid --require-service-visibility
if ($LASTEXITCODE -ne 0) { throw '新存储检查未通过，禁止启动新 Harbor/新 KIND' }
```

成功输出包含 UUID、`/mnt/sunmoon-data` 与两条 bind。请将这些非秘密结果回传助手；这一步不会启动 Harbor、创建 KIND 或改变旧服务。

## 2a. 本次续接：只修复挂载空间，不创建/格式化

v1 的 Linux `mount` 运行在调用者空间，Windows 管理员和普通 WSL 会话可能隔离挂载。此次只读核实：三个挂载仍在 `mnt:[4026537444]`，而 PID 1 与 Docker 在 `mnt:[4026532219]`，两者没有这三个挂载。fstab/UUID 正确，旧路径身份未变。相关上游报告见 [Microsoft WSL #9690](https://github.com/microsoft/WSL/issues/9690)；本机结论以 `/proc/*/mountinfo` 实测为准。

v2 使用 `nsenter --target 1 --mount --`，只进入挂载空间，不修改传播属性，不停止服务。Linux helper 拒绝在非 PID 1 空间写挂载；检查还比对 PID 1 和运行中 Docker 的三个精确挂载及设备/inode。v1 发布目录原样保留。此修复属于已批准挂载单元，由所有者本人执行。

**本机本节已执行并复核通过，以下保留为故障续接记录，当前不用重复执行。** 首次遇到同样问题时，完成第 1 节 v2 发布，再在同一管理员窗口执行以下代码；不执行第 2 节。

```powershell
$DataUuid = (Get-Content -LiteralPath 'C:\wsl-disks\sunmoon-data.uuid' -Raw).Trim()
if ($DataUuid -ne 'a28de356-4ba1-4a21-93f5-744b9b9d8be0') { throw '与本次新盘 UUID 不符，停止' }
$CheckScript = "$LinuxPublished/check-storage-mounts.sh"
$Attach = Join-Path $Published 'attach-vhds.ps1'
& $Attach -Mode SunmoonData -Distro Ubuntu -ExpectedUuid $DataUuid -CheckScript $CheckScript
& $Attach -Mode SunmoonData -Distro Ubuntu -ExpectedUuid $DataUuid -CheckScript $CheckScript -Apply
if (-not $?) { throw '挂载修复失败，停止；不要重建磁盘' }
wsl.exe -d Ubuntu -u root -- nsenter --target 1 --mount -- bash $CheckScript --layout sunmoon-data --expected-uuid $DataUuid --require-service-visibility
if ($LASTEXITCODE -ne 0) { throw '服务挂载检查失败，禁止启动 Harbor/KIND' }
```

完成后助手从普通会话再次核对 UUID、三个挂载及旧路径。`service_visibility` 必须列出 systemd 和当前运行的 docker；Docker 未运行时不得声称其可见性已验证，后续启动后必须补查。不对已有管理员会话的正确挂载执行卸载。失败保留现场，不自动回滚 fstab、卸载或格式化。

## 3. 自动附盘任务（已注册）

本机任务为 `sunmoon-data-mount`；完整规则、维护暂停/恢复命令及功能索引见 [mount/README.md](../mount/README.md)。历史 `docker-pv` 属于格式化前 E 盘环境，不能恢复其旧路径。

执行器固定在 `C:\wsl-disks\scripts\storage-automation-20260928-v1`，无窗口启动器位于 v2；本次任务修复器与更新后的注册器最终发布于 v4：

- [ensure-sunmoon-data.ps1](../deploy-kind/ensure-sunmoon-data.ps1)：维护标记优先；Ubuntu 未运行则跳过，正常挂载只检查；缺盘时调用已发布 v2 attach，核原 UUID，不初始化、不启动 Harbor/KIND。
- [register-sunmoon-data-task.ps1](../deploy-kind/register-sunmoon-data-task.ps1)：默认只打印，`-Apply` 才注册；固定 runner 与 launcher SHA；已有同名任务拒绝覆盖。任务用当前 Ubuntu 所属 Windows 用户的最高 Interactive 权限，**仅登录触发，无分钟轮询**。
- [run-sunmoon-data-hidden.vbs](../deploy-kind/run-sunmoon-data-hidden.vbs)：非控制台入口，隐藏 PowerShell，等待并传回退出码；调用原 v1 runner，不改变附盘逻辑。
- [hide-sunmoon-data-task.ps1](../deploy-kind/hide-sunmoon-data-task.ps1)：只修复已核身份/动作的原任务，先备份 XML，等现有运行完成后移除定时触发并换无窗口入口；不强停附盘进程、不改服务。

每次任务运行重新核对脚本摘要。当前 runner SHA256：`70ca2d6693881940231bdd39acaad9b2853f96d0c7ddbf5e9d523747e0a4c2bd`。发布目录只允许 Administrators/SYSTEM 修改，当前用户读执行；不依赖 worktree。未来更换代码必须使用新版本发布目录、重新核对 SHA 和任务动作，不覆盖当前发布字节。

复用方法：管理员按脚本中固定路径发布 runner 和 launcher（已存在时仅比对摘要，拒绝覆盖），设置上述 ACL，再调用当前注册器 `-RunnerSha256 <已核对的runner摘要> -LauncherSha256 <已核对的launcher摘要> -Apply`。注册器保存回执并等首次运行结果。**本机已经完成修复，不重跑注册。** 唯一状态文件 `C:\wsl-disks\sunmoon-data-automation-status.json`；查看计划任务 `LastTaskResult` 并核状态为 `already-mounted`/`mounted-and-checked`，不能把 maintenance/Ubuntu-stopped 的跳过结果当挂载成功。

登录后单独重启 WSL 不会再次触发登录任务；如果登录时 Ubuntu 未运行，任务也会跳过。统一 Harbor/KIND CLI 启动入口已接按需附盘和严格挂载检查，完整重启/缺盘恢复分支仍待实测；不能因此取消现有启动门禁，也不恢复分钟轮询。取消轮询与无窗口执行的实际结果见 [存储索引](../mount/README.md#自动挂载的实际规则)。

完整关机/WSL 重启与 Harbor/正式 KIND 自动启动仍待后续验收。新服务继续经过严格挂载检查；任务成功不等于服务已启动。执行压缩之前必须使用索引中的维护标记、Disable 任务并等待已运行实例结束，再关闭 WSL。

## 4. 中断后处理

- 创建前报空间/脚本不符：没有新盘写入，修正明确问题后重试。
- VHDX 已创建但未格式化：保留文件，检查附盘状态、唯一新设备和签名；**不要重复运行创建脚本，也不要删除文件重来**。由助手读现场后给出准确续接步骤。
- 已生成 `sunmoon-data.uuid`、setup 中途失败：按该 UUID 复核现场；`nsenter --target 1 --mount -- python3 <管理目录>/sunmoon-data-storage.py setup --expected-uuid <UUID> --apply` 支持已有正确 fstab/挂载的续接，冲突时停止。
- fstab 修改前的副本在 `/etc/fstab.before-sunmoon-data.<UTC时间>`；不能整份回滚覆盖其他人的后续修改。mount 模式不修改 fstab。
- 错误挂载、非空未挂载目录、重复 UUID 或只读盘：保留现场，不自动卸载、清目录、格式化或启动服务。

## 5. 已核验与未核验

[只读证据](../../scripts/results/luna-data-storage-preparation.20260927.json)：三个 PowerShell 文件 Parser 语法通过；两个 shell 文件 bash -n 与 ShellCheck 0.9.0 通过；Python AST 通过；Linux 默认 setup 只打印、缺盘明确失败、旧 native 只读检查通过。

所有者已执行 Windows 创建/附盘/格式化，v1 管理员会话检查通过；原服务空间检查未通过；现已由所有者执行 v2，助手普通 WSL 会话复核通过。2026-09-28 已注册并核实新计划任务；未做整机/WSL 重启验收。UNC 默认执行被 RemoteSigned 拒绝，未修改/绕过策略；所有者使用 Windows 本地发布副本已实际运行。ShellCheck 仅在临时目录解包，没有系统安装。v2 静态与只读证据见 `../../scripts/results/luna-data-storage-v2-preparation.20260927.json`。

最终挂载复核：[v2 实测结果](../../scripts/results/luna-data-storage-v2-mounted.20260927.json)。包含正确 UUID/ext4/rw、两条 bind 的设备/inode、旧路径身份和 systemd/Docker 可见性。历史失败记录保留在 `luna-data-storage-mounted.20260927.json`，不覆盖为成功。
