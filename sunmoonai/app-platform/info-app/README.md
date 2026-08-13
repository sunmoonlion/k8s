# Info Architecture v2 部署入口

本目录只保存 Info 的 Architecture v2 平台声明。正式运行形态是两个 Next.js 前端共用一个
FastAPI Backend；Backend 以 API、Celery Worker、Celery Scheduler 和一次性 Migration Job
四种角色运行，并共用同一个业务数据库。

- `architecture-v2/`：正式 bundle、渲染器和唯一部署实现；
- `deploy-info-app-all/`：面向平台总入口的薄包装；
- 旧 Admin/Web 双 Backend、NodeBull Worker、旧前端部署树已在 R7.1 退役，不得恢复；
- 业务源码位于独立的 `/home/zymun/info-app` 仓库，不复制到本目录。

默认入口：

```bash
./deploy-info-app-all/deploy-info-app-all.sh plan --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh deploy --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh drift --cluster KIND
```

发布后的不可变 `2.0.0` 证据保持原样；当前分支上的 R7.1 只清理已关闭观察窗的旧运行面，
不会删除业务数据库或发布证据。
