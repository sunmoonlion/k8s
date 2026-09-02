# investment-app Agent 总体架构可行性分析

> 取证时点：2026-09-02 ｜ 作者：opus
> 对象：`worktrees/opus/investment-app`、`worktrees/opus/k8s`（本机 HEAD）
> 参照：`/home/zym/repo/codex`、`/home/zym/repo/deepseek-harness`
>
> **每条断言附取证命令或文件行号。**未运行进程、未连集群、未起模型调用，见 §10。
>
> 与 [`agent-architecture-feasibility-opus.md`](agent-architecture-feasibility-opus.md)
> 的分工：**那份只回答"supervisor + Codex + dsh 这个方案行不行"；本文回答
> "investment-app 的 agent 域整体该长什么样"**。那份是本文 §6 的展开。

## 1. 结论

**总体可行，但起点不是你以为的那个起点。**

最重要的一条,先说：

> **investment-app 生产环境里现在没有 agent。**
> 唯一对用户开放的链路（Pilot）是"检索 → 一次 LLM 出稿 → 人确认 → 返回"，
> 它的源码注释明写自己**不是**耐久运行器；
> 而承载了全部 agent 设计（Profile / 预算 / 工具 / 沙箱 / 状态机）的那一套
> **在生产里被开关关着**。

```bash
grep -n 'AGENT_V4_TRAFFIC_ENABLED' k8s/.../deployment/bundle/00-prerequisites.yaml
#   AGENT_V4_TRAFFIC_ENABLED: 'false'

head -6 investment-app/investment-backend/app/app/infrastructure/graph/pilot_graph.py
#   "it proves the browser/Runtime product contract in an isolated deployment;
#    it is not the M1 durable runner."
```

所以整体判断是：

| 维度 | 判定 |
| --- | --- |
| 领域设计 | ✅ **完整且质量好**——状态机、幂等、副作用账都比参照系统更严 |
| 生产接线 | ❌ **几乎为零**——预算/工具/沙箱三个 Port 生产层引用数都是 0 |
| 对外契约 | ✅ **已跑通一遍**——建单 / 快照 / SSE / 动作 / 取消 / citation 六件事在 Pilot 上是真的 |
| 拓扑 | ⚠ **两套并行栈**，是当前最大的结构风险，见 §4 |
| 接外部 agent | ⚠ 五处部署阻断、三处形状问题，见 §6 与另一份 |

**结论一句话**：**该做的不是"新建一套 agent 架构"，而是把已有的两套栈收敛成一套，
把领域设计接上线，然后再谈外部执行运行时。**顺序反了会同时维护四套。

## 2. 现状全景

### 2.1 两套并行栈

```
                      ┌── /agent/*  (admin 面, 开关 false) ──────────────┐
前端 ─── 浏览器 ──────┤                                                  │
                      └── /web/v1/runs/*  (web 面) ─────────┐            │
其他服务 ── /internal/v1/investment/runs/* ────────────────┤            │
                                                            ▼            ▼
                                              ┌──────────────────┐  ┌──────────────────┐
                                    应用层     │  PilotService    │  │ AgentRunService  │
                                    仓储       │ PilotRepository  │  │ AgentRepository  │
                                    表         │ agent_pilot_*    │  │ agent_runs       │
                                              │                  │  │ session_events   │
                                              │                  │  │ tool_side_effects│
                                    Celery     │pilot_agent_graph │  │ agent_graph      │
                                    图         │ pilot_graph      │  │ walking_skeleton │
                                              └──────────────────┘  └──────────────────┘
                                                     生产在用            生产关闭
```

取证：

```bash
grep -n '@router' app/interfaces/endpoints/agent_routes.py            # /agent, require_investment_admin
grep -n 'prefix' app/interfaces/endpoints/pilot_runtime_routes.py     # /internal/v1/investment
grep -n 'prefix' app/interfaces/http/web/interactions.py              # /web/v1
grep -rn 'PilotService\|AgentRunService' app/interfaces/
```

**符合 I1 的部分**：web 面与 internal 面共用 `PilotService`——这是正确的"接口分面"。
**违反的部分**：admin 面用的是**另一个应用服务、另一套表**——那不是分面，是第二套栈。

### 2.2 已经做对、不要重做的六件事

| 项 | 现状 | 评价 |
| --- | --- | --- |
| Run 状态机集中校验 | `RUN_STATUS_TRANSITIONS` + `validate_run_status_transition()`，七态四终态 | 两个仓储类都在行锁下调用，**比 Codex 更严** |
| 幂等建单 | `uq_agent_runs_session_idempotency`；Pilot 侧另有 owner+key 唯一约束 | 落库，不靠内存 |
| 副作用一次性 | `tool_side_effects` 以 `tool_call_id` 为主键 | 落 PG，跨进程有效 |
| 恢复令牌原子消费 | `pilot_repository.consume_resume`：`pg_advisory_xact_lock` + 幂等键 + 拒绝陈旧动作 | **真原子**，这是全仓质量最高的一处 |
| 六件对外契约 | 建单 / 快照 / SSE / 动作 / 取消 / citation 溯源 | 已在 Pilot 上端到端跑通 |
| 人工审批 | `pilot_graph` 的 `interrupt()` + `WAITING` 状态 + resume | **已有可用实现**，见 §5.1 |

**这六件是资产。**任何新架构必须继承它们，不是绕过。

### 2.3 设计完整但接线为零的部分

```bash
cd investment-app/investment-backend/app
for s in RunBudget SandboxPort ToolExecutionPort CancelRunCommand; do
  echo "$s → tasks/+application/ 引用 $(grep -rln "$s" app/tasks/ app/application/ | wc -l)"
done
# RunBudget 0 · SandboxPort 0 · ToolExecutionPort 0 · CancelRunCommand 0
```

| 领域构件 | 定义 | 生产引用 | 意味着 |
| --- | :-: | :-: | --- |
| `RunBudget`（四维限额） | ✅ | **0** | `budget_exceeded` 状态生产不可达 |
| `ToolExecutionPort` | ✅ | **0** | **没有工具循环**——现在的"agent"不调工具 |
| `SandboxPort`（含 shell/python） | ✅ | **0** | 设计意图含执行代码，现状零实现 |
| `CancelRunCommand` | ✅ | **0** | Pilot 的取消是另写的，没走领域命令 |
| `AgentMemoryService` | ✅ | 1 | 不在两条主链上 |
| `AgentProfile` | ✅ | 2 | **只在关着的那套栈里** |

**最关键的一条**：`ToolExecutionPort` 引用为 0 意味着**目前不存在"模型调工具、看结果、再决定"的循环**。
Pilot 是固定三步直线图。**这不是 agent，是一次带审批的问答。**

## 3. 目标架构

### 3.1 五层

```
┌─ ① 受理 ────────────────────────────────────────────────────┐
│  身份 → 幂等 → 建单 → RECEIVED                              │
│  载体：一个 RunService（收敛后），一套表                     │
└──────────────────────────────────────────────────────────────┘
                          ▼
┌─ ② 解释与路由 (VALIDATING) ─────────────────────────────────┐
│  纯函数：(input, context) → profile_key                     │
│  规则优先，模型兜底。**不建 Task、不占状态机**               │
│  ← 这就是你说的 "supervisor"，它不是一个常驻实体             │
└──────────────────────────────────────────────────────────────┘
                          ▼
┌─ ③ Profile 目录 ────────────────────────────────────────────┐
│  profile → { prompt, model, tools, memory, ragflow_binding,  │
│              budget, backend_key, backend_options }          │
│  「财务分析 agent」= 这里的一行，不是一条新执行路径          │
└──────────────────────────────────────────────────────────────┘
                          ▼
┌─ ④ 执行 (RUNNING) ──────────────────────────────────────────┐
│  AgentBackendPort（唯一执行抽象，签名不含领域概念）          │
│    capabilities = {cancel, approval, resume, stream, schema} │
│    ├─ LangGraphBackend  ← 现有两条链，自己实现工具循环        │
│    ├─ CodexBackend      ← openai-codex SDK                   │
│    └─ DshBackend        ← deepseek-harness-sdk               │
└──────────────────────────────────────────────────────────────┘
                          ▼
┌─ ⑤ 账与交付 ────────────────────────────────────────────────┐
│  四本账落 PG（预算/幂等/副作用/证据）· 事件追加 · SSE · 溯源  │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 三条设计原则

**原则一：外部执行运行时不是真源。**

产品契约 §6.2 写死了：

> 所有要求"进程被杀后仍正确"的事实必须由持久化与并发控制承担……
> **不能把这些事实仅保存在 worker 内存或外部执行 harness 中。**

所以 Codex thread / dsh session **只能当缓存**：权威对话历史落我们自己的事件流，
外部会话 id 只用于"还活着就续接，省 token"，**续接失败必须能从我们的事件流重建重跑**。

**原则二：能力缺失要在受理时拒绝，不能跑到一半失败。**

dsh 自己的做法值得照抄：

> a request that needs a capability the chosen provider lacks is rejected with a
> typed error rather than accepted-then-ignored（"fail loud, no silent degradation"）

Profile 要求 `approval`，而 `backend_key=dsh` 没有这个能力 → **`VALIDATING` 阶段 `REJECTED`**。

**原则三：领域概念不进 Port 签名（A5）。**

`run(prompt, tools, limits)` 可以；`run_financial_analysis(股票代码)` 不可以。
否则每加一个专业 agent 就要动执行层。

## 4. 最大的结构风险：两套栈

这是本文与另一份最大的不同——**在谈外部后端之前，这件事更急。**

### 4.1 为什么急

现在是 2 套。按你的计划再加 supervisor + Codex + dsh，如果不先收敛：

```
现在：Pilot 栈 + v4 栈
之后：Pilot 栈 + v4 栈 + Codex 路径 + dsh 路径 = 4 套
```

每一套都要各自实现：状态转换、事件落库、SSE、取消、审批、证据、预算。
**四份实现意味着四个地方会漂移**，而 I13 要求"一个可变事实只有一个权威写入面"。

### 4.2 收敛方向

| | 保留 | 理由 |
| --- | --- | --- |
| **对外契约** | **Pilot 那一套**（`/web/v1/runs/*` 六个端点） | 已跑通、前端在用、web 与 internal 已正确共用应用层 |
| **领域模型与表** | **v4 那一套**（`agent_runs` / `session_events` / `tool_side_effects` / Profile） | 设计完整，且事件流 + 副作用账是四本账的现成载体 |
| **原子恢复实现** | **Pilot 的 `consume_resume`** | 全仓最强的一处并发控制，v4 侧的 `resume_run` 只做等值比较，不原子 |

即：**用 v4 的骨，Pilot 的皮，Pilot 的锁。**

**不建议**的两种做法：

- ❌ 保留两套、在上面加一层门面——门面掩盖不了两个真源
- ❌ 推倒 Pilot 重写——它是唯一验证过的对外契约，且带着可用的审批与取消

### 4.3 收敛的代价（诚实说）

`agent_pilot_requests` / `agent_pilot_controls` 有真实数据，收敛需要迁移。
`AGENT_V4_TRAFFIC_ENABLED` 从 false 打开会暴露一批从未在生产跑过的代码。
**这两件都不小**，见 §8 的第 1–3 步为什么排在最前。

## 5. 逐层可行性

### 5.1 ① 受理与 ⑤ 交付：**已可行**

六件对外契约在 Pilot 上是真的：

```
POST /web/v1/runs                建单（幂等键 + owner 唯一约束）
GET  /web/v1/runs/{id}           快照
GET  /web/v1/runs/{id}/events    SSE（Redis pub/sub + 事件表回放）
POST /web/v1/runs/{id}/actions   提交动作（原子消费 resume）
POST /web/v1/runs/{id}/cancel    取消
GET  /web/v1/citations/{id}/source  证据溯源（C6 七处同形）
```

**审批也是真的**：`pilot_graph` 用 LangGraph `interrupt()` 挂起 → 落 `waiting` →
前端提交动作 → `Command(resume=...)` 续跑。这正是契约 §4.2 的 `WAITING(APPROVAL)`。

**这一层是资产，直接继承。**

### 5.2 ② 路由：**可行，但别做成 Task**

契约 §8 明令：

> **协调 Task 不等待被协调 Task 全部完成。**图建立并验收后即 `SUCCEEDED`……
> 避免一个永不结束的"总管 Task"成为中央计划。

所以路由是 `VALIDATING` 阶段的一次分类，不产生实体。
第一版**建议用规则**（关键词 / 显式选择 / 用户在前端选），
模型分类留到有了足够多 Profile 再上——分类错的代价是跑错 agent，
而规则的可解释性在早期更值钱。

**真正需要 supervisor 的是"一个任务拆成多个并行子任务"**，那才建 `COORDINATION` Task，
且建完图就结束。**这件事建议放到最后**（§8 第 10 步）。

### 5.3 ③ Profile：**可行，改动最小**

`AgentProfile` 已有 `key/version/prompt/model/tools/memory/ragflow_binding`。
只需加两个字段：

```python
backend_key: str                  # "langgraph" | "codex" | "dsh"
backend_options: dict[str, str]   # 后端私有参数，不含领域概念
budget: RunBudgetSpec             # 见 5.5
```

`constraints.md` A1 原文支持这个做法：

> 新增业务智能体优先是**新增一份 Profile**，不是 fork 一套代码

### 5.4 ④ 执行：**这是真正的空白**

现状**没有工具循环**（`ToolExecutionPort` 引用 0）。三种补法：

| 路线 | 工作量 | 可控性 | 何时选 |
| --- | --- | --- | --- |
| **A. 自己在 LangGraph 里写循环** | 大 | 最高，全部落我们的账 | 通用能力、需要严格审批的场景 |
| **B. 租 Codex SDK** | 中 | 中，账要从事件里翻译 | 通用编排、代码类任务 |
| **C. 租 dsh SDK** | 中大 | 中，且缺取消/审批 | 需要 DeepSeek 模型时 |

**建议三条都要，但顺序是 A → B → C**：

- A 是兜底,不依赖任何外部进程、不需要出网(用现有 LLM 端点)、不受 §6 阻断影响；
- B 的阻断最少(无需 Node、有 `interrupt()`/`approval_handler`/异步客户端)；
- C 的阻断最多(需 Node、无取消、无审批)。

**注意这与"专用给 dsh"的直觉相反**：dsh 听起来承担核心的"专业 agent"，
但它恰恰是三条里工程阻力最大的一条。

### 5.5 ⑤ 四本账：**两本已有、两本没有**

| 账 | 状态 | 载体 |
| --- | :-: | --- |
| 幂等 | ✅ | `uq_agent_runs_session_idempotency` + Pilot 侧唯一约束 |
| 副作用 | ✅ | `tool_side_effects`（`tool_call_id` 主键 + `ON CONFLICT DO NOTHING`） |
| **预算** | ❌ | 只有内存 `RunBudget` 对象，生产引用 0 |
| **证据** | ❌ | `session_events` 里有 citation 事件，但结论没绑「后端 + 模型 + 版本 + 时点」 |

`constraints.md` A3：**四本账必须落 PostgreSQL。**

**预算为什么是所有并行工作的前置**（契约 I10：防"fan-out 放大无限额"）：
外部 agent 自己会循环调工具、自己会派 subagent。
**不接预算就接外部 agent，等于把无限额乘以并行度。**

**证据为什么在接外部后端后更要命**：同一个 prompt，Codex 的 `gpt-5.4` 与
dsh 的 `deepseek-v4` 会给出不同结论。不记执行者标识，两个月后无从归因——
**对投资研究结论不可接受。**

## 6. 部署可行性（摘要）

完整分析见 [`agent-architecture-feasibility-opus.md`](agent-architecture-feasibility-opus.md) §3。
五处阻断，**只影响路线 B/C，不影响路线 A**：

| # | 阻断 | 影响 |
| --- | --- | --- |
| 1 | worker egress 无 `ipBlock`，**完全不能出公网** | B、C 全废 |
| 2 | runtime 镜像**没有 Node** | C（dsh 需要，Codex 不需要） |
| 3 | `readOnlyRootFilesystem: true` | B、C 都要挂 `emptyDir` |
| 4 | 内存 limit **768Mi** | B、C；建议独立运行角色 |
| 5 | 模型凭据**集群里根本没配** | A 也受影响 |

第 5 条对路线 A 同样成立：`AGENT_PILOT_LLM_BASE_URL` 在 bundle 里 grep 为空——
**现在连 Pilot 的 LLM 都没接。**

拓扑建议：**新增一个运行角色 `agent-runtime`**（T3 允许按运行角色部署），
把出网、内存、可写卷三项特权限制在这一个角色里，不动现有 worker。

## 7. 与产品契约的对齐差距

| 契约要求 | 现状 | 差距 |
| --- | :-: | --- |
| §4.1 九态 Task 状态机 | ⚠ | 现有七态,缺 `RECEIVED/VALIDATING/REJECTED` 的显式区分 |
| §4.2 `WAITING` 五种原因码 | ⚠ | 只有 `waiting`,无 reason 码 |
| §2 Attempt 实体 | ❌ | **不存在**——重试、租约、执行者版本无处落 |
| §6.1 I14 租约与 fencing | ⚠ | 有 Redis 会话锁并在图前后 `renew()`,但**写库语句不带令牌条件**,renew 与写入之间有窗口 |
| §6.1 I10 预算覆盖 fan-out | ❌ | 见 §5.5 |
| §6.1 I11 结论绑执行者 | ❌ | 见 §5.5 |
| §8 子 Task 血缘 | ❌ | `RunLineage` 有 `parent_run_id`/`root_run_id`,**表里没有这两列**,只在 JSONB 不可查 |
| §8 `COORDINATION` Task | ❌ | 未实现（建议最后做） |

```bash
grep -n 'agent_runs' -A20 app/alembic/versions/20260708_0001_agent_phase0.py | grep -c 'parent_run_id'   # 0
grep -rn 'lease\|fencing' app/ --include='*.py' | grep -v outbox | grep -v test                          # 无
```

**Attempt 缺失是最容易被低估的一条**：没有 Attempt，"这次执行用了哪个后端、哪个模型、
消耗多少、失败码是什么、租约是谁"就无处可落。接外部 agent 后每个 run 可能有多次 Attempt
（重试、换后端），**这个实体迟早要建，越晚越贵**。

## 8. 落地顺序

每步独立可验收，后一步依赖前一步。**前五步不引入任何外部依赖。**

```
─── 第一阶段：收敛与接线（不碰外部 agent）────────────────────
1. 预算账落 PG + 接进现有链                  ← 一切并行工作的前置（A3/I10）
2. agent_runs 加 parent_run_id/root_run_id 列 + 索引
3. Attempt 实体（执行者/后端/模型/版本/租约/消耗/失败码）
4. 证据账：结论绑 backend+model+version+时点  （I11）
5. 两套栈收敛：v4 的骨 + Pilot 的皮 + Pilot 的锁   ← §4.2
   验收：/web/v1 六个端点行为一字不变，AGENT_V4 开关可拆

─── 第二阶段：抽象与自建执行 ────────────────────────────────
6. AgentBackendPort + BackendCapabilities
   先只落 LangGraphBackend（包住现有链）      ← 纯重构，零外部依赖
7. Profile 加 backend_key/backend_options/budget
8. 路线 A：在 LangGraph 里实现真正的工具循环   ← 第一个"真 agent"
   验收：ToolExecutionPort 引用数从 0 变正，预算能拦住失控循环

─── 第三阶段：部署与外部后端 ────────────────────────────────
9.  新增 agent-runtime 运行角色（独立队列/egress/emptyDir/内存）
10. 模型凭据 Secret + envFrom（路线 A 也需要，可提前到第 8 步）
11. CodexBackend（阻断最少）
12. DshBackend（能力位 cancel=False, approval=False，受理时拒绝）

─── 第四阶段：编排 ──────────────────────────────────────────
13. financial_analysis Profile（一份配置，零执行路径代码）
14. COORDINATION Task —— 只有真出现"拆并行子任务"时才做
```

**第 8 步是这条路线的分水岭**：在它之前，investment-app 没有 agent；
在它之后，有一个我们完全掌控、完全落账的 agent。
**外部后端（11/12）是在这个基础上"再租几个执行器"，不是从零起步。**

## 9. 需要拍板的五件事

| # | 问题 | 我的建议 |
| --- | --- | --- |
| 1 | 两套栈收敛，还是并存? | **收敛**。并存的代价是四份实现漂移（§4.1） |
| 2 | 第 8 步自建工具循环，值不值? | **值**。它是唯一不受五处部署阻断影响的路径，且是外部后端的兜底 |
| 3 | 出网怎么开? | 开发用 `0.0.0.0/0:443`，**生产走集群内正向代理**——写进部署计划，别等出事再补 |
| 4 | dsh 走 SDK 还是自写 ACP 客户端? | **先走 SDK**，能力位如实声明。A4 是硬规则，破例要有具体收益，不能靠假设 |
| 5 | 第一个专用 agent 是不是财务分析? | 先确认它**不需要**执行代码/中途取消/人工审批/跨 Pod 续接。需要就换一个更简单的打头阵 |

## 10. 边界

| 边界 | 说明 |
| --- | --- |
| 未运行进程 | 全部结论来自静态读码、迁移文件、部署清单与 `grep` 计数 |
| 未连集群 | 部署事实取自 `deployment/bundle/*.yaml`，未 `kubectl get` 核对实跑态 |
| 未实测内存 | §6 第 4 条"768Mi 不够"是推断，`agent-runtime` 的 limit **必须实测后再定** |
| 未验证 wheel 可装 | `deepseek-harness-runtime-bin` / `openai-codex-cli-bin` 能否从内网 PyPI 装到 linux/amd64 **未验证** |
| 未读前端 | 路由结果如何呈现、SSE 如何消费、审批 UI 长什么样，本文未涉及 |
| "引用为 0"的判定方法 | `grep -rln <符号> app/tasks/ app/application/`。若存在动态注入或字符串反射，该方法会漏判 |
| Pilot 数据量未知 | §4.3 说收敛需要迁移，但**未查表里有多少行**，迁移成本估不准 |
| 未评估 dsh 自带的 subagent 生态 | dsh 有 `dsh-subagent-codex` 等，理论上可让 dsh 自己当 supervisor。**未推荐**——四本账会落在它的 home 里，违反 §6.2。若要评估可另开一轮 |
