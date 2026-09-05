参与方：luna｜worktree：/home/zym/worktrees/luna/k8s｜HEAD：4513bcbd6a47b9032f2db31d614430947c29fa5d
# 产品运行时架构：一个内核、版本化任务契约与分级证据

> 候选稿。对象内核锚定 `working/request-lifecycle.md@70a7dd50`（647 行，
> sha256 前 16 位 `6fcd3973ede30b88`）；上一轮输入锚定
> `refact-fable.md@7e8464c2`（927 行，sha256 前 16 位 `89303624bfd9ef27`）。
> 本文不直接修改这两份输入；内核改法以规范修订工作单元描述。

## 0. 结论

系统只有一个产品运行时、一组 Task / Attempt 状态与合法边。开发不是运行时旁边的另一套流程，
而是 `dev.change.v1` 这个 Task Profile；五家助手是五个 Agent Profile。今天由人和 shell 驱动，
目标态由服务驱动，二者只替换 orchestrator 与持久载体，不改变对象、边、Interaction 形状和权力。

本方案的三个关键判断是：

1. “轨迹四要素”适合做核心等效比较，但单独不足以证明语义等效；必须同时钉住契约、策略、
   身份与副作用摘要，否则两个同形轨迹可能一个获权、一个越权。
2. Interaction 的响应不是“令牌已消费”，而是一份有作者、有版本的决议；`amend` 必须物化成
   新 Artifact 版本并成为后续 Attempt 的输入，不能另建 Task 来躲开原 Task 的历史。
3. 证据权威性不是文案属性，而是观测链的函数。只看到进程或文件前后差异时，执行者自报不采信；
   当前所有者与 agent 共用身份且没有隔离操作面，批准者身份权威性应明确记为 `UNVERIFIED`，
   不能被一个 commit 粉饰成已验证。

## 1. 一个运行时与唯一状态机

### 1.1 对象边界

唯一内核直接采用 `request-lifecycle.md@70a7dd50` 的对象：Task、Attempt、Interaction、Artifact、
Event、Side Effect、Delivery、Task Profile、Agent Profile；两种 Profile 的定义分别见该文件
`:103-104`。状态也只采用该文件 `:194-244` 的集合与合法边：

```text
Task = RECEIVED | VALIDATING | QUEUED | RUNNING | WAITING
     | SUCCEEDED | REJECTED | FAILED | CANCELLED

Attempt = CREATED | RUNNING | WAITING
        | COMPLETED | FAILED | CANCELLED | BUDGET_EXCEEDED
```

工单、候选、评审和代码提交都是 typed Artifact；一家的某次起草、评审、裁决或验收是 Attempt；
轮次名和环节号是 `dev.change.v1` 的策略字段及投影，不是新状态。Task 与 Attempt 不能合并，
因为一次 Attempt 失败不自动结束 Task（`request-lifecycle.md@70a7dd50:111-121,341-347`）。

开发代码仍可存在 Git 中，但 Git 只承载代码 Artifact；它不再兼任 Task 状态账、批准账与 Event 账。

### 1.2 开发 Task Profile

```yaml
profile_id: dev.change
version: 1
input:
  schema: WorkOrderV1
  required:
    - original_request
    - normalized_goal
    - scope
    - baseline_refs
    - acceptance_contract
    - requested_side_effects
output:
  schema: ChangeResultV1
  required:
    - candidate_artifacts
    - accepted_artifact_versions
    - acceptance_results
    - evidence_refs
    - side_effect_summary
acceptance:
  rule: frozen WorkOrderV1.acceptance_contract
  independence: acceptor_attempt != producing_attempt
evidence:
  claims_must_reference: EvidenceRecordV1
  authority_floor: derived from selected AgentProfileV1
policy:
  tier: T0 | T1 | T2
  retry: versioned
  budget: task-wide across all attempts
  approvals: versioned authority rules
  isolation: proposal attempts cannot read sibling proposal artifacts
```

`TaskProfile(dev.change,1)` 固定用户要得到什么以及怎样验收；它不登记某家模型的工具。
Agent Profile 固定谁能怎样执行。每个 Task 固定前者版本，每个 Attempt 固定后者版本，符合
`request-lifecycle.md@70a7dd50:487-505` 的边界。

T0/T1/T2 只是本 Task Profile 的策略档：它们选择 Attempt 拓扑、必需 Artifact、guard 和预算，
不改变状态词。当前 `round-protocol` 的提案、互评、裁决、异议、验收、确认、清理可分别投影成
一组 Attempt、Interaction 或 Side Effect；回退创建新 Attempt，绝不重开已终态 Attempt。

### 1.3 人的地位与权力

人是 principal，不注册为 Agent executor。Agent 产生方案；principal 经 Interaction 行使批准、否定、
修订、取消和授权权力。运行时的状态转换器是唯一写状态的组件，人和 agent 都不能直接写状态。

每次人的介入都必须引用下表恰好一行。`decision=amend` 覆盖“部分否定”与“采用人的方案”；
三者都保留原 Task，只改变输入 Artifact 版本。

| 权力 ID | 人的动作 | 当前等待 | 唯一合法恢复边 | 结果 |
| --- | --- | --- | --- | --- |
| `AUTH-CONTRACT` | 补充或修订尚未冻结的完成契约 | `WAITING(INPUT)` | `WAITING → VALIDATING` | 新 WorkOrder Artifact 版本，重新校验 |
| `AUTH-PLAN` | `approve` 一份执行/分发/分析计划 | `WAITING(APPROVAL)` | `WAITING → QUEUED` | 原计划版本进入下一 Attempt 输入 |
| `AUTH-AMEND` | 部分否定或提交替代方案 | `WAITING(APPROVAL)` | `WAITING → QUEUED` | principal 所著的新计划版本进入下一 Attempt 输入 |
| `AUTH-REJECT` | 全部否定且不再给成功路径 | `WAITING(APPROVAL)` | `WAITING → FAILED` | 记录拒绝理由与已发生副作用 |
| `AUTH-BUDGET` | 在原目标内追加预算或执行范围 | `WAITING(APPROVAL)` | `WAITING → QUEUED` | 新策略版本进入下一 Attempt 输入 |
| `AUTH-EFFECT` | 批准不可逆 Side Effect | `WAITING(APPROVAL)` | `WAITING → QUEUED` | 后续 Attempt 执行动作；不得直达成功终态 |
| `AUTH-CANCEL` | 取消 Task | 任一非终态 | 该状态 `→ CANCELLED` | 先落取消意图、fencing 与副作用收敛 |

若人的新要求修改目标、口径、授权范围或 Task Profile 版本，则不属于上表的 in-Task 修订，
应按 `request-lifecycle.md@70a7dd50:292-301` 建立带 `supersedes` 的新 Task。

### 1.4 bootstrap 与目标态是同一契约的两种实现

| 不变量 | 今天 | 目标态 |
| --- | --- | --- |
| Task Profile | `dev.change.v1` | `dev.change.v1` |
| orchestrator | 人运行确定性 shell 脚本 | 运行时服务运行确定性状态转换器与 outbox worker |
| Task/Event/Interaction 载体 | Git 文件与 commit 的临时投影 | PostgreSQL 事务账 + 对象存储 |
| 代码 Artifact | Git commit | 仍可为 Git commit，由 Artifact 表保存不可变引用 |
| executor | 现有 CLI/GUI 助手 | SDK executor 或受外层约束的 CLI bridge |
| 人的动作 | 手工投喂、手工回话 | Interaction API/UI；权力不变 |

允许载体和可观测粒度不同，不允许状态、边、对象关系、Interaction 双向形状及权力位置不同。
因此迁移不是把历史文件名硬塞进数据库，而是对同一 schema 做两个 adapter，并对相同 WorkOrder
比较规范化 trace。

Git 生命周期脚手架按能力逐项拆，不设“一键毕业”口号。全部满足才停止用 Git 判生命周期：

1. 状态转换器从同一机器可读 schema 校验所有 Task/Attempt 边，终态 CAS、租约和 fencing 测试通过；
2. Interaction v2 能完成 `approve/reject/amend`，并通过重复、过期、异主体、跨 Task 与 stale version 测试；
3. Artifact/Event/Side Effect/Delivery 均有权威表，服务重启后可重建非终态 Task；
4. `dev.change.v1` 至少各重放一个 T0、T1、T2 历史样例，除明示允许差异外 trace 等价；
5. 所有仍在用的 executor 都有可执行 adapter；无命令入口者要么经显式 `human_bridge` 产生可审计 Delivery，
   要么从可路由集合移除，不能靠不可见手工粘贴冒充自动分发；
6. 权威写入面拒绝无 `task_id/attempt_id/side_effect_id` 的发布，绕过扫描能在外部账上发现漏项；
7. 旧脚本进入只读回放期一个观察窗，期间没有只被旧判据发现的新事实。

拆除后仍保留 Git 代码历史和只读历史 adapter；删除的是“Git commit 等于运行时状态”的职责。

## 2. 可执行的等效判据

### 2.1 Trace schema

核心 trace 恰含题目要求的四个有序序列：

```text
TaskStatePoint = {
  seq, state, state_version, event_id, cause_ref
}

AttemptStatePoint = {
  seq, attempt_id, state, executor_profile_id,
  input_artifact_versions[], event_id
}

InteractionPoint = {
  seq, interaction_id, expected_state_version, audience,
  outbound: {
    requested_action, artifact_id, artifact_version, artifact_digest,
    render_mode, editable_scope[]
  },
  inbound: {
    decision, response_artifact_id, response_artifact_version,
    response_digest, authored_by
  },
  resume_target
}

ArtifactVersionPoint = {
  seq, artifact_id, artifact_type, version, digest,
  authored_by, source_attempt_id, supersedes_version
}
```

比较前去掉允许变化的物理字段（表名、文件路径、进程 PID、时间戳、executor 的内部 tool-call 数），
保留状态、边、对象引用、载荷摘要、作者 principal/Agent Profile、权力 ID 与因果顺序。

`TraceEnvelope` 还必须固定 `task_profile_id/version`、`acceptance_contract_digest`、
`policy_version`、principal 身份域、输入摘要、Side Effect 摘要及 Evidence authority 摘要。
它不是第五个序列，而是防止错误等价的比较上下文。

判定算法：

1. 验证每个状态属于上述唯一集合，每条相邻边属于内核合法边；
2. 对四序列分别做稳定排序和允许字段归一化；
3. 比较序列长度、标识映射、状态、载荷 digest、作者、引用与因果边；
4. 比较 TraceEnvelope；任何不允许字段的差异即 `NOT_EQUIVALENT`；
5. executor 观测粒度不同可以保留为差异，但不得把低权威证据提升到高权威等级。

反例说明为什么只比四序列不够：两次运行可产生完全相同的状态、Attempt、Interaction 与报告版本，
但其中一次用未获权凭据发布到生产。如果不比较策略版本、授权 principal 和 Side Effect 摘要，算法会误报等效。

### 2.2 从 `refact-fable` 真实产物导出的 trace

取件锚统一为 commit `7e8464c2`。该 commit 一次归档最终候选、九份评审、处置与裁定；
因此下表是“可由归档重建的最小 trace”，不是伪称当时已有完整 Event 账。可复跑：

```bash
git show --stat 7e8464c2
git show 7e8464c2:sunmoonai/docs/dev-plan/refact-fable.md | sha256sum
find sunmoonai/docs/dev-plan/rounds/refact-fable -type f -maxdepth 3
```

Task 状态序列（`derived=true`）：

| seq | state | 证据 / cause_ref |
| --- | --- | --- |
| 1 | `RECEIVED` | 追溯起点；原始口头请求未独立归档，`evidence=GAP` |
| 2 | `VALIDATING` | 最终稿修订记录列出 11:30–12:40 的多次契约与方案校验，`refact-fable.md@7e8464c2:5-37` |
| 3 | `QUEUED` | 九份评审对象已经形成；具体分发事件未归档，`evidence=GAP` |
| 4 | `RUNNING` | 九份实际评审 Artifact 存在于 `rounds/refact-fable/reviews/` |
| 5 | `WAITING` | 最终评审要求所有者裁定，随后由 R1/R2 记录 H1，`rulings.md@7e8464c2:9-10` |
| 6 | `QUEUED` | R1 记载五家终审结论被处置后恢复；恢复不能从等待直达成功 |
| 7 | `RUNNING` | fable response 与最终候选一并物化，见下表 |
| 8 | `SUCCEEDED` | commit `7e8464c2` 持久化最终候选、评审、处置与裁定；此处仅是历史投影 |

相邻边全部属于 `request-lifecycle.md@70a7dd50:205-209` 的合法边。

Attempt 状态序列（trace-local ID；原系统未持久化 ID 与 started 事件，所以 `CREATED/RUNNING` 为推导，
`COMPLETED` 由归档 Artifact 证明）：

| attempt_id | executor_profile_id | 状态序列 | 结果 Artifact |
| --- | --- | --- | --- |
| `rf-draft-fable-01` | `fable.gui.v1` | `CREATED → RUNNING → COMPLETED` | `refact-fable.md` |
| `rf-review-cursor-01` | `cursor.cli.v1` | `CREATED → RUNNING → COMPLETED` | `review-refact-fable-cursor.md` |
| `rf-review-kimi-01` | `kimi.cli.v1` | `CREATED → RUNNING → COMPLETED` | `review-refact-fable-kimi.md` |
| `rf-review-qwen-01` | `qwen.cli.v1` | `CREATED → RUNNING → COMPLETED` | `review-refact-fable-qoder.md` |
| `rf-final-{cursor,kimi,luna,opus,qwen}-01` | 对应 Agent Profile | 各自 `CREATED → RUNNING → COMPLETED` | 五份 `review-final-*` |
| `rf-disposition-fable-01` | `fable.gui.v1` | `CREATED → RUNNING → COMPLETED` | `review-final-fable-response.md` |

Interaction 序列中能可靠重建的一项：

```yaml
- interaction_id: rf-h1-freeze
  expected_state_version: unknown
  outbound:
    requested_action: freeze-or-return
    artifact_id: solution/refact-fable
    artifact_version: archived-final
    artifact_digest: 89303624bfd9ef27
    render_mode: full+diff
    editable_scope: []
  inbound:
    decision: approve
    response_artifact_id: ruling/refact-fable/R1
    response_artifact_version: 1
    response_digest: ab115a5b2b3a847d
    authored_by: owner-claimed-unverified
  resume_target: QUEUED
```

这里故意把作者写成 `owner-claimed-unverified`：`rulings.md@7e8464c2:9-10` 能证明文本存在，
不能证明操作主体；本轮 R2 进一步确认当前没有 agent 够不着的操作面。`expected_state_version` 也未归档，
所以本历史样例不能通过完整 v2 trace 门，只能用于迁移测试与缺口枚举。

Artifact 版本序列按正文修订记录与归档产物重建；同一 commit 内的精确先后无法由 Git 证明，
故 seq 只表达有文本证据的偏序：

| seq | artifact_id / version | authored_by | 行/字节 | sha256[:16] |
| --- | --- | --- | --- | --- |
| 1 | `solution/refact-fable/archived-final` | `fable.gui.v1` | 927 / 91506 | `89303624bfd9ef27` |
| 2 | `review/cursor/1` | `cursor.cli.v1` | 274 / 17607 | `77df40f4c8aa1622` |
| 2 | `review/kimi/1` | `kimi.cli.v1` | 150 / 10429 | `77a286adac5131d9` |
| 2 | `review/qwen/1` | `qwen.cli.v1` | 210 / 19812 | `b3f2b948b6499bd5` |
| 3 | `review-final/cursor/1` | `cursor.cli.v1` | 156 / 9359 | `3924dc7fa22e0f77` |
| 3 | `review-final/kimi/1` | `kimi.cli.v1` | 96 / 7884 | `1ea1bd0c418519dc` |
| 3 | `review-final/luna/1` | `luna.cli.v1` | 270 / 13469 | `4fe27debcacadf59` |
| 3 | `review-final/opus/1` | `opus.cli.v1` | 203 / 12432 | `a5cccdb1ddffdea1` |
| 3 | `review-final/qwen/1` | `qwen.cli.v1` | 104 / 9611 | `de4c57f3357494ff` |
| 4 | `disposition/fable/1` | `fable.gui.v1` | 97 / 7423 | `e6c8ff4f2426cf70` |
| 5 | `ruling/refact-fable/1` | `owner-claimed-unverified` | 22 / 4787 | `ab115a5b2b3a847d` |

`refact-fable.md@7e8464c2:5-37` 还声称存在五个中间版本，但它们没有分别绑定不可变 commit；
因此不得为它们编造 digest 或作者链。这正是新运行时必须逐版物化 Artifact 的理由。

## 3. Interaction v2：双向、有载荷、有版本

### 3.1 绑定字段

现有字段只有问题、受众、令牌与消费状态（`request-lifecycle.md@70a7dd50:257-265`），不足以表达
“人看的是哪一版、能改哪部分、回了什么”。扩展为：

| 分组 | 字段 | 约束 |
| --- | --- | --- |
| 身份 | `task_id, interaction_id, interaction_schema_version` | 全局稳定；v2 不与 v1 混读 |
| 并发 | `expected_state_version, idempotency_key` | 消费与恢复同一事务 CAS |
| 出向载荷 | `request_artifact_id, request_artifact_version, request_artifact_digest` | 精确钉住展示对象 |
| 展示 | `render_mode` | `diff / full / structured_summary / form`，由 renderer registry 解释 |
| 可编辑范围 | `editable_scope[]` | JSON Pointer、表格 cell ID 或 patch path；空集表示只可整单批准/否定 |
| 动作 | `requested_action, question_or_action, audience, expires_at` | 动作枚举与人读说明并存 |
| 入向决议 | `decision` | 恰为 `approve / reject / amend` |
| 入向载荷 | `response_artifact_id, response_artifact_version, response_digest` | `amend` 必填；其余可存理由 Artifact |
| 作者 | `responded_by_principal, responded_at, principal_channel_evidence_ref` | 不能从 Git author 猜主体 |
| 消费 | `resume_token_hash, consumed_at, consume_event_id` | 一次性、幂等、可审计 |
| 恢复输入 | `resume_input_artifact_id, resume_input_artifact_version, resume_target` | 明确下一 Attempt 实际读取哪版 |

出向载荷引用 Artifact 而不内嵌大正文；Interaction 固定“看哪版与怎么看”，renderer 只负责展示，
不能静默换到 latest。`editable_scope` 的每一项都由 Task Profile 定义，不能由前端自报扩大。

### 3.2 `approve / reject / amend` 的原子语义

响应事务按固定顺序执行：

1. 校验 principal、Task、active Interaction、令牌、期限与 `expected_state_version`；
2. 校验 decision；`amend` 的 patch 每一项必须落在 `editable_scope` 内；
3. `approve` 复用请求 Artifact 版本；`amend` 同时保存 patch 与 materialized content，创建
   `version=n+1, authored_by=<principal>, supersedes=n` 的新 Artifact；`reject` 保存结构化理由；
4. 将决议 Artifact 绑定到 Interaction，原子标记 token consumed；
5. 写恢复 Event，CAS 更新 Task；若继续执行，创建新 Attempt，并把
   `resume_input_artifact_id/version` 放入 `input_artifact_versions`；
6. 通过事务 outbox 投递。投递失败只留下可恢复 outbox，不丢失已经消费的响应。

“部分否定”就是对允许字段提交 `amend` patch；“采用人的方案”是 `amend` 提交完整替代内容，
但仍受 `editable_scope` 和原完成契约约束。目标没变时建新 Task 会切断旧方案、人的修改与新 Attempt 的因果链，
违反 Interaction 边界。只有触及目标、口径、授权范围或 Task Profile 版本才建立新 Task。

### 3.3 必须单开内核规范修订工作单元

这不是 `dev.change.v1` 的私有字段，而是财务分析计划、查询口径确认和动作批准共同需要的内核能力。
按 `request-lifecycle.md@70a7dd50:627-631`，另建规范修订 Task，边界如下：

| 项 | 内容 |
| --- | --- |
| 原始请求 | Interaction 支持被展示 Artifact、renderer、可编辑范围与三值响应；amend 形成新 Artifact 输入 |
| 正文边界 | 修改核心对象的 Interaction 定义、WAITING/恢复协议、持久化记录、F-INTERACT 与验收矩阵；不改状态集合和合法边 |
| API 影响 | response body 从 token-only 升为带 schema version 的 decision + payload/ref；前端新增 renderer registry 与 scope 校验 |
| 存储影响 | interaction 表加出向/入向 Artifact ref、decision、principal evidence；artifact 表支持 supersedes 与 materialized digest |
| runtime 影响 | SDK/CLI adapter 统一消费 v2；Attempt 输入固定修订版本；事件投影与 outbox 同事务 |
| 安全影响 | audience 授权、scope server-side 校验、载荷大小/恶意内容、敏感 diff 脱敏、stale/replay 拒绝 |
| 审计影响 | 证据账记录谁看哪版、怎样展示、改哪处、下一 Attempt 读哪版 |

迁移采用 additive + version gate：

1. 先加 nullable 新列与 `interaction_schema_version`，v1 读取保持原语义；
2. 历史行只在能证明来源时回填 Artifact ref；旧 `question_or_action` 可标成 legacy outbound，
   旧 token 消费只能标 `legacy_resume`，不得伪造 `approve`；
3. 新发布的 Task Profile 版本强制创建 v2 Interaction，旧的活动 Task 继续 v1 到终态；
4. 双读期指标按 schema version 分开，v2 writer 禁止回写 v1；
5. 通过原有 `AT-07`，并新增：三 decision 分支、scope 越界、stale Artifact、响应已落而投递失败、
   下一 Attempt 输入版本、跨 Task/异 principal 拒绝；
6. 活动 v1 归零且回放完成后移除 v1 writer，reader 只为历史展示保留。

## 4. Agent Profile、观测粒度与证据权威性

### 4.1 Agent Profile schema

```yaml
agent_profile_id: string
version: integer
invocation_mode: sdk | cli | gui
dispatch_mode: runtime | human_bridge
observation_granularity: tool_call | process | artifact_delta
runtime_visible_fields: []
isolation_enforcement: runtime_sandbox | outer_sandbox | convention
filesystem_scope: []
network_scope: []
credential_refs: []
allowed_tools: []
tool_policy_enforcement: prevent | audit_after
evidence_policy:
  executor_self_report: reject
  minimum_claim_level: E0 | E1 | E2 | E3 | E4
memory_policy: versioned-ref
supported_task_profiles: []
```

`observation_granularity` 是执行者属性，不是 PostgreSQL 或 Git 的属性。把账本换成数据库不会让运行时
突然看见闭源进程内部工具调用。`F-EXEC-01` 要求只用获准工具（`request-lifecycle.md@70a7dd50:381`）；
在 `process/artifact_delta` 上只能事后审计，不能声称已事中执行。

### 4.2 五家逐条登记

本表只登记本轮冻结事实；五家的调用方式与 fable 无命令入口见
`task.md@runtime/h1:267-275,281-283,352-361`，模型名或 provider 未机械核验者不作能力结论。

| Agent Profile | invocation / dispatch | observation_granularity | runtime_visible_fields | isolation_enforcement | tool_policy_enforcement | 最低可采证据 |
| --- | --- | --- | --- | --- | --- | --- |
| `luna.cli.v1` | `cli / runtime` | `process` | argv、stdin、stdout、exit、workspace before/after | `outer_sandbox`；若未启用则降为 `convention` | `audit_after` | `E2`，结论须另有 `E1` 复算 |
| `kimi.cli.v1` | `cli / runtime` | `process` | argv、stdin、stdout、exit、workspace before/after | 同上 | `audit_after` | `E2`，结论须另有 `E1` 复算 |
| `cursor.cli.v1` | `cli / runtime` | `process` | argv、stdin、stdout、exit、workspace before/after | 同上 | `audit_after` | `E2`，结论须另有 `E1` 复算 |
| `fable.gui.v1` | `gui / human_bridge` | `artifact_delta` | 仅投喂前后文件系统与提交 | `convention` | `audit_after` | `E1`；GUI 自报为 `E0` |
| `qwen.cli.v1` | `cli / runtime` | `process` | argv、stdin、stdout、exit、workspace before/after | `outer_sandbox`；若未启用则降级 | `audit_after` | `E2`，结论须另有 `E1` 复算 |

未来 SDK executor 登记为 `tool_call` 的前提是：每次工具调用都由运行时工具网关发起并写 Event；
只把 SDK 的回调日志转存，不足以升级权威性。

### 4.3 证据等级与采信算法

| 等级 | 观察来源 | 能证明什么 | 不能证明什么 |
| --- | --- | --- | --- |
| `E0 ASSERTED` | executor/principal 自述 | 仅作为待验证主张 | 行为发生、作者身份、完整性 |
| `E1 REDERIVED` | 运行时从冻结 workspace/Artifact 重算 diff、hash、测试 | 重算范围内的结果 | 未覆盖的进程内部动作 |
| `E2 PROCESS_OBSERVED` | 外层记录 argv/stdin/stdout/exit + E1 | 调过哪个进程及其外部结果 | 内部逐工具调用、内部未留下痕迹的出网 |
| `E3 TOOL_OBSERVED` | 运行时工具网关逐调用 Event + E1 | 经网关发生的调用与策略检查 | 绕过网关的系统调用，除非外层同时阻断 |
| `E4 EXTERNAL_AUTHORITY` | executor 凭据域外的受保护日志/签名/审计 API | 指定主体或外部副作用的权威事实 | 人是否充分理解；仍需内容门 |

采信等级是 `min(AgentProfile 可见上限, isolation 实际强度, verifier 独立性, coverage)`；任一字段未知即降级，
不得取平均。所有 `process` 与 `artifact_delta` 执行者的自报证据一律不采信，运行时必须从冻结输入与
workspace 重新计算；复跑命令、工具版本、输入 digest、退出码和输出 digest 一并落 EvidenceRecord。

覆盖声明必须同时列 `checked` 与 `not_checked`。零命中只有在输入集合可枚举且枚举成功时才是 E1；
否则结果为 `UNKNOWN`，不是 pass。

### 4.4 三道外层边界是常驻组件

闭源 CLI 的内部沙箱不由运行时控制，也不构成运行时证据。无论 bootstrap 还是目标态，执行器入口前都有：

1. **文件系统边界**：按 Task 建独立 OS 身份或容器/mount namespace，只挂载 allowlist 子树；
   workspace owner 唯一。SDK 腿由运行时沙箱强制；CLI 腿若只传一个目录但宿主其余目录仍可见，
   `isolation_enforcement=convention`，不能与真实 mount 隔离画等号。
2. **凭据边界**：默认空 env，只按 Attempt 注入短期、最小范围 capability；主线发布、生产写与批准凭据
   不进入 executor 域。env 名单与 capability ID 写 Event，秘密值不写日志。
3. **网络边界**：默认拒绝直连，获准流量经带 Task/Attempt 身份的 egress proxy 或工具网关；
   域名、动作、字节预算与响应摘要落账。无法外层阻断时必须标 `audit_after`，不得声称事中拦截。

provision 函数两边可相同，但后置保证不同：SDK workspace 是 runtime sandbox 内的能力；CLI workspace
只有在外层 OS 边界实际启用时才是隔离，否则只是独占约定。独占防写者冲突，隔离防越界读取，二者不能互换。

### 4.5 R2：零权威回执的极端案例

本轮 `rulings.md@opus:7-14` 记录：本机无签名配置和密钥，所有者与 agent 共用 Git 身份，且当前没有
agent 够不着的操作面。由此推导：

- commit 存在是 E1 的“文本存在”证据，但 `author=owner` 仅为 E0 身份自报；
- 当前 principal channel 应登记
  `channel=shared_git, identity_authority=UNVERIFIED, inaccessible_surface=false`；
- 任何要求 `AUTH-*` 的放行若只有这类回执，状态保持 `WAITING`；若本轮按已裁定 bootstrap 例外继续，
  Event 必须记 `authority_waiver=runtime/R2`、风险、适用 Task 与到期条件，输出不得写“已验证确认”；
- 仅读本机公钥、hook 或校验脚本不能升级为 E4，因为 agent 能改同一信任域内的对象；
- 首个可关闭条件不是“换一把 key”，而是先建立 agent 不可写、不可代操作的 principal surface，
  再以挑战签名和拒写实验验证。

这也规定了人的 Interaction 作者字段为何必须引用 `principal_channel_evidence_ref`，不能复用 Git author。

## 5. 必答 Q：运行时的开销盈亏线

### 5.1 分类规则

工单入站先计算以下布尔特征，不读自然语言观感：

```text
R = requires_resume
I = required_interaction_count > 0
A = expected_attempt_count > 1
P = writable_executor_count > 1
E = evidence_retention != none
S = side_effect_class != none
C = recurrence_key != null
X = external_dependency_count > 0
```

`R∨I∨A∨P∨E∨S∨C∨X` 为真时，运行时通常净成本更低：它复用续接、并行、审批、证据、幂等和恢复账。
全部为假，且 `output_artifact_count≤1`、`estimated_tool_calls≤1`、结果可立即丢弃时，完整编排净成本更高，
应走运行时的 micro path 或在当前 bootstrap 阶段直接调用并明确标为账外。

这条规则机械可判；路由结果必须保存 `matched_features`，不能只写“简单/复杂”。财务数据 Task 即使只问一句，
只要 `E` 或 `X` 为真也不能因文本短而降级。

### 5.2 反例

反例：让助手解释一个报错术语，答案只用于当前屏幕，不写文件、不需引用、不需续接、无外部工具和副作用。
手工直接调用只有“提交问题 → 得到文字”。若完整运行时为它建 WorkOrder、分配 worker、建 Artifact、跑独立验收、
写 Interaction/Delivery 再归档，贵在受理持久化、调度、验收和归档四个额外阶段；这些没有复用价值。

第二个反例是已由确定性 formatter 覆盖的单文件空白修复。调模型、建多份候选或要求人批准，均比直接运行
formatter 更贵；路由应直接选择非 agent 工具执行器，不能为了提高运行时使用率而调用 agent。

### 5.3 T0 开销上界判据

T0 必须同时满足以下可数上界，任一超限就自动升 T1，或判当前 runtime adapter 不合格：

| 指标 | 上界 |
| --- | --- |
| 提交后、稳定结果前的必需人工动作 | 可逆且无副作用为 `0`；请求不可逆发布时最多 `1` 次有语义的 `approve/reject/amend` |
| admission commit 到 dispatch | `1` 次原子事务（Task/Event/outbox 同交）后自动投递；人工复制粘贴为超限 |
| 额外控制 Artifact | 最多 `2`：版本化 RouteDecision 与 AcceptanceDecision；不得强制 Plan/评审文档 |
| executor handoff | `1` |
| producing Attempt | `1`；失败后的自动重试若使总数大于 `1`，从发生时升 T1 |
| 独立验收 | `1` 个机器验收器；不能机械验收的题目不得进 T0 |

Task、输入和结果是产品对象，不计“额外控制 Artifact”；但它们仍必须持久化。人的一次动作必须完成真实选择，
通知送达或敲命令不算决策却仍计动作，防止把传声筒成本藏掉。

### 5.4 绕过的可观测性

运行时账本无法观察自身之外的全部活动，方案不能声称能。可观测性来自独立的权威 sink：

1. 主仓、生产数据库和外部动作网关只接受带有效 `task_id + side_effect_id + capability` 的写；
2. 仓库审计日志、数据库审计和外部系统回执由独立 reconciler 枚举，找不到 runtime Event 的变更写成
   `UnattributedEffect`，不能反向补造一个正常 Task；
3. `bypass_rate = unattributed qualifying mutations / all qualifying mutations`，分母取外部 sink 审计，
   不取运行时自己看见的事件；
4. 只在本地 scratch、从未触及受监控 sink 的手工调用不可观测，明确标 `coverage_gap`。自愿 wrapper、
   shell telemetry 或抽样调查只能给下界，不得报“零绕过”。

在 R2 当前条件下，Git author 无法区分人和 agent，且所有者无隔离 surface，所以 principal bypass 指标为
`UNKNOWN`；仅能按 commit 是否带 runtime correlation ID 统计未归因变更，不能归责。建立外部权威 sink 后才可升级。

## 6. 对 OP-1 / OP-2 / OP-3 的表态

### OP-1：改写

采纳四个核心序列以及允许/不允许差异的方向，但反对把它们单独当充分条件。理由是授权策略与 Side Effect
可在四序列相同的情况下不同，产生“同形但越权”的假等效。本文以四序列 + TraceEnvelope 判定；
TraceEnvelope 只钉比较上下文，不另造生命周期对象。

### OP-2：改写

采纳双向载荷与三值决议，但反对把任意 amend blob 直接塞进 Interaction 行。大载荷、版本和作者属于 Artifact；
Interaction 应保存不可变引用、digest、renderer、editable scope 和消费关系。这样既保持 Interaction 可审计，
又让人的修订成为后续 Attempt 的明确输入。

### OP-3：改写

采纳四问，因为它们逼出成本反例和 T0 上界；但第 4 问若默认“账本能看见账外”会诱发假指标。
正确形式是要求独立 sink 提供分母、声明不可见范围，并允许结论为 `UNKNOWN`。本文按这一更严格口径作答。

## 7. 验收映射、盲区与后续工作单元

| 本轮要求 | 本文落点 | 可判点 |
| --- | --- | --- |
| 一个运行时、开发 Task Profile、五个 Agent Profile | 1、4.2 | `profile_id=dev.change`；五行无空粒度 |
| bootstrap/目标态与拆除条件 | 1.4 | 七项条件逐条有证据才拆 |
| 轨迹四要素与真实样例 | 2 | schema + `7e8464c2` 归档 trace |
| 人的介入映射 | 1.3 | 每次动作引用 `AUTH-*` 与合法边 |
| Interaction 双向与内核修订 | 3 | 字段、事务、边界、影响、迁移、测试 |
| 观测粒度与证据后果 | 4 | 五家登记、E0–E4、R2 |
| 必答 Q | 5 | 分类、两个反例、T0 上界、独立 sink |
| OP 表态 | 6 | 三项均为“改写”且各有理由 |

后续应拆成两个规范工作单元，而不是在本候选直接改只读输入：

1. `interaction-v2`：执行 3.3 的 additive migration，并冻结兼容与 AT 清单；
2. `agent-observation-authority-v1`：把 4.1 schema、证据等级、外层边界和 principal channel 证据写入内核，
   以五家 adapter 加一个 SDK adapter 做契约测试。

盲区与未验证项：

- `refact-fable` 的中间候选没有逐版 commit，Task/Attempt started Event 与 state_version 均缺；2.2 是带 GAP 的追溯投影，
  不是完整等效性通过证明。
- 五家 CLI/GUI 的内部工具调用未读取也不可见；本文不拿自报或休眠代码作能力证据。
- `outer_sandbox` 是目标 postcondition；未做宿主级 mount、网络和凭据拒绝实验前，各 CLI 条目必须运行时降级为 `convention`。
- E4 需要真正位于 executor 凭据域外的 surface；本轮 R2 明确它尚不存在。
- 本文没有重画文件树、重排实施路线，也未处理 `protocol-v2` 的待决项。
