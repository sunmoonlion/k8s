# ADR-001：Research Agent Runtime 选型

状态：ACCEPTED / CANDIDATE_A_SELECTED

原始日期：2026-07-11

接受日期：2026-07-16

任务：V5-P0-001

## 1. 决策

Research Agent 的当前生产基线选择：

> **A：Research 自有控制面 + 自建 durable dispatcher/worker + LangGraph
> executor/checkpointer + PostgreSQL durable state + Redis live signaling/SSE。**

不选择：

- B：自托管 Standalone Agent Server。
- C：Research 产品控制面 + Agent Server 执行面的混合模式。

本决策选择的是生产责任边界，不表示当前 Walking Skeleton 已具备生产资格，也不授权
绕过 Gate P0 扩建主链。P0-002 必须先冻结 Session/Thread/Run/Attempt/Invocation 映射；
Gate P0 后再按 M1-301~312 实现选中分支。

## 2. 决策驱动与硬约束

- 部署在现有私有 Kubernetes/App Platform。
- Research 领域数据库、用户授权、产品事件、citation 和审计 lineage 仍由 Research
  App 拥有。
- 支持长任务、interrupt/resume、checkpoint、stream、cancel、同 Thread 并发控制、
  worker 恢复与 Graph 版本 pin。
- PostgreSQL 是 Run、checkpoint、event、dispatch intent 和 operation journal 的 durable
  真相源；Redis 只允许承担 live signaling、短期锁、cancel signal 和 Pub/Sub。
- 产品身份必须安全传递到 Knowledge、Tool 和 Sandbox。
- 商业许可、采购、外部 egress 和 usage reporting 必须显式批准，不能成为隐藏前提。
- 未选 Runtime 分支不得继续进入生产主链。

## 3. 候选事实

### 3.1 候选 A：当前自建基线

Research 已有 FastAPI、RabbitMQ/Celery、PostgreSQL checkpointer、Redis Pub/Sub/SSE、
interrupt/resume 骨架、资源授权和副作用去重原型。P0-001 隔离 Spike 进一步证明：

- 同 Thread 的非终态 Run 采用确定的 `reject` 策略。
- 运行中 cooperative cancel 可形成 durable `cancelled` 终态，且取消前不产生副作用。
- 副作用提交前和提交后杀死进程，replacement worker 均可恢复；operation journal 保证
  副作用恰好一次。
- 两个独立 worker 进程可共享 PostgreSQL checkpoint 并同时完成不同 Thread。
- PostgreSQL 不可达时 fail closed；恢复后 replacement worker 继续完成。
- live stream 丢失后，浏览器按 durable cursor snapshot 对账，无缺口和重复。
- API 与 worker Deployment 均可临时扩为两个 Ready 副本并恢复为一个副本。
- broker 不可达时，durable dispatch intent 保持 `pending`，恢复后只投递一次。

这些证据证明候选 A 的架构语义可行，不代表当前生产代码已经实现全部语义。

### 3.2 候选 B/C：官方能力

官方 Agent Server 提供 assistant/thread/run、PostgreSQL persistence、durable task queue、
worker lease、stream、cancel、同 Thread 单 Run、API/queue worker 分离和故障 sweeper。
Redis 只承担 signaling、cancellation 和 streaming，不持久化 Run 数据。

来源：

- [Agent Server architecture](https://docs.langchain.com/langsmith/agent-server)
- [Scalability and resilience](https://docs.langchain.com/langsmith/scalability-and-resilience)
- [Cancel a run](https://docs.langchain.com/langsmith/cancel-run)

因此 B/C 在通用运行时能力上优于当前 A 基线；本 ADR 没有否认这一事实。

### 3.3 B/C 的生产硬门

截至接受日期，官方 Standalone Server 文档仍要求：

- `LANGGRAPH_CLOUD_LICENSE_KEY`。
- 非 air-gapped 模式访问 `https://beacon.langchain.com`，用于 license verification 和
  usage reporting。
- self-hosted LangSmith/Deployment 属于 Enterprise 范围，许可或试用需与供应商确认。

来源：

- [Deploy standalone server](https://docs.langchain.com/langsmith/deploy-standalone-server)
- [Self-hosted LangSmith](https://docs.langchain.com/langsmith/self-hosted)
- [Self-host dependency versions](https://docs.langchain.com/langsmith/self-host-dependency-versions)

当前项目没有已批准的商业许可、采购结论、air-gapped entitlement 或 beacon egress/
usage-reporting 审查。因此 B/C 同时触发两条预先冻结的淘汰规则：

1. 无法证明许可/采购可接受。
2. 生产运行依赖未经批准的外部 egress/usage reporting。

候选在硬约束阶段被淘汰后，不再为了形式完整而把其组件装入生产集群。若未来硬门解除，
可新建 ADR 重新比较，不修改本次历史结论。

## 4. 最终评分

评分：1=差，3=可接受，5=强。候选 B/C 已在硬约束阶段淘汰，不再计算一个会掩盖硬门的
加权总分。

| 维度 | 权重 | A 自建最终分 | 证据/约束 |
|---|---:|---:|---|
| 私有化/许可可接受性 | 20 | 5 | 无新增生产商业许可或外部 usage-reporting 前提 |
| durable queue/lease/cancel | 15 | 3 | Spike 通过；生产 outbox/Attempt/lease/reconciler 待 M1 |
| 产品领域事务集成 | 15 | 5 | Research 继续拥有 Run/event/citation/auth |
| 身份与资源授权 | 10 | 5 | 消费 ADR-005 与独立服务身份 |
| streaming/SSE 恢复 | 10 | 4 | subscribe-before-snapshot、cursor/browser reconciliation |
| checkpoint/store 升级 | 10 | 4 | PostgreSQL replacement、旧 Graph version pin |
| K8s 运维复杂度 | 10 | 3 | 复用现有 Postgres/Redis/RabbitMQ/Celery，但责任自担 |
| 团队维护与锁定 | 10 | 3 | 代码维护较多；无 Agent Server 运行时锁定 |

加权结果：`4.10 / 5.00`。

## 5. P0 同构 Spike 结果

同构 Graph：

```text
START -> persist_input -> ask_user(interrupt)
      -> side_effect_tool(idempotent) -> final -> END
```

| 验证项 | 结果 | 证据 |
|---|---|---|
| 创建、interrupt、resume | PASS | LangGraph 单元与 PostgreSQL checkpoint |
| side effect 前 SIGKILL | PASS | replacement 完成，journal count=1 |
| side effect 后 SIGKILL | PASS | replacement 完成，journal count=1 |
| 同 Thread 并发 | PASS | 非终态第二 Run 明确 reject；实现落 P0-002/M1 |
| running cancel | PASS | durable cancelled，journal count=0 |
| stream/cursor 恢复 | PASS | 服务端顺序测试 + Chromium 断线对账 |
| 双 worker 执行 | PASS | 两个进程均 exit=0、completed、journal count=1 |
| API/worker 双副本 | PASS | 两个 Deployment 均达到 requested=2/ready=2 后恢复 |
| Graph 升级 waiting resume | PASS | waiting Run 使用 pinned v1 builder/checkpoint |
| PostgreSQL 故障 | PASS | fail closed count=0，恢复后 count=1 |
| Redis/live channel 丢失 | PASS | durable snapshot 补偿，Redis 不作为真相源 |
| queue/broker 故障 | PASS（模式） | durable dispatch intent 保持 pending，恢复后单次发送 |

权威证据：`sunmoonai/docs/evidence/v5/V5-P0-001/result.md`。

## 6. 冻结的运行时边界

### 6.1 Research 控制面拥有

- Session/Thread/Run/Attempt/Invocation 和资源 ACL。
- EffectiveRunConfig、Graph/Prompt/Model/Toolset 版本。
- Run command/outbox、Attempt lease、cancel intent、reconciler。
- 领域事件、UI projection、citation、审计与成本 lineage。
- 对 Knowledge、Tool、Sandbox 的 delegated identity。

### 6.2 LangGraph executor 拥有

- 选定 Graph 的节点调度与状态 channel/reducer。
- PostgreSQL checkpointer 上的 step checkpoint。
- interrupt/resume 的图内语义。

LangGraph checkpoint 不替代 Research Run、Attempt、event 或 operation journal。

### 6.3 基础设施职责

- PostgreSQL：所有 durable truth。
- RabbitMQ/Celery：执行 transport；消息不是业务真相。
- Redis：live Pub/Sub、短期 signal/lock；丢失后必须能从 PostgreSQL cursor 收敛。
- Kubernetes：API/worker 独立扩缩、滚动升级、Pod termination 与探针。

### 6.4 冻结语义

- 同 Thread 非终态 Run：默认 `reject`。未来若支持 enqueue/interrupt/rollback，必须作为
  显式策略而不是竞态副作用。
- cancel：先持久化 cancel intent/终态，再通过 signal 加速；Tool/LLM/Sandbox 必须在
  cooperative boundary 检查。
- resume：token/idempotency 必须原子消费；重复 resume 不得重复 dispatch。
- stream：先订阅 live channel，再读取 durable snapshot；浏览器最终以 cursor snapshot
  对账，不能把 SSE 当事实源。
- side effect：稳定 operation ID + durable journal；worker 重放不得重复外部动作。
- Graph upgrade：waiting Run 必须路由到被 pin 的旧 Graph 版本，直到显式迁移或终止。

## 7. P0-001 不包含的生产实施

以下是选中 A 后必须实施的工作，不得因为 ADR Accepted 被误报为完成：

- P0-002：Session/Thread/Run/Attempt/Invocation 隔离模型。
- M1-301/302：Run command/outbox、dispatcher 与投递幂等。
- M1-303/304：Attempt lease、heartbeat、worker claim。
- M1-305：原子 resume/cancel。
- M1-306/307：reconciler、超时/孤儿恢复。
- M1-308：transactional event/projection。
- M1-309：SSE v2/backpressure/final reconciliation。
- M1-310~312：Graph registry/version migration、运维与可观测。

当前 `app/tasks/agent_graph.py` 仍固定构建 Walking Skeleton，不能进入生产主链。

## 8. 风险与退出方案

### 8.1 主要风险

- 自建分支需要长期维护 durable runtime 能力，不能把 Celery 默认重试误当业务恢复。
- Redis session lock 不是 Attempt lease；生产实现必须以 PostgreSQL 条件更新为准。
- 当前事件写入、Run 状态和 dispatch 尚未同事务收口。

### 8.2 退出/重开条件

满足以下条件可重新评估 Agent Server：

- 获得明确的生产许可、成本和 air-gapped/egress 条款。
- 完成数据、usage reporting 和供应链审查。
- 用本 ADR 同一故障矩阵运行 B/C。
- 提供 Research Run/ACL/event 与 Agent Server thread/run 的双写迁移和回退方案。

在此之前，M1-313/314 标记为 `NOT_APPLICABLE`，不得平行建设第二套 Runtime。
