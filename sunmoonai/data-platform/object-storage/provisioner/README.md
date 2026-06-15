# S3 资源 Provisioner

## 1. 定位

Provisioner 是 Data Platform 中唯一负责对象存储管理操作的组件。它根据
Provider 无关的 JSON 声明，在当前环境的 S3 Provider 中创建并维护：

- Bucket；
- Bucket 版本控制；
- 最小权限 IAM Policy；
- Backend 专用 IAM 用户和访问密钥；
- 目标 Namespace 中的 Kubernetes Secret 和 ConfigMap。

Backend 不直接使用 AIStor 或 MinIO 管理命令，只消费 Provisioner 下发的
标准 S3 配置。

## 2. 声明文件

参考：

```text
declarations/example-backend.json
```

JSON Schema：

```text
schema/object-storage-access.schema.json
```

声明文件只保存资源、权限和目标 Namespace，不保存 Access Key 或 Secret
Key。Bucket 权限支持：

```text
read
write
delete
list
```

当前删除策略固定为：

```json
"deletionPolicy": "Retain"
```

回收访问权限时不会删除 Bucket 或对象数据。

## 3. 命令

在 `k8s` 仓库根目录执行。

### 校验声明

```bash
./sunmoonai/data-platform/object-storage/provisioner/object-storage-provisioner.sh \
  validate DECLARATION.json
```

### 创建或更新

```bash
./sunmoonai/data-platform/object-storage/provisioner/object-storage-provisioner.sh \
  --cluster KIND provision DECLARATION.json
```

`provision` 可以重复执行：

- 已存在的 Bucket 保持不变；
- Policy 根据声明更新；
- 已存在且有 Secret 的 IAM 用户复用当前凭据；
- 缺少用户或 Secret 时重新生成凭据；
- Secret 和 ConfigMap 使用声明式更新。

远程开发集群使用同一命令并切换集群参数，例如：

```bash
./sunmoonai/data-platform/object-storage/provisioner/object-storage-provisioner.sh \
  --cluster C1 provision DECLARATION.json
```

Kind 和远程集群均通过目标集群内的短生命周期管理 Job 访问 Object Storage
Service。两种模式使用相同的声明、Bucket、Policy 和凭据下发流程。

### 查看状态

```bash
./sunmoonai/data-platform/object-storage/provisioner/object-storage-provisioner.sh \
  --cluster KIND status DECLARATION.json
```

状态检查包含 IAM 用户、Policy、Bucket 和版本控制。

### 轮换凭据

```bash
./sunmoonai/data-platform/object-storage/provisioner/object-storage-provisioner.sh \
  --cluster KIND rotate DECLARATION.json
```

轮换会生成新 Secret Key、更新 AIStor IAM 用户，并更新目标 Kubernetes
Secret。使用该 Secret 的工作负载需要重新加载配置或滚动重启。

### 回收访问权限

```bash
./sunmoonai/data-platform/object-storage/provisioner/object-storage-provisioner.sh \
  --cluster KIND teardown DECLARATION.json
```

该命令删除 IAM 用户、Policy、目标 Secret 和 ConfigMap，但保留 Bucket 和
全部对象。即使目标 Secret 已被手工删除，仍可根据声明回收 IAM 资源。

## 4. Backend 运行配置

Provisioner 在声明指定的 Namespace 中创建两个同名资源。

Secret：

```text
S3_ACCESS_KEY_ID
S3_SECRET_ACCESS_KEY
```

ConfigMap：

```text
S3_ENDPOINT
S3_REGION
S3_BUCKET
S3_BUCKETS
S3_FORCE_PATH_STYLE
S3_USE_TLS
```

`S3_BUCKET` 是声明中的第一个 Bucket，适用于只使用单一主 Bucket 的 SDK
配置。`S3_BUCKETS` 是全部 Bucket 的逗号分隔清单。

Backend Deployment 可使用 `envFrom` 同时引用 ConfigMap 和 Secret。Frontend
不得引用这些资源。

## 5. 安全约束

- 平台根凭据只挂载到短生命周期管理 Job。
- 应用密钥不会写入声明、日志或命令行参数。
- 临时管理 Secret、ConfigMap 和 Job 在命令结束后自动清理。
- 每个声明生成独立 IAM 用户和 Policy。
- Policy 只授权声明中的 Bucket 和操作。
- 业务 Backend 不使用平台根账号。
- Bucket 删除不属于普通 `teardown` 流程。

## 6. 当前限制

- 当前执行适配器面向平台自建 AIStor，支持 Kind 和部署相同 AIStor 拓扑的远程开发集群。
- 切换到公有云或其他 S3 Provider 时，需要为其 IAM 管理接口增加 Provider 适配器；Backend 的标准 S3 运行配置不需要改变。
- 生命周期规则和对象锁状态检查尚未实现。
- 暂无 `dry-run` 和凭据撤销宽限期。
