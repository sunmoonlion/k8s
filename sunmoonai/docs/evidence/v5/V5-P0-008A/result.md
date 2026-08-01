# V5-P0-008A Next Web 架构契约验收证据

状态：`ACCEPTED`

日期：2026-07-16（Asia/Shanghai）

ADR：`sunmoonai/docs/mooc-manus-v5/adr/ADR-014-next-web-template-rebaseline.md`

## 1. 结论

P0-008A 已结束。ADR-014 已冻结以下生产边界：

- Next Web Frontend 与同产品 Nest Web Backend 是不可拆分的发布/验收 pair。
- 浏览器只访问同源 `/api`，Nest Web Backend 是默认 BFF；Next 不复制第二套身份、
  session 或领域 BFF。
- Server Component 只经 `server-only` DAL/DTO 调用配对 Web Backend。
- public、login、authenticated workspace、live Run 的 rendering/cache owner 已分离。
- Research stream 使用受权 BFF adapter、durable cursor/snapshot reconciliation。
- 双镜像 digest、Web audience、contract 和回滚 tuple 必须一起验收。

本结论只解锁 P0-008B；当前模板和三个业务 Web 尚未达到生产资格。

## 2. 上游决策输入

| ADR | 状态 | 本任务消费的输出 |
| --- | --- | --- |
| ADR-001 | Accepted / Custom Runtime | SSE live channel、PostgreSQL durable cursor/snapshot、cancel/resume、terminal reconcile |
| ADR-002 | Accepted | Session/Thread/Run/Attempt/Invocation 分离与浏览器 ID 语义 |
| ADR-004 | Accepted | browser-safe Citation DTO 与同源受权来源跳转 |
| ADR-005 | Accepted | 六 audience、Web BFF session、PKCE/nonce/state、CSRF/Origin、资源授权 |

P0-008A 不再被 Runtime、Citation 或身份决策阻塞。

## 3. ixartz 固定参考输入

本地只读 clone：`/home/zymun/repo/Next-js-Boilerplate`

Git SHA：`9926cc1f8664f67eca63065bf1c31bc4f60b09c2`

提交日期：`2026-07-08T17:27:26+02:00`

许可证：MIT

| 文件 | SHA-256 |
| --- | --- |
| `LICENSE` | `cc79352a90f66bb27020bc40cb7481e661de807875e4ece5533ee4d4d9d20616` |
| `package.json` | `282b8613b0dcbe641e9698702b08b7ef3772a895da9c85d8a8b081ca2c5b2508` |
| `next.config.ts` | `6651768a85259ca706b7fd741534a62231eba528e0d99b5be1c397bc2912662f` |
| `src/libs/Env.ts` | `8184052ba254478aaf0d97305b281212ffd87c38aa11c5029c3a823d958ebe65` |
| `playwright.config.ts` | `8acb5d4674b5c022721b3d8ae8230e9e8cceb3d5f79d7f5a3f6e5c41fccefa10` |
| `vitest.config.ts` | `71bc7d83e65556064bc0278262afbce6627e66bdad3a65ceb3b3e289cc9c2b66` |
| `.github/workflows/CI.yml` | `421016c4d2db8d47b79fe8014462c399980840ffeadf7fc4a243bd6511f51bf3` |

### 采用

- 严格 TypeScript、可复现命令和环境 schema/fail-fast。
- `next-intl` 集中路由与 missing-key 检查。
- locale-aware loading/error/not-found、metadata/robots/sitemap。
- Vitest unit/component、Playwright、失败 trace/video/screenshot、基础 a11y。
- `poweredByHeader: false`、严格模式、显式命令启用 bundle analysis。

### 改造后采用

- App Router server/client 分层改为 `server-only` HTTP DAL/安全 DTO。
- Playwright 使用配对 Nest Web Backend 或受控 fixture，不使用 PGlite/Drizzle。
- GitHub CI 任务语义迁入现有 Gitee/Jenkins 责任链，不复制 GitHub/SaaS 流程。
- Storybook/依赖扫描只在组件面、owner、噪声和执行成本满足触发条件后启用。

### 拒绝

- Clerk、Drizzle/PGlite/Neon、前端数据库和 migration。
- Sentry、Arcjet、PostHog、Better Stack、Crowdin、Chromatic、Checkly 等未批准 SaaS。
- 外部字体/CDN、产品账户/支付/营销页面、GitHub 专用发布流程。
- 因上游 `engines.node >=24` 自动升级 SunmoonAI Node 20.18 发布基线。

## 4. 当前模板基线

### 4.1 Next Web Frontend

仓库：`tpl-app/tpl-web-frontend`

基线提交：`4db03b2e04025a8014237f00e63835a99ddd81ca`

| 文件 | SHA-256 |
| --- | --- |
| `app/package.json` | `7cfbd584e383398540a229d5dc4165a3b07d08d58053e2321b401aff1ef8d1b7` |
| `app/pnpm-lock.yaml` | `ba938b76b26143e6f9e9617aebfef9cbadfd4291b3a5a4504032fd36b17d4f32` |
| `app/next.config.ts` | `99d26d0a5a2a7401e651f6380fb37a36a9fa9682213457d82e69b0ce9225bef1` |
| `app/proxy.ts` | `352b4cf8fb50540861f398e807221a5d74e9f02d954cfff78aaf9dbca2085c08` |
| `app/.env.example` | `2fca2078c07c7564a461d439bcf3db1897b83517733928fe8320cde565e58334` |
| `app/.env.k8s` | `746e875c5814ad8b526f723c31312d2e192c3efb0cd56ae168bf4a6ea556fbbc` |
| `mybuild/Dockerfile` | `a069b967429fe9ee754befceae523ffd8f42311245b583a27ca4b7c6c552128a` |

已完成卫生：`.env.local` 不再跟踪、`proxy.ts` 已替代 `middleware.ts`、默认同源
`/api`、Node/pnpm 已固定。仍待 P0-008B：env schema、DAL/DTO、真实服务端 session
检查、测试、安全头/CSP、多副本与 stream。

### 4.2 Nest Web Backend

仓库：`tpl-app/tpl-web-backend`

基线提交：`d1abfa3409aae93d62d36733d55f50021e104ba1`

代码审查确认当前仍是不可生产的旧身份原型：

- `state` 随机生成但未持久化/回调消费。
- 无 PKCE、nonce、discovery/JWKS 签名和精确 issuer/audience 校验。
- Redis `session:{id}` 保存完整 token response。
- 以 base64 decode 的 ID Token claims 建立请求用户。
- `/auth/logout` 是有副作用的 GET。
- `/auth/me` 返回完整 session/token 结构。
- 多数 Web 业务 Controller 的 fail-closed/owner 策略尚未形成统一门禁。

这些不是“以后优化”，而是 P0-008B B2/B4 的阻断项。

## 5. 三个业务 Web pair 快照

| App | 父仓提交 | Web Frontend | Web Backend |
| --- | --- | --- | --- |
| Info | `37988c873e8dc4e6a7f019ee8eec26f90ce8c82d` | `abdbf63849c847b4301c37d31dec12405e2d3257` | `ffbc54ea2fe739495cdbd73ce174ec8c70bbd79e` |
| Knowledge | `2e410ad0ba8f813844147df39cda56269618a97e` | `2f4f68257062ea006e8e03ccd8e06844db7c1ad6` | `ada118c984e6338998d7f405579e3a4cd5434e76` |
| Research | `81215951809ead1cb5b06df182937551b026ebed` | `ea42d2974f1063ede160c8a547f49e616d6948aa` | `0714115ab64a730033f3544bdf2de78ed06aba81` |

三个 Web Frontend 都已是 Next 16，不存在 Vue→React Web 迁移。待完成的是 Web v2
通用能力再基线和配对安全改造。Research 当前 Agent Console 直连 Admin/FastAPI，
违反本 ADR；P0-008C 前必须改为 Research Web Backend 受权 adapter。

## 6. 冻结矩阵

ADR-014 已给出并接受：

- 目标拓扑与 BFF owner。
- BFF 路由 allowlist。
- route rendering matrix。
- cache owner matrix。
- stream/cursor/reconciliation contract。
- frontend/backend 环境和兼容矩阵。
- 双镜像 release tuple、CSP、多副本、滚动版本和回滚门禁。
- Info/Knowledge/Research Web↔同产品 Web Backend 的成对浏览器 E2E 纪律。

## 7. 静态验证

验证器：

```text
python sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_008a.py
```

结果：

```json
{
  "task": "V5-P0-008A",
  "result": "passed",
  "adr_status": "ACCEPTED",
  "ixartz_sha": "9926cc1f8664f67eca63065bf1c31bc4f60b09c2",
  "tpl_web_frontend_baseline": "4db03b2e04025a8014237f00e63835a99ddd81ca",
  "tpl_web_backend_baseline": "d1abfa3409aae93d62d36733d55f50021e104ba1",
  "web_pairs": ["info", "knowledge", "research"],
  "legacy_bff_findings_recorded": true,
  "secrets_printed": false
}
```

## 8. 下一步

当前唯一代码任务切换为 P0-008B/B1：

1. Repo/Env/Rendering 基线与测试骨架。
2. 配对 Nest Web Backend 身份/BFF 安全内核。
3. typed DAL/DTO、Query/stream/citation 通用能力。
4. Security/Test/Docker/KIND 双 Pod 与双镜像 release tuple。

P0-008B 未通过前不修改三个业务 Web；P0-008C 未通过前不推广模板或切正式流量。
