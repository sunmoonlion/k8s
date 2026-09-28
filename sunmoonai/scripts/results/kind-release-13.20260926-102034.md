# KIND release 13 — 2026-09-26

被测提交与待办一致：investment-app `3390156`（backend `23d321b`、web `319258d`）、knowledge-app `6a48507`（backend `dd68e6d`）、runtime `5645e63`、k8s `7c14b9d5`。前提里的现网镜像也一致（投资后端 `ab1288a4…`、网页 `3be96b51…`、知识后端 `67028600…`）。

结论：第 4 步 pass，第 11 步 pass，第 12 步 fail。回收再拉起后 runner 没有重启，时间线里也没有 HTTP 401，但发话没有正常出现回答，报的是 `thread not found`。没有写入口令、令牌或 key。

## 1–4 知识后端 `know-0926-metric`

- 身份准备沿用 `/home/zymun/private/knowledge-identity-recovered-20260925`，`runtime_identity_upgrade` 未改。`migration_head` 仍是 `20260911_0006`。
- 镜像 `harbor.sunmoonai.com:30443/app-images/knowledge-backend@sha256:01b694bb1ada41bbcbaf3ac76c85914827c74219fe6d3ce7ce77e84f26b17b61`。
- 锁只改了 knowledge-backend：commit `dd68e6d9042768b2362b3f757bf545529c7eef25`、tree `3056e57e66231fc2caf0aae6df3daf2e5e19ddaf`、`remote_branch` `origin/fable`，`task` `knowledge-metric-kind-20260926`。admin、web 两段未动。
- 渲染到空目录后的 diff 只有：backend digest、这一段锁与注解、派生哈希（含 config-sha256 与 release.json 的文件哈希）、release id。网络策略与 ingress 未变。已替换 bundle，`.conf` 的 `RELEASE_ID` 与 `BACKEND_IMAGE` 同步更换。
- 声明式门禁通过。单测 37 条里 36 条通过；`test_committed_development_candidates` 的 investment 子项报 `source checkout does not match the development lock`。这是当时投资锁还停在上一版，与 08 记录的同一类情况。知识包能按输入原样重渲染。投资锁更新后，投资段的同一组单测 34 条全部通过，其中包含三个 App 的 committed candidate。
- 只读 plan 通过。api、worker、scheduler 缩到 0，Pod 消失后做备份回执：`/home/zymun/private/knowledge-0926-metric/cutover-receipt.json`（目录 0700，回执 0600）。两次恢复目录与行数都相等，迁移头 `20260911_0006`，现场库未写。server-dry-run 通过。
- 部署一次通过。迁移 Job 完成并已删除。五个 Deployment rollout 成功。`database-upgrade-know-0926-metric/complete.json` 为 `grants_only=true`。之后 `drift=false`。api/worker/scheduler 镜像已是上面的 digest。

### 第 4 步 metric_definitions

原命令对 `http://127.0.0.1:8000` 发请求，返回 HTTP 400，正文是 `Invalid host header`。集群 `ALLOWED_HOSTS` 不含 `127.0.0.1`。这是检查方式不对，通过标准没改。

改后的命令：同一 URL、同一 JSON body、同一令牌文件，请求头增加 `Host: knowledge-backend`。

结果 HTTP 200。`metric_name` 为 `net_revenue_cents`，`display_name` 为「净营收」，`data_version` 为 `lesson23-analysis-b7ad59fddab30331`。不是空列表。令牌有效，不需要改到第 11 步用 DATA_QUERY 补验。

## 5–9 投资后端 + 网页 `kind-wb-20260926-r13`

- 身份准备沿用 `/home/zymun/private/investment-identity-recovered-20260926`，`runtime_identity_upgrade` 未改。`migration_head` 仍是 `20260925_0011`。admin 镜像与锁未动。
- 后端镜像 `sha256:dfbe3d0331ee230fe5b23a258d76490e79cdf2baf4e934613911e523b03e947f`。
- 网页镜像 `sha256:0e9263bd7da9810fa7268891e51b86f91b8a962798dab56497daec7df70dedcd`。
- 锁：backend commit `23d321b9b1ed38394b355b33c6001c9f8c7d38e2`、tree `69c04ba144a33a76b861a9ea644578e095792de7`；web commit `319258d6fe58a731e1405688668aa1d2b8241189`、tree `9ea308431944c7ecfbe1334e3c675f44fa2ebbdd`；`task` `runner-token-kind-20260926`。admin 仍是 `2e1f5c67…`。
- diff 只涉及 `00`/`10`/`20`/`release.json`：两个镜像 digest、backend 与 web 两段锁及注解、派生哈希、release id。网络策略与 ingress 未变。门禁通过。上一段所说的 34 条单测通过。plan 通过。
- 维护窗口把 api、worker、scheduler、runner 缩到 0，四类 Pod 都消失。停写前 runner 是 `investment-backend-runner-5bbb59f4ff-5d7jp`（Running，RESTARTS 0）。这是发版本身的重启，不是第 12 步要避免的那次。
- 回执 `/home/zymun/private/investment-wb-20260926-r13/cutover-receipt.json`（目录 0700，回执 0600）。两次恢复目录与行数都相等，迁移头 `20260925_0011`。server-dry-run 通过。
- 部署一次通过。六个 Deployment rollout 成功，含 runner。`database-upgrade-kind-wb-20260926-r13/complete.json` 为 `grants_only=true`。`drift=false`。六个 Deployment 都是 READY。发版后的 runner 基线：

```text
investment-backend-runner-6b888b474b-p8sxp   1/1   Running   0
```

第 12 步回收再拉起期间，要以这个 Pod 名和 RESTARTS 0 为对照，本地不重启 runner。

## 10 本地代理

- `node node_modules/typescript/bin/tsc -p tsconfig.json` 退出码 0。runtime 工作区没有新增改动。
- 停掉当时唯一的 kind2 进程（家目录 `/home/zymun/.sunmoon-agent-kind2`，旧 PID 3606403），没有重新 init。第一次用普通后台启动，父 shell 退出后进程被带走，会合点记了一次 `agent down`。随后用 `setsid` 再启动一次。
- 现在 kind2 PID 368958，`status.json` 里 relay `connected`。会合点有一次 `agent up user=u-a63d03b16693`。另有一个 demo 代理（PID 450664，家目录 `~/.sunmoon-agent-kind`），不是这个用户。kind2 只有这一个进程。

## 11 浏览器措辞：pass

所有者在已登录标签页里问专家 SMOKE（问题「你好」）。屏幕上：

- 右下按钮是「交给专家」。
- 时间线有「#7 · 交给专家」，随后委托状态自行出现，直到「#206 · 专家已交回 (SUCCEEDED)」。
- 委托卡状态 SUCCEEDED，2 步，预算 0.306940 / 5 CNY。
- 这几张截图里没有「方向盘」。

## 12 回收再拉起后发话：fail

所有者接着在设置页回收，再拉起。屏幕上：

- 回收后徽标是「还没有沙箱」，按钮是「拉起沙箱」，绿字：「已回收：沙箱已停下，研究记录保留。需要时点「拉起沙箱」恢复，不会给新的接入命令。」
- 拉起后徽标是「运行中」，绿字：「已恢复：沙箱正在启动，之前的研究记录都在。本地代理不用重新接入，开着就行。」
- 回到同一会话发「你好」。时间线「#207 · 你 / 你好」下面是「#208 · 命令失败」：`AppServerError: turn/start: thread not found: 01a0db8d-4b09-7693-be3b-e1569b7f2d25`。没有正常回答。
- 时间线里没有 `InvalidStatus … HTTP 401`。runner 近 25 分钟日志里与此相关的只有这一条 `thread not found`，没有 401。

runner 对照（发版后基线，到这次检查为止没有重启）：

```text
investment-backend-runner-6b888b474b-p8sxp   1/1   Running   0   start=2026-09-26T02:15:39Z
```

Pod 名与发版后的基线相同，RESTARTS 仍是 0。本地助手在这期间没有重启 runner。kind2 仍是 PID 368958，relay `connected`。

投资与知识的 `drift` 这时都是 false。

按待办的通过标准（回答正常出现，且没有 HTTP 401），第 12 步 fail。401 没有复现；失败停在发话这一步，没有改产品代码。
