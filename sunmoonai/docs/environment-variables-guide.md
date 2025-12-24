# 环境变量定义和使用规范文档

## 概述

本文档详细说明四种技术栈在环境变量方面的定义方式、传递方式和 K8s 部署配置：

- **Nuxt.js SSR** - 前端 SSR 应用
- **NestJS BFF** - 后端 BFF 服务（Node.js）
- **FastAPI BFF** - 后端 BFF 服务（Python）
- **Vite SSR** - 前端 SSR 应用（未来）

## 环境变量定义与传递方式总览

### 定义方式（Value Source）

环境变量的值可以从以下来源获取：

| 定义方式 | 说明 | 适用场景 |
|---------|------|---------|
| **1. 环境变量文件** | `.env`、`.env.local`、`.env.production` 等 | 本地开发、多环境配置 |
| **2. 系统环境变量** | `export VAR=value` 或容器环境变量 | 生产环境、CI/CD |
| **3. 显式配置** | 在代码配置文件中定义（带默认值） | 默认值、开发环境 |
| **4. 配置文件** | `config.yaml`、`config.json` 等 | 复杂配置、配置中心 |

### 传递方式（Delivery Method）

环境变量如何传递到应用：

| 传递方式 | 说明 | 适用场景 |
|---------|------|---------|
| **1. 源码直接使用** | 代码中直接读取 `process.env` 或 `import.meta.env` | 所有场景的基础 |
| **2. 环境变量文件** | 通过 `.env` 文件加载 | 本地开发 |
| **3. Docker Compose** | `docker-compose.yml` 中的 `environment` 或 `env_file` | 本地容器化开发 |
| **4. K8s ConfigMap/Secret** | 通过 `envFrom` 或 `env` 注入到容器 | 生产环境、K8s 部署 |
| **5. 配置中心** | 从 Vault、Consul、Nacos 等读取 | 大型系统、动态配置 |

### 四种技术栈对比

| 技术栈 | 定义方式 | 传递方式 | 源码访问方式 |
|--------|---------|---------|------------|
| **Nuxt.js SSR** | 1. `.env` 文件<br>2. 系统环境变量<br>3. `nuxt.config.ts` 显式配置 | 1. 直接读取 `process.env`<br>2. Docker Compose `env_file`<br>3. K8s ConfigMap/Secret | `useRuntimeConfig()`<br>`process.env.XXX` |
| **NestJS BFF** | 1. `.env` 文件<br>2. 系统环境变量<br>3. `ConfigModule` 默认值 | 1. `ConfigModule.forRoot()`<br>2. Docker Compose `environment`<br>3. K8s ConfigMap/Secret | `ConfigService.get()`<br>`process.env.XXX` |
| **FastAPI BFF** | 1. `.env` 文件<br>2. 系统环境变量<br>3. `Settings` 类默认值 | 1. `BaseSettings` 自动加载<br>2. Docker Compose `environment`<br>3. K8s ConfigMap/Secret | `settings.XXX`<br>`os.getenv()` |
| **Vite SSR** | 1. `.env` 文件<br>2. 系统环境变量<br>3. `vite.config.ts` 配置 | 1. `import.meta.env`<br>2. Docker Compose `env_file`<br>3. K8s ConfigMap/Secret | `import.meta.env.XXX`<br>`process.env.XXX`（服务端） |

## 文档结构

### 一、环境变量定义与传递方式总览
### 二、技术栈环境变量使用方式
### 三、K8s 部署配置规范
### 四、实际应用示例
### 五、最佳实践

---

## 一、环境变量定义与传递方式总览

### 1.1 定义方式（Value Source）

环境变量的值可以从以下来源获取：

| 定义方式 | 说明 | 示例 | 适用场景 |
|---------|------|------|---------|
| **环境变量文件** | `.env`、`.env.local`、`.env.production` 等 | `VUE_APP_NAME=MyApp` | 本地开发、多环境配置 |
| **系统环境变量** | `export VAR=value` 或容器环境变量 | `export REDIS_HOST=localhost` | 生产环境、CI/CD |
| **显式配置（默认值）** | 在代码配置文件中定义默认值 | `apiUrl: process.env.API_URL \|\| 'http://localhost'` | 开发环境、兜底值 |
| **配置文件** | `config.yaml`、`config.json` 等 | `config: { apiUrl: '...' }` | 复杂配置、配置中心 |

### 1.2 传递方式（Delivery Method）

环境变量如何传递到应用运行时：

| 传递方式 | 说明 | 配置示例 | 适用场景 |
|---------|------|---------|---------|
| **源码直接读取** | 代码中直接读取 `process.env` 或 `import.meta.env` | `const url = process.env.API_URL` | 所有场景的基础 |
| **环境变量文件加载** | 框架自动加载 `.env` 文件 | `.env` 文件放在项目根目录 | 本地开发 |
| **Docker Compose** | `docker-compose.yml` 中的 `environment` 或 `env_file` | 见下方示例 | 本地容器化开发 |
| **K8s ConfigMap/Secret** | 通过 `envFrom` 或 `env` 注入到容器 | 见下方示例 | 生产环境、K8s 部署 |
| **配置中心** | 从 Vault、Consul、Nacos 等读取 | 通过 SDK 调用配置中心 API | 大型系统、动态配置 |

### 1.3 Docker Compose 传递方式示例

```yaml
# docker-compose.yml
services:
  app:
    image: app:latest
    # 方式一：直接定义环境变量
    environment:
      - NODE_ENV=production
      - API_URL=https://api.example.com
      - REDIS_HOST=redis
    
    # 方式二：从 .env 文件加载
    env_file:
      - .env
      - .env.production
    
    # 方式三：混合使用（environment 优先级更高）
    environment:
      - NODE_ENV=production  # 覆盖 .env 文件中的值
    env_file:
      - .env
```

### 1.4 K8s 传递方式示例

```yaml
# Deployment
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        # 方式一：从 ConfigMap/Secret 批量注入
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secret
        
        # 方式二：单独注入特定变量
        env:
        - name: API_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: API_URL
        
        # 方式三：直接设置（优先级最高）
        env:
        - name: NODE_ENV
          value: "production"
```

### 1.5 四种技术栈对比

| 技术栈 | 定义方式 | 传递方式 | 源码访问方式 |
|--------|---------|---------|------------|
| **Nuxt.js SSR** | 1. `.env` 文件<br>2. 系统环境变量<br>3. `nuxt.config.ts` 显式配置 | 1. 自动加载 `.env`<br>2. Docker Compose `env_file`<br>3. K8s ConfigMap/Secret | `useRuntimeConfig()`<br>`process.env.XXX`（服务端） |
| **NestJS BFF** | 1. `.env` 文件<br>2. 系统环境变量<br>3. `ConfigModule` 默认值 | 1. `ConfigModule.forRoot()`<br>2. Docker Compose `environment`<br>3. K8s ConfigMap/Secret | `ConfigService.get()`<br>`process.env.XXX` |
| **FastAPI BFF** | 1. `.env` 文件<br>2. 系统环境变量<br>3. `Settings` 类默认值 | 1. `BaseSettings` 自动加载<br>2. Docker Compose `environment`<br>3. K8s ConfigMap/Secret | `settings.XXX`<br>`os.getenv()` |
| **Vite SSR** | 1. `.env` 文件<br>2. 系统环境变量<br>3. `vite.config.ts` 配置 | 1. 自动加载 `.env`<br>2. Docker Compose `env_file`<br>3. K8s ConfigMap/Secret | `import.meta.env.XXX`<br>`process.env.XXX`（服务端） |

---

## 二、技术栈环境变量使用方式

#### 1.1 Nuxt.js SSR

**技术栈特点：**
- 使用 `runtimeConfig` 在 `nuxt.config.ts` 中配置如何读取环境变量
- 通过 `useRuntimeConfig()` composable 在代码中使用
- 区分 `private`（仅服务端）和 `public`（客户端可访问）配置

**1. 环境变量文件定义（.env）**

在项目根目录创建 `.env` 文件定义环境变量：

```bash
# .env
VUE_APP_NAME=SunMoonAI Auth
VUE_APP_ENV=production
VUE_APP_DOMAIN_API=https://api.sunmoonai.com
VUE_APP_BFF_URL=https://auth-bff.sunmoonai.com
SESSION_COOKIE_NAME=sunmoonai_session

# 服务端专用（不以 VUE_APP_ 开头）
VUE_PRIVATE_TERM=your-secret-key
```

**2. 源码配置方式（nuxt.config.ts）**

Nuxt.js 支持三种方式使用环境变量：

**方式一：显式配置（推荐用于客户端可访问的配置）**

在 `runtimeConfig.public` 中显式声明需要在客户端访问的环境变量：

```typescript
export default defineNuxtConfig({
  runtimeConfig: {
    // Private keys - 仅服务端可用（可选，也可以直接使用 process.env）
    apiSecret: process.env.VUE_PRIVATE_TERM,
    
    // Public keys - 客户端可访问（必须显式声明）
    public: {
      appName: process.env.VUE_APP_NAME,
      appEnv: process.env.VUE_APP_ENV,
      apiUrl: process.env.VUE_APP_DOMAIN_API,
      bffUrl: process.env.VUE_APP_BFF_URL || process.env.VUE_APP_DOMAIN_API,
      sessionCookieName: process.env.SESSION_COOKIE_NAME || 'sunmoonai_session',
    }
  }
})
```

**方式二：直接使用 process.env（适合服务端，变量多时）**

如果有很多环境变量，不需要全部在 `runtimeConfig` 中声明，服务端代码可以直接使用 `process.env`：

```typescript
// nuxt.config.ts - 只声明需要在客户端访问的配置
export default defineNuxtConfig({
  runtimeConfig: {
    public: {
      // 只声明客户端需要的配置
      apiUrl: process.env.VUE_APP_DOMAIN_API,
    }
  }
})

// server/middleware/auth.global.ts - 服务端直接使用 process.env
export default defineEventHandler(async (event) => {
  // 服务端可以直接访问所有环境变量，无需在 runtimeConfig 中声明
  const redisHost = process.env.REDIS_HOST
  const redisPort = process.env.REDIS_PORT
  const dbUrl = process.env.DATABASE_URL
  const apiSecret = process.env.VUE_PRIVATE_TERM
  // ... 其他环境变量
})
```

**方式三：混合方式（最佳实践）**

常用配置通过 `runtimeConfig` 提供类型安全，其他配置直接使用 `process.env`：

```typescript
export default defineNuxtConfig({
  runtimeConfig: {
    // 常用配置，提供类型安全和默认值
    apiSecret: process.env.VUE_PRIVATE_TERM,
    public: {
      apiUrl: process.env.VUE_APP_DOMAIN_API,
      sessionCookieName: process.env.SESSION_COOKIE_NAME || 'sunmoonai_session',
    }
  }
})
```

**说明：**
- ✅ **客户端访问**：必须在 `runtimeConfig.public` 中显式声明
- ✅ **服务端访问**：可以直接使用 `process.env.XXX`，无需在 `runtimeConfig` 中声明
- ✅ **类型安全**：通过 `runtimeConfig` 访问的配置有类型提示
- ✅ **灵活性**：`.env` 文件中的所有变量都可以通过 `process.env` 访问（服务端）

**3. 源码使用方式**

**客户端代码（必须通过 runtimeConfig.public）：**
```typescript
// api/core.ts
export const apiCore = {
  url(): string {
    // 客户端只能访问 runtimeConfig.public 中的配置
    return useRuntimeConfig().public.apiUrl
  }
}
```

**服务端代码（两种方式都可以）：**

**方式一：通过 runtimeConfig（推荐，有类型提示）**
```typescript
// server/middleware/auth.global.ts
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  const sessionCookieName = config.public.sessionCookieName || 'sunmoonai_session'
  const apiSecret = config.apiSecret  // 从 runtimeConfig 读取
})
```

**方式二：直接使用 process.env（适合变量多时）**
```typescript
// server/middleware/auth.global.ts
export default defineEventHandler(async (event) => {
  // 服务端可以直接访问所有环境变量，无需在 runtimeConfig 中声明
  const redisHost = process.env.REDIS_HOST
  const redisPort = process.env.REDIS_PORT
  const dbUrl = process.env.DATABASE_URL
  const apiSecret = process.env.VUE_PRIVATE_TERM
  const sessionCookieName = process.env.SESSION_COOKIE_NAME || 'sunmoonai_session'
  
  // 使用这些环境变量
  const redis = new Redis({
    host: redisHost,
    port: parseInt(redisPort || '6379'),
  })
})
```

**混合使用（最佳实践）：**
```typescript
// server/middleware/auth.global.ts
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  
  // 常用配置从 runtimeConfig 读取（有类型提示）
  const apiUrl = config.public.apiUrl
  const apiSecret = config.apiSecret
  
  // 其他配置直接使用 process.env（无需声明）
  const redisHost = process.env.REDIS_HOST
  const dbUrl = process.env.DATABASE_URL
})
```

**4. Docker Compose 传递方式**

```yaml
# docker-compose.yml
services:
  auth-app-ssr:
    image: auth-app-ssr:latest
    # 方式一：直接定义环境变量
    environment:
      - VUE_APP_NAME=SunMoonAI Auth
      - VUE_APP_ENV=production
      - VUE_APP_DOMAIN_API=https://api.sunmoonai.com
      - SESSION_COOKIE_NAME=sunmoonai_session
    
    # 方式二：从 .env 文件加载（推荐）
    env_file:
      - .env
      - .env.production
    
    # 方式三：混合使用（environment 优先级更高）
    environment:
      - VUE_APP_ENV=production  # 覆盖 .env 文件中的值
    env_file:
      - .env
```

**5. K8s 部署配置**

环境变量通过 K8s ConfigMap/Secret 注入到容器，Nuxt 在运行时读取 `process.env`。

**ConfigMap 示例：**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: auth-app-ssr-config
data:
  VUE_APP_NAME: "SunMoonAI Auth"
  VUE_APP_ENV: "production"
  VUE_APP_DOMAIN_API: "https://api.sunmoonai.com"
  VUE_APP_BFF_URL: "https://auth-bff.sunmoonai.com"
  SESSION_COOKIE_NAME: "sunmoonai_session"
```

**Deployment 配置：**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: auth-app-ssr
        envFrom:
        - configMapRef:
            name: auth-app-ssr-config
        - secretRef:
            name: auth-app-ssr-secrets  # 敏感配置
```

**5. 注意事项**

- ✅ **客户端访问限制**：只有 `runtimeConfig.public` 中的配置才能在客户端访问
- ✅ **服务端灵活性**：服务端可以直接使用 `process.env.XXX`，无需在 `runtimeConfig` 中声明
- ✅ **类型安全**：通过 `runtimeConfig` 访问的配置有类型提示，直接使用 `process.env` 没有
- ✅ **敏感信息**：`public` 配置会暴露到客户端，不要放敏感信息
- ✅ **环境变量前缀**：客户端可访问的变量建议使用 `VUE_APP_` 前缀（Nuxt 3 兼容）
- ✅ **默认值**：使用默认值避免未定义错误：`process.env.XXX || 'default'`
- ✅ **变量多时**：如果有很多环境变量，服务端代码可以直接使用 `process.env`，无需全部在 `runtimeConfig` 中声明
#### 1.2 NestJS BFF

**技术栈特点：**
- 使用 `@nestjs/config` 模块管理环境变量
- 通过 `ConfigService` 注入使用
- 支持 Joi 验证和类型转换
- 支持多环境 `.env` 文件

**1. 环境变量文件定义（.env）**

在项目根目录创建 `.env` 文件定义环境变量：

```bash
# .env
NODE_ENV=production
REDIS_HOST=redis-service
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=your-redis-password
SESSION_TTL_SECONDS=604800
SESSION_COOKIE_NAME=sunmoonai_session
JWT_SECRET=your-jwt-secret
```

**2. 源码配置方式（config.module.ts）**

在 `src/common/config/config.module.ts` 中配置如何读取环境变量：

```typescript
import { Module } from '@nestjs/common';
import * as Joi from 'joi';
import { ConfigModule as Config } from '@nestjs/config';

const schema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production')
    .default('development'),
  REDIS_HOST: Joi.string().default('localhost'),
  REDIS_PORT: Joi.number().default(6379),
});

const envFilePath = [`.env.${process.env.NODE_ENV || 'development'}`, '.env'];

@Module({
  imports: [
    Config.forRoot({
      isGlobal: true,  // 全局可用，无需在每个模块导入
      envFilePath,
      validationSchema: schema,  // 可选：环境变量验证
    }),
  ],
})
export class ConfigModule {}
```

**3. 源码使用方式**

**在 Service 中注入使用：**
```typescript
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class RedisService {
  constructor(private configService: ConfigService) {}

  async onModuleInit() {
    const redis = new Redis({
      host: this.configService.get<string>('REDIS_HOST', 'localhost'),
      port: this.configService.get<number>('REDIS_PORT', 6379),
      password: this.configService.get<string>('REDIS_PASSWORD'),
    });
  }
}
```

**类型安全的使用方式：**
```typescript
// 带默认值
const host = this.configService.get<string>('REDIS_HOST', 'localhost');

// 类型转换
const port = this.configService.get<number>('REDIS_PORT', 6379);

// 必填项（无默认值，缺失会报错）
const password = this.configService.get<string>('REDIS_PASSWORD');
```

**4. Docker Compose 传递方式**

```yaml
# docker-compose.yml
services:
  auth-app-bff:
    image: auth-app-bff:latest
    # 方式一：直接定义环境变量
    environment:
      - NODE_ENV=production
      - REDIS_HOST=redis-service
      - REDIS_PORT=6379
      - SESSION_TTL_SECONDS=604800
    
    # 方式二：从 .env 文件加载（推荐）
    env_file:
      - .env
      - .env.production
    
    # 方式三：混合使用（environment 优先级更高）
    environment:
      - NODE_ENV=production  # 覆盖 .env 文件中的值
    env_file:
      - .env
    # 注意：敏感信息（如密码）建议使用 secrets
    secrets:
      - redis_password
      - jwt_secret

secrets:
  redis_password:
    file: ./secrets/redis_password.txt
  jwt_secret:
    file: ./secrets/jwt_secret.txt
```

**5. K8s 部署配置**

环境变量通过 K8s ConfigMap/Secret 注入，NestJS 自动读取 `process.env`。

**ConfigMap 示例：**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: auth-app-bff-config
data:
  NODE_ENV: "production"
  REDIS_HOST: "redis-service"
  REDIS_PORT: "6379"
  REDIS_DB: "0"
  SESSION_TTL_SECONDS: "604800"
  SESSION_COOKIE_NAME: "sunmoonai_session"
```

**Secret 示例（敏感配置）：**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: auth-app-bff-secrets
type: Opaque
stringData:
  REDIS_PASSWORD: "your-redis-password"
  JWT_SECRET: "your-jwt-secret"
```

**Deployment 配置：**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: auth-app-bff
        envFrom:
        - configMapRef:
            name: auth-app-bff-config
        - secretRef:
            name: auth-app-bff-secrets
```

**5. 注意事项**

- ✅ 使用 `isGlobal: true` 使 ConfigModule 全局可用
- ✅ 使用 Joi 验证确保环境变量格式正确
- ✅ 敏感信息（密码、密钥）放在 Secret 中
- ✅ 提供默认值避免运行时错误
- ✅ 支持 `.env.development`、`.env.production` 等多环境文件
#### 1.3 FastAPI BFF

**技术栈特点：**
- 使用 `pydantic-settings` 的 `BaseSettings` 管理环境变量
- 支持类型验证和自动类型转换
- 通过 `SettingsConfigDict` 配置加载方式
- 全局 `settings` 对象，直接导入使用

**1. 环境变量文件定义（.env）**

在项目根目录创建 `.env` 文件定义环境变量：

```bash
# .env
PROJECT_NAME=My App
SERVER_NAME=app-service
SERVER_HOST=https://api.example.com
AUTH_SERVICE_URL=http://auth-service:3030
POSTGRES_SERVER=postgres-service
POSTGRES_USER=app_user
POSTGRES_PASSWORD=your-db-password
POSTGRES_PORT=5432
POSTGRES_DB=app_db
BACKEND_CORS_ORIGINS=["https://app.example.com"]
```

**2. 源码配置方式（config.py）**

在 `app/core/config.py` 中配置如何读取环境变量：

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import field_validator, AnyHttpUrl
from typing import List, Optional

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_ignore_empty=True,
        extra="ignore"
    )
    
    # 基础配置
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str
    SERVER_NAME: str
    SERVER_HOST: AnyHttpUrl
    
    # 认证服务配置
    AUTH_SERVICE_URL: str = "http://localhost:3030"
    
    # 数据库配置
    POSTGRES_SERVER: str
    POSTGRES_USER: str
    POSTGRES_PASSWORD: str
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = ""
    
    # CORS 配置（支持自定义验证器）
    BACKEND_CORS_ORIGINS: List[AnyHttpUrl] = []
    
    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Any) -> list[str] | str:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)

# 全局 settings 实例
settings = Settings()
```

**3. 源码使用方式**

**直接导入 settings 对象：**
```python
from app.core.config import settings

class AuthClient:
    def __init__(self):
        self.base_url = settings.AUTH_SERVICE_URL
    
    async def get_current_user(self, request: Request):
        # 使用 settings 中的配置
        response = await client.get(
            f"{settings.AUTH_SERVICE_URL}/api/v1/auth/me",
            headers=headers
        )
```

**在依赖注入中使用：**
```python
from fastapi import Depends
from app.core.config import settings

async def get_db():
    # 使用 settings 中的数据库配置
    db_url = f"postgresql://{settings.POSTGRES_USER}:{settings.POSTGRES_PASSWORD}@{settings.POSTGRES_SERVER}/{settings.POSTGRES_DB}"
    # ...
```

**4. Docker Compose 传递方式**

```yaml
# docker-compose.yml
services:
  incubator-app-bff:
    image: incubator-app-bff:latest
    # 方式一：直接定义环境变量
    environment:
      - PROJECT_NAME=Incubator App
      - SERVER_NAME=incubator-app-bff
      - AUTH_SERVICE_URL=http://auth-app-bff:3030
      - POSTGRES_SERVER=postgres-service
      - POSTGRES_PORT=5432
    
    # 方式二：从 .env 文件加载（推荐）
    env_file:
      - .env
      - .env.production
    
    # 方式三：混合使用（environment 优先级更高）
    environment:
      - PROJECT_NAME=Incubator App  # 覆盖 .env 文件中的值
    env_file:
      - .env
    # 注意：敏感信息（如密码）建议使用 secrets
    secrets:
      - postgres_password
      - secret_key

secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
  secret_key:
    file: ./secrets/secret_key.txt
```

**5. K8s 部署配置**

环境变量通过 K8s ConfigMap/Secret 注入，FastAPI 自动读取 `os.environ`。

**ConfigMap 示例：**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: incubator-app-bff-config
data:
  PROJECT_NAME: "Incubator App"
  SERVER_NAME: "incubator-app-bff"
  SERVER_HOST: "https://incubator-api.sunmoonai.com"
  POSTGRES_SERVER: "postgres-service"
  POSTGRES_PORT: "5432"
  POSTGRES_DB: "incubator_db"
  AUTH_SERVICE_URL: "http://auth-app-bff:3030"
  BACKEND_CORS_ORIGINS: '["https://incubator.sunmoonai.com"]'
```

**Secret 示例（敏感配置）：**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: incubator-app-bff-secrets
type: Opaque
stringData:
  POSTGRES_PASSWORD: "your-db-password"
  SECRET_KEY: "your-secret-key"
```

**Deployment 配置：**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: incubator-app-bff
        envFrom:
        - configMapRef:
            name: incubator-app-bff-config
        - secretRef:
            name: incubator-app-bff-secrets
```

**5. 注意事项**

- ✅ 使用 `pydantic-settings` 的 `BaseSettings` 自动从环境变量加载
- ✅ 支持类型验证（`int`、`str`、`List` 等）
- ✅ 使用 `field_validator` 自定义验证逻辑
- ✅ 敏感信息（密码、密钥）放在 Secret 中
- ✅ 提供默认值避免必填项缺失错误
- ✅ `env_ignore_empty=True` 忽略空值环境变量
- ✅ `extra="ignore"` 忽略未定义的额外环境变量
#### 1.4 Vite SSR

**技术栈特点：**
- 使用 `import.meta.env` 访问环境变量
- 通过 `.env` 文件定义环境变量
- 区分客户端和服务端环境变量
- 使用 `VITE_` 前缀暴露给客户端

**1. 源码定义方式**

在项目根目录创建 `.env` 文件：

```bash
# .env
VITE_APP_NAME=SunMoonAI
VITE_APP_ENV=production
VITE_API_URL=https://api.sunmoonai.com
VITE_BFF_URL=https://bff.sunmoonai.com

# 服务端专用（不以 VITE_ 开头）
SSR_API_SECRET=your-secret-key
DATABASE_URL=postgresql://...
```

**环境特定文件：**
- `.env.development` - 开发环境
- `.env.production` - 生产环境
- `.env.local` - 本地覆盖（不提交到 Git）

**2. 源码使用方式**

**客户端代码（组件、页面）：**
```typescript
// 使用 import.meta.env 访问环境变量
const apiUrl = import.meta.env.VITE_API_URL
const appName = import.meta.env.VITE_APP_NAME

// 在组件中使用
export default {
  setup() {
    const config = {
      apiUrl: import.meta.env.VITE_API_URL,
      bffUrl: import.meta.env.VITE_BFF_URL || import.meta.env.VITE_API_URL,
    }
    return { config }
  }
}
```

**服务端代码（SSR 中间件、API 路由）：**
```typescript
// 服务端可以访问所有环境变量（包括非 VITE_ 前缀）
const apiSecret = import.meta.env.SSR_API_SECRET
const dbUrl = import.meta.env.DATABASE_URL

// 在 SSR 中间件中使用
export default defineEventHandler(async (event) => {
  const apiUrl = import.meta.env.VITE_API_URL
  const secret = import.meta.env.SSR_API_SECRET
  
  // 调用后端 API
  const response = await $fetch(`${apiUrl}/api/v1/auth/me`, {
    headers: {
      'X-API-Secret': secret
    }
  })
})
```

**类型定义（可选）：**
```typescript
// env.d.ts
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_APP_NAME: string
  readonly VITE_APP_ENV: string
  readonly VITE_API_URL: string
  readonly VITE_BFF_URL: string
  readonly SSR_API_SECRET: string  // 服务端专用
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
```

**3. Docker Compose 传递方式**

```yaml
# docker-compose.yml
services:
  vite-ssr-app:
    image: vite-ssr-app:latest
    # 方式一：直接定义环境变量
    environment:
      - VITE_APP_NAME=My App
      - VITE_APP_ENV=production
      - VITE_API_URL=https://api.example.com
    
    # 方式二：从 .env 文件加载（推荐）
    env_file:
      - .env
      - .env.production
    
    # 方式三：混合使用（environment 优先级更高）
    environment:
      - VITE_APP_ENV=production  # 覆盖 .env 文件中的值
    env_file:
      - .env
```

**4. K8s 部署配置**

环境变量通过 K8s ConfigMap/Secret 注入，Vite 在构建时和运行时读取。

**ConfigMap 示例：**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vite-ssr-app-config
data:
  VITE_APP_NAME: "SunMoonAI"
  VITE_APP_ENV: "production"
  VITE_API_URL: "https://api.sunmoonai.com"
  VITE_BFF_URL: "https://bff.sunmoonai.com"
```

**Secret 示例（敏感配置）：**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vite-ssr-app-secrets
type: Opaque
stringData:
  SSR_API_SECRET: "your-secret-key"
  DATABASE_URL: "postgresql://..."
```

**Deployment 配置：**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: vite-ssr-app
        envFrom:
        - configMapRef:
            name: vite-ssr-app-config
        - secretRef:
            name: vite-ssr-app-secrets
```

**4. 注意事项**

- ✅ **客户端可见性**：只有 `VITE_` 前缀的环境变量会暴露到客户端代码
- ✅ **服务端专用**：不以 `VITE_` 开头的变量仅在服务端可用
- ✅ **构建时 vs 运行时**：`VITE_` 变量在构建时替换，非 `VITE_` 变量在运行时读取
- ✅ **类型安全**：使用 `env.d.ts` 定义类型，获得 IDE 自动补全
- ✅ **敏感信息**：永远不要使用 `VITE_` 前缀存储敏感信息
- ✅ **多环境**：使用 `.env.development`、`.env.production` 管理不同环境

### 二、K8s 部署配置规范

#### 2.1 ConfigMap 配置

**用途：** 存储非敏感的环境变量配置

**1. ConfigMap 模板结构**

在 `resources/k8s-resource/templates/configmap/` 目录下创建模板文件：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-name-config
  namespace: ${NAMESPACE}
  labels:
    app: app-name
data:
  # 使用 ${VARIABLE_NAME} 作为占位符
  PROJECT_NAME: "${PROJECT_NAME}"
  SERVER_NAME: "${SERVER_NAME}"
  SERVER_HOST: "${SERVER_HOST}"
  AUTH_SERVICE_URL: "${AUTH_SERVICE_URL}"
  REDIS_HOST: "${REDIS_HOST}"
  REDIS_PORT: "${REDIS_PORT}"
```

**2. 配置生成脚本**

**配置文件（generate-*-config.conf）：**
```bash
# 基础配置
NAMESPACE="${NAMESPACE:-default}"
ENVIRONMENT="${ENVIRONMENT:-development}"

# 应用配置（带默认值）
PROJECT_NAME="${PROJECT_NAME:-My App}"
SERVER_NAME="${SERVER_NAME:-app-service}"
SERVER_HOST="${SERVER_HOST:-http://localhost:3000}"
AUTH_SERVICE_URL="${AUTH_SERVICE_URL:-http://auth-service:3030}"

# Redis 配置
REDIS_HOST="${REDIS_HOST:-redis-service}"
REDIS_PORT="${REDIS_PORT:-6379}"
```

**生成脚本（generate-*-config.sh）：**
```bash
#!/bin/bash
# 加载配置
source "$CONFIG_FILE"

# 使用 envsubst 替换模板中的变量
envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
```

**3. 使用方式**

**生成 ConfigMap：**
```bash
cd resources/k8s-resource/custom-values/configMap/app-config/generate-app-config/
./generate-app-config.sh
```

**应用 ConfigMap：**
```bash
kubectl apply -f generated-config.yaml
```

**4. 配置原则**

- ✅ **非敏感信息**：只存储非敏感配置（URL、端口、开关等）
- ✅ **默认值**：所有配置项都应提供默认值
- ✅ **环境变量优先级**：环境变量 > 主配置 > 默认值
- ✅ **命名规范**：使用大写字母和下划线（`PROJECT_NAME`）
- ✅ **注释说明**：在模板中添加注释说明配置用途
#### 2.2 Secret 配置

**用途：** 存储敏感信息（密码、密钥、Token 等）

**1. Secret 模板结构**

在 `resources/k8s-resource/templates/secret/` 目录下创建模板文件：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-name-secret
  namespace: ${NAMESPACE}
  labels:
    app: app-name
type: Opaque
stringData:
  # 使用 stringData（明文，K8s 会自动 base64 编码）
  # 应用密钥
  SECRET_KEY: "${SECRET_KEY}"
  JWT_SECRET: "${JWT_SECRET}"
  
  # 数据库密码
  POSTGRES_PASSWORD: "${POSTGRES_PASSWORD}"
  REDIS_PASSWORD: "${REDIS_PASSWORD}"
  
  # 第三方服务密钥
  SMTP_PASSWORD: "${SMTP_PASSWORD}"
  SENTRY_DSN: "${SENTRY_DSN}"
```

**2. 配置生成脚本**

**配置文件（generate-*-secret.conf）：**
```bash
# 敏感配置（从环境变量或密钥管理服务获取）
SECRET_KEY="${SECRET_KEY:-}"
JWT_SECRET="${JWT_SECRET:-}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
```

**生成脚本（generate-*-secret.sh）：**
```bash
#!/bin/bash
# 检查必填项
if [ -z "${SECRET_KEY:-}" ]; then
  echo "ERROR: SECRET_KEY is required"
  exit 1
fi

# 使用 envsubst 替换模板
envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
```

**3. 安全最佳实践**

**✅ 使用 stringData（推荐）：**
```yaml
stringData:
  PASSWORD: "my-password"  # 明文，K8s 自动 base64
```

**❌ 避免使用 data（需要手动 base64）：**
```yaml
data:
  PASSWORD: bXktcGFzc3dvcmQ=  # 需要手动 base64 编码
```

**✅ 从密钥管理服务获取：**
```bash
# 从 Vault 获取密钥
export SECRET_KEY=$(vault kv get -field=secret_key secret/app)

# 从 AWS Secrets Manager 获取
export SECRET_KEY=$(aws secretsmanager get-secret-value \
  --secret-id app/secret-key --query SecretString --output text)
```

**✅ 使用 sealed-secrets（GitOps 友好）：**
```bash
# 使用 kubeseal 加密
kubeseal < secret.yaml > sealed-secret.yaml
```

**4. 注意事项**

- ✅ **永远不要提交到 Git**：Secret 文件应添加到 `.gitignore`
- ✅ **使用 stringData**：避免手动 base64 编码错误
- ✅ **最小权限原则**：只给需要的 Pod 访问权限
- ✅ **定期轮换**：定期更新密钥和密码
- ✅ **审计日志**：记录 Secret 的访问和修改
- ✅ **加密存储**：在生产环境使用加密的 etcd 或外部密钥管理
#### 2.3 Deployment 配置

**用途：** 在 Deployment 中注入 ConfigMap 和 Secret 的环境变量

**1. 使用 envFrom 注入（推荐）**

**批量注入所有环境变量：**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-name
spec:
  template:
    spec:
      containers:
      - name: app-container
        image: app:latest
        envFrom:
        # 从 ConfigMap 注入所有键值对
        - configMapRef:
            name: app-name-config
        # 从 Secret 注入所有键值对
        - secretRef:
            name: app-name-secret
```

**2. 使用 env 单独注入（精确控制）**

**选择性注入特定环境变量：**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app-container
        env:
        # 从 ConfigMap 注入单个值
        - name: API_URL
          valueFrom:
            configMapKeyRef:
              name: app-name-config
              key: API_URL
        # 从 Secret 注入单个值
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: app-name-secret
              key: SECRET_KEY
        # 直接设置环境变量
        - name: NODE_ENV
          value: "production"
```

**3. 混合使用（最佳实践）**

**推荐方式：使用 envFrom + 少量 env 覆盖：**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app-container
        envFrom:
        # 批量注入 ConfigMap（非敏感配置）
        - configMapRef:
            name: app-name-config
        # 批量注入 Secret（敏感配置）
        - secretRef:
            name: app-name-secret
        env:
        # 覆盖或添加特定配置
        - name: LOG_LEVEL
          value: "info"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
```

**4. 多 ConfigMap/Secret 注入**

**从多个来源注入：**
```yaml
envFrom:
# 应用配置
- configMapRef:
    name: app-config
# 共享配置（如 Redis、数据库等）
- configMapRef:
    name: shared-infra-config
# 应用密钥
- secretRef:
    name: app-secret
# 共享密钥
- secretRef:
    name: shared-infra-secret
```

**5. 注意事项**

- ✅ **优先级**：`env` 中的变量会覆盖 `envFrom` 中的同名变量
- ✅ **命名冲突**：如果多个 ConfigMap/Secret 有同名键，后注入的会覆盖先注入的
- ✅ **可选引用**：使用 `optional: true` 允许 ConfigMap/Secret 不存在
- ✅ **字段引用**：可以使用 `fieldRef` 引用 Pod 元数据（如 `metadata.name`、`metadata.namespace`）
- ✅ **资源引用**：可以使用 `resourceFieldRef` 引用容器资源（如 CPU、内存限制）

### 三、实际应用示例

#### 3.1 完整示例：auth-app-bff (NestJS)

**源码配置（config.module.ts）：**
```typescript
@Module({
  imports: [
    Config.forRoot({
      isGlobal: true,
      envFilePath: [`.env.${process.env.NODE_ENV}`, '.env'],
    }),
  ],
})
export class ConfigModule {}
```

**源码使用（redis.service.ts）：**
```typescript
@Injectable()
export class RedisService {
  constructor(private configService: ConfigService) {}
  
  async onModuleInit() {
    this.client = new Redis({
      host: this.configService.get<string>('REDIS_HOST', 'localhost'),
      port: this.configService.get<number>('REDIS_PORT', 6379),
      password: this.configService.get<string>('REDIS_PASSWORD'),
    });
  }
}
```

**K8s ConfigMap：**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: auth-app-bff-config
data:
  NODE_ENV: "production"
  REDIS_HOST: "redis-service"
  REDIS_PORT: "6379"
  SESSION_TTL_SECONDS: "604800"
```

**K8s Secret：**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: auth-app-bff-secret
type: Opaque
stringData:
  REDIS_PASSWORD: "redis-password"
  JWT_SECRET: "jwt-secret-key"
```

**Deployment 注入：**
```yaml
spec:
  template:
    spec:
      containers:
      - name: auth-app-bff
        envFrom:
        - configMapRef:
            name: auth-app-bff-config
        - secretRef:
            name: auth-app-bff-secret
```

#### 3.2 完整示例：llmops-app-bff (FastAPI)

**源码配置（config.py）：**
```python
class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")
    
    AUTH_SERVICE_URL: str = "http://localhost:3030"
    POSTGRES_SERVER: str
    POSTGRES_USER: str
    POSTGRES_PASSWORD: str

settings = Settings()
```

**源码使用（auth_client.py）：**
```python
from app.core.config import settings

class AuthClient:
    def __init__(self):
        self.base_url = settings.AUTH_SERVICE_URL
```

**K8s ConfigMap：**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: llmops-app-bff-config
data:
  AUTH_SERVICE_URL: "http://auth-app-bff:3030"
  POSTGRES_SERVER: "postgres-service"
  POSTGRES_USER: "llmops_user"
```

**K8s Secret：**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: llmops-app-bff-secret
type: Opaque
stringData:
  POSTGRES_PASSWORD: "db-password"
```

#### 3.3 完整示例：auth-app-ssr (Nuxt.js)

**源码配置（nuxt.config.ts）：**
```typescript
export default defineNuxtConfig({
  runtimeConfig: {
    public: {
      apiUrl: process.env.VUE_APP_DOMAIN_API,
      bffUrl: process.env.VUE_APP_BFF_URL,
      sessionCookieName: process.env.SESSION_COOKIE_NAME || 'sunmoonai_session',
    }
  }
})
```

**源码使用（api/core.ts）：**
```typescript
export const apiCore = {
  url(): string {
    return useRuntimeConfig().public.apiUrl
  }
}
```

**K8s ConfigMap：**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: auth-app-ssr-config
data:
  VUE_APP_DOMAIN_API: "https://api.sunmoonai.com"
  VUE_APP_BFF_URL: "https://auth-bff.sunmoonai.com"
  SESSION_COOKIE_NAME: "sunmoonai_session"
```

**Deployment 注入：**
```yaml
spec:
  template:
    spec:
      containers:
      - name: auth-app-ssr
        envFrom:
        - configMapRef:
            name: auth-app-ssr-config
```

### 四、最佳实践

#### 4.1 配置分离原则

**✅ 正确做法：**

| 配置类型 | 存储位置 | 示例 |
|---------|---------|------|
| 非敏感配置 | ConfigMap | URL、端口、开关、环境名 |
| 敏感配置 | Secret | 密码、密钥、Token、DSN |
| 运行时配置 | Deployment env | 日志级别、调试开关 |

**❌ 错误做法：**
- 将密码放在 ConfigMap 中
- 将 URL 放在 Secret 中
- 硬编码配置在代码中

#### 4.2 命名规范

**环境变量命名：**
- ✅ 使用大写字母和下划线：`REDIS_HOST`、`AUTH_SERVICE_URL`
- ✅ 使用有意义的名称：`POSTGRES_PASSWORD` 而不是 `DB_PWD`
- ✅ 使用前缀区分：`VITE_`（Vite）、`VUE_APP_`（Nuxt 兼容）
- ✅ 保持一致性：同一服务的配置使用统一前缀

**ConfigMap/Secret 命名：**
- ✅ 格式：`{app-name}-{type}`（如 `auth-app-bff-config`、`auth-app-bff-secret`）
- ✅ 使用 kebab-case：`incubator-app-bff-config`
- ✅ 明确类型：`-config` 或 `-secret` 后缀

#### 4.3 多环境管理

**环境变量优先级（从高到低）：**
1. 容器环境变量（Deployment env）
2. ConfigMap/Secret（envFrom）
3. 应用默认值（代码中）

**多环境配置策略：**
```bash
# 开发环境
NAMESPACE=app-platform-dev
ENVIRONMENT=development

# 测试环境
NAMESPACE=app-platform-test
ENVIRONMENT=staging

# 生产环境
NAMESPACE=app-platform-prod
ENVIRONMENT=production
```

**使用环境特定配置：**
```bash
# 不同环境使用不同的 ConfigMap
kubectl apply -f configmap-dev.yaml    # 开发环境
kubectl apply -f configmap-prod.yaml    # 生产环境
```

#### 4.4 安全最佳实践

**✅ Secret 管理：**
- 使用 `stringData` 而不是 `data`（避免手动 base64）
- 定期轮换密钥和密码
- 使用密钥管理服务（Vault、AWS Secrets Manager）
- 限制 Secret 的访问权限（RBAC）

**✅ 配置验证：**
- NestJS：使用 Joi 验证环境变量格式
- FastAPI：使用 Pydantic 类型验证
- 启动时检查必填项，避免运行时错误

**✅ 敏感信息处理：**
- 永远不要在日志中输出敏感信息
- 使用环境变量而不是配置文件存储密钥
- 在 CI/CD 中使用加密的 Secret

#### 4.5 开发工作流

**本地开发：**
1. 创建 `.env` 文件（不提交到 Git）
2. 使用 `.env.example` 作为模板
3. 使用默认值避免本地配置复杂

**部署流程：**
1. 生成 ConfigMap/Secret YAML
2. 应用 ConfigMap/Secret 到 K8s
3. 更新 Deployment（触发 Pod 重启）
4. 验证环境变量是否正确注入

**调试技巧：**
```bash
# 查看 Pod 的环境变量
kubectl exec <pod-name> -- env

# 查看 ConfigMap
kubectl get configmap <name> -o yaml

# 查看 Secret（base64 解码）
kubectl get secret <name> -o jsonpath='{.data}' | jq 'to_entries | map({key, value: .value | @base64d})'
```

#### 4.6 常见问题排查

**问题 1：环境变量未生效**
- 检查 ConfigMap/Secret 是否存在
- 检查 Deployment 中的 `envFrom` 配置
- 检查 Pod 是否重启（环境变量变更需要重启）

**问题 2：Secret 值错误**
- 检查 `stringData` 格式（不要手动 base64）
- 检查是否有特殊字符需要转义
- 使用 `kubectl describe secret` 查看

**问题 3：配置冲突**
- 检查多个 ConfigMap 是否有同名键
- 检查 `env` 是否覆盖了 `envFrom` 的值
- 使用 `kubectl exec` 查看实际环境变量

**问题 4：类型转换错误**
- NestJS：使用 `get<number>()` 进行类型转换
- FastAPI：使用 Pydantic 类型验证
- 确保环境变量的值格式正确（数字、布尔值等）

