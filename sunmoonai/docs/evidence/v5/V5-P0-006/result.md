# V5-P0-006：可靠交付 ADR 与 Info 参考实现

- 状态：**ACCEPTED / INFO_REFERENCE_IMPLEMENTATION**
- 日期：2026-07-15
- ADR：`sunmoonai/docs/mooc-manus-v5/adr/ADR-006-durable-asynchronous-delivery.md`
- Runbook：`sunmoonai/docs/mooc-manus-v5/runbooks/info-delivery-outbox.md`
- 最终原始结果：`final-verifier.json`、`final-cluster-state.json`

## 1. 接受结论

接受“事务性本地 outbox + 至少一次投递 + 接收端/Provider 幂等”作为跨进程关键命令的统一可靠语义。Info→Knowledge P0 参考实现已在真实 KIND/PostgreSQL/RabbitMQ/Knowledge ingestion 链路完成连续故障矩阵；不承诺跨数据库、Broker、Provider exactly-once。

本接受结论不表示四仓 SDK、正式 NetworkPolicy、Prometheus 指标、归档策略或 Knowledge/Research 后续业务链路已经完成。它们分别由 M1-005、M1-104/105、M1-202/203、M1-302/311、M1-503 与 M3-001 承接。

## 2. 最终实现

- `DistributionRecord` 与 `delivery_outbox_message` 在一个 PostgreSQL transaction 中写入；因 session 使用 `autoflush=False`，父记录在同一 transaction 内显式 flush 后再插入带外键的 outbox，最后只 commit 一次。
- 状态机为 `pending -> leased -> published -> completed`；`FOR UPDATE SKIP LOCKED` 支持多 scanner 竞争，lease/published acknowledgement 超时可恢复。
- API immediate kick 只作加速，并使用独立数据库 session；其 commit/失败不会使待返回的 ORM record 过期或污染请求 session。
- stable outbox idempotency key、Celery task ID、Artifact Contract idempotency key 与 correlation/causation identity 不因重试改变。
- Info worker 仅在 Knowledge business success 后确认 outbox `completed`；重复消息依靠 Knowledge ingestion 幂等收敛为一个业务效果。
- scanner 使用同一不可变后端镜像、独立无 token ServiceAccount、PostgreSQL/RabbitMQ 最小 Secret，且不挂载 Knowledge service credential。

## 3. 代码与本地门禁

Info Backend 最终相关提交：

- `9923fa0 fix: flush distribution before outbox insert`
- `fb53e7a fix: isolate outbox dispatcher session`
- `ac48194 test: cover stable outbox redispatch`

K8s 验证器最终相关提交：

- `7423ca6 fix: reauthorize p0 delivery verification`
- `0c25f46 fix: harden p0 outbox verifier`

验证结果：

```text
pytest: 77 passed
pyright app core: 0 errors, 0 warnings, 0 informations
Alembic head: 20260714_0004
verify_p0_006_scanner_manifest.sh --validate-cluster: passed
verify_p0_006_kind.py: passed
```

scanner manifest 门禁确认：默认 `suspend=true`、`automountServiceAccountToken=false`、无 Knowledge service credential、生成清单通过 kubectl client dry-run。

## 4. 最终候选与集群状态

- 镜像：`harbor.sunmoonai.com:30443/app-images/info-admin-backend:p0-006-outbox-r3-20260715`
- Harbor manifest / API+worker 实际 imageID：`sha256:ff2291ab40ef238acff359af1e1509a010a63949c43fe64a31051bf30e973dc8`
- Info API：`ready=1/1`
- Info worker：`ready=1/1`
- Knowledge worker：`ready=1/1`，恢复稳定 `knowledge-admin-backend:1.0.1`
- scanner：`schedule=*/1 * * * *`，最终恢复 `suspend=true`，Job `ttlSecondsAfterFinished=300`
- 临时 API/Knowledge env override：无
- `sunmoonai.com/p0-verifier=true` Job：0
- 最终 outbox：`active=0`、`completed=16`

滚动更新历史产生的 migration/scanner `Completed` Pod 不算运行候选；对应 Job 由 TTL 回收。最终验证器在开始时只接受唯一 `Running+Ready` API/worker Pod，并把实际 digest写入结果。

## 5. 最终连续故障矩阵

最终 r3 运行一次连续通过：

1. **DB commit / RabbitMQ 不可用**：业务命令与 outbox 保留；恢复后 attempts `1 -> 2`，最终 `completed`。
2. **两个 scanner 竞争**：两个 Job 只产生一个 claim，Knowledge 业务效果为 1。
3. **Broker accept / published 未写**：短暂把 Info worker 缩到 0，故障 Job 把真实任务投递到既有 `info.admin.default` 后退出；lease 到期后 scanner 重发，恢复 worker 后两条消息仅产生一个 Knowledge ingestion，outbox `completed`。
4. **Provider effect / outbox ack 未写**：Provider 已成功后故障进程退出；ack 超时 scanner 重发，Knowledge 业务效果仍为 1，outbox `completed`。
5. **正式 CronJob 恢复**：临时解除 suspend 后自动扫描完成，随后恢复 `suspend=true`。

完整 ID、attempt 和 digest 见 `final-verifier.json`。输出明确记录 `credentials_printed=false`。

## 6. 验证过程中发现并系统修复的问题

这些失败均保留为审计记录，不能删除后假装一次成功：

- rollout 中断后 broker override 可能遗留：helper 改为在自身失败路径内回滚，并增加 SIGINT/SIGTERM `finally` 恢复。
- 旧 verifier 用匿名 Admin API 判断 port-forward：P0-005 后正确的 `401` 被误报为网络失败；改为受控 Pod 内领域 harness，不降低鉴权。
- `autoflush=False` 下父记录尚未 flush 就插入 outbox：生产代码在同一 transaction 内显式 flush，补回归测试约束 `add -> flush -> outbox -> commit`。
- best-effort dispatcher 与 HTTP 请求共用 session：dispatcher commit 使返回 record 过期；改为隔离 unit of work，并补测试。
- 故障测试尝试创建任意 RabbitMQ 队列：服务身份被 `403 AccessRefused` 正确拒绝；验证器不扩大权限，改为使用既有 `info.admin.default`，通过可回滚 worker 缩容隔离消费。
- 故障 harness 在 commit 后访问过期 ORM ID：commit 前复制不可变 UUID。
- Kubernetes EnvVar 的数字阈值被渲染为 number：统一 JSON 字符串序列化。

以上均是代码、事务边界或可重复验证器修复，不是集群手工打补丁。最终运行未依赖匿名接口、额外 RabbitMQ 权限、浏览器 token 或数据库手改。

## 7. 权限、观测与后续任务边界

P0 最小权限证据：scanner 不挂载 ServiceAccount token、不挂载 Knowledge credential；RabbitMQ worker 身份只能操作预定义 Info 队列，任意 `p0-*` 队列操作被 403 拒绝。完整 namespace/application NetworkPolicy 明确留在 M1-005。

P0 观测证据：scanner 输出结构化 `claimed/published/broker_failures`，verifier 查询 state/attempt/timestamp 并保存最终 JSON。正式 queue/outbox/lease 指标与告警留在 M1-503，恢复和回滚步骤已写入 runbook。

M1 继承关系：

- M1-104/105：产品化 Info Delivery Record 与 dispatcher，补 reconciliation、保留、告警和正式启停策略。
- M1-202/203：固化 Knowledge ingestion 状态机、Provider 幂等和非阻塞 polling。
- M1-302/311：按 ADR-001 选中 Runtime 分支实现 Research durable command/lease/reconciler，不复制 Info 代码。
- M1-005/503：NetworkPolicy、容器安全、Prometheus metrics/alerts。
- M3-001：第二条链路稳定后再决定四仓 outbox/inbox 规范或共享 SDK。

## 8. 版本治理

P0 候选 digest作为验收证据保留，但不覆盖已冻结的稳定 `1.0.1`。正式发布必须使用独立 release decision 和新版本；P0 阶段号、candidate tag 与正式产品版本不得混用。
