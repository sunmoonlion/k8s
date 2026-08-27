# App Platform 架构文档（实现参考，非权威）

> ⚠ **本目录不是现状的权威来源。**如本目录末行所述，这些文档"描述长期边界和目标状态"，
> 即它们写的是**应该怎样**，不保证与代码一致。
>
> **项目现状以 [项目总览](../../docs/overall-architecture.md) 与
> [`docs/architecture/`](../../docs/architecture/) 为准**（那里每条断言都可回代码取证）；
> 与代码冲突时以代码为准。本目录保留作为设计意图与实现参考。
>
> 阶段、门禁和回滚点见
> [App Platform Architecture v2 重构执行基线](../../docs/app-platform-architecture-v2-refactor-plan.md)。

## 总体设计

- **[项目总览（现状权威）](../../docs/overall-architecture.md)**
- [数据所有权](./data-ownership.md)
- [集成规范](./integration-standards.md)
- [生产就绪标准](./production-readiness.md)
- [实施路线](./implementation-roadmap.md)

## 应用架构

- [Auth App](./auth-app.md)
- [Info App](./info-app.md)
- [Info App 采集与资讯治理架构](../info-app/docs/info-app-spider-architecture.md)
- [Info App 采集与资讯治理实施任务](../info-app/docs/info-app-spider-implementation-tasks.md)
- [Knowledge App](./knowledge-app.md)
- [Investment App](./investment-app.md)
- [未来 Research App（尚未创建）](./research-app.md)
- [未来 Tools App（尚未创建）](./tools-app.md)

## 架构决策（已迁至 `docs/architecture/decisions/`）

- [ADR-0001：按长期业务领域划分 App](../../docs/architecture/decisions/0001-domain-boundaries.md)
- [ADR-0002：每类业务数据只有一个权威主档](../../docs/architecture/decisions/0002-system-of-record.md)
- [ADR-0003：同步 API 与异步事件并用](../../docs/architecture/decisions/0003-sync-and-event-integration.md)
- [ADR-0004：对象存储按领域拥有和隔离](../../docs/architecture/decisions/0004-object-storage-ownership.md)
- [ADR-0005：RAGFlow 定位为可重建的派生系统](../../docs/architecture/decisions/0005-ragflow-as-derived-system.md)
- [ADR-0006：模板组件不定义领域边界](../../docs/architecture/decisions/0006-template-components-and-domain-boundaries.md)
- [ADR-0007：每个领域 App 只有一个规范 Backend](../../docs/architecture/decisions/0007-one-canonical-backend-per-app.md)
- [ADR-0008：Backend 仓库收敛与归档](../../docs/architecture/decisions/0008-backend-repository-convergence.md)
- [ADR-0009：Admin、Web 与 Internal 接口及身份分面](../../docs/architecture/decisions/0009-api-surfaces-and-identity.md)
- [ADR-0010：每个 App 的数据库与迁移链归并](../../docs/architecture/decisions/0010-database-convergence.md)
- [ADR-0011：Backend 运行角色与容量边界](../../docs/architecture/decisions/0011-backend-runtime-roles.md)
- [ADR-0012：模板优先与实例完整同步](../../docs/architecture/decisions/0012-template-first-adoption.md)
- [ADR-0013：发布 Artifact 生命周期](../../docs/architecture/decisions/0013-release-artifact-lifecycle.md)

## 工程约定

- [新增 App 注意事项](./APP-DEVELOPMENT-NOTES.md)
- [App 依赖预检查配置说明](./app-dependency-preflight.md)

## 建设任务

- [建设平台 S3 对象存储](./tasks/platform-object-storage.md)
- [完善 Elasticsearch App 级资源初始化](./tasks/elasticsearch-app-provisioning.md)

架构文档描述长期边界和目标状态；实际部署目录描述当前实现。目标能力尚未落地时，文档必须明确标注阶段，不得把计划写成现状。
