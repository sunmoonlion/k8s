# App Platform 总体架构

> **Architecture v2 迁移提示（2026-08-01）**：本文中的四组件、独立 Admin/Web
> Backend 和旧模板技术栈描述是重构前 v1 现状。Architecture v2 已决定保留领域 App
> 边界，但把每个 App 收敛为一个规范 FastAPI Backend、两个 Next.js 前端和一个逻辑
> 数据库。重构期间唯一施工权威是
> [Architecture v2 重构执行基线](../../docs/app-platform-architecture-v2-refactor-plan.md)，
> 决策权威是 ADR-0007～ADR-0013。本文将在 R8 根据已验收实现整体重写。

## 1. 文档定位

本文只描述 App Platform 的总体架构，包括平台目标、应用边界、依赖方向、数据所有权和共同设计原则。

相关文档：

- [架构文档索引](./README.md)
- [数据所有权](./data-ownership.md)
- [集成规范](./integration-standards.md)
- [生产就绪标准](./production-readiness.md)
- [实施路线](./implementation-roadmap.md)
- [Auth App](./auth-app.md)
- [Info App](./info-app.md)
- [Knowledge App](./knowledge-app.md)
- [Research App](./research-app.md)
- [Tools App](./tools-app.md)
- [Investment App](./investment-app.md)

## 2. 平台定位

App Platform 是由多个长期演进的应用系统组成的业务平台。各 App 按领域划分职责，拥有独立的数据和业务边界，并通过稳定接口协作。

平台当前包含：

```text
App Platform
├── auth-app
├── info-app
├── knowledge-app
├── research-app
├── tools-app
└── investment-app
```

这些 App 不按照“主要系统”和“次要功能”划分。每个 App 都代表一个需要长期建设的独立领域系统：

- `auth-app`：身份、组织、认证和授权系统。
- `info-app`：资讯获取、管理、治理、组织和分发系统。
- `knowledge-app`：知识处理、文档索引、语义检索、RAG 和模型辅助处理能力系统。
- `research-app`：通用研究协作、研究任务、研究材料组织和研究产物系统。
- `tools-app`：可复用的通用工具能力系统。
- `investment-app`：投资研究、分析、组合、策略和决策支持系统。

`investment-app` 是投资领域应用，会广泛使用其他 App 提供的能力，但其他 App 的领域价值和架构不从属于投资场景。未来新增业务应用时，也应复用这些平台能力。

平台长期目标是形成可演进、可审计、可恢复的投资管理系统。当前 Kind 和 `app-platform-dev` 是开发环境实现，不代表生产拓扑。

### 2.1 App 与技术组件

领域 App 和 `tpl-app` 组件属于不同层次：

- `auth-app`、`info-app`、`knowledge-app`、`research-app`、`tools-app`、
  `investment-app` 表达长期业务领域。
- `admin-backend`、`web-backend`、`admin-frontend`、`web-frontend` 是可选技术栈样板。
- Deployment、Worker、Scheduler 和 Migration Job 是运行角色。

`tpl-app` 当前提供四种可以独立选择、开发和部署的组件：

| 模板组件 | 主要技术栈 |
|---|---|
| `tpl-admin-backend` | Python / FastAPI |
| `tpl-web-backend` | JavaScript/TypeScript / NestJS |
| `tpl-admin-frontend` | Vue |
| `tpl-web-frontend` | Next.js |

组件名称用于保持统一工程和部署约定，不预先规定其业务职责。具体 App 根据所需技术栈选择组件，并在各组件的 `app` 目录中实现不同领域功能。

每个 App 的工程骨架完整保留四个组件及其平台接入能力。是否开发具体业务能力与
是否在某个集群启动是两个独立决策：尚未承载业务的组件可以保留样板代码，实际
运行组件由 Kubernetes 部署配置按集群控制，不通过裁剪源码工程表达。

## 3. 总体关系

```text
                         ┌──────────────────┐
                         │     auth-app     │
                         │ 身份 / 组织 / 权限 │
                         └────────┬─────────┘
                                  │
                 ┌────────────────┼────────────────┐
                 │                │                │
        ┌────────▼────────┐ ┌─────▼──────┐ ┌──────▼─────────┐
        │    info-app     │ │knowledge-app│ │    tools-app   │
        │ 资讯管理与分发   │ │ 知识处理与检索│ │ 通用工具能力    │
        └────────┬────────┘ └─────┬──────┘ └──────┬─────────┘
                 │                │                │
                 └────────────────┼────────────────┘
                                  │
                         ┌────────▼──────────┐
                         │  investment-app  │
                         │ 投资研究与决策支持 │
                         └───────────────────┘
```

该图表达主要能力关系，不表示所有调用都必须经过 `investment-app`。例如：

- `info-app` 可以使用 `knowledge-app` 完成内容理解、知识处理和检索。
- `info-app` 可以使用 `tools-app` 完成文件转换。
- 新业务 App 可以直接使用 `auth-app`、`info-app`、`knowledge-app`、`research-app`
  和 `tools-app`。

## 4. 应用职责

### 4.1 Auth App

负责：

- 用户和组织管理。
- 登录、认证和令牌管理。
- 角色、权限和访问控制。
- 为其他 App 提供统一身份。

不负责各业务 App 内部的领域数据和业务规则。

### 4.2 Info App

负责：

- 资讯源、采集、接入和订阅管理。
- 原始资讯及其版本的长期保存。
- 内容标准化、去重、分类和关联。
- 资讯元数据、来源、版权、血缘和质量治理。
- 资讯检索、分发、订阅、摘要和预警。
- 向 RAGFlow 等知识处理系统分发可重建副本。

`info-app` 是资讯领域的 System of Record，不是单一爬虫或投资资讯附属模块。

### 4.3 Knowledge App

负责：

- 知识空间、文档投递、处理任务和检索请求。
- 文档解析、分块、Embedding、语义检索和 RAG 能力。
- 领域文档与 RAGFlow 对象的映射、对账和重建。
- 通过统一 API 隔离 RAGFlow 等具体知识引擎。

不持有其他领域的唯一原文和业务主数据。

### 4.4 Research App

负责：

- 通用研究项目、研究任务和研究协作。
- 研究材料组织、证据引用和研究产物沉淀。
- 跨领域研究工作流和过程审计。

不持有资讯原文、知识处理副本、工具运行主档和投资领域结论。

### 4.5 Tools App

负责：

- 文档转换、格式处理等通用工具。
- 可被多个领域复用、且不属于某个领域的数据处理能力。
- 工具调用接口及运行管理。

只有真正跨领域、无明确业务所有者的能力才进入 `tools-app`。

### 4.6 Investment App

负责：

- 投资研究流程。
- 公司、行业和标的分析。
- 投资组合、策略和风险管理。
- 研究观点、笔记、评级和投资结论。
- 对 `info-app` 资讯、`knowledge-app` 知识/RAG 能力和 `tools-app` 工具能力的投资领域编排。

不复制其他 App 的基础能力，也不成为其他领域主数据的所有者。

`investment-app` 内部长期按 Security Master、Research、Portfolio、Valuation、Risk、Decision、Reporting 和 Audit 划分模块。初期采用模块化单体，不因模块边界立即拆分微服务。

## 5. 依赖原则

### 5.1 领域独立

每个 App 必须能够独立演进。某个 App 可以依赖另一个 App 的公开能力，但不能直接依赖其内部数据库结构或实现细节。

### 5.2 依赖关系受控

各 App 之间不限制实际请求、回调和事件的流动方向。同步调用和异步消息可以根据业务需要双向发生，例如：

- `investment-app` 查询资讯或请求模型能力。
- `info-app` 根据投资业务公开的关注对象执行定向分发。
- `knowledge-app`、`research-app` 和 `tools-app` 回调任务状态或发布完成事件。
- `auth-app` 发布用户、组织和权限变化事件。

需要控制的是领域依赖、数据所有权和故障传播：

- App 只能通过公开 API、事件、任务消息或对象交换协议协作。
- App 不得直接依赖其他 App 的数据库结构和内部实现。
- 调用、回调或消费事件不会改变数据的权威所有者。
- 事件生产者仍然拥有事件所表达的领域事实。
- 避免形成启动、发布和运行时的循环强依赖。
- 某个依赖暂时不可用时，能够根据业务要求降级、排队、重试或补偿。
- `auth-app`、`info-app`、`knowledge-app`、`research-app` 和 `tools-app` 的核心能力
  不依赖 `investment-app` 才能成立。

`investment-app` 不是跨 App 的中心编排器。各 App 保持领域自治，并可以根据公开契约双向提供或消费能力。

### 5.3 接口优先

跨 App 协作通过以下方式完成：

- 同步 API。
- 异步事件或任务消息。
- 明确定义的文件或对象交换协议。

禁止以共享数据库表作为默认集成方式。

同一 App 内不同 Backend 技术组件之间也遵循接口优先原则。某类数据由负责它的 Backend 提供唯一权威 API，其他 Backend 和前端不能绕过该接口直接读取其数据库。

跨 App API、事件、任务和对象交换遵循 [App Platform 集成规范](./integration-standards.md)。

### 5.4 可替换基础能力

领域系统不能与某个具体基础产品永久绑定。例如：

- `info-app` 不依赖 RAGFlow 保存唯一原文。
- `investment-app` 不依赖某个具体模型供应商。
- 文件主档不依赖某个转换工具的私有目录。

基础产品可以替换或重建，而领域主数据必须保持完整。

## 6. 数据所有权

每类数据必须只有一个权威所有者。

| 数据 | 权威所有者 |
|---|---|
| 用户、组织、角色、权限 | `auth-app` |
| 资讯源、原文、版本、标签、血缘、质量和分发状态 | `info-app` |
| 知识空间、知识处理任务、映射、模型辅助处理配置和推理运行引用 | `knowledge-app` |
| 通用研究项目、研究任务和跨领域研究产物 | `research-app` |
| 通用工具配置和工具任务 | `tools-app` |
| 投资研究、组合、策略、观点和结论 | `investment-app` |

### 6.1 App 与 Backend 的数据责任

App 是领域边界和领域数据的总体所有者。Backend 是该 App 内根据功能和技术栈选择的数据责任单元。

当一个 App 同时启用 Python/FastAPI Backend 和 JavaScript/TypeScript/NestJS Backend 时：

- 两个 Backend 仍然属于同一个 App 领域。
- 每个 Backend 负责该领域内一组明确且互不重叠的数据。
- 每类数据只能由一个 Backend 写入。
- 每类数据只能由负责它的 Backend 提供权威读取 API。
- 其他 Backend 通过 API、事件或任务消息使用该数据，不能直接访问其数据库。
- 前端不拥有业务数据库，只能通过 Backend API 使用数据。
- Worker 和 Scheduler 跟随所属 Backend，复用其领域代码、数据库和写入规则，不形成新的数据所有权。

平台数据访问的核心规则是：

```text
一份数据，一个写入者。
一类数据，一个权威 API。
跨组件协作，不跨数据库访问。
```

Backend 的 `admin`、`web` 名称及其编程语言不决定数据的领域归属。功能和数据职责应先确定，再选择适合的技术组件承载。

如果数据职责需要从一个 Backend 转移到另一个 Backend，必须经过明确的迁移过程，包括停止旧写入、迁移数据、切换接口、校验一致性和撤销旧权限。禁止长期双写。

下游系统可以保存缓存、索引和处理副本，但副本必须可由权威数据重新生成。

详细分类、时间版本和备份等级遵循 [App Platform 数据所有权](./data-ownership.md)。

## 7. 存储原则

每个 App 拥有自己的逻辑数据边界：

- 每个启用且承担数据职责的 Backend 使用独立逻辑数据库和独立运行凭据。
- Backend 数据库只保存该 Backend 负责且不与其他 Backend 重叠的领域数据。
- 对象存储保存该领域拥有的文件主档。
- 搜索和向量数据库保存可重建索引。
- 缓存和队列不作为长期主数据。

PostgreSQL、MongoDB、Redis、对象存储、搜索引擎和消息系统可以共享物理集群，但必须通过独立数据库、账号、Bucket、索引、Key 空间、vhost、凭据和访问策略保持逻辑隔离。

具体隔离方式必须以基础产品实际提供的能力为准，不能只通过命名约定宣称隔离。
当前 PostgreSQL 和 MongoDB 按 Backend 创建独立数据库、用户和连接 Secret；
Redis、S3 和 Elasticsearch 分别使用 ACL Key 空间、Bucket/凭据和索引/角色隔离。
Neo4j Community 不具备同等级的多数据库和细粒度授权能力，在升级为支持所需
隔离能力的版本或改为独立实例前，只作为未默认启用的平台可选能力。

平台共享设施与产品内置设施可以同时存在，二者承担不同职责。例如：

- Data Platform Object Storage 通过统一 S3 接口保存各 App 拥有的文件主档和领域处理产物。
- Data Platform Elasticsearch 保存各 App 自己维护的领域搜索索引。
- RAGFlow 自带 MinIO 保存其知识处理文档副本。
- RAGFlow 自带 Elasticsearch 保存其分块、Embedding、向量和内部检索数据。

平台对象存储以 S3 API 作为稳定契约，不把 App 绑定到具体产品。Kind 环境长期使用固定版本 MinIO；远程环境使用仍受维护、满足高可用和恢复要求的 S3 兼容实现。

接入平台对象存储或 Elasticsearch，不意味着第三方产品必须改用这些设施。产品内置存储属于该产品的私有运行边界，可以随产品整体升级、删除和重建；领域主档及领域索引不能依赖产品内置存储成为唯一来源。

前端组件不申请业务数据库。Worker 使用所属 Backend 的数据库，不能建立独立主档。其他 Backend 即使能够获得网络连接，也不得把跨数据库查询作为正式读取方式。

关键业务数据必须支持历史版本和按时点重现。PVC 保留策略、缓存、索引和消息队列均不能替代备份。

## 8. 部署原则

所有 App 遵循 App Platform 统一部署规范：

```text
app-platform
  -> business app
    -> deployable component
```

新 App 原则上从统一 `tpl-app` 完整实例化四个源码组件和两个配套 Worker 运行角色，
以继承认证、数据库、S3、Elasticsearch、构建、镜像和部署约定。完整实例化不代表这些角色必须同时承载
业务或在所有集群运行：

- 四个组件始终保留完整工程和平台接入配置。
- Celery Worker 复用 admin-backend，NodeBull Worker 复用 web-backend；二者不建立独立子仓库、镜像或数据所有权。
- 按功能和技术栈选择当前实际开发的组件。
- 通过 Kubernetes 组件启用标志控制不同集群中的运行状态。
- 领域模块可以在所选组件的 `app` 内采用与业务匹配的代码组织。
- 不得根据 `admin`、`web` 等模板名称机械推导领域边界。
- 每类业务数据在实现时确定唯一权威写入 Backend，其他组件通过 API、事件或任务使用。
- Worker、Scheduler 等运行角色可以复用所属组件的源码和镜像，不必因此创建新的领域 App。

每个 App 应具备：

- 独立的 `deploy-<app>-all` 入口。
- 按集群控制的启用标志和部署优先级。
- 独立 Namespace 配置或明确的共享 Namespace 策略。
- Harbor 镜像检查。
- Secret、ConfigMap、Service 和 Ingress 的标准部署方式。
- `deploy`、`uninstall`、`status` 和 `logs` 等统一操作。

开发环境继续使用现有脚本化部署规范。生产环境的目标能力包括：

- dev、test、staging 和 prod 环境隔离。
- 声明式 GitOps 发布和变更审计。
- Secret 管理、最小权限和网络隔离。
- 指标、日志、链路、告警和 SLO。
- 高可用、备份、RPO/RTO 和恢复演练。
- 镜像固定版本、扫描、签名和 SBOM。

各 App 上线前遵循 [App Platform 生产就绪标准](./production-readiness.md)。

## 9. 演进原则

长期架构和第一阶段实现并不矛盾：

- 长期领域边界从第一天确定。
- 第一阶段可以只实现少量模块。
- 未实现模块保留清晰接口和扩展位置。
- 不以短期省事为由让基础产品持有唯一业务主档。
- 不因当前只有投资场景而把通用领域设计成投资附属功能。

后续每增加一个 App，应先建立独立架构文档，再确定内部模块和部署组件。

具体建设阶段和验收顺序见 [App Platform 实施路线](./implementation-roadmap.md)。影响领域边界、数据所有权或平台契约的决定必须增加 ADR。
