# KIND：诊断——沙箱持久卷是不是随 Pod 换了节点（本地机，只看不改）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按下面编号步骤做，全是只读命令，不发版、不改任何资源
仓与提交：k8s 本条待办所在的 fable 头；KIND 不用动
预计：10 分钟；要 KIND 与 docker（要进 kind 节点容器）
看什么：15 里写到盘上又"消失"的那个 rollout 文件（线程 01a0dbc1-e34d-7ed1-964a-172d1c030222）现在躺在哪个节点的哪个目录；卷有没有节点亲和；前后两个 Pod 是不是在不同节点
前提：无
回传：k8s/sunmoonai/scripts/results/kind-diag-pv-node.<时间>.md（写下后在被测仓提交）
```

## 背景

15 的结论是 B：文件写到了 `/data/codex/sessions`，回收再拉起后整个 `/data/codex` 里的东西都没了，但 `/data` 目录本身还是 9 月 25 日那份，PVC 与卷名也没变。供给器、入口脚本、沙箱桥里都没有删文件的动作。KIND 有三个节点，沙箱 PVC 用的是节点本地目录类型的存储（local-path），而 kind 配置里只有一个工作节点挂了宿主机目录 `/data/kind-local-storage`。所以最像的解释是：卷没有节点亲和，Pod 回收后重新拉起落到了另一个节点，那里是同名的另一份空目录。这条待办就是核实这一点。

## 步骤

```bash
export KUBECONFIG=~/.kube/kind-config
PV=pvc-7fdb9035-f4d0-4471-9109-769a9edb9f2c
```

1. 卷的定义（把输出整段贴进结果）：
   ```bash
   kubectl get pv $PV -o yaml | sed -n '/^spec:/,$p' | grep -v "^\s*resourceVersion\|uid:"
   kubectl get sc
   kubectl -n local-path-storage get cm local-path-config -o jsonpath='{.data.config\.json}'; echo
   ```
   要看的：`spec.hostPath.path`（或 `local.path`）是什么；有没有 `nodeAffinity`，指向哪个节点；`storageClassName`；local-path 的配置里有没有 `sharedFileSystemPath`。
2. 前后两个 Pod 在哪个节点：
   ```bash
   kubectl get nodes -o wide
   kubectl get pods -n sandbox-pool -o wide
   kubectl get events -n sandbox-pool --sort-by=.lastTimestamp | grep -E "Scheduled|sandbox-u-a63d03b16693" | tail -20
   ```
   要看的：现在的 Pod `sandbox-u-a63d03b16693-56c87f6b5-gq6fh` 在哪个节点；events 里 `bg8gp`（回收前）和 `gq6fh`（拉起后）各被调度到哪个节点。events 只留一小时，没有就写"已过期"。
3. 到每个 kind 节点容器里找那个文件（`<path>` 用第 1 步的 hostPath 路径）：
   ```bash
   for n in $(docker ps --format '{{.Names}}' | grep '^kind-'); do
     echo "== $n"
     docker exec $n sh -c 'ls -la <path> 2>&1 | head; find <path> -name "rollout-*.jsonl" 2>/dev/null'
   done
   ```
   要看的：哪个节点的目录里有 `rollout-2026-09-26T03-28-32-01a0dbc1-…jsonl`；哪个节点的目录是 03:31 新建的那份。
4. 顺手看一眼另一个用户卷是不是同样情况：`kubectl get pv $(kubectl get pvc -n sandbox-pool sandbox-demo-codex-home -o jsonpath='{.spec.volumeName}') -o jsonpath='{.spec.nodeAffinity}{"\n"}{.spec.hostPath.path}{"\n"}'`。

## 怎么判

- **卷没有 nodeAffinity，且第 3 步在另一个节点找到了 rollout**：坐实"换节点"。停下，远程定修法（沙箱 Deployment 固定节点，或让卷带亲和）。
- **卷有 nodeAffinity，两个 Pod 也在同一节点，文件却哪里都找不到**：那是有人删了，把第 1、3 步输出贴全，远程再查。
- **卷有 nodeAffinity 但 Pod 却在别的节点**：调度没尊重亲和，把第 1、2 步输出贴全。

不管哪种，都停在这里，不改任何东西。
