# Auth 统一认证重构方案（分段版 · Part 4：灰度/回滚、配置清单、兼容矩阵、实施 Checklist、监控与风险）

本部分进一步细化，便于直接按清单落地与灰度发布。

---
## 1. 灰度与回滚策略

### 1.1 开关位
- `AUTH_SESSION_ENABLED`（bool）：是否启用 Session+Cookie 主路径（默认先 true，仅在故障时可回退）。
- `AUTH_COOKIE_SAMESITE`（Lax/None）：方便按环境切换。
- `AUTH_RETURN_JWT_IN_RESPONSE`（bool）：兼容期是否继续在响应体返回 access/refresh。
- `AUTH_PASSIVE_REFRESH_ENABLED`（bool，可选）：/auth/me 是否执行被动刷新。

### 1.2 灰度步骤建议
1) **Stage/Dev 环境**：开启 `AUTH_SESSION_ENABLED=true`，`AUTH_RETURN_JWT_IN_RESPONSE=true`（保兼容），验证全链路。  
2) **Pre-prod**：按用户/流量灰度（网关或上游路由分流），观察 /auth/me 延迟、401 比例。  
3) **Prod 小流量**：仍保留 JWT 兼容，逐步扩大 Cookie 认证比例。  
4) **Prod 全量**：确认各 BFF/SSR 已适配后，可关闭 `AUTH_RETURN_JWT_IN_RESPONSE`（如无老客户端依赖）。  

### 1.3 回滚路径
- 紧急：`AUTH_SESSION_ENABLED=false`，回退到 Bearer JWT 流；保留 Redis 仍可读但不必写 Session。
- 如果 Cookie 域/代理问题导致大面积 401：暂时改回 `SameSite=Lax` 或关闭 Cookie 路径。
- 保留 JWT 兼容 Guard，保证回滚时仍可服务。

---
## 2. 配置与依赖清单

### 2.1 环境变量（auth-app-backend）
- `SESSION_COOKIE_NAME`（默认 `sunmoonai_session`）
- `SESSION_TTL_SECONDS`（如 604800 = 7d）
- `AUTH_SESSION_ENABLED`（bool）
- `AUTH_COOKIE_SAMESITE`（Lax/None），`AUTH_COOKIE_DOMAIN`（如 `.sunmoonai.com`），`AUTH_COOKIE_SECURE`（true）
- `AUTH_RETURN_JWT_IN_RESPONSE`（bool）
- `AUTH_PASSIVE_REFRESH_ENABLED`（bool）
- Redis：`REDIS_HOST/PORT/DB/PASSWORD`
- JWT：`JWT_SECRET`, `JWT_REFRESH_SECRET`, `ACCESS_TOKEN_EXPIRE_SECONDS`, `REFRESH_TOKEN_EXPIRE_SECONDS`

### 2.2 K8s / Ingress
- ConfigMap/Secret 同步以上变量。
- Ingress/Traefik：确保不改写 Set-Cookie，支持 HTTPS；若 SameSite=None，务必开启 Secure。
- NetworkPolicy：限制 Redis 访问来源。

### 2.3 依赖
- Redis（建议哨兵/集群，至少监控内存/连接/延迟）。
- ioredis（Node）或等效客户端。

---
## 3. 兼容矩阵（行为预期）

| 客户端形态 | Cookie 可用 | Bearer JWT | 预期行为 |
|-----------|-------------|------------|----------|
| 新 SSR/BFF（推荐） | 是 | 可选 | 走 Cookie+Session；无 Cookie 则 401 |
| 旧前端/客户端（仅 JWT） | 否 | 是 | 兼容期仍可验证 JWT；黑名单生效；可被动回退 |
| 双通道并存 | 是 | 是 | 优先 Cookie；无 Cookie 时尝试 JWT |
| Cookie 域/代理异常 | 否 | 是 | 可临时回退 JWT 路径（AUTH_SESSION_ENABLED=false） |

---
## 4. 实施 Checklist（按模块）

### 4.1 auth-app-backend
- Infra/Config
  - [ ] 新增/暴露 Redis 与 Session 相关配置。
  - [ ] 新增 RedisService、SessionStorageService；TokenStorage 改 Redis。
- 登录/刷新/登出
  - [ ] 登录成功：写 Redis session + Set-Cookie（SessionId）。
  - [ ] 刷新：读取 session/refresh，更新 Redis，返回/或不返回新 token（按开关）。
  - [ ] 登出：删 session，清 Cookie，refresh 入黑名单。
- /auth/me & Guard
  - [ ] 新 Guard（SessionOrJwt），优先 Cookie→Redis，回退 Bearer。
  - [ ] /auth/me 返回用户信息，Cookie 不存在或过期→401。
- 魔法链接/TOTP/恢复
  - [ ] 最终落点统一走“创建 session + 写 Cookie”。
- 日志/监控
  - [ ] 不打印敏感 token；关键埋点：登录成功/失败、/auth/me 延迟、Redis 错误。

### 4.2 llmops-app-bff / incubator-app-bff / portal-bff
- [ ] ConfigMap 增加 AUTH_SERVICE_URL。
- [ ] AuthClient 统一调用 `/auth/me`，原样转发 Cookie（必要时转发 Authorization 兼容）。
- [ ] 路由中间件依赖 AuthClient，不再本地验证 JWT（或标记为 Deprecated）。
- [ ] 可选本地短 TTL 缓存 session_id→user。

### 4.3 SSR（auth-app-front 起）
- [ ] 登录后不在 Pinia/localStorage 持久化 access/refresh，依赖 HttpOnly Cookie。
- [ ] SSR 服务端中间件：读 Cookie→调用 BFF `/me`→渲染用户态。
- [ ] 清理前端主动拼 Authorization header 的路径（或降级为走 BFF）。
- [ ] 登出流程：调用登出接口，清 Cookie，重定向登录。

### 4.4 基础设施
- [ ] Redis 部署与监控。
- [ ] Ingress Cookie 策略（Domain/SameSite/Secure），HTTPS 强制。
- [ ] CORS（若有跨站 XHR）：允许可信域名，`credentials: true`。

---
## 5. 监控与验证

### 5.1 指标
- /auth/me 延迟、QPS、错误率（4xx/5xx）。
- 登录成功/失败计数，刷新成功/失败。
- Redis：连接数、延迟、内存占用、key 数量。
- 401 比例：灰度阶段关注 Cookie 相关 401 激增。

### 5.2 日志要点
- 登录失败原因（密码错误/用户不存在/禁用/TOTP 未通过）。
- /auth/me 失败原因（无 Cookie/Session 过期/黑名单/Redis 不可用）。
- 刷新/撤销日志（不含敏感 token 内容）。

### 5.3 最小回归用例
- 登录（用户名密码、魔法链接、TOTP）。
- /auth/me：有 Cookie → 200，Cookie 失效 → 401，被踢后 → 401。
- 刷新：过期 access + 有效 refresh → 新 access；refresh 失效 → 401。
- 登出：当前端/多端；踢全端（若实现）。
- BFF 受保护路由：有 Cookie 正常，无 Cookie 401。
- 跨子应用 SSO：在一个应用登录，访问另一个无需重登。

---
## 6. 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Redis 不可用/高延迟 | 全部认证受阻/超时 | 本地短 TTL 缓存；快速失败；回退 JWT 路径；监控告警 |
| Cookie 域/SameSite 配置错误 | 大面积掉登录/401 | 灰度前在预发验证；必要时回退 SameSite=Lax 或关闭 Session |
| 双通道兼容期漏测 | 某些路径仍依赖 JWT，Cookie 未携带 | 保留 Bearer 回退；用兼容矩阵排查；日志聚类发现未携带 Cookie 的请求 |
| Set-Cookie 被代理改写 | 登录失效 | 检查 Ingress/Traefik 配置；抓包验证 |
| 黑名单/踢人未生效 | 安全风险 | 黑名单存 Redis + TTL；验证时必查黑名单 |

---
## 7. 建议的发布节奏（参考）
1) Dev/Stage：全开 Session + 保留 JWT 返回，完成回归。  
2) Pre-prod：小流量灰度，监控 /auth/me 延迟/401。  
3) Prod：扩大流量；确认 BFF/SSR 全适配后，考虑关闭响应体 JWT（若不再需要）。  
4) 稳定后：评估是否关闭 Bearer 兼容入口（取决于是否还有旧客户端）。  

---
以上为补充的细化版，便于直接按清单实施、灰度与回滚。确认后可据此执行。  

