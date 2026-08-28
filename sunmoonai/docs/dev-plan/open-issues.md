# 已知缺口

> 最后更新：2026-08-28
>
> 从五仓代码投影中查出、**发现但未处置**的八项。原先埋在
> [`../project-guide/history.md`](../project-guide/history.md)（那是归档，写完即冻结），
> 移到这里因为它们是活的待办。
>
> 按 [`../project-guide/request-lifecycle.md`](../project-guide/request-lifecycle.md) R6：
> 每条要么立请求，要么写一条 ADR 声明"已知并接受"。**当前状态：全部待定。**

编号 O 系列，与 [`README.md`](README.md)「下一步」的 U 系列（智能体设计未决）不同：
U 是"还没想清楚"，O 是"已经查实、等着处理"。

| # | 事项 | 出处 | 性质 |
| --- | --- | --- | --- |
| O1 | 代码层 `2.0.0.dev0` 与部署层 `formal_release: true` 矛盾，且有测试阻止代码层追平 | [总览](../project-guide/overall-architecture.md) §9.1 | 需澄清是有意还是缺陷 |
| O2 | RAGFlow `CANCEL` 被当作成功，被取消的摄入标记为 succeeded | [`repos/knowledge-app.md`](../project-guide/repos/knowledge-app.md) §7 | 数据完整性风险 |
| O3 | `RunBudget` 生产未接线，`budget_exceeded` 状态不可达 | [`repos/investment-app.md`](../project-guide/repos/investment-app.md) §4.5 | 已设计未接线 |
| O4 | 共享 Outbox/Inbox 四仓零业务调用 | [总览](../project-guide/overall-architecture.md) §9.2 | 模板有意留白，倾向"声明接受" |
| O5 | 四仓均无 `beat_schedule`，Scheduler 空转 | [总览](../project-guide/overall-architecture.md) §9.2 | 同上 |
| O6 | 契约 `source_href` 与真实路由不匹配，照字面 GET 会 404 | [`topics/contracts.md`](../project-guide/topics/contracts.md) §5 | 契约缺陷 |
| O7 | REQ-009 的"休眠能力声明+校验"机制未落地 | [来历记录](../project-guide/history.md) §3.3 | 机制缺口 |
| O8 | `docs/` 下并存的历史目录尚未清理 | [`README.md`](../project-guide/README.md) §本集之外 | 见该节 |

## 与智能体计划的交叉

**O3 就是 [`README.md`](README.md) 下一步表里的 U3。**同一件事的两面：
O3 是"投资仓已经有 `RunBudget` 设计但没接线"，U3 是"四本账要落 PG 的表结构未定"。
做 U3 时直接把 O3 一并了结，不要另起一套预算表。

其余七项与智能体架构无关，可独立处理。

## 优先级判断

**O2 与 O6 是真缺陷，其余是待澄清或有意留白。**

- **O2** 数据完整性：被取消的摄入被标记为 succeeded，下游会把不完整的知识当成完整的用
- **O6** 契约缺陷：`source_href` 照字面 GET 会 404，任何按契约文档实现的 consumer 都会踩

O1（版本矛盾）需要的是一个决定，不是修复——先确认 `formal_release: true` 是否有意。

O4、O5 倾向"声明接受"：模板有意留白，等实例填。按 R6 也应落一条记录，
否则下一轮投影会再次把它们当成缺口报一遍。
