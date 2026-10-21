# fable-c0b 启动器准备回执（luna）

WS=fable；C0a 已实跑通过并推送两站，提交 `cb6df3ebf`。本次按所有者指示仅准备可独立运行的 C0b，**没有启动维护、停服务、fstrim、关闭 WSL 或调用 DiskPart**。C0b 卡保留 inbox/luna，待所有者运行、恢复后验实际结果再归档。

## Windows 独立入口

- 双击 `C:\wsl-disks\maintenance\c0b-20261021\Start-C0b.cmd`。它从 Windows 启动 PowerShell，必要时用原所有者账号弹 UAC；不从 WSL 启动，不依赖助手会话。
- 或 Windows 开始菜单打开管理员 PowerShell 后执行：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\wsl-disks\maintenance\c0b-20261021\Start-C0b.ps1 -Run`。
- 说明：同目录 `README.txt`。关闭全部 VS Code（包括当前助手窗口）、Ubuntu/WSL 终端与 Windows Terminal 的 WSL 标签，以及正在访问 \\wsl$ / \\wsl.localhost 的资源管理器和程序；原生 Windows PowerShell 可用于运行启动器。
- 用户手动 Run 即确定新的维护时段，启动器自行记录本次 UTC 时间并执行 2 小时窗检查；不再需要助手填写 reviewed.json 或 ready.json，也不复用上一轮的文件。

## 三项修正

1. 任何 WSL/服务动作前，以及真正 shutdown 前，都检查 Code.exe/wsl.exe；发现残留则列名字与 PID 并拒绝，不硬关。shutdown 后等 10 秒，检查运行发行版为空；再次核进程、精确两块 VHDX 文件均释放，才进 DiskPart。每块 compact 前再查离线状态；不增加磁盘、删除或扩容操作。
2. 整条流程由 Windows 脚本自己完成：原生 preflight/status → platform-stop → 维护标记/暂停原附盘任务 → sync/fstrim 两盘 → shutdown/compact → 原附盘任务先附盘再开 Ubuntu → preflight/platform-start → Jenkins/代理检查 → platform-status/节点检查。关闭 WSL 后无需助手接续。互斥锁拒绝同时开第二个维护实例。
3. 离线异常立即写入 `offline-error.log`，随后才做恢复；恢复异常单独写 `recovery-error.log`，两份都保留，不再被 finally 覆盖。每条原生命令有独立 stdout/stderr 文件和退出码，避免只靠 transcript 漏掉原生命令输出；每轮在 `runs/<开始时间>/` 新建目录，`last-run.txt` 指向最近一轮。before/after-compact/after JSON 和 result JSON/log 保存空间与结果。独立 `-Recover <实际运行目录>` 只恢复服务，不再压缩。

## 准备验证（没有真停机）

- Windows PowerShell 5.1 解析与默认只读预览通过。实际 Ubuntu 注册的 VHDX 路径与脚本目标一致；当前无维护标记，C0b 的 runs 目录不存在。
- 16 项隔离检查通过：Code.exe/wsl.exe 阻断、空进程通过、有效/过期维护窗、两个阶段错误分别保留且原错误先落盘、成功阶段、英/中文 DiskPart 成功识别、退出 0 却失败/无成功文本的拒绝、WSL UTF-16 解码、原生退出 0/7 的真实捕获。只在 checks 下写隔离测试文件，并调用 cmd.exe 的 exit 探针；未调用 WSL、DiskPart、服务或任务修改。
- 原文：`fable-c0b.launcher-checks.20261021-114610.txt`；其他 preview、registration-check 原文也在 results。最终交付材料及逐文件 SHA-256：`fable-c0b.launcher-sources.final.20261021-115134.txt`（早期 114959 快照保留，但其中 CMD 是包装器检查前的版本，不作交付依据）。控制台 README 使用 Windows 可识别编码；CMD 为 CRLF，PowerShell/中文说明为 UTF-8 BOM。

- CMD 包装器人工核对发现两处分行错误，已修复；随后复制 CMD 原件到隔离目录，放入只记录 Run 参数并退出 17 的无害同名 PowerShell stub，实际从 cmd.exe 执行，确认参数传递、pause 与退出 17 保留均通过；未运行真实维护入口或 UAC。原文：`fable-c0b.cmd-wrapper-check.20261021-115052.txt`。

**未查**：没有替所有者执行 Windows 独立离线压缩，不宣称获得空间或完成 C0b。实际运行结束看绿色 Completed/exit=0 后再重开 WSL；失败看同轮日志，不盲目重跑。

exit=0
