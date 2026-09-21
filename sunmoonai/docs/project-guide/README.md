# `project-guide/` 目录

**本目录只回答「项目现在是什么样」**，随代码覆盖式重写；不放规则，也不放脚本。

| 文件 / 目录 | 内容 |
| --- | --- |
| [`overall-architecture.md`](overall-architecture.md) | **先读这一份**：项目是什么、五个仓怎么分、去哪看细节、按任务找什么、`docs/` 下其他目录的定性、已知缺口 |
| [`governance.md`](governance.md) | 谁决定什么、改动怎么走 |
| [`repos/`](repos/) | 一仓一文件：[`tpl-app`](repos/tpl-app.md) · [`info-app`](repos/info-app.md) · [`knowledge-app`](repos/knowledge-app.md) · [`investment-app`](repos/investment-app.md) · [`k8s`](repos/k8s.md)。各自的硬规则与已知未实现 |
| [`topics/`](topics/) | 跨仓主题：[契约](topics/contracts.md) · [数据](topics/data.md) · [身份](topics/identity.md) · [发布](topics/release.md) |

另外两处：规则与要建什么在 [`../dev-agent/`](../dev-agent/)（**代码要跟着改**），
怎么共事在 [`../dev-human/`](../dev-human/)（协作方式变，代码不变）。
