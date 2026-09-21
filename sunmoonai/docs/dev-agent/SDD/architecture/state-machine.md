# 两层状态机

> Task 与 Attempt 两层状态机：状态词、合法转换、`WAITING` 与 Interaction、取消与终态。
**三方共用**——后端实现转换，runtime 要懂暂停与恢复语义，桌面按它渲染进度。

**状态机与 workflow 的分工**：状态机管纵向——这个 Task 现在算什么；workflow 管横向——走到第几步。

**步骤推进不是状态迁移。**走到第 3 步还是第 5 步，Task 都是 `RUNNING`；步骤前进只动游标，不动状态词。
workflow **不得自己定义状态**（P0：任何场景不得新增状态词）——否则每个领域方法都会长出一套
「已取数」「已分析」「待复核」，状态词立刻失控。

两者的交点只有四处：

| 时机 | 状态机做什么 | workflow 做什么 |
| --- | --- | --- |
| 派发 | `QUEUED` → `RUNNING` | 读游标，取这一步的 `step_contract` |
| 交回且通过 | 不动 | 游标 +1；没有下一步时才让状态机走向 `SUCCEEDED` |
| 交回不合格 | 要交人时才进 `WAITING` | 按 `on_reject` 定去向：重做本步、回到前一步、或交人 |
| 等待 | 等设备、等批准、等依赖一律由 `WAITING` 的原因码表达 | 不参与——**失败与等待归状态机，去向归 workflow** |

**通用任务是长度为 1 的 workflow**：派一个 Attempt、通过即成功，游标从 0 到 1。两类任务共用同一条推进逻辑。

谁能写什么：步骤表与 `step_contract` 是 Task Profile 的一部分，版本化并签名（`F-GUARD-01`）；
游标是 Task 主档上的字段，**只能由 orchestrator 在改状态的同一个事务里改**。

## Task 状态机

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

任何入口——客户端接口、派发网关、调度器、超时扫描器、管理后台——都必须调用同一转换规则。

| 状态 | 产品语义 | 进入门禁 |
| --- | --- | --- |
| `RECEIVED` | 后端已可靠建单 | 身份、原始输入、幂等记录和首事件已提交 |
| `VALIDATING` | 正在解释目标、路由并检查契约、权限和政策 | Profile 候选与授权上下文存在 |
| `QUEUED` | 已可执行，等待设备、资源或可靠投递 | 完成契约、执行策略、预算、路由决定已持久化 |
| `RUNNING` | 至少一个有效 Attempt 正在推进 | Attempt 在绑定设备上持有效租约，输入版本固定 |
| `WAITING` | 当前没有 Attempt 能推进，等待已知条件 | 原因、问题或条件、恢复方式、超时策略 |
| `SUCCEEDED` | 用户结果完成并可重新获取 | 结果密文先持久化；验收逐条通过；本地内容检查回执有效；证据合规 |
| `REJECTED` | 已建单但不予执行 | 安全的政策、范围、能力或业务理由已记录 |
| `FAILED` | 已无获准的成功路径 | 失败码、重试判定、Attempt 与副作用记录完整 |
| `CANCELLED` | 有权主体已终止 Task | 取消意图、fencing、Attempt 处置和副作用状态完整 |

`VALIDATING` 与 `QUEUED` 是否分开展示由客户端投影决定，但持久化语义不得合并到无法区分「尚未形成契约」和「已可执行但未获资源」。

## WAITING 与 Interaction

等待原因使用结构化码，不为每种等待另造状态：

- `INPUT`：等待用户补充关键输入，含路由拿不准时请用户选择类别；
- `APPROVAL`：等待用户或授权角色批准，含工具级请求升级（§6.2）、计划批准、合并到用户工作区、预算追加；
- `DEVICE`：等待绑定设备上线；
- `DEPENDENCY`：等待另一 Task 或依赖条件；
- `RESOURCE`：等待配额、设备容量、锁或计划时间；
- `EXTERNAL`：等待外部系统或现实事件。

Interaction 必须绑定：

```text
task_id, interaction_id, expected_state_version
question_or_action, audience, expires_at
subject_digest                          待决对象（文档、请求）的版本与摘要值
resume_token_hash, idempotency_key, consumed_at
resume_target
```

恢复必须在同一并发控制边界内完成：校验主体与 Task、校验当前等待动作与待决对象摘要、检查过期与过时动作、按幂等键判断重复、原子标记消费、安排后续投递。重复、过期、异键、跨用户、跨 Task 或摘要不符的恢复必须拒绝。

验证阶段等待后回 `VALIDATING`；执行阶段等待后先回 `QUEUED`，只有 Attempt 获得有效租约才重新进入 `RUNNING`。Attempt 若在原运行时 thread 中原地恢复，可在自己的状态机内 `WAITING → RUNNING`。

Interaction 到期不得无事件消失：Task Profile 必须规定超时后关闭该 Interaction，并使 Task 进入 `FAILED`、重新 `QUEUED`、回 `VALIDATING` 或按已批准政策 `CANCELLED`；自动选择必须追加事件并保留超时原因。过期不等于拒绝，也不等于同意。

只有没有任何 Attempt 能继续推进时，Task 才进入 `WAITING`；并行 Attempt 仍有一路可推进时，Task 保持 `RUNNING`，等待记录在对应 Attempt。

## 取消意图与终态

用户取消时，后端必须先持久化取消意图，而不是直接写 `CANCELLED`：

1. 校验主体、Task 版本和当前状态；
2. 写入取消意图并阻止新 Attempt；
3. 撤销租约或提高 fencing，经 ① 通知执行端中断，拒绝旧执行端的迟到写入；
4. 检查已发生副作用，丢弃独立工作区或执行约定的补偿，登记不可补偿的结果；
5. 以比较交换提交唯一的 `CANCELLED` 终态。

执行端离线时，第 3 步以提高 fencing 完成；执行端重连后按 §8.3 对账，不得提交任何结果或副作用。完成与取消并发时只能有一个终态提交成功。客户端可以把已记录的取消意图投影为「正在取消」，但这不是第二套 Task 状态。

## 终态与重新处理

`SUCCEEDED`、`REJECTED`、`FAILED`、`CANCELLED` 不可转出。以下情况建立新 Task：刷新到新的数据时点；修改目标、口径、授权范围或 Profile 版本；重新处理失败、取消或拒绝的 Task；要求另一个方案。新 Task 用 `retry_of`、`refresh_of` 或 `supersedes` 连接旧 Task；旧结果保持当时输入、数据时点、策略与 Profile 版本下的语义。

## Attempt 状态机

Task 层与 Attempt 层必须分开。跨层引用使用 `task.state` 与 `attempt.status`；事件分字段携带两者，日志与客户端投影不得只写一个不带层级的 `status`。

```text
CREATED → RUNNING ⇄ WAITING
   │         │         │
   │         │         └→ PAUSED（失去租约）→ RUNNING | ABANDONED ●
   │         ├→ COMPLETED ●
   ├─────────┼→ FAILED ●
   ├─────────┼→ ESCALATED ●
   └─────────┼→ CANCELLED ●
             └→ BUDGET_EXCEEDED ●
```

Attempt 至少记录：

```text
attempt_id, task_id, device_id, runtime_version, codex_version
model, model_provider                  这一份是哪个模型做的
task_profile_version, agent_profile_id, agent_profile_version
input_artifact_versions, workspace_ref
execution_binding                     运行时 thread 标识
lease_owner, lease_expires_at, fencing_token
status, started_at, ended_at
budget_allocated, budget_consumed     token 与费用为自报
failure_code, retryable
output_artifacts, content_check_receipt
tool_call_refs, side_effect_refs, evidence_refs, approval_refs
```

必须满足：

1. 执行端只有持有效租约和 fencing token 才能写入；过期执行端的迟到结果被拒绝；
2. Attempt 终态不可重开；重试创建新 Attempt；
3. 同一 Task 是否允许并行 Attempt 由执行策略明确；并行数受设备容量限制；
4. 首个通过验收的结果胜出后，其余 Attempt 停止或降为无副作用的只读探索；
5. `COMPLETED` 只表示 Attempt 产出了候选结果，不自动使 Task `SUCCEEDED`；
6. 恢复不得重复已经记账的副作用；
7. `BUDGET_EXCEEDED` 是 Attempt 终态；Task 随后按契约进入 `WAITING(APPROVAL)`、重新 `QUEUED` 或 `FAILED`；
8. `ESCALATED` 表示执行中调用了 `escalate`；Task 回到 `VALIDATING` 由 supervisor 重新路由，改判入账；
9. `PAUSED` 表示执行端失去租约（§8.3）；租约恢复且 fencing 未变时回 `RUNNING`，否则 `ABANDONED`，由新 Attempt 接续；
10. 同一 Agent Profile 版本连续若干个 Attempt 启动即失败时，熔断该版本并落事件，新 Attempt 不再分发到它，直到人解除。

