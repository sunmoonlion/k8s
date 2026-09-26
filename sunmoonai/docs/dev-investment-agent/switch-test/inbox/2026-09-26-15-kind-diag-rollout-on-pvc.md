# KIND：诊断——沙箱线程的 rollout 有没有写到持久卷上（本地机，只看不发版）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：按下面编号步骤做，全是只读检查加一次正常发话与一次回收拉起，不建镜像、不发版、不改产品代码
仓与提交：k8s 本条待办所在的 fable 头；KIND 现在是 14 发的版本（投资后端 `4f639f78…`），不用动
预计：20 分钟；要 KIND
看什么：第 3 步发话后 `/data/codex/sessions` 下有没有出现这条线程的 rollout 文件；第 5 步回收再拉起后这个文件还在不在。结果分三种，见末尾
前提：无
回传：k8s/sunmoonai/scripts/results/kind-diag-rollout.<时间>.md（写下后在被测仓提交）
```

## 背景

14 的第 6 步：回收再拉起后 `thread/resume` 报 `no rollout found for thread id …`，持久卷没换。远程在本机用同版 Codex 复现过：线程在第一句话发出后才把 rollout 写到 `$CODEX_HOME/sessions/日期/`，写了以后换进程按 id 恢复是通的，cwd 不存在也通。Codex 源码里按 id 查找没有别的过滤条件。所以要么沙箱里根本没写盘，要么写到了持久卷以外。这条待办就是把这一点看清楚。

## 步骤

沙箱 Deployment 名 `sandbox-u-a63d03b16693`，命名空间 `sandbox-pool`。下面的 `SB` 用它：

```bash
export KUBECONFIG=~/.kube/kind-config
SB="-n sandbox-pool deploy/sandbox-u-a63d03b16693"
```

1. 沙箱进程环境与目录（不会打印任何令牌）：
   ```bash
   kubectl exec $SB -- sh -c 'echo pid1=$(cat /proc/1/comm); tr "\0" "\n" </proc/1/environ | grep -E "^(CODEX_HOME|HOME|USER)="; id; codex --version; ls -la /data /data/codex; ls -laR /data/codex/sessions /data/codex/archived_sessions 2>&1 | head -60; ls -la /data/codex/*.sqlite* /data/codex/thread-writer-locks 2>&1 | head -30; df -h /data | tail -1; mount | grep " /data "'
   ```
   写进结果：PID 1 是不是 `codex`；`CODEX_HOME` 是不是 `/data/codex`；sessions 目录里现在有哪些文件；`/data` 是不是挂的 PVC。
2. 记下当前时间，作为第 3 步"新文件"的分界：`date -u +%FT%TZ`。
3. **所有者**：网页新建一个会话（this-pc、sandbox-u-a63d03b16693），发一句「你好」，等回答出现。然后本地助手：
   ```bash
   kubectl exec $SB -- sh -c 'find /data/codex -newer /data/codex/config.toml -type f 2>/dev/null | grep -v "\.sqlite" | head; find / -xdev -name "rollout-*.jsonl" -newer /data/codex/config.toml 2>/dev/null | head'
   kubectl logs $SB --since=10m | grep -iE "materialize|rollout|persist|permission|denied|read-only|no space" | head -20
   ```
   写进结果：这条线程的 rollout 文件出现在哪个路径（应是 `/data/codex/sessions/2026/09/26/rollout-…-<线程号>.jsonl`）；如果不在 `/data` 下而在别处，把路径写清；日志里有没有 `failed to materialize thread persistence` 一类的行。线程号在会话时间线的「Codex 会话已建立」条目里，或用 runner 日志 `grep "thread/start\|thread_started"`。
4. 再发一句「谢谢」，等回答。再跑一次第 3 步的 find，看文件有没有变大（`ls -la` 同一路径两次对比）。
5. **所有者**：设置页回收沙箱，等「已回收」；再拉起，等「运行中」。本地助手在新 Pod 里：
   ```bash
   kubectl get pods -n sandbox-pool -l user=u-a63d03b16693 -o wide
   kubectl get pvc -n sandbox-pool
   kubectl exec $SB -- sh -c 'ls -laR /data/codex/sessions 2>&1 | head -40; ls -la /data/codex/thread-writer-locks 2>&1 | head'
   ```
   写进结果：第 3 步那个文件还在不在；PVC 名与卷名是否和回收前一致。
6. **所有者**：回同一会话发「你好」。本地助手看 runner：`kubectl -n app-platform-dev logs deploy/investment-backend-runner --since=15m | grep -E "thread resumed|no rollout|thread not found|gone on sandbox"`。写进结果。

## 三种结果怎么判

- **A. 第 3 步文件在 `/data/codex/sessions` 下，第 5 步文件还在，第 6 步却报 `no rollout found`**：文件在、找不到，是查找那一侧的问题，把第 1 步和第 5 步的完整 `ls -laR` 贴全（含权限与属主），远程去对源码。
- **B. 第 3 步文件在，第 5 步没了**：回收流程把持久卷上的东西弄丢了，把第 5 步的 PVC/卷名对比和 Pod 的 volumeMounts（`kubectl get pod <名> -n sandbox-pool -o jsonpath='{.spec.volumes}{"\n"}{.spec.containers[0].volumeMounts}'`）贴全。
- **C. 第 3 步就没有文件（或文件不在 `/data` 下）**：沙箱里根本没写到持久卷，把第 1 步的环境变量、第 3 步的两个 find 输出和日志贴全。

不管哪种，都停在这里，不改任何东西。
