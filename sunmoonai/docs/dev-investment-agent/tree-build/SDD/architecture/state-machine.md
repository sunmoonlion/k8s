# 两层状态机

> Task 与 Attempt。工作台实现转换；网页按它渲染；沙箱与本地代理不持有状态。
> 起点是 `investment-app` 现有的 Run 状态机、事件表与 Outbox；按能力收窄：首版单委托、无并行。

**状态机与 workflow 的分工**：状态机管纵向（这个 Task 现在算什么），workflow 管横向（走到第几步）。步骤前进只动游标，不动状态词。workflow 不得自己定义状态（`P0`）。方向盘是 Session 属性，不是状态词（[方向盘](wheel.md)）。

| 时机 | 状态机 | workflow |
| --- | --- | --- |
| 派发 | `QUEUED → RUNNING` | 读游标，取这一步的 `step_contract` |
| 交回且通过 | 不动 | 游标 +1；没有下一步时才让状态机走向 `SUCCEEDED` |
| 交回不合格 | 要交人时才进 `WAITING` | 按 `on_reject` 定去向 |
| 返工用尽 | `WAITING(INPUT)` 或 `FAILED` | 停 |

## Task

```text
RECEIVED → VALIDATING → QUEUED → RUNNING → SUCCEEDED ●
               │           │        ├→ WAITING ─→ QUEUED | VALIDATING | FAILED ● | CANCELLED ●
               │           │        ├→ FAILED ●
               │           │        └→ CANCELLED ●
               ├→ WAITING ┘
               └→ REJECTED ●
非终态收到取消意图后，经安全收敛进入 CANCELLED ●
```

合法转换只有：

- `RECEIVED → VALIDATING | CANCELLED`
- `VALIDATING → QUEUED | WAITING | REJECTED | CANCELLED`
- `QUEUED → RUNNING | WAITING | FAILED | CANCELLED`
- `RUNNING → QUEUED | WAITING | SUCCEEDED | FAILED | CANCELLED`
- `WAITING → VALIDATING | QUEUED | FAILED | CANCELLED`

任何入口（网页接口、编排、超时扫描器、管理后台）都调用同一转换函数。

| 状态 | 语义 | 进入门禁 |
| --- | --- | --- |
| `RECEIVED` | 已可靠建单，方向盘已交给顾问 | 身份、原始输入、幂等记录、首事件、`wheel=advisor` 同一提交 |
| `VALIDATING` | 正在检查契约、权限、专家包与环境 | Profile 版本与授权上下文存在 |
| `QUEUED` | 已可执行，等顾问发 turn | 完成契约、预算、专家包版本已持久化；环境在线 |
| `RUNNING` | 一个 Attempt 正在推进 | Attempt 绑定 thread，输入版本固定 |
| `WAITING` | 没有 Attempt 能推进，等一个可命名的外部条件 | 原因码、条件、恢复方式、超时策略 |
| `SUCCEEDED` | 结果完成并可重新获取；方向盘已交回 | 结果、验收证据、预算结算、`wheel=user` 同一提交 |
| `REJECTED` | 已建单但不予执行 | 安全的理由已记录；方向盘交回 |
| `FAILED` | 已无获准的成功路径 | 失败码、Attempt 与副作用记录完整；方向盘交回 |
| `CANCELLED` | 用户终止 | 取消意图、Attempt 处置、副作用状态完整；方向盘交回 |

### `WAITING` 的原因码

| 原因 | 在等什么 | 怎么解除 |
| --- | --- | --- |
| `INPUT` | 用户回答澄清或步骤交人 | Interaction 消费 |
| `APPROVAL` | 用户批准工具级升级的动作、外发范围、外部副作用 | Interaction 消费 |
| `RESOURCE` | 预算用尽，等用户追加 | Interaction 消费；拒绝则 `FAILED` |
| `ENVIRONMENT` | 用户机器的执行环境离线 | `thread/environment/connected` 事件；超时则 `FAILED` |

判据只有一条：要不要一个外部事件来解除。要的进 `WAITING`，只等轮到自己的是 `QUEUED`。旧树的 `WAITING(DEVICE)` 改名 `ENVIRONMENT`；没有"等设备绑定"，Session 已经绑了环境。

### WAITING 与 Interaction

- Task 进入 `WAITING(INPUT|APPROVAL|RESOURCE)` 与创建 Interaction 在**同一个提交边界**内；
- Interaction 带一次性令牌、目标 `state_version`、截止时间；响应原子消费：重复、过期、异键、跨 Task、摘要不符一律拒绝（`AT-07`）；
- 过期不等于拒绝也不等于同意：按契约进 `FAILED` 或延长，由 Profile 决定；
- 消费后 Task 回 `QUEUED`（继续）或 `VALIDATING`（改了契约）。

### 取消

取消意图先持久化（`cancel_requested_at`），再对沙箱发 `turn/interrupt`，再收敛：Attempt 进 `CANCELLED`，Task 进 `CANCELLED`。完成与取消只有一个终态胜出，靠 `state_version` 比较交换（`AT-13`）。

## Attempt

```text
CREATED → RUNNING → COMPLETED ●
              ├→ SUSPENDED ─→ RUNNING | ABANDONED ●
              ├→ FAILED ●
              ├→ BUDGET_EXCEEDED ●
              └→ CANCELLED ●
```

至少记录：

```text
attempt_id, task_id, session_id, thread_id, environment_id
codex_version, agent_version, model, model_provider
task_profile_version, expert_pack_version
step_id, step_version, input_artifact_versions
turn_ids[]                            这段执行在 thread 上发了哪些 turn
status, started_at, ended_at
budget_allocated, budget_consumed     token 与费用为厂商回报
failure_code, retryable
output_artifacts
tool_call_refs, side_effect_refs, evidence_refs, approval_refs
```

必须满足：

1. Attempt 终态不可重开；重试创建新 Attempt；
2. 第一期一个 Task 同时只有一个非终态 Attempt；并行与竞争择优不做（`C-A10`）；
3. `COMPLETED` 只表示产出了候选结果，不自动使 Task `SUCCEEDED`；
4. `BUDGET_EXCEEDED` 是终态；Task 随后进 `WAITING(RESOURCE)`；
5. `SUSPENDED` 表示执行环境断开（`thread/environment/disconnected`）；在 Codex 恢复窗内重连回 `RUNNING`，超窗 `ABANDONED`，Task 进 `WAITING(ENVIRONMENT)`，恢复后由新 Attempt 接续；
6. 恢复不得重复已经记账的副作用；工作区内的文件改动以 Codex 协议记录的 patch 为准；
7. 同一专家包版本连续若干个 Attempt 启动即失败时熔断该版本并落事件，直到人解除；
8. 验收 Attempt 与执行 Attempt 分开：独立验收由另一个 turn 承担，记 `role=acceptance`，不得读执行 Attempt 的推理过程，只读交回物。
