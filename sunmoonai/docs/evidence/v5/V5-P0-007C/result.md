# V5-P0-007C React Admin v1 修正与冻结

状态：`ACCEPTED`

日期：2026-07-14（Asia/Shanghai）

## 结论

P0-007C 的模板修正、迁移契约、clean-room 构建和三个现有 Admin 仓库的只读迁移 dry-run 均完成。React Admin v1 现在具备 `TEMPLATE_MIGRATION_READY` 资格；本任务没有修改 Info、Knowledge、Research 的正式工作树、父仓 gitlink、Deployment、镜像 tag 或流量。

## 冻结来源

- 模板功能提交：`tpl-admin-frontend@1ddb056d62646eb6f4e08d7afd7acdb7a88f38e4`（审计确认上传前置能力及测试）。
- 模板冻结提交：`tpl-admin-frontend@be4bf3dcaa1b70e5c659169831b8bee9da668fdc`（加入 React Admin v1 原地迁移清单）。
- `tpl-app` 父仓 gitlink 提交：`tpl-app@28469db`。
- 迁移清单：`tpl-admin-frontend/docs/react-admin-v1-migration-checklist.md`。
- 只读验证脚本：`sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_007c_admin_migration_dry_run.sh`。

冻结的运行基线为 React 19.2.7、React Router 8.2.0 Framework Mode（`ssr: false`）、TypeScript 5.9.3、Ant Design 6、Lucide registry、TanStack Query、Zustand；生产镜像只运行 Nginx 静态产物，不包含 Node runtime。依赖锁、Docker/Nginx、CSP hash、同源 `/api`、会话/CSRF、测试和回滚约束随模板提交冻结。

## 差异审查

- `template/common`：Info 试点反馈的 `ContractUpload.onBeforeUpload` 审计确认前置回调回收到模板，并补充模板测试；图标能力矩阵改为“受控本地图标 registry，远程图标必须经过单独 adapter/ADR”。
- `Info-specific`：`app/lib/info-api.ts`、`app/routes/info-crawl.tsx` 以及 Info 导航、DTO、API 路由和业务文案继续留在 Info，不进入模板。
- `Knowledge/Research-specific`：在后续各自原地迁移时保留各自 DTO、导航、API、领域路由和状态；当前未复制到模板或互相复制。
- `deferred`：Vditor WYSIWYG、Howler/Video.js 高级 runtime、ECharts 全量 option、远程 Iconify、PWA/Electron 均未伪装为已实现，按 ADR/owner/触发条件单独推进。

## 已通过的验证

模板固定提交的 clean-room 验证从零 checkout 并离线安装依赖，结果如下：

- `pnpm typecheck`：通过。
- `pnpm lint`：通过。
- `pnpm test -- --run`：10 个文件、41 个测试通过。
- `pnpm build`：通过。
- `pnpm test:e2e`：7 个 Chromium 测试通过。
- `pnpm verify:production`：`V5-P0-007A2/A2.5` 通过。
- Docker/Nginx smoke：health、history fallback、deep link、404、CSP、安全 headers、`nginx -t`、无 Node runtime 均通过。

三 App 迁移 dry-run（脚本为只读，未访问网络）结果：

| App | 分支 | 当前前端提交 | 模板 clean-room | 父仓 gitlink | 变量映射 |
| --- | --- | --- | --- | --- | --- |
| Info | `codex-1` | `429f31578a80d6054d895f89a45415bcafe81408` | 通过 | 未改变 | `/api`、`info:admin`、`sunmoonai_info_admin_sid` |
| Knowledge | `master` | `1fc2cc611c063e5f706cb4164da3281bf3878416` | 通过 | 未改变 | `/api`、`knowledge:admin`、`sunmoonai_knowledge_admin_sid` |
| Research | `master` | `0ba13f3c57d951086258fa6b666278b5d759503f` | 通过 | 未改变 | `/api`、`research:admin`、`sunmoonai_research_admin_sid` |

脚本最终输出：`P0-007C admin migration dry-run passed (Info -> Knowledge -> Research; no App repository changed)`。

## 发布边界

- 本证据不代表三个 App 已完成 React 替换；它只证明替换来源、变量契约和串行施工步骤可重复。
- 不创建 `*-react`、`*-next-v2` 或新的业务仓库；后续必须在现有三个 Admin 子仓原地替换。
- Info 的 P0-007B candidate digest 保持不可变，正式 `1.1.0` 提升仍需按 Gate P0、正式 digest 核对、canary 和回滚证据执行；旧 `1.0.1` 保持 Vue 回滚资产，不覆盖、不删除。
- 下一步为按 Info → Knowledge → Research 串行执行真实迁移，每个 App 都必须先打迁移前 tag、记录镜像 digest/Deployment/回滚命令，再做隔离候选验证；不得批量覆盖或跳过证据。
