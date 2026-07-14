# V5-P0-007A2 / A2.5 Production Gate

状态：`IN_PROGRESS`（clean-room、Docker/Nginx 本地 smoke 已接受；Harbor digest/KIND 待验收）

## 固定实现

- 模板仓库：`tpl-admin-frontend`
- 实现提交：`168ed144e419a5b4b01abc2224d345a8ccd9785a`
- 父仓指针：`tpl-app@b884ad404940e92013979642db82ab178c95b5af`
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

候选镜像：`tpl-admin-frontend:a25-candidate-20260714`。容器 `tpl-admin-frontend-a25-smoke` 通过 `/health`、根页面、`/rich-reference` deep-link、未知 asset `404`、CSP 响应头、`nginx -t`，并确认运行容器不存在 Node runtime。第一次 readiness probe 出现一次 `curl 56` 连接重置，随后重试成功；该瞬态已通过显式 readiness loop 收敛，不能作为失败证据。当前尚未产生 Harbor 镜像 digest。

## 尚未完成的外部门禁

以下项目必须在目标 Docker/KIND 环境执行并回填原始命令、镜像 digest、部署 commit 和清理结果后，才能把状态改为 `ACCEPTED` / `TEMPLATE_MIGRATION_READY`：

1. 将候选镜像推送到 Harbor，记录不可变镜像 digest。
2. 以固定镜像 digest 部署 KIND 隔离入口，执行严格 TLS/浏览器 smoke，并记录回滚路径。
3. 只有以上证据齐全，才可勾选能力矩阵 P0-007A2 退出条件并开始 P0-007B；在此之前禁止同步三个业务 Admin。

## 防止重复失误

- 本地通过、镜像构建、KIND 部署、浏览器验收、tag/digest 固化是五个不同状态；任何一个没有证据都不能写 `ACCEPTED`。
- 先固定模板 commit，再生成父仓指针、镜像 tag/digest 和证据；禁止从未提交工作树构建迁移基线。
- 业务 App 只在 P0-007A2 与 P0-007C 都接受后按 Info -> Knowledge -> Research 串行原地替换；不创建新仓库、不提前切流量。
