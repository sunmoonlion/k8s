# `architecture/`

任务树第一层的设计定稿：**三块怎么分、怎么连、各自守什么**。

> 依据：[需求](../../PRD/requirement.md) 与 [产品合同](../../../product/product-contract.md)。
> 本层定稿以 thread [0001/0001](../../thread/0001-prd-none/0001-none/user-message.md)、[0001/0002](../../thread/0001-prd-none/0002-none/user-message.md)、[0001/0003](../../thread/0001-prd-none/0003-none/user-message.md) 的 response 为底。

| 文件 | 内容 |
| --- | --- |
| [`lifecycle.md`](lifecycle.md) | **先读这一份**：请求生命周期——一条 message 从用户发出到用户看到 response 的完整往返，九站，以及每站落在哪个模块 |
| [`components.md`](components.md) | 系统由哪几部分组成、各自承担什么；本轮建哪三块、哪些沿用现状不开发；未决 |
| [`channels.md`](channels.md) | 七条通道：两端、协议、内容、安全要点；以及交互上要落实的几件事 |
| [`trust.md`](trust.md) | 哪类数据流到哪、到哪为止——信任边界 |
| [`engineering.md`](engineering.md) | 工程落点（技术栈、独立成仓、界面不共享、契约单一真源）与各模块共同的约束 |

同层的其他定稿：[`constraints.md`](../constraints.md) 是代码必须遵守的规则，
[`agent-dev-guide.md`](../agent-dev-guide.md) 是开发指导，
[`protocol/`](../../../dev-human/protocol/README.md) 是多方竞争在本平台的做法。
