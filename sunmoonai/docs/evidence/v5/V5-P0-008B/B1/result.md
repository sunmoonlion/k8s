# V5-P0-008B/B1 Web Repo/Env/Rendering/Test Baseline 证据

状态：`ACCEPTED / B2_CURRENT_TASK`

日期：2026-07-18（Asia/Shanghai）

## 1. 当前结论

B1 的代码、固定提交和最终 Docker 门禁均已接受：

| 单元 | 固定提交 |
| --- | --- |
| `tpl-web-frontend` | `9e01dcfcf7981fca4413a513f7e1f42dc007cb52` |
| `tpl-web-backend` | `73eead4a7d771dd05bd61eac81f48e867e305b42` |
| `tpl-app` 双 gitlink | `6beb3638c698a32c2237fb44abc44b6814641bf4` |

三个业务 Web 仓库没有被提前修改。B1 只接受模板 Repo/Env/Rendering/Test 基线，
不赋予三个业务 Web 应用迁移或发布资格；当前唯一后续任务为 B2 Nest BFF Identity +
Next DAL/DTO。

## 2. Frontend 已完成

- 保持 React 19.2.4、Next 16.2.2、App Router、next-intl、Tailwind/shadcn/Base UI
  候选和 `output: standalone`。
- `NEXT_PUBLIC_API_URL` 只允许同源绝对 path；server-only 环境在 Node runtime
  启动期 fail-fast。
- `/en`、`/zh-CN` 为 SSG public content；Dashboard/Login 为 dynamic/no-store/
  noindex surface。
- 增加 locale-aware loading/error/not-found、global error、metadata、robots、
  sitemap 和内容语言边界。
- 增加 i18n missing-key 检查、Vitest unit/component、Playwright rendering/cache/
  404 验收。
- Playwright 运行真实 standalone 产物，不再用会产生警告的 `next start`。
- 最终 Node 镜像使用 `nextjs` 非 root 用户；构建和运行关闭 Next telemetry。
- 删除未被使用、会持久化假身份状态的旧 Zustand auth store。

本地已通过：

- typecheck；
- lint；
- i18n：2 locales、37 keys；
- Vitest：2 files、9 tests；
- Playwright：3 tests（public、workspace cache/noindex、404）；
- Next build 曾验证 `/[locale]` 为 SSG、Dashboard/Login 为 dynamic。

最终提交在增加语言属性、telemetry 和环境文件 Docker 隔离后仍通过 typecheck、
lint、i18n 和 9 个 Vitest；最终 Docker build 需按第 7 节重新执行，不能复用更早
候选镜像。

## 3. Backend 已完成

- Node/pnpm 固定为 20.18.0/10.24.x。
- 删除被 Git 跟踪的 `app/.env` 和
  `db-access-bootstrap/.env.local.k8s.db`；`.env.k8s` 不再保存真实凭据或伪
  `REQUIRED_SECRET` 值。
- Joi 启动期环境校验 fail-fast；生产环境强制 TLS verify、数据库、Redis、
  Casdoor 和前端 origin 契约，并拒绝已知占位/默认凭据。
- 删除 Redis `example` 密码 fallback 和 Cron SSH 硬编码 host/user/password；
  启用 Cron 时必须显式提供 SSH 环境。
- `/api/health` 与 `/api/version` 只返回非秘密平台元数据和发布兼容 tuple，不再
  用 cache mutation 伪装版本接口。
- 修正 boolean/version/CORS/validation pipe 和 CommonJS 默认导入互操作。
- 增加配置单测和隔离 HTTP E2E；Docker 安装读取 pnpm build-script allowlist，
  `.dockerignore` 排除宿主 `node_modules`、dist 和所有环境文件。
- 生产镜像继续使用 `appuser` 非 root 用户。

已通过：

- typecheck；
- B1 scoped lint；
- unit：2 suites、7 tests；
- HTTP E2E：1 suite、2 tests；
- Nest/SWC build：192 files；
- Docker bootstrap 的 registry/proxy 契约已上移到共享 `base` stage；首次 pnpm
  安装和两个依赖 stage 均从固定镜像、锁文件和显式代理完成，不依赖宿主
  `node_modules` 或旧 pnpm layer。

`pnpm lint:all` 仍显示旧模板 91 项历史债务（87 errors、4 warnings，其中多数是
Prettier 和旧模块问题）。这些没有被隐藏：`lint:all` 保留为全仓审计，B1 强制
lint 已覆盖本次新增/修改的环境、入口、cache、conditional、controller 和测试
文件；后续改造旧模块时逐目录纳入强制门禁，禁止用一次全仓自动修复混入无关变更。

## 4. 安全处置

Git 历史中曾出现的数据库、Redis、Casdoor 值按已泄漏处理。B1 只停止继续跟踪并
建立 fail-closed 契约，不等于凭据已轮换。B2/B4 前必须由 Secret 管理链轮换并
验证旧值失效；不得从历史提交复制回新环境。

本阶段没有修改旧 Casdoor auth 实现本身。旧实现仍缺 PKCE/nonce/state 原子消费、
discovery/JWKS、精确 issuer/audience、最小 session、CSRF/Origin 等能力，必须在
B2 整体替换，不能把 B1 的 repo/env 通过解释为身份生产资格。

## 5. 固定参考和三业务仓保护

ixartz 输入仍固定为：

```text
9926cc1f8664f67eca63065bf1c31bc4f60b09c2
```

B1 只吸收 ADR-014 已批准的工程能力；未引入 Clerk、Drizzle/PGlite、SaaS
telemetry、外部字体/CDN、GitHub 专用 release 或 Node 24 强制升级。

静态验证同时断言 Info、Knowledge、Research 的 Web Frontend/Backend 仍停留在
P0-008A 快照，未提前覆盖业务仓。

## 6. 静态验证

```bash
cd /home/zymun/k8s
python sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_008b_b1.py
```

结果：

```json
{"backend_commit":"73eead4a7d771dd05bd61eac81f48e867e305b42","business_web_repositories_unchanged":true,"frontend_commit":"9e01dcfcf7981fca4413a513f7e1f42dc007cb52","parent_commit":"6beb3638c698a32c2237fb44abc44b6814641bf4","result":"passed","secrets_printed":false,"task":"V5-P0-008B-B1-source"}
```

## 7. Docker/Runtime 门禁

执行：

```bash
cd /home/zymun/k8s
P0_HTTP_PROXY=http://192.168.32.1:7890 \
bash sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_008b_b1_docker.sh
```

脚本从三个固定提交对应的干净工作树：

1. clean build 两个镜像；
2. 验证 Frontend=`nextjs`、Backend=`appuser` 非 root；
3. 验证 Backend 镜像不含任何 `.env*`；
4. 在 Backend 镜像内执行生产环境 fail-fast 正向 contract；
5. 启动 Frontend standalone，验证 public HTML、404 和 UID 1001；
6. 对最终 Frontend 容器执行全部 4 项 Playwright（含 runtime sitemap origin）；
7. 输出两个本地不可变 image ID，且不打印 secret。

结果：

```json
{"task":"V5-P0-008B-B1-docker","result":"passed","frontend_image_id":"sha256:c440293b4b23dbb9de83fa6c0fbbccbf10014de1aa47aaf75af7d9edde48538b","backend_image_id":"sha256:b4558d4bbc20bc15f446dbfc6942daf31c14ff8da77006034c6263e865ada904","frontend_user":"nextjs","backend_user":"appuser","secrets_printed":false}
```

运行中的 Frontend readiness 首次连接可能在 Node 监听切换期间收到一次 connection
reset；门禁使用有界重试，随后 public HTML、未知路由 404、UID 1001 和 Playwright
4/4 全部通过。该启动竞态没有被误记为业务失败，也没有通过无限 timeout 掩盖。

## 8. B1 退出结论

- B1 `ACCEPTED`，允许进入 B2；
- B1 不等于身份、安全或配对发布完成，B2/B3/B4 仍是 P0-008B 必经施工包；
- Info、Knowledge、Research 的 Web Frontend/Backend 未发生模板覆盖；
- 迁移与正式 tag 仍须等待 P0-008C 真实 Research 试点及后续逐 App 迁移门禁。
