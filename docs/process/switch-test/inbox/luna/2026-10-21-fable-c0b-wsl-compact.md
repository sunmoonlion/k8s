# luna 卡 fable-c0b：WSL 离线压缩重做（所有者定：先压缩，再建机）

> 状态：**现在做，排在 c0a 之后、c0 建机之前**（远程 Fable 2026-10-21 写；所有者「先压缩」）。上次（c0 维护回执）DiskPart 没跑到：`wsl --shutdown` 之后 VS Code 的 WSL 服务自己把 WSL 又拉起来了。先按下面三点改材料（`C:\wsl-disks\maintenance\`），改好把启动器路径和「要关什么」交给所有者，所有者关掉全部 VS Code 与 WSL 终端后从开始菜单开的管理员 PowerShell 里跑；恢复后你回 WSL 核对、写回执。
>
> 范围不变：只对 WSL 系统盘 vhdx 和 `sunmoon-data.vhdx` 做 DiskPart compact；不清理里面任何数据（C-R19）。

## 这次要改的三点

1. **离线前先掐断会自动重连 WSL 的东西**：所有者关掉全部 VS Code 窗口（含远程 WSL 的）、Windows Terminal 里的 WSL 标签；Windows 侧脚本在 `wsl --shutdown` 前检查没有 `Code.exe`/`wsl.exe` 进程，有就停下报出来，不硬关；`wsl --shutdown` 后再等 10 秒复查 `wsl -l --running` 为空才进 DiskPart。
2. **脚本从独立的 Windows PowerShell 跑**（不是从 WSL 里 `powershell.exe` 调出去的那种，那样 WSL 一停它自己就没了）。所有者双击或管理员 PowerShell 里直接运行。
3. **最初的异常单独落日志**：worker 的离线段任何异常先写 `offline-error.log` 再进恢复分支；恢复分支自己的失败另写一份，不覆盖。

## 跑的时候

同上次：原生 `platform-stop` → fstrim → `wsl --shutdown` → compact 两块 → 附盘 → `platform-start` → `platform-status` → 回执写压缩前后 C 空闲、两块 vhdx 文件长度。开机守卫要全部 Flux Ready，c0a 清掉孤儿之后才能过，所以本卡排在 c0a 之后。

## 回执与推回

`scripts/results/fable-c0b.<时间>.md`，命令同前；推回同前（卡移 `done/`）。
