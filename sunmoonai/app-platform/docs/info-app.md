# Info App 架构

## 1. 系统定位

`info-app` 是 App Platform 中独立、长期演进的资讯管理系统。

它统一负责资讯的获取、接入、保存、治理、组织、检索和分发。投资资讯、宏观政策、行业信息、公司动态、监管信息及未来其他资讯类型，都是系统平等管理的领域内容，不存在“核心投资资讯”和“附带其他信息”的主次关系。

`info-app` 不是：

- 单一爬虫服务。
- RAGFlow 的上传工具。
- `investment-app` 的内部模块。
- 临时文件中转站。
- 只面向某一个网站或某一种资讯的项目。

它应当成为平台统一的 Information System of Record。

## 2. 核心目标

`info-app` 长期提供以下能力：

1. 多来源资讯统一接入。
2. 原始证据和历史版本长期保存。
3. 资讯标准化、去重、分类和实体关联。
4. 来源、版权、血缘、质量和可信度治理。
5. 结构化检索、全文检索和内容发现。
6. 订阅、分发、摘要、专题和预警。
7. 向 RAGFlow、搜索引擎和其他下游系统分发处理副本。
8. 为 `investment-app` 及未来其他业务应用提供统一资讯服务。

## 3. 与其他 App 的边界

### 3.1 与 Investment App

`info-app` 负责客观资讯及其治理：

- 公告、新闻、政策和报告。
- 来源、时间、正文和附件。
- 公司、证券、行业、地区和主题关联。
- 资讯版本、质量、重要性和状态。

`investment-app` 负责投资领域产生的数据：

- 研究笔记。
- 观点和评级。
- 组合、策略和风险判断。
- 资讯对投资决策的解释和使用记录。

`investment-app` 引用 `info_id`，不复制资讯主档。

### 3.2 与 Knowledge App

`info-app` 拥有资讯主数据和原始证据；`knowledge-app` 提供知识处理和检索能力；
模型辅助处理和 RAGFlow 适配能力也由 `knowledge-app` 对外封装。

`info-app` 可以调用：

- 文本分类和实体识别。
- 摘要和标签生成。
- 通过 `knowledge-app` 使用 Embedding、语义检索和 RAGFlow 文档处理。

模型生成结果必须记录模型、版本、时间和输入来源，不能覆盖人工确认的主数据。

### 3.3 与 Tools App

`tools-app` 提供跨领域通用工具，例如：

- PDF、Office、HTML 和 Markdown 转换。
- OCR。
- 图片和附件处理。
- 文件格式检测。

`info-app` 负责编排这些工具，并决定处理结果如何成为资讯版本。工具本身不拥有资讯。

### 3.4 与 Auth App

`auth-app` 提供统一身份和权限。`info-app` 负责资讯领域内的访问策略，例如来源权限、内容可见范围、订阅权限和管理权限。

## 4. 与 RAGFlow 的分工

核心原则：

```text
info-app = 资讯主系统和权威数据源
RAGFlow  = 可替换的知识处理与检索引擎
```

| 职责 | Info App | RAGFlow |
|---|---|---|
| 资讯源和采集计划 | 权威管理 | 不负责 |
| 原始响应、文件和附件 | 保存唯一主档 | 保存处理副本 |
| 历史版本和内容血缘 | 权威管理 | 不负责 |
| 标题、来源、时间、版权 | 权威管理 | 接收检索元数据 |
| 去重和同源合并 | 权威管理 | 不作为主去重系统 |
| 公司、证券、行业和主题关联 | 权威管理 | 用于过滤和检索 |
| 质量、可信度和重要性 | 权威管理 | 不负责业务判断 |
| 文档分块 | 不作为业务主数据 | 负责 |
| Embedding 和向量索引 | 不持有权威结果 | 负责 |
| RAG 检索和问答 | 调用并编排 | 提供能力 |
| 同步和重建状态 | 权威管理 | 提供处理状态 |

删除或重建 RAGFlow 时，`info-app` 的资讯、原文和版本必须保持完整，并可以重新同步生成全部知识处理副本。

## 5. 存储架构

从第一阶段开始采用长期存储边界，不采用由 RAGFlow 保存唯一原文的临时方案。

### 5.1 Info App 业务数据库

保存：

- 资讯及其生命周期状态。
- 信息源、采集器和采集任务。
- 内容版本和去重关系。
- 实体、分类、标签和专题关系。
- 质量、版权、血缘和审计数据。
- 下游分发及 RAGFlow 同步状态。

### 5.2 Info App 对象存储

保存资讯原始主档：

- 原始 PDF、Office 文档和附件。
- 原始 HTML 和 HTTP 响应。
- 必要的响应头和抓取元数据。
- 页面截图。
- 清洗后的 Markdown 和纯文本。
- OCR、转换和抽取产物。
- 每次内容变化对应的历史版本。

对象存储由 `info-app` 拥有。物理上使用平台 S3 对象存储，但必须使用独立 Bucket、凭据和生命周期策略。Kind 环境的 S3 实现为 MinIO，远程实现由平台环境决定。

### 5.3 Info App 检索存储

结构化筛选和资讯全文检索属于 `info-app` 的服务能力。搜索索引是可重建副本，权威数据仍在业务数据库和对象存储。

### 5.4 RAGFlow 存储

RAGFlow MinIO 保存从 `info-app` 分发的知识处理副本，不是原文主档。

RAGFlow MySQL、Elasticsearch 和 Valkey 分别保存其内部元数据、知识索引和运行状态。它们都不替代 `info-app` 数据库。

### 5.5 平台设施与 RAGFlow 内置设施

长期保留两组相互隔离的存储设施：

```text
Info App
├── 平台 PostgreSQL：资讯业务主档
├── 平台 S3 对象存储
│   ├── 原始文件主档
│   └── 规范化及其他领域处理产物
└── 平台 Elasticsearch：Info App 领域全文索引
        |
        | 由 Info App 受控分发
        v
RAGFlow
├── 自带 MinIO：知识处理文档副本
├── 自带 Elasticsearch：分块、Embedding、向量和内部检索数据
├── 自带 MySQL：RAGFlow 内部元数据
└── 自带 Valkey：缓存和运行状态
```

即使 Data Platform 已经提供 S3 对象存储和 Elasticsearch，RAGFlow 仍继续使用其自带 MinIO 和 Elasticsearch。原因是：

- RAGFlow 内部数据结构、版本和升级过程属于产品私有实现。
- RAGFlow 的解析和向量写入负载不应影响 Info App 主档和领域检索。
- RAGFlow 可以连同其内部依赖整体删除、替换或重建。
- Info App 可以独立备份、恢复和演进，不受某个 RAG 产品约束。

必须遵守：

- RAGFlow 不直接持有平台 `info-originals` Bucket 的永久访问权限。
- Info App 和 RAGFlow 不共享 Elasticsearch Index、Alias 或写入账号。
- Info App 不把 RAGFlow Elasticsearch 作为自己的全文检索接口。
- 同一文件在 Info App 和 RAGFlow 中形成主档与处理副本，是有意的数据分级，不是两个权威来源。
- 删除或重建 RAGFlow 后，由 Info App 根据版本、内容哈希和分发记录重新生成知识处理副本。

### 5.6 集群重建与资源恢复

Info App 的 S3 和 Elasticsearch 资源声明随 App 源码维护，平台部署脚本负责在
Backend 启动前执行幂等恢复。统一部署顺序为：

```text
Data Platform
├── Object Storage
└── Elasticsearch
        |
        v
Info App resource bootstrap
├── Bucket、版本控制、IAM Policy、IAM 用户和应用 S3 凭据
└── Index Template、物理索引、读写 Alias、角色和应用 Elasticsearch 凭据
        |
        v
Info App Backend 和 Frontend
```

完整部署 Info App 时会自动执行资源恢复：

```bash
./sunmoonai/app-platform/info-app/deploy-info-app-all/deploy-info-app-all.sh \
  --cluster KIND deploy
```

远程开发集群使用相同入口，仅切换集群参数：

```bash
./sunmoonai/app-platform/info-app/deploy-info-app-all/deploy-info-app-all.sh \
  --cluster C1 deploy
```

也可以只操作领域资源而不启动或重启业务组件：

```bash
# 校验声明，不连接数据服务
./sunmoonai/app-platform/info-app/deploy-info-app-all/deploy-info-app-all.sh \
  --cluster KIND validate-resources

# 创建或恢复 S3、Elasticsearch 资源与应用凭据
./sunmoonai/app-platform/info-app/deploy-info-app-all/deploy-info-app-all.sh \
  --cluster KIND provision-resources

# 检查领域资源状态
./sunmoonai/app-platform/info-app/deploy-info-app-all/deploy-info-app-all.sh \
  --cluster KIND resource-status
```

这些操作必须保持幂等。普通 App `uninstall` 不删除 Bucket、对象、索引或访问
凭据，防止应用重装误伤领域数据。彻底回收资源必须使用各 Provisioner 的显式
回收命令，并遵循数据保留策略。

## 6. 领域模型

建议围绕以下核心实体设计：

### Source

资讯来源，例如交易所、政府网站、公司官网、新闻机构或数据接口。

### SourceEndpoint

具体栏目、API、Feed、列表页或文件入口。

### CollectionJob

一次采集计划或任务，记录触发方式、时间范围、游标、结果和错误。

### RawArtifact

未经业务修改的原始证据，包括响应正文、文件、附件、截图和响应元数据。

### InformationItem

一条可被管理和分发的逻辑资讯，是稳定业务标识，不随内容修订而改变。

### InformationVersion

资讯在某个时间点的内容版本，关联原始证据、规范化内容和内容哈希。

### Entity

公司、证券、行业、机构、人物、地区、产品、政策和其他可关联对象。

### Classification

资讯类型、主题、标签、重要性、情绪和质量评价。

### Distribution

资讯向搜索索引、RAGFlow、订阅者和其他业务系统的分发记录。

### Subscription

用户或系统对来源、实体、主题和条件的订阅。

## 7. 模块化架构

`info-app` 可以先采用模块化单体或少量服务部署，但内部边界应按长期模块设计。

```text
info-app
├── source-management
├── collection
├── artifact-repository
├── normalization
├── deduplication
├── entity-resolution
├── classification
├── catalog
├── search
├── distribution
├── subscription-alerting
├── ragflow-integration
└── administration
```

### Source Management

管理信息源、入口、采集协议、频率、凭据、合规说明和启停状态。

### Collection

执行网页、API、Feed 和文件采集，支持游标、增量、重试、限速和失败隔离。

### Artifact Repository

负责原始主档写入、校验、版本化、不可变保存和生命周期管理。

### Normalization

执行正文抽取、编码处理、格式转换、Markdown 化、时间和字段标准化。

### Deduplication

处理 URL 规范化、内容哈希、标题相似度、转载关系和同一事件聚合。

### Entity Resolution

关联公司、证券代码、行业、机构、人物、地区和主题，并保存识别依据与置信度。

### Classification

管理资讯类型、标签、重要性、情绪、可信度和质量状态。

### Catalog

提供资讯主记录、版本、附件、血缘和处理历史的统一查询。

### Search

提供结构化筛选、关键词检索和聚合统计。

### Distribution

将资讯及版本分发到 RAGFlow、搜索索引和其他下游系统，负责幂等、重试和状态跟踪。

### Subscription And Alerting

管理订阅规则，产生站内、邮件、消息或其他预警事件。

### RAGFlow Integration

隔离 RAGFlow API 和数据模型细节，使未来替换或增加知识引擎时不影响其他模块。

## 8. 主数据流程

```text
Source
  -> CollectionJob
  -> RawArtifact
  -> InformationItem / InformationVersion
  -> Normalization
  -> Deduplication
  -> Entity Resolution
  -> Classification
  -> Catalog / Search
  -> Distribution
  -> RAGFlow / Subscribers / Business Apps
```

原始证据必须先进入 `info-app` 对象存储，再进行后续处理。任何下游失败都不能导致原始证据丢失。

## 9. RAGFlow 同步流程

### 9.1 同步内容

- PDF、报告和公告：同步适合解析的文件副本。
- 网页资讯：同步规范化 Markdown，并保留原始页面引用。
- 多附件资讯：主记录与附件分别建立明确关系。
- 纯结构化数据：只有在确有知识检索价值时才生成文档副本。

### 9.2 同步元数据

至少包含：

```text
info_id
version_id
source_id
source_name
source_url
publish_time
information_type
entity_ids
company_codes
industries
topics
content_hash
```

### 9.3 同步状态

```text
PENDING
UPLOADING
UPLOADED
PARSING
READY
FAILED
STALE
DELETING
DELETED
```

`info-app` 保存 RAGFlow `dataset_id`、`document_id`、同步版本、错误和最后处理时间。

### 9.4 重建

系统必须支持：

1. 创建新的 RAGFlow 知识库。
2. 从 `info-app` 选择需要同步的资讯版本。
3. 从对象存储读取主档或规范化产物。
4. 批量上传并触发解析。
5. 校验数量、状态和内容哈希。
6. 切换下游使用的新知识库。

## 10. API 与事件

面向其他 App 的能力应包括：

- 查询资讯列表和详情。
- 按来源、时间、类型、实体和主题筛选。
- 获取原始文件和指定版本。
- 查询关联资讯和同一事件。
- 管理订阅和预警规则。
- 请求语义检索或知识问答。
- 查询处理、分发和 RAGFlow 状态。

建议发布领域事件：

```text
InformationCollected
InformationCreated
InformationVersionCreated
InformationClassified
InformationReady
InformationDistributed
InformationAlertTriggered
```

事件只携带稳定标识和必要摘要，消费者通过 API 获取完整数据。

## 11. 安全、版权与治理

长期系统必须从设计阶段考虑：

- 来源许可和抓取合规。
- 版权、使用范围和保留期限。
- 原文访问权限。
- API 密钥和来源凭据管理。
- 敏感信息识别。
- 数据修改和人工校正审计。
- 模型生成标签的来源、版本和置信度。
- 删除、更正和下游同步策略。

## 12. 第一阶段实施架构

Info App 从统一 `tpl-app` 完整实例化。四个模板组件均保留工程、构建和平台接入
配置；第一阶段优先实现与当前功能匹配的组件，并仅在 Kubernetes 中启动需要运行
的组件。

```text
info-app
├── info-admin-backend     # Python / FastAPI，第一阶段运行
├── info-admin-frontend    # Vue，第一阶段运行
├── info-web-backend       # NestJS，配置完整，按需启动
├── info-web-frontend      # Next.js，配置完整，按需启动
└── deploy-info-app-all
```

这里的 `admin` 和 `web` 是模板组件名称，不是 Info App 的固定业务分层。具体职责由组件 `app` 目录中的领域代码决定。

第一阶段选择 Python Backend，是因为采集、文件处理、NLP、批任务和知识系统集成与 Python 技术栈更匹配；选择 Vue Frontend，是因为当前首先需要管理和治理界面。这是阶段性技术选择，不改变 Info App 的长期领域边界。

### 12.1 Python Backend

承载：

- Source、RawArtifact、InformationItem 和 InformationVersion API。
- 上传、查询、版本、分发和重建命令。
- 第一阶段管理能力。
- Transactional Outbox 写入。

内部代码仍按第 7 节的长期模块划分，禁止把所有逻辑集中到 Controller 或数据库模型中。

### 12.2 Worker 和 Scheduler

执行：

- 来源采集。
- 文件校验和对象存储写入。
- 文档转换与规范化编排。
- 哈希和基础去重。
- RAGFlow 同步、轮询和对账。
- Outbox 发布及失败重试。

Worker 和 Scheduler 是 Python Backend 的不同运行角色，复用同一份领域源码和镜像，不建立独立的 `info-worker` 业务工程。

初期可以通过 Celery Worker、Celery Beat 或 Kubernetes CronJob 运行，并使用队列区分任务。出现资源差异后再拆成 collection、processing 和 distribution Worker Deployment。

### 12.3 Vue Frontend

第一阶段至少提供：

- 来源管理。
- 文件上传。
- 资讯、版本和原始证据查询。
- 处理状态及失败原因。
- RAGFlow 分发、重试和重建操作。

当需要面向普通用户的资讯门户、搜索、订阅或专题页面时，可以启用 Next.js 组件；当这些功能明确需要独立 NestJS API 或 BFF 时，再启用 JavaScript Backend。组件启用不改变 Info App 的主档和领域规则。

## 13. 第一阶段存储决策

### 13.1 PostgreSQL

复用 Data Platform PostgreSQL 物理集群，创建独立：

```text
database: info
user: info
schema: info
```

Info App 凭据不得供其他 App 使用。数据库迁移由 Info App 发布流程负责。

### 13.2 对象存储

使用平台 S3 对象存储时创建独立 Bucket：

```text
info-originals
info-derived
```

- `info-originals`：保存原始响应、文件、附件、截图和原始元数据，按版本不可变写入。
- `info-derived`：保存 Markdown、文本、OCR、缩略图等可重新处理产物。
- 两个 Bucket 使用 Info App 独立凭据和访问策略。
- RAGFlow 不直接访问 `info-originals`，由 Info App 创建受控处理副本。
- 这些 Bucket 属于平台领域存储，与 RAGFlow 自带 MinIO 相互独立。

Kind 开发环境长期使用平台固定版本 MinIO；进入远程环境前必须选定仍受维护的 S3 兼容实现，并确定高可用、备份、版本控制和生命周期策略。

### 13.3 Redis 和 RabbitMQ

- Redis 只用于缓存、锁和短期状态。
- RabbitMQ 使用 Info App 独立 vhost、用户、Exchange、Queue 和死信队列。
- 业务事务与 Outbox 位于同一 PostgreSQL 事务。
- Worker 消费任务时保存幂等记录。

### 13.4 检索

第一阶段优先使用 PostgreSQL 元数据查询和必要的全文检索能力，不立即引入新的独立搜索集群。

当数据规模、中文检索质量或聚合需求超过 PostgreSQL 能力时，再建立 Info App 独立 Elasticsearch 索引。该索引始终属于可重建派生数据。

Info App Elasticsearch 索引只服务资讯领域全文检索，不与 RAGFlow 的内部 Elasticsearch 索引共享。两者可以分别从 Info App 主档重建，但重建方式和生命周期互相独立。

## 14. 第一阶段主链路

### 14.1 人工上传

```text
User
  -> Info Admin API
  -> create upload session
  -> write info-originals
  -> verify hash and metadata
  -> create RawArtifact
  -> create InformationItem / InformationVersion
  -> enqueue normalization
  -> distribute to RAGFlow
```

文件成功进入对象存储并完成哈希校验前，不创建可用的资讯版本。

### 14.2 自动采集

```text
Scheduler
  -> CollectionJob
  -> fetch source
  -> save raw response first
  -> normalize
  -> deduplicate
  -> create or revise InformationItem
  -> distribute
```

网络响应、响应头和必要抓取元数据先进入原始证据层。解析失败不能导致原始响应丢失。

### 14.3 工具调用

Info App 通过 Tools App 的任务接口请求文档转换，传递对象引用和哈希。转换结果返回后，由 Info App 写入 `info-derived` 并创建处理产物记录。

### 14.4 RAGFlow 同步

Info App 通过 Knowledge App 的 RAGFlow Adapter 提交文档，不让业务模块直接依赖 RAGFlow 私有 API。

第一阶段知识空间按信息领域或访问权限划分，不按单个用户随意创建。每条同步记录保存：

```text
knowledge_space_id
dataset_id
document_id
info_id
version_id
content_hash
sync_status
last_error
synced_at
```

## 15. API 与事件落地

第一阶段 API：

```text
POST /api/v1/uploads
POST /api/v1/uploads/{id}/complete
GET  /api/v1/information
GET  /api/v1/information/{info_id}
GET  /api/v1/information/{info_id}/versions
GET  /api/v1/artifacts/{artifact_id}
POST /api/v1/information/{info_id}/distributions/ragflow
POST /api/v1/ragflow-rebuilds
GET  /api/v1/jobs/{job_id}
```

第一阶段事件：

```text
info.information.created.v1
info.information.version-created.v1
info.information.ready.v1
info.distribution.completed.v1
info.distribution.failed.v1
```

实现必须遵循 [App Platform 集成规范](./integration-standards.md)。

## 16. 分阶段建设

阶段划分只控制实现范围，不改变长期架构和数据所有权。

### 第零阶段：工程骨架

- 从统一 `tpl-app` 实例化 `info-app` 工程。
- 四个模板组件均完成源码、构建和部署配置；第一阶段默认只启动 Python Backend 和 Vue Frontend，其余组件保留为可随时启动的技术栈。
- 为 Python Backend 配置 API、Worker、Scheduler 和 Migration Job 运行角色。
- 创建 Kubernetes 部署目录和统一部署入口。
- 注册到 `deploy-app-platform-all`。
- 建立数据库、对象存储、RabbitMQ 和 Redis 隔离配置。
- 建立健康检查、迁移、日志和指标基础。

### 第一阶段：主档闭环

- 实现 Source、CollectionJob、RawArtifact、InformationItem 和 InformationVersion。
- 打通人工上传和至少一个受控信息源。
- 实现对象主档、内容哈希、版本和基础去重。
- 接入 Tools App 文档转换。
- 实现 Catalog 查询和 RAGFlow Integration。
- 完成全量重建和增量对账。

### 第二阶段：治理与发现

- 实体识别、分类、标签和质量治理。
- 全文检索、订阅和预警。
- 多来源转载关系和事件聚合。
- 管理端、业务指标和运行监控。

### 第三阶段：规模化

- 更丰富的来源协议和复杂文档。
- 专题、时间线和跨来源关联。
- 多知识引擎分发。
- 高级资讯发现、摘要和研究支持。

## 17. 第一阶段验收标准

### 数据主档

- 每个文件在处理前进入 `info-originals`。
- 原始对象具有内容哈希、来源、获取时间和稳定标识。
- 内容变化生成新的 InformationVersion，不覆盖历史版本。
- PostgreSQL 和对象存储可以共同恢复完整资讯主档。

### 处理与分发

- Tools App 或 RAGFlow 故障不影响原始文件接收。
- 所有任务具有状态、错误、重试和幂等记录。
- 删除 RAGFlow 数据后可以全量重建。
- 对账可以发现遗漏、版本不一致和内容哈希不一致。

### 契约与治理

- 其他 App 只通过 API、事件和对象交换协议访问资讯。
- Investment App 使用 `info_id + version_id` 引用研究证据。
- 每次人工修改和管理操作具有审计记录。
- 第一批来源记录许可、使用范围和采集限制。

### 运行

- 部署入口支持 `deploy`、`uninstall`、`status` 和 `logs`。
- 组件具有 readiness、liveness 和资源配置。
- 关键链路输出日志、指标和 `trace_id`。
- 备份和重建流程至少在开发环境演练一次。

## 18. 后续决策门

以下事项在达到触发条件后再决定，不阻塞第一阶段：

| 事项 | 决策触发条件 |
|---|---|
| 独立 Elasticsearch | PostgreSQL 检索无法满足规模或质量 |
| 拆分 Worker | 采集、转换和分发出现明显资源冲突 |
| 独立 MinIO 集群 | 容量、可靠性或安全隔离需要 |
| 多知识引擎 | 出现 RAGFlow 之外的明确业务需求 |
| 独立采集服务 | 来源数量和团队边界要求独立发布 |
