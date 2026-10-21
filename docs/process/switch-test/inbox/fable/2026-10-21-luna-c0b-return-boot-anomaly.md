# C0b 已压缩，回连额外遇到自动恢复的 scope/cgroup 失败（luna → Fable）

C0a 已完成；C0b 本次真正执行两次 DiskPart 并成功，净回收 109.54 GiB，独立脚本 19 步 exit=0。C0b 回执 `scripts/results/fable-c0b.20261021-1220.md`，卡已移 done。C0 虚拟机卡仍在 inbox/luna，等待所有者按 VMware GUI 建机。

请单独排查以下自动恢复问题；本地未改 runtime/启动机制，只用原生 Make 恢复服务。

## 事实（2026-10-21 CST）

1. 独立脚本 12:09:13 完成恢复，platform-start、Jenkins、platform-status、3 节点检查均 exit=0。
2. systemd 日志 12:09:27 开始停止 cluster/boot；停止触发者尚未确定，不将 WSL 空闲退出作为已证实原因。
3. 12:09:52 boot 再次启动，先等待 Harbor health；12:11:41 启动三个 KIND 容器时失败：`OCI runtime create failed ... unable to apply cgroup configuration ... unable to start unit docker-<container-id>.scope ... got failed`。boot 退出 1。
4. 本地 platform-preflight=0；单次 `make -C infrastructure platform-start` 重试成功，12:13:09 三节点 Ready，整条 Make exit=0；无 Docker daemon 重置、systemd 定义修改、手工 docker start 或再次 WSL shutdown。
5. 12:17:50：96 Flux Ready 且 generation 匹配，273 Pod Ready/Succeeded；Harbor=200、Knowbench=307、Jenkins=200，严格校验平台 CA；五个服务 active。Windows 附盘任务 Ready/Enabled/LastTaskResult=0，无维护标记。
6. boot.service 仍保留 failed/ExecMainStatus=1 历史，未 reset-failed。压缩成功和当前服务恢复可用不等于无人值守自动恢复可靠。

## 证据

- `scripts/results/fable-c0b.return-boot-journal.20261021-1218.txt`：本轮 boot/cluster 的完整相关时间窗日志，包含成功、停止、失败和重试。
- `scripts/results/fable-c0b.return-{preflight.20261021-121237,start.20261021-121258,checks.20261021-121750,windows.20261021-1219}.txt`：原生恢复与事后检查。
- `scripts/results/fable-c0b.20261021-1220.raw.txt`：Windows 全轮文件 SHA-256、空间快照和关键完整输出；原件在 `C:\wsl-disks\maintenance\c0b-20261021\runs\20261021-115628-880\`。

请远程确定是否需另开宿主启动卡；当前没有为复现而再停服务，后续真实重启验收需安排维护窗口。
