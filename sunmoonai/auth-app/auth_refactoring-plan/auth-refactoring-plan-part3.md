# Auth 统一认证重构方案（分段版 · Part 3：详细设计）

本部分给出更接近“设计说明书”的细节：关键数据结构、接口契约、时序流程，方便直接对照实现与评审。

---
## 1. Session 与 Redis 数据结构设计

### 1.1 Session 对象结构（Redis Value）
建议使用 JSON 序列化（或 msgpack），字段示例：

```json
{
  "session_id": "string",          // 冗余存一份，方便排查
  "user_id": 1,
  "username": "admin@example.com",
  "email": "admin@example.com",
  "full_name": "Admin",
  "is_active": true,
  "is_superuser": true,

  "access_token": "jwt-string",
  "refresh_token": "jwt-string",
  "access_expires_at": 1710000000,   // epoch 秒
  "refresh_expires_at": 1710600000,  // epoch 秒

  "created_at": 1709000000,
  "updated_at": 1709000000,
  "client_ip": "optional",
  "user_agent": "optional"
}
```

### 1.2 Redis Key 命名约定
- Session 主数据：
  - `session:{session_id}` → 上述 JSON，TTL = `SESSION_TTL_SECONDS`（通常与 refresh 一致或略短）
- 用户到 Session 映射（可选，但推荐）：
  - `user_sessions:{user_id}` → Set(session_id1, session_id2, ...)
  - 用于“踢出该用户所有设备”
- Token 黑名单：
  - `blacklist:{token}` → 任意值，TTL = token 剩余有效期
- 魔法链接 / 密码重置 / TOTP 等临时 token：
  - `magic_email:{email_token}` → { claim_token, fingerprint, expires_at }
  - `recovery:{recovery_token}` → { claim_token, fingerprint, expires_at }
  - `totp-setup:{username}` → { secret, expires_at }

---
## 2. 关键 HTTP 接口设计（auth-app-bff）

以下路径假定全局前缀 `/api`，版本 `v1`，实际以现有配置为准。

### 2.1 登录相关

#### 2.1.1 用户名/密码登录
- **URL**：`POST /api/v1/login/oauth`
- **请求（JSON 或 form-data，保持兼容）**：
```json
{
  "username": "user@example.com",
  "password": "password123"
}
```
- **行为**：
  1. 校验用户名/密码
  2. 如果启用 TOTP：返回短期临时 token（现有逻辑保留）
  3. 否则：
     - 生成 access_token / refresh_token
     - 生成 `session_id`
     - 写入 `session:{session_id}`
     - 设置 Cookie：`Set-Cookie: sunmoonai_session=<session_id>; HttpOnly; Secure; SameSite=Lax; Domain=.sunmoonai.com; Path=/`
  4. 返回体中：
     - 兼容期保留 `{access_token, refresh_token, token_type}`（方便旧前端/客户端）
     - 后续可通过配置开关关闭。

#### 2.1.2 魔法链接 & TOTP
- 保留现有接口形态（`/login/magic/:email`, `/login/claim`, `/login/totp`），只在“完成最终登录”的那一步：
  - 统一走“创建 session → 写 Redis → Set-Cookie”逻辑。

### 2.2 统一认证接口 `/auth/me`

- **URL**：`GET /api/v1/auth/me`
- **请求**：
  - 优先从 Cookie 中读取：`Cookie: sunmoonai_session=<session_id>`
  - 兼容支持：`Authorization: Bearer <access_token>`

- **行为**：
  1. 若存在 `sunmoonai_session`：
     - 从 Redis 取 `session:{session_id}`，若不存在/过期→401
     - 可选择检查 Redis 中的 access_expires_at，若 access 已过期但 refresh 仍有效：
       - 也可以在此处做被动刷新（取决于策略），或直接返回 401 由客户端走 refresh 流程。
  2. 若无 Cookie 且有 Bearer Token：
     - 验证 JWT 签名 + 过期
     - 检查 `blacklist:{token}` 是否存在
     - 可选：对照 Redis session 中是否仍然有效（更严格）
  3. 返回用户信息（不含密码等敏感字段），结构与 SSR/BFF 期待一致。

- **响应示例**：
```json
{
  "id": 1,
  "email": "user@example.com",
  "email_validated": true,
  "is_active": true,
  "is_superuser": false,
  "full_name": "User Name",
  "password": true,
  "totp": false
}
```

### 2.3 刷新 Token

- **URL**：`POST /api/v1/login/refresh`
- **请求**：
  - 优先 Cookie：`sunmoonai_session`
  - 或 Bearer：`Authorization: Bearer <refresh_token>`
- **行为**：
  1. 从 session 中取 refresh_token 或直接从 header 中读
  2. 验证 refresh_token → 签名/过期/黑名单
  3. 生成新的 access_token（必要时也可轮换 refresh_token）
  4. 更新 Redis 中 `session:{session_id}` 的 token 与过期时间
  5. 返回新的 token（兼容期），或者保持无感（仅在 Cookie/Session 中更新）。

### 2.4 登出与踢人

#### 2.4.1 当前端登出
- **URL**：`POST /api/v1/auth/logout`
- **行为**：
  1. 从 Cookie 取 session_id
  2. `DEL session:{session_id}`
  3. 从 `user_sessions:{user_id}` 中移除该 session_id
  4. 清 Cookie（Set-Cookie: Max-Age=0）

#### 2.4.2 管理员踢某用户所有设备（可选）
- **URL**：`POST /api/v1/auth/logout-all`
- **请求**：
```json
{ "user_id": 1 }
```
- **行为**：
  1. 检查当前调用者是否管理员
  2. 从 `user_sessions:{user_id}` 取出所有 session_id
  3. 逐个 `DEL session:{sid}`
  4. 删除 `user_sessions:{user_id}`

---
## 3. BFF 使用规范（以 llmops-app-bff 为例）

### 3.1 配置

```yaml
env:
  - name: AUTH_SERVICE_URL
    value: "http://auth-app-bff:3030"  # k8s Service
```

### 3.2 AuthClient 规范

伪代码（Python/FastAPI）：

```python
class AuthClient:
    def __init__(self, base_url: str):
        self.base_url = base_url

    async def get_current_user(self, request: Request) -> dict:
        # 1. 原样转发 Cookie
        cookies = request.headers.get("cookie")
        headers = {}
        if cookies:
            headers["Cookie"] = cookies

        # 2. 可按需转发 Authorization（兼容期）
        auth = request.headers.get("authorization")
        if auth:
            headers["Authorization"] = auth

        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{self.base_url}/api/v1/auth/me", headers=headers, timeout=5.0)
            resp.raise_for_status()
            return resp.json()
```

在路由中：

```python
@router.get("/protected")
async def protected_endpoint(
    request: Request,
    auth_client: AuthClient = Depends(get_auth_client),
):
    user = await auth_client.get_current_user(request)
    # 此处仅做授权逻辑，例如检查 user["is_superuser"]
    ...
```

---
## 4. SSR 使用规范（以 auth-app-ssr 为例）

### 4.1 登录页行为
- 前端提交用户名/密码到自身 BFF（或直接到 auth-app-bff）。
- 服务端拿到 200 + Set-Cookie 后：
  - SSR 负责重定向到首页/目标页
  - 不再在 Pinia/localStorage 中长期保存 JWT。

### 4.2 SSR 获取用户信息

Nuxt 3 示例（伪代码）：

```ts
// server/middleware/auth.global.ts
export default defineEventHandler(async (event) => {
  const req = event.node.req
  const res = event.node.res

  // 从请求中读取 Cookie，并调用对应 BFF 的 `/me`
  const cookies = req.headers.cookie || ""
  const { data: user } = await $fetch(`${BFF_URL}/me`, {
    headers: { cookie: cookies },
    credentials: "include",
  }).catch(() => ({ data: null }))

  // 挂到 event.context 里，后续页面可使用
  ;(event.context as any).user = user
})
```

页面中：

```ts
const user = useRequestEvent().context.user
if (!user) {
  // 重定向到登录
}
```

---
## 5. 时序示意（文字版）

### 5.1 登录（用户名/密码）

```text
Browser → SSR(auth-app-ssr) → Auth BFF(auth-app-bff)

1. Browser 提交表单 /login
2. SSR 接收到请求，转发到 Auth BFF /login/oauth
3. Auth BFF 验证密码 → 生成 JWT → 生成 session_id → Redis 写 session → Set-Cookie(sunmoonai_session)
4. SSR 收到响应（带 Set-Cookie），转发给浏览器
5. Browser 自动保存 HttpOnly Cookie
6. SSR 重定向到首页或目标页
```

### 5.2 访问受保护页面（跨子应用）

```text
Browser (带 Cookie: sunmoonai_session)
  → SSR (llmops-app-ssr)
    → BFF (llmops-app-bff)
      → Auth BFF (auth-app-bff /auth/me)

1. Browser 访问 llmops 页面，请求头带 Cookie
2. SSR 将 Cookie 转发给 BFF /me
3. BFF 将 Cookie 转发给 Auth BFF /auth/me
4. Auth BFF 从 Redis 读取 session，返回用户信息
5. BFF 根据用户信息做授权判断，返回给 SSR
6. SSR 用用户信息渲染页面
7. 页面返回给浏览器
```

---
## 6. 实施与评审要点

- **实现顺序**：严格按照 Part2 中 Phase 顺序，避免前端/BFF 先改导致无法认证。
- **开关控制**：
  - 可考虑加入开关：`AUTH_SESSION_ENABLED=true/false`，便于灰度回滚。
- **评审重点**：
  - 所有写 Cookie/读 Cookie 的地方是否统一使用 `SESSION_COOKIE_NAME`
  - Redis 操作是否有超时与错误处理（避免 Auth 崩溃）
  - 日志中避免打印敏感 token

当以上设计文档确认后，即可按 Phase 逐步在各项目中落实实现与回归。  

