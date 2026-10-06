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

## 续（所有者批准挪开、不删）

时间：2026-10-06 13:23 +0800。残留只改名，没有删除。待办写明的 `storage.py check`（不进 init 挂载命名空间）退出 1，所以 `platform-start`、状态、四个数量、`platform-check`、relay 都没有做。

### 1. 残留和正本

`du` 退出 0：`/data/kind-clusters` 52K，`/mnt/sunmoon-data/kind-clusters` 2.5G。

系统盘残留（`find -maxdepth 3`，退出 0）只有空目录：`sunmoon-kind/{bootstrap,control-plane,worker,worker2}` 以及各节点下的 `static`、`dynamic`，没有文件。

数据盘正本（退出 0）有 `identity.json`、多份 bootstrap-pull、`kind.yaml`、`calico`、`evidence`，以及同样的节点目录。

`find /data/kind-clusters -type f -newer .../identity.json` 退出 0，没有列出任何文件。残留里没有比正本更新的东西。

### 2. 挪开

三条都退出 0：

```
sudo mv /data/kind-clusters /data/kind-clusters.rootfs-stale-20261003
sudo mkdir -m 0755 /data/kind-clusters
drwxr-xr-x  2 root root 4096 Oct  6 13:23 kind-clusters
drwxr-xr-x  3 root root 4096 Oct  3 08:46 kind-clusters.rootfs-stale-20261003
```

### 3. 绑盘

`storage.py mount`（经 `nsenter --target 1 --mount`）退出 0：

```
{"storage_verified": true, "uuid": "a28de356-4ba1-4a21-93f5-744b9b9d8be0", "services_started": false}
```

待办里的 `storage.py check`（没有 nsenter）退出 **1**，原话：

```
Storage blocked: Wrong/missing UUID or bind root: /data/kind-clusters
```

同一条 shell 里的 `findmnt` 退出 0，两个路径仍在 `/`（`/dev/sdd`）。

按「check 不是 0 就停下」，第 4 步没有做。

为了分清是没绑上还是当前 shell 看不见，又只读看了 init 的挂载命名空间（没有再 mount，没有启动服务）：

```
/data/kind-clusters  /dev/sde[/kind-clusters]  ext4
/data/harbor         /dev/sde[/harbor]         ext4
nsenter storage.py check 退出 0
{"storage_verified": true, "uuid": "a28de356-4ba1-4a21-93f5-744b9b9d8be0", "services_started": false}
```

bind 在 PID 1 的挂载命名空间里已经成立。待办那条不进这个命名空间的 `check` 和 `findmnt` 仍看到系统盘。

## 续二（换 wsl.exe 起的 shell）

时间：2026-10-06 13:26 +0800。第 2 步 `check` 退出 1，第 3、4 步没有做。

### 1. 两个挂载命名空间

```
readlink /proc/self/ns/mnt          mnt:[4026532225]   exit=0
sudo readlink /proc/1/ns/mnt        mnt:[4026532219]   exit=0
```

两个不一样。PID 1 里 `findmnt -T /data/kind-clusters` 仍是 `/dev/sde[/kind-clusters]`，退出 0。

### 2. wsl.exe 起的 shell

```
/mnt/c/Windows/System32/wsl.exe -d Ubuntu -u zymun -- bash -lc '...'
```

这个 shell 的命名空间是 `mnt:[4026532225]`，和当前终端相同，不是 PID 1。`findmnt` 里 `/data/kind-clusters` 和 `/data/harbor` 都还在 `/`（`/dev/sdd`）。

`storage.py check` 的原话：

```
Storage blocked: Wrong/missing UUID or bind root: /data/kind-clusters
```

`wsl.exe` 自身退出码是 **1**（用 `false` 对照，`wsl.exe` 会把内部退出码传出来，`false` 的退出码是 1）。第一次在脚本里写 `echo exit=$?` 时，外层 shell 把 `$?` 换成了 0，那个 0 不作数。

### 3、4

没有跑 `platform-start`、状态、四个数量、`platform-check`、relay 镜像。

## 续三（命令钻进 PID 1 的挂载命名空间）

时间：2026-10-06 13:29–13:35 +0800。前缀是 `sudo nsenter --target 1 --mount -- sudo -u zymun -H bash -lc`。当前终端是 zsh，不拆 `$R`，所以这组命令放在 bash 里执行，进的命名空间不变。

### 1. 验证

```
mnt:[4026532219]
/data/kind-clusters  /dev/sde[/kind-clusters]
/data/harbor         /dev/sde[/harbor]
{"storage_verified": true, "uuid": "a28de356-4ba1-4a21-93f5-744b9b9d8be0", "services_started": false}
exit=0
```

这个 shell 的命名空间和 PID 1 相同。`check` 退出 **0**。

### 2. 拉起和检查

`platform-start` 退出 **0**，用时 **255.48 秒**（05:29:48Z 到 05:34:03Z）。日志尾部先是多次 `curl: (7) Failed to connect to harbor.sunmoonai.com port 11443`，随后：

```
node/sunmoon-kind-control-plane condition met
node/sunmoon-kind-worker condition met
node/sunmoon-kind-worker2 condition met
Owned Harbor, TLS entry and KIND restored. Run platform-check for application protocols.
```

`platform-status OBJECT=all` 退出 0。状态里现网源仍是 revision `e59bdc006a2eaca8c7b3af367ad7e801a6136547`、digest `sha256:e26d2a19932686a64a7226cbf64666c457d797450fdf92f462b184a1ca7a2aef`。

四个数量：

| 项 | 这次 | CHECKPOINT「已完成的运行状态」 |
| --- | --- | --- |
| 节点 | 3 个 Ready（control-plane、worker、worker2，v1.36.5） | 新三节点 Ready |
| Flux Kustomization | 63；`grep -vc True` 得到 0 | 当时写 51 个阶段 Ready；后来维护记录是 63 个阶段 Ready |
| Running Pod | 57；没有非 Running、非 Completed 的行 | 57 个 Running Pod |
| PV | 13 | 13 组 PV |

`platform-check OBJECT=all` 退出 **2**。停在 `services/verify.yaml` 读阶段：集群里没有 `neo4j-ui`、`object-storage-ui`、`rabbitmq-ui`、`flower`、`pgadmin`、`redisinsight`、`relay`。前面列出的已有阶段是 ok。PLAY RECAP：`ok=14 failed=1`。

### 3. relay 镜像

钉的摘要是 `sha256:dfc4d0e08fc83f846ceb1d3024a7f944b688f1283f886a89fb0c8c5b0702b647`。`docker pull` 退出 1：Harbor 已在听，但 HEAD 返回 **401 Unauthorized**。本机没有这份镜像，标签、创建时间、镜像里的 `relay.py` 都没有。工位源码 `sunmoonai/relay-platform/relay/relay.py` 的 sha256 是 `550019baa1a677a3a10c0ca3878384ac294d85627fe6381e049af10675ac6d62`。两边对不上，因为镜像侧没有哈希。没有改 lock，没有登录 Harbor。
