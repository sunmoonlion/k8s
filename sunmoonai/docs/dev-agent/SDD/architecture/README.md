# `architecture/`

**模块之间怎么连**，以及三方共用的对象、契约与约束。

每个模块**各自是什么**不在这里，在同层的 [`modules/`](../modules/)；往下的子任务在 [`submodules/`](../submodules/)。

> 依据：[需求](../../PRD/requirement.md) 与 [产品合同](../../../product/product-contract.md)。

| 文件 | 内容 |
| --- | --- |
| [`lifecycle.md`](lifecycle.md) | **先读这一份**：系统由哪几部分组成、本轮建哪三块、哪些沿用现状不开发；一条 message 从用户发出到用户看到 response 的完整往返（九站与完成判据）；终点在哪；未决 |
| [`channels.md`](channels.md) | 七条通道：两端、协议、内容、安全要点；以及交互上要落实的几件事 |
| [`trust.md`](trust.md) | 哪类数据流到哪、到哪为止——信任边界 |
| [`engineering.md`](engineering.md) | 工程落点（技术栈、独立成仓、界面不共享、契约单一真源）与各模块共同的约束 |
| [`objects.md`](objects.md) | 核心对象：Task、Attempt、Interaction、Artifact、Event、Side Effect、Delivery 与设备——三方共用的词 |
| [`task-contract.md`](task-contract.md) | Task 契约：提交信封、持久化主档、解释与完成契约、最终结果信封 |
| [`approval.md`](approval.md) | 审批：工具级与 Task 级怎么分、各走哪条路 |
| [`invariants.md`](invariants.md) | 全程不变量 `I1`–`I20`、持久化记录、问题侧明文与资料侧加密 |

`SDD/` 下的同层：[`modules/`](../modules/)（每块是什么）、[`submodules/`](../submodules/)（子任务）、
[`dev-workflow.md`](../dev-workflow.md)（开发这件事交给程序驱动时的 workflow）。

再上一层是 [`dev-agent/`](../../README.md)：`PRD/` 写要什么，`rules/` 放代码规则与开发指导。
