# BFF 环境变量对比说明

本文档说明 `auth-app-bff` 和其他业务 BFF（`portal-app-bff`、`incubator-app-bff`、`llmops-app-bff`）的环境变量配置关系。

## 核心问题

**如果 `auth-app-bff` 使用了某些环境变量（如 `PORT`、`PREFIX`、`VERSION`），那么其他业务 BFF 是否也需要这些环境变量？**

**答案：部分需要，但用途不同。**

---

## 环境变量分类

### 1. 服务自身配置（每个 BFF 都需要，但值可以不同）

这些环境变量用于配置 BFF 服务自身的运行参数：

| 环境变量 | auth-app-bff | portal-app-bff | incubator-app-bff | llmops-app-bff | 说明 |
|---------|--------------|----------------|-------------------|----------------|------|
| **PORT** | ✅ 3030 | ✅ 3000 | ❌ (FastAPI 默认 8000) | ❌ (FastAPI 默认 8000) | 服务监听端口 |
| **PREFIX** | ✅ `/api` | ✅ `/api` | ❌ (使用 `API_V1_STR`) | ❌ (使用 `API_V1_STR`) | API 前缀 |
| **VERSION** | ✅ `v1` | ✅ `v1` | ❌ (硬编码在 `API_V1_STR`) | ❌ (硬编码在 `API_V1_STR`) | API 版本 |

**说明：**
- 每个 BFF 都有自己的 `PORT`，因为它们都是独立的服务
- NestJS BFF（`auth-app-bff`、`portal-app-bff`）使用 `PREFIX` 和 `VERSION`
- FastAPI BFF（`incubator-app-bff`、`llmops-app-bff`）使用 `API_V1_STR`（包含前缀和版本）

### 2. 调用 auth-app-bff 的配置（所有业务 BFF 都需要）

这些环境变量用于业务 BFF 调用 `auth-app-bff`：

| 环境变量 | portal-app-bff | incubator-app-bff | llmops-app-bff | 说明 |
|---------|----------------|-------------------|----------------|------|
| **AUTH_SERVICE_URL** | ✅ 必需 | ✅ 必需 | ✅ 必需 | auth-app-bff 的访问地址 |

**说明：**
- 所有业务 BFF 都需要 `AUTH_SERVICE_URL` 来调用 `auth-app-bff`
- 这个地址需要包含 `auth-app-bff` 的协议、主机和端口
- **不需要**包含路径（`/api/v1`），因为路径在代码中硬编码

---

## 详细对比

### auth-app-bff (NestJS)

**环境变量：**

```bash
# 服务自身配置
PORT=3030                    # HTTP 服务端口
PREFIX=/api                  # API 前缀
VERSION=v1                   # API 版本

# 其他配置
SECRET_KEY=...               # JWT 密钥
SESSION_COOKIE_NAME=sunmoonai_session
REDIS_HOST=localhost
REDIS_PORT=6379
# ... 其他配置
```

**API 地址格式：**
```
http://localhost:3030/api/v1/auth/me
```

### portal-app-bff (NestJS)

**环境变量：**

```bash
# 服务自身配置（与 auth-app-bff 类似，但值可以不同）
PORT=3000                    # 自己的端口（不同于 auth-app-bff）
PREFIX=/api                  # 自己的 API 前缀（可以与 auth-app-bff 相同）
VERSION=v1                   # 自己的 API 版本（可以与 auth-app-bff 相同）

# 调用 auth-app-bff 的配置（必需）
AUTH_SERVICE_URL=http://localhost:3030  # auth-app-bff 的地址

# 其他配置
JWT_SECRET=...               # 自己的 JWT 密钥（如果使用）
# ... 其他配置
```

**API 地址格式：**
```
# 自己的 API
http://localhost:3000/api/v1/auth/me

# 调用 auth-app-bff
http://localhost:3030/api/v1/auth/me  # 通过 AUTH_SERVICE_URL 配置
```

### incubator-app-bff (FastAPI)

**环境变量：**

```bash
# 服务自身配置（FastAPI 使用不同的方式）
API_V1_STR=/api/v1          # 包含前缀和版本（相当于 PREFIX + VERSION）

# 调用 auth-app-bff 的配置（必需）
AUTH_SERVICE_URL=http://localhost:3030  # auth-app-bff 的地址

# 其他配置
SECRET_KEY=...               # 自己的密钥
POSTGRES_SERVER=...
# ... 其他配置
```

**API 地址格式：**
```
# 自己的 API
http://localhost:8000/api/v1/auth/me

# 调用 auth-app-bff
http://localhost:3030/api/v1/auth/me  # 通过 AUTH_SERVICE_URL 配置
```

### llmops-app-bff (FastAPI)

**环境变量：**

```bash
# 服务自身配置（与 incubator-app-bff 类似）
API_V1_STR=/api/v1          # 包含前缀和版本

# 调用 auth-app-bff 的配置（必需）
AUTH_SERVICE_URL=http://localhost:3030  # auth-app-bff 的地址

# 其他配置
SECRET_KEY=...
POSTGRES_SERVER=...
# ... 其他配置
```

**API 地址格式：**
```
# 自己的 API
http://localhost:8000/api/v1/auth/me

# 调用 auth-app-bff
http://localhost:3030/api/v1/auth/me  # 通过 AUTH_SERVICE_URL 配置
```

---

## 关键区别

### 1. PORT 配置

| BFF | PORT 用途 | 默认值 | 说明 |
|-----|----------|--------|------|
| **auth-app-bff** | 自己的服务端口 | 3030 | 认证服务端口 |
| **portal-app-bff** | 自己的服务端口 | 3000 | 门户 BFF 端口 |
| **incubator-app-bff** | 自己的服务端口 | 8000 | FastAPI 默认端口 |
| **llmops-app-bff** | 自己的服务端口 | 8000 | FastAPI 默认端口 |

**结论：** 每个 BFF 都有自己的 `PORT`，值可以不同。

### 2. PREFIX / API_V1_STR 配置

| BFF | 配置方式 | 默认值 | 说明 |
|-----|---------|--------|------|
| **auth-app-bff** | `PREFIX=/api` | `/api` | NestJS 使用 PREFIX |
| **portal-app-bff** | `PREFIX=/api` | `/api` | NestJS 使用 PREFIX |
| **incubator-app-bff** | `API_V1_STR=/api/v1` | `/api/v1` | FastAPI 使用 API_V1_STR |
| **llmops-app-bff** | `API_V1_STR=/api/v1` | `/api/v1` | FastAPI 使用 API_V1_STR |

**结论：** 
- NestJS BFF 使用 `PREFIX`（只包含前缀）
- FastAPI BFF 使用 `API_V1_STR`（包含前缀和版本）
- 值可以不同，但建议保持一致以便统一管理

### 3. VERSION 配置

| BFF | 配置方式 | 默认值 | 说明 |
|-----|---------|--------|------|
| **auth-app-bff** | `VERSION=v1` | `v1` | NestJS 使用 VERSION |
| **portal-app-bff** | `VERSION=v1` | `v1` | NestJS 使用 VERSION |
| **incubator-app-bff** | 硬编码在 `API_V1_STR` | `v1` | 包含在 `/api/v1` 中 |
| **llmops-app-bff** | 硬编码在 `API_V1_STR` | `v1` | 包含在 `/api/v1` 中 |

**结论：** 
- NestJS BFF 使用独立的 `VERSION` 环境变量
- FastAPI BFF 将版本硬编码在 `API_V1_STR` 中
- 建议保持一致（都使用 `v1`）

### 4. AUTH_SERVICE_URL 配置

| BFF | 是否必需 | 默认值 | 说明 |
|-----|---------|--------|------|
| **auth-app-bff** | ❌ 不需要 | - | 自己是认证服务 |
| **portal-app-bff** | ✅ 必需 | `http://localhost:3030` | 调用 auth-app-bff |
| **incubator-app-bff** | ✅ 必需 | `http://localhost:3030` | 调用 auth-app-bff |
| **llmops-app-bff** | ✅ 必需 | `http://localhost:3030` | 调用 auth-app-bff |

**结论：** 所有业务 BFF 都需要 `AUTH_SERVICE_URL` 来调用 `auth-app-bff`。

---

## 代码中的使用方式

### portal-app-bff 调用 auth-app-bff

```typescript
// src/common/auth-client/auth-client.service.ts
constructor(private configService: ConfigService) {
  // 从环境变量读取 auth-app-bff 的地址
  this.baseUrl = this.configService.get<string>('AUTH_SERVICE_URL') || 
                 'http://localhost:3030';
}

// 调用时，路径是硬编码的
const response = await this.httpClient.get(
  `${this.baseUrl}/api/v1/auth/me`,  // /api/v1 是硬编码的
  { headers }
);
```

### incubator-app-bff 调用 auth-app-bff

```python
# app/core/auth_client.py
class AuthClient:
    def __init__(self):
        # 从环境变量读取 auth-app-bff 的地址
        self.base_url = settings.AUTH_SERVICE_URL  # 默认 "http://localhost:3030"
    
    async def get_current_user(self, request: Request):
        # 调用时，路径是硬编码的
        response = await client.get(
            f"{self.base_url}/api/v1/auth/me",  # /api/v1 是硬编码的
            headers=headers
        )
```

---

## 环境变量配置示例

### 开发环境

**auth-app-bff `.env`**
```bash
PORT=3030
PREFIX=/api
VERSION=v1
SESSION_COOKIE_NAME=sunmoonai_session
```

**portal-app-bff `.env`**
```bash
PORT=3000                    # 自己的端口
PREFIX=/api                  # 自己的前缀
VERSION=v1                   # 自己的版本
AUTH_SERVICE_URL=http://localhost:3030  # auth-app-bff 的地址
```

**incubator-app-bff `.env`**
```bash
API_V1_STR=/api/v1          # 自己的 API 路径
AUTH_SERVICE_URL=http://localhost:3030  # auth-app-bff 的地址
```

**llmops-app-bff `.env`**
```bash
API_V1_STR=/api/v1          # 自己的 API 路径
AUTH_SERVICE_URL=http://localhost:3030  # auth-app-bff 的地址
```

### 生产环境（K8s）

**auth-app-bff**
```bash
PORT=3030
PREFIX=/api
VERSION=v1
```

**portal-app-bff**
```bash
PORT=3000
PREFIX=/api
VERSION=v1
AUTH_SERVICE_URL=http://auth-app-bff:3030  # K8s Service 名称
```

**incubator-app-bff**
```bash
API_V1_STR=/api/v1
AUTH_SERVICE_URL=http://auth-app-bff:3030  # K8s Service 名称
```

**llmops-app-bff**
```bash
API_V1_STR=/api/v1
AUTH_SERVICE_URL=http://auth-app-bff:3030  # K8s Service 名称
```

---

## 总结

### ✅ 需要配置的环境变量

1. **服务自身配置**（每个 BFF 都需要，但值可以不同）：
   - `PORT`（NestJS BFF）或使用默认端口（FastAPI BFF）
   - `PREFIX`（NestJS BFF）或 `API_V1_STR`（FastAPI BFF）
   - `VERSION`（NestJS BFF）或硬编码在 `API_V1_STR`（FastAPI BFF）

2. **调用 auth-app-bff 的配置**（所有业务 BFF 都需要）：
   - `AUTH_SERVICE_URL`：auth-app-bff 的访问地址

### ❌ 不需要完全相同的环境变量

- 业务 BFF 的 `PORT` 可以与 `auth-app-bff` 不同
- 业务 BFF 的 `PREFIX`/`API_V1_STR` 可以与 `auth-app-bff` 不同（但建议保持一致）
- 业务 BFF 的 `VERSION` 可以与 `auth-app-bff` 不同（但建议保持一致）

### ⚠️ 注意事项

1. **AUTH_SERVICE_URL 的端口必须与 auth-app-bff 的 PORT 一致**
   - 如果 `auth-app-bff` 的 `PORT=3030`，那么业务 BFF 的 `AUTH_SERVICE_URL` 必须是 `http://...:3030`

2. **路径是硬编码的**
   - 代码中硬编码了 `/api/v1` 路径
   - 如果 `auth-app-bff` 的 `PREFIX` 或 `VERSION` 改变，需要修改业务 BFF 的代码

3. **建议保持配置一致**
   - 虽然值可以不同，但建议所有 BFF 使用相同的 `PREFIX` 和 `VERSION`，便于统一管理

