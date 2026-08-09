# Info legacy v1 runtime boundary

- Status: rollback/current-baseline only
- Updated: 2026-08-09

本目录名 `info-app` 仍是 Info 领域的规范 K8s 入口。架构 v2 切流前的六组件 v1 运行基线已
整体隔离到 `legacy-v1/`：

- `legacy-v1/info-admin-backend`
- `legacy-v1/info-web-backend`
- `legacy-v1/celeryworker-info-admin-backend`
- `legacy-v1/nodebullworker-info-web-backend`
- `legacy-v1/info-admin-frontend`
- `legacy-v1/info-web-frontend`

它们不是 `info-app` 父仓的活跃源码拓扑，默认 `deploy-info-app-all` 不扫描、不调用这些目录。
R7 观察窗完成前保留这些声明，用于整体回滚和差异审计。
删除、改名或切流必须由对应阶段门禁执行，不能因源码父仓已经收口而提前清理。

当前正式运行形态是两个 Next.js Frontend 与同一 `info-backend` 镜像的 API、Worker、
Scheduler、Migration 独立角色；其 Git 真相源是 `architecture-v2/`，默认入口是
`deploy-info-app-all/deploy-info-app-all.sh`。历史整体部署脚本仍可从冻结提交恢复，但不得伪装成
当前默认入口。
