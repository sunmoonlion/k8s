# 子 Task 与依赖编排

> 由产品合同搬入（合同「去向」表登记）。本模块要满足什么见 [requirement.md](requirement.md)。

派生子 Task 必须满足：

- 父 Task 的完成标准仍是用户业务目标，不能以「已经拆出子 Task」冒充完成；
- 父级预算覆盖全部子 Task，子级预算是预留，不是凭空新增；
- 子 Task 的授权只能收窄；扩大权限必须重新批准；
- 子 Task 各自有 Task Profile、Attempt、结果与验收；
- 父 Task 汇总结果时保留来源与子 Task 血缘。

多个 Task 的依赖图由一个有边界的 `COORDINATION` Task 管理：

```text
managed_task_ids[]
edges[] = from → to + 依据 + 可判定的满足条件
parallel_groups[]
ownership[]
graph_version
```

协调 Task 是边的唯一权威；被协调 Task 只保存 `coordination_task_id`。同时只能有一个现行协调视图。协调 Task 验收：节点存在、每条边有依据与解除条件、阻塞图无环、工作有责任归属、同一事实无第二写入面。协调 Task 在图建立并验收后即 `SUCCEEDED`，不等待被协调 Task 完成；依赖实质变化时建立 `supersedes` 旧图的新协调 Task。对子结果的等待发生在依赖这些节点的业务 Task：它进入 `WAITING(DEPENDENCY)`，条件满足后按 §5.2 恢复。

