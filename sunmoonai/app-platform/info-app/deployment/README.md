# Info 声明式部署

本目录是 Info 当前运行拓扑的唯一 Git 真相源。当前 bundle 是 KIND 专用开发包，
不代表新的正式版本；历史正式包与标签保持不变。`bundle/` 锁定统一
`info-backend` 的 API、Worker、Scheduler、Migration 两个 Next.js 前端、NetworkPolicy
及四条正式 TLS 路由；所有镜像必须使用 Harbor digest。

默认入口：

```bash
./deploy-info-app-all/deploy-info-app-all.sh plan --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh server-dry-run --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh deploy --cluster KIND \
  --backup-receipt /private/path/cutover-receipt.json \
  --identity-preparation /private/path/identity-preparation
./deploy-info-app-all/deploy-info-app-all.sh drift --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh status --cluster KIND
```

组件入口（均支持 `plan`、`server-dry-run`、`deploy`、`status` 和 `drift`；Migration 的
`drift` 由 App 总入口核验，因为成功 Job 会被删除）：

| 入口 | 组件 |
| --- | --- |
| `deploy-info-backend-api/` | FastAPI API |
| `deploy-info-backend-worker/` | Celery Worker |
| `deploy-info-backend-scheduler/` | Celery Scheduler |
| `deploy-info-admin-frontend/` | Admin Next.js |
| `deploy-info-web-frontend/` | Web Next.js |
| `deploy-info-migration/` | Alembic Migration Job |

`deploy` 按 prerequisites/network policy -> migration -> 开发身份授权验收 -> runtime -> ingress 收敛。
六个 v1 Deployment 已在 R7 后退役收口中删除；默认入口不会重建它们。它只引用集群中预先
受管的 Secret，不复制、不输出凭据。
Migration Job 成功后立即删除。

重新生成必须写到空目录并与已提交 `bundle/` 逐字比较：

```bash
python3 deployment/render.py --output-dir /tmp/info-development \
  --release-id kind-b7-20260919 --development-input deployment/development-input.json
diff -ru deployment/bundle /tmp/info-development
```

v1 声明保留在 Git 历史、`2.0.0` 标签和 R5/R7 证据中，不再复制到活动目录。任何私有 state
bundle、手工 `kubectl patch/scale/apply` 或集群当前状态都不能替代本目录。

开发升级只允许全 App 事务，组件入口可用于 plan/status/dry-run，不可单独 apply。
备份恢复、旧进程停写与回执格式见 [共享部署说明](../../scripts/README.md#kind-开发包部署)。
