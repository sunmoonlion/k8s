# V5-P0-007B Info Admin 真实业务试点

状态：`IN_PROGRESS`（迁移前基线已冻结；React 业务竖切、CSP hash 候选镜像、联合隔离严格 TLS、真实浏览器身份、业务 contract/E2E、可恢复 mutation/审计对账、来源/Collector/上传/分发真实 mutation 矩阵和隔离回滚均已通过；尚未切正式流量，仍需补齐重复操作、并发冲突、XSS/危险 URL 与显式回滚演练等剩余验收证据）

## 迁移前基线

- Info Admin 子仓库：`info-admin-frontend`
- 远程仓库：`https://gitee.com/sunmoonlion/info-admin-frontend.git`
- 当前分支：`codex-1`
- Vue 源码提交：`c12022ee24a248477ebd6b7b37fbc9818d9693ff`
- 迁移前 tag：`p0-007b-info-admin-vue-baseline-20260714`
- 父仓指针：`info-app@cd488aa`
- 当前 Deployment 镜像：`harbor.sunmoonai.com:30443/app-images/info-admin-frontend:1.0.1`
- 当前运行 Pod digest：`sha256:3ce28192f97bd38a46d47b3bc357b9d826f219cff79fa47bd05dbdb84180bc98`
- 当前 Pod：`info-admin-frontend-7669774c99-jj2zj`，Ready=`true`
- 当前 Deployment generation：`9`

创建 tag 和读取 Deployment 均未修改业务代码、Deployment 或流量配置。

## 业务迁移范围

React Admin v1 完整消费已冻结的 `tpl-admin-frontend@f24500f6d8f437a0162fa4939d3ed6b9b8ddbcf1` 工作树及其全部已验收通用、安全和生产能力，然后在 Info 现有仓库内增加领域页面与 typed adapter；不是只复制 Shell 或部分组件。Vue `src/pages/info/crawl.vue` 的真实业务薄切包含：

- 文档列表：关键词/状态筛选、刷新、选中和版本列表。
- 来源/Collector/URL crawl/文件上传创建操作。
- 文档审核：单条、批量、审核人、原因、状态。
- 实体链接与摘要画像保存。
- Knowledge 分发：创建、查询、详情、dispatch、retry。
- 对应 API：`/documents`、`/documents/{id}/versions`、`/documents/{id}/review`、`/documents/{id}/entity-links`、`/documents/{id}/summary-profile`、`/admin/crawl-jobs`、`/admin/sources`、`/admin/collectors`、`/admin/collectors/{id}/discover`、`/admin/uploads`、`/admin/distributions`、`/admin/distributions/knowledge`、`/admin/distributions/{id}/dispatch`、`/admin/distributions/{id}/retry`。

模板中的富组件、菜单、权限、Query、错误、审计 mutation、上传/下载等通用能力必须复用；业务 DTO 和 Info 规则只进入 Info 子仓库，不能回流模板。

## 不进入本任务

- Vue `components/**`、`directives/**` 纯展厅页不复制；能力已由模板矩阵和 A2.4/A2.5 证据覆盖。
- PWA/Electron、纯 about/demo 页面不进入业务迁移主链。
- 不修改 Knowledge/Research Admin，不批量同步，不切换正式入口流量。

## 当前实现快照（未验收）

- 前端实现已推送：Info Admin `42e524e`，父仓 `info-app@f4e6e41`；canonical 模板通用修正 `tpl-admin-frontend@f8d6ac8`（父仓 `tpl-app@b7cf6bf`）；K8s 同源 API 路由与隔离证据提交已推送至 `k8s@245918d`。候选镜像已推送，但尚未覆盖正式 `1.0.1`。
- React 基线已在现有 `info-admin-frontend` 子仓库原地替换；旧 Vue 源码保留在迁移前 Git tag，不作为当前工作树运行时。
- 新增 `app/lib/info-api.ts`：所有领域请求显式走 `/api`，JSON mutation 自动声明 `Content-Type`，上传保持浏览器 multipart boundary；审计 mutation 由 correlation/operation/reason headers 传递。
- 生产构建默认 `VITE_API_URL=`；Info Admin IngressRoute 已把同一 Host 的 `/api` 按顺序转发到 `info-admin-backend:8000`，`/` 才转发到前端，保持 CSP `connect-src 'self'`、session/CSRF cookie 和 OIDC 回调在同一浏览器 Origin。KIND 临时 OIDC 的 `127.0.0.1` 值仍只能由隔离脚本覆盖，不是生产默认。
- 已验收的 CSP 候选镜像：`harbor.sunmoonai.com:30443/app-images/info-admin-frontend:p0-007b-csp-20260714@sha256:f553514576d4d1bf15722aeceb514e710d6d91f7af3d2b65f302e6df9c5f4087`；旧 `p0-007b-info-admin-react-20260714` 不得作为验收依据。
- 审计修复后端候选已推送：`harbor.sunmoonai.com:30443/app-images/info-admin-backend:p0-007b-audit-20260714@sha256:668a104838c99cc745457365e0908c6bd71d95058aefd0ba843a7f94d0d7398d`；只用于隔离验证，未覆盖正式 `info-admin-backend:1.0.1`。
- 新增 `app/routes/info-crawl.tsx` 和 `/info/crawl` 导航：URL crawl、source、collector/discover、上传、文档筛选/选择/版本、单条/批量审核、实体链接、摘要画像、Knowledge 分发/详情/dispatch/retry 均使用真实 API，不提供 mock success。
- 2026-07-14 本地补齐所有 Info 写操作的统一审计确认：URL crawl、source、collector、discover、upload 和 distribution-create 均先经过 `AuditedActionModal`，再由 `useCrudMutation` 生成并传递 correlation/operation/reason headers；上传从“选中文件即写入”改为“选中文件暂存、确认原因后才上传”。并新增 deferred-upload 回归测试；该改动已包含在 CSP candidate 并通过前端 44 tests、Docker/Nginx 和浏览器验证。
- 通用 `apiRequest` 的 JSON Content-Type 修正同步回 canonical React Admin 模板及其单元测试；该修正属于 template/common，不能把 Info DTO 或页面回流模板。
- 已增加 Info API adapter、导航和通用请求头测试；Info `typecheck`、`lint` 和 `test` 已通过（11 files / 44 tests），并清理了 Ant Design 弃用 API 和测试 warning；生产 `pnpm build` 已在允许临时 preview 监听的环境通过。
- Docker/Nginx smoke 已通过；KIND 隔离 `info-admin-frontend-p0-007b` 已用固定 digest 完成严格 CA/SNI 验收：`/health`、首页、`/info/crawl`、未知 asset `404`、同源 `/api/auth/me=401`、CSP 和无 Node runtime 均通过。临时 Deployment、Service、IngressRoute 已自动删除；正式 `info-admin-frontend:1.0.1` 与 `info-admin-backend:1.0.1` 未改变。首次 port-forward 建立前的瞬时 `curl (7)` 已由 readiness loop 收敛，不作为失败证据。
- 真实 Info 浏览器身份矩阵已通过（`verify_p0_005_browser.mjs`，`P0_BROWSER_APPS=info`、严格 TLS、真实 Casdoor/KIND backend、Info React 工作树）：`authenticated_me=200`、stable actor binding、callback one-time、HttpOnly session cookie、transaction cookie consumed、Admin role/scope、4 个 CSRF negative cases、CORS=200、positive logout、session revoked 全部通过；provider UI 一次完成（569ms），`credentials_printed=false`、`provider_tokens_printed=false`。首次运行的 Vite 冷启动依赖优化失败已在重试中消除，不计为业务失败。
- 真实 Info 业务 E2E 已通过（临时 port-forward + 当前 Info React 客户端，未写入业务数据）：`/info/crawl` 页面登录后渲染并在刷新后恢复；`/api/auth/me=200` 且 CSRF 存在；`/api/documents`、`/api/admin/sources`、`/api/admin/collectors`、`/api/admin/distributions` 均返回 `200` 数组；携带正确 CSRF 的非法 `POST /api/admin/crawl-jobs` 返回 `422`；浏览器无意外外连，凭据未输出。未带 CSRF 的同一请求先返回 `403`，证明安全门禁优先于 schema 校验。
- 本轮复盘发现并修复后端审计上下文缺口：后端现在生成/回显受校验的 `X-Correlation-ID`，允许并回显 `X-Operation-ID`，允许 `X-Audit-Reason` CORS 头；已认证 actor 会进入请求上下文，文档审核和 Knowledge 分发状态/重试会把 correlation、operation、actor、reason 写入内部审计记录，并在下游 Artifact Contract 载荷中剔除内部审计字段。后端单测/类型检查当前为 `67 passed`、`pyright 0 errors`；审计候选已隔离部署并完成真实 mutation→审计读取→状态恢复验证。
- 2026-07-14 本地补齐后端请求级结构化审计日志：所有 `/api/` 非读请求记录 method/path/status/actor/correlation/operation/reason_present；未处理异常按 `500` 记录；日志不写入原始 reason、凭据或正文。对应测试断言审计日志存在且不泄露 reason；后端当前仍为 `67 passed`、`pyright 0 errors`。
- 当前待推送提交链：模板前端 `c8b2bd0`（tpl-app 父仓需更新子仓指针）、Info 前端 `1f86ee7`（父仓指针 `85cb800`）、Info 后端 `8ce914e`、K8s 文档基线 `ab81ce5` 加本轮证据更新；这些提交必须与对应 candidate 镜像 digest 一起推送，不能只推其中一个仓库。
- 2026-07-14 CSP 复盘与修复：旧 candidate 的真实浏览器诊断确认 `script-src 'self'` 会拦截 React Router SPA `index.html` 的 4 个框架启动内联脚本，表现为登录回跳后页面空白。模板与 Info 均新增构建期 `scripts/generate_csp_headers.mjs`，按最终 `index.html` 内容生成精确 `sha256-*` script sources；Docker run stage 只复制生成文件，继续禁止 `unsafe-inline` 和 `unsafe-eval`。模板提交 `c8b2bd0`，Info 前端提交 `1f86ee7`，Info 父仓指针提交 `85cb800`。新候选：模板 `harbor.sunmoonai.com:30443/app-images/tpl-admin-frontend:p0-007c-csp-20260714@sha256:ad35b3c97a9a89626ae998297da2e0348d1648b418b26ab4c178f387f88fb9fa`；Info `harbor.sunmoonai.com:30443/app-images/info-admin-frontend:p0-007b-csp-20260714@sha256:f553514576d4d1bf15722aeceb514e710d6d91f7af3d2b65f302e6df9c5f4087`。
- 2026-07-14 CSP 候选验证：模板真实无头浏览器页面有渲染文本、CSP 阻断错误为 `0`、控制台错误为 `0`、响应头包含 hash；Info 候选 Docker/Nginx smoke 和 KIND 严格 TLS smoke 均通过（`health=200`、首页、`/info/crawl`、未知 asset `404`、同源 `/api/auth/me=401`、CSP、Nginx `-t`、无 Node runtime）。Info 候选同源真实 Casdoor 浏览器 E2E 通过：刷新恢复、CSRF、6 篇文档、审核可恢复 mutation、实体链接/摘要画像可恢复 mutation、sources/collectors/distributions 数组 contract、非法 crawl `422`、无外连、凭据未输出。
- 2026-07-14 来源/Collector/上传/分发 mutation 矩阵已通过：脚本 `sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_007b_info_mutation_matrix.mjs` 以真实 Casdoor 身份、真实同源 `/api` 执行；source 创建 `201`、changedetection Collector 创建 `201` 且 source 绑定、discover 生成 1 个本地 crawl job（无外部抓取）、multipart 上传 `201` 且 raw/clean/text 三类 artifact 均创建、Knowledge distribution 创建 `201` 且 contract v1、失败状态→retry→pending、dispatch `200`（本地 Knowledge 配置返回 pending）；所有 mutation 带 CSRF/correlation/operation/reason，浏览器无外连、凭据未输出。
- 2026-07-14 生产门禁验证：隔离后端临时设置 `ENV=production` 时因本地 Casdoor HTTP redirect URI 被拒绝启动（`CASDOOR_REDIRECT_URI must use HTTPS in production`），证明生产 HTTPS 回调门禁为 fail-closed；随后恢复仅用于本地浏览器矩阵的 development 配置，正式配置未改变。
- 候选后端真实可恢复 mutation 已通过：在开发库一篇现有文档上仅执行 `reviewed → active → reviewed`，以及实体链接、摘要画像的变更→审计读取→原值恢复；读取到 actor/correlation/operation/reason 审计字段，正文/标题/来源/分发未改变；审计历史按设计保留。候选后端产生请求级 `audit_mutation` 结构化日志（仅字段/布尔 `reason_present`，不由应用 logger 写入原始 reason）；开发环境的 SQL echo 会在 SQL 参数调试日志中显示持久化 JSON，这是已知开发配置行为，生产环境已由启动门禁强制使用 HTTPS 并应关闭 debug SQL echo。联合候选资源已清理，正式前后端镜像仍为 `1.0.1`。

## 验收前明确禁止

- 不把当前本地提交标记为 `P0-007B ACCEPTED`，不覆盖现有 `info-admin-frontend:1.0.1`，不修改正式 Ingress/流量。
- 必须先构建新的 candidate tag，在隔离 Deployment/Ingress 上验证首页、`/info/crawl`、未知 asset 404、CSP、严格 TLS、无 Node runtime，再做真实 Info backend contract/E2E；失败时删除隔离资源即可回到 Vue 基线。

## 回滚基线

1. 删除/回退隔离的 React Info Deployment，不触碰现有 Vue Deployment。
2. 将父仓 `info-app` 子模块恢复到 `c12022ee24a248477ebd6b7b37fbc9818d9693ff` 或 tag `p0-007b-info-admin-vue-baseline-20260714`。
3. 重新部署并确认镜像 tag `1.0.1`、digest `sha256:3ce28192f97bd38a46d47b3bc357b9d826f219cff79fa47bd05dbdb84180bc98`。
4. 通过现有 Info Admin 严格 TLS、session、403 和业务 smoke 后，才可关闭试点回滚窗口。

下一证据必须同时包含：React Info 实例提交、父仓指针、迁移镜像 tag+digest、隔离 Deployment/Ingress、真实浏览器页面无 CSP 拦截、真实 mutation→审计对账→恢复、失败矩阵和回滚演练。CSP candidate 和来源/Collector/上传/分发 mutation 矩阵均已完成构建与隔离验证；P0-007B 仍保持 `IN_PROGRESS`，下一步仅补齐重复操作、并发冲突、XSS/危险 URL 与显式回滚演练等剩余证据，不能把候选验证误标为 `ACCEPTED`，正式 `1.0.1` 流量保持不变。
