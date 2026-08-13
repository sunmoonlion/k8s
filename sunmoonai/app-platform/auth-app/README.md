# auth-app

`auth-app` 是 App Platform 的身份 Provider 部署单元。当前且唯一活动组件是 Casdoor：

```text
auth-app/
├── casdoor/
└── deploy-auth-app-all/
```

历史独立认证 Backend/Frontend 已归档到 `repo-backup`，不再部署、配对或参与登录链。

## 职责边界

Casdoor 负责用户、组织、应用、OIDC discovery、授权码和 token 颁发。每个领域 App 的统一
FastAPI Backend 负责自己的 Admin/Web OIDC callback、session、CSRF、scope 与资源授权；两个
Next.js 前端不持有 Casdoor client secret、OIDC token 或数据库凭据。

每个 App 的 Admin 和 Web 必须使用独立 client、redirect URI、cookie、session namespace、scope
和 Origin policy。Casdoor 是身份提供方，不是领域权限和领域数据所有者。

## 部署

App 级入口只调用 Casdoor，不再动态扫描目录：

```bash
./deploy-auth-app-all/deploy-auth-app-all.sh --cluster KIND status
./deploy-auth-app-all/deploy-auth-app-all.sh --cluster KIND deploy
```

Casdoor 的环境差异、数据库 bootstrap、Helm values、Secret、Ingress 与严格 TLS 配置均位于
`casdoor/`。Secret 值不得进入 Git。
