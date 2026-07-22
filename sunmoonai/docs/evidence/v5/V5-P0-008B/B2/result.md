# V5-P0-008B/B2 Nest BFF Identity + Next DAL/DTO 证据

状态：`ACCEPTED / B3_NEXT`

日期：2026-07-22（Asia/Shanghai）

## 1. 固定输入与输出

| 单元 | B1 输入 | B2 固定提交 |
| --- | --- | --- |
| `tpl-web-backend`（当前仍为 Nest） | `f5bedfb` | `839ea091c602985f60020977a5d2beb14ff7df88` |
| `tpl-web-frontend`（Next） | `f5340ac` | `b1730a6f6d63bee6247c459868c9b9df3fa98ce5` |
| `tpl-app` gitlink | `fe29739` | `4cae61d352273fdac2fa9c6fd8992031067bdde4` |

本包没有改名仓库、没有创建 FastAPI Web Backend、没有修改或部署 Info、Knowledge、
Research 的业务 Web 仓。当前 `tpl-web-backend` 仍是 B3/B4 的 Nest 输入，只有 B4 完成
真实安全、部署、回滚和不可变摘要门禁后才允许改名为 `tpl-web-backend-nest`。

## 2. Nest 身份内核

已建立：

- Authorization Code + PKCE S256；state、nonce、code verifier 只保存于 Redis
  transaction，并通过 `GETDEL` 原子一次性消费；callback 重放只有一个成功者。
- Discovery/JWKS 使用有界超时、禁止自动 redirect、固定 provider host/port；ID Token
  使用 JOSE 本地 JWK 集校验签名、精确 issuer、单一 audience、iat/exp 和 nonce；未知
  `kid` 只允许一次强制刷新。
- session cookie 为 Host-only、HttpOnly、Secure（生产强制）、SameSite=Lax；Redis session
  只保存最小 Principal 与 CSRF token，不保存 access/refresh/id token。
- Principal 由 issuer+subject 生成稳定 UUID；provider role/scope 只经过本地 allowlist，
  session 同时绑定 app、surface、audience 和 policy version。
- unsafe method 同时校验 Origin allowlist 与 CSRF token；logout 只允许 POST；return URL
  只接受显式允许的站内 path。
- 全局 SessionGuard 与稳定错误封装已启用；错误只暴露 reason code、稳定消息与
  operation id，不返回 provider 响应、token、cookie 或堆栈。

## 3. Next server-only DAL 与浏览器 DTO

已建立：

- SSR route 通过 `server-only` DAL 将请求 Cookie 转给配对 Web Backend 的
  `GET /api/auth/me`；只有 401 被解释为匿名，网络错误、非预期状态和 DTO 漂移均 fail
  closed。
- 浏览器会话使用严格 Zod DTO，限定 `surface=web`、预期 app、最小用户字段和 CSRF
  token；unknown field 被拒绝，因此 provider token 不能越过浏览器边界。
- Dashboard 在服务端执行 session check，并保持 dynamic/no-store；匿名请求在 SSR 阶段
  跳转登录，不依赖 hydration 后的客户端修正。
- logout 使用同源 POST + CSRF；旧 Axios 通用浏览器 client 与第二套客户端 session
  redirect/store 已删除。
- `DEPLOYMENT_ENV` 与 Next 构建模式显式分离：生产部署必须 HTTPS；受控 E2E 只允许
  loopback HTTP，不以测试环境放松 Kubernetes 生产契约。

共享 contract 新增 `browser-session.vectors.json`，并补齐
`provider_unavailable` reason code。负向向量覆盖 provider token 泄漏和 Admin session 被
Web consumer 接受。

## 4. 运行门禁

Nest：

```bash
cd /home/zymun/tpl-app/tpl-web-backend/app
pnpm check
```

结果：typecheck、scoped lint、29/29 unit、2/2 HTTP E2E、Nest/SWC 198 files build 全部
通过。

Next：

```bash
cd /home/zymun/tpl-app/tpl-web-frontend/app
pnpm check
pnpm test:e2e
```

结果：typecheck、lint、i18n（2 locales、39 keys）、22/22 unit/component、Next 16.2.2
production build、5/5 Playwright 全部通过。配对 E2E 明确验证：

- public route 可渲染；
- 匿名 Dashboard 在 SSR 授权边界被重定向；
- 只有 Nest contract fixture 验证 opaque session 后才渲染 workspace；
- not-found 与 runtime sitemap 正确。

本包使用的 provider/backend fixture 仅证明 B2 identity/consumer contract 与 SSR 配对，
不是 Casdoor 实际登录、真实业务 API、SSE 或生产流量证据。真实 Casdoor、双 Pod、KIND、
滚动/version-skew、回滚和 digest 属于 B4，不能从本结果推导为已完成。

## 5. 静态门禁

执行：

```bash
cd /home/zymun/k8s
python sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_008b_b2.py
```

结果：

```json
{"backend_commit":"839ea091c602985f60020977a5d2beb14ff7df88","backend_e2e_tests":2,"backend_unit_tests":29,"business_web_repositories_unchanged":true,"frontend_commit":"b1730a6f6d63bee6247c459868c9b9df3fa98ce5","frontend_tests":22,"paired_playwright_tests":5,"parent_commit":"4cae61d352273fdac2fa9c6fd8992031067bdde4","provider_tokens_exposed":false,"result":"passed","secrets_printed":false,"task":"V5-P0-008B-B2-source"}
```

## 6. 退出结论与下一游标

B2 的实现、测试、契约、固定 commit 和静态证据齐全，状态为 `ACCEPTED`。P0-008B 整体
仍为 `IN_PROGRESS`；唯一下一代码任务变为 B3：中性 UI、typed query、SSE reconcile、
Citation/HITL/error contract 与 Next+Nest 配对。B4 前继续禁止仓库改名，B5 前禁止创建
FastAPI `tpl-web-backend`，B6 前禁止同步三个实例 App。
