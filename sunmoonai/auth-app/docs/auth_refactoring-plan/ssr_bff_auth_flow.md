# SSR + BFF + Auth + 微服务 登录和渲染流程文档

本文档整理了我们讨论的 SSR、BFF、Auth 服务、多子域 Cookie、JWT 缓存以及微前端架构下的最佳实践，包括所有细节。

---

## 1. 核心机制

1. **浏览器只存 session_id / token 的引用**
   - Cookie 设置 HttpOnly，浏览器 JS 无法读取

2. **后端缓存存储 JWT / 用户信息**
   - Redis / Memcached / 数据库保存 JWT、用户信息、权限和过期时间
   - SSR 或 BFF 拿到 Cookie 后查询缓存获取真实 JWT 或用户信息

3. **Token 生命周期管理**
   - JWT 设置短期过期，refresh token 可长期保存于后端
   - 支持强制登出/踢人 → 后端直接删除缓存

4. **安全优势**
   - 浏览器无法直接读取 JWT → XSS 风险降低
   - SSR/BFF 使用后端缓存 JWT 调用微服务 → 安全可靠

---

## 2. 浏览器 Cookie 与跨子域

### **SameSite 设置**
- **Lax（默认）**：跨域普通请求不带 cookie，但 top-level GET 跳转带 cookie → SSR 场景足够
- **Strict**：任何跨域请求都不带 cookie → 高安全性，但不适合多子域登录
- **None**：允许所有跨站请求带 cookie（必须 Secure） → SPA 跨域 / SSO 必须

### **Domain 设置**
- `.example.com` → 所有子域共享 Cookie  
- 单独子域如 `auth.example.com` → 只能自己访问 Cookie

### **浏览器行为**
- HttpOnly Cookie JS 无法读取，但会随请求自动发送  
- SPA 跨域 POST / GET 需 SameSite=None + credentials + CORS  
- SSR 请求不受浏览器 SameSite / CORS 限制

---

## 3. SSR + BFF + Auth + 微服务流程

```text
Browser (访问 /dashboard)
   │  (带 HttpOnly Cookie: session_id)
   ▼
SSR (Node.js)
   │  接收请求头 Cookie
   │  可原样转发 Cookie 到 BFF
   ▼
BFF (/me 或 /auth/validate)
   │  两种模式：
   │     1. 内置 /me 验证逻辑（查询缓存/数据库）
   │     2. 调用 Auth Service 验证 cookie / session
   ▼
返回用户信息 / Access Token
   │
SSR 使用返回数据渲染页面
   ▼
Browser 显示完整 HTML 页面
```

### **说明**
- SSR 本身不会主动读取 Cookie，只是接收 HTTP 请求头并转发  
- BFF 可以自己验证 `/me` 或调用 Auth Service，推荐调用 Auth Service 以统一安全策略  
- SSR 拿到用户信息后渲染页面，浏览器前端 JS 不需要管理 token

---

## 4. BFF 调用模式对比

| 设计模式 | 描述 | 优点 | 缺点 |
|-----------|------|------|------|
| BFF 自己处理 `/me` | BFF 内部验证 cookie / session | 简单，减少网络调用 | 多 BFF 需重复认证逻辑，统一策略难 |
| BFF 调用 Auth Service | BFF 转发 cookie / session 给 Auth Service | Auth 集中管理，多 BFF 可复用，统一安全策略 | 增加一次网络请求 |

### **建议**
- 小型系统：BFF 自己处理 `/me` 可以  
- 多 BFF / 多子应用：推荐 BFF 调用 Auth Service，便于统一管理登录、登出、token refresh

---

## 5. SPA 场景注意事项

- 浏览器直接发起跨子域 AJAX / POST 请求，需要：
  1. Cookie: SameSite=None; Secure; HttpOnly
  2. 前端请求带 `credentials: include`
  3. 后端 CORS 配置 `Access-Control-Allow-Origin` 指定域 + `Access-Control-Allow-Credentials: true`
- 跨域 POST 会先发 OPTIONS 预检请求，预检成功后才携带 Cookie
- SSR 避免这些复杂问题 → 微前端架构推荐 SSR

---

## 6. SSR 与 SPA 对比

| 特性 | SSR | SPA |
|------|-----|-----|
| 是否受 SameSite 限制 | ❌ 不受 | ✅ 受 SameSite / CORS / credentials |
| 跨域 POST | ✅ 无问题 | ✅ 需 SameSite=None + credentials + CORS |
| Cookie 读取 | SSR 可转发或解析 | JS 无法读取 HttpOnly Cookie |
| 安全性 | 高 | 若使用 localStorage 存 JWT，风险较高 |
| 登录共享 | 简单，Domain=.example.com | 需 SameSite=None + credentials + CORS |

---

## 7. 核心结论

1. SSR 不直接读取 cookie，只接收并转发到 BFF / Auth 服务  
2. BFF 可选择内置 `/me` 或调用 Auth Service，推荐后者统一管理  
3. 浏览器只存 HttpOnly Cookie，JWT / token 真正内容存在后端缓存  
4. SSR 场景跨域 POST / GET 不受 SameSite / CORS 限制  
5. SPA 跨子域请求必须 SameSite=None + credentials + CORS  
6. 多子域登录共享：Cookie Domain 设置为顶级域名，SSR/BFF 使用缓存 JWT 或 session 验证身份

---

此文档覆盖了从浏览器到 SSR、BFF、Auth 服务及微服务的完整登录和渲染流程，以及 Cookie、JWT、跨域、SPA/SSR 场景的所有讨论内容。

