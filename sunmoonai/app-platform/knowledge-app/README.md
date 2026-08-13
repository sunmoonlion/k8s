# Knowledge Architecture v2 部署入口

本目录只保存 Knowledge 的 Architecture v2 平台声明。两个 Next.js 前端共用一个 FastAPI
Backend；Backend 以 API、Celery Worker、Celery Scheduler 和 Migration Job 四种角色运行，
并共用同一个业务数据库。

- `architecture-v2/`：正式 bundle、渲染器和唯一部署实现；
- `deploy-knowledge-app-all/`：面向平台总入口的薄包装；
- `providers/ragflow/`：Knowledge 拥有的外部 RAGFlow Provider 部署声明；
- `components/`：仅保存未来可能接入的组件源码，不属于当前运行拓扑；
- 旧 Admin/Web 双 Backend、Celery V1 Worker 和旧前端部署树已在 R7.1 退役。

默认入口：

```bash
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh plan --cluster KIND
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh deploy --cluster KIND
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh drift --cluster KIND
```

RAGFlow 是 Knowledge 的 Provider，不是第四个业务 App；其数据库与 PVC 不属于旧 V1 清理范围。
