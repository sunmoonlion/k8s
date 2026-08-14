# info-app

> 仓库路径 `/home/zymun/info-app`。深读基线：2026-08-11（后端约 1.2 万行 Python、两个前端、
> 契约与文档）。App 之间的公共形态见 `baseline/app-platform/inter-apps/app-platform.md`。

## 1. 概要

资讯采集与内容治理域 App：从外部信息源（RSS/API/网页/上传）采集内容，完成抽取、去重、
人工治理，把可分发制品（artifact）经持久投递链路分发给 knowledge-app——**knowledge 的
唯一内容上游**。

### 仓库拓扑

```
info-app/                      # 父仓（契约锁 + 架构文档）
├── contracts/
│   ├── README.md              # Info 不拥有 Knowledge 摄入 schema；锁文件只钉住消费版本
│   └── knowledge-provider-lock.json   # artifact 契约 major=1 + schema sha256 锁
├── docs/（拓扑文档与历史快照材料）
├── info-backend/              # 后端组件仓（FastAPI / Python ≥3.12 / uv，v2.0.0.dev0）
│   ├── app/                   # Python 包根（含 app/、core/、alembic/、pyproject.toml）
│   ├── db-provisioner/  db-access-bootstrap/  search-access-bootstrap/  storage-access-bootstrap/
│   └── mybuild/               # 构建脚本
├── info-admin-frontend/app/   # 运营治理台（Next.js，项目根在 app/ 子目录）
└── info-web-frontend/app/     # 用户交互面
```

一个 Backend 同时服务 Admin/Web 两表面；父仓 `contracts/knowledge-provider-lock.json`
是 artifact 契约的**消费锁**（契约真源在 knowledge-app 仓）。

### 与 tpl 的差异

collectors 适配层（rss/api/changedetection/scrapy）、crawl 治理链、delivery outbox 持久投递、
KnowledgeAppClient 跨 App 集成、info 专属配置段（crawl/storage/search/delivery）、6 步迁移链。
其余（认证、错误契约、bootstrap 四角色、前端骨架）与 tpl 完全同构。

### 运行与验证

与模板同套：`uv sync --frozen && ruff && pyright && pytest`；前端 `pnpm check`。采集链依赖
对象存储（local/S3），搜索索引默认 disabled。

## 2. 重要点

1. **采集-抽取链**：httpx 抓取 → trafilatura 抽取 → **sha256 精确 + simhash64 近似去重**
   （阈值 0.84）→ 文档归并/版本/制品。
2. **治理全留痕**：review_history / audit_log 记入 metadata_json（correlation_id/actor/reason），
   治理动作全部 `expected_updated_at` 乐观并发（FOR UPDATE）。
3. **分发强校验**：仅 clean_markdown/text_plain、≤50MiB、必须有 S3 version_id 才可分发，
   否则 409 ArtifactNotDistributable。
4. **delivery outbox 状态机**：pending→leased→published→completed；**completed 表示业务完成
   而非仅 broker 发布**；broker 故障不使 API 层 5xx；CronJob 有界扫描兜底。
5. **幂等键**：`info-app:{version_id}:{dataset_key}:artifact-v1`。
6. **授权面**：资讯域端点整体挂 `require_info_admin`；web 面只暴露 interaction 契约。
7. **消费锁纪律**：契约真源在 knowledge-app 仓；Info CI 必须下载 provider 工件跑消费方
   测试，无测试通过的锁更新无效。
8. Alembic head `20260811_0006`（6 步迁移链）。

## 3. 架构

### 3.1 后端分层（`info-backend/app/`）

#### 分层结构

- `app/bootstrap/`：同一不可变镜像的四个入口 —— `api.py`（FastAPI app 工厂）、`worker.py`/`scheduler.py`（Celery，require_broker=True）、`migration.py`（一次性 Alembic CLI：`upgrade <rev>` / `current`）。
- `app/interfaces/`：HTTP 适配层（见下）。
- `app/application/services/`：领域服务核心 —— `info_crawl_service.py`（1789 行）与 `delivery_outbox.py`（338 行）；另有 `auth_service`、`web_interaction`。
- `app/application/collectors/`：采集适配器 Protocol（`discover(url, config) → list[CollectedLink]`）+ registry；实现：rss/atom（ElementTree 双格式）、api（items_path 点路径 + 字段映射）、changedetection（需 watch_id）、scrapy/playwright（外部 crawler worker 提供结果，`parse_external_links` 解析）。
- `app/infrastructure/`：models、repositories、external（downstream_service + knowledge_app 客户端）、search、storage、security、messaging（celery_producer）。
- `app/domain/`：Principal / BrowserSession 等领域类型。
- `app/tasks/`：`crawl_url`、`dispatch_distribution`、`index_document_version`、`ping`（每个任务 `asyncio.run` 独立事件循环，任务内必须 shutdown postgres）。
- `app/cli/drain_delivery_outbox.py`：Kubernetes CronJob 用有界单次扫描（--limit 1~1000，需 CELERY_BROKER_URL）。
- `core/config.py`：Info 专属配置段（见 §3.5）。

#### HTTP 表面（interfaces）

- 路由装配 `http/routes.py`：admin_auth_router、web_auth_router、admin_diagnostics_router、web_interactions_router，以及 **info_router 整体挂在 `Depends(require_info_admin)` 之下**（全部资讯域端点要求 admin 面 `{app}:admin` scope）。
- 认证面：`/api/auth/admin/{login,callback,logout,me}` 与 `/api/auth/web/{login,signup,callback,continue,logout,me}`；Web 面支持 provider_error 降级重定向（`/{locale}/login?error=auth_failed&reason=...`，reason 白名单：oidc_transaction_invalid/token_invalid/issuer_mismatch/audience_mismatch/provider_unavailable）。
- 认证依赖 `middleware/auth.py`：cookie 会话 + CSRF 校验（X-CSRF-Token）、`require_admin_scopes()` 工厂 → `require_info_admin`、internal 面 `get_internal_service_principal` / `require_internal_scopes`（Bearer workload JWT）。
- Web 交互面 `/api/web/v1`：`GET /runs/{run_id}`（RunSnapshot）、`GET /runs/{run_id}/events`（SSE，Last-Event-ID/query cursor 冲突即 400）、`POST /runs/{run_id}/actions`、`GET /citations/{evidence_id}/source`（302，路径白名单校验）、`GET /reference/sources/{evidence_id}`（隐藏 reference fixture）。UUID 只接受 v4/v5。
- Admin 诊断：`POST /api/admin/v1/diagnostics/tasks/ping`（Celery ping）。
- 错误契约 `errors/exception_handlers.py`：统一 `application/problem+json`，body 含 `type=urn:sunmoonai:problem:{code}` + 兼容扩展 `error.{code,message,operation_id}`；四层 handler（AppException / RequestValidationError→422 invalid_request / HTTPException / Exception→500）。

#### 资讯域端点（`endpoints/info_routes.py`）

- 源与采集器：`POST/GET /admin/sources`、`POST/GET /admin/collectors`、`POST /admin/collectors/{id}/discover`。
- 抓取任务：`POST /admin/crawl-jobs`（enqueue 时经 celery producer 派发）、`GET /admin/crawl-jobs/{id}`、`POST /admin/crawl-jobs/{id}/run`（同步执行）。
- 文档读模型：`GET /documents`（keyword/source/status 过滤）、`GET /documents/{id}`、`GET /documents/{id}/versions`、各级 artifacts 列表。
- 治理动作（均需 require_info_admin + Principal.actor_id 记入审计）：`POST /documents/{id}/review`、`/relations`、`/entity-links`、`/summary-profile`、`/versions/{vid}/review`；全部支持 `expected_updated_at` 乐观并发。
- 分发：`POST /admin/distributions/knowledge`（dispatch=true 时触发 `_best_effort_kick_delivery_outbox`）、`GET /admin/distributions`、`/{id}`、`/{id}/status`、`/{id}/retry`、`/{id}/dispatch`。
- 其他：`POST /admin/search-index/rebuild`、`POST /admin/uploads`（multipart 上传入库）。
- `_best_effort_kick_delivery_outbox()` 关键设计：用**独立 session** 唤醒 dispatcher（避免请求 session 上的 ORM 对象被 commit 后过期），唤醒失败只记日志——持久请求已随领域变更提交，CronJob scanner 会兜底恢复。

### 3.2 核心领域流程（`info_crawl_service.py`）

#### 采集-抽取链 `process_crawl_job`

1. httpx 抓取（限 `crawl_max_bytes`，UA `SunmoonAI InfoAppBot/0.1`，超时 `crawl_timeout_seconds`）；raw.html + headers.json 存入对象存储（key 模式 `info/original/source={code}/date={date}/job={id}/{name}`，put 后 head 校验 size）。
2. trafilatura 抽取 markdown + text（含 metadata.title/date）；抽取失败走 `_record_extraction_failure`（生成 extraction_failed 版本，保留 raw 制品）。
3. `_find_or_create_document` 按 canonical_url 归并文档；**sha256 精确去重 + simhash64 近似去重**（blake2b 8 字节逐 token 加权，阈值 0.84，命中时 `_apply_duplicate_metadata`）。
4. content_hash 未变则跳过新版本；变了则建 clean.md/text.txt 制品 + InfoDocumentVersion + 两条 ExtractedContent。
5. finally 中 `_enqueue_or_index_document_version`：Celery 优先，broker 不可用时回落 inline 索引。

`ingest_uploaded_file`：`upload://` 伪 URL；文本可解码走抽取链，二进制标记 `pending_tool_processing`。

#### 治理与审计

- `review_document` / `review_document_version`：`FOR UPDATE` + `expected_updated_at` 乐观并发（ConcurrencyConflictError）。
- `mark_document_relation`：repost / same_story / canonical_duplicate 三类关系，写入 `canonical_document_id` 与 `governance_state`。
- `update_document_entity_links`：companies/securities/industries/topics 四元组，casefold 去重。
- `update_document_summary_profile`：summary/tags/importance_score(0~1)/importance_reason。
- 所有变更追加到 metadata_json 内的 `review_history` / `*_history` / `audit_log`（含 correlation_id、operation_id、actor、reason，来自请求上下文中间件）。

#### 分发链（Info → Knowledge）

1. `create_knowledge_distribution`：校验 dataset_key 正则；`_select_distribution_artifact` 强校验制品可分发性——**仅 clean_markdown/text_plain、≤50MiB、必须有 S3 version_id**，否则 `ArtifactNotDistributableError`（HTTP 409）。
2. 同事务写入 DistributionRecord + `ensure_distribution_dispatch_outbox`（创建或显式 re-arm，不会产生第二条消息）。
3. 契约 payload `_artifact_contract_payload`：contract_version=1、operation=upsert、`s3://` uri、storage_version、sha256、**idempotency_key = `info-app:{version_id}:{dataset_key}:artifact-v1`**。
4. `dispatch_distribution` 经 `KnowledgeAppClient.ingest_document()` 调用；未配置 → pending+skipped，异常 → failed，成功 → succeeded。
5. `retry_distribution` 仅 failed 可重试并重新 arm outbox。

#### Delivery Outbox 状态机（`delivery_outbox.py`）

- topic `info.distribution.dispatch.v1`；状态 **pending → leased → published → completed**。
- `claim_due_delivery_outbox`：SKIP LOCKED + 三类到期判定 + lease_token + attempt_count 递增。
- `release_delivery_outbox`：指数退避 `base × 2^min(n-1, 8)` 封顶 max。
- `mark_delivery_outbox_published` 带 lease 校验；**`complete_delivery_outbox` 表示业务完成而非仅 broker 发布**（由 dispatch_distribution 任务在下游确认成功后调用）。
- `dispatch_due_delivery_outbox`：broker 发布失败只记录并 release，不抛出——API 层永远不因 broker 故障返回 5xx。
- 恢复面：CronJob 跑 `cli/drain_delivery_outbox.py` 有界扫描。

### 3.3 数据模型与迁移

#### 领域模型（`infrastructure/models/info.py`，8 个）

| 模型 | 关键点 |
|---|---|
| InfoSource | code 唯一、trust_level、copyright_status、license_url/terms_url、crawl_policy JSONB |
| InfoCollector | collector_type + config JSONB，挂 source |
| CrawlJob | job_type url/upload、attempt_count、duration_ms、request/response_metadata |
| RawArtifact | bucket/object_key/version_id/sha256/storage_state |
| InfoDocument | canonical_url、current_version_id、content_hash、metadata_json（治理审计载体） |
| InfoDocumentVersion | uq(document_id, version_no)、raw/clean/text 三个 artifact id、extraction_status |
| ExtractedContent | content_format + 对象存储坐标 |
| DistributionRecord | target_app="knowledge-app"、payload JSONB、status |

外加模板原语（`models/outbox.py`）：OutboxMessage（pending/delivering/published、deduplication_key 唯一、SKIP LOCKED 租约）+ InboxMessage（consumer+message_id 复合主键幂等）。

#### Alembic 链（head = `20260811_0006`，6 个版本）

1. `20260706_0001` info spider mvp：8 张核心表 + 索引（canonical_url/content_hash/status/sha256）+ 后补 FK。
2. `20260707_0002` source governance：info_source 加 trust_level/copyright_status/license_url/terms_url。
3. `20260712_0003` auth identity：auth_user（uq issuer+subject）。
4. `20260714_0004` durable delivery outbox：delivery_outbox_message（uq topic+idempotency_key、ix state+available_at、FK→distribution_record）。
5. `20260809_0005` outbox primitives：outbox_message + inbox_message（模板原语）。
6. `20260811_0006` delivery outbox id 补 `uuid_generate_v4()` server default。

env.py 用 `get_settings().migration_url`，异步引擎 `asyncio.run`。

### 3.4 跨 App 集成

- `infrastructure/external/knowledge_app.py`：`ServiceTokenProvider`（client_credentials + 内存 token 缓存 + 独立 discovery/backchannel 配置）→ `KnowledgeAppClient.ingest_document()`；`get_knowledge_app_client()` lru_cache；未配置时抛 `KnowledgeAppNotConfiguredError`。
- `infrastructure/external/downstream_service.py`：通用 `DownstreamServiceClient`，路径白名单 `downstream_allowed_path_prefix_list`（默认 `/api/internal/v1`），禁绝对 URL/协议相对路径/反斜杠；5xx→503、4xx→400。
- **消费方契约锁** `contracts/knowledge-provider-lock.json`：provider=knowledge-app、contract=`info-knowledge-artifact`、major_version=1、schema=`contracts/artifact/v1/info-knowledge-artifact.schema.json`、sha256=`a3219604...499c81`。契约真源在 knowledge-app 仓；Info CI 必须下载 provider 工件并设 `KNOWLEDGE_ARTIFACT_CONTRACT_PATH` 跑消费方测试，无测试通过的锁更新无效。

### 3.5 Info 专属配置（core/config.py，在模板基础上新增）

- `delivery_outbox_*`：batch 50 / lease 30s / ack 300s / retry 5~300s 指数退避。
- `storage_*`：local/S3 双后端，bucket 默认 `development-info-originals`。
- `crawl_*`：timeout 20s、max 10MiB、UA `SunmoonAI InfoAppBot/0.1`。
- `search_*`：默认 disabled，索引 `info-information`（dynamic:false 严格 mapping、nested artifacts/extracted_contents、metadata enabled:false），aliases JSON 指定写入目标别名。
- `knowledge_app_*`：ingest_url、service client 配置、scope 默认 `knowledge:ingest`。
- `celery_queue` 默认 `info.default`；`app_slug=info`。
- 依赖栈：fastapi/asyncpg/sqlalchemy/alembic/celery/redis/boto3/httpx/joserfc/**trafilatura**/python-multipart。

### 3.6 前端

两个前端结构同构（Next.js 16.2.2 + React 19 + Tailwind v4 + shadcn + Zustand + TanStack Query + next-intl + zod 4，pnpm 10.24，`output:'standalone'`，Node ≥24.18）：

- **admin**：页面 `[locale]/(dashboard)` 下 dashboard / info/crawl（`info-crawl-panel.tsx` 采集操作台）/ settings / reference / rich-reference / forbidden；`lib/info-api.ts` 是完整领域客户端（documents/versions/distributions/crawl-jobs/sources/collectors/discover/uploads/review/entity-links/summary-profile/distribution dispatch+retry，全部带 csrfToken）；`lib/info/api.ts` 是精简旧版。组件库含 crud 套件（data-table/schema-form/audited-action-dialog/contract-upload）与 rich 套件（markdown-editor/metric-chart/media-player 等）。
- **web**：页面 dashboard / toolkit / login；核心是 **interaction 契约**（`contracts/interaction.ts`，zod 严格 schema）：RunSnapshot（status: queued/running/waiting_for_input/succeeded/failed/cancelled、citations≤50、required_action）、RunEvent 判别联合（status/delta/citation/input_required/completed/failed/heartbeat，SSE `id/event:run-event/data`）、RunAction、apiError。citation 的 `source_href` 必须精确匹配 `/api/web/v1/citations/{evidence_id}/source`。
- 共同约定：`proxy.ts`（Next 16 路由边界）每请求生成 CSP nonce；认证鉴权不委托给前端中间件，全部走服务端会话（cookie `sunmoonai_info_{surface}_sid`）；token 不落地 localStorage；`scripts/pair-gateway.mjs` / `prepare-standalone.mjs` 支撑 pair 部署。

### 3.7 部署与发布

- 走 k8s-deployment 脚手架五件套 + `deployment/bundle/release.json`（schema 2、formal_release=true）；Secret 名 `info-backend-runtime`（10 个 required key）。
- 实例同步顺序：info → knowledge → investment（见 tpl 的 template-release-manifest）。

## 4. 关联

- 下游（artifact 契约真源）：`../knowledge-app/knowledge-app.md`。
- 母模板：`../tpl-app/tpl-app.md`；公共形态：`../../inter-apps/app-platform.md`。
- 部署声明：`../k8s/k8s.md`；平台间关系：`../../../sunmoonai/architecture.md`。
