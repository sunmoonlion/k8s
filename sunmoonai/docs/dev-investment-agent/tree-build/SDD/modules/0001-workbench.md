# `0001-workbench` 工作台后端

> 跑在内网；映射 `investment-app/investment-backend`。账房、方向盘、顾问、审批分发、验收、交付，以及每个用户 app-server 的唯一客户端。
> 不调模型（`C-A9`），不执行工具。

## 内部的六块

| 块 | 做什么 | 起点（现有代码） |
| --- | --- | --- |
| 账房 | 四本账；Task/Attempt 转换函数；事件表与 Outbox；Interaction 原子消费 | Run 状态机、事件表、Outbox/Inbox、执行租约（租约退役，留幂等） |
| 会话 | Session 与方向盘；环境登记；沙箱分配；`thread/start` | 新 |
| 顾问 | 编排：表驱动的工作流解释器——读游标、取步骤契约、组 turn 输入、发 `turn/start`、收产物、按 `on_reject` 走。**不用 LangGraph**：节点不调模型、状态在账房、`WAITING` 可跨天跨重启，框架的 checkpoint 会成第二真源；崩了从游标与 Artifact 版本续 | Pilot 链（LangGraph）退役，换成 turn 循环 |
| 审批分发 | 工具级请求按策略处置或转 Interaction；本地上限变更登记 | 新 |
| 验收 | 确定性检查、定位检查、验收 turn、终态原子提交 | 新 |
| 交付 | 事件流 cursor；结果读取；Delivery 重试 | 事件表 |

## 功能义务

| ID | 义务 |
| --- | --- |
| `F-INTAKE-01` | 幂等键在 `tenant + requester + profile` 内唯一；同键同摘要返回原 `task_id`，异摘要冲突 |
| `F-INTAKE-02` | 提交必须带 `session_id`、`profile_id`、`budget_limit`；判不出专家包时返回候选让用户选，不默认 |
| `F-ADMIT-01` | 身份从会话确定；分配 `task_id` 与首事件在同一提交；后续拒绝形成 `REJECTED` |
| `F-ADMIT-02` | 受理时检查：环境在线、沙箱可用、专家包版本可用、预算大于最低步骤成本；**问题与任何专家包不匹配即 `REJECTED`**，理由可读（"不在专家范围，继续自己用 Codex 即可"），不转任何通用顾问——通用能力由用户自己的 Codex 提供 |
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
| `F-SIGNAL-01` | 自驾时按确定性规则算质量信号并推给网页；不调模型；可关闭；**领域门**：先用知识服务的实体词典匹配证券、报告期、指标，匹配不到一条信号都不算；信号从工具调用记录与产物里算（引用为零 = 有财务数字而本轮零次 MCP 调用；时点过期 = 引用时点落后库里最新一个报告期以上），宁漏勿误 |

## 与 app-server 的客户端

一个用户一条 WebSocket 到其沙箱的 app-server。要处理的事件：`thread/started`、`turn/started`、`turn/completed`、`item/*`、`item/commandExecution/requestApproval`、`item/fileChange/requestApproval`、`thread/environment/connected|disconnected`、`error`。连接断开时按 Codex 的恢复语义重连；超窗按状态机 `SUSPENDED → ABANDONED`。

## 留好位置、第一期不做

多臂竞争择优：`Attempt.role/arm`、`step_contract.mode=compete`、`attempt/compared|judged|objected` 事件已预留（`state-machine.md`）；开启条件是三条同时成立——步骤是高价值判断点、专家包声明允许多臂、用户预算里勾选。

## 不做

跨网派发；租约与 fencing；领域识别做路由；LangGraph 或任何 agent 框架；加密；调模型；通用顾问包。

## 待定

`D4`、`D8`。

## 实现状态（2026-09-24，第三段）

已落在 `investment-backend/app`：迁移 `20260924_0008_workbench`；`domain/workbench`（状态表、对象、专家包 `SMOKE`/`DATA_QUERY`）；`infrastructure/workbench`（仓储、app-server 客户端）；`application/workbench`（账本、会话服务、runner、顾问、验收）；`interfaces/endpoints/workbench_routes.py`（`/api/workbench`）；第五个进程角色 `runner`。测试 457 通过；本机真链 14 项 pass（`k8s/sunmoonai/scripts/local-integration/workbench-chain.sh`）。

未做：`F-LEDGER-02` 只重建命令队列，runner 重启丢未决工具审批；runner 多实例分片；`DATA_QUERY` 需知识 MCP（第四段）；`F-SIGNAL-01`；`D10` 令牌签发。

