# V5-P0-006：可靠交付 ADR 与 Info 原型

- 状态：IN_PROGRESS / INFO_CANDIDATE_DEPLOYED_NOT_ACCEPTED
- 日期：2026-07-14
- ADR：`sunmoonai/docs/mooc-manus-v5/adr/ADR-006-durable-asynchronous-delivery.md`

## 当前已完成（本地代码验证）

- Info `DistributionRecord` 在用户请求 dispatch 时与 `delivery_outbox_message` 在同一 transaction 写入；retry/re-dispatch 重用稳定 operation，不产生第二条 idempotency key。
- Outbox 使用 `pending -> leased -> published -> completed` 状态和 PostgreSQL `FOR UPDATE SKIP LOCKED` lease；过期 lease/published acknowledgement 都可由 scanner 重新发现。
- API immediate kick 仅为加速，不因 RabbitMQ 故障回滚已持久化业务命令；worker 在 Knowledge business success 后才确认 outbox complete。
- scanner CLI：`python -m app.cli.drain_delivery_outbox --limit 50`；CronJob 默认 `suspend: true`，只在候选 KIND 故障矩阵中临时运行。
- 现有 Info worker 资源会生成独立 scanner ServiceAccount/CronJob，默认 `suspend: true`；它只引入 PostgreSQL 与 RabbitMQ secret，不引入 Knowledge service client 或浏览器 OIDC secret。
- KIND 故障验证器：`sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_006_kind.py`。它先要求候选 namespace 没有非 `completed` 的 Info delivery outbox，以免注入故障时触碰无关业务；随后临时阻断 Info 的 broker wake-up、验证两个 scanner 的单次 lease 竞争、注入“Broker accept 后/published 写库前”与“Provider effect 后/outbox ack 前”中断，并检查 CronJob 恢复后回到 `suspend: true`。P0-005 后 Admin HTTP 继续保持 browser-session/CSRF 保护，因此验证器通过受控 `kubectl exec` 在既有 Info/Knowledge Pod 内调用同一领域服务、只读取无凭据状态标记；它不使用匿名 Admin HTTP，也不提取浏览器 cookie/token。临时 API/Knowledge/CronJob/测试队列状态必须在 `finally` 清理；broker 覆盖 helper 自身还含 rollout 失败的内联回滚与 SIGINT/SIGTERM cleanup，不能依赖调用方在函数返回后才登记 cleanup。

## 已执行的本地验证

```bash
cd /home/zymun/info-app/info-admin-backend/app
.venv/bin/pytest -q
# 75 passed
.venv/bin/pyright app core
# 0 errors, 0 warnings, 0 informations
.venv/bin/alembic heads
# 20260714_0004 (head)
.venv/bin/python -m app.cli.drain_delivery_outbox --help
# exit 0
git diff --check
# exit 0
cd /home/zymun/k8s
bash sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_006_scanner_manifest.sh
# 默认暂停的 CronJob、无 token ServiceAccount、最小 secret 输入验证通过
```

## 候选部署与恢复演练（2026-07-14）

- 候选镜像已构建并推送：`harbor.sunmoonai.com:30443/app-images/info-admin-backend:p0-006-outbox-20260714`，digest `sha256:017f3c8ff58f58403fe2d6e83ec9bc1efa31711b09422fd75355ffd13102fdc9`。
- Info API migration gate 已在 KIND 实际执行 `20260712_0003 -> 20260714_0004`；API、worker 和默认暂停的 scanner CronJob 已部署为候选配置。
- 首次 KIND 故障验证在 API broker override rollout 阶段中断。检查发现显式 `CELERY_BROKER_URL=amqp://127.0.0.1:1/p0` 遗留在 Info API Deployment；已立即移除并完成 rollout，复核为 `ready=1/1`、显式 broker override 为空、scanner `suspend=true`。
- 根因不是 outbox 语义：验证器在 `kubectl set env` 成功、但 rollout 失败时尚未向调用方报告“已修改”，其原先的 `finally` 无法恢复该覆盖。已修复为 helper 内联 rollback，并为验证进程加入 SIGINT/SIGTERM cleanup；`py_compile` 与 scanner manifest client dry-run 均通过。
- 该恢复演练只证明清理缺陷已发现且候选集群恢复正常，**不构成** RabbitMQ/Knowledge fault matrix 通过，也不允许变更正式 `1.0.1`。

## 第二次 KIND 运行的验证器纠偏（2026-07-15）

- 第二次运行已完成 API/Knowledge worker 的临时 override 恢复；复核 API 与 Knowledge worker 均 `ready=1/1`、Info API 没有显式 `CELERY_BROKER_URL`、scanner 仍 `suspend=true`。
- 运行失败点为旧验证器以匿名 `GET /api/documents` 作为 Info port-forward 的健康判断。P0-005 已正确地使该 Admin 路由返回 `401`，所以端口转发实际可用却被验证器错误报告为超时。**这不是允许重新开放匿名 API 的理由。**
- 已把 verifier 改为受控 Pod 内领域 harness：它调用认证 Admin route 背后的同一分发/投递领域服务，读取 Info outbox 与 Knowledge ingestion 的最小状态标记。P0-005/P0-007 保留浏览器登录、CSRF、角色和 HTTP 路由责任；P0-006 只证明可靠交付。外层 zsh 恢复包装如需保留，变量必须命名为 `exit_code`，不得使用 zsh 保留的只读 `$status`。
- 本次是验证器修正与集群恢复记录，**不是** P0-006 fault matrix 通过；修正后的完整矩阵仍须以候选 image 重跑。

## 未完成，禁止误报为通过

1. 尚未在修复后的验证器上完成 RabbitMQ block/recover、两个 scanner 竞争、Broker accept 后 kill、Provider effect 后 worker kill 和 CronJob 的完整真实故障矩阵。
2. 尚未证明 Knowledge 的真实 ingestion idempotency 在上述所有 fault 下最终收敛。
3. 尚未记录完整 verifier JSON、API/worker imageID、CronJob/ServiceAccount/网络最小权限、指标和恢复 runbook 的最终证据。

完成这些验证并记录 image/deployment digest、ServiceAccount、网络和恢复证据前，ADR-006 不得转 `ACCEPTED`。
