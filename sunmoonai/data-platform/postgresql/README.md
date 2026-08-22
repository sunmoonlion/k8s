# PostgreSQL 安全部署使用说明

## 📋 概述

本项目提供了PostgreSQL数据库的安全部署方案，使用Kubernetes Secret管理所有敏感信息，为Harbor等应用提供数据存储服务。

## 🏗️ 架构设计

### 组件关系
```
PostgreSQL (主数据库)
    ↓
Harbor (镜像仓库)
    ↓
其他应用组件
```

### 安全特性
- ✅ 所有密码使用Kubernetes Secret管理
- ✅ 支持密码轮换
- ✅ 自动创建Harbor用户和数据库
- ✅ 持久化存储支持

## 📁 目录结构

```
postgresql/
├── resources/
│   ├── postgresql/                    # PostgreSQL官方Chart
│   └── custom-values/
│       └── dev-values.yaml           # PostgreSQL自定义配置
├── deploy/
│   ├── deploy-postgresql.conf        # 部署配置
│   └── deploy-postgresql.sh          # 部署脚本
├── scripts/
│   └── create-postgresql-secrets.sh  # Secret创建脚本
└── README.md                         # 本文档
```

## 🔧 配置说明

### PostgreSQL配置 (`custom-values/dev-values.yaml`)

#### 认证配置
```yaml
# 使用Secret管理密码
auth:
  enabled: true
  existingSecret: "postgresql-secrets"
  existingSecretPasswordKey: "postgres-password"
  database: "sunmoonai_dev"
  username: "sunmoonai_dev"
```

#### 存储配置
```yaml
primary:
  persistence:
    enabled: true
    storageClass: "nfs-storage"
    size: "8Gi"
    accessModes:
      - "ReadWriteOnce"
```

#### 初始化脚本
```yaml
primary:
  env:
    - name: POSTGRES_PASSWORD
      valueFrom:
        secretKeyRef:
          name: postgresql-secrets
          key: postgres-password
    - name: HARBOR_PASSWORD
      valueFrom:
        secretKeyRef:
          name: postgresql-secrets
          key: harbor-password
  
  initdb:
    scripts:
      create-harbor-user.sql: |
        CREATE USER sunmoonai_harbor WITH PASSWORD '$HARBOR_PASSWORD';
        CREATE DATABASE sunmoonai_harbor OWNER sunmoonai_harbor;
        GRANT ALL PRIVILEGES ON DATABASE sunmoonai_harbor TO sunmoonai_harbor;
        GRANT CREATE ON SCHEMA public TO sunmoonai_harbor;
```

## 🚀 部署流程

### 前置条件

1. **Kubernetes集群**：版本 1.23+
2. **Helm**：版本 3.8.0+
3. **kubectl**：已配置集群访问
4. **存储类**：nfs-storage

### 部署步骤

#### 步骤1：创建Secret
```bash
cd ~/master/k8s/sunmoonai/data-platform/postgresql
./scripts/create-postgresql-secrets.sh
```

#### 步骤2：部署PostgreSQL
```bash
./deploy/deploy-postgresql.sh
```

#### 步骤3：验证部署
```bash
kubectl get pods -n data-platform-dev -l app.kubernetes.io/name=postgresql
kubectl get pvc -n data-platform-dev
```

## 🔐 Secret管理

### PostgreSQL Secrets
- **Secret名称**：`postgresql-secrets`
- **命名空间**：`data-platform-dev`

#### 包含的密码
| 键名 | 用途 | 默认值 |
|------|------|--------|
| `postgres-password` | PostgreSQL主密码 | SunMoonAI_PostgreSQL_2024! |
| `harbor-password` | Harbor用户密码 | SunMoonAI_PostgreSQL_2024! |
| `dev-password` | 开发用户密码 | sunmoonai_dev_2024! |

### 查看Secret内容
```bash
# 查看Secret列表
kubectl get secrets -n data-platform-dev | grep postgresql

# 查看Secret详情
kubectl get secret postgresql-secrets -n data-platform-dev -o yaml

# 解码密码
kubectl get secret postgresql-secrets -n data-platform-dev -o jsonpath='{.data.postgres-password}' | base64 -d
```

## 🌐 数据库访问

### 连接信息
- **主机**：postgresql-sunmoonai.data-platform-dev.svc.cluster.local
- **端口**：5432
- **主用户**：postgres
- **主密码**：SunMoonAI_PostgreSQL_2024!

### 创建的用户和数据库

#### Harbor用户
- **用户名**：sunmoonai_harbor
- **密码**：SunMoonAI_PostgreSQL_2024!
- **数据库**：sunmoonai_harbor
- **权限**：所有权限

#### 开发用户
- **用户名**：sunmoonai_dev
- **密码**：sunmoonai_dev_2024!
- **数据库**：sunmoonai_dev
- **权限**：所有权限

## 🔍 验证部署

### 检查Pod状态
```bash
kubectl get pods -n data-platform-dev -l app.kubernetes.io/name=postgresql
```

### 检查服务
```bash
kubectl get svc -n data-platform-dev -l app.kubernetes.io/name=postgresql
```

### 检查存储
```bash
kubectl get pvc -n data-platform-dev
```

### 测试数据库连接
```bash
# 进入PostgreSQL容器
kubectl exec -it postgresql-sunmoonai-0 -n data-platform-dev -- bash

# 连接数据库
psql -U postgres

# 查看数据库列表
\l

# 查看用户列表
\du

# 退出
\q
```

## 🛠️ 维护操作

### 密码轮换

#### 更新PostgreSQL主密码
```bash
kubectl patch secret postgresql-secrets -n data-platform-dev \
  --type='json' \
  -p='[{"op": "replace", "path": "/data/postgres-password", "value": "'$(echo "新密码" | base64)'"}]'

# 重启PostgreSQL Pod
kubectl rollout restart deployment postgresql-sunmoonai -n data-platform-dev
```

#### 更新Harbor用户密码
```bash
kubectl patch secret postgresql-secrets -n data-platform-dev \
  --type='json' \
  -p='[{"op": "replace", "path": "/data/harbor-password", "value": "'$(echo "新密码" | base64)'"}]'
```

### 备份恢复

#### 备份数据库
```bash
# 备份所有数据库
kubectl exec postgresql-sunmoonai-0 -n data-platform-dev -- pg_dumpall -U postgres > postgresql-backup.sql

# 备份Harbor数据库
kubectl exec postgresql-sunmoonai-0 -n data-platform-dev -- pg_dump -U sunmoonai_harbor sunmoonai_harbor > harbor-backup.sql
```

#### 恢复数据库
```bash
# 恢复所有数据库
kubectl exec -i postgresql-sunmoonai-0 -n data-platform-dev -- psql -U postgres < postgresql-backup.sql

# 恢复Harbor数据库
kubectl exec -i postgresql-sunmoonai-0 -n data-platform-dev -- psql -U sunmoonai_harbor sunmoonai_harbor < harbor-backup.sql
```

### 扩容操作

#### 增加存储空间
```bash
# 编辑PVC
kubectl edit pvc data-postgresql-sunmoonai-0 -n data-platform-dev

# 修改size字段
# 例如：从8Gi改为16Gi
```

## 🚨 故障排除

### 常见问题

#### 1. PostgreSQL无法启动
```bash
# 检查Pod日志
kubectl logs -n data-platform-dev postgresql-sunmoonai-0

# 检查事件
kubectl get events -n data-platform-dev --sort-by='.lastTimestamp'
```

#### 2. 存储问题
```bash
# 检查PVC状态
kubectl get pvc -n data-platform-dev

# 检查存储类
kubectl get storageclass
```

#### 3. 数据库连接失败
```bash
# 检查服务状态
kubectl get svc -n data-platform-dev -l app.kubernetes.io/name=postgresql

# 测试网络连接
kubectl run test-pod --image=postgres:13 --rm -it --restart=Never -- psql -h postgresql-sunmoonai.data-platform-dev.svc.cluster.local -U postgres
```

#### 4. Secret问题
```bash
# 检查Secret是否存在
kubectl get secret postgresql-secrets -n data-platform-dev

# 检查Secret内容
kubectl describe secret postgresql-secrets -n data-platform-dev
```

## 📊 监控配置

### 启用监控（可选）
```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

### 查看指标
```bash
# 获取指标端点
kubectl get svc postgresql-sunmoonai-metrics -n data-platform-dev

# 查看指标
kubectl port-forward svc/postgresql-sunmoonai-metrics 9187:9187 -n data-platform-dev
curl http://localhost:9187/metrics
```

## 📚 相关文档

- [PostgreSQL官方文档](https://www.postgresql.org/docs/)
- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [Harbor组件文档](../../cicd-platform/harbor/README.md)

## 🔄 版本历史

- **v1.0.0**：初始版本，支持基本PostgreSQL部署
- **v1.1.0**：添加Secret管理，提高安全性
- **v1.2.0**：集成Harbor用户和数据库自动创建

## 📞 支持

如有问题，请联系：
- 项目维护者：SunMoonAI团队
- 文档更新：2024年10月

---

**注意**：本部署方案适用于生产环境，请确保在生产部署前进行充分测试。
