# 待办 21：安装「先附盘、再启动 Ubuntu」

- 工位：`~/worktrees/fable/k8s`
- 分支：`fable`
- HEAD：`1a4c244c`
- 时间：2026-10-06 13:48–13:50 +0800
- 结论：**通过**。没有重启 WSL，没有做待办 22。

当前终端挂载命名空间 `mnt` 和 PID 1 仍可能不同；`make` 按新入口自己处理，没有手工加 `nsenter`。

## 一、计划

`git log --oneline -1`：`1a4c244c switch-test: 待办 20 做完（现网已拉起；根因查清），移到 done`

`make -C infrastructure host-lifecycle-plan` 退出 **0**。PLAY RECAP：`ok=24 changed=6 unreachable=0 failed=0 skipped=39`。

## 二、差异

`diff` 退出 1（两边不同，这是预期）。全文只有先附盘那一段，和 blkid 分支里多的一行 throw：

```
14a15,23
> # Attach the existing VHDX BEFORE the first `wsl.exe -d` call. Starting the distribution first
> # makes systemd process fstab without the disk; a later attachment is then mounted only in PID 1's
> # mount namespace and user sessions never see it (observed 2026-10-06, first real WSL boot).
> $Running = @(wsl.exe --list --running --quiet 2>$null | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
> $EarlyAttach = $null
> if ($Running -notcontains $Distro) {
>     $EarlyAttachOutput = (wsl.exe --mount --vhd $Vhd --bare 2>&1 | Out-String)
>     $EarlyAttach = $LASTEXITCODE
> }
20a30
>     if ($null -ne $EarlyAttach -and $EarlyAttach -ne 0) { throw ('Attachment before distribution start failed; do not blindly unmount/retry: ' + $EarlyAttachOutput.Trim()) }
```

候选目录 `windows-files.json` 的 destination 是 `C:\ProgramData\Sunmoon\platform-kind-v1\boot-76a96ecb1e8fe60f`。

## 三、安装运行副本

`make -C infrastructure platform-install-lifecycle` 退出 **0**。PLAY RECAP：`ok=51 changed=6 unreachable=0 failed=0 skipped=21`。

`sunmoon-platform-boot.service` 仍是 enabled。`sunmoon-platform.target`、`sunmoon-registry.service`、`sunmoon-entry.service`、`sunmoon-cluster.service` 都是 active。

普通用户 `ls /mnt/sunmoon-data/backups/host/` 是 Permission denied（管道把退出码记成了 0）。root 下列表，新备份是 `lifecycle-92t66n89`（Oct 6 13:48）。

## 四、Windows 任务

用 `ZYMUN\zymun` 提权跑的，UAC 已通过。干跑打印了上面的 `windows-files.json`。应用打印：`Attachment task installed; logon trigger only, no recurring check. Services were not restarted.` 这两个 PowerShell 脚本没有设置 `LASTEXITCODE`，所以记录到的 `dry_exit` / `apply_exit` 是空的。

任务状态 Ready。动作参数：

```
//B //Nologo "C:\ProgramData\Sunmoon\platform-kind-v1\boot-76a96ecb1e8fe60f\run-storage-hidden.vbs"
```

## 五、启用 boot

`make -C infrastructure platform-enable-boot` 退出 **0**。PLAY RECAP：`ok=13 changed=1 unreachable=0 failed=0 skipped=50`。`sunmoon-platform-boot.service` 仍是 enabled。`windows-request-path.txt` 是 `C:\ProgramData\Sunmoon\platform-kind-v1\boot-76a96ecb1e8fe60f\request-storage.ps1`。

这一步按剧本改了六个容器的重启策略，其中包含旧 kind 的三个。改完它们仍是退出状态：`kind-control-plane` Exited (137) 约 3 天，`kind-worker` / `kind-worker2` Exited (255) 约 4 小时。新三节点仍是 Up。没有 start、没有删除。

## 六、不重启地跑一遍

提权手工跑新 `attach-storage.ps1`，`Boot=C:\ProgramData\Sunmoon\platform-kind-v1\boot-76a96ecb1e8fe60f`。输出：

```
{"storage_verified": true, "uuid": "a28de356-4ba1-4a21-93f5-744b9b9d8be0", "services_started": false}
attach exit=0
```

`make -C infrastructure platform-status OBJECT=all` 退出 **0**（8159 行）。两段 PLAY RECAP 都是 `failed=0`：宿主 `ok=3 skipped=60`，对象状态 `ok=7 skipped=5`。

## 七、结论

通过。先附盘的脚本已经装进 `boot-76a96ecb1e8fe60f`，登录任务指向它。现网在跑，这次没有重启 WSL。待办 22 没有做。
