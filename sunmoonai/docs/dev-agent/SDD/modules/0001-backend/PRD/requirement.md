# 后端：要满足什么

> 依据：[上层设计](../../../architecture/README.md) 与 [产品合同](../../../../../product/product-contract.md) 的「责任投影」中的「后端 supervisor」与「运维与管理后台」。

同目录另有三份，由合同搬入：

| 文件 | 内容 |
| --- | --- |
| [`control-plane.md`](control-plane.md) | 控制面怎么实现（状态机 + outbox + 任务队列，不引入图执行框架）、workflow 的步骤类型是开放集合、一个执行体、编排留在后端 |
| [`routing.md`](routing.md) | 任务类别的三层判定与路由 |
| [`methods.md`](methods.md) | 方法库的两种形态、口径与计算做成服务端 MCP 工具、按敏感度分档、跨 Task 上下文 |
| [`state-machine.md`](state-machine.md) | 两层状态机：Task 与 Attempt 的状态、合法边、`WAITING` 与 Interaction、取消意图与终态 |
| [`profile.md`](profile.md) | Task Profile 与 Agent Profile、通用与专业、示例 |
| [`subtask.md`](subtask.md) | 子 Task 与依赖编排 |

## 职责

做产品的控制面：受理用户提交的 Task，路由到 Profile 与设备，按 workflow 编排并派发 Attempt，验收结果，维护持久化账与审计；自己不调用生成式模型。

## 目标与范围

把合同里归后端的那部分做出来：受理、路由、排队与派发、执行对接、中断与恢复、验收与完成提交，以及持久化账与审计。

- **包含**：合同 `F-ADMIT-*` 至 `F-DELIVERY-*` 中归后端的功能 ID；
- **不包含**：执行本身（在用户电脑上）、界面（客户端）、自有数据的采集与建库（知识服务）。

## 输入与输出

| 方向 | 内容 |
| --- | --- |
| 从客户端收 | 提交信封（合同「提交信封」一节）、取消、Task 级审查结论、状态与结果的读取请求 |
| 从执行端收 | 事件与进度、副作用意图与回执、工具级审批结论摘要、用量、结果密文与本地内容检查回执 |
| 给客户端 | Task 状态、事件流、结果密文、待审查提醒 |
| 给执行端 | 带签名的派发内容、租约与续约、取消、审批结论 |

## 验收

- 合同 `F-ADMIT-*`、`F-DISPATCH-*`、`F-INTERACT-*`、`F-ACCEPT-*`、`F-DELIVERY-*` 中归后端的条目全部满足；
- 合同的不变量里由存储与并发控制承担的部分（I1 至 I15、I17）成立；
- 合同的验收矩阵中涉及后端的场景可复现：`AT-01` 至 `AT-08`、`AT-10` 至 `AT-15`、`AT-18` 至 `AT-23`、`AT-25`、`AT-26`、`AT-28`、`AT-32`。

## 约束

- 不调用生成式模型，也不请执行端代为判断；需要语义判断的环节派 Attempt（合同「后端 supervisor」一节）；
- 不接触用户 key，不中转模型请求，看不到结果正文（合同 I16、I17）；
- 四本账都在数据库里，执行端不持有权威副本（I13）；
- 合同的不变量 `I1` 至 `I20`、[代码规则](../../../constraints.md)、[IMP 规则](../../../../../dev-human/imp/message-rules.md)。
