# 开发必须遵守的规则

> 迁自 [`dev-plan/constraints.md`](../../../../../dev-plan/constraints.md) 的单条规则（2026-09-14）；同类其余规则见 [后端的 constraints](../../composition/constraints.md)。执行层的约束。

## 智能体

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| A4 | 执行层**租用不自建**，依赖边界严格限定在 SDK，不得直接依赖裸协议 | ⚠ 自检 |
| A5 | 领域概念**不得进入 Port 签名**（`run(sql, limit)` 可以，`run_portfolio_query(持仓ID)` 不可以） | ⚠ 自检 |
