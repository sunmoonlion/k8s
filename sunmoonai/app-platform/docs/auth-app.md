# Auth App

Auth App 当前是 Casdoor 的专用部署边界，不是普通领域 App，也不套用“一 Backend + 两个
Next.js 前端”的业务模板。

## 当前拓扑

```text
auth-app
├── casdoor
└── deploy-auth-app-all
```

- Casdoor：平台 OIDC Provider，管理用户、组织、应用、服务身份和 token 颁发；
- deploy-auth-app-all：只代理 Casdoor 的 deploy/upgrade/uninstall/status/logs；
- 历史认证 Backend/Frontend：已归档到 `repo-backup`，不属于当前运行拓扑。

## 与业务 App 的边界

Info、Knowledge、Investment 及未来 App 的统一 FastAPI Backend 各自负责 Admin/Web 两个浏览器
表面的 OIDC callback、服务端 session、CSRF、scope 和领域资源授权。Casdoor 不持有领域数据，
也不替业务 Backend 作资源所有权判断。

Admin 与 Web 使用独立 OIDC client、redirect URI、cookie、session namespace、scope 与 Origin
policy。浏览器不接触 client secret、Provider token、服务凭据或数据库凭据。

## 生产要求

- Authorization Code + PKCE，严格校验 issuer、audience、nonce、state、有效期和签名；
- Casdoor、回调和业务 Origin 全部使用严格 TLS；
- 密钥进入受控 Secret 管理，支持轮换与吊销；
- 登录、登出、禁用、授权变更和管理操作可审计；
- NetworkPolicy 只允许声明的 Backend backchannel 与管理入口访问 Casdoor。
