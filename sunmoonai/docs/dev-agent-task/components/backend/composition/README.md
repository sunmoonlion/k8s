# 后端的组成设计

后端内部各部分（受理、排队投递、Agent 执行、中断恢复、验收与完成提交、投递重试）之间的关系；Agent / runtime 与验收器在此层。

[development-plan.md](development-plan.md)、[agent-dev-guide.md](agent-dev-guide.md)、[pipeline.md](pipeline.md) 分别以 turn [0001](../thread/0001-none/user-message.md)、[02](../thread/0002-none/user-message.md)、[03](../thread/0003-none/user-message.md) 的交回物为底，内容未改。
子任务 02-intake、04-agent-execution、05-interrupt-resume、06-acceptance-commit 按产品合同第 5 节的阶段建立。
