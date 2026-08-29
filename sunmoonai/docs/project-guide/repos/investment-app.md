# investment-app（投资研究智能体）

> 取证时点：2026-08-29 ｜ 骨架继承 [`tpl-app.md`](tpl-app.md)，本文只写它多出来的东西

## 1. 定位

智能体域：以 LangGraph 承载投资研究 run，向 knowledge 取检索证据，经人机交互产出结论。
消费 knowledge 的 retrieval v1 契约。

**五仓中领域代码最重的一个**：112 个文件 / 8531 行。也是唯一有完整状态机、
检查点恢复、事件流与副作用记账的仓——[`../../working/request-lifecycle.md`](../../working/request-lifecycle.md)
§7 的映射表以本仓为对象。

## 2. 结构（只列模板之外）

| 路径 | 装什么 |
| --- | --- |
| `domain/agent/` | `runtime.py`（状态机 + RunBudget）、`models.py`（DomainEvent/UIEvent/RunLineage）、`commands.py`、`knowledge.py`、`tools.py`、`profiles.py`、`memory.py`、`message_upcaster.py` 等 |
| `application/agent/` | `run_service.py`、`pilot_service.py`、`graph_runtime_service.py`、`side_effect_service.py`、`session_lock.py`、`event_sink.py`、`timeline_projector.py`、`memory_service.py` |
| `infrastructure/graph/` | `walking_skeleton.py`、`pilot_graph.py`、`first_m1_graph.py`、`langgraph_runtime.py`、`checkpointer.py`、`state.py` + 两个 spike |
| `tasks/agent_graph.py` | 生产链一（203 行） |
| `tasks/pilot_agent_graph.py` | 生产链二（271 行） |
| `interfaces/endpoints/agent_routes.py` | Admin Agent v4 面（默认关闭） |
| `interfaces/endpoints/pilot_runtime_routes.py` | Internal Pilot 面 |
| `contracts/knowledge-retrieval-provider-lock.json` | retrieval 契约**消费锁** |

## 3. 硬规则

模板五项不变量（79 行）+ UUID 双侧默认值检查（`:60`，与 knowledge 同款）。

运行期约束：

| 规则 | 违反后果 |
| --- | --- |
| Run 状态转换须在 `RUN_STATUS_TRANSITIONS` 内 | `ValueError: invalid run status transition` |
| Agent v4 路由默认关闭（`AGENT_V4_TRAFFIC_ENABLED` 默认 `False`） | 全部 `/api/agent/*` 返回 404 |
| Pilot 检索**零证据即失败**，不是空答案 | run `failed` |
| Pilot Internal API 需 Bearer + 全量 Pilot 配置 | 401/403/503 |
| resume token 一次性，置位后不可复用 | 再调抛 `ValueError` |
| 抢会话锁失败即 failed | run 终态 `failed` |
| `tool_side_effects` 以 `tool_call_id` 为 PK + `ON CONFLICT DO NOTHING` | 重复副作用返回 `inserted=False` |
| GraphState 禁跨层键与大对象 body | 节点抛 `ValueError` |

## 4. 关键机制

### 4.1 Run 状态机（`domain/agent/runtime.py:34-59`）

```
created  → running / failed / cancelled
running  → waiting / completed / failed / cancelled / budget_exceeded
waiting  → running / failed / cancelled

completed · failed · cancelled · budget_exceeded  → ∅（四终态，出边为空集）
```

集中校验在 `validate_run_status_transition()`，不散落在各写入点。

### 4.2 两条生产链

| 链 | 入口 | 面 | 门控 |
| --- | --- | --- | --- |
| Walking Skeleton | `tasks/agent_graph.py` | `/api/agent/*` | `AGENT_V4_TRAFFIC_ENABLED`，**默认 false** |
| Pilot | `tasks/pilot_agent_graph.py` | `/api/internal/v1/investment/*` | dispatch 需 `AGENT_PILOT_ENABLED` |

**Pilot 链步骤**：建 run（`owner_actor_id` + `idempotency_key` 幂等）→ dispatch
→ HTTP POST knowledge 检索（OAuth client credentials）→ **零证据即失败**
→ `Citation.from_evidence` 逐条写 citation 事件 → LLM 草稿（OpenAI 兼容）
→ graph interrupt 要求 approval，写 `input_required` → resume 原子消费 token
→ summary → `completed`。

**Walking Skeleton 步骤**：加载 run（已完成直接返回）→ 抢 Redis 会话锁（失败即 failed）
→ 转 `running` → LangGraph stream + Postgres 检查点 → interrupt 写
`HumanInputRequested` 并转 `waiting` → 副作用记一次 → `RunCompleted` / `RunFailed`。

### 4.3 检查点与恢复

`PostgresSaver.from_conn_string()`（`infrastructure/graph/checkpointer.py:22`），
asyncpg URL 转 psycopg 同步 URL。四张表 `checkpoints` / `checkpoint_blobs` /
`checkpoint_writes` / `checkpoint_migrations` 在迁移 `0001` 中建立。
`thread_id` = `session_id`；两链恢复都用 `Command(resume=...)`。

### 4.4 事件

| 事件族 | 内容 |
| --- | --- |
| Domain 七种 | `RunStarted` `UserInputReceived` `HumanInputRequested` `ToolCallStarted` `ToolCallCompleted` `RunCompleted` `RunFailed` |
| Pilot 浏览器六种 | `status` `citation` `input_required` `delta` `completed` `failed` |

`DBEventSink` 同写 PostgreSQL `session_events` 与 Redis 两个 channel。
SSE 端点**先订阅 Redis 再读 DB 快照回放**——代码注释明确记录了这样做是为了避免窗口丢事件。

### 4.5 预算：定义在，门禁不在

`RunBudget` 四维限额（`max_steps` / `max_tool_calls` / `max_llm_calls` 默认 20，
`max_input_tokens` 默认 120000），超限抛 `AgentError(budget_exceeded)`。

**但两条生产链都不调用它。**全仓仅三处引用：

```
domain/agent/runtime.py                     ← 定义
infrastructure/graph/first_m1_graph.py      ← 非生产图（仅 tests 与 scripts 使用）
tests/test_agent_runtime_budget.py          ← 其测试
```

**推论：`budget_exceeded` 这个 run 状态在生产中不可达。**

## 5. 数据

迁移链 5 个版本，线性：

```
20260708_0001_agent_phase0  → 8 张表：checkpoint_migrations / checkpoints /
                               checkpoint_blobs / checkpoint_writes /
                               agent_sessions / agent_runs / session_events / tool_side_effects
20260712_0002_auth_identity → auth_user；另加 agent_sessions.owner_actor_id
20260729_0003_agent_pilot   → agent_pilot_requests / agent_pilot_controls
20260809_0004_outbox_primitives → outbox_message / inbox_message（零调用）
20260811_0005_uuid_defaults → 无新表
```

幂等键两套：Agent run 用 `session_id + idempotency_key`；
Pilot run 用 `owner_actor_id + idempotency_key`。

## 6. 对外接口

| 接口 | 角色 |
| --- | --- |
| knowledge retrieval v1 | **consumer**（锁：`contracts/knowledge-retrieval-provider-lock.json`） |
| `/api/internal/v1/investment/*` | provider（Pilot Runtime，Bearer + 委托用户头） |
| `/api/agent/*` | provider，**默认 404** |
| Admin/Web OIDC、`/api/web/v1` | 同模板 |

## 7. 已知未实现

> **这张表由 `tests/test_dormant_capabilities.py` 守着**：每条休眠声明都有可执行
> 判据，能力一旦接线、或判据锚点被改名，测试即失败。改这张表前先跑那个测试。
> 机制说明见该文件的模块 docstring；它的边界是**保证已声明的条目不变陈旧**，
> 发现不了新出现的休眠能力——新增时手工加一条。


| 项 | 实际状态 |
| --- | --- |
| **`RunBudget` 在生产生效** | 未接线，见 §4.5。`budget_exceeded` 生产不可达。现有实现是内存态 pydantic model、随 graph state 传递，**进程一死即失**，结构上满足不了「跨 run／跨进程仍须正确」的判据。载体须换 PG——归入 [`../../dev-plan/README.md`](../../dev-plan/README.md) 的 **U3 四本账**，不是单独接线 |
| **Web 面接了 Agent/Pilot** | **未接**。`/api/web/v1` 默认 `Unavailable` 适配器 503；开 flag 也只是内存 reference 适配器，不调 `AgentRunService` / `PilotService` |
| Attempt / Invocation 表 | **无 DB 表**，仅 spike 内存类 |
| `AgentMemoryService` | 类存在，生产无调用方 |
| `CancelRunCommand` | 领域命令已定义，无对应 HTTP 端点 |
| `first_m1_graph` | 非生产图，仅 tests 与 `scripts/agent_golden.py` |
| 两个 spike | `execution_identity_spike` / `runtime_selection_spike`，不在生产链 |
| 失败原因码分流 | 库内已能区分 `dispatch_failed` 与 `resume_dispatch_failed`，但**消费侧无按码分流的重试逻辑** |
| 共享 Outbox | 迁移与仓库类在，零业务调用 |

## 8. 验证

```bash
cd <repo>/investment-app/investment-backend/app
uv sync --frozen && uv run ruff check . && uv run pyright && uv run pytest -q
uv run pytest tests/test_kernel_invariants.py -q

# Phase 0 本地验收
uv run python scripts/validate_agent_phase0.py
```

复核两条最要紧的：
```bash
# RunBudget 未接线：应只有 3 处
grep -rln RunBudget app tests | grep -v __pycache__

# 状态机与终态
sed -n '/^RUN_STATUS_TRANSITIONS/,/^}/p' app/domain/agent/runtime.py
```
