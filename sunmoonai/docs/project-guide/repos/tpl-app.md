# tpl-app（模板仓）

> 取证时点：2026-09-13 后端源码复核；不代表部署升级 ｜ 总览见 [`../overall-architecture.md`](../overall-architecture.md)

## 1. 定位

定义"一个标准 App 长什么样"，并提供实例化所需的骨架、契约与部署脚手架。
**它本身没有业务领域**——`domain/models/`、`domain/repositories/`、`domain/services/`
都只有空的 `__init__.py`，唯一有内容的是 `domain/security/principal.py`。

它也没有 `interfaces/endpoints/`（那是实例放领域路由的地方）。

三个领域 App 从它实例化，同步顺序锁定为 `info → knowledge → investment`。

## 2. 结构

后端公共底座已包含可靠投递、角色探针与权限策略；文件规模不作为架构判据。

| 路径 | 装什么 |
| --- | --- |
| `tpl-backend/app/core/config.py` | **本仓最大单文件**，Pydantic Settings + 约 35 处生产期硬校验。真正的强制在这里 |
| `tpl-backend/app/app/bootstrap/` | 四个运行角色入口：`api.py` / `worker.py` / `scheduler.py` / `migration.py` |
| `tpl-backend/app/app/application/services/` | 身份、Web interaction、可靠投递与只读观测 |
| `tpl-backend/app/app/application/ports/` | `outbox.py`、`web_interaction.py`——Port 定义 |
| `tpl-backend/app/app/infrastructure/security/` | `oidc.py`、`service_identity.py` |
| `tpl-backend/app/app/infrastructure/repositories/outbox.py` | Outbox SQL 实现 |
| `tpl-backend/app/app/interfaces/http/` | `admin/`（auth、diagnostics）+ `web/`（auth、interactions）+ `middleware/` |
| `tpl-backend/db-provisioner/` | 建库建角色 |
| `tpl-backend/db-access-bootstrap/` | 数据库访问自举 |
| `tpl-backend/search-access-bootstrap/` | Elasticsearch 访问自举 |
| `tpl-backend/storage-access-bootstrap/` | 对象存储访问自举 |

| `tpl-backend/app/alembic/versions/` | 3 个版本（见 §5） |
| `tpl-admin-frontend/` `tpl-web-frontend/` | 两个 Next.js 前端 |
| `k8s-deployment/` | `scaffold.py` / `deploy.py` / `deployment_config.py` + 五份 YAML 模板 |
| `contracts/web-interaction-v1.consumer-vectors.json` | 双端测试向量（valid + invalid 两组） |
| `template-release-manifest.json` + `verify_template_release.py` | 模板发布锁与校验 |
| `init.sh` | 克隆转实例的一次性原地转换 |

⚠ **供给脚本有两份，别只看一份**：`k8s/sunmoonai/utils/db-provisioner/` 是平台侧入口；
上面四个供给目录在 Backend 仓内，随模板同步实例。旧入口不能冒充新运行角色策略已落地。

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
| `test_package_version_matches_the_formal_release` | pyproject 与 `uv.lock` **必须**同为 `2.0.0`；`api.py` **不得**硬写 `version="2.0.0"`，须经 `importlib.metadata` |

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

API readiness（2026-09-13 源码）在 2 秒协作式探测预算内检查 Redis ping 与数据库
`alembic_version`；必须恰好一个版本且等于本镜像迁移链的单 head，否则通用 503。
每次查数据库，不缓存 ready、不自动迁移或提权；live 保持无依赖。
这不验证完整表结构/数据，也不覆盖 Worker/Scheduler，见
[`B7b 子项与证据`](../../legacy-backlog/verification-index.md)。部署与业务角色权限尚未验收。

投递观测入口 `python -m app.cli.delivery_metrics [--format prometheus]` 从本 App
账本只读计算 gauge。`delivery_observers.py` 装配实际 delivery policy，实例沿用 handler
注册，Agent 实例用领域租约扩展；未知 topic 仅报聚合数量，无无限标签或敏感 payload。
没有新增表、迁移或自动 GC；异常不输出假零。B7h 补受服务身份和 `delivery:observe`
保护的 `GET /api/internal/v1/delivery/metrics`，每进程一个在途只读采集，失败 503，
不缓存旧值。CLI/HTTP 输出不等于实际接好 Prometheus，也不能证明 Worker/Scheduler
消费正常；后端 `docs/delivery-observation.md`
说明字段、权限/超时和未完成接线，分包证据见
[B7d 只读观测](../../legacy-backlog/verification-index.md)。

B7j 本地源码另从同一账本聚合匹配 consumer 的已提交 Inbox 数和最大记录时间，
由上述 CLI/HTTP 输出，仍是 gauge；不建第二本账。回滚/未提交/重复/错 consumer
不虚增，无回执 hint 不当作消费回执；非有限时间使整个采集失败。
记录时间不是提交时间或心跳，数量会随保留/恢复变化，不能证明每个 Worker 或业务结果
健康。真实共享 prefork 执行链与故障边界见
[B7j 回执进展](../../legacy-backlog/verification-index.md)，不推定当前业务部署已生效。

Worker 消费配置探针 `python -m app.cli.worker_readiness`（B7e 源码，四仓门禁已过，未部署）定向本 POD_NAME，
校验实际队列/交换机/路由/持久性及本镜像应用任务注册；6 秒子进程预算，失败固定错误，
无业务任务/数据库操作。模板未来 bundle 已接该命令；实例历史镜像/release 未重写，
须联合新镜像发布才能启用。它不是消费进展或 Scheduler 心跳，也不作 liveness；
详见 [B7e 证据与边界](../../legacy-backlog/verification-index.md)。

Scheduler bootstrap 已选用继承 PersistentScheduler 的活动观察类（B7i 本地源码，
未部署）。`python -m app.cli.scheduler_activity --schedule <同一文件> --max-age <秒>`
只在同容器/UID/PID namespace 读临时快照：BOOTTIME 年龄、boot/PID 启动标识及
进程状态校验；循环返回和发送调用返回/异常分列，不证明 broker 确认或消费完成。
未接自动重启或 Kubernetes 探针；说明与固定门禁见
[B7i 活动观测](../../legacy-backlog/verification-index.md)。实际监控部署/采集/告警
按所有者要求进入[未来 N4-OPS-01](../../tasks/N4-OPS-01/thread/0001-imp/0001/user-message.md)，尚未实施。

公共日志（2026-09-13 源码）：Postgres 固定关闭 SQL echo、隐藏绑定参数；API 与
Celery Worker/Scheduler 均将 SQLAlchemy engine/pool、httpx/httpcore 限为 WARNING，
应用 DEBUG 不自动打开 wire 日志。应用审计与 Celery 自身日志保留原级别；不是完整脱敏。
实现和验证边界见 [`B7a 证据`](../../legacy-backlog/verification-index.md)，不推定当前部署已生效。

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

迁移链 3 个版本，线性：

```
20260726_0001_auth_identity   （down_revision = None）
20260801_0002_outbox_primitives
20260911_0003_durable_delivery
```

表：`auth_user`（issuer+subject 唯一）、`outbox_message`、`inbox_message`、
`outbox_dead_letter`、`outbox_execution`，另有 `alembic_version`。
API/Worker 的冻结表列策略及 Scheduler 无数据库权限已在隔离环境验证；
生产供给、旧账号撤权及切换仍待处置，见 [数据边界](../topics/data.md)。

## 6. 对外接口

| 接口 | 位置 |
| --- | --- |
| Admin OIDC | `interfaces/http/admin/auth.py` |
| Web OIDC | `interfaces/http/web/auth.py` |
| Admin 诊断（Celery ping） | `interfaces/http/admin/diagnostics.py` |
| Web interaction `/api/web/v1` | `interfaces/http/web/interactions.py` |
| 服务身份校验 | `infrastructure/security/service_identity.py` |
| web-interaction 双端向量 | `contracts/web-interaction-v1.consumer-vectors.json` |

`interfaces/http/internal/delivery_metrics.py` 已挂载只读投递指标，复用现有服务身份
签名/audience/subject/scope 校验；不默认授予任何主体权限，尚未接实际采集器。

## 7. 已知未实现

> **这张表由 `tests/test_dormant_capabilities.py` 守着**：每条休眠声明都有可执行
> 判据，能力一旦接线、或判据锚点被改名，测试即失败。改这张表前先跑那个测试。
> 机制说明见该文件的模块 docstring；它的边界是**保证已声明的条目不变陈旧**，
> 发现不了新出现的休眠能力——新增时手工加一条。


模板**有意留白**的（实例继承后自己填，不是缺陷）：

| 项 | 状态 |
| --- | --- |
| 领域层 | `domain/{models,repositories,services}/` 仅空 `__init__.py` |
| web-interaction 运行时 | 默认 `Unavailable` 适配器，是显式的"未接线"信号 |

公共可靠投递已接线：应用服务同事务记录命令，Worker 使用持久租约与 Inbox；Scheduler 每 5 秒发出 pump 提示，数据库投递与对账由 Worker 执行，提供死信与显式重放。模板不注册领域任务，实例通过 `delivery_handlers.py` 接入。该能力的源码验证不代表既有正式镜像已更新。

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

---

**改模板、同步实例前**，先读 [`../../dev-agent/composition/constraints.md`](../../dev-agent/rules/constraints.md)「发布」——本页只写现状。
