# 所有者操作：创建并挂载 100 GiB 数据盘

状态：代码准备完成；**未创建磁盘，未格式化、挂载或注册任务**。2026-09-27 只读查询 C 盘剩余 232.54 GiB，目标 VHDX 不存在。按 100 GiB 长满、另留 22 GiB 预算后，静态余量 110.54 GiB；运行前脚本会再次检查至少 172 GiB 当前可用。

本文件对应已确定的[主方案](storage-and-harbor-placement-decision.md)。整块虚拟盘为 ext4，同一物理 C 盘不能防硬件故障。旧 `/data/kind-local-storage` 不被挂载、卸载或改写。

## 1. 先发布固定脚本副本

由所有者本人打开 **Windows 管理员 PowerShell**。下列代码将本次可审阅脚本发布到固定版本目录，逐文件 SHA256 校验；不改变 PowerShell 执行策略。现有 CurrentUser=RemoteSigned 拒绝直接运行 UNC 上的未签名脚本，因此先复制到本机管理目录。若本地副本仍被策略拒绝，停止，由所有者处理签名策略，不加 Bypass/Unrestricted。

```powershell
$ErrorActionPreference = 'Stop'
$Source = '\\wsl.localhost\Ubuntu\home\zymun\worktrees\luna\k8s\sunmoonai\kind-infrastructure\deploy-kind'
$Published = 'C:\wsl-disks\scripts\storage-20260927-v1'
$LinuxPublished = '/opt/sunmoon/admin/storage/storage-20260927-v1'
$WindowsInWsl = '/mnt/c/wsl-disks/scripts/storage-20260927-v1'
$Expected = @{
    'attach-vhds.ps1' = '17683b9d4b7eb622145590edb00510b42367c179243ddabbb4e7e57d259b8896'
    'initialize-sunmoon-data.ps1' = '57346d0366203818aaf8b7c9b2bc1c27981e753d1fe2db0784780a93ea068b9b'
    'check-storage-mounts.sh' = 'be63dddb1ce85d7de949d35b2a439c25aae8b27d6c3f7e5cc8ef748105515407'
    'sunmoon-data-storage.py' = '77cc817ef1fe96630a17bc92345d8ee4535ba58ce04c4b89c4bf2476a53b5bd5'
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
wsl.exe -d Ubuntu -u root -- bash $CheckScript --layout sunmoon-data --expected-uuid $DataUuid
if ($LASTEXITCODE -ne 0) { throw '新存储检查未通过，禁止启动新 Harbor/新 KIND' }
```

成功输出包含 UUID、`/mnt/sunmoon-data` 与两条 bind。请将这些非秘密结果回传助手；这一步不会启动 Harbor、创建 KIND 或改变旧服务。

## 3. 后续附盘与开机/登录任务

先确认原 `docker-pv` 等历史任务不会执行旧 E 盘/卸载逻辑；可只读检查其 Actions。不自动禁用或删除未知任务，存在冲突时先交所有者处理。以下只注册新任务，Windows 用户为当前所有者，不能用 SYSTEM 替代 Ubuntu 所属用户。

```powershell
$Attach = Join-Path $Published 'attach-vhds.ps1'
& $Attach -Mode SunmoonData -Distro Ubuntu -ExpectedUuid $DataUuid -CheckScript $CheckScript -Apply
$TaskName = 'sunmoon-data-mount'
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { throw '任务已存在：先核对，不覆盖' }
$TaskArgs = '-NoProfile -NonInteractive -File "{0}" -Mode SunmoonData -Distro Ubuntu -ExpectedUuid "{1}" -CheckScript "{2}" -Apply' -f $Attach,$DataUuid,$CheckScript
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $TaskArgs
$Owner = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$Triggers = @((New-ScheduledTaskTrigger -AtStartup),(New-ScheduledTaskTrigger -AtLogOn -User $Owner))
$Principal = New-ScheduledTaskPrincipal -UserId $Owner -LogonType Interactive -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 3)
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Triggers -Principal $Principal -Settings $Settings
Start-ScheduledTask -TaskName $TaskName
# 等任务结束，再核对 LastTaskResult=0 和 Linux 检查；不能只看注册成功。
Get-ScheduledTaskInfo -TaskName $TaskName | Select-Object LastRunTime,LastTaskResult
wsl.exe -d Ubuntu -u root -- bash $CheckScript --layout sunmoon-data --expected-uuid $DataUuid
if ($LASTEXITCODE -ne 0) { throw '任务后检查失败' }
```

Interactive 任务在未登录时不保证运行，登录触发兜底；要登录前运行须所有者另行配置账户凭据。新服务必须先经过新布局检查，并由受挂载依赖约束的启动服务管理；该服务集成将在 Harbor/正式 KIND 单元实现，目前不能直接给新容器开启自动重启。Windows/WSL 重启验收留在入口切换与压缩维护窗口，不现在关闭 WSL。

## 4. 中断后处理

- 创建前报空间/脚本不符：没有新盘写入，修正明确问题后重试。
- VHDX 已创建但未格式化：保留文件，检查附盘状态、唯一新设备和签名；**不要重复运行创建脚本，也不要删除文件重来**。由助手读现场后给出准确续接步骤。
- 已生成 `sunmoon-data.uuid`、setup 中途失败：按该 UUID 复核现场；`sunmoon-data-storage.py setup --expected-uuid <UUID> --apply` 支持已有正确 fstab/挂载的续接，冲突时停止。
- fstab 修改前的副本在 `/etc/fstab.before-sunmoon-data.<UTC时间>`；不能整份回滚覆盖其他人的后续修改。mount 模式不修改 fstab。
- 错误挂载、非空未挂载目录、重复 UUID 或只读盘：保留现场，不自动卸载、清目录、格式化或启动服务。

## 5. 已核验与未核验

[只读证据](../../scripts/results/luna-data-storage-preparation.20260927.json)：三个 PowerShell 文件 Parser 语法通过；两个 shell 文件 bash -n 与 ShellCheck 0.9.0 通过；Python AST 通过；Linux 默认 setup 只打印、缺盘明确失败、旧 native 只读检查通过。

未执行 Windows 创建/附盘/格式化/任务注册，没有真实新盘成功挂载或重启验收。UNC 默认执行被现有 RemoteSigned 策略拒绝，未修改/绕过策略；Windows 本地发布副本的实际执行仍由所有者验证。ShellCheck 仅从 Ubuntu 软件源下载到临时目录解包使用，没有系统安装。
