# App Platform 架构文档

## 总体设计

- [总体架构](./overall-architecture.md)
- [数据所有权](./data-ownership.md)
- [集成规范](./integration-standards.md)
- [生产就绪标准](./production-readiness.md)
- [实施路线](./implementation-roadmap.md)

## 应用架构

- [Auth App](./auth-app.md)
- [Info App](./info-app.md)
- [Knowledge App](./knowledge-app.md)
- [Research App](./research-app.md)
- [Tools App](./tools-app.md)
- [Investment App](./investment-app.md)

## 架构决策

- [ADR-0001：按长期业务领域划分 App](./adr/0001-domain-boundaries.md)
- [ADR-0002：每类业务数据只有一个权威主档](./adr/0002-system-of-record.md)
- [ADR-0003：同步 API 与异步事件并用](./adr/0003-sync-and-event-integration.md)
- [ADR-0004：对象存储按领域拥有和隔离](./adr/0004-object-storage-ownership.md)
- [ADR-0005：RAGFlow 定位为可重建的派生系统](./adr/0005-ragflow-as-derived-system.md)
- [ADR-0006：模板组件不定义领域边界](./adr/0006-template-components-and-domain-boundaries.md)

## 工程约定

- [新增 App 注意事项](./APP-DEVELOPMENT-NOTES.md)

## 建设任务

- [建设平台 S3 对象存储](./tasks/platform-object-storage.md)
- [完善 Elasticsearch App 级资源初始化](./tasks/elasticsearch-app-provisioning.md)

架构文档描述长期边界和目标状态；实际部署目录描述当前实现。目标能力尚未落地时，文档必须明确标注阶段，不得把计划写成现状。
