# 方法与专家包

> 方法收在工作台，随专家包版本化；下发给 Codex 的只有当前这一步。谁来编排见 [`0001-workbench`](../modules/0001-workbench.md)。

## 方法怎么到 Codex

```text
专家包（工作台）── 这一步的方法文本 + 工具清单 ──▶ turn 输入（②）──▶ 沙箱里的 Codex
                                                       └── MCP 工具（⑥）──▶ 知识服务
```

- **文本**随 turn 输入注入，只给这一步；
- **工具**在知识服务侧，每步 turn 注册这一步允许的清单；换步换清单；
- **判据、阈值、为什么**留在工作台的验收规则里，不进注入面；
- 注入文本不出现下一步的线索。

旧树"runtime 代理 MCP 回后端二次校验"那条链退役：循环在沙箱里，工作台是它的唯一客户端，本来就看得到每次调用。

## 编排就是逐步发 turn

顾问不调模型（`C-A9`）。它做的事：读游标，取步骤契约，组装 turn 输入，发 `turn/start`，等 `turn/completed`，取交回物，做确定性检查，需要语义判断的派验收 turn，按 `on_reject` 决定下一步。一个 Task 的全部 turn 在同一个 thread 上。

## 专家包

```text
pack_id + version（签名）
profile_ref                      对应的 Task Profile
workflow[]                       步骤序列与 step_contract
method_texts{step_id: ref}       版本化的方法文本
tools{step_id: [mcp_tool]}
auto_allow                       顾问驾驶时自动放行的工具级动作
acceptance_rules                 确定性检查 + 验收 turn 的提示
quality_signals[]                自驾时触发求助提示的规则
eval_set_ref                     发布门用的评测集
answers                          六问：解决什么、需要什么、不解决什么、何时完成、何时拒绝或交回、效果与成本
```

真人专家写包；包里只写研究步骤与计算方法，不写判断规则（`F-POS-02`）。改包必须过发布评测（`0007-eval`）。

## 编排不构成保密

每一步的文本在下发那次仍可见；重复观察能重建序列。真正抄不走的是数据、服务端计算与口径、评测闭环（[价值](../../PRD/value.md)）。

## 最小实例

第 23 到 25 课的问数五阶段做第一份专家包：`rewrite → sql_generate → sql_execute → normalize → final`。每阶段一步一个 turn；SQL 执行是知识服务上的 MCP 工具；真值是 `truth_queries` 加 `result_fingerprint`。它用来把机制跑通，之后换成勾稽切口。

**跨 Task 上下文**：项目背景、偏好、历史决定由工作台记在 Session 与 Task 上；长期记忆不做（第一期）。
