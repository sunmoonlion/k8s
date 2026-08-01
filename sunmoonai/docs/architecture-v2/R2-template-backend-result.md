# Architecture v2 R2 模板 Backend 合并结果

日期：2026-08-01

结果：`PASSED`

适用分支：`architecture-v2`

本结果仅关闭 R2。候选镜像尚未晋级正式 `2.0.0`，也没有部署到 KIND 或任何实例 App；
Kubernetes、严格 TLS、真实 Casdoor、探针和角色清单属于 R3。

## 1. 权威源码

| 组件 | Commit | 结果 |
| --- | --- | --- |
| `tpl-backend` | `8997e9e9422fd5fefaff6ab3519bd0367075fdb0` | Admin/Web 共用 FastAPI Backend |
| `tpl-admin-frontend` | `f993e1211b1a1a1d0029aeefa4c7044e32137275` | Next.js Admin 与统一 Backend 配对 |
| `tpl-web-frontend` | `b586884d0f937ac15d83fbcf2ff4851bcebd43b5` | Next.js Web 与统一 Backend 配对 |
| `tpl-app` | `5454c54e8ddd82501f6f5c6d463accad99b10b2a` | 锁定三组件 gitlink 与共享契约向量 |

Backend 版本为 `2.0.0.dev0`，镜像标签使用 `arch-v2-r2-*`。未创建、移动或覆盖正式
`2.0.0`/`1.0.0` 标签。

## 2. 合并结果

- 单一 Backend 对外分离 `/api/admin/v1`、`/api/web/v1` 和双 OIDC auth surface；
- Admin/Web 使用不同 cookie、Redis namespace、audience、client 和授权策略；
- 同一镜像提供 API、Worker、Scheduler、Migration 启动入口；
- 提供 `/health/live`、`/health/ready`，旧 `/api/health` 仅作为 readiness alias；
- 统一 RFC 7807 错误响应并保留受控兼容 envelope；
- 服务身份校验覆盖签名、issuer、audience、时间、subject binding 和 scope 交集；
- 建立事务 Outbox、租约式 claim、幂等 Inbox 和单一 Alembic head；
- Reference interaction 只能在非生产显式开启，默认 fail-closed；
- Admin/Web 两个 Next.js 运行时只通过 `BACKEND_INTERNAL_URL` 调用同一 Backend。

## 3. 静态、单元和迁移门禁

Backend：

```text
ruff: passed
pyright: 0 errors, 0 warnings
pytest: 43 passed, 2 skipped
alembic heads: 20260801_0002 (head)
```

两个 skip 是依赖配对环境的共享 interaction 向量，不被算作已通过；它们已由下节真实
Backend + Playwright 配对门禁覆盖。

Admin Next：

```text
typecheck: passed
eslint: passed
vitest: 42 passed
production build: passed
```

Web Next：

```text
typecheck: passed
eslint: passed
vitest: 44 passed, 2 environment-dependent vectors skipped
production build: passed
```

## 4. 隔离真实配对门禁

权威脚本：`architecture-v2/scripts/verify_r2_template_pair.py`。

脚本只创建并清理命名为 `arch-v2-r2-*` 的临时 Docker 网络、PostgreSQL、Redis 和容器，
不修改 KIND、Harbor 配置或开发数据库。它实际验证了迁移、数据库语义、角色入口、两个
Next.js 服务和两套浏览器会话，不使用 JS 假 Backend。

结果：

```json
{
  "task": "architecture-v2-r2-template-pair",
  "result": "passed",
  "backend_role": "api",
  "migration_head": "20260801_0002",
  "migration_roundtrip": "passed",
  "outbox_and_inbox": "passed",
  "worker_and_scheduler_bootstrap": "passed",
  "admin_playwright": "10/10",
  "web_playwright": "6/6",
  "surface_isolation": true,
  "csrf_fail_closed": true,
  "runtime_non_root": true,
  "build_proxy_in_runtime": false,
  "credentials_printed": false
}
```

迁移往返顺序为：

```text
base -> 20260726_0001 -> 20260801_0002
20260801_0002 -> 20260726_0001 -> base
base -> 20260726_0001 -> 20260801_0002
```

结束后 `arch-v2-r2-*` 容器和网络均为零残留。

## 5. Harbor 候选镜像

以下 digest 已从 Harbor 远端 manifest 重新读取并与本地门禁对象一致：

| 组件 | 候选标签 | OCI index digest | 运行用户 |
| --- | --- | --- | --- |
| Backend | `tpl-backend:arch-v2-r2-8997e9e` | `sha256:131793e27f5782511b7e6f8ce4c688639f9c2d460fe57fbe1ea805989ca481f1` | `appuser` |
| Admin | `tpl-admin-frontend:arch-v2-r2-f993e12` | `sha256:84c8343f57ae2475cc11bd871379bb7b506ed2b81b474a20affcc9249a6c5f81` | `nextjs` |
| Web | `tpl-web-frontend:arch-v2-r2-b586884` | `sha256:ea5d872c82c764b01eaa427a32e6393b9197e9842a002d4c8cad2ef7b5648808` | `nextjs` |

三个运行时均无 `HTTP_PROXY`/`HTTPS_PROXY` 环境泄漏，镜像 revision label 与上表源码
commit 完全一致，version label 为 `2.0.0-dev.0`。

## 6. 回滚与保留边界

- 旧 Admin Backend 源码仍可由 `tpl-backend` 的
  `pre-architecture-v2-20260801` 回到
  `69e634b8e5b06da9d1dcd01c9b1350e0571d74bd`；
- 旧 `tpl-web-backend` 保持未修改，当前仍是
  `289f2c46410e0aa2891fdf3da28242ceb1a33bdb`；
- `pre-refactor-source-lock.json` 与 `pre-refactor-image-lock.json` 中的 v1 源码及镜像 digest
  保持受保护；
- 没有归档旧仓、删除旧镜像、切换实例或变更数据库所有权。

R2 的回滚是源码、镜像和迁移链可达性验证；真实 Kubernetes 切换与回滚演练在 R3/R7
分别完成。

## 7. 结论

R2 退出条件“模板三组件可在隔离环境以不可变 digest 完整运行”已经满足。下一步只能进入
R3 K8s 模板重构；R3 通过前不得同步 Info/Knowledge/Research，也不得开始新的业务功能。
