# 实施计划

> 最后更新：2026-08-29
>
> **这里是任务本体：每件事怎么做、怎么算做完。**
>
> 现在到哪了、什么不能倒退，见 [`handoff.md`](handoff.md)；
> 为什么这么建见 [`development-plan.md`](development-plan.md)；
> 代码必须符合的规则见 [`constraints.md`](constraints.md)。

## 任务条目格式

每条任务固定这几栏，**缺栏视为未定义，不开工**：

| 栏 | 写什么 |
| --- | --- |
| 类型/优先级 | `ARCH` / `FEAT` / `FIX` / `OPS` + `P0`–`P2` |
| 仓库 | 涉及哪几个仓——跨仓任务必须列全，否则漏推 |
| 前置 | 依赖哪些任务或哪条未决项定了才能开工 |
| 目标 | 一句话说清做完之后什么变了 |
| 实施 | 具体动什么。**不写"完善 X"这种没有终点的表述** |
| 测试 | 适用的测试层次（见下），**不能只写"补测试"** |
| 验收 | 可判定的条件。做完能一条条对着勾 |
| 回滚 | 出问题怎么退回去 |
| 状态 | `NOT_STARTED` / `IN_PROGRESS` / `BLOCKED` / `ACCEPTED` + 日期与证据 |

## 测试层次

```
L1 Unit                    L5 Failure Injection
L2 Component Integration   L6 Evaluation/Quality
L3 Contract                L7 Deployment/Operations
L4 Cross-app E2E
```

P0 / P1 任务必须写明适用层次。

## 交付规则

**分支与提交**——子仓先推，父仓后推；父仓不得出现悬空 gitlink（规则 T4）。
推送后复核 gitlink 是否可达，见 [`../working/collaboration.md`](../working/collaboration.md) §3。

**证据**——完成的任务在 `docs/evidence/<task-id>/` 留去敏后的：`result.md`、
测试输出、关键 request/response、migration revision、image digest。
**不得提交 token、Cookie、数据库密码或 API key。**

**单一权威**——架构语义以 [`development-plan.md`](development-plan.md) 为准，
本文件只描述执行增量、依赖与验收；API/Schema 以各仓 `contracts/` 发布物为准，
本文件里的字段只用于解释，不作为机器契约。
**发现重复且可能漂移的定义时，删副本改引用，禁止两处同步维护。**

## 阶段一 · 前后端对接

### 任务清单

**空。**U1（web 面生产适配器的形状）未定——薄转发还是自持投影，决定了要写
什么、测什么、有没有迁移。现在列出来的任何任务都会作废。

U1 一定，本节即刻填充。U1 的已知输入见 [`handoff.md`](handoff.md)。

## 阶段二 · agent 开发

未开工。见 [`development-plan.md`](development-plan.md)。

## 阶段三 · 结构化数据问答

未开工，且有一个开工前置：投资仓现在没有任何业务数据表。
见 [`development-plan.md`](development-plan.md)。
