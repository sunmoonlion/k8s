# 新体系：真实重启一次 WSL，验开机恢复（本地机；**所有者说「跑 22」才做**）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按编号步骤做（停平台 → wsl --shutdown → 重新登录或手动触发附盘任务 → 等开机恢复 → 从新会话验）
仓与提交：待办 21 通过之后的 fable 头
预计：30 分钟；停服一次（现网会停、再自动起来）；会断掉本地助手在 WSL 里的会话，第三步起要在 Windows 侧的 PowerShell 里操作
看什么：WSL 起来后不用任何人工干预，sunmoon-platform-boot.service 成功、现网自己回来；新开的用户会话看得见 /data 两个 bind
前提：待办 21 通过；维护标记不存在；容量底线由脚本自己检查；不碰旧 kind
回传：k8s/sunmoonai/scripts/results/real-wsl-reboot.<时间>.md
```

## 一、停平台（WSL 里）

```bash
cd ~/worktrees/fable/k8s && make -C infrastructure platform-stop; echo "exit=$?"
docker ps --format '{{.Names}} {{.Status}}' | sort
```

## 二、关 WSL（Windows PowerShell，普通权限即可）

```powershell
wsl.exe --shutdown
Start-Sleep -Seconds 15
wsl.exe --list --running
```

## 三、模拟登录触发附盘（Windows PowerShell，所有者账号）

真正的登录触发要注销再登录；这里用手动触发同一个任务代替，效果一样（它会附盘并启动 Ubuntu）：

```powershell
Start-ScheduledTask -TaskName sunmoon-data-mount
Start-Sleep -Seconds 60
Get-ScheduledTaskInfo -TaskName sunmoon-data-mount | Format-List LastRunTime, LastTaskResult
wsl.exe --list --running
```

`LastTaskResult` 必须是 0。

## 四、等开机恢复（Windows PowerShell，通过 wsl.exe 看）

```powershell
wsl.exe -d Ubuntu -u root -- bash -c 'for i in $(seq 1 60); do s=$(systemctl is-active sunmoon-platform-boot.service); echo "$(date +%T) $s"; case $s in active|failed) break;; esac; sleep 15; done; systemctl status sunmoon-platform-boot.service --no-pager -l | tail -20; journalctl -b -u sunmoon-platform-boot.service --no-pager | tail -40'
```

`active` 就是恢复成功（Type=simple + RemainAfterExit）；`failed` 就把 journal 贴上，停下。

## 五、从新会话验（可以回到 WSL 里开新终端做）

```bash
readlink /proc/self/ns/mnt; sudo readlink /proc/1/ns/mnt
findmnt -T /data/kind-clusters; findmnt -T /data/harbor
cd ~/worktrees/fable/k8s && make -C infrastructure platform-status OBJECT=all; echo "exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=infrastructure/.tools/bin/kubectl
$K get nodes; $K get kustomizations -A --no-headers | grep -vc True; $K get pods -A --no-headers | grep -vE "Running|Completed" | head
docker ps -a --format '{{.Names}} {{.Status}}' | grep -E '^kind-' 
```

两个 ns 应该相同（盘在开机前附好，fstab 在最初的命名空间挂的）；旧 kind 三个容器应保持退出。

## 六、回传里要有的

1. 附盘任务的 `LastTaskResult`；boot 单元的最终状态和 journal 尾部。
2. 第五节的全部输出。
3. 结论：通过 / 不通过 / 判断不了。
