# SunMoonAI 总体平台架构

状态：`Architecture v2 权威总体说明 / 迁移实施中`

最后更新：2026-08-12

适用分支：`architecture-v2`

## 1. 文档定位

本文说明 `sunmoonai/` 下各个平台的职责、依赖方向、运行关系和治理边界。App Platform 内部的
详细设计见 [App Platform 总体架构](./app-platform-architecture.md)；重构任务状态见
[Architecture v2 重构执行基线](../../app-platform-architecture-v2-refactor-plan.md)。

旧文档中以 Portal、Nuxt、独立 Admin/Web Backend 和松散微服务为中心的描述已经废止。当前
架构以 Kubernetes 平台能力、领域 App、双 Next.js 前端、统一 FastAPI Backend、每 App 单一
逻辑数据库和显式跨 App 契约为基线。

## 2. 总体分层

```text
Users / Operators / Service Consumers
                   |
                   v
        +--------------------------+
        | ingress-platform         |
        | Traefik, TLS, routing    |
        +------------+-------------+
                     |
                     v
        +--------------------------+
        | app-platform             |
        | Auth + Domain Apps       |
        +----+-----------+---------+
             |           |
       state |           | events/tasks
             v           v
   +----------------+  +--------------------+
   | data-platform  |  | messaging-platform |
   +----------------+  +--------------------+

   +----------------+  +--------------------+
   | cicd-platform  |  | ops-platform       |
   | build/release  |  | observe/administer |
   +----------------+  +--------------------+

        +----------------------------------+
        | infrastructure / kind-infrastructure |
        | cluster foundation and conventions   |
        +----------------------------------+

deploy-sunmoonai-all orchestrates deployment order; it does not own domains.
```

平台之间遵循“基础能力向上提供、领域所有权不向下泄漏”的原则。Data、Messaging、Ingress 等平台
提供能力，不拥有 Info、Knowledge 或 Investment 的业务事实；App Platform 使用这些能力，并
对领域数据和业务规则负责。

## 3. 平台职责

| 平台 | 核心职责 | 明确不负责 |
| --- | --- | --- |
| `kind-infrastructure` | 本地 KIND 集群、节点、CNI、镜像加载、挂载与集群引导 | 业务 App 和领域数据 |
| `infrastructure` | 命名空间、通用脚本、共享部署约定和基础准备 | 替代各专用平台或 App 的所有权 |
| `ingress-platform` | Traefik、外部入口、严格 TLS、Host/Path 路由 | 用户认证、资源授权和业务 API |
| `cicd-platform` | Jenkins、Harbor、构建、扫描、制品保存和发布晋级 | 生产请求处理和业务数据 |
| `data-platform` | PostgreSQL、MongoDB、Redis、对象存储、Elasticsearch、Neo4j 等物理数据能力 | 定义业务主档归属 |
| `messaging-platform` | RabbitMQ、vhost、exchange/queue 和消息访问基础 | 把消息当作业务事实主档 |
| `app-platform` | Auth 与领域 App、业务规则、数据所有权、公开 API/事件/Artifact 契约 | 跨 App 共享数据库和基础设施编排 |
| `ops-platform` | pgAdmin、RedisInsight、Flower、mongo-express 等观察和受控运维入口 | 成为业务运行的同步关键依赖 |
| `deploy-sunmoonai-all` | 按依赖顺序编排各平台部署、状态和卸载 | 改写各平台内部资源所有权 |

## 4. 平台依赖方向

### 4.1 允许的依赖

```text
app-platform -> ingress-platform    对外暴露域名和 TLS
app-platform -> data-platform       使用独立逻辑数据资源
app-platform -> messaging-platform  异步任务、事件和可靠投递
app-platform -> auth-app/Casdoor    OIDC 与服务身份
ops-platform -> data/messaging/app  只读观察或受控管理
cicd-platform -> source/registry    构建、扫描、推送和晋级制品
deploy-* -> all platform scripts    只做编排
```

基础平台不能反向导入领域代码，Data Platform 不能调用 App API 来决定存储结构，Ingress 不能
承担业务授权，Ops 工具不能成为业务链路的必要跳板。

### 4.2 部署顺序不是运行时耦合

当前总控按基础设施、数据、消息、应用、运维等优先级部署。该顺序用于满足启动前置条件，不代表
运行时可以无限等待下游。每个 App 仍必须为依赖定义：

- 连接和请求超时；
- 有界重试、指数退避与抖动；
- 幂等键、Outbox/Inbox 和死信策略；
- readiness、降级和补偿；
- 周期性对账与恢复路径。

CI/CD 和 Ops 平台故障不应立即中断已发布业务；Ingress、数据、消息或身份等运行依赖的故障则
必须由业务 SLO、降级和恢复方案覆盖。

## 5. App Platform 在总体架构中的位置

### 5.1 当前业务边界

当前活动领域 App 为：

- `info-app`：来源、原始内容、版本、Artifact、血缘和可靠分发；
- `knowledge-app`：摄取、解析、索引、RAGFlow/检索适配和引用；
- `investment-app`：投资研究、Agent Runtime、证据、记忆及后续投资领域能力。

`auth-app` 提供平台身份基础，Casdoor 是当前 OIDC Provider。各业务 Backend 仍是自身资源授权
和数据所有权的最终责任人。

### 5.2 Research 历史与未来

旧 `research-app` 已被 `investment-app` 取代。旧名称可能暂时出现在：

- 迁移前的 K8s 目录、镜像、Secret、数据库或回滚记录；
- Investment 内部“投资研究”模块、类型或历史兼容字段；
- 尚未完成改名清理的阶段证据。

这些内容都不表示当前还存在一个与 Investment 并列的活动 `research-app`。

未来可能创建新的 `research-app`，用于通用、跨领域研究。它必须从届时已验收的 `tpl-app`
实例化，并获得独立的领域 ADR、仓库、工作负载身份、数据库、对象空间、消息资源和 API/事件
契约。未来 Research 不继承旧 Research 的身份，也不能直接拥有 Investment 的研究数据。

### 5.3 标准 App 形态

```text
Admin Next.js SSR -----+
                       +--> one FastAPI Backend --> one logical App database
Web Next.js SSR -------+           |
                                   +--> API / Worker / Scheduler / Migration roles
```

Admin 和 Web 是不同产品表面和安全会话，但共享本 App 的统一 Backend 与业务事实。这里的一个
数据库是“每 App 一个逻辑数据库”，绝不是所有 App 一个数据库。

## 6. 典型在线请求流

```text
1. Browser -> DNS/TLS -> Traefik
2. Traefik 根据 Host 区分 <app>-admin 与 <app>-web
3. 页面请求 -> 对应 Next.js standalone/SSR Service
4. 浏览器同源 /api -> Traefik -> 同一 <app>-backend Service
5. SSR -> BACKEND_INTERNAL_URL -> 同一 <app>-backend Service
6. Backend -> Casdoor / PostgreSQL / Redis / RabbitMQ / authorized dependencies
7. Response 沿原链路返回，correlation_id/trace context 贯穿
```

安全含义：

- 外部只暴露严格 TLS 域名；内部 ClusterIP 不作为浏览器配置；
- Admin/Web 使用独立 OIDC client、audience、cookie/session namespace、scope 和 Origin policy；
- Next.js 可以做 SSR 和同源交互，但 Backend 必须再次执行身份、角色、scope、资源级授权；
- 浏览器 Token、服务 Token、数据库凭据和 Kubernetes 身份不能复用。

## 7. 典型异步与跨 App 数据流

```text
Info local transaction
  -> business record + outbox
  -> RabbitMQ / authorized delivery
  -> Knowledge inbox + ingestion
  -> derived index / retrieval API
  -> Investment service identity call
  -> evidence/citation + agent run
```

约束：

- 每一步只写本 App 数据库；
- 跨 App 不使用分布式数据库事务；
- 事件只携带稳定 ID、版本和必要摘要，大对象使用 Artifact 引用和内容哈希；
- 消费者必须幂等，失败进入可观察状态并可对账/补偿；
- RAGFlow、Elasticsearch、向量、缓存等是可重建派生系统，不是权威主档。

## 8. Data Platform 与领域数据所有权

Data Platform 提供共享物理集群，App Platform 定义逻辑所有权：

```text
shared PostgreSQL cluster
├── info logical database + roles + backup policy
├── knowledge logical database + roles + backup policy
└── investment logical database + roles + backup policy
```

MongoDB、Redis、S3、Elasticsearch 和 Neo4j 同样按 App 划分数据库/namespace、bucket、index、
credential 和 policy。共享物理资源不授权跨 App 访问。

每个 App 的统一 Backend 拥有一条 Alembic 迁移链。Admin/Web 前端不拥有数据库，Worker 和
Migration 也不是新的数据所有者；它们只是同一 Backend 的不同运行角色。

## 9. Messaging Platform 与可靠交付

RabbitMQ 提供 broker 能力，领域语义由生产者 App 定义。消息分为：

- 领域事件：已经发生的事实；
- 任务消息：请求所属 Worker 执行；
- 补偿/对账触发：恢复遗漏或不一致。

数据库提交和消息发布使用 Transactional Outbox 收口；消费者使用 Inbox 或稳定幂等记录。
队列、vhost、用户和权限按 App/角色隔离。Broker 不保存唯一业务事实，也不能替代 PostgreSQL
备份或审计。

## 10. Ingress Platform

Traefik 是北南向入口和同源路由层：

- Admin Host `/` -> Admin Next.js，`/api` -> 统一 Backend；
- Web Host `/` -> Web Next.js，`/api` -> 同一统一 Backend；
- Internal API 默认不通过公网暴露；
- TLS secret、证书链、HSTS/CSP 等按生产门禁管理。

Ingress 只根据 Host/Path 转发，不根据页面角色决定最终业务授权。

## 11. CI/CD 与制品治理

源码在 GitHub 主远端维护，Gitee 作为镜像远端；施工分支当前为 `architecture-v2`。发布流程应
遵循：

```text
source commit -> tests/gates -> image build -> scan -> Harbor immutable digest
-> environment verification -> promote same digest to release tag
```

禁止为正式版本重新构建、使用可变 tag 代替 digest、或在未计算 release/live/evidence/rollback
保护闭包时删除 Harbor artifact。`1.0.0` 是旧架构回滚基线；Architecture v2 全部门禁通过后，
同一验收 digest 晋级 `2.0.0`。

## 12. Ops Platform 与可观测性

Ops Platform 提供受控的运维 UI 和诊断能力，不拥有数据。业务服务自身必须输出：

- 结构化日志与 correlation/trace ID；
- 请求率、错误率、延迟和饱和度；
- Worker 队列深度、任务延迟、重试和死信；
- Outbox/Inbox 积压与对账差异；
- 外部依赖健康、数据库迁移版本和发布 digest。

pgAdmin、RedisInsight、Flower 等只用于观察和授权管理；删除 Ops 工具不能破坏业务请求或任务
处理。

## 13. 环境、身份和网络隔离

- 环境使用独立 namespace、Secret、数据库角色、消息凭据和对象存储策略；
- 生产 Secret 不进入 Git、镜像、前端环境变量或日志；
- Kubernetes ServiceAccount 默认不挂载 Token，确需 API 权限时单独授权；
- NetworkPolicy 默认拒绝，按真实调用关系开放；
- 容器以非 root、只读根文件系统和最小 capabilities 运行；
- Migration、API、Worker、Scheduler 即使使用同一镜像，也必须使用不同工作负载身份和权限。

## 14. 模板、实例与平台资源的关系

`tpl-app` 不属于生产业务领域；它是创建领域 App 的工程基线，包含：

- 统一 FastAPI Backend；
- Admin/Web 两个 Next.js 前端；
- API/Worker/Scheduler/Migration 角色；
- K8s scaffold、身份、网络、构建和门禁。

共性修改先进入模板，经完整门禁后按 Info -> Knowledge -> Investment 串行同步。实例保留领域
代码，不允许模板覆盖业务实现。未来 Research/Tools 等 App 也从新模板创建。

`k8s/sunmoonai/app-platform/<app>` 是部署声明和迁移资产，不是业务源码仓的替代品。旧 v1 目录
在观察窗中存在，不代表其架构仍有效；目标目录只有在真实切流后才成为运行事实。

## 15. 当前迁移快照

| 范围 | 当前状态 |
| --- | --- |
| 模板统一 Backend、双 Next.js、角色化 K8s | 已实现并完成阶段验收 |
| Info、Knowledge、Investment 新源码底座 | 已建立并完成共同底座同步（R4 门禁通过） |
| 数据迁移（R5）与跨 App 真实竖线（R6） | 已完成；R6 全链验证于 2026-08-11 通过 |
| 发布收口与旧资源退役（R7/R8） | 进行中；门禁与观察窗完成前旧资产保留为回滚面 |
| 旧 `research-app` | 已由 `investment-app` 取代；遗留仅作迁移/回滚处理 |
| 未来新 `research-app` | 尚未创建，必须独立设计和实例化 |
| 旧 `tools-app` | 不属于当前活动拓扑；未来需要时重新从模板创建 |

## 16. 全局禁止事项

- 以共享物理数据库为理由跨 App 读表；
- 将平台部署顺序当作运行时可靠性；
- 让 Ingress、Next.js、队列、缓存或搜索索引成为领域主档；
- 把 Admin/Web 拆回两个 Backend 或两套主数据库；
- 复用用户 Token 作为服务身份；
- 将 Ops/CI/CD 工具放进业务同步关键路径；
- 把旧 `research-app`、Investment 内部研究模块和未来 `research-app` 混为一体；
- 在数据对账、回滚和观察窗完成前删除旧部署、数据库、Secret 或镜像；
- 未经模板门禁在多个实例重复修改共同底座。

## 17. 相关权威文档

- [App Platform 总体架构](./app-platform-architecture.md)
- [App Platform 数据所有权](../../../app-platform/docs/data-ownership.md)
- [App Platform 集成规范](../../../app-platform/docs/integration-standards.md)
- [Architecture v2 重构执行基线](../../app-platform-architecture-v2-refactor-plan.md)
- [Investment 清理与改名方案](../../investment清理和改名.md)
