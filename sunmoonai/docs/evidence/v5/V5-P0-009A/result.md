# V5-P0-009A Release / Migration Freeze 证据

状态：`ACCEPTED / P0-009B_NEXT`

验收日期：2026-07-29（Asia/Shanghai）

## 1. 结论

P0-008B/B6 本地接受后，P0-009A 已冻结同一 `template_release_id` 对 Info、
Knowledge、Research 的迁移基线。本包**只冻结清单、迁移前 tag、回滚边界与串行门**，
**没有**修改三个业务 App 的工作树内容，**没有**切换稳定流量，**没有**推送 Gitee。

`template_release_id`：`p0-008b-b6-unified-20260729`

默认组件（唯一允许进入实例）：

| 组件 | commit | digest |
|---|---|---|
| `tpl-admin-frontend` | `fb69795…` | `sha256:b426551c…` |
| `tpl-admin-backend` | `69e634b…` | `sha256:b24ce7a3…` |
| `tpl-web-frontend` | `1db9377…` | `sha256:2a359c8d…` |
| `tpl-web-backend` | `289f2c4…` | `sha256:41dc3a78…` |

明确不进入实例：`tpl-admin-frontend-react`、`tpl-admin-frontend-vue`、
`tpl-web-backend-nest`。

## 2. 迁移前冻结点

本地 annotated tag（**未 push**）：`p0-009a-pre-20260729`

覆盖三父仓及其四个默认子仓（共 15 个仓库）。机器可读明细见 `freeze.json`。

父仓 HEAD：

| App | parent | branch |
|---|---|---|
| Info | `37988c8…` | `codex-1` |
| Knowledge | `2e410ad…` | `codex-1` |
| Research | `8121595…` | `codex-1` |

## 3. 保留 / 替换 / 删除

### 替换（共同底座）

每个 App 的四个表面：

- Admin Frontend：现栈（Info=React Router；Knowledge/Research=Vue）→ **Next Admin** 共同底座
- Admin Backend：同步 FastAPI Admin **通用内核**（不覆盖领域表/migration 历史）
- Web Frontend：现 Next → **Next Web** 共同底座（含 `expires_at` offset 修复）
- Web Backend：现 **Nest/Node** → **FastAPI Web BFF 默认**

### 保留

- 领域 route/page/DTO/API adapter
- 领域模型、表、Alembic lineage、worker
- 实例 audience / cookie / session namespace / ServiceAccount / 镜像名前缀
- 一切既有稳定 Git tag 与镜像 tag（回滚资产）

Admin Alembic head（源码树）：

| App | head |
|---|---|
| Info | `20260714_0004` |
| Knowledge | `20260715_0003` |
| Research | `20260712_0002` |

Web Backend 当前无 Alembic versions（Nest）；FastAPI 采用后按模板内核 migration
兼容策略前进，禁止重置领域库。

### 删除

P0-009A **删除清单为空**。后续 009B/C/D 仅可清理本包产生的临时候选资源。

## 4. KIND 现状快照（迁移前）

已部署（`app-platform-dev`）含 Info 全表面、Research Admin/Web、Knowledge Admin
Backend；**Knowledge 的 admin-frontend / web-frontend / web-backend Deployment 当前缺失**。
该缺口记入 `freeze.json`，留给 P0-009C 用候选拓扑补齐，仍不切稳定流量。

## 5. 串行与回滚纪律

1. 顺序硬门：Info → Knowledge → Research；前一 App 未 ACCEPTED 不得开始下一 App。
2. 失败只回滚该 App 到 `p0-009a-pre-20260729` 与冻结镜像引用。
3. 候选 Deployment / 隔离 Host 验证；禁止把 `p0-*` candidate 写成稳定正式流量。
4. 开发冻结：P0-009 完成前业务 App 只允许迁移适配与阻断修复。

## 6. 验证

```bash
python3 sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_009a_freeze.py
```

结果：`passed`（见本目录证据链与脚本输出）。

## 7. 下一游标

唯一下一任务：**P0-009B Info Foundation Adoption**。  
禁止跳到 Knowledge/Research/P0-008C 或新增普通业务功能。
