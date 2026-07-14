# V5-P0-008A Next Web 架构契约审查与紧急卫生

状态：`IN_PROGRESS / BLOCKED_BY_P0-001`

日期：2026-07-14（Asia/Shanghai）

## 结论

P0-008A 已完成不依赖上游 Runtime 选型的模板卫生和架构盘点，但不能宣称
`ADR-014 Accepted`。ADR-001 当前仍为 `CANDIDATE_A_PARTIAL`；在其给出可执行的
stream/cursor/cancel/resume/worker-failure 语义前，不开始 P0-008B，不向三个 Web
实例复制任何 v2 代码。

本轮只修改 `tpl-app/tpl-web-frontend` 模板和 k8s 文档，未修改 Info、Knowledge、
Research Web 工作树、父仓 gitlink、Deployment、镜像或正式流量。

## 本地验证结果

用户在 Node `v24.18.0`、pnpm `10.24.0` 环境中执行了：

- `corepack pnpm install --frozen-lockfile --registry=https://registry.npmmirror.com`：通过。
- `corepack pnpm typecheck`：通过。
- `corepack pnpm lint`：通过。
- `corepack pnpm build`：通过；Next `16.2.2` 正确识别 `ƒ Proxy (Middleware)`，静态页和动态页均完成构建。

pnpm 报告 `@parcel/watcher`、`@swc/core`、`msw` 的 build scripts 当前被忽略。这不是构建失败；在 P0-008B 依赖治理前不执行全量 `approve-builds`。后续只允许对经验证确实需要的原生构建/测试脚本建立最小 allowlist，并把 lockfile、安装日志和构建结果一起纳入证据。

## 已实施的模板卫生

- 删除被 Git 跟踪的 `app/.env.local`，并将其加入 `app/.gitignore`；`.env.example`
  和 `.env.k8s` 不再放置 Casdoor/Redis/服务凭据或不受支持的“frontend BFF”声明。
- 删除 `next.config.ts` 中硬编码的开发来源 IP。
- 按 Next 16 文件约定将 `middleware.ts` 改为 `proxy.ts`。Proxy 只做 next-intl
  locale negotiation，明确不承担最终认证/授权。
- 固定 Web 模板工具链：`.nvmrc`/Docker/CI Node `20.18.0`，`packageManager`
  `pnpm@10.24.0`；package engines 允许本地 Node `>=20.18.0 <25`，pnpm 仍固定
  `10.24.x`。发布证据以 Node 20.18.0 构建为准。
- 默认 API 入口改为同源 `/api`；跨源地址只允许在有隔离诊断证据、CORS/CSRF/
  audience 契约和回滚记录时由部署显式覆盖。
- README 改为 SunmoonAI 模板说明、质量门禁、Server/Client 与 BFF 边界，移除
  create-next-app/Vercel/默认产品文案。

## 外部参考采用矩阵

参考固定为 MIT 许可的 `ixartz/Next-js-Boilerplate` release `v6.3.4`（2026-05-22
页面所示；地址：`https://github.com/ixartz/Next-js-Boilerplate/tree/v6.3.4`）。只提取
工程实践，不复制其产品页面和依赖栈。

| 参考能力 | 决策 | SunmoonAI 处理 |
| --- | --- | --- |
| App Router、严格 TypeScript、清晰的 `src/app`/components/tests 组织 | 采用 | 保持现有 App Router，B1 再补 server-only DAL/DTO、route matrix 和测试目录 |
| Vitest/Testing Library、Playwright、a11y、错误/加载边界 | 采用并改造 | 按 ADR-014 增加真实身份、CSP、stream reconnect/reconcile 和双 Pod 验证 |
| 环境变量 schema 与启动时校验 | 采用 | 只允许公开变量进入 `NEXT_PUBLIC_*`；Casdoor/Redis/服务凭据由后端/BFF contract 管理 |
| Clerk、DrizzleORM、PGlite、Neon | 拒绝替换 | 身份使用 Casdoor + ADR-005；数据和 Provider contract 归后端，不在 Web 建第二数据库 |
| Sentry、Arcjet、PostHog、Better Stack、Checkly 等 SaaS | 暂不采用 | 需另有供应商、数据出境、成本和部署 ADR；不能成为模板运行时依赖 |
| Crowdin、外部字体/CDN、完整 SaaS demo 页面 | 拒绝 | 保持自托管和本地/受控资源，避免运行时外连和领域污染 |
| Node 24+ 要求 | 不直接采纳 | Next 16 官方最低 Node 为 20.9；SunmoonAI 先固定已验证的 Node 20.18，升级需单独兼容矩阵和镜像证据 |

## 候选架构矩阵（尚未冻结）

| 主题 | 当前候选 | 阻塞/验收证据 |
| --- | --- | --- |
| Server/Client | Server Component 负责受控读取；交互面使用 Client Component | P0-008B route/render matrix |
| API | 同源 `/api` typed browser client；BFF 仅做 session/token mediation、同源代理和协议适配 | ADR-005 + P0-008B BFF allowlist |
| 身份 | App/Surface 专属 HttpOnly session、CSRF、audience/owner check；Proxy 只改善 UX | ADR-005 已接受，待 Web 浏览器矩阵 |
| Rendering/cache | public 内容可 SSG/ISR；受权 workspace 默认 dynamic；Backend/Projection 是权威状态 | P0-008B cache owner matrix |
| Streaming | cursor、去重、退避、snapshot reconciliation、cancel/resume、terminal precedence | ADR-001（当前 partial，阻塞） |
| Citation | 浏览器只消费安全 Citation DTO 和受权跳转 | ADR-004 + P0-008C Research 试点 |
| 部署 | `standalone` 自托管，反向代理前置，固定 digest，多副本滚动兼容 | P0-008B Docker/KIND evidence |

## 下一步

1. 完成 ADR-001 Runtime 选型和浏览器 stream harness，确定 adapter 形态。
2. 消费 ADR-004 Citation DTO 与 ADR-005 Web BFF/身份边界，正式接受 ADR-014。
3. 进入 P0-008B，仍在现有 `tpl-web-frontend` 仓库内原地重构；完成前不改三个
   Web 实例，不创建 `*-next-v2` 仓库。
