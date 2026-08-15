# tpl-app

> 仓库 `sunmoonlion/tpl-app`
> 最后更新：2026-08-15 ｜ 验证时点：2026-08-15（对代码取证）
> 跨仓规则见 [`../shared/`](../shared/)；全局地图见 [`../map.md`](../map.md)

## 1. 这个仓是什么

模板仓。父仓聚合三个 Git 子模块 `tpl-backend` / `tpl-admin-frontend` / `tpl-web-frontend`
（`.gitmodules:1-9`），另含 K8s 部署脚手架 `k8s-deployment/`。
产出可实例化的后端与前端源码模板、bundle 生成器、以及模板发布锁
`template-release-manifest.json`。消费方为新 App 实例（`init.sh` 原地转换）与实例同步链
（顺序锁定 `info → knowledge → investment`，`verify_template_release.py:77`）。

## 2. 目录地图

| 路径 | 装什么 | 什么任务会动它 |
| --- | --- | --- |
| `tpl-backend/` | FastAPI 统一后端（API/Worker/Scheduler/Migration 同镜像） | 领域 API、认证、Outbox 原语、迁移 |
| `tpl-admin-frontend/` | Next.js 管理端 | Admin OIDC 会话、CRUD 壳层、E2E |
| `tpl-web-frontend/` | Next.js 用户端 | Web OIDC、web-interaction 消费端 |
| `k8s-deployment/` | `scaffold.py` / `deploy.py` / `deployment_config.py` + YAML 模板 | 生成、应用、清理 bundle |
| `contracts/` | 跨仓共享契约测试向量 | web-interaction v1 双端对齐 |
| `dev-to-prod-deploy/` | 晋级手册、Secret/ConfigMap 分层 | 发布流程 |
| `template-release-manifest.json` | 模板正式 release 锁 | 实例同步前门禁 |
| `verify_template_release.py` | 模板 release 校验脚本 | CI 与发布前 |
| `init.sh` | 克隆转实例父仓 | 新建 App 时一次性 |
| `frontend-pairing-matrix.json` | Admin/Web ↔ Backend 配对声明 | 配对验收 |
| `docs/` | 空目录 | — |

## 3. 改动前必读的硬规则

| 规则 | 代码位置 | 违反后果 |
| --- | --- | --- |
| 禁止在名为 `tpl-app` 的权威目录跑 `init.sh` | `init.sh:26-28` | `exit 2` |
| 实例化要求父仓与子模块工作树干净 | `init.sh:31-47` | `exit 2` |
| 生产禁止启用 reference interaction | `tpl-backend/app/core/config.py:171-174` | `Settings` 抛 `ValueError` |
| bundle 须 `schema_version=1` 且 `architecture=app-platform-v2` | `k8s-deployment/deploy.py:52-53` | `DeployError` |
| bundle 文件 sha256 须与 `release.json` 一致 | `k8s-deployment/deploy.py:57-61` | `DeployError: bundle hash mismatch` |
| Secret env 文件不得含 group/other 权限位 | `k8s-deployment/deploy.py:66-68` | `DeployError` |
| Secret env 键须与 `release.json.secret_keys` 完全匹配 | `k8s-deployment/deploy.py:75-81` | `DeployError: secret key mismatch` |
| `apply` 必须带 `--secret-env-file` | `k8s-deployment/deploy.py:353-354` | `DeployError` |
| 镜像须为 `repository@sha256:<64hex>` | `k8s-deployment/scaffold.py:37-40` | `ValueError` |
| scaffold 输出目录须不存在或为空 | `k8s-deployment/scaffold.py:143-144` | `ValueError` |
| 部署 `.conf` 禁未知键、禁 `export` 语法 | `k8s-deployment/deployment_config.py:81-86` | `ConfigError` |
| 部署配置值须与 `release.json` 完全一致 | `k8s-deployment/deployment_config.py:177-186` | `ConfigError` |
| 模板 release 锁须 schema 2 + `formal_release=true` + `template_release=2.0.0` | `verify_template_release.py:34-41` | `ReleaseError`，退出码 1 |
| 组件镜像须匹配不可变 digest 正则 | `verify_template_release.py:14-15,62-63` | `ReleaseError: mutable component image` |
| 生产前端 `APP_ORIGIN` 须 HTTPS | `tpl-web-frontend/app/env/server-schema.ts:64-65` | `throw new Error` |

## 4. 分层与关键流程

| 组件/层 | 职责 | 入口位置 |
| --- | --- | --- |
| Bootstrap | 按角色启动四种进程 | `tpl-backend/app/app/bootstrap/api.py:36`、`worker.py:3-5`、`scheduler.py:3-5`、`migration.py:20-38` |
| HTTP 路由 | Admin/Web 认证、Admin 诊断、Web interaction | `tpl-backend/app/app/interfaces/http/routes.py:8-12` |
| Application | 认证服务、Web interaction 端口适配 | `application/services/auth_service.py:27-28`、`application/ports/web_interaction.py:232-235` |
| Domain | 安全主体模型（其余目录为空，见 §8） | `domain/security/principal.py:17` |
| Infrastructure | PG/Redis、Outbox SQL、OIDC、Celery producer | `repositories/outbox.py:11`、`messaging/celery_producer.py:20` |
| K8s 脚手架 | 渲染、部署、配置校验 | `k8s-deployment/scaffold.py:107`、`deploy.py:345` |

**Web interaction 请求（默认不可用）**

| 步骤 | 做什么 | 位置 |
| --- | --- | --- |
| 1 | 路由前缀 `/api/web/v1` | `interfaces/http/web/interactions.py:32` |
| 2 | `get_web_current_user` 校验会话 | `interactions.py:67-68` |
| 3 | `get_web_interaction_port` 选适配器 | `application/ports/web_interaction.py:232-235` |
| 4 | 默认返回 `UnavailableWebInteractionAdapter` → 503 | `web_interaction.py:41-51,235` |

**K8s 全量部署（脚手架侧，与正式 bundle 顺序一致）**

| 步骤 | 做什么 | 位置 |
| --- | --- | --- |
| 1 | 校验 bundle hash 与 schema | `deploy.py:47-62` |
| 2 | apply prerequisites + 校验外部 Secret | `deploy.py:161-169` |
| 3 | 创建并标注 runtime Secret | `deploy.py:171-197` |
| 4 | apply NetworkPolicy | `deploy.py:199` |
| 5 | 跑 migration Job 后删除 | `deploy.py:106-146,242-248` |
| 6 | apply runtime + ingress，等 5 个 Deployment rollout | `deploy.py:250-268` |

cleanup 的 label selector 为
`sunmoonai.com/managed-by=app-platform-v2,sunmoonai.com/app={app}`（`deploy.py:289-301`）。

## 5. 数据与迁移

| 实体或迁移链 | 位置 | 说明 |
| --- | --- | --- |
| 迁移链目录 | `tpl-backend/app/alembic/versions/` | 线性单链，head 见该目录最新 revision 文件 |
| `20260726_0001` auth_user | `alembic/versions/20260726_0001_auth_identity.py:14-15` | `down_revision = None` |
| `20260801_0002` outbox/inbox | `alembic/versions/20260801_0002_outbox_primitives.py` | 顺序由 `tests/test_kernel_invariants.py:45-51` 锁定 |
| ORM `auth_user` | `infrastructure/models/auth.py:10-13` | issuer + subject 唯一 |
| ORM `outbox_message` / `inbox_message` | `infrastructure/models/outbox.py:14-15,51-54` | 见 §8：未接线 |
| Outbox DTO 约束 | `application/dto/outbox.py:10-19` | topic/payload/headers 大小与格式 |
| 迁移入口 | `app/bootstrap/migration.py:24-37` | `upgrade head` / `current` |

## 6. 契约与对外接口

| 契约/接口 | 真源位置 | 消费方 |
| --- | --- | --- |
| web-interaction v1 共享向量 | `contracts/web-interaction-v1.consumer-vectors.json:2-3` | 后端 `tests/test_interaction_consumer_vectors.py:26-27`；Web `interaction-consumer-vectors.test.ts:39` |
| 后端 interaction DTO | `tpl-backend/app/app/application/dto/interaction.py` | `interfaces/http/web/interactions.py:14-17` |
| Web 前端 interaction Zod | `tpl-web-frontend/app/contracts/interaction.ts:15-31` | `reference-workspace.tsx:5-6` |
| Web interaction Port | `application/ports/web_interaction.py:22` | Reference / Unavailable 两个适配器（`:41,78`） |
| Reference 适配器的固定 ID | `application/ports/web_interaction.py:33-38` | **硬编码 v5 格式常量**；全仓无 `uuid5()` 调用 |
| 模板 release 锁 schema 2 | `template-release-manifest.json:2-4` | `verify_template_release.py:34-41` |
| 脚手架 bundle release schema 1 | `k8s-deployment/scaffold.py:209-211` | 正式实例 bundle 为 schema 2，见 [`../shared/release.md`](../shared/release.md) |
| 前后端配对矩阵 | `frontend-pairing-matrix.json:4-20` | Admin/Web 均配对 `tpl-backend` |
| 后端契约版本 | `app/bootstrap/api.py:160-166` | `/api/version` 返回 `contractVersion: 1` |

## 7. 本地怎么跑与怎么验

| 我要做什么 | 命令 | 定义位置 |
| --- | --- | --- |
| 后端依赖同步 | `cd tpl-backend/app && uv sync --frozen` | `README.md:69-71` |
| 后端三件套 | `uv run ruff check .` / `uv run pyright` / `uv run pytest -q` | `README.md:72-74` |
| 脚手架单测 | `python3 -m unittest discover -s k8s-deployment/tests -v` | `README.md:80` |
| 模板 release 锁校验 | `python3 verify_template_release.py` | `README.md:81` |
| 渲染 bundle | `python3 k8s-deployment/scaffold.py --app ... --output-dir ...` | `k8s-deployment/README.md:31-43` |
| 部署 | `python3 k8s-deployment/deploy.py plan\|apply\|cleanup --bundle ...` | `k8s-deployment/README.md:66-70` |
| 前端 | `pnpm dev` / `pnpm build` / `pnpm check` | `tpl-web-frontend/app/package.json:11-23` |
| Celery 探活 | `uv run celery -A app.worker.celery_app inspect ping` | `tpl-backend/docs/CELERY.md:28-30` |
| E2E | `pnpm test:e2e`（自动起 `scripts.pair_fixture:app`） | `package.json:21`；`playwright.config.ts:26` |
| 跨仓向量测试 | 设 `WEB_INTERACTION_CONSUMER_VECTORS=<path>` 后跑 pytest / vitest | `test_interaction_consumer_vectors.py:18-20` |

## 8. 已知未实现

| 容易被误认为已完成的东西 | 实际状态 | 位置 |
| --- | --- | --- |
| 生产级 Web interaction Provider | 默认 `UnavailableWebInteractionAdapter` 返回 503 | `application/ports/web_interaction.py:232-235,41-51` |
| Reference interaction 可用于生产 | 生产环境显式禁止开启 | `core/config.py:171-174` |
| `/api/internal/v1` 入站 API | 只有 `get_internal_service_principal` 中间件，无 router 挂载 | `middleware/auth.py:100-133`；`routes.py:8-12` |
| Outbox 消费链路 | 仓库类与 Port 存在，业务层零调用（全仓仅 `__init__.py` 再导出） | `repositories/outbox.py:11`；`ports/outbox.py:24-25` |
| Downstream 出站客户端已接线 | 仅被单元测试直接使用 | `external/downstream_service.py:18`；`tests/test_downstream_service.py:41` |
| 领域层业务模型 | `domain/models`、`domain/repositories`、`domain/services` 仅空 `__init__.py` | 目录 listing |
| Celery 周期任务 | Scheduler bootstrap 存在，无 `beat_schedule` 定义 | `bootstrap/scheduler.py:3-5` |
| `release.json` 与部署配置副本对齐 | `scaffold.py` 输出不含 `deployment_replicas`，而 `validate_release` 要求匹配 | `scaffold.py:209-229` vs `deployment_config.py:167-181` |
| Scheduler 副本可配置 | 模板硬编码 `replicas: 1`，配置层却要求与 release 一致 | `20-runtime.yaml.tpl:356` vs `deployment_config.py:36,172` |
| Web Reference UI 默认可见 | 默认 `REFERENCE_UI_ENABLED=false` | `server-schema.ts:57,81`；`dashboard/page.tsx:48` |
| Admin 前端有 Reference UI | 无相关代码 | `rg REFERENCE_UI tpl-admin-frontend` 无匹配 |
| E2E 跑真实 Backend bootstrap | Playwright 启独立 `pair_fixture`，代码注释声明非生产 bootstrap | `scripts/pair_fixture.py:1-6` |
| React/Vue Admin、Nest Backend 变体 | 仅列于 manifest `optional_capabilities`，不在活动子模块 | `template-release-manifest.json:98-118`；`.gitmodules:1-9` |
