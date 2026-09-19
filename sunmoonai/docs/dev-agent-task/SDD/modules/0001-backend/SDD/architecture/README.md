# 后端：设计层的模块结构与关系

> 依据：[后端需求层](../../PRD/architecture/README.md)。
> 本层定稿以 thread [0001/0001](../../thread/0001-sdd-none/0001-none/user-message.md)、[0001/0002](../../thread/0001-sdd-none/0002-none/user-message.md)、[0001/0003](../../thread/0001-sdd-none/0003-none/user-message.md) 的 response 为底。

## 模块

| 模块 | 设计要点 |
| --- | --- |
| [`0001-intake`](../modules/0001-intake/README.md) | 身份与幂等在同一个事务边界内完成；契约固定后才进队列 |
| [`0002-agent-execution`](../modules/0002-agent-execution/README.md) | outbox 投递；租约与 fencing 随派发下发；事件、副作用与用量按 Attempt 归集 |
| [`0003-interrupt-resume`](../modules/0003-interrupt-resume/README.md) | Interaction 的令牌在同一并发控制边界内消费；断线后按 fencing 对账 |
| [`0004-acceptance-commit`](../modules/0004-acceptance-commit/README.md) | 确定性验收与本地内容检查回执核对；终态、结果、预算结算原子提交 |

同层的其他定稿：[`agent-dev-guide.md`](../agent-dev-guide.md) 是开发指导。

## 模块之间

- 四个模块共用同一套 Task 与 Attempt 状态机与同一张事件表，状态只由集中的转换规则改写；
- 传递只经数据库与事件流，不经进程内状态；
- 持久化账（幂等、预算、副作用、证据）共用，写入面各自明确，同一事实不写两处；
- 与执行端之间只有一条通道，派发、续约、回传都走它。

## 约束

[代码规则](../../../../constraints.md)、[IMP 规则](../../../../../../dev-agent-standards/imp/imp-rules.md)，以及产品合同的不变量 `I1` 至 `I20`。
