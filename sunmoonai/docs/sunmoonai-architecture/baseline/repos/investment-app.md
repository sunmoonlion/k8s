# investment-app

> 仓库 `sunmoonlion/investment-app`
> 最后更新：2026-08-15 ｜ 验证时点：2026-08-15（对代码取证）
> 跨仓规则见 [`../shared/`](../shared/)；全局地图见 [`../map.md`](../map.md)

## 1. 这个仓是什么

投资研究与智能体域 App。单一 FastAPI 后端 `investment-backend` 同时承载 Admin/Web 浏览器身份、
Internal Pilot Runtime、Phase 0 Agent API 与 Celery Worker。
对外提供 OIDC 会话鉴权、Web 交互契约端点、Admin Agent 控制面、Internal Pilot 运行面；
作为 consumer 消费 knowledge-app 的检索契约。五仓中运行时最复杂的一个。

## 2. 目录地图

| 路径 | 装什么 | 什么任务会动它 |
| --- | --- | --- |
| `investment-backend/app/app/domain/agent/` | Run/Session 枚举、预算、命令、Knowledge 端口 | 改状态机、预算、领域约束 |
| `investment-backend/app/app/application/agent/` | RunService、PilotService、EventSink、Timeline 投影 | 改编排、事件投递、快照 |
| `investment-backend/app/app/infrastructure/graph/` | LangGraph 图：`walking_skeleton`、`pilot`、`first_m1`、两个 spike | 改执行链、检查点、节点 |
| `investment-backend/app/app/tasks/` | Celery 入口 `agent_graph`、`pilot_agent_graph` | 改 Worker 执行路径 |
| `investment-backend/app/app/interfaces/` | HTTP 路由（admin/web/agent/pilot） | 改前缀与鉴权 |
| `investment-backend/app/alembic/versions/` | 线性迁移链 | 表结构变更 |
| `investment-admin-frontend/` | Next.js 管理端 | Admin UI、诊断 |
| `investment-web-frontend/` | Next.js 用户端 | Web UI、BFF `/api/auth` |
| `contracts/` | knowledge 检索 consumer 锁 | 升级跨仓契约 |
| `.cursor/rules/` | 仓内局部规则 | 前端与脚本约束 |

## 3. 改动前必读的硬规则

| 规则 | 代码位置 | 违反后果 |
| --- | --- | --- |
| Run 状态仅允许 `RUN_STATUS_TRANSITIONS` 内转换；`completed`/`failed`/`cancelled`/`budget_exceeded` 四终态无出边 | `domain/agent/runtime.py:34-59`；写入点 `repositories.py:149`、`pilot_repository.py:196` | `ValueError: invalid run status transition` |
| `tool_side_effects` 以 `tool_call_id` 为 PK + `ON CONFLICT DO NOTHING` | `repositories.py:272-295`；`side_effect_service.py:20-31` | 重复副作用返回 `inserted=False` |
| Agent run 幂等：`session_id` + `idempotency_key` 唯一 | `repositories.py:64-77`；`20260708_0001_agent_phase0.py:93` | 重复 create 不插新行 |
| Pilot create 幂等：`owner_actor_id` + `idempotency_key` 唯一 | `pilot_repository.py:37-60` | 重复 create 返回 `(row, False)` |
| Pilot resume token 一次性：置位后不可复用 | `pilot_repository.py:373-415`；`pilot_service.py:135-158` | 再调抛 `ValueError`；dispatch 失败转 `failed` |
| Session 并发用 Redis NX 锁，抢锁失败即 failed | `session_lock.py:16-28`；`agent_graph.py:70-90` | run 终态 `failed`，事件 `RunFailed` |
| Agent v4 路由默认关闭 | `config.py:133-135`；`agent_routes.py:26-35` | 全 `/api/agent/*` 返回 404 |
| Pilot Celery dispatch 需 `AGENT_PILOT_ENABLED=true` | `celery_producer.py:84-85` | `CeleryNotConfiguredError` |
| Pilot Internal API 需 Bearer + `require_agent_pilot()` 全量配置 | `pilot_service_auth.py:62-78`；`config.py:615-632` | 401/403/503 |
| Knowledge 检索无凭据时抛 `KnowledgeRetrievalNotConfiguredError` | `knowledge_retrieval.py:131-135`；`config.py:600-605` | Pilot 检索失败 |
| Pilot 检索零 evidence 直接失败 | `pilot_agent_graph.py:134-137` | run `failed` |
| 生产禁 `REFERENCE_INTERACTION_ENABLED=true` | `config.py:263-266` | 启动 `ValueError` |
| GraphState 禁跨层键与大对象 body | `state.py:71-92` | 节点抛 `ValueError` |

## 4. Agent 运行时

### 4.1 状态机

| 状态 | 合法转换 | 定义位置 |
| --- | --- | --- |
| `created` | → `running` / `failed` / `cancelled` | `models.py:18-25`；转换表 `runtime.py:34-48` |
| `running` | → `waiting` / `completed` / `failed` / `cancelled` / `budget_exceeded` | 同上 |
| `waiting` | → `running` / `failed` / `cancelled` | 同上 |
| `completed` `failed` `cancelled` `budget_exceeded` | ∅（终态） | `runtime.py:44-47` |
| `SessionStatus` | 枚举存在，**无转换校验函数**，与 run 同名字符串同步写入 | `models.py:9-15`；`repositories.py:168-177` |
| Pilot 对外状态映射 | DB `waiting` → 对外 `waiting_for_input` 等 | `pilot_service.py:19-27` |

### 4.2 预算：定义在，门禁不在

| 维度 | 默认值 | 超限行为 |
| --- | --- | --- |
| `max_steps` | 20（`runtime.py:63`） | `budget.check()` → `AgentError(budget_exceeded)`（`runtime.py:73-78`） |
| `max_tool_calls` | 20（`runtime.py:64`） | 同上（`:79-84`） |
| `max_llm_calls` | 20（`runtime.py:65`） | 同上（`:85-90`） |
| `max_input_tokens` | 120000（`runtime.py:66`） | 同上（`:91-96`） |

**两条生产链都不调用 `RunBudget`。**全仓 `RunBudget` 只出现在两处：
定义处 `domain/agent/runtime.py`，与非生产图 `infrastructure/graph/first_m1_graph.py`
（该图仅被 `tests/` 与 `scripts/agent_golden.py` 使用）。
`tasks/agent_graph.py`、`tasks/pilot_agent_graph.py`、`graph/walking_skeleton.py` 均无引用
（验证：`rg -l RunBudget investment-backend/app/app`）。
`pilot_agent_graph.py:122` 的 `token_budget=4000` 是 Knowledge 检索参数，与 `RunBudget` 无关。

### 4.3 运行链

| 链 | 入口位置 | 面向的前缀 | 门控 |
| --- | --- | --- | --- |
| Phase 0 Walking Skeleton | `tasks/agent_graph.py:197-203` | `/api/agent/*`（`agent_routes.py:31-35`） | `AGENT_V4_TRAFFIC_ENABLED`，默认 false |
| P0-008C Pilot | `tasks/pilot_agent_graph.py:269-271` | `/api/internal/v1/investment/*`（`pilot_runtime_routes.py:35-38`） | dispatch 需 `AGENT_PILOT_ENABLED`；路由本身无 flag |
| Web Interaction | `interfaces/http/web/interactions.py:34` | `/api/web/v1/*` | Reference / Unavailable 二选一，**不经 Agent 服务层**（见 §8） |
| `first_m1_graph` | `first_m1_graph.py:80-89` | 无 HTTP | 仅 tests 与 `scripts/agent_golden.py` |
| execution / runtime selection spike | `execution_identity_spike.py`、`runtime_selection_spike.py` | 无 HTTP | 仅 `scripts/run_*_spike.py` |

### 4.4 Phase 0 链步骤

| 步骤 | 做什么 | 位置 |
| --- | --- | --- |
| 1 | 建 session/run，可选 Celery dispatch | `run_service.py:22-52` |
| 2 | Worker 加载 run，已完成则直接返回 | `agent_graph.py:56-61` |
| 3 | 抢 session 锁，失败则 failed | `agent_graph.py:66-90` |
| 4 | 状态转 `running` | `agent_graph.py:94-96` |
| 5 | LangGraph stream `walking_skeleton` + Postgres checkpointer | `agent_graph.py:109-128`；`walking_skeleton.py:33-40` |
| 6 | Interrupt：写 `HumanInputRequested`，状态 `waiting`，token `phase0:{run_id}` | `agent_graph.py:132-146` |
| 7 | 副作用记一次 | `agent_graph.py:160-164` |
| 8 | 完成写 `RunCompleted`；异常写 `RunFailed` | `agent_graph.py:172-191` |

### 4.5 Pilot 链步骤

| 步骤 | 做什么 | 位置 |
| --- | --- | --- |
| 1 | 建 session/run/pilot_requests/controls + dispatch | `pilot_service.py:34-68`；`pilot_repository.py:29-137` |
| 2 | HTTP POST Knowledge 检索（OAuth client credentials） | `pilot_agent_graph.py:116-133`；`knowledge_retrieval.py:131-179` |
| 3 | LLM 草稿（OpenAI 兼容 HTTP） | `pilot_agent_graph.py:151-159` |
| 4 | Graph interrupt 要求 approval，写 `input_required` | `pilot_agent_graph.py:162-205` |
| 5 | Resume：`Command(resume=...)` → summary → `completed` | `pilot_agent_graph.py:207-237` |
| 6 | Cancel：`cancel_requested` + 状态 `cancelled` | `pilot_repository.py:344-371` |

### 4.6 检查点与恢复

| 机制 | 位置 |
| --- | --- |
| LangGraph PostgresSaver（表 `checkpoints` / `checkpoint_blobs` / `checkpoint_writes`） | `checkpointer.py:20-25`；迁移 `20260708_0001_agent_phase0.py:20-60` |
| `thread_id` = `session_id` | `agent_graph.py:106`；`pilot_agent_graph.py:112` |
| Resume 输入 | 两链均为 `Command(resume=...)`（`agent_graph.py:128`；`pilot_agent_graph.py:207-210`） |
| 跨连接 checkpoint 验证脚本 | `scripts/validate_agent_phase0.py:53-58` |

### 4.7 事件与流式

| 事件族 | 定义/写入位置 | 投递方式 |
| --- | --- | --- |
| Domain 七种（`RunStarted` `UserInputReceived` `HumanInputRequested` `ToolCallStarted` `ToolCallCompleted` `RunCompleted` `RunFailed`） | 写入 `agent_graph.py:99-188` | `DBEventSink.append` → PG `session_events` + Redis 两个 channel（`event_sink.py:20-41`） |
| UI 投影（`TimelineRunStarted` 等） | 映射表 `timeline_projector.py:39-47` | SSE `/api/agent/sessions/{id}/stream`（`agent_routes.py:153-220`） |
| `LiveDelta` | `models.py:73-78` | Redis `session_deltas_channel` |
| Pilot Browser 六种（`status` `citation` `input_required` `delta` `completed` `failed`） | 写入 `pilot_agent_graph.py`；包装 `pilot_repository.py:260-268` | `session_events.event_type='BrowserRunEvent'` + Redis `pilot_run_events_channel` |
| Web 契约 RunEvent 七种（含 `heartbeat`） | `application/dto/interaction.py:111-180` | Reference 适配器内存 yield；**真实路径未接 Pilot**（`ports/web_interaction.py:132-185`） |

## 5. 数据与迁移

| 迁移文件 | 建了哪些表 | 位置 |
| --- | --- | --- |
| `20260708_0001_agent_phase0.py` | `checkpoint_migrations`、`checkpoints`、`checkpoint_blobs`、`checkpoint_writes`、`agent_sessions`、`agent_runs`、`session_events`、`tool_side_effects`（共 8 张） | `investment-backend/app/alembic/versions/` |
| `20260712_0002_auth_identity.py` | `auth_user`；另加 `agent_sessions.owner_actor_id` 列 | 同上 |
| `20260729_0003_agent_pilot.py` | `agent_pilot_requests`、`agent_pilot_controls` | 同上 |
| `20260809_0004_outbox_primitives.py` | `outbox_message`、`inbox_message`（**未接线**，见 §8） | 同上 |
| `20260811_0005_uuid_defaults.py` | 无新表；`auth_user.id` server default | 同上 |

链顺序真源 `tests/test_kernel_invariants.py:39-57`；验证：
`cd investment-backend/app && uv run pytest tests/test_kernel_invariants.py::test_one_linear_canonical_migration_chain -q`

## 6. 契约与对外接口

| 契约/接口 | 真源位置 | 角色 |
| --- | --- | --- |
| Knowledge Retrieval v1 | consumer 锁 `contracts/knowledge-retrieval-provider-lock.json`；provider 在 knowledge-app | **consumer**；测试 `tests/test_knowledge_retrieval_contract.py:30-37` |
| Web Interaction RunSnapshot/RunEvent | `application/dto/interaction.py` | provider（BFF 面） |
| Pilot Runtime DTO | `application/dto/pilot_runtime.py` | provider（Internal 面） |
| Admin OIDC | `/api/auth/admin/*`（`interfaces/http/admin/auth.py:23`） | provider |
| Web OIDC | `/api/auth/web/*`（`interfaces/http/web/auth.py:24`） | provider |
| Admin Agent v4 | `/api/agent/*`（`endpoints/agent_routes.py:31-35`） | provider，默认 404 |
| Internal Pilot | `/api/internal/v1/investment/*`（`endpoints/pilot_runtime_routes.py:35-38`） | provider |
| Celery ping 诊断 | `/api/admin/v1/diagnostics/tasks/ping`（`admin/diagnostics.py:10-18`） | provider |
| 健康检查 | `/api/health`、`/health/live`（`bootstrap/api.py:135-157`） | provider |

## 7. 本地怎么跑与怎么验

| 我要做什么 | 命令 | 定义位置 |
| --- | --- | --- |
| DB/Redis 合并进 `.env` | `cd investment-backend/db-access-bootstrap && ./merge-and-generate-app-env.sh external` | `db-access-bootstrap/README.md:47-51` |
| 启动 API | `cd investment-backend/app && uv run uvicorn app.main:app --host 0.0.0.0 --port 8001` | `db-access-bootstrap/README.md:113`；`app/main.py:3` |
| 跑迁移 | `uv run python -m app.bootstrap.migration upgrade head` | `bootstrap/migration.py:20-38` |
| 启动 Worker | `uv run celery -A app.bootstrap.worker worker -Q investment.default` | `bootstrap/worker.py:1-7`；队列 `config.py:122-125` |
| 单测 | `uv run pytest` | `pyproject.toml:33-35` |
| Phase 0 本地验收 | `uv run python scripts/validate_agent_phase0.py` | `scripts/validate_agent_phase0.py:253-278` |
| 已部署 HTTP 验收 | `python scripts/validate_deployed_agent_http.py --base-url ...` | `scripts/validate_deployed_agent_http.py:42-49` |
| 检索契约锁校验 | `KNOWLEDGE_RETRIEVAL_CONTRACT_DIR=... uv run pytest tests/test_knowledge_retrieval_contract.py -q` | `test_knowledge_retrieval_contract.py:33-37` |
| 环境变量 | 复制 `investment-backend/app/.env.example` | `.env.example:1-108` |

## 8. 已知未实现

| 容易被误认为已完成的东西 | 实际状态 | 位置 |
| --- | --- | --- |
| `/api/web/v1` 接了 Agent 服务层 | **未接**。默认 `UnavailableWebInteractionAdapter` 抛 503；开 flag 也只是内存 Reference 适配器，不调 `AgentRunService` / `PilotService` | `ports/web_interaction.py:43-92,274-277`；`interactions.py:66-72` |
| 存在 Attempt / Invocation 表或实体 | **无 DB 表**。仅 spike 内存类 `RunAttempt` / `AgentInvocation`，未进主链 | `execution_identity_spike.py:43-128`；迁移目录无对应表 |
| 规范里写有「禁 fake SSE / 禁 mock 检索」红线 | **无该字面条文**。`investment-backend/CLAUDE.md` 仅通用编码约定；最接近的是生产禁 reference（`config.py:263-266`）与前端禁 raw LangGraph 事件（`.cursor/rules/31-frontend-web.mdc:12`） |
| `RunBudget` 在生产链生效 | 仅在 `first_m1_graph` 与测试；两条生产链无引用（见 §4.2） | `rg -l RunBudget app/` 仅两处 |
| `CancelRunCommand` 有 HTTP 端点 | 领域命令已定义，无 `/api/agent` cancel 路由 | `commands.py:31-37` |
| `AgentMemoryService` 已接入 | 类存在，未接入 worker 任务 | `memory_service.py:14-29` |
| Outbox 已接入 Agent/Pilot | 迁移与仓库存在，零业务调用点 | `repositories/outbox.py:11-14` |
| `GraphRuntimeService.resume` 可用 | 基类抛 `NotImplementedError`；生产用 `LangGraphRuntimeService` 子类 | `graph_runtime_service.py:26-31`；`langgraph_runtime.py:14-21` |
| `DeterministicFakeLLM` 用于 pilot | pilot 走真实 HTTP；fake 仅测试用 | `fake_llm.py:6-22`；`pilot_agent_graph.py:151-156` |
| Pilot Internal → Web BFF 有桥接 | 不存在调 Pilot 的 `WebInteractionPort` 实现 | `ports/web_interaction.py:28-51` |
| Celery 未配置时 create run 会执行图 | `enqueued=False`，图不执行 | `run_service.py:36-44` |
| Pilot 为 M1 durable runner | 代码注释声明其为 isolated candidate，非 M1 runner | `pilot_graph.py:1-6`；`pilot_repository.py:18-24` |
