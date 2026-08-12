# 任务：建设平台 S3 对象存储

## 1. 任务状态

- 状态：实施中（Kind 基础部署与持久化验证已完成）
- 优先级：高
- 所属阶段：阶段 B 前置基础设施
- 主要目录：`k8s/sunmoonai/data-platform/object-storage`
- 首个使用方：`info-app`

## 2. 背景

App Platform 已确定由各 App 持有本领域文件主档，但当前 Data Platform
尚未提供独立的共享对象存储。

RAGFlow 自带 MinIO 属于 RAGFlow 的私有运行边界，只保存知识处理副本，
不能作为 Info App 或其他 App 的领域主档存储。平台必须建设独立的 S3
对象存储能力，并按 App 和环境分配 Bucket、访问策略及凭据。

S3 是平台依赖的接口契约，不限定唯一产品实现：

- Kind 长期使用固定版本的 MinIO，服务本地开发和集成测试。
- 远程开发和生产环境使用仍受维护、满足可靠性要求的 S3 兼容实现。
- 可选远程实现包括云 S3、Ceph RGW 或具有正式支持的 MinIO 产品。

MinIO Community 及其 Helm Chart 上游仓库已于 2026 年归档。因此固定版本
MinIO 仅作为 Kind 开发实现，不作为远程生产环境的长期默认方案。

## 3. 目标

1. 在 Data Platform 建立统一的 S3 对象存储能力。
2. 支持 Kind、开发和生产环境的差异化配置。
3. 支持按 App 自动创建 Bucket、Policy 和访问凭据。
4. 通过 Kubernetes Secret 向获准的 Backend 提供凭据。
5. 支持版本控制、生命周期、备份、监控和恢复。
6. 保持平台对象存储与第三方产品内置对象存储相互独立。
7. 允许替换底层实现而不改变 App 的 S3 接入契约。

## 4. 边界

平台对象存储负责：

- 各 App 拥有的原始文件主档。
- 各 App 拥有的领域处理产物。
- App 级 Bucket、Policy、用户和凭据管理。
- 对象版本、生命周期、审计、备份和恢复。

平台对象存储不负责：

- 代替 PostgreSQL 保存业务元数据。
- 保存 Redis、消息队列或搜索索引。
- 接管 RAGFlow 自带 MinIO。
- 允许不同 App 使用共享管理员凭据。
- 允许前端直接获得长期访问密钥。

## 5. 目标资源模型

每个环境选择一个平台对象存储实现，并按 App 做逻辑隔离：

```text
App
└── S3 API
    └── environment object-storage provider
        ├── app/environment buckets
        ├── app-specific policy
        ├── app-specific service account
        └── app namespace Kubernetes Secret
```

实现矩阵：

| 环境 | 默认实现 | 定位 |
|---|---|---|
| Kind | 固定版本 MinIO | 长期本地开发和集成测试 |
| 远程开发 | 待选 S3 兼容实现 | 验证远程部署与运维方案 |
| 远程生产 | 受维护且有恢复保障的 S3 实现 | 正式领域主档存储 |

Bucket 名称必须全局唯一，建议采用：

```text
<environment>-<app>-<purpose>
```

Info App 首批资源：

```text
development-info-originals
development-info-derived
```

- `info-originals`：不可变原始证据，启用版本控制，禁止普通覆盖和删除。
- `info-derived`：可重建处理产物，允许配置生命周期和清理策略。

实际名称应由配置生成，业务代码不得硬编码环境前缀。

## 6. 可移植性约束

### 6.1 统一配置契约

所有 Provider 向 Backend 暴露同一组运行配置：

```text
S3_ENDPOINT
S3_REGION
S3_ACCESS_KEY_ID
S3_SECRET_ACCESS_KEY
S3_BUCKET
S3_FORCE_PATH_STYLE
S3_USE_TLS
```

- Kind 配置指向平台 MinIO Service。
- 远程环境替换 Endpoint、Region 和凭据，不改变业务代码。
- 非敏感配置进入 ConfigMap，访问凭据进入 Secret。
- Bucket 名称由部署声明注入，不在代码中硬编码。
- Frontend 不接收长期 S3 凭据。

### 6.2 Backend 统一接口

Python 和 NestJS 分别实现相同语义的对象存储 Adapter：

```text
put_object
get_object
head_object
delete_object
list_objects
create_presigned_url
```

- Python 使用 AWS S3 兼容 SDK，例如 `boto3`。
- NestJS 使用 AWS SDK for JavaScript，例如 `@aws-sdk/client-s3`。
- 业务模块只能依赖 Adapter 接口，不能直接依赖 MinIO SDK。
- MinIO Admin API、Console URL 和专有事件格式不得进入业务领域代码。
- Provider 管理操作只存在于 Data Platform 的初始化工具中。

### 6.3 Object Key 规范

Object Key 只表达稳定业务定位，不包含 Endpoint、Pod、Namespace 或
Provider 名称。建议格式：

```text
<domain>/<artifact-type>/<yyyy>/<mm>/<sha256>/<sanitized-filename>
```

例如：

```text
info/original/2026/06/0123...cdef/report.pdf
```

Key 生成必须由共享规则实现，并满足：

- 使用 `/` 作为层级分隔符。
- 文件名经过安全规范化，不能包含路径穿越片段。
- 同一版本写入后不可覆盖。
- 业务数据库不保存永久下载 URL。
- 下载使用 API 流式返回或短期 Presigned URL。

### 6.4 权威对象清单

对象本体存放在 S3，业务数据库保存权威清单。至少记录：

```text
bucket
object_key
version_id
sha256
size_bytes
content_type
created_at
storage_state
```

写入流程：

```text
计算 SHA-256 和大小
-> 上传对象
-> HeadObject 验证对象存在和大小
-> 保存对象清单
-> 对外发布可用状态
```

不得把 ETag 当作通用内容哈希，因为分段上传和不同 Provider 的 ETag
语义可能不同。

### 6.5 自动化约束

在 `tpl-app` 和实际 App 的 CI 中加入：

- [ ] 禁止业务代码引入 MinIO SDK。
- [ ] 扫描硬编码 Endpoint、Bucket、Access Key 和 Secret Key。
- [ ] 校验所有 S3 配置均由环境变量或 Secret 注入。
- [ ] 对 Adapter 运行统一 S3 契约测试。
- [ ] 测试上传、下载、Head、列表、删除和 Presigned URL。
- [ ] 测试普通上传和分段上传后的 SHA-256 一致性。
- [ ] 至少使用 Kind MinIO 和一种非 MinIO S3 实现执行兼容测试。

### 6.6 迁移校验

迁移工具必须以业务数据库中的对象清单为核验基准：

```text
建立目标 Bucket 和 Policy
-> 全量复制对象
-> 持续同步迁移期间增量
-> 比对对象数量和总字节数
-> 按清单核验 version_id、size 和 SHA-256
-> 暂停写入并完成最后增量
-> 切换 S3 配置
-> 执行业务读写验证
-> 保留旧存储回滚窗口
```

- 版本控制、对象锁、生命周期、CORS 和 Policy 必须单独迁移和核对。
- 迁移完成前不得删除旧对象。
- 迁移报告必须记录遗漏、冲突、重试和最终校验结果。

## 7. 实施任务

### O1. Data Platform 统一组件

- [x] 创建 `data-platform/object-storage` 目录。
- [x] 遵循现有统一部署模板建立部署脚本和配置文件。
- [x] 定义统一 S3 Endpoint、Region、Bucket、凭据和 TLS 配置契约。
- [x] 按集群映射选择 Kind 或远程 Provider。
- [x] 将组件注册到 `deploy-data-platform-all` 并配置部署优先级。
- [x] 将 Provider 特有部署与 App 级资源初始化分离。
- [ ] 不在业务代码中硬编码 MinIO 专有管理接口。
- [x] 定义 Provider 无关的对象存储资源声明 Schema。

### O2. Kind MinIO 实现

- [x] 固定官方 AIStor Operator 和 ObjectStore Helm Chart、镜像版本及来源信息。
- [x] 将所需镜像同步到 Harbor。
- [x] 提供 `dev-values-kind.yaml`。
- [x] 使用带 `Retain` 策略的静态 hostPath PV。
- [x] 配置 ClusterIP Service、资源限制和 Pod 安全上下文。
- [x] S3 API 和 Console 使用独立 ClusterIP Service，默认不公开暴露。
- [x] 明确 AIStor Free 单节点实现只承担开发和测试责任。
- [x] 导入 AIStor Free License，使 ObjectStore 完成调谐。
- [x] 验证 PVC 绑定、Pod Ready 和 S3 API。
- [x] 配置并验证 Console 的受控访问方式。

### O3. 远程 Provider 选型与接入

- [ ] 对云 S3、Ceph RGW 和受支持 MinIO 产品进行评估。
- [ ] 对比维护状态、许可证、成本、高可用、备份和团队运维能力。
- [ ] 通过 ADR 记录远程开发和生产环境的最终选择。
- [ ] Provider 必须满足平台统一 S3 配置契约。
- [ ] 生产环境不得默认使用已归档的 MinIO Community Chart。
- [ ] 若 Provider 由 Kubernetes 部署，按统一 Helm 模式纳入 Data Platform。
- [ ] 若使用外部云服务，Data Platform 负责连接配置和资源初始化，不伪装成本地 Helm 工作负载。

### O4. 持久化和可恢复性

- [x] Kind 环境提供带 `Retain` 策略的本地持久卷。
- [x] 验证 ObjectStore Pod 重建后对象和 SHA-256 保持不变。
- [ ] 明确 Kind 完整集群重建时的初始化、复用和恢复模式。
- [ ] 远程环境按 Provider 制定持久化与高可用方案。
- [ ] 制定 Bucket 版本控制和对象锁策略。
- [ ] 制定备份目标、保留周期和恢复演练流程。
- [ ] 验证删除 Pod、重新部署和节点故障后的数据恢复。

### O5. 安全基线

- [ ] Provider 管理凭据由受控 Secret 系统提供。
- [ ] 禁止业务 App 使用根凭据或平台管理凭据。
- [x] 每个 App 和环境创建独立服务身份。
- [x] Policy 只授予指定 Bucket 和必要操作。
- [x] Secret 只部署到对应 App Namespace。
- [x] 实现凭据轮换，并记录工作负载重新加载要求。
- [ ] 启用操作审计，并避免在日志中输出密钥。
- [ ] 通过 NetworkPolicy 限制管理接口和数据接口访问范围。

### O6. App 级资源自动初始化

职责分为两层：

```text
Data Platform object-storage provisioner
  -> 解释 Provider 无关的资源声明
  -> 创建 Bucket、版本控制、生命周期、Policy 和 Service Account
  -> 将连接配置和凭据下发到目标 Backend Namespace

Backend storage-access-bootstrap
  -> 声明该 Backend 承担的对象数据职责
  -> 调用平台 provisioner，不直接使用 MinIO 管理接口
  -> 将平台生成的 ConfigMap 和 Secret 接入 Backend 运行配置
```

平台 provisioner 是对象存储管理逻辑的唯一实现位置。`tpl-app` 的两个
Backend 只提供同结构的 `storage-access-bootstrap` 接入脚手架；未承担对象
数据职责的 Backend 保持禁用，不创建 Bucket 或凭据。

`info-app` 尚未从 `tpl-app` 实例化前，不预先创建其 Service Account，也不
猜测由 Admin Backend 或 Web Backend 承担原文写入。应在领域模块和唯一写入
Backend 确定后再提交首份资源声明。

- [x] 定义声明式 App 对象存储配置格式。
- [x] 实现幂等的创建、更新、检查和撤销脚本。
- [ ] 自动创建 Bucket、版本控制、生命周期和 Policy。（Bucket、版本控制和 Policy 已完成，生命周期待实现）
- [x] 自动创建或轮换 App 服务身份。
- [x] 自动生成对应 Kubernetes Secret 和 ConfigMap。
- [ ] 支持 `status` 和 `dry-run`。
- [x] 删除操作默认保留 Bucket 数据，普通流程不提供危险删除。
- [ ] 将初始化流程接入 App 或 Backend 的统一部署入口。
- [x] 在 `tpl-app` 两个 Backend 建立同级 `storage-access-bootstrap`，默认
      禁用，并为承担对象数据职责的 Backend 分配独立配置。

建议声明包含：

```text
app
component
environment
namespace
secret name
buckets
permissions
versioning
object lock
lifecycle
```

### O7. Info App 首次接入

- [ ] 为 Info App 声明 originals 和 derived Bucket。
- [ ] 为承担写入职责的唯一 Backend 分配凭据。
- [ ] 其他组件通过该 Backend API 读写，不直接共享凭据。
- [ ] Worker 复用所属 Backend 的数据职责和凭据。
- [ ] 验证上传、哈希校验、版本读取和受控删除。
- [ ] 验证 RAGFlow 只能接收处理副本，不能直接访问原始主档。
- [ ] 建立对象清单表，并以 SHA-256、大小和版本标识核验写入。
- [ ] 使用统一 Adapter，不引入 MinIO 专用 SDK。

### O8. 运维与可观测

- [ ] 接入指标、日志和告警。
- [ ] 监控容量、错误率、延迟、磁盘状态和副本健康。
- [ ] 配置容量阈值和扩容流程。
- [ ] 编写部署、升级、回滚、备份和恢复手册。
- [ ] 建立定期恢复演练记录。

### O9. Provider 迁移工具

- [ ] 实现对象全量复制和增量追赶。
- [ ] 读取业务数据库对象清单执行数量、大小和 SHA-256 核验。
- [ ] 导出并迁移版本控制、生命周期、CORS 和 Policy。
- [ ] 生成机器可读和人工可读的迁移报告。
- [ ] 支持切换前检查、切换后验证和回滚。

## 8. 推荐执行顺序

```text
1. 确定 S3 配置、Adapter 和对象清单契约
2. 建立 Data Platform object-storage 统一组件
3. 部署 Kind MinIO Provider
4. 建立 App 级 Bucket、Policy 和 Secret 初始化
5. 扩展 tpl-app 两个 Backend 模板
6. 在 Info App 实现对象清单和 S3 Adapter
7. 加入兼容性与静态检查
8. 实现迁移和校验工具
9. 评估并选定远程 Provider
10. 使用迁移工具完成远程演练
```

## 9. 验收标准

- [ ] Object Storage 可由 Data Platform 统一入口配置、检查和管理。
- [ ] Kind MinIO 可由统一入口部署、检查和卸载。
- [ ] Kind 环境重建工作负载后对象仍可恢复。
- [ ] App 使用统一 S3 配置即可在不同 Provider 间迁移。
- [ ] 两个 App 不能读取或列出彼此 Bucket。
- [ ] App 不持有 Provider 管理凭据。
- [ ] Info App 能使用独立凭据读写两个指定 Bucket。
- [ ] `info-originals` 的版本和不可变策略符合设计。
- [ ] 凭据可以轮换，旧凭据会被撤销。
- [ ] 备份可以实际恢复到测试环境。
- [ ] 平台对象存储的故障不会改变 RAGFlow 私有 MinIO 的数据边界。
- [ ] 业务代码中不存在 MinIO SDK 和 MinIO 专有管理调用。
- [ ] 对象清单可用于逐对象核验迁移结果。
- [ ] 同一套 Adapter 契约测试可以通过 Kind MinIO 和远程 Provider。

## 10. 暂不处理

- 跨地域多活。
- CDN 和公网匿名下载。
- 所有 App 的 Bucket 一次性创建。
- 将 RAGFlow 内部对象迁移到平台对象存储。
- 由浏览器持有长期访问密钥。

## 11. 关联文档

- [总体架构](../../../docs/sunmoonai-architecture/architecture/app-platform-architecture.md)
- [数据所有权](../data-ownership.md)
- [Info App](../info-app.md)
- [ADR-0004：对象存储按领域拥有和隔离](../adr/0004-object-storage-ownership.md)
- [ADR-0005：RAGFlow 定位为可重建的派生系统](../adr/0005-ragflow-as-derived-system.md)
