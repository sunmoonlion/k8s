# Investment App Agent 开放总体架构可行性分析

> 最后更新：2026-09-02
>
> **性质：架构决策输入，不是已批准规范，不登记实施状态。**
>
> 本文评估一种开放执行架构：Investment Backend 建立统一 Supervisor，接收前端
> Task；通用任务经官方 SDK 交给 Codex，财务等专业任务经官方 SDK 交给基于
> DeepSeek Harness Profile 构建的专业 Agent。
>
> 权威边界仍是：代码约束见 [`constraints.md`](constraints.md)，目标方向见
> [`development-plan.md`](development-plan.md)，产品 Task 合同见
> [`working/request-lifecycle.md`](working/request-lifecycle.md)，当前状态与未决项见
> [`handoff.md`](handoff.md)。本文被人批准并吸收进权威文档前，不改变其中任何结论。

## 1. 结论

总体方案**有条件可行**：

- 这次更新本质上是“自研边界校正”：继续自研 Investment 业务控制面，停止重复自研
  通用模型循环；目标架构优于原体系，但当前生产成熟度尚未超过已有链路；
- OpenClaw Gateway 的确定性 binding、agent/runtime 分层、capability contract、
  fail-closed 和运行准入值得借鉴，但它不是财务/通用语义路由器，不适合整体替代
  Investment 的 BFF、Task Supervisor、PostgreSQL 主档或多租户边界；
- Investment 自建 Supervisor 与 Task 控制面是可行的；
- Codex 当前 Python SDK 已基本具备作为通用执行器的必要控制能力；
- DeepSeek Harness 的 Profile / Plugin 架构适合承载财务等专业 Agent；
- 但 DeepSeek Harness 当前 SDK wire 控制面不足，尚不满足生产所需的逐 Turn 结果、
  取消、恢复、逐 Session 关闭和可信逐 Task 安全上下文；
- Investment 当前 Pilot 与 Agent v4 是两条重叠运行链，不能在其旁边继续增加第三、
  第四条状态链；
- 因此应先建立唯一 Task/Attempt 内核和统一执行 Port，再接 Codex，最后在
  DeepSeek Harness SDK 门禁通过后接专业 Agent 与 Supervisor 路由。

一句话目标态：

> Investment 拥有 Task、权限、路由、预算、证据、验收和交付；Codex 与 DeepSeek
> Harness 只拥有各自 Attempt 内的模型执行，通过 SDK 被租用，不成为业务真源。

若绕过 DeepSeek Harness SDK 缺口，改为直接调用 Cordis 内部服务、私有 JSON-RPC
或用“杀整个子进程”冒充业务取消，虽然能做出 Demo，但不满足本项目的产品合同，
不进入实施方案。

## 2. 研究范围与证据基线

### 2.1 本轮直接读取

| 对象 | 本地提交 | 主要核对面 |
| --- | --- | --- |
| DeepSeek Harness | `dd6322d604e00eec1ba5e0c8541159906a21094a` | 架构、Profile/Bundle、Agent/Session、SDK protocol/server/client、Python SDK、持久化与事件 |
| Codex | `7d6f808b97e424da80271be8cc539e8c5437a229` | Python/TypeScript SDK、app-server 门面、Thread/Turn 生命周期、事件、取消、恢复、沙箱与批准 |
| OpenClaw | `173f41d682b0d4a05674820a3d390d934da8b066` | Gateway 控制面、确定性 channel binding、SessionKey、agent/runtime 分层选择、harness registry、运行准入与多租户边界 |
| Investment 父仓 | `f8fbcf678aec3e6b2b118ecc0faaf9b912819baf` | 仓边界与子模块关系 |
| Investment Backend | `18d88c7c7dd2c737fb9e7057e5ed46f0fd9a991d` | Pilot/v4 两条链、Run/事件/副作用、Celery、SSE、前端交互契约与迁移 |

同时对读 `~/codex-reference-archive/` 的 28 份历史研究，以及本分支
`~/codex-reference-archive/` 的 Codex、Investment、沙箱、SQLBot 和
WrenAI 材料。历史材料用于发现应核对的问题，不替代当前源码证据。

### 2.2 证据等级

本文只用以下措辞：

- **已实现**：当前源码与测试能直接证明；
- **当前限制**：当前公开 SDK/协议明确没有，或文档列为限制；
- **建议**：目标架构判断，不描述现状；
- **待决定**：会改变权限、成本、合同或部署形态，必须由人批准。

没有运行真实模型、没有连接生产数据库或集群，因此本文不证明模型质量、吞吐、成本、
集群资源或真实故障恢复已经达标；这些是实施前门禁，不是静态读码可以替代的事实。

## 3. 约束自检

| 规则 | 本方案结论 |
| --- | --- |
| A1 通用/专用两分，新增业务 Agent 优先 Profile | ✅ Supervisor/通用执行与专业 Profile 分离；财务 Agent 是 Harness Profile，不 fork runtime |
| A2 两边都有纪律 | ✅ 通用与专业 Attempt 共用权限、预算、证据、验收、取消和交付合同 |
| A3 四本账落 PostgreSQL | ✅ 外部 harness 的本地日志只作执行资料，不承载跨进程不变量 |
| A4 执行层租用且只依赖 SDK | ✅ 两个 adapter 只依赖官方 Python SDK；不依赖 app-server 或 Harness 私有协议 |
| A5 Port 不含领域概念 | ✅ 统一 Port 使用 ExecutionRequest/Event/Binding；财务概念只在 Profile 和工具 DTO |
| C1 长耗时走事件 | ✅ 建单与查询走同步 API；执行、进度和完成走 Outbox/事件/SSE |
| I1 Admin/Web/Internal 共享 application 用例 | ✅ 三个接口面进入同一个 TaskApplicationService，只在 interface 层分身份 |
| I3/I5 服务身份与浏览器身份隔离 | ✅ BFF 解析浏览器会话，Backend 重验所有权；worker 与专业工具使用服务身份 |
| T2/T3 一个规范 Backend、按运行角色部署 | ✅ Supervisor、adapter、worker 都在 Investment Backend；不同 worker 不是新领域 Backend |
| D1 单一主档 | ✅ Task/Attempt/四本账以 Investment PostgreSQL 为唯一业务主档 |

本方案不改变 App 领域边界，不新增独立“Agent App”，也不让 Next.js 成为 Task 或
Agent 数据所有者。

## 4. 当前实现的可复用基础与结构性缺口

### 4.1 已有基础

Investment 已具备不少可复用骨架：

- FastAPI、Celery Worker、PostgreSQL、Redis、LangGraph/PostgresSaver；
- `agent_sessions`、`agent_runs`、`session_events`、`tool_side_effects`；
- Run 状态转换与幂等建 Run；
- Redis session lock；
- DB durable event + Redis 低延迟通知 + SSE 回放；
- Pilot 的知识检索、citation、HITL、取消意图和前端交互合同；
- `AgentProfile`、工具 allow/deny、memory policy 的模型；
- Transactional Outbox/Inbox 基础表。

这些证明“平台能承载 Agent Task”，但不等于目标 Task 内核已经存在。

### 4.2 两条重叠链

当前生产相关代码至少有两条链：

```text
Admin Agent v4
  AgentRunService
    -> app.tasks.agent_graph.run
      -> walking_skeleton + DBEventSink + session lock + side-effect ledger

Web/Internal Pilot
  PilotService
    -> app.tasks.pilot_agent_graph.run
      -> knowledge retrieval + LLM + LangGraph HITL + browser event stream
```

它们分别拥有部分 Run、resume/cancel、event、repository 和前端投影语义。继续在旁边
加入 `codex_task.py` 与 `deepseek_task.py` 会产生四套状态与恢复路径，后续无法证明
Task 终态、取消竞争、预算和事件回放一致。

### 4.3 当前 `run` 不是目标 Task

产品合同已经要求 Task 与 Attempt 分层：

- Task 表达用户目标、完成契约、总预算、结果与唯一业务终态；
- Attempt 表达一次执行器运行、租约、runtime/profile 版本、checkpoint、消耗和失败；
- Attempt `COMPLETED` 只表示产生候选结果，不自动使 Task `SUCCEEDED`。

现有 `agent_runs` 可以作为迁移输入或 Attempt 的一部分，但不能继续同时承担两层职责。

### 4.4 四本账现状

| 账 | 当前情况 | 目标缺口 |
| --- | --- | --- |
| 幂等 | 已有 run/pilot idempotency key | 需要 `tenant + requester + task_profile + key + request_digest` 的 Task 级唯一性与异载荷冲突 |
| 副作用 | `tool_side_effects.record_once` 已接线 | 需要目标、意图、状态、回执、补偿、Attempt 与 fencing |
| 预算 | 只有内存 `RunBudget` | 必须持久化 Task 总额、Attempt 预留/已用/释放、子 Task 共摊与追加批准 |
| 证据 | citation 存在于 Pilot 事件 | 必须持久化 claim/source/as-of/transformation/producer/validator，事件不是证据主档 |

## 5. 两个执行 SDK 的可行性

### 5.1 Codex Python SDK

当前 Codex Python SDK 已实现：

- 同步与异步客户端；
- `thread_start/list/read/resume/fork/archive/unarchive`；
- Turn `run/stream/steer/interrupt`；
- token usage 与结构化 `output_schema`；
- read-only/workspace-write/full-access sandbox；
- developer instructions、模型与 effort 选择；
- SDK 钉版 runtime 二进制。

因此 Codex 可以作为第一种外部执行器，但仍有平台侧限制：

1. SDK 的 Thread 不是 Investment Task；Thread ID 只能进入 executor binding；
2. 默认批准行为不能替代产品 HITL；首版使用 deny-all，高风险动作由 Investment
   Interaction 放行；
3. 通用 worker 不得拥有财务数据库或 Knowledge 服务凭据；
4. `CODEX_HOME` 与 workspace 需要显式生命周期和租户隔离；
5. Codex rollout 丢失时，平台必须能从 Task Artifact 创建新 Attempt，不能把本地
   Thread 当唯一恢复源；
6. Codex SDK 的 async 实现内部包装同步客户端，worker 并发、线程和关闭行为必须实测。

判定：**满足接入 Spike 和首个只读通用 Agent 的条件，不等于未经测试即可投产。**

### 5.2 DeepSeek Harness 的适配优势

DeepSeek Harness 的强项与专业 Agent 高度匹配：

- 全插件 Cordis 架构；
- Profile + Bundle + patch 组合，不必 fork runtime；
- model、tools、session、agent-loop、sandbox、subagent、compaction 都有 capability seam；
- append-only SessionEvent 是模型上下文和回放源；
- SDK profile 可由 Python SDK 启动；
- session event、agent status、subagent start/finish 可流式投影；
- Python wheel 可以携带同版本 runtime。

这使财务工具、证据工具、Artifact 工具、结果提交工具可以作为插件挂入专用 Profile，
而不是修改 Agent loop。

### 5.3 DeepSeek Harness 当前 SDK 的阻塞缺口

当前公开 wire 只有：

```text
initialize
session/prompt
shutdown
```

当前限制包括：

- 没有逐 Session close；
- 没有 prompt/Turn cancel；
- 没有 Turn ID 与逐 prompt 结果归属；
- 没有 session read/resume/list；
- SDK server 对未知 session 调 `ctx.agents.create()`，没有走持久 session resume；
- initialize 的 cwd/provider/model/maxTokens 是进程级配置；
- session prompt 不能选择 per-session Agent preset；
- wire 没有模型不可篡改的 tenant/actor/permissions/policy version/dataset binding；
- Python 高层 API 是同步阻塞接口；
- 结构化结果没有与 Codex `output_schema` 对等的逐 Turn SDK 参数。

这些缺口直接阻塞：

- `F-EXEC-03` 每次高风险动作重新授权；
- `F-EXEC-05` 进程死亡后的 checkpoint 恢复；
- `F-INTERACT-*` 等待、批准与恢复；
- 取消意图、fencing 和唯一终态竞争；
- 多租户专业工具的可信授权；
- SDK Attempt 与 Task 事件的稳定因果绑定。

判定：**Harness runtime 适合专业 Agent，当前 Harness SDK 尚不适合直接承担生产
Attempt 控制面。**二者不能混为一个结论。

## 6. 目标总体架构

```text
Browser
  -> Next.js same-origin BFF
      -> FastAPI Task API
          -> TaskAdmissionService
              -> identity / authorization / idempotency / contract
              -> PostgreSQL transaction
              -> Transactional Outbox
          -> TaskSupervisor
              -> RoutePolicy
                  -> deterministic rules
                  -> bounded structured classifier
                  -> Interaction when ambiguity changes risk/cost/result
              -> AttemptScheduler
                  -> general queue -> CodexExecutorAdapter -> Codex SDK
                  -> finance queue -> HarnessExecutorAdapter -> Harness SDK

SDK event streams
  -> ExecutionEventNormalizer
      -> Task/Attempt/Event + four ledgers in PostgreSQL
          -> projection
              -> Redis notification
                  -> SSE cursor replay
```

### 6.1 所有权

| 能力 | 所有者 |
| --- | --- |
| 用户 Task、Task Profile、完成契约 | Investment |
| 身份、租户、授权、路由政策 | Investment |
| Task/Attempt 状态机、租约、fencing、重试 | Investment |
| 四本账、Artifact、Interaction、Delivery | Investment PostgreSQL |
| 一次模型 Turn、provider 原生工具循环 | 对应外部执行器 |
| 专业模型提示、专业工具与工具约束 | Harness Agent Profile + Investment tool adapters |
| 最终验收与 Task `SUCCEEDED` | Investment validator；需人工终审的仍由人批准 |
| 浏览器投影 | Next.js 消费后端事实，不拥有领域状态 |

## 7. Supervisor 设计

### 7.1 Supervisor 不是第三个自由 Agent

Supervisor 应是 application 层 `TaskSupervisor` / `TaskOrchestrator`，而不是一个拥有
全部工具、长期运行、靠自然语言自由派活的大模型会话。

理由：

- 路由必须可重放、可解释、可评估；
- LLM 路由不能扩大权限；
- 预算、租约、取消和重试属于确定性控制面；
- Supervisor 进程死亡不能丢失调度决定；
- 直接让 Agent 调 SDK 会把业务控制藏进对话历史；
- Task 验收不能由产出候选结果的同一主体自我批准。

Supervisor 可以使用一个分类模型，但分类只是受限节点，不拥有队列和执行器。

### 7.2 路由顺序

1. **显式约束**：用户或调用方选择了获准 Task Profile；
2. **确定性政策**：按所需能力、数据源、输出合同和安全等级匹配；
3. **结构化分类**：无工具、低预算、固定 schema，输出候选 route/reason/confidence；
4. **政策复核**：验证候选执行器是否有权限、容量、Profile 和预算；
5. **歧义处理**：若路由会改变权限、成本、数据范围或完成含义，建立 Interaction；
6. **持久化决定**：RouteDecision 与 Task/Attempt/Outbox 在可靠边界内提交。

不允许“分类失败一律发 Codex”或“看到财务关键词一律给财务库权限”。

### 7.3 初始路由边界

| Task | 初始 route | 说明 |
| --- | --- | --- |
| 通用阅读、总结、方案、代码/仓库分析 | `general/codex` | 默认只读，无财务服务身份 |
| 财报分析、财务指标、估值、现金流、结构化财务数据 | `finance/harness` | 必须匹配专业 Task/Profile、数据权限与证据合同 |
| 投资交易、下单、写外部系统 | 不在首版 | 必须另立 ACTION Task Profile、批准与补偿合同 |
| 混合任务 | Supervisor 拆子 Task 或询问用户 | 父预算与权限不能被子 Task 放大 |
| 无法满足证据/权限/能力 | `ask_user` 或 `reject` | 不得伪造完整结果 |

### 7.4 RouteDecision

至少持久化：

```text
task_id
route_kind
task_profile_id / version
agent_profile_id / version
executor_id / runtime_version
reason_codes
classifier_model / version / confidence
policy_version
decided_by
decided_at
```

自然语言解释可以作为辅助字段，不能成为唯一机械判据。

## 8. 统一执行 Port

建议 application 层只依赖：

```python
class AgentExecutorPort(Protocol):
    async def capabilities(self) -> ExecutorCapabilities: ...
    async def start(self, request: ExecutionRequest) -> ExecutionBinding: ...
    async def resume(self, binding: ExecutionBinding, input: ExecutionInput) -> None: ...
    async def cancel(self, binding: ExecutionBinding, reason: CancelReason) -> None: ...
    async def events(
        self, binding: ExecutionBinding, cursor: ExecutionCursor | None
    ) -> AsyncIterator[ExecutionEvent]: ...
    async def inspect(self, binding: ExecutionBinding) -> ExecutionSnapshot: ...
```

### 8.1 通用 DTO

`ExecutionRequest` 只承载：

```text
attempt_id
profile_ref
workspace_ref
input_artifact_refs
completion_contract
budget_allocation
security_context_ref
deadline
```

`ExecutionBinding` 只承载 opaque provider identity：

```text
executor_id
provider_session_id
provider_turn_id
runtime_version
binding_version
```

Port 不出现 portfolio、ticker、financial statement 等领域概念。专业语义存在于
Task Profile、Artifact schema 和财务工具 DTO。

### 8.2 Adapter 职责

Adapter 只负责：

- 将通用请求映射到公开 SDK；
- 保存/读取 opaque binding；
- 把 SDK event 映射为统一 ExecutionEvent；
- 正确关闭 SDK runtime；
- 将 SDK 错误映射为稳定 failure code；
- 暴露能力而不是假装两边功能完全对称。

Adapter 不负责 Task 状态机、路由、授权决策、验收或四本账。

## 9. DeepSeek Harness SDK 前置门禁

要让专业路线进入实施，建议先在 DeepSeek Harness 正式公开 SDK 中补齐：

```text
session/start
session/resume
session/read
session/close

turn/start        -> stable turn id
turn/read
turn/steer
turn/cancel

session/events(after_seq)
```

`session/start/resume` 还需携带模型不可见、模型不可改的 trusted execution context：

```text
task_id / attempt_id
tenant_id / actor_id
authorization_policy_version
allowed_capabilities
dataset_bindings
evidence_policy
deadline
```

同时需要：

- per-session preset/profile 选择；
- 逐 Turn completion correlation；
- 明确 cancel 后的 durable turn-end；
- Python async 或经证明的非阻塞包装；
- TypeScript/Python SDK 协议镜像与 expected-output 同步；
- crash/restart、cancel race、resume、close、malformed wire 测试；
- 一个能力查询，让 Investment 在 dispatch 前 fail-closed。

必须在 Harness 仓通过正式 SDK 实现，不能由 Investment 私自复制协议类型或 import
Harness 内部包。若 Harness 不接受这些能力，则专业执行器应保持 `unavailable`，而不是
在 Investment 内永久维护一个私有 fork。

## 10. 财务专业 Agent Profile

### 10.1 首个 Profile

首版建议只建一个窄 Profile：

```text
investment-finance-analysis-v1
```

它是 Harness Profile/patch 加 Investment 专业插件，不修改 Agent loop。

### 10.2 初始工具

| 工具 | 作用 | 安全边界 |
| --- | --- | --- |
| `knowledge_retrieve` | 获取非结构化证据 | dataset/tenant/actor/policy 每次重验；引用同源 |
| `financial_dry_plan` | 规划受管查询但不执行 | 只产生可审计计划 |
| `financial_query` | 执行结构化财务查询 | 只读数据库角色、行数/时限/模型白名单 |
| `artifact_write` | 保存大结果与报告 | 对象存储按领域隔离，只返回引用 |
| `evidence_record` | 提交 claim/source/as-of/transformation | 写入 Investment 证据账，不只写 Harness log |
| `submit_result` | 提交版本化候选结果 | 严格 schema；未提交不算 Attempt completed |

任意 Python/shell 若后续开放，应走独立沙箱与网络政策，不与受管 SQL 通道合并。

### 10.3 凭据

- 数据库与 Knowledge 凭据不能进入 prompt、普通环境回显或工具结果；
- Agent 只拿 opaque capability，host plugin 解析可信 execution context；
- 财务 worker 不持有 Codex/OpenAI 凭据；
- Codex worker 不持有财务库、Knowledge 或其他专业服务凭据；
- 每次工具调用重新检查当前授权，不能只在 Task 开始时检查一次。

### 10.4 结果合同

专业 Agent 的最终候选结果至少区分：

```text
facts
inferences
assumptions
unknowns
claims[]
evidence_refs[]
data_as_of
limitations[]
uncertainty
artifact_refs[]
```

`submit_result` 成功只使 Attempt 获得候选产物。Investment validator 仍需检查 schema、
Task acceptance、证据、新鲜度、权限和副作用，再决定 Task 是否成功。

## 11. 持久化模型

目标至少需要以下逻辑记录；具体是否一表一记录由 U3/后续 schema 设计决定：

```text
Task
TaskEvent
Attempt
RouteDecision
ExecutorBinding
Interaction
Artifact
EvidenceClaim
IdempotencyLedger
BudgetLedger
SideEffectLedger
Delivery
```

关键不变量：

1. Task 与 Attempt 终态不可转出；
2. 同一 Task 的外部执行重试创建新 Attempt；
3. worker 只有持有效 lease/fencing 才能提交进度、结果或副作用；
4. Task 总预算覆盖全部 Attempt、子 Task、模型和工具；
5. SDK thread/session 日志不替代证据账和副作用账；
6. provider 完成不等于 Task 成功；
7. 取消先持久化意图，再终止执行、检查副作用、CAS 提交唯一终态；
8. Provider session 丢失时可以基于 Task/Artifact 建新 Attempt，不能丢失业务事实。

## 12. 统一事件与前端交付

### 12.1 事件标准化

不能把 Codex notification 或 Harness SessionEvent 原样作为浏览器合同。统一事件至少包括：

```text
attempt.started
attempt.waiting
attempt.completed
attempt.failed
output.delta
assistant.message
tool.started
tool.completed
tool.failed
artifact.created
evidence.recorded
interaction.required
budget.updated
subtask.started
subtask.completed
```

每条事件带：

```text
event_id
task_id
attempt_id
sequence_no
payload_schema_version
executor_id
provider_session_id
provider_turn_id
occurred_at
visibility
```

原始 provider payload 可以去敏后作为内部诊断附件保存，但不是前端稳定契约。

### 12.2 顺序

```text
SDK event
  -> deduplicate by provider identity
  -> persist PostgreSQL event
  -> update projection
  -> publish Redis notification
  -> SSE/WebSocket low-latency delivery
```

Redis 不是结果载体。客户端仍采用 cursor、sequence gap 检查、去重和 snapshot
reconcile。流式 token 是中间 Delivery，不构成 `SUCCEEDED`。

### 12.3 前端迁移

现有 Web 交互契约已经有 `event_id`、`sequence_no`、cursor、gap 和 duplicate 处理，
可作为迁移基础。目标需要：

- 外部主键从 `run_id` 明确升级为 `task_id`；
- 事件显式区分 `task_state` 与 `attempt_status`；
- snapshot 能展示 route、专业能力、等待原因和稳定最终结果；
- provider 细节仅在允许的诊断视图展示；
- Web/Admin/Internal 继续共享 application use case。

## 13. 部署与进程模型

仍保持一个 Investment Backend 仓和一个不可变 backend 镜像，按角色部署：

```text
investment-api
investment-worker-general
investment-worker-finance
investment-scheduler
investment-migration
```

两个 worker 是同一 Backend 的不同运行角色，不是新领域服务。拆分依据已经存在：

- 服务身份不同；
- Secret 与网络出口不同；
- Codex workspace 与财务数据通道攻击面不同；
- runtime 资源、任务时长、取消和扩缩容指标可能不同。

若 Spike 证明同一通用 Worker 足以隔离，也可先使用不同 Celery queue 但同一 Worker
Deployment；从共享到拆分必须以身份、NetworkPolicy、资源和故障数据决定，而非框架偏好。

### 13.1 SDK 进程纪律

- SDK runtime 不得在 Celery prefork 前创建；
- SDK client/process 不跨 fork 共享；
- 每个 Attempt 的 runtime owner、PID/session/thread 与关闭结果可追溯；
- worker SIGTERM 先停止领取新任务，再取消/收敛 active Attempt；
- SDK 子进程必须有资源上限、deadline 和 teardown ladder；
- runtime stdout/stderr 去敏，不能进入普通用户事件；
- 本地 Harness/Codex home 只作可重建执行资料，不作 App 间交换协议。

## 14. 安全模型

### 14.1 Supervisor

- 路由只选择获准能力，不能扩大原 Task 权限；
- 分类模型无工具、无凭据、无数据库访问；
- 检索文本、附件和其他 Agent 输出一律作为数据，不作为控制指令；
- 置信度不足且影响权限/成本/完成含义时必须问人；
- RouteDecision 版本化、可审计、可回放。

### 14.2 Codex 通用执行器

- 首版 `deny_all` 批准模式；
- 默认 read-only workspace；
- 写任务使用独立 workspace/沙箱与明确 writable roots；
- 不挂财务专业凭据；
- 不允许 provider 自动批准替代 Investment Interaction；
- Thread resume 前重新验证 Task/Attempt/actor/tenant 绑定。

### 14.3 Harness 专业执行器

- trusted execution context 不进入模型消息；
- profile 工具集默认拒绝，按 Task/Profile/权限显式开放；
- 受管 SQL 使用只读角色、AST/语句类型/模型白名单和结果上限；
- 任意代码与 SQL 使用不同威胁模型和沙箱；
- 所有 claim 与数字必须有关联证据、时点和 transformation；
- 子 Agent 继承收窄后的权限和父预算预留，不能获得新额度或更宽工具。

## 15. 失败与恢复语义

| 故障 | 目标处置 |
| --- | --- |
| SDK 启动失败 | Attempt `FAILED`/retryable；Task 按策略重新排队或失败 |
| Provider 过载 | 有界退避；同 Attempt 是否重试按 SDK 语义，不能重复副作用 |
| Worker 被杀 | lease 到期、fencing 旧 writer；按 checkpoint 能力恢复或创建新 Attempt |
| Provider session 丢失 | 不伪造 resume；从 Task/Artifact 建新 Attempt，并保留旧 Attempt 失败记录 |
| 用户取消与完成竞争 | 先持久化取消意图；唯一 CAS 终态；迟到结果因 fencing 被拒绝 |
| SSE 断开 | 按 cursor 从 PostgreSQL 回放，不影响 Task 终态 |
| 结构化结果不合格 | Attempt 可 completed，但 validator 失败；预算允许才创建新 Attempt |
| 证据不合格 | 不得 Task success；请求补充、换 Attempt 或明确失败 |
| 高风险动作待批准 | 建 Interaction；没有有效批准不执行 |
| Harness 不支持所需控制 | capability check fail-closed，不降级到裸协议或进程杀死模拟 |

## 16. 分阶段路径

### Gate 0 · SDK 可行性 Spike

目标：在改变产品路由前证明两个官方 SDK 真能承担 Port。

必须验证：

- Codex start/stream/output schema/interrupt/restart-resume；
- Codex `CODEX_HOME`、workspace、凭据与多租户隔离；
- Harness 补齐的 start/resume/read/close/turn cancel/trusted context；
- Harness 自定义 Profile、专业 fake tool 与结构化 `submit_result`；
- 两边 SDK subprocess 在 Celery prefork worker 内的启动和关闭；
- 运行时被 kill、网络中断、重复投递和取消竞争；
- 同一 capability contract 的 fake adapter tests。

退出条件：能力矩阵中所有 P0 能力均有自动测试；Harness 缺项未补齐则专业路线保持
blocked，不能进入下一阶段。

### Phase 1 · 唯一 Task 内核

- 建 Task/Attempt/lease/fencing/Interaction/四本账；
- 收口 Pilot/v4 的 application use case、状态、事件、取消与恢复；
- 接通 Transactional Outbox 与重复消息幂等；
- 前端从 Run 投影迁移到 Task 投影；
- 此阶段使用 fake executor，不依赖真实模型。

### Phase 2 · Codex 通用执行器

- 实现 `CodexExecutorAdapter`；
- 只开放 read-only、无外部副作用的通用 Task Profile；
- 完成事件映射、结构化结果、预算扣减、取消和恢复；
- 通过 failure injection 后再扩大工具能力。

### Phase 3 · Harness 财务执行器

- 发布 `investment-finance-analysis-v1`；
- 接入受管知识/财务查询、Artifact、证据和结果提交工具；
- 建 20–50 道金标准财务问题和证据质量门禁；
- 验证权限、数据时点、引用、成本和恢复；
- 未达到准确率和证据阈值时不进入自动路由。

### Phase 4 · Supervisor 路由

- 先上确定性规则，再上结构化分类；
- 持久化 RouteDecision；
- 支持 ask-user、reject 与混合 Task 拆分；
- 监控误路由率、人工改路由率、验收通过率、成本、延迟和失败率；
- 只有有评测数据后才允许自动路由扩大覆盖面。

## 17. 测试与验收矩阵

| 层 | 必测内容 |
| --- | --- |
| L1 Unit | RoutePolicy、状态转换、预算 reservation、validator、event mapping、错误映射 |
| L2 Component | 两个 adapter 对 fake SDK runtime；Task/Attempt repository；outbox/inbox |
| L3 Contract | SDK 公开 API 签名/版本、前后端 DTO、ExecutionEvent、Profile 工具 schema |
| L4 Cross-app E2E | Browser→BFF→Backend→Worker→Knowledge/财务 fake→SSE→结果读取 |
| L5 Failure Injection | kill runtime/worker、重复消息、锁/lease 过期、取消竞争、SSE 重连、provider overload |
| L6 Evaluation | 路由混淆矩阵、财务金标准、citation/数字可追溯、结构化结果通过率 |
| L7 Deployment | 镜像 runtime、Secret/ServiceAccount、NetworkPolicy、资源、优雅终止、回滚 |

首版验收至少包括：

1. 同幂等键同摘要只产生一个 Task，异摘要冲突；
2. 通用/财务 route 可解释、可回放、不能扩大权限；
3. Provider 完成但验收失败时 Task 不成功；
4. Task 总预算覆盖所有 Attempt 和子 Agent；
5. worker/SDK 被杀后不丢 Task、账、证据和已发生副作用；
6. 取消与完成竞争只有一个业务终态；
7. SSE 断开后 cursor 回放无丢失、无重复副作用；
8. Codex worker 无财务凭据，财务 worker 无 Codex 凭据；
9. 每个财务数字能指向 source、as-of、transformation 和 Attempt；
10. Harness SDK 缺失能力时系统明确 unavailable，不走私有协议降级。

## 18. 主要风险与取舍

| 风险 | 影响 | 控制 |
| --- | --- | --- |
| 两家 SDK 生命周期不对称 | 统一 Port 被迫伪装能力 | capabilities + fail-closed；Harness 先补正式 SDK |
| 外部 runtime 本地状态丢失 | 无法原 Attempt 恢复 | PostgreSQL/Artifact 是业务真源；必要时新 Attempt |
| Supervisor 误路由 | 成本、权限或结果合同错误 | 规则优先、结构化分类、ask-user、混淆矩阵 |
| 专业 Agent 获得过宽工具 | 数据泄漏或副作用 | trusted context、host-side auth、profile deny-by-default |
| 多 Agent fan-out 放大预算 | 成本失控 | 父 Task 总账 + reservation，不给子 Agent新额度 |
| provider 事件污染前端合同 | 升级即破坏消费者 | normalization + versioned platform events |
| Celery 内管理子进程复杂 | 僵尸、关闭不全、容量失控 | prefork 后创建、owner/teardown、并发与资源门禁 |
| 双 provider 依赖增加镜像面 | 构建与 CVE 面扩大 | 钉版 runtime、SBOM、同镜像不同身份；有证据再拆 |
| 财务质量被架构掩盖 | 系统完整但答案不准 | L6 金标准先于自动路由与扩大覆盖 |

## 19. 新架构是否比原自研体系更合理

### 19.1 先界定比较对象

这里的“原架构”和“新架构”不能简化成“LangGraph 对 SDK”或“自研对外购”。真正的
边界变化是：

| 层 | 原体系的实际倾向 | 新体系的目标 |
| --- | --- | --- |
| 业务控制 | Investment 自己维护 Run、图、事件、HITL、交付 | Investment 继续拥有 Task、Attempt、权限、预算、证据、验收与交付 |
| 通用 Agent loop | Investment/LangGraph 自己编排模型、工具和状态 | 租用 Codex SDK 的原生 Thread/Turn 与工具循环 |
| 专业 Agent loop | 在 Investment 内继续长出专业节点和工具 | 租用 DeepSeek Harness Profile，专业能力以 Profile/Plugin 组合 |
| 跨执行器调度 | 没有统一边界，Pilot 与 v4 已经分叉 | 一个 TaskSupervisor、一个执行 Port、多个能力不对称的 adapter |
| 业务真源 | PostgreSQL 已承担一部分，但 Run/checkpoint/event 语义分散 | PostgreSQL 明确成为 Task/四本账/交付的唯一业务真源 |

因此新架构不是“放弃自研”，而是一次**自研边界校正**：不再自研通用模型循环和
provider 运行时，但保留且强化只有 Investment 才能正确拥有的业务控制面。

### 19.2 判断

结论分三层：

1. **架构方向：更合理，也优于原体系。**原体系正在重复建设通用 agent runtime，
   同时 Pilot/v4 已出现状态、事件和恢复语义分叉。把通用执行租给 Codex、把专业执行
   租给 Harness Profile，能把工程投入移回 Task 合同、财务证据、权限和验收。
2. **当前生产成熟度：尚未优于原体系。**旧链至少已有可运行路径；新方案目前仍缺唯一
   Task/Attempt 内核，DeepSeek Harness SDK 也缺取消、恢复、读取和可信逐 Task 上下文。
   在这些门禁完成前，新方案只是更好的目标态，不是更成熟的现状。
3. **满足门禁后的目标态：整体更好。**它会减少重复 runtime 代码，提高 Codex 与
   Harness 原生能力的升级速度，并让财务能力以 Profile 演进；代价是增加双 runtime
   运维、版本不对称和外部 SDK 兼容性工作。

简要比较如下：

| 维度 | 原体系 | 新体系 | 判断 |
| --- | --- | --- | --- |
| 业务状态一致性 | Pilot/v4 分叉，容易继续长出新链 | 统一 Task/Attempt/Outbox | 新体系明显更好，但必须先收口 |
| 通用 Agent 能力 | 自己追赶工具循环、上下文、恢复和模型变化 | 直接使用 Codex 原生能力 | 新体系更好 |
| 财务专业化 | 容易把领域逻辑写进通用图和 Backend | Profile/Plugin + 受管领域工具 | 新体系更可演进 |
| 可靠性 | 能完全掌控，但当前语义并未统一 | 平台可靠性 + 外部 runtime 可靠性两层 | 有条件更好，adapter 必须 fail-closed |
| 安全 | 自研路径少但边界易混 | 执行器隔离更清晰，但 SDK 子进程和凭据面增加 | 取决于身份、工具和 workspace 隔离是否落实 |
| 可观测性 | 原生事件较容易掌控，但两条链不一致 | 必须归一两家事件，provider 内部不完全可见 | 初期更难，统一后更好 |
| 维护成本 | 长期承担通用 runtime 演进 | 转为 SDK 钉版、兼容和双 runtime 运维 | 总体下降，但不会降为零 |
| 锁定风险 | 锁定自研实现与历史状态 | 锁定两个 SDK 的公开合同 | 可通过统一 Port 与 Artifact 恢复降低 |
| 故障面 | 单栈但已有重复链 | 多一个 runtime 家族和子进程生命周期 | 新体系更复杂，必须用能力矩阵和故障注入控制 |

### 19.3 “更好”成立的硬条件

只有同时满足以下条件，才可以在工程上宣称新架构比旧架构更好：

- Supervisor 消费的是已经持久化的 Task，而不是直接拿前端请求启动 SDK；
- Pilot、v4 和新执行器收口到同一个 Task/Attempt 状态机，不保留三套终态；
- Investment PostgreSQL 始终拥有业务真源，Codex Thread、Harness Session 和本地日志
  只作为可丢失、可重建的 executor binding；
- 外部 SDK 只通过稳定 Port 接入，能力不对称要显式表达，缺能力时拒绝而不是伪装；
- 财务权限由服务端 Task/Agent Profile 授予，分类模型和外部 runtime 都不能自行扩大；
- 确定性财务步骤、预算、HITL、ACTION 和验收仍由平台控制，不迁入自由对话历史；
- 每一类 route 都有离线评测、线上指标、回滚和人工纠错入口；
- Provider 完成与 Task 成功严格分离，结果必须经过结构、证据和业务 validator。

如果“新架构”被理解成让某个 SDK 内的 agent 兼任 Supervisor、直接拥有 Task 终态、
预算、财务凭据和重试，那么它反而比原体系更差：只是把可见的自研复杂度换成了不可控
的会话内复杂度。

## 20. OpenClaw Gateway 的真实做法与适用边界

### 20.1 它不是语义任务分类器

OpenClaw 当前 Gateway 是一个常驻的**渠道接入与控制面进程**。它复用一个端口承载
WebSocket RPC、HTTP API、Control UI、hooks 和多渠道连接，并由 Gateway 拥有会话
状态和消息交付。

它有两个容易被混称为“路由”的层次：

1. **Channel → Agent 路由**：`src/routing/resolve-route.ts` 按配置 binding 确定性选择
   一个 `agentId`，顺序是 exact peer、parent peer、peer wildcard、guild+roles、guild、
   team、account、channel、default；返回值还带 `matchedBy` 和派生的 `sessionKey`。
2. **Provider/Model → Agent Runtime 选择**：`src/agents/harness/selection.ts` 和
   `docs/concepts/agent-runtimes.md` 把 provider、model、agent runtime、channel 分成
   不同轴；显式 model policy 优先于 provider policy，再到 `auto` capability claim。
   显式 runtime 缺失或不支持时 fail-closed；runtime 已经开始执行后，不把失败的 turn
   悄悄重放到另一 runtime。

这两层都不是“读懂用户问题后判断是财务还是通用”。OpenClaw 的核心路由回答的是
“这个渠道/账号/会话属于哪个 agent”和“准备好的 provider/model route 由哪个 runtime
执行”。如果 Investment 完全转向 OpenClaw，财务/通用语义分类仍然要由 Investment
或另一个上层组件完成。

### 20.2 值得借鉴的内容

| OpenClaw 做法 | Investment 应如何借鉴 |
| --- | --- |
| 渠道路由确定性、分层优先级、返回 `matchedBy` | RoutePolicy 使用稳定规则层级，并持久化命中的规则和候选淘汰原因 |
| `agentId` 与 `sessionKey` 分离 | `AgentProfile`、Task、Attempt 和 executor session 分开建模，不能一串 ID 混用 |
| provider、model、runtime、channel 是正交轴 | 再把“专业 Agent 选择”和“执行器选择”拆成两个决策，不用 `finance/codex` 之类耦合枚举作为核心模型 |
| 显式 runtime 不可用时 fail-closed | 指定 Harness 的财务 Task 不得无声降级给 Codex；若允许替代，必须是显式政策和新 RouteDecision |
| 执行开始后不跨 runtime 自动重放 | retry 只能复用同一已批准执行上下文，换 runtime 必须创建新 Attempt 并重新验权/预留预算 |
| harness registry + capability support contract | `AgentExecutorPort.capabilities()` 返回版本化能力，选择器只在合格候选中决策 |
| host 准备上下文，runtime 只拥有模型 loop | Investment 先固定权限、模型、工具、预算和 workspace，再交给 SDK；runtime 不二次选业务权限 |
| run admission、idempotency reservation、live authority recheck | Task/Attempt 建单、lease/fencing、等待后提交前复核写权限都进入确定性控制面 |
| canonical native thread + host transcript mirror 的所有权说明 | 明确 Codex/Harness 原生会话与 Investment 事件投影的主从关系，不双写成两个业务真源 |
| 来源路由与回复交付分开 | Task 的 requester/delivery projection 与 agent/runtime 选择分开，避免换执行器改变交付目标 |

尤其值得采用的是它的**选择分层和所有权声明**，而不是它的单进程形态。

### 20.3 不应照搬或整体转向的原因

| OpenClaw 假设 | Investment 的现实 | 直接采用的后果 |
| --- | --- | --- |
| 一个 Gateway 是一个受信任 operator domain | Investment 是组织/用户/服务身份并存的 SaaS 边界 | 不能把 session id 或 agent id 当租户授权；需一租户一完整 cell 才接近其安全模型 |
| 核心是聊天渠道、会话连续性和回复回原渠道 | 核心是 durable Task、完成合同、财务证据、预算和验收 | Gateway session 无法替代 Task/Attempt 与四本账 |
| 会话和 agent 状态主要由每 agent SQLite/本地目录拥有 | Investment 规范要求 PostgreSQL 主档、跨副本恢复和 Outbox | 会产生第二状态主档和跨库一致性问题 |
| Gateway 同时拥有入口、控制面、会话和交付 | 现有 Next.js BFF、FastAPI application、Celery、Redis/SSE 已有明确职责 | 引入第二 Gateway 会重复 auth、API、事件、会话与运维面 |
| Channel binding 根据来源身份/位置选 agent | Investment 需要依据 Task Profile、能力、证据、权限和风险选专业能力 | 即使复用 binding 语法，也解决不了语义路由和业务验收 |
| 多租户建议每个信任域运行完整 cell，Fleet 仍是实验性 | Investment 需要共享业务控制面下的强租户隔离 | 实例数量、升级和状态汇聚成本过高，且仍需额外业务控制面 |

因此，**不建议把 Investment 的路由和 Supervisor 完全转向 OpenClaw Gateway，也不建议
在现有 BFF 与 FastAPI 之间再放一个 OpenClaw Gateway。**这会增加一个控制面，却没有
消除 Task Supervisor、财务路由、四本账或验收中的任何一个核心问题。

OpenClaw 可以保留为高价值参考实现；若未来需要接 Slack、Telegram 等个人助理渠道，
可以把它当作一个受限 channel adapter，向 Investment 提交标准 Task，而不是让它成为
Investment 的业务主档。若未来要评估其 Codex harness 作为执行后端，也必须走独立
Spike 和 `AgentExecutorPort`，不能绕开已经确立的公开 SDK 边界或调用其私有内核。

## 21. 更好的路由与 Supervisor 方案

### 21.1 把一个“路由”拆成四个决定

建议将现有 `RoutePolicy` 进一步拆开：

```text
durable Task
  -> Task Profile Resolver
       决定完成合同、证据要求、风险等级
  -> Domain Agent Resolver
       决定 general-agent / finance-analysis-agent / ask-user / reject
  -> Executor Resolver
       在该 Agent 允许的 runtime 中按能力、健康、版本和政策选择 Codex/Harness
  -> Attempt Admission Gate
       固定权限、工具、预算、workspace、deadline、idempotency、lease/fencing
  -> Task Supervisor
       创建/监控 Attempt，验收候选结果，决定 retry/replan/interaction/terminal
```

这样“财务任务为何需要专业 Agent”和“这个专业 Agent 此次为何由 Harness 执行”会成为
两个独立、可审计的事实。未来新增第二个财务 runtime、降级只读分析器或模型版本时，
不会被迫修改 Task Profile 合同。

建议将 `RouteDecision` 扩充为：

```text
task_profile_ref
domain_agent_ref
executor_ref
decision_source          # explicit / rule / classifier / operator
matched_rule_ids
eligible_candidates
rejected_candidates      # candidate + stable reason code
classifier_binding       # model/version/schema/confidence，可空
policy_version
security_context_digest
budget_reservation_id
supersedes_decision_id   # 改路由时形成链，不覆盖历史
```

### 21.2 Gate 与 Supervisor 各自负责什么

建议可以使用“Gate”这个概念，但不要把它等同于 OpenClaw Gateway：

| 组件 | 类型 | 职责 | 明确不负责 |
| --- | --- | --- | --- |
| Task Admission Gate | 同步、确定性 | 身份、所有权、请求 schema、幂等、初始预算上限、持久化 Task/Outbox | 不启动模型，不决定 Task 成功 |
| Routing Gate | 纯决策/可回放 | 规则、受限分类、候选能力过滤、route explanation | 不持有 SDK session，不执行工具 |
| Attempt Admission Gate | 确定性安全边界 | 权限交集、工具、凭据、workspace、预算 reservation、lease/fencing | 不接受 runtime 自报权限 |
| Task Supervisor | 持久化编排器 | 消费 Outbox、推进状态、调 adapter、处理取消/重试/HITL、触发 validator | 不作为拥有全部工具的自由 Agent |
| Executor Adapter | 基础设施 | SDK 映射、事件归一、opaque binding、生命周期关闭 | 不路由、不验收、不改 Task 权限 |

前端不应物理上“直连 Supervisor”。正确生命周期是：前端经 BFF 调 Task API，Admission
Gate 在 PostgreSQL 中提交 Task 和 Outbox；Supervisor 再异步消费 durable fact。这样
即使 API 或 Supervisor 在请求中途重启，也不会出现“前端收到 Task ID，但执行从未可靠
入队”或“SDK 已经启动，Task 记录尚未提交”的夹缝。

### 21.3 路由算法

建议首版采用“确定性外壳 + 受限语义分类”，而不是纯关键词，也不是自由 LLM
Supervisor：

1. 根据调用面、租户政策、显式 Task Profile 和授权建立候选集；
2. 用 completion contract、所需数据源、证据等级、工具能力和风险等级做硬过滤；
3. 只有剩余多个合法候选时才运行低预算、无工具、固定 schema 的分类器；
4. 对分类结果再做一次政策复核，分类器只能在候选集中选，不能创造权限；
5. 低置信度本身不是唯一标准；只要歧义会改变数据访问、风险、成本或完成含义，就
   `ask_user`；
6. 路由、分类输入摘要、候选集和淘汰 reason code 持久化；
7. runtime 健康变化只影响 Executor Resolver。已开始 Attempt 不透明迁移，需重路由时
   创建新 Attempt 和新的 superseding decision；
8. 混合 Task 只有在父 Task completion contract 定义了组合验收时才拆子 Task，且共享
   父预算，不让子 Agent 自由 fan-out。

### 21.4 最终意见

对本轮两个问题的直接回答是：

- **新架构方向合理，边界上比原体系更好；但当前实现成熟度还没有更好。**完成 SDK
  Gate、唯一 Task 内核和四本账后，才能把“更好”从设计判断变成工程事实。
- **借鉴 OpenClaw，不整体转向 OpenClaw。**借它的确定性 binding、选择层次、
  capability contract、fail-closed、准入与 authority/fencing 思路；不借它作为
  Investment 的业务 Gateway、主档或多租户边界。
- **比“一个 Supervisor 负责所有事情”更好的方案，是 Admission Gate、Routing Gate、
  Domain Agent Resolver、Executor Resolver、Attempt Admission 和 Task Supervisor
  分责。**其中只有受限分类节点可以使用模型，其余关键控制都应可重放、可审计并由
  PostgreSQL 事实驱动。

## 22. 后续决策接口（本轮不展开）

本轮只完成架构判断，不要求对以下实施事项拍板。它们保留在这里，是为了防止后续开发
把尚未确定的合同误写成既成规范：

| ID | 决定 | 为什么需要批准 |
| --- | --- | --- |
| D1 | 是否把目标执行层从“Codex 单执行器”修订为“Codex + Harness 开放执行器” | 修改 `development-plan.md` 的当前规范方向 |
| D2 | 是否承担 DeepSeek Harness SDK 正式扩展及其上游维护 | 跨仓范围、版本与维护成本 |
| D3 | U2 统一执行 Port 的最终 DTO/能力表 | 决定 adapter、fake 与业务控制边界 |
| D4 | U3 Task/Attempt/预算/证据 schema | 涉及迁移、主档与并发不变量 |
| D5 | U5 worker 进程、home/PVC、凭据和队列部署形态 | 影响隔离、恢复、资源与运维 |
| D6 | 首个财务数据源、Task Profile 和质量阈值 | 没有数据与客观阈值不能证明专业 Agent 有效 |
| D7 | 是否以及何时开放外部副作用 | 需要 ACTION 合同、批准、回执和补偿，不属于首版 |

批准后应把稳定结论吸收进 `development-plan.md`，把当前阻塞和下一动作写入
`handoff.md`，再按 `implementation-plan.md` 的固定栏目拆任务。本文不应长期与权威
计划维护两份平行目标态；吸收完成后保留为决策证据或压缩为指针。

## 23. 最终架构建议

本文支持的不是“立即同时接两个模型”，而是下面这条建设原则：

> 建立 Investment 自有的 Task Supervisor 和统一执行 Port，通过官方 Python SDK
> 租用 Codex 与 DeepSeek Harness；通用 Task 由 Codex Attempt 执行，财务专业 Task
> 由 Harness Profile Attempt 执行；Task 状态、权限、四本账、验收和交付始终由
> Investment Backend 与 PostgreSQL 拥有。

建议按 Gate 0 → 唯一 Task 内核 → Codex 通用执行器 → Harness 财务执行器 →
Supervisor 自动路由推进。最先需要解决的是 SDK 能力与 Task 内核，不是路由提示词。

只有在以下四项完成后，后续开发才有稳定地基：

1. DeepSeek Harness 正式 SDK 补齐取消、恢复、结果归属和可信安全上下文；
2. Pilot 与 Agent v4 收口为唯一 Task/Attempt application use case；
3. 四本账与 lease/fencing 落 PostgreSQL；
4. 两个执行器通过同一 Port 的故障注入与契约测试。

跳过其中任一项直接做 Supervisor，会把最难修复的状态、权限和恢复缺陷固化在第三条
执行链里，后续实际开发将无法可靠展开。
