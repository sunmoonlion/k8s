# ADR-0009：Admin、Web 与 Internal 是接口分面，不是三套应用层

- 状态：已接受
- 日期：2026-08-01

## 背景

同一个用例可能被管理前端、用户前端、Worker 或另一个 App 调用。按调用方复制 application
会造成规则漂移；完全不区分入口又会混淆浏览器身份、服务身份、CSRF 和资源授权。

## 决策

规范 HTTP 分面为：

```text
/api/admin/v1/...      管理浏览器表面
/api/web/v1/...        用户产品表面
/api/internal/v1/...   服务到服务能力
/api/auth/...          登录、回调与会话
/health/live
/health/ready
```

- 分面位于 interfaces 层，共享 application 用例；
- 只有业务语义、权限或事务边界确实不同才建立不同 command/query；
- Internal API 按提供方能力命名，例如 `ingestions`、`retrievals`、`citations`；
- 不按调用方命名 `/internal/info-app/...` 等路径；
- 调用方差异由 workload identity、subject、scope、资源策略和 consumer contract 表达；
- 浏览器使用 Casdoor Authorization Code + PKCE；
- Next.js session/BFF 与 FastAPI 最终授权分工必须有显式契约；
- Backend 必须复核资源所有权、Origin/CSRF、租户和工具权限；
- 浏览器、服务和数据库凭据禁止复用。

## 结果

接口表面可以独立演进，领域规则保持单一；服务消费者新增时不需要复制 provider API 目录。
