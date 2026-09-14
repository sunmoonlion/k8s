# 开发必须遵守的规则

> 迁自 [`dev-plan/constraints.md`](../../../../../dev-plan/constraints.md) 的单条规则（2026-09-14）；同类其余规则见 [后端的 constraints](../../composition/constraints.md)。与交付规则同处：跨仓交付的约束。

## 拓扑

| # | 规则 | 谁在执行 |
| --- | --- | --- |
| T4 | 父仓**不得出现悬空 gitlink**——子仓提交没推，别人克隆父仓会拉不到 | `~/five-repos-sync/sync-five-repos.sh`：它同步五个父仓，拉取侧自动 `submodule update --init --recursive`，子仓提交没推会**当场报错**。⚠ 但它只推父仓不推子仓，子仓的提交仍须自己推 |
| T5 | 跨仓改动宣称"已完成"时，**必须带「仓 + 提交号」**——k8s 与四个 App 是并列独立仓，只写提交信息的话，评审方只能猜取证对象，会得出"改动不存在"的结论 | ⚠ 自检 |
