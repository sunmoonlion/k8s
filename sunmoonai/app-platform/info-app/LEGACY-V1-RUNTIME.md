# Info legacy v1 runtime boundary

- Status: rollback/current-baseline only
- Updated: 2026-08-09

本目录名 `info-app` 仍是 Info 领域的规范 K8s 入口，但其中以下子目录描述的是
架构 v2 切流前的 v1 四组件运行基线：

- `info-admin-backend`
- `info-web-backend`
- `celeryworker-info-admin-backend`
- `nodebullworker-info-web-backend`
- 相关 Admin/Web Frontend 与 `deploy-info-app-all`

它们不是 `info-app` 父仓的活跃源码拓扑，也不得作为新 v2 部署生成器输入。R5
数据迁移和 R7 观察窗完成前保留这些声明，用于当前环境运维、整体回滚和差异审计。
删除、改名或切流必须由对应阶段门禁执行，不能因源码父仓已经收口而提前清理。

架构 v2 的目标运行形态是两个 Next.js Frontend 与同一 `info-backend` 镜像的 API、
Worker、Scheduler、Migration 等独立角色；其权威施工状态见
`sunmoonai/docs/architecture-v2/`。
