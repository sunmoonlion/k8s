# Session 基于服务端认证方案提案

## 文档说明

**重要说明**：这是首次开发，采用全新的 Session + Cookie 方案，**不需要兼容旧的 JWT Token 机制**。

本文档基于 `auth-refactoring-plan-part1.md` 至 `part4.md` 和 `ssr_bff_auth_flow.md`，针对 `auth-app-bff` 实现服务端 Session（Redis）+ HttpOnly Cookie 机制，提出需要讨论和确认的关键问题。

**目标**：在开始实施前，明确所有技术决策和设计细节，避免实施过程中的返工。

**核心原则**：
- ✅ 浏览器只持有 HttpOnly Cookie（session_id）
- ✅ 服务端（Redis）存储完整的 Session 信息
- ✅ 所有认证通过 Cookie 进行，不返回 JWT Token 给客户端
- ❌ 不兼容 Bearer JWT Token 方式

**实施策略**：
- ✅ 认证和权限分开解决（先认证，后权限）
- ✅ Session 结构预留权限字段（`is_superuser`, `roles`），供后续 RBAC 系统使用
- ✅ Phase 1：完成认证改造，保持现有简单权限判断逻辑
- ✅ Phase 2：在 auth-app-bff 中实现完整的 RBAC 系统（不需要独立的权限管理服务）

---

## 一、Session 存储结构设计

### 问题 1.1：Session 存储结构

**方案**：Session 中存储用户信息、权限字段和 JWT Token（用于服务间调用）

**架构说明**：
- **浏览器 → SSR/BFF**：使用 Cookie（session_id）
- **SSR/BFF → auth-app-bff**：服务间调用，**肯定需要 JWT Token**
  - 场景 1：SSR 登录页面调用 auth-app-bff（服务间调用，没有 Cookie）
  - 场景 2：BFF 鉴权时调用 auth-app-bff（服务间调用，可以转发 Cookie 或使用 JWT Token）
- **BFF → 其他微服务**：服务间调用，**肯定需要 JWT Token**（用于验证用户身份）

**关键点**：
- ✅ 服务间调用**肯定需要** JWT Token（这是架构决定的）
- ✅ Session 中存储 JWT Token（`access_token`），供服务间调用使用
- ✅ SSR/BFF 可以通过 Cookie 获取 Session，然后使用 Session 中的 `access_token` 进行服务间调用

**Session 结构**（包含 JWT Token，用于服务间调用）：
```json
{
  "session_id": "uuid-string",
  "user_id": 1,
  "username": "admin@example.com",
  "email": "admin@example.com",
  "full_name": "Admin",
  "is_active": true,
  "is_superuser": true,              // 权限字段：当前使用，后续 RBAC 系统会扩展
  "email_validated": true,
  "roles": [                          // 权限字段：预留，供后续 RBAC 系统使用
    {
      "roleId": 1,
      "roleName": "admin",            // 后续扩展
      "permissions": []                // 后续扩展：权限列表
    }
  ],
  
  "access_token": "jwt-string",       // JWT Token：用于服务间调用
  "access_expires_at": 1710000000,   // Access Token 过期时间（15分钟）
  
  "created_at": 1710000000,
  "updated_at": 1710000000,
  "expires_at": 1710600000,          // Session 过期时间（7天）
  "last_activity": 1710000000,       // 最后活动时间（用于滑动续期）
  
  "client_ip": "192.168.1.1",        // 可选，用于安全审计
  "user_agent": "Mozilla/5.0..."     // 可选，用于安全审计
}
```

**说明**：
- ✅ Session 中存储 JWT Token（`access_token`），用于服务间调用
- ✅ SSR/BFF 调用 auth-app-bff 时，可以：
  - 方式 1：转发 Cookie（推荐，更简单）
  - 方式 2：使用 Session 中的 `access_token`（如果需要）
- ✅ BFF 调用其他微服务时，可以使用 Session 中的 `access_token`
- ✅ Session 中存储权限字段（`is_superuser`, `roles`），为后续 RBAC 系统预留
- ✅ Phase 1 阶段：保持现有简单权限判断逻辑（`is_superuser` 检查）
- ✅ Phase 2 阶段：在 auth-app-bff 中实现完整的 RBAC 系统，扩展 `roles` 结构

---

### 问题 1.2：Session TTL 策略

**方案**：
- **Session TTL**：7天（604800 秒）
- **滑动续期**：用户每次活动时，如果 Session 剩余时间 < 1天，则自动续期到 7天
- **过期策略**：Session 过期后，用户需要重新登录

**实现逻辑**：
```typescript
async function getSession(sessionId: string) {
  const session = await redis.get(`session:${sessionId}`);
  if (!session) return null;
  
  const now = Date.now() / 1000;
  const expiresAt = session.expires_at;
  const remaining = expiresAt - now;
  
  // 如果剩余时间 < 1天，且距离上次续期 > 1小时，则滑动续期
  if (remaining < 86400 && (now - session.last_activity) > 3600) {
    session.expires_at = now + 604800; // 续期到 7天
    session.last_activity = now;
    await redis.setex(`session:${sessionId}`, 604800, JSON.stringify(session));
  }
  
  return session;
}
```

**配置项**：
- `SESSION_TTL_SECONDS`：Session TTL（默认 604800 = 7天）
- `SESSION_SLIDE_RENEWAL_THRESHOLD`：滑动续期阈值（默认 86400 = 1天）

---

## 二、认证接口设计（综合方案）

### 问题 2.1：`/auth/me` 接口设计（统一认证接口）

**方案**：**支持 Cookie 和 Bearer Token 两种认证方式（自动识别，优先级：Cookie > Bearer Token）**

**设计原则**：
- ✅ 统一接口，支持多种调用场景
- ✅ 自动识别认证方式，无需调用方指定
- ✅ 优先级策略：Cookie（浏览器场景）> Bearer Token（服务间调用）
- ✅ 服务端调用返回 `access_token`（通过 `X-Service-Call` header 标识）

**接口规范**：
- **URL**：`GET /api/v1/auth/me`
- **认证方式**：支持 Cookie 和 Bearer Token（自动识别，优先级：Cookie > Bearer Token）
- **行为**：
  1. **优先尝试 Cookie 认证**：
     - 从 Cookie 中读取 `session_id`
     - 从 Redis 获取 Session
     - 如果 Session 有效，返回用户信息
  2. **回退到 Bearer Token 认证**（如果 Cookie 不存在或无效）：
     - 从 `Authorization: Bearer <token>` header 读取 JWT Token
     - 验证 JWT Token 签名和过期时间
     - 检查 Token 黑名单
     - 如果 Token 有效，返回用户信息
  3. **自动处理**：
     - 更新 Session 的 `last_activity`（用于滑动续期）
     - 自动刷新 `access_token`（如果过期）

**响应内容**：
- **浏览器调用**：只返回用户信息（不返回 `access_token`）
- **服务端调用**（带 `X-Service-Call: true` header）：返回用户信息 + `access_token`（用于服务间调用）

**实现示例**：
```typescript
@Get('auth/me')
async getCurrentUser(@Req() req: Request): Promise<UserProfileDto | UserProfileWithTokenDto> {
  // 1. 优先尝试 Cookie 认证
  const sessionId = req.cookies[SESSION_COOKIE_NAME];
  if (sessionId) {
    const session = await sessionStorage.getSession(sessionId);
    if (session && !isExpired(session)) {
      // Cookie 认证成功
      await sessionStorage.updateLastActivity(sessionId);
      
      // 判断是否为服务端调用
      const isServiceCall = req.headers['x-service-call'] === 'true';
      if (isServiceCall) {
        // 服务端调用：返回用户信息 + access_token
        return {
          ...this.mapSessionToUserProfile(session),
          access_token: session.access_token,
        };
      } else {
        // 浏览器调用：只返回用户信息
        return this.mapSessionToUserProfile(session);
      }
    }
  }
  
  // 2. 回退到 Bearer Token 认证（服务间调用）
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token) {
    try {
      const payload = await this.jwt.verifyAsync(token);
      
      // 检查黑名单
      if (this.tokenStorage.isBlacklisted(token)) {
        throw new UnauthorizedException('Token has been revoked');
      }
      
      // 从 Token 中获取用户信息
      const userId = parseInt(payload.sub, 10);
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

**响应示例（浏览器调用）**：
```json
{
  "id": "1",
  "email": "user@example.com",
  "email_validated": true,
  "is_active": true,
  "is_superuser": false,
  "full_name": "User Name",
  "password": true,
  "totp": false
}
```

**响应示例（服务端调用，带 `X-Service-Call: true` header）**：
```json
{
  "id": "1",
  "email": "user@example.com",
  "email_validated": true,
  "is_active": true,
  "is_superuser": false,
  "full_name": "User Name",
  "password": true,
  "totp": false,
  "access_token": "jwt-string"  // 服务间调用使用
}
```

---

### 问题 2.2：登录接口响应

**方案**：**登录成功后，只设置 Cookie，不返回任何 Token**

**接口规范**：
- **URL**：`POST /api/v1/login/oauth`
- **响应**：
  - 设置 HttpOnly Cookie（`session_id`）
  - 响应体返回用户信息（可选）或简单的成功消息

**实现示例**：
```typescript
@Post('login/oauth')
async loginWithOauth(
  @Body() body: OAuthLoginDto,
  @Res() res: Response,
): Promise<void> {
  // 验证用户名密码
  const user = await this.validateUser(body.username, body.password);
  
  // 创建 Session
  const sessionId = uuidv4();
  const session = {
    session_id: sessionId,
    user_id: user.id,
    username: user.username,
    email: user.email,
    // ... 其他用户信息
    created_at: Date.now() / 1000,
    expires_at: Date.now() / 1000 + SESSION_TTL_SECONDS,
  };
  
  // 写入 Redis
  await sessionStorage.setSession(sessionId, session, SESSION_TTL_SECONDS);
  
  // 设置 Cookie
  res.cookie(SESSION_COOKIE_NAME, sessionId, {
    httpOnly: true,
    secure: AUTH_COOKIE_SECURE,
    sameSite: AUTH_COOKIE_SAMESITE,
    domain: AUTH_COOKIE_DOMAIN,
    path: '/',
    maxAge: SESSION_TTL_SECONDS * 1000,
  });
  
  // 返回用户信息（可选）
  res.json(this.mapSessionToUserProfile(session));
}
```

**响应示例**：
```json
{
  "id": "1",
  "email": "user@example.com",
  "email_validated": true,
  "is_active": true,
  "is_superuser": false,
  "full_name": "User Name",
  "password": true,
  "totp": false
}
```

**注意**：响应体中**不包含**任何 Token 信息

---

## 三、Session 刷新机制

### 问题 3.1：刷新策略

**方案**：**Session 滑动续期 + Access Token 自动刷新**

**刷新机制**：
1. **Session 滑动续期**：
   - 每次调用 `/auth/me` 时，如果 Session 剩余时间 < 1天，自动续期到 7天
   - 客户端无需处理刷新逻辑，完全由服务端处理

2. **Access Token 自动刷新**：
   - 每次调用 `/auth/me` 时，检查 `access_token` 是否过期
   - 如果过期（但 Session 仍有效），自动生成新的 `access_token` 并更新 Session
   - 新的 `access_token` 用于后续的服务间调用

**用户体验**：
- 用户只要在 7 天内有活动，Session 就会自动续期
- Access Token 自动刷新，服务间调用无需手动处理

**实现逻辑**：
```typescript
async getSession(sessionId: string) {
  const session = await redis.get(`session:${sessionId}`);
  if (!session) return null;
  
  const now = Date.now() / 1000;
  const expiresAt = session.expires_at;
  const remaining = expiresAt - now;
  
  // 如果 Session 已过期
  if (remaining <= 0) {
    await this.deleteSession(sessionId);
    return null;
  }
  
  // 1. Session 滑动续期：如果剩余时间 < 1天，且距离上次续期 > 1小时，则滑动续期
  if (remaining < 86400 && (now - session.last_activity) > 3600) {
    session.expires_at = now + SESSION_TTL_SECONDS; // 续期到 7天
    session.last_activity = now;
  } else {
    // 更新最后活动时间
    session.last_activity = now;
  }
  
  // 2. Access Token 自动刷新：如果过期，生成新的（用于服务间调用）
  if (session.access_expires_at < now) {
    session.access_token = await this.jwt.signAsync(
      {
        sub: String(session.user_id),
        username: session.username,
        is_superuser: session.is_superuser,
      },
      { expiresIn: '15m' }
    );
    session.access_expires_at = now + 900; // 15分钟后过期
  }
  
  // 更新 Redis
  await redis.setex(`session:${sessionId}`, remaining > 86400 ? remaining : SESSION_TTL_SECONDS, JSON.stringify(session));
  
  return session;
}
```

**说明**：
- ✅ 不需要单独的 `/login/refresh` 接口
- ✅ 客户端完全无感知，体验更好
- ✅ 实现简单，逻辑清晰

---

### 问题 3.2：是否需要主动刷新接口

**疑问**：
- 是否还需要保留 `/login/refresh` 接口？
- 如果需要，它的作用是什么？

**建议**：**不需要主动刷新接口**

**原因**：
- Session 的刷新完全由服务端自动处理（滑动续期）
- 客户端只需要在 Cookie 过期时重新登录即可
- 简化架构，减少接口数量

**如果未来需要**：
- 可以添加 `/auth/refresh` 接口，用于客户端主动触发刷新（但通常不需要）

---

## 四、跨子域 Cookie 共享

### 问题 4.1：域名结构

**疑问**：
- 所有子应用是否在同一顶级域名下？
- 例如：`auth.sunmoonai.com`, `llmops.sunmoonai.com`, `incubator.sunmoonai.com`？
- 如果不在同一域名，如何实现 SSO？

**决策**：✅ **所有子应用都在同一顶级域名下**（已确认）

**域名结构**：
- 所有子应用都在 `*.sunmoonai.com` 下
- 例如：`auth.sunmoonai.com`, `llmops.sunmoonai.com`, `incubator.sunmoonai.com`

**Cookie 配置**：
- ✅ 使用 `Domain=.sunmoonai.com`（所有子域共享 Cookie）
- ✅ 使用 `SameSite=Lax`（SSR 场景足够）
- ✅ 使用 `Secure=true`（生产环境，HTTPS only）
- ✅ 使用 `HttpOnly=true`（防止 XSS）

**实现示例**：
```typescript
res.cookie(SESSION_COOKIE_NAME, sessionId, {
  httpOnly: true,
  secure: true,
  sameSite: 'lax',
  domain: '.sunmoonai.com',  // 所有子域共享
  path: '/',
  maxAge: SESSION_TTL_SECONDS * 1000,
});
```

---

### 问题 4.2：Cookie 属性配置

**疑问**：
- `SameSite` 应该设置为 `Lax` 还是 `None`？
- `Secure` 是否必须（HTTPS only）？

**决策**：✅ **已确认**

**SameSite 设置**：
- ✅ **默认值：`Lax`**
- **理由**：
  - SSR 场景足够：用户通过浏览器导航（链接、表单）访问不同子域时，Cookie 会自动带上
  - 安全性更好：减少 CSRF 风险
  - 无需 HTTPS 强制：开发环境可用 HTTP（配合 `Secure=false`）
  - 符合常见实践：大多数 SSR 应用使用 Lax
- **何时需要 `None`**：
  - 前端 JavaScript 需要跨域发送 Cookie（如 SPA 的 fetch/XHR）
  - 需要实现跨域 SSO（OAuth2/OIDC 回调）
  - 当前架构是 SSR，服务端请求不受浏览器 SameSite 限制，所以不需要
- **配置开关**：`AUTH_COOKIE_SAMESITE=Lax`（环境变量，默认 `Lax`）

**Secure 设置**：
- ✅ **生产环境：`true`（HTTPS only）**
- ✅ **开发环境：`false`（允许 HTTP）**
- **配置开关**：`AUTH_COOKIE_SECURE`（根据环境自动设置）
- **注意**：如果 `SameSite=None`，则 `Secure` 必须为 `true`

---

## 五、TokenStorageService 迁移

### 问题 5.1：临时 Token 存储策略

**当前实现**：`TokenStorageService` 使用内存存储（魔法链接、TOTP 等临时 token）

**疑问**：
- 是否应该将所有临时 token 也迁移到 Redis？
- 还是只迁移 Session，临时 token 仍用内存（单实例场景）？

**决策**：✅ **统一使用 Redis**（已确认）

**理由**：
1. **Session 已经要用 Redis**：既然 Session 必须用 Redis（支持多实例、持久化），临时 Token 也应该统一用 Redis
2. **容量不是问题**：
   - 临时 Token 都有 TTL，会自动过期，不会无限增长
   - 临时 Token 类型和过期时间：
     - `magic:{token}` - 15分钟过期
     - `recovery:{token}` - 1小时过期
     - `totp-setup:{username}` - 10分钟过期
     - `email-validation:{token}` - 24小时过期
     - 黑名单 - 1小时过期
   - 每个临时 Token 很小（几十到几百字节）
   - 数量通常远小于 Session（因为过期快）
3. **支持多实例部署**：临时 Token 需要在多个实例间共享（如魔法链接可能在不同实例上验证）
4. **统一存储便于管理**：统一使用 Redis，便于监控、备份、运维

**容量估算**（假设 10,000 活跃用户）：
- Session：10,000 个 × 2KB ≈ 20MB（7天过期）
- 临时 Token（峰值）：
  - 魔法链接：假设 100 个并发 × 200B ≈ 20KB（15分钟过期）
  - 密码恢复：假设 50 个并发 × 200B ≈ 10KB（1小时过期）
  - TOTP 设置：假设 20 个并发 × 100B ≈ 2KB（10分钟过期）
  - 邮箱验证：假设 200 个并发 × 200B ≈ 40KB（24小时过期）
  - **总计：< 100KB**
- **结论**：临时 Token 的容量可以忽略不计，远小于 Session

**实现方案**：
- 统一使用 Redis 存储 Session 和临时 Token
- 使用统一的 Redis Key 命名规范（见 5.2）
- 所有 Token 都设置 TTL，自动过期清理

---

### 问题 5.2：Redis Key 命名规范

**疑问**：
- 是否应该统一 Redis Key 命名规范？
- 如何避免 Key 冲突？

**决策**：✅ **统一命名规范，使用 `auth:` 前缀**（已确认）

**命名规范**：

1. **统一前缀**：`auth:`（便于 Redis 管理、监控、批量操作）
2. **命名格式**：`auth:{type}:{identifier}`
3. **命名空间分类**：

| 类型 | Key 格式 | 数据类型 | TTL | 说明 |
|------|----------|----------|-----|------|
| **Session** | `auth:session:{session_id}` | String (JSON) | 7天（滑动续期） | 用户会话数据 |
| **用户 Session 映射** | `auth:user_sessions:{user_id}` | Set | 7天 | 用户的所有 session_id（用于"踢出所有设备"） |
| **黑名单** | `auth:blacklist:{token}` | String | Token 剩余有效期 | JWT Token 黑名单 |
| **魔法链接** | `auth:magic:{token}` | String | 15分钟 | 魔法链接临时 Token |
| **密码恢复** | `auth:recovery:{token}` | String | 1小时 | 密码恢复临时 Token |
| **TOTP 设置** | `auth:totp-setup:{username}` | String | 10分钟 | TOTP 设置临时 Token |
| **邮箱验证** | `auth:email-validation:{token}` | String | 24小时 | 邮箱验证临时 Token |

**命名原则**：
1. ✅ **统一前缀**：所有 Key 使用 `auth:` 前缀，便于：
   - 批量操作（如 `KEYS auth:*` 查看所有认证相关 Key）
   - 监控和统计（如 `INFO keyspace` 查看 Key 数量）
   - 避免与其他服务冲突
2. ✅ **清晰的命名空间**：使用 `{type}:{identifier}` 格式，类型明确
3. ✅ **小写 + 连字符**：使用小写字母和连字符（`-`），符合 Redis 最佳实践
4. ✅ **避免特殊字符**：不使用空格、特殊字符，避免解析问题

**示例**：
```typescript
// Session
const sessionKey = `auth:session:${sessionId}`;
await redis.setex(sessionKey, 604800, JSON.stringify(session));

// 用户 Session 映射
const userSessionsKey = `auth:user_sessions:${userId}`;
await redis.sadd(userSessionsKey, sessionId);
await redis.expire(userSessionsKey, 604800);

// 魔法链接
const magicKey = `auth:magic:${token}`;
await redis.setex(magicKey, 900, claimToken);

// 黑名单
const blacklistKey = `auth:blacklist:${token}`;
await redis.setex(blacklistKey, 3600, '1');
```

**运维优势**：
- 批量查看：`KEYS auth:*` 或 `SCAN 0 MATCH auth:*`
- 批量删除：`redis-cli --scan --pattern "auth:magic:*" | xargs redis-cli DEL`
- 监控统计：`INFO keyspace` 可以看到 `auth:*` 的 Key 数量
- 避免冲突：其他服务可以使用 `user:*`、`cache:*` 等前缀

**实现建议**：
```typescript
// 统一 Key 生成工具
class RedisKeyBuilder {
  private static readonly PREFIX = 'auth';
  
  static session(sessionId: string): string {
    return `${this.PREFIX}:session:${sessionId}`;
  }
  
  static userSessions(userId: string): string {
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

---

## 六、BFF 调用方式改造

### 问题 6.1：AuthClient 改造

**什么是 BFF AuthClient？**

**BFF AuthClient** 是 `llmops-app-bff` 和 `incubator-app-bff` 中用来调用 `auth-app-bff` 的客户端类。

**当前实现**（`llmops-app-bff/app/core/auth_client.py`）：
```python
class AuthClient:
    """认证服务客户端"""
    
    async def get_user_by_token(self, token: str) -> Dict[str, Any]:
        """使用 Bearer Token 调用 auth-app-bff"""
        response = await client.get(
            f"{self.base_url}/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token}"},  # ❌ 旧方式
            timeout=5.0
        )
        return response.json()
```

**问题**：
- ❌ 使用 Bearer Token 方式（不符合新架构）
- ❌ 需要从 Authorization header 读取 Token
- ❌ 不支持 Cookie 认证

**改造方案**：✅ **重写 AuthClient，支持 Cookie 转发**（已确认）

**架构说明**：
- **BFF → auth-app-bff**：服务间调用
  - 方式 1（推荐）：转发 Cookie（从浏览器请求中获取）
  - 方式 2：使用 Session 中的 JWT Token（如果需要）

**新实现**（`llmops-app-bff/app/core/auth_client.py`）：
```python
class AuthClient:
    """认证服务客户端 - 支持 Cookie 转发（推荐）或 JWT Token"""
    
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
        # 原样转发 Cookie（推荐方式）
        headers = {}
        cookies = request.headers.get("cookie")
        if cookies:
            headers["Cookie"] = cookies
        
        # 添加服务端调用标识（用于获取 access_token）
        headers["X-Service-Call"] = "true"
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v1/auth/me",
                headers=headers,
                timeout=5.0
            )
            response.raise_for_status()
            user_info = response.json()
            
            # auth-app-bff 会返回 access_token（因为带了 X-Service-Call header）
            # BFF 可以使用这个 access_token 调用其他微服务
            return user_info
    
    async def get_access_token_for_service_call(self, request: Request) -> str:
        """
        获取 access_token（用于服务间调用）
        
        说明：
        - BFF 调用其他微服务时，需要使用 JWT Token 验证用户身份
        - 可以通过 Cookie 获取 Session，然后从 Session 中获取 access_token
        - 或者调用 auth-app-bff 的专门接口获取 access_token
        
        Args:
            request: FastAPI Request 对象，包含 Cookie
            
        Returns:
            JWT Token 字符串
        """
        # 方式 1（推荐）：通过 Cookie 调用 auth-app-bff 获取 Session，然后获取 access_token
        # 方式 2：调用 auth-app-bff 的专门接口获取 access_token
        # 方式 3：BFF 自己生成 JWT Token（基于用户信息，但需要知道 JWT_SECRET）
        
        # 推荐实现：调用 /auth/me 获取用户信息，然后从响应中获取 access_token
        # 或者：调用专门的接口 /auth/token 获取 access_token
        user_info = await self.get_current_user(request)
        # 如果 /auth/me 返回 access_token，则使用
        # 否则，调用专门的接口获取
        pass
```

**说明**：
- ✅ 只支持 Cookie 认证（从 Request 中读取 Cookie 并转发）
- ✅ 添加 `X-Service-Call: true` header，获取 `access_token`（用于后续服务间调用）
- ❌ 不再支持 Bearer Token 方式（旧方式）

**改造影响**：
- **文件**：`llmops-app-bff/app/core/auth_client.py`、`incubator-app-bff/app/core/auth_client.py`
- **方法变更**：
  - 旧：`get_user_by_token(token: str)` - 需要传入 Token
  - 新：`get_current_user(request: Request)` - 从 Request 读取 Cookie
- **依赖注入改造**：`app/api/deps.py` 中的 `get_current_user` 需要修改（见 6.2）

---

### 问题 7.2：依赖注入改造

**方案**：**重写依赖函数，支持 Cookie 认证**

**新实现**（`llmops-app-bff/app/api/deps.py`）：
```python
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
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 401:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
            )
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Could not validate credentials",
        )
```

**说明**：
- ✅ 从 Request 中读取 Cookie
- ✅ 调用 AuthClient 转发 Cookie 到 auth-app-bff
- ❌ 不再从 Authorization header 读取 Token

---

## 七、SSR 改造

### 问题 7.1：前端 Token 存储移除

**方案**：**完全移除 Token 存储，只保留用户信息**

**改造内容**：
1. **删除**：`stores/tokens.ts`（不再需要 Token Store）
2. **简化**：`stores/auth.ts`，移除所有 token 相关逻辑
3. **改造**：所有 API 调用，移除 Authorization header，依赖 Cookie

**新的 `stores/auth.ts` 结构**：
```typescript
export const useAuthStore = defineStore("authUser", {
  state: (): IUserProfile => ({
    id: "",
    email: "",
    // ... 用户信息
  }),
  persist: {
    storage: persistedState.cookiesWithOptions({
      httpOnly: false,  // 用户信息可以前端读取（非敏感）
      secure: true,
      maxAge: 60 * 60 * 24 * 7,  // 7天
    }),
  },
  actions: {
    async logIn(payload: { username: string; password?: string }) {
      // 调用登录接口，服务端会设置 HttpOnly Cookie
      const response = await $fetch('/api/v1/login/oauth', {
        method: 'POST',
        body: payload,
        credentials: 'include',  // 重要：发送 Cookie
      });
      
      // 登录成功后，获取用户信息
      await this.getUserProfile();
    },
    
    async getUserProfile() {
      // 调用 /auth/me，Cookie 会自动发送
      const response = await $fetch('/api/v1/auth/me', {
        credentials: 'include',  // 重要：发送 Cookie
      });
      
      this.setUserProfile(response);
    },
    
    async logOut() {
      // 调用登出接口，服务端会清除 Cookie
      await $fetch('/api/v1/auth/logout', {
        method: 'POST',
        credentials: 'include',
      });
      
      // 清除本地用户信息
      this.$reset();
    },
  }
});
```

**最佳实践要点**：
1. ✅ **完全移除 Token 存储**：不存储任何 Token 到 localStorage/sessionStorage
2. ✅ **统一使用 Cookie**：所有 API 调用使用 `credentials: 'include'`
3. ✅ **错误处理**：区分网络错误和认证错误，提供友好的错误提示
4. ✅ **类型安全**：使用 TypeScript 类型定义
5. ✅ **状态管理**：使用 Pinia 统一管理用户状态
6. ✅ **持久化策略**：只持久化非敏感的用户信息（如用户名、头像）

**说明**：
- ✅ 不再存储任何 Token（完全移除 Token Store）
- ✅ 所有 API 调用使用 `credentials: 'include'` 自动发送 Cookie
- ✅ 登录/登出由服务端通过 Set-Cookie 控制
- ✅ 错误处理：网络错误和认证错误分别处理
- ✅ 类型安全：使用 TypeScript 类型定义

---

### 问题 7.2：SSR 服务端中间件

**决策**：✅ **基于最佳生产实践的 SSR 中间件方案**（已确认）

**最佳实践要点**：
1. ✅ **错误处理**：区分网络错误和认证错误
2. ✅ **超时控制**：避免长时间等待
3. ✅ **缓存策略**：短时间缓存用户信息，减少 BFF 调用
4. ✅ **类型安全**：使用 TypeScript 类型定义
5. ✅ **性能优化**：异步并发处理，避免阻塞
6. ✅ **安全考虑**：验证 Cookie 格式，防止注入攻击

**实现方案**（`server/middleware/auth.global.ts`）：
```typescript
import type { EventHandler } from 'h3'
import { useRuntimeConfig } from '#imports'

interface AuthContext {
  user: any | null
  authenticated: boolean
  sessionId?: string
}

// 扩展 Nuxt 事件上下文类型
declare module 'h3' {
  interface H3EventContext {
    auth?: AuthContext
  }
}

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

  // 调用 BFF 的 /auth/me 接口（BFF 会转发 Cookie 到 auth-app-bff）
  try {
    const bffUrl = config.public.bffUrl || 'http://localhost:3030'
    const user = await $fetch(`${bffUrl}/api/v1/auth/me`, {
      headers: {
        cookie: `Cookie: ${sessionCookieName}=${sessionId}`, // 只转发 Session Cookie
      },
      timeout: 3000, // 3秒超时
      retry: 1, // 重试1次
    })

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
      // 生产环境：可以发送到监控系统（如 Sentry）
      event.context.auth = {
        user: null,
        authenticated: false,
      }
    }
  }
}) satisfies EventHandler
```

**页面使用**（最佳实践）：
```typescript
// composables/useAuth.ts
export const useAuth = () => {
  const event = useRequestEvent()
  const auth = event?.context.auth

  return {
    user: auth?.user || null,
    isAuthenticated: auth?.authenticated || false,
    sessionId: auth?.sessionId,
  }
}

// pages/dashboard.vue
<script setup lang="ts">
const { user, isAuthenticated } = useAuth()

// 服务端渲染时检查认证
if (import.meta.server && !isAuthenticated) {
  throw createError({
    statusCode: 401,
    statusMessage: 'Unauthorized',
  })
}

// 客户端渲染时重定向
if (import.meta.client && !isAuthenticated) {
  await navigateTo('/login')
}
</script>
```

**性能优化**（可选，基于最佳实践）：
```typescript
// 短时间缓存用户信息（减少 BFF 调用）
const userCache = new Map<string, { user: any; expires: number }>()
const CACHE_TTL = 5000 // 5秒缓存

export default defineEventHandler(async (event) => {
  // ... 前面的代码 ...
  
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

  // ... 调用 BFF ...
  
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
})
```

**说明**：
- ✅ 错误处理：区分认证错误和网络错误
- ✅ 超时控制：3秒超时，避免长时间等待
- ✅ 安全验证：验证 Session ID 格式，防止注入攻击
- ✅ 性能优化：可选缓存策略，减少 BFF 调用
- ✅ 类型安全：使用 TypeScript 类型定义
- ✅ 可观测性：记录错误日志，便于监控

---

### 问题 7.3：API 调用改造

**方案**：**移除所有 Token 相关代码，统一使用 Cookie**

**改造规则**：
1. **移除**：所有 `Authorization: Bearer ${token}` header
2. **添加**：所有 API 调用添加 `credentials: "include"`
3. **删除**：所有 `this.tokenStore.token` 的使用

**示例**：
```typescript
// ❌ 旧代码
const response = await $fetch('/api/users/', {
  headers: {
    Authorization: `Bearer ${this.tokenStore.token}`
  }
});

// ✅ 新代码
const response = await $fetch('/api/users/', {
  credentials: "include"  // 自动发送 Cookie
});
```

**全局配置**（`nuxt.config.ts`）：
```typescript
export default defineNuxtConfig({
  runtimeConfig: {
    public: {
      apiBase: process.env.API_BASE_URL || 'http://localhost:3030',
    }
  },
  // 全局配置 fetch，自动包含 credentials
  app: {
    head: {
      // ...
    }
  }
});

// 在 composables 或 utils 中
export const useApi = () => {
  const config = useRuntimeConfig();
  
  return {
    fetch: (url: string, options: any = {}) => {
      return $fetch(url, {
        baseURL: config.public.apiBase,
        credentials: 'include',  // 全局默认包含 Cookie
        ...options,
      });
    }
  };
};
```

---

## 八、实施顺序和灰度策略

### 问题 8.1：实施顺序

**决策**：✅ **最佳实施顺序**（已确认）

**实施顺序**：

#### 阶段 1：基础设施准备（1-2天）
1. **Redis 部署和配置**
   - 部署 Redis（单实例或集群）
   - 配置连接、密码、ACL
   - 配置监控和告警

2. **auth-app-bff 基础设施**
   - 添加 Redis 依赖（ioredis）
   - 添加 Cookie 解析依赖（cookie-parser）
   - 配置环境变量（Redis、Cookie 相关）

#### 阶段 2：auth-app-bff 核心实现（3-5天）
3. **Session 存储层**
   - 实现 `RedisService`（基础封装）
   - 实现 `SessionStorageService`（Session CRUD）
   - 重构 `TokenStorageService`（迁移到 Redis）

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

#### 阶段 3：BFF 适配（2-3天，可与阶段 4 并行）
7. **llmops-app-bff 改造**
   - 重构 `AuthClient`：Cookie 转发方式
   - 重构 `deps.py`：从 Request 读取 Cookie
   - 测试：认证流程、服务间调用

8. **incubator-app-bff 改造**
   - 重构 `AuthClient`：Cookie 转发方式
   - 重构 `deps.py`：从 Request 读取 Cookie
   - 测试：认证流程、服务间调用

#### 阶段 4：SSR 适配（2-3天，可与阶段 3 并行）
9. **auth-app-ssr 改造**
   - 删除 `stores/tokens.ts`
   - 重构 `api/core.ts`：移除 Token header，使用 `credentials: 'include'`
   - 重构 `stores/auth.ts`：移除 Token 相关逻辑
   - 实现 SSR 中间件：读取 Cookie，调用 BFF
   - 更新所有页面和组件：移除 Token 使用

10. **其他 SSR 应用改造**（如果有）
    - 同样的改造流程

#### 阶段 5：基础设施完善（1-2天）
11. **Ingress/网关配置**
    - 配置 Cookie Domain（`.sunmoonai.com`）
    - 确保 Cookie 不被代理篡改
    - 配置 CORS（如需要）

12. **监控和告警**
    - 配置 Redis 监控（连接数、内存、延迟）
    - 配置认证接口监控（延迟、错误率）
    - 配置告警阈值

#### 阶段 6：文档和回归测试（1-2天）
13. **文档更新**
    - 更新架构文档
    - 更新 API 文档
    - 更新部署文档

14. **完整回归测试**
    - 登录流程（OAuth、魔法链接、TOTP）
    - 认证流程（Cookie 认证、Bearer Token 兼容）
    - 跨子域 SSO
    - 登出和踢出
    - 性能测试

**关键依赖关系**：
- ✅ **阶段 2 必须先完成**（auth-app-bff 是核心）
- ✅ **阶段 3 和 4 可以并行**（BFF 和 SSR 互不依赖）
- ✅ **阶段 5 在阶段 2-4 完成后进行**（基础设施配置）

**总时间估算**：10-15 个工作日

---

### 问题 8.2：灰度策略

**决策**：✅ **不需要复杂灰度策略**（已确认）

**理由**：
- ✅ 这是首次开发，不是改造现有系统
- ✅ 新功能不影响现有系统（旧 JWT 系统仍然可用）
- ✅ 可以逐步切换，不需要一次性全量切换

**发布策略**：

1. **开发环境（Dev）**
   - 完整功能开发和测试
   - 所有功能验证通过

2. **预发布环境（Stage）**
   - 完整回归测试
   - 性能测试
   - 安全测试

3. **生产环境（Prod）**
   - 直接发布新功能
   - 保留旧 JWT 系统作为回退（兼容期）
   - 逐步切换用户到新系统

**回滚策略**（可选，用于紧急情况）：
- **配置开关**：`AUTH_SESSION_ENABLED=false`
  - 如果设置为 `false`，所有 Session 相关接口返回 503
  - 系统自动回退到 JWT 认证（如果保留兼容代码）
- **快速回滚**：回滚代码版本（如果使用 Git 版本控制）

**监控重点**：
- `/auth/me` 延迟和错误率
- Redis 连接数和延迟
- Cookie 设置成功率
- 401 错误率

---

## 十、监控和告警（基于最佳生产实践）

### 问题 9.1：关键指标和告警阈值

**决策**：✅ **基于最佳生产实践的监控方案**（已确认）

**监控指标分类**（基于 SRE 最佳实践）：

#### 1. 可用性指标（Availability）
- **认证接口可用性**：`/auth/me`、`/login/oauth`、`/auth/token` 等
  - 目标：99.9% 可用性（SLA）
  - 告警阈值：可用性 < 99.5%（持续 5 分钟）
- **Redis 可用性**：连接成功率
  - 目标：99.95% 可用性
  - 告警阈值：连接失败率 > 1%（持续 2 分钟）

#### 2. 延迟指标（Latency）
- **认证接口延迟**：
  - `/auth/me`：P50 < 50ms, P95 < 200ms, P99 < 500ms
  - `/login/oauth`：P50 < 100ms, P95 < 300ms, P99 < 1000ms
  - `/auth/token`：P50 < 30ms, P95 < 100ms, P99 < 200ms
  - **告警阈值**：
    - P95 延迟 > 500ms（持续 5 分钟）
    - P99 延迟 > 1000ms（持续 2 分钟）
- **Redis 延迟**：
  - P50 < 1ms, P95 < 5ms, P99 < 10ms
  - **告警阈值**：P95 延迟 > 10ms（持续 5 分钟）

#### 3. 错误率指标（Error Rate）
- **HTTP 错误率**：
  - 4xx 错误率：< 1%（正常认证失败除外）
  - 5xx 错误率：< 0.1%
  - **告警阈值**：
    - 4xx 错误率 > 5%（持续 5 分钟）
    - 5xx 错误率 > 1%（持续 2 分钟）
- **认证失败率**：
  - 正常范围：根据业务情况（如 5-10%）
  - **告警阈值**：认证失败率激增 > 50%（相比基线，持续 5 分钟）

#### 4. 吞吐量指标（Throughput）
- **QPS（每秒请求数）**：
  - `/auth/me`：监控峰值和平均值
  - `/login/oauth`：监控峰值和平均值
  - **告警阈值**：QPS 突然下降 > 50%（可能服务异常）

#### 5. 资源使用指标（Resource Usage）
- **Redis 资源**：
  - 连接数：< 80% 最大连接数
  - 内存使用：< 80% 总内存
  - CPU 使用：< 70% 单核
  - **告警阈值**：
    - 连接数 > 80%（持续 5 分钟）
    - 内存使用 > 85%（持续 5 分钟）
    - CPU 使用 > 80%（持续 5 分钟）
- **应用资源**：
  - 内存使用：< 80% 容器限制
  - CPU 使用：< 70% 容器限制
  - **告警阈值**：资源使用 > 85%（持续 5 分钟）

#### 6. 业务指标（Business Metrics）
- **登录成功率**：
  - 目标：> 95%
  - **告警阈值**：登录成功率 < 90%（持续 5 分钟）
- **Session 创建/删除速率**：
  - 监控 Session 创建和删除的速率
  - **告警阈值**：Session 创建速率异常（可能被攻击）

**监控工具建议**：
- **指标收集**：Prometheus
- **可视化**：Grafana
- **告警**：Alertmanager + PagerDuty/Slack
- **日志聚合**：ELK Stack 或 Loki
- **APM**：Jaeger 或 Zipkin（分布式追踪）

**告警级别**：
- **P0（紧急）**：服务完全不可用，需要立即处理
  - 认证接口 5xx 错误率 > 5%
  - Redis 完全不可用
- **P1（高优先级）**：服务降级，影响用户体验
  - 认证接口延迟 P95 > 1000ms
  - 认证失败率激增 > 50%
- **P2（中优先级）**：需要关注，但不紧急
  - 认证接口延迟 P95 > 500ms
  - Redis 资源使用 > 80%

---

### 问题 9.2：日志规范（基于最佳生产实践）

**决策**：✅ **基于最佳生产实践的日志规范**（已确认）

**日志级别**（基于 SLF4J 标准）：
- **ERROR**：系统错误，需要立即处理
  - Redis 连接失败
  - 认证服务异常
  - 数据库操作失败
- **WARN**：警告信息，需要关注
  - 认证失败（正常业务逻辑）
  - 资源使用接近阈值
  - 性能下降
- **INFO**：重要业务事件
  - 用户登录/登出
  - Session 创建/删除
  - 关键操作（如密码重置）
- **DEBUG**：调试信息（仅开发/测试环境）
  - 详细的请求/响应信息
  - 中间状态信息

**日志格式**（结构化日志，基于最佳实践）：
```typescript
// 标准日志格式（JSON）
{
  "timestamp": "2024-01-01T12:00:00.000Z",
  "level": "INFO",
  "service": "auth-app-bff",
  "trace_id": "abc123...",  // 分布式追踪 ID
  "span_id": "def456...",   // Span ID
  "user_id": "user-123",    // 用户 ID（如果可用）
  "session_id": "session-456", // Session ID（如果可用）
  "event": "user.login",    // 事件类型
  "message": "User logged in successfully",
  "metadata": {
    "ip": "192.168.1.1",
    "user_agent": "Mozilla/5.0...",
    "login_method": "oauth"
  }
}
```

**关键日志事件**：
1. **认证相关**：
   ```typescript
   // 登录成功
   logger.info({
     event: 'auth.login.success',
     user_id: user.id,
     session_id: sessionId,
     login_method: 'oauth',
   })
   
   // 登录失败
   logger.warn({
     event: 'auth.login.failed',
     username: username,
     reason: 'invalid_credentials',
     ip: req.ip,
   })
   
   // Session 创建
   logger.info({
     event: 'session.created',
     session_id: sessionId,
     user_id: user.id,
     expires_at: session.expires_at,
   })
   
   // Session 过期
   logger.info({
     event: 'session.expired',
     session_id: sessionId,
     user_id: user.id,
   })
   ```

2. **错误相关**：
   ```typescript
   // Redis 连接失败
   logger.error({
     event: 'redis.connection.failed',
     error: error.message,
     stack: error.stack,
   })
   
   // 认证服务异常
   logger.error({
     event: 'auth.service.error',
     endpoint: '/auth/me',
     error: error.message,
     status_code: 500,
   })
   ```

3. **性能相关**：
   ```typescript
   // 慢查询
   logger.warn({
     event: 'auth.slow_query',
     endpoint: '/auth/me',
     duration_ms: 500,
     threshold_ms: 200,
   })
   ```

**日志输出位置**：
- **标准输出**：所有日志输出到 stdout/stderr（容器化部署）
- **文件日志**：可选，用于本地调试
- **日志聚合**：发送到 ELK Stack 或 Loki

**日志保留策略**：
- **生产环境**：保留 30 天
- **开发/测试环境**：保留 7 天
- **敏感信息**：不记录密码、Token 等敏感信息

**日志安全**：
- ✅ **脱敏处理**：密码、Token、敏感信息不记录
- ✅ **访问控制**：日志系统需要访问控制
- ✅ **加密传输**：日志传输使用 TLS
- ✅ **合规要求**：符合 GDPR、CCPA 等合规要求

**实现建议**：
```typescript
// 使用结构化日志库（如 winston、pino）
import { Logger } from '@nestjs/common'
import { createLogger, format, transports } from 'winston'

const logger = createLogger({
  format: format.combine(
    format.timestamp(),
    format.errors({ stack: true }),
    format.json()
  ),
  defaultMeta: {
    service: 'auth-app-bff',
  },
  transports: [
    new transports.Console({
      format: format.combine(
        format.colorize(),
        format.simple()
      ),
    }),
  ],
})

// 使用示例
logger.info({
  event: 'user.login',
  user_id: user.id,
  session_id: sessionId,
})
```

**疑问**：
- 日志中是否应该记录敏感信息（如 token、session_id）？
- 如何平衡调试需求和安全性？

**建议**：
- **禁止记录**：
  - 完整的 JWT Token
  - Session ID（可以记录前 8 位用于追踪）
  - 用户密码
- **可以记录**：
  - 用户 ID、用户名（脱敏）
  - 操作类型（登录、登出、刷新）
  - 错误类型（无 Cookie、Session 过期、黑名单等）
- **日志格式**：
```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "level": "info",
  "service": "auth-app-bff",
  "operation": "login",
  "user_id": 1,
  "username": "user@example.com",
  "session_id_prefix": "abc12345",
  "result": "success",
  "duration_ms": 150
}
```

---

## 十、风险评估和缓解

### 问题 10.1：主要风险

**疑问**：
- 改造过程中可能遇到哪些风险？
- 如何缓解？

**风险清单**：

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Redis 不可用/高延迟 | 全部认证受阻 | 1. 本地短 TTL 缓存（session_id→user）<br>2. 快速失败（超时 100ms）<br>3. 回退 JWT 路径（AUTH_SESSION_ENABLED=false）<br>4. 监控告警 |
| Cookie 域/SameSite 配置错误 | 大面积掉登录/401 | 1. 灰度前在预发验证<br>2. 必要时回退 SameSite=Lax<br>3. 抓包验证 Set-Cookie |
| 双通道兼容期漏测 | 某些路径仍依赖 JWT | 1. 保留 Bearer 回退<br>2. 日志聚类发现未携带 Cookie 的请求<br>3. 兼容矩阵排查 |
| Set-Cookie 被代理改写 | 登录失效 | 1. 检查 Ingress/Traefik 配置<br>2. 抓包验证 Set-Cookie<br>3. 测试 Cookie 是否正常设置 |
| 黑名单/踢人未生效 | 安全风险 | 1. 黑名单存 Redis + TTL<br>2. 验证时必查黑名单<br>3. 单元测试覆盖 |

---

## 十一、待确认事项清单

### 技术决策
- [x] Session 中存储用户信息 + JWT Token（`access_token`），用于服务间调用（已确认）
- [x] Session TTL = 7天，支持滑动续期（已确认）
- [x] `/auth/me` 支持 Cookie 和 Bearer Token 两种认证方式（自动识别，优先级：Cookie > Bearer Token）（已确认）
- [x] 登录接口不返回 JWT Token 给浏览器（已确认）
- [x] 刷新策略：Session 滑动续期 + Access Token 自动刷新（已确认）
- [x] 服务端调用返回 `access_token`（通过 `X-Service-Call: true` header 标识）（已确认）
- [x] 删除兼容代码（auth-app-bff 的 `/auth/signin` 和 `/auth/signup`）（已确认，在重构中一起实施）
- [x] 重构不符合新架构的代码（auth-app-ssr、incubator-app-bff、llmops-app-bff）（已确认，在重构中一起实施）
- [x] 认证和权限分开解决（先认证，后权限）（已确认）
- [x] Session 结构预留权限字段（`is_superuser`, `roles`）（已确认）
- [x] 权限系统：完整的 RBAC 系统（已确认）
- [x] 权限管理：集成在 auth-app-bff 中，不需要独立服务（已确认）
- [x] `/auth/token` 接口：实现，作为推荐方式（已确认）
- [x] `X-Service-Call` header 命名：保持当前命名（已确认）
- [x] `/auth/validate` 接口：不需要（已确认）
- [x] 服务间调用 Token 过期时间：15分钟，配置化（已确认）
- [x] Cookie SameSite 设置：默认 `Lax`，配置化（已确认）
- [x] 临时 Token 存储策略：统一使用 Redis（已确认）
- [x] Redis Key 命名规范：统一使用 `auth:` 前缀（已确认）

**详细说明**（参考 `auth-service-call-scenarios-analysis.md` 第 8 节）：

1. **`/auth/token` 接口**：
   - ✅ 实现，作为推荐方式
   - 语义清晰，专门用于获取服务间调用 Token
   - 两种方式都支持：`/auth/me` + `X-Service-Call` 或 `/auth/token`
   - 实现优先级：第一阶段实现 `/auth/me` + `X-Service-Call`，第二阶段实现 `/auth/token`

2. **`X-Service-Call` header**：
   - ✅ 保持当前命名
   - 清晰明确，符合 `X-` 前缀惯例
   - 使用方式：`X-Service-Call: true`

3. **`/auth/validate` 接口**：
   - ❌ 不需要
   - `/auth/me` 已经可以验证认证状态（返回用户信息或 401）
   - 避免接口冗余

4. **Token 过期时间**：
   - ✅ 15分钟（默认），配置化
   - 符合行业标准（OAuth2 推荐）
   - 自动刷新机制，不影响用户体验
   - 配置项：`ACCESS_TOKEN_EXPIRES_IN = '15m'`（环境变量）

5. **Cookie SameSite 设置**：
   - ✅ 默认 `Lax`，配置化
   - **SameSite=Lax**：适合 SSR 场景，跨站导航会发送 Cookie，安全性好
   - **SameSite=None**：仅当需要 SPA 跨域或跨域 SSO 时使用（需配合 `Secure=true`）
   - 配置项：`AUTH_COOKIE_SAMESITE=Lax`（环境变量，默认 `Lax`）
   - 理由：当前架构是 SSR，服务端请求不受浏览器 SameSite 限制，Lax 足够且更安全

6. **临时 Token 存储策略**：
   - ✅ 统一使用 Redis
   - **理由**：
     - Session 已经要用 Redis，临时 Token 也应该统一用 Redis
     - 容量不是问题：临时 Token 都有 TTL，会自动过期，不会无限增长
     - 支持多实例部署：临时 Token 需要在多个实例间共享
     - 统一存储便于管理：便于监控、备份、运维
   - **容量估算**：临时 Token 的容量可以忽略不计（< 100KB），远小于 Session（20MB+）
   - **实现**：统一使用 Redis 存储 Session 和临时 Token，使用统一的 Key 命名规范

7. **Redis Key 命名规范**：
   - ✅ 统一使用 `auth:` 前缀
   - **命名格式**：`auth:{type}:{identifier}`
   - **Key 类型**：
     - `auth:session:{session_id}` - Session 数据
     - `auth:user_sessions:{user_id}` - 用户 Session 映射（Set）
     - `auth:blacklist:{token}` - Token 黑名单
     - `auth:magic:{token}` - 魔法链接
     - `auth:recovery:{token}` - 密码恢复
     - `auth:totp-setup:{username}` - TOTP 设置
     - `auth:email-validation:{token}` - 邮箱验证
   - **优势**：
     - 便于批量操作和监控
     - 避免与其他服务冲突
     - 符合 Redis 最佳实践
   - **实现**：建议使用统一的 Key 生成工具类（如 `RedisKeyBuilder`）

8. **域名结构**：
   - ✅ 所有子应用都在 `*.sunmoonai.com` 下
   - **Cookie 配置**：
     - `Domain=.sunmoonai.com`（所有子域共享）
     - `SameSite=Lax`（SSR 场景足够）
     - `Secure=true`（生产环境，HTTPS only）
     - `HttpOnly=true`（防止 XSS）

9. **BFF AuthClient 改造**：
   - ✅ 重写为 Cookie 转发方式
   - **什么是 BFF AuthClient**：`llmops-app-bff` 和 `incubator-app-bff` 中用来调用 `auth-app-bff` 的客户端类
   - **当前问题**：使用 Bearer Token 方式（不符合新架构）
   - **改造方案**：
     - 从 Request 中读取 Cookie 并转发到 `auth-app-bff`
     - 添加 `X-Service-Call: true` header，获取 `access_token`
     - 方法变更：`get_user_by_token(token)` → `get_current_user(request)`
   - **改造文件**：
     - `llmops-app-bff/app/core/auth_client.py`
     - `incubator-app-bff/app/core/auth_client.py`
     - `llmops-app-bff/app/api/deps.py`
     - `incubator-app-bff/app/api/deps.py`

### 架构确认
- [x] 域名结构：所有子应用都在 `*.sunmoonai.com` 下，使用 `Domain=.sunmoonai.com`（已确认）
- [x] BFF AuthClient 改造方案：重写为 Cookie 转发方式（已确认）
- [x] SSR 中间件实现方案：基于最佳生产实践，包含错误处理、超时控制、缓存策略（已确认）
- [x] 前端 Token 存储移除方案：完全移除 Token Store，统一使用 Cookie（已确认）

### 实施计划
- [x] 实施顺序：6 个阶段，总时间 10-15 个工作日（已确认）
- [x] 灰度策略：不需要复杂灰度策略，直接发布（已确认）
- [x] 监控指标和告警阈值：基于 SRE 最佳实践，包含可用性、延迟、错误率、吞吐量、资源使用、业务指标（已确认）
- [x] 日志规范：基于最佳生产实践，结构化日志，包含日志级别、格式、关键事件、安全要求（已确认）

---

## 十三、代码清理工作（在重构中一起实施）

### 12.1 删除兼容代码

**auth-app-bff**：
- [ ] 删除 `src/auth/auth.controller.ts` 中的 `/auth/signin` 和 `/auth/signup` 接口
- [ ] 删除 `src/auth/auth.service.ts` 中的 `signin()` 和 `signup()` 方法
- [ ] 删除 `src/auth/dto/signin-user.dto.ts`（如果不再使用）

### 12.2 重构不符合新架构的代码

**auth-app-ssr**：
- [ ] 删除 `stores/tokens.ts`（不再需要 Token Store）
- [ ] 重构 `api/core.ts`：移除 `headers(token)` 方法，所有 API 调用使用 `credentials: 'include'`
- [ ] 重构 `api/auth.ts`：移除所有 `headers` 参数，使用 `credentials: 'include'`
- [ ] 重构 `stores/auth.ts`：移除所有 `tokenStore` 相关代码
- [ ] 更新所有使用 `tokenStore.token` 的页面和组件

**incubator-app-bff 和 llmops-app-bff**：
- [ ] 重构 `app/core/auth_client.py`：新增 `get_current_user(request)` 方法（从 Cookie 读取）
- [ ] 重构 `app/api/deps.py`：修改 `get_current_user` 从 Request 读取 Cookie

**说明**：这些工作会在实施 Session + Cookie 重构时一起完成，不需要单独进行。

---

## 十三、下一步行动

1. **逐一讨论**：按照本文档的问题顺序，逐个讨论并确认
2. **更新文档**：根据讨论结果，更新 `auth-refactoring-plan-part*.md`
3. **制定详细实施计划**：确认所有问题后，制定详细的实施 Checklist
4. **开始实施**：按照 Phase 顺序开始实施，同时完成代码清理工作

---

## 十二、多种登录方式对 Session 实现的影响分析

### 问题 12.1：多种登录方式是否影响 Session 实现？

**疑问**：
- 当前有 OAuth、魔法链接、TOTP、密码恢复等多种登录方式
- 这些多种方式是否会影响 Session 的实现？
- 如果影响大，是否可以考虑只实现基本的登录？

**决策**：✅ **保留所有登录方式，影响很小**（已确认）

**详细分析**：见 `login-methods-impact-analysis.md`

**核心结论**：

1. **对核心 Session 机制的影响**：⭐ **无影响**
   - 所有登录方式最终都统一到 Session 创建
   - 无论使用哪种登录方式，最终都需要：
     - 验证用户身份
     - 创建 Session（存储到 Redis）
     - 设置 HttpOnly Cookie

2. **对临时 Token 存储的影响**：⭐⭐ **已解决**
   - 魔法链接、TOTP、密码恢复需要临时 Token 存储
   - 已经在 `TokenStorageService` 中实现
   - 已经规划迁移到 Redis（见问题 5.1）
   - 容量很小（< 100KB），不影响性能

3. **对登录流程复杂度的影响**：⭐ **业务需求**
   - 复杂度是业务需求，不是技术障碍
   - 所有登录方式最终都统一到 `createSession()` 方法

**统一实现方案**：

```typescript
// 所有登录方式最终都调用这个方法
async createSession(user: User, res: Response): Promise<void> {
  // 1. 生成 session_id
  const sessionId = uuidv4();
  
  // 2. 创建 Session 数据
  const session = {
    session_id: sessionId,
    user_id: user.id,
    username: user.username,
    email: user.email,
    // ... 其他用户信息
    access_token: await this.generateAccessToken(user),
    access_expires_at: Date.now() / 1000 + 900,
    created_at: Date.now() / 1000,
    expires_at: Date.now() / 1000 + SESSION_TTL_SECONDS,
  };
  
  // 3. 存储到 Redis
  await this.sessionStorage.setSession(sessionId, session, SESSION_TTL_SECONDS);
  
  // 4. 设置 Cookie
  res.cookie(SESSION_COOKIE_NAME, sessionId, {
    httpOnly: true,
    secure: AUTH_COOKIE_SECURE,
    sameSite: AUTH_COOKIE_SAMESITE,
    domain: AUTH_COOKIE_DOMAIN,
    path: '/',
    maxAge: SESSION_TTL_SECONDS * 1000,
  });
}
```

**各登录方式的实现**：

- **OAuth 登录**：验证用户名密码 → `createSession()`
- **魔法链接登录**：发送邮件 → 验证链接 → `createSession()`
- **TOTP 登录**：先获取临时 Token → 验证 TOTP → `createSession()`
- **密码恢复**：发送恢复邮件 → 验证链接 → 重置密码 → （可选）`createSession()`

**建议**：

1. **推荐方案**：保留所有登录方式
   - 影响小：多种登录方式不影响核心 Session 实现
   - 已规划：临时 Token 存储已规划迁移到 Redis
   - 统一实现：所有登录方式最终都统一到 `createSession()` 方法
   - 业务价值：提供多种登录方式提升用户体验和安全性

2. **分阶段实施**（如果时间紧迫）：
   - **第一阶段**：实现 OAuth 登录 + Session（最快上线）
   - **第二阶段**：实现魔法链接登录（提升用户体验）
   - **第三阶段**：实现 TOTP 登录（提升安全性）
   - **第四阶段**：实现密码恢复（完善功能）

**最终决定**：✅ **保留所有登录方式，但暂时只使用基本登录（OAuth）**（已确认）

**实施策略**：
1. ✅ **保留所有登录方式的代码**：不删除魔法链接、TOTP、密码恢复等代码
2. ✅ **暂时只启用 OAuth 登录**：通过配置开关控制
3. ✅ **其他登录方式暂时禁用**：可以通过配置开关后续启用
4. ✅ **统一实现**：所有登录方式最终都统一到 `createSession()` 方法

**配置开关建议**：
```typescript
// config/auth.config.ts
export const authConfig = {
  // 登录方式开关
  loginMethods: {
    oauth: process.env.AUTH_LOGIN_OAUTH_ENABLED !== 'false', // 默认启用
    magicLink: process.env.AUTH_LOGIN_MAGIC_LINK_ENABLED === 'true', // 默认禁用
    totp: process.env.AUTH_LOGIN_TOTP_ENABLED === 'true', // 默认禁用
    passwordRecovery: process.env.AUTH_LOGIN_PASSWORD_RECOVERY_ENABLED === 'true', // 默认禁用
  },
};
```

**实现示例**：
```typescript
// auth.controller.ts
@Post('login/magic/:email')
async loginWithMagicLink(@Param('email') email: string) {
  // 检查是否启用
  if (!authConfig.loginMethods.magicLink) {
    throw new NotFoundException('Magic link login is not enabled');
  }
  
  return this.authService.loginWithMagicLink(email);
}

@Post('login/totp')
async loginWithTotp(@Body() body: WebTokenDto, @Req() req: any) {
  // 检查是否启用
  if (!authConfig.loginMethods.totp) {
    throw new NotFoundException('TOTP login is not enabled');
  }
  
  return this.authService.loginWithTotp(token, body);
}
```

**环境变量配置**：
```bash
# 生产环境（暂时只启用 OAuth）
AUTH_LOGIN_OAUTH_ENABLED=true
AUTH_LOGIN_MAGIC_LINK_ENABLED=false
AUTH_LOGIN_TOTP_ENABLED=false
AUTH_LOGIN_PASSWORD_RECOVERY_ENABLED=false

# 后续可以逐步启用
# AUTH_LOGIN_MAGIC_LINK_ENABLED=true
# AUTH_LOGIN_TOTP_ENABLED=true
# AUTH_LOGIN_PASSWORD_RECOVERY_ENABLED=true
```

**优势**：
- ✅ **代码保留**：不删除代码，后续可以快速启用
- ✅ **灵活控制**：通过配置开关控制，无需修改代码
- ✅ **渐进式上线**：可以先上线 OAuth，后续逐步启用其他方式
- ✅ **降低风险**：减少初始上线的复杂度

---

## 附录：参考文档

- `auth-refactoring-plan-part1.md` - 核心原则和阶段总览
- `auth-refactoring-plan-part2.md` - 任务清单和测试要点
- `auth-refactoring-plan-part3.md` - 详细设计（数据结构、接口契约）
- `auth-refactoring-plan-part4.md` - 灰度/回滚、配置清单、监控
- `ssr_bff_auth_flow.md` - SSR + BFF + Auth 流程文档
- `sunmoonai·-architecture.md` - 系统架构文档
- `login-methods-impact-analysis.md` - 多种登录方式对 Session 实现的影响分析

