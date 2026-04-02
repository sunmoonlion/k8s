# auth-integration-template

新业务应用接入 auth-app OIDC 的标准模板。
适用于：Python（Flask）后端 + Nuxt 4 前端（BFF 模式）技术栈。

---

## 架构一句话说明

```
浏览器
  │ GET /api/auth/login
  ▼
Nuxt BFF（server route）── PKCE ──▶ auth-app-backend /authorize
                                           │ 302 ▶ auth-app-frontend 登录页
                                           │ 用户提交表单
                                           ▼
                                    auth-app POST /authorize
                                           │ 302 ▶ /auth/callback?code=...
  ◀────────────────────────────────────────┘
Nuxt BFF /auth/callback
  │ 换 token（POST /token）
  │ 写 HttpOnly Cookie（{app}_session）
  │ 302 ▶ /
  ▼
页面请求 ── server middleware 注入 accessToken
  │
  ▼
Python 后端 API（Flask）
  │ 读 Authorization: Bearer <JWT>
  │ @login_required 装饰器
  │ JWKS 拉公钥验签（RS256 + aud + iss）
  ▼
返回数据
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

### 第 2 步：Python 后端

根据框架选择对应模板：

#### Flask（`flask-backend/`）

1. 把 `flask-backend/jwks_auth.py` 复制到工具目录（如 `common/utils/`）
2. 在 Flask config 中添加三个变量（见 `flask-backend/config_example.py`）
3. 用装饰器保护接口：
   ```python
   from common.utils.jwks_auth import login_required, login_optional

   @login_required
   def get_profile():
       return {'user_id': g.user_id}   # g.user_id / g.user_payload
   ```

#### NestJS（`nestjs-backend/`）

1. 把 `nestjs-backend/` 下五个文件复制到项目的 `src/auth/` 目录
2. 在 `.env` 中设置三个变量（见 `nestjs-backend/config_example.ts`）
3. 在 `AppModule` 中注册为全局 Guard：
   ```typescript
   // app.module.ts
   import { APP_GUARD } from '@nestjs/core';
   import { AuthModule } from './auth/auth.module';
   import { JwksGuard } from './auth/jwks.guard';

   @Module({
     imports: [ConfigModule.forRoot({ isGlobal: true }), AuthModule],
     providers: [{ provide: APP_GUARD, useClass: JwksGuard }],
   })
   export class AppModule {}
   ```
4. 用 `@CurrentUser()` 取用户信息，`@Public()` 跳过鉴权：
   ```typescript
   import { CurrentUser, JwtPayload } from './auth/current-user.decorator';
   import { Public } from './auth/public.decorator';

   @Get('/profile')
   getProfile(@CurrentUser() user: JwtPayload) {
     return { userId: user.sub, role: user.role };
   }

   @Public()
   @Get('/health')
   health() { return 'ok'; }
   ```

#### FastAPI（`fastapi-backend/`）

1. 把 `fastapi-backend/jwks_auth.py` 和 `fastapi-backend/config_example.py`（重命名为 `config.py`）复制到项目
2. 在 `.env` 中设置三个变量（与 Flask 版本相同）
3. 用 `Depends` 注入用户信息：
   ```python
   from fastapi import Depends
   from .jwks_auth import require_user, optional_user, CurrentUser

   @router.get("/profile")
   def get_profile(user: CurrentUser = Depends(require_user)):
       return {"user_id": user.user_id}   # user.user_id / user.role / user.payload

   @router.get("/feed")
   def get_feed(user = Depends(optional_user)):
       # user 为 None 表示匿名
   ```

### 第 3 步：Nuxt BFF

把 `nuxt-bff/` 下的文件复制到项目，然后**全局搜索替换**以下占位符：

| 占位符 | 替换为 | 说明 |
|--------|--------|------|
| `{APP_NAME}` | 如 `myapp` | 用于 Cookie 名，全小写 |
| `{APP_AUDIENCE}` | 如 `myapp-api` | 与 Python 后端 `AUTH_JWT_AUDIENCE` 一致 |

完成后：
- `server/api/auth/login.get.ts` → 发起 OIDC，`aud` 参数改为 `{APP_AUDIENCE}`
- `server/routes/auth/callback.get.ts` → Cookie 名改为 `{APP_NAME}_session`
- `server/api/auth/logout.post.ts` → Cookie 名同上
- `server/middleware/auth.ts` → Cookie 名同上

### 第 4 步：Nuxt 环境变量

在 `nuxt.config.ts` 的 `runtimeConfig` 中添加（见 `nuxt-bff/nuxt.config.snippet.ts`）：

```
AUTH_BACKEND_URL=http://auth-app-backend:3030/api/v1
AUTH_CLIENT_ID=myapp-bff
AUTH_CLIENT_SECRET=your-secret-here
SESSION_SECRET=random-32-char-string
```

---

## 文件说明

```
auth-integration-template/
├── README.md                        本文件
├── scripts/
│   └── register-client.sh           向 auth-app 数据库注册新客户端
├── flask-backend/                   Flask 技术栈
│   ├── jwks_auth.py                 装饰器模式：@login_required / @login_optional
│   └── config_example.py            Flask config 三个必填变量
├── fastapi-backend/                 FastAPI 技术栈
│   ├── jwks_auth.py                 依赖注入模式：Depends(require_user)
│   └── config_example.py            pydantic-settings 配置（重命名为 config.py 使用）
├── nestjs-backend/                  NestJS 技术栈
│   ├── jwks.service.ts              JWKS 拉取 + 缓存
│   ├── jwks.guard.ts                Guard：验签 + 写 request.user
│   ├── current-user.decorator.ts    @CurrentUser() 参数装饰器
│   ├── public.decorator.ts          @Public() 跳过鉴权
│   ├── auth.module.ts               模块（导入到 AppModule）
│   └── config_example.ts            .env 变量说明 + AppModule 注册示例
└── nuxt-bff/
    ├── nuxt.config.snippet.ts        runtimeConfig 片段
    ├── server/
    │   ├── middleware/
    │   │   └── auth.ts               读 session Cookie，注入 accessToken，自动刷新
    │   ├── api/auth/
    │   │   ├── login.get.ts          发起 OIDC + PKCE 授权
    │   │   └── logout.post.ts        撤销 token，清 Cookie
    │   └── routes/auth/
    │       └── callback.get.ts       OAuth 回调：code 换 token，写会话 Cookie
```

---

## 关键约定（不要改）

- **redirect_uri 必须放在 `server/routes/`**，不能放 `server/api/`——OAuth 回调地址是 `/auth/callback`（无 `/api` 前缀）
- **Cookie 必须 HttpOnly**，不要把 access_token 暴露给浏览器 JS
- **client_secret 只在 BFF server 端使用**，不要出现在前端代码或客户端 bundle 里
- **`AUTH_JWT_AUDIENCE` 要与 BFF login 时传的 `aud` 参数一致**，否则 Flask 验签会失败
- PKCE state / verifier Cookie 的 5 分钟 TTL 不要延长（授权码有效期对齐）

---

## 已接入的 app

| App | client_id | audience | 前端 repo |
|-----|-----------|----------|-----------|
| toutiao-front | `toutiao-bff` | `toutiao-api` | toutiao/toutiao-front |

新 app 接入后在此表追加。
