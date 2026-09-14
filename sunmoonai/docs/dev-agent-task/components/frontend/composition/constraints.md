# 开发必须遵守的规则

> 迁自 [`dev-plan/constraints.md`](../../../../dev-plan/constraints.md) 的单条规则（2026-09-14）；同类其余规则见 [后端的 constraints](../../backend/composition/constraints.md)。前端侧的约束。

## 数据

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| D9 | 前端**不得**持有后端或数据库凭据 | `core/config.py` 启动期校验 |
