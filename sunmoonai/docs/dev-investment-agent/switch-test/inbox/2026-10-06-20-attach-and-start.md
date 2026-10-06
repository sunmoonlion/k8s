# 新体系：先把附盘那一步的真实报错拿到，再拉起现网（本地机；第一节的 1a 要所有者在管理员 PowerShell 里跑）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按编号步骤做（1a 所有者跑附盘任务并留日志 → 1b 本地助手看 Linux 这一侧的报错 → 2 platform-start → 3 状态与检查 → 4 relay 镜像）
仓与提交：k8s 本条待办所在的 fable 头（含 infrastructure/host/lifecycle.yaml 的一处改动：platform-start 的输出先写日志再交给 Ansible）
预计：40 分钟；platform-start 内部有界等待最长约 15 分钟
看什么：1a/1b 能说出附盘失败的那一行报错；2 退出 0；3 的 status/check 退出 0、3 节点 Ready、Flux 阶段全 Ready、Running Pod 全 Ready
前提：不碰原始旧 kind 的三个容器；不碰维护标记；不删任何目录里的文件（第 1b 步如果说目录非空，只列出来，停）；不 stage、不 flux-release、不 deploy
回传：k8s/sunmoonai/scripts/results/attach-and-start.<时间>.md（口令、令牌、age 密钥不贴；Windows 日志里的用户名可以留）
```

## 19 查到的

开机恢复单元跑了，死在附盘：`boot.sh boot` 先 `storage.py check` 报 `/mnt/sunmoon-data` 没挂，于是请求 Windows 的附盘任务 `sunmoon-data-mount`；那个任务 09:19:13 就跑过一次（登录触发），结果是 1，所以 boot.sh 直接报「Attachment task failed」退出。任务的 PowerShell 是用 `wscript` 隐藏窗口跑的，**它的报错没有写到任何地方**，所以到现在不知道它死在 `attach-storage.ps1` 的哪一行（守卫哈希、`wsl --mount`、还是 Linux 侧的 `storage.py mount`）。另外 `platform-start` 这条路因为 PowerShell 输出不是合法 UTF-8，Ansible 连输出都收不下；这次改了 `lifecycle.yaml`，输出先写 `/var/log/sunmoon/platform-start.log`。

现在的状态：`/mnt/sunmoon-data` 挂着（谁挂的不清楚），`/data/kind-clusters`、`/data/harbor` 两个 bind 不在。

## 一、附盘的真实报错

### 1a（所有者，管理员 PowerShell，用您自己的账号）

把附盘脚本再跑一遍，这次把所有输出留下：

```powershell
$Boot = 'C:\ProgramData\Sunmoon\platform-kind-v1\boot-6f82dd8673eeb6a0'
Get-ChildItem $Boot
Start-Transcript -Path C:\wsl-disks\scripts\platform-kind-v1\attach-manual.log -Force
& powershell.exe -NoProfile -NonInteractive -File "$Boot\attach-storage.ps1"
"attach exit=$LASTEXITCODE"
Stop-Transcript
```

跑完把 `C:\wsl-disks\scripts\platform-kind-v1\attach-manual.log` 的内容交给本地助手放进回传。它要么成功（那两个 bind 就回来了），要么在某一行 `throw`，那一行就是答案。

### 1b（本地助手）

不管 1a 成不成，都把 Linux 这一侧的守卫单独跑一遍，看它的原话（这就是附盘任务最后调用的那条命令，只会挂已有的盘，不会建、不会格式化）：

```bash
sudo blkid -U a28de356-4ba1-4a21-93f5-744b9b9d8be0; echo "exit=$?"
grep -nE "sunmoon-data|kind-clusters|/data/harbor" /etc/fstab
findmnt -T /mnt/sunmoon-data; findmnt -T /data/kind-clusters; findmnt -T /data/harbor
ls -la /data/kind-clusters /data/harbor | head -20
sudo nsenter --target 1 --mount -- /usr/bin/python3 /opt/sunmoon/host/sunmoon-kind/storage.py mount /opt/sunmoon/host/sunmoon-kind/storage.json; echo "exit=$?"
sudo /usr/bin/python3 /opt/sunmoon/host/sunmoon-kind/storage.py check /opt/sunmoon/host/sunmoon-kind/storage.json; echo "exit=$?"
findmnt -T /data/kind-clusters; findmnt -T /data/harbor
```

守卫说「Unmounted target is not an empty directory」就把那个目录的 `ls -la` 整段放进回传并停下，**不要删里面的东西**，第二节不做。说别的也照抄原话。`check` 退出 0 才做第二节。

## 二、拉起

```bash
cd ~/worktrees/fable/k8s && git log --oneline -1
make -C infrastructure platform-start; echo "exit=$?"
sudo tail -n 80 /var/log/sunmoon/platform-start.log
```

退出不是 0：把日志尾部放进回传，第三节不做。不要手工 `docker start`，不要动旧 kind。

## 三、状态与检查

```bash
make -C infrastructure platform-status OBJECT=all; echo "exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config
K=infrastructure/.tools/bin/kubectl
$K get nodes
$K get kustomizations -A --no-headers | wc -l
$K get kustomizations -A --no-headers | grep -vc True
$K get pods -A --field-selector=status.phase=Running --no-headers | wc -l
$K get pods -A --no-headers | grep -vE "Running|Completed" | head
$K get pv --no-headers | wc -l
make -C infrastructure platform-check OBJECT=all; echo "exit=$?"
```

## 四、relay 镜像

```bash
D=$(grep '^digest:' gitops/components/relay-platform/relay/image.lock.yaml | awk '{print $2}')
docker pull harbor.sunmoonai.com:30443/app-images/relay@$D; echo "exit=$?"
docker inspect --format '{{json .Config.Labels}}' harbor.sunmoonai.com:30443/app-images/relay@$D
docker inspect --format '{{.Created}}' harbor.sunmoonai.com:30443/app-images/relay@$D
docker run --rm --entrypoint sh harbor.sunmoonai.com:30443/app-images/relay@$D -c 'sha256sum /app/relay.py 2>/dev/null || find / -name relay.py -not -path "*/site-packages/*" 2>/dev/null | head -3'
sha256sum sunmoonai/relay-platform/relay/relay.py
```

## 五、回传里要有的

1. 1a 的日志全文（去掉口令）；1b 每条命令的输出和退出码；一句话：附盘死在哪一行、为什么。
2. `platform-start` 的退出码和日志尾部。
3. 第三节四个数量和对照；`platform-check` 的退出码。
4. relay 镜像的标签、创建时间、两个 sha256。
5. 结论：通过 / 不通过 / 判断不了。
