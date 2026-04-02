# Auth 统一认证重构方案（分段版）

## 0. 目标与范围
- 目标：实现符合 `ssr_bff_auth_flow.md` 的统一认证体系——浏览器仅持有 HttpOnly Cookie（session 引用），Auth 服务集中管理身份、会话与令牌，BFF 统一调用 Auth，SSR 不持有长期 JWT。
- 覆盖范围：`auth-app-backend`（核心）、`auth-app-front`、`incubator-app-bff/ssr`、`llmops-app-bff/ssr`，以及 K8s/Ingress 层的 Cookie 策略与 Redis 依赖。

## 1. 核心原则
1) 浏览器只存引用：HttpOnly + Secure + SameSite=Lax/None 的 `session_id`，不在前端持久化 access/refresh JWT。  
2) Auth 中心化：所有 BFF 通过 Auth Service 的 `/auth/me` 做认证，BFF 内只做授权与业务逻辑。  
3) Redis 持久化：会话、JWT 映射、黑名单、魔法链接/TOTP 指纹都存 Redis，可踢人、强制登出。  
4) 兼容迁移：短期内保留 Bearer JWT 兼容路径，逐步引导 SSR/BFF 转向 Cookie+Session。  
5) 安全优先：防止 XSS 读取 Token，支持黑名单/撤销，支持多端登出，Cookie 域统一。  
6) 可观测与灰度：关键路径埋点/日志，便于分阶段灰度与回滚。

## 2. 阶段总览（执行顺序）
- Phase 1（Auth 核心）：`auth-app-backend` 引入 Redis Session，改造登录/刷新/登出/ /auth/me，支持 Cookie+Session（兼容 JWT）。
- Phase 2（BFF 适配）：`llmops-app-bff`、`incubator-app-bff` 统一通过 `/auth/me` + Cookie 认证；清理本地 JWT 校验。
- Phase 3（SSR 适配）：`auth-app-front` 起，移除前端持久化 JWT，改为依赖 HttpOnly Cookie，SSR 调 BFF，再由 BFF 调 Auth。
- Phase 4（基础设施）：Redis 部署与配置，Ingress/Traefik Cookie 策略（Domain / SameSite / Secure / CORS），K8s ConfigMap/Secret 更新。
- Phase 5（文档与回归）：更新文档、提供测试用例/脚本，灰度与监控。

## 3. 技术方案概要
### 3.1 Session/Token 存储设计（Redis）
- Key 设计（建议）：  
  - `session:{session_id}` → `{ user_id, username, roles/is_superuser, access_token, refresh_token, expires_at, refresh_expires_at }`  
  - `user_sessions:{user_id}` → Set(session_id...)（用于踢全端，可选）  
  - `blacklist:{token}` → bool（TTL=token 剩余时间）  
  - 现有魔法链接/TOTP 指纹 → 迁移到 Redis，沿用 key 前缀。
- TTL 策略：  
  - Session TTL 与 refresh 绑定（如 7d），access_token 短期（如 15m），刷新时可滑动续期。

### 3.2 Cookie 策略
- `Set-Cookie: <SESSION_COOKIE_NAME>=<session_id>; HttpOnly; Secure; SameSite=Lax; Domain=.sunmoonai.com; Path=/`
- SSR 场景默认 Lax；若后续有跨子域 XHR/POST，再切换 SameSite=None+Secure 并配置 CORS。

### 3.3 Auth 接口行为
- 登录成功：生成 session_id → Redis 写 session → 设置 Cookie；响应体可以不再返回 access/refresh（或仅在兼容模式返回）。
- `/auth/me`：优先从 Cookie 取 session→Redis 取用户；若无 Cookie 再看 Bearer JWT（兼容模式）；返回用户信息。
- 刷新：读取 Cookie 中 session/refresh，刷新 access，并更新 Redis；返回新的 access（也可透明，取决于兼容需求）。
- 登出：删除 session key，清 Cookie；支持登出全部设备（删 `user_sessions:{uid}`）。
- 黑名单：撤销 refresh 时把旧 token 加入黑名单；验证时额外检查。

### 3.4 兼容策略
- 短期保留 Bearer JWT 入口：BFF 若仍带 Authorization 头，可继续工作；但推荐逐步改为 Cookie。
- SSR 前端存储：先并存（避免一次性全量改动），逐步移除 Pinia/localStorage 中的 token 持久化。

（后续 Phase 细节、任务清单、测试清单将放在后续分段文件）

