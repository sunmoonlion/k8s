# agent 任务的组成设计

第一层分前端与后端，Agent / runtime 与验收器归后端；责任划分依 [产品请求生命周期合同](request-lifecycle.md) 第 9 节。
这里写总体设计与前后端的交互：提交信封、Interaction 往返、事件回放与结果获取。

[development-plan.md](development-plan.md)、[constraints.md](constraints.md)、[agent-dev-guide.md](agent-dev-guide.md) 分别以 turn [01](../thread/01/user-message.md)、[02](../thread/02/user-message.md)、[03](../thread/03/user-message.md) 的交回物为底。
[产品请求生命周期合同](request-lifecycle.md) 是本任务的产品合同，[`protocol/`](protocol/README.md) 是多方竞争在本平台的具体做法。
