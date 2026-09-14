# 执行器详细设计（SDD）

> SDD / 执行器｜S2→S3/S4。按租用边界、SDK 能力、Port/门禁、两腿恢复与进程部署、功能矩阵排序；一条能力从接口到验证可以顺读。
>
> 2026-09-14 按 [dev-plan-architecture.md](../dev-plan-architecture.md) 第八节从 `1d0adde3` 迁入。每节前的 `<!-- Ixx-xxx -->` 是安置表 ID，冻结原文用 architecture 的 `show` 取。

## 租用边界与版本化能力

说明 loop 与控制面责任及 SDK 能力证据；日期/未验前提完整保留，不声称表中读数今天仍成立。

<!-- I02-021 -->
### 执行层：租用什么、自建什么

constraints A4 是「执行层租用不自建」。它的准确含义不是「什么都用现成的」，而是：
**租 agent loop，自建业务控制面。**loop（模型调用、工具循环、会话推进）用官方 SDK；
Task/Attempt/四本账/验收/授权是本平台的，不 fork runtime、不改 agent loop、
不复制协议类型、不 deep import 内部包、不维护私有 wire fork。

⚠ **先钉现状：生产环境里现在没有任何 agent 在跑。**本节结论一律处于 `defined`，
不是 `wired`，更不是 `runtime-verified`。可复核的休眠登记表在
`investment-backend/app/tests/test_dormant_capabilities.py`——它按
「锚点还在吗 + 还休眠着吗」两个方向立判据，**比 grep 计数稳**：
`:154` `RunBudget` 生产未接线、`:182` Attempt/Invocation 未落库、
`:208` `CancelRunCommand` 无 HTTP 端点、`:240` `AgentProfile` 只被记录不被执行。
开关 `AGENT_V4_TRAFFIC_ENABLED` 与 `AGENT_PILOT_ENABLED` 在 bundle 里都是 `'false'`。
**读本节任何一条都要带着这个前提，不得把目标态写成现状**——这正是 `design/evidence-sdd.md`「证据等级与采信规则」 推论 2
「拿休眠代码当能力证据」那个错误的机制来源。

**专用 Agent 的构建方法固定，具体 Profile 不冻结**：Profile/patch + 插件组合；
每个工具逐条声明输入/输出 schema 与数据、副作用边界；dry-plan 只产生可审计 Plan
Artifact，query 才执行；结果经显式 `submit_result` 提交，未提交不算 Attempt 完成，
提交只产生候选，validator 过 `F-ACCEPT-*` 后 Task 才可成功；两条 worker 凭据互斥。
**不冻结某个财务 Profile 的字段、工具清单、数据集或金标准**——内核要求首项工作以真实
输入确认契约，而当前业务数据源仍为空；未有真实数据和评测前，任何具体表都是 ⚠ 假设。

**OpenClaw：借机制，不转向。**它的 Gateway 是渠道接入与控制面，两层「路由」都不读用户
语义——channel/account/peer binding 是确定性映射并返回 `matchedBy`；provider/model route
选 runtime 且显式 plugin runtime 默认 fail-closed。可借的机制与本项目落点：确定性 binding +
命中规则 + 拒绝 reason code 存进 RouteDecision；agent/session/runtime/model 四者正交；
capability 支持与显式路线 fail-closed；host 先备好上下文、runtime 只跑 loop；来源路由与
回复交付分离。**不整体转向**：它「一 Gateway 一信任域」、多租户靠每租户一个仍属实验性的
cell，主档是 SQLite 不是共享 PostgreSQL，本身是 TypeScript/Node CLI；引入会重复现有控制面。
**其危险默认更不能继承**：sandbox 默认关闭、`tools.profile: full` 等于无限制、
`/elevated full` 可跳过 exec approval。明确不借：Gateway 当业务主档、channel binding 冒充
语义路由、本地会话存储取代 PostgreSQL、默认 host 执行、那三个逃生门、运行中静默跨 runtime
重放，以及把 Gateway 放进 BFF 与 FastAPI 之间。

**哪些路不该交给模型自己找。**输入输出与失败形态已经明确的确定性步骤，编排权留在
控制面；租用 loop 处理确实需要模型探索工具与方案的部分。把已知流程改成聊天循环，
不自动增加能力，却会降低可解释性。应用编排可以用 LangGraph 原语实现，
“执行层租用”不等于“不自建业务编排”，也不等于“重定义库的协议”。

**执行路线是否更好，分三层判断**：架构分工合理、当前生产成熟、目标门禁通过，是三种结论。
第一种不能替后两种背书。执行器接入的 Gate 0 至少须逐条验证下面三项；
这是执行器 spike，**不是 `development-plan.md`「依赖顺序」 的 G0 协议修复步骤**。

| Gate 0 条件 | 验收与证据 | 失败后的退路 |
| --- | --- | --- |
| 两条腿的事件能忠实投影到 Event/timeline | 事件映射不丢 Task/Attempt/turn 的关键归属，覆盖 `I4`、`F-EXEC-02` | 该腿不接产品链路；补公开 SDK 或由上层换腿 |
| 专业腿确有质量收益或至少不劣 | 同一真实输入和金标准，对照 Codex 单腿结构化输出；标准、预算与样本先冻结 | 不维持没有收益的专业路线；上层改用通过门禁的路线，Port 不变 |
| worker 内进程模型稳定 | 启动失败率、常驻/峰值内存、僵尸进程达到预先约定阈值 | 不塞入现有通用 worker；满足 constraints 的拆分条件才拆同一 Backend 下的专业运行角色，否则不接入 |

⚠ **三项都仍是待验条件，本次没有运行 SDK、模型或部署实验。**阈值和金标准未冻结时，
结论为不可判，不填“通过”。失败退路是公开 SDK 路线或约束修订，不是恢复自研通用 loop。

<!-- I02-022 -->
### 两个官方 SDK：两个轴、非对称能力

**专业构建能力与生产控制能力是两个独立轴，不能合成一个「谁更强」。**

事实钉在 Codex `7d6f808b`、DeepSeek Harness `dd6322d6`。
**升级钉版必须重跑锚点，不得沿用本表结论。**

| 轴 / 能力 | Codex Python SDK | DeepSeek Harness Python SDK | 对本平台的结论 |
| --- | --- | --- | --- |
| 专业 Agent 组装 | 进程级配置为主，无 preset 一等概念 | preset 是一目录一 `agent.cordis.yml`，按会话组合 tools/prompt/skills/persona，一进程可跑多种 agent（`packages/preset/README.md:12`） | Harness 适合专用 Agent；**这不表示其生产控制面已合格** |
| 生命周期 | thread start/resume/list/read/fork/archive、turn interrupt（`sdk/python/src/openai_codex/client.py:430-469`、`:641-646`） | wire 只有 initialize、session/prompt、shutdown；事件对 runtime 全量且未过滤 | Port 必须**表达缺失**，锚 `F-EXEC-02/05`、`F-INTERACT-*` |
| 逐 Turn 结果 | run/turn 有 turn id、流与 `output_schema` | `SessionPromptResult.messageId` 只标识**入队的用户消息**，「does not identify a later assistant message, turn ending, or prompt result」（`packages/sdk/protocol/README.md:52`） | Harness 缺完成归属，**不能伪装 `COMPLETED`** |
| 取消 / 关闭 | 有 turn interrupt；thread 可 archive | 「**No cancel or session-close methods** — a client abandons a turn by closing the runtime process」（同上 `:115`） | 只能用进程级补法，**代价写入 Attempt** |
| 交互批准 | 可接 approval handler，**但默认自动接受**：`_default_approval_handler` 对 `commandExecution` 与 `fileChange` 一律返回 `{"decision": "accept"}`（`client.py:773-779`） | 「**Server→client requests are a dead capability** — the transport supports them, but the server never sends one」（同上 `:116`） | **Codex headless 必须覆盖默认 handler；Harness 不得声称原生 HITL** |
| provider 协议 | 已钉死 Responses API，`wire_api="chat"` 明确报错（`codex-rs/model-provider-info/src/lib.rs:57-88`） | 面向 DeepSeek 等自身 adapter 路线 | DeepSeek Chat Completions 经 Codex 需另建翻译代理，**是真实阻抗，不是无成本替代** |
| 系统 Node | 不适用 | wheel 携闭包，SDK 不需系统 Node | ⚠ 内网 PyPI 能否取得 wheel 未验证；**不得复活「缺 Node 阻断」** |

⚠ **这张表是「投喂 vs SDK」问题的证据底座。**它说明两件事：其一，CLI 投喂路径答不了审批
请求不是配置问题——Codex 侧默认就是自动接受，Harness 侧根本收不到请求；其二，
换 SDK 不等于自动获得 HITL，Harness 腿的审批要靠**平台工具网关**，不能靠 runtime 自批。

工具可通过插件注册，参数/输出校验与 policy hook 见
`~/repo/deepseek-harness/docs/cookbook/adding-a-tool.md:7-59`；这支持「不 fork agent loop」，
**不证明多租户授权、取消和恢复已接线**。

<!-- I06-005 -->
#### 执行层租用，不自建

通用部分的执行层采用 Codex 的 Python SDK（`openai-codex`，Apache 2.0）：
不自建轮次生命周期、隔离进程、中断恢复、审批协议、工具与沙箱。

**依赖边界严格限定在 SDK，不得直接依赖其 app-server 裸协议。**依据实测：

| 层 | 近 3 个月提交 | 破坏性变更 |
| --- | --- | --- |
| `app-server-protocol`（裸协议） | 280 次 | 12 处 |
| `sdk/python`（门面） | **10 次** | **0** |

执行层须通过 Port 隔离——理由不是"将来可能要换"，而是：有该接口才能用 fake
执行器测试纪律层（隔离是否生效、吸收有没有留处置记录），否则每次测试都要真起
harness 并需凭据。

**harness 只给执行原语，不给运作纪律**：N 路隔离、轮次、中断恢复、审批、工具、
沙箱它有；三阶段可见性、提案包构造、评审协议、吸收处置记录、重叠分歧判据——
这些在 [`round-protocol.md`](../protocol/round-protocol.md)，必须自建。

## Port 与准入门

签名、探针与 Harness 过渡路线共同决定能否派工；不将支持的近似能力写成产品已支持。

<!-- I02-023 -->
### 统一执行 Port 与三态能力探针

application 层只依赖中性 Port；签名里不得出现 ticker、portfolio、财报等领域词（A4/A5）：

```python
class AgentExecutorPort(Protocol):
    async def capabilities(self) -> ExecutorCapabilities: ...
    async def start(self, request: ExecutionRequest) -> ExecutionBinding: ...
    async def resume(self, binding: ExecutionBinding, value: ExecutionInput) -> None: ...
    async def cancel(self, binding: ExecutionBinding, reason: CancelReason) -> CancelReceipt: ...
    async def events(self, binding: ExecutionBinding,
                     cursor: ExecutionCursor | None) -> AsyncIterator[ExecutionEvent]: ...
    async def inspect(self, binding: ExecutionBinding) -> ExecutionSnapshot: ...
    async def close(self, binding: ExecutionBinding) -> None: ...
    async def submit_result(self, binding: ExecutionBinding,
                            payload: ResultEnvelope) -> SubmissionReceipt: ...
```

**`submit_result` 在签名里，不是 Adapter 私货。**结果必须经一个显式提交动作进入平台，
未提交不算 Attempt 完成，提交成功也**只产生候选**——validator 说了才算。放进 Adapter 内部
会让两条腿在「什么算完成」上出现两套语义。⚠ **Harness SDK 当前不存在这个方法**，
它是我们自建的约定，不是租来的能力。

**Port 存在的第一理由是可测性，不是「将来可能换执行器」。**有了它，纪律层可以用
`FakeAgentWorker` 跑完整状态机、超时、取消与恢复路径，不必每次真起 runtime、真发凭据、
真花模型钱。「将来可能换」是**收益**，可测性是**现在就成立**的理由——本仓
`ToolExecutionPort` 生产引用为 0，正说明没有可测载体时 Port 会停在 `defined`。

`ExecutionBinding` 必须可序列化并落 PostgreSQL：**SDK 侧的 thread/session id 不是 Task 的
真源**（`I13`），进程重启后要能只读持久载体接着做。

**能力探针是三态，不是布尔：**

| 状态 | 含义 | 调度规则 |
| --- | --- | --- |
| `available` | 钉版 SDK 与 runtime 已证明原生保真支持 | 仍须过 Attempt 准入 |
| `explicit_unsupported` | SDK 明确不支持且不得降级 | **fail-closed**；换路线必须新建 RouteDecision/Attempt |
| `implicit_fallback` | 有替代语义但会损失能力或改变边界 | 只有冻结政策明确允许且**代价落账**才可用；不得静默 |

⚠ **布尔 `true/false` 会把「明确不支持」和「悄悄降级」压成同一种事实**，
于是 `AT-09`、`AT-14`、`AT-20` 无法证明。探针必须带 runtime/SDK 版本、证据与探测时间；
dispatch 以所需能力集合做**硬过滤**，不能等 Adapter 内部临场降级。

**Port 的 DTO 和 Adapter 边界。**通用 DTO 只承载 `attempt_id`、版本化 `profile_ref`、
workspace/input Artifact 引用、完成合同引用、预算预留引用、trusted security context 引用、
deadline，以及 opaque provider session/turn identity；实际字段由实施时的契约测试钉定。
Adapter 只做公开 SDK 映射、binding 持久化、事件与错误码归一、teardown。
它不路由、不授权、不验收，不拥有四本账或 Task 终态；thread/session 不能升成业务主档。
纪律层用 Fake 执行器验证状态与失败路径，真实 SDK 只在集成及运行门禁中验证。

<!-- I02-024 -->
### Harness 腿的前置门禁与过渡补法

门禁卡的是「本平台的状态机能否管住 Harness」，**不是「能否用 Harness 建专业 Agent」**。
专业腿进入自动路由前，必须由上游在正式 SDK 同步实现并测试以下公开合同：

- session start/resume/read/close，按 cursor 读取 session events；
- turn start/read/steer/cancel，stable turn id，**逐 Turn completion correlation**；
- per-session preset 选择与逐 Turn 结构化输出合同；
- **模型不可见、不可改的 trusted context**：Task/Attempt、tenant/actor、授权策略版本、
  允许能力、数据集绑定、证据策略、deadline；
- async 且已证明不阻塞的 Python 面、cancel durable end、crash/restart/malformed-wire 测试、
  版本化 capability query。

门禁未过时**只允许显式、受限的过渡路线**，四条，且代价必须落账：

1. 取消时先持久化意图并 revoke Attempt 网关令牌，再按 teardown ladder 杀 runtime 进程；
2. 每个专业 Profile 必须提供显式 `submit_result` 工具；未调用不算 `COMPLETED`，
   调用成功只产生候选，仍由独立 validator 判 `F-ACCEPT-*`；
3. 高风险工具**不交给 runtime 自批**，全部经平台工具网关按审批分层决定；
4. 等待/恢复**创建新 Attempt**，从持久 Artifact 和现场快照恢复，不伪造原 Session 续跑。

代价：进程级取消粒度粗、上下文重建耗时、可能丢失未提交中间推理、重复计算增加预算、
不能原地 resume。相关项探针标 `implicit_fallback`，**不得标 `available`**。
若完成合同需要保真的原 Attempt 恢复或逐 Turn HITL，该路线保持 `explicit_unsupported`。

⚠ **注意这条与 「直接沿用实际中断/恢复原语」 的关系**：`dev.change` 走的是 LangGraph checkpointer，**原地 resume 可用**
（「直接沿用实际中断/恢复原语」 已实测）。本节说的是 Harness 腿——**两条腿的恢复语义不同，不可互相外推**。

## 进程恢复与功能落实

部署/取消/两腿 resume 语义及 F-EXEC 矩阵一起复验；权限授予本体引用 authority SDD。

<!-- I02-025 -->
### 双 runtime 的部署、进程与恢复

先按运行角色分 API、通用执行 worker、专业执行 worker。两类 worker 使用**互斥的服务身份、
队列、网络与凭据**，不能在同一进程里把两套 key 都做成环境变量。

当前部署有四条硬阻断，都是现状不是建议：

| 阻断 | 可复跑锚点 | 必须补的门禁 |
| --- | --- | --- |
| worker 无模型 API egress | `deployment/bundle/30-network-policies.yaml:221-268` 只放 PostgreSQL/Redis/RabbitMQ、Casdoor、Knowledge；`rg -n 'ipBlock' 该文件` 零命中 | 精确目的地/代理 egress，**在 Calico 环境实际验证**，锚 `I3/I12`、`AT-05` |
| root filesystem 只读 | `deployment/bundle/20-runtime.yaml:361-373` | `CODEX_HOME`、`DSH_HOME`、workspace、snapshot staging 分离到有配额的可写卷 |
| worker 内存上限 768Mi | `deployment/bundle/20-runtime.yaml:354-373` | 双 runtime 峰值与 prefork 并发实测后定 requests/limits |
| 模型配置/凭据未进 bundle | `deployment/bundle/00-prerequisites.yaml:106-119`；`rg -n 'AGENT_PILOT_LLM_' bundle` 零命中 | 代理 endpoint、短 TTL token issuer、Secret/ServiceAccount、启动 fail-closed |

⚠ **KIND 默认不执行 NetworkPolicy。**第一条阻断的「包级验证」只在生产 Calico 下成立；
开发用的 KIND 集群里策略写了也不生效，**会让人误以为出口已经封死**。

⚠ **这条进程纪律有死者，不是设计洁癖。**Celery worker 默认 prefork 数继承节点 CPU，
本仓曾因此起了 12 个子进程直接打爆 768Mi；模板已把并发钉成
`CELERY_WORKER_CONCURRENCY: '2'`。**在这个内存上限下再往每个子进程里塞一个 SDK runtime，
是同一个坑的第二次。**

SDK 进程纪律：Celery prefork **之后**按 Attempt 或受控槽创建 SDK client/runtime；
不得在 parent 初始化后跨 fork 共享 fd、锁、event loop 或子进程句柄；owner 记 PID/进程组与
binding。关闭按 `stop intake → revoke token → SDK cancel/close → 限时 TERM 进程组 →
限时 KILL → reap → 核对副作用账`，每步写证据。
⚠ Codex async 客户端内部把同步调用包到 worker thread（`async_client.py:161-183,293-295`），
**并发与 teardown 必须做负载/故障注入，不能由 `async` 关键字推断安全**。

可恢复执行现场按 `attempt_id + runtime_version + profile_version + digest` 内容寻址写对象
存储；PostgreSQL 只存引用与摘要。restore 在新可写面校验摘要、授权、fencing、
runtime/Profile 兼容性后继续，**不把 executor 本地目录当真源**。

**恢复必须有界**：Profile 固定 `max_attempts`；同一
`failure_fingerprint + profile_version + runtime_version` 连续失败达阈值就**熔断该版本路线**，
停止自动恢复并转 Interaction。Profile 升级**不得替历史 Task 静默解锁**。

<!-- I02-054 -->
### 直接沿用实际中断/恢复原语

当前基座已经提供足够原语：

- `investment-backend/app/app/infrastructure/graph/pilot_graph.py:59-66` 调用
  `interrupt({...})`，出向值就是任意字典；
- `investment-backend/app/app/infrastructure/graph/langgraph_runtime.py:14-21` 用
  `Command(resume=user_input)` 接收任意恢复值；
- `investment-backend/app/app/application/agent/graph_runtime_service.py:14-23` 将同一 `session_id`
  映射为同一 `thread_id`；
- `investment-backend/app/app/tasks/agent_graph.py:106-128` 在同一 thread 配置和 PostgreSQL
  checkpointer 上首次执行或恢复。

**中断恢复在本项目已经端到端跑通**，不只是「库有原语」：

| 层 | 状态 | 取证 |
| --- | --- | --- |
| 抽象基类 `GraphRuntimeService.resume` | `raise NotImplementedError(...)` | `graph_runtime_service.py:26-31`——这是**抽象方法的正确写法**，不是功能缺失 |
| 适配器 `LangGraphRuntimeService.resume` | **已实现**：`Command(resume=…)` + 同 `thread_id` | `langgraph_runtime.py:13-21` |
| 端到端 | **通过**：中断 → `resume` → 原地续跑并产生副作用 | `test_graph_runtime_service.py:18-35`，`uv run pytest` → **2 passed** |

⚠ **这一段曾经写反过，教训比结论有用。**先前据抽象基类那行 `NotImplementedError`
断定「端到端未接线」——**错在只读了基类 18 行就停**，没搜谁继承、没搜谁调用、没跑测试。
把「留给实现方的空位」（**接口契约**）读成了「功能缺失」。

> **「打开文件自验」也会失败**：验了，但**验的范围是自己划的**，而范围划错了。
> 这与「没验就下结论」是两种错，**后者好防，前者难防**。

因此实现应把产品 Interaction 的 `question_or_action / audience / expires_at / resume_token_hash /
idempotency_key / consumed_at / resume_target` 绑定到这些原语，字段真源仍是
`request-lifecycle.md @ ed0b5136:247-277`。中断节点返回业务需要的 dict；恢复端鉴别主体、校验
Task 与状态版本、原子消费令牌，然后把经验证的响应作为 `Command(resume=value)` 送回同一 thread。
checkpoint 原地续跑时是同一 Attempt 的 `WAITING → RUNNING`，不因“人给了内容”另开 Attempt。

**`dev.change` 的 H8 具体这样接**（五步，缺一步就会长回自造协议）：

1. 需要人时，adapter 调库的 `interrupt(payload)`；**payload 的形状由 Task Profile 的入向约定声明**，
   不写进内核绑定字段——形状归 Profile，字段归内核，这样扩展不必动内核；
2. 人的答复经 **principal channel** 到达后，adapter 调 `Command(resume=答复)`，
   **同一 `thread_id` 原地续跑**；
3. **这不是新 Attempt，也不建新 Task。**内核 Attempt 状态机走 `WAITING → RUNNING`；
4. **只有**当答复实质改变了目标、口径、授权范围或 Profile 版本，才按内核建带 `supersedes`
   的新 Task——**四个条件之外的答复一律回原 Task**；
5. 过期、异键、跨 Task 的恢复**由库与内核既有校验拒绝**，不在 Profile 层再造一套。

⚠ **「需要载荷」这个需求，是被「恢复必须开新 Attempt」自己造出来的。**
库的恢复不换 Attempt，载荷就是 `resume` 的那个值。取消掉那个不该有的执行边界，
围绕它长出来的一整支设计（载荷、schema、过期校验、Task 级暂停）就一并消失。

若未来业务确需结构化编辑，先拿一个真实 Task Profile 的前端 payload、拒收用例和迁移数据立规范修订；
不要从自由 `resume` 值反推一套平台级 patch/replace 协议。修改目标、授权范围或 Profile 版本仍按产品
“终态、刷新与重新处理”建立新 Task；普通澄清只恢复原 Task。

**按问询类型展示信息，避免轻问题背重合同。**补缺失参数只展示具体问题与必要上下文；
批准某个产物则展示其版本、证据等级、允许改动范围和各选项后果；依赖/资源/外部事件按已有合同。
业务内容放在 Profile 的 payload 内，不另造内核字段。

人指出错误、由 agent 继续修订时，把反馈作为恢复值交回同一执行；
人亲自提供新 Artifact 版本时，保存人的作者归属并把引用绑定到经验证的响应。
**谁写下一版不决定是否新开 Attempt**：可原地续跑就仍是原 Attempt；旧执行已终态、
需重试或换执行器才新开；目标/授权/Profile 改变则按合同新建 Task。
这保留“人可以贡献内容”，排除旧稿“人写新版本必然换 Attempt”的额外执行边界。

<!-- I02-071 -->
### `F-EXEC-*` / `F-INTERACT-*` 双腿落地矩阵

状态按 「统一执行 Port 与三态能力探针」 的三态探针标注。⚠ **探针词与「已支持 / 需补法 / 当前缺失」的对应固定如下，
读表一律按右列判定，不得只看探针词：**

| 探针状态 | 三档判定 | 含义 |
| --- | --- | --- |
| `available` | **已支持** | SDK 原语直接满足该条义务；平台仍需归一并记账 |
| `implicit_fallback` | **需补法** | SDK 有近似原语但不满足义务，平台/Adapter 必须补齐 |
| `explicit_unsupported` | **当前缺失** | 协议显式否定该能力，须走上游门禁或过渡补法 |

⚠ **不得把 SDK 原语冒充产品能力**：把 `implicit_fallback` 读成「已支持」是一次真实的措辞坑。
矩阵只投影内核的稳定 ID，不重新定义其义务；证据锚点一律注明出自哪个仓——
⚠ **不得拿本仓自己的代码当租用 SDK 的能力证据**（真实案例：某候选以本仓休眠的
`AgentProfile.permits_tool` 佐证 Harness 腿工具门）。

| 功能 ID | Codex 腿 | Harness 腿 | 需补法与验收 |
| --- | --- | --- | --- |
| `F-EXEC-01` | `available`：sandbox/approval/tool 面可配置；**但 headless 默认 approval handler 会自动 accept** | `implicit_fallback`：**进程内**工具门是真的（`adding-a-tool.md:59` 的单调 deny，preset 按会话组合 tools/prompt/skills）；但 wire 无可信逐 Task context，也无 per-session preset 选择 | Attempt 准入取 Task/Profile/当前批准的交集；**Codex 必须覆盖默认 handler**；Harness 工具网关逐次验权。`AT-05` |
| `F-EXEC-02` | `available`：thread/turn/event 可关联，仍需归一并写平台账 | `implicit_fallback`：`sessionId` 可作 Attempt 级关联的**输入**，但只是来源标签，不自动完成唯一 binding、全 runtime 事件过滤、子 session 递归归属与证据持久化 | 平台强制 binding、过滤、递归登记、补齐版本并持久化。⚠ **逐 Turn completion correlation 另属上游门禁**（`SessionPromptResult.messageId` 不标识 turn 结束或结果，`protocol/README.md:52`）；需要逐 Turn 保真的路线**在 dispatch 前 fail-closed** |
| `F-EXEC-03` | `available`：approval callback 可逐动作接平台复核，**默认实现不可用** | `explicit_unsupported`：**server→client request 不发生**（`protocol/README.md:116`） | 高风险动作**只经工具网关**；审批绑定动作/产物哈希并落账。`AT-05/07/12` |

⚠ **这张矩阵是 「两个官方 SDK：两个轴、非对称能力」 那张表在内核功能 ID 上的投影。**两张表口径必须一致：
`F-EXEC-03` 的 Harness 腿判 `explicit_unsupported`，依据就是 「两个官方 SDK：两个轴、非对称能力」「交互批准」那一行。
**升级钉版时两张表必须同时重跑。**
