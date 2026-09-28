# KIND release 14 — 2026-09-26

被测提交与待办一致：investment-app `3dbadad`（backend `c89d8fe`、web 仍是 `319258d`）、k8s `c5f8fbf0`。发版前现网镜像与前提一致：投资后端 `dfbe3d03…`、网页 `0e9263bd…`。网页、知识、本地代理没有动。

结论：第 6 步 fail。发版后第一句有回答，但 runner 日志里没有 `thread resumed`。回收再拉起后发「你好」没有回答，报 `thread/resume: no rollout found`。没有 `thread not found`，没有 `HTTP 401`，也没有 `gone on sandbox … starting a new one`。runner 没有重启。没有写入口令、令牌或 key。

## 1–5 投资后端 `kind-wb-20260926-r14`

- 身份准备沿用 `/home/zymun/private/investment-identity-recovered-20260926`，`runtime_identity_upgrade` 未改。`migration_head` 仍是 `20260925_0011`。admin 与 web 的镜像和锁未动。
- 后端镜像 `harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:4f639f78faea51306ddb2f495b8921763906a2ceb1cbdeb453b43bc2a2fe8710`。
- 锁只改了 backend：commit `c89d8fe7491952d0dffd32ecebd4e5adc4042ab3`、tree `eb310486799081fcf766e6ebf4cf088de36bef99`，`task` `thread-resume-kind-20260926`。web 仍是 `319258d6fe58…`，admin 仍是 `2e1f5c67…`。
- 渲染到空目录后的 diff 只涉及 `00`/`10`/`20`/`release.json`：后端 digest、backend 一段锁与注解、派生哈希（含 config-sha256 与文件哈希）、release id。网页镜像、网络策略、ingress 未变。已替换 bundle，`.conf` 只换了 `RELEASE_ID` 与 `BACKEND_IMAGE`。
- 声明式门禁通过。同 13 的那组单测 34 条全部通过。只读 plan 通过。
- 维护窗口把 api、worker、scheduler、runner 缩到 0，四类 Pod 都消失。停写前 runner 是 `investment-backend-runner-6b888b474b-p8sxp`（13 的那个）。这是发版本身的重启。
- 回执 `/home/zymun/private/investment-wb-20260926-r14/cutover-receipt.json`（目录 0700，回执 0600）。两次恢复目录与行数都相等，迁移头 `20260925_0011`，现场库未写。server-dry-run 通过。
- 部署一次通过。六个 Deployment rollout 成功。`database-upgrade-kind-wb-20260926-r14/complete.json` 为 `grants_only=true`。`drift=false`。网页镜像仍是 `0e9263bd…`。发版后的 runner 基线：

```text
investment-backend-runner-77596b8695-4l7l6   1/1   Running   0   start=2026-09-26T03:07:03Z
```

第 6 步回收再拉起期间，以这个 Pod 名和 RESTARTS 0 为对照。本地助手不重启 runner。

## 6 浏览器：fail

所有者发了两句「你好」。时间线从上到下是：

- 「#2 · Codex 会话已建立」
- 「#6 · 你 / 你好」，随后「#74 · Codex」给出了完整回答（「你好！我是 Codex…」）。
- 「#78 · 你 / 你好」，随后「#79 · 命令失败」：`AppServerError: thread/resume: no rollout found for thread id 01a0dbaf-821d-70b3-91d1-e609ea3236d2`。没有正常回答。
- 时间线里没有 `thread not found`，没有 `HTTP 401`。

runner 日志（过滤后）只有这三行相关内容：

```text
2026-09-26 03:08:27 sandbox link up sandbox=2cc3cb8b-6422-4e92-a5ae-97f135d3abac
2026-09-26 03:09:44 sandbox link up sandbox=2cc3cb8b-6422-4e92-a5ae-97f135d3abac
2026-09-26 03:09:44 command failed kind=turn.start
    thread/resume: no rollout found for thread id 01a0dbaf-821d-70b3-91d1-e609ea3236d2
```

没有 `thread resumed`，没有 `thread not found`，没有 `401`，没有 `gone on sandbox … starting a new one`。第一句能回答，但日志对不上「这一步也要走 resume」的那一行。第二句是在沙箱 Pod 换新之后：`sandbox-u-a63d03b16693-65476d4dc9-bg8gp` 启动于 `2026-09-26T03:09:11Z`，失败在 `03:09:44`。

持久卷还在，没有换成新卷：

```text
sandbox-u-a63d03b16693-codex-home   Bound   pvc-7fdb9035-f4d0-4471-9109-769a9edb9f2c   2Gi   12h
sandbox-demo-codex-home             Bound   pvc-9e5b113e-0b82-4558-b953-6f165db84728   2Gi   25h
```

runner 对照，Pod 名与发版后基线相同，RESTARTS 仍是 0：

```text
investment-backend-runner-77596b8695-4l7l6   1/1   Running   0   start=2026-09-26T03:07:03Z
```

本地助手没有重启 runner。投资 `drift` 在部署后是 false。

按待办（要有 `thread resumed`，回收后再发话要有正常回答），第 6 步 fail。失败停在这里，没有改产品代码。
