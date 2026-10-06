# 待办 20：拿到附盘的真实报错

- 工位：`~/worktrees/fable/k8s`
- 分支：`fable`
- HEAD：`18926291`
- 时间：2026-10-06 13:21 +0800
- 结论：**不通过**。附盘死在 Linux 守卫：`/data/kind-clusters` 还没挂上，而且目录不是空的。`storage.py check` 退出 1。按待办，第二节及以后没有做。

一句话：附盘死在 `attach-storage.ps1` 第 26 行。它调用的 `storage.py mount` 报 `Unmounted target is not an empty directory: /data/kind-clusters`，因为这个路径在系统盘上，里面已经有一个 `sunmoon-kind` 目录，守卫拒绝往上覆盖。

## 一、1a

用所有者账号 `ZYMUN\zymun` 提权跑的。UAC 已通过。待办里的那几行放在 `C:\wsl-disks\scripts\platform-kind-v1\attach-manual-runner.ps1`，再 `Start-Process -Verb RunAs`，因为从 WSL 直接开的 PowerShell 不是管理员。Transcript：`C:\wsl-disks\scripts\platform-kind-v1\attach-manual.log`。开始 `20261006132032`，结束 `20261006132033`。`attach exit=1`。

日志是 UTF-8 和 UTF-16 混在一起，中文表头乱码，英文报错完整。去掉乱码后的正文：

```
Storage blocked: Unmounted target is not an empty directory: /data/kind-clusters
Existing disk mount failed; see the precise Linux guard error above
所在位置 C:\ProgramData\Sunmoon\platform-kind-v1\boot-6f82dd8673eeb6a0\attach-storage.ps1:26 字符: 28
+ ... DE -ne 0) { throw 'Existing disk mount failed; see the precise Linux  ...
    + CategoryInfo          : OperationStopped: (Existing disk m...ard error above:String) [], RuntimeException
    + FullyQualifiedErrorId : Existing disk mount failed; see the precise Linux guard error above
attach exit=1
```

没有口令。`wsl --mount` 没有报错，盘已经在。失败发生在挂完之后的 Linux `storage.py mount`。

## 一、1b

| 命令 | 退出码 | 输出 |
| --- | --- | --- |
| `sudo blkid -U a28de356-4ba1-4a21-93f5-744b9b9d8be0` | 0 | `/dev/sde` |
| `grep` `/etc/fstab` | 0 | 见下 |
| `findmnt` 三个路径 | 0 | `/mnt/sunmoon-data` 在 `/dev/sde`；另外两个落在 `/`（`/dev/sdd`） |
| `ls -la /data/kind-clusters /data/harbor` | 0 | 见下 |
| `storage.py mount` | 1 | `Storage blocked: Unmounted target is not an empty directory: /data/kind-clusters` |
| `storage.py check` | 1 | `Storage blocked: Wrong/missing UUID or bind root: /data/kind-clusters` |
| 再 `findmnt` 两个 bind | 0 | 仍在 `/`（`/dev/sdd`） |

fstab：

```
UUID=a28de356-4ba1-4a21-93f5-744b9b9d8be0 /mnt/sunmoon-data ext4 defaults,nofail,x-systemd.device-timeout=10s 0 2
/mnt/sunmoon-data/kind-clusters /data/kind-clusters none bind,nofail,x-systemd.requires=/mnt/sunmoon-data 0 0
/mnt/sunmoon-data/harbor /data/harbor none bind,nofail,x-systemd.requires=/mnt/sunmoon-data 0 0
```

`/data/kind-clusters` 不是空目录，没有删：

```
/data/harbor:
total 8
drwxr-xr-x 2 root root 4096 Sep 27 11:29 .
drwxr-xr-x 5 root root 4096 Sep 27 11:29 ..

/data/kind-clusters:
total 12
drwxr-xr-x 3 root root 4096 Oct  3 08:46 .
drwxr-xr-x 5 root root 4096 Sep 27 11:29 ..
drwxr-xr-x 6 root root 4096 Oct  3 08:46 sunmoon-kind
```

`/data/harbor` 是空的。挡住 bind 的是 `/data/kind-clusters/sunmoon-kind`，时间是 10 月 3 日 08:46，和上一开机结束的时刻一致。

## 二、三、四

`check` 不是 0，而且守卫原话就是「Unmounted target is not an empty directory」。`platform-start`、状态、四个数量、`platform-check`、relay 镜像都没有做。

## 五、结论

不通过。数据盘本身已经挂上（`/dev/sde`，UUID 对得上）。两个 bind 起不来，是因为系统盘上的 `/data/kind-clusters` 里留着一份 `sunmoon-kind`，守卫拒绝覆盖。目录还在，没有删。
