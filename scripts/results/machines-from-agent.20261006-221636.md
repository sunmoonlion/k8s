# 待办 29 回传：本地代理报到 → 「我的机器」自动登记

时间：2026-10-06 22:16。没有退回。第六、七节（换代理令牌、看页面）没做。

## 一、核对

头是 `188a174c`，工作区干净。`component-images.yaml` 第 10 行 `revision: a43473f1…`。`sources.yaml` 第 31–32 行 `d3ff90468327…`。investment-backend 头 `d3ff904`，runtime 头 `bdcdddd`。

## 二、重建两个镜像

会合点构建退出 0，26 秒。investment 后端构建退出 0，33 秒。锁的差异：

```text
investment  digest: sha256:86a20079… → sha256:e9d7ddde9d7f90be7f71ec6114e6b41ff284fd662194c46ec4cecebad4a49cbc
            source_revision: a49577a4… → d3ff90468327e32f4157f4bb3271c890fe6e3842
会合点      digest: sha256:5224cf4f… → sha256:531d417826292336c034c7378fcb7347799a6e54e0a48e9b08fdb36757c1afc2
            source_revision: b23ea80b… → a43473f162195a7be7202ec382b0b13b16985b6f
```

## 三、暂存

会合点暂存退出 0，25 秒。investment 暂存退出 0，68 秒。没有 sops 变化。workload 摘录：

- 四个进程镜像换成 `investment-backend@sha256:e9d7ddde…`
- `investment-relay-admin-out` 的角色从 `[investment-api]` 变成 `[investment-api, investment-runner]`
- 身份 Job 名从 `investment-service-identity-86a20079c309-v1` 换成 `investment-service-identity-e9d7ddde9d7f-v1`

会合点镜像换成 `relay@sha256:531d4178…`。提交 `357a2ff4`。

## 四、发布、晋级、应用

`flux-release` 退出 0，27 秒。候选：

```yaml
digest: sha256:9c808c724167d7850991ef348f49039cdc3213b7af64c99350c9789b60c20b86
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: 357a2ff41c1b08f04e55833a9994a59a61845edc
```

diff 只有 digest 和 revision。提交 `7bdb1be0`。`flux-source-apply` 退出 0，224 秒。`flux-source-status` 退出 0，3 秒。

## 五、检查

investment 新进程都是 1/1 Running（当时约 50 秒）：`investment-api-55f4bd7dfd-df4wf`、`investment-runner-76ff879d4f-l8s8g`、`investment-scheduler-7f6867dfbf-krnqj`、`investment-worker-6dc8c57c6d-6ccdh`。新身份 Job `investment-service-identity-e9d7ddde9d7f-v1-cdxz4` 与迁移 Job `investment-migrate-e9d7ddde9d7f-v3-x4zq2` 都是 Completed。会合点 `relay-6f5994f8d7-v55l2` 1/1 Running。

runner 日志：`machine sync starting interval=10.0s`。最后 80 行里 `cannot reach the relay` 出现 0 次。`application-check APP=investment` 退出 0，23 秒。

## 乙、六个入口探测与 platform-check

```text
500 application/json  <- aistor.sunmoonai.com/api/v1/login
{"code":500,"detailedMessage":"unable to login due to network error","message":"an error occurred, please try again"}
200 text/html  <- aistor.sunmoonai.com/
302 text/html; charset=utf-8  <- pgadmin.sunmoonai.com/
200 text/html; charset=utf-8  <- pgadmin.sunmoonai.com/misc/ping
PING
200 text/html; charset=utf-8  <- redisinsight.sunmoonai.com/
401 text/html; charset=UTF-8  <- flower.sunmoonai.com/
Access denied
200 text/plain; charset=utf-8  <- relay.sunmoonai.com/healthz
{"ok": true, "relay": "edge-1", "proto": 1, "agents": 0, "paired": 0, "rejected": 0, "agent_up": 0}
```

`platform-check OBJECT=all` 退出 2，93 秒。失败任务：`Require object storage console acceptance without printing private inputs`（`infrastructure/services/verify.yaml:293`）。fail_msg：`{"passed": false, "reason": "Invalid console credentials must be denied: HTTP 500"}`。Neo4j Browser 那一项是 `passed: true`。

## 结论

待办 29 第一节到第五节通过。页面上的「我的机器」三项没看。整套 platform-check 仍不通过，停在对象存储控制台：错误口令拿到的是 HTTP 500，不是拒绝。
