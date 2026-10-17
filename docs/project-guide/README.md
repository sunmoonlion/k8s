# `project-guide/` 目录

**本目录只回答「项目现在是什么样」**，随代码覆盖式重写；不放规则，也不放脚本。2026-10-16 按 knowlab 定位与改名、`sunmoonai/` 移出后的现状整体重写。

| 文件 / 目录 | 内容 |
| --- | --- |
| [`overall-architecture.md`](overall-architecture.md) | **先读这一份**：产品是什么、仓怎么分、东西跑在哪、应用与数据怎么流、部署与发布、身份、红线、去哪查、已知缺口 |
| [`repos/`](repos/) | 一仓一文件：[`tpl-app`](repos/tpl-app.md) · [`knowfeed-app`](repos/knowfeed-app.md) · [`knowbase-app`](repos/knowbase-app.md) · [`knowbench-app`](repos/knowbench-app.md) · [`k8s`](repos/k8s.md) · [`runtime`](repos/runtime.md) |
| [`topics/`](topics/) | 跨仓主题：[契约](topics/contracts.md) · [数据](topics/data.md)；[v5 历史索引](topics/v5-history.md)只用于取回退役材料。身份、发布的现状写在总览 §6、§7 |
| [`staging.md`](staging.md) | 接下来按什么顺序做——计划，不是进度 |
| [`governance.md`](governance.md) | 权威排序、接手演练、什么不属于本目录 |
| [`licensing.md`](licensing.md) | 第三方许可与本产品的关系 |

另外三处：

- [`../dev-investment-agent/pipeline.md`](../dev-investment-agent/pipeline.md)——一次 turn 的九站，以及**每一站现在谁做**（人还是脚本）；人机分工的现状只记在那里；
- [`../dev-investment-agent/turn/`](../dev-investment-agent/turn/README.md)——一次一问一答怎么走完，**跨项目通用**；
- [`../dev-investment-agent/tree-build/`](../dev-investment-agent/tree-build/README.md)——这个项目的需求、设计、规则、决策，**本项目专有**。
