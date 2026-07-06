# Info App 采集与资讯治理架构

## 1. 定位

`info-app` 是平台的资讯主系统，负责信息源管理、采集、原始证据保存、正文抽取、版本治理、去重、分类、检索、订阅、分发和审计。

爬虫项目不是一个独立的业务 App，也不是 `knowledge-app` 或 `investment-app` 的附属脚本。它应当作为 `info-app` 的采集与资讯治理能力存在：

- 爬虫、网页监测、正文抽取、反爬策略和采集任务属于 `info-app`。
- RAG 入库、文档分块、向量索引和问答属于 `knowledge-app` 的派生处理能力。
- 投资分析、研究观点、组合决策和使用记录属于 `investment-app` 的业务场景。
- OCR、格式转换、文件解析等跨领域通用能力可由 `tools-app` 提供，`info-app` 负责编排和接收结果。

这份文档是 `docs/info-app.md` 的采集侧细化说明，参考资料见 `spider-reference/`。

## 2. 核心原则

1. 一份资讯，一个权威主档。
2. 原始证据必须先落地，再做清洗、摘要、入库、RAG 分发等派生处理。
3. 采集系统保存事实和证据，不保存投资结论。
4. RAGFlow 是可重建的派生系统，不保存唯一原文。
5. 反爬策略按来源分级治理，不能把浏览器模拟作为所有站点的默认路径。
6. 采集、治理、检索、分发是同一条资讯生命周期的不同阶段，不应拆成互相绕过的脚本。

## 3. 目标能力

`info-app` 需要长期覆盖以下能力：

- 信息源目录：网站、栏目、RSS、API、文件上传、邮件、公告源、监管源、研报源。
- 采集任务：一次性采集、定时采集、增量采集、重点页面监测、失败重试。
- 原始证据：HTML、PDF、Office、附件、HTTP 头、截图、抓取时间、来源 URL、内容哈希。
- 正文抽取：HTML 正文、标题、发布时间、作者、机构、附件链接、正文 Markdown、纯文本。
- 版本治理：同一 URL 或同一资讯的变化记录、差异对比、撤稿和修订。
- 去重合并：URL 去重、内容哈希去重、相似文本去重、同源转载合并。
- 分类标注：公司、证券、行业、地区、主题、事件、重要性、可信度、版权状态。
- 全文检索：面向资讯库的结构化筛选与全文检索。
- 下游分发：向 `knowledge-app` 分发可处理副本，向 `investment-app` 提供资讯引用。
- 审计与观测：来源成功率、失败原因、抽取质量、任务耗时、反爬风险、下游同步状态。

## 4. 领域对象

建议从以下核心对象建模：

| 对象 | 说明 | 权威归属 |
|---|---|---|
| `source` | 信息源，如网站、栏目、API、RSS、文件入口 | info-app |
| `collector` | 采集器定义，如 Scrapy spider、API adapter、RSS adapter | info-app |
| `crawl_job` | 采集任务实例，记录参数、状态、耗时和失败原因 | info-app |
| `raw_artifact` | 原始 HTML、PDF、附件、截图、HTTP 元数据 | info-app S3 |
| `document` | 规范化后的资讯主档 | info-app |
| `document_version` | 每次内容变化对应的版本 | info-app |
| `extracted_content` | 正文 Markdown、纯文本、结构化字段 | info-app |
| `entity_link` | 公司、证券、行业、主题、地区等关联 | info-app |
| `dedup_group` | 去重和同源合并关系 | info-app |
| `distribution_record` | 分发到搜索、RAG、订阅等下游的记录 | info-app |
| `knowledge_mapping` | RAGFlow Dataset/Document 映射和处理状态 | knowledge-app |
| `investment_usage` | 资讯被投资研究使用的记录 | investment-app |

## 5. 采集流水线

标准流水线如下：

```text
source
  -> schedule / manual trigger / change detection
  -> crawl_job
  -> fetch raw response
  -> save raw_artifact
  -> extract content
  -> normalize metadata
  -> deduplicate and version
  -> classify and link entities
  -> index for info search
  -> distribute to knowledge-app / subscription / alert
```

关键要求：

- `raw_artifact` 在正文抽取前保存，避免抽取失败导致证据丢失。
- 每个处理阶段必须记录输入版本、输出版本、处理器名称和处理时间。
- 抽取失败不等于采集失败；失败页面仍应保留原始响应以便复跑。
- 下游分发使用内容哈希和版本号判断是否需要重新处理。

## 6. 技术组件建议

### 6.1 基础采集

默认使用轻量、稳定、可观测的采集路径：

- `Scrapy`：批量抓取、调度、重试、限速、代理、pipeline。
- `httpx` 或 `requests`：小型 API adapter、简单页面拉取。
- `feedparser`：RSS/Atom 信息源。
- 官方 API：公告、交易所、监管机构、数据服务优先使用官方接口。

### 6.2 正文抽取

正文抽取作为 `info-app` 的处理阶段：

- `trafilatura`：新闻、公告、研究文章等 HTML 正文抽取优先选择。
- `readability-lxml`：作为备选正文抽取器。
- 自定义规则：对高价值来源维护站点级 CSS/XPath 规则。
- 附件解析：PDF、Office、图片 OCR 可通过 `tools-app` 编排。

### 6.3 动态页面

动态页面不作为默认路径，只在来源确实需要时启用：

- `Playwright`：登录态、JS 渲染、复杂页面交互。
- `Crawl4AI`：需要对动态页面进行 LLM 友好抽取时作为实验能力。
- 截图和 DOM 快照必须作为原始证据保存。

### 6.4 页面变化监测

重点页面可引入变化监测：

- `changedetection.io` 或等价能力用于触发重点页面复采。
- 变化监测只负责发现变化，不成为资讯主档。
- 变化结果进入 `crawl_job`，由 `info-app` 完成版本治理。

### 6.5 反爬治理

反爬能力按来源配置：

- 访问频率、并发、重试、User-Agent、Referer、Cookie、代理池按 `source` 策略管理。
- 优先遵守 robots、版权、访问条款和公开接口。
- 对登录、验证码、强反爬来源设置风险等级和人工审核。
- 禁止把个人浏览器登录态、私有 Cookie 和不可审计凭据直接固化进采集器。

## 7. App Platform 组件归属

在现有 `info-app` 目录结构下，建议分工如下：

| 组件 | 建议职责 |
|---|---|
| `info-admin-backend` | 信息源、采集器、任务、质量规则、人工审核、治理配置 API |
| `info-admin-frontend` | 管理后台：来源管理、任务管理、抽取结果审核、去重合并、监控 |
| `info-web-backend` | 面向普通用户和其他 App 的资讯查询、详情、订阅、检索 API |
| `info-web-frontend` | 资讯浏览、搜索、专题、订阅和详情页 |
| `celeryworker-info-admin-backend` | Scrapy、正文抽取、附件处理编排、分类、去重、RAG 分发任务 |
| `nodebullworker-info-web-backend` | Web 侧异步任务、通知、轻量索引刷新或前端相关后台任务 |

如果未来采集规模明显扩大，可以把采集 worker 拆成独立服务，但第一阶段仍应保持在 `info-app` 领域边界内。

## 8. 存储分层

### 8.1 PostgreSQL

保存权威业务数据：

- 信息源、采集器、任务、任务日志。
- 资讯主档、版本、元数据、状态。
- 去重关系、实体关联、分类标签。
- 分发记录、审计记录、质量评分。

### 8.2 S3 / MinIO

保存不可丢失的原始证据和处理产物：

- 原始 HTML、PDF、Office、附件、图片。
- HTTP 响应头、抓取元数据、截图、DOM 快照。
- 清洗后的 Markdown、纯文本、OCR 结果。
- 版本化对象路径，避免覆盖历史证据。

建议路径示例：

```text
s3://info-originals/source={source_code}/date=YYYY-MM-DD/{document_id}/raw.html
s3://info-originals/source={source_code}/date=YYYY-MM-DD/{document_id}/headers.json
s3://info-originals/source={source_code}/date=YYYY-MM-DD/{document_id}/clean.md
s3://info-originals/source={source_code}/date=YYYY-MM-DD/{document_id}/attachments/{file_name}
```

### 8.3 Elasticsearch / OpenSearch

保存可重建索引：

- 资讯标题、正文、来源、发布时间、公司、证券、行业、主题。
- 支持结构化过滤、全文检索和排序。
- 不作为权威主档，索引可由 PostgreSQL 和 S3 重建。

### 8.4 RAGFlow 内部存储

RAGFlow 的 MinIO、MySQL、Elasticsearch、Valkey 保存知识处理副本和内部状态。它们不替代 `info-app` 的 PostgreSQL、S3 和搜索索引。

## 9. 跨 App 协作

### 9.1 与 Knowledge App

`info-app` 不直接依赖 RAGFlow 私有 API，而是通过 `knowledge-app` 的公开契约分发文档：

```text
info-app document_version
  -> knowledge-app ingestion API / event
  -> RAGFlow dataset/document
  -> knowledge-app processing status
  -> info-app distribution_record
```

分发内容包括：

- `document_id`
- `version_id`
- `content_hash`
- `title`
- `source`
- `published_at`
- `metadata`
- `clean_markdown` 或受控对象副本地址

### 9.2 与 Investment App

`investment-app` 只引用资讯，不复制主档：

- 研究笔记引用 `document_id` 或 `document_version_id`。
- 投资结论保存在 `investment-app`。
- 资讯详情、来源和证据仍从 `info-app` 查询。

### 9.3 与 Tools App

`tools-app` 只提供通用处理能力：

- PDF 转 Markdown。
- Office 文档转换。
- OCR。
- 文件类型识别。

处理结果回写到 `info-app` 的版本和对象存储，不由 `tools-app` 持有资讯主数据。

## 10. API 与事件

第一阶段建议优先提供稳定的内部 API，事件作为后续解耦手段逐步加入。

核心 API：

- `POST /admin/sources`
- `POST /admin/collectors`
- `POST /admin/crawl-jobs`
- `GET /admin/crawl-jobs/{id}`
- `GET /documents`
- `GET /documents/{id}`
- `GET /documents/{id}/versions`
- `POST /documents/{id}/review`
- `POST /documents/{id}/distribute/knowledge`

核心事件：

- `info.source.created`
- `info.crawl_job.completed`
- `info.document.created`
- `info.document.versioned`
- `info.document.extraction_failed`
- `info.document.ready_for_knowledge`
- `info.document.distribution_completed`

## 11. MVP 范围

MVP 不追求一次性覆盖所有网站，先完成可闭环的资讯治理链路。

建议 MVP 包括：

1. 信息源管理：支持网站栏目、RSS、API、手动上传。
2. Scrapy/HTTP 采集：支持定时任务、手动触发、失败重试。
3. 原始证据保存：HTML/PDF/附件进入 `info-app` S3。
4. 正文抽取：`trafilatura` 加站点级规则。
5. 资讯主档：标题、来源、发布时间、正文、附件、版本、状态。
6. 去重：URL、内容哈希、标题时间近似去重。
7. 搜索：基础全文检索和结构化过滤。
8. 分发：通过 `knowledge-app` 投递到 RAGFlow。
9. 管理后台：来源、任务、失败、抽取结果、人工确认。
10. 基础观测：成功率、失败原因、耗时、抽取为空比例、下游同步状态。

暂缓到第二阶段：

- 大规模代理池。
- 自动验证码处理。
- 全站复杂登录态采集。
- 多模态理解。
- 深度事件抽取和知识图谱。
- 完整投资因子或交易信号生成。

## 12. 演进路线

### 第一阶段：可控采集闭环

完成从来源配置、采集、原文保存、正文抽取、主档入库、搜索、RAG 分发的闭环。

### 第二阶段：治理增强

引入更强的去重、版本差异、质量评分、来源可信度、版权状态、人工审核和专题管理。

### 第三阶段：智能处理

引入实体识别、事件抽取、摘要、标签、主题聚类和重要性评分。模型结果必须作为可审计派生结果保存。

### 第四阶段：多下游分发

在 `knowledge-app`、`investment-app`、订阅预警、外部报告系统之间建立统一分发和对账机制。

## 13. 风险与约束

- 版权和访问条款是采集系统的业务风险，不能只作为技术问题处理。
- 强反爬来源要设置人工审批和采集频率限制。
- 资讯主档和 RAG 副本必须区分，否则未来替换 RAGFlow 会造成数据迁移风险。
- 采集器配置、代理、Cookie、账号凭据必须纳入密钥和审计管理。
- 动态页面和浏览器集群成本高，应只服务高价值来源。
- 自动摘要、分类和重要性评分不能覆盖人工确认结果。

## 14. 参考资料

- `info-app/docs/info-app-spider-implementation-tasks.md`
- `app-platform/docs/info-app.md`
- `app-platform/docs/adr/0001-domain-boundaries.md`
- `app-platform/docs/adr/0005-ragflow-as-derived-system.md`
- `info-app/docs/spider-reference/01-金融研究信息收集.md`
- `info-app/docs/spider-reference/02-反爬问题解决方案.md`
- `info-app/docs/spider-reference/03-MVP技术组合.md`
