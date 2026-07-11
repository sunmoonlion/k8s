# ADR-001：Research Agent Runtime 选型

状态：IN_PROGRESS / CANDIDATE_A_PARTIAL
日期：2026-07-11
任务：V5-P0-001

## 1. 决策问题

Research App 应采用以下哪种生产执行运行时：

- A：自建 FastAPI + durable dispatcher/Celery + LangGraph checkpointer + Redis/SSE。
- B：自托管 Standalone Agent Server。
- C：Research 产品控制面 + Agent Server 执行面的混合模式。

本 ADR 决定执行职责归属，不决定 LangGraph 是否使用；三种候选都以 LangGraph 为图编排内核。

## 2. 硬约束

- 部署在现有私有 Kubernetes/App Platform。
- Research 领域数据库、用户授权和产品事件仍由 Research App 拥有。
- 支持长任务、interrupt/resume、checkpoint、stream、cancel、同 Thread 并发控制和 worker 恢复。
- 不允许 Redis 成为 Run/用户数据的持久真相源。
- 必须支持四仓身份、契约、citation 和审计 lineage。
- 生产依赖的商业许可、外部 egress 和 usage reporting 必须显式批准，不能作为隐藏前提。
- 未选 Runtime 分支不得继续建设。

## 3. 已核验事实

### 3.1 当前自建基线

当前 Research 已有：

- FastAPI 创建 Session/Run。
- RabbitMQ/Celery worker。
- Postgres checkpointer。
- Redis Pub/Sub + SSE。
- interrupt/resume Walking Skeleton。
- Redis session lock 和副作用去重骨架。

但缺少或存在缺陷：

- durable enqueue/outbox、RunAttempt/lease、cancel 和 reconciler。
- 首轮 input 传递、原子 resume、真正 reducer、生产 Graph。
- SSE catch-up/live 空窗。
- 领域状态/事件/投影事务收口。

因此候选 A 不是“零成本沿用”，而是继续自行承担上述生产运行时能力。

### 3.2 Agent Server 官方能力

官方 Agent Server 提供 assistant/thread/run、持久化、durable task queue、stream、cancel、worker lease、同 Thread 单 Run、API/queue worker 分离以及长期 Store。Run 数据写 PostgreSQL，Redis 用于 signaling/cancellation/streaming，不持久化 Run 数据。

来源：[Agent Server architecture](https://docs.langchain.com/langsmith/agent-server)

Standalone Server 可部署到 Kubernetes，需要 PostgreSQL 和 Redis；生产自托管仍由使用方管理扩缩容、CI/CD 和基础设施。

来源：[Deploy standalone server](https://docs.langchain.com/langsmith/deploy-standalone-server)

### 3.3 商业与网络约束

官方文档要求 Standalone Server 配置 `LANGGRAPH_CLOUD_LICENSE_KEY`，启动时验证许可证；非 air-gapped 模式还要求访问 `https://beacon.langchain.com` 进行 license verification/usage reporting。平台文档把 self-hosted/hybrid 列为 Enterprise，免费仅明确覆盖本地测试和开发。

来源：[Standalone prerequisites](https://docs.langchain.com/langsmith/deploy-standalone-server)、[Platform setup](https://docs.langchain.com/langsmith/platform-setup)

这构成生产选用 B/C 的硬门：没有可接受的许可、采购结论、数据/usage reporting 审查和 egress 决策时，B/C 不能进入生产候选，但仍可进行隔离的免费本地 Spike。

## 4. 评分模型

评分：1=差，3=可接受，5=强。权重在 Spike 前冻结，防止结果导向调整。

| 维度 | 权重 | A 自建 | B Agent Server | C 混合 | Spike 证据 |
|---|---:|---:|---:|---:|---|
| 私有化/许可可接受性 | 20 | 5 | 待定 | 待定 | 商务、法务、egress |
| durable queue/lease/cancel | 15 | 2 | 5 | 5 | kill/cancel/concurrency |
| 产品领域事务集成 | 15 | 5 | 2 | 4 | Run+event+outbox |
| 身份与资源授权 | 10 | 5 | 3 | 4 | delegated identity |
| streaming/SSE 恢复 | 10 | 2 | 5 | 4 | disconnect race |
| checkpoint/store 升级 | 10 | 3 | 5 | 4 | upgrade/resume |
| K8s 运维复杂度 | 10 | 3 | 3 | 2 | deployment/backup |
| 团队维护与锁定 | 10 | 2 | 3 | 2 | 代码量/退出演练 |

表中非“待定”分数是进入 Spike 的初始假设，不是最终结论。

## 5. 必须运行的同构 Spike

对 A 和至少一个 B/C 候选使用同一测试 Graph：

```text
START -> persist_input -> ask_user(interrupt)
      -> side_effect_tool(idempotent) -> final -> END
```

测试矩阵：

1. 创建 Thread/Run 并 stream。
2. interrupt 后杀死 worker，重启并 resume。
3. side effect 前、后分别 kill，验证不重复。
4. 同 Thread 并发创建两个 Run。
5. running 时 cancel，验证终态和 checkpoint。
6. SSE/stream 断线后按 cursor 恢复。
7. API 与 worker 分别扩为两个副本。
8. Graph 版本升级后恢复旧 waiting Run。
9. 注入 PostgreSQL、Redis 和 queue 短暂故障。
10. 记录代码量、运行组件、资源、日志、指标和人工恢复步骤。

## 6. 候选淘汰规则

任一条件满足即淘汰对应候选：

- 无法满足私有部署、许可或合规要求。
- 生产运行必须依赖未经批准的外部 egress/usage reporting。
- worker kill 后无法从已确认 checkpoint 恢复。
- 同 Thread 并发不能保证确定语义。
- 无法把产品用户/服务身份安全传递到 Knowledge/Tool/Sandbox。
- 无法 pin Graph/Prompt/Model/Toolset 版本或无法处理旧 waiting Run。
- 无法提供可测试的 cancel 和 stream 恢复。

## 7. 当前临时结论

- A 保持生产候选，原因是无新增商业许可且与现有平台集成直接；风险是需要自行补齐大量 durable runtime 能力。
- B/C 仅保持 Spike 候选。它们在运行能力上明显更完整，但生产资格取决于许可、egress、采购和控制面集成。
- 在同构 Spike 和商业硬门完成前不作最终选择，不扩建任何候选的生产主链。

## 8. 决策完成条件

- A 与 B 或 C 的同构 Spike 报告。
- 商业许可/成本/egress 书面结论。
- 加权评分与淘汰规则结果。
- 选中分支的实施任务激活，其他分支标记 `NOT_APPLICABLE`。
- 从选中 Runtime 退出或迁移的最小方案。

## 9. Spike 执行记录

### 9.1 候选 A：自建 Runtime（部分完成）

2026-07-11 已在 `research-app/research-admin-backend/app` 增加隔离、不可被生产路由导入的同构 Spike：

- `app/infrastructure/graph/runtime_selection_spike.py`
- `scripts/run_runtime_selection_spike.py`
- `scripts/run_runtime_selection_postgres_spike.py`
- `tests/test_runtime_selection_spike.py`

已验证：

- interrupt/resume 后完成。
- 副作用提交后注入崩溃，再次执行从 checkpoint 恢复；稳定 operation ID 使物理副作用为一次。
- 两个不同 Thread 不共享 checkpoint 和 operation ID。
- waiting Run 使用被 pin 的旧 Graph builder 恢复。
- PostgreSQL checkpointer 关闭并重新连接后，替代 worker 能恢复 waiting Thread。

尚未验证，因此候选 A 不能判定通过：

- 同一 Thread 的两个并发 Run 的正式拒绝/排队语义。
- running cancel 及终态/checkpoint 一致性。
- cursor stream 断线无缝补偿。
- API/worker 双副本、真实 worker `SIGKILL` 和 queue/Redis/PostgreSQL 故障矩阵。
- durable operation journal；当前 Spike ledger 只是进程内测试替身。

执行证据：`sunmoonai/docs/evidence/v5/V5-P0-001/candidate-a-partial.md`。

### 9.2 候选 B/C

尚未执行。2026-07-11 尝试以不写入项目依赖的 `uvx --from 'langgraph-cli[inmem]'` 获取官方本地开发 CLI，但当前软件源未解析到该 extra，离线缓存也不存在。因此没有伪造候选 B 的运行结果，也没有把 CLI 写入生产依赖。

后续必须确认可审计的软件源、锁定版本与本地开发许可获取方式；生产资格仍受第 3.3 节商业、egress 和 usage reporting 硬门约束。候选 A 的部分成功不得代替 B/C 对照，也不得触发 ADR Accepted。
