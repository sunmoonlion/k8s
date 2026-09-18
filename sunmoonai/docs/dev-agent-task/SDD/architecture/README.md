# 设计层：模块之间的结构与关系

> 依据：[需求层](../../PRD/architecture/README.md) 与 [产品合同](../../../product/product-contract.md)。
> 本层定稿以 thread [0001/0001](../../thread/0001-sdd-none/0001-none/user-message.md)、[0001/0002](../../thread/0001-sdd-none/0002-none/user-message.md)、[0001/0003](../../thread/0001-sdd-none/0003-none/user-message.md) 的 response 为底。

## 模块

| 模块 | 内部结构见 |
| --- | --- |
| [`0001-backend`](../modules/0001-backend/SDD/architecture/README.md) | 受理、排队与派发、执行对接、中断与恢复、验收与完成提交 |
| [`0002-frontend`](../modules/0002-frontend/SDD/architecture/README.md) | 交互响应；其余部分待设计 |

同层的其他定稿：[`constraints.md`](../constraints.md) 是代码必须遵守的规则，[`agent-dev-guide.md`](../agent-dev-guide.md) 是开发指导，[`protocol/`](../../protocol/README.md) 是多方竞争在本平台的做法。

## 模块之间怎么交互

按 [产品合同](../../../product/product-contract.md) 的「通道」一节定，设计上只落实这几件事：

| 交互 | 设计要点 |
| --- | --- |
| 提交 | 客户端生成幂等键，后端在可靠边界内建单并写首事件（合同 `F-INTAKE-01`、`F-ADMIT-01`） |
| 事件与结果 | 先持久化后通知；客户端按 cursor 续传，重复事件幂等（`F-DELIVERY-02` 至 `F-DELIVERY-05`） |
| 审批与审查 | 工具级只在本机闭环，Task 级经后端 Interaction 原子消费；两条提交逻辑不得共用（`F-APPROVE-*` 与 `F-REVIEW-*`） |
| 结果 | 执行端本地检查后加密，后端只存密文与元数据，客户端本机解密（`F-CRYPTO-*`） |

## 共同约束

- 状态机只有一套，场景差异只体现在 Profile 与 workflow（[SDD 规则](../../../dev-agent-standards/sdd/sdd-rules.md) P0）；
- 同一事实只有一个权威写入面（P1）；
- 跨进程仍须正确的不变量由持久存储承担，不放在执行进程本地；
- 执行层租用不自建，领域概念不进执行端口的签名。

## 未决

第一层是否单列本地 runtime，见合同附录 A 的 D1；定了之后本目录与 [`../modules/`](../modules/) 一起改。
