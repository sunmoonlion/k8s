# Info App 采集与资讯治理实施任务清单

## 1. 任务状态

- 状态：实施中（第一轮后端最小闭环已落代码，并已用本机 kind PostgreSQL / Redis 跑通基础验证）
- 优先级：高
- 所属阶段：Info App MVP
- 主架构文档：`info-app/docs/info-app-spider-architecture.md`
- 参考资料：`info-app/docs/spider-reference/`
- 首个目标：跑通“手动提交 URL -> 采集 -> 原始证据保存 -> 正文抽取 -> 资讯主档入库”的最小闭环。

## 2. 实施原则

1. 先闭环，再扩来源。
2. 先保存原始证据，再做抽取和派生处理。
3. 先做 `info-app` 主档，不直接绑定 RAGFlow 私有 API。
4. 先实现后端和 worker，前端管理界面后置。
5. 所有可重建副本都能从 PostgreSQL 和 S3 主档恢复。
6. 每个阶段都要有可运行、可验证的结果。

## 3. 目标闭环

第一条闭环如下：

```text
POST URL
  -> create crawl_job
  -> worker fetch HTML
  -> save raw.html and headers.json
  -> extract clean.md and text.txt
  -> create document and document_version
  -> update crawl_job status
  -> query document detail
```

## 4. 阶段 A：现状摸底

- [x] A1. 确认 `info-admin-backend` 技术栈、启动方式、依赖管理和数据库接入方式。
- [x] A2. 确认 `celeryworker-info-admin-backend` 当前模板结构、任务注册方式和运行入口。
- [x] A3. 确认现有 PostgreSQL、S3、Elasticsearch 运行配置是否已注入到 `info-app`。
- [x] A4. 确认是否已有 ORM、migration、配置加载、日志、健康检查和测试约定。
- [x] A5. 标记哪些目录只是 K8S 部署模板，哪些目录已经包含业务源码。

验收标准：

- [x] 形成实际代码落点说明。
- [x] 明确第一阶段是否需要先补模板基础设施。

摸底结论：

- 业务源码位于 `/home/zym/info-app/info-admin-backend/app`，平台目录 `k8s/sunmoonai/app-platform/info-app` 主要是 K8S 部署骨架。
- `info-admin-backend` 是 FastAPI + SQLAlchemy async + Alembic + Celery 模板。
- `celeryworker-info-admin-backend` 在源码仓库内主要是部署骨架，实际 worker 入口与 admin backend 共用镜像和 `app.worker`。
- PostgreSQL、Redis、S3、Elasticsearch 已有 bootstrap/config 约定；本轮先使用本地对象存储 fallback，K8S 用环境变量切换到平台 S3。

## 5. 阶段 B：领域模型与数据库

- [x] B1. 设计 `info_source` 表。
- [x] B2. 设计 `info_collector` 表。
- [x] B3. 设计 `crawl_job` 表。
- [x] B4. 设计 `raw_artifact` 表。
- [x] B5. 设计 `info_document` 表。
- [x] B6. 设计 `info_document_version` 表。
- [x] B7. 设计 `extracted_content` 表。
- [x] B8. 设计 `distribution_record` 表。
- [x] B9. 增加 URL、内容哈希、版本号、状态和时间字段的索引。
- [x] B10. 编写 migration 并提供本地执行说明。

验收标准：

- [x] migration 可重复执行到目标状态。
- [x] 数据模型能表达 URL 去重、内容版本和原始证据对象路径。

当前说明：

- migration 已移除 `uuid-ossp` / `uuid_generate_v4()` 依赖，UUID 由应用侧生成。
- 已用本机 kind PostgreSQL 创建全新临时库，并用普通 `info_admin_user` 执行 `alembic upgrade head` 成功。

## 6. 阶段 C：基础 API

- [x] C1. 实现创建信息源 API。
- [x] C2. 实现查询信息源 API。
- [x] C3. 实现手动提交 URL 并创建 `crawl_job` API。
- [x] C4. 实现查询 `crawl_job` 状态 API。
- [x] C5. 实现查询 document 列表 API。
- [x] C6. 实现查询 document 详情和版本 API。
- [x] C7. 实现基础错误码和状态机。

建议首批 API：

```text
POST /admin/sources
GET  /admin/sources
POST /admin/crawl-jobs
GET  /admin/crawl-jobs/{id}
GET  /documents
GET  /documents/{id}
GET  /documents/{id}/versions
```

验收标准：

- [x] 可以通过 API 创建 URL 采集任务。
- [x] 任务状态可以从 `pending` 变为 `running`、`succeeded` 或 `failed`。
- [x] 失败任务记录明确原因。

## 7. 阶段 D：对象存储接入

- [x] D1. 确认 Info App S3 Bucket、Secret 和环境变量名称。
- [x] D2. 实现 Python S3 Adapter。
- [x] D3. 实现 object key 生成规则。
- [x] D4. 上传 `raw.html`。
- [x] D5. 上传 `headers.json`。
- [x] D6. 上传 `clean.md` 和 `text.txt`。
- [x] D7. 保存 `bucket`、`object_key`、`sha256`、`size_bytes`、`content_type`。
- [x] D8. 写入后执行 head 校验。

验收标准：

- [x] 原始响应和抽取产物都能在对象存储找到。
- [x] 数据库不保存永久下载 URL，只保存对象清单。

当前说明：

- 已通过本机端口转发平台 MinIO/AIStor，用 `STORAGE_BACKEND=s3` 跑通 HTML crawl job。
- 验证 job `93785fb0-efea-4dac-be2d-3ef0fddbe8f9` 成功生成 `raw_html`、`headers_json`、`clean_markdown`、`text_plain` 四类 artifact，均写入 `development-info-originals`，并返回对象 `version_id`。

## 8. 阶段 E：最小采集 worker

- [x] E1. 在 `celeryworker-info-admin-backend` 中注册 `crawl_url` 任务。
- [x] E2. 使用 `httpx` 拉取静态 HTML。
- [x] E3. 保存状态、耗时、HTTP 状态码、最终 URL、错误信息。
- [x] E4. 支持超时、重试和最大响应大小限制。
- [x] E5. 计算内容哈希。
- [x] E6. 将原始证据写入 S3。
- [x] E7. 采集失败时仍保存必要的失败元数据。

验收标准：

- [x] 手动提交一个网页 URL 后，worker 能完成采集。
- [x] 网络失败、非 200 响应和抽取失败有不同状态说明。

验证记录：

- 平台 RabbitMQ 默认队列 `info.admin.default` 已验证。API 投递 job
  `a14ebe20-2bf1-422a-8637-fc9178ebff9c` 后，本地 worker 消费
  `app.tasks.crawl_url`，生成 `document_version=947851da-be8a-418b-be86-2d255869eb91`，
  并写入 `development-info-originals` 下 raw/header/clean/text 四类 artifact。

## 9. 阶段 F：正文抽取与版本治理

- [x] F1. 接入 `trafilatura`。
- [x] F2. 提取标题、正文 Markdown、纯文本、发布时间候选值。
- [x] F3. 抽取失败时保留原始证据并标记 `extraction_failed`。
- [x] F4. 同 URL 同内容不重复创建版本。
- [x] F5. 同 URL 内容变化创建新的 `document_version`。
- [x] F6. 生成 `info_document` 当前版本指针。
- [x] F7. 保存抽取器名称、版本和处理时间。

验收标准：

- [x] 重复采集同一 URL 不产生重复主档。
- [x] 页面内容变化时能形成新版本。
- [x] 抽取产物可从 API 查询。

## 10. 阶段 G：基础搜索

- [x] G1. 如果平台 Elasticsearch 资源已可用，声明 Info App `information` 索引字段。
- [x] G2. 实现索引写入 adapter。
- [x] G3. 在 document version 成功后写入搜索索引。
- [x] G4. 提供关键词搜索和来源、时间、状态过滤。
- [x] G5. 明确索引可从 PostgreSQL 和 S3 重建。

验收标准：

- [x] 可以按关键词搜索已采集资讯。
- [x] 删除索引后有重建方案。

当前说明：

- 第一轮先提供 PostgreSQL 标题/URL 查询，满足 MVP 管理检索。
- `info-admin-backend` 已声明 `info-information` mapping，并提供 Elasticsearch/OpenSearch 写入 adapter。
- `POST /api/admin/search-index/rebuild` 可从 PostgreSQL 中的 `document_version` 和 S3 artifact 引用重建索引。
- `document_version` 创建并提交成功后会触发增量索引；Celery broker 可用时后台执行，未配置时主事务提交后 best-effort 执行，避免外部搜索服务故障影响采集主事务。
- 已补齐平台运行配置：后端支持 `ELASTICSEARCH_USERNAME` / `ELASTICSEARCH_PASSWORD` / `ELASTICSEARCH_CA_CERT_PATH` / `ELASTICSEARCH_ALIASES`，K8S ConfigMap 默认启用 `SEARCH_BACKEND=elasticsearch`，并优先写入 provisioner 提供的 `information.write` alias。
- 已通过平台 Elasticsearch Secret/CA 和 `development-info-app-information-write` alias 验证真实写入；验证文档写入 `development-info-app-information-v1-000001` 后已删除。
- 已通过平台 RabbitMQ 队列验证 `document_version` 成功后继续投递并执行 `app.tasks.index_document_version`。

## 11. 阶段 H：Knowledge App 分发接口

- [x] H1. 定义 `info-app -> knowledge-app` 的 ingestion payload。
- [x] H2. 在 `distribution_record` 中记录目标、版本、内容哈希和状态。
- [x] H3. 实现手动分发 API 或后台任务。
- [x] H4. 不直接调用 RAGFlow 私有 API。
- [x] H5. 支持失败重试和状态对账。

验收标准：

- [x] `info-app` 能产生可分发的规范化文档包。
- [x] `knowledge-app` / RAGFlow 故障不影响资讯主档保存。

当前说明：

- `info-admin-backend` 已提供分发记录列表、详情、状态更新、失败重试和手动 dispatch API。
- 状态对账记录保存在 `distribution_record.payload.status_history`，重试记录保存在 `payload.retry_history`。
- 失败重试当前将 `failed` 记录重置为 `pending`，供后续分发 worker 再次处理。
- 配置 `KNOWLEDGE_APP_INGEST_URL` 后可投递到 `knowledge-app` ingestion API；Celery broker 可用时后台执行，未配置时同步执行一次。未配置 ingestion URL 时记录保持 `pending` 并写入跳过原因。

## 12. 阶段 I：管理后台

- [x] I1. 信息源列表和详情。
- [x] I2. 手动提交 URL。
- [x] I3. 采集任务列表、详情和失败原因。
- [x] I4. 文档列表、详情、版本和原始证据入口。
- [x] I5. 抽取结果审核和状态调整。

验收标准：

- [x] 无需直接查数据库即可完成第一阶段日常操作。

当前说明：

- `info-admin-frontend/src/pages/info/crawl.vue` 已提供最小管理入口，覆盖来源、URL 任务、collector、上传和文档列表。
- `info-admin-backend` 已提供 document 与 document_version 审核状态调整 API，可记录 reviewer、reason 和 review_history。
- 前端依赖已安装，`pnpm type-check` 和 `pnpm build-only` 已通过。
- 本机 API 已通过 `POST /api/admin/crawl-jobs/{job_id}/run` 抓取 `http://127.0.0.1:18080/`，生成 `document_id` 与 `document_version_id`；外网 `https://example.com` 在当前网络下超时并被记录为业务失败。
- K8S `info-admin-backend-config` 默认启用 `STORAGE_BACKEND=s3`，Celery worker 也会继承业务 PostgreSQL、Redis、S3、Elasticsearch 配置，并挂载 Elasticsearch CA。

## 13. 阶段 J：来源扩展

- [x] J1. RSS/Atom adapter。
- [x] J2. 官方 API adapter。
- [ ] J3. Scrapy spider adapter。
- [x] J4. PDF/Office 上传与附件处理。
- [ ] J5. Playwright 动态页面 adapter。
- [x] J6. changedetection 触发器。

验收标准：

- [ ] 新来源接入不改变 document 主档模型。
- [ ] 动态页面只作为高价值来源的按需能力。

当前说明：

- RSS/Atom adapter 已实现，可发现 feed 条目并创建待采集 `crawl_job`。
- 官方 API adapter 已实现，可从 JSON 列表发现 URL 并创建待采集 `crawl_job`。
- 文件上传入口已实现；PDF/Office 暂标记为 `pending_tool_processing`，等待 `tools-app` 转换/OCR。
- changedetection 触发器已实现为变化触发到 `crawl_job` 的桥接。
- Scrapy 和 Playwright 已有 adapter 契约与显式占位实现，后续接专用 crawler worker。

## 14. 阶段 K：治理增强

- [ ] K1. 来源可信度和版权状态。
- [ ] K2. 近似重复检测。
- [ ] K3. 转载关系和同源合并。
- [ ] K4. 公司、证券、行业、主题关联。
- [ ] K5. 摘要、标签和重要性评分。
- [ ] K6. 人工审核和审计日志。

验收标准：

- [ ] 模型处理结果可追溯，不覆盖人工确认结果。

## 15. 第一轮建议执行顺序

第一轮只做到可运行闭环：

1. A：现状摸底。
2. B：最小数据模型。
3. C：创建 URL 采集任务 API。
4. D：S3 Adapter。
5. E：最小 URL 采集 worker。
6. F：正文抽取与 document 入库。

完成后再进入搜索、RAG 分发和管理前端。

## 16. 本轮暂不做

- 大规模代理池。
- 自动验证码处理。
- 复杂登录态采集。
- 全量投资分析逻辑。
- 直接调用 RAGFlow 私有 API。
- 把 RAGFlow 存储当作原文主档。
- 前端完整产品化。

## 17. 关联文档

- [Info App 采集与资讯治理架构](./info-app-spider-architecture.md)
- [爬虫项目参考资料](./spider-reference/README.md)
- [平台 Info App 架构](../../docs/info-app.md)
- [ADR-0001：按长期业务领域划分 App](../../docs/adr/0001-domain-boundaries.md)
- [ADR-0005：RAGFlow 定位为可重建的派生系统](../../docs/adr/0005-ragflow-as-derived-system.md)
