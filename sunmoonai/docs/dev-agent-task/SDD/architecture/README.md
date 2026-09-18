# agent 任务的组成设计

第一层分前端与后端，Agent / runtime 与验收器归后端；责任划分依 [产品合同](../../PRD/product-contract.md) §12。
这里写总体设计与前后端的交互：提交信封、Interaction 往返、事件回放与结果获取。

[development-plan.md](../../PRD/development-plan.md)、[constraints.md](../constraints.md)、[agent-dev-guide.md](../agent-dev-guide.md) 分别以 turn [0001/0001](../../thread/0001-sdd-none/0001-none/user-message.md)、[0001/0002](../../thread/0001-sdd-none/0002-none/user-message.md)、[0001/0003](../../thread/0001-sdd-none/0003-none/user-message.md) 的交回物为底。
[产品合同](../../PRD/product-contract.md) 是本任务的产品合同，[`protocol/`](../../protocol/README.md) 是多方竞争在本平台的具体做法。
