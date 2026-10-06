# 新体系：把「先附盘、再启动 Ubuntu」的附盘脚本装上去（本地机；有一次 UAC 由所有者确认）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按编号步骤做（计划 → 看差异 → 安装运行副本 → Windows 任务重新发布 → 启用 boot → 不重启地验一遍）
仓与提交：k8s 本条待办所在的 fable 头（含 infrastructure/Makefile、host/templates/attach-storage.ps1.j2、host/troubleshooting.md 三处改动）
预计：30 分钟；不停服
看什么：第 2 步候选和现装的附盘脚本只差「先附盘」那一段；第 3、5 步退出 0；第 6 步手工跑附盘脚本退出 0 且现网不受影响
前提：现网在跑（待办 20 续三拉起的）；不碰旧 kind；不 stage/发布/晋级/deploy。这是文档里写的「维护安装」，所有者批准本待办即批准
回传：k8s/sunmoonai/scripts/results/boot-order-install.<时间>.md（口令、密钥不贴）
```

## 改了什么、为什么

待办 20 查明：登录时的附盘任务第一句就 `wsl.exe -d Ubuntu`（启动了 Ubuntu），之后才 `wsl --mount`。Ubuntu 一启动 systemd 就按 fstab 挂盘，那时盘还没附上，挂不到；事后再挂只落在 PID 1 的挂载命名空间，用户会话永远看不见。改动三处：

1. `host/templates/attach-storage.ps1.j2`：Ubuntu 没在跑时，先 `wsl --mount --vhd --bare`，再做哈希守卫和后面的步骤。盘已经附着时 `--mount` 会报错，脚本接着用 `blkid -U` 核实，核实到就继续。
2. `infrastructure/Makefile`：所有 `make` 入口在用户会话和 PID 1 不在同一挂载命名空间时，自己钻进 PID 1 的命名空间跑（身份仍是当前用户）。以后不用手工加 `nsenter`。
3. `host/troubleshooting.md`：加了这一条。

第 1 处要重新安装 root 运行副本并重新发布 Windows 任务才生效（文档「首次维护安装与 Windows 任务」那一节的流程）。

## 一、计划（只生成候选）

```bash
cd ~/worktrees/fable/k8s && git log --oneline -1
readlink /proc/self/ns/mnt; sudo readlink /proc/1/ns/mnt
make -C infrastructure host-lifecycle-plan; echo "exit=$?"
```

现在不用再手工加 `nsenter`：Makefile 自己处理。退出不是 0 就停下贴输出。

## 二、看差异

```bash
diff <(sed 's/\r$//' /mnt/c/ProgramData/Sunmoon/platform-kind-v1/boot-6f82dd8673eeb6a0/attach-storage.ps1) <(sed 's/\r$//' /mnt/c/wsl-disks/scripts/platform-kind-v1/candidate/attach-storage.ps1)
cat /mnt/c/wsl-disks/scripts/platform-kind-v1/candidate/windows-files.json
```

差异只能是 `$Running`/`$EarlyAttach` 那一段和 blkid 分支里多的一行 throw。多了别的就停下贴出来。

## 三、安装运行副本（不启用 boot，不停服）

```bash
make -C infrastructure platform-install-lifecycle; echo "exit=$?"
systemctl is-enabled sunmoon-platform-boot.service; systemctl is-active sunmoon-platform.target sunmoon-registry.service sunmoon-entry.service sunmoon-cluster.service
ls -la /mnt/sunmoon-data/backups/host/ | tail -3
```

它会把旧单元、重启策略备份到 `/mnt/sunmoon-data/backups/host/lifecycle-*`。现网单元应保持 active。

## 四、Windows 任务重新发布（管理员 PowerShell，所有者账号；弹 UAC 时所有者确认）

```powershell
$Candidate = 'C:\wsl-disks\scripts\platform-kind-v1\candidate'
& "$Candidate\install-task.ps1" -CandidateDirectory $Candidate
& "$Candidate\install-task.ps1" -CandidateDirectory $Candidate -Apply
Get-ScheduledTask -TaskName sunmoon-data-mount | Select-Object State, @{n='Action';e={$_.Actions[0].Arguments}}
```

第二条跑完，任务应指向新的 `C:\ProgramData\Sunmoon\platform-kind-v1\boot-<新摘要>\run-storage-hidden.vbs`。

## 五、启用 boot

```bash
make -C infrastructure platform-enable-boot; echo "exit=$?"
systemctl is-enabled sunmoon-platform-boot.service
cat /opt/sunmoon/host/sunmoon-kind/windows-request-path.txt
```

## 六、不重启地验一遍

在管理员 PowerShell（所有者账号）里把新附盘脚本手工跑一次，现在盘已经附着、Ubuntu 在跑，它应该走「已附着」分支直接通过：

```powershell
$Boot = (Get-ScheduledTask -TaskName sunmoon-data-mount).Actions[0].Arguments -replace '.*"(.*)\\run-storage-hidden.vbs".*','$1'
Start-Transcript -Path C:\wsl-disks\scripts\platform-kind-v1\attach-manual-2.log -Force
& powershell.exe -NoProfile -NonInteractive -File "$Boot\attach-storage.ps1"
"attach exit=$LASTEXITCODE"
Stop-Transcript
```

然后在 WSL：

```bash
make -C infrastructure platform-status OBJECT=all; echo "exit=$?"
```

现网应原样在跑。

## 七、回传里要有的

1. 每步退出码；第二步的 diff 全文；第四步任务指向的新目录。
2. 第六步的日志；status 的输出。
3. 结论：通过 / 不通过 / 判断不了。

真实重启 WSL 的验收是下一条待办（22），要所有者另说一声才跑。
