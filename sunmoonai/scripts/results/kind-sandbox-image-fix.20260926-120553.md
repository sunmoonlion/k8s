# KIND：沙箱镜像匿名卷修复，并发布 runner 兜底文案 — 2026-09-26

被测提交与待办一致：k8s `4283f53c`（fable），investment-app `db1d92c`（backend `6f45b33`，web 仍是 `319258d`）。发版前投资后端是 `4f639f78…`。网页、知识、本地代理没有动。demo 沙箱没有按新清单 apply。

结论：**pass**。第 6 步在 `kind-worker2` 的 hostPath 里直接看到了 rollout。第 7 步回收再拉起后同一文件还在并且变大，同一会话有回答，旧 runner 日志有 `thread resumed`。第 8 步只换了投资后端。第 9 步发「在吗」有回答，新 runner 日志又有一行 `thread resumed`。没有 `no rollout`，没有 `thread not found`，没有 `gone on sandbox`。没有写入口令、令牌或 key。

`development-input.json` 里嵌着同一份锁。为了让渲染结果带上 backend 锁（待办要求 diff 含 backend 锁），输入里的 backend commit/tree 和 `task` 与锁文件一起改了，`images` 只换了 backend。`migration_head` 与 `runtime_identity_upgrade` 未改。

## 1–3 沙箱镜像与供给器

- 镜像 `harbor.sunmoonai.com:30443/app-images/sandbox:0.155.1-r2`。`Config.Volumes` 是 `null`。
- `docker push` 后 `RepoDigests[0]` 是 `harbor.sunmoonai.com:30443/app-images/sandbox@sha256:dbafbcd4eba426fe2a8aa89545214a90b80ae38d508bf1bcee55dda7d41502af`（OCI index；其中 linux/amd64 清单是 `sha256:780a17876f460c4106ecaf2330cd2d6bf0305c10546bebe64bb1c6f66acdce09`）。引用用的是待办指定的 `RepoDigests[0]`。
- `provisioner.yaml` 的 `SANDBOX_IMAGE` 与 `demo-user.yaml` 的 `image` 都换成这个 digest。供给器已 apply 并 rollout 成功。供给器环境变量 `SANDBOX_IMAGE` 是新 digest。demo 未 apply。

## 4 清掉老 PVC 里的空目录

所有者看到「已回收」。Deployment 没了，PVC `sandbox-u-a63d03b16693-codex-home` 仍 Bound 在 `pvc-7fdb9035-f4d0-4471-9109-769a9edb9f2c`。hostPath 里的 `codex` 是空目录、root 属主、Sep 25 14:57。`rmdir` 成功。删完后该目录只剩 `.` 和 `..`。

## 5 新 Pod 不再盖匿名卷

所有者看到「运行中」。Pod `sandbox-u-a63d03b16693-6d77fc6df8-9ttwc`，1/1 Running，在 `kind-worker2`，镜像是 `sha256:dbafbcd4…`。`mountinfo` 里匹配 `/data` 的只有一条，挂载点是 `/data`，没有单独的 `/data/codex`。`/data/codex` 属主是 `codex`（uid 10001）。容器用户也是 uid 10001。没有 `not writable`。

## 6 持久卷上能看到 rollout

所有者新建会话发「你好」，Codex 回答「你好！👋 有什么可以帮你的吗？」。节点上：

```text
-rw------- 1 10001 10001 41610 Sep 26 03:57 .../codex/sessions/2026/09/26/rollout-2026-09-26T03-57-31-01a0dbdc-6e3c-75f0-b1b2-cc2817429ab0.jsonl
```

## 7 回收再拉起后文件还在

所有者回收再拉起，回到同一会话发「你好」，Codex 回答「你好！😊 又见面了～」。没有再做第 4 步。同一路径的文件变成 54069 字节，时间 Sep 26 03:59。新 Pod `sandbox-u-a63d03b16693-6c8fd966f4-ksb8f`，1/1 Running。当时 runner 仍是 14 的 `investment-backend-runner-77596b8695-4l7l6`。日志：

```text
2026-09-26 03:59:09 thread resumed sandbox=2cc3cb8b-6422-4e92-a5ae-97f135d3abac thread=01a0dbdc-6e3c-75f0-b1b2-cc2817429ab0
```

没有 `no rollout`，没有 `thread not found`，没有 `gone on sandbox`。

## 8 投资后端 `kind-wb-20260926-r15`

- 身份准备沿用 `/home/zymun/private/investment-identity-recovered-20260926`。`runtime_identity_upgrade` 未改。`migration_head` 仍是 `20260925_0011`。admin 与 web 的镜像和锁未动。
- 后端镜像 `harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:b5336cfbf2b4ef487525f8aa2b65a73af5b771cb1b7f59b6a14af986bd4266e3`。
- 锁只改了 backend：commit `6f45b332f3bf29709cae6f10c4cb7ad13817af82`、tree `07e662b90865759e7c7ab17dd1bbb2fa0246714b`，`task` `resume-text-kind-20260926`。web 仍是 `319258d6fe58…`，admin 仍是 `2e1f5c67…`。
- 渲染到空目录后的 diff 只涉及 `00`/`10`/`20`/`release.json`：后端 digest、backend 一段锁与注解（含 `source-commit`、`task`、tree）、派生哈希（含 config-sha256 与文件哈希）、release id。网页镜像、网络策略、ingress 未变。已替换 bundle，`.conf` 只换了 `RELEASE_ID` 与 `BACKEND_IMAGE`。
- 声明式门禁通过。同 13 的那组单测 34 条全部通过。只读 plan 通过，`contains_credentials=false`。
- 维护窗口把 api、worker、scheduler、runner 缩到 0，四类 Pod 都消失。停写前 runner 是 `investment-backend-runner-77596b8695-4l7l6`（14 的那个）。这是发版本身的重启。
- 回执 `/home/zymun/private/investment-wb-20260926-r15/cutover-receipt.json`（目录 0700，回执 0600）。两次恢复目录与行数都相等，迁移头 `20260925_0011`，`live_writes=false`。server-dry-run 通过。
- 部署一次通过。六个 Deployment rollout 成功。`database-upgrade-kind-wb-20260926-r15/complete.json` 为 `grants_only=true`。`drift=false`。`status` 的 `result` 是 `passed`，release id 是 `kind-wb-20260926-r15`。网页镜像仍是 `0e9263bd…`，admin 仍是 `422e7c1e…`。发版后的 runner：

```text
investment-backend-runner-7476d7d74f-z6thg   restarts=0   start=2026-09-26T04:03:59Z
```

## 9 发版后同一会话

所有者发「在吗」，Codex 回答「在的！😊 有什么需要帮忙的尽管说～」。新 runner 日志：

```text
2026-09-26 04:05:19 thread resumed sandbox=2cc3cb8b-6422-4e92-a5ae-97f135d3abac thread=01a0dbdc-6e3c-75f0-b1b2-cc2817429ab0
```

没有 `no rollout`，没有 `thread not found`，没有 `gone on sandbox`。核对时 runner 仍是 `investment-backend-runner-7476d7d74f-z6thg`，RESTARTS 仍是 0。本地助手在发版之后没有再重启 runner。

exit=0
