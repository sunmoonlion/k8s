# V5-P0-006：可靠交付 ADR 与 Info 原型

- 状态：IN_PROGRESS / INFO_PROTOTYPE_IMPLEMENTED_NOT_ACCEPTED
- 日期：2026-07-14
- ADR：`sunmoonai/docs/mooc-manus-v5/adr/ADR-006-durable-asynchronous-delivery.md`

## 当前已完成（本地代码验证）

- Info `DistributionRecord` 在用户请求 dispatch 时与 `delivery_outbox_message` 在同一 transaction 写入；retry/re-dispatch 重用稳定 operation，不产生第二条 idempotency key。
- Outbox 使用 `pending -> leased -> published -> completed` 状态和 PostgreSQL `FOR UPDATE SKIP LOCKED` lease；过期 lease/published acknowledgement 都可由 scanner 重新发现。
- API immediate kick 仅为加速，不因 RabbitMQ 故障回滚已持久化业务命令；worker 在 Knowledge business success 后才确认 outbox complete。
- scanner CLI：`python -m app.cli.drain_delivery_outbox --limit 50`；尚未在集群运行。

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
```

## 未完成，禁止误报为通过

1. 尚未构建/推送候选后端镜像，未更新 Deployment，不变更 `1.0.1` 或任何正式 tag。
2. 尚未对 KIND 数据库运行 `alembic upgrade head`，未部署 scanner CronJob。
3. 尚未运行 RabbitMQ block/recover、两个 scanner 竞争、Broker accept 后 kill、Provider effect 后 worker kill 的真实故障矩阵。
4. 尚未证明 Knowledge 的真实 ingestion idempotency 在上述 fault 下最终收敛。

完成这些验证并记录 image/deployment digest、ServiceAccount、网络和恢复证据前，ADR-006 不得转 `ACCEPTED`。
