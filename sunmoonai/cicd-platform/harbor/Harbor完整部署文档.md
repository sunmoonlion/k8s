# Harbor 完整部署文档

## 文档信息

- **创建日期**: 2025-10-05
- **Harbor 版本**: 2.13.2 (Bitnami Chart)
- **部署环境**: Kubernetes 集群 (sunmoonai)
- **命名空间**: cicd-platform-dev

---

## 目录

1. [架构概述](#架构概述)
2. [部署配置](#部署配置)
3. [访问信息](#访问信息)
4. [配置文件详解](#配置文件详解)
5. [典型部署问题案例](#典型部署问题案例)
6. [故障排查](#故障排查)
7. [维护操作](#维护操作)
8. [常见问题](#常见问题)

---

## 架构概述

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      客户端（浏览器/Docker）                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
                 http://harbor.sunmoonai.local:30090
                              ↓
┌─────────────────────────────────────────────────────────────┐
│           Traefik Ingress Controller (NodePort 30090)        │
│              路由规则: Host(`harbor.sunmoonai.local`)         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              Harbor Service (ClusterIP: 10.101.8.2)          │
└─────────────────────────────────────────────────────────────┘
                              ↓
        ┌────────────────────┴────────────────────┐
        ↓                    ↓                     ↓
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Harbor Nginx │    │ Harbor Core  │    │Harbor Portal │
│  (前端代理)   │    │   (核心服务)  │    │  (Web界面)   │
└──────────────┘    └──────────────┘    └──────────────┘
                            ↓
        ┌───────────────────┴───────────────────┐
        ↓                                       ↓
┌──────────────────────┐          ┌──────────────────────┐
│  PostgreSQL (外部)    │          │    Redis (外部)       │
│  数据库存储           │          │    缓存服务           │
│  data-platform-dev   │          │  data-platform-dev   │
└──────────────────────┘          └──────────────────────┘
```

### 组件说明

| 组件 | 作用 | 部署方式 | 副本数 | 架构 |
|------|------|----------|--------|------|
| **Harbor Nginx** | 前端反向代理，处理 HTTP 请求 | Deployment | 1 | - |
| **Harbor Core** | 核心 API 服务，处理业务逻辑 | Deployment | 1 | - |
| **Harbor Portal** | Web UI 前端页面 | Deployment | 1 | - |
| **Harbor Registry** | 镜像存储服务 (Docker Registry v2) | Deployment | 1 | - |
| **Harbor JobService** | 异步任务处理（复制、扫描等） | Deployment | 1 | - |
| **Harbor Trivy** | 镜像安全扫描服务 | StatefulSet | 1 | - |
| **PostgreSQL** | 外部数据库（data-platform-dev） | StatefulSet | 1 | 单实例 |
| **Redis** | 外部缓存（data-platform-dev） | StatefulSet | 主1+从N | 主从复制 |

### 外部数据服务架构说明

#### PostgreSQL：单实例架构

```
postgresql-sunmoonai-0 (唯一实例)
  ↓
postgresql-sunmoonai.svc.cluster.local
```

**特点**：
- ✅ 简单、轻量，适合开发环境
- ✅ 持久化存储（NFS PVC 8Gi）
- ❌ 无高可用（单点故障风险）
- ❌ 无读写分离

**配置来源**：`readReplicas.enabled: false`（dev-values.yaml）

**服务名称**：无后缀，直接使用 `postgresql-sunmoonai`

#### Harbor Chart 的 PostgreSQL 配置差异

| 配置方式 | Harbor Chart 行为 | 数据库/用户创建 | 是否需要手动干预 |
|---------|------------------|----------------|-----------------|
| **内置 PostgreSQL** | `postgresql.enabled: true` | ✅ 自动创建 `harbor` 数据库和 `bn_harbor` 用户 | ❌ 无需干预 |
| **外部 PostgreSQL** | `postgresql.enabled: false` + `externalDatabase.*` | ❌ 不会自动创建 | ✅ 必须手动创建 |

**内置 PostgreSQL 的自动创建**：
- Harbor Chart 会自动部署 PostgreSQL 子 Chart
- 自动创建 `harbor` 数据库
- 自动创建 `bn_harbor` 用户和随机密码
- 通过 Secret 将凭证提供给 Harbor 组件

**外部 PostgreSQL 的自动创建（推荐）**：
- 使用 Bitnami PostgreSQL Chart 的 `initdbScripts` 功能
- 在 PostgreSQL 初始化时自动创建 Harbor 用户和数据库
- 无需手动干预，完全自动化

**外部 PostgreSQL 的手动创建（传统方式）**：
- Harbor Chart 假设外部数据库已准备好
- 需要手动创建 Harbor 专用用户和数据库
- 需要确保用户有足够的权限

**Harbor 如何知道使用外部数据库**：
1. **配置传递**：Harbor Chart 读取 `externalDatabase` 配置
2. **环境变量注入**：将数据库连接信息注入到 Harbor 组件
3. **自动连接**：Harbor 组件启动时自动连接到外部数据库

**环境变量示例**：
```yaml
# Harbor Core 组件会收到这些环境变量
POSTGRESQL_HOST: "postgresql-sunmoonai.data-platform-dev.svc.cluster.local"
POSTGRESQL_PORT: "5432"
POSTGRESQL_USERNAME: "sunmoonai_harbor"
POSTGRESQL_DATABASE: "sunmoonai_harbor"
POSTGRESQL_SSLMODE: "disable"
```

#### 使用 PostgreSQL initdbScripts 自动创建 Harbor 用户和数据库（推荐）

**优势**：
- ✅ **完全自动化**：无需手动创建用户和数据库
- ✅ **部署一致性**：每次部署都会自动创建
- ✅ **减少错误**：避免手动操作导致的配置错误
- ✅ **易于维护**：配置集中管理

**配置方法**：

在 PostgreSQL Chart 的 `values.yaml` 中添加：

```yaml
# PostgreSQL Chart 配置
postgresql:
  initdbScripts:
    create-harbor-user.sql: |
      CREATE USER sunmoonai_harbor WITH PASSWORD 'SunMoonAI_PostgreSQL_2024!';
      CREATE DATABASE sunmoonai_harbor OWNER sunmoonai_harbor;
      GRANT ALL PRIVILEGES ON DATABASE sunmoonai_harbor TO sunmoonai_harbor;
```

**部署顺序**：
1. **先部署 PostgreSQL**：使用包含 `initdbScripts` 的配置
2. **再部署 Harbor**：使用 `externalDatabase` 配置连接外部数据库

**验证自动创建**：
```bash
# 检查 Harbor 用户是否已创建
kubectl exec -n data-platform-dev postgresql-sunmoonai-0 -- \
  env PGPASSWORD="SunMoonAI_PostgreSQL_2024!" \
  psql -U postgres -c "\du" | grep sunmoonai_harbor

# 检查 Harbor 数据库是否已创建
kubectl exec -n data-platform-dev postgresql-sunmoonai-0 -- \
  env PGPASSWORD="SunMoonAI_PostgreSQL_2024!" \
  psql -U postgres -c "\l" | grep sunmoonai_harbor
```

#### Redis：主从复制架构

```
redis-sunmoonai-master-0 (主节点，读写)
  ↓
redis-sunmoonai-master.svc.cluster.local  ← Harbor 连接此服务

redis-sunmoonai-replicas-0 (从节点，只读)
redis-sunmoonai-replicas-1 (从节点，只读)
  ↓
redis-sunmoonai-replicas.svc.cluster.local
```

**特点**：
- ✅ 高可用（主节点故障可切换）
- ✅ 读写分离（主节点写，从节点读）
- ✅ 数据冗余（多副本）
- ⚠️ 资源占用更多（多个实例）

**配置来源**：`architecture: replication`（Bitnami Redis Chart 默认）

**服务名称**：有 `-master` 后缀，区分主从角色

**为什么选择不同架构？**

1. **PostgreSQL 选择单实例**：
   - 开发环境，无需高可用
   - 数据持久化存储，不易丢失
   - 节省资源（主从至少需要 2 倍资源）
   - Harbor 数据量不大，单实例足够

2. **Redis 选择主从架构**：
   - 内存数据库，数据丢失影响大
   - 缓存场景，需要高可用保证服务不中断
   - 读多写少，主从可以分担读压力
   - Bitnami Chart 默认启用主从复制

**重要提示**：Harbor 必须连接到 Redis 主节点（`redis-sunmoonai-master`），因为需要执行写操作（缓存更新、删除等）。从节点（`redis-sunmoonai-replicas`）是只读的，无法满足 Harbor 的需求。

---

## 部署配置

### 前置要求

#### 控制平面节点 DNS 解析配置

**重要提示**：Harbor 部署脚本会在控制平面节点上检查 Harbor API 是否就绪，因此**必须在控制平面节点上配置 Harbor 域名的 DNS 解析**。

**配置方法**：

1. **通过 infrastructure 部署脚本自动配置（推荐）**：
   - 在 `deploy-infrastructure-all.conf` 中确保以下配置：
     ```bash
     STEP11_ENABLED=true
     STEP11_ENABLE_HARBOR_DNS=true
     STEP11_TARGET=all  # 确保在所有节点（包括控制平面）上设置
     STEP11_HARBOR_DOMAIN="harbor.sunmoonai.com"
     STEP11_HARBOR_IP="<Harbor服务IP>"
     ```
   - 运行 `step11_load-initial-images.sh` 会自动在所有节点（包括控制平面节点）的 `/etc/hosts` 中添加 Harbor 域名映射

2. **手动配置**：
   如果 infrastructure 部署已完成，可以手动在控制平面节点上添加：
   ```bash
   # 在控制平面节点上执行
   echo "<Harbor服务IP> harbor.sunmoonai.com" | sudo tee -a /etc/hosts
   ```

**验证方法**：
```bash
# 在控制平面节点上验证
ssh <control-plane-node> "grep harbor.sunmoonai.com /etc/hosts"
```

**为什么需要这个配置**：
- Harbor 部署脚本使用 `wait_for_harbor_ready` 函数在控制平面节点上通过 SSH 执行 curl 检查 Harbor API
- 如果控制平面节点无法解析 `harbor.sunmoonai.com`，会导致脚本一直等待 Harbor API 启动
- 控制平面节点上的 `/etc/hosts` 配置确保域名解析正常

### 1. 配置文件位置

```bash
# Harbor 部署脚本
~/master/k8s/sunmoonai/cicd-platform/harbor/deploy/deploy-harbor.sh

# Harbor 配置文件
~/master/k8s/sunmoonai/cicd-platform/harbor/deploy/deploy-harbor.conf

# Harbor Helm Values
~/master/k8s/sunmoonai/cicd-platform/harbor/resources/custom-values/dev-values.yaml

# Traefik 路由配置
~/master/k8s/sunmoonai/ingress-platform/ingress/cicd-platform/harbor/web-routes/harbor-web-route.yaml
~/master/k8s/sunmoonai/ingress-platform/ingress/cicd-platform/harbor/web-routes/harbor-middleware.yaml
```

### 2. 关键配置参数

#### deploy-harbor.conf

```bash
# 项目和命名空间
HARBOR_PROJECT_ID="sunmoonai"
HARBOR_NAMESPACE="cicd-platform-dev"
ENVIRONMENT="development"

# 访问配置
HARBOR_EXTERNAL_HOST="harbor.example.com"
HARBOR_EXTERNAL_PORT="80"
HARBOR_TLS_ENABLED="false"

# 代理缓存配置
PROXY_CACHE_ENABLE="true"
PROXY_DOCKER_IO_PATH="/proxy-docker"
PROXY_K8S_IO_PATH="/proxy-k8s"
```

#### dev-values.yaml 核心配置

```yaml
# 外部访问 URL
externalURL: http://harbor.sunmoonai.local:30090

# 管理员密码（Bitnami Chart 会自动生成随机密码，此配置无效）
# adminPassword: "Harbor@12345"  # 此配置会被忽略

# TLS 禁用（HTTP 模式）
tls:
  enabled: false

nginx:
  tls:
    enabled: false

# 外部 PostgreSQL
postgresql:
  enabled: false

externalDatabase:
  host: "postgresql-sunmoonai.data-platform-dev.svc.cluster.local"
  port: 5432
  user: "sunmoonai_harbor"
  password: "SunMoonAI_PostgreSQL_2024!"
  sslmode: "disable"
  coreDatabase: "sunmoonai_harbor"

# 外部 Redis
redis:
  enabled: false

externalRedis:
  host: "redis-sunmoonai-master.data-platform-dev.svc.cluster.local"
  port: 6379
  password: "SunMoonAI_Redis_2024!"
  coreDatabaseIndex: "0"
  jobserviceDatabaseIndex: "1"
  registryDatabaseIndex: "2"
  trivyAdapterDatabaseIndex: "5"
```

#### Traefik IngressRoute

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: harbor-web
  namespace: cicd-platform-dev
spec:
  entryPoints:
    - web
    - websecure
  routes:
    - match: Host(`harbor.sunmoonai.local`)
      kind: Rule
      services:
        - name: sunmoonai-harbor
          port: http
```

### 3. 部署命令

```bash
# 部署 Harbor
cd ~/master/k8s/sunmoonai/cicd-platform/harbor/deploy
./deploy-harbor.sh deploy

# 升级 Harbor
./deploy-harbor.sh upgrade

# 查看状态
./deploy-harbor.sh status

# 查看日志
./deploy-harbor.sh logs

# 卸载 Harbor
./deploy-harbor.sh uninstall
```

### 4. 部署 Traefik 路由

```bash
cd ~/master/k8s/sunmoonai/ingress-platform/ingress/cicd-platform/harbor/web-routes

# 部署路由
bash deploy.sh apply

# 删除路由
bash deploy.sh delete
```

---

## 访问信息

### Web 界面访问

**访问地址**: http://harbor.sunmoonai.local:30090

> **重要**: 需要先配置本地 hosts 文件（见下文配置步骤）

**登录凭据**:
- **用户名**: `admin`
- **密码**: 需要通过以下命令获取（Bitnami Chart 自动生成）

### 获取管理员密码

> **重要**: 即使你在 `values.yaml` 中设置了 `adminPassword`，Harbor 实际使用的可能是自动生成的密码。

```bash
# 方法1：从 Harbor Core Pod 环境变量获取
kubectl exec -n cicd-platform-dev \
  $(kubectl get pod -n cicd-platform-dev -l app.kubernetes.io/component=core --no-headers | head -1 | awk '{print $1}') \
  -- env | grep HARBOR_ADMIN_PASSWORD

# 方法2：从 Kubernetes Secret 获取（推荐）
kubectl get secret sunmoonai-harbor-core -n cicd-platform-dev \
  -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d
```

**常见问题**：
- 如果设置了 `adminPassword` 但登录失败，说明 Harbor 使用的是自动生成的密码
- 使用上述命令获取实际密码，而不是 `values.yaml` 中设置的密码

> **重要**: 首次登录后请立即修改密码
> 1. 点击右上角头像
> 2. 选择 "Change Password"
> 3. 设置新密码

### 配置本地 Hosts 文件

在访问 Harbor 之前，需要在本地电脑上配置 hosts 文件：

#### Windows 系统

1. 以**管理员身份**运行记事本
2. 打开文件：`C:\Windows\System32\drivers\etc\hosts`
3. 在文件末尾添加：
   ```
   101.126.151.0  harbor.sunmoonai.local
   ```
4. 保存文件

#### Linux/Mac 系统

```bash
sudo sh -c 'echo "101.126.151.0  harbor.sunmoonai.local" >> /etc/hosts'
```

#### 验证配置

```bash
ping harbor.sunmoonai.local
# 应该解析到 101.126.151.0
```

### Docker 客户端访问

#### 认证方式说明

Harbor 支持多种认证方式，不同方式下的登录方法略有不同：

| 认证方式 | Web 登录 | Docker 登录 | 是否共用密码 | 备注 |
|---------|----------|-------------|-------------|------|
| **本地用户（默认）** | ✅ 同密码 | ✅ 同密码 | ✅ 一样 | 推荐方式 |
| **LDAP** | ✅ LDAP 密码 | ✅ LDAP 密码 | ✅ 一样 | 企业环境 |
| **OIDC** | ✅ OIDC 登录 | ❌ 需要 CLI Secret | ❌ 不一样 | 需要生成令牌 |

#### 使用 Docker

**本地用户认证（默认方式）**：
```bash
# 登录 Harbor（使用与 Web UI 相同的用户名和密码）
docker login harbor.sunmoonai.local:30090
# 输入用户名: admin
# 输入密码: <与 Web UI 相同的密码>

# 标记镜像
docker tag myimage:latest harbor.sunmoonai.local:30090/library/myimage:latest

# 推送镜像
docker push harbor.sunmoonai.local:30090/library/myimage:latest

# 拉取镜像
docker pull harbor.sunmoonai.local:30090/library/myimage:latest
```

**OIDC 认证（如果启用）**：
```bash
# 1. 在 Harbor Web UI 中生成 CLI Secret
# 用户资料 → CLI Secret → 生成新令牌

# 2. 使用 CLI Secret 登录
docker login harbor.sunmoonai.local:30090 -u <用户名> -p <CLI Secret Token>
```

#### 使用 nerdctl（推荐）

**本地用户认证（默认方式）**：
```bash
# 登录 Harbor（使用与 Web UI 相同的用户名和密码）
sudo nerdctl login harbor.sunmoonai.local:30090
# 输入用户名: admin
# 输入密码: <与 Web UI 相同的密码>

# 标记镜像
sudo nerdctl tag myimage:latest harbor.sunmoonai.local:30090/library/myimage:latest

# 推送镜像
sudo nerdctl push harbor.sunmoonai.local:30090/library/myimage:latest

# 拉取镜像
sudo nerdctl pull harbor.sunmoonai.local:30090/library/myimage:latest
```

**OIDC 认证（如果启用）**：
```bash
# 使用 CLI Secret 登录
sudo nerdctl login harbor.sunmoonai.local:30090 -u <用户名> -p <CLI Secret Token>
```

> **重要**: Harbor 使用统一的用户认证系统，**Docker/nerdctl 登录与 Web UI 登录使用相同的用户名和密码**。
> 
> **注意**: `nerdctl` 是 containerd 的客户端工具，与 Docker 命令兼容，但需要使用 `sudo` 权限。

### Kubernetes 集群使用 Harbor

> **说明**: 这里指的是 Kubernetes 集群中的 Pod 如何从 Harbor 镜像仓库拉取镜像，包括两种场景：
> 1. **其他应用使用 Harbor**：从 Harbor 拉取镜像部署应用
> 2. **Harbor 自身使用**：Harbor 组件拉取自己的镜像

#### 使用场景说明

**场景1：其他应用从 Harbor 拉取镜像**
```yaml
# 部署应用时使用 Harbor 镜像
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: my-app
        image: harbor.sunmoonai.local:30090/library/nginx:latest  # 从 Harbor 拉取
      imagePullSecrets:
      - name: harbor-registry-secret  # Harbor 认证
```

**场景2：Harbor 自身组件拉取镜像**
```yaml
# Harbor Chart 配置
global:
  imagePullSecrets:
    - name: harbor-registry-secret  # 用于拉取 Harbor 组件镜像
```

#### Secret 需求分析

| 场景 | 镜像来源 | 是否需要 Secret | 说明 |
|------|----------|----------------|------|
| **其他应用使用 Harbor** | `harbor.sunmoonai.local:30090/library/nginx` | ✅ **需要** | 私有 Harbor 需要认证 |
| **Harbor 自身组件** | `docker.io/bitnami/harbor-core` | ❌ **不需要** | 公网 docker.io 无需认证 |
| **Harbor 自身组件** | `private-registry.com/harbor-core` | ✅ **需要** | 私有仓库需要认证 |

**Harbor 默认镜像来源**：
- Harbor Core: `docker.io/bitnami/harbor-core:2.13.2`
- Harbor Portal: `docker.io/bitnami/harbor-portal:2.13.2`
- Harbor Registry: `docker.io/bitnami/harbor-registry:2.13.2`
- 等等...

**结论**：
- **其他应用使用 Harbor**：必须配置 Secret
- **Harbor 自身组件**：通常不需要 Secret（使用 docker.io）
- **企业环境**：可能需要配置 Secret（使用私有镜像仓库）

#### Docker 登录认证 vs Kubernetes Secret 认证

> **重要区别**：Docker 登录认证和 Kubernetes Secret 认证是两种不同的机制！

| 认证方式 | 用途 | 存储位置 | 数据格式 | 使用场景 |
|---------|------|----------|----------|----------|
| **Docker 登录** | 客户端工具认证 | `~/.docker/config.json` | JSON 格式 | `docker login`, `nerdctl login` |
| **Kubernetes Secret** | Pod 拉取镜像认证 | Kubernetes 集群 | Base64 编码的 JSON | Pod 拉取镜像 |

**Docker 登录认证**：
```bash
# 客户端登录
docker login harbor.sunmoonai.local:30090
# 认证信息存储在本地 ~/.docker/config.json
```

**Kubernetes Secret 认证**：
```yaml
# 创建 Kubernetes Secret
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.sunmoonai.local:30090 \
  --docker-username=admin \
  --docker-password=<密码> \
  --docker-email=admin@example.com
```

**关键区别**：
- ✅ **认证信息可以不同**：可以使用不同的 Harbor 用户
- ❌ **存储位置不同**：本地文件 vs Kubernetes 集群
- ❌ **使用场景不同**：客户端工具 vs Pod 拉取镜像
- ❌ **数据格式不同**：JSON vs Base64 编码的 JSON

#### 认证用户关系说明

> **重要澄清**：不同认证场景的用户关系

| 认证场景 | 用户名 | 密码 | 是否必须相同 | 说明 |
|---------|--------|------|-------------|------|
| **Harbor Web UI 登录** | `admin` | Harbor 密码 | - | Web 界面管理 |
| **Docker 登录** | `admin` | **相同的** Harbor 密码 | ✅ **必须相同** | 客户端工具认证 |
| **Kubernetes Secret** | `admin` 或其他用户 | 对应密码 | ❌ **可以不同** | Pod 拉取镜像认证 |

**正确的理解**：

1. **Harbor Web UI 和 Docker 登录**：
   - ✅ **必须使用相同的用户和密码**
   - ✅ **Harbor 认证系统是统一的**
   - ✅ **都使用同一个 Harbor 用户账户**

2. **Kubernetes Secret**：
   - ✅ **可以使用不同的 Harbor 用户**
   - ✅ **但必须是 Harbor 中存在的用户**
   - ✅ **必须有权限访问对应镜像**

**实际使用场景**：

**场景1：使用相同用户**
```bash
# Web UI 登录：admin + Harbor密码
# Docker 登录：admin + 相同密码
# Kubernetes Secret：admin + 相同密码
```

**场景2：使用不同用户（推荐）**
```bash
# Web UI 登录：admin + Harbor密码
# Docker 登录：admin + 相同密码
# Kubernetes Secret：dev用户 + dev密码（不同用户）
```

**创建不同用户的 Kubernetes Secret**：
```bash
# 使用 admin 用户
kubectl create secret docker-registry harbor-admin-secret \
  --docker-server=harbor.sunmoonai.local:30090 \
  --docker-username=admin \
  --docker-password=<admin密码> \
  --docker-email=admin@example.com

# 使用 dev 用户
kubectl create secret docker-registry harbor-dev-secret \
  --docker-server=harbor.sunmoonai.local:30090 \
  --docker-username=dev \
  --docker-password=<dev密码> \
  --docker-email=dev@example.com
```

**在 Pod 中使用不同的 Secret**：
```yaml
# 使用 admin 用户的 Secret
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: harbor.sunmoonai.local:30090/library/admin-app:latest
      imagePullSecrets:
      - name: harbor-admin-secret

---
# 使用 dev 用户的 Secret
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: harbor.sunmoonai.local:30090/library/dev-app:latest
      imagePullSecrets:
      - name: harbor-dev-secret
```

#### 如何保证 Harbor 用户存在

> **重要**：使用 Kubernetes Secret 前，必须确保对应的 Harbor 用户存在且有权限。

**Harbor 用户类型**：

| 用户类型 | 创建方式 | 管理位置 | 推荐场景 |
|---------|----------|----------|----------|
| **本地用户** | Harbor Web UI | Harbor 内部数据库 | 开发环境 |
| **Robot 用户** | Harbor Web UI | Harbor 内部数据库 | 生产环境/CI/CD |
| **LDAP 用户** | 外部 LDAP 服务器 | LDAP 服务器 | 企业环境 |
| **OIDC 用户** | 外部 OIDC 服务器 | OIDC 服务器 | 企业环境 |

**方法1：创建本地用户（开发环境）**

1. **登录 Harbor Web UI**
2. **进入用户管理**：Administration → Users
3. **创建新用户**：点击 "New User"
4. **填写用户信息**：
   - Username: `dev`
   - Email: `dev@example.com`
   - Password: `Dev@123`
   - Real Name: `Developer`

**方法2：创建 Robot 用户（生产环境推荐）**

1. **登录 Harbor Web UI**
2. **进入 Robot 账户**：Administration → Robot Accounts
3. **创建 Robot 账户**：点击 "New Robot Account"
4. **配置权限**：
   - Name: `k8s-dev-robot`
   - Description: `Kubernetes dev namespace robot`
   - Expiration: 设置过期时间
   - Permissions: 选择项目权限

**使用 Robot Token 创建 Secret**：
```bash
# Robot 用户的用户名格式：robot$<robot-name>
kubectl create secret docker-registry harbor-dev-secret \
  --docker-server=harbor.sunmoonai.local:30090 \
  --docker-username=robot$k8s-dev-robot \
  --docker-password=<robot-token> \
  --docker-email=dev@example.com
```

**验证用户存在**：
```bash
# 通过 Harbor API 检查用户
curl -u "admin:password" \
  "http://harbor.sunmoonai.local:30090/api/v2.0/users" | jq '.[].username'

# 检查 Robot 账户
curl -u "admin:password" \
  "http://harbor.sunmoonai.local:30090/api/v2.0/robots" | jq '.[].name'
```

**最佳实践**：
- ✅ **开发环境**：使用本地用户
- ✅ **生产环境**：使用 Robot 用户（更安全）
- ✅ **企业环境**：使用 LDAP/OIDC 统一认证
- ✅ **定期检查**：确保用户权限正确

> **重要说明**：无论使用哪种方式，**Secret 都必须手动创建**！区别在于如何引用 Secret。

#### 方法1：手动引用 Secret（传统方式）

**步骤1：手动创建 Secret**
```bash
# 创建 Harbor Registry Secret
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.sunmoonai.local:30090 \
  --docker-username=admin \
  --docker-password=<admin密码> \
  --docker-email=admin@example.com
```

**步骤2：在 Pod 中手动引用**
```yaml
# 在 Pod 中手动引用 Secret
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: my-container
    image: harbor.sunmoonai.local:30090/library/myimage:latest
  imagePullSecrets:
  - name: harbor-registry-secret  # 手动引用
```

#### 方法2：通过 Harbor Chart 配置引用（推荐）

**步骤1：手动创建 Secret**
```bash
# 同样需要手动创建 Secret
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.sunmoonai.local:30090 \
  --docker-username=admin \
  --docker-password=<admin密码> \
  --docker-email=admin@example.com
```

**步骤2：在 Harbor values.yaml 中配置引用**
```yaml
# 在 Harbor 的 values.yaml 中配置引用
global:
  imagePullSecrets:
    - name: harbor-registry-secret
    - name: another-registry-secret

# 或者为特定组件配置引用
core:
  imagePullSecrets:
    - name: core-registry-secret

registry:
  imagePullSecrets:
    - name: registry-secret
```

**Harbor Chart 的工作机制**：
- ✅ **引用现有 Secret**：不会自动创建，但会正确引用
- ✅ **全局应用**：自动应用到所有 Harbor 组件
- ✅ **标准 Kubernetes**：生成标准的 `imagePullSecrets` 字段
- ✅ **模板支持**：通过 `harbor.imagePullSecrets` 函数实现

**两种方式对比**：

| 方式 | Secret 创建 | Secret 引用 | 适用场景 |
|------|-------------|-------------|----------|
| **方法1：手动引用** | 手动创建 | 手动引用 | 单个应用 |
| **方法2：Chart 配置** | 手动创建 | Chart 自动引用 | Harbor 组件 |

**优势**：
- ✅ **官方支持**：Harbor Chart 原生支持
- ✅ **全局配置**：一次配置，所有组件生效
- ✅ **灵活配置**：支持全局和组件级别的配置
- ✅ **自动应用**：无需在每个 Pod 中手动指定

#### 配置步骤

> **重要**: Harbor Chart **不会自动创建** `kubernetes.io/dockerconfigjson` 类型的 Secret。
> 
> **两种不同的 Secret 需求**：
> 
> | Secret 类型 | Helm 是否自动创建 | 作用 | 说明 |
> |------------|------------------|------|------|
> | **Harbor 内部组件 Secret** | ✅ 自动创建 | Harbor 自身使用 | admin 密码、TLS、内部通信 |
> | **Kubernetes 拉取镜像 Secret** | ❌ 手动创建 | 其他 Pod 使用 | docker-registry 类型 |
> 
> **Harbor Chart 的设计**：
> - Harbor Chart 自动创建内部组件需要的 Secret
> - 但不会为外部 Pod 创建镜像拉取 Secret
> - 需要手动创建 `kubernetes.io/dockerconfigjson` 类型的 Secret

1. **手动创建 Harbor Registry Secret**：
   ```bash
   kubectl create secret docker-registry harbor-registry-secret \
     --docker-server=harbor.sunmoonai.local:30090 \
     --docker-username=admin \
     --docker-password=<您的密码> \
     --docker-email=admin@example.com \
     -n cicd-platform-dev
   ```

2. **在 Harbor values.yaml 中配置**：
   ```yaml
   global:
     imagePullSecrets:
       - name: harbor-registry-secret
   ```

3. **重新部署 Harbor**：
   ```bash
   helm upgrade sunmoonai-harbor ./harbor -f dev-values.yaml -n cicd-platform-dev
   ```

> **说明**: Harbor Chart 只支持**引用**现有的 Secret，不会自动创建。但配置后会自动应用到所有 Harbor 组件。

---

## 配置文件详解

### dev-values.yaml 完整结构

```yaml
# ============================================================================
# 全局配置
# ============================================================================
global:
  imageRegistry: ""
  # Harbor 官方 Chart 支持的全局 imagePullSecrets 配置
  imagePullSecrets:
    - name: harbor-registry-secret  # 用于拉取 Harbor 自身镜像的 Secret
  defaultStorageClass: "nfs-storage"

# ============================================================================
# 通用配置
# ============================================================================
nameOverride: ""
fullnameOverride: ""

commonLabels:
  app.kubernetes.io/name: "harbor"
  app.kubernetes.io/instance: "sunmoonai"
  app.kubernetes.io/component: "harbor"
  app.kubernetes.io/environment: "development"
  app.kubernetes.io/part-of: platform
  app.kubernetes.io/managed-by: helm

commonAnnotations:
  app.kubernetes.io/version: "2.13.2"
  app.kubernetes.io/created-by: "unified-deployment-template"

# ============================================================================
# Harbor 核心配置
# ============================================================================
adminPassword: "Harbor@12345"
externalURL: http://harbor.sunmoonai.local:30090

# ============================================================================
# 服务配置
# ============================================================================
service:
  type: "ClusterIP"
  ports:
    http: 80
    https: 443

# ============================================================================
# TLS/SSL 配置
# ============================================================================
tls:
  enabled: false
  secretName: ""

nginx:
  tls:
    enabled: false

# ============================================================================
# Ingress 配置
# ============================================================================
ingress:
  enabled: false  # 使用外部 Traefik

# ============================================================================
# 持久化存储配置
# ============================================================================
persistence:
  persistentVolumeClaim:
    trivy:
      storageClass: "nfs-storage"
      size: "5Gi"
      accessModes:
        - ReadWriteOnce

# ============================================================================
# 外部数据库配置（PostgreSQL）
# ============================================================================
postgresql:
  enabled: false

externalDatabase:
  host: "postgresql-sunmoonai.data-platform-dev.svc.cluster.local"
  port: 5432
  user: "sunmoonai_harbor"
  password: "SunMoonAI_PostgreSQL_2024!"
  sslmode: "disable"
  coreDatabase: "sunmoonai_harbor"

# ============================================================================
# 外部缓存配置（Redis）
# ============================================================================
redis:
  enabled: false

externalRedis:
  host: "redis-sunmoonai-master.data-platform-dev.svc.cluster.local"
  port: 6379
  password: "SunMoonAI_Redis_2024!"
  coreDatabaseIndex: "0"
  jobserviceDatabaseIndex: "1"
  registryDatabaseIndex: "2"
  trivyAdapterDatabaseIndex: "5"

# ============================================================================
# Harbor 组件配置
# ============================================================================
portal:
  replicaCount: 1

core:
  replicaCount: 1

jobservice:
  replicaCount: 1
  maxJobWorkers: 10

registry:
  replicaCount: 1
  storage:
    type: "filesystem"

trivy:
  enabled: true
  replicaCount: 1
  resources:
    limits:
      cpu: "500m"
      memory: "1Gi"
    requests:
      cpu: "100m"
      memory: "256Mi"

notary:
  enabled: false

# ============================================================================
# RBAC 和 ServiceAccount
# ============================================================================
rbac:
  create: true

serviceAccount:
  create: true
  name: ""
```

---

## 典型部署问题案例

> 本章节记录了 Harbor 在 Kubernetes 集群中部署时的实际调试过程，包括问题诊断、根因分析和解决方案。

### 案例背景

**问题时间**: 2025-10-04  
**Harbor 版本**: 2.13.2  
**部署方式**: Helm Chart  
**外部依赖**: PostgreSQL (data-platform-dev), Redis (data-platform-dev)

### 初始问题现象

部署 Harbor 后，多个核心组件无法正常启动：

```bash
NAME                                           READY   STATUS             RESTARTS        AGE
sunmoonai-harbor-core-68466b94d4-q74dk         0/1     CrashLoopBackOff   1 (19s ago)     86s
sunmoonai-harbor-jobservice-77687b98dc-k7l4t   0/1     CrashLoopBackOff   1 (23s ago)     86s
sunmoonai-harbor-registry-678bb79d59-n9m4j     0/2     Pending            0               86s
```

**问题分析**:
- ❌ Harbor Core: 崩溃重启（CrashLoopBackOff）
- ❌ Harbor Jobservice: 崩溃重启（CrashLoopBackOff）
- ❌ Harbor Registry: 无法调度（Pending）

### 调试步骤详解

#### 步骤 1: 检查组件日志

**查看 Harbor Core 日志**:
```bash
kubectl logs -n cicd-platform-dev sunmoonai-harbor-core-68466b94d4-q74dk --tail=30
```

**发现的错误信息**:
```
2025-10-04T15:00:39Z [ERROR] [/lib/cache/cache.go:126]: 
failed to ping redis://sunmoonai-harbor-redis-master.cicd-platform-dev.svc.cluster.local:6379//0, 
retry after 500ms : dial tcp: lookup sunmoonai-harbor-redis-master.cicd-platform-dev.svc.cluster.local 
on 10.96.0.10:53: no such host
```

**问题诊断**: 
- Harbor 尝试连接**内部** Redis 服务 `sunmoonai-harbor-redis-master`
- DNS 解析失败，该服务不存在
- 说明 Harbor Chart 启用了内置 Redis，而不是使用外部 Redis

#### 步骤 2: 检查 Helm 部署配置

**查看实际部署的 Values**:
```bash
helm get values sunmoonai-harbor -n cicd-platform-dev | grep -A5 -B5 "externalRedis\|externalDatabase"
```

**发现的配置问题**:
```yaml
# 实际部署的配置
externalDatabase:
  host: localhost          # ❌ 错误：默认值
  password: ""             # ❌ 错误：空密码
  port: 5432
  sslmode: disable
  user: bn_harbor          # ❌ 错误：默认用户

externalRedis:
  host: ""                 # ❌ 错误：空值
  password: ""             # ❌ 错误：空密码
  port: 6379
```

**根本原因**: 
1. Helm Chart 默认启用了内置 PostgreSQL 和 Redis
2. `dev-values.yaml` 中的外部服务配置未生效
3. 需要显式禁用内置服务并配置外部连接

#### 步骤 3: 修正配置文件

**修改 `dev-values.yaml`**:

```yaml
# ============================================================================
# 1. 显式禁用内置数据库和 Redis
# ============================================================================
postgresql:
  enabled: false           # ✅ 必须显式禁用

redis:
  enabled: false           # ✅ 必须显式禁用

# ============================================================================
# 2. 配置外部 PostgreSQL
# ============================================================================
externalDatabase:
  host: "postgresql-{{PROJECT_ID}}.data-platform-dev.svc.cluster.local"  # ✅ 正确的服务名
  port: 5432
  user: "{{PROJECT_ID}}_harbor"                                          # ✅ 专用用户
  password: "SunMoonAI_PostgreSQL_2024!"                                 # ✅ 正确的密码
  sslmode: "disable"
  coreDatabase: "{{PROJECT_ID}}_harbor"                                  # ✅ 专用数据库

# ============================================================================
# 3. 配置外部 Redis (主从架构)
# ============================================================================
externalRedis:
  host: "redis-{{PROJECT_ID}}-master.data-platform-dev.svc.cluster.local"  # ✅ 连接主节点
  port: 6379
  password: "SunMoonAI_Redis_2024!"                                         # ✅ 正确的密码
  coreDatabaseIndex: "0"
  jobserviceDatabaseIndex: "1"
  registryDatabaseIndex: "2"
  trivyAdapterDatabaseIndex: "5"
```

**关键修正点**:
1. ✅ **禁用内置服务**: 必须显式设置 `enabled: false`
2. ✅ **服务名称**: 使用实际的服务名（Redis 主从架构需要连接 `-master` 服务）
3. ✅ **密码**: 使用外部服务的实际密码

#### 步骤 4: 验证外部服务

**检查 Redis 服务**:
```bash
kubectl get svc -n data-platform-dev | grep redis
```

**结果**:
```
redis-sunmoonai-headless   ClusterIP   None             <none>        6379/TCP    11h
redis-sunmoonai-master     ClusterIP   10.104.249.63    <none>        6379/TCP    11h  ← Harbor 连接此服务
redis-sunmoonai-replicas   ClusterIP   10.100.129.136   <none>        6379/TCP    11h
```

**检查 PostgreSQL 服务**:
```bash
kubectl get svc -n data-platform-dev | grep postgresql
```

**结果**:
```
postgresql-sunmoonai       ClusterIP   10.100.6.40      <none>        5432/TCP    24h  ← Harbor 连接此服务
postgresql-sunmoonai-hl    ClusterIP   None             <none>        5432/TCP    24h
```

#### 步骤 5: 获取正确的服务密码

**获取 Redis 密码**:
```bash
kubectl get secret redis-sunmoonai -n data-platform-dev \
  -o jsonpath='{.data.redis-password}' | base64 -d
```
**结果**: `SunMoonAI_Redis_2024!`

**获取 PostgreSQL 密码**:
```bash
kubectl get secret postgresql-sunmoonai -n data-platform-dev \
  -o jsonpath='{.data.postgres-password}' | base64 -d
```
**结果**: `SunMoonAI_PostgreSQL_2024!`

#### 步骤 6: 配置 PostgreSQL 自动创建 Harbor 用户和数据库（推荐方法）

> **重要**: Harbor Chart 在不同 PostgreSQL 配置下的行为：
> 
> | 配置方式 | 是否自动创建数据库/用户 | 是否需要手动创建 | 说明 |
> |---------|----------------------|-----------------|------|
> | **内置 PostgreSQL** (`postgresql.enabled: true`) | ✅ 自动创建 | ❌ 无需干预 | Chart 自动创建 `harbor` 数据库和 `bn_harbor` 用户 |
> | **外部 PostgreSQL + initdbScripts** | ✅ 自动创建 | ❌ 无需干预 | PostgreSQL Chart 自动创建 Harbor 用户和数据库 |
> | **外部 PostgreSQL（传统方式）** | ❌ 不会创建 | ✅ 必须手动创建 | 需要预先创建用户和数据库 |

**推荐方法：使用 PostgreSQL initdbScripts**

在 PostgreSQL Chart 的 `values.yaml` 中配置：

```yaml
postgresql:
  initdbScripts:
    create-harbor-user.sql: |
      CREATE USER sunmoonai_harbor WITH PASSWORD 'SunMoonAI_PostgreSQL_2024!';
      CREATE DATABASE sunmoonai_harbor OWNER sunmoonai_harbor;
      GRANT ALL PRIVILEGES ON DATABASE sunmoonai_harbor TO sunmoonai_harbor;
```

**部署顺序**：
1. **先部署 PostgreSQL**：使用包含 `initdbScripts` 的配置
2. **再部署 Harbor**：使用 `externalDatabase` 配置连接外部数据库

**验证自动创建**：
```bash
# 检查 Harbor 用户是否已创建
kubectl exec -n data-platform-dev postgresql-sunmoonai-0 -- \
  env PGPASSWORD="SunMoonAI_PostgreSQL_2024!" \
  psql -U postgres -c "\du" | grep sunmoonai_harbor

# 检查 Harbor 数据库是否已创建
kubectl exec -n data-platform-dev postgresql-sunmoonai-0 -- \
  env PGPASSWORD="SunMoonAI_PostgreSQL_2024!" \
  psql -U postgres -c "\l" | grep sunmoonai_harbor
```

#### 步骤 7: 重新部署 Harbor

**执行重新部署**:
```bash
cd ~/master/k8s/sunmoonai/cicd-platform/harbor/deploy
./deploy-harbor.sh deploy
```

**验证部署结果**:
```bash
kubectl get pods -n cicd-platform-dev -l app.kubernetes.io/instance=sunmoonai-harbor
```

**最终状态** ✅:
```
NAME                                           READY   STATUS    RESTARTS        AGE
sunmoonai-harbor-core-7677b57d67-dd25v         1/1     Running   5 (3m10s ago)   4m43s
sunmoonai-harbor-jobservice-5487758594-8z8pb   1/1     Running   3 (88s ago)     4m43s
sunmoonai-harbor-nginx-6b8464b6-pfrw5          1/1     Running   0               4m43s
sunmoonai-harbor-portal-775b74cf48-9k2hm       1/1     Running   0               4m43s
sunmoonai-harbor-registry-65cd699f48-p6kc9     2/2     Running   0               4m43s
sunmoonai-harbor-trivy-0                       1/1     Running   0               4m41s
```

### 问题总结

#### 根本原因

| 问题类型 | 具体原因 | 影响 |
|---------|---------|------|
| **配置缺陷** | 未显式禁用内置 PostgreSQL 和 Redis | Harbor 尝试连接不存在的内部服务 |
| **服务名错误** | Redis 服务名未包含 `-master` 后缀 | DNS 解析失败 |
| **密码不匹配** | 使用了默认密码而非实际密码 | 认证失败 |
| **用户缺失** | PostgreSQL 缺少 Harbor 专用用户 | 数据库连接失败 |

#### 解决方案总结

1. ✅ **显式禁用内置服务**: 
   ```yaml
   postgresql:
     enabled: false
   redis:
     enabled: false
   ```

2. ✅ **使用正确的服务名**:
   - PostgreSQL (单实例): `postgresql-sunmoonai`
   - Redis (主从架构): `redis-sunmoonai-master` (必须连接主节点)

3. ✅ **配置正确的密码**:
   - 从 Kubernetes Secret 获取实际密码
   - 确保 `dev-values.yaml` 中的密码与实际一致

4. ✅ **预先创建数据库资源**:
   - 创建 Harbor 专用用户
   - 创建 Harbor 专用数据库
   - 授予适当的权限

### 经验教训

#### 配置最佳实践

1. **外部服务配置**:
   - ✅ 必须显式禁用内置服务 (`enabled: false`)
   - ✅ 使用完整的 FQDN 服务名
   - ✅ 验证密码的正确性
   - ✅ 预先创建必要的用户和数据库

2. **服务命名规范**:
   - ✅ 了解 Bitnami Chart 的命名规则
   - ✅ 单实例架构: 无后缀（如 `postgresql-{name}`）
   - ✅ 主从架构: 有后缀（如 `redis-{name}-master`）

3. **调试技巧**:
   - ✅ 优先检查 Pod 日志，定位具体错误
   - ✅ 验证 Helm 部署的实际配置（`helm get values`）
   - ✅ 确认外部服务的可用性和连接信息
   - ✅ 逐步验证每个依赖组件的状态

#### 预防措施

1. **部署前检查清单**:
   ```bash
   # ✅ 检查外部服务是否存在
   kubectl get svc -n data-platform-dev | grep -E "postgresql|redis"
   
   # ✅ 验证服务密码
   kubectl get secret <service-secret> -n data-platform-dev -o jsonpath='{.data.*}' | base64 -d
   
   # ✅ 检查数据库用户是否存在
   kubectl exec -n data-platform-dev postgresql-sunmoonai-0 -- \
     psql -U postgres -c "\du"
   
   # ✅ 验证配置文件语法
   helm template sunmoonai-harbor ./harbor -f dev-values.yaml --dry-run
   ```

2. **配置验证**:
   - ✅ 使用 `helm template` 预览渲染结果
   - ✅ 检查 ConfigMap 中的环境变量
   - ✅ 确认服务端口和协议

3. **监控和告警**:
   - ✅ 设置 Pod 重启告警
   - ✅ 监控外部服务的连接数
   - ✅ 定期检查 Harbor 组件健康状态

---

## 故障排查

### 常见问题诊断

#### 1. Pod 启动失败

```bash
# 查看 Pod 状态
kubectl get pods -n cicd-platform-dev -l app.kubernetes.io/instance=sunmoonai-harbor

# 查看 Pod 详细信息
kubectl describe pod <pod-name> -n cicd-platform-dev

# 查看 Pod 日志
kubectl logs <pod-name> -n cicd-platform-dev

# 查看所有组件日志
cd ~/master/k8s/sunmoonai/cicd-platform/harbor/deploy
./deploy-harbor.sh logs
```

**常见错误及解决方案**:

| 错误信息 | 原因 | 解决方案 |
|---------|------|----------|
| `failed to ping redis` | Redis 连接失败 | 检查 Redis 服务和密码配置 |
| `failed to connect to database` | PostgreSQL 连接失败 | 检查数据库服务、用户和密码 |
| `CrashLoopBackOff` | 容器启动失败 | 查看日志定位具体原因 |
| `ImagePullBackOff` | 镜像拉取失败 | 检查镜像是否存在 |

#### 2. 外部数据库连接问题

```bash
# 测试 PostgreSQL 连接
kubectl exec -n data-platform-dev postgresql-sunmoonai-0 -- \
  psql -U sunmoonai_harbor -d sunmoonai_harbor -c "SELECT 1;"

# 测试 Redis 连接
kubectl exec -n data-platform-dev redis-sunmoonai-master-0 -- \
  redis-cli -a "SunMoonAI_Redis_2024!" ping
```

#### 3. Web 界面访问问题

```bash
# 测试 Harbor 服务
curl -I http://harbor.sunmoonai.local:30090/

# 测试 Traefik 路由
kubectl get ingressroute -n cicd-platform-dev harbor-web -o yaml

# 查看 Traefik 日志
kubectl logs -n ingress-traefik deployment/traefik --tail=100
```

**访问问题排查步骤**:

1. **检查域名解析**
   ```bash
   ping harbor.sunmoonai.local
   # 应该解析到 101.126.151.0
   # 如果无法解析，请检查本地 hosts 文件配置
   ```

2. **检查 Traefik 路由配置**
   ```bash
   kubectl get ingressroute -n cicd-platform-dev harbor-web
   ```

3. **检查 Harbor 服务状态**
   ```bash
   kubectl get svc -n cicd-platform-dev sunmoonai-harbor
   ```

4. **检查 Pod 健康状态**
   ```bash
   kubectl get pods -n cicd-platform-dev | grep harbor
   ```

#### 4. 登录问题

**密码错误**:

获取实际的管理员密码:
```bash
kubectl exec -n cicd-platform-dev \
  $(kubectl get pod -n cicd-platform-dev -l app.kubernetes.io/component=core --no-headers | head -1 | awk '{print $1}') \
  -- env | grep HARBOR_ADMIN_PASSWORD
```

**忘记密码**:

通过数据库重置密码:
```bash
# 1. 连接到 PostgreSQL
kubectl exec -it -n data-platform-dev postgresql-sunmoonai-0 -- bash

# 2. 登录数据库
export PGPASSWORD=SunMoonAI_PostgreSQL_2024!
psql -U sunmoonai_harbor -d sunmoonai_harbor

# 3. 查看管理员用户
SELECT user_id, username, email FROM harbor_user WHERE username='admin';

# 4. 使用 Harbor Core 重新初始化（推荐重新部署）
```

或者重新部署 Harbor 以重置密码:
```bash
cd ~/master/k8s/sunmoonai/cicd-platform/harbor/deploy
./deploy-harbor.sh uninstall
./deploy-harbor.sh deploy
```

---

## 维护操作

### 1. 备份 Harbor

#### 备份数据库

```bash
# 备份 PostgreSQL 数据库
kubectl exec -n data-platform-dev postgresql-sunmoonai-0 -- \
  pg_dump -U sunmoonai_harbor sunmoonai_harbor > harbor_backup_$(date +%Y%m%d).sql

# 或使用密码
kubectl exec -n data-platform-dev postgresql-sunmoonai-0 -- \
  bash -c "PGPASSWORD=SunMoonAI_PostgreSQL_2024! pg_dump -U sunmoonai_harbor sunmoonai_harbor" \
  > harbor_backup_$(date +%Y%m%d).sql
```

#### 备份镜像数据

```bash
# 如果使用文件系统存储，需要备份 Registry PVC 数据
kubectl get pvc -n cicd-platform-dev | grep registry

# 创建快照或复制数据
# 具体方法取决于存储类型（NFS、Ceph 等）
```

### 2. 恢复 Harbor

```bash
# 恢复数据库
cat harbor_backup_20251005.sql | \
kubectl exec -i -n data-platform-dev postgresql-sunmoonai-0 -- \
  psql -U sunmoonai_harbor sunmoonai_harbor
```

### 3. 升级 Harbor

```bash
# 1. 备份数据
# 2. 更新 Chart 或 Values
# 3. 执行升级
cd ~/master/k8s/sunmoonai/cicd-platform/harbor/deploy
./deploy-harbor.sh upgrade

# 4. 验证升级
./deploy-harbor.sh status
```

### 4. 扩容 Harbor

修改 `dev-values.yaml`:
```yaml
core:
  replicaCount: 2  # 增加副本数

registry:
  replicaCount: 2
```

重新部署:
```bash
./deploy-harbor.sh upgrade
```

### 5. 清理旧数据

```bash
# 清理未使用的镜像（通过 Web UI）
# 1. 登录 Harbor
# 2. 进入 Projects → 选择项目
# 3. Repositories → 选择仓库
# 4. 删除旧的 Tags
# 5. Administration → Garbage Collection → Run Now

# 或通过 API
curl -X POST "http://harbor.sunmoonai.local:30090/api/v2.0/system/gc/schedule" \
  -u "admin:password" \
  -H "Content-Type: application/json" \
  -d '{"schedule":{"type":"Manual"}}'
```

---

## 常见问题

### Q1: 为什么需要配置 hosts 文件？

**A**: Harbor 使用自定义域名 `harbor.sunmoonai.local` 来区分不同的服务（通过 Traefik 路由）。由于这是内部域名，不在公共 DNS 中注册，需要在本地 hosts 文件中配置域名解析。

**配置方法**:
```bash
# Windows: C:\Windows\System32\drivers\etc\hosts
# Linux/Mac: /etc/hosts
101.126.151.0  harbor.sunmoonai.local
```

**为什么使用本地域名**: 使用本地域名 `harbor.sunmoonai.local` 配合 hosts 文件配置，避免了对外部 DNS 服务的依赖，在企业网络环境中更稳定可靠，且便于管理和维护。

### Q1.1: Chrome 显示 502 错误，但 Edge 可以访问？

**A**: 这通常是 Chrome 的代理设置导致的。代理服务器无法解析内网域名，导致 502 Bad Gateway。

**解决方法**:
1. Chrome 设置 → 搜索"代理" → 打开系统代理设置
2. 在"请勿对以下条目开头的地址使用代理服务器"中添加：
   ```
   harbor.sunmoonai.local;101.126.151.0;*.local
   ```
3. 或临时关闭代理进行测试
4. 也可能是 Chrome 缓存问题，访问 `chrome://net-internals/#dns` 清除 DNS 缓存

### Q2: 为什么禁用 TLS？

**A**: 在开发环境中使用 HTTP 更简单，减少证书配置复杂度。生产环境建议启用 HTTPS。

启用 HTTPS 的步骤:
1. 准备 TLS 证书
2. 创建 Kubernetes Secret
3. 修改 `dev-values.yaml`:
   ```yaml
   tls:
     enabled: true
     secretName: harbor-tls-secret
   
   nginx:
     tls:
       enabled: true
   
   externalURL: https://harbor.sunmoonai.local:30090
   ```
4. 重新部署

### Q3: 如何配置镜像代理缓存？

**A**: 
1. 登录 Harbor Web UI
2. 进入 Registries → New Endpoint
3. 配置上游仓库:
   - Provider: Docker Hub
   - Endpoint URL: https://registry-1.docker.io
   - Name: docker-hub-proxy
4. 创建 Proxy Cache 项目:
   - Projects → New Project
   - Project Name: docker-hub
   - Registry: docker-hub-proxy
   - 勾选 "Proxy Cache"

使用代理缓存:
```bash
docker pull harbor.sunmoonai.local:30090/docker-hub/library/nginx:latest
```

### Q4: 如何配置镜像扫描？

**A**: Harbor 已集成 Trivy 扫描器，默认启用。

使用方式:
1. 推送镜像后，在 Repositories 页面查看
2. 点击 Tag → Scan
3. 等待扫描完成，查看漏洞报告

配置自动扫描:
1. Administration → Interrogation Services
2. 勾选 "Automatically scan images on push"
3. 配置扫描触发器

### Q5: 如何配置镜像复制？

**A**:
1. Registries → New Endpoint（配置目标 Harbor）
2. Replications → New Replication Rule
3. 配置复制规则:
   - Source registry: Local
   - Destination registry: 目标 Harbor
   - Trigger: Manual/Scheduled/Event Based
4. 执行复制

### Q6: 如何查看系统配置？

```bash
# 通过 API 查看配置
curl -u "admin:password" \
  http://harbor.sunmoonai.local:30090/api/v2.0/configurations

# 查看系统信息
curl http://harbor.sunmoonai.local:30090/api/v2.0/systeminfo
```

### Q7: 如何监控 Harbor？

**A**: Harbor 支持 Prometheus 监控。

启用监控:
```yaml
# 在 dev-values.yaml 中配置
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

Prometheus 抓取端点:
- Core: `http://sunmoonai-harbor-core/metrics`
- Registry: `http://sunmoonai-harbor-registry/metrics`
- Exporter: `http://sunmoonai-harbor-exporter/metrics`

### Q8: 为什么设置了 adminPassword 但登录时密码不对？

**A**: 这是 Bitnami Harbor Chart 的常见问题。即使你在 `values.yaml` 中设置了 `adminPassword`，但登录时发现密码不对，原因如下：

**问题原因**：
1. **旧 Secret 已存在**：如果之前安装过 Harbor，旧的 admin 密码 Secret 仍然存在
2. **Helm 不会覆盖**：Chart 检测到同名 Secret 已存在，会跳过密码更新
3. **使用自动生成密码**：Harbor 实际使用的是 Helm 自动生成的随机密码

**验证当前密码**：
```bash
# 查看当前 Harbor 实际使用的密码
kubectl get secret sunmoonai-harbor-core -n cicd-platform-dev \
  -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 -d
```

**解决方案**：

**方案1：彻底重新安装（推荐）**：
```bash
# 1. 卸载 Harbor
helm uninstall sunmoonai-harbor -n cicd-platform-dev

# 2. 删除相关 PVC（可选，会丢失数据）
kubectl delete pvc -l app.kubernetes.io/instance=sunmoonai-harbor -n cicd-platform-dev

# 3. 重新安装
helm install sunmoonai-harbor ./harbor -f dev-values.yaml -n cicd-platform-dev
```

**方案2：手动更新 Secret**：
```bash
# 1. 删除旧的 admin 密码 Secret
kubectl delete secret sunmoonai-harbor-core -n cicd-platform-dev

# 2. 重新部署
helm upgrade sunmoonai-harbor ./harbor -f dev-values.yaml -n cicd-platform-dev

# 3. 重启 Harbor Core（使新密码生效）
kubectl rollout restart deployment sunmoonai-harbor-core -n cicd-platform-dev
```

**预防措施**：
- 首次部署时确保没有旧的 Secret
- 使用 `helm upgrade --install` 而不是 `helm install`
- 部署后立即验证密码是否正确

### Q9: 为什么使用外部 PostgreSQL 时需要手动创建数据库用户？

**A**: 这是 Harbor Chart 的设计行为，取决于你使用的 PostgreSQL 配置方式。

**两种配置方式的差异**：

| 配置方式 | Harbor Chart 行为 | 数据库/用户创建 | 是否需要手动干预 |
|---------|------------------|----------------|-----------------|
| **内置 PostgreSQL** | `postgresql.enabled: true` | ✅ 自动创建 `harbor` 数据库和 `bn_harbor` 用户 | ❌ 无需干预 |
| **外部 PostgreSQL** | `postgresql.enabled: false` + `externalDatabase.*` | ❌ 不会自动创建 | ✅ 必须手动创建 |

**内置 PostgreSQL（自动创建）**：
```yaml
postgresql:
  enabled: true  # Harbor Chart 自动部署 PostgreSQL
```
- Harbor Chart 会自动部署 PostgreSQL 子 Chart
- 自动创建 `harbor` 数据库
- 自动创建 `bn_harbor` 用户和随机密码
- 通过 Secret 将凭证提供给 Harbor 组件

**外部 PostgreSQL（手动创建）**：
```yaml
postgresql:
  enabled: false  # 禁用内置 PostgreSQL

externalDatabase:
  host: "postgresql-sunmoonai.data-platform-dev.svc.cluster.local"
  user: "sunmoonai_harbor"  # 需要手动创建
  password: "SunMoonAI_PostgreSQL_2024!"
  coreDatabase: "sunmoonai_harbor"  # 需要手动创建
```
- Harbor Chart 假设外部数据库已准备好
- 需要手动创建 Harbor 专用用户和数据库
- 需要确保用户有足够的权限

**为什么这样设计？**
- **内置 PostgreSQL**：Harbor Chart 完全控制，可以自动创建所需资源
- **外部 PostgreSQL**：Harbor Chart 无法控制外部数据库，需要用户预先准备

**Harbor 如何知道使用外部数据库？**
1. **配置读取**：Harbor Chart 读取 `values.yaml` 中的 `externalDatabase` 配置
2. **模板处理**：Chart 模板将配置转换为环境变量
3. **环境变量注入**：将数据库连接信息注入到 Harbor 组件的环境变量中
4. **自动连接**：Harbor 组件启动时读取环境变量，自动连接到外部数据库

**环境变量传递过程**：
```yaml
# values.yaml 配置
externalDatabase:
  host: "postgresql-sunmoonai.data-platform-dev.svc.cluster.local"
  user: "sunmoonai_harbor"
  password: "SunMoonAI_PostgreSQL_2024!"
  coreDatabase: "sunmoonai_harbor"

# ↓ Harbor Chart 模板处理

# ↓ 注入到 Harbor Core 组件
POSTGRESQL_HOST: "postgresql-sunmoonai.data-platform-dev.svc.cluster.local"
POSTGRESQL_USERNAME: "sunmoonai_harbor"
POSTGRESQL_PASSWORD: "SunMoonAI_PostgreSQL_2024!"
POSTGRESQL_DATABASE: "sunmoonai_harbor"
```

### Q10: 为什么 Redis 服务名是 redis-sunmoonai-master 而不是 redis-sunmoonai？

**A**: 因为您的 Redis 部署的是**主从复制架构**（Replication），而不是单实例架构。

**Bitnami Redis Chart 的命名规范**：
- 主从架构：自动添加 `-master` 和 `-replicas` 后缀来区分角色
- 单实例架构：无后缀

**您的配置**：
- **PostgreSQL**：单实例 → 服务名 `postgresql-sunmoonai`（无后缀）
- **Redis**：主从架构 → 服务名 `redis-sunmoonai-master`（有后缀）

**为什么必须连接 master？**

Harbor 需要执行写操作（SET、DEL、HSET 等），只有主节点支持写入。从节点（replicas）是只读的，无法满足 Harbor 的需求。

**如何确认架构？**
```bash
# 查看 Redis 服务
kubectl get svc -n data-platform-dev | grep redis

# 单实例会看到：
redis-sunmoonai

# 主从架构会看到：
redis-sunmoonai-master      ← Harbor 连接这个
redis-sunmoonai-replicas    ← 只读副本
redis-sunmoonai-headless
```

**这是 Bitnami Helm Chart 的标准命名规范**，不是随意命名，而是架构设计的必然结果。详见"架构概述 → 外部数据服务架构说明"。

### Q9: Harbor 占用多少资源？

**A**: 当前配置的资源需求:

| 组件 | CPU 请求 | 内存请求 | CPU 限制 | 内存限制 |
|------|----------|----------|----------|----------|
| Core | 100m | 256Mi | 1000m | 2Gi |
| Registry | 100m | 256Mi | 1000m | 2Gi |
| JobService | 100m | 256Mi | 1000m | 2Gi |
| Portal | 50m | 128Mi | 500m | 1Gi |
| Nginx | 50m | 128Mi | 500m | 1Gi |
| Trivy | 100m | 256Mi | 500m | 1Gi |

总计约: CPU 0.5-4 核，内存 1.2-9 GB

---

## 附录

### A. 相关服务信息

#### Traefik Ingress

- **命名空间**: ingress-traefik
- **NodePort (HTTP)**: 30090
- **NodePort (HTTPS)**: 32274
- **服务名**: traefik

#### PostgreSQL

- **命名空间**: data-platform-dev
- **服务名**: postgresql-sunmoonai
- **端口**: 5432
- **数据库**: sunmoonai_harbor
- **用户**: sunmoonai_harbor
- **密码**: SunMoonAI_PostgreSQL_2024!

#### Redis

- **命名空间**: data-platform-dev
- **架构**: 主从复制（Master-Slave Replication）
- **主节点服务**: redis-sunmoonai-master（Harbor 连接此服务）
- **从节点服务**: redis-sunmoonai-replicas（只读）
- **端口**: 6379
- **密码**: SunMoonAI_Redis_2024!
- **配置**: `architecture: replication`（Bitnami Chart 默认）

> **说明**：Harbor 必须连接主节点服务（redis-sunmoonai-master），因为需要执行写操作。从节点是只读的，仅用于读取和高可用。

### B. 有用的命令

```bash
# 查看所有 Harbor 资源
kubectl get all -n cicd-platform-dev -l app.kubernetes.io/instance=sunmoonai-harbor

# 重启所有 Harbor 组件
kubectl rollout restart deployment -n cicd-platform-dev -l app.kubernetes.io/instance=sunmoonai-harbor

# 查看 Harbor 事件
kubectl get events -n cicd-platform-dev --sort-by='.lastTimestamp' | grep harbor

# 进入 Harbor Core Pod
kubectl exec -it -n cicd-platform-dev \
  $(kubectl get pod -n cicd-platform-dev -l app.kubernetes.io/component=core --no-headers | head -1 | awk '{print $1}') \
  -- bash

# 查看 Harbor 版本
kubectl exec -n cicd-platform-dev \
  $(kubectl get pod -n cicd-platform-dev -l app.kubernetes.io/component=core --no-headers | head -1 | awk '{print $1}') \
  -- cat /harbor-version

# 强制删除 Pod
kubectl delete pod <pod-name> -n cicd-platform-dev --force --grace-period=0
```

### C. API 示例

```bash
# 获取 Token
curl -X POST "http://harbor.sunmoonai.local:30090/c/login" \
  -H "Content-Type: application/json" \
  -d '{"principal":"admin","password":"your-password"}'

# 列出所有项目
curl -u "admin:password" \
  "http://harbor.sunmoonai.local:30090/api/v2.0/projects"

# 创建项目
curl -X POST -u "admin:password" \
  "http://harbor.sunmoonai.local:30090/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -d '{"project_name":"myproject","public":false}'

# 列出仓库
curl -u "admin:password" \
  "http://harbor.sunmoonai.local:30090/api/v2.0/projects/library/repositories"

# 获取系统信息
curl "http://harbor.sunmoonai.local:30090/api/v2.0/systeminfo"
```

### D. 参考链接

- **Harbor 官方文档**: https://goharbor.io/docs/
- **Bitnami Harbor Chart**: https://github.com/bitnami/charts/tree/main/bitnami/harbor
- **Harbor API 文档**: https://goharbor.io/docs/latest/working-with-projects/working-with-images/pulling-pushing-images/
- **Traefik 文档**: https://doc.traefik.io/traefik/
- **Traefik IngressRoute**: https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/

---

## 更新日志

| 日期 | 版本 | 更新内容 | 操作人 |
|------|------|----------|--------|
| 2025-10-05 | 1.0 | 初始版本，完成 Harbor 部署 | System |
| 2025-10-05 | 1.1 | 配置外部数据库和 Redis | System |
| 2025-10-05 | 1.2 | 配置 Traefik 路由和域名访问 | System |
| 2025-10-05 | 1.3 | 完善文档，添加故障排查 | System |
| 2025-10-05 | 1.4 | 修改为本地域名方案（hosts文件） | System |
| 2025-10-05 | 1.5 | 添加 Redis/PostgreSQL 架构说明 | System |
| 2025-10-05 | 2.0 | 整合《Harbor调试过程文档》，添加典型部署问题案例章节 | System |

---

## 联系方式

如有问题，请联系：
- **项目**: sunmoonai
- **环境**: development
- **命名空间**: cicd-platform-dev

---

**文档结束**

