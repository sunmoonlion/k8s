# investment-app Agent 架构可行性与 OpenClaw 借鉴（kimi 版）

> 合并整理：2026-09-03。本文由 kimi 2026-09-02 的两份稿原样拼接
> （`supervisor-dual-harness-feasibility-kimi.md` 440 行、
> `architecture-change-and-openclaw-gateway-kimi.md` 234 行），**内容一字未改**。
> 第二部分里的「可行性文档」即本文第一部分；两部分各自的章节编号保持原样，
> 跨部分引用请按「第一部分 §X」理解。

---

# 第一部分 · Supervisor + Codex SDK / deepseek-harness SDK 双腿架构可行性分析（kimi 版）

> 最后更新：2026-09-02
>
> 性质：架构可行性分析（个人决策底稿），非 baseline、非 REQ；转实施按治理规则走 REQ。
> 论证对象（用户 2026-09-02 原话收敛）：investment-app 的 agent 部分按如下架构创建——
> 先建一个 Supervisor 接受前端 task 并路由：**通用任务给通用 agent（经 SDK 分发给
> Codex）**；**专业任务（如财务分析）给专用 agent（经 SDK 分发给我们采用 deepseek
> harness 构建的财务等专业 agent）**。
>
> 取证范围（本轮全部亲核，非凭印象）：
> - `~/repo/deepseek-harness`（dsh）：docs/architecture.md、packages/sdk/{protocol,client,server}、
>   packages/bundle/{base,sdk-app,sdk-minimal}、python/sdk README、packages/{preset,interaction/user-approval,
>   mcp,subagent,e2b,sandbox}、docs/cookbook/adding-a-tool.md
> - `~/repo/codex`：sdk/python 全部 docs 与 src（client.py/api.py/models.py）、
>   codex-rs/model-provider-info、codex-rs/config、codex-rs/responses-api-proxy、docs/
> - 本仓：constraints.md、agent-discipline.md、development-plan.md、handoff.md、
>   overall-architecture.md；investment-app 现有 agent 代码目录
> - 既有研究：codex-reference/ 六份 kimi 文档（编排评估、动态图源码追踪、沙箱、WrenAI、SQLBot、总架构）

---

## 0. 结论

**架构方向成立，且与已立治理规则同向**——constraints A4 早已写下"执行层租用不自建，
依赖边界严格限定在 SDK"，development-plan 已把通用部分执行层定为 Codex Python SDK。
本提案真正新增的决策只有一条：**专用 agent 的执行引擎从"同一 Codex 腿"换成
"deepseek-harness 腿"**。

**双腿分工本身可行，但有三个必须先接受的事实：**

1. **dsh SDK 协议当前是"半成品"**：无取消方法（放弃 = 杀进程）、无服务端→客户端
   请求通道（审批流协议层不存在）、无结构化输出参数、协议版本 0.0.1 无兼容承诺、
   Python 包版本 0.0.0.dev0。这三样缺口每样都有我们的补法（§4 R1–R3），但补法
   是要写、要测、要维护的代码，不是配置。
2. **Codex 腿的模型提供方被钉死在 Responses API**：本仓版本已移除 `wire_api = "chat"`
   （`model-provider-info/src/lib.rs:57` 的报错原文"`wire_api = \"chat\"` is no longer
   supported"），内置 provider 只有 OpenAI 与 Ollama。若想让通用 agent 跑 DeepSeek
   等 Chat Completions 模型，必须自建/引入 Responses→Chat 翻译代理——这是一个有真实
   阻抗风险（reasoning item、工具调用、流式事件两套语义）的额外组件，必须 spike 先行。
   通用腿跑 OpenAI 模型则零障碍。
3. **两个 harness 的会话状态都活在本地盘**（CODEX_HOME rollouts / DSH_HOME JSONL），
   而 worker 进程可被杀。A3 已判定"harness 自带存储不满足四本账"——四本账永远落 PG，
   这条不变；要补的是**执行现场的快照/恢复机制**（§4 R5），否则长 run 中途死进程
   只能从头再来。

**一个必须现在就摆上台面的替代路线**：专用 agent 也跑在 Codex 上（Profile + MCP 工具），
单 harness、单运维模型。放弃的是 DeepSeek 原生模型成本与 dsh 的 preset 可组合性。
§5 给出取舍论证；本文的立场是**双腿可辩护，但要用两个 spike 的实证换掉信仰**（§6）。

---

## 1. 两个 SDK 的核实事实（全部带锚点）

### 1.1 Codex Python SDK（`openai-codex`，Apache-2.0）

| 能力 | 事实 | 锚点 |
| --- | --- | --- |
| 进程形态 | spawn `codex app-server --listen stdio://` 子进程，行分隔 JSON-RPC | `sdk/python/src/openai_codex/client.py:252` |
| 二进制分发 | 配套钉版 `openai-codex-cli-bin` 包，SDK 自动解析 | `sdk/python/_runtime_setup.py` |
| 线程生命周期 | `thread_start/resume/fork/list/archive/unarchive` | `sdk/python/docs/api-reference.md` |
| turn 控制 | `run()`（含 `output_schema=` 结构化输出）/ `turn()` → `stream()`、`steer()`、`interrupt()`；单客户端可并行消费多 turn | 同上 |
| 结构化输出 | **`output_schema` 原生参数**，TurnResult 带 `final_response/items/usage` | 同上 |
| HITL 审批 | 服务端→客户端请求 `item/commandExecution/requestApproval`、`item/fileChange/requestApproval`，**可注入自定义 `approval_handler`**（默认全 accept） | `client.py:66,218,773` |
| 沙箱 | 内核级（seccomp）：`read_only/workspace_write/full_access` 三档；**限写不限读** | api-reference + sandbox-extension-advice-kimi.md §3 |
| 模型提供方 | 内置 OpenAI、Ollama（均 Responses API）；第三方 provider 必须 `wire_api = "responses"`，**chat 已移除** | `codex-rs/model-provider-info/src/lib.rs:57,511-533` |
| MCP | config.toml `[mcp_servers]`（HashMap），进程级 `-c` 覆盖可传 | `codex-rs/config/src/config_toml.rs:270`、`client.py` config_overrides |
| 认证 | `login_api_key()` / ChatGPT 浏览器与设备码登录 | api-reference |
| 多路隔离 | 每进程独立 `CODEX_HOME` 已本机实测（3 路/5 路并发互不干扰，不碰 `~/.codex`）；**真实模型调用未实测**（本机无登录态） | agent-discipline.md §3.1 |
| 协议稳定性 | 裸协议 3 个月 280 提交 12 处破坏；SDK 门面 10 提交 0 破坏 | development-plan.md |

### 1.2 deepseek-harness Python SDK（`deepseek-harness-sdk`，MIT）

| 能力 | 事实 | 锚点 |
| --- | --- | --- |
| 进程形态 | 启动捆绑 `dsh --profile sdk` 运行时（wheel 自带，**无需系统 Node**），行分隔 JSON-RPC stdio | `python/README.md`、`python/sdk/README.md` |
| 隔离 | **必须显式 `dsh_home`**，SDK 故意不读 `~/.dsh`；每 home 自含 profile/插件/会话存储 | `python/sdk/README.md` |
| 模型选择 | initialize 时定 `provider/model/reasoning_effort/max_tokens`；内置 `deepseek-official`；可挂 `llm-pi-ai` 适配任意 pi-ai 目录内 provider | 同上 |
| 会话 | `session/prompt` 按 `session_id` 持久入队；**同 home + 同 session id 复用即续聊**；RunResult(final_response, finish_reason, events, notifications) | 同上 |
| 事件 | `session.event` 通知**全量推送运行时内所有会话事件**（不过滤）；`subagent.started/finished`；token usage 在持久事件流里（`assistant/message` 带 usage） | `packages/sdk/protocol/README.md`、`docs/subsystems/session.md` |
| 结构化输出 | **无 output_schema 参数**；`final_response` = 最后一条 root assistant 文本 | protocol README |
| 取消 | **协议无 cancel/session-close**——放弃一个 turn 的唯一方式是关运行时进程 | protocol README「Known Limitations」原文 |
| 审批 | 协议的服务端→客户端请求是**死能力**（"the server never sends one; the Python SDK's responder surface exists for future approval flows"）；但运行时层有 `ctx.approval` 接缝，`approval/request` 瀑布监听器可自写 answerer 插件；无 answerer 时 fail-closed 为 unavailable | 同上 + `packages/interaction/user-approval/README.md` |
| 工具扩展 | 一切皆插件：`ctx.tools.register(defineTool(...))`，schema 进 prompt 组装；`dsh plugin add file:` 装进 profile，或按次启动传 patches | `docs/cookbook/adding-a-tool.md`、`python/sdk/README.md` |
| 专用 agent 载体 | **preset 组**：一个 preset = 一个目录一份 `agent.cordis.yml`，按会话组合 tools/prompt sections/skills/persona；**一个进程可同时跑多个不同组合的 agent** | `packages/preset/README.md` |
| 沙箱 | `ctx.sandbox` 后端可换；有 e2b 三件套（fs/subprocess 远程沙箱）；默认本地 | `packages/sandbox/`、`packages/e2b/` |
| MCP | 有 `mcp-client` 包（可作为 MCP 工具的消费方） | `packages/mcp/` |
| 子代理 | 后端可选：in-process fork/spawn、**subagent-codex（把 Codex 当子代理）**、subagent-claude-code、dsh-sdk | `packages/subagent/` |
| 稳定性 | **developer preview，明示有兼容性破坏变更**；协议版本 0.0.1 不校验、无兼容承诺；Python 包 0.0.0.dev0 | README、protocol README、pyproject |
| 默认人设 | sdk profile 出厂人设是 coding agent（"You are a coding agent powered by {{model}}"），可用 preset persona 覆盖 | `packages/bundle/sdk-app/README.md` |

### 1.3 关键不对称（决定设计的那几行）

| 维度 | Codex 腿 | dsh 腿 | 设计后果 |
| --- | --- | --- | --- |
| 结构化产出 | 原生 `output_schema` | 无 | dsh 腿自建 `submit_result` 工具契约（§3.4） |
| 取消 | `turn.interrupt()` 干净 | 只能杀进程 | dsh 腿的取消语义 = 进程生命周期管理（§4 R1） |
| 审批/HITL | 协议内审批请求 + 可注入 handler | 协议无通道；运行时层可自写 answerer 插件 | 双腿 HITL 分层：决策级在我们控制面，工具级各按各法（§3.5） |
| 模型 | OpenAI 系（Responses API 锁定） | DeepSeek 原生 | 双腿模型策略天然分开；想让 Codex 跑 DeepSeek 需翻译代理（§4 R4） |
| 专用能力组合 | 无 preset 概念，进程级配置 | preset 一等公民 | 专用 agent 的"Profile"在 dsh 侧有天然载体，这是选 dsh 的最硬理由 |
| 成熟度 | SDK 门面 3 个月 0 破坏 | 0.0.0.dev0 + 明示破坏式迭代 | dsh 腿必须钉版 + 协议契约测试（§4 R7） |

---

## 2. 与治理规则的对照（先过尺子再谈设计）

| 规则 | 对照结论 |
| --- | --- |
| A4 执行层租用不自建、依赖边界限定 SDK | ✅ 本提案正是该规则的展开；两个 SDK 各自有 Port 隔离，不碰 app-server / JSON-RPC 裸协议 |
| A1 新增业务智能体 = 新增 Profile | ✅ 落成 `AgentProfile`（U4）：harness 选择 + 模型路由 + preset/persona + 工具白名单 + 预算档 + 产出 schema，见 §3.6 |
| A3 四本账落 PG，harness 自带存储不满足 | ✅ 四本账一本也不进 harness；harness home 只是**执行现场**，按可恢复副本管理（§4 R5） |
| A2 两边都要有纪律 | ✅ 通用侧纪律 = agent-discipline.md；专用侧纪律 = 零证据即失败/citation 同源/结论可复现（development-plan） |
| D1 一类数据一个主档 | ✅ run/timeline/账在 PG；harness home 快照是引用与可重建副本，不是第二真源 |
| C1 即时查询走版本化同步 API，长耗时走事件 | ✅ 工具网关是版本化 internal API；run 进展走事件 + Outbox |
| I3/I5/I7 身份与令牌 | ⚠ 工具网关按 internal 面规矩办：服务令牌 + allowlist + 后端自行复核 run 归属，**不信 harness 进程声明的身份**（§3.3） |
| T3 单 Backend 按运行角色部署；拆专用 Worker 要证据 | ⚠ agent run 子进程确实显著扩大攻击面与镜像体积（命中拆分标准第 1 条），但**先不拆**：通用 Worker 起步，拿到队列延迟/资源证据再拆 |
| R6 模板优先 | ⚠ 执行层 Port 与 Supervisor 属于通用能力，应先进 tpl-app 过门禁再同步实例——这是流程要求，不是架构障碍 |
| U2/U4/U5 未决项 | ✅ 本提案恰好是这三个未决项的答案候选：U2=双腿统一 Port（§3.2）、U4=§3.6 字段、U5=§3.7 部署形态 |

**与既有 front-back 对接（阶段一）无冲突**：Supervisor 插在 application 层 run 创建之后，
web/internal 两面路由与 WebInteractionPort（U1）原样不动。

---

## 3. 架构落形

### 3.0 总图

```text
浏览器 ──▶ /api/web/v1/runs（已有）──▶ WebInteractionPort（U1，阶段一）
                                            │
                                     application/agent
                                     run_service（幂等建 run，已有）
                                            │
                                     Supervisor（路由，§3.1）── 未命中 ──▶ 通用档 + 雷达事件
                                            │
                ┌───────────────────────────┴─────────────────────────────┐
          通用档 run                                                专用档 run
    ExecutionPort(Codex) 实现                              ExecutionPort(Dsh) 实现
    codex app-server 子进程                                dsh --profile sdk 子进程
    独立 CODEX_HOME/run                                    独立 DSH_HOME/run + 财务 preset
    模型：OpenAI 系                                        模型：DeepSeek 系
                │                                                     │
                └──────────────▶ 工具网关（§3.3）◀────────────────────┘
                          MCP（Codex 消费） / MCP 或薄插件（dsh 消费）
                          Wren 受管 SQL · 知识检索 · 资讯 · artifact · submit_result
                                            │
        事件：turn.stream() / session.event ──▶ event_sink（已有）──▶ timeline ──▶ SSE
        账本：usage/副作用/证据/预算 ──▶ PostgreSQL 四本账（A3）
```

### 3.1 Supervisor 是什么、在哪

**Supervisor v1 是我们 application 层的一段代码，不是 LLM agent。**

- 位置：`application/agent/` 新增 supervisor 服务，在 run_service 幂等建 run 之后、
  分发之前。run 实体、timeline、幂等、四本账全部留在现有控制面——治理已经长在这里，
  不另起炉灶。
- 路由输入：前端 task 携带显式 `task_type`（首选，用户或入口表单给定）；
  自由文本走受限分类器（闭集标签 + 置信度阈值 + 兜底通用档），**分类器只做选择不做
  创作**。路由决策（命中规则/分类器版本/置信度/落档）落 DomainEvent——这就是旧架构
  文档的"路由雷达"：未命中进通用档并落事件，是新任务类型出现的最早信号。
- 路由表即配置（意图 → 执行档/Profile），改表不改码。
- **v1 不做 LLM 动态编排**（fan-out、动态拆任务）。那条路（旧架构 §4 的 L2 层）将来
  若要开，形态是"一个持有控制面工具的 supervisor 线程"，控制面工具经 MCP 暴露同一套
  application services——地基不变。这条明确推到 P2 以后，先让单 run 闭环成立。

### 3.2 双腿统一 Port（U2 的答案）

```python
class ExecutionPort(Protocol):
    def start_attempt(self, run_id, profile: AgentProfile, briefing: RunBriefing) -> AttemptHandle: ...
    def cancel(self, handle: AttemptHandle) -> None: ...        # codex=interrupt()，dsh=杀进程
    def snapshot(self, handle: AttemptHandle) -> None: ...      # home → 对象存储（§4 R5）
    def restore(self, run_id, attempt_no) -> AttemptHandle: ... # 对象存储 → home → resume
```

- 两个实现：`CodexExecutionAdapter`、`DshExecutionAdapter`。进程生命周期、事件采集、
  usage 记账、快照恢复全部藏在实现里；纪律层（预算闸门、审批、路由、审计）对 Port
  之上是同一张脸。
- **Fake 执行器照旧**：纪律层测试不起真 harness、不需凭据（development-plan 已定的
  Port 隔离理由）。加一个 `ScriptedFakeExecution`：回放事件序列、可注入超时/超限/崩溃。
- 协议依赖红线：代码里只允许 import `openai_codex` / `deepseek_harness` 两个门面；
  出现一个裸 JSON-RPC 帧构造即评审打回（A4 的可执行形态）。
- celery 承载：一个 run attempt = 一个 worker 任务，任务体内拉起/看守 harness 子进程；
  取消、预算硬停、进程死亡全部翻译为 run 事件。

### 3.3 工具网关：一个控制面，两扇门

两个 harness 都是"通用执行引擎"，**领域能力不指望它们自带，统一由我们供给**。
形态：investment-backend 新增 internal 面能力（或独立 sidecar 服务，先用 internal 面），
版本化 HTTP API，承载：

| 能力 | 说明 | 威胁模型 |
| --- | --- | --- |
| `wren_query` / `wren_dry_plan` / `wren_list_models` | Wren 受管 SQL（Python wren-engine 留在我们进程内，语义层即 SQL 治理） | 只读凭据；MDL 受治理资产 |
| 知识检索 / 资讯检索 | 现有 knowledge-retrieval 契约、info 域 | 契约锁已有 |
| artifact 存取 | 对象存储按域隔离（D4），产物带 run lineage | 引用不进自由文本 |
| `submit_result(schema_id, payload)` | **专用腿的产出契约**：按注册 schema 校验，落库 + 落事件，返回接受/拒绝 | 校验失败 = run 未完成，不许靠自述 |
| 沙箱计算 | 任意代码（pandas 二次加工等），v1 可先不接，接时走 e2b/容器 | 与受管 SQL 分两个威胁模型 |

- **门一（Codex）**：MCP。Codex config.toml `[mcp_servers]` 指向网关的 MCP 适配面
  （优先 streamable HTTP 远程 MCP；stdio 每进程拉起是备选）。
- **门二（dsh）**：dsh 自带 `mcp-client` 包，消费同一个 MCP 面；若 mcp-client 在 sdk
  profile 的组合验证不顺，退为自写薄插件（每个工具 = 一个 HTTP 调用，`defineTool`
  包装，半天工作量）。**细则属 spike 验证项，不在这里拍死。**
- 认证与审计：网关按 I7 办——run 级服务令牌（subject 绑定 run_id + profile），
  下游路径 allowlist；**每次工具调用带 run lineage 落 PG（证据账/副作用账的载体）**。
  harness 进程送来的任何字段都是数据不是指令（防线前置双向适用）。
- 工具按 Profile 分发：通用档挂检索/沙箱类，财务档挂 Wren/术语/submit_result 类；
  白名单在网关门禁，不在 harness 配置里——**harness 侧配置可以写错，网关不会因此放行**。

### 3.4 产出契约：熟路纪律在双腿上的形态

- Codex 腿：`output_schema` 直接上，`TurnResult.final_response` 按 schema 校验，
  失败即 attempt 失败（可重试一档）。
- dsh 腿：**`submit_result` 工具是完成的唯一通道**。preset 的 prompt 纪律写明
  "不调 submit_result 不算完成"；Supervisor 收到 `submit_result 已接受` 事件才把 run
  置为待评审/完成。`final_response` 只当人读摘要——"退出看契约不看自述"（旧架构
  熟路第二条）在无 output_schema 的引擎上的实现。
- 评审（Generator-Critic）：critic = **独立 harness 会话 + 干净上下文**（只给产物
  artifact，不继承推理过程），双腿同法。`wren_dry_plan` 在财务链是白捡的第一道
  critic（旧架构已定）。

### 3.5 HITL：决策级在我们层，工具级各按各法

| 层 | 机制 | 说明 |
| --- | --- | --- |
| 决策级（投决必过人、SQL 新模式审批、术语歧义问人） | **run 级 interrupt/resume，底座已有**（LangGraph interrupt + web actions 路由） | Supervisor 在契约点暂停 run，前端动作恢复。与 harness 无关，双腿统一——**决策类 run 终态必须由 HITL 事件触发**（旧架构红线，原样保留） |
| 工具级（Codex 腿） | SDK `approval_handler` 桥接到我们的 HITL：审批请求 → 落事件 + 等人工 → 回 accept/reject | 协议原生，成本低；v1 也可直接全 auto（通用档工具本就低风险） |
| 工具级（dsh 腿） | **v1 工具策展**：只挂受管/只读/可丢弃沙箱工具，approval policy 运行时可配 ask→无 answerer fail-closed，等于"危险操作天然拒绝"；v2 需要时自写 answerer 插件（HTTP 回调我们层） | 协议缺通道是事实，但财务档工具集可控使该缺口不致命 |

### 3.6 AgentProfile（U4 的答案，A1 的载体）

```text
AgentProfile =
  id / version
  execution:  { harness: codex | dsh, model, provider, reasoning_effort, max_tokens }
  persona:    { instructions（或 dsh preset 目录引用） }
  tools:      { gateway_allowlist, sandbox_class }
  budgets:    { steps / llm_calls / tokens / wall_clock 四档上限 }
  contract:   { output_schema_id | submit_result_schema_id, citation_required }
  hitl:       { decision_points[], tool_approval: auto | bridge | curated_deny }
```

新增业务智能体 = 新增一行 Profile（+ 财务档加一个 dsh preset 目录），不 fork 代码。

### 3.7 部署形态（U5 的答案）

- **每 run attempt 一个 harness 子进程 + 独立 home**（CODEX_HOME / DSH_HOME 放
  emptyDir）：隔离、崩溃容纳、取消即杀，与 parallel-proposals.py 已实测的形态同款。
  不做进程池 v1（run 是分钟级，秒级启动开销可接受；热池是后续优化）。
- 镜像：worker 镜像加 `openai-codex`（自带钉版 CLI）与 `deepseek-harness-sdk`
  （自带运行时，无需系统 Node）。两个 pip 依赖，无新基础设施组件。
- 凭据：`OPENAI_API_KEY` / `DEEPSEEK_API_KEY` 经 Secret 进 worker 环境；**spawn 前
  清洗子进程环境**（只放白名单变量——DB/Redis 凭据不下发给 harness 进程，这是限写
  不限读沙箱下的硬动作，见 §4 R6）。
- 资源：按并发 run 数定 worker pod 规格与 celery concurrency；harness 子进程 +
  模型流式本身不重（百 MB 级/进程），重的是将来的沙箱容器——沙箱独立部署件
  （旧沙箱文档 §3/§6）不进 worker pod。
- 多租户/成本：双腿都是单服务账号（一把 API key），**按 run 从事件流记 usage 账**，
  成本分摊在账本上不在 harness 上。

---

## 4. 风险与缺口（逐条：事实 → 后果 → 缓解）

**R1 · dsh 无取消协议（硬事实，protocol README 明示）**
后果：用户点取消、预算硬停、超时在 dsh 腿 = SIGTERM/SIGKILL 子进程。
缓解：取消语义定义为"attempt 终止 + run 落取消事件"，杀进程即可完整实现；
会话 JSONL 在 home 里，重试走 restore + 续聊。副作用：kill 不是优雅中断，正在执行的
工具调用可能半截——受管工具全部幂等（网关侧幂等键），这是既有 C2/副作用账纪律的
自然延伸。上游将来补 cancel 方法后无缝升级。

**R2 · dsh 无审批通道（协议死能力）**
后果：harness 内"这个工具调用要不要问人"在协议层送不到我们手里。
缓解：§3.5 已分层——决策级 HITL 在我们层（不依赖该通道）；工具级 v1 靠工具策展 +
fail-closed。v2 的 answerer 插件是明确的小工程（瀑布监听器 + HTTP 回调 + 超时拒绝），
不阻塞立项。

**R3 · dsh 无结构化输出**
后果：无法让引擎强制 schema 化产出。
缓解：`submit_result` 工具契约（§3.4）。这条路其实比 output_schema 更合我们的纪律：
产出过了网关校验才算数，引擎自觉与否无关紧要。

**R4 · Codex 模型 Responses API 锁定（本仓已核：chat wire_api 被移除）**
后果：通用腿要么用 OpenAI 系模型（零障碍、计费一把 key），要么为 DeepSeek 等
Chat Completions 模型自建/引入 Responses→Chat 翻译代理。
风险细节：翻译代理要处理 reasoning item 往返、工具调用增量流、两套事件语义，
做错的表现是"偶发呆傻/工具调用错位"，不易测。
缓解：**v1 决策 = OpenAI 模型**；DeepSeek-on-Codex 仅当成本压力真实出现时单独立项，
且必须先过 spike（同一组金标准任务双跑对比）。反向组合（dsh 腿跑 OpenAI）经
pi-ai 适配器天然成立，是成本对冲的另一扇门。

**R5 · harness 会话状态在本地盘，进程可被杀（A3 判过：不满足账本要求）**
后果：长 run 中途 worker 死亡，harness 对话现场丢失。
缓解（两条腿同一机制）：
- home 在 emptyDir；**快照到对象存储**：attempt 结束必做；长 run 周期性增量做
  （rollout/session 均为 append-only 文件，增量便宜）。
- 重试 = 新 attempt：restore home → Codex `thread_resume(thread_id)` / dsh 同
  home+session_id 复用 → 续跑。快照不含秘钥（API key 走环境注入，不进 home；
  快照前断言扫一遍）。
- 账与状态的真源仍在 PG（run/timeline/四本账）；快照是**可重建执行现场的可恢复
  副本**，D1 语义站得住。丢快照的最坏结果 = 该 attempt 重来，账目不乱。

**R6 · 沙箱读隔离缺口 + 凭据泄露面（sandbox-extension-advice 已判：限写不限读）**
后果：harness 子进程若继承 worker 全量环境，LLM 生成代码可读到 DB/Redis 凭据。
缓解：spawn 白名单环境（§3.7）；敏感工具调用一律走网关（凭据在网关侧，harness
只见令牌不见真凭据）；联网需求经出口代理白名单收拢（旧沙箱文档 §5）；生产档任意
代码执行等 e2b/容器沙箱，本地 subprocess 沙箱 feature-flag 禁入生产（同文档 §3）。

**R7 · dsh 破坏式迭代（developer preview 明示 + 0.0.0.dev0）**
后果：升级即可能破协议；钉版则与安全/修复脱节。
缓解：依赖钉死精确版本；**协议契约测试进 CI**——用真 SDK 起真 runtime 跑一组
金标准会话（initialize/prompt/事件序列/submit_result 往返），升级先过这套再合入；
复用 development-plan 对 Codex SDK 的"门面 vs 裸协议"度量方法，每季度复测一次
dsh 两侧变更率。Codex 腿同理但已知门面稳定（10 提交 0 破坏）。

**R8 · 预算无引擎内硬闸门**
事实：Codex 内部有 rollout 预算提醒阶梯但不暴露硬上限；dsh 的 max_tokens 只限单次
请求输出。后果：超限执行靠我们层。
缓解：usage 从事件流实时入账（Codex `TurnResult.usage` + 流事件；dsh `assistant/message`
usage 字段），触限动作 = Codex `interrupt()` / dsh 杀进程，全部落预算事件——
与旧架构"超限是事件不是惊喜"一致。预算账表结构（U3）是一切的前置，不变。

**R9 · 进程管理与资源放大**
每 run 一个子进程 + 将来 N 路 fan-out + 沙箱容器 = worker 资源模型与今天完全不同。
缓解：v1 禁 fan-out（Supervisor 单 run 分发）； celery concurrency 按实测调；
队列背压参数化压测（25 课方法学，旧架构 P4 已定）；拆专用 Worker 等证据（T3 标准）。

**R10 · 数据供给仍是财务 agent 的死穴**
handoff 明示：投资仓 13 张表全是运行时基础设施，业务数据为 0。**没有数据，财务
agent 的 harness 选型再对也无米下锅。** 本架构不改变这一前置：Wren MDL 建模、
术语库、示例库、金标准 20 题全部照旧是阶段三门槛（wrenai/sqlbot 两份文档的
结论原样成立）。

---

## 5. 关键取舍：专用腿为什么是 dsh，而不是也跑 Codex？

| | 专用腿跑 dsh（本提案） | 专用腿也跑 Codex（单 harness 替代） |
| --- | --- | --- |
| 模型 | DeepSeek 原生（成本与中文财务语义的主场）；pi-ai 可换 | OpenAI 系锁定；接 DeepSeek 需翻译代理（R4） |
| 专用组合载体 | **preset 一等公民**：目录化 tools/prompt/skills/persona，按会话组合，一进程多 agent | 无 preset；进程级配置 + 系统提示，粒度粗 |
| 工具接入 | mcp-client 或薄插件 | MCP 原生 |
| 引擎可改造性 | 一切皆插件，可拆可换（连 agent loop 都可换） | 黑盒，行为靠 prompt 与配置 |
| 协议成熟度 | 0.0.0.dev0，三个缺口（R1–R3），破坏式迭代 | 门面稳定，output_schema/审批/取消齐备 |
| 运维模型 | 两套（Rust 二进制 + Node 运行时） | 一套 |
| 社区/持续性 | DeepSeek 官方，新项目 | OpenAI 官方，体量大 |

**论证**：选 dsh 的真实理由只有两个——DeepSeek 模型的成本/质量优势，和 preset 的
按会话组合能力。两者对"财务等一簇专用 agent"都成立（多 Profile 恰是 A1 预设的形态）。
代价 R1–R3 有确定补法且工作量可估（submit_result 与工具网关本来就是我们要建的）。
**但这个取舍的正确性依赖两个未实证前提**：(a) DeepSeek 模型在财务任务上的实际表现
不劣于通用腿的模型；(b) dsh SDK 的进程/事件模型在我们 worker 里真的跑得稳。
所以 §6 把这两件事排成最前面的 spike——**信仰不进架构，实证进**。

互锁彩蛋（不影响决策）：dsh 的 subagent 后端里有 `subagent-codex`——两套生态官方
层面就能互相套娃，将来"财务 agent 里派一个 coding 子任务给 Codex"是现成路径。

---

## 6. 与旧架构（investment-app-agent-architecture-kimi.md）的关系

旧架构是"一套 LangGraph 地基上自研两种执行形态"；本提案是"控制面自研、执行面租用
两个 harness"。**不是推翻，是执行层换人**：

| 旧架构组件 | 新架构下的去向 |
| --- | --- |
| L5 治理层（RunBudget/DomainEvent/timeline/身份） | **原样保留**，且仍是红线；预算执行动作换成 interrupt/杀进程 |
| L4 质量层（dry_plan/独立评审/HITL/eval） | **原样保留**；critic 会话改由 harness 承载（干净上下文原则不变） |
| L3 能力层（Wren/沙箱/检索/术语） | **原样保留并升格为工具网关**（§3.3），从"图节点的工具"变成"双腿共享的受管供给" |
| L2 动态层（Supervisor meta-agent + 编排工具集） | **推迟**：v1 Supervisor 是确定性代码路由（§3.1）；LLM 编排态推迟到单 run 闭环成立之后 |
| L1 领域骨架（静态图主链） | **保留我们的 LangGraph 静态图作为熟路主链的骨架**，节点执行体换成 harness 会话（取数/分析/评审节点 = dsh 会话或网关调用）；财务 agent 的 preset 管"节点内怎么推理"，静态图管"节点怎么连"——熟路三条纪律（边是代码、退出看契约、改必回归）全部守得住 |
| L0 运行时（LangGraph + PostgresSaver + celery + outbox） | **原样保留**，外加双腿执行适配 |
| 固化传送带 / 路由雷达 / 预算梯度 | 原样保留，雷达改由 Supervisor 路由事件承载 |
| 沙箱文档、Wren/SQLBot 四机制、ChartSpec、MCP 外放 | 全部原样成立（资产与契约层，与执行引擎无关） |

一句话：**旧架构的"一套地基"继续是地基；变的是生路的执行引擎和专用档的承载方式。**

---

## 7. 落地顺序（spike 优先，证据驱动）

```text
S1（双腿实证 spike，先于一切正式开发，1–2 周量级）：
   a. Codex 腿：worker 形态起 app-server 子进程，独立 CODEX_HOME，跑通一个真实
      任务（真实模型调用——本机尚未验过），验证 stream/usage/output_schema/
      interrupt/审批 handler/环境清洗六项。
   b. dsh 腿：worker 形态起 dsh sdk 子进程，独立 dsh_home + 一个财务 preset
      （persona + 两三个假工具 + submit_result），跑通 initialize/prompt/事件采集/
      杀进程取消/同 session 续聊五项。
   c. 工具网关最小面：submit_result + 一个假检索工具，MCP 面给 Codex、dsh 各消费
      一次（dsh 先验 mcp-client，不顺则薄插件）。
   退出标准：两条腿各有一个真实任务 E2E 事件进 event_sink，usage 入 PG 账。
S2（U3 前置不变）：预算账 + 证据账表结构与迁移（与 S1 并行，无依赖）。
P1：ExecutionPort 双腿实现 + Supervisor 确定性路由 + Fake 执行器 + 取消/快照/恢复。
    退出：杀 worker 后 run 可 restore 续跑；预算硬停落事件。
P2：财务档首个 Profile 真上（Wren 网关 + 术语库 + 金标准 20 题门槛照旧）+
    决策级 HITL 接线。退出：金标准达标 + 决策 run 终态必由 HITL 触发。
P3：熟路静态图节点换 harness 执行体；评审独立会话；SSE 交付打磨；压测。
P4（按证据触发）：LLM 编排态 Supervisor、fan-out、沙箱计算接入、专用 Worker 拆分、
    DeepSeek-on-Codex 翻译代理（仅当成本压力真实）。
```

模板优先（R6）：ExecutionPort/Supervisor/网关骨架属通用能力，P1 起先进 tpl-app
过门禁再同步实例；财务 Profile/preset 是投资域扩展，留在 investment-app。

---

## 8. 待决问题清单（开工前要拍板的）

1. **通用腿模型**：OpenAI 直连（推荐 v1）还是立即上 Responses 翻译代理接 DeepSeek？
2. **dsh 工具消费面**：mcp-client 验证结论（S1c 之前悬置；不顺则薄插件）。
3. **预算四档限额的具体值与分档**（U3 表结构定稿时同定）。
4. **快照周期与保留策略**：长 run 多久快照一次、留几代（对象存储生命周期规则）。
5. **财务数据从哪来**（R10，阶段三总闸，与本架构无关但卡死财务档价值）。
6. **dsh 版本钉版与升级节奏**（建议：钉版 + 季度评估；升级必须过协议契约测试）。
7. **审批 handler 的默认姿态**：通用档工具级审批 v1 全 auto 还是桥接人工（影响首版
   HITL 工作量）。

---

## 9. 速查

```text
Codex SDK：~/repo/codex/sdk/python/{README.md,docs/api-reference.md,src/openai_codex/client.py:252,773}
Codex 模型锁定：~/repo/codex/codex-rs/model-provider-info/src/lib.rs:57（wire_api chat 移除）,511
Codex MCP：~/repo/codex/codex-rs/config/src/config_toml.rs:270
dsh SDK：~/repo/deepseek-harness/python/{README.md,sdk/README.md}
dsh 协议缺口：~/repo/deepseek-harness/packages/sdk/protocol/README.md（Known Limitations 三条）
dsh 审批接缝：~/repo/deepseek-harness/packages/interaction/user-approval/README.md
dsh preset：~/repo/deepseek-harness/packages/preset/README.md
dsh 工具写法：~/repo/deepseek-harness/docs/cookbook/adding-a-tool.md
治理：constraints.md（A1–A5）、development-plan.md（执行层租用、四本账、三阶段）、
     handoff.md（U1–U5）、agent-discipline.md §3.1（CODEX_HOME 多路实测）
旧架构收敛：codex-reference/investment-app-agent-architecture-kimi.md（§6 对照表的所有出处）
后续：codex-reference/architecture-change-and-openclaw-gateway-kimi.md（换架构判定 +
     OpenClaw 五机制借鉴 B1–B5，对本文 §3.1/§3.3/§3.5/§3.7/§4 R5/§6 的增量修订）
```

# 第二部分 · 换架构合理吗 + OpenClaw Gateway 借鉴分析（kimi 版）

> 最后更新：2026-09-02
>
> 性质：决策分析（个人决策底稿），非 baseline、非 REQ。
> 姊妹文档：`supervisor-dual-harness-feasibility-kimi.md`（双腿架构可行性，下称"可行性文档"）。
> 本文回答用户 2026-09-02 提出的两个问题：
> 1. 从自研架构换成双腿 SDK 架构，合理吗？比原来的更好吗？
> 2. `~/repo/openclaw` 的 gate（Gateway）做法，我们的路由和 Supervisor 该借鉴还是完全转向？
>
> 取证：`~/repo/openclaw` 的 docs/start/why-openclaw.md、docs/concepts/architecture.md、
> docs/agent-runtime-architecture.md、docs/channels/channel-routing.md、VISION.md（2026-09-02 亲核）；
> 本仓 development-plan.md、constraints.md、旧架构文档（investment-app-agent-architecture-kimi.md）。

---

## 1. 问题一：换架构合理吗？比原来更好吗？

### 1.1 先纠正一个事实：被"换掉"的到底是什么

"推翻自研架构"这个印象需要精确化，因为涉及两份地位不同的文档：

| 文档 | 地位 | 对执行层的主张 |
| --- | --- | --- |
| `investment-app-agent-architecture-kimi.md`（2026-08-22） | **个人决策底稿**，明示"非 baseline、非 REQ" | L2 动态层自研（Supervisor meta-agent 写成 LangGraph 图），L1 静态图自研，L0 复用已有 |
| `development-plan.md`（2026-08-29，治理文件） | **正式计划** | "通用部分的执行层采用 Codex 的 Python SDK……不自建轮次生命周期、隔离进程、中断恢复、审批协议、工具与沙箱"（原文） |

即：**正式治理在 2026-08-29 已经判定执行层租用不自建**——比这次提问早四天。
用户的双腿提案不是推翻正式架构，而是：(a) 追认已定的租用方向；(b) 把它具体化
（Supervisor、ExecutionPort、工具网关、部署形态）；(c) 新增唯一一个真决策——
专用腿用 dsh 而非同跑 Codex。我 8-22 那份自研 L2 的旧文档才是被治理否掉的偏离项，
这一点如实记录，不粉饰。

### 1.2 为什么"租用执行层"是对的——用旧文档自己的论证回收

旧架构文档 §1 论证了"为什么源码公开，多数人还是做不出 Codex 水平的 coding agent"，其
七条理由恰恰是今天换架构的依据，逐条回收：

| 旧 §1 论点 | 对今天的含义 |
| --- | --- |
| "机制在源码里，智能不在" | 我们不需要抄机制——直接**调用**机制（SDK）。自研循环既没有模型的判断力，又要自己扛机制的复杂度，两头不占 |
| "可靠性的复利在长尾……重试、断点恢复、预算、沙箱、会话重建、compaction、背压，无聊的 80%" | 这 80% 正是租用买到的东西。小团队的机会成本账：花在重建 turn 生命周期上的每一周，都是没花在 MDL 质量与金标准题集上的一周——而后者才决定答数对不对，答数对不对才是产品 |
| "机制与模型是 co-design" | Codex 与 OpenAI 模型、dsh 与 DeepSeek 模型各自 co-design 过；自研循环套外来模型，prompt/工具粒度/上下文预算全部要自己重新调——租用把 co-design 一起租来了 |
| "移动靶" | 靶还在动（我们亲见 codex 移除 wire_api chat），但 SDK 门面层 3 个月 0 破坏（development-plan 实测），租用的是稳定门面不是移动的内部 |
| "评估缺位" | 不变：金标准题集仍是必须自建的七样之一，与执行引擎无关 |
| "知道什么不用建比知道建什么更省钱" | 这句话的直接推论就是：agent loop 本身不用建。旧文档写了这句话却没有把它贯彻到 L2，新架构贯彻了 |

**结论：换架构合理，因为它是旧分析的逻辑终点，不是新冲动。**

### 1.3 诚实的代价清单（我们放弃了什么）

说"更好"之前先把代价摆全，每条都是真实损失：

1. **单一状态机让位给两个黑盒**。自研 LangGraph 路线下，checkpoint = 完整状态机，
   time-travel、确定性恢复、图内任意节点重放都是原生能力。租用后恢复粒度退化为
   "home 快照 + thread_resume/同 session 续聊"（可行性文档 R5）——能恢复，但不能
   在 harness 对话中间做任意点分叉重放。**缓解而非消除**：我们把确定性拓扑留在
   自己手里（熟路静态图的骨架仍是我们的 LangGraph 图，harness 会话只是节点执行体），
   图级 checkpoint 照旧在 PostgresSaver——分叉重放的粒度从"对话内任意点"变成
   "图节点边界"，对熟路场景恰好够用。
2. **事件保真度依赖上游词汇表**。我们的 timeline 从"原生事件流"变成"对两个 harness
   事件词汇表的投影"，映射必有取舍（Codex 的 item 体系 vs dsh 的 SessionEvent 体系
   形状不同）。这是 S1 spike 的验证项，不是嘴上说能映射就算数。
3. **两个上游的路线图进入我们的风险面**。破坏性变更（dsh 明示）、功能移除（codex
   移除 chat wire_api，我们亲见）都会砸进来。靠钉版 + 协议契约测试 + 季度复测管理
   （可行性文档 R7），不能归零。
4. **运维面从一个 Python 运行时变成三个运行时**（Python worker + Rust 二进制 +
   Node 运行时）。镜像、排障、资源模型都变复杂。
5. **跨进程边界无处不在**。工具调用从进程内函数调用变成 JSON-RPC + HTTP 网关往返；
   延迟、失败模式、序列化成本都新增。换来的恰好是隔离与审计点（网关），这笔账是
   赚的，但账要记着。

### 1.4 判定与反证条件

**判定：更好，且好得有结构，不是好得有情绪。**好在三个层面：

- **战略层**：执行层是商品（commodity），领域不是。我们的壁垒清单（旧 §7 七样自建物：
  领域骨架、评估集、MDL、反馈采集、HITL UX、压缩策略、口径资产）里**没有一样是
  agent loop**。把预算从非壁垒项移到壁垒项，是资源配置的修正。
- **风险层**：自研失败的模式是"loop 永远差一口气且拖住全部进度"（系统性、不可恢复）；
  租用失败的模式是"某个 harness 不达标，经 Port 换掉"（局部、可恢复）。**失败的
  不对称性站在租用这边。**
- **治理层**：新架构反而强化了旧纪律——工具网关让"每次能力调用带 run lineage 落账"
  成为结构性事实（自研路线下这只是约定）；harness 进程天然是最小权限执行体
  （凭据白名单下发）。

**但"更好"是有反证条件的**（falsifiable，写死以防自我说服）：

1. S1 spike 中，任一腿的事件流无法忠实喂给 timeline（词汇表映射损失过大）→ 该腿
   退回自研 LangGraph 循环重估；
2. dsh 腿 `submit_result` 契约 + preset 在金标准任务上打不过"Codex 单 harness +
   output_schema"的对照组 → 专用腿改回 Codex，dsh 出局；
3. dsh 进程模型在 worker 里不稳定（启动失败率/内存/僵尸进程超阈）→ 同上。

三条都触发不了，结论站住；触发任何一条，按条款回退，不嘴硬。

---

## 2. 问题二：OpenClaw 的 gate 做法——借鉴还是转向？

### 2.1 核实：OpenClaw 的 Gateway 到底是什么

一句话：**一个长驻的可信控制面守护进程，拥有全部通道连接、凭据、策略与持久状态；
执行被推到不可信的、可移动的沙箱/节点/云 worker；策略以代码强制而非 prompt 请求；
路由由宿主配置决定，模型不参与。**（docs/start/why-openclaw.md 标题句："trusted
gateway, untrusted execution, deterministic policy"）

关键机制（全部亲核）：

| 机制 | 事实 | 锚点 |
| --- | --- | --- |
| 信任边界 | Gateway 持通道/配置/凭据/控制面 API/持久 transcript；sandbox（Docker 默认无网+只读 root+drop all caps+非 root）、node（密封工件、三处哈希校验）、cloud worker（**按次派发铸造凭据、10 分钟 TTL、RPC 方法白名单、推理经 Gateway 代理、worker 不留 transcript、只见有界单轮上下文**） | why-openclaw.md "The trust boundary" |
| 策略即代码 | 权限模式直接决定**哪些工具存在**（read-only 会话里 edit/write 根本不出现）；tool policy deny 永远赢；exec 审批**绑定规范化命令+cwd+环境哈希+内容哈希文件操作数，任何漂移即拒**；无审批 UI 时默认拒；严格情形（inline eval、heredoc）任何 fallback 都不可软化 | why-openclaw.md "Policy as code" |
| 确定性路由 | "**The model does not choose a channel**; routing is deterministic and controlled by the host configuration"；session key 形状决定上下文桶；bindings 覆盖有序 | channel-routing.md |
| 运行时选择也是配置策略 | harness 注册表 + 按 model/provider 的 `agentRuntime.id` 配置；`auto` 确定性解析；模型/provider 前缀本身永不选择 harness | agent-runtime-architecture.md "Runtime Selection" |
| 身份与作用域 | operator scope 按请求实际参数在 dispatch 前导出；**无分类的方法默认拒**；role 是天花板，只取交集永不叠加 | why-openclaw.md "Identity and roles" |
| 凭据不出模型上下文 | SecretRef（env/file/exec/store）+ 出口边界 sentinel 替换（只给绑定目的主机替换真值，未识别 sentinel 拒发）；agent 只见句柄 | why-openclaw.md "Secrets" |
| 状态与升级 | DB-first（SQLite）、schema 双段版本契约（库比自身新即拒开）、升级预检、迁移单一 owner（doctor）、备份哈希校验、**重启恢复在有限尝试预算内恢复中断 turn + 崩溃循环熔断器** | why-openclaw.md "Versioned state" |
| 协议 | WebSocket，首帧必须 connect，幂等键用于副作用方法，设备配对 | concepts/architecture.md |

### 2.2 为什么不能"完全转向"

OpenClaw 不是我们的 Supervisor 位置的组件，而是这个位置上的**竞品**——转向它意味着
把我们的 Supervisor、路由、Profile、账本全部重平台化到一个聊天助手产品的扩展点里。
五个具体理由：

1. **问题不同**。它解的是"个人/团队助手在不可信设备与聊天通道边界上的治理"
   （WhatsApp/Telegram/Slack 通道、设备配对、operator 角色）；我们解的是"多租户
   服务端投资平台的 run 治理"（领域契约：citation、MDL 口径、as-of、决策必过人）。
   它的策略粒度是 tool/exec，我们的粒度是领域语义——它的框架里没有放这些的地方。
2. **租户模型冲突**。原文："one gateway is one trust domain"，多租户 = 每租户一个
   gateway（fleet 实验特性）。我们是 Casdoor 身份下的多用户单平台，模型不匹配。
3. **存储冲突**。它的状态是 per-gateway SQLite；D1/D2 要求 PG、每 App 一个逻辑库
   一条迁移链。转过去等于数据层再开一个异构真源。
4. **叠加运行时**。A4 已租 Codex/dsh 两个执行层；OpenClaw 自带 agent runtime
   （还能把 codex 挂成它的 plugin harness）——转向它不是替代我们的 Supervisor 而是
   在我们与 harness 之间再塞进一个完整产品，三层变四层。
5. **我们已有它通道层要做的事**。Web/Internal 接口分面、SSE、Casdoor 身份、Outbox
   都在或在建；它的 WS 协议/通道抽象对我们是重复建设。

**结论：不转向。但它的七条机制里有五条恰好打在我们设计的薄弱处，定向借鉴。**

### 2.3 该借鉴的五条（每条：机制 → 我们的现状 → 改动）

**B1 · "模型不路由" + 运行时选择是配置策略。**
OpenClaw 双重确认：通道路由确定性（模型不参与），harness 选择也是
model/provider 作用域的配置（`auto` 是确定性解析函数，不是模型决策）。
我们的现状：可行性文档 §3.1 已定 Supervisor v1 = 确定性代码路由 + 闭集分类器兜底。
**改动（加固而非转向）**：路由表与 Profile→harness 映射写成**版本化配置文件**
（不是代码里的字面量），变更走评审 + 落事件；分类器永不创作标签；未命中 → 通用档
+ 雷达事件（原设计保留）。这条借鉴的实质是：把我们已定的方向用"配置即策略"的
形式固化，并获得一个外部独立佐证。

**B2 · 被拒绝的工具应当不存在，而不是存在但被禁止。**
OpenClaw：权限模式直接从会话里**移除**工具定义（模型连 schema 都看不见），deny 永远
赢，无分类方法默认拒。
我们的现状：profiles.py 有 allowed/denied_tools；可行性文档 §3.3 已定网关白名单
fail-closed。
**改动（双层）**：第一层在会话组装时——dsh 侧用 preset 只挂该 Profile 的工具、
Codex 侧按 Profile 裁剪 MCP 暴露面，**被拒绝的工具不进入模型上下文**；第二层在
网关——未注册/未授权工具调用结构性强拒。两层都不可单独失效：harness 配置写错，
网关不放行；网关被绕过，模型手里本来就没有那把工具。

**B3 · 审批绑定 + 漂移即拒 + 触达不到人时 fail-closed。**
OpenClaw：exec 审批绑定规范化命令/cwd/环境哈希/文件操作数内容哈希，批准后任何
漂移即拒；无审批 UI 默认拒；严格情形不可软化。
我们的现状：可行性文档 §3.5 的 HITL 是"人在决策点批准"，没有定义批准的**对象粒度**。
**改动（直接升级 SQL 审批与决策 HITL 的语义）**：批准对象 = **绑定产物**——SQL 审批
绑定（SQL 文本 + 参数 + 数据源 + as-of）的哈希，决策审批绑定（备忘录 artifact 内容
哈希 + 证据快照 id）；批准后内容有任何变化 = 原批准作废、重新过人。HITL 超时策略
定为 **fail-closed**（决策类 run 等不到人就停在终态之外，绝不超时自动放行）。

**B4 · 凭据按次铸造 + 推理经网关代理。**
OpenClaw cloud worker：按次派发铸造凭据（10 分钟 TTL、哈希落盘、RPC 白名单），
推理经 Gateway 代理，worker 不持任何常驻模型/GitHub/云凭据。
我们的现状：可行性文档 §3.7 是"worker 环境持 API key、spawn 时白名单清洗下发"——
harness 进程仍持有真 key（能调通 OpenAI/DeepSeek 的就是真 key）。
**改动（v1 就值得做，两侧配置成本都极低）**：
- **推理代理**：模型调用经我们网关/代理出口，真 key 只在代理侧——Codex 的 provider
  `base_url`、dsh 的 `DEEPSEEK_BASE_URL`/`base_url` 参数都原生支持指向自建端点
  （可行性文档 §1 已核）。harness 进程拿到的 base_url 指向内网代理，进程里**一把
  真 key 都没有**。附带收益：token 计量在代理处天然落账（R8 的预算记账更准）、
  出口白名单收拢有了物理载体（R6）。
- **run 级令牌**：工具网关令牌按 attempt 铸造，subject 绑 run_id+profile+attempt_no，
  短 TTL，run 结束即吊销——把 I7 的"精确键 + allowlist"再收紧到时间维度。

**B5 · 有界恢复预算 + 崩溃循环熔断。**
OpenClaw：重启恢复在有限尝试预算内恢复中断 turn；崩溃循环熔断器保住控制面可达。
我们的现状：可行性文档 R5 有快照/恢复，没有定义"恢复尝试的上限"与"连续崩溃怎么办"。
**改动**：RunBudget 增加 `max_attempts` 档（第四维之外的第五维）；同一 Profile 版本
连续 N 个 attempt 启动即崩 → 熔断该 Profile 版本并落事件 + 告警，新 run 不再分发到
它（防"dsh 某钉版在我们环境里坏了，所有财务 run 排队送死"）；快照格式带 harness
版本号，restore 校验兼容性（学它"库比自身新即拒开"）。

### 2.4 明确不借的清单

WS Gateway 协议与通道抽象（我们有 HTTP 分面 + SSE）、设备配对（我们有 Casdoor）、
SQLite 状态（D1/D2 要 PG）、它的插件 API 作为我们的扩展机制（我们的扩展 = Profile
+ 网关工具）、它的 agent runtime 本体（我们租 Codex/dsh）、fleet 多租户形态
（我们是单平台多用户）。

### 2.5 对可行性文档的具体修订点

以上五条落实为可行性文档的增量，不推翻其任何一节：

| 位置 | 增量 |
| --- | --- |
| §3.1 Supervisor | 路由表 = 版本化配置，变更落事件（B1） |
| §3.3 工具网关 | 双层门禁：会话组装层裁剪工具面 + 网关结构性强拒（B2） |
| §3.5 HITL | 审批绑定产物哈希、漂移作废、超时 fail-closed（B3） |
| §3.7 部署形态 | 推理经出口代理、真 key 不下发；run 级短 TTL 令牌（B4，R6 同步升级为"已收拢"） |
| §4 R5 | 恢复有界：max_attempts + Profile 版本熔断 + 快照版本校验（B5） |
| §6 落地顺序 | B4 推理代理进 S1 spike（两侧都是 base_url 配置，顺便验计量落账） |

---

## 3. 两问合一的一句话

换架构是旧分析的逻辑终点，好得有结构、且留有反证条款（§1.4）；OpenClaw 证明了
我们 Supervisor 的形态选择（确定性路由 + 代码强制策略 + 不可信执行）是对的方向，
它的价值是**机制教师**而不是**平台候选**——借五条机制（B1–B5），一行它的代码
和架构都不进我们的仓。

## 4. 速查

```text
OpenClaw 机制锚点：~/repo/openclaw/docs/start/why-openclaw.md（信任边界/策略即代码/凭据/版本化状态）
                ~/repo/openclaw/docs/channels/channel-routing.md（模型不路由原文）
                ~/repo/openclaw/docs/agent-runtime-architecture.md（Runtime Selection 配置策略）
                ~/repo/openclaw/docs/concepts/architecture.md（WS 协议/配对）
换架构事实锚点：development-plan.md（执行层租用原定）、constraints.md A4、
               investment-app-agent-architecture-kimi.md §1/§7（论证回收与壁垒清单）
修订落点：supervisor-dual-harness-feasibility-kimi.md §3.1/§3.3/§3.5/§3.7/§4 R5/§6
```

