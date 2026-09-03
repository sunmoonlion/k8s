# investment-app Agent 总体架构可行性分析（Supervisor + 双 Harness SDK 分发）

> 时点：2026-09-02 ｜ 作者：qwen3.8 ｜ 性质：架构可行性分析（个人决策底稿），**非 baseline、非 REQ**。
> 立项时按治理规则走 `k8s/sunmoonai/docs/sunmoonai-architecture/requests/` 的 REQ 流程。
>
> **评估对象（用户拟议架构）**：investment-app 下新建一个 supervisor，接受前端 task，
> 做路由——通用任务交"通用 agent"（经 SDK 分发给 **codex**），专业任务（如财务分析）
> 交"专用 agent"（经 SDK 分发给用 **deepseek-harness（dsh）** 构建的财务等专业 agent）。
>
> **证据纪律**：本文所有 `file:line` 锚点均于 2026-09-02 亲自 `ls/grep/read` 核实
> （REQ-002 纪律）；与代码冲突时以代码为准。四个一手源 + 六份既有产物见 §1。
> 凡只有外部文档指针（developers.openai.com）支撑、未能在本地源码复核的结论，均降半档标注。
>
> **本文与既有 `~/codex-reference-archive/qwen3.8/investment-app-agent-architecture-qwen3.8.md` 的关系**：
> 那份假定的是**自建 LangGraph 运行时 + 自研 Supervisor + Wren/DockerSandbox**；本文评估的是
> **把执行外包给两个现成 harness（codex/dsh）、supervisor 只做路由分发**的新路线。二者不冲突：
> 那份的治理纪律（"一套地基两种形态"、决策权三分法、结果契约、预算三件套、"没有人在场"）
> 在本文里**全部继续适用**，只是"两种形态"从"两种自建执行档"变成"两个外部 harness"。

---

## 0. 结论先行（TL;DR）

**可行，且与现有基建高度契合——但有三条必须钉死的前提，和一个用户可能没考虑到的关键备选。**

1. **supervisor 不是新建独立系统，是现有治理壳上的增量。** investment-backend 已有一条
   成熟的 Pilot 生产链（LangGraph + PostgresSaver + celery + 事件溯源 + HITL interrupt/resume
   + SSE + 幂等 + 委托安全上下文 + 协作式取消），`AgentProfileCatalog` 就是路由表的现成落点。
   supervisor + 双 harness 应**嵌进这条链**，而不是另起炉灶（§3、§4）。

2. **两个 SDK 架构同形，落地成本比想象低。** codex 官方 Python SDK（`openai-codex`）与
   dsh 官方 Python SDK（`deepseek-harness`）是**同一形状**：子进程 + 捆绑原生 runtime 二进制
   + stdio 上换行分隔 JSON-RPC + `run()→result` + notification 流。两者的原生二进制都能跑在
   现有 `python:3.12-slim`（glibc 2.36）worker 镜像里（§2、§6）。

3. **三条硬前提（不满足则方案不成立）**：
   - **① 安全红线**：codex SDK 的默认审批 handler **自动 accept 命令执行与文件改动**
     （`client.py:773-779`）。headless 生产**必须**覆盖 `approval_handler` 并配 `Sandbox`/
     `ApprovalMode`，把审批路由到现有 HITL 或 `deny_all`。这是"没有人在场"下最危险的一处。
   - **② 治理黑箱**：两个 harness 的内部 agent loop 都是"自由编排"（模型自决工具调用），
     按既有决策权三分法（D1）属**生产禁用的第 3 档**。委派给它们 = 进口一个黑箱循环。
     只能从**外部**约束（sandbox / approval / output_schema / budget），财务域还须用 dsh 的
     `workflow`/`guard`/`plan`/`preset` 把循环收敛成受约束工作流，**不得放任 ReAct**（§7-8）。
   - **③ 异构契约统一**：codex `TurnResult` 与 dsh `RunResult` 是两套结果契约 + 两套事件协议
     + 两套原生二进制 + 两套认证。必须统一投影进现有 Run/RunStatus/RunBudget/timeline/HITL，
     让一个 codex run 与一个 dsh run 能在**同一条 timeline 上回放**（§4、§7-4）。

4. **关键备选（用户方案之外，务必先决策）**：dsh 原生带 **`subagent-codex`**（"one-shot
   unattended Codex delegation"）、**`subagent-dsh-sdk`**（委托另一个 harness runtime）、
   **`tool-subagent-control`**（全局 `send_message`/`interrupt_agent`/`list_agents`）。这意味着
   **dsh 本身就能当 supervisor 去委托 codex**（Option B），与"in-house supervisor + 双 SDK
   adapter"（Option A，即用户字面方案）构成路线选择。我倾向 **Option C 混合**（§5）。

5. **一个语义契合问题需用户澄清**：codex 是**编码优化**的 agent。investment 的"通用任务"
   究竟指编码/自动化，还是研究/问答/分析？前者 codex 契合；后者 codex 能做（有 web/MCP）
   但非最优，且要为它单开 OpenAI 出口与认证（§7-10）。

6. **两个补充裁决（应你要求，§10/§11）**：① **更新架构只换了 L3 执行层**（自建 agent loop →
   委托 codex/dsh harness），L0/L2/L4/L5 与"必须自建六样"的前五样全不变——方向合理、执行层更好，
   但治理从"内生可控"变"外挂箍黑箱"，净收益为正、取决于 gate 箍得好不好（§10）。② **OpenClaw**
   （trusted gateway / untrusted execution / deterministic policy，把 codex app-server 当 native
   runtime）是我们路线的**成熟外部参照系**：借鉴其确定性 binding 路由 + 分层 gate + native-runtime
   边界 + Tier/hard-blocks，**不搬其 TS 单网关系统**——落成"supervisor = 确定性 gate 路由器，而非
   LLM 意图分类 agent"，即 Option C 的 gate 化精修版（§11）。

**一句话裁决**：架构成立、地基现成、SDK 同形；成败不在"能不能跑通一个 run"，而在
**"能不能把两个自由编排的外部黑箱，套进现有治理壳，做到可审计、可预算、可 HITL、可统一回放"**。
下文逐项给证据与缓解。

---

## 1. 证据基础（五源 + 六份既有产物，证据分层）

| 层级 | 源 | 今日亲验内容 |
| --- | --- | --- |
| L1 一手源码 | `/home/zym/repo/deepseek-harness` | Python SDK（`python/sdk`、`python/sdk-runtime`）、`AGENTS.md`、`packages/{bundle,preset,subagent}` |
| L1 一手源码 | `/home/zym/repo/codex` | Python SDK（`sdk/python`、`sdk/python-runtime`）、`codex-rs/*` 目录面、`codex-cli/bin/codex.js`、`docs/` |
| L1 一手源码 | `investment-app/investment-backend` | domain/application/infrastructure/interfaces/tasks 五层 agent 代码、前端入口、`mybuild/Dockerfile` |
| L1 一手源码（参照系） | `/home/zym/repo/openclaw` | 架构主张 `docs/start/why-openclaw.md`、gate 分层 `docs/plugins/plugin-permission-requests.md`、Codex 监督边界 `docs/specs/codex-supervision.md`、多 agent 路由 `docs/concepts/multi-agent.md`、委托/网关 `docs/concepts/{delegate-,}architecture.md`、`VISION.md` |
| L2 既有产物 | `~/codex-reference-archive/`（我此前六份） | orchestration-assessment / deepdive-v2 / sandbox-advice / wrenai / sqlbot / agent-architecture |
| L3 外部指针 | codex `docs/{sandbox,exec}.md` | 仅指向 developers.openai.com，本地源码无细节——涉沙箱内核行为处降半档 |

六份既有产物的定位（避免重复探索）：编排考证与决策权三分法见 `codex-orchestration-assessment`；
源码级机制（trigger_turn/预算三件套/压缩/角色/code-mode）见 `codex-deepdive-v2`；沙箱端口与加固见
`sandbox-extension-advice`；财务问数走 Wren 语义层的路线决策见 `wrenai-financial-analysis-integration`
与 `sqlbot`；总体设计纪律见 `investment-app-agent-architecture`。本文是它们之上的**路线增量评估**。
OpenClaw（`~/repo/openclaw`）作为**外部参照系**新加入 L1——它是"委托外部 harness + 确定性 gate 治理"
路线的成熟样本（本身把 codex app-server 当 native runtime），评估与借鉴清单见 §11。

---

## 2. 两个 SDK 的真实接口面（一手核查）

### 2.1 codex 官方 Python SDK（`openai-codex`）

**进程模型**：`CodexClient.start()` spawn `codex app-server --listen stdio://` 子进程
（`sdk/python/src/openai_codex/client.py:246-269`），走 stdio 上换行分隔 JSON-RPC；reader 线程
把消息分流成 request/response/notification（`client.py:803-834`）。runtime 二进制由
`openai-codex-cli-bin` wheel 提供（`client.py:111-121` `bundled_codex_path()`），或 `CodexConfig.codex_bin`
覆盖。`bin/codex.js:18-25` 表明 Linux 目标是 `x86_64-unknown-linux-musl`（**musl 静态二进制**，容器友好）。

**公开 API**（`sdk/python/docs/api-reference.md`）：
- 入口 `Codex`（同步，eager：`__init__` 即启动 transport + initialize）/ `AsyncCodex`（异步，lazy）。
- 线程生命周期：`thread_start(approval_mode, base_instructions, config, cwd, developer_instructions, ephemeral, model, model_provider, personality, sandbox)` / `thread_resume` / `thread_fork` / `thread_list` / `thread_archive`（`api-reference.md:68-73`）。
- 跑一轮：`Thread.run(input, *, approval_mode, cwd, effort, model, output_schema, personality, sandbox, service_tier, summary) -> TurnResult`（`api-reference.md:153`）。
- `TurnResult`：`id/status/error/started_at/completed_at/duration_ms/final_response/items/usage`（`api-reference.md:171-179`）——**带 token usage**，可直接喂 RunBudget。
- 低层控制：`Thread.turn(...) -> TurnHandle`，含 `steer()`/`interrupt()`/`stream()->Iterator[Notification]`/`run()`（`api-reference.md:208-220`）。
- **并发**："Turn streams are routed by turn ID so one client can consume multiple active turns concurrently"（`api-reference.md:5`）——**单个 Codex 实例可并发多 turn**（fan-out 友好）。
- 结构化输出：`output_schema=`（`api-reference.md:153`）——结果契约的现成抓手。
- 沙箱：`Sandbox.read_only / workspace_write / full_access`（`api-reference.md:199-203`）。
- 审批：`ApprovalMode = deny_all | auto_review`（`_approval_mode.py:13-17`）；审批以 **server→client JSON-RPC 请求**到来，client 应答（`client.py:826-834`）。
- 压缩 / 目标：`thread.compact()`（`client.py:486-491`）、`thread/goal/*`（`client.py:493-518`）。
- 认证：`login_api_key` / `login_chatgpt` / `login_chatgpt_device_code` / `account` / `logout`；复用 `CODEX_HOME`（`client.py:863-865` `default_codex_home()=~/.codex`）。
- 部署旋钮：`CodexConfig`（`client.py:194-209`）= `codex_bin / launch_args_override / config_overrides(--config k=v) / cwd / env / experimental_api`。
- 要求 Python >= 3.10（`api-reference.md:50`）。

**⚠ 安全红线（亲验）**：`client.py:773-779` `_default_approval_handler` 在调用方**未提供** handler 时，
对 `item/commandExecution/requestApproval` 与 `item/fileChange/requestApproval` **一律返回 `{"decision":"accept"}`**。
headless 生产若不覆盖，等于放任 codex 在 worker 容器内自动执行命令、改文件。

### 2.2 deepseek-harness 官方 Python SDK（`deepseek-harness`）

**进程模型**：`HarnessClient.start()` spawn 捆绑的 `dsh` CLI（`--profile sdk`）子进程
（`python/sdk/src/deepseek_harness/client.py:80-90`、`_default_launch_args:458-486`），同样走 stdio
换行分隔 JSON-RPC（`python/sdk/README.md:5`）。runtime 由 `deepseek-harness-runtime-bin` wheel 提供：
**单文件 Node 可执行（SEA）+ ripgrep sidecar**，"SDK use requires no system Node.js"
（`sdk-runtime/README.md:5,11`）；`resolve_bundled_launch_args()` 解析 argv（`sdk-runtime/__init__.py`）。
平台：`sdk-runtime/platforms.json` = Linux x64 `manylinux_2_28_x86_64`、Linux arm64 `manylinux_2_28_aarch64`
（**glibc 2.28+，非 musl**）、macOS arm64、Windows x64。

**公开 API**（`python/sdk/src/deepseek_harness/api.py`）：
- 入口 `DeepSeekHarness(config | **kwargs)`（`api.py:49`），**仅同步**；context manager 或 `close()` 收子进程。
- 配置 `DeepSeekHarnessConfig`（`api.py:13-37`）= `provider(默认 deepseek-official) / model(默认 deepseek-v4-flash) / reasoning_effort / max_tokens / cwd / runtime_cwd / dsh_bin / profile(默认 sdk) / patches / dsh_home / env / base_url / api_key`。
- 跑一轮：`harness.run(input, *, session_id, on_notification) -> RunResult`（`api.py:124-131`）；或 `start_session(session_id).run(...)`（`api.py:120-122,139-189`，阻塞至 `session.status=idle`）。
- `RunResult`（`api.py:40-46`）= `session_id / final_response / finish_reason / events / notifications`；**`events` 只含 root-session**，子 agent 输出经 notifications（`README.md:66-68`）。
- 专业化 seam：**profile + bundle + patch**——`dsh plugin --profile sdk add file:/path/to/bundle`（`README.md:37-45`），或 per-invocation `patches=(*.patch.yml,)`；profile 拥有 JSON-RPC server / agent composition / credentials / persistence / tools / shutdown（`README.md:13`）。
- 认证：`DEEPSEEK_API_KEY` / `DEEPSEEK_BASE_URL`（`api.py:71-74`）；`DSH_HOME` **必须显式**，绝不 fallback `~/.dsh`（`README.md:15`、`client.py:471-479`）。

**⚠ 关键不对称（亲验）**：`grep -rniE 'interrupt|cancel|steer|abort' python/sdk/src/` **零命中**——
dsh Python SDK **无 per-run 中断/取消/转向**，只有 run-to-completion + `close()`（shutdown→terminate→kill，
`client.py:94-131`）。取消一个 dsh run 的粒度 = **杀子进程**，比 codex 的 `turn/interrupt` 粗。

### 2.3 同形性 vs 关键不对称（对照表）

| 维度 | codex `openai-codex` | dsh `deepseek-harness` |
| --- | --- | --- |
| 形状 | 子进程 + stdio JSON-RPC | **同形** |
| runtime 二进制 | `openai-codex-cli-bin`（musl 静态 Rust） | `deepseek-harness-runtime-bin`（glibc Node SEA + rg） |
| 执行单元 | Thread → Turn | Session → run |
| 跑一轮 | `thread.run()→TurnResult` | `harness.run()→RunResult` |
| 同步/异步 | **同步 + 异步（AsyncCodex）** | **仅同步** |
| 单实例并发 | **是（多 turn 按 id 路由）** | 多 session，但 `run()` 阻塞/线程 |
| 流式 | `turn().stream()` / `item/agentMessage/delta` | `on_notification` / `session.event` |
| 结构化输出 | **`output_schema=` 原生** | 无 run 级参数，靠 bundle 工具/会话日志产出 |
| 中断/取消 | **`turn/interrupt` + `steer`** | **无（只能杀进程）** |
| 压缩 | `thread.compact()` | profile 的 compaction 插件 |
| 沙箱 | `Sandbox` 枚举（read_only/workspace_write/full_access） | profile 拥有 tools + `native/` landlock |
| 审批 | server→client 请求 + `ApprovalMode`；**默认 auto-accept** | profile 的 `interaction` 插件（permission/ask-user） |
| 专业化 | config/base_instructions/developer_instructions/personality/model | **profile + bundle + patch + preset** |
| 认证 | CODEX_HOME（API key / ChatGPT） | DSH_HOME + DEEPSEEK_API_KEY/BASE_URL |
| 模型 | OpenAI（GPT 系） | DeepSeek（可经 composition 挂 llm-pi-ai 换 provider） |

**判读**：同形让"双 adapter 投影进同一治理壳"在工程上成立；不对称（异步/并发/output_schema/interrupt
在 codex 侧更强，profile/bundle/preset/subagent 在 dsh 侧更强）决定了**两侧 adapter 不是镜像复制**，
取消语义与结构化输出要分别处理（§7-4、§7-5）。

---

## 3. 现有 investment-backend 治理壳（supervisor 的地基，不是空地）

`grep -rniE 'supervisor|harness|codex|deepseek|openai_codex' app/app` **零命中**——集成是 greenfield。
但**治理壳已建成**，supervisor 应复用而非重建：

**Pilot 生产链全貌**（亲验）：
```text
前端 research-workspace.tsx / lib/interaction/client.ts
  → POST /runs（pilot_runtime_routes.py:52）或 POST /agent/sessions/{id}/runs（agent_routes.py:78，v4 流量门 agent_v4_traffic_enabled 默认关）
  → PilotService.create_run（pilot_service.py:34，幂等键 + DelegatedUser.actor_id）
  → celery dispatch_pilot_graph（celery_producer.py:77）
  → worker task pilot_agent_graph.py:269 → _run_pilot_graph:79（_run_in_worker_loop 起 asyncio loop）
  → build_pilot_graph(checkpointer=phase0_postgres_checkpointer())（:110-111，LangGraph + PostgresSaver）
  → LangGraphRuntimeService.stream_with_config（graph_runtime_service.py:33，graph.stream + __interrupt__）
  → retrieve（knowledge_retrieval，RetrievalSecurityContext 带 delegated_run_id）→ citations → draft（OpenAICompatiblePilotLLM.answer）
  → interrupt（HITL 审批）→ input_required 事件 + status=waiting + resume_token=action_id（:174-205）
  → resume：graph.stream(Command(resume=...)) → summary → delta/completed（:207-237）
  → 全程 append_browser_event + Redis publish → GET /runs/{id}/events SSE（pilot_runtime_routes.py:98）
```

**可复用的治理原语**（domain 层，亲验）：
- `AgentProfileCatalog.resolve(agent_profile_key)`（`profile_catalog.py`）→ **路由表现成落点**；现有
  `default_research`/`literature_review` 两个 profile（`system_prompt_id`/`model_key`/allowed-denied tools/
  `memory_policy`/`ragflow_binding_key`）。`CreateRunCommand.agent_profile_key`（`commands.py:14`）就是路由输入槽。
- `AgentProfile` / `EffectiveAgentConfig.permits_tool()`（`profiles.py:14,26,36`，deny 优先）——角色=配置（对应既有 D7）。
- `RunBudget`（`runtime.py:62`，四维 max_steps/tool_calls/llm_calls/input_tokens + 不可变 `consume_*`）——
  预算账本现成；codex `TurnResult.usage` 可直接喂它。
- `RunStatus` + `RUN_STATUS_TRANSITIONS` + `validate_run_status_transition`（`runtime.py:34,51`）——状态机现成
  （含 `budget_exceeded` 终态）。
- `CancelRunCommand`（`commands.py:31`，休眠）+ 协作式取消（`pilot_agent_graph.py:70-76` `_cancelled`）。
- `SandboxPort`（`domain/agent/sandbox.py:39`，**生产零调用**，休眠）——**port/adapter 手法的现成模板**：
  两个 harness adapter 应照此形状（domain 定义 port、infrastructure 实现、profile 裁决权限）。
- 事件溯源 + timeline（`event_sink.py` / `timeline_projector.py`）+ SSE（`agent_routes.py:153-220`，
  Redis pubsub + durable snapshot 去重）+ 幂等 + 委托安全上下文（`SecurityContext`）。

**结论**：用户方案的 supervisor + 双 harness 是这条链的**增量**——新增"路由节点 + 两个 HarnessPort
adapter + 投影统一"，复用 Run/RunStatus/RunBudget/event/timeline/HITL/SSE/幂等/委托。**不建第二套系统**
（既有架构文档 §1 第二总纲）。

---

## 4. 用户方案的架构落位（Option A：in-house supervisor + 双 SDK adapter）

```text
L5 治理层   RunBudget 账本 │ 事件溯源/timeline │ 身份权限(DelegatedUser) │ 契约锁   ← 全部现成，复用
L4 质量层   output_schema 校验 │ dry_plan critic │ HITL interrupt │ 金标准评估       ← 现成 + 增量
L3 执行层   ┌ CodexHarnessAdapter（通用任务）   ┐  ┌ DeepSeekHarnessAdapter（财务等）┐ ← 新增（SandboxPort 同款 port/adapter）
            │ openai_codex: thread_start/run    │  │ deepseek_harness: run/session   │
            │ →TurnResult(usage/items/schema)   │  │ →RunResult(final/events/notifs) │
            └ 子进程: codex app-server (musl)   ┘  └ 子进程: dsh --profile fin (SEA) ┘
L2 路由层   Supervisor 节点：意图→执行档（constrained-dynamic enum，落 AgentProfileCatalog）← 新增（LangGraph 节点）
L1 领域骨架 财务工作流（dsh bundle/preset：analyst/checker/awaiter + Wren 六工具）        ← 新增（dsh 侧）
L0 运行时   LangGraph + PostgresSaver + celery + outbox + event_sink                    ← 现成，复用
```

**概念→实体映射表**：

| 用户概念 | 现有实体 | 新增件 |
| --- | --- | --- |
| 前端传 task | `POST /runs`、`CreateRunCommand`（含 `agent_profile_key`） | 路由输入契约（task 类型/数据集 hint） |
| supervisor | Pilot 链的 LangGraph + celery worker | **Supervisor 路由节点**（新 graph 或 pilot graph 前置节点） |
| 路由（通用/专业） | `AgentProfileCatalog.resolve` | 扩 catalog：`general_codex` / `financial_dsh` 等 profile + 分类器 |
| 通用 agent（codex） | `SandboxPort` 的 port/adapter 模板 | **CodexHarnessAdapter**（infrastructure）+ codex 子进程池 |
| 专业 agent（dsh 财务） | 同上 | **DeepSeekHarnessAdapter** + dsh financial **bundle/profile/preset** |
| 结果回收 | `event_sink`/`timeline_projector`/browser_event | 两套 result→统一 Run/artifact/event 投影器 |
| 预算/取消/HITL | `RunBudget`/`CancelRunCommand`/interrupt-resume | usage→budget 映射；approval→HITL 路由；dsh 杀进程取消 |

**supervisor 路由 = 决策权三分法第 2 档**（constrained-dynamic）：LLM/规则只能在**已注册执行档枚举**
里选（`general_codex` / `financial_dsh` / `pilot_rag` / …），选择经 pydantic schema 校验后落应用服务执行；
**未命中本身落事件流**（新任务类型信号，喂固化雷达）。这是既有 D1 纪律的直接套用，不是新发明。

**两个 adapter = SandboxPort 同款手法**：domain 定义 `HarnessPort`（`run(request)->HarnessResult` 值对象，
可序列化），infrastructure 双实现（codex/dsh），profile 层裁决权限与预算。第一版 REQ 应明确**不改 domain
签名**（沙箱文档 §2.1 纪律），接口演进留给被真实需求顶出来后的第二份 REQ。

---

## 5. 关键备选：Option B（dsh-native supervisor）与 Option C（混合，我倾向）

**dsh 原生委托家族**（`packages/subagent/`，亲验）——这是用户字面方案之外、必须纳入决策的发现：

| 包 | 作用（README description 原文） |
| --- | --- |
| `subagent` | 委托 seam `ctx.subagents`：provider registry、one-shot run、continuable child、discovery |
| **`subagent-codex`** | **"one-shot Codex subagent provider … configuring an unattended Codex delegation"** |
| **`subagent-dsh-sdk`** | **"out-of-process SDK subagent backend … child Harness runtime command"**（委托另一个 dsh） |
| `subagent-acp` | out-of-process ACP subagent（配置 child ACP agent command） |
| `subagent-claude-code` | one-shot Claude Code subagent（unattended delegation） |
| `subagent-spawn/fork-in-process` | 进程内子 agent（fresh / 从父已完成历史 fork） |
| `tool-subagent` | 模型可见的委托工具 |
| **`tool-subagent-control`** | **全局 `send_message` / `interrupt_agent` / `list_agents`（continuable-child 控制）** |
| `tool-subagent-report` | child→parent 返回通道 |

即 `packages/subagent/README.md` 明说：一个 composition 可混用进程内子 agent 与**进程外子 agent——
"an ACP agent, a real Codex or Claude Code installation, or a complete Harness runtime over the SDK"**。

**三种落法对照**：

| 维度 | Option A：in-house supervisor + 双 SDK adapter（用户字面方案） | Option B：dsh supervisor profile 委托 codex | Option C：混合（我倾向） |
| --- | --- | --- | --- |
| supervisor 在哪 | investment-backend LangGraph 节点 | dsh 内一个 DeepSeek 模型的 agent loop | in-house 壳做路由+治理；财务域内部用 dsh preset/subagent |
| 编排来源 | 自建（复用现有壳） | **dsh 原生**（subagent-codex + tool-subagent-control，几乎白捡） | 自建壳 + dsh 域内委托 |
| 治理可控性（"没有人在场"） | **最高**（预算/审计/HITL/timeline 全在 in-house 壳） | 最低（supervisor 脑在 dsh 黑箱内，治理须从外部强加或靠 dsh session log + guard 插件） | **高**（单一 in-house 控制面） |
| 统一 timeline | 两 adapter 各自投影，可控 | 复杂：Python SDK `RunResult.events` **只含 root-session**，codex 子 agent 经 notifications（subagent.started/finished）+ ancestry，投影更绕 | 可控（codex 由 in-house 直接分发，不嵌进 dsh） |
| codex 审批/HITL | in-house `approval_handler` 直接路由到现有 interrupt/resume | codex 作为 dsh 的 "unattended" 子 agent，审批由 subagent-codex provider 配置控制，**难路由到 in-house HITL** | in-house 直接控 codex 审批 |
| 财务域角色组合 | 需自建 | **dsh preset 白捡**（一进程多 agent：analyst/checker/awaiter） | **dsh preset 白捡** |
| 复用现有壳 | **完全** | 部分（壳退化成"包一个 dsh run"） | **完全** |
| 新增依赖面 | codex SDK + dsh SDK（两个并列） | 主要 dsh SDK（codex 经 dsh 委托，间接） | codex SDK + dsh SDK |

**我的倾向：Option C。** 理由：① 治理壳留在 in-house（"没有人在场"→比 codex/dsh 桌面形态更设防，
既有总纲）；② codex 由 in-house supervisor **直接**分发，审批/取消/output_schema 可控（不嵌进 dsh 的
unattended 委托，避免 §5 表里 Option B 的审批黑箱与 timeline 投影难题）；③ 财务域**内部**用 dsh 的
preset/bundle/subagent 组合 analyst/checker/awaiter 三角色与 fan-out（白捡 dsh 的域内编排，对应既有 D7）。
即：**in-house 壳是单一控制面，codex 与 dsh 是它下面两个平级执行器；dsh 财务 agent 内部可再自带子 agent 树。**

Option B 不是否定——若未来"通用任务"占比低、财务域内部编排极复杂，可把更多编排下沉给 dsh；但**第一步
不应让 supervisor 的脑进黑箱**，否则治理与审计从第一天就欠债。

---

## 6. 部署可行性（原生二进制 × 现有 worker 镜像）

| 项 | 事实（亲验） | 裁决 |
| --- | --- | --- |
| worker 基础镜像 | `mybuild/Dockerfile:8,56` `FROM python:${PYTHON_VERSION}-slim`；`build-image.sh:110` `python:3.12-slim`（Debian bookworm，**glibc 2.36**） | ✓ 满足 dsh `manylinux_2_28`（glibc 2.28+） |
| codex 二进制 | musl 静态 Rust（`bin/codex.js:18` `x86_64-unknown-linux-musl`） | ✓ 静态，无 glibc 依赖，容器友好 |
| dsh 二进制 | 单文件 Node SEA + ripgrep sidecar，"no system Node.js"（`sdk-runtime/README.md:5,11`） | ✓ 自包含；须烘进镜像 |
| 架构 | 镜像 multi-arch（x64/arm64）；两 SDK 均按平台发 wheel | ✓ 按目标 arch 选 wheel |
| HOME 供给 | codex 需 `CODEX_HOME`（默认 `~/.codex`）；dsh 需**显式** `DSH_HOME`（绝不 fallback） | 须在镜像/Secret 里 provision 两个隔离 home |
| 二进制钉死 | 两 SDK 版本 track 各自 CLI release | 按 digest 钉死（既有 release.json 不可变纪律） |
| 出口 | codex→OpenAI；dsh→DeepSeek（+ 财务库/Wren） | **两个模型 provider 出口** + 数据源出口，白名单默认拒绝（沙箱文档 §5-10） |

**部署形态建议**：两个 runtime wheel（`openai-codex-cli-bin`、`deepseek-harness-runtime-bin`）烘进
**worker 镜像**（不是 API 镜像——子进程在 celery worker 里 spawn）；`CODEX_HOME`/`DSH_HOME` 用空目录 +
Secret 注入凭据；财务 bundle 与 Wren MDL 制品按 digest 进镜像（wrenai 文档 §3-⑥）。

---

## 7. 必须正视的硬约束与风险清单（"没有人在场"演绎）

> 既有考证的核心判断继续成立：codex/dsh 的编排可靠性在桌面场景由**用户在场**兜底；你的生产系统没有
> 这个兜底（`codex-orchestration-assessment` §2.3、`agent-architecture` §1）。下述每条都从这一条推出。

1. **codex 默认审批 auto-accept（安全红线，最高优先）**。`client.py:773-779` 默认 accept 命令执行/文件改动。
   **缓解**：in-house adapter 必须传自定义 `approval_handler`——生产默认 `ApprovalMode.deny_all` +
   `Sandbox.read_only`；需写/执行的动作路由到现有 HITL（interrupt/resume + action token，`pilot_service.py:111`）。
   验收：一个 codex run 想执行 shell 时，能在 timeline 上看到 `input_required` 而非静默 accept。

2. **治理黑箱 vs 决策权三分法**。harness 内部 loop = 自由编排（D1 第 3 档，生产禁用）。**缓解**：从外部
   四道箍——`Sandbox`/`ApprovalMode`（codex）、profile tools/`interaction`（dsh）、`output_schema`（codex 原生；
   dsh 靠 bundle 工具产 schema artifact）、`RunBudget`（usage 映射）。财务域**必须**用 dsh `workflow`/`guard`
   （loop-hygiene + tool-timeout）/`plan`/`preset` 把循环收敛成受约束工作流，**不得放任 ReAct**（否则违约
   既有 §2 八条：不可回放/不可回归/成本方差失控/决策无红线）。

3. **子进程资源模型**。N 并发 = N 原生子进程（codex musl 二进制 / dsh Node SEA，RSS 各数十~数百 MB）。
   codex `AsyncCodex` 单实例可多路复用 turn（省进程）；dsh 仅同步、一实例一进程。**缓解**：子进程**池化 +
   并发上限 + TTL 回收**（孤儿进程兜底，沙箱文档 §4 `SandboxHandle` TTL 纪律）；RunBudget **全树共享账本**
   （deepdive §3：fan-out 的 N 个子 run 共摊根预算，防 N 份失控）。

4. **异构结果契约统一**。`TurnResult`（items/usage/final_response/output_schema）vs `RunResult`
   （final_response/events/notifications/finish_reason）。**缓解**：定义统一 `HarnessResult` 值对象 +
   两个投影器；**回读即攻击面**（既有 D4）——supervisor 读回 harness 产物默认不可信，schema 化回读
   （只回 schema 字段，不回自由文本全文）写进 adapter 验收标准。codex 用 `output_schema` 拿结构化结果；
   dsh 财务 bundle 须产 schema'd artifact（经工具或会话日志，dsh "model-visible ⟺ logged" 保证可重建）。

5. **取消语义不对称**。codex 有 `turn/interrupt`+`steer`（细粒度）；dsh Python SDK **无**中断，取消=杀子进程
   （粗粒度，`client.py:94-131`）。**缓解**：`CancelRunCommand` 接线时分两路——codex 走 interrupt（可恢复/可转向），
   dsh 走 close/kill（不可恢复，须重跑）；dsh 长 job 用 `presets` 的 **awaiter 角色**（便宜模型轮询，deepdive §5）
   降低"杀进程重跑"的代价。

6. **沙箱内核嵌套（L3 降半档）**。codex 自带 landlock/seccomp（`codex-rs/linux-sandbox`），dsh 有
   `native/` landlock-run addon。k8s pod 内 landlock 可能不可用/受限，二者内部沙箱**可能初始化失败**
   （codex `docs/sandbox.md` 仅指向外部 URL，本地无细节，降半档）。**缓解**：以**容器为沙箱边界**——
   codex 用 `Sandbox.full_access` 或 read_only 关掉其内部沙箱依赖、dsh profile 关内部沙箱，worker 容器
   cap-drop/seccomp/只读 rootfs（沙箱文档 §5）；dev 阶段 kind+runsc 演练 gVisor（沙箱文档 §3-2），把升级
   路径变成做过的事。

7. **双 provider 认证与出口**。codex：`CODEX_HOME` + API key（headless 用 `login_api_key`，不用 ChatGPT 浏览器流）；
   dsh：`DSH_HOME` + `DEEPSEEK_API_KEY/BASE_URL`。**缓解**：凭据经现有 Secret 管理注入，不落 home 文件/不进镜像；
   财务库/Wren 凭据**只读、最小权限、单 scope**，用委托令牌（DelegatedUser 体系），harness 拿到的是最小委托身份
   而非 worker 身份（沙箱文档 §5-9）；出口白名单默认拒绝、逐项放行、可审计。

8. **版本漂移**。两 SDK 都 track 各自 CLI release，API 可能动（codex `api-reference.md:51` 已有 snake_case 迁移注）。
   **缓解**：编排工具/harness 调用 schema 进**契约锁**纪律（如现有 `contracts/knowledge-retrieval-provider-lock.json`），
   两 SDK 版本 + 两 runtime 二进制 digest 一起钉死。

9. **可观测债**。supervisor 每次路由/分发若无事件落库，出问题无法区分"路由错"还是"harness 执行错"。
   **缓解**：路由决策、harness 启动/完成/审批/取消、usage→budget 消耗**全落 DomainEvent**（现有 event_sink 底座），
   一个 run 能在 timeline 完整回放（既有 §2 第 9 条验收）。

10. **"通用 agent = codex" 的语义契合（需用户澄清）**。codex 是编码优化的 agent。若 investment"通用任务"=
    编码/仓库/自动化，codex 契合；若=研究/问答/分析，codex 能做（web/MCP）但非最优，且要为它单开 OpenAI 出口 +
    认证 + 成本。**缓解/决策点**：明确"通用任务"边界；若主要是研究问答，评估是否"通用"也走 dsh（单一 DeepSeek
    provider，省一个出口与一套认证），codex 只留给真正需要编码/强推理的场景。

---

## 8. 财务专业 agent 的构建路径（dsh bundle/preset + Wren）

**专业 agent = dsh 域 bundle + preset 组合**（不是写一个新 harness）：
- **bundle**（`packages/bundle/README.md`："Domain packages can declare additional layers outside this directory"）：
  一个 out-of-tree 财务 bundle，声明 `dsh.bundle.patch`，贡献——Wren 六工具（`wren_query`/`wren_dry_plan`/
  `wren_list_models`/`wren_fetch_context`/`wren_recall_queries`/`wren_store_query`，wrenai 文档 §1.1）、财务
  system-prompt/skill、术语库检索（sqlbot 借鉴 §5-1）。经 `dsh plugin --profile fin add file:/path/to/fin-bundle`
  装进 `fin` profile。
- **preset**（`packages/preset/README.md`："one process run several differently composed agents at once"）：
  财务域三角色 **analyst（强模型分析）/ checker（中模型校验）/ awaiter（最便宜模型盯长 job）**（既有 D7），
  各一个 `agent.cordis.yml`，同一 dsh 进程内并存；`persona` 行改身份。
- **受约束工作流**：财务分析是正确性敏感域，用 dsh `workflow`/`plan`/`guard` 把"取数→dry_plan 校验→分析→
  checker 评审→产出"收敛成受约束流程（对应既有 L1 静态骨架 + Generator-Critic），**不做自由 ReAct**。
- **问数路线**：Wren 语义层受管 SQL（wrenai 文档决策，非 SQLBot prompt 链）；`dry_plan` 白捡 critic；
  数据/凭据治理——MDL 进镜像 digest 钉死、memory 索引挂 PVC、财务库只读最小凭据、**持仓交易账本是自产
  敏感数据单列**（agent-architecture §3.6-1）。

**这条路径与 Option A/B/C 都兼容**：财务 agent 的内部组合在 dsh 侧完成，in-house supervisor 只把它当一个
`financial_dsh` 执行档分发（Option A/C），或让 dsh supervisor 用 in-process preset 组合（Option B）。

---

## 9. 分阶段建设路径（P0–P5，闸门纪律）

> 沿用既有 P0.5 闸门纪律（`agent-architecture` §6）：**单 run 价值闭环成立才进编排**。双轨并行。

```text
P0-A  财务问数 spike：选财务数据源（L3 第一个必答）→ DuckDB/样例库 + Wren（langgraph 原语路线）
      → 20 金标准题准确率基线（eval 门禁先于架构投入，wrenai §2 之三）
P0-B  双 SDK 执行 spike（与 P0-A 并行，不依赖数据源）：
      - codex：python:3.12-slim 容器内 spawn app-server，API-key 登录，read_only 跑通一个 run，
        覆盖 approval_handler，output_schema 拿结构化结果，usage 读出
      - dsh：容器内 spawn dsh --profile sdk-minimal，DSH_HOME 隔离，跑通一个 run，验证无 interrupt 下的取消=kill
      - 验收：两个原生二进制都在 worker 镜像里启动成功 + 认证通过 + 沙箱行为明确（内部沙箱关/容器为界）
P0.5  闸门：单 run 价值闭环——一个真 codex run + 一个真 dsh financial run 各自穿过现有
      event_sink/timeline/HITL/SSE，能被统一回放；否则不进编排
P1    CodexHarnessAdapter（先行，codex 侧能力强：output_schema+interrupt+async）+ HarnessPort domain 定义
      （不改签名纪律）+ AgentProfileCatalog 扩 general_codex + usage→RunBudget 投影 + approval→HITL 路由
      退出：第一个真实通用任务在 Web 上完成并 timeline 可回放
P2    Supervisor 路由节点（constrained-dynamic enum，未命中落事件流）+ DeepSeekHarnessAdapter +
      财务 bundle/preset（analyst/checker/awaiter）+ Wren adapter + FakeWren 测试
      退出：第一个真实财务分析 run 完成；路由决策全落 DomainEvent
P3    统一结果契约（HarnessResult + 两投影器 + schema 化回读）+ RunBudget 全树账本（fan-out 共摊）+
      编排事件审计 + memory 存取 + 取消双路（codex interrupt / dsh kill）
P4    子进程池化 + 并发上限 + TTL 回收；dsh 压缩/awaiter 上线；SSE/ChartSpec 上 Web（sqlbot §5-3 g2-ssr 模式）
P5    压测（25 课 v5 方法学：并发/排队/背压）+ 生产加固 + 决策型 REQ 过审
      （新依赖/新资产/新数据源/新 provider 四条都命中 AGENTS.md 漂移尺子）
```

**Option 决策应在 P0 之前**：A/B/C 路线（§5）决定 P1/P2 的 adapter 形状与 supervisor 落点，先拍板再动工。

---

## 10. 架构变更合理性裁决：外包执行 vs 原自研执行层（回答"是否比原架构更好"）

> 先厘清"到底变了什么"，避免把"执行层换实现"误读成"整体推翻"。对照对象 = 既有
> `~/codex-reference-archive/qwen3.8/investment-app-agent-architecture-qwen3.8.md`（假定**自建 LangGraph 运行时 +
> 自研 Supervisor + Wren/DockerSandbox**）。

### 10.1 逐层对账：变的只有 L3

| 层 | 原自研架构 | 新架构（本文） | 变了吗 |
| --- | --- | --- | --- |
| L0 运行时 | LangGraph+PostgresSaver+celery+event_sink | 同 | **不变**（复用） |
| L1 领域骨架 | 财务工作流知识（自建，壁垒） | 移进 dsh bundle/preset（知识仍自建，换载体） | 载体变，**知识仍自建** |
| L2 路由层 | 自研 Supervisor（D1 第2档受约束） | supervisor 路由节点（D1 第2档） | **不变**（仍自研自控） |
| **L3 执行层** | **自建 LangGraph agent loop + DockerSandbox** | **外包给 codex/dsh harness 子进程** | **★ 变了：唯一的实质变更** |
| L4 质量层 | output_schema/dry_plan critic/HITL/评估 | 同 + harness 侧 gate | 不变（增量） |
| L5 治理层 | RunBudget/事件溯源/身份/契约锁 | 同 | **不变**（复用） |

### 10.2 对照原架构"必须自建的六样"（agent-architecture §5）：外包动摇了哪几样

| 必须自建六样 | 新架构下 |
| --- | --- |
| ① L1 领域骨架 | **仍自建**（移进 dsh bundle，harness 不替你写财务工作流知识） |
| ② 评估集 20 题 | **仍自建**（harness 不给金标准） |
| ③ MDL 语义建模 | **仍自建**（Wren MDL 与 harness 无关） |
| ④ 反馈采集 | **仍自建** |
| ⑤ HITL UX | **仍自建**（且要接 codex approval / dsh interaction） |
| ⑥ run 内压缩 | **★白捡**（codex `thread.compact()` / dsh profile compaction——原文"Codex 有完整机制，你目前为零"，外包反而补上短板） |

即：外包**只替代了"执行 loop 引擎 + 沙箱"、并白捡第⑥样压缩**；前五样壁垒**一样没少**。

### 10.3 裁决（Q1）

**方向合理，在"执行层"维度确实更好；但它是一次"用外部成熟度换内部控制力"的交易，净收益为正、
但正得有限，且完全取决于治理 gate 箍得好不好。**

- **更好的部分（执行层）**：自建 agent loop 是既有 §7.6 警告的"小号 Codex"高风险区（自由编排 loop
  极易滑向不可回放/不可回归）。外包给 codex/dsh = 拿到成熟的 loop/工具调用/压缩/code-mode/子进程管理，
  工程量骤降、能力天花板抬高。这与 OpenClaw 把 codex app-server 当 native runtime 委托是**同一个判断**（§11）。
- **代价的部分（治理）**：原自研执行层里，编排决策权**内生可控**（是你自己的 LangGraph 图，D1 第1/2档
  天然在手）。外包后 harness 内部 loop = 自由编排（D1 第3档生产禁用），决策权进了黑箱，治理从"内生"
  变"外挂四道箍"（§7-2）。**治理难度是上升的，不是下降的。**
- **不是"整体更好"，是"执行层实现选择更优"**：新架构不推翻原架构，而是给原架构的 L3 执行层换了一个
  更强的实现。原架构的分层/纪律/壁垒（一套地基两种形态、决策权三分法、P0.5 闸门、必须自建六样前五样）
  **全部继续成立**。
- **"更好"的边界条件**：只有当 supervisor+治理壳自研自控、执行外包给 harness 当 native runtime、且用
  确定性 gate 箍住黑箱时，才净更好（=Option C）。若把路由/治理也塞进 harness 黑箱（Option B 极端），
  则比自研更差——治理欠债从第一天开始。

---

## 11. OpenClaw gate 做法评估：借鉴什么、不转向什么、更好的建议（回答 Q2）

### 11.1 OpenClaw 是什么（一手核查 `~/repo/openclaw`，2026-09-02）

TypeScript/Node 的**单网关**个人/团队 AI 助手（"on your devices, in your chats"）。架构主张三句话：
**trusted gateway / untrusted execution / deterministic policy**（`why-openclaw.md`）。它自己把
**codex app-server、Copilot SDK、Claude Agent SDK 当 native runtime 委托**（`why-openclaw.md` 对比表
"Vendor harnesses" 行）——**它和我们是同一层的东西**（都是被委托 harness 的控制面），不是我们要转向的上位目标。

### 11.2 OpenClaw 的 gate/routing 真实做法（一手，带锚点）

1. **确定性 binding 路由，不是 LLM 意图分类**（`multi-agent.md`）："Inbound messages route to the right
   agent through **bindings**"——binding 把 channel account（一个 Slack workspace/一个 WhatsApp 号）映射到
   一个 agent。路由由**配置**决定，不由模型运行时判断；每 agent = 独立 workspace/agentDir/auth/session/model registry。
2. **Gateway 层 tool policy = 确定性拒绝，独立于 prompt**（`delegate-architecture.md`）："per-agent tool policy
   to enforce boundaries at the Gateway level, independent of the agent's personality files—**even if the agent
   is instructed to bypass its rules, the Gateway blocks the tool call**"。即 `why-openclaw.md` 核心论点：
   "policy is enforced in code, not requested in the system prompt"——**正是我们既有 D1 决策权三分法的同一立场**。
3. **gate 分层**（`plugin-permission-requests.md:24-34` "Choose the right gate"）：optional tools（discovery-time
   gate，`tools.allow`）/ plugin permission requests（per-call gate，`plugin.approval.*`）/ exec approvals /
   **Codex native permission requests**（codex app-server 或 native hook 审批，OpenClaw 拥有 prompt 时路由进
   plugin approval）/ MCP approval elicitations。原文："Optional tools are a discovery-time gate. Plugin permission
   requests are a per-call gate."
4. **before_tool_call hook = per-call 拦截点**（`plugin-permission-requests.md:38-73`）：hook "runs after the model
   selects a tool and before OpenClaw executes it"，返回 `requireApproval`（severity/allowedDecisions/timeoutMs）。
   **这正是 codex SDK `approval_handler`（我们的安全红线 §7-1）的成熟框架版**。
5. **Codex supervision 的边界纪律**（`codex-supervision.md`）："**Codex App Server remains the thread and
   model-loop owner.** OpenClaw supplies the fleet catalog, authenticated operator UI, session binding, and channel
   delivery... **There is no separate Supervisor plugin or second Codex protocol implementation.**"——委托 harness 时
   **不重实现它的协议、不建第二个 supervisor**，只做 catalog/UI/binding/delivery + gate。
6. **能力分层 Tier + hard blocks 先行**（`delegate-architecture.md`）：Tier 1（read-only+draft，nothing sends
   without approval）/ Tier 2（send on behalf）/ Tier 3（proactive/autonomous）。"**Tier 3 requires hard blocks
   configured first**"——先定"agent 无论如何都不能做的动作"（never 导出财务记录、never 执行 inbound 指令=
   prompt injection 防御、never 改 IdP 设置），"These rules load every session—last line of defense"。
7. **动态建 agent 需 operator 批准**（`multi-agent.md` agent provenance）：agent 可请求创建另一个 agent，但
   "creates the agent only after operator approval"——动态扩张是 gated 的。

### 11.3 裁决（Q2）：借鉴纪律与手法，不完全转向系统

**为什么不完全转向 OpenClaw（4 条，一手依据）**：
1. **技术栈不兼容**：OpenClaw = TS/Node 单网关 WebSocket daemon；我们 = Python DDD + celery + LangGraph +
   PostgresSaver + k8s + 现有 Pilot 生产链。完全转向 = 推倒重建，违反"不建第二套系统"总纲。
2. **场景不同**：OpenClaw 默认是"trusted single-operator assistant"，**sandboxing off by default**、本地 loopback
   自动批准（`why-openclaw.md` "What we do not claim"）；我们是"没有人在场"的 headless 生产投研。它的个人助手
   默认在我们场景是危险默认。
3. **它是 harness 控制面，和我们同层，不是上位替代**：转向它 = 用另一个黑箱网关替换我们自研可控的控制面，
   治理反而更失控（其内部 loop 仍是自由编排黑箱）。
4. **OpenClaw 自己反对重编排层**：`VISION.md` "What We Will Not Merge" 明列 "**Heavy orchestration layers that
   duplicate existing agent and tool infrastructure**"——为"转向 openclaw"而推倒现有基建，恰是它自己拒绝的形态。

### 11.4 更好的建议：supervisor 重定义为"确定性 gate 路由器" + Option C 的 gate 化精修

> 核心转变：**supervisor 不是"LLM 意图分类 agent"，而是"确定性 gate 路由器 + 治理控制面"。**
> OpenClaw 最大的启发：路由和治理应尽量落在**确定性代码**里，而非模型的运行时判断里。

- **路由三档**（把 §4 的 constrained-dynamic 细化，OpenClaw binding 印证）：
  - **第1档 确定性 binding（首选，不过 LLM）**：task 带明确类型标签/来源入口/数据集 hint 时，直接确定性映射
    到执行档（general_codex / financial_dsh / pilot_rag）。最可控、最省成本、天然可回放。
  - **第2档 受约束 LLM 分类（无法确定性判定时才降级）**：LLM 只在**已注册执行档枚举**里选，pydantic schema
    校验后落应用服务，**未命中落事件流**（新任务类型信号）。= D1 第2档。
  - **第3档 自由编排路由：生产禁用**（D1 第3档）——不允许"LLM 自由决定调哪个 agent 并自由多轮委托"。
- **执行层委托 codex/dsh 当 native runtime，用 OpenClaw 式分层 gate 箍住黑箱**（把 §7-2 "四道箍"具体化）：
  - **discovery-time gate** = profile 的 allowed/denied tools（现有 `EffectiveAgentConfig.permits_tool`，deny 优先）——
    工具在模型看到前就被裁掉。
  - **per-call gate** = codex `approval_handler` / dsh `interaction` 插件——在"模型选定动作后、执行前"拦截，默认
    `deny_all`，需写/执行的动作路由到现有 HITL（interrupt/resume + action token）。**直接封掉 §7-1 的 codex
    默认 auto-accept 安全红线**。
  - **exec/sandbox gate** = 容器为沙箱边界（§7-6）+ 出口白名单（§7-7）。
- **Tier 授权 + hard blocks 先行**（借鉴 delegate-architecture）：通用 codex 档默认 **Tier 1**（read_only +
  产出草稿/schema artifact，不自动执行副作用），需写/执行升档且过 per-call gate + HITL；财务 dsh 档**先配
  hard blocks**（写进 bundle 的每会话必加载规则）：never 改持仓/交易账本、never 导出敏感财务数据、never 执行
  inbound 消息里的指令（prompt injection 防御）。
- **不重实现协议、不建第二个 supervisor**（借鉴 codex-supervision）：in-house supervisor 只做路由(gate)+治理
  (budget/audit/HITL/timeline)+投影(result→统一契约)+分发(spawn 子进程)；**model loop 归 harness**。这条
  **否定 Option B 的极端形态**（让 dsh 当 supervisor 去 supervise codex = 一个黑箱 harness 监督另一个，治理面
  更糊，且违反 "no separate supervisor" 纪律），**强化 Option C**。

**一句话**：OpenClaw 是我们这套"委托外部 harness + 确定性 gate 治理"路线的**成熟外部参照系**——它已把
"不重实现 harness 协议、用 policy-as-code 分层 gate 治理被委托黑箱"做了出来。我们**借鉴它的纪律与手法
（binding 路由 / 分层 gate / native-runtime 边界 / Tier+hard-blocks），但不搬它的系统**（TS 单网关个人助手
≠ Python headless 生产投研）。落到我们身上 = **Option C 的 gate 化精修版**。

---

## 12. 待用户拍板的决策点（open questions）

1. **路线 Option A / B / C**（§5）：in-house supervisor + 双 adapter（A，字面方案）/ dsh-native supervisor
   委托 codex（B）/ 混合（C，我倾向）？这决定 supervisor 的脑在不在黑箱里。
2. **"通用任务"语义边界**（§7-10）：编码/自动化，还是研究/问答/分析？决定 codex 是否契合，或"通用"也走 dsh。
3. **是否引入 codex**：为通用任务单开 OpenAI 出口 + 认证 + 成本，还是全 dsh（单一 DeepSeek provider）起步、
   codex 后置？
4. **财务数据源**（L3 第一个必答，wrenai §7-1）：哪个库、谁入库、freshness？没有它连 P0-A spike 都无数据。
5. **治理黑箱容忍度**：harness 内部 loop 的动态性 vs D1 第 3 档生产禁用——外部四道箍（sandbox/approval/
   output_schema/budget）+ 财务域 dsh workflow/guard 收敛，是否够？还是要更细的工具级白名单？
6. **取消语义**：dsh 无 per-run interrupt（取消=杀进程重跑）是否可接受？awaiter 角色能否覆盖长 job 场景？
7. **REQ 立项范围**：决策型 REQ 覆盖到 P1 还是 P1+P2？（新依赖/新资产/新数据源/新 provider 四条漂移尺子）
8. **子进程并发上限与成本账**：worker pod 能承载多少并发原生子进程？RunBudget 全树账本的根预算定额？

---

## 13. 速查（锚点）

```text
# codex Python SDK（~/repo/codex）
sdk/python/src/openai_codex/client.py:194   CodexConfig（codex_bin/config_overrides/env/experimental_api）
sdk/python/src/openai_codex/client.py:246   spawn `codex app-server --listen stdio://`
sdk/python/src/openai_codex/client.py:773   _default_approval_handler 默认 accept（安全红线）
sdk/python/src/openai_codex/client.py:641   turn_interrupt / :648 turn_steer / :721 stream_text
sdk/python/src/openai_codex/_approval_mode.py:13  ApprovalMode = deny_all | auto_review
sdk/python/docs/api-reference.md:153,171    Thread.run(output_schema)→TurnResult(usage/items/final_response)
sdk/python/docs/api-reference.md:5,199      单实例并发多 turn；Sandbox read_only/workspace_write/full_access
codex-cli/bin/codex.js:18                   x86_64-unknown-linux-musl（musl 静态）
sdk/python-runtime/README.md:8              openai-codex-cli-bin（wheel-only）

# deepseek-harness Python SDK（~/repo/deepseek-harness）
python/sdk/src/deepseek_harness/api.py:13,49,124  DeepSeekHarnessConfig / DeepSeekHarness / run→RunResult
python/sdk/src/deepseek_harness/client.py:80,458  spawn dsh 子进程 / _default_launch_args(--profile/--patch)
python/sdk/README.md:5,13,15,37,66          subprocess JSON-RPC/stdio；profile 拥有一切；DSH_HOME 显式；bundle 安装；RunResult
python/sdk/src（grep interrupt|cancel|steer|abort）  零命中（无 per-run 中断）
python/sdk-runtime/platforms.json           linux-x64/arm64 = manylinux_2_28（glibc 2.28+）
python/sdk-runtime/README.md:5,11           单文件 Node SEA + rg sidecar，无需系统 Node
AGENTS.md:3,30,31,36,44,45,111              all-plugin Cordis；subagent/bundle/preset/acp/interaction；Plugins-not-loop
packages/subagent/README.md                 ctx.subagents：out-of-process = ACP / real Codex / Harness over SDK
packages/subagent/subagent-codex            one-shot unattended Codex delegation
packages/subagent/subagent-dsh-sdk          child Harness runtime over SDK
packages/subagent/tool-subagent-control     send_message / interrupt_agent / list_agents
packages/bundle/README.md                   dsh --profile patch layers；域包可声明额外层；dsh plugin add
packages/preset/README.md                   per-session 组合；一进程多 agent；agent.cordis.yml + persona

# investment-backend（~/worktrees/qwen3.8/investment-app/investment-backend）
app/app/domain/agent/profiles.py:14,36      AgentProfile / EffectiveAgentConfig.permits_tool（deny 优先）
app/app/domain/agent/runtime.py:34,62       RunStatus 状态机 / RunBudget 四维
app/app/domain/agent/commands.py:9,31       CreateRunCommand(agent_profile_key) / CancelRunCommand(休眠)
app/app/domain/agent/sandbox.py:39          SandboxPort（生产零调用，port/adapter 模板）
app/app/application/agent/profile_catalog.py  AgentProfileCatalog.resolve（路由表落点）
app/app/application/agent/run_service.py:25   create_run（幂等 + celery dispatch_agent_graph）
app/app/application/agent/pilot_service.py:34,111,160  create_run/resume(原子 token)/cancel
app/app/application/agent/graph_runtime_service.py:33  stream_with_config（graph.stream + __interrupt__）
app/app/tasks/pilot_agent_graph.py:79,110,174,207,269  _run_pilot_graph/build_pilot_graph/interrupt/resume/celery task
app/app/interfaces/endpoints/agent_routes.py:26,78,153   v4 流量门 / POST runs / SSE stream
app/app/interfaces/endpoints/pilot_runtime_routes.py:52,77,98  POST /runs / /commands / /events SSE
mybuild/Dockerfile:8,56 + build-image.sh:110  python:3.12-slim（glibc 2.36）
（grep supervisor|harness|codex|deepseek app/app）  零命中（集成 greenfield）

# 前端 task 入口
investment-web-frontend/app/components/research/research-workspace.tsx
investment-web-frontend/app/lib/interaction/{client.ts,use-run-projection.ts}
investment-admin-frontend/app/components/research/research-runtime-panel.tsx

# openclaw（~/repo/openclaw，参照系非目标；2026-09-02 亲验）
docs/start/why-openclaw.md                     trusted gateway/untrusted execution/deterministic policy；codex app-server 等=native runtime；policy in code not prompt
docs/plugins/plugin-permission-requests.md:24  "Choose the right gate"：optional tools(discovery)/plugin approval(per-call)/exec/codex native/MCP
docs/plugins/plugin-permission-requests.md:38  before_tool_call hook（选定工具后、执行前拦截）→requireApproval
docs/specs/codex-supervision.md                "Codex App Server remains model-loop owner"；"no separate Supervisor plugin or second Codex protocol implementation"
docs/concepts/multi-agent.md                   确定性 binding 路由（channel account→agent）；per-agent 隔离；动态建 agent 需 operator 批准
docs/concepts/delegate-architecture.md         Gateway tool policy 独立于 prompt（"even if instructed to bypass, Gateway blocks"）；Tier 1/2/3 + hard blocks 先行
docs/concepts/architecture.md                  req:agent→runId→event:agent streaming→final；幂等键；JSON Schema 校验（与 Pilot Run/SSE 同构）
VISION.md                                      "Heavy orchestration layers that duplicate existing agent/tool infra" ∈ Will Not Merge

# 既有产物（~/codex-reference-archive/qwen3.8/）
investment-app-agent-architecture-qwen3.8.md   总体设计纪律（一套地基两种形态/D1-D9/必须自建六样/P0.5）
codex-orchestration-assessment-qwen3.8.md      决策权三分法/没有人在场/回读攻击面
codex-deepdive-v2-qwen3.8.md                   trigger_turn/预算三件套/压缩/awaiter 角色/code-mode
sandbox-extension-advice-qwen3.8.md            SandboxPort 零改动/加固 6+4/容器为沙箱边界
wrenai-financial-analysis-integration-qwen3.8.md  Wren 六工具/语义层路线/MDL 治理/数据域
sqlbot-qwen3.8.md                              术语库借鉴/g2-ssr 出图/路线不切换
```
