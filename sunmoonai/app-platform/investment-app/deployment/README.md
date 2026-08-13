# Investment 正式声明式部署

本目录是 Investment 正式运行拓扑的唯一 Git 真相源。`bundle/` 锁定正式 `2.0.0`
`investment-backend`、两个 Next.js 前端、网络策略和 TLS 路由。统一 Backend 镜像分别承担
API、Celery Worker、Celery Scheduler 和一次性 Alembic Migration Job。

App 级入口：

```bash
./deploy-investment-app-all/deploy-investment-app-all.sh plan --cluster KIND
./deploy-investment-app-all/deploy-investment-app-all.sh server-dry-run --cluster KIND
./deploy-investment-app-all/deploy-investment-app-all.sh deploy --cluster KIND
./deploy-investment-app-all/deploy-investment-app-all.sh drift --cluster KIND
./deploy-investment-app-all/deploy-investment-app-all.sh status --cluster KIND
```

组件入口位于 `deploy-investment-backend-api/`、`deploy-investment-backend-worker/`、
`deploy-investment-backend-scheduler/`、`deploy-investment-admin-frontend/`、
`deploy-investment-web-frontend/` 和 `deploy-investment-migration/`。每个入口委托给同一个
`deployment/deploy.py`，所以可独立部署但不会形成分叉 YAML。

正式部署会幂等收敛 Investment 专用 RabbitMQ、Redis 和 Knowledge 服务绑定，不恢复旧
Research 双 Backend。重新生成必须写入空目录并逐字比较：

```bash
python3 deployment/render.py --output-dir /tmp/investment-formal
diff -ru deployment/bundle /tmp/investment-formal
```

`deployment/evidence/` 仅保存迁移历史来源证明，不是活动部署输入。
