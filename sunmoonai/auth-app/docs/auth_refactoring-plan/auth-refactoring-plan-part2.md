# Auth 统一认证重构方案（分段版 · Part 2）

本部分列出可直接执行的分阶段任务清单与测试要点。默认优先从 Auth 核心（Phase 1）开始，逐步推进。

---
## Phase 1：auth-app-backend 引入 Redis Session 与 Cookie 认证（最高优先级）

### 1.1 基础设施与配置
- 新增配置项：`SESSION_COOKIE_NAME`（如 `sunmoonai_session`）、`SESSION_TTL_SECONDS`、`REDIS_HOST/PORT/DB/PASSWORD`。
- 在 `ConfigModule` 暴露上述配置，提供默认值用于本地开发。
- 引入 Redis 客户端封装（如 ioredis），提供健康检查和重连。

### 1.2 存储层实现
- 新增 `RedisService`：`get/set/del/expire` 基础封装。
- 新增 `SessionStorageService`：
  - `setSession(sessionId, data, ttl)` / `getSession(sessionId)` / `deleteSession(sessionId)`
  - 可选：`deleteUserSessions(userId)` 支持踢全端。
- 重构 `TokenStorageService`：由内存 Map/Set 改为 Redis，黑名单也存 Redis。
- Key 约定：
  - `session:{session_id}` → session JSON（含 user_id、username、roles、access/refresh、expires）
  - `user_sessions:{user_id}` → set(session_id...)（可选）
  - `blacklist:{token}` → TTL=token 剩余时间
  - 魔法链接/TOTP 指纹沿用现有前缀，迁移至 Redis。

### 1.3 Cookie 策略落地
- 登录/刷新/登出接口统一设置 Cookie：
  - `Set-Cookie: <SESSION_COOKIE_NAME>=<session_id>; HttpOnly; Secure; SameSite=Lax; Domain=.sunmoonai.com; Path=/`
- 提供可配置 SameSite（Lax/None），为未来跨子域 XHR 留接口。
- 登出时清理 Cookie（Max-Age=0）与 Redis session。

### 1.4 认证接口与登录流程重构
- 登录成功流程（OAuth / 魔法链接 / TOTP）：
  - 生成 `session_id`，写 Redis session
  - 设置 Cookie
  - 兼容返回 access/refresh（用于过渡期），可配置关闭
- `/auth/me`：
  - 优先 Cookie→Redis session 获取用户；若缺失则回退 Bearer JWT（兼容期）
  - 返回用户信息（脱敏）
- 刷新：
  - 从 Cookie 读取 session / refresh，验证/更新 Redis，会话滑动续期（可选）
- 撤销/登出：
  - 删除 Redis session；refresh 加黑名单（TTL=剩余时间）；清 Cookie
- 新增/替换 Guard：
  - `SessionOrJwtAuthGuard`：先 Cookie+Session，后 Bearer JWT
  - 在 Controller 层替换原有 `AuthGuard('jwt')`（逐步）

### 1.5 回归与监控
- 单元/集成测试：登录、/auth/me、刷新、登出、黑名单、魔法链接/TOTP。
- 性能与错误日志：登录、/auth/me 延迟、Redis 失败时的降级策略（可返回 503 或回退 JWT）。
- 可选：短 TTL 本地缓存（session_id→user）以减轻 Redis 压力。

---
## Phase 2：BFF 适配（llmops / incubator / portal）

### 2.1 配置与客户端
- 各 BFF ConfigMap 增加 `AUTH_SERVICE_URL`，指向 `auth-app-backend` Service。
- 提供统一的 `AuthClient`（NestJS/HTTPX）：
  - 调用 `/api/v1/auth/me`（或 `/api/auth/me`，取决于版本前缀）
  - 原样转发前端 Cookie（关键），不依赖前端拼 JWT。

### 2.2 认证流程调整
- 路由中间件/依赖：
  - 读取入站请求的 Cookie
  - 调用 Auth `/auth/me` 获取用户信息
  - 本地仅做授权判定（角色/权限）
- 清理/降级：
  - 移除或标记废弃的本地 JWT 解析逻辑；保留兼容 Bearer 模式（短期）。
- 可选缓存：
  - 短 TTL 缓存 `session_id→user` 以减少 Auth 调用，TTL 30~120s。

### 2.3 回归
- 覆盖：已登录 Cookie 访问 BFF 受保护路由；Cookie 失效→401；踢出后立即失效。
- 压测：/auth/me QPS 与延迟；BFF 本地缓存命中率（若启用）。

---
## Phase 3：SSR 适配（auth-app-front 起步）

### 3.1 前端存储策略
- Pinia 中不再持久化 access/refresh 到浏览器存储；仅存 UI 状态或临时 claim。
- 登录调用后依赖 HttpOnly Cookie（由 BFF/Auth 设置）。

### 3.2 SSR 数据获取
- SSR 侧（server routes/middleware）：
  - 读取入站 Cookie
  - 调用对应 BFF 的 `/me`（BFF 再调 Auth `/auth/me`）
  - 将用户信息注入页面渲染上下文
- 纯前端调用若需 Authorization：
  - 过渡期可从 SSR 注入的用户信息中获取一次性 token，或直接让前端改为走 BFF（推荐）。

### 3.3 页面/接口清理
- 清理前端直接拼 Authorization header 的逻辑（逐步），优先登录/刷新路径。
- 确保登出路径清 Cookie，并引导到登录页。

### 3.4 回归
- 登录后在多子应用间跳转无需再次登录（SSO）。
- Cookie 删除或过期后，自动跳回登录。

---
## Phase 4：基础设施与安全

### 4.1 Redis
- 确认集群/哨兵或单实例部署；限制访问范围（NetworkPolicy）。
- 配置密码/ACL；监控连接数、内存、延迟。

### 4.2 Ingress / Traefik
- 统一主域：`*.sunmoonai.com`
- Cookie 设置不被代理篡改；如需 SameSite=None，确保 HTTPS + CORS 配置。

### 4.3 CORS（若 SPA 场景）
- 仅允许可信来源；`Access-Control-Allow-Credentials: true`；预检缓存。

### 4.4 安全审计
- 确认 XSS 场景无法读取 Token（HttpOnly）。
- 确认撤销/踢人立即生效（Redis 删除 session + 黑名单）。

---
## Phase 5：文档与测试

### 5.1 文档
- 更新 `ssr_bff_auth_flow.md`：标记“已实现”状态与差异。
- 更新 `sunmoonai·-architecture.md`：补充“统一 Auth + Session + Redis”章节。
- 更新/补充 `auth-app-backend/ARCHITECTURE_ADAPTATION.md`：记录接口、配置、迁移说明。

### 5.2 测试清单（最小回归集）
- 登录（用户名/密码、魔法链接、TOTP）
- /auth/me（Cookie）返回用户；无 Cookie→401；被踢后→401
- 刷新：过期 access + 有效 refresh（在 Cookie/Session 中）→ 新 access
- 登出：当前端/多端；踢全端
- BFF 受保护接口：有 Cookie 正常，无 Cookie 401
- SSR 跨子应用 SSO：在一个应用登录，访问另一个无需重登

---
## 建议的实施顺序（可执行）
1) **Auth Phase 1**：落地 Redis、SessionStorageService、Cookie 登录与 /auth/me，保留 JWT 兼容。  
2) **BFF Phase 2**：llmops/incubator/portal 改为用 Cookie 调 /auth/me，清理本地 JWT 校验。  
3) **SSR Phase 3**：auth-app-front 起，移除前端持久化 JWT，改为依赖 Cookie+SSR→BFF→Auth。  
4) **Infra Phase 4**：Cookie 策略在 Ingress 生效，Redis 监控与安全。  
5) **Docs/Tests Phase 5**：同步文档与回归。

待你确认后，我将按上述顺序从 Phase 1 开始动手实现。  

