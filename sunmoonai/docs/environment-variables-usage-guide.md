# 环境变量在代码中的使用方式

本文档详细说明在不同技术栈中如何在代码中访问和使用环境变量。

## 目录

1. [NestJS BFF (portal-app-bff)](#nestjs-bff-portal-app-bff)
2. [Nuxt.js SSR (portal-app-ssr, incubator-app-ssr, llmops-app-ssr)](#nuxtjs-ssr)
3. [FastAPI BFF (incubator-app-bff, llmops-app-bff)](#fastapi-bff)
4. [实际代码示例](#实际代码示例)

---

## NestJS BFF (portal-app-bff)

### 1. 配置模块设置

NestJS 使用 `@nestjs/config` 模块来管理环境变量。

**文件：`src/common/config/config.module.ts`**

```typescript
import { Module } from '@nestjs/common';
import * as Joi from 'joi';
import { ConfigModule as Config } from '@nestjs/config';

const schema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production')
    .default('development'),
});

// 环境变量文件路径（按优先级顺序）
const envFilePath = [
  `.env.${process.env.NODE_ENV || 'development'}`,
  '.env'
];

@Module({
  imports: [
    Config.forRoot({
      isGlobal: true,        // 全局模块，所有模块都可以使用
      envFilePath,           // 自动加载 .env 文件
      validationSchema: schema, // 可选：使用 Joi 验证环境变量
    }),
  ],
})
export class ConfigModule {}
```

### 2. 在服务中使用 ConfigService

**方式一：通过依赖注入使用 ConfigService（推荐）**

```typescript
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AuthClientService {
  public readonly baseUrl: string;

  constructor(private configService: ConfigService) {
    // 方式1：使用 get() 方法，可以指定类型和默认值
    this.baseUrl = this.configService.get<string>('AUTH_SERVICE_URL') || 
                   'http://localhost:3030';
    
    // 方式2：使用 getOrThrow() 方法，如果不存在会抛出异常
    // this.baseUrl = this.configService.getOrThrow<string>('AUTH_SERVICE_URL');
  }

  async someMethod() {
    // 在方法中也可以使用
    const timeout = this.configService.get<number>('REQUEST_TIMEOUT', 5000);
  }
}
```

**方式二：直接使用 process.env（不推荐，但可用）**

```typescript
// 不推荐：直接使用 process.env，无法利用 ConfigService 的类型检查和验证
const baseUrl = process.env.AUTH_SERVICE_URL || 'http://localhost:3030';
```

### 3. 在 main.ts 中使用

```typescript
import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService); // 获取 ConfigService 实例
  
  const port = configService.get<number>('PORT', 3000);
  const prefix = configService.get('PREFIX', '/api');
  
  app.setGlobalPrefix(prefix);
  await app.listen(port);
}
```

### 4. 环境变量文件示例

**`.env.development`**
```bash
NODE_ENV=development
PORT=3000
PREFIX=/api
AUTH_SERVICE_URL=http://localhost:3030
SESSION_COOKIE_NAME=sunmoonai_session
```

**`.env.production`**
```bash
NODE_ENV=production
PORT=3000
PREFIX=/api
AUTH_SERVICE_URL=http://auth-app-bff:3030
SESSION_COOKIE_NAME=sunmoonai_session
```

---

## Nuxt.js SSR

### 1. 在 nuxt.config.ts 中定义

**文件：`nuxt.config.ts`**

```typescript
export default defineNuxtConfig({
  runtimeConfig: {
    // 私有配置（仅在服务器端可用）
    // 这些配置不会暴露给客户端
    apiSecret: process.env.VUE_PRIVATE_TERM,
    
    // 公共配置（客户端和服务器端都可用）
    // ⚠️ 注意：这些配置会暴露给客户端，不要包含敏感信息
    public: {
      // 从环境变量读取，带默认值
      bffUrl: process.env.VUE_APP_BFF_URL || 
              process.env.PORTAL_BFF_URL || 
              'http://localhost:3000',
      
      apiVersion: process.env.VUE_APP_API_VERSION || 'v1',
      prefix: process.env.VUE_APP_API_PREFIX || '/api',
      sessionCookieName: process.env.SESSION_COOKIE_NAME || 'sunmoonai_session',
    },
  },
})
```

### 2. 在服务器端代码中使用

**文件：`server/middleware/auth.global.ts`**

```typescript
import { useRuntimeConfig } from '#imports'

export default defineEventHandler(async (event) => {
  // 获取运行时配置
  const config = useRuntimeConfig()
  
  // 访问公共配置（客户端和服务器端都可用）
  const bffUrl = config.public.bffUrl
  const apiVersion = config.public.apiVersion
  const sessionCookieName = config.public.sessionCookieName
  
  // 访问私有配置（仅服务器端可用）
  // const apiSecret = config.apiSecret
  
  // 使用配置
  const user = await $fetch(`${bffUrl}/api/${apiVersion}/auth/me`, {
    headers: {
      cookie: `${sessionCookieName}=${sessionId}`,
    },
  })
})
```

### 3. 在客户端代码中使用

**文件：`app/composables/useApi.ts`**

```typescript
export const useApi = () => {
  const config = useRuntimeConfig()
  
  // 只能访问 public 配置
  const apiUrl = config.public.bffUrl
  const apiVersion = config.public.apiVersion
  
  return {
    apiUrl,
    apiVersion,
  }
}
```

**在 Vue 组件中使用：**

```vue
<script setup>
const config = useRuntimeConfig()
const bffUrl = config.public.bffUrl

// 调用 API
const data = await $fetch(`${bffUrl}/api/v1/users`)
</script>
```

### 4. 直接使用 process.env（仅服务器端）

在服务器端代码中，也可以直接使用 `process.env`：

```typescript
// 仅在服务器端可用（server/ 目录下的文件）
const nodeEnv = process.env.NODE_ENV
const port = process.env.PORT
```

### 5. 环境变量文件示例

**`.env.development`**
```bash
NODE_ENV=development
VUE_APP_BFF_URL=http://localhost:3000
VUE_APP_API_VERSION=v1
VUE_APP_API_PREFIX=/api
SESSION_COOKIE_NAME=sunmoonai_session
```

**`.env.production`**
```bash
NODE_ENV=production
VUE_APP_BFF_URL=http://portal-app-bff:3000
VUE_APP_API_VERSION=v1
VUE_APP_API_PREFIX=/api
SESSION_COOKIE_NAME=sunmoonai_session
```

---

## FastAPI BFF

### 1. 定义 Settings 类

**文件：`app/core/config.py`**

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class Settings(BaseSettings):
    # 配置模型
    model_config = SettingsConfigDict(
        env_file=".env",           # 自动加载 .env 文件
        env_ignore_empty=True,     # 忽略空值
        extra="ignore"             # 忽略额外字段
    )
    
    # 环境变量定义（带类型和默认值）
    API_V1_STR: str = "/api/v1"
    SECRET_KEY: str  # 必需的环境变量，没有默认值
    TOTP_SECRET_KEY: str
    
    # 可选的环境变量，带默认值
    AUTH_SERVICE_URL: str = "http://localhost:3030"
    SESSION_COOKIE_NAME: str = "sunmoonai_session"
    
    # 可选的环境变量
    SENTRY_DSN: Optional[str] = None

# 创建全局 settings 实例
settings = Settings()
```

### 2. 在代码中使用

**方式一：使用全局 settings 对象（推荐）**

```python
from app.core.config import settings

class AuthClient:
    def __init__(self):
        # 直接访问 settings 对象的属性
        self.base_url = settings.AUTH_SERVICE_URL
        self.cookie_name = settings.SESSION_COOKIE_NAME
    
    async def get_current_user(self, request: Request):
        # 使用配置
        response = await client.get(
            f"{self.base_url}/api/v1/auth/me",
            headers={
                "Cookie": f"{self.cookie_name}={session_id}",
            }
        )
```

**方式二：使用 os.getenv()（不推荐，但可用）**

```python
import os

# 不推荐：直接使用 os.getenv()，无法利用类型检查和验证
base_url = os.getenv('AUTH_SERVICE_URL', 'http://localhost:3030')
```

### 3. 在依赖注入中使用

```python
from fastapi import Depends
from app.core.config import settings

def get_auth_client():
    return AuthClient(base_url=settings.AUTH_SERVICE_URL)

@router.get("/me")
async def get_current_user(
    auth_client: AuthClient = Depends(get_auth_client)
):
    # 使用 auth_client
    pass
```

### 4. 环境变量文件示例

**`.env`**
```bash
API_V1_STR=/api/v1
SECRET_KEY=your-secret-key-here
TOTP_SECRET_KEY=your-totp-secret-key-here
AUTH_SERVICE_URL=http://localhost:3030
SESSION_COOKIE_NAME=sunmoonai_session
```

---

## 实际代码示例

### 示例 1：portal-app-bff AuthClientService

**文件：`src/common/auth-client/auth-client.service.ts`**

```typescript
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import axios, { AxiosInstance } from 'axios';

@Injectable()
export class AuthClientService {
  public readonly baseUrl: string;
  private readonly httpClient: AxiosInstance;

  constructor(private configService: ConfigService) {
    // 从环境变量读取 AUTH_SERVICE_URL，带默认值
    this.baseUrl =
      this.configService.get<string>('AUTH_SERVICE_URL') ||
      'http://localhost:3030';
    
    this.httpClient = axios.create({
      timeout: 5000,
    });
  }

  async getCurrentUser(request: Request): Promise<any> {
    const headers: Record<string, string> = {};
    const cookies = request.headers.cookie;
    if (cookies) {
      headers['Cookie'] = cookies;
    }
    headers['X-Service-Call'] = 'true';

    const response = await this.httpClient.get(
      `${this.baseUrl}/api/v1/auth/me`,  // 使用配置的 baseUrl
      { headers }
    );
    return response.data;
  }
}
```

### 示例 2：portal-app-ssr 认证中间件

**文件：`server/middleware/auth.global.ts`**

```typescript
import { useRuntimeConfig } from '#imports'

export default defineEventHandler(async (event) => {
  // 获取运行时配置
  const config = useRuntimeConfig()
  
  // 从配置中读取 Session Cookie 名称
  const sessionCookieName = config.public.sessionCookieName || 'sunmoonai_session'
  const cookies = parseCookies(event)
  const sessionId = cookies[sessionCookieName]

  if (!sessionId) {
    return
  }

  // 从配置中读取 BFF URL 和 API 版本
  const bffUrl = config.public.bffUrl || 'http://localhost:3000'
  const apiVersion = config.public.apiVersion || 'v1'
  const prefix = config.public.prefix || '/api'

  // 调用业务BFF的接口
  const user = await $fetch(`${bffUrl}${prefix}/${apiVersion}/auth/me`, {
    headers: {
      cookie: `${sessionCookieName}=${sessionId}`,
    },
    credentials: 'include',
    timeout: 3000,
  })

  // 注入到上下文
  event.context.auth = {
    user,
    authenticated: true,
    sessionId,
  }
})
```

### 示例 3：incubator-app-bff AuthClient

**文件：`app/core/auth_client.py`**

```python
from typing import Dict, Any
from fastapi import Request
from app.core.config import settings  # 导入全局 settings

class AuthClient:
    """认证服务客户端 - 支持 Cookie 转发"""
    
    def __init__(self):
        # 从 settings 读取 AUTH_SERVICE_URL
        self.base_url = settings.AUTH_SERVICE_URL
    
    async def get_current_user(self, request: Request) -> Dict[str, Any]:
        headers = {}
        cookies = request.headers.get("cookie")
        if cookies:
            headers["Cookie"] = cookies
        headers["X-Service-Call"] = "true"
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v1/auth/me",  # 使用配置的 base_url
                headers=headers,
                timeout=5.0
            )
            response.raise_for_status()
            return response.json()
```

---

## 环境变量优先级

不同技术栈的环境变量加载优先级：

### NestJS
1. 系统环境变量（最高优先级）
2. `.env.${NODE_ENV}` 文件
3. `.env` 文件
4. 代码中的默认值（最低优先级）

### Nuxt.js
1. 系统环境变量（最高优先级）
2. `.env.${NODE_ENV}` 文件
3. `.env` 文件
4. `nuxt.config.ts` 中的默认值（最低优先级）

### FastAPI
1. 系统环境变量（最高优先级）
2. `.env` 文件
3. `Settings` 类中的默认值（最低优先级）

---

## 最佳实践

### 1. 使用类型安全的方式

**✅ 推荐（NestJS）**
```typescript
const baseUrl = this.configService.get<string>('AUTH_SERVICE_URL', 'http://localhost:3030');
```

**❌ 不推荐**
```typescript
const baseUrl = process.env.AUTH_SERVICE_URL || 'http://localhost:3030';
```

### 2. 提供默认值

**✅ 推荐**
```typescript
const timeout = this.configService.get<number>('REQUEST_TIMEOUT', 5000);
```

**❌ 不推荐**
```typescript
const timeout = this.configService.get<number>('REQUEST_TIMEOUT'); // 可能为 undefined
```

### 3. 敏感信息不要放在 public 配置中

**✅ 推荐（Nuxt.js）**
```typescript
runtimeConfig: {
  apiSecret: process.env.API_SECRET,  // 私有配置
  public: {
    apiUrl: process.env.API_URL,       // 公共配置
  }
}
```

**❌ 不推荐**
```typescript
runtimeConfig: {
  public: {
    apiSecret: process.env.API_SECRET,  // ❌ 会暴露给客户端
  }
}
```

### 4. 使用环境变量验证

**✅ 推荐（NestJS + Joi）**
```typescript
const schema = Joi.object({
  AUTH_SERVICE_URL: Joi.string().uri().required(),
  PORT: Joi.number().port().default(3000),
});
```

### 5. 使用类型提示

**✅ 推荐（FastAPI）**
```python
class Settings(BaseSettings):
    AUTH_SERVICE_URL: str = "http://localhost:3030"  # 类型明确
    PORT: int = 3000                                  # 类型明确
```

---

## 总结

| 技术栈 | 访问方式 | 推荐方法 | 示例 |
|--------|---------|---------|------|
| **NestJS** | `ConfigService.get()` | ✅ 依赖注入 | `configService.get<string>('VAR')` |
| **Nuxt.js SSR** | `useRuntimeConfig()` | ✅ 运行时配置 | `config.public.var` |
| **FastAPI** | `settings.VAR` | ✅ 全局 settings | `settings.AUTH_SERVICE_URL` |

记住：
- **NestJS**：使用 `ConfigService`（依赖注入）
- **Nuxt.js**：使用 `useRuntimeConfig()`（运行时配置）
- **FastAPI**：使用 `settings` 对象（全局实例）

