# Harbor 数据库配置指南

## 概述

本文档说明Harbor的两种数据库配置方案：
1. **内置数据库方案**：使用Harbor Chart内置的PostgreSQL和Redis
2. **外部数据库方案**：使用外部PostgreSQL和Redis实例

---

## 方案一：内置数据库配置

### 1.1 启用内置数据库

在 `dev-values.yaml` 中配置：

```yaml
# ============================================================================
# 内置数据库配置（PostgreSQL）
# ============================================================================
postgresql:
  enabled: true
  # 优化PostgreSQL内存配置
  primary:
    resources:
      limits:
        memory: "512Mi"  # 限制最大内存使用
      requests:
        memory: "256Mi"  # 请求最小内存
    persistence:
      enabled: true
      storageClass: "nfs-storage"
      size: "8Gi"
      accessModes:
        - ReadWriteOnce

# ============================================================================
# 内置缓存配置（Redis）
# ============================================================================
redis:
  enabled: true
  # 优化Redis内存配置
  master:
    resources:
      limits:
        memory: "256Mi"  # 限制最大内存使用
      requests:
        memory: "128Mi"  # 请求最小内存
    persistence:
      enabled: true
      storageClass: "nfs-storage"
      size: "8Gi"
      accessModes:
        - ReadWriteOnce

# 禁用外部数据库配置
# externalDatabase: ...
# externalRedis: ...
```

### 1.2 修改内置数据库镜像

**注意**：通过 `dev-values.yaml` 配置镜像的方法在Harbor Chart中不生效，必须直接修改子Chart的配置文件。

#### 修改PostgreSQL镜像

直接编辑PostgreSQL子Chart的配置文件：

```bash
# 编辑PostgreSQL子Chart的values.yaml
vim ~/k8s/sunmoonai/cicd-platform/harbor/resources/harbor/charts/postgresql/values.yaml
```

找到并修改镜像配置：

```yaml
image:
  registry: docker.io
  repository: bitnami/postgresql
  tag: 16.7.0-debian-12-r0  # 修改为所需版本
  digest: ""
  pullPolicy: IfNotPresent
```

#### 修改Redis镜像

直接编辑Redis子Chart的配置文件：

```bash
# 编辑Redis子Chart的values.yaml
vim ~/k8s/sunmoonai/cicd-platform/harbor/resources/harbor/charts/redis/values.yaml
```

找到并修改镜像配置：

```yaml
image:
  registry: docker.io
  repository: bitnami/redis
  tag: 8.2.1-debian-12-r0  # 修改为所需版本
  digest: ""
  pullPolicy: IfNotPresent
```

#### 为什么dev-values.yaml配置不生效？

Harbor Chart的子Chart（PostgreSQL和Redis）有自己的默认配置，`dev-values.yaml` 中的镜像配置会被子Chart的默认配置覆盖。因此必须直接修改子Chart的配置文件。


### 1.4 内置数据库的优势

- ✅ **简化部署**：无需管理外部数据库
- ✅ **网络隔离**：数据库只在集群内部通信
- ✅ **统一管理**：与Harbor组件在同一命名空间
- ✅ **自动配置**：Harbor自动处理数据库初始化
- ✅ **资源优化**：内存占用约450-600MB

---

## 方案二：外部数据库配置

### 2.1 外部PostgreSQL配置

#### 使用Secret管理密码（推荐）

```yaml
# 禁用内置PostgreSQL
postgresql:
  enabled: false

# 配置外部PostgreSQL
externalDatabase:
  host: "postgresql-sunmoonai.data-platform-dev.svc.cluster.local"
  port: 5432
  user: "harbor_user"
  password: ""  # 留空，使用Secret
  existingSecret: "postgresql-secrets"  # 使用Kubernetes Secret
  existingSecretPasswordKey: "harbor-password"  # Secret中的密码键
  sslmode: "disable"
  coreDatabase: "harbor_core"
  notaryServerDatabase: "harbor_notary_server"
  notarySignerDatabase: "harbor_notary_signer"
```

#### 创建PostgreSQL Secret

**步骤1：在数据平台命名空间创建Secret**

```bash
# 使用现有的PostgreSQL Secret创建脚本
cd ~/k8s/sunmoonai/data-platform/postgresql/scripts
./create-postgresql-secrets.sh
```

**步骤2：复制Secret到Harbor命名空间**

```bash
# 从data-platform-dev命名空间复制Secret到cicd-platform-dev命名空间
kubectl get secret postgresql-secrets -n data-platform-dev -o yaml | \
  sed 's/namespace: data-platform-dev/namespace: cicd-platform-dev/' | \
  kubectl apply -f -
```

**步骤3：验证Secret复制成功**

```bash
# 验证Secret已复制到Harbor命名空间
kubectl get secret postgresql-secrets -n cicd-platform-dev

# 验证Secret内容
kubectl get secret postgresql-secrets -n cicd-platform-dev -o jsonpath='{.data.harbor-password}' | base64 -d
```

### 2.2 外部Redis配置

#### 使用明文密码（Bitnami Chart要求）

```yaml
# 禁用内置Redis
redis:
  enabled: false

# 配置外部Redis
externalRedis:
  host: "redis-sunmoonai-master.data-platform-dev.svc.cluster.local"
  port: 6379
  password: "SunMoonAI_Redis_2024!"  # 明文密码（Bitnami Chart要求）
  coreDatabaseIndex: "0"
  jobserviceDatabaseIndex: "1"
```


**注意**：Bitnami Redis Chart存在已知问题，使用Secret会导致连接失败，因此必须使用明文密码。

### 2.3 外部数据库的完整配置示例

```yaml
# ============================================================================
# 外部数据库配置
# ============================================================================

# 禁用内置PostgreSQL
postgresql:
  enabled: false

# 禁用内置Redis
redis:
  enabled: false

# 外部PostgreSQL配置（使用Secret）
externalDatabase:
  host: "postgresql-sunmoonai.data-platform-dev.svc.cluster.local"
  port: 5432
  user: "harbor_user"
  password: ""  # 留空，使用Secret
  existingSecret: "postgresql-secrets"
  existingSecretPasswordKey: "harbor-password"
  sslmode: "disable"
  coreDatabase: "harbor_core"
  notaryServerDatabase: "harbor_notary_server"
  notarySignerDatabase: "harbor_notary_signer"

# 外部Redis配置（使用明文密码）
externalRedis:
  host: "redis-sunmoonai-master.data-platform-dev.svc.cluster.local"
  port: 6379
  password: "SunMoonAI_Redis_2024!"  # 明文密码
  coreDatabaseIndex: "0"
  jobserviceDatabaseIndex: "1"
```

### 2.4 外部数据库的优势

- ✅ **独立扩展**：数据库可以独立扩展
- ✅ **高可用**：可以使用外部高可用数据库
- ✅ **资源共享**：多个应用可以共享数据库
- ✅ **专业管理**：可以使用专业的数据库管理工具

---

## 配置对比

| 特性 | 内置数据库 | 外部数据库 |
|------|------------|------------|
| **部署复杂度** | 简单 | 复杂 |
| **内存占用** | +450-600MB | 无额外占用 |
| **网络安全** | 高（集群内部） | 中等（需要网络访问） |
| **扩展性** | 有限 | 高 |
| **高可用** | 依赖Kubernetes | 可独立配置 |
| **管理复杂度** | 低 | 高 |
| **密码管理** | 自动 | 需要手动管理 |

---

## 推荐方案

### 小到中等规模部署
**推荐：内置数据库**
- 部署简单
- 管理方便
- 安全性高
- 资源占用合理

### 大规模部署
**推荐：外部数据库**
- 独立扩展
- 高可用性
- 资源共享
- 专业管理

---

## 注意事项

1. **跨命名空间Secret管理**：
   - Harbor在 `cicd-platform-dev` 命名空间
   - 外部数据库在 `data-platform-dev` 命名空间
   - 需要将Secret从数据平台命名空间复制到Harbor命名空间

2. **看似冗余的Secret复制**：
   - 部署脚本会自动复制 `postgresql-secrets` 和 `redis-secrets` 到Harbor命名空间
   - 即使使用内置数据库，这些Secret也会被复制（但不会被使用）
   - 这是**无害的冗余**：不影响内置数据库运行，不占用计算资源
   - 好处：保持脚本逻辑统一，为将来切换到外部数据库做准备

3. **Redis密码**：外部Redis必须使用明文密码，Bitnami Chart不支持Secret

4. **PostgreSQL密码**：外部PostgreSQL推荐使用Secret管理

5. **网络连通性**：外部数据库需要确保网络连通性

6. **数据库初始化**：外部数据库需要手动创建数据库和用户

7. **备份策略**：外部数据库需要独立的备份策略

8. **Secret同步**：当外部数据库密码更新时，需要同步更新Harbor命名空间中的Secret

---

## 故障排除

### 内置数据库问题
- 检查PVC是否正确创建
- 检查资源限制是否合理
- 检查镜像版本是否兼容

### 外部数据库问题
- 检查网络连通性
- 检查密码配置
- 检查数据库权限
- 检查Secret配置

---

## 总结

选择合适的数据库配置方案需要考虑：
- 部署规模
- 安全要求
- 管理复杂度
- 扩展需求
- 资源限制

内置数据库适合大多数场景，外部数据库适合大规模或特殊需求场景。

### 部署脚本设计说明

部署脚本采用**统一处理**的设计：
- 无论使用内置还是外部数据库，都会复制相关Secret
- 使用内置数据库时，复制的Secret不会被使用（无害冗余）
- 使用外部数据库时，复制的Secret会被使用
- 这样设计的好处：代码逻辑统一，无需为不同场景写不同逻辑
