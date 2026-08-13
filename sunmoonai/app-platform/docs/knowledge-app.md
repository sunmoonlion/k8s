# Knowledge App 架构

最后更新：2026-08-13

## 1. 系统定位

`knowledge-app` 是独立领域 App，负责 Artifact 摄取、知识对象版本、知识引擎绑定、索引、
检索和引用元数据。Info 拥有原文与 Artifact，Investment 拥有投资研究和证据使用记录；
Knowledge 不复制二者的权威主档。

## 2. 当前 Architecture v2 拓扑

```text
knowledge-app/
├── knowledge-backend          # 唯一 FastAPI Backend
├── knowledge-admin-frontend   # Next.js Admin
└── knowledge-web-frontend     # Next.js Web

Kubernetes:
knowledge-r5-backend-api       # HTTP / Admin / Web / Internal API
knowledge-r5-backend-worker    # Celery 摄取和外部 provider 任务
knowledge-r5-backend-scheduler # 扫描、补偿、对账
knowledge-r5-admin-frontend
knowledge-r5-web-frontend
```

API、Worker、Scheduler 和 Migration 使用同一 `knowledge-backend` 源码与不可变镜像，但以
不同命令、ServiceAccount、凭据和容量策略运行。旧 `knowledge-admin-backend`、
`knowledge-web-backend` 和独立 worker 仓/部署树已在 R7.1 退役，不是回滚入口。

## 3. 接口与调用关系

```text
Info Artifact + Outbox
          |
          v
Knowledge Internal Ingestion -> knowledge-backend -> RAGFlow
                                             |
Investment service identity -> Retrieval API-+
```

- Admin/Web 前端共享同一个 Backend 和一个 Knowledge 逻辑数据库；
- Admin、Web、Internal 是独立接口与身份分面，不是独立 Backend；
- Info 使用受绑定的服务身份投递不可变 Artifact；
- Investment 使用受绑定的服务身份检索；
- 调用方不能直接访问 Knowledge 数据库、RAGFlow、MinIO 或 Elasticsearch。

## 4. 数据所有权

Knowledge 数据库保存：

- 摄取任务、幂等键、状态历史和失败分类；
- Knowledge Document/Version；
- Info 源文档版本与 Knowledge 版本的稳定映射；
- Dataset/Document provider binding；
- 检索、引用所需的稳定元数据。

RAGFlow 的 MySQL、MinIO、Elasticsearch 和 Redis 保存 provider 内部状态与可重建派生数据，
不能成为跨 App 契约或唯一业务主档。

## 5. 正式运行规则

- 正式摄取必须使用真实 Artifact、真实 RAGFlow 和真实 embedding provider；禁止 mock success；
- RAGFlow 通过 `knowledge-ragflow-provider` 和 `RAGFLOW_API_BASE` 适配，调用方不可见 provider ID；
- 解析失败、配置失败、Artifact 不可读和外部 API 失败必须有稳定、可重试的分类；
- 正式 bundle 由 `knowledge-app/deployment/render.py` 生成并按 digest 固定镜像；
- 当前正式 release id 为 `v20-knowledge-formal-001`，正式版本与 Info、Investment 统一为
  `2.0.0`；R7.1 深层门禁包含真实
  Info→Knowledge→Investment 竖线、严格 TLS 和 Casdoor 浏览器登录。

总体边界以[App Platform 总体架构](../../docs/sunmoonai-architecture/baseline/overall/app-platform-architecture.md)
为准。
