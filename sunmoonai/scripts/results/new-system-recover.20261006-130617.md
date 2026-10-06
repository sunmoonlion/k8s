# 待办 19：查开机恢复，再用 platform-start 拉起

- 工位：`~/worktrees/fable/k8s`
- 分支：`fable`
- 开始时 HEAD：`92799509`
- 时间：2026-10-06 13:06 +0800
- 结论：**不通过**。开机恢复单元跑过，停在附盘。`platform-start` 退出 2，用时 7.18 秒，没有启动 Harbor、入口或集群。第三节、第四节按待办没有做。

一句话：开机恢复跑了，停在 `boot.sh` 附盘。`storage.py` 报 `Wrong/missing UUID or bind root: /mnt/sunmoon-data`，Windows 附盘接着抛 `Attachment task failed; services remain blocked`。容量、Harbor 健康、入口、集群、等 Pod、等 Flux 都没走到。

## 一、只读诊断

当前这次 WSL 开机是 `2026-10-06 09:19:43 CST`（boot id `d29dd11a41ff4a78ad6ce6bc27863391`）。上一开机停在 `2026-10-06 00:42:16 CST`。诊断时 `uptime` 为 3 小时 46 分，`systemctl is-system-running` 为 `degraded`（退出 1）。

`sunmoon-platform-boot.service` 是 enabled。它在 09:19:48 启动，09:19:57 失败，主进程 `boot.sh boot` 退出 1，只跑了 8.7 秒。`sunmoon-data-boot.service` 是 disabled。`sunmoon-platform.target`、`sunmoon-registry.service`、`sunmoon-entry.service`、`sunmoon-cluster.service` 都是 inactive (dead)。Docker 从 09:19:48 起是 active。`sunmoon-wsl-interop.service` 09:19:43 成功退出。

维护标记 `/mnt/c/wsl-disks/sunmoon-data.maintenance` 不存在。

挂载：

```
/mnt/sunmoon-data  /dev/sde  ext4
/data/kind-clusters 和 /data/harbor 都落在根文件系统 /dev/sdd，不是独立 bind
```

当时再跑 `storage.py check` 退出 1，报的是下一条：`Wrong/missing UUID or bind root: /data/kind-clusters`。期望的三挂载是 `/mnt/sunmoon-data`（fsroot `/`）、`/data/kind-clusters`（fsroot `/kind-clusters`）、`/data/harbor`（fsroot `/harbor`），盘 UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`。开机那一下先卡在第一挂载；现在第一挂载在了，两个 bind 仍不在。

Windows 计划任务 `sunmoon-data-mount`：`LastRunTime 2026/10/6 9:19:13`，`LastTaskResult 1`，`NextRunTime` 空，`NumberOfMissedRuns 0`。

`systemctl status` 与本开机 unit journal 如下。

```
● docker.service - Docker Application Container Engine
     Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; preset: enabled)
     Active: active (running) since Tue 2026-10-06 09:19:48 CST; 3h 45min ago
   Main PID: 303 (dockerd)

○ sunmoon-wsl-interop.service
     Active: inactive (dead) since Tue 2026-10-06 09:19:43 CST
    Process: 165 ExecStart=.../wsl_interop.py --apply (code=exited, status=0/SUCCESS)
Oct 06 09:19:43 python3[165]: {"available": true, "handler_restored": false, "windows_process_started": false, "restart_performed": false}

× sunmoon-platform-boot.service - Recover SunMoon once after WSL startup
     Loaded: loaded (/etc/systemd/system/sunmoon-platform-boot.service; enabled; preset: enabled)
     Active: failed (Result: exit-code) since Tue 2026-10-06 09:19:57 CST
   Duration: 8.737s
    Process: 814 ExecStart=/opt/sunmoon/host/sunmoon-kind/boot.sh boot (code=exited, status=1/FAILURE)
Oct 06 09:19:53 boot.sh[971]: Storage blocked: Wrong/missing UUID or bind root: /mnt/sunmoon-data
Oct 06 09:19:57 boot.sh[975]: Attachment task failed; services remain blocked
Oct 06 09:19:57 boot.sh[975]: [102B blob data]
Oct 06 09:19:57 boot.sh[975]:     + CategoryInfo          : OperationStopped: (Attachment task... remain blocked:String) [], RuntimeException
Oct 06 09:19:57 boot.sh[975]:     + FullyQualifiedErrorId : Attachment task failed; services remain blocked
Oct 06 09:19:57 systemd[1]: sunmoon-platform-boot.service: Failed with result 'exit-code'.

○ sunmoon-platform.target     Active: inactive (dead)
○ sunmoon-registry.service    Active: inactive (dead)   （unit disabled）
○ sunmoon-entry.service       Active: inactive (dead)   （unit disabled）
○ sunmoon-cluster.service     Active: inactive (dead)
```

本开机这五个 unit 的 `journalctl -b` 只有上面 wsl-interop 成功和 platform-boot 失败这两段，没有 Harbor、入口、集群的启动记录。`boot.sh` 对应行是附盘：先 `storage.py check`，失败后调用 `C:\ProgramData\Sunmoon\platform-kind-v1\boot-6f82dd8673eeb6a0\request-storage.ps1`。journal 里 PowerShell 的 102 字节二进制块没有展开，避免把里面的内容写进回传。

## 二、platform-start

`make -C infrastructure platform-start` 退出 **2**，用时 **7.18 秒**（2026-10-06T05:06:10Z 到 05:06:17Z）。没有手工 bind，没有 `docker start`，没有动旧 kind 的三个容器。

它停在 `lifecycle.yaml` 的「Start the reviewed worktree independent sequence」（`boot.sh manual`）。Ansible 拒绝反序列化这条命令的输出：`invalid UTF8 string value: surrogates not allowed`。PLAY RECAP：`ok=4 changed=0 unreachable=0 failed=1 skipped=48`。`make: *** [Makefile:393: platform-start] Error 2`。

因此 `boot.sh manual` 的正文没有进 Ansible 结果。从同一份 `boot.sh` 和开机 journal 看，它同样会先撞上附盘失败；这次连输出都没被 Ansible 收下。

最后一段：

```
TASK [Start the reviewed worktree independent sequence] ************************
[ERROR]: Task failed: Refusing to deserialize an invalid UTF8 string value: 'utf-8' codec can't encode characters in position 119-122: surrogates not allowed
Origin: /home/zymun/worktrees/fable/k8s/infrastructure/host/lifecycle.yaml:334:11
fatal: [localhost]: FAILED! => {"changed": false, "msg": "Task failed: Refusing to deserialize an invalid UTF8 string value: 'utf-8' codec can't encode characters in position 119-122: surrogates not allowed"}

PLAY RECAP *********************************************************************
localhost                  : ok=4    changed=0    unreachable=0    failed=1    skipped=48   rescued=0    ignored=0

make: *** [Makefile:393: platform-start] Error 2
elapsed_sec=7.18
exit=2
```

`journalctl -b -u sunmoon-cluster.service -u sunmoon-registry.service -u sunmoon-entry.service --no-pager | tail -80` 的结果是：

```
-- No entries --
```

## 三、四

`platform-start` 不是 0，这两节没有做。没有 `platform-status`、`platform-check`，没有四个数量，没有 relay 镜像的标签、创建时间和两个 sha256。

## 五、结论

不通过。第一次真实开机时，恢复单元有跑，死在附盘，平台没起来。日常入口 `platform-start` 也没越过这一步，而且 Ansible 因 `boot.sh` 输出里的非法 UTF-8 直接失败。现网仍和待办 18 一样：两个 bind 不在，Harbor 和集群没在听。

## 六、所有者这轮另说的一句

本地助手收到的原话是：「现在我决定先上 Argo 了。」这一轮没有改发布链，没有开始换 Argo。只写在这里，避免下一轮还按「先留 Flux」去做。
