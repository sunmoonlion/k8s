# Casdoor 认证架构

> 本文说明 Casdoor 在 app-platform 中的定位、接入方式及各组件职责边界。

---

## 1. Casdoor 是什么

Casdoor 是一个开源的 OIDC/OAuth 2.0 认证服务，提供：

- 登录页面（用户名密码、社交登录、MFA 等）
- 用户管理（注册、权限、组织）
- 标准 OIDC token 颁发（access_token、id_token、refresh_token）
- 应用管理（每个接入方对应一个 Application，有独立的 clientId/clientSecret）

**Casdoor 只负责颁发 token**，颁发之后 token 如何存储、如何验证，由接入方的业务应用自己决定。

---

## 2. 业务应用的两种接入形态

> **说明**：这里的 BFF 指的是**业务应用自身的 BFF 层**（如 Nuxt/Next.js 的 server 层），不是 Casdoor 的任何组件。Casdoor 只是 OIDC 提供方，不参与 BFF 逻辑。

### 2.1 业务前端有 BFF（如 Nuxt SSR、Next.js）

业务前端框架自带服务端层，可以在该层做 token 交换，OIDC 对接由**业务 BFF** 负责。

```
用户浏览器
  │
  ├─► Casdoor 登录页（跳转）
  │     │
  │     └─► 业务 BFF /auth/callback
  │               │  用 code 换 token（与 Casdoor 通信）
  │               │  将 token 存入 Redis
  │               └─► 下发 HTTP-only cookie（session_id）给浏览器
  │
  └─► 业务 BFF（业务请求）
            │  用 session_id 从 Redis 取 token，验证身份
            └─► 业务 API 后端（携带用户身份信息）
```

**结论**：业务 BFF 全权负责 OIDC 流程，业务 API 后端完全不参与登录，只处理业务逻辑。

### 2.2 业务前端无 BFF（纯 SPA，如 Vue + Vite）

没有业务服务端层，无法在前端侧做安全的 token 交换，OIDC 职能由业务后端承担。

```
用户浏览器
  │
  ├─► Casdoor 登录页（跳转）
  │     │
  │     └─► 业务后端 /auth/callback
  │               │  用 code 换 token（与 Casdoor 通信）
  │               │  将 token 存入 Redis
  │               └─► 下发 HTTP-only cookie（session_id）给浏览器
  │
  └─► 业务后端（业务请求，携带 cookie）
            │  用 session_id 从 Redis 取 token，验证身份
            └─► 返回业务数据
```

**结论**：业务后端需要接入 Casdoor SDK，负责完整 OIDC 流程。

---

## 3. OIDC Token 与业务 Session Token 的区别

| | OIDC Token（Casdoor 颁发） | 业务 Session Token（自签发） |
|---|---|---|
| 颁发方 | Casdoor | 业务后端 / BFF |
| 用途 | 证明用户已通过 Casdoor 认证 | 维持用户与业务系统的会话 |
| 验证方 | 负责 OIDC 对接的一方 | 业务后端自己 |

业务后端自签发的 session token，永远由它自己验证，与 Casdoor 无关。

---

## 4. Token 存储方式

### 4.1 服务端存储（推荐）

Token 存入 **Redis**，前端只持有 `session_id`（HTTP-only cookie）。

```
登录成功
  ├─► token 写入 Redis（key = session_id，设过期时间）
  └─► HTTP-only cookie 下发 session_id

后续请求
  ├─► 浏览器自动带 cookie（session_id）
  ├─► 后端用 session_id 从 Redis 取 token
  └─► 验证通过，处理业务
```

优点：
- XSS 无法窃取 token（cookie 是 HTTP-only）
- 可在服务端主动吊销（删除 Redis key）
- token 刷新对前端完全透明

### 4.2 客户端存储

Token 存在前端（localStorage 或普通 cookie），每次请求带 `Authorization: Bearer <token>`。

适用于对安全要求较低、架构简单的场景。

---

## 5. 完整决策树

```
业务前端有自己的 BFF 层？
├── 有（SSR 框架，如 Nuxt/Next.js）
│     └── 业务 BFF 负责 OIDC 对接，业务 API 后端不参与
│           └── Token 用 Redis 持久化？
│                 ├── 是 → Redis 存 token，前端只有 session_id（HTTP-only cookie）✅ 推荐
│                 └── 否 → Token 存前端
│
└── 无（纯 SPA，如 Vue + Vite）
      └── 业务 API 后端负责 OIDC 对接（需接入 Casdoor SDK）
            └── Token 用 Redis 持久化？
                  ├── 是 → Redis 存 token，前端只有 session_id（HTTP-only cookie）✅ 推荐
                  └── 否 → Token 存前端
```

---

## 6. 各组件职责边界

| 组件 | 职责 | 不做什么 |
|---|---|---|
| Casdoor | 登录页、颁发 OIDC token、用户与应用管理 | 不管业务 session |
| 业务 BFF（有时） | OIDC callback、换 token、存 Redis、管 session | 不处理业务数据 |
| 业务 API 后端 | 业务逻辑、验证 session | 有 BFF 时不碰 OIDC |
| Redis | 持久化 session token | — |
