# luna 卡 fable-c0d：生产虚拟机随 Windows 开机自起 + WSL 转发开机自动（0039 C0 收尾）

> 状态：**可执行**（远程 Fable 2026-10-21 晚写，所有者定：无界面 Ubuntu 起得快，开机自启动装上）。两件事：① 用 VMware Workstation 17 自带的 **Auto Start**（宿主开机、不等登录就起 VM；由 `VMware Autostart Service` 管，关机时它收尾），不用计划任务起 `vmrun`；② 让 WSL→VMnet8 的 IPv4 转发开机自动开（WSL 的 vEthernet 每次 WSL 启动会重建，设置不一定留得住），用一个 SYSTEM 身份的计划任务轮询两张网卡、幂等开启。
>
> 临时就地修授权同前：`infrastructure/environments/prod/vm/` 下脚本与本卡命令里让步骤过不去的错可以就地改、验、续跑并推 `origin/fable`，回执里写「就地修了什么」；不改机制（不改成登录任务起 vmrun、不关防火墙、不改 VM 配置）、不碰 WSL/开发集群。需要管理员权限的两步走 UAC，所有者点同意（同 c0 转发那次）。

```text
工位 WS=fable：~/worktrees/fable/sunmoonun，分支 fable；收件箱 docs/process/switch-test/inbox/luna/
目标：Windows 宿主的 VMware 服务与计划任务；虚拟机本身不改
所有者要做的：第二节在 VMware 界面里勾一下；第四节重启一次 Windows
```

## 一、VMware Autostart 服务设为自动（luna，UAC）

```bash
cd ~/worktrees/fable/sunmoonun && git pull --ff-only origin fable && git log --oneline -1
powershell.exe -NoProfile -Command 'Get-Service | Where-Object { $_.DisplayName -like "*VMware*" } | Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize'
```

找到显示名含 `Autostart` 的那个服务（17.x 叫 `VMware Autostart Service`，Name 以实测为准），提权把它设为自动并启动：

```bash
powershell.exe -NoProfile -Command 'Start-Process powershell -Verb RunAs -Wait -ArgumentList "-NoProfile","-Command","Set-Service -Name <实测Name> -StartupType Automatic; Start-Service -Name <实测Name>; Get-Service -Name <实测Name> | Select-Object Name,Status,StartType | Format-List"'
powershell.exe -NoProfile -Command 'Get-Service -Name <实测Name> | Select-Object Name,Status,StartType | Format-List'
```

要看到 `Status: Running`、`StartType: Automatic`。

## 二、把 sunmoon-prod 加进自动启动列表（**所有者**，界面）

把这一行交给所有者：VMware Workstation → 菜单 **文件 → 配置自动启动虚拟机**（File → Configure Auto Start VMs）→ 勾选 `sunmoon-prod` → 确定。列表为空的话先确认第一节服务已 Running，再重开 VMware。所有者说「勾了」再往下。

## 三、转发开机自动（luna，UAC）

写两个脚本进仓库 `infrastructure/environments/prod/vm/`：

- `Enable-SunmoonForwarding.ps1`：最多等 20 分钟，直到 `VMware Network Adapter VMnet8` 和 `vEthernet (WSL*` 两张 IPv4 接口都在；对两者 `Set-NetIPInterface -Forwarding Enabled`（已开的不动）；把时间、接口名、前后状态追加到 `C:\ProgramData\Sunmoon\prod-vm\forwarding.log`（只写状态，没有秘密）。
- `Register-SunmoonForwardingTask.ps1`：把前者拷到 `C:\ProgramData\Sunmoon\prod-vm\`，注册计划任务 `Sunmoon-ProdVm-Forwarding`：触发器 **系统启动时**，之后 **每 10 分钟重复**（持续一天，幂等所以无害），身份 `SYSTEM`，最高权限，`-ExecutionPolicy Bypass -File <路径>`；已存在就替换。注册完立即 `Start-ScheduledTask` 跑一次。

```bash
powershell.exe -NoProfile -Command 'Start-Process powershell -Verb RunAs -Wait -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","\\wsl.localhost\Ubuntu\home\<你>\worktrees\fable\sunmoonun\infrastructure\environments\prod\vm\Register-SunmoonForwardingTask.ps1"'
powershell.exe -NoProfile -Command 'Get-ScheduledTask -TaskName Sunmoon-ProdVm-Forwarding | Select-Object TaskName,State; Get-ScheduledTaskInfo -TaskName Sunmoon-ProdVm-Forwarding | Select-Object LastRunTime,LastTaskResult; Get-NetIPInterface -AddressFamily IPv4 | Where-Object { $_.Forwarding -eq "Enabled" } | Select-Object InterfaceAlias'
```

要看到任务 `Ready`、`LastTaskResult: 0`，Forwarding Enabled 的列表里同时有 VMnet8 和 vEthernet (WSL…)。`\\wsl.localhost\Ubuntu\...` 路径以你的发行版名和家目录为准；UNC 路径提权执行不了就先把脚本拷到 `C:\ProgramData\Sunmoon\prod-vm\` 再从那里跑（写进回执）。

## 四、重启 Windows 验收（所有者重启，luna 验）

让所有者重启 Windows、登录后**不要打开 VMware**，也不开 WSL 以外的东西，然后你跑：

```bash
powershell.exe -NoProfile -Command '& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" -T ws list'
powershell.exe -NoProfile -Command 'Get-NetIPInterface -AddressFamily IPv4 | Where-Object { $_.Forwarding -eq "Enabled" } | Select-Object InterfaceAlias; Get-ScheduledTaskInfo -TaskName Sunmoon-ProdVm-Forwarding | Select-Object LastRunTime,LastTaskResult'
ssh -o BatchMode=yes -o ConnectTimeout=10 sunmoon@192.168.80.10 'uptime -s; journalctl --list-boots --no-pager | tail -3; journalctl -b -1 --no-pager -o short-iso | grep -i -E "reached target (power-off|shutdown)|shutting down|systemd-shutdown" | tail -2 || true; last -x shutdown reboot | head -4'
```

通过标准：`vmrun list` 列出 `sunmoon-prod.vmx`（你没开 VMware 它就在跑）；转发两张都 Enabled；SSH 通，`uptime -s` 的时间在 Windows 这次开机之后一两分钟内；**上一次关机是干净的**（`journalctl -b -1` 末尾有 power-off/shutdown 目标，或 `last -x` 显示 `shutdown`），说明 Autostart 服务在宿主关机时正常关了客户机。上一次关机**不干净**（没有 shutdown 记录、像断电）也先不改什么，把证据写进回执，远程来定补法。

## 五、回执

`scripts/results/fable-c0d.<YYYYMMDD-HHMM>.md`：服务状态、任务状态、重启后三条命令原文、就地修了什么；两个脚本随卡提交；卡移 `done/`；`git add` → commit → `git push origin fable`。不通过停，写 `inbox/fable/`。
