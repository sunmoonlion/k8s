# 任务：完善 Elasticsearch App 级资源初始化

## 1. 任务状态

- 状态：实施中
- 优先级：高
- 所属阶段：阶段 B/E 平台能力
- 现有组件：`k8s/sunmoonai/data-platform/elasticsearch`
- 首个候选使用方：`info-app`

## 2. 背景

Data Platform 已有 Elasticsearch 部署组件，包含 Helm Chart、环境 values、
Kind 持久化和统一部署入口，但当前主要解决物理集群部署问题。

平台尚缺少按 App 自动创建索引模板、生命周期策略、别名、角色和访问凭据的
完整机制。若业务组件直接使用管理员账号或临时手工建索引，将破坏 App 数据
所有权、最小权限和可重复部署原则。

## 3. 目标

1. 保留现有 Elasticsearch 物理集群部署能力。
2. 建立声明式、幂等的 App 级搜索资源初始化机制。
3. 按 App、环境和用途隔离索引、角色和凭据。
4. 通过稳定别名隐藏索引版本和重建过程。
5. 支持凭据轮换、权限撤销、状态检查和审计。
6. 明确平台领域索引与 RAGFlow 内部索引的边界。

## 4. 边界

平台 Elasticsearch 负责：

- App 自己维护的领域全文搜索和聚合索引。
- 索引模板、组件模板、ILM 策略和稳定别名。
- App 级角色、用户或 API Key。
- App Namespace 内的访问 Secret。
- 可重建索引的迁移、切换和回滚。

平台 Elasticsearch 不负责：

- 保存业务权威主档。
- 允许跨 App 直接搜索私有索引。
- 代替 Backend 的权威读取 API。
- 接管 RAGFlow 自带 Elasticsearch。
- 将管理员账号下发给业务组件。

## 5. 目标资源模型

共享物理集群，按 App、环境和索引用途隔离：

```text
Elasticsearch cluster
├── component template
├── index template
├── ILM policy
├── versioned physical index
├── stable read/write aliases
├── application role
└── application credential
```

建议命名：

```text
index pattern: <environment>-<app>-<dataset>-*
physical index: <environment>-<app>-<dataset>-v<schema>-<sequence>
read alias:     <environment>-<app>-<dataset>-read
write alias:    <environment>-<app>-<dataset>-write
role:           <environment>-<app>-<component>-search
secret:         <app>-<component>-elasticsearch
```

Info App 示例：

```text
development-info-information-v1-000001
development-info-information-read
development-info-information-write
development-info-web-backend-search
```

索引仅保存可由 Info App PostgreSQL 和对象存储重建的数据。

## 6. 实施任务

### E1. 核实现状校正

- [x] 确认现有 Chart 的安全功能、认证方式和许可证约束。
- [x] 启用 Elasticsearch 身份认证和必要的 TLS。
- [x] 明确管理员 Secret 的创建、保存和轮换方式。
- [x] 禁止通过公开 Ingress 暴露无认证 Elasticsearch。
- [x] 检查 Kind、开发和生产 values 的安全配置一致性。
- [ ] 确认 Kibana 和 Logstash 使用独立服务凭据。

### E2. 声明式资源定义

- [x] 定义 App 搜索资源配置格式。
- [x] 配置中声明数据集、索引模式、Mapping 和 Settings。
- [ ] 支持组件模板、索引模板和 ILM 策略。
- [x] 支持读写别名和初始物理索引。
- [x] 支持资源版本及变更说明。
- [x] 配置文件不得保存明文长期密钥。

建议声明包含：

```text
app
component
environment
namespace
dataset
schema version
index settings
mapping source
ILM policy
read/write permissions
secret name
credential type
```

### E3. 幂等初始化工具

- [x] 实现 `provision`、`status`、`rotate` 和 `revoke` 操作。
- [ ] 支持 `dry-run`。
- [x] 幂等创建或更新索引模板。
- [x] 首次部署时创建物理索引及读写别名。
- [x] 创建最小权限角色。
- [x] 创建原生用户，并生成 Kubernetes Secret。
- [x] 更新 Secret 时避免在标准输出中打印凭据。
- [ ] 失败时返回明确错误，不能留下权限过大的半成品账号。

### E4. 权限模型

- [x] 写入组件仅能写指定 write alias。
- [x] 查询组件仅能读取指定 read alias。
- [ ] 同一 App 内是否共享权限由数据职责决定，不按技术栈自动共享。
- [x] 不同 App 默认互不可见。
- [ ] 管理模板、ILM、角色和凭据的权限只属于平台初始化账号。
- [x] Backend 对外提供权威搜索 API，其他 App 不直接持有索引凭据。
- [ ] Worker 复用所属 Backend 的数据职责，不形成第二权威写入口。

### E5. 索引演进与重建

- [ ] Mapping 破坏性变更必须创建新版本物理索引。
- [ ] 从权威主档全量构建新索引。
- [ ] 对重建期间的增量数据建立追赶机制。
- [ ] 校验文档数量、抽样内容和业务查询。
- [ ] 原子切换 read/write alias。
- [ ] 保留可配置的旧索引回滚窗口。
- [ ] 验证失败后可以恢复旧别名。
- [ ] 索引删除不得影响业务主档。

### E6. 部署流程接入

- [x] 将 App 级初始化置于 Elasticsearch 就绪之后。
- [ ] 接入 App 或 Backend 统一部署入口。
- [ ] Namespace Secret 创建完成后才启动依赖组件。
- [x] 支持单独重新执行初始化，不要求重装 Elasticsearch。
- [ ] 卸载 App 默认不删除物理索引。
- [ ] 数据销毁必须使用独立、显式确认的流程。

### E7. Info App 首次验证

- [x] 确认 Info App 长期需要独立领域全文索引。
- [x] 创建 Info App `information` 领域索引。
- [ ] 索引原文、规范化文本还是仅索引摘要必须由 Info App 数据模型确定。
- [x] Mapping 包含 `info_id` 和 `version_id`，权威数据仍通过 Info App API 获取。
- [ ] 验证删除全部索引后可以从 Info App 主档重建。
- [x] 验证 Info App 账号无法访问未授权索引。

### E8. 运维与可观测

- [ ] 监控集群健康、分片、磁盘水位、查询延迟和拒绝数。
- [ ] 监控各 App 索引容量和增长速度。
- [ ] 记录初始化、轮换、撤销和别名切换审计。
- [ ] 建立索引重建和故障恢复手册。
- [ ] 对管理员凭据和 App 凭据进行周期轮换。

## 7. 验收标准

- [ ] Elasticsearch 必须认证后才能访问。
- [ ] App 资源可由声明重复初始化且结果一致。
- [ ] 每个 App 具有独立角色和凭据。
- [ ] App 只能操作授权的索引或别名。
- [ ] 业务组件不持有 Elasticsearch 管理员凭据。
- [ ] 凭据可以轮换并撤销旧凭据。
- [ ] 索引可在不停止权威数据库写入的情况下重建和切换。
- [ ] 删除领域索引后能够从权威主档完整重建。
- [ ] RAGFlow 私有 Elasticsearch 不属于该初始化机制管理范围。

## 8. 关键决策点

实施前需要明确：

1. 使用原生用户还是 API Key 作为业务访问凭据。
2. 开发环境和生产环境的 TLS 终止位置。
3. ILM、快照和可重建策略之间的责任边界。
4. App 资源声明放在 Data Platform、App 目录还是二者分层管理。
5. Mapping 由平台审核、App 维护的具体流程。

推荐方向：

- 平台维护初始化工具和安全基线。
- App 在自己的部署目录声明所需数据集、Mapping 和权限。
- 初始化工具读取声明并创建物理资源。
- App 只获得运行凭据，不获得平台管理权限。

## 9. 暂不处理

- 让不同 App 直接联表式查询彼此索引。
- 将 Elasticsearch 作为业务主数据库。
- 将 RAGFlow 内部索引迁入平台 Elasticsearch。
- 未经真实容量需求提前建设跨地域搜索集群。

## 10. 关联文档

- [总体架构](../../../docs/sunmoonai-architecture/overall-architecture/app-platform-architecture.md)
- [数据所有权](../data-ownership.md)
- [Info App](../info-app.md)
- [生产就绪标准](../production-readiness.md)
- [ADR-0005：RAGFlow 定位为可重建的派生系统](../adr/0005-ragflow-as-derived-system.md)
