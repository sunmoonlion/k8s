# info-app

> 仓库 `sunmoonlion/info-app`
> 最后更新：2026-08-15 ｜ 验证时点：2026-08-15（对代码取证）
> 跨仓规则见 [`../shared/`](../shared/)；全局地图见 [`../map.md`](../map.md)

## 1. 这个仓是什么

信息域 App。父仓固定三个子模块：统一 FastAPI 后端、Admin 前端、Web 前端
（`.gitmodules:1-9`）。后端承载来源治理、URL 与上传采集、文档版本、原始制品、去重元数据、
可重建搜索索引、向 knowledge-app 分发，以及分发用的 durable outbox。
Admin/Web 经 Casdoor 浏览器会话调 `/api`；Worker 消费 Celery 队列；knowledge-app 消费其制品契约。

## 2. 目录地图

| 路径 | 装什么 | 什么任务会动它 |
| --- | --- | --- |
| `info-backend/app/app/application/` | 采集、分发、认证、Web 交互服务 | 业务规则、去重、索引、分发 |
| `info-backend/app/app/infrastructure/` | PG/Redis/S3/ES/Celery/OIDC 适配 | 存储与外部调用 |
| `info-backend/app/app/interfaces/` | FastAPI 路由、中间件、Schema | HTTP 契约、鉴权 |
| `info-backend/app/app/tasks/` | Celery 任务定义 | 异步抓取、索引、分发 |
| `info-backend/app/app/bootstrap/` | API/Worker/Scheduler/Migration 入口 | 进程角色 |
| `info-backend/app/alembic/versions/` | 线性迁移链 | 表结构变更 |
| `info-backend/app/core/config.py` | 环境变量与校验 | 阈值、开关、凭据边界 |
| `info-admin-frontend/app/` | Next.js Admin | 来源/采集/审核/分发 UI |
| `info-web-frontend/app/` | Next.js Web | 登录、交互契约 UI |
| `contracts/` | knowledge 制品契约的消费端锁 | 契约升级、CI 校验 |
| `dev-to-prod-deploy/` | 晋级流程与 Secret 分层指南 | 生产发布 |
| `docs/` | 历史与拓扑证据 | 非运行时真源（`README.md:23-24`） |

## 3. 改动前必读的硬规则

| 规则 | 代码位置 | 违反后果 |
| --- | --- | --- |
| `application` 层不得 import `app.interfaces` | `app/tests/test_kernel_invariants.py:32-36` | CI 失败 |
| 迁移须单链线性 | `app/tests/test_kernel_invariants.py:39-59` | CI 失败 |
| 生产 `ALLOWED_HOSTS` 禁 `*` | `app/core/config.py:269-271` | 启动 `ValueError` |
| 生产禁 `REFERENCE_INTERACTION_ENABLED=true` | `app/core/config.py:278-281` | 启动 `ValueError` |
| Admin API 需 `info:admin` scope | `app/core/config.py:443`；`interfaces/http/middleware/auth.py:97` | 403 |
| 抓取响应超 `CRAWL_MAX_BYTES`（默认 10MiB）即拒 | `core/config.py:171-172`；`services/info_crawl_service.py:1428-1429` | 任务 failed |
| 可分发 artifact 仅 `clean_markdown` / `text_plain`，大小 1–52428800 字节 | `services/info_crawl_service.py:1024-1041` | `ArtifactNotDistributableError` → 409 |
| `target_dataset` 须匹配 `[a-z0-9][a-z0-9._-]{0,119}` | `services/info_crawl_service.py:924-925` | 404 / `ValueError` |
| 共享 outbox 事件序列化 ≤256 KiB | `application/dto/outbox.py:44-45` | `ValidationError` |
| Outbox claim `limit` ∈ 1–1000 | `infrastructure/repositories/outbox.py:49-50` | `ValueError` |
| Worker/Scheduler 启动须配 broker | `app/worker.py:29-30`；`bootstrap/worker.py:5` | `RuntimeError` |
| 镜像构建上下文须排除 `.env` 与 `tests` | `app/tests/test_kernel_invariants.py:81-85` | CI 失败 |

## 4. 分层与关键流程

| 组件/层 | 职责 | 入口位置 |
| --- | --- | --- |
| Bootstrap API | 生命周期、CORS、健康检查 | `app/bootstrap/api.py:36-169` |
| HTTP 路由 | Admin 认证、Web 认证与交互、资讯域 API | `interfaces/http/routes.py:10-15` |
| `info_crawl_service` | 采集、文档、去重、分发、索引编排 | `application/services/info_crawl_service.py` |
| `delivery_outbox` | 分发 durable outbox + Celery 唤醒 | `application/services/delivery_outbox.py:1-7` |
| 对象存储 | 原始/清洗/文本制品 | `infrastructure/storage/object_storage.py` |
| 搜索读模型 | ES/OpenSearch，默认关闭（见 §8） | `infrastructure/search/info_index.py:617-620` |

**Celery 任务**

| 任务名 | 事件循环 | 位置 |
| --- | --- | --- |
| `app.tasks.ping` | **无**（同步返回 `"pong"`） | `app/tasks/ping.py:4-7` |
| `app.tasks.crawl_url` | 每任务 `asyncio.run` | `app/tasks/crawl.py:11-14` |
| `app.tasks.index_document_version` | 每任务 `asyncio.run` | `app/tasks/search.py:13-16` |
| `app.tasks.dispatch_distribution` | 每任务 `asyncio.run` | `app/tasks/distribution.py:17-20` |

**抓取 → 版本 → 索引**

| 步骤 | 做什么 | 位置 |
| --- | --- | --- |
| 1 | 建 `CrawlJob`；`enqueue=true` 且 broker 已配则投 Celery | `interfaces/endpoints/info_routes.py:149-161` |
| 2 | Worker 拉 URL、校验大小、存 raw/clean/text 制品、写 `InfoDocumentVersion` | `services/info_crawl_service.py:1399-1583` |
| 3 | 写 simhash64 指纹与近重复候选（阈值常量 `_NEAR_DUPLICATE_THRESHOLD`） | `services/info_crawl_service.py:45-46,1700-1749` |
| 4 | 完成后索引：优先 Celery，失败则 API 内联 | `services/info_crawl_service.py:1336-1365,1606-1607` |

**分发 → knowledge-app**

| 步骤 | 做什么 | 位置 |
| --- | --- | --- |
| 1 | 校验 artifact，组装 `info-knowledge-artifact` v1 payload | `services/info_crawl_service.py:910-934,963-1000` |
| 2 | 写 `distribution_record` + `delivery_outbox_message` | `services/info_crawl_service.py:951-957`；`delivery_outbox.py:78-83` |
| 3 | 扫描器或 Celery 执行 `dispatch_distribution`，POST knowledge ingest | `tasks/distribution.py:17-48`；`external/knowledge_app.py:94-114` |

## 5. 数据与迁移

| 实体或迁移链 | 位置 | 说明 |
| --- | --- | --- |
| 迁移链目录 | `info-backend/app/alembic/versions/` | head 见该目录最新 revision；顺序由 `test_kernel_invariants.py:45-52` 锁定 |
| `info_source` / `info_collector` / `crawl_job` | `infrastructure/models/info.py:22-88` | 来源与采集作业 |
| `raw_artifact` | `infrastructure/models/info.py:91-115` | 对象存储制品元数据 |
| `info_document` / `info_document_version` | `infrastructure/models/info.py:118-159` | 文档与版本 |
| `extracted_content` | `infrastructure/models/info.py:162-174` | 抽取内容 |
| `distribution_record` | `infrastructure/models/info.py:177-191` | 跨 App 分发记录 |
| `delivery_outbox_message` | `infrastructure/models/info.py:194-229` | Info 域 durable 分发 outbox（**这个是接线的**） |
| `outbox_message` / `inbox_message` | `infrastructure/models/outbox.py:14-60` | 共享 outbox 原语，**未接线**（见 §8） |
| 迁移入口 | `app/bootstrap/migration.py:20-38` | `upgrade` / `current` |

## 6. 契约与对外接口

| 契约/接口 | 真源位置 | 角色 |
| --- | --- | --- |
| knowledge 制品 schema | provider 在 knowledge-app；本仓锁文件 `contracts/knowledge-provider-lock.json` | consumer |
| 分发 payload 字段 | `services/info_crawl_service.py:963-1000` | 发往 knowledge ingest |
| Admin 会话与 CSRF | `interfaces/http/admin/auth.py:23` | provider（浏览器面） |
| Web 会话 | `interfaces/http/web/auth.py:24` | provider |
| Web Run/SSE/Citation DTO | `application/dto/interaction.py`；路由 `interfaces/http/web/interactions.py:32` | provider（见 §8：未接真实后端） |
| 资讯 Admin REST | `interfaces/endpoints/info_routes.py` | 被 `info-admin-frontend/app/lib/info-api.ts:97-256` 消费 |
| 服务身份 JWT 校验 | `infrastructure/security/service_identity.py` | 见 [`../shared/identity.md`](../shared/identity.md) |
| Python / 前端依赖锁 | `info-backend/app/uv.lock`；各 `app/pnpm-lock.yaml` | 冻结安装 |
| release.json 与三镜像 digest | **不在本仓**，在 k8s 仓 | 见 [`../shared/release.md`](../shared/release.md) |
| 按角色拆分的外部 Secret | `dev-to-prod-deploy/secret-conf/guide.md:6-12` | migration/API/Worker/Scheduler 各持最小凭据 |

## 7. 本地怎么跑与怎么验

| 我要做什么 | 命令 | 定义位置 |
| --- | --- | --- |
| 克隆含子模块 | `git clone --recurse-submodules ...` | `README.md:32-34` |
| 后端依赖 | `cd info-backend/app && uv sync --frozen` | `README.md:44` |
| 后端门禁 | `uv run ruff check . && uv run pyright && uv run pytest -q` | `README.md:45-47` |
| 跑 API | `uvicorn app.bootstrap.api:app --host 0.0.0.0 --port 8000` | `info-backend/app/Dockerfile:37` |
| 跑迁移 | `uv run python -m app.bootstrap.migration upgrade head` | `app/bootstrap/migration.py:20-38` |
| 单次 outbox 扫描 | `uv run python -m app.cli.drain_delivery_outbox --limit 50` | `app/cli/drain_delivery_outbox.py:41-55` |
| Celery Worker | `celery -A app.bootstrap.worker worker`（须 `CELERY_BROKER_URL`） | `app/bootstrap/worker.py:1-7` |
| 前端 dev / check | `corepack pnpm install --frozen-lockfile`；`corepack pnpm dev` / `pnpm check` | `info-admin-frontend/app/README.md:12-16`；`package.json:23` |
| 环境变量 | 由 `info-backend/app/.env.example` 生成 `.env` | `core/config.py:643-646` |

## 8. 已知未实现

| 容易被误认为已完成的东西 | 实际状态 | 位置 |
| --- | --- | --- |
| 共享 `outbox_message` 事件发布 | 表与 `SqlOutboxRepository` 存在，业务层零调用 | `infrastructure/repositories/outbox.py:11-39` |
| `/api/internal` 服务面 HTTP | `interfaces/http/internal/` 只有包说明，无路由注册 | `interfaces/http/internal/__init__.py:1` |
| Web Run 由下游驱动 | `DownstreamServiceClient` 存在；`get_web_interaction_port` 默认返回 Unavailable | `external/downstream_service.py:18`；`ports/web_interaction.py:232-235` |
| 生产 Web 交互可用 | 默认 `REFERENCE_INTERACTION_ENABLED=false`；开启也只是 reference fixture | `core/config.py:101`；`ports/web_interaction.py:78-79` |
| Elasticsearch 搜索启用 | 默认 `SEARCH_BACKEND=disabled`，索引任务直接 skip | `core/config.py:180`；`info_crawl_service.py:1298-1300` |
| 内置 Scrapy/Playwright 爬虫 | 不内嵌；须由 `config.results` 外部注入 | `scrapy.py:19-22`；`playwright.py:18-21` |
| Celery Beat 周期任务 | Scheduler bootstrap 存在，无调度定义 | `bootstrap/scheduler.py:1-7` |
| `dispatch_distribution` 支持多下游 | 运行时仅接受 `target_app == "knowledge-app"` | `info_crawl_service.py:1177-1178` |
| Admin 上传有大小限制 | `/admin/uploads` 读全文件，无 `crawl_max_bytes` 同类校验 | `info_routes.py:501-506` |
| PDF 上传抽正文 | `_decode_upload_text` 对 PDF 返回 `None` | `tests/test_upload_helpers.py:8-9` |
| `required-secret-keys.txt` 在本仓 | 指南要求 Git 跟踪该文件，仓内未见 | `dev-to-prod-deploy/secret-conf/guide.md:3` |

核查范围：Celery 任务注册（`worker.py:81-84`）、HTTP 路由聚合（`routes.py`）、outbox 与下游
client 引用 grep、前端 env 开关、迁移与门禁测试。
