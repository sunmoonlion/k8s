# V5-P0-008B/B1 Repo/Env/Rendering/Test/Runtime Baseline 证据

状态：`ACCEPTED / NODE24_RUNTIME_BASELINE / IMPLEMENTATION_PAUSED`

日期：2026-07-18（Asia/Shanghai）

## 1. 当前结论

B1 已在 Node 20 EOL 后重新执行生命周期审查、源码门禁和干净容器门禁。当前唯一有
新发布资格的模板运行时基线是 Node `24.18.0` LTS、pnpm `10.24.x`；更早的 Node
20 B1 只保留为历史证据，不再允许产生新发布。

| 单元 | 固定提交 |
| --- | --- |
| `tpl-admin-frontend` | `1561e5d02251ccc0f96fa48e272e4c5072a1e2c3` |
| `tpl-web-frontend` | `f5340ac9c9b63d8179b9a5dc8feff3e85fb213ab` |
| `tpl-web-backend` | `f5bedfb3ebd8ad3696545b1d0feb0a945ee1866f` |
| `tpl-app` 三个 gitlink | `fe297396b07a05d684f985beac4f0292058f11b4` |

本次修订只统一模板运行时和重跑 B1，没有开始 B2，也没有修改 Info、Knowledge、
Research 的业务 Web 仓库。按项目负责人要求，从本证据接受起暂停进一步实施，先
讨论架构与施工问题；不得把 `ACCEPTED` 误读为已授权自动进入 B2。

## 2. 冻结的运行时 tuple

| 维度 | 冻结值 |
| --- | --- |
| Node | `24.18.0` LTS；本地 engine `>=24.18.0 <25` |
| pnpm | `10.24.0`；engine `10.24.x` |
| JOSE | `6.2.3`；Node 24 CommonJS compatibility smoke 已通过 |
| Linux 架构 | `linux/amd64` |
| 基础镜像 | `harbor.sunmoonai.com:30443/k8s-images/node:24.18.0-alpine` |
| 不可变摘要 | `sha256:4ba75f835bb8802193e4c114572113d4b26f95f6f094f4b5229d2a77773e0afc` |

`.nvmrc`、`.node-version`、`packageManager`、`engines`、Dockerfile、构建脚本和文档
已对齐到同一 tuple。Docker 发布证据必须使用上述精确 digest，不能只引用可变 tag。

该冻结不是“永远不升级”。ADR-014 要求至少每季度审查 Node 生命周期，并最迟在 EOL
前六个月完成下一次兼容、镜像、回滚验证；未经审查不得因为上游模板变动自动追随
新 major。

## 3. Admin 模板门禁

`tpl-admin-frontend` 已从旧 Node/pnpm 漂移统一到上述 tuple。已通过：

- typecheck、lint；
- Vitest：10 files、41 tests；
- React Router SPA production build；
- `verify:production`；
- Docker clean build；
- Nginx 配置、`/health=ok`、运行镜像不含 Node。

最终本地候选镜像 ID：

```text
sha256:af2d6fb8401d97ec860dda0d548cecfa4ba8a0a8a757120699954c6412316e33
```

Admin 运行镜像仍是纯 Nginx；Node 24 只存在于可信构建阶段，不扩大生产攻击面。

## 4. Next Frontend 已完成

- 保持 React 19.2.4、Next 16.2.2、App Router、next-intl、Tailwind/shadcn/Base UI
  候选和 `output: standalone`。
- `NEXT_PUBLIC_API_URL` 只允许同源绝对 path；server-only 环境在 Node runtime
  启动期 fail-fast。
- `/en`、`/zh-CN` 为 SSG public content；Dashboard/Login 为 dynamic/no-store/
  noindex surface。
- locale-aware loading/error/not-found、global error、metadata、robots、sitemap 和
  内容语言边界已建立。
- Playwright 运行真实 standalone 产物；最终镜像使用 `nextjs` 非 root 用户并关闭
  Next telemetry。
- 未使用的浏览器持久化假身份 store 已删除。

本地门禁已通过 typecheck、lint、i18n（2 locales、37 keys）、Vitest（2 files、
9 tests）和 production build。最终 clean-room 容器门禁又执行 4 项 Playwright：
public rendering/index、workspace dynamic/noindex、unknown route、runtime sitemap origin，
结果 `4/4 passed`。

## 5. Nest Backend 已完成

- Node/pnpm/JOSE 固定为 `24.18.0`/`10.24.x`/`6.2.3`。
- 删除被 Git 跟踪的环境文件；模板不再保存真实凭据、默认密码或伪 secret。
- Joi 启动期环境校验 fail-fast；生产环境强制 TLS verify、数据库、Redis、Casdoor、
  origin 和发布 compatibility tuple。
- `/api/health` 与 `/api/version` 仅返回非秘密平台元数据。
- Docker 安装只读取锁文件和显式 registry/proxy，不复制宿主 `node_modules` 或环境文件。
- 生产镜像使用 `appuser` 非 root 用户。

已通过 typecheck、B1 scoped lint、unit（2 suites、7 tests）、HTTP E2E（1 suite、
2 tests）、Nest/SWC build（192 files）和最终 clean-room production fail-fast contract。

`pnpm lint:all` 仍保留旧模板 91 项历史债务审计（87 errors、4 warnings，主要是旧模块
Prettier/风格问题）。本次没有隐藏或批量改写无关代码；改造旧模块时必须逐目录纳入
强制门禁。

## 6. 安全处置

Git 历史中曾出现的数据库、Redis、Casdoor 值继续按已泄漏处理。本阶段停止跟踪并
建立 fail-closed 契约，不等于凭据已经轮换；B2/B4 前仍须由 Secret 管理链轮换并
验证旧值失效。

本阶段没有实现 B2 身份内核。PKCE/nonce/state 原子消费、discovery/JWKS、精确
issuer/audience、最小 session、CSRF/Origin 等仍属于 B2，B1 通过不赋予身份生产资格。

## 7. 固定参考与业务仓保护

ixartz 只读输入继续固定为：

```text
9926cc1f8664f67eca63065bf1c31bc4f60b09c2
```

它仍只是工程实践输入，不是运行时依赖。Clerk、Drizzle/PGlite、SaaS telemetry、外部
字体/CDN、GitHub 专用发布链均未引入。

静态门禁断言 Info、Knowledge、Research 的 Web Frontend/Backend 仍位于 P0-008A
快照；本轮没有提前覆盖、迁移、打正式 tag 或切业务流量。

## 8. 静态验证

执行：

```bash
cd /home/zymun/k8s
python sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_008b_b1.py
```

结果：

```json
{"admin_commit":"1561e5d02251ccc0f96fa48e272e4c5072a1e2c3","backend_commit":"f5bedfb3ebd8ad3696545b1d0feb0a945ee1866f","business_web_repositories_unchanged":true,"frontend_commit":"f5340ac9c9b63d8179b9a5dc8feff3e85fb213ab","node_image_digest":"sha256:4ba75f835bb8802193e4c114572113d4b26f95f6f094f4b5229d2a77773e0afc","node_version":"24.18.0","parent_commit":"fe297396b07a05d684f985beac4f0292058f11b4","result":"passed","secrets_printed":false,"task":"V5-P0-008B-B1-source"}
```

## 9. Docker/Runtime 门禁

执行：

```bash
cd /home/zymun/k8s
P0_HTTP_PROXY=http://192.168.32.1:7890 \
bash sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_008b_b1_docker.sh
```

脚本从固定提交对应的干净工作树构建 Next/Nest 镜像，验证 Node 24 基础镜像摘要、
非 root、环境文件隔离、生产 fail-fast、standalone 页面、404、运行时 sitemap 和
Playwright 4/4。最终结果：

```json
{"task":"V5-P0-008B-B1-docker","result":"passed","frontend_image_id":"sha256:1d1bca80fde1dbcbe83640e775c98886f50db273277c9fab340a709bac2f4213","backend_image_id":"sha256:7636648c43539687508de88fc66ed70e0d65d54a8718b522b47d14e8fa67b298","frontend_user":"nextjs","backend_user":"appuser","secrets_printed":false}
```

readiness 首次连接可能在监听切换时收到一次 connection reset；门禁使用有界重试，
随后全部 contract 和 Playwright 通过。没有使用无限 timeout 或忽略最终失败。

## 10. 历史基线处置与暂停点

- 更早的 Node 20 固定提交和镜像仅作审计历史，状态为 `SUPERSEDED / NO_NEW_RELEASE`；
- 当前 B1 状态为 `ACCEPTED / NODE24_RUNTIME_BASELINE`；
- P0-008B 整体仍为 `IN_PROGRESS`，因为 B2/B3/B4 尚未完成；
- B2 没有开始，P0-008C 没有开始，三个业务 Web 实例没有迁移；
- 当前施工状态为 `IMPLEMENTATION_PAUSED`。恢复实施必须先完成项目负责人要求的讨论，
  明确记录决定和必要措施后，才能重新指定下一项唯一代码任务。
