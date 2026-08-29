# App Platform 架构文档（实现参考，非权威）

> ⚠ **本目录不是现状的权威来源。**如本目录末行所述，这些文档"描述长期边界和目标状态"，
> 即它们写的是**应该怎样**，不保证与代码一致。
>
> **项目现状以 [项目总览](../../docs/project-guide/overall-architecture.md) 与
> [`docs/project-guide/`](../../docs/project-guide/) 为准**（那里每条断言都可回代码取证）；
> 与代码冲突时以代码为准。本目录保留作为设计意图与实现参考。
>
> 阶段、门禁和回滚点见
> [App Platform Architecture v2 重构执行基线](../../docs/app-platform-architecture-v2-refactor-plan.md)。

## 总体设计

- **[项目总览（现状权威）](../../docs/project-guide/overall-architecture.md)**
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

## 架构决策（已升为约束）

原 14 条 ADR 已删除。其结论**全文**写在
[`docs/dev-plan/README.md`](../../docs/dev-plan/README.md) 的「既有约束」一节（18 条），
其中能机械判定的已变成
[`docs/project-guide/check-cross-repo.py`](../../docs/project-guide/check-cross-repo.py)
与各仓 `test_kernel_invariants.py` 里的检查。

理由：留着仅作参考的文档不会被执行。

## 工程约定

- [新增 App 注意事项](./APP-DEVELOPMENT-NOTES.md)
- [App 依赖预检查配置说明](./app-dependency-preflight.md)

## 建设任务

- [建设平台 S3 对象存储](./tasks/platform-object-storage.md)
- [完善 Elasticsearch App 级资源初始化](./tasks/elasticsearch-app-provisioning.md)

架构文档描述长期边界和目标状态；实际部署目录描述当前实现。目标能力尚未落地时，文档必须明确标注阶段，不得把计划写成现状。
