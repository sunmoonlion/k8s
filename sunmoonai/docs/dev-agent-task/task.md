# 任务：开发 SunMoonAI 的 agent 产品

> **初稿，待所有者修改确认。**2026-09-15 由 opus 从本任务已有文档摘出（产品合同第 0、1、11 节，constraints，原 handoff 与原实施计划），只摘不编；
> 确认前不作为派工依据。写法按 [PRD 规则](../dev-agent-standards/task/prd/prd-rules.md) 的最严格一档。

## 背景

- **要做的是什么**：平台只建设一个产品运行时（见 [agent-dev-guide](composition/agent-dev-guide.md)）；本任务按 [产品请求生命周期合同](composition/request-lifecycle.md) 把它做出来。
- **施工顺序**：一 前后端对接 → 二 agent 开发 → 三 问数；每个阶段要建什么、为什么这么建，见 [development-plan](composition/development-plan.md)。
- **现在的状况**（原 handoff，2026-08-29）：处在阶段一（前后端对接），尚未开工——U1 未定，任务清单为空；阶段二、三未开工。
  代码现状以代码、测试与 [investment-app 现状](../project-guide/repos/investment-app.md) 为准。
- **尚未决定的事**：U1–U5 等登记在 [agent-dev-guide](composition/agent-dev-guide.md)「7.4 风险和未决」；**每项定下来之前，不要开工依赖它的部分**。
- **已有的决定**：见下文「约束」与 [log.md](log.md)。

## 要什么

按 [合同](composition/request-lifecycle.md) §1，请求生命周期的终点不是“模型返回了文字”，也不是“一条 SSE 消息发送成功”，而是：

1. 最终结果、验收、证据和副作用状态已经可靠持久化；
2. Task 已以唯一合法终态提交；
3. 有权用户可以在断线、刷新或换设备后重新取得结果；
4. 通知失败可以独立重试，不改变 Task 结果。

## 范围

包含（[合同](composition/request-lifecycle.md) §0.2「本文负责」）：

- Task 的身份、契约、状态和终态语义；
- Task 与 Attempt/Run、Interaction、Artifact、Event、Side Effect、Delivery 的关系；
- 从提交、受理、调度、执行、中断到结果交付的产品闭环；
- 幂等、授权、预算、副作用、证据、恢复、取消、重试和审计纪律；
- Profile、子 Task 和依赖编排的扩展规则；
- 前端、后端、Agent 的实现责任与验收矩阵。

不包含：

- 当前代码已经实现到哪里；
- 具体模型、prompt、SDK、图节点或队列产品选型；
- Git、远端、子模块和跨机操作；
- 开发助手或人怎样提出、实施、评审、批准和交付一项开发工作；
- 某个业务 Profile 的完整业务算法。

不包含的归谁：project-guide、具体开发工作单元、[agent-dev-guide](composition/agent-dev-guide.md)、[通用开发规范](../dev-agent-standards/README.md) 和相应 Profile 规范。

## 验收标准

按 [合同](composition/request-lifecycle.md) §11「产品验收矩阵」：宣布某项能力已经实现前，提供该节 `AT-01`–`AT-22` 的自动化或可复现实验，并满足其后 5 条。
验收依据以合同该节为准，本文不复制。

## 约束

### 代码规则

动代码前对照 [constraints.md](composition/constraints.md)（39 条）；违反任一条的方案不进入讨论。

### 用语

「必须」缺失即不符合；「应该」偏离时必须记录理由、风险和等价控制；「可以」是合法选项（[合同](composition/request-lifecycle.md) §0.3）。

### 不能倒退的决定

所有者 2026-08-29 定，接手时**不要重新讨论**（原记于后端 handoff）：

| | 结论 | 定于 |
| --- | --- | --- |
| 施工顺序 | 前后端对接 → agent 开发 → 问数 | 2026-08-29 |
| 问数的位置 | 专用智能体的一个实例（加一份 Profile + 一个工具），不是另一套架构 | 2026-08-29 |
| SQLBot / WrenAI | **参考资料，不是选型候选** | 2026-08-29 |
| v5 的地位 | 历史设计输入；其 §10 前后端对接仍有效且详尽，做阶段一时逐节引用 | 2026-08-29 |
| 四本账 | 幂等、副作用已接线；缺预算与证据 | 取证于 2026-08-29 |

### 工作单元的写法

> 依据的通用规范：[SDP「工作单元要说清什么」](../dev-agent-standards/deliverables/sdp/sdp-rules.md)

本任务拆出的所有子任务，SDP 都照此写（原实施计划）。

测试层次：

```
L1 Unit                    L5 Failure Injection
L2 Component Integration   L6 Evaluation/Quality
L3 Contract                L7 Deployment/Operations
L4 Cross-app E2E
```

P0 / P1 任务必须写明适用层次。

每条任务固定这几栏，**缺栏视为未定义，不开工**：

| 栏 | 写什么 |
| --- | --- |
| 类型/优先级 | `ARCH` / `FEAT` / `FIX` / `OPS` + `P0`–`P2` |
| 仓库 | 涉及哪几个仓——跨仓任务必须列全，否则漏推 |
| 前置 | 依赖哪些任务或哪条未决项定了才能开工 |
| 目标 | 一句话说清做完之后什么变了 |
| 实施 | 具体动什么。**不写"完善 X"这种没有终点的表述** |
| 测试 | 适用的测试层次（见上），**不能只写"补测试"** |
| 验收 | 可判定的条件。做完能一条条对着勾 |
| 回滚 | 出问题怎么退回去 |
| 状态 | `NOT_STARTED` / `IN_PROGRESS` / `BLOCKED` / `ACCEPTED` + 日期与证据 |

## 交付

- **交回什么**：SDD（结构层）——前端与后端的划分、彼此的交互与共同约束，放在 [`composition/`](composition/)。只交文本，可改范围限于 `composition/`。
  本任务是规划任务，不交 SDP、UAT；它们由拆出的子任务交付。
- **已有进展**：第一层分前端与后端，Agent / runtime 与验收器归后端（所有者 2026-09-14 定，见 [log.md](log.md)）。
- **需要人批准的动作**：SDD 验收通过（通过后才按拆分建子任务）；修改产品合同（按合同的修订纪律）；其余见 [人的批准点](../dev-agent-standards/approvals.md)。
