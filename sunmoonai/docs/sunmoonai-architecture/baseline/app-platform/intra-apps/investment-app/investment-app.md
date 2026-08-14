# investment-app

> 仓库路径 `/home/zymun/investment-app`。深读基线：2026-08-13（后端约 15600 行 Python 含
> 测试/脚本、契约锁、迁移链、两个前端、父仓文档）。App 之间的公共形态见
> `baseline/app-platform/inter-apps/app-platform.md`。

## 1. 概要

投资研究与智能体域 App（曾用名 research-app）。拥有 Session/Thread/Run/Attempt/Invocation、
Graph/Runtime 与 Agent 产品状态；**不接管 Info/Knowledge 领域事实**。旧 Research 四组件无
运行态（回滚面为零），历史材料只在冻结标签，不得复制回活动架构。

### 仓库拓扑

```
investment-app/
├── contracts/
│   ├── README.md                              # 消费锁治理规则
│   └── knowledge-retrieval-provider-lock.json # retrieval/v1 消费锁（真源在 knowledge-app）
├── docs/（只读历史性质材料）
├── investment-backend/（app/ 包根 + db-provisioner + 三个 access-bootstrap + mybuild）
├── investment-admin-frontend/app/    # 运营面（Next.js）
└── investment-web-frontend/app/      # 用户面
```

发布：三子仓门禁 → 不可变 digest 写入 K8s 仓 `release.json`（schema 2，正式 2.0.0，禁重构建）；
完整发布规则见 §3.2。

## 2. 重要点

1. **命名护栏**：合法领域概念可保留 `research` 命名（如 `research_web_pilot` graph），但
   应用/基础设施身份必须逐项为 `investment-*`。
2. **检索无授权证据 = 失败，不是空答案**（pilot 链硬规则）。
3. **resume token 原子消费后永不复用**：消费后 transport 失败必须落终态 failed。
4. **citation source 只回同源 BFF 路径**（`/api/citation-sources/{evidence_id}`），永不重定向
   到 provider 控制的 URI。
5. **Run 状态机四终态不可转出** + RunBudget 四维限额（steps/tool_calls/llm_calls/input_tokens，
   默认 20/20/20/120000）。
6. **验收红线**：禁 fake SSE、fake citation、mock retrieval、hardcode graph；Pilot 七件套
   配置缺任一即拒绝启动相关功能。
7. **Agent v4 流量门**：`agent_v4_traffic_enabled` 关闭时全部 `/api/agent` 返回 404；SSE
   先订阅 Redis pub/sub 再读 DB 快照回放，防窗口丢事件。
8. **消费锁纪律**：retrieval/v1 真源在 knowledge-app；无 provider+consumer 双测的锁更新
   不是有效升级。

## 3. 架构

### 3.1 领域边界与命名

未来 research-app 边界：未来通用研究 App 必须从届时已验收的 tpl-app 全新实例化（独立仓库/
身份/数据库/对象空间/消息资源/契约），不继承旧 Research 身份，也不得把 Investment 的研究数据
自动归属给它；当前拓扑中的"研究能力"默认全部属于 investment-app（详见
`../../inter-apps/app-platform.md` §10）。

### 3.2 发布规则

三子仓各自过质量门禁 → 不可变候选 tag 推 `harbor.sunmoonai.com:30443/app-images` → 镜像 digest 写入 K8s 仓 `investment-app/deployment/bundle/release.json`（schema 2、`formal_release=true`、release_id `v20-investment-001`）→ 用 `tpl-app/k8s-deployment` 脚手架部署 → **正式版本 `2.0.0`，禁止重新构建再打 tag**；K8s 清单必须引用 `repository@sha256:...`。

### 3.3 契约消费侧（retrieval/v1 锁）

- `contracts/knowledge-retrieval-provider-lock.json`：provider=knowledge-app，contract=`sunmoonai.knowledge.retrieval`，major=1，钉住三个 schema 的 sha256（request `1a09240f...`、response `1a0fef96...`、citation `b5cf350f...`）。
- 规则：唯一可编辑真源在 `knowledge-app/contracts/retrieval/`；契约 CI 必须下载/检出 provider 制品、设 `KNOWLEDGE_RETRIEVAL_CONTRACT_DIR` 并跑消费方测试；**没有 provider+consumer 双测的锁更新不是有效升级**；生成/复制的 schema 不得成为第二真源。
- 后端 `app/domain/agent/knowledge.py` 是契约的客户端领域模型：KnowledgeQuery / KnowledgeEvidence / Citation（`from_evidence` 投影、source_href 必须 `^/api/citations/{uuid}/source$`）/ KnowledgePort，字段与 provider 的 retrieval DTO 严格对齐（extra=forbid）。

### 3.4 Agent 领域模型（domain/agent）

- **Run 状态机**：created→running→{waiting,completed,failed,cancelled,budget_exceeded}；waiting→{running,failed,cancelled}；四个终态不可转出（`RUN_STATUS_TRANSITIONS` + `validate_run_status_transition`）。
- **RunBudget** 四维限额（steps/tool_calls/llm_calls/input_tokens，默认 20/20/20/120000），consume_* 不可变累加，超限产出 `AgentError(budget_exceeded)`。
- **消息与事件**：StoredMessage（schema_version + `upcast_stored_message` 升级器）；DomainEvent/UIEvent/LiveDelta 均带 RunLineage（session/run/root/parent）。
- **工具端口**：ToolExecutionPort/ToolResultHandler → ToolResultProjection（llm_message + artifacts + domain_events）；ArtifactRef 只存引用。
- **记忆**：AgentMemory（scope/kind/confidence/sensitive/ttl）+ WindowMemoryPolicy（session 级最近 20 条、默认排除 sensitive）。
- **AgentProfile**：allowed/denied tools（deny 优先，allow 空=全放行）、memory_policy、ragflow_binding_key。
- **graph state 分层护栏**（state.py）：FORBIDDEN_STATE_KEYS 禁止 event_history/long_term_memories 等跨层键进 state；FORBIDDEN_ARTIFACT_KEYS 禁止 body/content 进 artifact（只存引用）；merge_versioned_dict 按版本号、append_unique_by_id 按 id 合并。

### 3.5 LangGraph 图族（infrastructure/graph）

| 图 | 用途 |
|---|---|
| `walking_skeleton` | Phase-0：ask_user interrupt → side_effect 节点，验证 checkpoint/resume 闭环 |
| `pilot_graph`（`research_web_pilot`, p0-008c-v1） | 产品契约试点：prepare **强制要求真实 draft + ≥1 真实 citation** → request_approval `interrupt(confirmation)` → finalize（拒绝词集 → 拒绝摘要）；`approval_action_id` = uuid5(NAMESPACE_URL, `sunmoonai:p0-008c:{run_id}:approval`) 稳定派生 |
| `first_m1_graph` | planner-react 雏形：normalize_input → create_or_update_plan（消耗 budget，超限转 budget_exceeded）→ summarize |

- checkpointer 用 `PostgresSaver`（`phase0_postgres_checkpointer`，asyncpg URL 转 psycopg 同步 URL）；`LangGraphRuntimeService` 统一 stream/resume 封装。
- 验收红线（CLAUDE.md）：**禁止 fake SSE、fake citation、mock retrieval、hardcode graph**。

### 3.6 两条运行链

#### Pilot 链（真产品链，Web 用户面）

- **API 面**（`PilotService`）：create_run 要求 Celery producer 可用，idempotency_key 幂等建 run，dispatch 失败立即置 failed 并写 `failed` 浏览器事件；snapshot 回放 browser events 聚合 citation/input_required/summary；resume 用 `consume_resume` **原子消费 action token**——消费后 transport 失败必须落终态 failed（token 永不可复用）；`citation_source` 先 `assert_citation_owner`，只返回同源 BFF 路径 `/api/citation-sources/{evidence_id}`，**永不重定向到 provider 控制的 URI**。
- **Worker 面**（`tasks/pilot_agent_graph.run`）：终态直接返回 → running 事件 → 调 KnowledgeRetrievalClient（dataset_keys=`AGENT_PILOT_DATASET_KEYS`、top_k 5、token_budget 4000、tenant `sunmoonai`、actor_type human、`delegated_run_id=run_id`）→ **无授权证据即失败** → `Citation.from_evidence` 逐条写 citation 事件 → 每步检查 cancel → `OpenAICompatiblePilotLLM`（OpenAI 兼容 /chat/completions，temperature 0，只取 top5 证据各 4000 字，system prompt 要求只据证据回答、不泄露内部标识）→ 跑 pilot graph **必须 interrupt**（否则报错）→ input_required 事件 + waiting（resume_token=action_id）→ resume 分支拿 summary（空则报错）→ delta + completed。任何异常：非终态则置 failed + `pilot_failed` 事件后 re-raise。

#### Agent v4 链（Admin 面，流量门控）

- `agent_v4_traffic_enabled` 关闭时全部 `/api/agent` 返回 404（流量门）。
- 端点（`require_investment_admin`）：POST `/agent/sessions`、`.../runs`、`/agent/runs/{id}/resume`、`GET .../events`、`GET .../stream`（SSE：**先订阅 Redis pub/sub 两个 channel 再读 DB 快照回放**，避免窗口丢事件；UI 事件按 replayed_event_ids 去重，LiveDelta 不去重且防无界集合内存泄漏）。
- Worker（`tasks/agent_graph.run`）：`RedisSessionLock`（拿不到锁 → session_locked RunFailed；执行前后 renew，丢失即报错）→ walking skeleton + PostgresSaver → `__interrupt__` 转 waiting（resume_token `phase0:{run_id}`）→ `ToolSideEffectService.record_once` 幂等副作用 → 事件链 RunStarted/UserInputReceived/HumanInputRequested/ToolCallStarted/ToolCallCompleted/RunCompleted，`DBEventSink` 同写 DB + Redis。

### 3.7 HTTP 表面与三类 Service Identity

`routes.py` = admin/web 认证 + diagnostics + web interactions（模板同构）+ `agent_router` + `pilot_runtime_router`。

**Internal 面**（`/api/internal/v1/investment`，端点级 `require_pilot_service`）：POST `/runs`、GET `/runs/{id}`、POST `/runs/{id}/commands`（resume/cancel 判别联合）、GET `/runs/{id}/events`（SSE：header/query cursor 冲突 400、回放+pubsub 去重、10s heartbeat、completed/failed/cancelled 即关流、no-cache + X-Accel-Buffering: no）、GET `/citations/{evidence_id}/source`。所有端点用 `X-Delegated-Actor-ID` 头携带被委托用户（Web BFF 委托模型，DelegatedUser 含 policy_version）。

| 身份 | 方向 | 关键配置 |
|---|---|---|
| `PilotServiceAuthVerifier` | 入站（Web BFF → Investment internal） | application `sunmoonai-investment-runtime`、scope `investment:runtime`、audience + subject allowlist、policy `investment-runtime-v1` |
| `ServiceIdentityVerifier` | 入站通用 | `service_auth_subject_bindings_json`：subject→最大 scope 集，token_scopes ⊆ 绑定 ∧ required ⊆ token |
| `RetrievalServiceTokenProvider` | 出站（→ Knowledge retrieve） | client-credentials、application `sunmoonai-investment-knowledge-retrieve`、scope `knowledge:retrieve`、内存 token 缓存（提前 30s 刷新、asyncio 锁） |
| `DownstreamServiceClient` | 出站跨 App 通用 | 路径前缀 allowlist（默认 `/api/internal/v1`）、**拒绝指向自己 Backend 的 URL**、生产强制 verify_ssl、X-Operation-ID |

`KnowledgeRetrievalClient`：请求带 `contract_version:1`；401/403→Authorization 错、超时/HTTP→Unavailable、响应校验 contract_version 后剥离并解析领域模型（Protocol 错）。错误四分类：NotConfigured/Authorization/Unavailable/Protocol。

### 3.8 数据模型与迁移（head = `20260811_0005`）

1. `20260708_0001` agent phase0：LangGraph 三表（checkpoints/checkpoint_blobs/checkpoint_writes，thread_id 索引）+ agent sessions/runs 领域表。
2. `20260712_0002` auth_identity（auth_user）。
3. `20260729_0003` agent_pilot：pilot runs 表（owner_actor_id、uq idempotency_key、title≤512、user_input）+ pilot run state（run_id PK、resume_action_id、cancel 标志等）。
4. `20260809_0004` outbox primitives（模板原语）。
5. `20260811_0005` uuid 默认值补齐。

### 3.9 Investment 专属配置（core/config.py 647 行）

- `app_slug=investment`；celery_queue `investment.default`；Redis 前缀 `investment:agent`。
- **流量门**：`agent_v4_traffic_enabled`（默认 false）；`agent_session_lock_ttl_seconds` 300。
- **Pilot 七件套**（`require_agent_pilot()` 缺任一即拒绝启动相关功能，且强制 knowledge_retrieval_enabled）：internal_auth application/audience/subjects/scope/policy + dataset_keys + LLM 四键（base_url/api_key/model 默认 qwen-plus/timeout≤120）。
- **Knowledge 出站**：`knowledge_retrieval_url` + client_id/secret + scope `knowledge:retrieve`；`knowledge_retrieval_enabled` = 三键齐备。
- **Downstream 边界**：base_url/client/scope/path 前缀；校验下游 origin 不得是本地自身 origin。
- 认证表面沿用模板：cookie `sunmoonai_investment_{surface}_sid`、admin 强制 scope `investment:admin`、Web 可开自助注册（`GET /api/auth/web/signup`，Casdoor signup endpoint + 授权码 PKCE，Admin 关闭注册）。前端 AUTH_APP 枚举在模板 `tpl|info|knowledge|research` 基础上领域扩展加入 `investment`（默认值）。

### 3.10 前端

与模板/info/knowledge 同构（Next.js + shadcn + Tailwind v4 + next-intl + standalone + proxy.ts CSP nonce）：

- **admin**：`(dashboard)/research/runtime` 页 + `research-runtime-panel.tsx`（当前为 Agent v4 API 说明面板）+ dashboard/settings/reference/rich-reference/forbidden + crud/rich 组件套件。
- **web**：`research-workspace.tsx` 是 Pilot 用户面——createRun（contract_version 1、`crypto.randomUUID()` 幂等键）→ RunWorkspace + `useRunProjection`（interaction SSE 投影，与模板 interaction 契约同构）；`lib/common/api-client.ts` 只允许同源 `/api/` 路径、ApiProblem（code/message_key/retryable/correlation_id）、非安全方法带 csrf、`redirect: 'manual'`、token 不落 localStorage。

### 3.11 关键边界规则速查

| 规则 | 位置 |
|---|---|
| pilot draft/citation 必须真实，禁止 mock/fake 验收 | pilot_graph / CLAUDE.md |
| resume token 原子消费后永不复用，transport 失败即终态 failed | PilotService._fail_consumed_resume |
| citation source 只回同源 BFF 路径，不重定向 provider URI | PilotService.citation_source |
| 检索无授权证据 = 失败，不是空答案 | pilot_agent_graph |
| SSE 先订阅后回放，防窗口丢事件 | agent_routes / pilot_runtime_routes |
| artifact/state 只存引用不存内容体 | graph/state.py |
| 消费锁升级需 provider+consumer 双测 | contracts/README.md |
| 旧 Research 无运行态，历史只在冻结标签 | 部署现状 |

## 4. 关联

- 证据上游（retrieval 契约真源）：`../knowledge-app/knowledge-app.md`。
- 母模板：`../tpl-app/tpl-app.md`；公共形态与 Research 命名治理：`../../inter-apps/app-platform.md`（§10）。
- 部署声明：`../k8s/k8s.md`；平台间关系：`../../../sunmoonai/architecture.md`。
