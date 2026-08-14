# tpl-app

> 仓库路径 `/home/zymun/tpl-app`。深读基线：2026-08-13。
> App 之间的公共形态见 `baseline/app-platform/inter-apps/app-platform.md`；
> 平台间关系见 `baseline/sunmoonai/architecture.md`。

## 1. 概要

领域 App 母模板：info/knowledge/investment（及未来 research/tools）都从它实例化。本身无业务
领域，提供「一个 FastAPI Backend + 两个 Next.js 前端 + K8s 部署脚手架 + 发布治理」的完整
生产骨架。正式版本 **2.0.0**（`template-release-manifest.json` 锁定，`status=FORMAL_RELEASE`）。

### 仓库拓扑

| 组件 | 角色 |
| --- | --- |
| `tpl-backend` | FastAPI / Python ≥3.12 / uv；四角色一镜像（API/Worker/Scheduler/Migration） |
| `tpl-admin-frontend` | Next.js 16 管理端（shadcn + @base-ui + Tailwind v4） |
| `tpl-web-frontend` | Next.js 16 用户端 |
| `k8s-deployment` | scaffold.py / deploy.py + 五件套模板 |
| 父仓 | release manifest、配对矩阵、init.sh、verify 脚本 |

React Router/Vue Admin 与 NestJS 变体已移至独立 `repo-backup`，只保证源码可恢复，不参与
当前配对验收。

### 运行与验证

- backend：`uv sync --frozen && ruff check && ruff format --check && pyright && pytest`
  （Dockerfile type-check 阶段任一失败即中断构建）。
- scaffold：`python3 -m unittest discover -s k8s-deployment/tests` +
  `python3 verify_template_release.py`。
- 前端：`pnpm check`（typecheck + lint + i18n + test + build）。

## 2. 重要点

1. **母模板 + 实例化**：新 App 克隆 → 改名 → `./init.sh <app> <org>` 一次性原地转换 →
   **子仓先推、父仓后提交 gitlink**。
2. **四角色一镜像**：API/Worker/Scheduler/Migration 同一不可变镜像、不同命令与权限；
   Migration 成功才 rollout 运行角色。
3. **每表面不可变安全边界**：`BrowserSurfaceProfile`（frozen）——admin 强制 `{app}:admin`
   scope，web 无；cookie/redirect/origin 生产强校验。
4. **认证三件套**：双表面 OIDC/Casdoor（PKCE + Redis 事务 + CSRF）、internal 服务身份
   （subject→scope 精确绑定）、出站 downstream client_credentials。
5. **web-interaction v1 契约**：RunSnapshot / 七种 SSE 事件 / Citation 自洽约束 + 消费方
   测试向量；Port 未实现默认 503 provider_unavailable。
6. **Outbox/Inbox 原语**：dedup 唯一键幂等、SKIP LOCKED 租约、inbox 复合主键幂等。
7. **发布治理**：manifest schema 2 锁三组件 commit/tree/digest + verify 脚本逐项核对；
   实例同步顺序 **info→knowledge→investment** 冻结、禁 mutable tag、禁覆盖 1.0.0。
8. **同步纪律**：公共缺陷必须先修模板、过门禁，再串行同步实例；实例差异分类登记，
   prohibited-drift=0 才能写入。

## 3. 架构

### 3.1 配对矩阵（当前锁定的 commit）

三个活动 git 子模块 + 父仓治理文件。默认三组件：

| 组件 | commit | 镜像 digest | 说明 |
| --- | --- | --- | --- |
| tpl-backend | `2d3c27fa`（146 files） | `sha256:8b504098...` | FastAPI 3.12，uv 管理，version 2.0.0 |
| tpl-admin-frontend | `798203a3`（123 files） | `sha256:cd2b91f5...` | Next.js 管理端 |
| tpl-web-frontend | `e56965af`（99 files） | `sha256:a835b1d4...` | Next.js 用户端 |

`frontend-pairing-matrix.json` 只保留两个 DEFAULT pair：Next Admin↔FastAPI 与
Next Web↔FastAPI；历史 release manifest 中的旧路径仅作冻结审计。`frontend-capability-matrix.json`
继续规定 COMMON 能力必须 Admin/Web 各自实现并测试。

### 3.2 init.sh 实例化（一次性原地转换）

拒绝在名为 `tpl-app` 的目录或脏工作树执行；APP_NAME 必须 `^[a-z][a-z0-9-]*$` 且不为 tpl。
步骤：三个活动组件全文本替换 tpl→app 标识并改名路径 → 重写 `.gitmodules` 指向
`github.com/{org}/{app}-*` → `git mv` 三组件 → 修正 package identity 与子模块元数据。推送顺序
永远是子仓先推、父仓后提交 gitlink。

### 3.3 tpl-backend：四角色一镜像

同一不可变镜像四个入口（`bootstrap/`）：API（`uvicorn app.bootstrap.api:app`）、Worker（`celery -A app.bootstrap.worker:celery_app worker`）、Scheduler（beat）、Migration（`python -m app.bootstrap.migration upgrade|current`，一次性退出）。CELERY.md 验收六条：四角色同 digest、三个 ServiceAccount 互异、Migration 成功才 rollout、失败可重试无重复副作用、Scheduler 不重复调度、API 不持 consumer 凭据。

#### api.py 工厂

生产禁 /docs、/redoc、/openapi；lifespan 生产或配置了 Casdoor 即 `require_browser_identity()`；request-context 中间件：audit_mutation 日志（非安全方法 + /api/）、X-Correlation-ID/X-Operation-ID 回传、nosniff/DENY/no-referrer/Permissions-Policy、`/api/auth/` 强制 no-store；TrustedHost + CORS（仅前端 origins，白名单头含 X-CSRF-Token/X-Audit-Reason）；readiness 别名 /health/ready、/api/health、/ready（Redis ping + SELECT 1）；`/api/version` 返回 deploymentId + contractVersion=1。

#### 配置内核（core/config.py）

`BrowserSurfaceProfile`（frozen）= 每表面的不可变安全边界：client_id/secret、redirect_uri、application、frontend origins、policy_version、role/scope allowlist、return_to 白名单、required_scopes（**admin 强制 `{app_slug}:admin`，web 无**）、cookie 名 `sunmoonai_{app}_{surface}_sid`/事务 cookie、Redis key 前缀。生产强校验：HTTPS origins、禁 wildcard host、禁 `REFERENCE_INTERACTION_ENABLED`、cookie secure、redirect 必须以 `/api/auth/{surface}/callback` 结尾且 origin 与 FRONTEND_BASE_URL 一致且包含在 allowed origins 内；discovery URL 必须同源标准路径。downstream：`require_downstream_identity()` 拒绝指向本 Backend 的 base_url、路径前缀非空（默认 `/api/internal/v1`）、生产强制 verify_ssl。service_auth：`SERVICE_AUTH_SUBJECT_BINDINGS_JSON` = subject→最大 scope 集精确映射。Celery 队列默认 `{app}.default`；DATABASE_URL 归一化为 asyncpg 并剥 sslmode。

#### 认证体系

- **双表面 OIDC/Casdoor**（AuthService 以 profile 参数化，admin/web 完全同构）：begin_login 生成 transaction_id/state/nonce/PKCE verifier，事务存 Redis（NX+TTL），signup 模式仅 web 允许；complete_login 用 `GETDEL` 原子消费事务，hmac.compare_digest 验 state，换码后经 `verify_id_token`（issuer/audience/nonce 严格校验、claims registry essential、JWKS 验签失败强制刷新重试一次）；expires = min(provider exp, now+session_ttl)；影子用户 `auth_user` upsert（uq issuer+subject，roles/scopes 只收 allowlist 交集）；会话以 NX 写 Redis。**CSRF**：非安全方法必须 Origin∈frontend_origins + X-CSRF-Token 与会话 csrf hmac 相等。
- **internal 面**：`ServiceIdentityVerifier` 验 Provider 签发的 workload JWT（audience=SERVICE_AUTH_AUDIENCE），subject 必须命中 bindings 精确键，token scopes ⊆ allowed 且 required ⊆ token scopes，产出 surface=internal 的 service Principal。
- **出站**：`DownstreamServiceClient` client_credentials（锁内双检 + 提前 30s 刷新、expires_in 上限 3600），路径必须命中 allowlist 前缀且为安全相对路径，follow_redirects=False，5xx→503、4xx→400、非 JSON→contract_invalid。
- HTTP 依赖（middleware/auth.py）：`get_admin/web_browser_session`（cookie+CSRF+actor 注入）、`require_admin_scopes`、`get_internal_service_principal`/`require_internal_scopes`（Bearer 严格解析）。

#### Web 交互契约（web-interaction v1）

`/api/web/v1` 四端点：`GET /runs/{id}`（RunSnapshot）、`GET /runs/{id}/events`（SSE，Last-Event-ID 头与 last_event_id 参数冲突即 400，事件 `id:/event: run-event/data:` 格式，no-cache + X-Accel-Buffering:no）、`POST /runs/{id}/actions`（RunAction）、`GET /citations/{evidence_id}/source`（302，location 必须安全相对路径）。DTO 全部 contract_version=1、frozen、extra=forbid：RunStatus 六态、七种 RunEvent（status/delta/citation/input_required/completed/failed/heartbeat，discriminator=type）、BrowserCitation 的 source_href 正则且必须与 evidence_id 自洽、citations ≤50 且 evidence_id 唯一。Port 未实现时默认 UnavailableAdapter（503 provider_unavailable）；ReferenceAdapter 是确定性配对测试适配器，用固定 uuid5 序列，生产配置拒绝启用。`contracts/web-interaction-v1.consumer-vectors.json` 是消费方测试向量（快照+七事件流+invalid 向量）。

#### Outbox/Inbox 原语

`OutboxEvent` DTO：topic 正则、256 KiB 序列化上限、headers ≤32 条且禁 CRLF。`SqlOutboxRepository`：enqueue 用 `ON CONFLICT (deduplication_key) DO UPDATE`（幂等返回已有 id）；claim_batch = CTE 候选（pending 或 delivering 租约过期）`FOR UPDATE SKIP LOCKED` → 置 delivering + lease_owner/lease_expires_at + attempt_count；mark_published/mark_failed 必须仍持租约（丢失即 RuntimeError），失败按 retry_seconds 回 pending。`claim_inbox_once`：(consumer, message_id) 复合主键 DO NOTHING 幂等。表约束：status 三态 CHECK + (status, available_at, lease_expires_at) claim 索引。

#### 错误模型与审计

AppException 族（400/401/403/404/409 cursor_expired/422/502 contract_invalid/503）→ 统一 `application/problem+json`：`urn:sunmoonai:problem:{code}` + operation_id + 兼容旧浏览器契约的 error 嵌套。AuditContext（contextvar）：X-Correlation-ID 校验或生成 uuid4、X-Operation-ID、X-Audit-Reason ≤500 且禁控制字符，`set_actor` 在认证依赖中回填。

#### 迁移与数据模型

Alembic 链 head `20260801_0002`：`20260726_0001` auth_user（本地授权绑定，非用户主库）→ `20260801_0002` outbox_message + inbox_message。env.py 用 `migration_url`（MIGRATION_DATABASE_URL 可独立于运行时 URL），asyncio 在线迁移。实例 App 以此为 down_revision 接续自己的领域链。

#### 构建与工具链

pyproject：Python ≥3.12，fastapi/sqlalchemy2/asyncpg/redis/celery/httpx/joserfc/pydantic2；ruff select E/F/I/UP/B/ASYNC；pyright basic（include app/core，exclude alembic）；uv 源清华镜像。`mybuild/Dockerfile` 三阶段：**type-check 阶段装全量依赖跑 ruff check + ruff format --check + pyright，任一失败中断构建** → builder 裁 dev 依赖 → runtime 非 root uid 1001。10 个测试文件覆盖 auth 路由安全/OIDC/CSRF/service identity/downstream/outbox/interaction 契约与消费向量/config 安全/kernel 不变量。附属：db-provisioner（dbctl + external/k8s adapters + postgresql/redis/mongodb drivers）、db/search/storage-access-bootstrap 三套凭据引导脚本。

### 3.4 双前端（Next.js 16.2 / React 19 / pnpm 10.24 / node ≥24.18）

同构技术栈：next-intl（zh-CN/en locale 路由）、shadcn + @base-ui + tailwind v4、tanstack query 5、zustand 5、zod 4、vitest + playwright。`output:'standalone'`；源码在内层 `app/` 目录。

- **proxy.ts**（Next 16 路由边界）：仅做 locale 路由 + 每请求 CSP nonce（x-nonce 头），matcher 只匹配 `/` 与 `/(en|zh-CN)/:path*`；注释明示**鉴权绝不下放此处**。
- **env/server-schema.ts**：zod 严格校验 server env；生产运行时强制 DEPLOYMENT_ENV/AUTH_APP/APP_ORIGIN(HTTPS)/BACKEND_INTERNAL_URL/DEPLOYMENT_ID，test 环境强制 loopback。AUTH_APP 枚举 `tpl|info|knowledge|research`。
- **SSR 会话**：`lib/server/auth-session.ts`（server-only）带浏览器 cookie 调 `BACKEND_INTERNAL_URL + /api/auth/web/me`，401→null，契约失败或 `user.app !== AUTH_APP` → contract_invalid；`requireBrowserSession` 无会话 redirect login。浏览器永不持 token。
- **api-client**（client）：只允许同源 `/api/` 路径，非安全方法带 X-CSRF-Token，redirect manual，problem 归一化（code/message_key/retryable/correlation_id/field_errors）。
- **run-stream-hitl-citation（WEB_ONLY）**：`use-run-projection` = 快照 query + EventSource（withCredentials，last_event_id 续传）+ 事件应用（gap → reconcile 重拉快照，终态 → reconcile）+ 指数退避重连 ≤10s；contracts/interaction.ts 用 zod 复刻后端契约（含 citation source_href 自洽 refine）；消费 vectors 做契约测试。
- **Admin 专属**：app-shell/菜单/settings/forbidden 页、crud 套件（data-table/schema-form/action-drawer/audited-action-dialog/contract-upload/feedback/resource-description）、rich 套件（markdown-editor/media-player/metric-chart/progress/text-effects/avatar/behavior/icon-registry）、zustand ui store、download 工具。

### 3.5 k8s-deployment 脚手架（scaffold.py + deploy.py + deployment_config.py + 五模板）

`scaffold.py`：渲染五件套（00-prerequisites/10-migration/20-runtime/30-network-policies/40-ingress）。校验：镜像必须 `repo@sha256:64hex`、DNS label、strict origin、app+release-id 生成的 Job 名 ≤63、副本 1-20、输出目录必须为空、渲染后拒绝残留 `__TOKEN__`。默认值：client_id `sunmoonai-{app}-{surface}`、casdoor namespace `app-platform-dev`、image-pull `harbor-registry-secret`、ingress namespace `kube-system`（traefik pod label）。产物：required-secret-keys.txt 十键（ADMIN/WEB_CASDOOR_CLIENT_SECRET、API/WORKER/SCHEDULER_CELERY_BROKER_URL、API/MIGRATION/SCHEDULER/WORKER_DATABASE_URL、REDIS_PASSWORD）+ optional 两键（WORKER_CELERY_RESULT_BACKEND、WORKER_DOWNSTREAM_CLIENT_SECRET）+ release.json（模板侧 schema 1，正式实例 bundle 已演进为 schema 2，见 `intra-apps/k8s/k8s.md`）、每文件 sha256。`deploy.py`：plan/apply/cleanup；apply 强制 `--secret-env-file`（0600 env 注入 Secret）；cleanup 按 selector `sunmoonai.com/managed-by=architecture-v2`。runtime 模板：非 root 1001、seccomp RuntimeDefault、automountServiceAccountToken:false、topologySpread、RollingUpdate maxUnavailable:0；API 只拿 API_* Secret 键，角色间 Secret 键隔离。

### 3.6 发布治理（template-release-manifest.json + verify_template_release.py）

manifest schema 2：`source`（repository/branch/commit `1c557930`/tree `d7dcca19`/pre_refactor_tag）；三组件锁 commit/tree/tracked_files/digest；scaffold 路径 `k8s-deployment`（tree `ab75eb30`，11 files），deployment_order = prerequisites-secret-network-policy → migration → runtime → ingress；common_file_manifest（git-tree-v1，差异只许 domain-extension/deployment-config/temporary-compatibility，其余 prohibited-drift）；contract_versions（backend_api v1、migration head `20260801_0002`、bundle 1）；identity_policy（shared_backend + 五分离）；database_policy（一 App 一 owner + 四运行 principal）；release_policy（实例同步顺序 **info→knowledge→investment** 冻结、禁 mutable tag、禁覆盖 1.0.0、formal_version 2.0.0、promotion_method exact-digest-alias、observation_window closed、irreversible_v1_cleanup_allowed=true）。verify 脚本逐项核对：schema/架构/formal_release/source tree/组件 HEAD=锁定 commit/tree/文件数/镜像不可变/scaffold tree 与计数/同步顺序/1.0.0 保护。

## 4. 关联

- 公共形态与模板治理规则：`../../inter-apps/app-platform.md`（§10 模板治理）。
- 部署声明与验收门禁：`../k8s/k8s.md`。
- 三个实例 App：`../info-app/info-app.md`、`../knowledge-app/knowledge-app.md`、
  `../investment-app/investment-app.md`。
- 平台间关系：`../../../sunmoonai/architecture.md`。
