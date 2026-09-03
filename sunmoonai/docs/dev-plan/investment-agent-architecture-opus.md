# investment-app Agent 架构可行性与 OpenClaw 借鉴（opus 版）

> 取证时点：2026-09-02 ｜ 作者：opus ｜ 合并整理：2026-09-03
>
> **性质：架构可行性分析（决策底稿），非 baseline、非 REQ。**转实施按治理规则走 REQ 流程。
>
> **论证对象（用户 2026-09-02 原话）**：investment-app 的 agent 部分按如下架构创建——
> 先建一个 Supervisor 接受前端 task 并路由：通用任务给通用 agent（经 SDK 分发给 Codex）；
> 专业任务（如财务分析）给专用 agent（经 SDK 分发给用 deepseek-harness 构建的财务等专业 agent）。
>
> **本文回答两问**：
> 1. 这条架构可行吗？从自研执行体系改成租用，合理吗？比原来更好吗？
> 2. `~/repo/openclaw` 的 Gateway 做法，路由与 Supervisor 该借鉴、完全转向，还是另有更好建议？
>
> **每条断言附取证命令或文件行号。**未运行进程、未连集群、未起模型调用，见 §16。
>
> 对象：`worktrees/opus/investment-app`、`worktrees/opus/k8s`（本机 HEAD）；
> 参照：`/home/zym/repo/codex`、`/home/zym/repo/deepseek-harness`、`/home/zym/repo/openclaw`。
>
> **合并说明**：本文由 2026-09-02 的三份 opus 稿合并
> （`agent-architecture-feasibility-opus.md` 514 行、`investment-agent-architecture-opus.md`
> 399 行、`agent-architecture-review-opus.md` 430 行），内容不改判，仅去重与统一编号。
> 一处例外：§4 ❷ 已于 2026-09-03 复核为不成立，原文保留并就地标注。

---

# 第一部分 · 架构可行性

## 1. 结论

**方向成立，形状要改，顺序要换。**

按原描述的形状（supervisor 路由 → 通用给 Codex / 专用给 dsh）直接开工，会在三个层次撞墙：

| 层次 | 判定 | 说明 |
| --- | --- | --- |
| **部署** | ❌ 五处硬阻断，现在一行都跑不通 | 出网被 NetworkPolicy 全禁、镜像无 Node（**已复核不成立**）、根文件系统只读、内存 768Mi、无凭据通道 |
| **架构** | ⚠ 三处形状错误 | 按供应商分而不是按能力分；把「路由」做成 supervisor；两个后端能力不对等却打算同等对待 |
| **契约** | ⚠ 两本账缺失是 fan-out 的绝对前置 | 预算账引用数 0、证据账无载体、`agent_runs` 无父子列 |

**但底子比想象的好**：Profile 目录、状态机集中校验、幂等唯一约束、副作用账都已落 PG，
路由的挂载点（`agent_profile_key`）现成。**要补的是接线和一层 Port，不是重建。**

**而「自研 vs 租用」是个假二分。**真正的选择是**在哪一层自研**，而且有一个事实必须先摆正：

> **原来的「自研架构」从来没有被建出来。**
> `ToolExecutionPort` 生产层引用数是 **0**——不存在「模型调工具、看结果、再决定」的循环。

所以现在不是「放弃一个能跑的自研系统去租别人的」，而是「**第一件事先做哪个**」。

| | 判定 |
| --- | --- |
| 租用作为**补充**（多一种执行后端） | ✅ 更好，现在就该规划 |
| 租用作为**替代**（不自研执行层了） | ❌ 更差，会把产品契约架空 |
| 租用作为**第一步**（先接外部再补基础） | ❌ 顺序错，部署阻断全砸在这条路上 |

**一句话：租用是对的，但它必须是第二实现，不是新体系。**

## 2. 现状全景

### 2.1 两套并行栈

```text
                      ┌── /agent/*  (admin 面, 开关 false) ──────────────┐
前端 ─── 浏览器 ──────┤                                                  │
                      └── /web/v1/runs/*  (web 面) ─────────┐            │
其他服务 ── /internal/v1/investment/runs/* ────────────────┤            │
                                                            ▼            ▼
                                              ┌──────────────────┐  ┌──────────────────┐
                                    应用层     │  PilotService    │  │ AgentRunService  │
                                    仓储       │ PilotRepository  │  │ AgentRepository  │
                                    表         │ agent_pilot_*    │  │ agent_runs       │
                                                                     │ session_events   │
                                                                     │ tool_side_effects│
                                    Celery     │pilot_agent_graph │  │ agent_graph      │
                                    图         │ pilot_graph      │  │ walking_skeleton │
                                              └──────────────────┘  └──────────────────┘
                                                     生产在用            生产关闭
```

```bash
grep -n '@router' app/interfaces/endpoints/agent_routes.py            # /agent, require_investment_admin
grep -n 'prefix' app/interfaces/endpoints/pilot_runtime_routes.py     # /internal/v1/investment
grep -n 'prefix' app/interfaces/http/web/interactions.py              # /web/v1
grep -n 'AGENT_V4_TRAFFIC_ENABLED' k8s/.../deployment/bundle/00-prerequisites.yaml
#   AGENT_V4_TRAFFIC_ENABLED: 'false'
```

**符合 I1 的部分**：web 面与 internal 面共用 `PilotService`——这是正确的「接口分面」。
**违反的部分**：admin 面用的是另一个应用服务、另一套表——那不是分面，是第二套栈。

继续在旁边加 `codex_task.py` 与 `deepseek_task.py`，会变成四套状态与恢复路径。

### 2.2 已经做对、不要重做的六件事

| 项 | 现状 | 评价 |
| --- | --- | --- |
| Run 状态机集中校验 | `RUN_STATUS_TRANSITIONS` + `validate_run_status_transition()`，七态四终态 | 两个仓储都在行锁下调用，**比 Codex 更严** |
| 幂等建单 | `uq_agent_runs_session_idempotency`；Pilot 侧另有 owner+key 唯一约束 | 落库，不靠内存 |
| 副作用一次性 | `tool_side_effects` 以 `tool_call_id` 为主键 | 落 PG，跨进程有效 |
| 恢复令牌原子消费 | `pilot_repository.consume_resume`：`pg_advisory_xact_lock` + 幂等键 + 拒绝陈旧动作 | **真原子，全仓质量最高的一处** |
| 六件对外契约 | 建单 / 快照 / SSE / 动作 / 取消 / citation 溯源 | 已在 Pilot 上端到端跑通 |
| 人工审批 | `pilot_graph` 的 `interrupt()` + `WAITING` + resume | **已有可用实现** |

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
| `ToolExecutionPort` | ✅ | **0** | **没有工具循环** |
| `SandboxPort`（含 shell/python） | ✅ | **0** | 设计意图含执行代码，现状零实现 |
| `CancelRunCommand` | ✅ | **0** | Pilot 的取消是另写的，没走领域命令 |
| `AgentMemoryService` | ✅ | 1 | 不在两条主链上 |
| `AgentProfile` | ✅ | 2 | 只在关着的那套栈里 |

**最关键的一条**：`ToolExecutionPort` 引用为 0，意味着目前不存在「模型调工具、看结果、
再决定」的循环。Pilot 是固定三步直线图。**这不是 agent，是一次带审批的问答。**

## 3. 原方案里已经对的部分

**分通用与专用，符合 A1**（新增业务智能体优先是新增一份 Profile，不是 fork 一套代码）——
直觉与已立规则一致，但 A1 的后半句被违反了，见 §5.1。

**租 SDK 不自建，符合 A4**（依赖边界严格限定在 SDK，不得直接依赖裸协议）。两边都有官方
Python SDK，不需要自己实现协议。**这是这个方案最大的可行性支撑。**

```bash
ls /home/zym/repo/codex/sdk/python/src/openai_codex/          # api.py async_client.py client.py …
ls /home/zym/repo/deepseek-harness/python/sdk/src/deepseek_harness/
```

**路由的挂载点已经存在**：`create_run` 已接收 `agent_profile_key`，经
`AgentProfileCatalog.resolve()` 解析成 `EffectiveAgentConfig`。

```
app/application/agent/run_service.py:27      effective_config = self.profile_catalog.resolve(...)
app/application/agent/profile_catalog.py:44  build_builtin_profile_catalog()
```

现有两份 Profile：`default_research`、`literature_review`。
**「财务分析 agent」应该是第三份 Profile，不是第三套代码。**

## 4. 部署层：五处硬阻断

每一条都会让方案**在集群里根本起不来**，与架构好坏无关。

### ❶ worker 没有出公网权限（最硬的一条）

`investment-default-deny` + 逐条 allowlist。worker 的 egress **只有**：

| 允许的目的地 | 端口 |
| --- | --- |
| data-platform（PG / Redis / AMQP） | 5432 / 6379 / 5672 |
| app-platform-dev 内的 provider Pod | 8000 |
| kube-system DNS | 53 |

```bash
grep -n 'ipBlock' k8s/sunmoonai/app-platform/investment-app/deployment/bundle/30-network-policies.yaml
# 无输出
```

**没有任何 `ipBlock`。**Codex 要连 `api.openai.com`，dsh 要连 `api.deepseek.com`，两个都连不出去。

**先例存在**：`info-app` 的 worker 有 `ipBlock: 0.0.0.0/0` port 443。

```bash
grep -n 'ipBlock' -A4 k8s/sunmoonai/app-platform/info-app/deployment/bundle/30-network-policies.yaml
```

**但不能照抄。**info-app 那个 pod 跑确定的抓取逻辑；投资 worker 里要跑**模型决定要访问
什么**的 agent。给它 `0.0.0.0/0:443` 等于把出网决定权交给模型。

| 做法 | 成本 | 风险 |
| --- | --- | --- |
| 照抄 `0.0.0.0/0:443` | 最低 | 模型可任意外联，数据外泄面 = 整个互联网 |
| 只放模型厂商 IP 段 | 中（IP 会变，要维护） | 收敛到厂商，但仍是明文出口 |
| 走集群内正向代理，只允许代理出网 | 高（要建代理） | 可审计、可限流、可记录每一次外联 |

**这是拍板项一。**

### ❷ 运行镜像里没有 Node.js —— **此条已复核不成立（2026-09-03）**

原判断：`nodejs` 只装在 type-check 阶段，最终 runtime 阶段是干净的 `python:3.12-slim`，
故 dsh 装不进去。

```bash
grep -n 'nodejs' investment-app/investment-backend/mybuild/Dockerfile   # 只在 type-check stage
tail -20 investment-app/investment-backend/app/Dockerfile               # runtime 阶段无 node
```

**复核结论：镜像事实为真，推论不成立。**该推论隐含前提「dsh 依赖系统 Node」，未经验证。
`~/repo/deepseek-harness/python/sdk-runtime/README.md` 原文：*It packages the normal `dsh`
CLI and its closed Node dependency tree into a native executable, so **SDK use requires no
system Node.js***；`platforms.json` 已发布 `linux-x64 → manylinux_2_28_x86_64` 与
`linux-arm64 → manylinux_2_28_aarch64`。仓库另有需系统 Node 22.19+ 的 `runtime/node/`
carrier，但 README 明写 *never selected automatically and excluded from wheels and sdists*。

**仍未验证**：该 wheel 能否从内网 PyPI 镜像装到。这是供应链问题，不是运行时缺失问题。

（`openai-codex-cli-bin` 是 musl 静态 Rust 二进制，本就不需要 Node。）

### ❸ `readOnlyRootFilesystem: true`

```
k8s/.../bundle/20-runtime.yaml:363   readOnlyRootFilesystem: true
```

两个 SDK 都要求可写 home：dsh 的 `DSH_HOME` 必须显式给出且 SDK 刻意不读 `~/.dsh`；
Codex 的 `CODEX_HOME` 存 thread 持久化。必须挂 `emptyDir` 并把 home 指过去。
**注意 `emptyDir` 随 Pod 消失**——Codex 的 `thread_resume` / dsh 的 session 续接在 Pod
重启后失效，见 §6.4。

### ❹ 内存上限 768Mi

```
resources: requests{cpu:100m, memory:192Mi}  limits{cpu:'1', memory:768Mi}
```

同一容器要塞下 Celery worker（Python）+ LangGraph + 一个 Node dsh runtime 或一个 Codex 进程。
`--concurrency > 1` 时是每个并发任务一个子进程。**未实测，但 768Mi 几乎确定不够。**
这直接影响拓扑选择，见 §6.3。

### ❺ 没有模型凭据的下发通道

`AGENT_PILOT_LLM_BASE_URL` / `_API_KEY` 代码里有字段，**部署 bundle 里根本没配**。

```bash
grep -n 'AGENT_PILOT_LLM' k8s/sunmoonai/app-platform/investment-app/deployment/bundle/*.yaml
# 无输出
```

**现在集群里连 Pilot 的 LLM 都没接。**需新建 Secret + envFrom，遵守 I3 与 D9。

## 5. 架构层：三处形状问题

### 5.1 「通用给 Codex / 专用给 dsh」是按**供应商**分，不是按**能力**分

**这是最重要的一条。**

这个分法把「专用」绑死在 dsh 上。结果是：加一个财务 agent 就得走 dsh 那条路径，
加一个通用 agent 就得走 Codex 那条路径。两条路径各有一套装配、一套错误处理、
一套证据落库——**这正是 A1 说的「fork 一套代码」**。

它经不起一个简单的追问：**如果财务分析 agent 用 Codex 效果更好呢？**
按原分法，换后端要改路由代码；按下面的分法，改一行 Profile 配置。

**正确的分法是两个正交维度**：

```text
维度一：Profile（领域）       default_research · literature_review · financial_analysis · …
维度二：Backend（执行运行时）  codex · dsh · in-process-langgraph
```

**Profile 声明它要哪个 backend，路由只认 Profile。**backend 是可替换的实现细节。

```python
class AgentProfile(BaseModel):
    key: str
    version: int
    # 已有
    system_prompt_id: str
    model_key: str
    allowed_tools: set[str]
    denied_tools: set[str]
    memory_policy: MemoryPolicyConfig
    ragflow_binding_key: str | None
    # 新增
    backend_key: str                 # "codex" | "dsh" | "langgraph"
    backend_options: dict[str, str]  # 后端私有参数，不含领域概念（A5）
```

这样「财务分析 agent」就是 A1 说的**新增一份 Profile**，不是新增一条执行路径。

### 5.2 「路由」不需要 supervisor

原描述里的 supervisor 把两件事混在了一起：

| 原描述 | 实际是什么 | 该放哪 |
| --- | --- | --- |
| 接前端 task | 受理建单 | 已有：`create_run` |
| **判断通用还是专业，选 agent** | **Profile 选择** | `VALIDATING` 阶段的一次分类，**不是一个 Task** |
| （没说但迟早要）拆成多个并行子任务 | **编排** | 这才是 `COORDINATION` Task |

产品契约 `request-lifecycle.md` 对此有明确规定，而且**明确禁止**做成常驻管家：

> §8：**协调 Task 不等待被协调 Task 全部完成。**图建立并验收后即 `SUCCEEDED`……
> 避免一个永不结束的「总管 Task」成为中央计划。

所以：

- **路由**是 `VALIDATING` 阶段的一个纯函数 `(user_input, context) → profile_key`。
  规则优先，模型兜底。**它不产生 Task，不占状态机。**
- **编排**（一个任务拆成多个）才建 `COORDINATION` Task，且建完图就结束。
- **等待子结果**发生在依赖它的业务 Task 里：`WAITING(DEPENDENCY)`。

第一版若把 supervisor 做成常驻的、等所有子任务的 Task，会同时违反 §8 和 §10 反模式，
而且它会变成整个系统的单点。

### 5.3 两个后端能力**不对等**，不能同等对待

| 能力 | Codex SDK | dsh SDK（`sdk` profile） | 对我们意味着 |
| --- | :-: | :-: | --- |
| 异步客户端 | ✅ `AsyncCodex` | ❌ 纯同步 | dsh 必须丢进线程池 |
| 会话续接 | ✅ `thread_resume(id)` | ✅ 同 `session_id` | 都可以 |
| 列出可续接会话 | ✅ `thread_list()` | ❌ | — |
| 分叉 | ✅ `thread_fork()` | ❌ | — |
| **中断运行中的任务** | ✅ `TurnHandle.interrupt()` | ❌ **无** | **dsh 只能杀进程** |
| **运行中追加指令** | ✅ `steer()` | ❌ | — |
| **工具审批回调** | ✅ `approval_handler` | ❌ **无** | **dsh 无法实现 `WAITING(APPROVAL)`** |
| 流式 | ✅ `stream()` 按 turn 路由 | ✅ `on_notification` | 都可以 |
| 单实例并发多任务 | ✅ 明确支持 | ⚠ 未声明 | dsh 需一任务一进程 |
| 结构化输出 | ✅ `output_schema` | ⚠ 未见 | — |

```bash
sed -n '200,235p' /home/zym/repo/codex/sdk/python/docs/api-reference.md    # interrupt/steer/stream
grep -n 'approval_handler' /home/zym/repo/codex/sdk/python/src/openai_codex/client.py
sed -n '113,120p' /home/zym/repo/deepseek-harness/packages/sdk/protocol/src/types.ts
#   'initialize' | 'session/prompt' | 'shutdown'   —— 只有三个方法
grep -rn 'cancel\|interrupt' /home/zym/repo/deepseek-harness/python/sdk/src/   # 无输出
```

**这不是小差别。**产品契约要求 `RUNNING → CANCELLED`（§4.1 合法转换）、
`WAITING(APPROVAL)`（§4.2 等待原因码）、I14（worker 失去租约后不能提交结果）。
**dsh 的 `sdk` profile 三条都做不到。**

**有一个出口**：dsh 的 **`acp` profile** 支持 create/resume/list、prompt 或 cancel、
权限决策（`session/requestPermission`）。

```bash
head -14 /home/zym/repo/deepseek-harness/packages/acp/acp/README.md
grep -n 'requestPermission' /home/zym/repo/deepseek-harness/packages/acp/acp/src/index.ts
```

**但 dsh 没有 Python ACP 客户端**（它自己的客户端 `dsh-subagent-acp` 是 TypeScript）。
自己写 ACP 客户端 = 直接依赖裸协议 = **违反 A4**。**这是拍板项二。**

正确的工程做法是照抄 dsh 自己的解法——**能力声明 + 失败要响**：

> `SubagentCapabilities` ……a request that needs a capability the chosen provider lacks
> is rejected with a typed error rather than accepted-then-ignored
> （"fail loud, no silent degradation"）

`AgentBackendPort` 必须带能力位。Profile 要求了后端没有的能力，**在 `VALIDATING` 阶段
就拒绝**，不要跑到一半才发现取消不了。

## 6. 修改后的架构

### 6.1 五层

```text
┌─ ① 受理 ────────────────────────────────────────────────────┐
│  身份 → 幂等 → 建单 → RECEIVED                              │
│  载体：一个 RunService（收敛后），一套表                     │
└──────────────────────────────────────────────────────────────┘
                          ▼
┌─ ② 解释与路由 (VALIDATING) ─────────────────────────────────┐
│  纯函数：(input, context) → profile_key                     │
│  规则优先，模型兜底。不建 Task、不占状态机                   │
│  ← 这就是原描述里的 "supervisor"，它不是一个常驻实体          │
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

### 6.2 三条设计原则

**原则一：外部执行运行时不是真源。**产品契约 §6.2 写死了：

> 所有要求「进程被杀后仍正确」的事实必须由持久化与并发控制承担……
> **不能把这些事实仅保存在 worker 内存或外部执行 harness 中。**

Codex thread / dsh session **只能当缓存**：权威对话历史落我们自己的 `session_events`，
外部会话 id 只用于「还活着就续接，省 token」，**续接失败必须能从我们的事件流重建重跑**，
而不是报错。

**原则二：能力缺失要在受理时拒绝，不能跑到一半失败。**Profile 要求 `approval` 而
`backend_key=dsh` 没有这个能力 → `VALIDATING` 阶段 `REJECTED`。

**原则三：领域概念不进 Port 签名（A5）。**`run(prompt, tools, limits)` 可以；
`run_financial_analysis(股票代码)` 不可以。否则每加一个专业 agent 就要动执行层。

### 6.3 Port 的形状与拓扑

```python
class AgentBackendPort(Protocol):
    @property
    def capabilities(self) -> BackendCapabilities: ...

    async def start(self, spec: RunSpec) -> BackendHandle: ...
    async def stream(self, handle: BackendHandle) -> AsyncIterator[BackendEvent]: ...
    async def cancel(self, handle: BackendHandle) -> None: ...        # 能力位为假时 raise
    async def resume(self, handle: BackendHandle, inp: UserInput) -> None: ...
```

`RunSpec` 里只有 prompt / model / tools / limits / workspace。

**拓扑：不要塞进现有 worker。**三个理由：内存（§4 ❹，现有 768Mi，agent 运行时是每任务
一个子进程）；出网（§4 ❶，只有跑 agent 的角色需要出网，开给现有 worker 等于把**所有**
Celery 任务放出去）；`T3` 允许「一个 Backend 代码库按运行角色部署」，**再加一个运行角色
是 T3 允许的，加一个新 App 不是**（T2）。

**建议**：同一代码库、新增运行角色 `agent-runtime`。

| | 现有 worker | 新增 agent-runtime |
| --- | --- | --- |
| 镜像 | 同一个 | 同一个（多装 SDK wheel） |
| 出网 | 保持全禁 | 单独一条 egress（§4 ❶ 三选一） |
| 内存 | 768Mi | 需实测，起步建议 2Gi |
| 根文件系统 | 只读 | 只读 + `emptyDir` 挂 `DSH_HOME` / `CODEX_HOME` |
| 队列 | 现有队列 | 独立 Celery 队列，避免抢占 |

这样三条阻断被限制在一个新角色里，不动现有部署面。

### 6.4 会话持久化的取舍

Codex thread 与 dsh session 都存在执行运行时自己的 home 里（`emptyDir`，Pod 消失即没）。
按原则一，**外部 harness 的会话 id 只能当优化，不能当真源**：权威对话历史落
`session_events`；`codex_thread_id` / `dsh_session_id` 存进 `agent_runs` 的新列，仅用于
省 token；续接失败从我们自己的事件流重建 prompt 重跑。

## 7. 契约层：三个必须先补的缺口

### 7.1 预算账（A3 / I10）—— fan-out 的绝对前置

`RunBudget` 定义了四维限额，**两条生产链引用数为 0**（§2.3 已取证）。

> I10：预算覆盖 Task 的全部 Attempt、子 Task 和工具调用——防「**fan-out 放大无限额**」

**接外部 agent 会让这条从「隐患」变成「必然事故」**：Codex / dsh 自己会循环调工具、
自己会派 subagent，一个 run 烧掉多少 token 我们**当前完全不可见、不可控**。

必须落库（不能只在内存对象里），且要区分：**本任务预算耗尽** → `budget_exceeded`
（可追加预算）；**厂商配额耗尽** → 另一个码（等配额，追加预算没用）。

### 7.2 `agent_runs` 没有父子列

`RunLineage` 领域模型有 `root_run_id` / `parent_run_id`，**但表里没有这两列**：

```bash
grep -n 'agent_runs' -A20 app/alembic/versions/20260708_0001_agent_phase0.py
# 列：id session_id graph_name graph_version agent_profile_key agent_profile_version
#     thread_id idempotency_key status resume_token error started_at completed_at …
# 没有 parent_run_id / root_run_id
```

血缘只活在 `session_events.lineage` 的 JSONB 里，**不可索引查询**。产品契约 §8 要求
「父 Task 汇总结果时保留来源和子 Task 血缘」——现在做不到。一次迁移解决：加两列 + 索引 + 外键。

### 7.3 证据账（I11）无载体

> I11：结论和数值按 Profile 关联**来源、时点、转换与执行者**

接外部 agent 后这条更要命：**同一个 prompt，Codex 的 `gpt-5.4` 和 dsh 的 `deepseek-v4`
会给出不同结论。**不记执行者标识（后端 + 模型 + 版本 + 时点），两个月后无从归因——
**对投资研究结论不可接受。**

### 7.4 顺带确认：租约不是 fencing

现有 `RedisSessionLock` 会在图执行前后 `renew()`，失败即抛错——比「完全没有」好，
但**写库语句本身不带令牌条件**：

```
app/tasks/agent_graph.py:107   if not await lock.renew(lock_token): raise
app/tasks/agent_graph.py:129   if not await lock.renew(lock_token): raise
```

I14（失去租约后不能提交结果）在 renew 与写入之间仍有窗口。外部 agent 的执行时间比现在
长得多，这个窗口会被放大。

## 8. 落地顺序

每步独立可验收，后一步依赖前一步。**前五步不引入任何外部依赖。**

```text
─── 第一阶段：收敛与接线（不碰外部 agent）────────────────────
1. 预算账落 PG + 接进现有链                  ← 一切并行工作的前置（A3/I10）
2. agent_runs 加 parent_run_id/root_run_id 列 + 索引
3. Attempt 实体（执行者/后端/模型/版本/租约/消耗/失败码）
4. 证据账：结论绑 backend+model+version+时点  （I11）
5. 两套栈收敛：v4 的骨 + Pilot 的皮 + Pilot 的锁
   验收：/web/v1 六个端点行为一字不变，AGENT_V4 开关可拆

─── 第二阶段：抽象与自建执行 ────────────────────────────────
6. AgentBackendPort + BackendCapabilities
   先只落 LangGraphBackend（包住现有链）      ← 纯重构，零外部依赖
7. Profile 加 backend_key/backend_options/budget
8. 路线 A：在 LangGraph 里实现真正的工具循环   ← 第一个「真 agent」
   验收：ToolExecutionPort 引用数从 0 变正，预算能拦住失控循环

─── 第三阶段：部署与外部后端 ────────────────────────────────
9.  新增 agent-runtime 运行角色（独立队列/egress/emptyDir/内存）
10. 模型凭据 Secret + envFrom（路线 A 也需要，可提前到第 8 步）
11. CodexBackend（阻断最少）
12. DshBackend（能力位 cancel=False, approval=False，受理时拒绝）

─── 第四阶段：编排 ──────────────────────────────────────────
13. financial_analysis Profile（一份配置，零执行路径代码）
14. COORDINATION Task —— 只有真出现「拆并行子任务」时才做
```

**第 8 步是分水岭**：在它之前，investment-app 没有 agent；在它之后，有一个我们完全掌控、
完全落账的 agent。**外部后端（11/12）是在这个基础上「再租几个执行器」，不是从零起步。**

三条执行路线的顺序是 **A → B(Codex) → C(dsh)**：A 是兜底，不依赖任何外部进程、不需要
出网、不受部署阻断影响；B 的阻断最少（无需 Node、有 `interrupt()`/`approval_handler`/
异步客户端）；C 的阻断最多。**注意这与「专用给 dsh」的直觉相反**——dsh 听起来承担核心的
「专业 agent」，但它恰恰是三条里工程阻力最大的一条。

## 9. 需要拍板的五件事

| # | 问题 | 建议 |
| --- | --- | --- |
| 1 | 两套栈收敛，还是并存？ | **收敛**。并存的代价是四份实现漂移 |
| 2 | 第 8 步自建工具循环，值不值？ | **值**。它是唯一不受部署阻断影响的路径，且是外部后端的兜底 |
| 3 | 出网怎么开？ | 开发用 `0.0.0.0/0:443`，**生产走集群内正向代理**——写进部署计划，别等出事再补 |
| 4 | dsh 走 SDK 还是自写 ACP 客户端？ | **先走 SDK**，能力位如实声明 `cancel=False`。A4 是硬规则，破例要有具体收益，不能靠假设 |
| 5 | 第一个专用 agent 是不是财务分析？ | 先确认它**不需要**执行代码 / 中途取消 / 人工审批 / 跨 Pod 续接。需要就换一个更简单的打头阵 |

---

# 第二部分 · 改成租外部运行时，更好吗

## 10. 为什么「作为替代」更差：四条

### 10.1 最难的部分逃不掉，租了也得自己做

`constraints.md` A3：四本账必须落 PostgreSQL。产品契约 §6.2 说得更死（原文见 §6.2）。

Codex 的 thread 状态在它的 `CODEX_HOME`，dsh 的 session 在它的 `DSH_HOME`。
**租了以后，还是得把它们的事件流翻译成我们的四本账。**

也就是说：**租用省掉的是「工具循环」，省不掉「记账」**。而记账是难的那一半——幂等、
副作用一次性、租约、fencing、预算扣减，全在这一半。

**推论**：如果记账无论如何要自研，那么「顺手把工具循环也自研」的**边际成本远低于**
「再养一条把外部事件流翻译成本地账」的管道。（此推论**未量化**，见 §16。）

### 10.2 能力下限被最弱的那个后端锁死

| 能力 | 自研（LangGraph） | Codex SDK | dsh SDK |
| --- | :-: | :-: | :-: |
| 中途取消 | ✅ 已有（Pilot 的 cancel） | ✅ `interrupt()` | ❌ **无** |
| 人工审批 | ✅ 已有（`interrupt()`+`WAITING`） | ✅ `approval_handler` | ❌ **无** |
| 异步 | ✅ | ✅ `AsyncCodex` | ❌ 纯同步 |

产品契约 §4.1 要求 `RUNNING → CANCELLED` 合法，§4.2 要求 `WAITING(APPROVAL)`。
**如果只租 dsh，这两条对那条路径直接不可实现。**

而自研那条路上，这两件事**我们已经有了**——Pilot 链的 `interrupt()` + `WAITING` +
原子 resume 是全仓质量最高的一处实现。**放弃自研 = 把已有的能力扔掉。**

### 10.3 产品契约会被供应商节奏绑架

`request-lifecycle.md` 是**我们的**契约：九态状态机、五种等待原因码、十五条不变量。
如果唯一的执行路径是别人的进程：想加一个等待原因码 → 看它的协议支不支持；想改 fencing
语义 → 它的 SDK 没有这个概念；它发一个 breaking change → 我们的产品跟着停。

```bash
grep -n 'COMPATIBILITY-BREAKING' /home/zym/repo/deepseek-harness/README.md
#   DeepSeek Harness is in _developer preview_ … THERE WILL BE COMPATIBILITY-BREAKING CHANGES.
```

**dsh 自己声明是 developer preview。**把产品的唯一执行路径压在一个 preview 上，
不是架构选择，是风险选择。

### 10.4 部署阻断全部只砸在租用这条路上

五处阻断（§4）里，**自研路线一条都不占**——自研工具循环跑在现有 worker 里，用现有 LLM
端点，不需要子进程、不需要可写 home。

## 11. 但「作为补充」确实更好：三条

1. **有一类工作我们不该自研。**Codex 在「改代码、跑测试、看输出、再改」上做了很多年。
   我们要做的是投资研究，不是重做一个编码 agent。
2. **沙箱、压缩、重试是无差别工作。**`SandboxPort` 真做起来是一整个子系统。
   Codex 有三档沙箱，dsh 有完整的 sandbox/approval 层。**没有领域差异的东西，租比自研划算。**
3. **多后端本身就是一种抗风险。**单一后端（无论自研还是租用）都是单点。能在 Profile 里
   换后端本身就是价值。

## 12. 第三方证据：OpenClaw 两个都做

这不是推理，是一个成熟系统的实际选择。OpenClaw 明确**自己拥有内置运行时**：

> OpenClaw owns the built-in agent runtime. Runtime code lives under `src/agents/`……
> **no external agent framework packages remain.**

**同时**注册外部 harness：

> The built-in runtime id is `openclaw`……**Plugin harnesses register additional runtime
> ids (for example `codex`)**。`auto` selects a registered plugin harness that supports
> the effective provider route, **otherwise the built-in OpenClaw runtime**.

```bash
head -30 /home/zym/repo/openclaw/docs/agent-runtime-architecture.md
ls /home/zym/repo/openclaw/src/agents/harness/    # registry/selection/policy/availability…
```

**注意最后半句**：外部 harness 不支持时，**回落到自建运行时**。自建的那个是**默认值兼
兜底**，外部的是**可选加速器**。

## 13. 第二部分第一问的结论

```text
❌ 不是    自研 → 租用
✅ 而是    自研（Port + 四本账 + 契约 + 一个内置运行时）
           ＋ 租用（Codex / dsh 作为同一 Port 后面的可替换实现）
```

**顺序上，自建那个内置运行时必须先有**——它是默认、是兜底、是唯一不受五处部署阻断
影响的路径。这与 §8 的第 8 步（路线 A）一致。

---

# 第三部分 · OpenClaw 的门禁模型

## 14. 它到底做了什么

### 14.1 四道**正交**的门

| 门 | 管什么 |
| --- | --- |
| Sandbox | 在哪里跑（进程隔离、文件系统、网络） |
| Tool policy | 哪些工具**存在** |
| Permission mode | 会话的整体档位（read-only / 默认 / elevated / full） |
| Approval | 谁批准某一次具体动作 |

文档写的是「three related but different controls」加另一篇的 permission modes；
**把它数成四道是本文的归纳**，OpenClaw 自己没这么表述（见 §16）。

### 14.2 判定规则写得很硬

`deny` 优先；`allow` 非空即默认拒；**工具门是硬停，任何会话级开关不得越过**。

连同那句诚实话：**门禁按名字过滤，不检查 `exec` 内部的副作用——允许了 shell 就等于允许写。**

### 14.3 审批可以不是人

它的 reviewer 分档不要求每次批准都由人做。

### 14.4 路由是**确定性配置**，不是 LLM

它的三支柱之一就叫 `deterministic policy`。

### 14.5 能力探针 + 分级降级

harness registry + `availability` + `policy`：显式指定但不支持 → 拒绝且要响；
`auto` 选中但不支持 → 回落内置运行时。

### 14.6 可解释性：说得出该改哪个配置键

它的门禁决定能回答「为什么被拒」并指向具体配置项。

## 15. 借鉴还是转向

**借鉴，不转向。**它是一个个人/团队助手产品的控制面，我们是多租户服务端投资平台；
它的状态是 per-gateway SQLite，我们要 PG 主档；它自带 agent runtime，转向它等于在我们
与 harness 之间再塞一层。

### 15.1 该借鉴的五条（按性价比排序）

**① 门禁决定要可解释，并说出该改哪个键 —— 最值钱最便宜。**

一个 `GET /web/v1/runs/{id}/explain`，返回：

```json
{
  "tool": "web_fetch",
  "decision": "denied",
  "gate": "tool_policy",
  "rule": "profile.denied_tools",
  "source": "profile:financial_analysis@v3",
  "fix": "改 Profile 的 denied_tools，或换一个 Profile"
}
```

**建议在写门禁的同时做，不要事后补**——事后补要重新推导每条规则的来源。

**② 我们比 OpenClaw 该多做一步：门禁决定是一条事件，不是一行日志。**

OpenClaw 把门禁决定写进日志。**我们应该写进 `session_events`。**

理由是 I11（证据账）：结论必须绑来源、时点、转换、执行者。**「某个工具被挡了」是这条
证据链的一部分**——为什么这份分析没引用某个数据源？可能不是模型没想到，是工具被
Profile 禁了。日志里查不到，事件流里查得到。

```text
gate_decision { gate, rule_label, config_key, decision, subject, profile_version }
```

门禁本来就要写，多发一个事件几乎零成本。**这是我们能做得比 OpenClaw 好的地方。**

**③ 四道门正交拆开，别混进一个 `allowed_tools`。**

现状 `AgentProfile` 只有 `allowed_tools` / `denied_tools`。建议拆成：

```python
class AgentProfile(BaseModel):
    tool_policy: ToolPolicy          # 哪些工具存在（deny 优先；allow 非空即默认拒）
    execution_scope: ExecScope       # 在哪里跑（in-process / sandbox / 外部后端）
    approval_policy: ApprovalPolicy  # 谁审批
    # 不要 elevated —— 见 §15.2
```

并把三条判定规则**写进 `constraints.md`**，连同「允许了 shell 就等于允许写」那句诚实话。

**④ 审批分级：不是所有批准都必须是人。**

| 档 | 审批者 | 我们的用法 |
| --- | --- | --- |
| `none` | 无（直接拒绝该动作） | 只读研究 Profile |
| `auto-allowlist` | 白名单快路径 | 已知安全的检索类工具 |
| `llm-review` | **模型审查 + 人兜底** | 中风险；解决「人不能一直在线」 |
| `human` | 人 | 高风险、不可逆、对外副作用 |

**`llm-review` 那一档必须落账**（谁审的、哪个模型、什么时点），否则就成了自我批准。
契约里「agent 不得自我批准」约束的是**同一个 agent**，一个独立的审查模型 + 人兜底是
另一回事——**但必须留痕才成立**。

**⑤ 能力探针 + 分级降级。**

`AgentBackendPort` 的选择结果应该是带类型的决定，不是布尔：

```python
class BackendDecision(StrEnum):
    available            = "available"              # 直接用
    explicit_unsupported = "explicit_unsupported"   # 显式指定但不支持 → REJECTED，要响
    implicit_fallback    = "implicit_fallback"      # 自动选的不支持 → 回落内置，记事件
```

Profile 显式写了 `backend_key` → 能力不足就在 `VALIDATING` 拒；`backend_key = "auto"` →
回落到内置运行时，并**发一条事件说明为什么回落**。

**这条修正了 §5.3 写的「能力缺失一律受理时拒绝」**——那对显式指定是对的，对自动选择过严。

### 15.2 明确**不**借鉴的三条

| 不借鉴 | 理由 |
| --- | --- |
| **`elevated` 逃生门** | 它的前提是操作者 = 用户本人。我们是多租户浏览器用户，**任何会话内可达的提权面都是越权入口**。我们的「升级」只能走 Interaction 记录交给人，不能是一个会话开关 |
| **`full` 无限制模式** | 同上。而且「允许 exec 就等于允许写」意味着 `full` 实际上是无门禁 |
| **按 provider/model 分层的路由粒度** | 它有几十个模型提供方才需要 `tools.byProvider[p]` 这种粒度。我们现在一个 Profile 一个模型，**上来就做这个粒度是过度设计** |

### 15.3 路由用确定性，别用模型

这是对原方案最直接的一条修正。原设想是 supervisor **判断**任务是通用还是专业。
OpenClaw 的证据说明：**成熟系统在这一层不用模型。**

```text
1. 前端显式选择   用户自己选「财务分析」—— 最准，也最可解释
2. 规则匹配       关键词 / 来源渠道 / 入口页 → profile_key
3. 模型分类       只在 1、2 都没命中时兜底，且必须落事件记录判据
```

**理由不是「模型不准」，是三条别的**：

1. **路由错的代价不对称**：跑错 agent = 整条任务的结果都错，而且用户看不出为什么；
2. **不可解释**：确定性路由能回答「为什么是这个 agent」，模型分类只能回答「模型这么说的」；
3. **它自己也要预算**：一次分类调用也是模型调用，而**预算账现在引用数是 0**——在有预算
   闸门之前，多一处不受控的模型调用是净负债。

真到了 Profile 多到规则维护不动，再上模型分类。**那时它也应该是一个正常的 Task，
落账、可复核，而不是一个隐形的路由层。**

## 16. 边界

| 边界 | 说明 |
| --- | --- |
| 未运行进程 | 全部结论来自静态读码、迁移文件、部署清单与 `grep` 计数 |
| 未连集群 | 部署事实取自 `deployment/bundle/*.yaml`，未 `kubectl get` 核对实跑态 |
| 未实测内存 | §4 ❹「768Mi 不够」是推断，`agent-runtime` 的 limit **必须实测后再定** |
| 未验证 wheel 可装 | `deepseek-harness-runtime-bin` / `openai-codex-cli-bin` 能否从内网 PyPI 装到 linux/amd64 **未验证** |
| §4 ❷ 已推翻 | 「镜像无 Node 故 dsh 装不进」经 2026-09-03 复核不成立，原文与更正就地保留 |
| OpenClaw 只读了约 2% | 读了 `docs/agent-runtime-architecture.md`、`docs/gateway/sandbox-vs-tool-policy-vs-elevated.md`、`docs/gateway/permission-modes.md`、`docs/concepts/{architecture,multi-agent,delegate-architecture,parallel-specialist-lanes}.md`、`src/agents/harness/{policy,availability}.ts` 全文 + 目录清单。**未读**：`selection.ts`（1021 行）、`registry.ts`、沙箱实现、网关协议 |
| 未运行 OpenClaw | 未起进程、未跑 `sandbox explain`，行为描述全部来自文档与源码 |
| 「四道门正交」是本文归纳 | OpenClaw 自己没这么表述 |
| 未评估 OpenClaw 的许可与供应链 | MIT，但依赖树未审计 |
| §10.1 的「边际成本」论证未量化 | 「自研工具循环的边际成本低于翻译管道」是推断，**没有工时估算支撑** |
| 未与其他助手交叉 | 本文是单方判断，未看其他分支对同一问题的意见 |
