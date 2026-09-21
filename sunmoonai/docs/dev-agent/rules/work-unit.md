# 工作单元的写法

> 依据的通用规范：[IMP「工作单元要说清什么」](../../dev-human/imp/message-rules.md)

本任务拆出的所有子任务，IMP 都照此写（原实施计划）。

测试层次：

```
L1 Unit                    L5 Failure Injection
L2 Component Integration   L6 Evaluation/Quality
L3 Contract                L7 Deployment/Operations
L4 Cross-app E2E
```

P0 / P1 任务必须写明适用层次。

每条任务固定这几栏，**缺栏视为未定义，不开工**：

| 栏 | 写什么 |
| --- | --- |
| 类型/优先级 | `ARCH` / `FEAT` / `FIX` / `OPS` + `P0`–`P2` |
| 仓库 | 涉及哪几个仓——跨仓任务必须列全，否则漏推 |
| 前置 | 依赖哪些任务或哪条未决项定了才能开工 |
| 目标 | 一句话说清做完之后什么变了 |
| 实施 | 具体动什么。**不写"完善 X"这种没有终点的表述** |
| 测试 | 适用的测试层次（见上），**不能只写"补测试"** |
| 验收 | 可判定的条件。做完能一条条对着勾 |
| 回滚 | 出问题怎么退回去 |
| 状态 | `NOT_STARTED` / `IN_PROGRESS` / `BLOCKED` / `ACCEPTED` + 日期与证据 |
