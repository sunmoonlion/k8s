# 实施计划

> 迁自 `dev-plan/implementation-plan.md`（tag `dev-plan-final`） 的以下各节（`49d4ecb7`，2026-09-14）。节号沿用原文件；原文件其余各节的去向见 MIGRATION.md（2026-09-15 删除，原文见提交 `e7ab0e0b`）。

## 交付规则

> 依据的通用规范：[SDP「交付、发布与保留」](../../../../../dev-agent-standards/deliverables/sdp/sdp-rules.md)

**分支与提交**——父仓不得出现悬空 gitlink（规则 T4）。五仓同步用
`~/five-repos-sync/sync-five-repos.sh`；它只推父仓，子仓的提交仍须自己推，
否则同步在拉取侧对齐子模块时报错。

**证据**——完成的任务在 `docs/evidence/<task-id>/` 留去敏后的：`result.md`、
测试输出、关键 request/response、migration revision、image digest。
**不得提交 token、Cookie、数据库密码或 API key。**

**单一权威**——架构语义以 [`development-plan.md`](../../composition/development-plan.md) 为准，
本文件只描述执行增量、依赖与验收；API/Schema 以各仓 `contracts/` 发布物为准，
本文件里的字段只用于解释，不作为机器契约。
**发现重复且可能漂移的定义时，删副本改引用，禁止两处同步维护。**
