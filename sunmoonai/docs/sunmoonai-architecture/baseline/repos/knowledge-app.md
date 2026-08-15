# knowledge-app

> 仓库 `sunmoonlion/knowledge-app`
> 最后更新：2026-08-15 ｜ 验证时点：2026-08-15（对代码取证）
> 跨仓规则见 [`../shared/`](../shared/)；全局地图见 [`../map.md`](../map.md)

## 1. 这个仓是什么

知识域 App。父仓固定三个子模块 `knowledge-admin-frontend` / `knowledge-web-frontend` /
`knowledge-backend`（`.gitmodules:1-9`）。单一 FastAPI 后端同时服务 Admin 与 Web 浏览器面
（`knowledge-backend/app/app/bootstrap/api.py:64-66`）。领域实体含 Dataset 键、Provider binding、
Ingestion job、Retrieval Evidence 与 Citation 投影。
对外提供两套契约：**artifact 摄入**（消费方 info-app）与 **retrieval 检索**（消费方 investment-app）；
服务间入口为 `/api/internal/v1/knowledge/*`（`interfaces/endpoints/knowledge_routes.py:33-90`）。

## 2. 目录地图

| 路径 | 装什么 | 什么任务会动它 |
| --- | --- | --- |
| `knowledge-backend/app/app/application/` | 摄入/检索/认证/交互服务与 DTO | 业务规则与契约模型 |
| `knowledge-backend/app/app/interfaces/` | HTTP 路由、Schema 导出 | 新增或改 API 面 |
| `knowledge-backend/app/app/infrastructure/` | ORM、RAGFlow、S3、Celery、Redis/PG | 外部适配与持久化 |
| `knowledge-backend/db-access-bootstrap/` | 本地 PG/Redis 合并脚本 | 生成本地 `.env` |
| `knowledge-admin-frontend/app/` | Next.js Admin | 运维与治理 UI |
| `knowledge-web-frontend/app/` | Next.js Web | 用户会话、可选 Reference UI |
| `contracts/artifact/v1/` | Info→Knowledge 摄入 Schema | 摄入契约变更 |
| `contracts/retrieval/v1/` | 检索请求/响应/Citation Schema 与 manifest | 检索契约变更 |
| `dev-to-prod-deploy/` | 晋级配置指南 | 环境分层 |
| `docs/` | 父仓历史文档 | 非运行时真源 |

## 3. 改动前必读的硬规则

| 规则 | 代码位置 | 违反后果 |
| --- | --- | --- |
| `application/` 不得 import `interfaces` | `app/tests/test_kernel_invariants.py:33-36` | CI 失败 |
| Admin `/api/knowledge/*` 需 `knowledge:admin` scope | `app/core/config.py:409`；`middleware/auth.py:97` | 403 |
| 生产禁 `REFERENCE_INTERACTION_ENABLED=true` | `app/core/config.py:244-247` | 启动校验失败 |
| RAGFlow 轮询只有 `run=="FAIL"` 抛错 | `infrastructure/external/ragflow.py:334-344` | 其它终态（含 `CANCEL`）走成功链路 |
| 无 RAGFlow 凭据时摄入止于 `artifact_verified` | `services/knowledge_ingestion_service.py:458-531` | 不写 `KnowledgeDocument*` |
| 检索需 RAGFlow 已配置 | `services/knowledge_retrieval_service.py:73-74` | `ServiceUnavailableError` |
| `dataset_keys` ⊆ `RETRIEVAL_DATASET_ALLOWLIST` | `core/config.py:159-161`；`knowledge_retrieval_service.py:49-52` | `ForbiddenError` |
| `security_context.tenant_id` 须等于 `RETRIEVAL_DEFAULT_TENANT_ID` | `core/config.py:162-164`；`knowledge_retrieval_service.py:53-54` | `ForbiddenError` |
| Artifact 必须恰好 1 个 `s3://` 引用 | `infrastructure/external/ragflow.py:368-371` | `RAGFlowError` |
| S3 bucket/prefix 受 allowlist 约束 | `core/config.py:182-188`；`ragflow.py:388-394` | 摄入拒绝 |
| 内部 ingest/retrieve 需 Bearer + subject allowlist | `infrastructure/security/service_auth.py:71-74,153-164` | 401/403/503 |
| 生产关闭 OpenAPI 与 `/docs` | `app/bootstrap/api.py:69-71` | 无文档端点 |

## 4. 分层与关键流程

| 组件/层 | 职责 | 入口位置 |
| --- | --- | --- |
| Bootstrap | 组装 FastAPI、健康检查、CORS | `app/bootstrap/api.py:36-169` |
| HTTP Admin | Casdoor 会话 + 知识运维 API | `interfaces/http/admin/auth.py:23`；`endpoints/knowledge_routes.py:32` |
| HTTP Web | 用户认证 + Run/Interaction | `interfaces/http/web/auth.py`；`web/interactions.py:32` |
| HTTP Internal | 服务间 ingest / retrieve | `endpoints/knowledge_routes.py:33-90` |
| Application | 摄入与检索编排 | `services/knowledge_ingestion_service.py`；`knowledge_retrieval_service.py:41-105` |
| Infrastructure | RAGFlow、S3 校验、ORM | `external/ragflow.py`；`models/knowledge.py:13-132` |
| Tasks | Celery 异步摄入 | `tasks/knowledge_ingestion.py:11-25` |

**摄入**

| 步骤 | 做什么 | 位置 |
| --- | --- | --- |
| 1 | 校验 artifact 契约 DTO | `application/dto/knowledge.py:50-66` |
| 2 | 幂等写 job，`status=accepted` | `knowledge_ingestion_service.py:73-119` |
| 3 | Celery 可用则投递，否则同步处理 | `knowledge_routes.py:49-52,169-177` |
| 4 | `running` → S3 校验 → RAGFlow 上传/parse/轮询 | `knowledge_ingestion_service.py:461-497`；`ragflow.py:210-261,324-344` |
| 5 | 成功：upsert `KnowledgeDocument`/`Version`，job `succeeded` | `knowledge_ingestion_service.py:237-321` |
| 6 | 失败：分类为 `artifact_unreadable` / `ragflow_parse_failed` 等 | `knowledge_ingestion_service.py:324-355` |

**检索**

| 步骤 | 做什么 | 位置 |
| --- | --- | --- |
| 1 | 校验请求 DTO（对齐 schema） | `application/dto/retrieval.py:39-69` |
| 2 | dataset / tenant / scope 授权 | `knowledge_retrieval_service.py:49-56` |
| 3 | 查 `indexed` 且 `provider=ragflow` 的版本 | `knowledge_retrieval_service.py:107-137` |
| 4 | 调 RAGFlow `/retrieval` | `ragflow.py:172-207` |
| 5 | chunk → Evidence（稳定 UUID5） | `knowledge_retrieval_service.py:140-217` |
| 6 | Citation 由 `Citation.from_evidence` 投影 | `application/dto/retrieval.py:131-144` |

## 5. 数据与迁移

| 实体或迁移链 | 位置 | 说明 |
| --- | --- | --- |
| 迁移链目录 | `knowledge-backend/app/alembic/versions/` | head 见该目录最新 revision；顺序由 `test_kernel_invariants.py:39-63` 锁定 |
| `knowledge_ingestion_job` | `infrastructure/models/knowledge.py:13-58` | 摄入任务、状态历史、RAGFlow 绑定 |
| `knowledge_document` / `knowledge_document_version` | `models/knowledge.py:61-132` | 稳定文档 ID（UUID5）与 provider binding |
| `outbox_message` / `inbox_message` | `models/outbox.py:14-40` | **未接线**（见 §8） |
| Auth 身份表 | `alembic/versions/20260712_0002_auth_identity.py` | 浏览器会话 |
| UUID server default | `alembic/versions/20260811_0005_uuid_defaults.py` | 无新表 |
| 迁移入口 | `app/bootstrap/migration.py:20-38` | `upgrade` / `current` |

## 6. 契约与对外接口

| 契约/接口 | 真源位置 | 角色 |
| --- | --- | --- |
| Artifact v1 schema | `contracts/artifact/v1/info-knowledge-artifact.schema.json` | **provider**；producer 为 info-app |
| Artifact manifest | `contracts/artifact/v1/contract-manifest.json` | 测试校验 digest（`tests/test_knowledge_ingestion.py:115-117`） |
| Internal ingest | `POST /api/internal/v1/knowledge/ingestions` | `endpoints/knowledge_routes.py:55-73` |
| Retrieval v1 请求 / 响应 / Citation schema | `contracts/retrieval/v1/` | **provider**，major 1 |
| Retrieval manifest | `contracts/retrieval/v1/contract-manifest.json:5-6` | `service_consumers: ["investment-app"]` |
| 后端检索 DTO | `application/dto/retrieval.py:39-144` | `extra=forbid`，对 manifest digest（`tests/test_knowledge_retrieval.py:63-68`） |
| Internal retrieve | `POST /api/internal/v1/knowledge/retrievals` | `endpoints/knowledge_routes.py:76-90` |
| Admin 运维 API | `GET/POST /api/knowledge/ingestions*` | `endpoints/knowledge_routes.py:39-211` |
| Citation `source_href` 契约约束 | 正则 `^/api/citations/[0-9a-fA-F-]{36}/source$`（`citation.schema.json:31-34`） | **无同名 HTTP 路由**，见 §8 与 [`../shared/contracts.md`](../shared/contracts.md) |
| 浏览器面 Citation 路由 | `GET /citations/{evidence_id}/source`，挂在 web 前缀下 | `interfaces/http/web/interactions.py:128` |

## 7. 本地怎么跑与怎么验

| 我要做什么 | 命令 | 定义位置 |
| --- | --- | --- |
| 克隆含子模块 | `git clone --recurse-submodules ...` | `README.md:33-39` |
| 后端依赖 | `cd knowledge-backend/app && uv sync --frozen` | `README.md:44-45` |
| 后端门禁 | `uv run ruff check .`；`uv run pyright`；`uv run pytest -q` | `README.md:46-48` |
| 本地 PG/Redis 写入 `.env` | `./merge-and-generate-app-env.sh external` | `db-access-bootstrap/README.md:51-52` |
| 跑 API | `uv run uvicorn app.main:app --host 0.0.0.0 --port 8001` | `db-access-bootstrap/README.md:114` |
| 跑迁移 | `uv run python -m app.bootstrap.migration upgrade` | `bootstrap/migration.py:24-33` |
| 前端 | `corepack pnpm install --frozen-lockfile`；`corepack pnpm dev` | 两前端 `README.md:12-16` |
| 前端门禁 | `corepack pnpm typecheck` 等 | 两前端 `README.md:29-35` |
| 环境变量 | 复制 `knowledge-backend/app/.env.example` | `.env.example:1-112` |

## 8. 已知未实现

| 容易被误认为已完成的东西 | 实际状态 | 位置 |
| --- | --- | --- |
| Admin「Knowledge ingestions」运维页 | **静态占位页**：只列 API 路径文案，无 fetch、无表格、无操作 | `knowledge-admin-frontend/app/components/knowledge/knowledge-ingestions-panel.tsx:5-17` |
| RAGFlow `CANCEL` 被当作失败 | 与 `DONE` 同等视为 parse 完成，job 标 `succeeded` | `ragflow.py:334-344`；`knowledge_ingestion_service.py:306-318` |
| 检索契约 `source_href` 可直接 GET | DTO 与 schema 定义 `/api/citations/...`，后端无该路由；实际路由在 web 前缀下 | `dto/retrieval.py:124-127` vs `web/interactions.py:128` |
| Outbox 领域发布 | 表与 `SqlOutboxRepository` 存在，应用服务层零 `enqueue` 调用 | `repositories/outbox.py:11-14` |
| Web Run/Interaction 生产路径 | 默认 `UnavailableWebInteractionAdapter` 抛 503 | `ports/web_interaction.py:41-75,232-235` |
| Reference UI 默认可见 | 前端默认 `REFERENCE_UI_ENABLED=false` | `web-frontend/app/.env.example:12`；`dashboard/page.tsx:48-53` |
| 无 RAGFlow 也能完整索引 | 摄入止于 `artifact_verified`，不写 document/version | `knowledge_ingestion_service.py:519-531` |
| Web 侧有检索业务页 | 只有 toolkit/common 与可选 reference workspace | `web-frontend/app/app/[locale]/(dashboard)/` 目录 listing |

核查范围：Admin 入库页组件与路由、outbox 调用链、web interaction 适配器、citation 路由 grep、
`tasks/` 目录（仅 `ping` 与 `knowledge_ingestion`）、RAGFlow 轮询终态映射。
