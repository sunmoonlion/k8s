# ADR-014：Next Web 模板架构再基线

状态：IN_PROGRESS / BLOCKED_BY_ADR-001（P0-008A 紧急卫生已完成；等待 Runtime ADR 的可执行 stream/cancel/resume 输出后冻结细节）
日期：2026-07-11  
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
- Docker 使用 Node 20.18/pnpm 10，而新 React Admin 使用 Node 22.22/pnpm 9；这不自动构成运行错误，但版本治理、注释和缺失 `.nvmrc` 已漂移。

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
10. v2 冻结前不向三个 Web 实例应用 v2，不做无 tag/digest 的不可回滚覆盖，不改变现有流量；冻结且 Gate P0 通过后按 Info -> Knowledge -> Research 串行改造现有仓库。

## 3. 尚待上游 ADR 决定

以下内容不得由模板实现先行决定：

- ADR-005：浏览器 session/cookie、CSRF/CORS、Web/Admin audience，以及 frontend BFF 或直接产品 API 的默认拓扑。
- ADR-001：SSE/stream adapter、cursor、cancel/resume 和 Runtime endpoint 形态。
- ADR-004：Citation DTO、安全跳转与 evidence 展示边界。
- Kubernetes/发布设计：Node/pnpm 固定版本、反向代理、CSP 策略、共享 cache/tag invalidation、deployment ID、Server Action encryption key 和滚动版本兼容。

这些输出未冻结前，只允许审计和紧急卫生修复，不开始 v2 主体实现。

## 4. 实施门

- P0-008A：基于 ADR-001/004/005 输出接受本 ADR，冻结 Web v2 边界和验收矩阵。
- P0-008B：在现有 `tpl-app/tpl-web-frontend` 仓库内按 B1~B4 串行重构并验证 Next v2 生产骨架。
- P0-008C：在 Research 隔离入口运行真实 Run/SSE/cancel/resume/HITL/citation 薄切，回收通用修正并冻结 v2。
- M1：按 Info -> Knowledge -> Research 串行把固定 v2 commit 应用到三个现有 Web 仓库；P0-008C 的 Research 薄切直接演进，不重新实现，也不创建平行业务仓库。

任一阶段发现必须把领域状态放进 BFF、无法安全恢复 stream、或多副本自托管语义无法闭合，P0-008 标记 BLOCKED 并重开本 ADR，禁止带病推广。

## 5. P0-008A 审查结果（尚不代表 ADR Accepted）

### 已完成的紧急卫生

- 删除被 Git 跟踪的 `app/.env.local`，并在 `app/.gitignore` 中明确忽略本地环境文件；可提交的环境样例不再包含 Casdoor client secret、Redis URL 或其他凭据。
- 删除 `next.config.ts` 中硬编码的开发来源 IP；开发来源不得通过模板写死，隔离环境如确有需要必须由部署契约显式提供。
- 按 Next 16 约定将 `middleware.ts` 改为 `proxy.ts`；Proxy 只做 next-intl locale negotiation，不能承担最终身份认证/授权。
- 固定模板工具链：生产/CI/Docker 使用 Node `20.18.0`、pnpm `10.24.x`；本地开发允许 Node `>=20.18.0 <25`，但必须以 Docker/CI 的 Node 20.18.0 结果作为发布证据。Next 16 的最低 Node 要求由官方升级说明单独核验，不因外部模板的 Node 24 要求擅自升级基础镜像。
- `.env.example` 和 `.env.k8s` 改为同源 `/api` 默认值；跨源 API 只能作为有证据的隔离诊断配置，必须通过 CORS/CSRF/audience 契约。

### 当前架构矩阵（候选，未冻结）

| 主题 | 当前模板候选 | 冻结前必须消费的证据 |
| --- | --- | --- |
| Server/Client | App Router；Server Component 不直接暴露 Provider 类型；交互面才使用 Client Component | P0-008B route/render matrix |
| API 拓扑 | 同源 `/api` typed browser client；BFF 只保留为 ADR-005 允许的 session/协议适配边界 | ADR-005 + P0-008B BFF allowlist |
| 身份 | App/Surface 专属 HttpOnly session、CSRF、audience/owner check；Proxy 仅 UX 检查 | ADR-005 已接受；Web 真实浏览器矩阵 |
| Rendering/cache | public 内容可 SSG/ISR；受权 workspace 默认 dynamic；产品 Backend/Projection 是权威状态，浏览器不使用 Zustand 持久化认证 | P0-008B route/render/cache owner matrix |
| Stream | cursor、重连、去重、snapshot reconciliation、cancel/resume、terminal precedence | ADR-001（当前仍 partial，阻塞） |
| Citation | 浏览器只消费安全 Citation DTO 和受权来源跳转 | ADR-004 Accepted 输出 + Research 试点 |
| Runtime/deploy | `standalone` 自托管；反向代理前置；固定镜像 digest；滚动版本需验证 Server Action/stream/cache 兼容 | P0-008B Docker/KIND/双 Pod evidence |

因此本 ADR 目前只能作为 P0-008B 的候选输入，不能宣称 `Accepted`，也不能据此开始三个 Web 实例的替换。

## 6. 参考

- <https://nextjs.org/docs/app/guides/authentication>
- <https://nextjs.org/docs/app/guides/backend-for-frontend>
- <https://nextjs.org/docs/app/getting-started/proxy>
- <https://nextjs.org/docs/app/guides/content-security-policy>
- <https://nextjs.org/docs/app/guides/self-hosting>
