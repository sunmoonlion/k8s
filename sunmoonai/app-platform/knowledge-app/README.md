# Knowledge 正式部署入口

本目录只保存 Knowledge 的 Architecture v2 平台声明。两个 Next.js 前端共用一个 FastAPI
Backend；Backend 以 API、Celery Worker、Celery Scheduler 和 Migration Job 四种角色运行，
并共用同一个业务数据库。

- `deployment/`：与分支名无关的正式 bundle、渲染器和唯一部署实现；
- `deploy-knowledge-app-all/`：总入口、正式发布 `.conf` 与集群 profiles；
- `deploy-knowledge-*/`：API、Worker、Scheduler、Migration 和两个前端的独立部署入口；
- `providers/ragflow/`：Knowledge 拥有的外部 RAGFlow Provider 部署声明；
- `components/`：仅保存未来可能接入的组件源码，不属于当前运行拓扑；
- 旧 Admin/Web 双 Backend、Celery V1 Worker 和旧前端部署树已在 R7.1 退役。

默认入口：

```bash
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh plan --cluster KIND
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh config --cluster KIND
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh deploy --cluster KIND
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh drift --cluster KIND
./deploy-knowledge-backend-worker/deploy-knowledge-backend-worker.sh deploy --cluster KIND
```

配置合同见 `../docs/formal-deployment-configuration.md`。旧 V1 `.conf` 已移除；当前文件声明并
校验正式 `2.0.0` 的统一 Backend、双 Next.js 前端和五个工作负载副本数。

RAGFlow 是 Knowledge 的 Provider，不是第四个业务 App；其数据库与 PVC 不属于旧 V1 清理范围。
