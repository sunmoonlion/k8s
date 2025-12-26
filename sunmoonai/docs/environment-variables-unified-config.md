# 统一环境变量配置文档

本文档包含所有 app 的联动环境变量配置，用于 K8s 部署时创建 ConfigMap 和 Secret。

## 联动环境变量配置

### 核心联动变量（所有服务必须一致）

| 环境变量 | 值 | 说明 | 使用服务 |
|---------|-----|------|---------|
| `SESSION_COOKIE_NAME` | `sunmoonai_session` | Session Cookie 名称 | 所有服务 |

### 服务端口配置

| 服务 | 环境变量 | 默认值 | K8s Service 地址 |
|------|---------|--------|-----------------|
| **auth-app-bff** | `PORT` | `3030` | `auth-app-bff:3030` |
| **portal-app-bff** | `PORT` | `3000` | `portal-app-bff:3000` |
| **incubator-app-bff** | (FastAPI 默认) | `8000` | `incubator-app-bff:8000` |
| **llmops-app-bff** | (FastAPI 默认) | `8000` | `llmops-app-bff:8000` |

---

## 各 App 环境变量配置

### 1. auth-app-bff

```bash
# ============================================================================
# 服务配置（联动配置）
# ============================================================================
PORT=3030
PREFIX=/api
VERSION=v1
SESSION_COOKIE_NAME=sunmoonai_session

# ============================================================================
# 其他配置（业务特定）
# ============================================================================
GRPC_PORT=40001
CORS=true
ERROR_FILTER=true

# Secret 配置（敏感信息，放在 Secret 中）
# SECRET_KEY=...
# JWT_SECRET=...
# DATABASE_URL=...
# REDIS_HOST=redis
# REDIS_PORT=6379
# REDIS_PASSWORD=...
```

### 2. portal-app-bff

```bash
# ============================================================================
# 服务配置（联动配置）
# ============================================================================
PORT=3000
PREFIX=/api
VERSION=v1
SESSION_COOKIE_NAME=sunmoonai_session

# ============================================================================
# 认证服务配置（联动配置 - 调用 auth-app-bff）
# ============================================================================
# 开发环境：http://localhost:3030
# 生产环境（K8s）：http://auth-app-bff:3030
AUTH_SERVICE_URL=http://auth-app-bff:3030

# ============================================================================
# 其他配置（业务特定）
# ============================================================================
CORS=true
ERROR_FILTER=true

# Secret 配置（敏感信息，放在 Secret 中）
# JWT_SECRET=...
# DATABASE_URL=...
```

### 3. incubator-app-bff

```bash
# ============================================================================
# 服务配置（联动配置）
# ============================================================================
# API 路径前缀（包含版本，相当于 PREFIX + VERSION）
API_V1_STR=/api/v1
SESSION_COOKIE_NAME=sunmoonai_session

# ============================================================================
# 认证服务配置（联动配置 - 调用 auth-app-bff）
# ============================================================================
# 开发环境：http://localhost:3030
# 生产环境（K8s）：http://auth-app-bff:3030
AUTH_SERVICE_URL=http://auth-app-bff:3030

# ============================================================================
# 其他配置（业务特定）
# ============================================================================
PROJECT_NAME=incubator-app-bff
SERVER_NAME=incubator-app-bff
SERVER_HOST=http://incubator-app-bff:8000

# Secret 配置（敏感信息，放在 Secret 中）
# SECRET_KEY=...
# TOTP_SECRET_KEY=...
# POSTGRES_SERVER=postgres
# POSTGRES_USER=...
# POSTGRES_PASSWORD=...
# POSTGRES_PORT=5432
# POSTGRES_DB=incubator_db
# NEO4J_SERVER=neo4j
# NEO4J_USERNAME=...
# NEO4J_PASSWORD=...
```

### 4. llmops-app-bff

```bash
# ============================================================================
# 服务配置（联动配置）
# ============================================================================
# API 路径前缀（包含版本，相当于 PREFIX + VERSION）
API_V1_STR=/api/v1
SESSION_COOKIE_NAME=sunmoonai_session

# ============================================================================
# 认证服务配置（联动配置 - 调用 auth-app-bff）
# ============================================================================
# 开发环境：http://localhost:3030
# 生产环境（K8s）：http://auth-app-bff:3030
AUTH_SERVICE_URL=http://auth-app-bff:3030

# ============================================================================
# 其他配置（业务特定）
# ============================================================================
PROJECT_NAME=llmops-app-bff
SERVER_NAME=llmops-app-bff
SERVER_HOST=http://llmops-app-bff:8000

# Secret 配置（敏感信息，放在 Secret 中）
# SECRET_KEY=...
# TOTP_SECRET_KEY=...
# POSTGRES_SERVER=postgres
# POSTGRES_USER=...
# POSTGRES_PASSWORD=...
# POSTGRES_PORT=5432
# POSTGRES_DB=llmops_db
# NEO4J_SERVER=neo4j
# NEO4J_USERNAME=...
# NEO4J_PASSWORD=...
# REDIS_HOST=redis
# REDIS_PORT=6379
# REDIS_DB=0
# WEAVIATE_URL=...
# WEAVIATE_API_KEY=...
# COS_REGION=...
# COS_SECRET_ID=...
# COS_SECRET_KEY=...
# GITHUB_CLIENT_ID=...
# GITHUB_CLIENT_SECRET=...
# MOONSHOT_API_KEY=...
# DEEPSEEK_API_KEY=...
# GAODE_API_KEY=...
```

### 5. portal-app-ssr

```bash
# ============================================================================
# 业务 BFF 配置（联动配置 - 调用 portal-app-bff）
# ============================================================================
# 开发环境：http://localhost:3000
# 生产环境（K8s）：http://portal-app-bff:3000
VUE_APP_BFF_URL=http://portal-app-bff:3000
PORTAL_BFF_URL=http://portal-app-bff:3000

# API 前缀（必须与 portal-app-bff 的 PREFIX 一致）
VUE_APP_API_PREFIX=/api

# API 版本（必须与 portal-app-bff 的 VERSION 一致）
VUE_APP_API_VERSION=v1

# ============================================================================
# Session 配置（联动配置）
# ============================================================================
SESSION_COOKIE_NAME=sunmoonai_session

# ============================================================================
# 其他配置（业务特定）
# ============================================================================
NODE_ENV=production
```

### 6. incubator-app-ssr

```bash
# ============================================================================
# 业务 BFF 配置（联动配置 - 调用 incubator-app-bff）
# ============================================================================
# 开发环境：http://localhost:8000
# 生产环境（K8s）：http://incubator-app-bff:8000
VUE_APP_BFF_URL=http://incubator-app-bff:8000
INCUBATOR_BFF_URL=http://incubator-app-bff:8000

# API 版本（必须与 incubator-app-bff 的 API_V1_STR 中的版本一致）
VUE_APP_API_VERSION=v1

# ============================================================================
# Session 配置（联动配置）
# ============================================================================
SESSION_COOKIE_NAME=sunmoonai_session

# ============================================================================
# 其他配置（业务特定）
# ============================================================================
NODE_ENV=production
# BACKEND_API_URL=...
# AUTH_SERVICE_URL=...
```

### 7. llmops-app-ssr

```bash
# ============================================================================
# 业务 BFF 配置（联动配置 - 调用 llmops-app-bff）
# ============================================================================
# 开发环境：http://localhost:8000
# 生产环境（K8s）：http://llmops-app-bff:8000
VUE_APP_BFF_URL=http://llmops-app-bff:8000
LLMOPS_BFF_URL=http://llmops-app-bff:8000

# API 版本（必须与 llmops-app-bff 的 API_V1_STR 中的版本一致）
VUE_APP_API_VERSION=v1

# ============================================================================
# Session 配置（联动配置）
# ============================================================================
SESSION_COOKIE_NAME=sunmoonai_session

# ============================================================================
# 其他配置（业务特定）
# ============================================================================
NODE_ENV=production
# BACKEND_API_URL=...
# AUTH_SERVICE_URL=...
```

---

## K8s ConfigMap 和 Secret 使用

### ConfigMap（非敏感信息）

已创建：`/home/zym/k8s/sunmoonai/configmaps/environment-configmap.yaml`

包含：
- 所有服务的端口、前缀、版本配置
- Session Cookie 名称
- SSR 的 BFF URL 配置

### Secret（敏感信息）

已创建：`/home/zym/k8s/sunmoonai/secrets/environment-secret.yaml.example`

包含：
- 所有服务的密钥（SECRET_KEY、JWT_SECRET 等）
- 数据库密码
- Redis 密码
- 第三方 API 密钥

### 部署步骤

1. **创建 ConfigMap**：
   ```bash
   kubectl apply -f k8s/sunmoonai/configmaps/environment-configmap.yaml
   ```

2. **创建 Secret**：
   ```bash
   # 创建 secret-values.txt 文件（包含所有敏感值）
   kubectl create secret generic sunmoonai-environment-secret \
     --from-env-file=secret-values.txt \
     --namespace=default
   ```

3. **在 Deployment 中引用**：
   见 `/home/zym/k8s/sunmoonai/docs/environment-variables-k8s-deployment.md`

---

## 联动关系图

```
┌─────────────────┐
│  portal-app-ssr │
│  (Nuxt SSR)     │
└────────┬────────┘
         │ BFF_URL=http://portal-app-bff:3000
         │ SESSION_COOKIE_NAME=sunmoonai_session
         ▼
┌─────────────────┐
│ portal-app-bff  │
│  (NestJS)       │
└────────┬────────┘
         │ AUTH_SERVICE_URL=http://auth-app-bff:3030
         │ SESSION_COOKIE_NAME=sunmoonai_session
         ▼
┌─────────────────┐
│  auth-app-bff   │
│  (NestJS)       │
│  PORT=3030      │
│  SESSION_COOKIE_NAME=sunmoonai_session
└─────────────────┘

┌─────────────────┐
│incubator-app-ssr│
│  (Nuxt SSR)     │
└────────┬────────┘
         │ BFF_URL=http://incubator-app-bff:8000
         │ SESSION_COOKIE_NAME=sunmoonai_session
         ▼
┌─────────────────┐
│incubator-app-bff│
│  (FastAPI)      │
└────────┬────────┘
         │ AUTH_SERVICE_URL=http://auth-app-bff:3030
         │ SESSION_COOKIE_NAME=sunmoonai_session
         ▼
┌─────────────────┐
│  auth-app-bff   │
│  (NestJS)       │
│  PORT=3030      │
│  SESSION_COOKIE_NAME=sunmoonai_session
└─────────────────┘

┌─────────────────┐
│ llmops-app-ssr  │
│  (Nuxt SSR)     │
└────────┬────────┘
         │ BFF_URL=http://llmops-app-bff:8000
         │ SESSION_COOKIE_NAME=sunmoonai_session
         ▼
┌─────────────────┐
│ llmops-app-bff  │
│  (FastAPI)      │
└────────┬────────┘
         │ AUTH_SERVICE_URL=http://auth-app-bff:3030
         │ SESSION_COOKIE_NAME=sunmoonai_session
         ▼
┌─────────────────┐
│  auth-app-bff   │
│  (NestJS)       │
│  PORT=3030      │
│  SESSION_COOKIE_NAME=sunmoonai_session
└─────────────────┘
```

---

## 总结

✅ **已完成的配置：**
1. 统一了所有联动环境变量
2. 创建了 K8s ConfigMap 配置
3. 创建了 K8s Secret 配置示例
4. 创建了详细的部署文档

📝 **关键联动变量：**
- `SESSION_COOKIE_NAME=sunmoonai_session`（所有服务必须一致）
- `AUTH_SERVICE_URL=http://auth-app-bff:3030`（业务 BFF 调用认证服务）
- `BFF_URL`（SSR 调用业务 BFF，端口必须与业务 BFF 的 PORT 一致）

🔧 **K8s 部署要点：**
- 使用 K8s Service 名称（如 `auth-app-bff:3030`）而不是 `localhost`
- 非敏感信息放在 ConfigMap 中
- 敏感信息放在 Secret 中
- 所有服务必须使用相同的 `SESSION_COOKIE_NAME`

