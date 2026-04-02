# Session + Cookie 认证实施指南

## 文档说明

**本文档是开发实施时的快速参考指南**，整合了所有关键决策、配置、接口规范和实施步骤。

**详细分析文档**：
- `session-based-auth-proposal.md` - 主提案文档（包含所有确认的决策）
- `auth-refactoring-plan-part1.md` - 核心原则和阶段总览
- `auth-refactoring-plan-part2.md` - 任务清单和测试要点
- `auth-refactoring-plan-part3.md` - 详细设计（数据结构、接口契约）
- `auth-refactoring-plan-part4.md` - 灰度/回滚、配置清单、监控
- `auth-service-call-scenarios-analysis.md` - 调用场景分析
- `compatibility-analysis.md` - 兼容性分析
- `login-methods-impact-analysis.md` - 登录方式影响分析
- `auth-vs-permission-strategy.md` - 认证vs权限策略

---

## 一、核心决策快速参考

### 1.1 技术架构

- ✅ **认证方式**：Session + HttpOnly Cookie
- ✅ **存储**：Redis（Session + 临时 Token）
- ✅ **Cookie 配置**：`Domain=.sunmoonai.com`, `SameSite=Lax`, `Secure=true`, `HttpOnly=true`
- ✅ **Session TTL**：7天，支持滑动续期
- ✅ **Access Token TTL**：15分钟（用于服务间调用）
- ✅ **登录方式**：保留所有方式，暂时只启用 OAuth
- ✅ **gRPC 调用**：**不受影响**（用于调用 user-service 获取用户数据，与认证方式无关）
- ✅ **SSO（单点登录）**：通过 Cookie Domain 设置为 `.sunmoonai.com`，实现跨子域单点登录

**SSO 说明：**
- **实现方式**：Cookie Domain 设置为 `.sunmoonai.com`（注意前面的点），使 Cookie 在所有 `*.sunmoonai.com` 子域之间共享
- **工作原理**：用户在一个子域（如 `auth.sunmoonai.com`）登录后，Cookie 会自动在所有子域（如 `llmops.sunmoonai.com`、`incubator.sunmoonai.com`）之间共享
- **用户体验**：用户只需登录一次，即可访问所有子域应用，无需重复登录
- **测试项**：跨子域 SSO - 在一个应用登录，访问另一个无需重登

### 1.2 gRPC 说明

**重要**：`auth-app-backend` 通过 gRPC 调用 `user-service` 获取用户数据，这与 Session + Cookie 认证改造**无关**。

**架构说明**：
- **gRPC 调用**：`auth-app-backend` → `user-service`（服务间通信，获取用户数据）
- **Session + Cookie**：浏览器 → `auth-app-backend`（认证方式）

**影响分析**：
- ✅ **gRPC 调用不受影响**：Session + Cookie 改造只改变认证方式，不影响服务间 gRPC 调用
- ✅ **代码无需修改**：`userService.findOne()`, `userService.findById()` 等 gRPC 调用保持不变
- ✅ **功能正常**：用户数据获取功能完全正常

**当前 gRPC 使用场景**：
- 登录时：`userService.findOne({ username })` - 查找用户
- 认证时：`userService.findById({ id })` - 根据 ID 获取用户
- 用户管理：`userService.create()`, `userService.update()`, `userService.findAll()` 等

**实施建议**：
- 无需修改任何 gRPC 相关代码
- 保持现有的 `UserServiceClient` 使用方式
- 保持现有的 Consul 服务发现机制

### 1.2 关键接口

| 接口 | 方法 | 认证方式 | 响应内容 |
|------|------|----------|----------|
| `/api/v1/login/oauth` | POST | 无 | 设置 Cookie，返回用户信息 |
| `/api/v1/auth/me` | GET | Cookie（优先）或 Bearer Token | 用户信息（+ access_token 如果带 `X-Service-Call: true`） |
| `/api/v1/auth/token` | GET | Cookie | `{ access_token: string }` |
| `/api/v1/auth/logout` | POST | Cookie | 删除 Session，清除 Cookie |

### 1.3 Redis Key 命名规范

| 类型 | Key 格式 | TTL |
|------|----------|-----|
| Session | `auth:session:{session_id}` | 7天 |
| 用户 Session 映射 | `auth:user_sessions:{user_id}` | 7天 |
| 黑名单 | `auth:blacklist:{token}` | Token 剩余有效期 |
| 魔法链接 | `auth:magic:{token}` | 15分钟 |
| 密码恢复 | `auth:recovery:{token}` | 1小时 |
| TOTP 设置 | `auth:totp-setup:{username}` | 10分钟 |
| 邮箱验证 | `auth:email-validation:{token}` | 24小时 |

---

## 二、Session + Cookie 系统完整说明

### 2.1 Session + Cookie 架构概述

**Session + Cookie 认证**是一种基于服务器端会话管理的认证方式，通过 HttpOnly Cookie 在客户端和服务器之间传递 Session ID，实现用户认证和状态管理。

### 2.2 核心组件

#### 2.2.1 Session（会话）

**定义**：Session 是服务器端存储的用户会话信息，包含用户身份、权限、状态等数据。

**存储位置**：Redis（内存数据库，高性能）

**生命周期**：
- **创建**：用户登录成功后创建
- **有效期**：7天（可配置）
- **续期**：滑动续期机制（用户活跃时自动延长）
- **销毁**：用户登出或过期后删除

**数据结构**：
```typescript
interface Session {
  session_id: string;           // Session ID（UUID）
  user_id: number;              // 用户ID
  username: string;             // 用户名
  email: string;                // 邮箱
  full_name: string;            // 全名
  is_active: boolean;           // 是否激活
  is_superuser: boolean;        // 是否超级用户
  email_validated: boolean;     // 邮箱是否验证
  roles: Array<{ roleId: number }>;  // 角色列表
  
  access_token: string;         // JWT Token（用于服务间调用）
  access_expires_at: number;   // Access Token 过期时间（15分钟）
  
  created_at: number;          // 创建时间
  updated_at: number;          // 更新时间
  expires_at: number;          // 过期时间（7天）
  last_activity: number;      // 最后活动时间（用于滑动续期）
  
  client_ip?: string;         // 客户端IP（可选）
}
```

#### 2.2.2 Cookie（HTTP Cookie）

**定义**：Cookie 是存储在浏览器中的小段数据，用于在客户端和服务器之间传递 Session ID。

**关键配置**：
- **Name**：`sunmoonai_session`（可配置）
- **Value**：Session ID（UUID格式）
- **Domain**：`.sunmoonai.com`（跨子域共享，实现SSO）
- **Path**：`/`（全路径有效）
- **HttpOnly**：`true`（防止XSS攻击，前端JavaScript无法访问）
- **Secure**：`true`（仅HTTPS传输）
- **SameSite**：`Lax`（防止CSRF攻击，同时允许跨站导航）

**安全特性**：
- ✅ **HttpOnly**：前端JavaScript无法读取，防止XSS攻击
- ✅ **Secure**：仅通过HTTPS传输，防止中间人攻击
- ✅ **SameSite=Lax**：防止CSRF攻击，同时允许正常的跨站导航
- ✅ **Domain=.sunmoonai.com**：所有子域共享，实现单点登录（SSO）

### 2.3 完整认证流程

#### 2.3.1 用户登录流程

```
1. 用户访问业务应用（未登录）
   ↓
2. 业务SSR → 业务BFF（调用API）
   ↓
3. 业务BFF 判断：未登录，返回401或重定向
   ↓
4. 浏览器重定向到 auth-app-front（登录页面）
   ↓
5. 用户输入用户名密码，提交登录表单
   ↓
6. auth-app-front → auth-app-backend（POST /api/v1/login/oauth）
   ↓
7. auth-app-backend 验证用户凭证：
   - 调用 user-service（gRPC）验证用户名密码
   - 验证通过后创建 Session
   ↓
8. auth-app-backend 创建 Session：
   - 生成 Session ID（UUID）
   - 存储用户信息到 Redis（key: auth:session:{session_id}）
   - 设置过期时间（7天）
   - 生成 access_token（JWT，15分钟有效期）
   ↓
9. auth-app-backend 设置 Cookie：
   - 在 HTTP Response 中设置 Set-Cookie 头
   - Cookie Name: sunmoonai_session
   - Cookie Value: {session_id}
   - Domain: .sunmoonai.com
   - HttpOnly: true
   - Secure: true
   - SameSite: Lax
   ↓
10. 浏览器保存 Cookie（自动，无需前端代码）
    ↓
11. auth-app-front 重定向回业务应用
    ↓
12. 浏览器携带 Cookie 访问业务应用（已登录）
```

#### 2.3.2 已登录用户访问流程

```
1. 用户访问业务应用（已登录）
   ↓
2. 浏览器自动发送 Cookie（sunmoonai_session={session_id}）
   ↓
3. 业务SSR 接收请求，读取 Cookie
   ↓
4. 业务SSR → 业务BFF（调用API，转发 Cookie）
   ↓
5. 业务BFF 接收请求，读取 Cookie
   ↓
6. 业务BFF → auth-app-backend（调用 /api/v1/auth/me，转发 Cookie）
   ↓
7. auth-app-backend 验证 Session：
   - 从 Cookie 中提取 Session ID
   - 验证 Session ID 格式（防止注入攻击）
   - 从 Redis 读取 Session（key: auth:session:{session_id}）
   - 检查 Session 是否过期
   - 如果 access_token 过期，自动刷新
   ↓
8. auth-app-backend 返回用户信息（+ access_token，如果带了 X-Service-Call: true）
   ↓
9. 业务BFF 处理业务逻辑，返回业务数据
   ↓
10. 业务SSR 渲染页面，返回给浏览器
```

#### 2.3.3 Session 滑动续期机制

```
1. 用户访问业务应用（已登录）
   ↓
2. auth-app-backend 验证 Session 时检查：
   - 当前时间：now
   - Session 过期时间：expires_at
   - 剩余时间：remaining = expires_at - now
   ↓
3. 如果剩余时间 < 1天：
   - 自动延长 Session 过期时间（延长到7天后）
   - 更新 last_activity 时间
   - 更新 Redis 中的 Session
   ↓
4. 用户持续活跃时，Session 自动续期
   ↓
5. 如果用户7天未活动，Session 过期
```

#### 2.3.4 用户登出流程

```
1. 用户点击登出按钮
   ↓
2. 业务SSR → auth-app-backend（POST /api/v1/auth/logout，携带 Cookie）
   ↓
3. auth-app-backend 处理登出：
   - 从 Cookie 中提取 Session ID
   - 从 Redis 删除 Session（DEL auth:session:{session_id}）
   - 删除用户 Session 映射（DEL auth:user_sessions:{user_id}）
   - 清除 Cookie（Set-Cookie: sunmoonai_session=; expires=Thu, 01 Jan 1970 00:00:00 GMT）
   ↓
4. 浏览器删除 Cookie（自动）
   ↓
5. 用户已登出，需要重新登录
```

### 2.4 数据流转过程

#### 2.4.1 Session 存储结构

**Redis Key 命名规范**：

| 类型 | Key 格式 | 示例 | TTL |
|------|----------|------|-----|
| Session | `auth:session:{session_id}` | `auth:session:550e8400-e29b-41d4-a716-446655440000` | 7天 |
| 用户 Session 映射 | `auth:user_sessions:{user_id}` | `auth:user_sessions:123` | 7天 |
| 黑名单 | `auth:blacklist:{token}` | `auth:blacklist:eyJhbGc...` | Token剩余有效期 |

**Session 存储示例**：
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": 123,
  "username": "john.doe",
  "email": "john.doe@example.com",
  "full_name": "John Doe",
  "is_active": true,
  "is_superuser": false,
  "email_validated": true,
  "roles": [{"roleId": 1}],
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "access_expires_at": 1704067200,
  "created_at": 1704063600,
  "updated_at": 1704067200,
  "expires_at": 1704668400,
  "last_activity": 1704067200
}
```

#### 2.4.2 Cookie 传递过程

**请求流程**：
```
1. 浏览器发送请求：
   GET /api/v1/projects HTTP/1.1
   Host: llmops.sunmoonai.com
   Cookie: sunmoonai_session=550e8400-e29b-41d4-a716-446655440000
   
2. 业务SSR 接收请求，读取 Cookie：
   const sessionId = req.cookies['sunmoonai_session']
   
3. 业务SSR 转发请求到业务BFF，携带 Cookie：
   GET /api/v1/projects HTTP/1.1
   Host: llmops-app-bff:3030
   Cookie: sunmoonai_session=550e8400-e29b-41d4-a716-446655440000
   
4. 业务BFF 转发请求到 auth-app-backend，携带 Cookie：
   GET /api/v1/auth/me HTTP/1.1
   Host: auth-app-backend:3030
   Cookie: sunmoonai_session=550e8400-e29b-41d4-a716-446655440000
   X-Service-Call: true
   
5. auth-app-backend 验证 Session，返回用户信息
```

### 2.5 安全机制

#### 2.5.1 防止 XSS 攻击

**机制**：HttpOnly Cookie
- Cookie 设置了 `HttpOnly: true`
- 前端 JavaScript 无法读取 Cookie
- 即使存在 XSS 漏洞，攻击者也无法窃取 Session ID

**示例**：
```javascript
// 前端代码无法访问 HttpOnly Cookie
document.cookie  // 不包含 sunmoonai_session
```

#### 2.5.2 防止 CSRF 攻击

**机制**：SameSite Cookie
- Cookie 设置了 `SameSite: Lax`
- 防止跨站请求伪造（CSRF）攻击
- 同时允许正常的跨站导航（如从邮件链接跳转）

**工作原理**：
- **Lax 模式**：允许 GET 请求的跨站导航，阻止 POST 请求的跨站提交
- **Strict 模式**：完全阻止跨站请求（可能影响用户体验）

#### 2.5.3 防止中间人攻击

**机制**：Secure Cookie
- Cookie 设置了 `Secure: true`
- 仅通过 HTTPS 传输
- 防止 HTTP 传输时被窃听

#### 2.5.4 防止 Session 固定攻击

**机制**：登录时重新生成 Session ID
- 用户登录成功后，创建新的 Session ID
- 旧的 Session ID 失效
- 防止攻击者预先设置 Session ID

#### 2.5.5 防止 Session 注入攻击

**机制**：Session ID 格式验证
- 验证 Session ID 格式（UUID格式：`^[0-9a-fA-F-]{36}$`）
- 防止注入恶意代码
- 无效格式直接拒绝

**代码示例**：
```typescript
// 验证 Session ID 格式
if (!/^[0-9a-fA-F-]{36}$/.test(sessionId)) {
  throw new UnauthorizedException('Invalid session ID format');
}
```

### 2.6 单点登录（SSO）实现

#### 2.6.1 Cookie Domain 共享

**配置**：`Domain=.sunmoonai.com`（注意前面的点）

**工作原理**：
- Cookie 在所有 `*.sunmoonai.com` 子域之间共享
- 用户在一个子域登录后，Cookie 自动在所有子域可用

**支持的子域**：
- `auth.sunmoonai.com`（认证服务）
- `llmops.sunmoonai.com`（LLMOps 应用）
- `incubator.sunmoonai.com`（Incubator 应用）
- 其他 `*.sunmoonai.com` 子域

#### 2.6.2 SSO 流程

```
1. 用户在 auth.sunmoonai.com 登录
   ↓
2. auth-app-backend 设置 Cookie（Domain=.sunmoonai.com）
   ↓
3. 浏览器保存 Cookie（对所有 .sunmoonai.com 子域有效）
   ↓
4. 用户访问 llmops.sunmoonai.com
   ↓
5. 浏览器自动发送 Cookie（因为 Domain 匹配）
   ↓
6. llmops-app-bff 验证 Cookie，用户已登录
   ↓
7. 用户无需重新登录，直接访问业务功能
```

### 2.7 与 OIDC SSO 的对比

| 特性 | Session + Cookie | OIDC SSO |
|------|------------------|----------|
| **实现复杂度** | 简单 | 复杂（需要实现标准协议） |
| **性能** | 高（Redis 内存访问） | 中等（需要验证 JWT 签名） |
| **标准化** | 自定义实现 | OIDC 标准协议 |
| **适用场景** | 内部系统、单组织 | 企业级 SaaS、多租户 |
| **第三方集成** | 不支持 | 支持（Google、Microsoft 等） |
| **跨组织 SSO** | 不支持 | 支持 |
| **开发成本** | 低 | 高 |
| **维护成本** | 低 | 中等 |
| **安全性** | 高（HttpOnly、Secure、SameSite） | 高（标准协议） |

### 2.8 优势与局限性

#### 2.8.1 优势

1. **实现简单**：无需实现复杂的 OAuth/OIDC 协议
2. **性能优秀**：Session 存储在 Redis，访问速度快
3. **安全性高**：HttpOnly、Secure、SameSite 多重保护
4. **适合内部系统**：单组织内多应用共享认证
5. **开发成本低**：快速实现，易于维护

#### 2.8.2 局限性

1. **不支持第三方 IDP**：无法使用 Google、Microsoft 等第三方登录
2. **跨组织 SSO 受限**：仅支持同域名下的子域共享
3. **无标准化协议**：无法与其他系统标准化对接
4. **扩展性有限**：不适合多租户 SaaS 场景

### 2.9 最佳实践

1. **Session 存储**：使用 Redis，设置合理的 TTL
2. **Cookie 安全**：必须设置 HttpOnly、Secure、SameSite
3. **Session ID 验证**：严格验证格式，防止注入攻击
4. **滑动续期**：用户活跃时自动延长 Session
5. **登出清理**：登出时彻底删除 Session 和 Cookie
6. **监控告警**：监控 Session 创建速率、Redis 性能等

---

## 四、Session 数据结构

```typescript
interface Session {
  session_id: string;
  user_id: number;
  username: string;
  email: string;
  full_name: string;
  is_active: boolean;
  is_superuser: boolean;  // 权限字段
  email_validated: boolean;
  roles: Array<{ roleId: number }>;  // 权限字段（预留）
  
  access_token: string;  // JWT Token（用于服务间调用）
  access_expires_at: number;  // 15分钟
  
  created_at: number;
  updated_at: number;
  expires_at: number;  // 7天
  last_activity: number;  // 用于滑动续期
  
  client_ip?: string;  // 可选
  user_agent?: string;  // 可选
}
```

---

## 五、环境变量配置

```bash
# Session 配置
SESSION_COOKIE_NAME=sunmoonai_session
SESSION_TTL_SECONDS=604800  # 7天
SESSION_SLIDE_RENEWAL_THRESHOLD=86400  # 1天

# Cookie 配置
AUTH_COOKIE_DOMAIN=.sunmoonai.com
AUTH_COOKIE_SAMESITE=Lax
AUTH_COOKIE_SECURE=true  # 生产环境

# Redis 配置
REDIS_HOST=redis-service
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=your_password
# ⚠️ 风险：单实例有单点故障风险，生产环境建议使用 Sentinel 或 Cluster（见 10.4 风险 2）
# REDIS_SENTINELS= sentinel1:26379,sentinel2:26379,sentinel3:26379
# REDIS_SENTINEL_NAME=mymaster

# JWT 配置
JWT_SECRET=your_secret
ACCESS_TOKEN_EXPIRES_IN=15m  # 15分钟
REFRESH_TOKEN_EXPIRES_IN=7d  # 7天

# 登录方式开关（暂时只启用 OAuth）
AUTH_LOGIN_OAUTH_ENABLED=true
AUTH_LOGIN_MAGIC_LINK_ENABLED=false
AUTH_LOGIN_TOTP_ENABLED=false
AUTH_LOGIN_PASSWORD_RECOVERY_ENABLED=false

# 灰度开关（可选，见 10.6 高级优化 4）
AUTH_SESSION_ENABLED=true
# AUTH_SESSION_USER_IDS=1,2,3  # 指定用户 ID 使用 Session

# 安全配置（可选，见 10.4 风险 5）
# AUTH_INTERNAL_IPS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16  # 允许的内网 IP
```

---

## 六、实施步骤（6 个阶段）

### 阶段 1：基础设施准备（1-2天）

1. **Redis 部署和配置**
   - 部署 Redis（单实例或集群）
   - 配置连接、密码、ACL
   - 配置监控和告警

2. **auth-app-backend 基础设施**
   - 添加 Redis 依赖：`npm install ioredis @types/ioredis`
   - 添加 Cookie 解析依赖：`npm install cookie-parser @types/cookie-parser`
   - 配置环境变量
   - **重要**：在 `main.ts` 中配置 `cookie-parser` 中间件（见 5.13）
   - **重要**：在 `AuthModule` 中注册 `RedisService` 和 `SessionStorageService`（见 5.14）

### 阶段 2：auth-app-backend 核心实现（3-5天）

3. **Session 存储层**
   - 实现 `RedisService`（基础封装）
   - 实现 `SessionStorageService`（Session CRUD）
   - 重构 `TokenStorageService`（迁移到 Redis）
   - 实现 `RedisKeyBuilder`（统一 Key 生成）

4. **认证接口改造**
   - 登录接口：生成 session_id，设置 Cookie
   - `/auth/me` 接口：支持 Cookie 认证（优先）+ Bearer Token（兼容）
   - `/auth/token` 接口：获取服务间调用 Token
   - 刷新接口：Session 滑动续期
   - 登出接口：删除 Session，清除 Cookie

5. **删除兼容代码**
   - 删除 `/auth/signin` 和 `/auth/signup` 接口
   - 删除 `signin()` 和 `signup()` 方法

6. **测试和验证**
   - 单元测试：Session CRUD、Cookie 设置
   - 集成测试：登录、认证、登出流程
   - 性能测试：Redis 延迟、并发能力

### 阶段 3：BFF 适配（2-3天，可与阶段 4 并行）

**调用关系说明：**

**重要术语说明：**
- **业务SSR**：指 `llmops-app-ssr`、`incubator-app-ssr` 等业务前端应用
- **业务BFF**：指 `llmops-app-bff` 和 `incubator-app-bff`，它们是业务后端服务
- **auth-app-front**：认证相关的SSR应用，负责登录页面
- **auth-app-backend**：认证服务

**正确的调用流程：**

```
场景1：已登录用户访问业务应用
浏览器/用户
  ↓ (发送 Cookie)
业务SSR (llmops-app-ssr / incubator-app-ssr)
  ↓ (调用业务API)
业务BFF (llmops-app-bff / incubator-app-bff)
  ↓ (判断：已登录，转发 Cookie 到 auth-app-backend)
auth-app-backend (认证服务)
  ↓ (验证 Session, 返回用户信息)
  ↑
  ↓ (返回用户信息和业务数据)
业务BFF → 业务SSR → 浏览器

场景2：未登录用户访问业务应用
浏览器/用户
  ↓ (发送请求，无 Cookie 或 Cookie 无效)
业务SSR (llmops-app-ssr / incubator-app-ssr)
  ↓ (调用业务API)
业务BFF (llmops-app-bff / incubator-app-bff)
  ↓ (判断：未登录，返回 401 或重定向)
  ↓ (重定向到 auth-app-front)
auth-app-front (认证页面)
  ↓ (用户登录，调用 auth-app-backend)
auth-app-backend (认证服务)
  ↓ (验证登录，设置 Cookie)
  ↑
  ↓ (登录成功，重定向回业务应用)
浏览器 → 业务SSR → 业务BFF → auth-app-backend
```

**详细流程：**

**场景1：已登录用户**
1. **浏览器** → **业务SSR**：用户访问业务应用，浏览器自动发送 Cookie
2. **业务SSR** → **业务BFF**：业务SSR 调用业务BFF 的 API（转发 Cookie）
3. **业务BFF 判断认证状态**：
   - 调用 `AuthClient.get_current_user(request)` 验证 Cookie
   - 如果 Cookie 有效（已登录）：继续处理业务请求
4. **业务BFF** → **auth-app-backend**：转发 Cookie 到 auth-app-backend 验证 Session
5. **auth-app-backend**：验证 Session，返回用户信息
6. **业务BFF**：处理业务逻辑，返回业务数据
7. **业务SSR**：渲染页面，返回给浏览器

**场景2：未登录用户**
1. **浏览器** → **业务SSR**：用户访问业务应用，无 Cookie 或 Cookie 无效
2. **业务SSR** → **业务BFF**：业务SSR 调用业务BFF 的 API
3. **业务BFF 判断认证状态**：
   - 调用 `AuthClient.get_current_user(request)` 验证 Cookie
   - 如果 Cookie 无效（未登录）：返回 401 或重定向响应
4. **业务SSR** → **浏览器**：收到 401 或重定向，重定向到 `auth-app-front`（登录页面）
5. **浏览器** → **auth-app-front**：用户访问登录页面
6. **auth-app-front** → **auth-app-backend**：用户提交登录信息，auth-app-front 调用 auth-app-backend 进行认证
7. **auth-app-backend**：验证登录，创建 Session，设置 Cookie
8. **auth-app-front** → **浏览器**：登录成功，重定向回业务应用
9. **浏览器** → **业务SSR**：携带 Cookie 重新访问业务应用（回到场景1）

**关键点：**
- ✅ **业务SSR调用业务BFF**：业务前端应用调用业务后端API
- ✅ **业务BFF判断认证状态**：业务BFF负责判断用户是否已登录
- ✅ **未登录时重定向**：如果未登录，业务BFF返回401或重定向到auth-app-front
- ✅ **auth-app-front负责登录**：认证页面由auth-app-front提供，调用auth-app-backend进行认证
- ✅ **业务BFF调用auth-app-backend**：已登录时，业务BFF转发Cookie到auth-app-backend验证

**实际代码架构验证：**
根据实际代码和配置文件：
- ✅ **业务BFF配置了 AUTH_SERVICE_URL**：
  - `llmops-app-bff` 配置：`AUTH_SERVICE_URL="${AUTH_SERVICE_URL:-http://localhost:8000}"`
  - `incubator-app-bff` 配置：`AUTH_SERVICE_URL="${AUTH_SERVICE_URL:-http://auth-app-backend:3030}"`
  - 说明业务BFF确实会调用auth-app-backend进行认证
- ✅ **业务SSR配置了后端API地址**：
  - 业务SSR通过配置调用对应的业务BFF API
  - 具体调用关系需要在业务SSR的源代码中确认

**服务角色说明：**
- **llmops-app-bff**：LLMOps 业务后端服务（业务BFF）
- **incubator-app-bff**：Incubator 业务后端服务（业务BFF）
- **auth-app-backend**：认证服务（虽然名字里有"bff"，但它是专门的认证服务）

7. **llmops-app-bff 改造**（业务BFF服务）
   - 重构 `AuthClient`：Cookie 转发方式（从 Request 读取 Cookie，转发到 auth-app-backend）
   - 重构 `deps.py`：从 Request 读取 Cookie，调用 `AuthClient.get_current_user(request)`
   - 测试：认证流程、服务间调用

8. **incubator-app-bff 改造**（业务BFF服务）
   - 重构 `AuthClient`：Cookie 转发方式（从 Request 读取 Cookie，转发到 auth-app-backend）
   - 重构 `deps.py`：从 Request 读取 Cookie，调用 `AuthClient.get_current_user(request)`
   - 测试：认证流程、服务间调用

### 阶段 4：SSR 适配（2-3天，可与阶段 3 并行）

**调用关系说明：**

**重要术语说明：**
- **业务SSR**：指 `llmops-app-ssr`、`incubator-app-ssr` 等业务前端应用
- **auth-app-front**：认证相关的SSR应用（Nuxt.js），负责登录页面和认证流程
- **业务BFF服务**：指 `llmops-app-bff` 和 `incubator-app-bff`，提供后端API服务
- **auth-app-backend**：认证服务

**auth-app-front 的作用（认证页面）：**
- ✅ **登录页面**：提供用户登录界面（OAuth、用户名密码等）
- ✅ **服务端渲染（SSR）**：在服务端渲染HTML页面，提供更好的SEO和首屏加载速度
- ✅ **认证流程**：处理登录请求，调用 auth-app-backend 进行认证
- ✅ **Cookie 设置**：登录成功后，auth-app-backend 设置 Cookie，auth-app-front 重定向回业务应用
- ❌ **不是业务应用**：auth-app-front 是专门的认证页面，不是业务应用

**业务SSR 的作用（业务前端应用）：**
- ✅ **业务页面**：提供业务功能页面（如 LLMOps 项目管理、Incubator 孵化器等）
- ✅ **服务端渲染（SSR）**：在服务端渲染HTML页面
- ✅ **调用业务BFF**：调用业务BFF的API获取业务数据
- ✅ **认证状态处理**：如果业务BFF返回401，重定向到auth-app-front登录页面

**正确的调用流程：**

```
未登录用户访问业务应用：
浏览器 → 业务SSR → 业务BFF (判断未登录) → 返回401/重定向
  ↓
浏览器 → auth-app-front (登录页面)
  ↓
auth-app-front → auth-app-backend (认证)
  ↓
auth-app-backend (设置Cookie) → auth-app-front (重定向)
  ↓
浏览器 → 业务SSR → 业务BFF (已登录) → auth-app-backend (验证) → 返回业务数据
```

**调用链：**
```
浏览器/用户
  ↓ (发送 Cookie)
auth-app-front (SSR 中间件)
  ↓ (读取 Cookie, 调用 BFF /api/v1/auth/me, 转发 Cookie)
llmops-app-bff / incubator-app-bff (BFF 服务)
  ↓ (AuthClient 转发 Cookie 到 auth-app-backend)
auth-app-backend (认证服务)
  ↓ (验证 Session, 返回用户信息)
  ↑
  ↓ (返回用户信息)
BFF
  ↑
  ↓ (返回用户信息)
auth-app-front (注入到 event.context.auth)
```

**详细流程：**
1. **浏览器** → **auth-app-front**：用户访问页面，浏览器自动发送 Cookie
2. **auth-app-front SSR 中间件**：读取 Cookie，调用 BFF 的 `/api/v1/auth/me` 接口（转发 Cookie）
3. **BFF** → **auth-app-backend**：BFF 的 `AuthClient.get_current_user(request)` 方法转发 Cookie 到 auth-app-backend
4. **auth-app-backend**：验证 Session，返回用户信息（如果 BFF 带了 `X-Service-Call: true`，还会返回 access_token）
5. **BFF** → **auth-app-front**：BFF 返回用户信息给 SSR
6. **auth-app-front**：将用户信息注入到 `event.context.auth`，供页面使用

**关键点：**
- ✅ **auth-app-front 是前端应用**：负责SSR渲染和前端交互，不是认证服务
- ✅ **业务BFF 是后端API**：提供业务逻辑和数据接口
- ✅ **SSR 不直接调用 auth-app-backend**：SSR 只调用业务BFF，由业务BFF负责认证
- ✅ **业务BFF 是认证代理**：业务BFF 接收来自 SSR 或浏览器的请求，转发 Cookie 到 auth-app-backend 进行认证
- ✅ **统一认证入口**：所有对 auth-app-backend 的调用都通过业务BFF 的 `AuthClient` 进行

**auth-app-front 和业务 BFF 的关系：**

**架构说明：**

这是标准的**前后端分离架构**，SSR 应用作为前端应用调用后端 API 服务。

**关系定位：**
- **auth-app-front**：前端 SSR 应用（Nuxt.js），负责页面渲染和前端交互
- **业务 BFF**（llmops-app-bff、incubator-app-bff）：后端 API 服务，提供业务逻辑和数据接口
- **关系**：前端-后端关系，**SSR 作为客户端调用业务 BFF 的 API**

**为什么是 SSR 调用 BFF，而不是 BFF 调用 SSR？**

这是标准的 Web 架构模式：

1. **SSR 是前端应用**：
   - 用户通过浏览器访问 SSR 应用（如 `https://auth.sunmoonai.com`）
   - SSR 应用在服务端渲染 HTML 页面
   - SSR 应用需要数据时，调用后端 API（业务 BFF）获取数据

2. **业务 BFF 是后端 API**：
   - 提供 RESTful API 接口，返回 JSON 数据
   - 不负责页面渲染，只负责业务逻辑
   - 接收来自 SSR 或浏览器的 HTTP 请求

3. **标准流程**：
   ```
   浏览器 → SSR 应用（渲染页面）
            ↓ 需要数据时
         业务 BFF API（返回 JSON 数据）
            ↓ 需要认证时
         auth-app-backend（认证服务）
   ```

**如果反过来（BFF 调用 SSR）会有什么问题？**
- ❌ BFF 是后端服务，不应该负责页面渲染
- ❌ SSR 是前端应用，不应该被后端服务调用
- ❌ 架构混乱：后端调用前端，不符合前后端分离原则

**交互方式：**
1. **SSR 服务端渲染时**：
   - auth-app-front 的 SSR 中间件调用业务 BFF 的 `/api/v1/auth/me` 接口
   - 获取用户信息，用于服务端渲染个性化内容

2. **前端页面交互时**：
   - 前端代码（组件、页面）通过 `$fetch` 或 `useFetch` 调用业务 BFF 的 API
   - 获取业务数据，更新页面状态

3. **认证流程**：
   - auth-app-front 转发 Cookie 到业务 BFF
   - 业务 BFF 转发 Cookie 到 auth-app-backend 进行认证
   - 认证成功后，业务 BFF 返回用户信息和业务数据

**调用接口示例：**
```typescript
// auth-app-front 调用业务 BFF 的接口

// 1. 获取用户信息（SSR 中间件）
const user = await $fetch(`${bffUrl}/api/v1/auth/me`, {
  headers: { cookie: `...` }
})

// 2. 获取业务数据（前端组件）
const data = await $fetch(`${bffUrl}/api/v1/llmops/projects`, {
  credentials: 'include'  // 自动发送 Cookie
})
```

**架构说明：**
```
前端层：auth-app-front (SSR前端应用)
  ↓ HTTP 调用业务API（转发 Cookie）
业务层：llmops-app-bff / incubator-app-bff (业务后端服务)
  ↓ HTTP 调用认证服务（转发 Cookie）
认证层：auth-app-backend (认证服务)
```

**为什么这样设计？**
- **职责分离**：前端应用（SSR）负责展示，业务服务（BFF）负责业务逻辑，认证服务（auth-app-backend）负责认证
- **可扩展性**：前端可以调用多个业务BFF，业务BFF可以调用统一的认证服务
- **安全性**：认证逻辑集中在 auth-app-backend，业务BFF只负责转发认证请求
- **前后端分离**：前端和后端独立部署、独立扩展，通过 HTTP API 通信

9. **auth-app-front 改造**
   - 删除 `stores/tokens.ts`（不再需要 Token 存储）
   - 重构 `api/core.ts`：移除 Token header，使用 `credentials: 'include'`（浏览器自动发送 Cookie）
   - 重构 `stores/auth.ts`：移除 Token 相关逻辑
   - 实现 SSR 中间件：读取 Cookie，调用 BFF 的 `/api/v1/auth/me` 接口（转发 Cookie）
   - 更新所有页面和组件：移除 Token 使用，改为从 `event.context.auth` 获取用户信息

10. **其他 SSR 应用改造**（如果有）
    - 同样的改造流程

### 阶段 5：基础设施完善（1-2天）

11. **Ingress/网关配置**
    - 配置 Cookie Domain（`.sunmoonai.com`）
    - 确保 Cookie 不被代理篡改
    - 配置 CORS（如需要）

12. **监控和告警**
    - 配置 Redis 监控（连接数、内存、延迟）
    - 配置认证接口监控（延迟、错误率）
    - 配置告警阈值

### 阶段 6：文档和回归测试（1-2天）

13. **文档更新**
    - 更新架构文档
    - 更新 API 文档
    - 更新部署文档

14. **完整回归测试**
    - 登录流程（OAuth）
    - 认证流程（Cookie 认证、Bearer Token 兼容）
    - 跨子域 SSO
    - 登出和踢出
    - 性能测试

---

## 七、详细代码实现

### 5.1 Redis 服务封装

**文件**：`src/common/services/redis.service.ts`

```typescript
import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis;

  constructor(private configService: ConfigService) {}

  async onModuleInit() {
    this.client = new Redis({
      host: this.configService.get<string>('REDIS_HOST', 'localhost'),
      port: this.configService.get<number>('REDIS_PORT', 6379),
      db: this.configService.get<number>('REDIS_DB', 0),
      password: this.configService.get<string>('REDIS_PASSWORD'),
      retryStrategy: (times) => {
        const delay = Math.min(times * 50, 2000);
        return delay;
      },
      maxRetriesPerRequest: 3,
    });

    this.client.on('connect', () => {
      this.logger.log('Redis connected');
    });

    this.client.on('error', (err) => {
      this.logger.error('Redis error:', err);
    });
  }

  async onModuleDestroy() {
    await this.client.quit();
  }

  async get(key: string): Promise<string | null> {
    try {
      return await this.client.get(key);
    } catch (error) {
      this.logger.error(`Redis GET error for key ${key}:`, error);
      throw error;
    }
  }

  async set(key: string, value: string, ttl?: number): Promise<void> {
    try {
      if (ttl) {
        await this.client.setex(key, ttl, value);
      } else {
        await this.client.set(key, value);
      }
    } catch (error) {
      this.logger.error(`Redis SET error for key ${key}:`, error);
      throw error;
    }
  }

  async del(key: string): Promise<void> {
    try {
      await this.client.del(key);
    } catch (error) {
      this.logger.error(`Redis DEL error for key ${key}:`, error);
      throw error;
    }
  }

  async exists(key: string): Promise<boolean> {
    try {
      const result = await this.client.exists(key);
      return result === 1;
    } catch (error) {
      this.logger.error(`Redis EXISTS error for key ${key}:`, error);
      return false;
    }
  }

  async expire(key: string, seconds: number): Promise<void> {
    try {
      await this.client.expire(key, seconds);
    } catch (error) {
      this.logger.error(`Redis EXPIRE error for key ${key}:`, error);
      throw error;
    }
  }

  // Set 操作（用于 user_sessions）
  async sadd(key: string, ...members: string[]): Promise<void> {
    try {
      await this.client.sadd(key, ...members);
    } catch (error) {
      this.logger.error(`Redis SADD error for key ${key}:`, error);
      throw error;
    }
  }

  async smembers(key: string): Promise<string[]> {
    try {
      return await this.client.smembers(key);
    } catch (error) {
      this.logger.error(`Redis SMEMBERS error for key ${key}:`, error);
      return [];
    }
  }

  async srem(key: string, ...members: string[]): Promise<void> {
    try {
      await this.client.srem(key, ...members);
    } catch (error) {
      this.logger.error(`Redis SREM error for key ${key}:`, error);
      throw error;
    }
  }

  getClient(): Redis {
    return this.client;
  }
}
```

### 5.2 Redis Key 生成工具

**文件**：`src/common/utils/redis-key-builder.ts`

```typescript
export class RedisKeyBuilder {
  private static readonly PREFIX = 'auth';

  static session(sessionId: string): string {
    return `${this.PREFIX}:session:${sessionId}`;
  }

  static userSessions(userId: string | number): string {
    return `${this.PREFIX}:user_sessions:${userId}`;
  }

  static blacklist(token: string): string {
    return `${this.PREFIX}:blacklist:${token}`;
  }

  static magic(token: string): string {
    return `${this.PREFIX}:magic:${token}`;
  }

  static recovery(token: string): string {
    return `${this.PREFIX}:recovery:${token}`;
  }

  static totpSetup(username: string): string {
    return `${this.PREFIX}:totp-setup:${username}`;
  }

  static emailValidation(token: string): string {
    return `${this.PREFIX}:email-validation:${token}`;
  }
}
```

### 5.3 Session 存储服务

**文件**：`src/common/services/session-storage.service.ts`

```typescript
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RedisService } from './redis.service';
import { RedisKeyBuilder } from '../utils/redis-key-builder';

interface Session {
  session_id: string;
  user_id: number;
  username: string;
  email: string;
  full_name: string;
  is_active: boolean;
  is_superuser: boolean;
  email_validated: boolean;
  roles: Array<{ roleId: number }>;
  access_token: string;
  access_expires_at: number;
  created_at: number;
  updated_at: number;
  expires_at: number;
  last_activity: number;
  client_ip?: string;
  user_agent?: string;
}

@Injectable()
export class SessionStorageService {
  private readonly logger = new Logger(SessionStorageService.name);
  private readonly sessionTtl: number;

  constructor(
    private redisService: RedisService,
    private configService: ConfigService,
  ) {
    this.sessionTtl = this.configService.get<number>('SESSION_TTL_SECONDS', 604800);
  }

  async setSession(sessionId: string, session: Session, ttl?: number): Promise<void> {
    const key = RedisKeyBuilder.session(sessionId);
    const ttlSeconds = ttl || this.sessionTtl;
    
    session.updated_at = Date.now() / 1000;
    const sessionJson = JSON.stringify(session);
    
    await this.redisService.set(key, sessionJson, ttlSeconds);
    
    // 更新用户 Session 映射
    await this.addUserSession(session.user_id, sessionId);
    
    this.logger.debug(`Session created: ${sessionId} for user ${session.user_id}`);
  }

  async getSession(sessionId: string): Promise<Session | null> {
    const key = RedisKeyBuilder.session(sessionId);
    const sessionJson = await this.redisService.get(key);
    
    if (!sessionJson) {
      return null;
    }

    try {
      const session: Session = JSON.parse(sessionJson);
      
      // 检查是否过期
      const now = Date.now() / 1000;
      if (session.expires_at < now) {
        await this.deleteSession(sessionId);
        return null;
      }

      // ⚠️ 风险 6：优化滑动续期逻辑，减少写操作抖动
      const remaining = session.expires_at - now;
      const slideThreshold = this.configService.get<number>('SESSION_SLIDE_RENEWAL_THRESHOLD', 86400);
      const lastActivityDiff = now - session.last_activity;
      
      // 条件1：剩余时间 < 阈值
      // 条件2：距离上次活动 > 1小时（避免频繁更新）
      // 条件3：距离上次更新 > 5分钟（避免抖动）
      const shouldRenew = remaining < slideThreshold && 
                         lastActivityDiff > 3600 &&
                         (now - (session.updated_at || session.created_at)) > 300; // 5分钟冷却期
      
      if (shouldRenew) {
        session.expires_at = now + this.sessionTtl;
        session.last_activity = now;
        session.updated_at = now;
        await this.redisService.set(key, JSON.stringify(session), this.sessionTtl);
        this.logger.debug(`Session renewed: ${sessionId}`);
      } else {
        // 只更新 last_activity，使用 EXPIRE 命令只更新 TTL，不重写整个 Session
        session.last_activity = now;
        await this.redisService.expire(key, Math.ceil(remaining));
      }

      // Access Token 自动刷新
      if (session.access_expires_at < now) {
        // 需要重新生成 access_token（在 auth.service 中处理）
        // 这里只标记需要刷新
        session.access_expires_at = now + 900; // 临时设置，实际在 auth.service 中生成
      }

      return session;
    } catch (error) {
      this.logger.error(`Failed to parse session ${sessionId}:`, error);
      return null;
    }
  }

  async deleteSession(sessionId: string): Promise<void> {
    const key = RedisKeyBuilder.session(sessionId);
    
    // 先获取 session 信息，以便从 user_sessions 中删除
    const sessionJson = await this.redisService.get(key);
    if (sessionJson) {
      try {
        const session: Session = JSON.parse(sessionJson);
        await this.removeUserSession(session.user_id, sessionId);
      } catch (error) {
        this.logger.warn(`Failed to parse session when deleting: ${sessionId}`);
      }
    }
    
    await this.redisService.del(key);
    this.logger.debug(`Session deleted: ${sessionId}`);
  }

  async addUserSession(userId: number, sessionId: string): Promise<void> {
    const key = RedisKeyBuilder.userSessions(userId);
    await this.redisService.sadd(key, sessionId);
    await this.redisService.expire(key, this.sessionTtl);
  }

  async removeUserSession(userId: number, sessionId: string): Promise<void> {
    const key = RedisKeyBuilder.userSessions(userId);
    await this.redisService.srem(key, sessionId);
  }

  async getUserSessions(userId: number): Promise<string[]> {
    const key = RedisKeyBuilder.userSessions(userId);
    return await this.redisService.smembers(key);
  }

  async deleteUserSessions(userId: number): Promise<void> {
    const sessionIds = await this.getUserSessions(userId);
    for (const sessionId of sessionIds) {
      await this.deleteSession(sessionId);
    }
    const key = RedisKeyBuilder.userSessions(userId);
    await this.redisService.del(key);
  }
}

// ⚠️ 风险 5：IP 白名单检查（辅助方法）
private isIpAllowed(ip: string, allowedIps: string[]): boolean {
  // 简单的 CIDR 匹配（生产环境建议使用 ipaddr.js 库）
  for (const allowedIp of allowedIps) {
    if (allowedIp.includes('/')) {
      // CIDR 格式：10.0.0.0/8
      const [network, prefix] = allowedIp.split('/');
      // 简化实现，生产环境建议使用专业库
      if (this.isIpInCidr(ip, network, parseInt(prefix, 10))) {
        return true;
      }
    } else {
      // 直接 IP 匹配
      if (ip === allowedIp) {
        return true;
      }
    }
  }
  return false;
}

private isIpInCidr(ip: string, network: string, prefix: number): boolean {
  // 简化实现，生产环境建议使用 ipaddr.js
  // 这里仅作示例
  return ip.startsWith(network.split('.').slice(0, Math.floor(prefix / 8)).join('.'));
}
```

### 5.4 Token 存储服务（迁移到 Redis）

**文件**：`src/common/services/token-storage.service.ts`（重构后）

```typescript
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RedisService } from './redis.service';
import { RedisKeyBuilder } from '../utils/redis-key-builder';

interface TokenData {
  value: string;
  expiresAt: number;
  fingerprint?: string;
}

@Injectable()
export class TokenStorageService {
  private readonly logger = new Logger(TokenStorageService.name);

  constructor(
    private redisService: RedisService,
    private configService: ConfigService,
  ) {}

  async setToken(
    key: string,
    value: string,
    expiresInSeconds: number = 900,
    fingerprint?: string,
  ): Promise<void> {
    const tokenData: TokenData = {
      value,
      expiresAt: Date.now() + expiresInSeconds * 1000,
      fingerprint,
    };
    
    const redisKey = this.getRedisKey(key);
    await this.redisService.set(redisKey, JSON.stringify(tokenData), expiresInSeconds);
  }

  async getToken(key: string): Promise<string | null> {
    const redisKey = this.getRedisKey(key);
    const tokenDataJson = await this.redisService.get(redisKey);
    
    if (!tokenDataJson) {
      return null;
    }

    try {
      const tokenData: TokenData = JSON.parse(tokenDataJson);
      if (Date.now() > tokenData.expiresAt) {
        await this.deleteToken(key);
        return null;
      }
      return tokenData.value;
    } catch (error) {
      this.logger.error(`Failed to parse token data for key ${key}:`, error);
      return null;
    }
  }

  async getTokenData(key: string): Promise<TokenData | null> {
    const redisKey = this.getRedisKey(key);
    const tokenDataJson = await this.redisService.get(redisKey);
    
    if (!tokenDataJson) {
      return null;
    }

    try {
      const tokenData: TokenData = JSON.parse(tokenDataJson);
      if (Date.now() > tokenData.expiresAt) {
        await this.deleteToken(key);
        return null;
      }
      return tokenData;
    } catch (error) {
      this.logger.error(`Failed to parse token data for key ${key}:`, error);
      return null;
    }
  }

  async deleteToken(key: string): Promise<void> {
    const redisKey = this.getRedisKey(key);
    await this.redisService.del(redisKey);
  }

  async verifyFingerprint(key: string, fingerprint: string): Promise<boolean> {
    const tokenData = await this.getTokenData(key);
    if (!tokenData || !tokenData.fingerprint) {
      return false;
    }
    return tokenData.fingerprint === fingerprint;
  }

  async addToBlacklist(token: string, expiresInSeconds: number = 3600): Promise<void> {
    const key = RedisKeyBuilder.blacklist(token);
    await this.redisService.set(key, '1', expiresInSeconds);
  }

  async isBlacklisted(token: string): Promise<boolean> {
    const key = RedisKeyBuilder.blacklist(token);
    return await this.redisService.exists(key);
  }

  private getRedisKey(key: string): string {
    // 根据 key 前缀判断类型
    if (key.startsWith('magic:')) {
      return RedisKeyBuilder.magic(key.replace('magic:', ''));
    } else if (key.startsWith('recovery:')) {
      return RedisKeyBuilder.recovery(key.replace('recovery:', ''));
    } else if (key.startsWith('totp-setup:')) {
      return RedisKeyBuilder.totpSetup(key.replace('totp-setup:', ''));
    } else if (key.startsWith('email-validation:')) {
      return RedisKeyBuilder.emailValidation(key.replace('email-validation:', ''));
    }
    // 默认使用原始 key（兼容旧代码）
    return `auth:${key}`;
  }
}
```

### 5.5 创建 Session（统一方法）

**文件**：`src/auth/auth.service.ts`（新增方法）

**注意**：此方法中获取用户数据仍然通过 gRPC 调用 `user-service`，不受 Session + Cookie 改造影响。

```typescript
async createSession(user: User, res: Response, req?: Request): Promise<Session> {
  const sessionId = uuidv4();
  const now = Date.now() / 1000;
  
  // 生成 access_token（用于服务间调用）
  const accessToken = await this.jwt.signAsync(
    {
      sub: String(user.id),
      username: user.username,
      is_superuser: user.is_superuser,
    },
    { expiresIn: '15m' },
  );

  const session: Session = {
    session_id: sessionId,
    user_id: user.id,
    username: user.username,
    email: user.email,
    full_name: user.full_name || '',
    is_active: user.is_active,
    is_superuser: user.is_superuser,
    email_validated: user.email_validated || false,
    roles: user.roles || [],
    access_token: accessToken,
    access_expires_at: now + 900, // 15分钟
    created_at: now,
    updated_at: now,
    expires_at: now + this.configService.get<number>('SESSION_TTL_SECONDS', 604800),
    last_activity: now,
    client_ip: req?.ip,
    user_agent: req?.headers['user-agent'],
  };

  // 存储到 Redis
  await this.sessionStorageService.setSession(sessionId, session);

  // 设置 Cookie
  const cookieName = this.configService.get<string>('SESSION_COOKIE_NAME', 'sunmoonai_session');
  res.cookie(cookieName, sessionId, {
    httpOnly: true,
    secure: this.configService.get<boolean>('AUTH_COOKIE_SECURE', true),
    sameSite: this.configService.get<'lax' | 'strict' | 'none'>('AUTH_COOKIE_SAMESITE', 'lax'),
    domain: this.configService.get<string>('AUTH_COOKIE_DOMAIN', '.sunmoonai.com'),
    path: '/',
    maxAge: this.configService.get<number>('SESSION_TTL_SECONDS', 604800) * 1000,
  });

  this.logger.log(`Session created for user ${user.id}: ${sessionId}`);
  return session;
}
```

**gRPC 调用说明**：
- 在调用 `createSession()` 之前，用户数据通过 gRPC 从 `user-service` 获取
- 例如：`const user = await this.userService.findOne({ username })`
- 这个 gRPC 调用**不受 Session + Cookie 改造影响**，保持原有实现即可

### 5.6 登录接口改造

**文件**：`src/auth/auth.controller.ts`

**注意**：登录时通过 gRPC 调用 `user-service` 获取用户数据，这部分代码保持不变。

```typescript
@Post('login/oauth')
async loginWithOauth(
  @Body() body: OAuthLoginDto,
  @Res({ passthrough: false }) res: Response,
  @Req() req: Request,
): Promise<UserProfileDto> {
  // 检查是否启用 OAuth 登录
  const oauthEnabled = this.configService.get<string>('AUTH_LOGIN_OAUTH_ENABLED', 'true') !== 'false';
  if (!oauthEnabled) {
    throw new NotFoundException('OAuth login is not enabled');
  }

  // 验证用户名密码（内部通过 gRPC 调用 user-service）
  const user = await this.authService.validateUser(body.username, body.password);
  // 注意：validateUser() 内部调用 this.userService.findOne({ username })
  // 这是 gRPC 调用，不受 Session + Cookie 改造影响
  
  // 检查是否需要 TOTP
  if (user.totpEnabled && user.totpSecret) {
    // 返回临时 Token，需要 TOTP 验证
    const tempToken = await this.jwt.signAsync(
      { sub: String(user.id), totp: true },
      { expiresIn: '5m' },
    );
    return {
      access_token: tempToken,
      totp_required: true,
    } as any;
  }

  // 创建 Session（新增：设置 Cookie）
  const session = await this.authService.createSession(user, res, req);
  
  // 返回用户信息（不返回 Token）
  return this.authService.mapSessionToUserProfile(session);
}
```

**gRPC 调用流程**：
```
登录请求
  ↓
auth.service.validateUser()
  ↓
userService.findOne({ username })  ← gRPC 调用（不受影响）
  ↓
验证密码
  ↓
createSession()  ← 新增：创建 Session，设置 Cookie
  ↓
返回用户信息
```

### 5.7 `/auth/me` 接口实现

**文件**：`src/auth/auth.controller.ts`

**注意**：Bearer Token 认证回退路径中，仍然通过 gRPC 调用 `user-service` 获取用户数据。

```typescript
@Get('auth/me')
async getCurrentUser(@Req() req: Request): Promise<UserProfileDto | UserProfileWithTokenDto> {
  const cookieName = this.configService.get<string>('SESSION_COOKIE_NAME', 'sunmoonai_session');
  
  // 1. 优先尝试 Cookie 认证（新增：从 Redis Session 获取用户信息）
  const sessionId = req.cookies[cookieName];
  if (sessionId) {
    // 验证 Session ID 格式（防止注入攻击）
    if (!/^[a-zA-Z0-9\-_]+$/.test(sessionId)) {
      throw new UnauthorizedException('Invalid session ID format');
    }

    // ⚠️ 风险 4：Session ID 格式验证（更严格的正则）
    if (!/^[0-9a-fA-F-]{36}$/.test(sessionId)) {
      throw new UnauthorizedException('Invalid session ID format');
    }

    const session = await this.sessionStorageService.getSession(sessionId);
    if (session) {
      // 自动刷新 access_token（如果过期）
      const now = Date.now() / 1000;
      if (session.access_expires_at < now) {
        session.access_token = await this.jwt.signAsync(
          {
            sub: String(session.user_id),
            username: session.username,
            is_superuser: session.is_superuser,
          },
          { expiresIn: '15m' },
        );
        session.access_expires_at = now + 900;
        await this.sessionStorageService.setSession(sessionId, session);
      }

      const isServiceCall = req.headers['x-service-call'] === 'true';
      if (isServiceCall) {
        // 服务端调用：返回用户信息 + access_token
        return {
          ...this.mapSessionToUserProfile(session),
          access_token: session.access_token,
        };
      } else {
        // 浏览器调用：只返回用户信息（从 Session 中获取，无需 gRPC 调用）
        return this.mapSessionToUserProfile(session);
      }
    }
  }

  // 2. 回退到 Bearer Token 认证（服务间调用）
  // 注意：这里仍然通过 gRPC 调用 user-service 获取用户数据
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token) {
    try {
      const payload = await this.jwt.verifyAsync(token);
      
      // 检查黑名单
      if (await this.tokenStorage.isBlacklisted(token)) {
        throw new UnauthorizedException('Token has been revoked');
      }

      const userId = parseInt(payload.sub, 10);
      // gRPC 调用：获取用户数据（不受 Session + Cookie 改造影响）
      const user = await this.userService.findById({ id: userId });
      
      if (!user || user.isActive === false) {
        throw new UnauthorizedException('User not found or inactive');
      }

      return this.mapUserToProfile(user);
    } catch (error) {
      throw new UnauthorizedException('Invalid token');
    }
  }

  // 3. 都无效
  throw new UnauthorizedException('No valid authentication found');
}
```

**gRPC 调用说明**：
- **Cookie 认证路径**：从 Redis Session 获取用户信息，**无需 gRPC 调用**（性能更好）
- **Bearer Token 认证路径**：仍然通过 gRPC 调用 `userService.findById()` 获取用户数据
- **性能优化**：优先使用 Cookie 认证，减少 gRPC 调用

### 5.8 `/auth/token` 接口实现

**文件**：`src/auth/auth.controller.ts`

```typescript
@Get('auth/token')
async getServiceToken(@Req() req: Request): Promise<{ access_token: string }> {
  // ⚠️ 风险 5：敏感接口保护 - 必须带 X-Service-Call header
  const isServiceCall = req.headers['x-service-call'] === 'true';
  if (!isServiceCall) {
    throw new ForbiddenException('This endpoint is only available for service-to-service calls');
  }

  // 可选：校验内网 IP（生产环境推荐）
  const clientIp = req.ip || req.headers['x-forwarded-for']?.toString().split(',')[0];
  const allowedIps = this.configService.get<string[]>('AUTH_INTERNAL_IPS', []);
  if (allowedIps.length > 0 && !this.isIpAllowed(clientIp, allowedIps)) {
    throw new ForbiddenException('Access denied: IP not in allowed list');
  }

  const cookieName = this.configService.get<string>('SESSION_COOKIE_NAME', 'sunmoonai_session');
  const sessionId = req.cookies[cookieName];
  
  if (!sessionId) {
    throw new UnauthorizedException('No session found');
  }

  const session = await this.sessionStorageService.getSession(sessionId);
  if (!session) {
    throw new UnauthorizedException('Session expired');
  }

  // 如果 access_token 过期，自动刷新
  const now = Date.now() / 1000;
  if (session.access_expires_at < now) {
    session.access_token = await this.jwt.signAsync(
      {
        sub: String(session.user_id),
        username: session.username,
        is_superuser: session.is_superuser,
      },
      { expiresIn: '15m' },
    );
    session.access_expires_at = now + 900;
    await this.sessionStorageService.setSession(sessionId, session);
  }

  return { access_token: session.access_token };
}
```

### 5.9 登出接口实现

**文件**：`src/auth/auth.controller.ts`

```typescript
@Post('auth/logout')
async logout(@Req() req: Request, @Res() res: Response): Promise<MessageDto> {
  const cookieName = this.configService.get<string>('SESSION_COOKIE_NAME', 'sunmoonai_session');
  const sessionId = req.cookies[cookieName];

  if (sessionId) {
    // 获取 Session（用于获取 refresh_token 加入黑名单）
    const session = await this.sessionStorageService.getSession(sessionId);
    if (session) {
      // 删除 Session
      await this.sessionStorageService.deleteSession(sessionId);
      
      // 如果有 refresh_token，加入黑名单（如果实现了 refresh_token）
      // await this.tokenStorage.addToBlacklist(refreshToken, remainingTime);
    }
  }

  // 清除 Cookie
  res.clearCookie(cookieName, {
    httpOnly: true,
    secure: this.configService.get<boolean>('AUTH_COOKIE_SECURE', true),
    sameSite: this.configService.get<'lax' | 'strict' | 'none'>('AUTH_COOKIE_SAMESITE', 'lax'),
    domain: this.configService.get<string>('AUTH_COOKIE_DOMAIN', '.sunmoonai.com'),
    path: '/',
  });

  return { message: 'Logged out successfully' };
}
```

### 5.10 BFF AuthClient 改造（完整版）

**文件**：`llmops-app-bff/app/core/auth_client.py`

```python
import httpx
from typing import Optional, Dict, Any
from fastapi import Request
from app.core.config import settings


class AuthClient:
    """认证服务客户端 - 支持 Cookie 转发"""
    
    def __init__(self):
        self.base_url = settings.AUTH_SERVICE_URL
    
    async def get_current_user(self, request: Request) -> Dict[str, Any]:
        """
        从认证服务获取当前用户信息（通过 Cookie 转发）
        
        Args:
            request: FastAPI Request 对象，包含 Cookie
            
        Returns:
            用户信息字典（包含 access_token，用于后续服务间调用）
            
        Raises:
            httpx.HTTPStatusError: 如果请求失败（401/403）
        """
        headers = {}
        
        # 原样转发 Cookie
        cookies = request.headers.get("cookie")
        if cookies:
            headers["Cookie"] = cookies
        
        # 添加服务端调用标识（用于获取 access_token）
        headers["X-Service-Call"] = "true"
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(
                    f"{self.base_url}/api/v1/auth/me",
                    headers=headers,
                    timeout=5.0
                )
                response.raise_for_status()
                user_info = response.json()
                
                # auth-app-backend 会返回 access_token（因为带了 X-Service-Call header）
                return user_info
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 401:
                    raise
                raise
            except Exception as e:
                raise
    
    async def get_access_token(self, request: Request) -> str:
        """
        获取 access_token（用于服务间调用）
        
        Args:
            request: FastAPI Request 对象，包含 Cookie
            
        Returns:
            JWT Token 字符串
        """
        headers = {}
        cookies = request.headers.get("cookie")
        if cookies:
            headers["Cookie"] = cookies
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v1/auth/token",
                headers=headers,
                timeout=5.0
            )
            response.raise_for_status()
            result = response.json()
            return result.get("access_token", "")
```

### 5.11 BFF 依赖注入改造

**文件**：`llmops-app-bff/app/api/deps.py`

```python
from typing import Annotated, Dict, Any
from fastapi import Depends, HTTPException, status, Request
from app.core.auth_client import AuthClient, get_auth_client


async def get_current_user(
    request: Request,
    auth_client: AuthClient = Depends(get_auth_client),
) -> Dict[str, Any]:
    """
    获取当前用户（从认证服务，通过 Cookie）
    
    注意：这里返回的是字典，不是User模型，因为用户数据在认证服务
    """
    try:
        user = await auth_client.get_current_user(request)
        return user
    except Exception as e:
        # 如果是 401，返回 401
        if hasattr(e, 'response') and e.response.status_code == 401:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
            )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Could not validate credentials",
        )
```

### 5.12 配置 cookie-parser 中间件

**文件**：`src/main.ts`（修改）

**重要**：必须在所有路由之前配置 cookie-parser，否则无法读取 Cookie。

```typescript
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { VERSION_NEUTRAL, VersioningType } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { urlencoded, json } from 'express';
import * as cookieParser from 'cookie-parser'; // 新增
import { MicroserviceOptions, Transport } from '@nestjs/microservices';
import { join } from 'path';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configServcie = app.get(ConfigService);
  const versionStr = configServcie.get<string>('VERSION');
  const prefix = configServcie.get('PREFIX', '/api');

  // 支持 form-data 和 URL-encoded
  app.use(json());
  app.use(urlencoded({ extended: true }));
  
  // 配置 cookie-parser（必须在路由之前）
  app.use(cookieParser()); // 新增

  // ... 其他配置保持不变
}
bootstrap();
```

### 5.13 注册 Redis 和 Session 服务

**文件**：`src/auth/auth.module.ts`（修改）

**重要**：必须在 `AuthModule` 中注册 `RedisService` 和 `SessionStorageService`，否则无法注入使用。

```typescript
import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { JwtStrategy } from './strategies/jwt.strategy';
import { EmailService } from '../common/services/email.service';
import { TotpService } from '../common/services/totp.service';
import { TokenStorageService } from '../common/services/token-storage.service';
import { RedisService } from '../common/services/redis.service'; // 新增
import { SessionStorageService } from '../common/services/session-storage.service'; // 新增

@Module({
  imports: [
    PassportModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: async (configService: ConfigService) => {
        return {
          secret: configService.get('JWT_SECRET'),
          signOptions: { expiresIn: '15m' },
        };
      },
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    EmailService,
    TotpService,
    TokenStorageService,
    RedisService, // 新增
    SessionStorageService, // 新增
  ],
  exports: [AuthService],
})
export class AuthModule {}
```

### 5.14 实现 mapSessionToUserProfile 方法

**文件**：`src/auth/auth.service.ts`（新增方法）

**重要**：需要在 `AuthService` 中实现 `mapSessionToUserProfile` 方法，用于将 Session 转换为 UserProfileDto。

```typescript
/**
 * 映射 Session 到 UserProfileDto
 */
mapSessionToUserProfile(session: Session): UserProfileDto {
  return {
    id: String(session.user_id),
    email: session.email,
    email_validated: session.email_validated,
    is_active: session.is_active,
    is_superuser: session.is_superuser,
    full_name: session.full_name,
    password: false, // Session 中不存储密码
    totp: false, // 如果需要，可以从 user-service 获取
  };
}
```

### 5.15 实现 validateUser 方法（可选）

**文件**：`src/auth/auth.service.ts`（新增方法，可选）

**说明**：如果登录接口中需要独立的 `validateUser` 方法，可以实现如下：

```typescript
/**
 * 验证用户（用户名密码）
 */
async validateUser(username: string, password: string): Promise<any> {
  const user: any = await this.userService.findOne({ username });
  if (!user) {
    throw new ForbiddenException('用户不存在');
  }

  const isPasswordValid = await argon2.verify(user.password, password);
  if (!isPasswordValid) {
    throw new ForbiddenException('用户名或密码错误');
  }

  if (user.isActive === false) {
    throw new ForbiddenException('用户已被禁用');
  }

  return user;
}
```

**注意**：如果 `loginWithOauth` 方法中已经有验证逻辑，可以直接使用，无需单独实现 `validateUser`。

### 5.16 修改 createSession 方法签名

**文件**：`src/auth/auth.service.ts`（修改方法）

**重要**：`createSession` 方法需要注入 `SessionStorageService` 和 `ConfigService`。

```typescript
constructor(
  private jwt: JwtService,
  private consulService: ConsulService,
  private emailService: EmailService,
  private totpService: TotpService,
  private tokenStorage: TokenStorageService,
  private sessionStorageService: SessionStorageService, // 新增
  private configService: ConfigService, // 新增
) {}
```

### 5.17 修改 /auth/me 接口实现

**文件**：`src/auth/auth.controller.ts`（修改方法）

**重要**：需要在 Controller 中注入 `SessionStorageService` 和 `TokenStorageService`。

```typescript
constructor(
  private authService: AuthService,
  private configService: ConfigService,
  private sessionStorageService: SessionStorageService, // 新增
  private tokenStorage: TokenStorageService, // 新增（如果使用）
) {}
```

**完整实现**：

```typescript
@Get('auth/me')
async getCurrentUser(@Req() req: Request): Promise<UserProfileDto | UserProfileWithTokenDto> {
  const cookieName = this.configService.get<string>('SESSION_COOKIE_NAME', 'sunmoonai_session');
  
  // 1. 优先尝试 Cookie 认证
  const sessionId = req.cookies[cookieName];
  if (sessionId) {
    // 验证 Session ID 格式（防止注入攻击）
    if (!/^[a-zA-Z0-9\-_]+$/.test(sessionId)) {
      throw new UnauthorizedException('Invalid session ID format');
    }

    const session = await this.sessionStorageService.getSession(sessionId);
    if (session) {
      // 自动刷新 access_token（如果过期）
      const now = Date.now() / 1000;
      if (session.access_expires_at < now) {
        session.access_token = await this.authService.generateAccessToken({
          id: session.user_id,
          username: session.username,
          is_superuser: session.is_superuser,
        });
        session.access_expires_at = now + 900;
        await this.sessionStorageService.setSession(sessionId, session);
      }

      const isServiceCall = req.headers['x-service-call'] === 'true';
      if (isServiceCall) {
        // 服务端调用：返回用户信息 + access_token
        return {
          ...this.authService.mapSessionToUserProfile(session),
          access_token: session.access_token,
        };
      } else {
        // 浏览器调用：只返回用户信息
        return this.authService.mapSessionToUserProfile(session);
      }
    }
  }

  // 2. 回退到 Bearer Token 认证（服务间调用）
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token) {
    try {
      const payload = await this.authService.verifyToken(token);
      
      // 检查黑名单
      if (await this.tokenStorage.isBlacklisted(token)) {
        throw new UnauthorizedException('Token has been revoked');
      }

      const userId = parseInt(payload.sub, 10);
      const user = await this.authService.getUserById(userId);
      
      if (!user || user.isActive === false) {
        throw new UnauthorizedException('User not found or inactive');
      }

      return this.authService.mapUserToProfile(user);
    } catch (error) {
      throw new UnauthorizedException('Invalid token');
    }
  }

  // 3. 都无效
  throw new UnauthorizedException('No valid authentication found');
}
```

**注意**：如果 `AuthService` 中没有 `generateAccessToken`、`verifyToken`、`getUserById` 方法，需要实现或使用现有方法。

### 5.18 SSR 中间件实现（完整版）

**文件**：`auth-app-front/server/middleware/auth.global.ts`

```typescript
import type { EventHandler } from 'h3'
import { useRuntimeConfig } from '#imports'

interface AuthContext {
  user: any | null
  authenticated: boolean
  sessionId?: string
}

declare module 'h3' {
  interface H3EventContext {
    auth?: AuthContext
  }
}

// 短时间缓存用户信息（减少 BFF 调用）
const userCache = new Map<string, { user: any; expires: number }>()
const CACHE_TTL = 5000 // 5秒缓存

export default defineEventHandler(async (event) => {
  // 跳过静态资源和非 API 请求
  const url = getRequestURL(event)
  if (url.pathname.startsWith('/_nuxt') || url.pathname.startsWith('/api/')) {
    return
  }

  const config = useRuntimeConfig()
  const cookies = parseCookies(event)
  const sessionCookieName = config.public.sessionCookieName || 'sunmoonai_session'
  const sessionId = cookies[sessionCookieName]

  // 如果没有 Session Cookie，直接跳过
  if (!sessionId) {
    event.context.auth = {
      user: null,
      authenticated: false,
    }
    return
  }

  // 验证 Session ID 格式（防止注入攻击）
  if (!/^[a-zA-Z0-9\-_]+$/.test(sessionId)) {
    event.context.auth = {
      user: null,
      authenticated: false,
    }
    return
  }

  // 检查缓存
  const cached = userCache.get(sessionId)
  if (cached && cached.expires > Date.now()) {
    event.context.auth = {
      user: cached.user,
      authenticated: true,
      sessionId,
    }
    return
  }

  // 调用 BFF 的 /auth/me 接口（BFF 会转发 Cookie 到 auth-app-backend）
  try {
    const bffUrl = config.public.bffUrl || 'http://localhost:3030'
    const user = await $fetch(`${bffUrl}/api/v1/auth/me`, {
      headers: {
        cookie: `${sessionCookieName}=${sessionId}`, // 修正：直接设置 Cookie，不需要 "Cookie:" 前缀
        'X-Service-Call': 'true', // 获取 access_token
      },
      credentials: 'include', // 确保 Cookie 被发送
      timeout: 3000, // 3秒超时
      retry: 1, // 重试1次
    })

    // 更新缓存
    userCache.set(sessionId, {
      user,
      expires: Date.now() + CACHE_TTL,
    })

    // 定期清理过期缓存
    if (userCache.size > 1000) {
      const now = Date.now()
      for (const [key, value] of userCache.entries()) {
        if (value.expires < now) {
          userCache.delete(key)
        }
      }
    }

    // 注入到上下文
    event.context.auth = {
      user,
      authenticated: true,
      sessionId,
    }
  } catch (error: any) {
    // 区分错误类型
    if (error.statusCode === 401 || error.statusCode === 403) {
      // 认证失败：Cookie 无效或过期
      event.context.auth = {
        user: null,
        authenticated: false,
      }
    } else {
      // 网络错误或其他错误：记录日志，但不影响页面渲染
      console.error('[Auth Middleware] Failed to fetch user:', error)
      event.context.auth = {
        user: null,
        authenticated: false,
      }
    }
  }
}) satisfies EventHandler
```

---

## 八、测试清单

### 6.1 功能测试

- [ ] OAuth 登录：用户名密码登录成功，设置 Cookie
- [ ] `/auth/me`：Cookie 认证返回用户信息
- [ ] `/auth/me`：Bearer Token 认证返回用户信息（兼容）
- [ ] `/auth/me`：服务端调用（`X-Service-Call: true`）返回 access_token
- [ ] `/auth/token`：获取服务间调用 Token
- [ ] Session 滑动续期：剩余时间 < 1天时自动续期
- [ ] Access Token 自动刷新：过期时自动生成新的
- [ ] 登出：删除 Session，清除 Cookie
- [ ] 跨子域 SSO：在一个应用登录，访问另一个无需重登

### 6.2 性能测试

- [ ] Redis 延迟：P95 < 5ms
- [ ] `/auth/me` 延迟：P95 < 200ms
- [ ] 并发登录：支持 100+ 并发
- [ ] Session 创建速率：监控异常

### 6.3 安全测试

- [ ] Cookie HttpOnly：前端无法读取
- [ ] Cookie Secure：HTTPS only
- [ ] Session ID 格式验证：防止注入攻击
- [ ] Token 黑名单：撤销后立即失效
- [ ] 跨域 Cookie：只在同域下共享

---

## 九、监控指标

### 7.1 关键指标

- **可用性**：认证接口 99.9% 可用性
- **延迟**：`/auth/me` P95 < 200ms
- **错误率**：4xx < 1%, 5xx < 0.1%
- **Redis**：连接数 < 80%, 内存 < 80%, 延迟 P95 < 5ms
- **业务指标**：登录成功率 > 95%

### 7.2 告警阈值

- **P0（紧急）**：5xx 错误率 > 5%，Redis 完全不可用
- **P1（高优先级）**：延迟 P95 > 1000ms，认证失败率激增 > 50%
- **P2（中优先级）**：延迟 P95 > 500ms，Redis 资源使用 > 80%

---

## 十、调试和故障排查

### 8.1 调试工具

#### Redis 调试命令

```bash
# 连接 Redis
redis-cli -h <host> -p <port> -a <password>

# 查看所有 Session Key
KEYS auth:session:*

# 查看特定 Session
GET auth:session:<session_id>

# 查看用户的所有 Session
SMEMBERS auth:user_sessions:<user_id>

# 查看临时 Token
KEYS auth:magic:*
GET auth:magic:<token>

# 查看黑名单
KEYS auth:blacklist:*

# 查看 Key 的 TTL
TTL auth:session:<session_id>

# 删除测试数据
DEL auth:session:<session_id>
```

#### Cookie 调试

```javascript
// 浏览器控制台（注意：HttpOnly Cookie 无法通过 JavaScript 读取）
// 使用浏览器开发者工具 → Application → Cookies 查看

// 检查 Cookie 是否设置
document.cookie  // HttpOnly Cookie 不会出现在这里（这是正常的）

// 使用 curl 测试
curl -v -X POST http://localhost:3030/api/v1/login/oauth \
  -H "Content-Type: application/json" \
  -d '{"username":"user@example.com","password":"password"}' \
  -c cookies.txt

// 使用保存的 Cookie 调用
curl -v -X GET http://localhost:3030/api/v1/auth/me \
  -b cookies.txt
```

#### 日志调试

```typescript
// 在关键位置添加日志
this.logger.debug(`Session ID: ${sessionId}`);
this.logger.debug(`User ID: ${userId}`);
this.logger.debug(`Cookie Name: ${cookieName}`);

// 检查 Redis 连接
this.logger.log(`Redis connected: ${await this.redisService.getClient().ping()}`);
```

### 8.2 常见问题排查

#### 问题 1：登录后 Cookie 未设置

**排查步骤**：
1. 检查响应头中是否有 `Set-Cookie`
   ```bash
   curl -v -X POST http://localhost:3030/api/v1/login/oauth \
     -H "Content-Type: application/json" \
     -d '{"username":"user@example.com","password":"password"}'
   ```
2. 检查 Cookie 配置是否正确
   - `AUTH_COOKIE_DOMAIN` 是否正确
   - `AUTH_COOKIE_SECURE` 在 HTTP 环境下是否为 `false`
3. 检查 Ingress/Traefik 是否改写了 Set-Cookie
   - 查看 Ingress 配置
   - 检查代理日志

**解决方案**：
- 开发环境：设置 `AUTH_COOKIE_SECURE=false`
- 生产环境：确保使用 HTTPS
- 检查 Ingress 配置，确保不改写 Set-Cookie

#### 问题 2：Session 在 Redis 中找不到

**排查步骤**：
1. 检查 Redis 连接
   ```bash
   redis-cli ping
   ```
2. 检查 Session Key 是否正确
   ```bash
   redis-cli KEYS auth:session:*
   ```
3. 检查 Session 是否过期
   ```bash
   redis-cli TTL auth:session:<session_id>
   ```
4. 检查日志中是否有错误

**解决方案**：
- 检查 Redis 连接配置
- 检查 Session TTL 设置
- 检查 Session ID 是否正确传递

#### 问题 3：跨子域 Cookie 不共享

**排查步骤**：
1. 检查 Cookie Domain 配置
   ```bash
   # 应该是 .sunmoonai.com（注意前面的点）
   AUTH_COOKIE_DOMAIN=.sunmoonai.com
   ```
2. 检查浏览器 Cookie 设置
   - 开发者工具 → Application → Cookies
   - 查看 Domain 列
3. 检查 SameSite 设置
   - `SameSite=Lax` 应该足够（SSR 场景）

**解决方案**：
- 确保 Cookie Domain 设置为 `.sunmoonai.com`（带点）
- 确保所有子应用在同一顶级域名下
- 检查 SameSite 配置

#### 问题 4：`/auth/me` 返回 401

**排查步骤**：
1. 检查 Cookie 是否发送
   ```bash
   curl -v -X GET http://localhost:3030/api/v1/auth/me \
     -H "Cookie: sunmoonai_session=<session_id>"
   ```
2. 检查 Session 是否存在
   ```bash
   redis-cli GET auth:session:<session_id>
   ```
3. 检查 Session 是否过期
   ```bash
   redis-cli TTL auth:session:<session_id>
   ```
4. 检查日志中的错误信息

**解决方案**：
- 确保 Cookie 正确发送
- 检查 Session 是否过期
- 检查 Session ID 格式是否正确

#### 问题 5：服务间调用获取不到 access_token

**排查步骤**：
1. 检查是否带了 `X-Service-Call: true` header
   ```bash
   curl -v -X GET http://localhost:3030/api/v1/auth/me \
     -H "Cookie: sunmoonai_session=<session_id>" \
     -H "X-Service-Call: true"
   ```
2. 检查响应中是否包含 `access_token`
3. 检查 Session 中的 `access_token` 是否过期

**解决方案**：
- 确保请求中带了 `X-Service-Call: true` header
- 检查 access_token 自动刷新逻辑
- 使用 `/auth/token` 接口获取 Token

### 8.3 性能问题排查

#### Redis 延迟高

**排查步骤**：
1. 检查 Redis 连接数
   ```bash
   redis-cli INFO clients
   ```
2. 检查 Redis 内存使用
   ```bash
   redis-cli INFO memory
   ```
3. 检查慢查询
   ```bash
   redis-cli SLOWLOG GET 10
   ```

**解决方案**：
- 增加 Redis 连接池大小
- 优化 Redis Key 设计
- 考虑使用 Redis 集群

#### `/auth/me` 延迟高

**排查步骤**：
1. 检查 Redis 延迟
2. 检查数据库查询（如果从数据库获取用户信息）
3. 检查日志中的慢查询

**解决方案**：
- 优化 Redis 查询
- 使用缓存（如 SSR 中间件中的 5 秒缓存）
- 优化数据库查询

---

## 十一、部署检查清单

### 9.1 开发环境部署

- [ ] Redis 已部署并运行
- [ ] 环境变量已配置（`.env` 文件）
- [ ] Cookie Secure 设置为 `false`（HTTP 环境）
- [ ] Redis 连接测试通过
- [ ] 登录功能测试通过
- [ ] `/auth/me` 接口测试通过

### 9.2 生产环境部署

#### 基础设施
- [ ] Redis 已部署（单实例或集群）
- [ ] Redis 密码已配置
- [ ] Redis 监控已配置
- [ ] Redis 备份策略已配置

#### 应用配置
- [ ] 所有环境变量已配置（ConfigMap/Secret）
- [ ] Cookie Secure 设置为 `true`（HTTPS）
- [ ] Cookie Domain 设置为 `.sunmoonai.com`
- [ ] Session TTL 已配置（7天）
- [ ] Access Token TTL 已配置（15分钟）

#### Ingress/网关
- [ ] HTTPS 已启用
- [ ] Cookie Domain 配置正确
- [ ] Set-Cookie 不被代理改写
- [ ] CORS 配置正确（如需要）

#### 监控和告警
- [ ] Redis 监控已配置
- [ ] 认证接口监控已配置
- [ ] 告警阈值已设置
- [ ] 日志聚合已配置

#### 测试验证
- [ ] 登录功能测试通过
- [ ] `/auth/me` 接口测试通过
- [ ] 跨子域 SSO 测试通过
- [ ] 登出功能测试通过
- [ ] 性能测试通过

---

## 十二、架构师审查要点（关键）

### 10.1 必须完成的配置（否则无法运行）

1. ✅ **cookie-parser 中间件**：必须在 `main.ts` 中配置（见 5.12）
2. ✅ **模块注册**：`RedisService` 和 `SessionStorageService` 必须在 `AuthModule` 中注册（见 5.13）
3. ✅ **方法实现**：`mapSessionToUserProfile` 方法必须实现（见 5.14）
4. ✅ **依赖注入**：`createSession` 方法需要注入 `SessionStorageService` 和 `ConfigService`（见 5.16）
5. ✅ **Controller 注入**：`/auth/me` 接口需要注入 `SessionStorageService`（见 5.17）

### 10.2 关键依赖关系

```
AuthModule
  ├── RedisService (必须注册)
  ├── SessionStorageService (依赖 RedisService，必须注册)
  ├── TokenStorageService (依赖 RedisService，需要重构)
  └── AuthService (依赖 SessionStorageService)
      └── AuthController (依赖 AuthService 和 SessionStorageService)
```

### 10.3 实施顺序（必须遵守）

1. **阶段 1**：基础设施准备
   - 安装依赖
   - 配置 cookie-parser（5.12）
   - 创建 RedisService（5.1）
   - 创建 SessionStorageService（5.3）
   - 注册到 AuthModule（5.13）

2. **阶段 2**：核心实现
   - 实现 `createSession` 方法（5.5）
   - 实现 `mapSessionToUserProfile` 方法（5.14）
   - 改造登录接口（5.6）
   - 改造 `/auth/me` 接口（5.7、5.17）

3. **阶段 3-4**：BFF 和 SSR 适配
   - 按照指南实施

### 10.4 生产环境关键风险点（必须确认）

#### ⚠️ 风险 1：AUTH_COOKIE_SECURE 在环境切换时必炸一次

**问题**：登录成功，但浏览器死活没有 Cookie

**原因**：`AUTH_COOKIE_SECURE=true` 时，HTTP 环境下浏览器会拒绝设置 Cookie

**解决方案**：使用 `NODE_ENV` 自动切换，不要人工记忆

```typescript
// src/main.ts 或配置服务中
const isProduction = process.env.NODE_ENV === 'production';
const isHttps = process.env.AUTH_COOKIE_SECURE === 'true' || isProduction;

// 自动设置
AUTH_COOKIE_SECURE = isHttps ? 'true' : 'false';
```

**环境配置表**：

| 环境 | NODE_ENV | AUTH_COOKIE_SECURE | 必须值 |
|------|----------|-------------------|--------|
| 本地 / HTTP | development | false | false |
| 生产 / HTTPS | production | true | true |

#### ⚠️ 风险 2：Redis Session = 单点风险（默认单实例）

**问题**：Redis 重启 = 全员登出

**解决方案**：上线建议至少做到 Redis Sentinel 或 Redis Cluster（哪怕 3 节点）

```typescript
// Redis 配置支持集群
const client = new Redis({
  host: this.configService.get<string>('REDIS_HOST', 'localhost'),
  port: this.configService.get<number>('REDIS_PORT', 6379),
  // 支持 Sentinel
  sentinels: [
    { host: 'sentinel1', port: 26379 },
    { host: 'sentinel2', port: 26379 },
    { host: 'sentinel3', port: 26379 },
  ],
  name: 'mymaster',
  // 或支持 Cluster
  // cluster: true,
  // nodes: [
  //   { host: 'redis1', port: 6379 },
  //   { host: 'redis2', port: 6379 },
  //   { host: 'redis3', port: 6379 },
  // ],
});
```

**上线检查清单**：
- [ ] Redis Sentinel 已配置（推荐）
- [ ] 或 Redis Cluster 已配置（3节点以上）
- [ ] Redis 监控和告警已配置
- [ ] Redis 持久化策略已配置（RDB + AOF）

#### ⚠️ 风险 3：user_sessions Set 会无限增长（长期）

**问题**：用户 30 天内登录 200 次，Session 自动过期但 Set 未清理干净

**解决方案**：定期清理策略 - 每次 `getUserSessions` 校验对应 session key 是否还存在

```typescript
// src/common/services/session-storage.service.ts
async getUserSessions(userId: number): Promise<string[]> {
  const key = RedisKeyBuilder.userSessions(userId);
  const sessionIds = await this.redisService.smembers(key);
  
  // 清理策略：校验每个 session 是否还存在
  const validSessionIds: string[] = [];
  for (const sessionId of sessionIds) {
    const sessionKey = RedisKeyBuilder.session(sessionId);
    const exists = await this.redisService.exists(sessionKey);
    if (exists) {
      validSessionIds.push(sessionId);
    } else {
      // Session 已过期，从 Set 中移除
      await this.redisService.srem(key, sessionId);
      this.logger.debug(`Cleaned expired session from user_sessions: ${sessionId}`);
    }
  }
  
  return validSessionIds;
}
```

**优化建议**：
- 每次 `getUserSessions` 时自动清理
- 或定期任务（每天凌晨）批量清理所有用户的过期 Session

#### ⚠️ 风险 4：Session ID 正则略微偏松

**问题**：当前正则 `/^[a-zA-Z0-9\-_]+$/` 对 UUID v4 来说偏松

**解决方案**：使用更严格的正则，安全审计更好过

```typescript
// 如果使用 uuidv4()，格式：xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
// 更严格的正则
const SESSION_ID_REGEX = /^[0-9a-fA-F-]{36}$/;

// 在 /auth/me 接口中
if (!SESSION_ID_REGEX.test(sessionId)) {
  throw new UnauthorizedException('Invalid session ID format');
}
```

**UUID v4 格式验证**：
- 长度：36 字符（32 个十六进制字符 + 4 个连字符）
- 字符集：`0-9a-fA-F-`
- 位置：第 14 位必须是 `4`，第 19 位必须是 `8`、`9`、`a` 或 `b`

**更严格的验证（可选）**：
```typescript
function isValidUuidV4(sessionId: string): boolean {
  const uuidV4Regex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidV4Regex.test(sessionId);
}
```

#### ⚠️ 风险 5：/auth/token 是"敏感接口"

**问题**：一旦 XSS（极端情况），攻击者可通过 Cookie 换 token

**解决方案**：仅允许 BFF / 内网 IP 或校验 `X-Service-Call`

```typescript
@Get('auth/token')
async getServiceToken(@Req() req: Request): Promise<{ access_token: string }> {
  // 1. 必须带 X-Service-Call header
  const isServiceCall = req.headers['x-service-call'] === 'true';
  if (!isServiceCall) {
    throw new ForbiddenException('This endpoint is only available for service-to-service calls');
  }

  // 2. 可选：校验内网 IP（生产环境推荐）
  const clientIp = req.ip || req.headers['x-forwarded-for']?.toString().split(',')[0];
  const allowedIps = this.configService.get<string[]>('AUTH_INTERNAL_IPS', []);
  if (allowedIps.length > 0 && !allowedIps.includes(clientIp)) {
    throw new ForbiddenException('Access denied: IP not in allowed list');
  }

  // 3. 继续原有逻辑
  const cookieName = this.configService.get<string>('SESSION_COOKIE_NAME', 'sunmoonai_session');
  const sessionId = req.cookies[cookieName];
  
  if (!sessionId) {
    throw new UnauthorizedException('No session found');
  }

  const session = await this.sessionStorageService.getSession(sessionId);
  if (!session) {
    throw new UnauthorizedException('Session expired');
  }

  // ... 返回 access_token
}
```

**配置示例**：
```bash
# 允许的内网 IP（可选，生产环境推荐）
AUTH_INTERNAL_IPS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

#### ⚠️ 风险 6：滑动续期策略要注意"抖动"

**问题**：Redis SETEX QPS 是否抖动，`/auth/me` 高峰期是否触发大量写操作

**解决方案**：优化滑动续期逻辑，减少不必要的写操作

```typescript
// 优化后的滑动续期逻辑
async getSession(sessionId: string): Promise<Session | null> {
  const key = RedisKeyBuilder.session(sessionId);
  const sessionJson = await this.redisService.get(key);
  
  if (!sessionJson) {
    return null;
  }

  try {
    const session: Session = JSON.parse(sessionJson);
    const now = Date.now() / 1000;
    
    // 检查是否过期
    if (session.expires_at < now) {
      await this.deleteSession(sessionId);
      return null;
    }

    // 优化：只在必要时更新（减少写操作）
    const remaining = session.expires_at - now;
    const slideThreshold = this.configService.get<number>('SESSION_SLIDE_RENEWAL_THRESHOLD', 86400);
    const lastActivityDiff = now - session.last_activity;
    
    // 条件1：剩余时间 < 阈值
    // 条件2：距离上次活动 > 1小时（避免频繁更新）
    // 条件3：距离上次更新 > 5分钟（避免抖动）
    const shouldRenew = remaining < slideThreshold && 
                       lastActivityDiff > 3600 &&
                       (now - session.updated_at) > 300; // 新增：5分钟冷却期
    
    if (shouldRenew) {
      session.expires_at = now + this.sessionTtl;
      session.last_activity = now;
      session.updated_at = now;
      await this.redisService.set(key, JSON.stringify(session), this.sessionTtl);
      this.logger.debug(`Session renewed: ${sessionId}`);
    } else {
      // 只更新 last_activity，不更新 expires_at（减少写操作）
      session.last_activity = now;
      // 注意：这里不写回 Redis，只在内存中更新
      // 或者：使用 EXPIRE 命令只更新 TTL，不重写整个 Session
      await this.redisService.expire(key, Math.ceil(remaining));
    }

    return session;
  } catch (error) {
    this.logger.error(`Failed to parse session ${sessionId}:`, error);
    return null;
  }
}
```

**监控建议**：
- 监控 Redis SETEX QPS
- 监控 `/auth/me` 接口的写操作比例
- 设置告警：写操作比例 > 10%

### 10.5 常见陷阱

1. ❌ **忘记配置 cookie-parser**：导致无法读取 Cookie
2. ❌ **忘记注册服务**：导致依赖注入失败
3. ❌ **Cookie 格式错误**：SSR 中间件中 Cookie 格式不正确（已修正）
4. ❌ **Response 对象处理**：使用 `@Res({ passthrough: false })` 时注意返回值
5. ❌ **Session ID 验证缺失**：未验证 Session ID 格式，存在安全风险
6. ❌ **AUTH_COOKIE_SECURE 配置错误**：环境切换时必炸一次（见风险 1）
7. ❌ **Redis 单点故障**：未配置 Sentinel/Cluster（见风险 2）
8. ❌ **user_sessions 无限增长**：未清理过期 Session（见风险 3）

### 10.6 高级优化建议（大厂级，可选但推荐）

#### ⭐ 1. Session 并发踢出（设备管理）

**功能**：支持"只允许一个设备登录"或"下线其他设备"

**实现**：利用现有的 `auth:user_sessions:{user_id}` Set

```typescript
// 踢出用户的其他设备（保留当前设备）
async kickOtherDevices(userId: number, currentSessionId: string): Promise<void> {
  const sessionIds = await this.getUserSessions(userId);
  for (const sessionId of sessionIds) {
    if (sessionId !== currentSessionId) {
      await this.deleteSession(sessionId);
    }
  }
}

// 限制设备数量（例如：最多 5 个设备）
async limitDeviceCount(userId: number, maxDevices: number = 5): Promise<void> {
  const sessionIds = await this.getUserSessions(userId);
  if (sessionIds.length >= maxDevices) {
    // 删除最旧的 Session（按 created_at 排序）
    const sessions = await Promise.all(
      sessionIds.map(async (id) => {
        const session = await this.getSession(id);
        return { id, created_at: session?.created_at || 0 };
      })
    );
    sessions.sort((a, b) => a.created_at - b.created_at);
    
    // 删除最旧的
    const toDelete = sessions.slice(0, sessions.length - maxDevices + 1);
    for (const { id } of toDelete) {
      await this.deleteSession(id);
    }
  }
}
```

**使用场景**：
- 用户修改密码后，踢出所有其他设备
- 管理员强制下线用户
- 限制用户同时登录的设备数量

#### ⭐ 2. Session Version（防权限缓存不一致）

**功能**：当用户角色变更时，老 Session 自动失效

**实现**：在 Session 中添加 `permission_version`

```typescript
interface Session {
  // ... 其他字段
  permission_version: number; // 新增
}

// 创建 Session 时
const session: Session = {
  // ... 其他字段
  permission_version: user.permission_version || 1,
};

// 获取 Session 时校验
async getSession(sessionId: string): Promise<Session | null> {
  const session = await this.getSessionFromRedis(sessionId);
  if (!session) {
    return null;
  }

  // 校验权限版本（从 user-service 获取最新版本）
  const user = await this.userService.findById({ id: session.user_id });
  if (user.permission_version !== session.permission_version) {
    // 权限已变更，删除旧 Session
    await this.deleteSession(sessionId);
    return null;
  }

  return session;
}

// 用户角色变更时，增加版本号
async updateUserPermissionVersion(userId: number): Promise<void> {
  // 在 user-service 中更新 permission_version
  await this.userService.updatePermissionVersion({ id: userId });
  
  // 可选：立即踢出所有旧 Session
  await this.deleteUserSessions(userId);
}
```

#### ⭐ 3. 登录风控 Hook（预留）

**功能**：异地登录检测、异常设备拦截

**实现**：利用现有的 `client_ip` 和 `user_agent`

```typescript
interface Session {
  // ... 其他字段
  client_ip?: string;
  user_agent?: string;
  login_location?: string; // 新增：登录地点
  device_fingerprint?: string; // 新增：设备指纹
}

// 登录时记录
async createSession(user: User, res: Response, req?: Request): Promise<Session> {
  const session: Session = {
    // ... 其他字段
    client_ip: req?.ip,
    user_agent: req?.headers['user-agent'],
    login_location: await this.getLocationFromIp(req?.ip), // 可选：IP 地理位置
    device_fingerprint: this.generateDeviceFingerprint(req), // 可选：设备指纹
  };
  
  // 风控检查（可选）
  const riskLevel = await this.checkLoginRisk(user.id, session);
  if (riskLevel === 'high') {
    // 高风险：要求二次验证
    throw new ForbiddenException('Login requires additional verification');
  }
  
  // ... 创建 Session
}

// 风控检查（示例）
async checkLoginRisk(userId: number, session: Session): Promise<'low' | 'medium' | 'high'> {
  // 1. 检查异地登录
  const lastSession = await this.getLastSession(userId);
  if (lastSession && lastSession.client_ip !== session.client_ip) {
    // 异地登录：检查是否在允许的地理位置范围内
    const distance = this.calculateDistance(lastSession.login_location, session.login_location);
    if (distance > 1000) { // 超过 1000km
      return 'high';
    }
  }

  // 2. 检查异常设备
  const deviceHistory = await this.getUserDeviceHistory(userId);
  if (!deviceHistory.includes(session.device_fingerprint)) {
    // 新设备：要求验证
    return 'medium';
  }

  return 'low';
}
```

#### ⭐ 4. 灰度开关（快速回滚）

**功能**：允许某些用户仍走旧 JWT，快速回滚

**实现**：环境变量控制

```typescript
// 环境变量
AUTH_SESSION_ENABLED=true  # 是否启用 Session 认证
AUTH_SESSION_USER_IDS=1,2,3  # 指定用户 ID 使用 Session（可选）

// /auth/me 接口
@Get('auth/me')
async getCurrentUser(@Req() req: Request): Promise<UserProfileDto | UserProfileWithTokenDto> {
  const sessionEnabled = this.configService.get<string>('AUTH_SESSION_ENABLED', 'true') !== 'false';
  
  // 1. 如果 Session 未启用，直接走 JWT
  if (!sessionEnabled) {
    return this.getUserFromToken(req);
  }

  // 2. 如果指定了用户 ID，检查是否在列表中
  const allowedUserIds = this.configService.get<string>('AUTH_SESSION_USER_IDS', '');
  if (allowedUserIds) {
    const userIds = allowedUserIds.split(',').map(id => parseInt(id, 10));
    // 先尝试 Session，如果失败再走 JWT
    try {
      const session = await this.getSessionFromCookie(req);
      if (session && userIds.includes(session.user_id)) {
        return this.mapSessionToUserProfile(session);
      }
    } catch (error) {
      // Session 失败，回退到 JWT
    }
  }

  // 3. 正常流程：Cookie 优先 → Token fallback
  // ... 原有逻辑
}
```

**使用场景**：
- 灰度发布：先让部分用户使用 Session 认证
- 快速回滚：发现问题时，立即切回 JWT
- A/B 测试：对比两种认证方式的性能

### 10.7 测试检查点

- [ ] Redis 连接正常
- [ ] Cookie 可以正确读取
- [ ] Session 可以正确创建和获取
- [ ] `/auth/me` 接口 Cookie 认证正常
- [ ] `/auth/me` 接口 Bearer Token 认证正常（兼容）
- [ ] 跨子域 Cookie 共享正常
- [ ] **AUTH_COOKIE_SECURE 配置正确**（环境切换测试）
- [ ] **Redis 高可用已配置**（Sentinel/Cluster）
- [ ] **user_sessions 清理策略已实现**
- [ ] **Session ID 正则验证通过**
- [ ] **/auth/token 接口安全校验通过**
- [ ] **滑动续期抖动监控已配置**

---

## 十一、常见问题

### Q1: 如何启用其他登录方式？

**A**: 修改环境变量：
```bash
AUTH_LOGIN_MAGIC_LINK_ENABLED=true
AUTH_LOGIN_TOTP_ENABLED=true
```

### Q2: Redis 不可用怎么办？

**A**: 
1. 快速失败（超时 100ms）
2. 本地短 TTL 缓存（session_id→user）
3. 回退 JWT 路径（`AUTH_SESSION_ENABLED=false`）

### Q3: Cookie 设置失败怎么办？

**A**: 
1. 检查 Ingress/Traefik 配置（确保不改写 Set-Cookie）
2. 检查 Cookie Domain 配置
3. 抓包验证 Set-Cookie header

### Q4: 如何验证 Session 是否正常工作？

**A**: 
1. 登录后检查 Cookie 是否设置
2. 调用 `/auth/me` 验证返回用户信息
3. 检查 Redis 中是否有 Session 数据
4. 验证跨子域 Cookie 共享

### Q5: 如何调试跨子域问题？

**A**:
1. 检查 Cookie Domain 是否为 `.sunmoonai.com`（带点）
2. 检查浏览器 Cookie 设置（开发者工具）
3. 检查 SameSite 配置（应该是 `Lax`）
4. 使用 curl 测试不同子域

### Q6: Session 过期时间如何调整？

**A**: 修改环境变量：
```bash
SESSION_TTL_SECONDS=604800  # 7天（秒）
SESSION_SLIDE_RENEWAL_THRESHOLD=86400  # 1天（秒）
```

### Q7: 如何查看用户的活跃 Session？

**A**: 使用 Redis 命令：
```bash
# 查看用户的所有 Session
SMEMBERS auth:user_sessions:<user_id>

# 查看每个 Session 的详情
GET auth:session:<session_id>
```

### Q8: 如何踢出用户的所有设备？

**A**: 实现 `deleteUserSessions` 方法：
```typescript
await this.sessionStorageService.deleteUserSessions(userId);
```

### Q9: Session + Cookie 改造会影响 gRPC 调用吗？

**A**: **不会影响**。gRPC 调用是用于获取用户数据的（`user-service`），与认证方式无关。

**说明**：
- **gRPC 调用**：`auth-app-backend` → `user-service`（服务间通信，获取用户数据）
- **Session + Cookie**：浏览器 → `auth-app-backend`（认证方式）

**影响分析**：
- ✅ **gRPC 调用保持不变**：`userService.findOne()`, `userService.findById()` 等调用无需修改
- ✅ **性能优化**：Cookie 认证路径从 Session 获取用户信息，减少 gRPC 调用
- ✅ **功能正常**：所有用户数据获取功能完全正常

**代码示例**：
```typescript
// 登录时：仍然通过 gRPC 获取用户数据
const user = await this.userService.findOne({ username }); // gRPC 调用（不受影响）

// 认证时：优先从 Session 获取（无需 gRPC 调用）
const session = await this.getSession(sessionId); // 从 Redis 获取（性能更好）
// 如果 Session 中有用户信息，就不需要 gRPC 调用
```

---

## 十三、参考文档

- **主提案文档**：`session-based-auth-proposal.md`（包含所有确认的决策）
- **详细设计**：`auth-refactoring-plan-part3.md`（数据结构、接口契约）
- **任务清单**：`auth-refactoring-plan-part2.md`（分阶段任务）
- **调用场景**：`auth-service-call-scenarios-analysis.md`（各场景调用方式）

---

## 十二、开发工作流

### 11.1 本地开发环境设置

#### 1. 启动 Redis

```bash
# 使用 Docker
docker run -d \
  --name redis-auth \
  -p 6379:6379 \
  redis:7-alpine \
  redis-server --requirepass your_password

# 或使用本地 Redis
redis-server --port 6379 --requirepass your_password
```

#### 2. 配置环境变量

创建 `.env` 文件：
```bash
# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=your_password

# Session
SESSION_COOKIE_NAME=sunmoonai_session
SESSION_TTL_SECONDS=604800
SESSION_SLIDE_RENEWAL_THRESHOLD=86400

# Cookie
AUTH_COOKIE_DOMAIN=.localhost  # 本地开发
AUTH_COOKIE_SAMESITE=Lax
AUTH_COOKIE_SECURE=false  # 本地开发允许 HTTP

# JWT
JWT_SECRET=your_secret_key
ACCESS_TOKEN_EXPIRES_IN=15m

# 登录方式
AUTH_LOGIN_OAUTH_ENABLED=true
AUTH_LOGIN_MAGIC_LINK_ENABLED=false
AUTH_LOGIN_TOTP_ENABLED=false
```

#### 3. 安装依赖

```bash
cd auth-app-backend
npm install ioredis @types/ioredis cookie-parser @types/cookie-parser
```

#### 4. 启动服务

```bash
npm run start:dev
```

### 11.2 开发流程

#### 步骤 1：实现 Redis 服务

1. 创建 `src/common/services/redis.service.ts`
2. 实现基础 Redis 操作（get/set/del）
3. 添加连接管理和错误处理
4. 编写单元测试

#### 步骤 2：实现 Session 存储服务

1. 创建 `src/common/services/session-storage.service.ts`
2. 实现 Session CRUD 操作
3. 实现滑动续期逻辑
4. 实现用户 Session 映射
5. 编写单元测试

#### 步骤 3：重构 Token 存储服务

1. 修改 `src/common/services/token-storage.service.ts`
2. 将内存存储改为 Redis 存储
3. 使用 `RedisKeyBuilder` 生成 Key
4. 编写单元测试

#### 步骤 4：实现统一 Session 创建方法

1. 在 `auth.service.ts` 中添加 `createSession()` 方法
2. 实现 Session 数据结构和 Cookie 设置
3. 测试 Session 创建

#### 步骤 5：改造登录接口

1. 修改 `loginWithOauth()` 方法
2. 调用 `createSession()` 方法
3. 移除返回 Token 的逻辑
4. 编写集成测试

#### 步骤 6：改造 `/auth/me` 接口

1. 实现 Cookie 认证（优先）
2. 实现 Bearer Token 认证（兼容）
3. 实现 `X-Service-Call` header 处理
4. 实现 access_token 自动刷新
5. 编写集成测试

#### 步骤 7：实现其他接口

1. `/auth/token` 接口
2. `/auth/logout` 接口
3. 删除兼容代码
4. 编写集成测试

### 11.3 测试流程

#### 单元测试

```typescript
// session-storage.service.spec.ts
describe('SessionStorageService', () => {
  it('should create session', async () => {
    const session = { ... };
    await service.setSession(sessionId, session);
    const result = await service.getSession(sessionId);
    expect(result).toEqual(session);
  });

  it('should slide renew session', async () => {
    // 测试滑动续期逻辑
  });
});
```

#### 集成测试

```typescript
// auth.e2e-spec.ts
describe('Auth (e2e)', () => {
  it('should login and set cookie', async () => {
    const response = await request(app.getHttpServer())
      .post('/api/v1/login/oauth')
      .send({ username: 'user@example.com', password: 'password' });
    
    expect(response.headers['set-cookie']).toBeDefined();
    expect(response.body).not.toHaveProperty('access_token');
  });

  it('should get user info with cookie', async () => {
    // 先登录获取 Cookie
    const loginResponse = await request(app.getHttpServer())
      .post('/api/v1/login/oauth')
      .send({ username: 'user@example.com', password: 'password' });
    
    const cookies = loginResponse.headers['set-cookie'];
    
    // 使用 Cookie 调用 /auth/me
    const meResponse = await request(app.getHttpServer())
      .get('/api/v1/auth/me')
      .set('Cookie', cookies);
    
    expect(meResponse.status).toBe(200);
    expect(meResponse.body).toHaveProperty('id');
  });
});
```

---

## 十三、代码审查要点

### 12.1 安全审查

- [ ] **Session ID 格式验证**：是否验证 Session ID 格式（防止注入攻击）
- [ ] **Cookie 安全属性**：HttpOnly、Secure、SameSite 是否正确设置
- [ ] **敏感信息**：日志中不包含密码、完整 Token
- [ ] **Token 黑名单**：撤销的 Token 是否正确加入黑名单
- [ ] **输入验证**：所有用户输入是否经过验证

### 12.2 代码质量

- [ ] **统一方法**：所有登录方式是否使用 `createSession()` 方法
- [ ] **Key 生成**：是否使用 `RedisKeyBuilder` 生成 Redis Key
- [ ] **错误处理**：是否有完善的错误处理逻辑
- [ ] **日志规范**：是否使用结构化日志
- [ ] **类型安全**：是否使用 TypeScript 类型定义

### 12.3 性能审查

- [ ] **Redis 连接**：是否使用连接池
- [ ] **超时设置**：Redis 操作是否有超时设置
- [ ] **缓存策略**：是否合理使用缓存（如 SSR 中间件）
- [ ] **批量操作**：是否避免 N+1 查询

### 12.4 测试覆盖

- [ ] **单元测试**：核心逻辑是否有单元测试
- [ ] **集成测试**：关键流程是否有集成测试
- [ ] **边界情况**：是否测试边界情况（过期、无效等）
- [ ] **错误场景**：是否测试错误场景（Redis 不可用等）

---

## 十四、性能优化建议

### 13.1 Redis 优化

#### 连接池配置

```typescript
const client = new Redis({
  // ... 其他配置
  maxRetriesPerRequest: 3,
  retryStrategy: (times) => Math.min(times * 50, 2000),
  enableReadyCheck: true,
  enableOfflineQueue: false, // 离线时不排队
});
```

#### 批量操作

```typescript
// 使用 Pipeline 批量操作
const pipeline = this.redisService.getClient().pipeline();
pipeline.set(key1, value1);
pipeline.set(key2, value2);
pipeline.expire(key1, ttl);
await pipeline.exec();
```

#### 本地缓存

```typescript
// 短时间本地缓存（减少 Redis 调用）
const localCache = new Map<string, { data: any; expires: number }>();
const CACHE_TTL = 5000; // 5秒

async getSessionWithCache(sessionId: string): Promise<Session | null> {
  const cached = localCache.get(sessionId);
  if (cached && cached.expires > Date.now()) {
    return cached.data;
  }
  
  const session = await this.getSession(sessionId);
  if (session) {
    localCache.set(sessionId, {
      data: session,
      expires: Date.now() + CACHE_TTL,
    });
  }
  
  return session;
}
```

### 13.2 接口优化

#### 减少数据库查询

```typescript
// 优先从 Session 获取用户信息，避免查询数据库
const session = await this.getSession(sessionId);
if (session) {
  return this.mapSessionToUserProfile(session); // 不需要查询数据库
}
```

#### 异步并发处理

```typescript
// 并行处理多个操作
const [session, blacklist] = await Promise.all([
  this.getSession(sessionId),
  this.isBlacklisted(token),
]);
```

### 13.3 监控优化

#### 关键路径埋点

```typescript
const startTime = Date.now();
try {
  const session = await this.getSession(sessionId);
  const duration = Date.now() - startTime;
  
  // 记录慢查询
  if (duration > 100) {
    this.logger.warn({
      event: 'session.slow_query',
      session_id: sessionId,
      duration_ms: duration,
    });
  }
} catch (error) {
  // 记录错误
  this.logger.error({
    event: 'session.error',
    session_id: sessionId,
    error: error.message,
  });
}
```

---

## 十五、安全最佳实践

### 14.1 Session 安全

- ✅ **Session ID 随机性**：使用 UUID v4 生成 Session ID
- ✅ **Session ID 格式验证**：验证格式，防止注入攻击
- ✅ **Session 过期**：设置合理的 TTL，支持滑动续期
- ✅ **Session 撤销**：支持立即删除 Session（登出、踢出）

### 14.2 Cookie 安全

- ✅ **HttpOnly**：防止 XSS 攻击
- ✅ **Secure**：生产环境强制 HTTPS
- ✅ **SameSite**：防止 CSRF 攻击
- ✅ **Domain**：限制 Cookie 作用域

### 14.3 Token 安全

- ✅ **短期过期**：Access Token 15分钟过期
- ✅ **自动刷新**：过期时自动刷新
- ✅ **黑名单机制**：支持 Token 撤销
- ✅ **不返回给浏览器**：浏览器不接收 Token

### 14.4 日志安全

- ✅ **脱敏处理**：不记录密码、完整 Token
- ✅ **Session ID 部分记录**：只记录前 8 位用于追踪
- ✅ **访问控制**：日志系统需要访问控制
- ✅ **加密传输**：日志传输使用 TLS

---

## 十六、开发注意事项

1. ✅ **统一使用 `createSession()` 方法**：所有登录方式最终都调用这个方法
2. ✅ **使用 `RedisKeyBuilder`**：统一生成 Redis Key，避免拼写错误
3. ✅ **配置开关控制**：登录方式通过环境变量控制，无需修改代码
4. ✅ **错误处理**：区分网络错误和认证错误，提供友好的错误提示
5. ✅ **日志规范**：不记录敏感信息（密码、完整 Token），使用结构化日志
6. ✅ **测试覆盖**：每个功能都要有单元测试和集成测试
7. ✅ **类型安全**：使用 TypeScript 类型定义，避免运行时错误
8. ✅ **性能考虑**：合理使用缓存，避免不必要的 Redis 调用
9. ✅ **安全第一**：验证所有输入，防止注入攻击
10. ✅ **可观测性**：关键操作都要有日志和监控
11. ✅ **gRPC 调用不受影响**：Session + Cookie 改造不影响现有的 gRPC 调用（user-service）
12. ✅ **性能优化**：Cookie 认证路径从 Session 获取用户信息，减少 gRPC 调用

---

## 十七、快速参考表

### 16.1 接口快速参考

| 接口 | 方法 | 认证 | 响应 | 说明 |
|------|------|------|------|------|
| `/api/v1/login/oauth` | POST | 无 | 用户信息 | 设置 Cookie |
| `/api/v1/auth/me` | GET | Cookie/Bearer | 用户信息（+ access_token） | 统一认证接口 |
| `/api/v1/auth/token` | GET | Cookie | `{ access_token }` | 获取服务间 Token |
| `/api/v1/auth/logout` | POST | Cookie | `{ message }` | 删除 Session |

### 16.2 Redis Key 快速参考

| 类型 | Key 格式 | 示例 |
|------|----------|------|
| Session | `auth:session:{id}` | `auth:session:abc-123` |
| 用户映射 | `auth:user_sessions:{uid}` | `auth:user_sessions:1` |
| 黑名单 | `auth:blacklist:{token}` | `auth:blacklist:jwt...` |
| 魔法链接 | `auth:magic:{token}` | `auth:magic:magic-123` |

### 16.3 配置项快速参考

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `SESSION_COOKIE_NAME` | `sunmoonai_session` | Cookie 名称 |
| `SESSION_TTL_SECONDS` | `604800` | Session TTL（7天） |
| `AUTH_COOKIE_DOMAIN` | `.sunmoonai.com` | Cookie Domain |
| `AUTH_COOKIE_SAMESITE` | `Lax` | SameSite 设置 |
| `ACCESS_TOKEN_EXPIRES_IN` | `15m` | Access Token TTL |

---

## 十八、参考文档

- **主提案文档**：`session-based-auth-proposal.md`（包含所有确认的决策）
- **详细设计**：`auth-refactoring-plan-part3.md`（数据结构、接口契约）
- **任务清单**：`auth-refactoring-plan-part2.md`（分阶段任务）
- **调用场景**：`auth-service-call-scenarios-analysis.md`（各场景调用方式）
- **兼容性分析**：`compatibility-analysis.md`（需要删除/重构的代码）
- **登录方式分析**：`login-methods-impact-analysis.md`（登录方式影响）

---

**最后更新**：2024-01-01  
**版本**：1.0  
**维护者**：开发团队

