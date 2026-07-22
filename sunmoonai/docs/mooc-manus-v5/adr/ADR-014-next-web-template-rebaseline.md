# ADR-014：Next Web 模板架构再基线

状态：ACCEPTED（2026-07-18 由 ADR-016 修订 Web Backend profile；2026-07-22 由 ADR-017 修订实例采纳顺序）
原始日期：2026-07-11
接受日期：2026-07-16
决策者：项目负责人、架构评审

## 1. 背景与代码事实

`tpl-web-frontend` 与 Info/Knowledge/Research Web 已采用 React 19、Next.js 16 App Router、next-intl 和 `output: standalone`。技术路线本身符合 ADR-013，但当前模板仍是登录页加 Dashboard 的基础骨架：

- Dashboard 没有服务端 session/DAL 验证；登录页只在浏览器请求 `/auth/me` 后跳转。
- Zustand `persist` 保存一份浏览器认证状态，可能与服务端 session 漂移。
- `.env.example` 同时声称支持 frontend/backend BFF，但模板没有对应 Route Handler，实际页面直接使用 `NEXT_PUBLIC_API_URL`。
- Axios 401 跳转硬编码 `zh-CN`，没有稳定错误、return URL、correlation ID 和 Server/Client API 边界。
- 没有 public SSG/ISR 与 authenticated dynamic/CSR 的路由示例，也没有 cache/revalidation ownership。
- 没有通用 SSE cursor/reconnect/reconcile/cancel/HITL 客户端边界；Research 实例中的 Agent Console 是业务试验代码，不是模板能力。
- 没有 unit/component/Playwright/a11y、CSP、安全头、health/readiness、多副本 cache/version-skew 和浏览器观测门禁。
- `.env.local` 被 Git 跟踪；当前只含 `NEXT_PUBLIC_*`，未发现 secret，但该模式不允许延续。
- Next 16 已把 `middleware.ts` 约定改名为 `proxy.ts`；现有模板尚未迁移。
- 初始审查时 Docker 使用 Node 20.18/pnpm 10，而新 React Admin 使用 Node 22.22/pnpm 9；该漂移已在 2026-07-18 运行时基线修订中统一到 Node 24.18.0 LTS/pnpm 10.24.x。

三个实例的依赖和大部分文件仍近似同源，Research 只新增了 Agent Console，因此现在仍是低成本受控重构窗口。

## 2. 已同意方向

1. 保留 React、Next.js App Router、next-intl 与 `standalone` 自托管，不改用 Nuxt，也不把 Web 降级为纯 SPA。
2. 不在三个实例中分别零散打补丁；在现有 `tpl-web-frontend` 仓库的迁移分支内重构和验证 v2，迁移前以 Git tag/镜像 digest 保留旧实现，不创建 `tpl-web-frontend-next-v2`。
3. Web v2 必须显式区分 Server Component、Client Component、server-only DAL/DTO、浏览器 typed client 与可选的轻量 BFF/stream proxy。
4. BFF 只允许承担 session/token mediation、同源代理、协议适配和流式透传；不复制领域规则、不保存第二份 Run/Artifact/Retrieval 状态。
5. 浏览器不持久化权威认证状态或 token；Proxy 只做乐观路由检查，可靠授权在产品 API/靠近数据源处执行。
6. Info/Knowledge 公共内容保留 SSG/ISR/SSR 能力；受权检索和 Research Agent workspace 使用动态壳与 Client Components。不得为了统一 CSP 或认证而无条件把全部页面强制 dynamic。
7. SSE 客户端以 cursor、snapshot reconciliation、去重、退避、cancel/resume、页面隐藏、多标签和 terminal-state precedence 为契约；EventSource/ReadableStream 的具体 adapter 由 ADR-001 输出决定。
8. v2 必须有 typecheck、lint、unit/component、Playwright、基础可访问性、安全头/CSP、Docker/KIND、多副本/滚动版本和浏览器故障证据。
9. 模板只包含中性平台能力；Info/Knowledge/Research 页面和领域 DTO 留在各实例。Research 真实试点证明最难的 streaming/HITL/citation 路径后才冻结 v2。
10. P0-008B/B6 统一模板 release 冻结前不向三个 Web 实例应用 v2；冻结后必须立即按
    ADR-017/P0-009 以 Info -> Knowledge -> Research 串行同步共同基础，不等待 Gate P0。
    同步不做无 tag/digest 的不可回滚覆盖，也不自动改变现有稳定流量。

## 3. 上游输入已收敛

P0-008A 已消费以下 Accepted 决策：

- ADR-001：Custom Runtime；SSE 是 live channel，PostgreSQL cursor/snapshot 是 durable
  truth；浏览器必须重连、去重并最终对账；cancel/resume 是受权命令。
- ADR-002：Session/Thread/Run/Attempt/Invocation 分离；浏览器 DTO 不得把这些 ID 混用，
  resume/retry 不创建新 Run。
- ADR-004：浏览器只消费安全 Citation DTO；来源跳转必须走同源受权端点，不能暴露
  Provider ID、raw source URI 或服务身份。
- ADR-005：六个 App/Surface 独立 audience；浏览器只持有同产品 Web 的不透明 HttpOnly
  session；Authorization Code + PKCE、nonce、state、签名/issuer/audience 校验、CSRF/
  Origin 和资源授权均由服务端执行。

因此 Runtime、执行身份、Citation 与浏览器身份不再阻塞本 ADR。P0-008B 可以开始，
但必须同时改造模板的 Next Web Frontend 和配对 Web Backend，不能只升级页面。Backend
默认/可选实现、仓库演进和 FastAPI 母版来源由 ADR-016 冻结。

## 4. 实施门

- P0-008A：基于 ADR-001/002/004/005 输出接受本 ADR，冻结 Web v2 边界和验收矩阵。
- P0-008B：按 B1~B6 串行完成 Next v2、Nest 可选 BFF、FastAPI 通用母版与默认 Web
  BFF、共享契约和两套配对生产骨架；仓库改名/新建必须遵守 ADR-016 的原子迁移纪律。
- P0-009：P0-008B/B6 接受后，立即按 Info -> Knowledge -> Research 把统一模板 release
  的 Admin/Web 前后端共同基础原地同步到三个 App；不得等待 Gate P0 或插入其他业务开发。
- P0-008C：只能在 P0-009 已收敛的 Research 基线上运行真实
  Run/SSE/cancel/resume/HITL/citation 薄切，回收通用修正并冻结 v2。
- M1：只补完整业务等价、产品能力、切流和旧实现退出，不得再次执行共同基础首次同步。

任一阶段发现必须把领域状态放进 BFF、无法安全恢复 stream、或多副本自托管语义无法闭合，P0-008 标记 BLOCKED 并重开本 ADR，禁止带病推广。

## 5. P0-008A 审查结果

### 已完成的紧急卫生

- 删除被 Git 跟踪的 `app/.env.local`，并在 `app/.gitignore` 中明确忽略本地环境文件；可提交的环境样例不再包含 Casdoor client secret、Redis URL 或其他凭据。
- 删除 `next.config.ts` 中硬编码的开发来源 IP；开发来源不得通过模板写死，隔离环境如确有需要必须由部署契约显式提供。
- 按 Next 16 约定将 `middleware.ts` 改为 `proxy.ts`；Proxy 只做 next-intl locale negotiation，不能承担最终身份认证/授权。
- 固定模板工具链：生产/CI/Docker 使用 Node `24.18.0` LTS、pnpm `10.24.x`；本地、Docker 与 CI 均接受 Node `>=24.18.0 <25`，发布证据必须使用精确的 24.18.0 镜像及不可变 digest。该升级来自 Node 20 已 EOL 后的独立生命周期审查，不是自动追随外部模板。
- `.env.example` 和 `.env.k8s` 改为同源 `/api` 默认值；跨源 API 只能作为有证据的隔离诊断配置，必须通过 CORS/CSRF/audience 契约。

### 已冻结架构矩阵

| 主题 | 冻结决策 | 后续验收 |
| --- | --- | --- |
| Server/Client | App Router；Server Component 只经 `server-only` DAL/DTO 调用配对 Web Backend；交互面才使用 Client Component | P0-008B route/render matrix |
| API/BFF | 浏览器只访问同源 `/api`；配对 Web Backend 是唯一 BFF；FastAPI 为默认 profile，Nest 为受维护可选 profile；Next Route Handler 不建立第二套 auth/domain BFF | P0-008B BFF allowlist + 双实现 contract vectors |
| 身份 | App/Surface 专属 HttpOnly session、PKCE/nonce/state、CSRF、audience/owner check；Proxy 仅 UX | P0-008B Web 安全内核与真实浏览器矩阵 |
| Rendering/cache | public 可静态/ISR；受权 workspace dynamic/no-store；产品 Backend/Projection 是权威状态；不持久化浏览器认证 | P0-008B route/cache owner matrix |
| Stream | Web Backend 受权代理 Runtime SSE；cursor、重连、去重、snapshot reconcile、cancel/resume、terminal precedence | P0-008B adapter；P0-008C 真实 Research 试点 |
| Citation | 浏览器只消费 ADR-004 Citation DTO 和同源受权来源跳转 | P0-008C lineage/越权矩阵 |
| Runtime/deploy | Next/选中 Web Backend 两个 Deployment 是一个配对 release tuple；固定双 digest、profile、contract/audience、滚动兼容与回滚 | P0-008B Docker/KIND/双 Pod evidence |

本 ADR 接受只允许进入模板 P0-008B；不允许向三个业务 Web 实例切流量。

## 6. 参考

- <https://nextjs.org/docs/app/guides/authentication>
- <https://nextjs.org/docs/app/guides/backend-for-frontend>
- <https://nextjs.org/docs/app/getting-started/proxy>
- <https://nextjs.org/docs/app/guides/content-security-policy>
- <https://nextjs.org/docs/app/guides/self-hosting>
- <https://github.com/ixartz/Next-js-Boilerplate>（工程实践参考；不是可直接引入的产品或 SaaS 底座）
- `ADR-016-web-bff-implementation-profiles.md`（FastAPI 默认、Nest 可选、仓库与母版来源）
- `ADR-017-template-first-instance-adoption.md`（模板完成后立即串行收敛三个实例）

## 7. ixartz 参考审查与受控吸收（2026-07-15）

审查对象已固定为本地只读 clone `/home/zymun/repo/Next-js-Boilerplate` 的 Git SHA `9926cc1f8664f67eca63065bf1c31bc4f60b09c2`（审查日期 2026-07-15，MIT License，提交日期 2026-07-08）。此前文档中出现的 `v6.3.4` 仅是首次发现时的网页参考，**不得**再作为 P0-008B 的实现输入。此 SHA 不是运行时依赖，也不允许 `git clone` 后跟随上游 `main`。其当前配置提供 Next App Router、`next-intl`、严格环境变量、Vitest/Playwright、i18n 检查、bundle analysis、Storybook/a11y 等工程能力，也同时捆绑 Clerk、Drizzle/PGlite、Neon、Sentry、Arcjet、PostHog/BetterStack/Crowdin 等与 SunmoonAI 不相容的产品/SaaS 选择。

| 上游能力 | SunmoonAI 决策 | 落点与边界 |
| --- | --- | --- |
| 类型检查、格式/静态检查、unit/component、Playwright、失败 trace/video | 采用 | P0-008B B1/B4；E2E 的 server 必须改为受控 pair backend 或 fixture，不启动 PGlite/Drizzle。 |
| 严格环境变量校验 | 采用 | 以 Zod 或等价 schema 在 build/start fail-fast；客户端仅允许显式 `NEXT_PUBLIC_*`，服务端 secret 不进入浏览器。 |
| `next-intl`、错误/加载边界、metadata、`poweredByHeader: false`、严格模式、可选 bundle 分析 | 采用 | 进入 route/render/cache matrix；分析只在明确命令启用，不引入 SaaS。 |
| App Router 的 server/client 分层 | 改造后采用 | 用 `server-only` DAL/DTO、typed browser client 和 ADR-005 批准的最小 BFF；领域状态仍归产品后端。 |
| Storybook、依赖扫描、提交钩子 | 条件采用 | 组件面达到稳定规模、可服务回归且 Gitee CI 有对应 owner 后再启用；不是 P0 放行前提。 |
| Clerk、Drizzle/PGlite/Neon、db migration、账户/支付页面 | 拒绝 | Casdoor OIDC/BFF 和领域 Backend/Contract 分别替代；模板不拥有数据库。 |
| Sentry、Arcjet、PostHog、BetterStack、Crowdin、Chromatic 等外部服务 | 拒绝，除非另行 ADR 批准 | 默认不引入外传遥测、外部 CDN、第三方身份或运行时 SaaS 依赖。 |
| 上游 Node `>=24` | 不自动跟随；独立审查后采用 Node 24 LTS | 以 Node 24.18.0/pnpm 10.24 的本地、容器和回滚证据为准；上游继续升版也不能绕过兼容门禁。 |

### 7.1 固定源码的逐项可执行拆解

| 固定源码位置 | 吸收结论 | P0-008B 的具体落点与禁止项 |
| --- | --- | --- |
| `src/libs/Env.ts` | 改造后采用 | 以 Zod 或等价 schema 建立 server/public env 白名单，并在 build/start fail-fast；不采用 `@t3-oss/env-nextjs` 前必须证明 Next 16/Node 24.18 兼容。严禁把 Casdoor secret、service token、Redis/Provider 连接串放进 `NEXT_PUBLIC_*`。 |
| `src/libs/I18n*.ts`、`src/app/[locale]` | 采用 | 保留 `next-intl`，集中 locale/routing/navigation；补 i18n missing-key check。翻译不接 Crowdin，页面不得硬编码面向用户的字符串。 |
| `next.config.ts` | 选择性采用 | 保留 `poweredByHeader: false`、`reactStrictMode: true` 和明确命令才启用的 bundle analysis。`reactCompiler`、Sentry wrapper、source-map 上传、browser-to-terminal log 都不随模板复制；前者待性能/兼容性证据，后三者需独立 ADR。 |
| `src/app/global-error.tsx`、`robots.ts`、`sitemap.ts` | 改造后采用 | 增加 locale-aware error/loading/not-found、Metadata/robots/sitemap；真实公开路由由每个 App 提供，受权 workspace 和内部路径必须明确禁止索引。不得复制其产品页面或 Sentry 调用。 |
| `playwright.config.ts`、`tests/e2e/*` | 改造后采用 | 使用 pnpm、Node 24.18、模板的 standalone production server 或同领域受控 backend/fixture；失败保留 trace/video/screenshots 并归档到受控 CI。不得启动 PGlite/Drizzle，也不得用 fixture 替代业务 App 的成对浏览器 E2E。 |
| `vitest.config.ts`、co-located `*.test.*` | 采用 | B1/B4 建立 unit/component 两层；浏览器组件测试只覆盖 UI，真实鉴权、SSE/citation 必须走配对 Playwright。测试浏览器版本要由模板 lockfile/镜像固定。 |
| `.github/workflows/CI.yml`、`knip`、`lefthook` | 改造后采用 | 将“静态检查、i18n 检查、build、unit、E2E 失败产物”迁入已有 Gitee/Jenkins 流程；依赖漂移扫描和 pre-commit hook 仅在噪声、执行时长和责任人被记录后启用。不得复制 GitHub Action、Codecov、Chromatic、Crowdin 或 Checkly。 |
| `Logger.ts`、`instrumentation*.ts`、SaaS SDK | 拒绝 | 它们会把浏览器/运行时数据送往 Better Stack、Sentry、PostHog 等外部端点；无单独的数据出境、保留期、成本与自托管 ADR 前不引入。 |
| `src/models`、`src/libs/DB.ts`、`migrations`、Clerk auth 页面 | 拒绝 | 数据、迁移、账户/支付/身份模型归产品后端与 Casdoor；Web v2 仅有 ADR-005 批准的最小 BFF/session mediation。 |

## 8. 前端/后端成对验证约束

本 ADR 的 Web v2 骨架只可使用中性 fixture，不能借此声明任一业务 Web 已验证。每个真实 Web E2E 必须连接同 App 的 Web Backend：Info Web↔Info Web Backend、Knowledge Web↔Knowledge Web Backend、Research Web↔Research Web Backend 加 ADR-001 选中的 Runtime adapter。Admin 与 Web 后端不能互换作为证据。每次验收记录双方 image digest、OIDC audience、BFF/proxy 配置、URL 和 contract version；独立前端/后端测试均不能替代成对浏览器 E2E。

## 9. 目标拓扑与 BFF 归属

```text
Browser
  │ HTTPS, same-origin, Web audience session
  ▼
Ingress / Gateway
  ├── /, /_next/*, public assets ──> Next Web Frontend
  └── /api/*                    ──> paired Web Backend (BFF)
                                          │ default: FastAPI
                                          │ optional: NestJS
                                          │
                                          ├── Casdoor OIDC/JWKS + Redis session
                                          ├── same-product Web domain API
                                          └── service identity + delegated user snapshot
                                                └── Admin/Runtime/Knowledge internal API
```

冻结规则：

1. `Info|Knowledge|Research Web Frontend + 同名 Web Backend` 是一个发布和验收单元。
   二者仍可独立 Deployment/镜像，但 release manifest 必须记录双 digest、contract
   version、Web audience 和回滚组合。
2. 选中的 Web Backend 是唯一 BFF，拥有 Web OIDC transaction、session、CSRF、浏览器
   Principal、资源授权、同源 API 和下游协议适配。默认实现为 FastAPI；完成并固化的
   Nest 实现作为可选 profile 保留。Next 不复制第二套 session/token store。
3. Next Route Handler 默认只允许 frontend-owned health/metadata 或经 allowlist 批准的
   UI 协议适配；不得复制 `/auth/*`、通用反向代理、领域写模型或 durable Run 状态。
4. Server Component 只通过 `server-only` DAL 调用配对 Web Backend 的内部 Service
   URL；只转发 allowlist cookie/correlation/locale，返回最小 DTO。不能直连数据库、
   RAGFlow、LangGraph、Admin 浏览器 API或 Provider。
5. 浏览器不再直连 Research Admin/FastAPI。Research Web Backend 以 Web session 重新
   授权，再用独立 service identity 与 delegated user snapshot 调用 Research Runtime。
6. 任一 App 的 Web Frontend 不能用另一 App 的 Web Backend；Admin Backend 也不能作为
   Web BFF 的替代证据。

## 10. BFF 路由 allowlist

| 类别 | 对外形态 | Owner | 关键约束 |
| --- | --- | --- | --- |
| 登录 | `/api/auth/login|signup|callback|continue` | 配对 Web Backend | PKCE S256、state/nonce、一次性 transaction、精确 Web audience |
| 会话 | `GET /api/auth/me` | 配对 Web Backend | browser-safe Principal DTO + CSRF；`no-store` |
| 退出 | `POST /api/auth/logout` | 配对 Web Backend | CSRF + Origin；删除服务端 session；禁止 GET 副作用 |
| Web 领域 API | `/api/web/v1/...` | 同产品 Web Backend | session/scope/owner；稳定错误与 correlation ID |
| Research stream | `/api/web/v1/research/runs/{run_id}/events` | Research Web Backend | session/owner、cursor、重连、背压、权限撤销断流 |
| Research command | `/api/web/v1/research/runs/{run_id}:cancel|:resume` | Research Web Backend | POST、CSRF、幂等 command ID、Run/Thread 语义来自 ADR-002 |
| Citation source | `/api/web/v1/citations/{evidence_id}/source` | Research Web Backend | 当前用户重新授权；302/stream；不暴露 raw URI |

禁止提供任意目标 URL、任意 header/cookie 转发或 `/api/proxy/**` 通用代理。Web Backend
调用 Admin/Runtime/Knowledge 必须使用固定下游 allowlist、独立 service relation 和
结构化 DTO。

## 11. Route rendering matrix

| Route class | 示例 | 渲染 | 身份检查 | Cache/SEO |
| --- | --- | --- | --- | --- |
| Public immutable | favicon、静态资源、公开固定说明 | build-time static | 无 | 长缓存、内容 hash |
| Public content | 公开课程/知识介绍 | SSG/受控 ISR | 无或后端 public contract | 可索引；多 Pod 前先证明共享失效 |
| Login/callback result UI | `/{locale}/login` | dynamic Server Component | 服务端读取 Web session，已登录则 redirect | `no-store`、禁止用户间缓存 |
| Authenticated workspace | `/{locale}/workspace` | dynamic shell + Server DTO | DAL 调用 Web Backend `/auth/me`/workspace | `private, no-store`、noindex |
| Live Run | `/{locale}/runs/{id}` | dynamic shell + Client stream island | 首屏和每次 stream/reconcile 均 owner check | 不缓存权威 Run 状态 |
| Error/loading/not-found | locale-aware boundary | 按父 route | 不显示敏感错误 | 内部/受权路径 noindex |

不得用全局 `force-dynamic` 牺牲所有 public 路由，也不得为保留静态化而跳过受权页面的
服务端 session 检查。

## 12. Cache owner matrix

| 数据 | 权威 owner | Web 允许缓存 | 规则 |
| --- | --- | --- | --- |
| Public content DTO | 对应 Web Backend/领域服务 | Next build cache/受控 ISR | 只缓存公开且不含用户维度的数据 |
| Session/Principal | 配对 Web Backend + Redis | Next 仅 request-scope memoization | 绝不进入 shared cache、localStorage 或持久 Zustand |
| Authenticated resource DTO | 对应 Web Backend | request-scope；浏览器短期 React Query | key 必含资源/用户上下文；logout/身份切换立即清空 |
| Run/Event/Attempt | Research PostgreSQL projection | 浏览器内存派生状态 | SSE 不是真相；最终 cursor snapshot reconcile |
| Citation | Research projection | 当前页面内存 | 来源打开时重新授权；不缓存 raw source |
| Next route/ISR cache | Next runtime | 仅 public route | 多 Pod on-demand invalidation 前必须共享 cache/tag 或禁用 ISR |

P0-008B 默认不开启跨 Pod on-demand ISR，也不引入新 Redis cache。先用 build-time static
与 dynamic/no-store 闭合正确性；只有共享 cache owner、key namespace、失效和版本兼容
有证据后才启用 ISR。

## 13. Stream/reconciliation 契约

1. Browser -> Research Web Backend 使用同源 cookie SSE；连接和重连都重新验证 Web
   audience、session、Run owner 和权限版本。
2. 每个事件具有稳定 `event_id`、Run ID、单调 cursor、event type、occurred_at 和安全
   UI payload；不得发送 Provider response、service token 或内部 checkpoint 对象。
3. 客户端先订阅 live stream，再请求 durable snapshot/cursor；按 `event_id` 去重，
   应用 terminal-state precedence，避免 snapshot/stream 窗口丢失事件。
4. 断线使用最后确认 cursor 重连；cursor 过期或版本不兼容时返回明确 reason，客户端
   清空派生状态并从 snapshot 收敛，不能静默从头重复副作用。
5. cancel/resume 是独立 POST command，带 CSRF、operation/idempotency key；SSE
   disconnect 不等于 cancel。
6. 多标签页不共享写权限；每个 command 仍由服务端条件更新。客户端可用 BroadcastChannel
   降低重复刷新，但不能把浏览器锁当并发真相。

## 14. 环境、兼容与发布矩阵

### 14.1 Next Web Frontend

| 项 | 冻结值/规则 |
| --- | --- |
| Node | 本地/CI/Docker `24.18.0` LTS；`package.json` 接受 `>=24.18.0 <25`，发布镜像固定精确版本与 digest |
| pnpm | `10.24.x`，lockfile frozen |
| Next/React | 当前基线 Next `16.2.2`、React `19.2.4`；升级独立验证 |
| client env | `NEXT_PUBLIC_APP_NAME`；API 固定同源 `/api`，不接受 secret/绝对生产 credential |
| server env | `WEB_BACKEND_INTERNAL_URL`、`APP_ORIGIN`、`DEPLOYMENT_ID/BUILD_VERSION` 等经 schema allowlist 的非浏览器值 |
| build | `output: standalone`；`poweredByHeader: false`；self-host assets/fonts |

### 14.2 Web Backend profiles

共同规则：

- App/Surface 专属 Casdoor discovery/client/audience、Redis namespace、cookie 名/属性、
  allowed origin 和 internal downstream relations 必须通过 Secret/config schema 注入。
- 随机但未持久校验的 state、无 PKCE/nonce/JWT 验签、完整 token Redis session、
  `session:{id}`、GET logout、浏览器安全 DTO 泄漏和登录路径 schema DDL 均是阻断缺陷。
- FastAPI 与 Nest 必须通过同一 Auth/Principal/CSRF/Error/SSE/Citation consumer vectors；
  Next typed client/DAL 不得按语言分叉。

FastAPI 默认 profile：

- 先从三套已通过 P0-005 的业务后端反向补齐 canonical `tpl-admin-backend` 的通用能力，
  再由固定 commit 初始化 `tpl-web-backend`；禁止原样复制当前旧认证原型。
- 必须替换为 Web 专属 surface/audience/cookie/namespace/API/downstream relation，不能用
  Admin Backend 直接充当 Web BFF。

Nest 可选 profile：

- 现有 `tpl-web-backend` 完成 B2~B4 后固定并改名 `tpl-web-backend-nest`；若后续不再通过
  共享门禁，必须标记 `REFERENCE_ONLY`。
- Node/Nest/JOSE 生命周期独立治理，不得反向限制 FastAPI 默认 profile 的发布。

### 14.3 发布

- Next 与选中的 Web Backend 均使用不可变 image digest；release manifest 记录 frontend
  digest、backend digest、backend profile、contract version、OIDC audience、deployment ID
  和回滚 tuple。
- 默认不使用 Server Actions 承担身份/领域 mutation，避免滚动版本的 action ID/加密 key
  变成隐藏耦合。未来启用时必须固定 encryption key 并运行 version-skew 矩阵。
- CSP 按 route class 验证：authenticated dynamic route 使用严格 nonce/hash 策略；
  public static route不得因此被全局强制 dynamic。任何 `unsafe-eval` 仅限开发环境。
- P0-008B 必须验证至少两个 Frontend Pod、两个 Backend Pod、滚动新旧版本、session
  跨 Pod、stream 断线、静态资源 version skew、health/readiness 和回滚 tuple。

### 14.4 Node 运行时生命周期治理

- “冻结”表示一个 release tuple 内的本地、CI、Docker 和证据可复现，不表示永久停留在某个 Node 主版本。
- 模板只采用处于维护期的偶数 Node LTS；Current 版本不得直接成为生产基线。
- 每季度复核 Node、pnpm、Next、React，以及 Nest 可选 profile 与 JOSE 的兼容矩阵；距离 Node EOL 六个月时必须建立升级任务，EOL 后不得继续形成新发布基线。
- 升级顺序固定为模板基线、完整本地门禁、双镜像门禁、固定 commit/digest，随后必须由
  业务 App 按 ADR-017 紧邻继承；禁止等待 Gate P0，也禁止三个业务仓各自选择运行时版本。
- 2026-07-18 的 Node `24.18.0` 修订必须重跑 B1 全部门禁。B2 在修订接受前暂停，且不得把运行时升级与身份安全业务改动混入同一提交。

## 15. 接受结论与未完成项

ADR-014 在 2026-07-16 接受，P0-008A 结束。接受依据：

- ADR-001/002/004/005 已提供可执行 Runtime、身份、Citation 和浏览器安全边界。
- ixartz 固定 SHA、MIT 许可、依赖与逐文件采用/改造/拒绝矩阵已归档。
- 当前模板和三个 Web pair 已盘点；确认现有 Next 与 Nest 身份实现仍不满足本 ADR，且
  canonical `tpl-admin-backend` 不能未经 P0-005 通用能力回收就复制为 FastAPI Web 主线。
- 目标拓扑、route/cache、BFF allowlist、stream、环境/兼容、双镜像发布和配对 E2E
  矩阵已冻结。

未完成项全部进入 P0-008B/B1~B6、P0-009 和 P0-008C，尤其是 Nest 安全内核与固化改名、FastAPI
通用母版与默认 Web surface、共享契约、Next DAL/DTO、真实 stream adapter、多副本/CSP/
浏览器证据。ADR Accepted 不表示当前模板或三个业务 Web 已达到生产资格。
