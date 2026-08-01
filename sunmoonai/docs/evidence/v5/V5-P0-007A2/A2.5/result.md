# V5-P0-007A2 / A2.5 Production Gate

状态：`ACCEPTED`（2026-07-14；P0-007A2 = TEMPLATE_MIGRATION_READY）

## 固定实现

- 模板仓库：`tpl-admin-frontend`
- 实现提交：`f24500f6d8f437a0162fa4939d3ed6b9b8ddbcf1`
- 父仓指针：`tpl-app@f0ea6d616a8e7ed59d29d76e553c77d2c51cb8f0`
- 业务 App：未修改，未部署，未切流量。

## 已通过的模板本地门禁

在固定实现提交的工作树中执行：

```text
pnpm test                 # 10 files / 39 tests passed
pnpm typecheck            # passed
pnpm lint                 # passed
pnpm verify:production    # {"task":"V5-P0-007A2/A2.5","result":"passed"}
pnpm test:e2e             # 7 Chromium tests passed
pnpm build                # passed; static SPA output
BASE_PATH=/admin pnpm build # passed; assets use /admin/assets/*
```

`verify:production` 检查 CSP 不含 `unsafe-eval`、Nginx health/history/assets fallback、Docker 构建包含 lint，并实际确认 `VITE_AUTH_MODE=demo` 在生产构建中被拒绝。`mybuild/Dockerfile` 的 build stage 已固定执行 `typecheck -> lint -> test -> build`，run stage 仅复制静态产物到 Nginx。

浏览器新增覆盖：reduced-motion 媒体偏好、键盘焦点保持、移动 Drawer、富组件 reference、登出 POST。A2.2 已有的真实 Casdoor/CSRF/CORS/401/403/严格 TLS 证据继续作为身份前置，不在本文件重复伪造。

## Clean-room 结果

从固定 `488585f81a13e8d2f51378dffb36f653b90dc881` 全新目录完成离线安装和全量门禁：39 个 Vitest、`verify:production`、typecheck、lint、正式 build、7 个 Chromium Playwright 全部通过。工作目录：`/tmp/tpl-admin-frontend-a25-clean.XEHGyu`。

## Docker/Nginx 结果

候选镜像：`tpl-admin-frontend:a25-candidate-20260714`。容器 `tpl-admin-frontend-a25-smoke` 通过 `/health`、根页面、`/rich-reference` deep-link、未知 asset `404`、CSP 响应头、`nginx -t`，并确认运行容器不存在 Node runtime。第一次 readiness probe 出现一次 `curl 56` 连接重置，随后重试成功；该瞬态已通过显式 readiness loop 收敛，不能作为失败证据。Harbor 固化镜像：`harbor.sunmoonai.com:30443/app-images/tpl-admin-frontend:a25-20260714@sha256:44301ec3651cf822bb866db1253112634470463b92c05ecb3a52f2c7a0eb3278`。

## KIND 严格 TLS 结果

使用 Harbor 固定 digest 创建隔离 `tpl-admin-frontend-a25` Deployment、Service 和 Traefik IngressRoute；严格 CA/SNI 访问 `https://tpl-admin-a25.sunmoonai.com:19443`，首页、`/rich-reference`、未知 asset `404`、CSP 和无 Node runtime 全部通过。首次 readiness probe 在 port-forward 建立前出现一次 `curl (7)`，随后重试成功；最终 smoke 输出 `A2.5 KIND strict TLS smoke passed`。验收退出时临时资源已删除，三个业务前端 Deployment 未修改。

## 迁移边界

P0-007A2 现在已达到 `TEMPLATE_MIGRATION_READY`，模板冻结提交为 `f24500f6d8f437a0162fa4939d3ed6b9b8ddbcf1`，父仓指针为 `tpl-app@f0ea6d616a8e7ed59d29d76e553c77d2c51cb8f0`。这不是三个业务 App 已迁移。下一步只能按 P0-007B 在现有 Info Admin 仓库内建立迁移前 tag、固定镜像 digest、隔离入口和回滚路径，先完成 Info，再 Knowledge，最后 Research；禁止批量替换或创建新业务仓库。

## 防止重复失误

- 本地通过、镜像构建、KIND 部署、浏览器验收、tag/digest 固化是五个不同状态；任何一个没有证据都不能写 `ACCEPTED`。
- 先固定模板 commit，再生成父仓指针、镜像 tag/digest 和证据；禁止从未提交工作树构建迁移基线。
- 业务 App 只在 P0-007A2 与 P0-007C 都接受后按 Info -> Knowledge -> Research 串行原地替换；不创建新仓库、不提前切流量。
