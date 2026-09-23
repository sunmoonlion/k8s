# `0001-workbench` 工作台后端

> 跑在内网；映射 `investment-app/investment-backend`。账房、方向盘、顾问、审批分发、验收、交付，以及每个用户 app-server 的唯一客户端。
> 不调模型（`C-A9`），不执行工具。

## 内部的六块

| 块 | 做什么 | 起点（现有代码） |
| --- | --- | --- |
| 账房 | 四本账；Task/Attempt 转换函数；事件表与 Outbox；Interaction 原子消费 | Run 状态机、事件表、Outbox/Inbox、执行租约（租约退役，留幂等） |
| 会话 | Session 与方向盘；环境登记；沙箱分配；`thread/start` | 新 |
| 顾问 | 编排：读游标、组 turn 输入、发 `turn/start`、收产物、按 `on_reject` 走 | Pilot 链退役，换成 turn 循环 |
| 审批分发 | 工具级请求按策略处置或转 Interaction；本地上限变更登记 | 新 |
| 验收 | 确定性检查、定位检查、验收 turn、终态原子提交 | 新 |
| 交付 | 事件流 cursor；结果读取；Delivery 重试 | 事件表 |

## 功能义务

| ID | 义务 |
| --- | --- |
| `F-INTAKE-01` | 幂等键在 `tenant + requester + profile` 内唯一；同键同摘要返回原 `task_id`，异摘要冲突 |
| `F-INTAKE-02` | 提交必须带 `session_id`、`profile_id`、`budget_limit`；判不出专家包时返回候选让用户选，不默认 |
| `F-ADMIT-01` | 身份从会话确定；分配 `task_id` 与首事件在同一提交；后续拒绝形成 `REJECTED` |
| `F-ADMIT-02` | 受理时检查：环境在线、沙箱可用、专家包版本可用、预算大于最低步骤成本 |
| `F-WHEEL-01` | 建单与 `wheel=advisor` 同一提交；终态与 `wheel=user` 同一提交（`I12`） |
| `F-WHEEL-02` | `wheel=advisor` 期间拒绝用户的 turn；`wheel=user` 期间拒绝顾问的 turn；两侧都落事件 |
| `F-WHEEL-03` | 接手前若有未完成的用户 turn，先 `turn/interrupt` 并等待 `turn/completed` |
| `F-ORCH-01` | 每步一个或多个 turn，输入只含步骤契约的字段与固定版本 Artifact 引用 |
| `F-ORCH-02` | 步骤交回物落为新版本 Artifact；不就地覆盖 |
| `F-ORCH-03` | 按 `on_reject` 与 `max_reworks` 处置；用尽交人 |
| `F-ORCH-04` | 预算预留、扣减、释放随 turn 记账；超限硬停进 `WAITING(RESOURCE)`；顾问不得自行加步 |
| `F-APPROVE-01` | 工具级请求带 `environmentId` 回到本块；按专家包 `auto_allow` 处置；越出转 Interaction，同一提交 |
| `F-APPROVE-02` | 断线或超时时未决请求作废；恢复后由 Codex 重发 |
| `F-APPROVE-03` | 本地上限变更只登记不发起；工作台任何路径不能提高上限 |
| `F-ACCEPT-01` | 验收依据是派工时冻结的；确定性检查先跑，需要语义判断的派 `role=acceptance` 的 turn |
| `F-ACCEPT-02` | 定位检查（`F-POS-04`）在封装前跑；命中即打回并留痕 |
| `F-ACCEPT-03` | 终态、结果、预算结算、方向盘交回原子提交 |
| `F-DELIVERY-01` | 先持久化后通知；事件按 cursor 续传；重复幂等 |
| `F-DELIVERY-02` | 通知失败独立重试，不改终态 |
| `F-LEDGER-01` | 全部入口共用同一转换函数；状态版本比较交换 |
| `F-LEDGER-02` | 重启后重建所有非终态 Task、Attempt、等待中 Interaction、方向盘 |
| `F-SIGNAL-01` | 自驾时按确定性规则算质量信号并推给网页；不调模型；可关闭 |

## 与 app-server 的客户端

一个用户一条 WebSocket 到其沙箱的 app-server。要处理的事件：`thread/started`、`turn/started`、`turn/completed`、`item/*`、`item/commandExecution/requestApproval`、`item/fileChange/requestApproval`、`thread/environment/connected|disconnected`、`error`。连接断开时按 Codex 的恢复语义重连；超窗按状态机 `SUSPENDED → ABANDONED`。

## 不做

跨网派发；租约与 fencing；领域识别；LangGraph；加密；调模型。

## 待定

`D4`、`D8`。
