# Info Delivery Outbox 恢复 Runbook

状态：P0-006 已验证基线（2026-07-15）

## 1. 适用范围与不变量

本 runbook 只处理 `Info DistributionRecord -> delivery_outbox_message -> Knowledge ingestion`。PostgreSQL outbox 是恢复真相源，RabbitMQ/Celery 只是 wake-up transport；跨数据库、Broker、Provider 不承诺 exactly-once。

- 不删除非 `completed` outbox，不直接手改 lease/token/state。
- 不为恢复关闭 Admin 鉴权、提取浏览器 cookie 或把 service token 放进终端。
- 不给 scanner 挂载 Info→Knowledge 调用凭据；真正调用 Knowledge 的是 `celeryworker-info-admin-backend`。
- 不创建 RabbitMQ 临时业务队列或扩大账号正则；Info worker 只操作 `info.admin.default`。
- API、worker、scanner 必须使用同一不可变镜像 digest。

## 2. 只读分诊

先核对工作负载与 scanner，不输出 Secret：

```bash
export KUBECONFIG="$HOME/.kube/kind-config"
export NS=app-platform-dev

kubectl get deployment/info-admin-backend \
  deployment/celeryworker-info-admin-backend \
  cronjob/info-delivery-outbox-scanner \
  -n "$NS" -o wide

kubectl get pods -n "$NS" \
  -l 'app in (info-admin-backend,celeryworker-info-admin-backend)'
```

P0 的安全状态读取由 `verify_p0_006_kind.py` 内的受控 Pod harness 完成，输出只包含 state/count/attempt/timestamp。正式 M1-503 指标上线前，值班人员至少检查：

- `pending|leased|published` 数量与最老 `available_at`；
- 过期 `lease_expires_at`；
- 超过 acknowledgement 阈值的 `published_at`；
- scanner JSON 中的 `claimed/published/broker_failures`；
- 同一 distribution 的 outbox 是否唯一，以及 Knowledge idempotency key 是否只对应一个 ingestion。

## 3. 一次性安全恢复

确认 API/worker/scanner 镜像一致、RabbitMQ 与数据库配置正常后，从受限 CronJob 派生一次性 Job：

```bash
JOB="info-delivery-outbox-recover-$(date +%s)"
kubectl create job \
  --from=cronjob/info-delivery-outbox-scanner \
  "$JOB" -n "$NS"
kubectl wait --for=condition=complete "job/$JOB" \
  -n "$NS" --timeout=180s
kubectl logs "job/$JOB" -n "$NS"
kubectl delete job "$JOB" -n "$NS" --wait=true
```

成功标准：Job 的结构化结果无 credential，`broker_failures=0`，目标 outbox 最终 `completed`，Knowledge 同一 idempotency key 只有一个业务效果。若只是尚未到 `available_at`、lease expiry 或 acknowledgement deadline，不得通过改数据库时钟字段强行提前。

## 4. 常驻 scanner 与暂停

P0/KIND candidate 默认 `suspend=true`。只有部署决策明确允许该环境自动恢复后才解除：

```bash
kubectl patch cronjob/info-delivery-outbox-scanner \
  -n "$NS" --type=merge -p '{"spec":{"suspend":false}}'
```

发生配置异常、错误镜像或下游事故时先暂停新扫描，不删除已有记录：

```bash
kubectl patch cronjob/info-delivery-outbox-scanner \
  -n "$NS" --type=merge -p '{"spec":{"suspend":true}}'
```

CronJob 当前每分钟运行，Job 设置 `ttlSecondsAfterFinished=300`；短暂的 `Completed` Pod 是预期状态并由 TTL 回收。

## 5. 故障分类

| 现象 | 处置 |
|---|---|
| API 已提交、broker 不可用 | 保留 pending；修复 broker 后运行 scanner |
| leased 且 worker/scanner 已退出 | 等 lease 到期，再由 scanner claim |
| published 长期未 completed | 核对 Info worker 与 Knowledge；超过 ack 阈值后 scanner 可重发 |
| Knowledge 已成功但 outbox 未确认 | 允许按稳定 idempotency key 重试；验证只有一个 ingestion 业务效果 |
| broker_failures 持续增长 | 暂停 CronJob，修复 broker 身份/路由；禁止扩大到任意队列权限 |
| 同一 topic/idempotency key 出现多行 | 停止分发并升级为数据一致性事故，禁止人工合并 |

## 6. 回滚与升级

1. 暂停 scanner 和新的 dispatch/retry 流量。
2. 等待正在执行的 worker 收敛或有界终止，记录 active outbox。
3. 按 digest 回滚 API 与 worker，保持两者一致。
4. 不在存在 active outbox 时降级/删除 `delivery_outbox_message` migration。
5. 回滚后用一次性 scanner 验证恢复，再决定是否恢复常驻 CronJob。

P0-006 candidate 不覆盖稳定 `1.0.1`。正式发布、NetworkPolicy、Prometheus 指标/告警、归档保留和跨仓 SDK 分别由 release decision、M1-005、M1-503、M1-105/M3-001 完成。
