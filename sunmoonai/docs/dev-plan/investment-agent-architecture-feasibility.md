# investment-app Agent 总体架构可行性分析

> 最后更新：2026-09-02
>
> **性质：决策底稿，不是 baseline，不构成 REQ。**立项时按治理规则走请求。
> 本文回答：前端 Task → Supervisor 路由 → 通用走 Codex SDK、专用（财务分析等）走
> DeepSeek Harness SDK，这条架构能不能建、必须守什么、从哪一刀开工。
>
> 它把 [`development-plan.md`](development-plan.md) 已定的「执行层租用、不自建」
> 落到两个具体 runtime，并给出 U2（执行层 Port）与 U5（外部 harness 部署）的
> 可实施形状。产品生命周期仍以
> [`working/request-lifecycle.md`](working/request-lifecycle.md) 为准。
>
> 取证（2026-09-02）：
>
> | 对象 | 锚点 |
> | --- | --- |
> | DeepSeek Harness | `~/repo/deepseek-harness` `0.1.2-alpha.3`；Python `deepseek_harness.DeepSeekHarness` |
> | Codex | `~/repo/codex` @ `7d6f808b97`；Python `openai_codex.Codex` / app-server v2 |
> | 本仓 agent 域 | `worktrees/cursor/investment-app`：`AgentRunService`、`RunBudget`、`agent_profile_key` |
> | 本分支调研 | [`codex-reference/`](codex-reference/) |

## 0. 结论

**可行。** Supervisor 必须建在 investment-backend 的控制面上，不能建在 Codex
或 Harness 里。

产品上仍是**一个 Agent**：人在浏览器给目标，服务端调度，容器里干活。通用任务
和财务专用任务是两种 **worker**，不是两套产品、两套 Task 模型、两套账。

| 层 | 谁做 | 不做什么 |
| --- | --- | --- |
| 控制面 | FastAPI + Postgres + Celery 调度 | 不把 Task 身份交给 jsonl / sqlite |
| 路由 | `agent_profile_key` → worker 表 | 不让大模型当外层调度器 |
| 通用执行 | `openai-codex`（`codex app-server` stdio） | 不用 Codex Multi-Agent V2 当产品 supervisor |
| 专用执行 | `deepseek-harness-sdk`（`dsh --profile sdk` stdio） | 不用 Harness 调 Codex 当通用子 agent |
| 问数工具 | Wren `dry_plan` / `query` 挂在专用 worker | 不换 SQLBot 主链；不另开第三条编排 |
| 四本账 | 全部落 PostgreSQL | harness 自带存储只作排障 |

没有 Port、预算包装器、事件桥之前，**不得打开** `agent_v4` 生产流量。
Harness 是 Developer Preview：财务路径在版本钉死和金标准之前，不能对用户承诺。

## 1. 目标形态

```text
浏览器
  │ 提交 Task（含 agent_profile_key / 产品侧 kind→profile 映射）
  ▼
FastAPI 控制面
  │ 建 Session / Run（Postgres 为事实源）
  ▼
Supervisor（应用层，不是第三个 runtime）
  ├─ general_*            → CodexWorkerPort
  │                            spawn:  openai_codex.Codex()
  │                            句柄:   thread_id + turn_id
  └─ financial_analysis 等 → HarnessWorkerPort
                               spawn:  deepseek_harness.DeepSeekHarness
                               句柄:   dsh_session_id（独立 DSH_HOME）
                               工具:   Wren / 领域 skill / MCP
  │
  ▼
DomainEvent 投影 → Redis SSE → 浏览器
```

这与总稿一致：浏览器只打服务端；服务端是唯一控制面；Docker 是 Host。
熟路（问数、持仓体检）要有 Artifact 契约；生路才把循环交给租来的 runtime。

现有代码已经有钩子，不必推翻：

- `POST /agent/sessions/{id}/runs` 已收 `agent_profile_key`
- `AgentRunService.create_run` 落库后 `dispatch_agent_graph` 进 Celery
- 把 graph worker 换成 `AgentWorkerPort` 实现即可

今天的缺口是：`dispatch_agent_graph` **不传 profile**，生产图对
`allowed_tools` 引用为零；`RunBudget` 是内存 pydantic，进程一死即失。

## 2. 两个 SDK 实际是什么（不是印象）

两端都是 **Python 薄客户端 + 子进程全应用**，不是 `import` 就能跑的 agent 循环。
依赖边界守 [`development-plan.md`](development-plan.md)：**只经公开 SDK，不直接
打裸协议**。

### 2.1 Codex（通用 worker）

公开面：`openai_codex.Codex`。默认 `codex app-server --listen stdio://`。

| 能力 | 公开 API |
| --- | --- |
| 开会话 | `thread_start` / `thread_resume` / `thread_fork` |
| 跑一轮 | `Thread.run`（阻塞）或 `Thread.turn` + `TurnHandle.stream` |
| 中途输入 | `TurnHandle.steer` |
| 取消 | `TurnHandle.interrupt` → status `interrupted` |
| 结构化输出 | `output_schema`（turn 级） |
| 审批 | 反向 JSON-RPC；默认 `ApprovalMode.auto_review` |
| 预算辅闸 | `thread/goal` 的 token budget / `BudgetLimited` |

内部可以 fan-out（Multi-Agent V2），**子 thread 外部不可 `turn/start`**。
因此 Codex 只宜当 worker，不宜当产品 supervisor。

### 2.2 DeepSeek Harness（专用 worker）

公开面：`deepseek_harness.DeepSeekHarness`。启动 bundled `dsh --profile sdk`，
stdio 上 newline-delimited JSON-RPC。必须显式 `dsh_home`，**永不发现 `~/.dsh`**。

| 能力 | 公开 API |
| --- | --- |
| 跑一轮 | `run(...)` / `Session.run(...)` → `RunResult` |
| 流式 | `on_notification`：`session.event` / `session.status` |
| 取消 | **无 per-prompt cancel**；放弃 = `close()` 杀 runtime |
| HITL | SDK wire **尚无** approval 回传（ACP 才有 `session/request_permission`） |
| 预算 | `initialize.max_tokens`；无四维 `RunBudget` 协议 |
| 持久化 | `DSH_HOME` 下 JSONL |

专业化靠 preset + persona + skills + tools + MCP，没有内置
`financial-analysis` 包。用完整 `sdk` profile，不要 `sdk-minimal`
（后者故意去掉 skills / subagents）。成熟度：Developer Preview，文档写明
破坏性变更。

仓库里存在 `dsh-subagent-codex`：**技术上 Harness 能派 Codex 子 agent。**
若用它当外层，Task 身份、预算、前端 SSE 会落到 Harness JSONL 上，否决。

### 2.3 能力不对称（开发合同必须写进 Port）

| | Codex | Harness | Supervisor 必须怎么表现 |
| --- | --- | --- | --- |
| 细粒度取消 | 有 | 无 | 通用路径 interrupt；专用路径杀进程并标 `cancelled`；UI 不假装一样 |
| 内部审批 | 可接 handler 或 auto | SDK 接不住 | 产品审批一律升到我们的 `waiting` + `resume_token` |
| 结构化输出 | `output_schema` | 根 `run` 主要是文本 | 专用 adapter 强制 Artifact，禁止把聊天当数字 |
| 生产承诺 | 可用 | Preview | 专用路径 pin wheel；契约测试钉 JSON-RPC |

## 3. 执行层 Port（U2 的形状）

纪律层（隔离、预算、事件、审批）必须能用 **Fake worker** 测，否则每次测试
都要真起 runtime 和凭据。这是 Port 存在的理由，不是「将来可能换」。

```python
class AgentWorkerPort(Protocol):
    async def start(self, spec: WorkerStart) -> WorkerHandle: ...
    async def stream(self, handle: WorkerHandle) -> AsyncIterator[WorkerEvent]: ...
    async def interrupt(self, handle: WorkerHandle) -> None: ...
    async def close(self, handle: WorkerHandle) -> None: ...
```

`WorkerStart` 至少带：`run_id`、`session_id`、`profile_key`、`cwd`、
`user_input`、`budget_snapshot`、`output_schema`、`security_context`。

`WorkerHandle` 可序列化，存 Postgres：`worker_kind`（`codex` | `harness`）+
`codex_thread_id` / `codex_turn_id` / `dsh_session_id` + `runtime_home`。

实现三份：`FakeAgentWorker`（测试）、`CodexAgentWorker`、`HarnessAgentWorker`。
Celery 任务只认识 Port，不 import SDK。

并发槽：**先占后干，计数进 PostgreSQL**，失败回滚。不要抄 Codex 进程内
`AtomicUsize`。依据见
[`codex-reference/codex-mechanisms-for-investment-agent-cursor.md`](codex-reference/codex-mechanisms-for-investment-agent-cursor.md)。

## 4. 路由

用已有 `agent_profile_key`，不要第二套 `task_type`。

| profile（示例） | worker | 说明 |
| --- | --- | --- |
| `general_coding` / 默认研究 | Codex | 生路、改仓库、通用调研 |
| `financial_analysis` | Harness finance preset | 问数、财报、组合分析 |
| 以后的持仓体检 / 复盘 | 先专用 profile | 熟了再收成静态图节点 |

模糊输入：可以加一个**只输出枚举**的窄分类器，失败则停下来问人。
分类器不是编排引擎。

**禁止**：让 Codex 或 Harness 的模型在运行中改 worker 种类。跨 runtime 跳转
必须经过我们的 Run 状态机（结束当前 Run 或建子 Run）。

## 5. 身份与事件

Postgres 是 Task / Run 的事实源。SDK 句柄只是执行会话。

| 我们 | Codex | Harness | 规则 |
| --- | --- | --- | --- |
| Session | 可 1:N thread | 可 1:N session_id | 用户离开页面 Session 仍活 |
| Run | 一次 `run` / 一个 turn | 一次 `Session.run` 活动区间 | 一次用户提交 = 一个 Run；幂等键已有 |
| DomainEvent | `item/*`、`turn/*` | `session.event` | 全部投影到 Redis SSE；graph state 只放 artifact id |
| RunBudget | goal 辅闸 | `max_tokens` 辅闸 | 四维我们计数；超限写 `budget_exceeded` |

`CODEX_HOME` 与 `DSH_HOME` **隔离**。禁止共用 session 文件或复用对方的 id。
jsonl / sqlite 只作排障，禁止当任务态。

## 6. 专用 Agent 怎么建

新增业务智能体，优先加 Profile + worker 绑定，不 fork 控制面。
与 [`development-plan.md`](development-plan.md)「专用部分载体是 Profile」一致。

财务分析专家（Harness 侧）：

1. 复制 shipped `standard` preset，改 persona；独立 `DSH_HOME`
2. 问数：Wren 作为 tool 或 MCP；`strict_mode=True`；我们补 SELECT 白名单；
   `dry_plan` 与 `query` 分开，中间可升到我们的审批
3. 术语 / few-shot / ChartSpec 按
   [`codex-reference/sqlbot-cursor.md`](codex-reference/sqlbot-cursor.md) 挂在
   这张专用链上，不另开 SQLBot prompt 链
4. 代码执行：Host 容器即 `ExternalSandbox`，网络默认拒绝。见
   [`codex-reference/sandbox-extension-advice-cursor.md`](codex-reference/sandbox-extension-advice-cursor.md)

handoff 2026-08-29 写过「SQLBot / WrenAI 不是选型候选」。本文不把它们当成
**产品**或第三条编排；Wren 是专用 worker 的**工具**。这与「问数是专用智能体的
一个实例」同向。真正的选型空缺仍是：**准确率未评估，且仓内尚无业务数据表。**
没有样例库之前，专用路径只标 spike。

## 7. 必须拆掉的冲突

| 冲突 | 若不管 | 对策 |
| --- | --- | --- |
| 双重编排 | LangGraph 循环和 SDK 循环抢 next message | 状态机只做 create→route→wait→persist→HITL→complete；worker 内部 loop 不暴露 |
| 双重身份 | checkpoint id ≠ thread id ≠ session_id | `run_id` 主键；SDK id 只是句柄列 |
| 双重账本 | jsonl 和 PG 各写任务态 | adapter 映射 DomainEvent |
| 进程膨胀 | 每个 Celery task 拉一个 Node/Rust 运行时 | worker 池化长驻 runtime；按租户隔离 home；PG 槽位 |
| 取消不对称 | 前端点取消，专用路径杀不掉当前 turn | 契约写明两种语义，见 §2.3 |
| HITL 缺口 | 卡在 Harness 内部审批 | dry_plan / 决策批准走我们的 `waiting`；两端内部审批 auto 掉 |
| Preview | Harness 破坏性变更打断问数 | pin 版本；契约测试；P0 可先 Fake/Codex，专用后挂 |

LangGraph 可以留下当**控制面状态机**，但不再当通用/专用 agent 的推理循环。
现有 `first_m1_graph` / pilot 只作历史输入。

## 8. 明确否决

1. **Harness 调 Codex 当通用子 agent** — 外层控制面错位。
2. **Codex Multi-Agent V2 当产品 Supervisor** — 子 thread 不可外部寻址。
3. **两边共用 CODEX_HOME / DSH_HOME 或同一 session id**。
4. **跳过 Port，Celery 直接 new Codex() / DeepSeekHarness()** — 纪律层无法单测。
5. **把预算、证据只记在 harness 本地** — 违反四本账落 PG。
6. **为「支持沙箱」合并 Tool 与 Sandbox Port，或在业务 worker 里 LocalSandbox
   跑模型代码**。
7. **未接线 RunBudget 就开 fan-out 或真沙箱**。

## 9. 开工切片

与阶段「一对接 → 二 agent → 三问数」对齐。本文属阶段二，但 U3 预算账是硬前置。

| 阶段 | 交付 | 完成标准 |
| --- | --- | --- |
| 0. 合同 | `AgentWorkerPort` + profile→worker 表 + run 句柄列 | Fake worker 跑通 create_run → events → complete |
| 1. 通用 | Celery → Codex SDK；`output_schema`；interrupt；事件桥 | 前端一个通用 Task 可流式看到 item，取消能停 turn，PG 有 thread/turn id |
| 2. 预算与槽 | `RunBudget` 落 PG 并接线；并发槽先占后干 | 超限 → `budget_exceeded`；杀 worker 不泄漏槽 |
| 3. 专用 spike | Harness finance preset + 独立 home；Wren tool | 数字必须带 SQL/MDL/as-of；无金标准前不对用户承诺 |
| 4. HITL | `waiting` + `resume_token` 覆盖 dry_plan / 决策 | 拒绝带理由回下一次 prompt；超时不是拒绝 |
| 5. Host | 一 Run 一容器；网络默认拒绝；产物进对象存储 | 业务 worker 无 `docker.sock`；第一份沙箱实现不改 domain 签名 |

**下一刀是阶段 0**，不是先把 Harness 嵌进生产图。

## 10. 与未决项的关系

| 未决 | 本文给出的形状 | 仍未冻结、需要立项 |
| --- | --- | --- |
| U2 执行层 Port | §3 `AgentWorkerPort` | 方法名与事件枚举的精确 schema |
| U3 预算/证据表 | 四维沿用 `RunBudget` 字段，载体换 PG | 迁移 DDL |
| U4 Profile | 增加 `worker_kind` 绑定；现有 key 继续当路由键 | 财务 profile 字段与工具白名单 |
| U5 harness 部署 | Celery worker 内长驻/按需 spawn SDK 子进程；每租户 `DSH_HOME`/`CODEX_HOME` | 镜像、凭据、池大小、cgroup |
| U1 web 适配器 | 不在本文范围；控制面仍在 backend | 阶段一继续 |

## 11. 边界

- 未实跑 `openai-codex` 与 `deepseek-harness-sdk` 对当前 investment-app 的端到端
  回合；API 以各自公开 README / api-reference 为准，实施时用契约测试钉死。
- 未评估 Wren / 问数准确率；仓内无业务行情表，阶段三仍被数据挡住。
- 未设计多租户配额产品语义（只定了技术槽位）。
- 未把本文件升为 constraints / development-plan 正文。吸收时改那两份，
  不要让本分析同时当计划和状态。

## 12. 阅读顺序

1. [`development-plan.md`](development-plan.md) — 为什么租用执行层
2. 本文 — 两个 SDK 怎么接进控制面
3. [`codex-reference/investment-app-agent-architecture-cursor.md`](codex-reference/investment-app-agent-architecture-cursor.md) — 一个 Agent、熟路/生路
4. [`working/request-lifecycle.md`](working/request-lifecycle.md) — 产品 Task 合同
5. [`handoff.md`](handoff.md) — 现在卡在哪（状态，不是论证）
6. [`investment-agent-architecture-update-and-openclaw.md`](investment-agent-architecture-update-and-openclaw.md) — 相对自研是否更好；OpenClaw Gateway 借什么、不转向什么
