# Request Lifecycle：产品请求生命周期合同

> 最后更新：2026-08-31
>
> **本文是产品目标合同，不是当前能力清单，也不是开发协作流程。**它定义 investment-app 中“前端用户提交 Task，后端受理并
> 调度 Agent，Agent 完成后，结果可靠返回前端用户”的完整生命周期。后续开发，尤其产品
> Agent/runtime 能力开发，必须实现本文规定的功能并遵守本文规定的纪律。
>
> 当前实现事实以代码、迁移、测试、运行结果及
> [`../project-guide/repos/investment-app.md`](../../project-guide/repos/investment-app.md) 为准；发现实现与本文
> 不符时，应建立开发工作单元修代码，或按程序修订本文，不得把目标要求静默降级成当前实现。

## 0. 规范边界与条款筛选

### 0.1 只收产品要求

本文只约束产品中的 Submission → Task → Attempt → Delivery，以及实现该链路的六方：前端、后端、
Agent runtime、Profile/验收器、运维、测试与维护者。开发 Agent 与人的工作流程分别由
[`development-lifecycle-agent.md`](development-lifecycle-agent.md) 和
[`development-lifecycle-human.md`](development-lifecycle-human.md) 规定。

一条要求能否进入产品正文，用下面的问题裁决：

> **它是否必须落实为前端协议、后端持久化、Agent 执行纪律、运维控制或自动验收？**

答案为“否”的内容不得冒充产品要求。仓库、commit、L1–L7 测试层次、Markdown 栏目、worktree
选优等开发字段，只能进入开发 Profile 或 [`development-lifecycle-agent.md`](development-lifecycle-agent.md)。

### 0.2 本文负责什么

本文负责：

- Task 的身份、契约、状态和终态语义；
- Task 与 Attempt/Run、Interaction、Artifact、Event、Side Effect、Delivery 的关系；
- 从提交、受理、调度、执行、中断到结果交付的产品闭环；
- 幂等、授权、预算、副作用、证据、恢复、取消、重试和审计纪律；
- Profile、子 Task 和依赖编排的扩展规则；
- 前端、后端、Agent 的实现责任与验收矩阵。

本文不负责：

- 当前代码已经实现到哪里；
- 具体模型、prompt、SDK、图节点或队列产品选型；
- Git、远端、子模块和跨机操作；
- 开发助手或人怎样提出、实施、评审、批准和交付一项开发工作；
- 某个业务 Profile 的完整业务算法。

这些分别属于 project-guide、具体开发工作单元、现行 Git/协作专门规范、
[`development-lifecycle-agent.md`](development-lifecycle-agent.md)、
[`development-lifecycle-human.md`](development-lifecycle-human.md) 和相应 Profile 规范。

### 0.3 规范用语

- **必须**：缺失即不符合本文；
- **应该**：默认要求，偏离时必须记录理由、风险和等价控制；
- **可以**：合法选项，不构成统一实现要求。

## 1. 生命周期全景

```text
前端用户
   │ ① 提交 Task
   ▼
前端 ──→ ② 后端受理 / 校验 / 授权 / 幂等
                  │
                  ▼
          ③ 持久化 Task / 排队 / 可靠投递
                  │
                  ▼
          ④ Agent Attempt ──→ 工具 / 数据 / 子 Task / 外部动作
                  │                         │
                  ├── ⑤ 澄清 / 批准 ──────┤
                  │       ▲ 前端用户响应    │
                  │       └─────────────────┘
                  ▼
          ⑥ 验收 / 结果与证据持久化 / Task 终态
                  │
                  ▼
          ⑦ 事件回放 / 结果获取 / 通知
                  │
                  ▼
               前端用户
```

生命周期的终点不是“模型返回了文字”，也不是“一条 SSE 消息发送成功”，而是：

1. 最终结果、验收、证据和副作用状态已经可靠持久化；
2. Task 已以唯一合法终态提交；
3. 有权用户可以在断线、刷新或换设备后重新取得结果；
4. 通知失败可以独立重试，不改变 Task 结果。

## 2. 核心对象

| 对象 | 定义 | 必须保持的边界 |
| --- | --- | --- |
| **Task** | 用户提交并等待业务结果的持久请求；本文中的 request | 跨连接、进程和多次 Attempt 存在 |
| **Attempt / Run** | Agent 为完成一个 Task 发起的一次执行 | 一个 Task 可以有零到多次 Attempt |
| **Interaction** | Agent 向用户/审批者请求输入，以及对方的响应 | 绑定 Task、一次性恢复、不可串请求 |
| **Artifact** | 输入、Plan、中间结果、查询、报告、最终结果等稳定产物 | 有类型、版本、所有者和来源 |
| **Event** | Task/Attempt 已发生事实的追加记录 | 只追加；状态与进度由它投影 |
| **Side Effect** | 对数据库、外部系统、消息、交易或文件的写动作 | 幂等、可审计、必要时可补偿 |
| **Delivery** | 向前端呈现状态、事件和持久化结果 | 可重放；失败不污染 Task 终态 |
| **Task Profile** | 某类用户 Task 的输入、输出、验收、证据和策略契约 | 可版本化；不另造状态机 |
| **Agent Profile** | 执行某类 Task 的能力、工具、权限和 memory 策略 | Attempt 固定所用版本；不是 Task 契约本身 |

### 2.1 Task 不等于 Attempt

```text
Task T1
├── Attempt A1 → FAILED(retryable)
├── Attempt A2 → BUDGET_EXCEEDED
└── Attempt A3 → COMPLETED → acceptance passed → Task SUCCEEDED
```

一次投递失败、worker 崩溃、模型超时或验收不通过，只结束对应 Attempt。只有不存在获准的成功路径、
重试策略耗尽，或完成契约已不可能满足时，Task 才进入 `FAILED`。

不得为迁就当前 run 表而合并两者。当前 run 状态机可以作为 Attempt 实现输入，但不能独自定义目标 Task。

### 2.2 Submission 不一定产生 Task

未认证、无法解析或在 Task 身份分配前即被协议层拒绝的提交，只产生安全的协议错误，不进入 Task
生命周期。后端一旦分配 `task_id` 并提交首个事件，后续业务/政策拒绝必须形成可审计的 `REJECTED` Task。

这样既避免把攻击流量和无效载荷强制持久化，也保证已经受理的用户请求不会无痕消失。

## 3. Task 契约

### 3.1 提交信封

前端提交至少包含：

```text
idempotency_key       调用者作用域内稳定
profile_id            Task Profile 标识
profile_version       可请求；最终版本由后端固定
original_input        用户原始文本与结构化输入
attachments[]         稳定引用、媒体类型、大小、校验值
client_context        locale、timezone、展示能力等非授权上下文
requested_deadline    可选
```

后端必须从认证上下文确定 `requester`、`tenant`、角色和数据作用域，不能信任前端自报身份。
幂等唯一性至少包含 `tenant + requester + profile + idempotency_key`。同一键重复且请求摘要相同时返回
原 `task_id`；同一键携带不同摘要时必须返回幂等冲突，不能静默复用或另建 Task。

### 3.2 持久化主档

Task 至少持久化：

```text
task_id, requester, tenant, idempotency_key, request_digest
task_profile_id, task_profile_version
original_input_ref, normalized_goal
state, state_version, created_at, updated_at
acceptance_contract, execution_policy
active_attempt_ids, terminal_result_ref
parent_task_id, coordination_task_id
retry_of, refresh_of, supersedes
waiting_reason, active_interaction_id
cancel_requested_at, cancel_requested_by
```

`state` 是事件流的受约束投影；`state_version` 用于比较交换，防止两个入口同时完成、取消或恢复 Task。

### 3.3 解释、边界与完成契约

Task 进入 `QUEUED` 前必须固定：

- 归一化目标：用户真正要什么结果；
- 包含什么、不包含什么、不包含部分由谁处理；
- 输出 schema、允许的空值和前端 renderer 契约；
- 可判定的 acceptance 条目；
- 新鲜度、质量、证据和引用要求；
- 预算、deadline、重试、停止和取消策略；
- 允许的能力、数据源和外部副作用；
- 必须由用户或授权角色批准的动作；
- 不确定性、降级和部分结果是否允许。

简单 Task 可以从固定 Profile 自动生成契约。只有歧义会实质改变结果、权限、成本或风险时才请求澄清，
不得为填满形式化栏目而反复追问用户。

### 3.4 最终结果信封

成功结果至少包含：

```text
task_id, task_profile_id, task_profile_version
result_id, result_version, result_type
structured_result, human_summary
evidence[] / citations[]
limitations[] / uncertainty
data_as_of
artifacts[]
side_effect_summary[]
accepted_attempt_id
completed_at
```

失败、拒绝或取消结果至少包含稳定错误码、用户可理解说明、是否允许重新提交、已发生副作用及其状态，
以及仅供内部诊断的受限引用。前端文案不能泄露内部异常、路径、凭据或其他租户信息。

## 4. 两层状态机

### 4.1 Task 状态机

```text
RECEIVED → VALIDATING → QUEUED → RUNNING ──────────────→ SUCCEEDED ●
               │          ▲        │
               │          │        ├→ QUEUED       可重试 Attempt 结束
               │          │        ├→ WAITING
               │          │        ├→ FAILED ●
               │          │        └→ CANCELLED ●
               │          │
               ├→ WAITING ┘
               └→ REJECTED ●

非终态收到取消意图后，经安全收敛进入 CANCELLED ●
● = Task 终态，不可转出
```

合法转换只有：

- `RECEIVED → VALIDATING | CANCELLED`
- `VALIDATING → QUEUED | WAITING | REJECTED | CANCELLED`
- `QUEUED → RUNNING | WAITING | FAILED | CANCELLED`
- `RUNNING → QUEUED | WAITING | SUCCEEDED | FAILED | CANCELLED`
- `WAITING → VALIDATING | QUEUED | FAILED | CANCELLED`

任何入口——API、worker、调度器、超时扫描器和人工运维——都必须调用同一转换规则。

| 状态 | 产品语义 | 进入门禁 |
| --- | --- | --- |
| `RECEIVED` | 后端已可靠建单 | 身份、原始输入、幂等记录和首事件已提交 |
| `VALIDATING` | 正在解释目标并检查契约、权限和政策 | Profile 候选与授权上下文存在 |
| `QUEUED` | 已可执行，等待资源或可靠投递 | 完成契约、执行策略、预算已持久化 |
| `RUNNING` | 至少一个有效 Attempt 正在推进 | Attempt 持有效租约，输入版本固定 |
| `WAITING` | 当前没有 Attempt 能推进，等待已知条件 | reason、问题/条件、恢复方式、超时策略 |
| `SUCCEEDED` | 用户结果完成并可重新获取 | 结果先持久化；acceptance 逐条通过；证据合规 |
| `REJECTED` | 已建单但不予执行 | 安全的政策、范围、能力或业务理由已记录 |
| `FAILED` | 已无获准的成功路径 | 失败码、重试判定、Attempt 和副作用记录完整 |
| `CANCELLED` | 有权主体已终止 Task | 取消意图、fencing、Attempt 处置和副作用状态完整 |

`VALIDATING` 与 `QUEUED` 是否直接展示给用户由前端投影决定，但持久化语义不得合并到无法判断
“尚未形成契约”和“已经可执行但未获资源”的程度。

### 4.2 WAITING 与 Interaction

等待原因使用结构化码，不为每种等待另造状态：

- `INPUT`：等待用户补充关键输入；
- `APPROVAL`：等待授权角色批准高风险动作；
- `DEPENDENCY`：等待另一 Task 或依赖条件；
- `RESOURCE`：等待配额、容量、锁或计划时间；
- `EXTERNAL`：等待外部系统或现实事件。

Interaction 必须绑定：

```text
task_id, interaction_id, expected_state_version
question_or_action, audience, expires_at
resume_token_hash, idempotency_key, consumed_at
resume_target
```

恢复令牌必须在同一并发控制边界内完成：校验主体与 Task、校验当前等待动作、检查过期与 stale action、
按幂等键判断重复、原子标记消费、安排后续投递。重复、过期、异键、跨用户或跨 Task 的恢复必须拒绝。

验证阶段等待输入后回 `VALIDATING`；执行阶段等待后先回 `QUEUED`，只有 Attempt 获得有效租约才重新进入
`RUNNING`。Attempt 若从 checkpoint 原地恢复，可在自己的状态机内 `WAITING → RUNNING`。

Interaction 到期不得无事件消失。Task Profile 必须规定超时后关闭该 Interaction，并使 Task 进入
`FAILED`、重新 `QUEUED`、回 `VALIDATING` 或按已批准政策 `CANCELLED`；任何自动选择都必须追加事件并
保留超时原因。

只有没有任何 Attempt 能继续推进时，Task 才进入 `WAITING`；并行 Attempt 仍有一路可推进时，Task 保持
`RUNNING`，等待记录在对应 Attempt。

### 4.3 取消意图与终态

用户点击取消时，后端必须先持久化取消意图，而不是无条件直接写 `CANCELLED`：

1. 校验主体、Task 版本和当前状态；
2. 写入取消意图并阻止新 Attempt；
3. 撤销租约或提高 fencing，拒绝旧 worker 的迟到写入；
4. 停止执行，检查已发生副作用，执行约定的补偿或登记不可补偿结果；
5. 以比较交换提交唯一 `CANCELLED` 终态。

完成与取消并发时，只能有一个终态提交成功。前端可将已记录取消意图投影为“正在取消”，但这不是
第二套 Task 状态。

### 4.4 终态、刷新与重新处理

`SUCCEEDED / REJECTED / FAILED / CANCELLED` 终态不可转出。以下情况建立新 Task：

- 刷新到新的数据时点；
- 修改目标、口径、授权范围或 Profile 版本；
- 重新处理失败、取消或拒绝的 Task；
- 推翻旧决定或要求另一个方案。

新 Task 用 `retry_of`、`refresh_of` 或 `supersedes` 连接旧 Task；旧结果继续保持当时输入、数据时点、
策略和 Profile 版本下的语义。

### 4.5 Attempt / Run 状态机

**Task 层与 Attempt 层是目标实现中必须拆开的两层。**当前 `run` 表和状态词只能作为迁移输入，不能
继续同时承担用户 Task 与单次执行两个角色。跨层引用必须使用 `task.state` 与 `attempt.status`；事件
schema 分字段携带两者，日志和前端投影不得只写一个无层限定的 `status`。

Attempt 可以尽量沿用当前运行时词汇：

```text
CREATED → RUNNING ⇄ WAITING
   │         │
   │         ├→ COMPLETED ●
   ├─────────┼→ FAILED ●
   └─────────┼→ CANCELLED ●
             └→ BUDGET_EXCEEDED ●
```

Attempt 至少记录：

```text
attempt_id, task_id, executor_id, runtime_version
task_profile_version, agent_profile_id, agent_profile_version
input_artifact_versions
lease_owner, lease_expires_at, fencing_token
status, started_at, ended_at
budget_allocated, budget_consumed
failure_code, retryable
checkpoint_ref, output_artifacts
tool_calls, side_effect_refs, evidence_refs
```

必须满足：

1. worker 只有持有效租约和 fencing token 才能写入；过期 worker 的迟到结果被拒绝；
2. Attempt 终态不可重开；重试创建新 Attempt；
3. 同一 Task 是否允许并行 Attempt 由执行策略明确；
4. 首个通过验收的结果胜出后，其余 Attempt 停止或降为无副作用只读探索；
5. `COMPLETED` 只表示 Attempt 产出了候选结果，不自动使 Task `SUCCEEDED`；
6. checkpoint 恢复不得重复已经记账的外部副作用；
7. `BUDGET_EXCEEDED` 是 Attempt 终态。Task 随后按契约进入 `WAITING(APPROVAL)`、重新 `QUEUED` 或
   `FAILED`，不把当前实现的 run 终态无条件提升成用户 Task 终态。

## 5. 七阶段产品功能

本节为可独立实现和验收的功能义务分配稳定 ID。ID 一经发布不得复用或因章节移动而重排；废止要求
保留 ID 并记录替代项。§9 只投影这些 ID 的所有者，不再复制第二套要求。

### 5.1 提交（前端）

前端必须：

- **F-INTAKE-01**：生成并在重试时复用幂等键；
- **F-INTAKE-02**：校验可在客户端安全校验的输入，但不冒充后端授权；
- **F-INTAKE-03**：保存 `task_id` 和最后确认的 event cursor；
- **F-INTAKE-04**：对网络失败使用稳定、可判定的错误类型，只投影后端事实，不创造后端不存在的状态。

### 5.2 受理与校验（后端）

- **F-ADMIT-01**：后端必须在可靠边界内完成认证身份绑定、幂等占位、Task 建单和首事件写入；
- **F-ADMIT-02**：附件必须检查大小、媒体类型、恶意内容和授权；
- **F-ADMIT-03**：输入不合规不得“尽量执行”；Task 建单后的拒绝进入 `REJECTED`，协议层拒绝按
  §2.2 处理；
- **F-ADMIT-04**：浏览器入口与受信服务入口必须共享同一个 application use case，只在接口层解析
  身份。浏览器身份来自登录会话，服务入口使用服务身份和受信委托上下文，不得复制 Task 状态或业务逻辑。

### 5.3 排队与可靠投递

- **F-DISPATCH-01**：Task 进入 `QUEUED` 与 worker 收到消息之间不得有不可恢复丢失窗口；实现必须
  使用事务 outbox、可证明等价的队列事务或未投递 Task 扫描；
- **F-DISPATCH-02**：重复消息按 `task_id + attempt_id` 幂等处理；
- **F-DISPATCH-03**：调度策略必须明确租户公平性、优先级、并发上限、资源配额和 deadline，防止一个
  长 Task 饿死其他用户。

### 5.4 Agent 执行

Agent 必须：

- **F-EXEC-01**：只使用执行策略和 Agent Profile 允许的能力、数据源与工具；
- **F-EXEC-02**：将工具输入输出、模型/工具版本和证据关联到 Attempt；
- **F-EXEC-03**：每次高风险动作前重新校验授权和批准；
- **F-EXEC-04**：持续扣减 Task 总预算，在越限前停止；
- **F-EXEC-05**：将可恢复进度写 checkpoint，不依赖进程内记忆；
- **F-EXEC-06**：区分事实、推断、假设、缺失和不确定性；
- **F-EXEC-07**：无法满足完成契约时请求输入或明确失败，不伪造完整结果；
- **F-EXEC-08**：Plan 只能作为可选 Artifact。复杂 Task 可以要求 Plan 先经批准；简单问数不得为了
  经过 `PLANNED` 状态而制造空计划。

### 5.5 中断、批准与恢复

- **F-INTERACT-01**：后端必须把等待问题具体化为可直接回答的输入或可明确批准的动作，向正确受众
  投影 Interaction，并按 §4.2 原子恢复；
- **F-INTERACT-02**：消费恢复令牌后若后续投递失败，系统必须留下可恢复记录或进入合法失败路径，
  不得悬空。

### 5.6 验收与完成提交

- **F-ACCEPT-01**：Agent 输出不等于 Task 完成；验收器必须按固定 Task Profile 版本检查：

  - 输出 schema 与未声明字段；
  - 每条 acceptance；
  - 证据、来源、新鲜度和权限；
  - 副作用及批准条件；
  - 部分结果和不确定性是否符合契约。

- **F-ACCEPT-02**：验收失败可以在预算和策略允许时产生新 Attempt；禁止静默删改验收标准以换取通过；

- **F-ACCEPT-03**：提交 `SUCCEEDED` 时，最终结果、引用、Artifact 关系、验收判定、预算结算和终态
  事件必须原子提交，或采用可证明不会向前端暴露半成品的等价协议。

### 5.7 返回前端、失败与重试

结果交付采用“**持久化后通知**”：

- **F-DELIVERY-01**：前端可按 `task_id` 获取当前状态和稳定版本的最终结果；
- **F-DELIVERY-02**：每个事件有稳定 `event_id`、Task 内单调 `sequence_no`、
  `payload_schema_version`、时间、主体和可见级别；
- **F-DELIVERY-03**：服务端先持久化事件再推送；
- **F-DELIVERY-04**：流式连接使用 cursor 续传，重复事件对客户端幂等；
- **F-DELIVERY-05**：客户端采用“先建立订阅，再读取快照/历史并按 sequence 去重”或可证明无丢失
  窗口的等价握手；
- **F-DELIVERY-06**：SSE/WebSocket 只是低延迟通知，不是结果唯一载体；流式 token 和未验收草稿只
  属于 Delivery 或中间 Artifact，不能单独构成 `SUCCEEDED`；
- **F-DELIVERY-07**：终态和失败原因可以机械判定，不靠自然语言暗示；
- **F-DELIVERY-08**：用户可见失败包含可行动分类，不能只显示“出错了”；
- **F-DELIVERY-09**：每次读取状态、事件和结果都重新校验用户、租户和授权；
- **F-DELIVERY-10**：通知失败进入 Delivery 记录或重试，不修改 Task 终态。

失败至少分类为：

| 类别 | 例子 | 默认处置 |
| --- | --- | --- |
| `ADMISSION` | 已建单后发现业务/政策不可受理 | `REJECTED`，安全说明 |
| `DISPATCH` | 投递失败、无执行器 | 可重试；策略耗尽后 `FAILED` |
| `EXECUTION` | worker、模型、工具或外部系统失败 | 先查副作用，再决定重试 |
| `VALIDATION` | 输出 schema、验收或证据不通过 | 修实现/新 Attempt；不得原样盲重试 |
| `BUDGET` | Attempt 预算耗尽 | 按契约追加批准、换策略或失败 |
| `CANCEL` | 用户或系统取消 | 安全收敛后 `CANCELLED` |

## 6. 跨进程纪律与持久化账

### 6.1 全程不变量

| ID | 必须成立 | 防止的失败 |
| --- | --- | --- |
| I1 | 原始输入、调用者、租户、受理时间和 Profile 版本可追溯，不被后续解释覆盖 | 意图漂白 |
| I2 | 相同幂等作用域、键和摘要只对应一个 Task；异摘要冲突 | 重复建单或误复用 |
| I3 | 每次读取、工具调用和写入重新校验当前授权 | 撤权后继续访问、跨租户泄漏 |
| I4 | 状态转换集中校验，事件只追加；状态与进度是事件投影 | 状态多头、覆写历史 |
| I5 | Task 与 Attempt 终态不可转出；重新处理建立新实体 | 终态失真 |
| I6 | Task 成功前结果和验收证据已持久化且可重新获取 | 完成即丢失 |
| I7 | 通知与连接失败不改变 Task 业务终态 | 把交付故障误判成业务失败 |
| I8 | Attempt 失败不自动等于 Task 失败 | 过早终结用户任务 |
| I9 | 每个外部副作用有稳定幂等键、状态、回执和补偿信息 | 恢复或重试时重复动作 |
| I10 | 预算覆盖 Task 的全部 Attempt、子 Task 和工具调用 | fan-out 放大无限额 |
| I11 | 结论和数值按 Profile 关联来源、时点、转换与执行者 | 证据幻觉、口径漂移 |
| I12 | 敏感信息、凭据和越权原文不进入普通事件、日志和前端投影 | 泄密 |
| I13 | 一个可变事实只有一个权威写入面，其他视图均可重建 | 副本漂移 |
| I14 | worker 失去租约或 fencing 后不能提交结果或副作用 | 迟到写入覆盖新结果 |
| I15 | 每项可独立实现的义务有稳定 ID、所有者、代码位置和自动测试；未实现项显式登记 | 规范成为口号 |

这些纪律必须由事务、唯一约束、状态版本、租约、fencing、持久化账和常规自动测试保证，不能只依赖
prompt、执行者自律或“记得运行”的临时脚本。

### 6.2 持久化记录

传统“四本账”必须保留，并与 Task/Event、Attempt、Interaction、Delivery 主记录组合：

| 记录 | 最低内容 |
| --- | --- |
| Task / Event | 身份、契约、状态事件、因果/关联 ID、主体、时间、schema 版本 |
| Attempt | 执行者、Profile/运行时版本、租约、输入输出、失败码、消耗 |
| 幂等账 | 作用域、键、请求摘要、Task、首次/重复响应 |
| 预算账 | Task 总额、预留、已用、释放、追加批准和拒绝原因 |
| 副作用账 | 动作幂等键、目标、意图、执行状态、回执、补偿状态 |
| 证据账 | 主张、来源、时点、转换、生成者、Attempt 和验收者 |
| Interaction | 等待问题/动作、受众、令牌、状态版本、消费结果 |
| Delivery | 目标用户/通道、cursor、尝试、确认或失败；不保存第二份结果正文 |

所有要求“进程被杀后仍正确”的事实必须由持久化与并发控制承担。可以采用不同表或事件投影实现，
但不能把这些事实仅保存在 worker 内存或外部执行 harness 中。

## 7. Profile、Artifact 与扩展

### 7.1 Task Profile 与 Agent Profile

Task Profile 是版本化产品契约：

```text
profile_id + version
input_schema / output_schema / frontend_renderer_contract
normalization_rules
required_context / artifacts
acceptance / evidence / freshness rules
allowed_capabilities / data sources
default budget / retry / approval / privacy policy
```

Agent Profile 声明执行能力：模型、prompt、工具绑定、权限边界、memory policy 和支持的 Task Profile。
Task 固定 Task Profile 版本；每次 Attempt 记录所选 Agent Profile 与运行时版本。升级任一 Profile 不得
静默改变已受理 Task 的解释或历史结果。

新增领域应新增 Task Profile 和相容 Agent Profile，不修改通用状态语义。确需改变通用骨架时，必须先
通过一个有证据和迁移方案的规范修订工作单元；不能由领域 Profile 倒逼核心分叉。

### 7.2 Profile 示例

| Profile | 至少固定 |
| --- | --- |
| `DATA_QUERY` | 对象范围、指标口径、单位/币种/复权、时间区间/频率/时区/截至时点、授权数据源、缺失规则、结果形态、查询/转换链和引用 |
| `RESEARCH` | 研究问题、来源范围、时间边界、证据等级、反证、覆盖要求、不确定性和引用格式 |
| `ACTION` | 目标系统、授权主体、预期副作用、动作幂等键、批准点、回执、补偿和不可逆声明 |

这些是设计示例，不是已经冻结的业务契约；每个 Profile 的第一项开发工作单元 必须用真实输入、输出、前端
renderer 和验收用例确认字段，之后才发布其首个版本。Plan 是可选 Artifact，不是状态。复杂 Profile
可以要求 Plan 版本化并先经批准；简单问数可直接执行。

## 8. 子 Task 与依赖编排

Agent 可以派生子 Task，但必须满足：

- 父 Task 的完成标准仍是用户业务目标，不能以“已经拆出子 Task”冒充完成；
- 父级预算覆盖全部子 Task，子级预算是预留而不是凭空新增；
- 子 Task 的授权只能收窄；扩大权限必须重新批准；
- 子 Task 各自有 Task Profile、Attempt、结果和验收；
- 父 Task 汇总结果时保留来源和子 Task 血缘。

多个 Task 的依赖图由一个有边界的 `COORDINATION` Task 管理：

```text
managed_task_ids[]
edges[] = from → to + 依据 + 可判定满足条件
parallel_groups[]
ownership[]
graph_version
```

协调 Task 是边的唯一权威；被协调 Task 只保存 `coordination_task_id`，不复制具体边。同时只能有一个
现行协调视图。协调 Task 验收：节点存在、每条边有依据与解除条件、阻塞图无环、工作有责任归属、
同一事实无第二写入面。

**协调 Task 不等待被协调 Task 全部完成。**图建立并验收后即 `SUCCEEDED`。依赖实质变化时建立
`supersedes` 旧图的新协调 Task，避免一个永不结束的“总管 Task”成为中央计划。

对子结果的等待发生在依赖这些节点的业务 Task：该 Task 进入 `WAITING(DEPENDENCY)`，等待条件满足后
按 §4.2 恢复。协调 Task 只维护并验收依赖边，不替业务 Task 等结果。

## 9. 前端、后端与 Agent 责任投影

本节是所有者索引，不产生第二套规范。实现矩阵以 §5 的稳定功能 ID、§6 的不变量 ID 和 §11 的验收
ID 为键；此处只说明谁对它们负责。

| 所有者 | 负责的要求 |
| --- | --- |
| 前端 | `F-INTAKE-*`、`F-INTERACT-*` 的用户操作、`F-DELIVERY-*` 的订阅/回放/展示侧，以及相应 `AT-*` |
| 后端 | `F-ADMIT-*`、`F-DISPATCH-*`、Interaction 原子消费、Task/Attempt 状态与结果提交、`I1`–`I15` 的存储和并发载体 |
| Agent / runtime | `F-EXEC-*`、候选结果生成、checkpoint、工具/证据/副作用纪律，以及 `F-ACCEPT-*` 的 Agent 侧输入 |
| 验收器 / Profile | `F-ACCEPT-*`、Profile schema 与版本、结果 renderer 契约 |
| 运维 | 非终态 Task、过期租约、悬空投递和失败 Delivery 的扫描/告警，以及租户、Profile、失败码、Attempt 和预算可观测性 |
| 测试与维护者 | `AT-*`、实现矩阵、无法自动验证条款的人工门禁及其理由 |

当前覆盖状态只记录在实现矩阵或 project-guide，不写回本文形成易腐快照。

## 10. 反模式

| 反模式 | 失败方式 |
| --- | --- |
| Task 与 Attempt 合并 | 一次执行失败过早终结用户请求，或被迫重开终态 |
| 先推送后落库 | 用户看见无法回放的幽灵事件 |
| SSE 是唯一结果载体 | 断线或刷新后结果永久丢失 |
| 直接写 `CANCELLED` | 与正在完成的 worker 竞争，副作用未收敛 |
| 无 fencing 的租约 | 过期 worker 用迟到结果覆盖新执行 |
| 同幂等键异载荷静默复用 | 用户得到另一请求的结果 |
| 盲目重试执行中失败 | 已发生的外部动作被重复执行 |
| 每个子 Task 各自维护依赖边 | 图变化时多头漂移 |
| 协调 Task 等所有子 Task 完成 | 重新制造永不结束的中央计划 |
| 父 Task 以“已拆子 Task”宣布完成 | 内部动作冒充用户结果 |
| Profile 修改通用状态机 | 新领域产生第二套生命周期 |
| 开发字段进入产品骨架 | 问数等 Task 被迫穿开发流程的外衣 |
| 当前实现快照写进目标规范 | 规范随代码变化腐烂，目标与事实混淆 |
| 通知失败改写业务终态 | Delivery 故障污染 Task 结果 |
| 规范只有文字没有测试映射 | “必须”无法执行，最终退化为口号 |

## 11. 产品验收矩阵

宣布本文某项能力已经实现前，至少提供以下自动化或可复现实验：

| ID | 场景 | 必须证明 |
| --- | --- | --- |
| `AT-01` | 幂等重复提交 | 同作用域、同键、同摘要只创建一个 Task |
| `AT-02` | 幂等异载荷 | 同键异摘要明确冲突，不误复用、不另建 |
| `AT-03` | 协议拒绝 | 未认证/畸形提交不创建业务 Task，不泄露信息 |
| `AT-04` | 受理拒绝 | 已建单 Task 可进入 `REJECTED` 并返回安全理由 |
| `AT-05` | 越权访问 | 不能读取、订阅、恢复、批准或取消其他用户/租户 Task |
| `AT-06` | 简单问数 | 提交到结构化结果、口径、数据时点和引用完整闭环 |
| `AT-07` | 澄清恢复 | 令牌原子消费；重复、过期、异键、跨 Task 响应被拒绝 |
| `AT-08` | 投递窗口 | 建单后投递失败可恢复，不形成永久悬空 Task |
| `AT-09` | worker 崩溃 | 租约到期后可恢复，迟到 worker 不能写入 |
| `AT-10` | Attempt 重试 | 可重试失败产生新 Attempt，Task 不被过早终结 |
| `AT-11` | 验收失败 | 不合格输出不能使 Task 成功；允许按策略产生新 Attempt |
| `AT-12` | 副作用后崩溃 | 恢复不重复动作，回执与补偿状态可审计 |
| `AT-13` | 预算耗尽 | Attempt 明确终态；Task 按契约等待、重排或失败 |
| `AT-14` | 取消竞争 | 取消意图先持久化；完成与取消只有一个终态胜出 |
| `AT-15` | 服务重启 | 可重建所有非终态 Task、Attempt 和等待 Interaction |
| `AT-16` | 前端断线 | 按 cursor 回放无缺口，重复事件被去重 |
| `AT-17` | 页面刷新 | 有权用户仍可取得稳定版本结果 |
| `AT-18` | 通知失败 | Task 终态不变，Delivery 独立重试 |
| `AT-19` | 事件升级 | 旧客户端可按 `payload_schema_version` 兼容或明确拒绝 |
| `AT-20` | Profile 升级 | 历史 Task 仍按固定版本解释和复现 |
| `AT-21` | 子 Task | 预算不被放大、权限不扩张、血缘和证据可追溯 |
| `AT-22` | 协调 Task | 图通过后关闭，不等待全部子 Task 完成 |

此外必须满足：

1. Task/Attempt 状态迁移、API schema、事件 schema、Profile schema 和错误码有机器可检查版本；
2. 每个 `F-* / I*` 登记实现所有者、代码位置、自动测试和当前覆盖状态；
3. 无法自动化的条款登记人工门禁、理由和复核证据；
4. 至少一个真实前端 Task 跑通提交、澄清、Attempt 失败重试、结果持久化、断线重放和重取；
5. 项目事实与目标规范分开，未实现能力不写成已有。

## 12. 修订、落地与参考材料

### 12.1 修订纪律

修改本文必须通过一个有原始请求、边界、影响分析、迁移方案和验收的规范修订工作单元。修改状态语义、
Profile 协议或终态时，必须说明历史数据和客户端兼容策略。修订记录必须保留旧语义、变更原因和迁移
边界；不得为整洁而让曾经生效的合同无痕消失。

功能缺失应建立独立开发工作单元；已实现代码违反本文应按缺陷处理。每项工作独立闭环，不用中央计划维护第二份
状态。当前覆盖以代码、测试与
[`../project-guide/repos/investment-app.md`](../../project-guide/repos/investment-app.md) 为准；建立唯一实现矩阵时，
它必须记录 `要求 ID → 所有者 → 代码位置 → 自动测试 → 当前状态`、迁移映射和待实施工作。`handoff.md`
只投影当前阻塞与下一动作，其他计划文档不得复制覆盖状态；当前缺口和接线状态不进入本文。

### 12.2 参考材料边界

形成本文的候选、评审、历史设计和实现快照只保留在版本历史或相应研究记录中，不在产品合同内维护作者
清单或方案评分。它们可以解释某条要求的来源，但不能覆盖本文，也不能把可替换技术、开发流程或易腐现状
重新带回产品合同。需要改变本文时按 §12.1 修订，而不是引用某份候选绕过现行语义。

### 12.3 生效边界

本文写入 `dev-plan/`，因为改变它意味着代码必须跟着改变。它成为后续实现与验收的目标合同，但不因
文件存在就自动证明能力已经落地。矩阵中尚无对应实现或处于 `NOT_ASSESSED / GAP` 的场景，是规范先于
实现的正常状态，不构成合同缺陷；只有 §11 对应证据完成后，相关能力才可宣称已实现。
