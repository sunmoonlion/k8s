# 新体系：本地代理报到 → 「我的机器」自动登记（账 49）。重建会合点与 investment 后端，发布、晋级、应用（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s；另有 runtime 仓（本地代理）
跑：按编号步骤做（核对 → 两个镜像重建 → 暂存 → 发布晋级应用 → 检查 → 所有者重装本地代理并接入 → 看页面）
仓与提交：k8s 本条待办所在的 fable 头；investment-backend d3ff9046；runtime bdcdddd（agent 0.2.0）
预计：40 分钟；两次在线构建；investment 与会合点各滚动一次（会合点重启时在线的代理和沙箱会断开重连）
看什么：两个镜像构建退出 0；investment-runner 新 Pod 的日志里有 machine sync starting；会合点管理通道认 agents；
        所有者用 agent 0.2.0 接入后 10 秒内「我的机器」出现一台在线机器和它的白名单目录；关掉代理后 10 秒内变离线
前提：现网在 release-20261006-3（或续十二之后）上；不退回
回传：k8s/sunmoonai/scripts/results/machines-from-agent.<时间>.md
```

## 这一轮是什么

第 7 步点到「新建项目」时发现：本地代理连上会合点后，工作台后端不知道有这台机器（以前只能手工登记）。现在补上了，三处一起改：

| 处 | 改了什么 |
| --- | --- |
| 本地代理（runtime，agent 0.2.0） | 控制通道的 hello 带上机器名（默认主机名，`init --name` 可改）、白名单目录、上限 |
| 会合点（k8s `sunmoonai/relay-platform/relay`） | 记住在线代理报的机器信息；管理通道加 `{"type":"agents"}` 查询 |
| investment 后端 | runner 进程里每 10 秒问一次会合点谁在线：同名机器更新、没有就建、置在线；不在线的置离线；会合点问不到时什么都不改 |

配置上只动一处：investment 的 runner 也放行到会合点管理口（网络策略 `investment-relay-admin-out` 的角色从 api 变成 api、runner）。

## 一、核对

```bash
cd ~/worktrees/fable/k8s && git log --oneline -3 && git status --short | head -3
grep -n "revision: a43473f1" infrastructure/applications/component-images.yaml
grep -n "d3ff90468327" infrastructure/applications/sources.yaml
git -C ~/worktrees/fable/investment-app/investment-backend log --oneline -1    # 应是 d3ff904
git -C ~/worktrees/fable/runtime log --oneline -1                              # 应是 bdcdddd
```

## 二、重建两个镜像

```bash
make -C infrastructure platform-build OBJECT=relay-platform/relay; echo "exit=$?"
make -C infrastructure platform-build OBJECT=app-platform/investment-app/investment-backend; echo "exit=$?"
git status --short gitops | head
git diff gitops/components/relay-platform/relay/image.lock.yaml gitops/components/app-platform/investment-app/investment-backend/image.lock.yaml | grep -E '^[-+].*(digest|source_revision)'
```

要看到：两个退出 0；会合点锁的 source_revision 是 a43473f1…，investment 后端锁的 source_revision 是 d3ff9046…。
第二条如果说对象不认，改用 `OBJECT=app-platform/investment-app`（会连网页端一起重建，慢一些，结果一样）。

## 三、暂存

```bash
make -C infrastructure platform-stage OBJECT=relay-platform/relay; echo "exit=$?"
make -C infrastructure platform-stage OBJECT=app-platform/investment-app; echo "exit=$?"
git status --short gitops | head -30
git diff gitops/components/app-platform/investment-app/investment-backend/runtime/workload.yaml | grep -E '^[-+].*(investment-relay-admin-out|values: \[investment-|image: )' | head
```

要看到：两个退出 0；investment 的 workload 里镜像换新摘要、`investment-relay-admin-out` 的角色多了 `investment-runner`；身份 Job 的名字跟着新摘要变（这是对的）；没有 sops 文件只因重加密而变。

```bash
git add gitops && git -c core.editor=true commit -m "deploy: 会合点与 investment 后端——本地代理报到登记机器（待办 29）"
```

## 四、发布、晋级、应用

```bash
make -C infrastructure flux-release; echo "exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml; git rev-parse HEAD
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（待办 29：我的机器）"
make -C infrastructure flux-source-apply; echo "exit=$?"
make -C infrastructure flux-source-status; echo "exit=$?"
```

## 五、检查

```bash
K="kubectl --kubeconfig /home/zymun/.kube/sunmoon-kind.config"
$K -n app-platform-dev get pod | grep investment
$K -n relay-platform-dev get pod
$K -n app-platform-dev logs deploy/investment-runner --tail=40 2>&1 | grep -i "machine sync" | tail -3
make -C infrastructure application-check APP=investment 2>&1 | tail -n 6; echo "exit=${PIPESTATUS[0]}"
```

要看到：investment 四个进程和会合点都是新 Pod、Running；runner 日志里有 `machine sync starting`，**没有** `machine sync cannot reach the relay`；application-check 退出 0。

出现 `cannot reach the relay`：贴 `$K -n app-platform-dev get networkpolicy investment-relay-admin-out -o yaml | grep -A4 matchExpressions` 和 runner 日志最后 20 行，停下。

## 六、所有者：换新的本地代理并接入（WSL）

会合点重启后旧令牌仍然有效（公钥在 Secret 里），但之前那条令牌贴进过聊天，所以先在网页「设置」里点「换代理令牌」，拿新的接入命令。

```bash
cd ~/worktrees/fable/runtime && git log --oneline -1          # bdcdddd
cd agent && pnpm install && pnpm build && node dist/cli.js --version    # 0.2.0
export NODE_EXTRA_CA_CERTS=~/.sunmoon-agent/platform-ca.crt
node dist/cli.js init <新接入命令里 init 后面的全部参数> --root ~/research
node dist/cli.js start
```

启动日志第一行应有 `"machine":"wsl-dev"`（主机名）。想换显示的名字就在 init 里加 `--name 我的电脑`。

## 七、看页面（所有者）

1. 「我的机器」：10 秒内出现一台机器，在线，白名单目录 `/home/zymun/research`，上限「只能改白名单目录里的文件」「不许联网」。
2. 「项目」：不再是「还没有工作区」，能选这台机器的这个工作区新建项目。
3. 在代理窗口按 Ctrl+C：10 秒左右刷新「我的机器」，变离线，并有「本地代理没在运行」的提示。再 `start`，变回在线，还是同一台。

## 八、回传

每步退出码与用时；第二节两把锁的 diff；第三节 workload 的三行摘录；第五节 Pod 与 runner 日志摘录、检查结论；第七节三项各看到了什么（页面上的字）。结论：通过 / 不通过。

```bash
git add sunmoonai/scripts/results && git -c core.editor=true commit -m "test(local): 2026-10-06-29-machines-from-agent.md 结果"
```
