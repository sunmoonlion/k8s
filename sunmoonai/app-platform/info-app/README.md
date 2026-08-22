# Info 正式部署入口

本目录只保存 Info 的 Architecture v2 平台声明。正式运行形态是两个 Next.js 前端共用一个
FastAPI Backend；Backend 以 API、Celery Worker、Celery Scheduler 和一次性 Migration Job
四种角色运行，并共用同一个业务数据库。

- `deployment/`：与分支名无关的正式 bundle、渲染器和唯一部署实现；
- `deploy-info-app-all/`：总入口、正式发布 `.conf` 与集群 profiles；
- `deploy-info-*/`：API、Worker、Scheduler、Migration 和两个前端的独立部署入口；
- 旧 Admin/Web 双 Backend、NodeBull Worker、旧前端部署树已在 R7.1 退役，不得恢复；
- 业务源码位于独立的 `/home/zymun/master/info-app` 仓库，不复制到本目录。

默认入口：

```bash
./deploy-info-app-all/deploy-info-app-all.sh plan --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh config --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh deploy --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh drift --cluster KIND
./deploy-info-backend-api/deploy-info-backend-api.sh deploy --cluster KIND
```

配置合同见 `../docs/formal-deployment-configuration.md`。当前只有 KIND profile 已通过
`2.0.0` 门禁；镜像、域名、namespace 或副本数变更必须重新 render/gate，不能直接覆盖 bundle。

发布后的不可变 `2.0.0` 证据保持原样；当前分支上的 R7.1 只清理已关闭观察窗的旧运行面，
不会删除业务数据库或发布证据。
