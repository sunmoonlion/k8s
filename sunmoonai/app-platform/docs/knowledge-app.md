# Knowledge App 架构

## 1. 系统定位

`knowledge-app` 是 App Platform 的统一知识处理与检索能力系统，为所有领域 App
提供文档接入、知识库管理、解析、分块、索引、检索和 RAG 能力。

它不拥有资讯原文、研究结论或投资数据等其他领域主档。领域 App 保存权威数据，
`knowledge-app` 保存知识处理配置、任务状态、映射关系和可重建的处理副本。

## 2. 当前组件

工程完整保留 `tpl-app` 的四个标准组件，当前部署仅启用：

```text
knowledge-app
├── knowledge-admin-backend
├── knowledge-admin-frontend  # 保留，当前关闭
├── knowledge-web-backend     # 保留，当前关闭
├── knowledge-web-frontend    # 保留，当前关闭
├── ragflow
└── deploy-knowledge-app-all
```

`knowledge-admin-backend` 是平台统一知识服务和编排接口。组件名中的 `admin`
表示采用 Python/FastAPI 技术栈，不限制调用方必须是管理界面。

当前 ingestion worker 已支持两种模式：

- 未配置 `RAGFLOW_API_KEY`：保持 mock 模式，只验证任务状态机和队列链路。
- 配置 `RAGFLOW_API_BASE` + `RAGFLOW_API_KEY`：通过 RAGFlow 公开 HTTP API
  创建/查找 Dataset、上传 Document、触发解析并回写 `ragflow_document_id`。

## 3. 职责边界

负责：

- 对外提供稳定的知识服务 API。
- 管理知识空间、文档投递、处理任务和检索请求。
- 管理领域文档与 RAGFlow Dataset、Document 的映射关系。
- 统一认证、权限、幂等、重试、审计和状态回调。
- 隔离 RAGFlow 私有 API，支持未来替换或并行接入其他知识引擎。
- 提供全量重建、增量同步和一致性对账。

不负责：

- 保存其他 App 的唯一原文或业务主档。
- 决定资讯、研究或投资数据的业务含义。
- 把模型输出直接升级为领域事实。

## 4. 调用关系

```text
info-app / research-app / investment-app / tools-app
                         |
                         v
            knowledge-admin-backend
                         |
                         v
                     RAGFlow
```

其他 App 通过 `knowledge-admin-backend` 的公开 API、事件或任务协议使用知识能力，
不直接依赖 RAGFlow API、数据库、MinIO 或 Elasticsearch。

## 5. 数据与存储

`knowledge-app` 的业务数据库保存：

- 知识空间及访问策略。
- 文档投递任务和幂等记录。
- 领域对象、版本与知识引擎对象的映射。
- 处理状态、错误、重试、对账和重建记录。

RAGFlow 自带的 MySQL、MinIO、Elasticsearch 和 Valkey 保存产品内部状态与处理副本。
这些数据必须可由领域主档和 `knowledge-app` 的映射、任务记录重新构建。

## 6. 部署原则

- 四个模板组件完整保留，按集群配置决定是否启动。
- 当前启用 `knowledge-admin-backend` 和 `ragflow`。
- 当前关闭 `knowledge-admin-frontend`、`knowledge-web-backend` 和
  `knowledge-web-frontend`。
- 关闭的 Backend 同时关闭数据库、S3 和 Elasticsearch 自动 provision，避免产生
  无使用者的资源。
- RAGFlow 是 `knowledge-app` 的可替换内部组件，不是跨 App 的直接集成契约。
- `knowledge-admin-backend` 与 worker 默认注入
  `RAGFLOW_API_BASE=http://ragflow-sunmoonai-api:80`；真实入库需在 Secret 中配置
  `RAGFLOW_API_KEY`。
