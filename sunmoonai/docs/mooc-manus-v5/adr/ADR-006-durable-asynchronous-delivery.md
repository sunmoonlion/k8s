# ADR-006：异步可靠交付与本地 Outbox

状态：PROPOSED / INFO_CANDIDATE_DEPLOYED_NOT_ACCEPTED
日期：2026-07-14  
任务：V5-P0-006

## 1. 问题

Info 创建 `DistributionRecord` 后曾由 HTTP 路由直接调用 Celery/RabbitMQ。数据库提交成功而进程在 `apply_async` 前退出、Broker 暂不可用或 API 进程重启时，业务记录会永久停留在 `pending`，且没有确定的恢复者。反过来，Broker 已接受消息而发送方尚未记录结果、或 worker 在外部调用后退出时，重复消息不可避免。

PostgreSQL、RabbitMQ 与 Knowledge Provider 之间没有项目可用的全局事务；把消息“发成功”误当成业务“完成”不能消除此类窗口。

## 2. 决策

### 2.1 语义

1. 所有关键跨进程命令采用 **事务性本地 outbox + 至少一次投递 + 接收端/副作用幂等**。不承诺跨数据库、Broker 与 Provider 的 exactly-once。
2. 本地数据库是恢复真相源；RabbitMQ/Celery 只是 wake-up transport，Redis 也不是恢复真相源。
3. 每项异步命令都有稳定的 operation/idempotency identity。重复 publish、worker restart 和 scanner 竞争必须最多导致重复尝试，不能导致重复业务效果。

### 2.2 Info -> Knowledge P0 原型

当用户实际请求分发、重试或手工重新分发时，在同一 PostgreSQL transaction 中变更 `DistributionRecord` 并写入/重置一条：

```text
delivery_outbox_message
  topic              info.distribution.dispatch.v1
  aggregate          distribution_record / distribution_id
  idempotency_key    info.distribution:{distribution_id}:dispatch-v1
  payload            { distribution_id }（无 artifact 正文、token 或 secret）
  state              pending | leased | published | completed
  attempt_count / available_at / lease_token / lease_expires_at
  broker_message_id / published_at / completed_at / last_error
```

`DistributionRecord` 的既有 Artifact Contract `distribution_id` 与 Info -> Knowledge ingestion idempotency key 保持不变；outbox 只包装该稳定 operation，不复制或重写 Provider payload。

“只创建分发记录、暂不请求 dispatch”的既有 API 语义保持不变：不自动创建待投递 outbox。这样扫描器不会把仅供审核的记录静默发往 Knowledge。

### 2.3 Dispatcher 与 scanner

1. HTTP API 在提交后可作一次 **best-effort kick**，但 Broker 故障不得把已经持久化的业务请求伪装成失败，也不得回滚它。
2. 独立 scanner 周期性执行有限批次：通过 `SELECT ... FOR UPDATE SKIP LOCKED` 抢租约，再发布 Celery task。多个 scanner 可并行，不共享内存锁。
3. Broker accept 后才记录 `published`；若进程在二者之间退出，租约过期后会重新发布。Celery task ID 固定为 outbox UUID，只用于 trace，并不被误认为 Broker 去重保证。
4. `leased` 超时与 `published` 在确认超时前未完成都会重新变为可投递。发布失败按有上限的指数退避重试；P0 保留失败记录而不做静默丢弃。
5. Worker 仅在 `DistributionRecord` 进入 `succeeded` 后把 outbox 标记为 `completed`。worker 已调用外部 Provider 但未确认时，scanner 可能再发一次；这正是由稳定 Provider idempotency key 承担的场景。
6. P0 scanner 采用同一后端镜像中的有界 CLI，并由现有 Info worker 资源生成一个默认 `suspend: true` 的 Kubernetes CronJob；它只需 PostgreSQL/RabbitMQ，不携带 Info -> Knowledge service credential。真正调用 Knowledge 的仍是已绑定服务身份的 Info worker。只有候选镜像、migration 与 fault matrix 通过后，隔离验证才可显式解除暂停。

### 2.4 状态机

```text
pending --claim--> leased --broker accepted--> published --worker business success--> completed
   ^                    |                         |
   |                    | broker error            | worker/process acknowledgement timeout
   +--------------------+-------------------------+
                  (延迟后重新可 claim)
```

`completed` 是终态。显式业务 retry/re-dispatch 只能在相应 `DistributionRecord` 未成功时重置同一 outbox operation；不得插入第二个同 topic/idempotency key 的消息。

### 2.5 安全、观测与保留

- 日志/metrics 只记录 outbox ID、distribution ID、attempt、状态和错误分类；不记录 service token、RabbitMQ URL 密码、artifact 正文或完整 Provider response。
- 最小指标：pending/leased/published 数量、最老 lag、lease expiry、publish failure、completed latency、重复投递/幂等命中。
- `completed` 行的归档期限、失败告警/人工重驱与跨仓通用 library 不属于 P0；M1/M3 以实际容量、告警和第二条链路触发。

## 3. 拒绝方案

### 3.1 DB commit 后直接 `apply_async`

拒绝。无法从 API crash 或 Broker 不可用恢复，正是本 ADR 要消除的窗口。

### 3.2 RabbitMQ transaction/confirm 代替 outbox

拒绝。它最多说明 Broker 接收，不能与 PostgreSQL domain transaction 原子化，也不能覆盖 Knowledge 外部副作用与 worker kill。

### 3.3 只使用 Celery retry/result backend

拒绝。任务尚未入队时没有可 retry 的 task；result backend 也不是业务恢复真相源。

### 3.4 现在抽取四仓共享 SDK

暂不选择。先以 Info -> Knowledge 真实链路固化状态、身份和故障语义；第二条成功落地后再决定共享规范或库，避免错误抽象传播。

## 4. P0 接受条件

本 ADR 只能在下列证据全部存在后改为 `ACCEPTED`：

1. Info migration gate 应用 `delivery_outbox_message`，并有 rollback/升级检查。
2. KIND 中支撑认证 Info Admin dispatch 的同一领域服务创建分发 + outbox 同事务可证实；故意阻断 RabbitMQ 后记录仍是 pending，恢复后 scanner 自动补投。该可靠性交付验证不得为方便测试重开匿名 Admin HTTP；浏览器身份、角色、CSRF 与 HTTP 路由由 P0-005/P0-007 的配对 E2E 单独证明。
3. 两个 scanner 同时运行时，一条消息同一 lease 周期只被一个 scanner claim；lease expiry 后可恢复。
4. 注入“Broker 接受后、published 写库前”与“Provider 副作用后、worker acknowledgement 前”中断，重复投递后 Knowledge 无重复业务效果，最终 outbox completed。
5. worker/scan restart、错误重试和手工 re-dispatch 的 audit/operation/correlation 链完整；日志与输出不泄露 credential。
6. CronJob 的镜像 digest、ServiceAccount、网络最小权限、运行频率、指标和恢复 runbook 已验证。
7. 对 Knowledge/Research 的 M1 任务边界和统一 contract 已回填，不把 Info 原型误称为四仓通用能力。

## 5. 当前实现与未决事项

Info 原型代码已形成，候选镜像/migration 已部署，但尚未完成故障验收：

- `info-app/info-admin-backend/app/alembic/versions/20260714_0004_delivery_outbox.py`
- `app/application/services/delivery_outbox.py`
- `app/cli/drain_delivery_outbox.py`
- Info distribution API/worker 的 outbox 接入与单元测试。
- Info worker 资源中的 suspended scanner CronJob/独立无 token ServiceAccount，以及显式 outbox config values。
- `verify_p0_006_scanner_manifest.sh` 与 `verify_p0_006_kind.py`：前者验证生成资源默认暂停和最小凭据；后者在候选 KIND 环境验证 Info broker block/recover、scanner 竞争、broker accept/published 写库中断、provider effect/outbox acknowledgement 中断和 CronJob 恢复。P0-005 后 Admin HTTP 必须保持 browser-session/CSRF 保护，因此后者通过受控 `kubectl exec` 在既有 Info/Knowledge Pod 内调用同一领域服务、仅读取无凭据状态标记，绝不抽取 cookie/token 或把匿名 `401` 误判为网络故障。验证器的临时 API env、Knowledge worker env、CronJob suspend 与唯一测试队列均需恢复；API broker override 的 helper 还必须在 rollout 失败或 SIGINT/SIGTERM 时自行回滚，不能只依赖调用方的 `finally`。两者都不输出 credential。

候选镜像 `p0-006-outbox-20260714` 已推送，migration `20260714_0004` 已通过 KIND migration gate，API/worker 已候选部署，scanner 仍默认暂停。首次故障演练发现并修复验证器 cleanup 缺陷，且已手工恢复 Info API 配置；这不是 fault matrix 成功。KIND 全矩阵、CronJob 和最终证据通过前，不生成正式镜像 tag、不替换正在运行的 `1.0.1` 发布基线、不修改其他两仓的消息链路，状态保持 `PROPOSED / INFO_CANDIDATE_DEPLOYED_NOT_ACCEPTED`。
