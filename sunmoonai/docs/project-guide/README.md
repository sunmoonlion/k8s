# `project-guide/` 目录

**本目录只回答「项目现在是什么样」**，随代码覆盖式重写；不放规则，也不放脚本。

| 文件 / 目录 | 内容 |
| --- | --- |
| [`overall-architecture.md`](overall-architecture.md) | **先读这一份**：项目是什么、五个仓怎么分、去哪看细节、按任务找什么、`docs/` 下其他目录的定性、已知缺口 |
| [`governance.md`](governance.md) | 谁决定什么、改动怎么走 |
| [`repos/`](repos/) | 一仓一文件：[`tpl-app`](repos/tpl-app.md) · [`info-app`](repos/info-app.md) · [`knowledge-app`](repos/knowledge-app.md) · [`investment-app`](repos/investment-app.md) · [`k8s`](repos/k8s.md)。各自的硬规则与已知未实现 |
| [`staging.md`](staging.md) | 分期与工作量——计划，不是进度 |
| [`licensing.md`](licensing.md) | 第三方许可与本产品的关系 |
| [`topics/`](topics/) | 跨仓主题：[契约](topics/contracts.md) · [数据](topics/data.md) · [身份](topics/identity.md) · [发布](topics/release.md)；[v5 历史索引](topics/v5-history.md)只用于取回退役材料，不是当前任务入口 |

另外三处：

- [`../dev-investment-agent/pipeline.md`](../dev-investment-agent/pipeline.md)——一次 turn 的九站，以及**每一站现在谁做**（人还是脚本）。⚠ 人机分工的现状只记在那里，本目录不另记；
- [`../dev-investment-agent/turn/`](../dev-investment-agent/turn/README.md)——一次一问一答怎么走完，**跨项目通用**；
- [`../dev-investment-agent/tree-build/`](../dev-investment-agent/tree-build/README.md)——这个项目把九站建成了什么，**本项目专有**。
