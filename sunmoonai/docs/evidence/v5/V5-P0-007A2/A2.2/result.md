# V5-P0-007A2/A2.2 Identity/Data Foundation 施工证据

日期：2026-07-14  
状态：`ACCEPTED（2026-07-14；模板基础身份 consumer gate 已通过）`

## 本轮范围

只在 `tpl-app/tpl-admin-frontend` 完成通用身份/数据底座，不修改三个业务 App，不接入领域 DTO，不宣称业务迁移或完整身份安全验收。

## 已实现

- `/api/auth/me` contract version 1 归一化为模板 `AuthUser`；支持 actor、display name、email、roles、scopes、expires_at。
- 后端 HttpOnly session cookie 仍是唯一 session 持有者；CSRF token 只在内存保存，不写入 localStorage、sessionStorage 或 Zustand。
- unsafe `POST/PUT/PATCH/DELETE` 自动带 `X-CSRF-Token`；GET/HEAD/OPTIONS 不发送该头。
- `POST /api/auth/logout` 替代 GET logout；成功或失败都会清理内存 session 并返回登录页。
- TanStack Query 使用稳定的 `queryKeys.session`；loader 通过 `ensureQueryData` 复用身份缓存，logout 移除 session cache；业务资源 key 必须携带 scope。
- 401 清理内存 session；未认证 loader 使用相对 return URL 重定向到 `/login`。
- 每个 API 请求生成 `X-Correlation-ID`（调用方已有值时保留），错误只暴露结构化 message key/correlation id。

## 自动化验证

```text
pnpm typecheck => PASS
pnpm lint      => PASS
pnpm test      => PASS（7 files，22 tests）
pnpm build     => PASS（SPA Mode: Generated build/client/index.html）
pnpm test:e2e   => PASS（Chromium，5 tests；包含 POST logout smoke）
```

Clean-room（`/tmp/tpl-admin-frontend-clean.W3O5Bj`，2026-07-14）复验：

```text
pnpm install --frozen-lockfile --offline => PASS（369 packages）
pnpm typecheck                          => PASS
pnpm lint                               => PASS
pnpm test                               => PASS（7 files，22 tests）
pnpm build                              => PASS（SPA Mode: Generated build/client/index.html）
```

Vitest 输出的 jsdom CSS/getComputedStyle 与 React `act(...)` 为测试环境 warning，未产生失败；后续 Production Gate 仍需决定是否清理这些 warning。

Docker/Nginx candidate smoke（`tpl-admin-frontend:a22-candidate-20260714`，未推送）：

```text
GET /health                         => 200 OK
GET /                              => 200 React Router SPA HTML
container command -v node           => absent
nginx -t                            => successful
container cleanup                   => completed
```

响应同时包含 CSP、`X-Content-Type-Options`、`X-Frame-Options`、Referrer-Policy 和 Permissions-Policy。候选镜像未作为 release 固化。

## 严格 TLS 模板浏览器验收

2026-07-14 在清理旧的 `19082` 模板开发进程后，以新的 React 模板实例运行
`P0_BROWSER_FRONTEND_MODE=template`，并保持 `P0_BROWSER_STRICT_TLS=true`。
本次验证使用真实 Casdoor/KIND Info Admin Backend，且在回调后实际访问模板 `/`
并等待受保护的“管理首页”，因此验证了模板客户端的 `/api/auth/me` 消费，而不是
只验证一个静态 callback sink：

```text
task                         => V5-P0-005-browser
result                       => passed
authenticated_me             => 200
callback_one_time            => true
session_cookie_httponly      => true
transaction_cookie_consumed  => true
admin_role_and_scope         => true
csrf_negative_cases          => 4
csrf_positive_logout         => true
session_revoked_on_logout    => true
browser_cors_status          => 200
provider_material_exposed    => false
credentials_printed         => false
provider_tokens_printed      => false
provider_ui_ms               => 620
post-run residual processes  => none
post-run listeners 18082/19082=> none
```

随后以同一隔离模板实例运行三应用全量矩阵（`P0_BROWSER_APPS=info,knowledge,research`）：

```text
info primary                 => passed, /me=200, csrf_negative=4, logout=204/401
knowledge primary            => passed, /me=200, csrf_negative=4, internal_route=401, logout=204/401
research primary             => passed, /me=200, csrf_negative=4, logout=204/401
research secondary           => passed, /me=200, csrf_negative=4, logout=204/401
credentials/provider tokens  => never printed
template/port-forward cleanup=> no residual process or listener on 19082-19084/18082-18084
```

扩展 consumer 矩阵：

```text
Research owner isolation     => passed; owner read=200; cross-owner read=403
Research traffic restoration => passed; gate restored closed
Info expired Redis session   => passed; /me=401; template redirect=/login?return_to=/
All template CORS checks     => passed; allowed origin=200, attacker ACAO=absent
```

这证明同一 React 模板消费三套 Admin 身份契约时没有按 App 写分叉逻辑；它不等价于
三个业务前端已经迁移，也不改变 Knowledge 前端当前保持 disabled 的基线。

本次还修正了浏览器脚本的验收可靠性：模板模式支持显式前端端口覆盖，并在启动
前以 socket 绑定检查端口占用；模板
开发服务器以独立进程组启动并按进程组清理，避免复用旧端口上的开发服务器或在
验收结束后遗留 Vite/esbuild 进程。由于 KIND 后端回调地址由验收环境固定到
`19082`，正式运行前必须确认该端口为空；不能仅改浏览器期望 URL 来伪造隔离。

测试覆盖 `/api/auth/me` 归一化、CSRF 内存边界、unsafe 请求头、POST logout、401 redirect 和 correlation/error 行为。

## 验收结论与边界

- 三套 Admin 的真实 Casdoor/KIND 基础矩阵、CORS、CSRF、401/403、Research
  跨用户隔离和 Redis session 过期矩阵均已通过；consumer 验收脚本为
  `verify_p0_005_browser.mjs` 的 template/owner-isolation/session-expiry 模式。
- React 模板实现 commit：`tpl-admin-frontend@0b68498`；扩展浏览器 consumer
  gate commit：`k8s@3558a08`。clean-room、Docker/Nginx smoke 和依赖锁证据见上文。
- `pnpm build`/`pnpm test:e2e` 的 demo auth 只用于模板壳和通用错误/请求边界；
  真实身份结论以严格 TLS 浏览器矩阵为准。
- A2.5 仍需继续处理全量 a11y、响应式/reduced-motion、最终镜像固化和生产
  Gate；A2.2 的身份/数据底座不得被解释为三个业务前端已迁移。

说明：P0-005 的三套现有 Admin 严格 TLS/浏览器证据已接受（见 `V5-P0-005/result.md`），但该证据不自动转移为 React 模板的真实身份验收；模板后续必须在隔离入口消费同一 security contract 再复验。

为复用同一真实验证矩阵，`verify_p0_005_browser.mjs` 增加了可选的
`P0_BROWSER_FRONTEND_MODE=template` 模式：它启动当前 React 模板、连接对应
KIND Admin Backend，并保留 Casdoor/严格 TLS/凭据脱敏规则。2026-07-14 首次运行
曾在浏览器启动前因 WSL 缺少 `certutil` 失败：

```text
strict TLS requires certutil and a valid NSS profile: spawnSync certutil ENOENT
```

该结果是环境阻断，不计为通过，也不允许通过 `P0_BROWSER_STRICT_TLS=false`
规避正式证据门禁。安装 `libnss3-tools` 后，严格 TLS 模板实例验收已按上文
通过；首次使用非固定回调端口的尝试被正确判为失败，随后清理残留并按固定
`19082` 重新运行通过。

A2.2 已接受；下一施工包为 A2.3 CRUD Toolkit。P0-007B 和三个 App 的 React
替换仍必须等待 A2.4/A2.5、P0-007C 与 `TEMPLATE_MIGRATION_READY`，不能因
A2.2 接受而提前推广。
