# 后端：设计层的模块结构与关系

> 依据：[后端要满足什么](../../PRD/requirement.md)。
> 本层定稿以 thread [0001/0001](../../thread/0001-sdd-none/0001-none/user-message.md)、[0001/0002](../../thread/0001-sdd-none/0002-none/user-message.md)、[0001/0003](../../thread/0001-sdd-none/0003-none/user-message.md) 的 response 为底。

## 模块

按合同七阶段产品功能的阶段切，每个模块对一段：

| 模块 | 各自是什么 | 子任务 |
| --- | --- | --- |
| `0001-intake` | [说明](../modules/0001-intake.md) | [子任务](../submodules/0001-intake/PRD/requirement.md) |
| `0002-agent-execution` | [说明](../modules/0002-agent-execution.md) | [子任务](../submodules/0002-agent-execution/PRD/requirement.md) |
| `0003-interrupt-resume` | [说明](../modules/0003-interrupt-resume.md) | [子任务](../submodules/0003-interrupt-resume/PRD/requirement.md) |
| `0004-acceptance-commit` | [说明](../modules/0004-acceptance-commit.md) | [子任务](../submodules/0004-acceptance-commit/PRD/requirement.md) |

**各模块承担什么、不承担什么，写在 [`SDD/modules/`](../modules/) 下各自那一份**，本表只管关系。

`SDD/` 下的同层：[`modules/`](../modules/)（每块是什么）、[`submodules/`](../submodules/)（子任务）。
再上一层是本模块自己的任务目录：`PRD/` 写它要满足什么，`rules/` 放开发指导。

## 模块之间

- 四个模块共用同一套 Task 与 Attempt 状态机与同一张事件表，不各造一套（合同「两层状态机」）；状态只由集中的转换规则改写，事件只追加（I4）；
- 传递只经数据库与事件流，不经进程内状态；
- 持久化账（幂等、预算、副作用、证据）共用，写入面各自明确，同一事实不写两处；谁写哪一部分见合同「持久化记录」一节；
- 与执行端之间只有一条通道，派发、续约、回传都走它。

## 约束

[代码规则](../../../../../rules/constraints.md)、[IMP 规则](../../../../../../dev-human/imp/message-rules.md)，以及产品合同的不变量 `I1` 至 `I20`。
