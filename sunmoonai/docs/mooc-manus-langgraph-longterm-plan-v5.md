# MoocManus 长期智能体平台架构规划 v5

状态：Architecture Baseline（待 Phase 0 Spike 验证后冻结）
日期：2026-07-11
范围：`k8s`、`info-app`、`knowledge-app`、`research-app` 的统一系统架构
实施计划：见 `mooc-manus-langgraph-v5-implementation-plan.md`

## 0. 执行摘要

本项目在 `app-platform/research-app` 中全新建设以 LangGraph 为编排运行时的长期智能体平台，并依赖 `info-app` 提供可追溯资讯、`knowledge-app` 提供受治理知识检索、`k8s` 提供部署与运行保障。

旧 `imooc-mas/mooc-manus` 仅作为领域启发和 golden 样本来源，不部署、不迁移、不兼容、不回退。

v5 的核心结论：

1. 这是四仓协同系统，不是只在 Research App 内实现一张 Graph。
2. LangGraph 管理有状态执行；Research App 管理产品领域、身份、工具、事件和运行控制。
3. Info App 拥有来源、抓取、原始证据和不可变文档版本。
4. Knowledge App 拥有知识文档、数据集绑定、Provider 绑定、检索和引用，不把 RAGFlow ID 当作领域 ID。
5. Research App 只通过 Knowledge Retrieval Contract 读取知识，不直接依赖 RAGFlow。
6. Checkpoint、业务状态、事件、短期上下文、长期记忆和知识库必须分层。
7. `Session`、`Thread`、`Run`、`RunAttempt`、`AgentInvocation` 和 `ToolExecution` 是不同实体。
8. 多智能体和长期记忆不在第一阶段完整平台化，但必须在架构冻结前各验证一条薄切。
9. 设计必须覆盖生产目标；实施必须按 Spike、M1、M2、GA 分阶段并受门禁约束。
10. 在最小安全闭环和真实跨仓 E2E 通过前，Research Agent 流量保持关闭。
11. 前端不是后端事件的调试器：Research 用户工作台和三套治理控制面都是平台边界的一部分，必须共享身份、契约、恢复、审计和 E2E 门禁。

## 1. 背景与 v4 重构原因

v4 的 greenfield、Walking Skeleton、评估前置、重放安全以及 Memory/Event/Checkpoint 分离方向正确，继续继承。v5 重构而非继续追加补丁，原因如下：

- v4 主要围绕 Research 内部设计，四仓契约和数据所有权不是主轴。
- Info 产生的 `info-artifact:` 引用与 Knowledge 可读取协议未闭合。
- Knowledge 尚无 Research 所依赖的 Retrieval/Citation API。
- 用户身份、服务身份、资源授权没有形成统一模型。
- 数据库提交与异步投递之间没有可靠交接规范。
- `session_id = thread_id` 被写成长期铁律，无法覆盖分支、换图、多 Agent 和重试。
- 多智能体和长期记忆直到后期才首次验证，可能过晚暴露基础模型错误。
- 自建 Runtime 与 LangGraph Agent Server 在 v4 阶段未经过正式选择；v5 ADR-001 已于 2026-07-16 选择 Custom Runtime。
- 单一巨型文档同时承载目标态、任务、历史说明和实施状态，权威边界不清。

v5 不否定现有成果；现有代码作为验证资产重新分类为“保留、重构、替换或废弃”。

## 2. 目标、非目标与成功标准

### 2.1 目标

平台最终应支持：

- 多轮、长运行、可暂停恢复的复杂任务。
- 规划、执行、工具、沙箱、文件和产物。
- Human-in-the-loop 澄清、审批和纠错。
- 可选择的单 Agent、Workflow、Router、Subagent 和 Handoff 编排。
- 跨 Session 长期记忆，带来源、权限、纠错、删除和质量评估。
- Info 证据到 Knowledge 检索再到 Research 引用回答的完整 provenance。
- 版本锁定、预算、取消、超时、幂等、重放和故障恢复。
- 用户身份、服务身份、资源所有权和未来多租户隔离。
- 可观测、可评估、可审计、可灰度、可回滚。
- 面向最终用户的可恢复 Agent 工作台，以及面向 Info、Knowledge、Research 管理者的可审计治理控制面。
- 浏览器刷新、断网、多标签页、重复提交和长任务后台运行时，界面仍能从服务端事实恢复，不依赖易失本地状态维持正确性。

### 2.2 非目标

- 不迁移或兼容旧 MoocManus API、数据库和运行流。
- Research App 不拥有资讯采集或知识摄取。
- Knowledge App 不拥有 Info 原始证据，也不直接执行 Agent。
- Info App 不负责向量检索和 Agent 记忆。
- 第一阶段不建设通用低代码 Agent Builder。
- 第一阶段不一次性实现全部 Provider、工具、多 Agent 模式和多租户能力。
- M1 不在三个现有 React/Next Web 中分别临时修补架构缺口，而是先原地重基线模板、再逐 App 原地迁移；三个 Vue Admin 通过迁移分支和逐 App 等价替换迁移，不在原 Vue 页面中长期混嵌 React；不因技术统一预先抽取跨 App 运行时 UI 包。
- M1 不把 Info Web 或 Knowledge Web 改造成内部管理控制面；管理操作继续由各自 Admin Frontend 承担。

### 2.3 可度量成功标准

M1a 内部竖线必须至少满足：

- 使用隔离 test identity/test dataset，无公网和生产数据。
- Info -> Knowledge -> Research -> UI 的真实模型/检索/引用链可重复运行。
- 不允许 fake LLM、mock ingestion success 或手工伪造 retrieval result 代替真实链路。
- Research Web 必须通过真实 API 展示 Run 状态、HITL 和 citation；Info/Knowledge Admin 至少能查看该竖线对应的交付、摄取和检索诊断状态。

M1b 进入 canary 前必须至少满足：

- 一条真实跨仓 E2E 可重复通过。
- 首轮用户输入不丢失，重复请求不产生重复逻辑执行。
- worker 重启后 waiting/running 任务按策略恢复。
- SSE 重连后最终时间线不缺失、不重复。
- 工具副作用在重试/恢复时最多执行一次，或具有明确补偿语义。
- 回答引用可回溯至 KnowledgeVersion 和 InfoDocumentVersion。
- 未授权用户不能读取或操作他人 Session、Run、Artifact。
- golden set 达到预先设定阈值并在 CI 中阻断回退。
- 浏览器刷新/断网恢复、重复 resume/cancel、防止陈旧 UI 覆盖服务端终态的 E2E 通过。
- 关键流程具备 loading/empty/error/partial/waiting/cancelled 状态、键盘操作和基础可访问性检查。

M1c 有限生产必须额外满足：

- canary 观察达到预设 SLO、成本和安全阈值。
- 停流、回滚和恢复演练通过。

M2 必须额外满足：

- 长期记忆写入、召回、纠错和删除闭环通过。
- 至少一种多智能体模式在上下文隔离、预算、lineage 和失败传播上通过。
- Graph、Prompt、Model、Toolset 和 Memory Policy 可被 run pin 版本。

## 3. 架构原则

1. **数据所有权优先**：先确定哪个 App 拥有事实，再定义 API 和事件。
2. **领域 ID 稳定**：外部 Provider ID 只能是绑定，不得成为业务主键。
3. **状态分层**：运行快照、业务状态、事件、记忆、知识、文件各守边界。
4. **确定性包围非确定性**：LLM 决策可以非确定，权限、预算、路由门禁和副作用必须确定。
5. **恢复优先**：每个副作用在设计时声明幂等、可重试或补偿策略。
6. **契约先于适配器**：Research 依赖 Knowledge Contract，而不是依赖 RAGFlow SDK。
7. **身份不信任客户端**：actor、tenant、scope、reviewer 由认证上下文产生，不从业务请求体相信。
8. **真实竖线优先**：各层少量实现形成 E2E，避免先铺满所有抽象。
9. **设计完整、实施分期**：目标态必须清楚，代码落地由阶段门禁驱动。
10. **证据化验收**：测试输出、版本、镜像 digest、迁移 revision 和故障记录都是交付物。
11. **服务端事实优先**：浏览器缓存和 optimistic UI 只能改善体验，不能成为 Run、审批、摄取或发布状态的真相源。
12. **契约驱动前端**：页面不直接消费 LangGraph、RAGFlow、数据库模型或原始跨仓事件；只消费版本化产品 API、UIProjection 和稳定错误模型。
13. **可恢复交互**：每个长任务界面都按“提交、确认、追踪、重连、对账、终态”设计，而不是只覆盖成功路径。

## 4. 系统上下文与四仓职责

```text
External Sources
      |
      v
Info App ---------------------> Object Storage
  Source/Crawl/DocumentVersion       immutable artifacts
      |
      | Knowledge Upsert Contract
      v
Knowledge App ---------------> RAGFlow (provider)
  KnowledgeDocument/Version
  DatasetBinding/ProviderBinding
  Retrieval/Citation API
      ^
      | Retrieval Contract
      |
Research App ----------------> Model Provider / Sandbox / Tools
  Session/Thread/Run
  LangGraph Runtime
  Memory/Multi-agent
      ^
      |
Frontend surfaces
  Research Web: Agent workspace
  Info Admin: source/review/artifact delivery
  Knowledge Admin: ingestion/dataset/retrieval diagnostics
  Research Admin: profile/runtime/evaluation/audit
  Info Web / Knowledge Web: domain product portals (not control planes)

K8s: identity, network, secrets, migration, rollout, scaling, observability
```

### 4.1 Info App owns

- Source、Collector、CrawlJob。
- RawArtifact、ExtractedArtifact。
- InfoDocument、InfoDocumentVersion。
- 来源可信度、版权和审核治理。
- 内容 hash、canonical identity、原始证据 provenance。
- 向 Knowledge 发起 upsert/deactivate/delete 的交付记录。

Info 不拥有 KnowledgeDocument、vector chunk、Agent Memory。

### 4.2 Knowledge App owns

- KnowledgeDocument、KnowledgeVersion。
- DatasetDefinition/DatasetBinding。
- ProviderBinding（RAGFlow dataset/document/chunk ID）。
- Ingestion、Parse、Index、Deactivate、Delete、Reindex 状态。
- Retrieval、filter、rerank、citation 和访问控制。
- InfoDocumentVersion 到 KnowledgeVersion 的 lineage。

Knowledge 不把 RAGFlow 数据库当作自己的领域数据库。

### 4.3 Research App owns

- Session、Thread、Run、RunAttempt。
- AgentProfile、GraphSpec、EffectiveRunConfig。
- AgentInvocation、ToolExecution、Approval、Artifact。
- LangGraph graph/state/checkpoint 适配。
- 会话上下文和跨 Session 长期记忆。
- UI timeline、Run API、SSE 和用户交互。

Research 不直接读取 Info 数据库、不直接调用 RAGFlow ingestion。

### 4.4 前端产品面 owns

- `research-web-frontend`：最终用户 Agent 工作台；Session/Run、消息、计划、HITL、工具审批、Artifact、Citation、取消与恢复。
- `info-admin-frontend`：来源、抓取、审核、DocumentVersion、不可变 Artifact 及向 Knowledge 交付状态。
- `knowledge-admin-frontend`：Dataset/Provider binding、摄取状态、失败处置、Retrieval/Citation 诊断和 lineage。
- `research-admin-frontend`：AgentProfile/Graph/Prompt/Toolset/Policy 版本、运行审计、evaluation、停流和人工处置；M1 只实现上线门禁所需最小面。
- `info-web-frontend`、`knowledge-web-frontend`：各自面向普通用户的领域产品入口；M1 不承载内部治理写操作，后续可提供受权 provenance deep link 或只读搜索。

前端只拥有交互状态和本地缓存，不拥有领域事实。浏览器不得直接访问 RAGFlow、对象存储长期凭据、数据库、RabbitMQ/Redis 或 Agent Server 管理 API。

### 4.5 K8s owns

- 服务部署、依赖、服务身份和网络边界。
- Secret 注入和轮换。
- migration gate、rollout、rollback。
- API/worker 扩缩容和中断保护。
- 日志、metrics、trace 的运行基础设施。

## 5. 核心实体与身份模型

### 5.1 执行实体

```text
Session
  产品会话容器，具有 owner/security scope。

Thread
  一张 Graph 的持久状态链，绑定 graph identity/version。

Run
  一次逻辑执行，保存不可变输入和 EffectiveRunConfig。

RunAttempt
  一次物理领取/执行尝试，具有 lease、worker、heartbeat 和错误。

AgentInvocation
  主 Agent 或 Subagent 的一次调用，形成调用树。

ToolExecution
  一次外部动作，具有稳定 tool_call_id、权限判定和副作用策略。

Checkpoint
  Thread 在 graph step 上的运行快照；不是业务事件或长期记忆。
```

M1 可默认一个 Session 对应一个主 Thread，但数据库和 API 使用显式映射，不把两者 ID 合并。Subagent 可共享主 Thread、使用 subgraph namespace，或拥有私有 Thread，具体由模式决定。

### 5.2 全局 lineage

所有关键记录统一携带：

```text
tenant_id        M1 可固定单租户，但字段存在
actor_id         用户或服务主体
session_id
thread_id
run_id
run_attempt_id
root_invocation_id
parent_invocation_id
agent_invocation_id
tool_execution_id
correlation_id
causation_id
```

不是所有表都要求全部字段，但不得用一个模糊 `run_id` 替代整条调用关系。

## 6. Runtime 选型决策与冻结边界

v5 起草时不预设最终必须自建或必须采用 Agent Server。ADR-001 已于 2026-07-16
`ACCEPTED / CANDIDATE_A_SELECTED`：

- 选中候选 A：Research 自有控制面 + durable dispatcher/Celery + PostgresSaver +
  Redis live signaling/SSE。
- 候选 B（Standalone Agent Server）和 C（混合）因当前没有已批准的生产许可、采购、
  air-gapped entitlement 或 beacon egress/usage-reporting 审查，触发预设硬淘汰规则。
- B/C 的通用 runtime 能力更完整这一事实保留；若未来硬门解除，必须新建 ADR 并复用
  同一故障矩阵，不得直接恢复第二套生产分支。

已验证：

- PostgreSQL checkpoint replacement、提交前/后 SIGKILL、running cancel、双 worker。
- 同 Thread 非终态 Run 的 `reject` 语义。
- PostgreSQL fail-closed/recovery、broker pending intent/retry。
- subscribe-before-snapshot、cursor reconciliation 和真实 Chromium 断线恢复。
- API/worker 各两个 K8s Ready 副本并恢复。

证据：`sunmoonai/docs/evidence/v5/V5-P0-001/result.md`。

ADR 接受只选择分支，不表示当前 Walking Skeleton 可生产。后续运行时工作冻结为：

```text
Runtime Common（始终实施）：产品领域、EffectiveRunConfig、Ports、授权、业务事件、评估
Runtime Custom（已激活）：dispatcher/Attempt lease/checkpointer/SSE/cancel/reconciler
Runtime Agent Server：NOT_APPLICABLE
Runtime Hybrid：NOT_APPLICABLE
```

P0-002 已通过 ADR-002 冻结 Session/Thread/Run/Attempt/Invocation；Gate P0 后才按
M1-301~312 建设生产 Runner。M1-313/314 只有新 ADR 重开选型后才可激活。P0-002
证据见 `sunmoonai/docs/evidence/v5/V5-P0-002/result.md`；其隔离 schema 不代表生产
migration、Attempt lease 或 reconciler 已完成。

## 7. LangGraph 运行时边界

LangGraph 负责：

- 节点、边、条件路由、subgraph。
- checkpoint、interrupt、resume。
- graph state reducer 和 durable execution 语义。
- graph stream 到内部 runtime event 的适配。

Research 负责：

- Run 生命周期、attempt/lease、身份、预算、取消。
- Graph 解析和 EffectiveRunConfig。
- LLM、Knowledge、Tool、Sandbox、Memory ports。
- 业务事件、投影、artifact 和审计。
- API、SSE、授权和产品状态。

### 7.1 Graph State

State 只保留本次执行所需的最小可恢复数据：

- 输入引用和已规范化消息。
- plan/current step。
- pending tool calls、精简 tool result。
- artifact/evidence/memory 引用。
- budget counters、route state、error summary。

禁止保存：

- 完整事件历史。
- 文件正文和大二进制。
- 整个长期记忆库。
- Secret、credential、原始 access token。
- 可从领域数据库稳定读取的全量对象。

Reducer 必须通过 LangGraph channel schema 显式注册并测试结合律、幂等性和重放行为，不能只定义未使用的辅助函数。

### 7.2 EffectiveRunConfig

Run 创建时固定：

```text
graph_key/version
agent_profile_key/version
prompt_set/version
model_policy/version + resolved model
toolset/version
memory_policy/version
knowledge_binding/version
security policy snapshot/version
budget/deadline
```

运行中控制面更新不改变已有 Run；需要变更时创建新 Run 或显式 migration/resume policy。

## 8. 跨仓契约

所有契约必须具有：`contract_version`、幂等键、correlation/causation、身份、超时、错误分类和兼容策略。

### 8.0 契约唯一真相源与治理

Knowledge App 是 ingestion/lifecycle 和 retrieval/citation API 的 Provider，因此权威 OpenAPI/JSON Schema 存放在 `knowledge-app/contracts/`。本规划只描述语义，不复制第二份 schema。Info App 对 artifact/source 语义提出变更，最终以 Knowledge 接受的版本化 Provider Contract 发布；Research App 只消费 retrieval/citation contract。

治理规则：

- `knowledge-app/contracts/` 是唯一可编辑源，生成客户端和测试 fixture 不得手改。
- 契约发布为带版本和内容 digest 的 CI artifact；Info/Research 固定兼容版本范围。
- Knowledge CI 做 schema 与向后兼容检查。
- Info/Research CI 做 consumer-driven contract tests。
- k8s CI 运行四仓兼容矩阵和最小跨仓 contract smoke；k8s 文档只记录部署版本，不复制 schema。
- breaking change 提升 major version，并提供双版本窗口和下游迁移任务。

### 8.1 Info -> Knowledge Artifact Contract

推荐采用不可变对象存储引用：

```json
{
  "source_app": "info-app",
  "source_document_id": "uuid",
  "source_document_version_id": "uuid",
  "artifact": {
    "uri": "s3://bucket/key",
    "sha256": "...",
    "size_bytes": 123,
    "content_type": "text/markdown",
    "storage_version": "..."
  },
  "operation": "upsert",
  "dataset_key": "market-news",
  "idempotency_key": "...",
  "contract_version": 1
}
```

要求：

- URI 不得依赖共享数据库反查。
- Knowledge 读取后校验 size/hash。
- 对象不可原地覆盖；版本更新产生新 key/version。
- 对 HTTP signed URL 规定过期、域名 allowlist 和最大下载大小。
- `deactivate/delete/reindex` 使用相同 source identity。

### 8.2 Knowledge -> Research Retrieval Contract

请求至少包括：

```text
query
dataset_keys
filters
top_k
token_budget
security_context
request_id
contract_version
```

响应返回标准 Evidence：

```text
evidence_id
knowledge_document_id/version_id
chunk_id
content
score/rank
title
source_uri
source_document_id/version_id
content_hash
provider_metadata（受控，不作为领域身份）
access_scope
```

Citation 必须引用 `evidence_id`，最终可回溯到 InfoDocumentVersion。Research 不把“已检索到证据”视为“任务已验证完成”。

### 8.3 错误与兼容

统一错误类别：

- invalid_request
- unauthenticated / forbidden
- not_found
- conflict / idempotency_conflict
- artifact_unreadable / hash_mismatch
- provider_unavailable / timeout / rate_limited
- parse_failed / retrieval_failed
- contract_version_unsupported

消费者必须容忍响应新增可选字段；删除/改变语义需要新 contract major version。

## 9. 安全架构

### 9.1 身份类型

- HumanIdentity：来自 Casdoor/OIDC，映射内部 actor_id。
- ServiceIdentity：Info、Knowledge、Research、worker 的独立主体。
- WorkloadIdentity：K8s ServiceAccount 与服务主体绑定。
- DelegatedRunIdentity：Run 创建时保存用户授权快照，worker 执行时重建受限上下文。

身份协议、浏览器 BFF 会话、六 audience、CSRF/CORS、服务 token 与路由分区的权威决策见 `sunmoonai/docs/mooc-manus-v5/adr/ADR-005-identity-service-calls-browser-bff.md`。本节只保留长期架构原则，不复制其字段和协议细节。

Casdoor 的浏览器 BFF 使用 application-specific discovery；当前版本的
`client_credentials` access token 使用基础 issuer。服务关系必须显式配置
独立的 service discovery URL，并严格接受该 metadata 的 issuer/JWKS；不得从
token claim 推断 issuer，也不得把任意 provider host 加入 allowlist。

### 9.2 授权

所有资源访问检查：

```text
subject + action + resource + tenant/project scope + policy version
```

M1 至少实现：

- Session/Run/Artifact owner 检查。
- 管理 API role/scope。
- Info -> Knowledge ingestion scope。
- Research -> Knowledge retrieve scope。
- Tool/Sandbox 每次执行前再次校验。
- SSE 建连前授权，连接期间处理权限撤销策略。

`reviewer`、`actor_id`、`tenant_id` 不得由客户端业务 payload 决定。

认证成功不等于已授权。业务 Router 必须先按 Public、Admin/User、Internal 分区，再以 `principal + action + resource + policy_version` 判定；关键资源至少检查 owner/scope。人类 session 不得调用 Internal route，service token 不得调用浏览器业务 route。

### 9.3 网络、Secret 和数据

- K8s 默认拒绝，按调用关系最小开放。
- Secret 不进入 Git 明文，采用 External Secrets/SOPS/Sealed Secrets 之一。
- worker 非 root、禁止提权、drop capabilities、seccomp。
- 日志和事件不记录 token、Secret、完整敏感正文。
- Prompt/Tool 输出按不可信输入处理，Knowledge 内容不得提升为系统指令。
- 浏览器不保存 Provider token；后端 session、日志、事件和错误响应不暴露 token、authorization code、PKCE verifier、nonce 或 client secret。
- 服务 client 的 Secret 只由部署机/Secret 管理器注入；KIND 的一次性验证凭据不得成为 Git 或镜像输入。
- credential CORS 使用精确 origin，禁止 `allow_credentials=true` 配合通配 origin；cookie-auth 的非安全方法必须有 Origin 与 CSRF 双重校验。

## 10. 消息、事件、投影与流式输出

### 10.1 对象边界

- Command：请求执行某动作。
- DomainEvent/RunJournalEntry：已发生的业务事实。
- RuntimeEvent：节点、模型和工具的观测数据。
- UIProjection：用户界面所需的可重建视图。
- LiveDelta：易失的交互增量，不是事实源。
- TransportEnvelope：跨进程传输包装；在需要时实现，不污染领域对象。

### 10.2 事务原则

- Run 状态变化与关键 DomainEvent 在同一数据库事务提交。
- 异步交付使用本地 outbox 或等价的可恢复 dispatcher。
- UIProjection 可同步同事务更新，或由 projector 按 cursor 重建。
- 不默认把 DomainEvent 和 UIEvent 各存一份；是否物化由读模型需求决定。
- 序号由数据库安全生成，禁止无锁 `max+1`。
- Redis Pub/Sub/Stream 不是业务真相源。

### 10.3 SSE 对账

持久事件使用单调 cursor。连接流程必须消除“查历史后再订阅”的空窗，例如：

1. 建立 live subscription/buffer。
2. 读取持久化 watermark 后的事件。
3. 合并缓冲并按 cursor 去重。
4. 继续实时转发。

LiveDelta 可丢失，最终 AssistantMessage/UIProjection 必须持久化并收敛 UI。

### 10.4 前端 API 与 BFF 边界

- 浏览器只调用同一产品 App 的公开产品 API；跨仓调用由后端服务身份完成，禁止浏览器编排 Info -> Knowledge -> Research。
- Next.js Web Frontend 是否使用轻量 BFF/proxy 由身份与部署 ADR 决定，但 BFF 不复制领域规则、不保存第二份 Run 状态。
- Admin Frontend 使用管理 API 和管理 scope；Web 与 Admin token/audience、路由和 CORS 策略显式分离。
- OpenAPI/JSON Schema 生成或验证 typed client；生成物可提交，但唯一真相仍是 Provider Contract，禁止页面内散落手写 DTO。
- 错误统一映射为稳定 `code + message_key + retryable + correlation_id + field_errors`，UI 不依据后端自然语言判断逻辑。

### 10.5 Research Web 交互状态机

Research Web 至少支持以下可恢复状态：

```text
idle -> submitting -> accepted/queued -> running
running -> waiting_approval | waiting_input | completed
running/waiting -> cancelling -> cancelled
任意在线状态 -> reconnecting -> reconciling -> 服务端终态
任意动作 -> retryable_error | terminal_error
```

规则：

- 创建 Run、resume、approve、cancel 都携带幂等键；按钮禁用不能代替服务端幂等。
- URL 使用稳定 Session/Run 标识，刷新后从服务端重建；不得只存在 Zustand/React Query 内存中。
- SSE 只做增量通知；重连、页面恢复和后台唤醒后必须按 cursor 拉取持久投影并对账。
- 多标签页至少选择“单 active stream + BroadcastChannel 协调”或“多连接、cursor 去重”之一并测试。
- waiting/approval 展示动作对象、风险、权限、过期时间；陈旧 token、已取消和已处理必须显示服务端冲突结果。
- Citation 只渲染服务端验证后的 evidence 引用；内容按不可信文本处理，默认不允许任意 HTML、脚本或危险 URL。

### 10.6 三套 Admin 治理闭环

M1a/M1b 所需的最小治理界面不是通用 CRUD：

- Info Admin 能从 Source/Crawl 定位 DocumentVersion、Artifact hash/URI 元数据、审核人、交付 operation 和失败原因，并执行受权重试/停用。
- Knowledge Admin 能从 source version 定位 KnowledgeVersion、Provider binding、parse/index 状态，执行受权重试，并用测试身份运行 Retrieval/Citation 诊断。
- Research Admin 能查看 Run/Attempt/Invocation/ToolExecution lineage、固定配置版本、预算、失败分类和 correlation ID；canary 前提供停流状态和只读审计入口。

所有人工操作必须调用后端 Command API，填写原因并产生审计事件；前端不得直接修改状态字段或把“界面已更新”当作操作成功。

### 10.7 前端安全与隐私

- 浏览器身份来自 OIDC/session，不把 access token 放入可被任意脚本长期读取的持久存储；具体 cookie/token 模式由 ADR-005 决定。
- 防护 CSRF、XSS、开放重定向、危险 Artifact/Citation URL、公式/Markdown 注入和第三方内容嵌入。
- 前端路由守卫和按钮隐藏只是体验层；所有授权由 API 再判定。
- 日志、analytics、错误上报不得包含 prompt 全文、证据正文、token、signed URL 或敏感 Memory。
- 下载和预览通过受权短期 URL/后端代理；执行 content type、大小、文件名和 sandbox 策略。

### 10.8 状态、性能、可访问性与国际化

- Server state 使用查询缓存，表单/展开/草稿等 UI state 单独管理；禁止复制一份长期可漂移的领域 store。
- 长列表和长时间线分页/虚拟化；LiveDelta 合批渲染；断线退避带 jitter 和上限，页面隐藏时降频。
- 所有关键流程覆盖 loading、empty、partial、waiting、permission denied、retryable、terminal 和 cancelled 状态。
- M1b 前关键流程满足键盘可操作、焦点恢复、语义化状态/ARIA live、颜色对比和 reduced-motion；以自动检查加人工走查验收。
- 用户文案使用 message key，稳定错误 code 与本地化文案分离；至少保持现有中英文能力不回退。

### 10.9 前端观测与测试

- 前端记录匿名化 route、operation、Web Vitals、SSE reconnect/reconcile、错误 code 和 correlation ID；不得上报敏感正文。
- 单元/组件测试覆盖 reducer、状态机、citation sanitizer、权限状态和错误映射。
- Contract 测试验证生成 client 与 Provider schema；浏览器 E2E 覆盖登录、创建、流式、刷新、HITL、重复操作、取消、引用和跨 Admin lineage。
- 浏览器 E2E 是 M1a/M1b Gate 的组成部分；后端脚本成功不能替代页面级验收。

### 10.10 前端技术栈与渲染策略

ADR-013 已接受以下目标态：统一 React + TypeScript 开发生态，但不强制六个前端使用相同运行框架。

| 产品面 | 目标技术栈 | 渲染与部署 |
|---|---|---|
| Info/Knowledge/Research Web | React 19 + Next.js App Router | 按路由/组件混合渲染，`standalone` Node 部署 |
| Info/Knowledge/Research Admin | React 19 + React Router 8 Framework Mode + Vite + Ant Design 6 | `ssr: false` 纯 SPA，Nginx 静态部署 |

Web 模板可参考 `ixartz/Next-js-Boilerplate` 的 App Router、严格 TypeScript、环境校验、国际化、边界组件、测试和 CI 组织，但必须在 ADR-014 中逐项记录采用、改造或拒绝；不复制 Clerk、Drizzle/PGlite、前端数据库、SaaS 集成或其产品页面。Casdoor OIDC/BFF、Provider Contract、后端领域 API 和自托管 Node/KIND 约束优先于上游模板默认值；上游 Node 版本要求也不得未经兼容性验证直接带入。

Web 规则：

- Info Web 的公开内容优先 SSG/ISR/SSR，登录后交互使用 Client Component。
- Knowledge Web 的入口/说明可服务端渲染，受权检索和个人空间使用客户端数据层。
- Research Web 使用 Next 应用壳；Agent workspace、SSE、HITL、timeline 和多标签协调是 Client Component，不因采用 Next 把实时 Run 状态迁入 RSC cache。
- Next BFF 只在 ADR-005 证明需要 token mediation/同源代理时使用，不复制领域规则或保存第二份 Run 状态。

Admin 规则：

- React Router Framework Mode 负责 route module、类型生成、代码拆分、路由 pending/error boundary；配置 `ssr: false`，不增加三个 Node Server。
- TanStack Query 是 API server-state/caching/mutation 主层；Router loader 仅用于路由 bootstrap、权限前置和必要进入条件，禁止维护第二份业务缓存。
- Ant Design 6 是 Admin 主组件库，Ant Design Table 是默认表格；只有真实规模、编辑或虚拟化指标证明不足时，才为单一场景评估专项 Data Grid，禁止并存第二套完整 UI 体系。
- URL 保存分页、筛选、排序和可恢复视图；表单状态与纯 UI state 分离；不得把领域事实长期复制到 Zustand。
- Admin 不采用 Nuxt；Vue Admin 只保留在三个 App 的迁移前 tag/镜像和 Git 历史中作为可审计回滚基线，不维护独立 Vue 模板仓库，也不形成永久双栈产品线。

模板演进：

1. 保留现有 `tpl-web-frontend`（它已经是 React + Next）。
2. 将 React Admin 主模板固定在 `tpl-admin-frontend` 子仓库；`tpl-app` 不再保留独立 Vue 模板子仓库，Vue 参考来自三个 App 的历史源码和 commit，冻结旧实现新增平台能力。
3. 在 canonical `tpl-admin-frontend` 中完成 React 生产骨架；该阶段只证明技术路线、部署形态和平台接入点，不能宣称完成 Vue 功能迁移。
4. 新增独立的 React Admin 模板能力对齐门 `P0-007A2`：从三个 App 的现有 Vue 源码和固定 commit 冻结能力清单，逐项实现生产相关通用组件、布局、路由、权限、状态、国际化、错误/安全、构建和部署行为，并形成 Vue -> React 映射与测试矩阵。示例页、Electron/PWA 等 legacy 能力必须明确标记为保留、替代或延期，禁止静默遗漏。
5. 用 Info Admin Artifact/Delivery 真实薄切验证模板；通用能力回收模板，业务代码不进入模板。只有 `P0-007A2` 完成后，模板才具备业务迁移资格。
6. `P0-007C` 冻结且 Gate P0 通过后，在三个现有 App 前端仓库内按 Info -> Knowledge -> Research 串行原地替换基础实现；每个 App 先保留迁移前 Git tag 和可回滚镜像，替换代码不等于切换流量，也不创建新的业务仓库。
7. 三个 React Admin 分别在现有 App 仓库内完成真实业务功能、安全、可访问性和 E2E 等价后，才允许切换流量；迁移前用 Git tag 和镜像 digest 保留回滚基线，不再双重维护 Vue/React 实现。
8. 现有 `tpl-web-frontend` 保持可回退，不在三个实例中分别修补；ADR-014 按 P0-008A/B/C 再基线 Next Web 模板。
9. 在 ADR-001/004/005 决定 stream、Citation 和浏览器身份/BFF 前，只允许 Web 审计与紧急卫生修复，不提前实现 v2 主体。
10. 在现有 `tpl-web-frontend` 仓库的迁移分支内重构 Next Web v2，证明 Server/Client、DAL/DTO、typed client、render/cache、auth/BFF、SSE reconciliation、安全、测试和自托管多副本边界。
11. 用 Research 真实 Run/SSE/cancel/resume/HITL/citation 薄切验证并冻结 v2；通过前不修改三个 Web 的业务前端，不把 Research 领域代码回流模板。Gate P0 后再按 Info -> Knowledge -> Research 串行把冻结版本应用到三个现有 Web 仓库，每仓独立验证、切换和回滚。

### 10.11 React Admin 功能等价门槛

“等价”不是把 Vue 文件逐行翻译成 JSX，也不是只保留一个 Shell 和 Reference Page，而是对所有仍由模板承担的用户可见能力和可复用能力给出可验证对应物：

- **必须对齐**：布局、菜单、面包屑、标签/导航、主题、响应式内容密度、登录/退出/受保护路由、权限和错误边界、i18n、API/Query 状态、表格/筛选/分页、表单/校验、Dialog/Drawer、详情描述、通知、图标、上传/下载、编辑器/媒体、图表、持久化 UI 状态、CSP/CSRF/CORS/session 接入、Nginx/Docker/K8s 接口和测试约定。
- **逐项有证据**：每项记录 Vue 来源路径、React 目标路径、行为差异、API/契约、测试用例、可访问性结果和 owner；未实现项必须有明确的 defer ADR/任务，不得用“后续完善”作为状态。
- **业务与模板分离**：Info/Knowledge/Research 的领域页面、DTO 和业务规则不进入模板；模板只提供通用能力和中性示例。
- **Legacy 明确处置**：Electron、PWA、演示/组件展厅等不属于目标产品的能力可以延期，但必须在矩阵中标注理由、影响和恢复路径；如果任一 App 依赖它，则必须先完成对应 React 能力或重新批准 ADR-013。
- **迁移资格**：P0-007A 的骨架测试通过只产生 `SKELETON_ACCEPTED`；P0-007A2 完整能力矩阵、映射、测试和从固定 commit 的干净重建通过后，才产生 `TEMPLATE_MIGRATION_READY`。

## 11. 可靠执行

### 11.1 Run 状态

```text
created -> queued -> running -> waiting -> queued/running
running -> completed | failed | cancelled | timed_out | budget_exceeded
```

状态转换使用条件更新/乐观版本。`RunAttempt` 保存每次领取，Run 保存逻辑结果。

### 11.2 Lease、心跳与恢复

- worker 领取 RunAttempt 时获取有期限 lease。
- 定期 heartbeat；失效后 reconciler 判断重投或人工处置。
- 锁竞争是调度状态，不直接等价为业务失败。
- checkpoint 表示图恢复点，Run Journal 表示业务事实，两者由 reconciliation policy 对账。

### 11.3 幂等与副作用

每个 ToolExecution 声明：

- read_only：可安全重试。
- idempotent：使用外部或本地 idempotency key。
- resumable：保存阶段和外部 operation ID。
- compensatable：定义补偿动作。
- at_most_once：无法安全重试，执行前需审批并保存不确定结果状态。

仅用“结果缓存”不能证明外部副作用幂等。RAGFlow upload、文件写入、消息发送都必须保存外部 operation identity。

### 11.4 取消、超时和预算

- Cancel 是持久 Command，worker 在节点和工具边界协作检查。
- Tool/LLM/Knowledge 调用都有 timeout 和 deadline propagation。
- 预算至少覆盖 step、LLM/tool calls、token、费用、wall time 和并行度。
- timeout/cancel 后保存可解释终态，不无限重试。

## 12. Knowledge 架构

### 12.1 内部模型

```text
KnowledgeDocument
  stable identity, owner/scope, active status

KnowledgeVersion
  immutable source lineage, content hash, ingestion state

DatasetDefinition
  controlled dataset key, access policy, chunk/embedding policy

ProviderBinding
  provider, dataset_id, document_id, chunk mapping, stage/status

RetrievalRecord
  request, selected evidence, latency, policy/version
```

### 12.2 Provider workflow

目标态阶段：resolve -> verify -> upload -> parse -> index -> ready。M1 可用少量字段实现，但必须在 upload 后立即保存 provider document ID，使 retry 不重复上传。

RAGFlow 不可用时不得在非测试环境静默返回 mock success。Provider disabled、degraded 和 failed 必须可区分。

### 12.3 Dataset 控制

外部调用传 `dataset_key`，Knowledge 控制面解析为 Provider dataset。数据面默认无权创建任意 dataset。M1 可配置静态 allowlist，M2 再实现完整 Registry UI。

## 13. Memory 架构

### 13.1 四类不同对象

- Working State：Graph 当前执行状态。
- Thread Context：同一 Thread 的短期连续性，主要来自 checkpoint/message history。
- Long-term Memory：跨 Thread 可复用的用户/项目/Agent 记忆。
- Knowledge：受治理的外部文档知识，由 Knowledge App 拥有。

### 13.2 长期记忆模型

每条记忆至少包含：

```text
memory_id/version
tenant/user/project scope
visibility (private/shared)
kind (semantic/episodic/procedural/preference)
content
source refs/provenance
confidence
created_by (human/model/system)
validation status
sensitive classification
embedding/model version
ttl/last_used_at
supersedes/conflicts_with
```

### 13.3 写入与召回

写入：候选提取 -> 去重/冲突 -> 安全分类 -> 价值判定 -> 可选人工确认 -> 持久化。
召回：按 scope/intent 检索 -> 权限/敏感过滤 -> rerank/token budget -> 带来源注入 -> 记录 selected/used feedback。

模型自动判断 used/ignored 只能作为弱信号；需要任务结果、用户反馈和离线评估共同校准。

### 13.4 删除与纠错

- 用户可查看、纠错、撤回自己的可见记忆。
- 删除按 source/scope 级联索引和缓存。
- 冲突不原地覆盖历史，使用 version/supersedes。
- Knowledge 文档内容不复制为长期记忆，除非转化为带来源的用户决策或经验。

## 14. 多智能体架构

不把“多智能体”等同于 Supervisor。按任务选择：

- Workflow：确定性步骤和强约束流程。
- Router：一次分类后并行/单次派发。
- Subagent-as-tool：主 Agent 保持用户上下文，子 Agent 隔离专业上下文。
- Handoff：某角色需要持续直接与用户交互。
- Skills：同一 Agent 动态加载专业提示与资源。
- Custom graph：混合确定性和 agentic 节点。

每次 AgentInvocation 明确：

- 输入上下文选择器。
- 可见 memory/evidence/artifact。
- 允许工具和权限。
- 独立预算与 deadline。
- 输出 schema 和合并策略。
- checkpoint/thread 模式。
- 失败、取消和 interrupt 传播。

禁止所有 Agent 共享无限增长的 message list。Shared Task State 只保存协作所需事实，私有推理上下文不默认传播。

## 15. Tool、Sandbox 与 Artifact

Tool Registry 保存稳定 tool key、schema、版本、risk、required scopes、timeout、side-effect policy。工具返回结构化结果，不直接操纵 Run 状态。

高风险操作必须：

- 参数规范化和命令/路径 allowlist。
- Human approval 或 policy approval。
- sandbox 隔离和最小网络权限。
- 输出大小限制、Secret 扫描、artifact hash。
- 完整 ToolExecution audit。

Artifact 由 Research 持有引用和元数据，大对象存对象存储。Sandbox workspace 是临时执行空间，不是长期事实源。

## 16. 可观测性与评估

### 16.1 可观测

统一记录：

- Run/Attempt/Invocation 状态、耗时和 lineage。
- Graph node、route、interrupt 和 checkpoint identity。
- LLM model/prompt/version、token、费用、延迟。
- Knowledge query/evidence/citation、检索版本和延迟。
- Tool 参数摘要、权限结果、副作用 identity。
- Memory recalled/selected/written/corrected/deleted。
- outbox lag、queue depth、lease expiry、SSE reconnect gap。

优先采用 OpenTelemetry 语义，LangSmith 可作为 Agent 专项观测实现之一，不成为唯一事实源。

### 16.2 评估层次

1. 确定性单元测试：reducer、serializer、policy、state machine。
2. 组件集成：Postgres、RabbitMQ、Redis、S3、RAGFlow。
3. 契约测试：Info/Knowledge/Research provider-consumer。
4. E2E：真实文档到引用回答。
5. 故障注入：进程 kill、重复消息、超时、断网、SSE 重连。
6. Agent 质量：任务成功、工具选择、引用正确、成本、记忆污染。

LLM 测试使用录制回放保证控制流确定性，同时保留少量真实模型评估检测 Provider 和 Prompt 漂移。

## 17. 数据与 Schema 演进

- 所有业务 schema 使用 Alembic 或对应语言的正式 migration。
- deployment 通过独立 Migration Job gate，不由每个副本启动时迁移。
- expand -> migrate/backfill -> switch -> contract。
- Event/Contract/StoredMessage 带 schema/contract version 和 upcaster。
- Checkpointer schema 由官方组件管理或严格锁版本，禁止无验证复制第三方内部表结构。
- 删除策略覆盖 Postgres、checkpoint、object storage、vector index、cache、event projection 和 long-term memory。

## 18. Kubernetes 目标架构

M1 最小要求：

- API 与 worker 使用不可变 image digest 或可追溯 tag+digest。
- migration Job 先于新版本 API/worker。
- 非 root securityContext。
- live/readiness/startup 分离。
- 最小 NetworkPolicy allowlist。
- Secret 不以明文生成文件进入 Git。
- API 至少可滚动升级；worker 有优雅终止和任务 drain。
- traffic flag 的 Git desired state 与集群一致。

GA 目标：

- API HPA、worker KEDA/queue-depth scaling。
- PDB、topology spread/anti-affinity。
- 数据库/Redis/RabbitMQ/RAGFlow 的容量与备份恢复演练。
- canary、自动回滚、SLO 和告警。

## 19. 分阶段路线与门禁

### 19.1 Immediate Safeguard：立即保护

- 修复 Git/集群 traffic flag 漂移，确保重新部署仍关闭流量。
- 不等待 Phase 0 决策，不修改生产 Runner。

### 19.2 Phase 0：八个阻塞性架构决策/验证包

- Runtime 选型。
- Session/Thread/Run/Attempt 模型。
- Artifact Contract。
- Retrieval/Citation Contract。
- 身份与服务调用。
- 可靠交付 ADR。
- React Admin 模板、Info 真实试点与 v1 冻结。
- Next Web 模板架构再基线、Research 真实 streaming 试点与 v2 冻结。

Runtime Spike 内验证 SSE/cancel/worker kill；可靠交付 Spike 内验证重复投递和副作用恢复。前端先严格按 P0-007A -> P0-007A2/A2.1 -> P0-005 -> P0-007A2/A2.2~A2.5 -> P0-007B -> P0-007C 完成 React Admin 模板资格链；A2.2 的真实身份接入不得先于 P0-005 接受。随后完成 P0-004、P0-001/002、P0-006，并在 ADR-001/004/005 有输出后于现有 `tpl-web-frontend` 仓库内按 P0-008A/B/C 完成 Next Web v2，禁止未验证模板直接覆盖业务代码。全部 Phase 0 退出条件满足并通过 Gate P0 后，才按 Info -> Knowledge -> Research 串行原地迁移三个 Admin（M1-411）和三个 Web（M1-413）。核心 ADR Spike 仍使用 2~3 周时间盒，但完整 Phase 0 还包含 React 模板能力对齐、真实 Admin 薄切和 Next 模板资格链，不能宣称全部工作可在同一 2~3 周内完成。退出门禁是 ADR-001~006/013/014 有运行或试点证据、P0-007A/A2/B/C 与 P0-008A/B/C 全部通过、契约测试机制可执行且不存在阻断 M1a 的未决核心问题。

执行恢复纪律：旧 v4 局部实现、已运行镜像或单一模板骨架不得倒推为 v5 迁移完成。`SKELETON_ACCEPTED`、`PROVISIONAL_EARLY_SLICE` 与 `TEMPLATE_MIGRATION_READY` 必须使用不同状态；只有模板资格链和 Gate P0 全部通过后，才允许按 Info → Knowledge → Research 逐 App 原地迁移、独立切换和回滚。版本清理遵循“先记录 digest 和回滚基线，后删除临时 tag”，不得覆盖或删除仍被任何 Deployment/回滚流程引用的稳定版本。三套 App 的部署入口现在默认拒绝前端 `p0-*` tag，仅显式隔离测试模式可放行。具体操作、当前前端矩阵和经验教训以实施计划 §1.6 为唯一执行权威。

### 19.3 M1a：内部真实产品竖线

在无公网入口、无生产数据、隔离 namespace/test dataset 和内部测试身份下，打通 `InfoDocumentVersion -> Knowledge ingestion/retrieval -> Research real LLM -> citation UI`。目标是尽早证明产品回路，不代表允许真实用户流量。

### 19.4 M1a.5：核心目标架构验证

基于 M1a 的真实 Runner、模型和检索，完成一条跨 Session 记忆薄切和一个隔离上下文 Subagent 薄切。根据结果冻结 Thread/Invocation/Context/Memory 边界。

### 19.5 M1b：受控 Canary 门禁

完成真实身份/授权、可靠投递、原子 resume/cancel、SSE 对账、migration、最小网络策略、安全/故障/evaluation 门禁。全部通过后才允许 `canary`。

### 19.6 M1c：有限生产

canary 指标、回滚和恢复演练达标后，才进入有限真实流量；不等同 GA。

### 19.7 M2：长期记忆与多智能体产品化

完成受治理长期记忆、至少一种生产多智能体模式、版本锁定和质量门禁。

### 19.8 M3/GA：平台与规模化

多租户、标准 outbox/inbox、完整 Provider journal、自动扩缩容、数据治理、灰度与灾难恢复。

## 20. 现有实现处置

### 20.1 保留

- Info Source/Document/Version/Artifact 概念和大部分采集代码。
- Knowledge RAGFlow client 探索、配置检查和测试。
- Research checkpoint、interrupt/resume、事件/SSE 和 golden 骨架。
- 四仓部署脚手架与现有测试。
- Phase 0 前端 Console。
- 三套 Web Frontend 的 React/Next.js/i18n/auth shell，以及三套 Vue Admin 的现有部署管线；Vue 页面只作为迁移行为参考，不作为新 React 模板的框架约束。

### 20.2 重构

- Info canonical identity、版本并发、artifact contract、distribution delivery。
- Knowledge 领域模型、Provider workflow、Retrieval/Citation。
- Research Run model、生产 Runner、事务 EventSink、SSE reconciliation、授权。
- Research Web 从 Phase 0 Console 重构为可恢复产品工作台；Info/Knowledge/Research Admin 分别补齐 Artifact delivery、ingestion/retrieval 和 runtime/evaluation 治理面。
- 六个 Frontend 的 typed client、浏览器身份、错误模型、观测和测试门禁。
- `tpl-app` Admin 以 React Router Framework Mode SPA 为唯一主模板；先完成来自三个 App Vue 源码的完整通用能力对齐，再在现有 App 仓库内按固定 commit 原地替换并逐 App 通过等价门禁，禁止把骨架或单一业务薄切当作迁移完成。
- K8s migration、安全上下文、NetworkPolicy、配置真相。

### 20.3 不进入生产主链

- 固定 hardcode Walking Skeleton。
- 未接入的 first_m1_graph hardcode 输出。
- 非测试环境 mock ingestion success。
- `info-artifact:` 未定义引用。
- 未注册的 reducer 辅助函数。
- 无身份保护的业务 API。

## 21. 关键 ADR 清单

- ADR-001 Runtime 选型：Accepted，选择 Custom Runtime；Agent Server/Hybrid 当前不适用。
- ADR-002 Session/Thread/Run/Attempt/Invocation 身份模型（Accepted）。
- ADR-003 Info-Knowledge Artifact Contract（Accepted）。
- ADR-004 Knowledge-Retrieval/Citation Contract。
- ADR-005 用户身份、服务身份和 delegated run identity。
- ADR-006 异步可靠交付：outbox/dispatcher/reconciler。
- ADR-007 Run Journal、DomainEvent 与 UIProjection。
- ADR-008 Tool 副作用和 Provider operation 恢复。
- ADR-009 Long-term Memory scope、治理和删除。
- ADR-010 多智能体模式选择和上下文隔离。
- ADR-011 Graph/Prompt/Model/Toolset 版本锁定。
- ADR-012 Observability/Evaluation 实现。
- ADR-013 前端技术栈、渲染模式与 Vue Admin 退出策略（Accepted）。
- ADR-014 Next Web 模板架构再基线、BFF/渲染/缓存/stream 边界与推广策略（Proposed，待 P0-008A 接受）。

## 22. 主要风险

- 继续扩展 Phase 0 runner 导致验证代码成为生产核心。
- 过早冻结 Runtime 选型导致重复建设或供应商锁定。
- 只有直接 RAGFlow smoke，没有跨仓 E2E。
- 身份占位长期存在，后期无法回填所有权。
- 外部副作用只做本地幂等，重试产生重复对象。
- 多 Agent 共享上下文导致泄露、膨胀和不可评估。
- 长期记忆无纠错/删除机制导致污染。
- 只完成后端脚本而浏览器刷新/HITL/引用/治理链路不可用，形成“API 完成、产品未完成”。
- 浏览器直接编排跨仓或持有服务凭据，绕过领域与授权边界。
- SSE 增量被前端误当真相源，断网、多标签或陈旧事件覆盖服务端终态。
- 规划过细但没有门禁，文档与实现再次漂移。

每个风险必须在实施计划中映射到任务、测试或显式接受记录。

## 23. 架构冻结规则

本 v5 在 Phase 0 前是候选基线。以下条件满足后标记为 Baseline Accepted：

1. ADR-001~006 完成并有运行证据。
2. Artifact 和 Retrieval 契约通过 consumer/provider tests。
3. 执行身份模型通过 checkpoint/resume/retry Spike。
4. Runtime 分支已按 ADR-001 激活，未选分支明确停止。
5. 四仓负责人确认数据所有权、契约所有权和删除责任。
6. Web/Admin 前端边界、浏览器身份、Citation DTO 和 stream reconciliation 已分别进入 ADR-004/005/007 与 Runtime Spike 证据。
7. ADR-013 已接受，P0-007A/A2/B/C 通过且没有要求三个 Admin 新增 Node SSR 运行时；React Admin v1 有完整能力矩阵、固定版本、固定 commit 干净重建/dry-run 原地替换证据和 Vue 对照/迁移文档。P0-007A 单独通过不得触发迁移。
8. ADR-014 已接受，P0-008A/B/C 通过；Next Web v2 有固定版本、真实 Research streaming/HITL/citation 试点、多副本自托管证据和旧模板回滚路径。

这是进入 M1a 的架构基线冻结。Memory/Subagent 相关边界在 M1a.5 再做二次冻结；之后仍允许通过 ADR 修改，但禁止实现先行、文档事后追认。

## 24. 参考

- LangGraph：durable execution、persistence、interrupt、streaming。
- LangChain：model/tool/message protocol 与 multi-agent patterns。
- LangGraph/Agent Server：Thread、Run、Store、queue worker 和 deployment architecture。
- OpenTelemetry：trace、metric、log correlation。
- Kubernetes：workload identity、NetworkPolicy、security context、probes、HPA/PDB。
