# 后端：需求层的模块划分与关系

> 依据：上层的 [`PRD/modules/0001-backend`](../../../../../PRD/modules/0001-backend/README.md) 与 [产品合同](../../../../../../product/product-contract.md)。

## 目标与范围

把合同里归后端的那部分做出来：受理、路由、排队与派发、执行对接、中断与恢复、验收与完成提交，以及持久化账与审计。

- **包含**：合同 `F-ADMIT-*` 至 `F-DELIVERY-*` 中归后端的功能 ID；
- **不包含**：执行本身（在用户电脑上）、界面（客户端）、自有数据的采集与建库（知识服务）。

## 模块划分

按合同七阶段产品功能的阶段切，每个模块对一段：

| 模块 | 要满足什么 |
| --- | --- |
| [`0001-intake`](../modules/0001-intake/README.md) | 受理与路由：身份、幂等、建单、契约固定、路由决定 |
| [`0002-agent-execution`](../modules/0002-agent-execution/README.md) | 排队、派发与执行对接：outbox、租约与 fencing、事件与副作用回传 |
| [`0003-interrupt-resume`](../modules/0003-interrupt-resume/README.md) | 中断、批准与恢复：Interaction 的原子消费、断线暂停后的对账 |
| [`0004-acceptance-commit`](../modules/0004-acceptance-commit/README.md) | 验收与完成提交：确定性验收、回执核对、终态原子提交、交付 |

## 模块之间

- 四段共用同一套 Task 与 Attempt 状态机，不各造一套（合同「两层状态机」）；
- 状态只由集中的转换规则改写，事件只追加（I4）；
- 持久化账（幂等、预算、副作用、证据）四段共用，谁写哪一部分见合同「持久化记录」一节；
- 跨段传递只经数据库与事件，不靠进程内状态（I13）。

## 约束

合同的不变量 `I1` 至 `I20`、[代码规则](../../../../constraints.md)、[开发流程](../../SDD/pipeline.md)。
