# Knowledge legacy v1 runtime boundary

- Status: rollback/current-baseline only
- Updated: 2026-08-09

本目录名 `knowledge-app` 仍是 Knowledge 领域的规范 K8s 入口，但其中旧
Admin/Web Backend、Celery/NodeBull worker、前端与 `deploy-knowledge-app-all` 描述的是
架构 v2 切流前的 v1 四组件运行基线。

这些目录不是 `knowledge-app` 父仓的活跃源码拓扑，也不得作为新 v2 部署生成器输入。
R5 数据迁移和 R7 观察窗完成前保留它们，用于当前环境运维、整体回滚和差异审计。
删除、改名或切流必须由对应阶段门禁执行。

`ragflow/` 以及 `components/document-converter-backend`、
`components/onlyoffice-docs-bff` 是 Knowledge 领域外部能力/适配器，不因统一 Backend
而自动废弃；是否进入目标部署闭包由后续阶段单独决定。

架构 v2 的目标运行形态是两个 Next.js Frontend 与同一 `knowledge-backend` 镜像的
API、Worker、Scheduler、Migration 等独立角色；权威施工状态见
`sunmoonai/docs/architecture-v2/`。
