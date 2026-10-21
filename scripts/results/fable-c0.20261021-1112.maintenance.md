# fable-c0：停机维护未完成，服务已恢复（luna）

WS=fable；准备提交 `ecb24a3d3e0e9083aeae0da1cc48cfb240089a2f`；当前远程基线 `da70d7fc5`。所有者已在会话中批准 ISO 校验后立即停机，批准时间 2026-10-21 10:49:54 CST；Windows 管理员启动器在 10:57:22 开始。

**结论：本次维护 fail，C0 仍未完成，不移动卡。** ISO 准备通过；停服务、sync、两块 ext4 的 fstrim 成功；离线压缩没有进入 DiskPart；现有业务服务已恢复，但原生 platform-start 的完整 Flux 验收失败。未重试停机，未删除任何 Flux 条目、节点、PVC、Job、镜像或业务数据，未改验收判据。

## 实际发生的顺序

1. 原生 preflight/status/stop 完成，Windows prepare 日志 `exit=0`；创建维护标记、暂停既有附盘任务，两个 fstrim 完成后交离线 worker。原始完整准备日志留在本机 `C:\wsl-disks\maintenance\c0-20261021\prepare-20261021-105722.log`。
2. worker 在 10:59:14 写 before.json，随后执行 WSL shutdown；在 10:59:52 进入恢复分支，目录中没有任何 diskpart-*.txt 或 diskpart-*.log，故确认未调用 DiskPart。
3. Windows 进程现场显示 10:59:35 后 `Code.exe` 的子进程调用了 wsl.exe（例如 14340，父进程 32616）；32616 的程序名确认为 Code.exe，另一个 Code.exe 25888 的子进程也在该时段启动 wsl.exe。**VS Code 自动连接使离线条件未能保持**；本地维护准备遗漏了要求关闭这些连接。离线失败的最初异常未单独落日志，后续 finally 中的恢复异常又覆盖了它，因此不能唯一还原究竟卡在“发行版已重启”还是“VHDX 文件仍被占用”的哪一道检查。
4. 恢复分支已去掉本次维护标记、恢复原附盘任务，任务 Enabled=true、LastTaskResult=0；Harbor、入口、集群、Jenkins 及代理均 active，三个节点 Ready。原生 platform-start 在 pod 就绪后等待 Flux；最终在 **11:11:58** 以失败结束，Windows worker `exit=1`，无 recovered.json。窗口此后可以关闭，未再次停服务。

## 恢复与失败证据

- 实测集群 286 个 Pod，非 Succeeded Pod 的 not_ready=0；三个节点 Ready。
- 严格校验平台 CA 的实际 30443 入口：Harbor health HTTP=200；Knowbench HTTP=307；Jenkins login HTTP=200。
- Flux 共 105 个 Kustomization，按 Ready=True 统计有 95 个通过、10 个未通过。失败对象全部是 namespace=flux-system 的旧 investment-*：investment-admin、investment-agent-releases、investment-database、investment-identity、investment-migration、investment-rabbitmq、investment-redis、investment-runtime、investment-service-identity、investment-web。它们 sourceRef 仍是 OCIRepository/platform，path 仍指 components/app-platform/investment-app/...。直接源路径失败与其依赖失败并存；不少依赖失败的 lastTransitionTime 已是 10-17，属于遗留问题。没有把这些对象删掉或跳过全量检查。
- 本机 `/opt/sunmoon/host/sunmoon-kind/boot.sh` 实际代码对所有 Flux 对象要求 Ready，最后记录 `Flux reconciliation timed out`；不修改现行 guard 冒充恢复验收成功。原生诊断日志在 `/var/log/sunmoon/platform-start.log`，Window worker 最终错误为 `WSL command failed: make -C .../infrastructure platform-start`。
- Windows 程序名、父进程及创建时间原文见 `fable-c0-windows-processes.20261021-111408.txt`（未采集命令行或凭据）。
- Windows 完整失败输出拷贝：`fable-c0-maintenance.20261021-105911.txt`，`exit=1`；盘点原文：`fable-c0-disk-snapshots.20261021-105722.txt`。
- 节点/Pod/Flux 原文在 `fable-c0-post-restart.20261021-110939.txt`。该诊断包装命令在后续入口循环中误用了 zsh 特殊变量 path，导致子 shell 内 PATH 被改写，`exit=127`；没有改全局环境，失败输出原样保留。纠正变量名后的三入口及 Windows 任务核对见 `fable-c0-entry-recovery.20261021-111002.txt`，`exit=0`，不重写失败原文。

## 实际空间

维护开始 C 空闲 **136,983,511,040 字节（127.576 GiB）**；离线尝试后 **137,207,033,856 字节（127.784 GiB）**；该观察区间净增 **223,522,816 字节（0.208 GiB）**。不能将这一变化归为 DiskPart 的收益，也不能写成已回收预估的 180 GiB。

系统 VHDX 文件长度仍为 515,737,911,296 字节；数据 VHDX 从 180,728,365,056 变为 180,493,484,032 字节，文件长度减少 234,881,024 字节（224 MiB）。两者与 C 空闲变化不是同一指标。

## 交远程 Fable

请给遗留 investment-* Flux 对象出范围明确的处置卡，并核对 startup guard 与当前晋级对象的关系；本地不自行删除或放宽标准。离线压缩下一次需要先让所有 VS Code/终端的 WSL 自动连接停止，再从 Windows 独立执行；原一次性 worker 的失败日志需在 finally 恢复之前保留，不能让恢复失败遮掉原异常。当前材料与日志保留，不盲目重跑 Apply，也不修改正在/已执行的材料。

C0 两个 ISO 仍在 C:\iso\，VMware 安装/界面建机和 SSH 核对均未完成；卡留 inbox/luna。建机前压缩的顺序仍照卡，是否改顺序由所有者/远程按新卡决定。

exit=1
