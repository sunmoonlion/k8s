# KIND：发版——runner 在沙箱重启后恢复 Codex 线程（本地机）

```text
被测仓：k8s，本地路径 ~/worktrees/fable/k8s（还要 investment-app）
跑：按下面编号步骤做（只换投资后端镜像，走 13 的第二段那套；网页、知识、本地代理都不动）
仓与提交：investment-app 3dbadad（子仓 investment-backend c89d8fe；investment-web-frontend 仍是 319258d，不动）；k8s 本条待办所在的 fable 头
预计：40 分钟；要 Docker、KIND、Harbor
看什么：第 6 步回收再拉起沙箱后，不重启 runner，回原会话发话能正常得到回答；时间线里没有 `thread not found`，也没有 `HTTP 401`；runner 日志里有一行 `thread resumed`
前提：无（KIND 现在是 13 发的版本：投资后端 `dfbe3d03…`、网页 `0e9263bd…`）
回传：k8s/sunmoonai/scripts/results/kind-release-14.<时间>.md（写下后在被测仓提交）
```

## 这次发的是什么（已在远程测过，KIND 里还没生效）

投资后端 c89d8fe，只有 runner 一处改动。13 的第 12 步查明：回收再拉起后沙箱是一个新的 Codex 进程，内存里没有线程，但线程的 rollout 还在持久卷上；runner 拿会话记的线程号直接发 turn/start，Codex 回 `thread not found`。现在 runner 记住"当前这条连接对面已经装载了哪些线程"，发 turn 前先 `thread/resume` 从盘上恢复；只有 rollout 真的没了（比如换过持久卷）才另起一条线程，并在时间线里记一条带 `replaced_thread_id` 的 `session/thread_started`。没有数据库迁移。

## 步骤

1. 身份准备沿用 `~/private/investment-identity-recovered-20260926`，不动 `development-input.json` 里的 `runtime_identity_upgrade`。
2. 只建后端镜像：`cd ~/worktrees/fable/k8s/sunmoonai/app-platform/scripts && CLUSTER=KIND APPS=investment COMPONENTS=backend SOURCE_ROOT=$HOME/worktrees/fable bash build-push-app-images.sh`，取新 digest。
3. 锁与输入：`~/worktrees/fable/investment-app/development-source-lock.json` 只改 backend 一段的 commit/tree（commit 应为 c89d8fe…），`task` 改 `thread-resume-kind-20260926`；web、admin 两段不动。`k8s/sunmoonai/app-platform/investment-app/deployment/development-input.json` 只换 `images.backend` 与锁的那一段；`migration_head` 仍是 `20260925_0011`。
4. 渲染到空目录（`--release-id kind-wb-20260926-r14`），diff 只应有：后端镜像 digest、backend 一段锁与注解、派生哈希、release id。别的变化就停，贴 diff。替换 bundle，跑门禁、单测、plan（同 13）。
5. 维护窗口：api、worker、scheduler、runner 四类都停（`--replicas=0`），等 Pod 全部消失；备份回执输出到新目录 `~/private/investment-wb-20260926-r14`；`server-dry-run`，再 `deploy --backup-receipt … --identity-preparation ~/private/investment-identity-recovered-20260926`。部署完 `drift`、`status`。记下发版后的 runner Pod 名与 RESTARTS，作为第 6 步的对照。
6. **主要验证（所有者在浏览器，同一个登录过的标签页；本地助手看日志）**：
   - 先在现有会话发一句话，确认发版后正常（这一步会话的线程是上次拉起时的，runner 重启后第一次发话也要走 resume；能回答就是 resume 通了）。
   - 设置页点「回收沙箱」，确认后状态变「已回收」；再点「拉起沙箱」，等状态变「运行中」。
   - 回到同一会话发「你好」。通过：回答正常出现；时间线里没有 `thread not found`、没有 `HTTP 401`。
   - 本地助手：`kubectl -n app-platform-dev logs deploy/investment-backend-runner --since=30m | grep -E "thread resumed|thread .* gone|thread not found|401"`。通过：有 `thread resumed`，没有后三种。要是出现 `gone on sandbox … starting a new one`，说明 rollout 没保住，把这段日志和 `kubectl -n sandbox-pool get pvc` 一起写进结果，本条按 fail 停。
   - 拉起前后各跑一次 `kubectl -n app-platform-dev get pods | grep investment-backend-runner`，两次 Pod 名一样、RESTARTS 没变；本地助手这期间**不要**重启 runner。
7. 回传：每步结果与屏幕上看到的；`drift`/`status`；过滤含 sk-、kmcp-、token=、password 的行。

失败停在那步。
