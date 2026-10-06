# 新体系：查清开机为什么没恢复，再用统一入口把现网拉起来（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按下面编号步骤做（只读诊断 → platform-start → 状态与检查 → relay 镜像 → 18 的四个计数）
仓与提交：k8s 本条待办所在的 fable 头（工具已在 18 装好，不用重装）
预计：40 分钟；要 WSL、Docker；platform-start 内部有界等待最长约 15 分钟
看什么：第 1 步能说出开机恢复停在哪一步、为什么；第 2 步 platform-start 退出 0；第 3 步 status/check 退出 0，节点 3 Ready、Flux 阶段全部 Ready、Running Pod 全部 Ready
前提：不碰原始旧 kind 的三个容器（不 start、不 rm）；不碰维护标记；容量检查在 platform-start 里，不手工放宽；不 stage、不 flux-release、不 deploy
回传：k8s/sunmoonai/scripts/results/new-system-recover.<时间>.md（写下后在被测仓提交；口令、令牌、age 密钥一律不贴；journal 里有的话打码）
```

## 为什么有这一轮

待办 18 发现：数据盘 `/mnt/sunmoon-data` 挂着，但两个 bind（`/data/kind-clusters`、`/data/harbor`）不在；新集群三个节点、Harbor、入口容器全部在同一时刻（约 4 小时前）退出，退出码 255。这是 WSL 重启过的样子。新体系有一个「单次开机恢复」单元（`sunmoon-platform-boot.service` → `boot.sh boot`：附盘 → 容量 → Harbor → 入口 → 集群 → 等 Pod 和 Flux 就绪），验收边界里写明它**从没经过真实开机验证**。这次就是第一次真实开机，而它没有把平台恢复起来。所以这一轮先查清它停在哪，再用日常入口 `platform-start` 恢复，不要手工去 bind、去 docker start。

## 一、只读诊断（先做完这一节再做第二节）

```bash
cd ~/worktrees/fable/k8s
uptime; date -u
systemctl is-system-running
journalctl --list-boots --no-pager | tail -3
systemctl status docker sunmoon-wsl-interop.service sunmoon-platform-boot.service sunmoon-platform.target sunmoon-registry.service sunmoon-entry.service sunmoon-cluster.service --no-pager -l
systemctl is-enabled sunmoon-platform-boot.service sunmoon-data-boot.service 2>&1
journalctl -b -u sunmoon-platform-boot.service -u sunmoon-registry.service -u sunmoon-entry.service -u sunmoon-cluster.service -u sunmoon-wsl-interop.service --no-pager
ls -la /mnt/c/wsl-disks/sunmoon-data.maintenance 2>&1
findmnt -T /mnt/sunmoon-data; findmnt -T /data/kind-clusters; findmnt -T /data/harbor
ls -la /opt/sunmoon/host/sunmoon-kind/ | head -30
sudo /usr/bin/python3 /opt/sunmoon/host/sunmoon-kind/storage.py check /opt/sunmoon/host/sunmoon-kind/storage.json; echo "exit=$?"
/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -NonInteractive -Command "Get-ScheduledTask -TaskName sunmoon-data-mount | Get-ScheduledTaskInfo | Format-List LastRunTime,LastTaskResult,NextRunTime,NumberOfMissedRuns"
```

把 `systemctl status` 和 `journalctl` 的输出整段放进回传。要回答的是一句话：**开机恢复单元有没有跑；跑了的话停在 `boot.sh` 的哪一行（等 WSL 就绪、附盘、容量、Harbor 健康、入口、集群、等 Pod、等 Flux）、报了什么**。没跑的话，说它为什么没跑（没启用、条件不满足、docker 没起来……）。

## 二、用日常入口恢复

```bash
make -C infrastructure platform-start; echo "exit=$?"
```

它按文档的顺序做：附盘/三挂载 → 容量 → Harbor 健康 → 入口 → 三节点与 API → 有界等待 Pod 和 Flux 就绪。退出不是 0 就停下，把它最后 60 行输出和 `journalctl -b -u sunmoon-cluster.service -u sunmoon-registry.service -u sunmoon-entry.service --no-pager | tail -80` 放进回传，第三节不做。

**不要**手工 `mount --bind`、不要 `docker start` 任何容器、不要动原始旧 kind 的 `kind-control-plane`、`kind-worker`、`kind-worker2`（它们退出着就让它们退出着）。

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

`platform-check` 会创建限定的协议探针并清理，不是纯只读，文档允许。四个数量和 `CHECKPOINT.md`「已完成的运行状态」对照（3 节点、Flux 阶段当前代次全 Ready、Running Pod 全 Ready、13 组 PV）。

## 四、relay 镜像（待办 18 的第四节，这次 Harbor 起来了再做）

```bash
D=$(grep '^digest:' gitops/components/relay-platform/relay/image.lock.yaml | awk '{print $2}')
docker pull harbor.sunmoonai.com:30443/app-images/relay@$D; echo "exit=$?"
docker inspect --format '{{json .Config.Labels}}' harbor.sunmoonai.com:30443/app-images/relay@$D
docker inspect --format '{{.Created}}' harbor.sunmoonai.com:30443/app-images/relay@$D
docker run --rm --entrypoint sh harbor.sunmoonai.com:30443/app-images/relay@$D -c 'sha256sum /app/relay.py 2>/dev/null || find / -name relay.py -not -path "*/site-packages/*" 2>/dev/null | head -3'
sha256sum sunmoonai/relay-platform/relay/relay.py
```

## 五、回传里要有的

1. 第一节的整段输出，和那一句话的结论（开机恢复停在哪、为什么）。
2. `platform-start` 的退出码、用时；失败时的输出尾部和 journal。
3. 第三节的四个数量与对照；`platform-check` 的退出码和失败段（如果有）。
4. relay 镜像的标签、创建时间、两个 sha256。
5. 结论：通过 / 不通过 / 判断不了。
