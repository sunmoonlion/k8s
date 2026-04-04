# auth-integration-template

新业务应用接入 auth-app OIDC 的标准模板。

---

## ┌─────────────────────────────────────────────────────────────────┐
## │          nuxt-bff 模式 vs vite-spa 模式：核心区别                  │
## └─────────────────────────────────────────────────────────────────┘

```
╔══════════════════════════════════╦══════════════════════════════════╗
║         nuxt-bff 模式            ║       vite-spa + 后端模式         ║
╠══════════════════════════════════╬══════════════════════════════════╣
║ 前端框架   Nuxt 4（SSR/SPA）      ║ Vite（纯 SPA，无 SSR）            ║
╠══════════════════════════════════╬══════════════════════════════════╣
║ PKCE 生成  Nuxt server（服务端）  ║ 自有后端（服务端）                 ║
╠══════════════════════════════════╬══════════════════════════════════╣
║ token 存储 Redis（Nitro storage） ║ Redis（后端管理）                  ║
╠══════════════════════════════════╬══════════════════════════════════╣
║ 浏览器持有 UUID session Cookie    ║ UUID session Cookie               ║
║            （HttpOnly）          ║ （HttpOnly）                       ║
╠══════════════════════════════════╬══════════════════════════════════╣
║ access_token 在浏览器？ ✗ 否      ║ access_token 在浏览器？ ✗ 否      ║
╠══════════════════════════════════╬══════════════════════════════════╣
║ client_secret 在哪？              ║ client_secret 在哪？              ║
║   Nuxt server env（安全）         ║   自有后端 env（安全）             ║
╠══════════════════════════════════╬══════════════════════════════════╣
║ 适用场景   全栈 Nuxt 应用         ║ 前后端分离（React/Vue SPA + API） ║
╠══════════════════════════════════╬══════════════════════════════════╣
║ 后端角色   Nuxt server 同时是 BFF ║ 需要独立后端（Flask/FastAPI/NestJS）║
╚══════════════════════════════════╩══════════════════════════════════╝
```

> **两种模式安全等级相同**：token 都不落浏览器，cookie 都是 HttpOnly UUID。
> 区别只在工程结构——Nuxt 项目选 nuxt-bff，纯 SPA 项目选 vite-spa。

---

## nuxt-bff 模式流程

```
浏览器
  │ GET /api/auth/login
  ▼
Nuxt server（生成 PKCE）──▶ auth-app-backend /authorize
                                    │ 302 ▶ auth-app-frontend 登录页
                                    │ 用户提交表单
                                    ▼
                             auth-app POST /authorize
                                    │ 302 ▶ /auth/callback?code=...
  ◀──────────────────────────────────┘
Nuxt server /auth/callback
  │ 换 token → 存 Redis → 写 HttpOnly Cookie（toutiao_session=<uuid>）
  │ 302 ▶ /
  ▼
useFetch('/api/auth/me')
  → server middleware 读 Cookie → Redis 取 token → 注入 event.context.accessToken
  → API handler 转发 Bearer token 给 Python/NestJS 后端
```

---

## vite-spa 模式流程

```
SPA
  │ location.href = '/api/auth/login'（自有后端）
  ▼
后端 GET /api/auth/login（生成 PKCE，存 Redis，Set-Cookie: oidc_pkce=<pkce_id>）
  │ 302 ▶ auth-app-backend /authorize
  ▼
auth-app 登录页 → 用户提交表单
  │ 302 ▶ SPA /auth/callback?code=...&state=...
  ▼
SPA /auth/callback 页面（取 code + state）
  │ POST /api/auth/callback（自有后端，携带 oidc_pkce Cookie）
  ▼
后端 POST /api/auth/callback
  │ 读 pkce_id Cookie → Redis 取 verifier → 校验 state → 换 token
  │ 存 Redis → 写 HttpOnly Cookie（myapp_session=<uuid>）
  ▼
SPA fetch('/api/auth/me', { credentials: 'include' })
  → 后端读 Cookie → Redis 取 token → 调 auth-app /auth/me → 返回用户
```

---

## 接入步骤（每个新 app 做一次）

### 第 1 步：在 auth-app 注册 OAuth 客户端

执行 `scripts/register-client.sh`：

```bash
APP_NAME=myapp \
CLIENT_ID=myapp-bff \
CLIENT_SECRET=your-secret-here \
REDIRECT_URI=https://myapp.example.com/auth/callback \
DB_URL=postgresql://user:pass@host:port/auth_db \
bash scripts/register-client.sh
```

或者手动在 `OAuthClient` 表插入（字段说明见脚本注释）。

---

### 第 2 步：选择前端模式

#### ▶ 选 nuxt-bff 模式

把 `nuxt-bff/` 下的文件复制到项目，**全局替换**以下占位符：

| 占位符 | 替换为 | 说明 |
|--------|--------|------|
| `myapp_session` | 如 `toutiao_session` | Cookie 名，全小写 |
| `myapp-api` | 如 `toutiao-api` | JWT audience，与后端 AUTH_JWT_AUDIENCE 一致 |
| `bff:toutiao:` | 如 `bff:myapp:` | Redis key 前缀（在 nuxt.config.ts 中） |

设置 `.env`（服务端不暴露给浏览器）：

```
AUTH_BACKEND_URL=http://auth-app-backend:3030/api/v1
AUTH_CLIENT_ID=myapp-bff
AUTH_CLIENT_SECRET=your-secret-here
SESSION_SECRET=random-32-char-string
REDIS_URL=redis://:password@redis-host:6379/0
```

#### ▶ 选 vite-spa 模式

**SPA 侧**（把 `vite-spa/src/` 下文件复制到项目）：

1. 复制 `vite-spa/env.example` 为 `.env.local`，设置 `VITE_BFF_BASE_URL`（同源留空）
2. 在 Vue Router 注册回调路由：
   ```typescript
   { path: '/auth/callback', component: () => import('./pages/AuthCallback.vue') }
   ```
3. 在路由守卫 `authGuard.ts` 中注册（见文件注释）
4. 在 App.vue / 布局组件的 `onMounted` 中调用 `fetchUser()` 恢复登录态

**后端侧**（从 `vite-spa-backend/` 选对应框架）：

| 框架 | 文件 |
|------|------|
| Flask   | `vite-spa-backend/flask/auth_routes.py` |
| FastAPI | `vite-spa-backend/fastapi/auth_router.py` |
| NestJS  | `vite-spa-backend/nestjs/auth.controller.ts` + `session.service.ts` + `auth.module.ts` |

设置后端 `.env`：

```
AUTH_BACKEND_URL=http://auth-app-backend:3030/api/v1
AUTH_CLIENT_ID=myapp-bff
AUTH_CLIENT_SECRET=your-secret-here
AUTH_REDIRECT_URI=https://myapp.example.com/auth/callback
AUTH_JWT_AUDIENCE=myapp-api
AUTH_SESSION_COOKIE=myapp_session
REDIS_URL=redis://:password@redis-host:6379/0
```

---

### 第 3 步：API 后端 JWT 验签

如果 API 后端独立于 BFF 后端（常见于 Nuxt BFF 模式），根据框架选择模板：

#### Flask（`flask-backend/`）

```python
from common.utils.jwks_auth import login_required, login_optional

@login_required
def get_profile():
    return {'user_id': g.user_id}   # g.user_id / g.user_payload
```

#### FastAPI（`fastapi-backend/`）

```python
from .jwks_auth import require_user, CurrentUser

@router.get("/profile")
def get_profile(user: CurrentUser = Depends(require_user)):
    return {"user_id": user.user_id}
```

#### NestJS（`nestjs-backend/`）

```typescript
@Get('/profile')
getProfile(@CurrentUser() user: JwtPayload) {
  return { userId: user.sub }
}

@Public()
@Get('/health')
health() { return 'ok' }
```

在 `AppModule` 注册为全局 Guard（见 `nestjs-backend/config_example.ts`）。

---

## 文件说明

```
auth-integration-template/
├── README.md                          本文件
├── scripts/
│   └── register-client.sh             向 auth-app 数据库注册新客户端
│
├── flask-backend/                     【API 后端 JWT 验签】Flask
│   ├── jwks_auth.py                   @login_required / @login_optional
│   └── config_example.py              三个必填变量
├── fastapi-backend/                   【API 后端 JWT 验签】FastAPI
│   ├── jwks_auth.py                   Depends(require_user)
│   └── config_example.py
├── nestjs-backend/                    【API 后端 JWT 验签】NestJS
│   ├── jwks.service.ts
│   ├── jwks.guard.ts
│   ├── current-user.decorator.ts
│   ├── public.decorator.ts
│   ├── auth.module.ts
│   └── config_example.ts
│
├── nuxt-bff/                          【前端模式一】Nuxt 4 BFF
│   ├── nuxt.config.snippet.ts         runtimeConfig + Nitro Redis storage
│   ├── app/composables/
│   │   └── useAuth.ts                 登录态管理（含 SSR Cookie 转发）
│   └── server/
│       ├── middleware/auth.ts         读 session Cookie，注入 accessToken，自动刷新
│       ├── api/auth/login.get.ts      发起 OIDC + PKCE
│       ├── api/auth/logout.post.ts    撤销 token，清 Redis + Cookie
│       └── routes/auth/callback.get.ts  OAuth 回调：code 换 token，写 Redis session
│
├── vite-spa/                          【前端模式二】Vite 纯 SPA
│   ├── env.example                    仅一个变量：VITE_BFF_BASE_URL
│   └── src/
│       ├── composables/useAuth.ts     调用后端 /api/auth/*，无 token 落浏览器
│       ├── pages/AuthCallback.vue     /auth/callback 页面，POST code+state 给后端
│       └── router/authGuard.ts        路由守卫
│
└── vite-spa-backend/                  【vite-spa 配套后端】三选一
    ├── flask/
    │   ├── auth_routes.py             Flask Blueprint：login/callback/me/logout
    │   └── config_example.py          环境变量说明 + CORS 注册示例
    ├── fastapi/
    │   ├── auth_router.py             FastAPI Router：login/callback/me/logout（async）
    │   └── config_example.py          环境变量说明 + CORS 注册示例
    └── nestjs/
        ├── session.service.ts         Redis session 管理（PKCE + OAuth session）
        ├── auth.controller.ts         NestJS Controller：login/callback/me/logout
        ├── auth.module.ts             Module（导入到 AppModule）
        └── config_example.ts          环境变量说明 + main.ts Cookie/CORS 配置
```

---

## 关键约定（不要改）

- **redirect_uri 必须是 SPA 侧路由**（浏览器能访问的地址），后端 callback POST 端点不是 redirect_uri
- **Cookie 必须 HttpOnly**，不要把 access_token 暴露给浏览器 JS
- **client_secret 只在服务端使用**，不要出现在前端代码或客户端 bundle 里
- **vite-spa fetch 必须带 `credentials: 'include'`**，否则 Cookie 不随请求发送
- **跨域后端必须配 CORS `credentials: true`**，且 `Access-Control-Allow-Origin` 不能是 `*`

---

## 已知坑（联调 toutiao-app-front 时发现，新 app 接入前必读）

### 1. auth-app-backend `.env` 必须设置正确的 OIDC_DEFAULT_AUDIENCE

`auth-app-backend/.env` 中的 `OIDC_DEFAULT_AUDIENCE` 必须与本 app 注册时的 audience 一致。

```env
OIDC_DEFAULT_AUDIENCE=myapp-api   # ← 与 register-client.sh 里的 audience 参数一致
```

**原因**：auth-app-backend 在 Bearer Token 路径（`GET /auth/me`）验证 JWT 时，用此值做 audience 校验。不一致则验签失败，返回 401 "Invalid token"，且错误被吞掉不报原因。

> auth-app-backend 当前仅支持单一 audience 验证。多 app 共用同一 auth-app-backend 时，
> 所有 app 的 audience 必须相同，或改造 `verifyAccessToken` 支持 audience 列表。

### 2. Nuxt SSR 阶段 useFetch 不自动携带 Cookie

`useAuth.ts` 中调用 `useFetch('/api/auth/me')` 时，**SSR 阶段不会自动把浏览器 Cookie 带给内部 API**，
导致服务端渲染时永远返回未登录状态。

已在模板 `nuxt-bff/app/composables/useAuth.ts` 中修复（`useRequestHeaders(['cookie'])`），直接使用即可。

### 3. auth-app-backend TokenStorageService 缺 isBlacklisted() 方法（已修复）

auth-app-backend `src/common/services/token-storage.service.ts` 中 `isBlacklisted()` 方法
曾未实现，导致 `/auth/me` Bearer 路径运行时抛出 "isBlacklisted is not a function"。
已在 auth-app-backend 中修复，使用现有版本无需关注。

---

## 已接入的 app

| App | client_id | audience | 前端 repo | 模式 |
|-----|-----------|----------|-----------|------|
| toutiao-front | `toutiao-bff` | `toutiao-api` | toutiao/toutiao-app-front | nuxt-bff |

新 app 接入后在此表追加。
