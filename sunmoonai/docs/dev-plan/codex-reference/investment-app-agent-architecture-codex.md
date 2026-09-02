# Investment App Agent 架构：独立源码评估

> 目标父仓：`luna/investment-app` @ `535736d`；运行代码对应 backend `175a1d7`、admin `4a7053b`、web `e463809`。研究日期：2026-08-28。

## 结论

Investment 已具备一个可靠 Agent runtime 的主要“骨架”：明确的领域模型、Run 状态机与预算、LangGraph checkpoint/HITL、Celery 执行、数据库事件、Redis 实时通道、session lock、幂等副作用、知识检索边界和服务身份。当前最大问题不是缺少另一个 Agent 框架，而是存在两条重叠运行链、图选择仍偏静态、工具/沙箱仅停留在端口与测试骨架、领域对象和真实执行持久化尚未完全收口。

建议先把现有 v4 与 pilot 合成一条可恢复的“Run 内核”，再引入受控动态 fan-out；不要先移植 Codex 式自由多 Agent。

## 1. 已有分层

```text
HTTP / SSE
    │
Application services ── Run / Pilot / Timeline / SideEffect / Lock
    │
Domain ── Run, Event, Budget, Profile, Memory, Tool, Sandbox, Security
    │
Infrastructure ── LangGraph, Postgres checkpoint, Redis, Celery,
                   Knowledge retrieval, LLM, repositories
```

分层方向是正确的：domain 层以 Protocol 定义 LLM、tool、sandbox、knowledge 等端口；application 编排用例；infrastructure 适配 LangGraph/Redis/Postgres/HTTP。后续集成 SQLBot 或 WrenAI 应新增 adapter，而不是让第三方对象穿透 domain。

## 2. 核心不变量

### Run 与预算

`RunStatus` 和 `validate_run_status_transition` 明确限制 created/running/waiting 到 completed/failed/cancelled/budget_exceeded 的转换，终态不可转出（`app/app/domain/agent/runtime.py:10-60`）。`RunBudget` 独立计算 steps、tool calls、LLM calls、input tokens，并用不可变返回值消费预算（同文件 `62-112`）。

这比依赖 LangGraph 节点数更稳，因为业务预算不应受图内部实现细节控制。建议下一步加入 output tokens、wall time、external cost 和 child invocation 数，但仍由 Run 内核统一结算。

### 状态、事件、Artifact 分层

graph state 明确禁止 `event_history`、`long_term_memories` 等跨层内容进入 checkpoint，也禁止 artifact 内嵌 body/content/raw，仅保存引用（`infrastructure/graph/state.py:71-93`）。DomainEvent、UIEvent、LiveDelta 分离，则 durable replay 与瞬时 token delta 不会被混为一条无限事件流。

### HITL 与副作用

walking skeleton 和 pilot graph 使用 LangGraph `interrupt()`；resume token 在 application service 中原子消费。tool side effect 通过 `record_once` 避免重复。正确方向是：checkpoint 恢复控制流，数据库保存业务事实，幂等 ledger 保护副作用；三者不能互相替代。

## 3. 两条执行链的结构性重复

### Pilot 链

面向 Web 产品：创建 run → Celery → knowledge retrieval → citation → LLM draft → approval interrupt → resume/finalize → browser events。它已有真实证据约束、delegated actor、同源 citation source 和 resume 消费失败落终态等产品级边界。

### Agent v4 链

面向 Admin：session/run API → Celery → session lock → walking skeleton → DBEventSink + Redis → HITL → 幂等 side effect。它承载更通用的领域模型，但 `agent_v4_traffic_enabled` 默认关闭，图能力仍是阶段性骨架。

两条链分别证明了“产品闭环”和“通用内核”，但继续并行会产生：

- 两套 run repository/service/status projection；
- 两套 SSE 事件协议与 Redis channel；
- 两套 resume/cancel 入口；
- pilot 真实能力无法自然进入 v4 profile/tool registry；
- 同类恢复语义需要双份测试。

## 4. 推荐目标态

```text
Interaction API
  └── AgentRunService (唯一 Run 内核)
      ├── RunRepository / EventStore / Outbox
      ├── Lease + SessionLock
      ├── GraphRuntimePort
      ├── ToolRegistry
      │   ├── KnowledgeRetrievalTool
      │   ├── WrenSemanticQueryTool
      │   └── ArtifactTool
      ├── ApprovalService
      └── ProjectionService
          ├── browser interaction projection
          └── admin diagnostic projection
```

Pilot 不再是一套 runtime，而是 `investment-research` AgentProfile + graph definition + tool allowlist + Web projection。Admin v4 与 Web 共享 Run/Attempt/Invocation/Event，只使用不同认证、profile 权限和 presentation projection。

## 5. 引入动态多 Agent 的顺序

### 阶段 A：先收口单 Agent 内核

- 合并 run identity、resume/cancel、事件和 SSE cursor 语义。
- 将 pilot knowledge/LLM/approval 节点变成正式 Tool/Graph adapters。
- 统一 RunBudget 与 policy version 快照。
- 让每次外部调用都产生 Invocation + Attempt + idempotency key。

### 阶段 B：受控 fan-out

只开放固定角色：fundamental、risk、news、portfolio synthesizer。planner 输出 `GraphPatch`，validator 校验最大节点、深度、工具集、预算和无环；scheduler 再激活节点。子 Agent 结果必须是版本化 `AnalysisContribution`：

```text
contribution_id, role, thesis, evidence_refs[],
assumptions[], risk_flags[], confidence, artifact_refs[]
```

### 阶段 C：可恢复 join

由持久 DAG 判定前驱完成；synthesizer 只读取已验证 contribution。任何交易、通知或外部写入仍经过审批节点和 side-effect ledger，子 Agent 无直接提交权。

## 6. WrenAI 与 SQLBot 的位置

- WrenAI 适合作为 `SemanticQueryPort` 的实现：提供 MDL、dry plan、strict model boundary 和受限查询。
- SQLBot 更适合作为产品/算法参考或独立受控服务，不适合直接把 `LLMService` 嵌入 Run 内核；其许可证也使源码复用需要单独法务决策。
- Knowledge retrieval 继续负责非结构化证据；Wren 负责结构化数据语义。二者的 evidence 都投影为统一 `EvidenceRef`，不要让各工具自行拼最终回答。

## 7. 必须保持的安全边界

- 无授权 evidence 不是空结果，要作为明确失败或“数据不足”。
- citation source 只回同源、owner 校验后的 BFF URL。
- resume token 原子消费后不可重用。
- SSE 必须先订阅再 snapshot/replay，并按 durable event ID 去重。
- checkpoint 不存 secrets、长正文、完整 event history。
- service identity 与 delegated actor 分开；后者不能扩大前者 scope。
- SQL 工具使用只读数据库身份、statement timeout、row/byte cap、strict semantic model allowlist。

## 8. 验收门禁

1. Worker 在每个副作用前后 SIGKILL，恢复后副作用仍至多一次。
2. resume transport 失败后 token 永久失效且 Run 终态可解释。
3. Redis 在订阅/回放窗口注入事件，不丢不重 durable event。
4. 动态 graph patch 的环、越深、越预算、越工具权限全部被拒绝。
5. 子 Agent 只能返回 DTO/ref，不能把正文塞进 graph state。
6. Wren/Knowledge 超时、授权、协议、数据不足分别映射稳定 error code。
7. tenant A 的 MDL、memory、evidence、artifact 不能被 tenant B 命中。

## 源码索引

- Run 状态与预算：[runtime.py](/home/zymun/master/investment-app/investment-backend/app/app/domain/agent/runtime.py:10)
- graph state 边界：[state.py](/home/zymun/master/investment-app/investment-backend/app/app/infrastructure/graph/state.py:1)
- Pilot orchestration：[pilot_agent_graph.py](/home/zymun/master/investment-app/investment-backend/app/app/tasks/pilot_agent_graph.py:79)
- v4 worker：[agent_graph.py](/home/zymun/master/investment-app/investment-backend/app/app/tasks/agent_graph.py:44)
- resume 原子消费：[pilot_service.py](/home/zymun/master/investment-app/investment-backend/app/app/application/agent/pilot_service.py:100)
- SSE 订阅/回放：[agent_routes.py](/home/zymun/master/investment-app/investment-backend/app/app/interfaces/endpoints/agent_routes.py:154)
- 工具结果投影：[tool_result_handlers.py](/home/zymun/master/investment-app/investment-backend/app/app/application/agent/tool_result_handlers.py:1)
