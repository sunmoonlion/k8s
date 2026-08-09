# SunMoonAI App Platform 总体架构

状态：`Architecture v2 目标架构 / 迁移实施中`

最后更新：2026-08-09

适用分支：`architecture-v2`

## 1. 文档定位

本文定义 App Platform 的长期边界、标准 App 形态、运行时拓扑和跨 App 协作规则。它描述的
Architecture v2 已在 `tpl-app` 以及 Info、Knowledge、Investment 的新源码底座中实现；旧版
Kubernetes 目录和运行资源在完成数据迁移、切流与回滚观察窗前仍可能保留。

实施阶段、门禁和回滚点以
[Architecture v2 重构执行基线](../../docs/app-platform-architecture-v2-refactor-plan.md)为准。
若“目标架构”和“当前集群”不一致，必须明确标注迁移状态，不能把旧资源解释为长期设计。

## 2. 核心决策

Architecture v2 固定以下边界：

1. Info、Knowledge、Investment 是相互独立的领域 App，不合并为一个巨型 App。
2. 每个领域 App 只有一个规范 FastAPI Backend、一个逻辑业务数据库和一条 Alembic 迁移链。
3. 每个 App 保留 Admin 与 Web 两个独立 Next.js 前端；二者共同使用该 App 的统一 Backend。
4. Admin、Web、Internal 是同一 Backend 的接口分面，不是三套业务实现或三套数据库。
5. API、Worker、Scheduler、Migration 是同一 Backend 源码和镜像的运行角色，不是独立仓库。
6. App 之间只能通过受版本控制的 API、事件和 Artifact 契约协作，禁止跨 App 直接读写数据库。
7. 共性能力先在 `tpl-app` 完成并通过门禁，再完整同步到实例 App；领域代码只使用显式扩展点。

这里的“统一数据库”是指：**一个 App 内的 Admin 与 Web 统一到该 App Backend 所拥有的一个
逻辑数据库**。它不表示 Info、Knowledge、Investment 共用一个业务数据库。

## 3. App Platform 领域地图

### 3.1 当前领域 App

| App | 定位 | 权威数据 | 当前规范源码仓 |
| --- | --- | --- | --- |
| `auth-app` | 身份提供与平台认证基础 | 用户、组织、应用、服务身份和授权关系 | 位于 App Platform，核心 IdP 为 Casdoor |
| `info-app` | 来源发现、采集、版本化、Artifact 和可靠分发 | 来源、原始内容、文档版本、Artifact、血缘和投递状态 | `info-backend` + 两个 Next.js 前端 |
| `knowledge-app` | 摄取、解析、索引、检索和知识引擎适配 | 摄取任务、知识对象、索引绑定、检索与引用元数据 | `knowledge-backend` + 两个 Next.js 前端 |
| `investment-app` | 投资研究、Agent Runtime、证据组装及未来投资领域能力 | 投资研究会话、运行、证据、记忆及投资领域事实 | `investment-backend` + 两个 Next.js 前端 |

`auth-app` 是平台身份子系统，目前不强制套用普通领域 App 的三仓模板；它向各 App 提供 OIDC
能力，但不替代各 Backend 的资源级授权。

### 3.2 Research 名称与历史边界

必须区分两个完全不同的概念：

- **旧 `research-app`**：此前承载投资研究和 Agent 能力，已经由 `investment-app` 取代。
  旧源码身份不再代表当前活动 App；迁移期仍可在文档、领域类型或 Kubernetes 回滚目录中看到
  `research` 名称，这些是历史兼容或 Investment 内部的“研究”业务模块。
- **未来 `research-app`**：将来可能从完成验收的 Architecture v2 模板创建，用于通用、跨领域
  研究。它必须是新的有界上下文，使用新的仓库、身份、数据库、对象空间、消息资源和契约；
  不得复用旧 `research-app` 的身份或把 Investment 数据自动归属给它。

因此，当前拓扑中的“研究能力”默认属于 `investment-app`；只有新的 Research 领域定义、数据
所有权和 ADR 获得批准后，未来 `research-app` 才能进入当前 App 清单。

### 3.3 未来 App

未来的 `research-app`、`tools-app` 或其他领域 App，应从当时最新、已验收的 `tpl-app` 版本
实例化。删除的旧 Tools/Research 结构不是新 App 的模板或恢复源。

## 4. 一个领域 App 的标准拓扑

### 4.1 源码仓结构

```text
<app>-app/
├── <app>-backend
├── <app>-admin-frontend
└── <app>-web-frontend
```

- `<app>-backend`：Python、FastAPI、领域模型、应用用例、外部适配、异步任务和迁移。
- `<app>-admin-frontend`：Next.js、React、TypeScript、Ant Design，面向运营和管理人员。
- `<app>-web-frontend`：Next.js、React、TypeScript，面向最终用户和产品交互。

旧的独立 Admin Backend、Web Backend、Celery Worker 仓和 Node Bull Worker 仓不属于 v2
规范拓扑。`tpl-web-backend-nest`、`tpl-admin-frontend-react`、`tpl-admin-frontend-vue` 只可作为
参考实现，不进入默认生成链。

### 4.2 请求拓扑

```text
                            ┌─────────────────────────────┐
Browser ── HTTPS ─────────▶│ Traefik / strict TLS        │
                            └──────────────┬──────────────┘
                      Admin host          │          Web host
                 ┌────────────────────────┴────────────────────────┐
                 │                                                 │
          ┌──────▼────────────┐                            ┌───────▼───────────┐
          │ Admin Next.js SSR │                            │ Web Next.js SSR   │
          └──────┬────────────┘                            └───────┬───────────┘
                 │ BACKEND_INTERNAL_URL                            │
                 └──────────────────────┬───────────────────────────┘
                                        │
Browser same-origin /api ── Traefik ────┤
                                        ▼
                              ┌──────────────────────┐
                              │ Unified FastAPI API  │
                              │ Admin/Web/Internal   │
                              └───────┬──────────────┘
                                      │
                ┌─────────────────────┼─────────────────────┐
                ▼                     ▼                     ▼
       PostgreSQL logical DB       Redis/session       RabbitMQ/outbox
```

两个前端不是静态文件壳，而是各自独立的 Next.js standalone/SSR 工作负载：

- SSR 和 Server Component 使用 server-only `BACKEND_INTERNAL_URL` 访问同一个 Backend Service；
- 浏览器只访问本站点同源 `/api`，Traefik 以高优先级直接转发到同一 Backend；
- 浏览器不获得内部 Backend 地址、Casdoor client secret、服务令牌或数据库凭据；
- Next.js 可以承担页面渲染、同源交互和服务端会话读取，但不是领域事实或授权的最终所有者。

### 4.3 多前端为何仍然分开

统一技术栈不等于合并产品表面。Admin 与 Web 仍分别拥有：

- 独立域名、Deployment、Service、IngressRoute、镜像和扩缩容策略；
- 独立 Casdoor OIDC client、redirect URI、audience、cookie 名称和 session namespace；
- 独立菜单、页面信息架构、组件能力和发布节奏；
- 独立 `/api/admin/v1` 与 `/api/web/v1` 授权面。

二者共享的是工程底座、领域 Backend 和本 App 的业务事实，而不是共享浏览器登录态或扩大权限。
即使同一用户同时访问两端，Backend 仍必须根据请求表面、主体、scope、角色和资源所有权重新
授权。

## 5. 统一 Backend

### 5.1 分层

规范 Backend 采用以下依赖方向：

```text
interfaces -> application -> domain
     |              ^
     v              |
infrastructure -----+
bootstrap 负责装配，不承载领域规则
```

推荐目录：

```text
backend/app/app/
├── domain/
├── application/
├── interfaces/
│   ├── http/admin/
│   ├── http/web/
│   ├── http/internal/
│   ├── tasks/
│   └── cli/
├── infrastructure/
└── bootstrap/
    ├── api.py
    ├── worker.py
    ├── scheduler.py
    └── migration.py
```

### 5.2 接口分面

默认路径：

```text
/api/admin/v1/...      管理端 API
/api/web/v1/...        用户端 API
/api/internal/v1/...   服务到服务 API
/api/auth/admin/...    Admin OIDC 生命周期
/api/auth/web/...      Web OIDC 生命周期
/health/live
/health/ready
```

Admin、Web、Internal 只在接口、DTO、策略和身份边界上分面。能够复用的应用用例只实现一次；
只有业务语义真正不同才拆用例。Internal API 按提供方能力命名，不能按调用方 App 名称复制一套
接口。

### 5.3 统一不等于无边界

一个 Backend 代码库同时服务多个入口，但仍需保持：

- 浏览器身份和工作负载身份分离；
- Admin、Web 的 audience、scope、CSRF/Origin 策略分离；
- Internal API 使用独立服务凭据和最小权限；
- application 不依赖 FastAPI、Celery、数据库客户端等外部实现；
- 外部模型、RAGFlow、对象存储和第三方 API 通过 Port/Adapter 接入。

## 6. 一个 Backend 的多个运行角色

同一 Backend commit 构建一个不可变镜像，再以不同命令和权限运行：

| 角色 | 主要职责 | Kubernetes 形态 | 典型扩缩容信号 |
| --- | --- | --- | --- |
| API | HTTP、认证、命令受理、查询、SSE | Deployment + Service | 请求率、延迟、CPU |
| Worker | Celery 异步任务、Outbox 投递、外部调用 | Deployment | 队列深度、任务延迟、CPU/内存 |
| Scheduler | 周期扫描、补偿与对账触发 | 单副本 Deployment | 调度健康、漏扫数 |
| Migration | 单一 Alembic head 升级 | 一次性 Job | 成功后删除 |

角色共享领域代码和数据所有权，但不共享进程、ServiceAccount 或全部凭据。每个角色应具有独立
命令、资源限额、网络策略和最小数据库/消息权限。任务只有在资源类型、时长、故障隔离、权限或
扩缩容指标显著不同且有证据时，才进一步拆专用 Worker/Queue。

Investment 的长时 Agent 执行将来可以成为专用 Worker 角色，但仍属于 `investment-backend`
及其数据所有权，不应重新建立独立 Agent Backend。

## 7. 统一数据库与数据所有权

### 7.1 App 内统一

每个领域 App 最终只有：

- 一个 PostgreSQL 逻辑数据库；
- 一个数据库所有者和按角色区分的运行凭据；
- 一套 canonical ORM/domain model；
- 一条线性的 Alembic migration history；
- 一套备份、恢复、审计和数据保留策略。

Admin 与 Web 看到的是同一组领域事实，不得为两个前端各建主库、复制主表或双写。Redis、搜索
索引、向量、RAGFlow 数据和缓存均不能替代 PostgreSQL 中的权威业务记录。

### 7.2 App 间隔离

Info、Knowledge、Investment 可以共用 Data Platform 提供的物理 PostgreSQL 集群，但必须使用
独立逻辑数据库、角色、Secret、备份与访问策略。任何 App 都不能直接访问另一 App 的表。

跨 App 只传递稳定 ID、版本、哈希和必要快照。例如：

```text
Info Artifact/Outbox
    -> Knowledge Ingestion/Index/Retrieval
        -> Investment evidence/citation/agent run
```

物理资源共享是运维决策，领域数据所有权不会因此合并。

## 8. 跨 App 集成

跨 App 使用三类公开契约：

1. 同步 API：用户等待的查询、校验和短命令；必须有超时、稳定错误码和服务身份。
2. 异步事件/任务：本地事务 + Transactional Outbox，消费者使用 Inbox/幂等记录，并提供对账。
3. Artifact：对象引用、内容哈希、版本和受控读取授权；大文件不放入消息体。

主要链路：

- Info 拥有原始来源、内容版本和 Artifact，并可靠通知下游；
- Knowledge 消费 Artifact，拥有摄取、索引绑定和检索结果；
- Investment 通过 Knowledge 的检索契约取得证据，通过稳定引用保存可追溯关系；
- 各 App 自己记录调用、审计和失败补偿，不共享事务或数据库连接。

## 9. 身份与安全

- Casdoor 提供 OIDC；浏览器采用 Authorization Code + PKCE。
- Admin/Web 分别注册 client 和回调地址，cookie 使用 `Secure`、`HttpOnly`、适当 `SameSite`。
- Backend 是最终授权点；Next.js 路由保护不能替代 Backend 的资源级授权。
- 服务调用使用独立 workload identity/client credential，不复用用户或管理员 Token。
- 默认拒绝 NetworkPolicy；只开放 Traefik 到前端/API、前端到本 App API、声明的数据/消息依赖、
  Casdoor backchannel 和经授权的 Internal caller。
- API、Worker、Scheduler、Migration 使用独立 ServiceAccount 和最小 Secret key 集；不自动挂载
  Kubernetes ServiceAccount Token。
- 容器非 root、只读根文件系统、drop capabilities，正式部署按不可变镜像 digest 固定。

## 10. 模板治理

`tpl-app` 是共同底座的唯一来源：

```text
tpl-app/
├── tpl-backend
├── tpl-admin-frontend
├── tpl-web-frontend
└── k8s-scaffold-v2
```

模板负责统一认证、安全响应头、错误模型、日志、健康检查、Outbox/Inbox、运行角色、构建、镜像、
严格 TLS、NetworkPolicy 和配对门禁。实例 App 继承全部适用能力，不得只复制局部文件或在三个
实例中分别修同一个底座问题。

变更顺序固定为：

```text
模板设计与实现 -> 模板配对/集成/KIND 门禁 -> 冻结 release manifest
-> Info -> Knowledge -> Investment 串行同步 -> 每个实例独立验收
```

未来新 `research-app` 或 `tools-app` 也必须从已冻结 release 创建，不能从旧目录复制。

## 11. Kubernetes 目标形态

每个普通领域 App 的规范 release 包含：

- Backend API、Worker、Scheduler Deployment；
- Migration Job（成功后删除，避免遗留 Completed Pod）；
- Admin/Web 两个 Next.js Deployment 和 Service；
- 一个 Backend Service、ConfigMap 和受控 Secret；
- Admin/Web 两个严格 TLS IngressRoute；
- 角色化 ServiceAccount、NetworkPolicy、PDB、HPA、资源与探针。

部署顺序：prerequisite/secret/network -> migration -> runtime -> ingress。数据库迁移失败时不得
继续部署运行角色；切流前必须验证前滚、回滚和数据兼容窗口。

## 12. 当前迁移状态

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| `tpl-app` 统一 Backend、双 Next.js、K8s scaffold | 已实现并通过阶段门禁 | 是 Architecture v2 的唯一模板源 |
| Info、Knowledge 新三组件源码底座 | 已同步 | 仍需按后续阶段完成数据归并和切流 |
| Investment 新三组件源码底座 | 已由旧 Research 原地迁移并同步 | 旧 Research 身份已被 Investment 取代 |
| 旧 v1 K8s 目录、部署、数据库和 Secret | 迁移期回滚资产 | R5/R7 门禁和观察窗完成前不得误删 |
| `app-platform/research-app` 旧目录 | 历史回滚拓扑，不是未来 Research | 最终退役与未来新 App 创建是两件事 |
| 未来 `research-app` | 尚未创建 | 需独立 ADR、数据所有权和模板实例化 |
| 未来 `tools-app` | 尚未创建 | 旧实现已退出当前活动拓扑 |

“源码完成”“镜像构建”或“Pod Ready”都不等于迁移完成。只有数据库对账、真实双端配对、严格
TLS、真实身份、跨 App 契约、故障与回滚门禁通过后，才能切流和删除旧资产。

## 13. 架构约束

以下做法不被允许：

- 为 Admin 与 Web 重建两个 Backend 或两个主数据库；
- 把 Admin/Web/Internal 复制成三套 application/domain；
- 让 Next.js 持有领域主数据或成为最终授权点；
- 跨 App 直接访问数据库、Bucket、Redis key 或内部队列；
- 为每类任务预先建立独立 Worker 源码仓；
- 用未来 `research-app` 名称指代旧 Research 或 Investment 内部研究模块；
- 在模板门禁前直接修改三个实例，或用模板覆盖实例领域代码；
- 在回滚观察窗结束前删除旧数据库、Secret、镜像或部署；
- 用可变 tag 替代正式发布的 digest 锁定。

## 14. 相关文档

- [Architecture v2 重构执行基线](../../docs/app-platform-architecture-v2-refactor-plan.md)
- [数据所有权](./data-ownership.md)
- [集成规范](./integration-standards.md)
- [生产就绪标准](./production-readiness.md)
- [ADR-0007：每个领域 App 只有一个规范 Backend](./adr/0007-one-canonical-backend-per-app.md)
- [ADR-0009：Admin、Web 与 Internal 接口及身份分面](./adr/0009-api-surfaces-and-identity.md)
- [ADR-0010：每个 App 的数据库与迁移链归并](./adr/0010-database-convergence.md)
- [ADR-0011：Backend 运行角色与容量边界](./adr/0011-backend-runtime-roles.md)
- [Investment 清理与改名方案](../../docs/investment清理和改名.md)
