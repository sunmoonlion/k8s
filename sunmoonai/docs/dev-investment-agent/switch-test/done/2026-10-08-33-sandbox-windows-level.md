# 新体系：重建沙箱镜像（编排端加 Windows 沙箱级别），发布晋级应用，重拉所有者的沙箱（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s
跑：构建沙箱镜像 → 暂存供给器 → 提交 → 发布晋级应用 → 所有者在网页回收并重新拉起沙箱 → 检查
预计：20 分钟；一次沙箱镜像构建（apt/pip/npm 都有缓存，比第一次快）；供给器 Pod 滚动一次；所有者的沙箱 Pod 重建一次（研究记录保留）
看什么：构建退出 0，sandbox 锁的 source_revision 等于 component-images.yaml 钉的提交；供给器 workload 只有 SANDBOX_IMAGE 一行变；flux-source-apply 退出 0；重拉后的沙箱 Pod 里 /data/codex/config.toml 有 [windows] 段
前提：platform-status 退出 0；Harbor 在；工作区干净
回传：k8s/sunmoonai/scripts/results/sandbox-windows-level.<时间>.md
```

## 这一轮是什么

Windows 本地代理第 1 段联调查出：编排端（沙箱里的 app-server）按自己配置里的 `[windows] sandbox` 决定发给 Windows 执行器的内层沙箱级别，不配就是 disabled，于是在 Windows 环境上一条命令都不发。入口脚本已加这一项（账 62），要重建沙箱镜像并让所有者的沙箱用上新镜像。对 Linux 执行器没有影响。

## 一、核对与构建

```bash
cd ~/worktrees/fable/k8s && git log --oneline -1 && git status --short | head -3
grep -n "windows" sunmoonai/sandbox-platform/image/entrypoint.sh
grep -n "sandbox:" -A14 infrastructure/applications/component-images.yaml | grep -E "revision|^[0-9]+-  sandbox"
make -C infrastructure platform-status; echo "exit=$?"
make -C infrastructure platform-build OBJECT=sandbox-platform/sandbox 2>&1 | tail -n 8; echo "exit=${PIPESTATUS[0]}"
grep -vE '^#' gitops/components/sandbox-platform/sandbox/image.lock.yaml
```

要看到：锁的 `source_revision` 等于清单钉的提交，`digest` 是新的。

## 二、暂存供给器、提交

```bash
make -C infrastructure platform-stage OBJECT=sandbox-platform/provisioner; echo "exit=$?"
git diff gitops/components/sandbox-platform | grep '^[-+]' | grep -vE '^(\+\+\+|---)' | head -12
git add gitops/components/sandbox-platform && git -c core.editor=true commit -m "deploy(sandbox): 沙箱镜像加 Windows 沙箱级别（待办 33，账 62）"
```

要看到：差异只有 `sandbox/image.lock.yaml` 和供给器 `workload.yaml` 的 `SANDBOX_IMAGE` 一行（供给器自己的镜像不变，`sandbox_provisioner_input_digest` 变了会带动它滚动，这是预期）。

## 三、发布、晋级、应用

照待办 32 第五节的命令，提交消息写「待办 33：沙箱 Windows 级别」。

## 四、重拉沙箱（所有者在网页做）

网页「设置 → 沙箱」：先「回收沙箱」，再「拉起沙箱」（研究记录保留，令牌不变，不会给新的接入命令）。然后：

```bash
K="kubectl --kubeconfig /home/zymun/.kube/sunmoon-kind.config"
NS=$($K get pod -A --no-headers | awk '$2 ~ /^sandbox-/{print $1; exit}'); echo "NS=$NS"
$K -n "$NS" get pod -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase --no-headers | grep -v provisioner
P=$($K -n "$NS" get pod --no-headers | awk '$1 ~ /^sandbox-/ && $1 !~ /provisioner/{print $1; exit}')
$K -n "$NS" exec "$P" -- sh -c 'grep -n -A1 "^\[windows\]" /data/codex/config.toml'
make -C infrastructure platform-check OBJECT=sandbox-platform/provisioner 2>&1 | tail -n 8; echo "exit=${PIPESTATUS[0]}"
```

要看到：沙箱 Pod 的镜像摘要是新的；`config.toml` 里有 `[windows]` 和 `sandbox = "unelevated"`；检查退出 0。

## 五、回传并本地提交

照常：每步退出码、锁的两行、差异摘录、候选整份、第四节三条输出。文件名 `sandbox-windows-level.<时间>.md`。
