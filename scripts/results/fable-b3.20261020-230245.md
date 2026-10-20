# fable-b3 第三版回执（luna，WS=fable）

执行日期：2026-10-20，Asia/Shanghai。被测基线 `62d44f99e0d7fb295aebe7a6e3c32c5f7ac08482`。任务卡 `2026-10-20-fable-b3-release-to-plan-v3.md`；本次从该版卡第一节只读核对开始，没有重做前两版已通过的控制器部署。

结论：**流水线执行 pass；整卡验收 undecidable**。本次唯一一次触发的 `release #2` 为 **SUCCESS**，Make `exit=0`，七个业务阶段全部进入，秘密样子检查 `total=0`，代理 k8s 工作区恢复干净。与卡预期不同的是：三个镜像重新构建、发布后都得到已提交的摘要，锁的内容没变，故 `3-image-locks.txt` **0 字节**，没有“变化 3 个锁”。这是验收预期的裁量，已写 `inbox/fable/2026-10-20-fable-b3-v3-idempotent-locks.md`，没有自行改判据。第四节所有者浏览器走查待做（卡注明“不急”）。

## 一、核对与拉取

`git status --short` 起始为空，分支 `fable`；`git pull --ff-only origin fable` 从 `b47a07ed` 快进到上述基线，退出 0。`ci/release.groovy` 的 `2-align/align-sources` 与 `agent.yaml` 的 `jenkins_run_timeout_seconds | int` 均命中。

命令与原始输出：

| 命令 | 结果 / exit | 原始文件 |
| --- | --- | --- |
| `make -C infrastructure jenkins-status` | 0；active/running/enabled，NRestarts=0 | `fable-b3.20261020-230245.01-preflight.txt` |
| `make -C infrastructure jenkins-agent-status` | 0；节点在线，active/running/enabled，User=zymun，NRestarts=0 | 同上 |
| 卡给的 sudo 构建、队列、首启脚本只读检查 | 0；起初 render-check #29 正在运行，队列空；脚本共 8 个（4 个旧名 + 4 个 .override） | 同上 |
| sudo Python 只读轮询 build.xml 与 queue.xml，每 15 秒一次 | 0；23:00:31 开始，23:02:31 检出无进行中构建且队列空 | `fable-b3.20261020-230245.02-wait-idle.txt` |

等待期间没有停任务、改定时器或重装控制器。数据盘只读 `df -h /mnt/sunmoon-data`：可用 196 GiB。

## 二、release 试跑

实际命令（外层 Bash pipefail + tee 保留原始退出码）：

```bash
make -C infrastructure jenkins-release-run APPS="tpl" PIN=keep NOTE="B3 试跑 tpl 到计划为止"
```

原始输出 `fable-b3.20261020-230245.03-release-attempt1.txt`，`exit=0`。只触发一次；等待任务里的 RETRYING 是轮询同一次构建，并没有重复触发。

`Report the build result`：

```text
build: 2
name: #2 fable@62d44f99e0 tpl
result: SUCCESS
seconds: 171
description: B3 试跑 tpl 到计划为止 — 到第 5 阶段为止（B3）；gitops 变更 2 个文件，未提交
```

控制器元数据 `duration=171186` 毫秒，`timestamp=1792508573970`。完整 consoleText 保留在本机忽略目录 `infrastructure/.build/jenkins/release-2.log`，不提交整份控制台。

按卡第二节提取的原文（共 11 行，未补造到 16 行）：

```text
13:[Pipeline] { (ci/release.groovy)
21:[Pipeline] { (1 核对)
13703:[Pipeline] { (2 改钉)
13710:tpl: parent 65b8b11d3c backend ab7139389c web 479c7e6ce6 admin b89e474191
13834:[Pipeline] { (3 构建)
14914:[Pipeline] { (4 暂存)
16075:[Pipeline] { (5 计划)
16202:[Pipeline] { (秘密样子核查与产物)
16205:total=0
16211:[Pipeline] { (工作区回到干净)
16223:Finished: SUCCESS
```

## 三、产物与收尾

按卡读取指定构建 #2 的产物（明确指定本次编号，避免按最新文件误拿别的构建）。原始输出 `fable-b3.20261020-230245.04-artifacts.txt`，`exit=0`。

目录 `/mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/.build/release/2/` 共 11 个文件：

```text
1-platform-status.log
2-align.log
2-plan-tpl.log
2-sources.diff
3-build-tpl.log
3-image-locks.txt
4-gitops-touched.txt
4-gitops.stat
4-stage-tpl.log
4-workload.diff
5-plan-tpl.log
```

`2-sources.diff`：0 行。

`2-align.log`：

```text
tpl: parent 65b8b11d3c backend ab7139389c web 479c7e6ce6 admin b89e474191
```

`3-image-locks.txt`：空，0 字节。只读补核的原始输出在 `fable-b3.20261020-230245.05-build-lock-evidence.txt`，`exit=0`。`3-build-tpl.log` 三条原文为：

```text
385:/mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/../gitops/components/app-platform/tpl-app/tpl-backend/image.lock.yaml: 已是这一份（sha256:395b14bed28e）
725:/mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/../gitops/components/app-platform/tpl-app/tpl-web-frontend/image.lock.yaml: 已是这一份（sha256:a7cf0f3844d1）
1065:/mnt/sunmoon-data/jenkins/repos/k8s/infrastructure/../gitops/components/app-platform/tpl-app/tpl-admin-frontend/image.lock.yaml: 已是这一份（sha256:f2e8ca667609）
```

三个代理仓锁逐字节等于基线提交中的锁，`source_revision` 分别对应钉住的子仓提交：

| 镜像 | digest | source_revision |
| --- | --- | --- |
| tpl-backend | `sha256:395b14bed28e4f728959310a83d74dafc45f100a592d04d85114cc44250d893f` | `ab7139389cbc40a04459a3403ffc5ee4c8e26d89` |
| tpl-web-frontend | `sha256:a7cf0f3844d1dfc792dec6957d06bfb643fe454a91cc42ba35ba5fb3d1ef9e27` | `479c7e6ce6e69a5e4daf41bb55aed5f3b95a87c7` |
| tpl-admin-frontend | `sha256:f2e8ca667609c0a91e5a9f974d47e1a9550cff5c84520a1fbb07bee5ee6a3880` | `b89e474191109d807cdd50d56ecea971c0269a4a` |

`4-gitops-touched.txt`：

```text
      1 components/app-platform/tpl-app/tpl-admin-frontend
      1 components/app-platform/tpl-app/tpl-web-frontend
```

`4-gitops.stat`：

```text
 .../components/app-platform/tpl-app/tpl-admin-frontend/workload.yaml  | 4 ++++
 gitops/components/app-platform/tpl-app/tpl-web-frontend/workload.yaml | 4 ++++
 2 files changed, 8 insertions(+)
```

`4-workload.diff` 共 12 行，全部如下；仅两个 ingress 的 `/api/internal` 规则，没有 DEPLOYMENT_ID 或 Job 名变化：

```diff
+++ b/gitops/components/app-platform/tpl-app/tpl-admin-frontend/workload.yaml
@@ -79,6 +79,10 @@ spec:
+          # 内部接口不经公网：转给前端，前端没有这个页面，回 404（审读第 1 条；后端另按地址拦）
+          - path: /api/internal
+            pathType: Prefix
+            backend: {service: {name: tpl-admin, port: {number: 3000}}}
+++ b/gitops/components/app-platform/tpl-app/tpl-web-frontend/workload.yaml
@@ -79,6 +79,10 @@ spec:
+          # 内部接口不经公网：转给前端，前端没有这个页面，回 404（审读第 1 条；后端另按地址拦）
+          - path: /api/internal
+            pathType: Prefix
+            backend: {service: {name: tpl-web, port: {number: 3000}}}
```

`git -C /mnt/sunmoon-data/jenkins/repos/k8s status --short --untracked-files=no` 输出为空，`clean-check-done` 前为空。该仓 HEAD 为本次基线。未手改代理仓。

补核控制器归档目录 `home/jobs/release/builds/2/archive/infrastructure/.build/release/2/`：11 个文件齐全，逐个 SHA-256 比较与代理候选目录相同，见 `.05-build-lock-evidence.txt`。这是本机文件证据；没有代替所有者在浏览器登录或点击。

## 四、所有者走查与盲区

所有者方便时打开内网 Jenkins 的 `release #2`：确认历史 SUCCESS、Build Artifacts 可打开、Stage View 七列全绿。本次未代点，GUI 结论待所有者提供。

平台状态只通过本次原生流水线第一阶段的 platform-status 和起始两项 status 核对；没有执行集群发布或晋级，也没有另跑应用走查。流水线 `total=0` 是其已知秘密格式的检查结果，不代表任意秘密都已排除。

## 五、就地修了什么

**没有。** 本次没有代码改动或修复提交，也没有修改“怎样算通过”。第三版的两处远程修复已由本次成功实跑覆盖。

## 六、交回

技术执行已到本卡末尾；验收预期差异交远程 Fable 审定，GUI 待所有者走查。回执、5 份执行原始输出、给远程的审定请求和卡的归档已在 `ffd8ff91` 提交并推至 GitHub、Gitee 的 `origin/fable`，推送退出 0。推送原文另存 `fable-b3.20261020-230245.06-push.txt`，随本次补充提交交回。不改其它工位分支。

exit=0
