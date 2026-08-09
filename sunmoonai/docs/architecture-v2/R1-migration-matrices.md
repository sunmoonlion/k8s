# Architecture v2 R1 迁移矩阵

状态：`ACCEPTED`

日期：2026-08-01

适用分支：`architecture-v2`

源码回滚点：`pre-architecture-v2-20260801`

本文把 ADR-0007～0013 转换为逐仓、逐接口、逐数据库、逐运行角色的施工约束。R2～R7
必须按本文执行；若实现事实要求改变本文，必须先新增或修订 ADR，不能在代码中暗改架构。

## 1. 盘点范围与结论

本次核对了：

- tpl-app、Info、Knowledge、Research 的 8 个现有 FastAPI Backend 源码；
- 4 条 Admin Alembic 链和 4 条 Web Alembic 链；
- 8 个 Next.js 前端的真实 API 调用、SSR session introspection 与配对脚本；
- 四个父仓 `.gitmodules`、21 个施工仓分支和 3 个模板参考仓；
- KIND 中 API、Celery Worker、Node Worker、CronJob、镜像、命令和 ServiceAccount；
- 三个 Admin 数据库及两个实际存在的 Web 数据库的表、迁移 head 和行数；
- 浏览器会话、CSRF、服务身份、Knowledge ingestion/retrieval 与 Research pilot Runtime 路径。

结论：

1. 现有 Admin Backend 是领域代码与数据的唯一有效主线；
2. Web Backend 不是纯空壳，其 OIDC Web surface、interaction contract、SSE、citation 与
   Research Runtime adapter 必须审计迁入；
3. Info/Research Web 数据库存在但没有表，Knowledge Web 数据库未创建，因此不存在需要搬迁的
   Web 业务数据；
4. Web Alembic 都从独立 root 创建重复 `auth_user`，不得并入规范 migration chain；
5. 统一 Backend 后，Research Web adapter 不再通过服务令牌 HTTP 调用同一 Research Backend，
   而由 Web interface 直接调用共享 application use case；
6. 两个 Next.js 前端仍是两个安全表面，必须使用独立 OIDC client/profile、session cookie 和
   scope，不能因 Backend 合并而混成一个浏览器身份边界。

## 2. 仓库迁移矩阵

### 2.1 规范 Backend 仓

| 领域 | 当前历史主线 | 目标仓 | 旧 Web 仓 | 迁移结果 |
| --- | --- | --- | --- | --- |
| Template | `tpl-admin-backend` | `tpl-backend` | `tpl-web-backend` | Admin 历史主线原地改名；迁入通用 Web/BFF/interaction 能力 |
| Info | `info-admin-backend` | `info-backend` | `info-web-backend` | 保留 Info 领域代码；迁入 Web surface 通用能力 |
| Knowledge | `knowledge-admin-backend` | `knowledge-backend` | `knowledge-web-backend` | 保留 ingestion/retrieval/RAGFlow；迁入 Web surface 通用能力 |
| Research | `research-admin-backend` | `research-backend` | `research-web-backend` | 保留 Agent Runtime；迁入 Web contract，并消除 Backend 对自身 HTTP 调用 |

目标仓名在 2026-08-01 的 Gitee 只读探测结果均为未占用：`tpl-backend`、`info-backend`、
`knowledge-backend`、`research-backend`。

仓库操作采用“远端原地改名”，不新建空仓复制代码。每次改名必须按以下事务式顺序执行：

1. 验证源仓 `architecture-v2`、master、源码标签和 tree；
2. 在 Gitee 将 `*-admin-backend` 原地改为 `*-backend`；
3. 验证旧 URL redirect 与新 URL `ls-remote` 指向相同 commit；
4. 更新本地 origin、父仓 `.gitmodules`、gitlink、构建配置、Harbor/K8s 生成器和文档；
5. clean clone 父仓并运行 `submodule update --init --recursive`；
6. 验证 master、`architecture-v2`、`pre-architecture-v2-20260801` 均可解析；
7. 失败则先恢复父仓 gitlink/URL，再回退远端仓名。

### 2.2 旧 Web Backend 生命周期

旧 `*-web-backend` 在 R2/R5 期间进入 `compatibility-only`：

- 只允许安全、数据保护和回滚修复；
- 禁止新增产品能力、表或 migration；
- 每项迁出能力必须有来源文件、目标文件和测试映射；
- `2.0.0` 观察窗结束且引用扫描为零后归档为只读；
- 归档不等于删除 Git 历史或旧镜像，后两者受 ADR-0013 的回滚和 GC 门禁控制。

R4 实例三组件门禁通过后，旧 Web Backend 应从实例父仓的活跃 `.gitmodules`
解除，避免继续被误认为可开发源码。这里的“R5 compatibility-only”保留面是旧独立
仓库/冻结标签、锁定镜像和 K8s v1 回滚声明；不要求在实例父仓继续挂载第四个子模块。

### 2.3 父仓和参考实现

模板默认实例化链只包含：

```text
tpl-backend
tpl-admin-frontend
tpl-web-frontend
```

以下仓继续保留在 tpl-app 作为显式参考，不进入默认实例化和发布闭包：

- `tpl-admin-frontend-react`：React Router SPA 参考；
- `tpl-admin-frontend-vue`：Vue Admin 参考；
- `tpl-web-backend-nest`：NestJS Backend 参考。

参考仓必须能独立验证，但不得把它们的 Worker、数据库或 K8s 组件实例化到新 App。

现有 `celeryworker-*-admin-backend`、`nodebullworker-*-web-backend` 不是独立源码所有者。
R3 已把新架构运行角色收敛为规范 Backend 的 runtime-role manifests；R4 通过后，从实例
源码父仓删除这些重复脚手架。旧目录仅在 `k8s` 仓库作为 v1 运行基线/回滚声明保留到
R7，不再生成第二套 Backend。

## 3. 源码能力迁移矩阵

### 3.1 规范主线直接保留

| 能力 | 来源 | 目标 |
| --- | --- | --- |
| 领域模型、服务、Repository、迁移 | 各 `*-admin-backend` | 规范 `*-backend` 原位保留 |
| Admin OIDC、CSRF、scope、审计 | 各 `*-admin-backend` | `interfaces/http/admin` 与共享 security/application |
| PostgreSQL、Redis、Celery、错误与日志 | Admin 主线 + 模板核对 | 共享 infrastructure/bootstrap |
| Info collectors/artifact/outbox | `info-admin-backend` | `info-backend` |
| Knowledge ingestion/retrieval/RAGFlow | `knowledge-admin-backend` | `knowledge-backend` |
| Research Agent/graph/checkpoint/memory/tools | `research-admin-backend` | `research-backend` |

### 3.2 从 Web Backend 审计迁入

| 能力 | 来源路径类别 | 处理 |
| --- | --- | --- |
| Web OIDC signup/continue/callback | `interfaces/endpoints/auth_routes.py` | 与 Admin 共用 AuthService，但保留独立 Web auth profile |
| Web interaction schemas/port | `interfaces/schemas/interaction.py`、`application/ports/web_interaction.py` | 作为模板 Web surface contract 迁入 |
| Web SSE、action、citation | `interfaces/endpoints/interaction_routes.py` | 重挂 `/api/web/v1`，保留 cursor、no-buffer、redirect 校验 |
| Reference adapter | `application/services/web_interaction.py` | 仅配对测试启用；生产 fail-closed |
| Downstream service client | `infrastructure/external/downstream_service.py` | 只保留真正跨 App 调用能力；禁止用于同 Backend 自调用 |
| Research Runtime adapter | `research-web-backend/.../runtime_interaction.py` | 拆除 HTTP self-call；映射为 Research application facade |
| Web contract tests | `test_interaction_*`、`test_runtime_interaction.py` | 迁成统一 Backend 的 consumer/contract tests |

不得直接复制两边同名的 auth、config、logging、postgres、redis、base model 或 error 文件。
必须以模板规范实现为基线逐项合并差异，避免产生 `admin_auth_service`/`web_auth_service` 两套核心。

## 4. 目标代码结构与依赖规则

规范 Backend 采用：

```text
app/
├── domain/
├── application/
│   ├── commands/
│   ├── queries/
│   ├── services/
│   ├── ports/
│   ├── policies/
│   └── dto/
├── interfaces/
│   ├── http/
│   │   ├── admin/
│   │   ├── web/
│   │   ├── internal/
│   │   ├── auth/
│   │   └── middleware/
│   ├── tasks/
│   └── cli/
├── infrastructure/
└── bootstrap/
    ├── api.py
    ├── worker.py
    ├── scheduler.py
    └── migration.py
```

依赖只允许：`interfaces -> application -> domain`，`infrastructure` 实现 application ports，
`bootstrap` 负责装配。Domain/Application 禁止导入 FastAPI、Celery、SQLAlchemy model、Redis、
Casdoor SDK 或具体 HTTP client。

## 5. API 路径迁移矩阵

### 5.1 公共约定

| 当前 | 目标 | 兼容策略 |
| --- | --- | --- |
| `/health` | `/health/live` | R2～R7 保留 alias |
| `/ready` | `/health/ready` | R2～R7 保留 alias |
| `/api/health` | `/health/ready` | 前端配对脚本在 R2 更新；旧 alias 到 R7 |
| `/api/auth/*` | `/api/auth/{admin|web}/*` | R2 更新两前端；旧路径只在显式 surface 映射下短期兼容 |
| `/api/internal/tasks/ping` | `/api/admin/v1/diagnostics/tasks/ping` | 仅 Admin scope；不冒充服务 API |

兼容 alias 必须调用同一个 handler/use case，并带 deprecation 监控；禁止复制实现。

### 5.2 浏览器身份表面

```text
/api/auth/admin/login
/api/auth/admin/callback
/api/auth/admin/logout
/api/auth/admin/me

/api/auth/web/login
/api/auth/web/signup
/api/auth/web/callback
/api/auth/web/continue
/api/auth/web/logout
/api/auth/web/me
```

Admin 与 Web 分别使用独立 Casdoor application/client、redirect URI、state/PKCE namespace、
Redis session namespace 和 `__Host-` session cookie 名。二者共用 `auth_user` 本地主体绑定表，
但 session 中必须冻结 `app`、`surface`、scope、policy version 和认证时间。

Backend 是最终授权点。Next.js 仅执行 SSR session introspection、同源请求和 UI 路由，不保存
provider access token，不拥有领域数据。两个前端的 server-only 变量统一命名为
`BACKEND_INTERNAL_URL`，不再使用 `ADMIN_BACKEND_INTERNAL_URL`/`WEB_BACKEND_INTERNAL_URL`。

### 5.3 Admin API

| App | 当前路由族 | 目标路由族 |
| --- | --- | --- |
| Info | `/api/admin/*`、`/api/documents/*`、`/api/artifacts/*` | `/api/admin/v1/sources`、`collectors`、`crawl-jobs`、`documents`、`artifacts`、`distributions`、`search-index`、`uploads` |
| Knowledge | `/api/knowledge/*` | `/api/admin/v1/ingestions`、`ragflow/config-check` |
| Research | `/api/agent/*` | `/api/admin/v1/agent/sessions`、`runs`、`events` |

Admin 写操作统一要求 Admin scope、CSRF/Origin、资源授权、operation ID 和审计原因；不能仅靠菜单
隐藏或前端角色判断。

### 5.4 Web API

模板通用 contract 挂载于：

```text
GET  /api/web/v1/runs/{run_id}
GET  /api/web/v1/runs/{run_id}/events
POST /api/web/v1/runs/{run_id}/actions
GET  /api/web/v1/citations/{evidence_id}/source
```

Research 领域扩展：

```text
POST /api/web/v1/runs
POST /api/web/v1/runs/{run_id}/cancel
```

Info/Knowledge 在真实 Web 产品用例出现前使用 fail-closed adapter（503），不得把 reference fixture
当作生产成功。SSE 保留先订阅后回放、cursor 冲突校验、去重、heartbeat、`X-Accel-Buffering: no`
和资源所有权验证。

### 5.5 Internal API

| Provider | 当前 | 目标 | 调用身份 |
| --- | --- | --- | --- |
| Knowledge ingestion | `/api/internal/v1/knowledge/ingestions` | `/api/internal/v1/ingestions` | Info Worker workload identity + `knowledge:ingest` |
| Knowledge retrieval | `/api/internal/v1/knowledge/retrievals` | `/api/internal/v1/retrievals` | Research Agent Worker identity + `knowledge:retrieve` |
| Research pilot runs/events/citations | `/api/internal/v1/research/*` | R2 模板配对时保留 adapter；统一 Backend 后停止 Web Backend 消费 | 兼容期 Web Backend identity |

Internal endpoint 按 provider capability 命名。JWT 必须验证签名、issuer、audience、expiry、subject
binding 和 scope/policy mapping；浏览器 cookie 不得访问 Internal API。Research 合并完成后，其 Web
interface 直接调用 application port，原 pilot Internal API 只在存在真实跨进程/跨服务消费者时保留。

## 6. 数据库迁移矩阵

### 6.1 目标原则

- 现有 Admin 数据库是规范数据主线；物理名称无需为美观冒险改名；
- 逻辑所有者分别为 Info、Knowledge、Research Backend；
- 最终每个 App 一个应用写角色、一个 migration 角色、一条 Alembic head；
- Web migration root 全部废弃，不与 Admin migration 文件拼接；
- Web 数据库在回滚窗后删除，删除前必须再次证明没有表、没有连接和没有消费者；
- R5 才执行备份、恢复演练、凭据切换和 contract，R1 只冻结方案与当前基线。

### 6.2 当前实测基线

| App | 规范物理 DB / role | 当前 head | 当前表和精确行数 | 旧 Web DB |
| --- | --- | --- | --- | --- |
| Info | `info_admin` / `info_admin_user` | `20260714_0004` | `auth_user=1`、`crawl_job=25`、`delivery_outbox_message=16`、`distribution_record=22`、`extracted_content=30`、`info_collector=1`、`info_document=8`、`info_document_version=16`、`info_source=7`、`raw_artifact=56` | `info_web` 存在，0 张表 |
| Knowledge | `knowledge_admin` / `knowledge_admin_user` | `20260715_0003` | `auth_user=1`、`knowledge_document=1`、`knowledge_document_version=1`、`knowledge_ingestion_job=38` | `knowledge_web` 不存在 |
| Research | `research_admin` / `research_admin_user` | `20260712_0002` | `agent_runs=28`、`agent_sessions=29`、`auth_user=2`、`checkpoint_blobs=40`、`checkpoint_migrations=10`、`checkpoint_writes=363`、`checkpoints=160`、`session_events=278`、`tool_side_effects=21` | `research_web` 存在，0 张表 |

Research 源码已有 `20260729_0003`（pilot request/control），但当前数据库只到 `20260712_0002`。
它必须作为 R5 的显式待执行 migration，不能在 API 启动时自动补跑。

### 6.3 Migration chain 决策

| App | 保留链 | 丢弃的重复链 | v2 首个 migration |
| --- | --- | --- | --- |
| Template | Admin `20260726_0001` | Web 同名 root | 在 Admin head 后新增 v2 revision |
| Info | `0001 -> 0002 -> 0003 -> 0004` | Web `20260726_0001` | `0004` 之后 |
| Knowledge | `0001 -> 0002 -> 0003` | Web `20260726_0001` | `0003` 之后 |
| Research | `0001 -> 0002 -> 0003` | Web `20260726_0001` | `0003` 之后；部署前先受控补齐 `0003` |

Web 与 Admin 的 SQLAlchemy `auth_user` model 当前等价；规范表只保留一份，通过
`(issuer, subject)` 唯一约束共享主体，surface/session 差异不复制用户主档。

### 6.4 R5 数据操作顺序

每个 App 串行执行：

1. 停止新 migration，采集连接、表/约束/索引、exact count 和业务不变量；
2. `pg_dump --format=custom` 备份规范 DB，并导出 roles/grants 的无密钥定义；
3. 在隔离恢复库实际 restore，运行 schema/count/hash/抽样校验；
4. 创建规范 Backend runtime/migration role；保留现有 Admin role 作为限时回滚；
5. 对规范 DB 运行唯一 migration Job，验证单 head；
6. 两前端和所有 runtime role 切到同一 DB；阻断旧 Web 写角色；
7. 校验 exact count、外键/唯一约束、领域不变量和新旧读取结果；
8. 观察窗内保留旧 DB/role/Secret，只允许回滚；
9. 反向切换演练与重新前滚通过后，才进入 contract；
10. 引用/连接为零后删除空 Web DB 和旧角色，更新备份保留清单。

## 7. 运行角色与容量矩阵

### 7.1 统一启动入口

同一 Backend release 默认提供：

| 角色 | 入口 | 数据权限 | 网络/身份 |
| --- | --- | --- | --- |
| API | `app.bootstrap.api` | 应用读写；禁止 DDL | 浏览器入口 + 必要 Internal Service |
| Worker | `app.bootstrap.worker` | 应用读写；禁止 DDL | 按 App workload identity 调外部能力 |
| Scheduler/Scanner | `app.bootstrap.scheduler` 或显式 CLI | 仅所需表读写 | 默认无浏览器入口 |
| Migration Job | `alembic upgrade head` | DDL migration role | 无 Service/Ingress，运行即结束 |
| CLI/Reconciler | `python -m app.interfaces.cli.<command>` | 最小任务权限 | 人工/Job，带 operation ID |
| Agent Worker | Research 专用 worker 入口 | Research run/checkpoint 读写 | Knowledge retrieval、工具与沙箱身份 |

同一 source commit 和候选 digest 运行不同命令。只有浏览器/GPU/沙箱等依赖导致可证明的攻击面
或体积差异时，才允许从同一 release manifest 派生角色镜像。

### 7.2 逐 App 初始角色

| App | API | 通用 Worker | Scheduler/Reconciler | 专用角色 |
| --- | --- | --- | --- | --- |
| Info | `info-backend-api` | crawl/search/distribution | Outbox scanner/reconciler | 暂无；浏览器采集满足触发条件后再拆 |
| Knowledge | `knowledge-backend-api` | ingestion/index | ingestion/RAGFlow reconcile | 暂无 |
| Research | `research-backend-api` | 短异步任务 | stale run/lease reconcile | `research-agent-worker` |

初始每 App 一个通用 Celery queue；Research Agent queue 独立。拆队列必须以排队时延、p95/p99
运行时、资源、失败率、取消时延、网络/权限边界证据为依据。

### 7.3 当前运行态与迁移

| 当前组件 | 目标 |
| --- | --- |
| `*-admin-backend` Deployment | `*-backend-api`，统一镜像 |
| `celeryworker-*-admin-backend` | `*-backend-worker`，同一镜像不同 command |
| `nodebullworker-*-web-backend` | 兼容期保留；Web Backend 归档后删除，不迁成第二 Worker |
| `info-delivery-outbox-scanner` CronJob | `info-backend` 同镜像 scanner/CLI |
| Research 当前通用 Celery worker | 拆成通用 worker + agent worker，队列/lease/取消独立验证 |
| 两个 Backend migration gate | 每 App 一个规范 migration Job |

ServiceAccount 绑定按运行角色，不按代码仓数量。Info Worker 持有 Knowledge ingestion 调用身份；
Research Agent Worker 持有 Knowledge retrieval 身份；API Pod 不继承这些调用方凭据。

## 8. 模板完整继承契约

### 8.1 Backend 共同能力清单

模板 release 必须包含并验收：

- 目标分层、依赖方向和 bootstrap 入口；
- Admin/Web 双 OIDC profile、PKCE、session、CSRF/Origin、scope/ownership policy；
- service identity verifier/client、audience/subject/scope fail-closed；
- `auth_user`、PostgreSQL、Redis、Alembic、事务边界；
- operation ID、结构化日志、审计上下文、RFC 7807 错误；
- Celery producer/worker、幂等任务与通用 transactional outbox primitives；
- live/ready、关闭、超时、重试、连接池和配置生产校验；
- Web interaction port、SSE/citation contract 与生产 fail-closed adapter；
- 单元、契约、双前端配对、KIND、严格 TLS、真实 Casdoor 和回滚门禁；
- Docker、SBOM/扫描、不可变 digest、K8s runtime roles 与 release manifest。

S3、搜索、浏览器采集、RAGFlow、LangGraph 等通过可选 port/adapter 和领域 extension point 提供，
不强迫每个实例启用不需要的重依赖。

### 8.2 两个 Next.js 前端共同能力

Admin/Web 均继承：Next.js SSR、React、TypeScript、环境 schema、i18n、主题、可访问性、错误边界、
loading/empty state、server-only session introspection、同源 API client、CSP/security headers、
observability hooks、测试、Docker standalone 和 K8s 探针。

Admin 另外保留 Ant Design 管理能力、权限菜单、表格/表单、批量操作、审计输入和管理布局；Web
保留面向用户的 Tailwind/shadcn 风格、SEO/metadata、流式交互、引用展示和产品布局。统一技术栈
不等于统一产品 UI。

### 8.3 实例同步与漂移门禁

R2 完成后生成模板 release manifest，至少锁定：

```text
schema_version
template_release
source_commit/tree
component_commits
image_repository/digest
contract_versions
common_file_manifest
optional_capabilities
test_evidence
```

R4 严格按 Info -> Knowledge -> Research 串行：

1. 从相同模板 release 同步全部共同文件；
2. 领域扩展只进入预定义 extension points；
3. 输出逐文件差异，分类为 `domain-extension`、`deployment-config`、
   `temporary-compatibility`、`prohibited-drift`；
4. `prohibited-drift` 必须为零，临时兼容必须有 owner/截止阶段；
5. Admin/Backend、Web/Backend、双前端并行、identity、database 和 rollback 全部通过；
6. 一个实例失败即停止，不得跳到下一实例或继续业务开发。

## 9. 当前运行基线缺陷

2026-08-01 盘点时，`info-admin-backend` 与 `knowledge-admin-backend` 为
`CrashLoopBackOff`，共同原因是 Redis ACL `invalid username-password pair or user is disabled`。
对应 Celery Worker 仍在运行，数据库可读；这证明 Deployment 期望状态不能替代 Pod/依赖健康门禁。

该缺陷属于重构前环境配置漂移，不是 Architecture v2 代码回归，但必须在 R2 施工前恢复旧架构
回滚健康，并补充：

- Redis Secret/ACL 一致性检查；
- API 与 Worker 对 Redis 的共同 startup/ready 验证；
- 凭据轮换后 rollout 与负向测试；
- 禁止在 readiness 失败时把 Deployment 镜像清单宣称为健康基线。

## 10. R1 退出判定

R1 的架构选择已无悬空项：规范仓、能力来源、API namespace、双浏览器身份、服务身份、数据库
主线、migration chain、运行角色、模板继承和版本/回滚策略均已确定。

R2 开始前仍需完成的不是架构决策，而是执行性前置条件：

1. 恢复 Info/Knowledge Redis ACL 与旧回滚拓扑健康；
2. 对模板 Admin/Web Backend 能力清单生成机器可校验 manifest；
3. 执行 `tpl-admin-backend -> tpl-backend` 原地仓库改名事务；
4. 在规范模板仓开始代码合并。
