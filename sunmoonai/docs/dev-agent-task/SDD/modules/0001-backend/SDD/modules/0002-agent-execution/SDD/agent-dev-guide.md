# Agent 开发指导：一个产品运行时，一套开发纪律

### 2.6 执行层：租用什么、自建什么

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
**读本节任何一条都要带着这个前提，不得把目标态写成现状**——这正是 [§5.2](../../../agent-dev-guide.md) 推论 2
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
这是执行器 spike，**不是 [§7.1](../../../agent-dev-guide.md) 的 G0 协议修复步骤**。

| Gate 0 条件 | 验收与证据 | 失败后的退路 |
| --- | --- | --- |
| 两条腿的事件能忠实投影到 Event/timeline | 事件映射不丢 Task/Attempt/turn 的关键归属，覆盖 `I4`、`F-EXEC-02` | 该腿不接产品链路；补公开 SDK 或由上层换腿 |
| 专业腿确有质量收益或至少不劣 | 同一真实输入和金标准，对照 Codex 单腿结构化输出；标准、预算与样本先冻结 | 不维持没有收益的专业路线；上层改用通过门禁的路线，Port 不变 |
| worker 内进程模型稳定 | 启动失败率、常驻/峰值内存、僵尸进程达到预先约定阈值 | 不塞入现有通用 worker；满足 constraints 的拆分条件才拆同一 Backend 下的专业运行角色，否则不接入 |

⚠ **三项都仍是待验条件，本次没有运行 SDK、模型或部署实验。**阈值和金标准未冻结时，
结论为不可判，不填“通过”。失败退路是公开 SDK 路线或约束修订，不是恢复自研通用 loop。

### 2.7 两个官方 SDK：两个轴、非对称能力

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

### 2.8 统一执行 Port 与三态能力探针

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

### 2.9 Harness 腿的前置门禁与过渡补法

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

⚠ **注意这条与 [§4.3](../../0003-interrupt-resume/SDD/agent-dev-guide.md) 的关系**：`dev.change` 走的是 LangGraph checkpointer，**原地 resume 可用**
（[§4.3](../../0003-interrupt-resume/SDD/agent-dev-guide.md) 已实测）。本节说的是 Harness 腿——**两条腿的恢复语义不同，不可互相外推**。

### 2.10 双 runtime 的部署、进程与恢复

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
12 个子进程就能直接打爆 768Mi；模板已把并发钉成
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

### 3.2 工作区供给

> 依据的通用规范：[IMP「执行规范 · 工作区」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

```text
provision(task_id, source, baseline_commit, write_actors, review_needed, submodule_plan)
```

复用工作区前，必须同时满足 owner 是本 Task/执行者、`git status --porcelain` 为空、HEAD 等于基线 commit；
任一失败就新建，不 stash 人的修改。零写者只给只读取件；一名写者一棵独占 worktree；N 名写者在同一
基线上建 N 棵独占 worktree，另给 integrator 一棵；人需通读时临时开 review worktree，用完删除。
多仓逐仓钉 commit，并核父仓 gitlink。
⚠ **父仓推送不带子仓提交**：跨机同步脚本推的是父仓，拉取侧自动 `submodule sync/update` 对齐 gitlink，
**子仓的提交仍须自己推**（constraints T4）。只交父仓 gitlink 而子仓对象不可达，等于没交。

独占在 CLI/GUI 腿通常只是约定，因为同 OS 用户可能看见整个文件系统；只有 runtime 提供的 namespace、
文件挂载、凭据裁剪和出网网关才能构成事中限制。`workspace_isolation` 必须登记为 `enforced` 或
`convention`，不能把目录不同写成安全隔离。

⚠ **后果是一条硬约束，不是一句提醒**：`convention` 腿的授权范围声明（`I3`）只能依赖
「事后审计可发现越权读取」，不能依赖「事中读不到」。因此——
**涉及第二租户或真实财务数据之前，CLI 腿的数据源必须经运行时的数据网关，
不得给裸库凭据。**

### 3.6 私有地产生，单写者发布

> 依据的通用规范：[IMP「私有地产生，单写者发布」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

**会话隔离、模型隔离和任务名称不同，都不等于文件系统隔离。**
任何可能并行的执行者都不得把共享路径当自己的草稿纸。

```text
private draft → owner candidate → frozen commit / immutable Artifact
              → 选优 → integrator workspace → final commit → 共享分支 / release / Delivery
```

共享发布面包括 `master/main`、公共工作树、约定的最终文件路径、共享对象存储键、正式 PR、
release、部署环境和用户可见结果。⚠ **用户要求的最终文件名是发布目标，不是所有候选都可
同时写的路径。**多个候选各自在独立 worktree 里改同一相对路径是安全的；共用一个物理工作树
就必须用 owner namespace，**不能靠「最后再改名」避免覆盖**。

推荐的逻辑命名（实际路径可调，隔离维度不能丢）：

```text
branch:    task/<task-id>/<owner-id>/<work-unit-id>
worktree:  <sandbox>/worktrees/<owner-id>/<work-unit-id>/
artifact:  <artifact-store>/<task-id>/<work-unit-id>/<attempt-id>/<name>
evidence:  <artifact-store>/<task-id>/<attempt-id>/evidence/<name>
integrate: task/<task-id>/integrate/<run-id>
```

若工具限制导致只能共享一个工作树，草稿必须写进明确的 owner namespace（如
`.work/<task-id>/<owner-id>/...`），共享最终路径保持只读。**共享工作树是降级方案，
不能声称具备 worktree 级隔离。**连 owner namespace 都保证不了，任务必须串行。

**本仓当前落点：**

| | 路径 | 权限 |
| --- | --- | --- |
| 人的主 checkout | `~/master/<仓>` | **只读**。可读、可对照，**不是投稿箱**，也不因为「原件在这里」就该写这里 |
| 执行者工作区 | `~/worktrees/<助手>/<仓>` | 该助手唯一可写面；提交到自己的命名分支 |
| 整合面 | 整合方 worktree 上的 `integrate/<run-id>` | 只有 integrator 写；**源是选定 commit，不是任何人的工作区文件** |

「一仓一个默认工作区」不够多执行者用。同一 Task 出现第二名可写执行者时，
必须先建好各自的 worktree 和命名分支再派活，**不往默认工作区加写者**。

### 3.7 并发场景处置表

> 依据的通用规范：[IMP「并发与事故」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

每行四件事：场景、正确落点、禁止做法、**已发生时怎么收**。
恢复列给的是入口动作，统一规程见 §3.8。

| 场景 | 必须怎样做 | 禁止 | 已发生时 |
| --- | --- | --- | --- |
| 多执行者生成同名文档 | 各自在自己 branch/worktree 改同一相对路径，分别 commit | 一起写共享目录同一个 `.md` | **以 commit 认主，不以磁盘最后一版为准**；共享路径上的未提交文件视为污染，移进各自 namespace 后比 digest，声明哪些候选已不独立 |
| 只能共享物理目录 | 用 `owner_id/work_unit_id` namespace，最终路径只读 | 用时间先后或「谁最后保存」定结果 | 停写；分流进各自 namespace；由 integrator 裁决 |
| 单执行者单路任务 | 仍固定 owner、baseline 和 candidate commit | 在脏的共享 master 上直接写未跟踪结果 | 把脏工作区里属本任务的内容迁到自己分支并 commit |
| 人与 agent 混合 | 各有独占 worktree，统一登记 | 默认人的目录可被 agent 写 | 助手改动撤出人的工作区；**人的未提交改动优先保留** |
| 两个单元改同一文件 | 目标不同则各分支独立改由 integrator 解冲突；共同写同一事实则重划所有权或串行 | 同时共享写、事后凭 mtime 猜作者 | 停写；双写内容各自成 commit，交 integrator 判重复/互补/无关 |
| 多仓 / 子模块 | 每仓独立 owner branch/commit；子仓对象先可达再更新父仓 gitlink | 只交父仓 gitlink | 补齐每仓映射；**子仓对象不可达的 gitlink 不进整合** |
| 同一 Task 多 Attempt 重试 | 每次新 attempt/worktree/branch；旧结果标失败或 superseded | 在旧 Attempt 目录原地续写 | **旧目录冻结为失败现场**，新 Attempt 从固定 commit 重开 |
| 候选修订 | 新 commit + `supersedes` | 冻结后改 branch 再沿用旧评审 | 新哈希标为冻结后修订并记 `supersedes`，不进本次比较 |
| 内容相同的重复候选 | 按 digest 去重，可共享内容对象，**保留各自 provenance** | 删一方记录后声称只有一个来源 | 合并内容对象，两份 provenance 都留 |
| 合并冲突 | integrator 在独占整合 worktree 解析，记冲突双方与裁决依据 | 让候选作者互相覆盖，或按时间自动取新 | 同左；**不按时间自动取新** |
| 一方删除、一方修改同一文件 | 作为语义冲突交 integrator 依 Task 裁决并补回归 | 机械采用 delete/modify 任一侧 | 升给 integrator，不机械取任一侧 |
| 用户工作树已有脏改动 | 视为用户所有；另建 worktree/分支或避开，先记 baseline | **stash、reset、checkout 或覆盖用户文件来「清理」** | 不 stash、不 reset、不 checkout；先记 baseline 再绕开 |
| 执行中发现共享路径又被改 | 立即停写并进 §3.8 | 继续保存，期待自己的内容最后覆盖回去 | 停写转 §3.8；从最新可确认版本建新整合 Attempt |
| formatter/codegen 同时跑 | 只在 owner worktree 执行，生成物归该 owner commit，固定工具版本 | 对共享目录启用后台自动写入 | 关掉共享目录自动写入；受影响文件从 owner commit 重生成 |
| 无 Git 的简单任务 | 每个 Attempt 用独立 Artifact key，以 digest/version 冻结 | 多 Attempt 写同一临时文件或对象键 | 迁到 Artifact + digest；同键多次写入按 provenance 拆开 |
| CI / 并行测试 | 每 job 独立输出目录与 Artifact 名，聚合器只读 | 并行 job 写同一 coverage/报告/缓存真源 | 单槽输出作废，重跑到绑 commit 的独立位置；**不采信被覆盖过的报告** |
| 跨 Task 共享缓存 | 按输入摘要寻址、内容不可变、命中可校验、失败可丢弃重建 | 把可变缓存当结果真源 | 疑似互相覆盖的条目**一律丢弃重建，不尝试修复** |
| 大文件 / 二进制 | 内容寻址存储，Git 记摘要、schema、来源和位置 | 多人向同一路径覆盖上传 | 以 digest 认主；取有 provenance 的那份，其余降为未验证参考 |
| 敏感产出 | 加密/受控存储，最短保留期，日志脱敏 | commit、PR、Artifact 或聊天中保存凭据 | **按泄露处理**：轮换凭据、清理副本与日志、记暴露窗口；**不能靠删文件了事** |
| symlink / 路径别名 | 写前解析规范路径并确认仍在获准 writable root 内 | 利用软链、`..` 或挂载别名写出 owner 空间 | 核对实际写出的规范路径；越界按覆盖事故处理 |
| 外部发布 / 数据库写入 | 唯一 side-effect owner + 幂等键 + fencing + 回执 | 因代码分支隔离就允许多候选同时写生产 | 查副作用账按幂等键判是否重复；需要时补偿，**不靠重跑覆盖** |
| 多执行者推远端 | 各推自己的远端 ref；integrator 独占发布 ref | 共推同名远端分支，non-fast-forward 后 force-push | ⚠ **不要强推回滚**。报告有权主体，由其决定 revert 或冻结该 ref |
| PR 评审后新增 commit | 原评审绑定旧 commit；新 HEAD 重触发受影响门禁与评审 | 沿用旧批准声明新 commit 已通过 | 原批准作废，新 HEAD 重跑 |
| 候选迟到 | 标 `STALE` 只读保留；需要时新开改进单元 | 写入 final path、覆盖已选 commit、再执行副作用 | 同左；**源仍是 commit** |
| 失败 / 取消 | 冻结失败现场和已产出对象，盘点副作用，再按策略回收 | 先删 worktree 导致无法复盘 | 先冻结再回收；已删的现场按证据缺口登记，**不补造** |
| 执行者崩溃 | 新执行者从 manifest/checkpoint 和固定 commit 恢复到新 worktree | 盲接旧进程的半写目录 | 不接管半写目录，重建 |
| 已交卷 commit 需修改 | 新 commit；旧哈希仍报给评审并记 `supersedes` | `commit --amend` 改写已被他人读过或已交卷的提交 | 原 commit 仍可达则继续作评审对象；新哈希标冻结后修订，**不静默替换** |
| 两执行者提交到同一分支 | 不应发生——派工时 `exclusive_branch` 互斥 | 共用 `tmp`/`new` 这类分支名却不拆所有者 | 停写；按作者拆成两条分支，原分支冻结 |
| 从共享目录拷走他人未提交稿 | 不拷。交卷只经收集到的 commit | 把别人的草稿当自己的起点 | **该路不再计作独立候选**；记录污染来源与时间窗口 |
| 整合时误拷工作区文件进共享主仓 | integrator 从**选定 commit** 取内容 | 把任何人的未提交文件复制进共享主仓 | 从主仓撤出，改从 commit cherry-pick/merge；撤出前先确认没覆盖他人内容 |
| 只读探索 | 不写；或只写一次性抛弃分支且不推送 | 探索性改动混进实施分支或共享主仓 | 探索提交不进选优，除非任务包事先允许 |
| 跨机 / 新会话接手 | 只凭分支 + commit 恢复；cwd 必须是自己的 worktree | 凭「上次写在共享目录里」接着写 | 先看 `worktree list` 与 `status`；共享工作区里的未跟踪文件先按覆盖事故处理 |
| master/main 发布 | 仅 integrator 在最终验收并获授权后更新 | 每个候选直接向 master/main 写 | 未经整合的写入撤出发布面，从选定 commit 重走整合与 final gate，**不在发布面上就地修补** |

### 3.8 覆盖或来源不明时的事故规程

> 依据的通用规范：[IMP「并发与事故」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

⚠ **后到者赢在任何场景都不成立。**磁盘上的最后一版、时间戳最新的一份、最后推上去的那个
ref，都不因为「在后面」而获得正确性或所有权。**覆盖发生后唯一有效的认主依据是 commit、
digest 和 provenance。**

这是唯一一套事故规程，两档入口。

**四步前门**（单文件被覆盖、来源基本可判、无外部副作用、无发布竞争）：

1. **保全现场**：停止对该路径一切写入，先记录，不删除、不 reset、不 checkout；
2. **恢复归属**：从 Git 对象、reflog、Artifact 或备份取回各版本，各自恢复为归属者的独立
   分支或 owner namespace，交还归属者；
3. **判定关系**：由**非当事方**判定两份是重复、互补还是无关，据此取一、合并或都保留；
4. **留痕**：把覆盖窗口、受影响对象和恢复依据记入证据账。

任一条不成立——来源不明、涉及发布面或远端、已产生外部副作用、同一路径反复被改——
**立即升级为八步，不要在四步里硬撑**。

**八步完整规程**（内容、大小、hash、mtime、HEAD 或作者特征与预期不符时）：
① 停写（含自动格式化/生成任务）② 保全（记路径、stat、hash、`git status`、HEAD、进程）
③ 分流（各版本存进各自 namespace 或不可变 Artifact）④ 溯源（依 commit、checkpoint、
manifest、工具事件和内容特征判断；**mtime 只作线索**）⑤ 恢复（优先从 owner commit、
Git object、Artifact、备份）⑥ 裁决（由 integrator 决定选用/合并/全拒，
**不由最后写入者自动获胜**）⑦ 回归（在新 final commit 重跑门禁）⑧ 记录（覆盖窗口、
受影响对象、恢复依据、防复发控制）。

⚠ 来源无法确认时，**文件不得进入 final**；能恢复内容但不能恢复 provenance 时，
只能作为未验证参考。事故处理中**不得为了「恢复干净」破坏用户或其他执行者的未提交内容**。

### 3.9 冻结、迟到与取消

> 依据的通用规范：[IMP「冻结、迟到与取消」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

候选、评审、改进、最终结果和验收绑定不可变 commit。冻结后替换必须产生新 commit 并登记。
主线采纳后的在途结果标为 `STALE`，不得覆盖主线、执行副作用或推翻已交付结果。

**迟到判定分两层，机制不同，不要混用：**

| 层 | 判定依据 | 机制在哪 |
| --- | --- | --- |
| **产品侧**（Attempt 写回、副作用、终态提交） | Task/Attempt 状态、租约与 fencing token | 内核的目标合同。本文只引用，不重新定义 |
| **开发侧**（候选、评审、改进、整合） | 冻结 commit、候选状态、冻结时间戳 | 本文。⚠ **开发侧没有租约机制**：整合方吸收前必须显式核对四项——候选状态仍有效（非 `STALE`/`SUPERSEDED`/`REJECTED`）、commit 仍可达、提出方未撤回、基线未失效 |

⚠ **核对的对象是 commit 与候选状态，不是分支。**分支是可移动的运输通道，
「commit 还在某分支上」既**不必要**（可达即可核对）也**不充分**（分支可被重置或强推）。
把开发侧迟到写成租约，会让人误以为有一个运行时会自动拒绝迟到写入——没有。

取消：先持久化意图，再停止调度、撤销租约、终止执行、盘点副作用、固定需保留的 commit 和
Artifact，最后回收 worktree/sandbox。**取消与完成只能一个终态胜出。**
产品面的过期写入应由 fencing 拒绝；**开发面（分支、worktree、发布路径）没有等价运行时机制**，
只能靠条件式发布和整合方核对挡住，因此**开发侧的取消必须显式停止执行者，不能只靠标状态**。

### 3.10 物化门禁与写入前门禁

> 依据的通用规范：[IMP「两道门禁」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

**两道门，时机不同：物化门禁在第一个 Attempt 启动前，写入前门禁在每次落笔前。**

**物化门禁（首个 Attempt 启动前必须证明）：**

1. Task 契约已可靠持久化；
2. workspace **唯一归属本 Task**，路径、配额和回收策略明确；
3. source ref、Artifact 摘要、commit 和 gitlink 可取得；
4. 初始 `git status` 符合 Profile，预置脏文件均有解释；
5. 指令范围可由目录层级确定；
6. 凭据、越权数据和无关材料未进入版本库；
7. **manifest 与实际文件一致**；
8. 工具、权限和预算不超过 Task 授权；
9. owner、独占可写根、候选产出位置和唯一 integrator 已明确；
10. **共享发布面为只读**，除非当前 Attempt 正是获准的整合 Attempt。

⚠ 失败时**不得把半成品工作区交给执行者「尽量执行」**。重试复用 Task 身份但**建立新
Attempt**，并隔离或安全清理残留 workspace。

**manifest 证明实际给了什么**（Task 决定该给什么，manifest 证明给了什么）：

```text
task_id, workspace_id, created_at        run_id, owner_id, work_unit_id, attempt_id
source repository + commit / gitlink     artifact source + digest + destination + access mode
generated task package + profile version effective instruction files and scope
excluded material + reason               secret references (never values)
initial commit                           writable roots + output namespace
publication target + integrator
```

⚠ **材料在工作区内可见，不自动构成使用授权。**有效权限仍由 Task、Profile、工具策略和
当前批准共同决定（[§4.5](../../../agent-dev-guide.md) 的交集公式）。**上一 Task 的工作区不得在未重新受理、授权和物化的
情况下复用给下一 Task。**

**写入前门禁（一票否决）。**动手写任何文件之前逐条核对，任一不成立则**停，不写任何文件**：

1. `cwd == workspace_path`；
2. 当前分支 `== exclusive_branch`；
3. 目标路径不在禁写集内，且**解析软链、`..` 和挂载别名后的规范路径**仍落在获准的
   writable root 内；
4. 目标路径上**没有他人产物**；若有，不覆盖——先让对方的内容形成可达 commit 或备份；
5. 本次**不是宽泛写入**（批量生成、`>` 重定向、脚本 sweep、先 `rm -rf` 后重建）；
   确需宽泛写入时收窄到明确路径逐个执行。

⚠ **这五条不是建议。宽泛写入和「路径归属不明仍继续写」是覆盖事故的两个主因**，
两者都发生在**写入前**，而事后恢复（§3.8）代价远高于停一次。

**冷启动核对（每次 Attempt 开始时）：**Task/Attempt ID、租约、fencing、预算与停止条件；
原始请求、范围、验收、批准点与预期 Artifact；当前目录、仓库根、分支、HEAD、子模块与
工作树状态；manifest 的输入、摘要、基线与实际文件；生效的 `AGENTS.md` 与目标代码附近测试；
依赖、权限与外部系统是否仍有效；**哪些判断是事实、推断、假设、缺失或尚未验证**。
不匹配会改变结果时**停止并发起 Interaction**——不得在错误仓库、错误分支、过期 commit
或失效租约上继续。

### 3.13 执行形态、停止规则与成本

> 依据的通用规范：[IMP「执行形态、停止与成本」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

档位（[§3.4](../../../agent-dev-guide.md)）定 guard，**执行形态**定这一次实际怎么排人：

| 形态 | 适用条件 |
| --- | --- |
| 单路实施 | 解法明确、局部、可被测试充分判定 |
| 定向审核 | 已有唯一产物，只需独立判断 |
| 最小选优 | 需要独立候选，但无需完整评审团 |
| 完整选优 | 解法不明确、跨层/跨仓、错误代价高 |
| **胜者改进** | 主线已选，只吸收独立局部优点 |

⚠ **选形态的人不能顺手改上层决定**：不得改动已落账的 RouteDecision、降低硬门禁、
换执行器、扩大权限或增加总预算（§4.9）。

**停止规则（六条）：**

- 使用**足以产生独立信号的最少候选**；
- 顶层验收满足后，其余在途单元停止、取消或降为**无副作用只读参考**；
- 连续一轮没有关闭阻断问题或新增可验证价值时**停止**；
- 达到轮次上限仍有结构分歧时，**请 principal 裁决或重开 Task**；
- 单元耗尽预算**不得静默借用**；
- 协调者退出前留下可恢复 checkpoint。

⚠ **「已派工」「全部返回」「多数一致」都不等于完成**（[§3.12](../../0004-acceptance-commit/SDD/agent-dev-guide.md)、§11）。

**成本纪律：**

- 资源上限、超时、外部副作用和人工批准点**必须在启动前写入任务包**；
- **完整交叉阅读是二次复杂度**——候选较多时采用平衡分配，但**每个候选获得相同评审覆盖**；
- 无法运行命令的评审保留价值，但**必须标注「未经事实验证」**，且不能替代验收方的运行结果；
- 自动化必须保证**单路失败、超时或缺席也进入记录**，不能由成功路线覆盖。

### 3.14 建立 worktree 的细则

> 依据的通用规范：[IMP「工作区」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

- 每个并行单元**独立分支、独立可写 worktree**；候选从同一冻结 commit 开始；
- ⚠ **同一分支不能被两棵 worktree 同时检出**——Git 会拒绝第二处，这是机制不是约定；
- ⚠ **worktree 只隔离写入，不阻止读取共享 Git 对象**，隔离强度要在登记表里说明（§3.2）；
- 多仓单元固定每仓 commit 和父仓 gitlink；
- ⚠ **租约、凭据和产品状态不得提交进分支**；
- 建立、归属、基线和清理状态进入 manifest（§3.10）；
- ⚠ **删除 worktree 不等于删除证据**——commit 必须仍然可达；
- `master/main` 与其他共享分支**默认不是候选写入面**；
- 即使多个候选修改同一相对文件，也各自在自己的分支/worktree 里改；
- **只有 integrator** 在独占整合 worktree 中写最终路径并形成 final commit。

### 3.20 工作区能写，不代表 Git 能提交

> 依据的通用规范：[IMP「工作区」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

供给阶段同时检查文件写入面和 Git 元数据写入面。先在获准目录只读执行：

```bash
git rev-parse --show-toplevel
git rev-parse --git-dir
git rev-parse --git-common-dir
git status --porcelain=v1
```

任一身份/仓库判别失败立即报错，不通过吞退出码的管道生成假名字，
也不根据产品、模型或界面猜“我是哪个参与方”。工单中的执行者 id、登记的工作区归属、
实际仓库根应一致；目录名是本地归属线索，**不是经鉴别的 principal 身份**。

历史源稿记录了三个结果：共享 worktree 的 Git 元数据可能位于获准工作区外；
改成独立 clone 后，若沙箱仍把 `.git` 设为只读，同样不能提交；
私有 clone 加明确的私有 Git 元数据写权限才在那次实验中通过。
⚠ **这是原作者在特定沙箱的实验记录，本次未复跑，不能外推所有执行环境。**

因此实际采用什么布局，要由当前权限配置与一次获准的可丢弃提交实验验证。
不能为修一家提交失败而放开全体共享的 objects/refs；若需改变布局或可写根，
由供给方在既有授权内处理，受平台权限限制的操作仍遵循该平台的批准机制。
不得靠反复换工具、偷偷改权限或给整个主仓 `.git` 开写来绕开隔离。

执行者能写文件但不能提交时，保留在其私有工作区，报告内容摘要、基线和阻断原因，
由已获授权的组织者代提交。代提交必须区分 author 与 committer，记录内容作者、
代提交者、原因和 SHA-256，并计入人工传输成本。代提交只改记录方式，
不把可任填的 Git author 升为身份认证，也不把未冻结文件冒充已交卷。

### 3.22 停止、超时与回退不能省略

> 依据的通用规范：[IMP「执行形态、停止与成本」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

异议采纳且触及结构、验收失败、principal 打回，都回到③，重新冻结与验证；
同一次竞争回退超过两次就停止重整合，回到问题和标准本身确认，不无限重试。
预算停止规则仍见 §3.13；不通过向参与方施加模糊时间压力来换取缺证据的半成品。

逾期使用已冻结的可观测判据。观察窗 `W` 由本次竞争实际交付用时的中位数得出，
不能拿一个临时秒数冒充；数据不足算不出 W 时，记录“不可判”并按已批准的停止规则处理，
不得自行据时钟宣布弃权。

| 观测 | 允许的结论 |
| --- | --- |
| 产物字节或分支提交仍增长 | 正在推进，不因派生时间线到点就宣布逾期 |
| 连续 W 内产物字节与分支无变化 | 可按冻结的停滞判据处理，附两次观测与 HEAD |
| 零产出且 CPU 时间增量、输出增量均为零 | 联合信号可提示卡住；CPU 绝对值为零不能证明未启动，等待网络也可能如此 |
| 没有足够观测或观察窗无依据 | UNKNOWN，不是弃权、超时通过或同意 |

延长观察窗可记录后执行，缩短须 principal 确认。宣布逾期前实际运行判据并保存观测。
各环节后果不同：①不交则候选数减少，降到一家时停下；②评审不计但候选仍在池中；
④未响应按协议记弃权，**不是认可**；⑤验收方不可用则按同一算法换人；
⑥没有逾期默认，未经确认就不发布。只有冻结协议已允许的缺席处理才能直接执行，
额外免除参与方仍属 H3，不得把“超时处理”用作绕开授权的理由。

### 4.9 Attempt 内的三条硬禁令

> 依据的通用规范：[产品合同「Attempt 内的三条硬禁令」](../../../../../../../../product/product-contract.md)

上层路由完、权限收窄之后，Attempt 内还需要**可执行的边界**——抽象声明容易被绕过。
任一条被突破即为越权，按 `I3`、`I10`、`I15` 与 constraints A2/A4 处理：

| # | 禁令 | 具体形态 |
| --- | --- | --- |
| 1 | **不得改路由** | 执行器种类在 Attempt 创建时钉死并落账；不得因为「这个单元更像财务」而在 Attempt 内改投另一条腿 |
| 2 | **不得换执行器** | 不得在 Attempt 内自行构造新的 runtime 客户端实例绕开已固定的 Adapter；换腿只能由上层**新建 Attempt** |
| 3 | **不得扩权** | 不得重新注册已被 deny 的工具，**不得把 `human-approval` 降级为执行器默认的自动批准**，不得追加预算 |

⚠ **第 3 条的现实动因见 §2.7**：Codex Python SDK 的默认审批处理器对命令执行与文件改动
一律返回 `accept`，而**该兜底发生在构造函数里**——

> **「忘了传 handler」与「故意选自动批准」在代码里长得一样。**

所以这条**必须由 Adapter 强制显式传入 handler，不能靠纪律**。这是「机制优于自律」
在本文里最具体的一处落点。

### 4.13 执行器凭据、子进程与跨腿委派

模型推理经过平台 egress proxy；真实 provider key 只在代理/Secret 边界，
不下发 Codex 或 Harness 执行器进程。Attempt 只取得短 TTL、可撤销的网关令牌，
绑定 `attempt_id + executor + model_allowlist + tenant/actor + budget + deadline`。
取消、失租、预算耗尽或终态立即 revoke；恢复前重新准入，不复用过期令牌。

工具凭据由 host-side gateway 按实际调用解析，不进入 prompt、普通环境回显、checkpoint、
日志或 Artifact。通用 worker 不持有专业数据凭据，专业 worker 不持有通用 provider 凭据。
这落实 [§4.6](../../../agent-dev-guide.md) 的 Scope 与 Policy；**只写“两类 worker 互斥”而不管子进程继承，边界仍会漏**。

**spawn 前洗环境。**执行器子进程只继承明确白名单变量，数据库、Redis、消息队列凭据不下发；
白名单是版本化配置，要落账并由测试断言。限写不等于限读，继承父进程全量环境会把业务凭据
暴露给执行器，即使其工作区是只读也不能消除这个问题。

**Adapter 禁止未经上层路由的跨腿委派。**历史 Harness 调查记录了 `subagent-codex` 这类嵌套入口，
可在专业腿内再启通用执行器；⚠ 本次没有重验该 SDK 能力。无论实际插件叫什么，
不得让内部 spawn 绕过已冻结执行器、预算和凭据互斥。确需换腿或跨腿协作，由上层新建
RouteDecision/Attempt，经过正常能力、权限、预算和数据门，不在现有 Attempt 内偷偷造客户端。

父预算覆盖全部 Attempt、Work Unit、工具、评审与改进。Side Effect 用稳定幂等键进入持久账，
保留意图、目标、状态、回执和补偿引用；重试、恢复或取消前先查账，不能从 Git 或进程退出码
猜某项外部动作是否已发生。这些均是执行器接入门禁，不是本次已完成的部署能力。

### 5.6 `F-EXEC-*` / `F-INTERACT-*` 双腿落地矩阵

状态按 §2.8 的三态探针标注。⚠ **探针词与「已支持 / 需补法 / 当前缺失」的对应固定如下，
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

⚠ **这张矩阵是 §2.7 那张表在内核功能 ID 上的投影。**两张表口径必须一致：
`F-EXEC-03` 的 Harness 腿判 `explicit_unsupported`，依据就是 §2.7「交互批准」那一行。
**升级钉版时两张表必须同时重跑。**

### 7.5 跨运行时 thread 续接

> 依据的通用规范：[IMP「跨运行时 thread 续接」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

⚠ **判据只有一句：把今天的记忆抹掉，另一个人只读持久载体能否接着做？不能，就是没落盘。**

- 当前推进哪件事、卡在哪、下一动作，由任务目录（`thread/`、`composition/`、`components/`）推出，不落在脑子里；
- **「不能倒退的输入」必须写下来**——已经定过的事下次不重新讨论，写进定稿（[`composition/`](../../../../../../architecture/README.md)），派工时写进 turn 的 `user-message.md`；
- 停下来之前，先让任务目录能回答：「接手的人一分钟内要知道什么？」

⚠ **交接投影不是第二真源**，不得在 `user-message.md` 或 turn 里复制整张覆盖矩阵。
checkpoint 是恢复输入，不是第二份代码真源，**也不保存凭据**。

⚠ **`composition/` 与各 turn 的 `user-message.md` 是单写者面。**多名执行者并行时只有派工的一方（协调者）写它们，各执行者只交回到自己的 turn，
进度写在**自己的 worktree** 里。判据不是「内容重不重要」，而是
「同一事实只能有一个权威写入者」（`I13`，[§1.2](../../../agent-dev-guide.md)）——**多人各自往同一份定稿 追加，
就是在共享路径上并发写**。

同一判据对 agent 与人都成立，只是理由不同：**agent 是记不住，人是记得但传不出去。**

checkpoint 至少保存下面这些恢复输入，可用持久记录中的引用避免重复事实：

```text
task_id, attempt_id, work_unit_id, owner_id, workspace_id
current_commit, baseline_commits, runtime_version, profile_version
completed_scope, remaining_scope, decisions + evidence_refs
commands/tests + raw_output_refs, budget_consumed + remaining
side_effects + idempotency_refs
output_namespace, publication_target, integrator
blocker, next_action, facts_to_revalidate
```

恢复前重新确认 Task 未终态、当前授权仍有效、租约/fencing 有效、输入/基线/依赖未漂移，
并先查预算与副作用账；失租的执行者不能因拥有 checkpoint 继续写。
现场快照的 digest 与 runtime/Profile 兼容性按 §2.10 校验；只能在新获准可写面恢复，
不可把旧会话的权限、已消费批准或未提交动作直接当成仍有效。

### 7.6 执行器架构的未验证清单

⚠ **§2.6–§2.10 描述的执行层，在本清单清空之前一律按 `defined` 对待**（[§5.8](../../../agent-dev-guide.md) 四级词典）。
本节只登记「未验证」；「已知不支持」在 §5.6 矩阵里，两者不可混。

| # | 未验证的事 | 位置 | 验证方式 |
| --- | --- | --- | --- |
| 1 | 两条执行腿的部署门禁与 Harness wire 门禁**均无运行证据** | §2.6、§2.9 | Gate 0 spike |
| 2 | 「租用 loop、自建控制面」的硬条件全部未实证 | §2.6 | Gate 0 spike，逐条给退出判定 |
| 3 | Harness sdk-runtime wheel 能否从**内网 PyPI 镜像**取得 | §2.7 系统 Node 行 | 供应链验证，非文档问题 |
| 4 | worker egress 的包级验证**在 KIND 上不成立** | §2.10 | 另起 Calico 环境实测 |
| 5 | 双 runtime 峰值内存与 prefork 并发的**实测值** | §2.10 | 负载测试后再定 requests/limits |
| 6 | Codex async 客户端在并发/teardown 下的行为 | §2.10 | 负载与故障注入，**不得由 `async` 关键字推断** |
| 7 | **未跑过任何 SDK 端到端**、未联调 OpenClaw、未做故障注入 | §2.6–§2.10 全部 | Gate 0 |
| 8 | 多租户配额的产品语义尚未设计 | 本条即登记 | 属产品契约侧 |

⚠ **本清单不是免责声明。**它的用途是：读到 §2.6–§2.10 任何一节时，能立刻判断那一节是
`defined` 还是 `runtime-verified`。**清单为空之前，那五节描述的是目标形状，不是现状。**

## 11. 反模式

> 依据的通用规范：[IMP「反模式」](../../../../../../../../dev-agent-standards/imp/imp-rules.md)

**这一节是机制描述，不是训诫。**每行左边是做法，右边是它**怎样失败**——
没有失败方式的条目不该进表。与 [§8](../../../agent-dev-guide.md) 的区别：[§8](../../../agent-dev-guide.md) 是本项目**已被推翻的设计**，
本节是**任何项目都会踩的做法**。

| 反模式 | 失败方式 |
| --- | --- |
| 只保存整理稿，不保存原话 | 原始意图不可追溯（违 `I1`） |
| Task 未落库就建仓或调度 | 无主 sandbox、不可恢复执行 |
| 把所有资料塞进工作区 | 越权、泄密、上下文污染 |
| 执行者猜仓库、分支或目录 | 修改落错可写面 |
| 在获准工作区之外另建仓 | 绕过供给、授权和回收 |
| **会话隔离当作文件隔离** | 多个执行者仍写同一物理文件，**最后保存者覆盖前者** |
| **用 `-new` / 时间戳 / 执行者名当隔离** | **文件名不是工作区。**共享路径上照样后写覆盖先写，且制造虚假安全感——以为改了名就安全，于是继续都写同一个目录 |
| 把人的主 checkout 当文档原件投放点 | 既覆盖人的未提交改动，也覆盖其他执行者的草稿；**被覆盖方无痕消失** |
| 未提交就让别人到「同一路径」接盘 | 拷走的是没有归属的污染源，**接盘者不再是独立候选** |
| 交卷报路径不报 commit | 路径会漂移、会被覆盖，**评审对象丢失** |
| 每个执行者都改共享的 `user-message.md` 或 `composition/` | 单写者面被互相覆盖，定稿失真 |
| 所有候选直接写用户指定的最终路径 | **路径成为竞态，选优在写入时被偷偷决定** |
| 多个执行者直接改 master/main | 未经整合的草稿互相覆盖并污染发布面 |
| 发布时不校验目标 HEAD/version | 新结果静默覆盖别人的更新，或旧结果覆盖新结果 |
| non-fast-forward 后 force-push | **用运输命令抹掉并发历史和已评审对象** |
| 用 mtime 判断作者或采用版本 | 时钟和后续复制会误导溯源，provenance 丢失 |
| 未跟踪文件作为唯一交付 | 无 commit/digest，覆盖后难以恢复和归因 |
| 并行单元共用工作树 | 相互覆盖、无法归因 |
| 候选读取其他候选 | **独立信号退化成改写** |
| 候选阶段偷看发起方倾向 | 同上；候选向倾向收敛，选优失效 |
| 作者自评自收、自我批准 | 同一判断链为缺陷背书 |
| 候选人互投制造独立性 | 被审方兼任判定方，**独立性是假的** |
| 多数票覆盖失败测试 | 偏好压过事实 |
| 全体一致的共同盲区 | 多个相似模型可能共享盲区，一致不等于正确 |
| 只固定分支名 | 评审对象漂移 |
| 冻结后原地替换，或把迟到 commit 算进本次比较 | 比较对象漂移，无法复核 |
| final commit 不回归 | 整合缺陷未被发现 |
| 大补丁混合多条主张 | 无法逐条处置，接受与拒绝被绑在一起 |
| 把会话记忆或人脑当状态账 | 接手者无法恢复现场，决定无痕丢失 |
| 只靠自律执行纪律 | **换人或换会话后纪律蒸发** |
| Git 充当授权、预算或副作用账 | 恢复后越权或重复动作 |
| 删除分支/worktree 前不建立持久 ref | commit 变成不可达对象，可能被回收 |
| 复制文件代替整合记录 | 内容存在但来源、取舍和验证对象不明 |
| 「已派工」或「全部返回」当作完成 | **内部动作冒充用户结果** |
| 成功后立即删工作区 | commit 和证据丢失 |
| 静默扩大范围 | 越权副作用无人批准 |
| 伪造完整结果掩盖缺口 | 验收被污染，缺口被当成已完成 |
| 通知失败改写终态 | Delivery 故障污染结果 |
| 人当协调者就跳过隔离与角色分离 | 独立信号退化成改写——**协调者身份不豁免纪律** |
