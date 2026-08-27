# tpl-app（模板仓）

> 取证时点：2026-08-27 ｜ 总览见 [`../../overall-architecture.md`](../../overall-architecture.md)

## 1. 定位

定义"一个标准 App 长什么样"，并提供实例化所需的骨架、契约与部署脚手架。
**它本身没有业务领域**——`domain/models/`、`domain/repositories/`、`domain/services/`
都只有空的 `__init__.py`，唯一有内容的是 `domain/security/principal.py`。

它也没有 `interfaces/endpoints/`（那是实例放领域路由的地方）。

三个领域 App 从它实例化，同步顺序锁定为 `info → knowledge → investment`。

## 2. 结构

后端 65 个 py 文件 / 3478 行（不含 `core/`）。`core/config.py` 另有 518 行。

| 路径 | 装什么 |
| --- | --- |
| `tpl-backend/app/core/config.py` | **518 行**，Pydantic Settings + 约 35 处生产期硬校验。真正的强制在这里 |
| `tpl-backend/app/app/bootstrap/` | 四个运行角色入口：`api.py`(173) / `worker.py`(7) / `scheduler.py`(7) / `migration.py`(42) |
| `tpl-backend/app/app/application/services/` | `auth_service.py`(373)、`web_interaction.py`(235) |
| `tpl-backend/app/app/application/ports/` | `outbox.py`、`web_interaction.py`——Port 定义 |
| `tpl-backend/app/app/infrastructure/security/` | `oidc.py`(428)、`service_identity.py`(108) |
| `tpl-backend/app/app/infrastructure/repositories/outbox.py` | 164 行，Outbox SQL 实现 |
| `tpl-backend/app/app/interfaces/http/` | `admin/`（auth、diagnostics）+ `web/`（auth、interactions）+ `middleware/` |
| `tpl-backend/app/alembic/versions/` | 2 个版本（见 §5） |
| `tpl-admin-frontend/` `tpl-web-frontend/` | 两个 Next.js 前端 |
| `k8s-deployment/` | `scaffold.py` / `deploy.py` / `deployment_config.py` + 五份 YAML 模板 |
| `contracts/web-interaction-v1.consumer-vectors.json` | 双端测试向量（valid + invalid 两组） |
| `template-release-manifest.json` + `verify_template_release.py` | 模板发布锁与校验 |
| `init.sh` | 克隆转实例的一次性原地转换 |

`app/main.py` 只有 5 行，注释自陈是 "Backward-compatible ASGI import"，
真正的进程构造在 `bootstrap/api.py`。

## 3. 硬规则

### 3.1 结构不变量（`app/tests/test_kernel_invariants.py`，65 行 5 项）

| 检查 | 实际断言什么 |
| --- | --- |
| `test_legacy_split_backend_shortcuts_are_absent` | `AdminAuthService`/`WebAuthService` 字符串不出现；无 `ADMIN_/WEB_BACKEND_INTERNAL_URL`；无 `allow_origins=["*"]`；routes 里两个 auth router 都在 |
| `test_interface_partition_and_dependency_direction_are_explicit` | 9 个关键文件存在；且 **`app.interfaces` 字符串不出现在整个 `app/application/` 目录** |
| `test_one_linear_canonical_migration_chain` | 迁移文件名清单**逐字**匹配；恰好 1 个 `down_revision = None`；第二个的 down_revision 指向第一个 |
| `test_runtime_image_context_excludes_credentials_and_tests` | `.dockerignore` 含 `app/.env`、`app/.env.*`、`app/tests` |
| `test_candidate_does_not_claim_the_formal_release` | pyproject **必须**是 `2.0.0.dev0`；`api.py` **不得**含 `version="2.0.0"` |

**注意这批检查的性质**：多为文件存在性与字符串缺席断言，是结构性冒烟测试，
不是深度架构校验。例如分层检查只 grep 字符串，不做真正的导入图分析。

### 3.2 启动期硬校验（`core/config.py`，约 35 处）

配置错误的表现是**启动抛异常**，不是运行期降级。生产环境下会失败的包括：

`DEPLOYMENT_ID` 为空 · `ALLOWED_HOSTS` 用通配或为空 · `CASDOOR_VERIFY_SSL` 非 true ·
`SESSION_COOKIE_SECURE` 为 false · `REFERENCE_INTERACTION_ENABLED` 为 true ·
`CASDOOR_ENDPOINT` 非 HTTPS · frontend origins 含通配或非 origin-only ·
`DOWNSTREAM_BASE_URL` 指向本 Backend · `DOWNSTREAM_VERIFY_SSL` 非 true ·
`SERVICE_AUTH_SUBJECT_BINDINGS_JSON` 非法或为空 · `SERVICE_AUTH_AUDIENCE` 缺失

### 3.3 部署脚手架门禁（`k8s-deployment/`）

镜像必须 `repo@sha256:<64hex>` · 输出目录必须为空 · bundle 文件 sha256 须与 `release.json` 一致 ·
Secret env 文件不得有 group/other 权限位 · Secret 键须与 `release_json.secret_keys` 完全匹配 ·
`.conf` 禁未知键、禁 `export` 语法、值须与 `release.json` 完全一致

## 4. 关键机制

### 4.1 浏览器身份：两个表面是两个安全边界

`BrowserSurfaceProfile`（不可变）为每个表面固定：client_id/secret、redirect_uri、
frontend origins、cookie 名、事务 cookie 名、Redis key 前缀、required_scopes。

**关键不对称**：
```python
required_scopes=(f"{self.app_slug}:admin",) if surface == "admin" else ()
```
Admin 强制 `{app}:admin` scope；**Web 不要求任何 scope**。

登录流程：`/api/auth/{surface}/login` → 生成 transaction/state/nonce/PKCE，事务存 Redis
→ 重定向 Casdoor → `/api/auth/{surface}/callback` 原子消费事务 → 校验 state/issuer/audience/nonce
→ 影子用户 upsert（`auth_user`，issuer+subject 唯一）→ 会话写 Redis。

CSRF：非安全方法必须 Origin ∈ frontend_origins 且 `X-CSRF-Token` 与会话值 hmac 相等。

### 4.2 服务身份

`ServiceIdentityVerifier.verify()` 的链条：
验 audience → 取 `sub`/`iss` → **subject 必须命中 `service_auth_subject_bindings` 的精确键**
（不在表中即 `service_subject_unbound`）→ `token_scopes ⊆ allowed_scopes` 且
`required_scopes ⊆ token_scopes`。

### 4.3 API 工厂（`bootstrap/api.py`）

生产禁 `/docs` `/redoc` `/openapi.json` · lifespan 在生产或已配 Casdoor 时
`require_browser_identity()` · request-context 中间件写审计日志并回传
`X-Correlation-ID`/`X-Operation-ID` + 四个安全响应头 · `/api/auth/` 强制 `no-store` ·
TrustedHost + CORS（仅 frontend origins） · 健康检查 5 个别名
（`/health/live` `/health` `/api/health` `/health/ready` `/ready`） ·
`/api/version` 返回 `contractVersion: 1`

### 4.4 Web interaction：默认不可用

```python
async def get_web_interaction_port() -> WebInteractionPort:
    if get_settings().reference_interaction_enabled:
        return ReferenceWebInteractionAdapter()
    return UnavailableWebInteractionAdapter()
```

而生产禁止 `reference_interaction_enabled`。所以**生产环境该契约面必定返回 503**
（`provider_unavailable`）。`ReferenceWebInteractionAdapter` 的类 docstring 自陈是
"Deterministic pair-test adapter; production config rejects its use"。

它的固定 ID 是**硬编码的 v5 格式常量**（`UUID("00000000-0000-5000-8000-000000000001")` 等），
代码里**没有 `uuid5()` 调用**。

## 5. 数据

迁移链 2 个版本，线性：

```
20260726_0001_auth_identity   （down_revision = None）
20260801_0002_outbox_primitives
```

表：`auth_user`（issuer+subject 唯一）、`outbox_message`、`inbox_message`。

## 6. 对外接口

| 接口 | 位置 |
| --- | --- |
| Admin OIDC | `interfaces/http/admin/auth.py` |
| Web OIDC | `interfaces/http/web/auth.py` |
| Admin 诊断（Celery ping） | `interfaces/http/admin/diagnostics.py` |
| Web interaction `/api/web/v1` | `interfaces/http/web/interactions.py`（170 行） |
| 服务身份校验 | `infrastructure/security/service_identity.py` |
| web-interaction 双端向量 | `contracts/web-interaction-v1.consumer-vectors.json` |

`interfaces/http/internal/__init__.py` 只有一行 docstring——**无 router 挂载**。

## 7. 已知未实现

模板**有意留白**的（实例继承后自己填，不是缺陷）：

| 项 | 状态 |
| --- | --- |
| 领域层 | `domain/{models,repositories,services}/` 仅空 `__init__.py` |
| Outbox 消费链路 | Port、DTO、SQL 仓库类齐备，**业务层零调用** |
| web-interaction 运行时 | 默认 `Unavailable` 适配器，是显式的"未接线"信号 |
| `/api/internal/v1` | 只有中间件，无 router |
| Celery 周期任务 | Scheduler 入口在，无 `beat_schedule` |

## 8. 验证

```bash
cd <repo>/tpl-app/tpl-backend/app
uv sync --frozen && uv run ruff check . && uv run pyright && uv run pytest -q
uv run pytest tests/test_kernel_invariants.py -q     # 5 项结构不变量

cd <repo>/tpl-app
python3 -m unittest discover -s k8s-deployment/tests -v
python3 verify_template_release.py
```

复核几条关键断言：
```bash
grep -n "get_web_interaction_port" -A4 tpl-backend/app/app/application/services/web_interaction.py
grep -rn "uuid5" tpl-backend/app/app/            # 应无结果
wc -l tpl-backend/app/app/main.py                # 应为 5
```
