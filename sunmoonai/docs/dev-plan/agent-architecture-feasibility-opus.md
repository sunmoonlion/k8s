# supervisor + Codex + DeepSeek Harness：架构可行性分析

> 取证时点：2026-09-02 ｜ 作者：opus
> 取证对象：`/home/zym/repo/deepseek-harness`、`/home/zym/repo/codex`、
> `worktrees/opus/investment-app`、`worktrees/opus/k8s`（本机 worktree HEAD）
>
> **每条断言附取证命令或文件行号，可复跑。**未运行任何进程、未连集群、未起模型调用——
> 全部结论来自静态读码与清单比对，见 §9 边界。

## 1. 结论

**方向成立，形状要改。**

按你描述的形状（supervisor 路由 → 通用给 Codex / 专用给 dsh）直接开工，会在**三个层次**上撞墙：

| 层次 | 判定 | 说明 |
| --- | --- | --- |
| **部署** | ❌ **五处硬阻断，现在一行都跑不通** | 出网被 NetworkPolicy 全禁、运行镜像无 Node、根文件系统只读、内存 768Mi、无凭据通道 |
| **架构** | ⚠ **三处形状错误** | 按供应商分而不是按能力分；把"路由"做成 supervisor；两个后端能力不对等却打算同等对待 |
| **契约** | ⚠ **两本账缺失是 fan-out 的前置** | 预算账 0 引用、证据账无载体、`agent_runs` 无父子列 |

**但底子比想象的好**：Profile 目录、状态机集中校验、幂等唯一约束、副作用账都已落 PG，
路由的挂载点（`agent_profile_key`）现成。**要补的是接线和一层 Port，不是重建。**

## 2. 你的架构里已经对的部分

### 2.1 分通用与专用，符合 `constraints.md` A1

> A1：分**通用**（执行编排）与**专用**（领域），新增业务智能体优先是**新增一份 Profile**，
> 不是 fork 一套代码

你的直觉与已立的规则一致。**但 A1 的后半句你的方案违反了**，见 §4.1。

### 2.2 租 SDK 不自建，符合 A4

> A4：执行层**租用不自建**，依赖边界严格限定在 **SDK**，不得直接依赖裸协议

Codex 有 `openai-codex` Python SDK（同步 + 异步），dsh 有 `deepseek-harness-sdk` Python SDK。
两边都有官方 Python SDK，**不需要自己实现协议**。这是这个方案最大的可行性支撑。

```bash
ls /home/zym/repo/codex/sdk/python/src/openai_codex/          # api.py async_client.py client.py …
ls /home/zym/repo/deepseek-harness/python/sdk/src/deepseek_harness/
```

### 2.3 路由的挂载点已经存在

`create_run` 已经接收 `agent_profile_key`，并经 `AgentProfileCatalog.resolve()`
解析成 `EffectiveAgentConfig`（含 `model_key`、`allowed_tools`、`denied_tools`、
`memory_policy`、`ragflow_binding_key`）。

```
investment-backend/app/app/application/agent/run_service.py:27   effective_config = self.profile_catalog.resolve(...)
investment-backend/app/app/application/agent/profile_catalog.py:44 build_builtin_profile_catalog()
```

现有两份 Profile：`default_research`、`literature_review`。
**"财务分析 agent"应该是第三份 Profile，不是第三套代码。**

## 3. 部署层：五处硬阻断

这一节的每一条都会让方案**在集群里根本起不来**，与架构好坏无关。

### 3.1 ❌ worker 没有出公网权限（最硬的一条）

`investment-default-deny` + 逐条 allowlist。worker 的 egress **只有**：

| 允许的目的地 | 端口 |
| --- | --- |
| data-platform（PG / Redis / AMQP） | 5432 / 6379 / 5672 |
| app-platform-dev 内的 provider Pod | 8000 |
| kube-system DNS | 53 |

**没有任何 `ipBlock`。**Codex 要连 `api.openai.com`，dsh 要连 `api.deepseek.com`，
**两个都连不出去。**

```bash
grep -n 'ipBlock' k8s/sunmoonai/app-platform/investment-app/deployment/bundle/30-network-policies.yaml
# 无输出

grep -n 'backend-worker-egress' -A34 .../30-network-policies.yaml   # 只有上表三项
```

**先例存在**：`info-app` 的 worker 有 `ipBlock: 0.0.0.0/0` port 443。

```bash
grep -n 'ipBlock' -A4 k8s/sunmoonai/app-platform/info-app/deployment/bundle/30-network-policies.yaml
```

**但这不是照抄就行。**info-app 那个 pod 跑的是确定的抓取逻辑；投资 worker 里将要跑
**模型决定要访问什么**的 agent。给它 `0.0.0.0/0:443` 等于把出网决定权交给模型。
可选做法（成本递增）：

| 做法 | 成本 | 风险 |
| --- | --- | --- |
| 照抄 `0.0.0.0/0:443` | 最低 | 模型可任意外联，数据外泄面 = 整个互联网 |
| 只放模型厂商 IP 段 | 中（IP 会变，要维护） | 收敛到厂商，但仍是明文出口 |
| 走集群内正向代理，只允许代理出网 | 高（要建代理） | 可审计、可限流、可记录每一次外联 |

**这是需要你拍板的第一件事**，见 §8。

### 3.2 ❌ 运行镜像里没有 Node.js

`nodejs` 只装在 **type-check 阶段**，最终 runtime 阶段是干净的 `python:3.12-slim`。

```bash
grep -n 'nodejs' investment-app/investment-backend/mybuild/Dockerfile   # 只在 type-check stage
tail -20 investment-app/investment-backend/app/Dockerfile               # runtime 阶段无 node
```

- **dsh 需要 Node**：它是 Node 应用，Python SDK 靠 `deepseek-harness-runtime-bin` wheel
  把 `dsh` CLI 打进来。该 wheel 是**平台相关**的（`platforms.json`），
  需确认有 linux/amd64 且能从内网 PyPI 镜像装到——**未验证**。
- **Codex 不需要 Node**：`openai-codex-cli-bin` 是 Rust 二进制 wheel。
  这让 Codex 的接入成本明显低于 dsh。

```bash
cat /home/zym/repo/deepseek-harness/python/sdk-runtime/platforms.json
grep -n 'codex_cli_bin\|bundled_codex_path' /home/zym/repo/codex/sdk/python/src/openai_codex/client.py
```

### 3.3 ❌ `readOnlyRootFilesystem: true`

```
k8s/.../bundle/20-runtime.yaml:363   readOnlyRootFilesystem: true
```

两个 SDK **都要求可写 home**：

- dsh：`DSH_HOME` 必须显式给出，**且 SDK 刻意不读 `~/.dsh`**（profiles、plugins、session store 都写在里面）
- Codex：`CODEX_HOME` 存 thread 持久化

必须挂 `emptyDir` 并把 home 指过去。**注意**：`emptyDir` 随 Pod 消失——
Codex 的 `thread_resume` / dsh 的 session 续接**在 Pod 重启后失效**。
这与 I5（终态不可转出）和恢复语义有冲突，见 §5.4。

### 3.4 ❌ 内存上限 768Mi

```
resources: requests{cpu:100m, memory:192Mi}  limits{cpu:'1', memory:768Mi}
```

同一容器里要塞下：Celery worker（Python）+ LangGraph + **一个 Node dsh runtime**
或 **一个 Codex 进程**。`--concurrency` 大于 1 时是**每个并发任务一个子进程**。

**未实测**，但 768Mi 几乎确定不够。这直接影响拓扑选择：见 §5.3，我建议**不要**把
agent 运行时塞进现有 worker。

### 3.5 ❌ 没有模型凭据的下发通道

`AGENT_PILOT_LLM_BASE_URL` / `_API_KEY` 在代码里有字段，**但部署 bundle 里根本没配**。

```bash
grep -n 'AGENT_PILOT_LLM' k8s/sunmoonai/app-platform/investment-app/deployment/bundle/*.yaml
# 无输出
```

也就是说：**现在集群里连 Pilot 的 LLM 都没接**。需要新建 Secret + envFrom，
并且遵守 I3（浏览器 / 服务 / 数据库凭据禁止复用）与 D9。

## 4. 架构层：三处形状问题

### 4.1 ⚠ "通用给 Codex / 专用给 dsh" 是按**供应商**分，不是按**能力**分

这是最重要的一条。

你的分法把"专用"绑死在 dsh 上。结果是：**要加一个财务 agent，就得走 dsh 那条路径；
要加一个通用 agent，就得走 Codex 那条路径。**两条路径各有一套装配、一套错误处理、
一套证据落库——**这正是 A1 说的"fork 一套代码"**。

而且它经不起一个简单的追问：**如果财务分析 agent 用 Codex 效果更好呢？**
按你的分法，换后端要改路由代码；按下面的分法，改一行 Profile 配置。

**正确的分法是两个正交维度**：

```
维度一：Profile（领域）      default_research · literature_review · financial_analysis · …
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

这样"财务分析 agent"就是 A1 说的**新增一份 Profile**，而不是新增一条执行路径。

### 4.2 ⚠ "路由"不需要 supervisor

你说的 supervisor 做两件事被混在了一起：

| 你说的 | 实际是什么 | 该放哪 |
| --- | --- | --- |
| 接前端 task | 受理建单 | 已有：`create_run` |
| **判断通用还是专业，选 agent** | **Profile 选择** | `VALIDATING` 阶段的一次分类，**不是一个 Task** |
| （你没说但迟早要）把一个任务拆成多个并行子任务 | **编排** | 这才是 `COORDINATION` Task |

产品契约对此有明确规定，而且**明确禁止**把它做成常驻管家：

> §8：**协调 Task 不等待被协调 Task 全部完成。**图建立并验收后即 `SUCCEEDED`。
> ……避免一个永不结束的"总管 Task"成为中央计划。

所以：

- **路由**是 `VALIDATING` 阶段的一个纯函数：`(user_input, context) → profile_key`。
  它可以由一次小模型调用实现，也可以先用规则实现。**它不产生 Task，不占状态机。**
- **编排**（一个任务拆成多个）才建 `COORDINATION` Task，且建完图就结束。
- **等待子结果**发生在依赖它的业务 Task 里：`WAITING(DEPENDENCY)`。

**如果第一版把 supervisor 做成一个常驻的、等所有子任务的 Task，会同时违反 §8 和 §10 反模式，
而且它会变成整个系统的单点。**

### 4.3 ⚠ 两个后端能力**不对等**，不能同等对待

实测两个 SDK 的能力差距很大：

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
| 沙箱档位 | ✅ read_only / workspace_write / full_access | 由 profile 配 | — |

取证：

```bash
sed -n '200,235p' /home/zym/repo/codex/sdk/python/docs/api-reference.md    # interrupt/steer/stream
grep -n 'approval_handler' /home/zym/repo/codex/sdk/python/src/openai_codex/client.py

# dsh SDK 的 JSON-RPC 只有三个方法
sed -n '113,120p' /home/zym/repo/deepseek-harness/packages/sdk/protocol/src/types.ts
#   'initialize' | 'session/prompt' | 'shutdown'
grep -rn 'cancel\|interrupt' /home/zym/repo/deepseek-harness/python/sdk/src/   # 无输出
```

**这不是小差别。**产品契约要求：

- `RUNNING → CANCELLED`（§4.1 合法转换）
- `WAITING(APPROVAL)`（§4.2 等待原因码）
- I14：worker 失去租约后不能提交结果

**dsh 的 `sdk` profile 三条都做不到。**

**有一个出口**：dsh 的 **`acp` profile** 支持 create/resume/list、**prompt 或 cancel**、
**权限决策**（`session/requestPermission`）。

```bash
head -14 /home/zym/repo/deepseek-harness/packages/acp/acp/README.md
grep -n 'requestPermission' /home/zym/repo/deepseek-harness/packages/acp/acp/src/index.ts
```

**但 dsh 没有 Python ACP 客户端**（它自己的客户端 `dsh-subagent-acp` 是 TypeScript）。
自己写 ACP 客户端 = 直接依赖裸协议 = **违反 A4**。

**这是需要你拍板的第二件事**，见 §8。

正确的工程做法是照抄 dsh 自己的解法——**能力声明 + 失败要响**：

> `SubagentCapabilities` ……a request that needs a capability the chosen provider lacks
> is rejected with a typed error rather than accepted-then-ignored
> （"fail loud, no silent degradation"）

我们的 `AgentBackendPort` 也必须带能力位。Profile 要求了后端没有的能力，
**在 `VALIDATING` 阶段就拒绝**，不要跑到一半才发现取消不了。

## 5. 修改后的架构

### 5.1 分层

```
前端 Task
   │
   ▼
[ API: create_run ]                     受理建单、幂等、RECEIVED
   │
   ▼
[ 路由器 (VALIDATING) ]                 纯函数：input → profile_key
   │  规则优先，模型兜底；不建 Task、不占状态机           ← 这才是你说的 "supervisor"
   ▼
[ Profile 目录 ]                        profile → { prompt, model, tools, memory, backend_key }
   │
   ▼
[ AgentBackendPort ]                    ← 唯一的执行抽象（A5：签名里不出现领域概念）
   │      capabilities: {cancel, approval, resume, stream, structured_output}
   ├──── CodexBackend        (openai-codex SDK)
   ├──── DshBackend          (deepseek-harness-sdk)
   └──── LangGraphBackend    (现有 walking_skeleton / pilot_graph，不要删)
   │
   ▼
[ 四本账落 PG ]                          预算 · 幂等 · 副作用 · 证据（A3）
```

**关键点**：`financial_analysis` 是一份 Profile，它的 `backend_key` 可以是 `dsh`，
也可以某天改成 `codex`——**改配置，不改路由代码**。

### 5.2 Port 的形状（A5：领域概念不进签名）

```python
class AgentBackendPort(Protocol):
    @property
    def capabilities(self) -> BackendCapabilities: ...

    async def start(self, spec: RunSpec) -> BackendHandle: ...
    async def stream(self, handle: BackendHandle) -> AsyncIterator[BackendEvent]: ...
    async def cancel(self, handle: BackendHandle) -> None: ...        # 能力位为假时 raise
    async def resume(self, handle: BackendHandle, inp: UserInput) -> None: ...
```

`RunSpec` 里只有 prompt / model / tools / limits / workspace，
**不能出现 `持仓`、`财报` 这类领域词**（A5 原文：`run(sql, limit)` 可以，
`run_portfolio_query(持仓ID)` 不可以）。

### 5.3 拓扑：**不要塞进现有 worker**

三个理由：

1. 内存（§3.4）——现有 worker 768Mi，agent 运行时是**每任务一个子进程**；
2. 出网（§3.1）——只有跑 agent 的那个角色需要出网，把 `0.0.0.0/0:443`
   开给现有 worker，等于把**所有** Celery 任务都放出去了；
3. `T3` 说"一个 Backend 代码库按运行角色部署（API / Worker / Scheduler / Migration）"——
   **再加一个运行角色是 T3 允许的，加一个新 App 不是**（T2：每个领域 App 只有一个规范 Backend）。

**建议**：同一代码库、新增一个运行角色 `agent-runtime`：

| | 现有 worker | 新增 agent-runtime |
| --- | --- | --- |
| 镜像 | 同一个 | 同一个（多装 SDK wheel） |
| 出网 | 保持全禁 | 单独一条 egress（见 §3.1 三选一） |
| 内存 | 768Mi | 需实测，起步建议 2Gi |
| 根文件系统 | 只读 | 只读 + `emptyDir` 挂 `DSH_HOME` / `CODEX_HOME` |
| 队列 | 现有队列 | **独立 Celery 队列**，避免抢占 |

这样 §3.1 / §3.3 / §3.4 三条阻断被限制在一个新角色里，不动现有部署面。

### 5.4 会话持久化的取舍

Codex thread 与 dsh session 都存在**执行运行时自己的 home 里**（`emptyDir`，Pod 消失即没）。
产品契约 §6.2 明确：

> 所有要求"进程被杀后仍正确"的事实必须由持久化与并发控制承担……
> **不能把这些事实仅保存在 worker 内存或外部执行 harness 中。**

**所以：外部 harness 的会话 id 只能当作"优化"，不能当作真源。**

- 权威对话历史仍落我们自己的 `session_events`；
- `codex_thread_id` / `dsh_session_id` 存进 `agent_runs` 的新列，
  **仅用于"如果还活着就续接，省 token"**；
- 续接失败必须能**从我们自己的事件流重建 prompt 重跑**，而不是报错。

## 6. 契约层：三个必须先补的缺口

### 6.1 预算账（A3 / I10）—— **fan-out 的绝对前置**

`RunBudget` 定义了四维限额，**两条生产链引用数为 0**（今日复跑，与 8-28 的取证一致）：

```bash
cd investment-app/investment-backend/app
for s in RunBudget SandboxPort ToolExecutionPort CancelRunCommand; do
  echo "$s: $(grep -rln "$s" app/tasks/ app/application/ | wc -l)"
done      # 全为 0
```

> I10：预算覆盖 Task 的全部 Attempt、子 Task 和工具调用——防"**fan-out 放大无限额**"

**接外部 agent 会让这条从"隐患"变成"必然事故"**：Codex / dsh 自己会循环调工具、
自己会派 subagent，一个 run 烧掉多少 token 我们**当前完全不可见、不可控**。

必须落库（不能只在内存对象里），且要区分：
- **本任务预算耗尽** → `budget_exceeded`（可追加预算）
- **厂商配额耗尽** → 另一个码（等配额，追加预算没用）

### 6.2 `agent_runs` 没有父子列

`RunLineage` 领域模型有 `root_run_id` / `parent_run_id`，**但表里没有这两列**：

```bash
grep -n 'agent_runs' -A20 investment-app/investment-backend/app/alembic/versions/20260708_0001_agent_phase0.py
# 列：id session_id graph_name graph_version agent_profile_key agent_profile_version
#     thread_id idempotency_key status resume_token error started_at completed_at …
# 没有 parent_run_id / root_run_id
```

血缘只活在 `session_events.lineage` 的 JSONB 里，**不可索引查询**。
§8 要求"父 Task 汇总结果时保留来源和子 Task 血缘"——现在做不到。

**一次迁移解决**：加 `parent_run_id` / `root_run_id` 列 + 索引 + 外键。

### 6.3 证据账（I11）无载体

> I11：结论和数值按 Profile 关联**来源、时点、转换与执行者**

接外部 agent 后这条更要命：**同一个 prompt，Codex 的 `gpt-5.4` 和 dsh 的 `deepseek-v4` 会给出不同结论。**
不记执行者标识（后端 + 模型 + 版本 + 时点），两个月后无从归因。
对投资研究结论，这是**不可接受**的。

### 6.4 顺带确认：租约不是 fencing

现有 `RedisSessionLock` 会在图执行前后 `renew()`，失败即抛错——
比"完全没有"好，但**写库语句本身不带令牌条件**：

```
app/tasks/agent_graph.py:107   if not await lock.renew(lock_token): raise
app/tasks/agent_graph.py:129   if not await lock.renew(lock_token): raise
```

I14（失去租约后不能提交结果）在 renew 与写入之间仍有窗口。
外部 agent 的执行时间比现在长得多，这个窗口会被放大。

## 7. 落地顺序

每一步都可独立验收，且后一步依赖前一步。

```
第 0 步  拍板 §8 的三个问题（出网方式 / dsh 走 SDK 还是 ACP / 第一个专用 agent 是谁）

第 1 步  【契约】预算账落 PG + 两条生产链接线            ← 一切外部 agent 的前置
第 2 步  【契约】agent_runs 加 parent_run_id/root_run_id 列 + 索引
第 3 步  【契约】证据账：结论带 backend/model/version/时点

第 4 步  【架构】AgentBackendPort + BackendCapabilities
         先落 LangGraphBackend（包住现有两条链），此步**不引入任何外部依赖**
         验收：现有行为一字不变，测试全绿  ← 纯重构，风险最低

第 5 步  【架构】Profile 加 backend_key / backend_options
         验收：两份现有 Profile 显式声明 backend_key="langgraph"

第 6 步  【部署】新增 agent-runtime 运行角色（独立队列 / 独立 egress / emptyDir / 2Gi）
         验收：空跑一个 langgraph Profile，与现有 worker 行为一致

第 7 步  【接入】CodexBackend（先做 Codex，不是 dsh）
         理由：无需 Node、有 interrupt/approval、有 async 客户端——阻断最少
         验收：一个通用 Profile 端到端跑通，取消可用，审批可用

第 8 步  【接入】DshBackend，能力位 cancel=False approval=False
         验收：请求这两个能力的 Profile 在 VALIDATING 阶段被显式拒绝，不是跑到一半失败

第 9 步  【领域】financial_analysis Profile（一份配置，零执行路径代码）

第 10 步 【编排】COORDINATION Task —— 只有真出现"一个任务要拆并行子任务"时才做
```

**注意第 7 步先于第 8 步，与你原来的表述相反**：你的方案里 dsh 承担"专用"，
听上去更核心；但从阻断数量看，**Codex 的接入成本明显更低**（无 Node、能力更全）。
先用 Codex 把整条链路打通，再补 dsh，风险小得多。

## 8. 需要你拍板的三件事

### 问题一：出网怎么开？

| 选项 | 成本 | 风险 | 我的建议 |
| --- | --- | --- | --- |
| A. 照抄 info-app 的 `0.0.0.0/0:443` | 最低 | 模型可任意外联 | 仅限开发环境 |
| B. 只放模型厂商 IP 段 | 中，IP 变化要维护 | 收敛但仍明文 | — |
| C. 集群内正向代理，只允许代理出网 | 高 | 可审计、可限流、可记录 | **生产必须走 C** |

**建议：开发用 A 先跑通，但把 C 写进部署计划,不要等出了事再补。**

### 问题二：dsh 走 SDK 还是 ACP？

| | `sdk` profile | `acp` profile |
| --- | --- | --- |
| 官方 Python 客户端 | ✅ 有 | ❌ 无（只有 TS） |
| 取消 / 审批 / 列会话 | ❌ 全无 | ✅ 全有 |
| 符合 A4（不依赖裸协议） | ✅ | ❌ 要自己写客户端 |

**这是一个真取舍，不能两全。**我的建议：**先走 SDK，能力位如实声明为 `cancel=False`**。
理由是 A4 是已立的硬规则，而"专用 agent 不能中途取消"在第一版是可以接受的
（任务短、可等它跑完）。等真需要取消时，再评估是否值得为 ACP 破一次 A4——
**那时候是一个有具体收益的例外申请,而不是现在的一个假设。**

### 问题三：第一个专用 agent 是不是"财务分析"？

你举的例子是财务分析。但请确认它**不需要**下面任何一项，否则第一个专用 agent
就会同时撞上多个未解决问题：

- 需要执行代码（`SandboxPort` 引用数为 0，沙箱是设计意图不是现状）
- 需要取消（dsh 走 SDK 就没有）
- 需要人工审批某一步（同上）
- 需要跨 Pod 重启续接会话（§5.4）

**如果都不需要,财务分析是个好的第一个。如果需要,建议第一个专用 agent 换成更简单的,
把这些问题留到第二个。**

## 9. 边界

| 边界 | 说明 |
| --- | --- |
| 未运行任何进程 | 全部结论来自静态读码、清单比对与 `grep` 计数 |
| 未实测内存 | §3.4 的"768Mi 不够"是推断，**必须实测后再定 agent-runtime 的 limit** |
| 未验证 wheel 可装 | `deepseek-harness-runtime-bin` / `openai-codex-cli-bin` 能否从内网 PyPI 镜像装到 linux/amd64，**未验证**，是第 6 步的第一个风险点 |
| dsh 只读了约 3% | 读了 `docs/architecture.md`、Python SDK 全部、`packages/sdk/protocol`、`packages/acp` README、`packages/subagent` README。**未读**：Cordis、agent-loop、工具管线、web |
| Codex 只读了 SDK 层 | `sdk/python/docs/api-reference.md` 全文 + `client.py` 的启动与审批部分。未读 `codex-rs` |
| 未读前端 | 路由结果怎么呈现、流式怎么消费，本文未涉及 |
| dsh 的 subagent 生态未纳入方案 | dsh 自带 `dsh-subagent-codex` / `dsh-subagent-claude-code`,理论上可以让 dsh 自己当 supervisor 去调 Codex。**我没有推荐这条路**——它把编排权交给外部 harness,四本账就落在它的 home 里,直接违反 §6.2。但这是一个真实存在的备选,若你想让我评估,可另开一轮 |
