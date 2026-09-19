# Investment 声明式部署

本目录是 Investment 运行拓扑的唯一 Git 真相源。当前 `bundle/` 为 KIND 专用开发包，
不代表新的正式版本，历史正式标签保持不变。它锁定
`investment-backend`、两个 Next.js 前端、网络策略和 TLS 路由。统一 Backend 镜像分别承担
API、Celery Worker、Celery Scheduler 和一次性 Alembic Migration Job。

App 级入口：

```bash
./deploy-investment-app-all/deploy-investment-app-all.sh plan --cluster KIND
./deploy-investment-app-all/deploy-investment-app-all.sh server-dry-run --cluster KIND
./deploy-investment-app-all/deploy-investment-app-all.sh deploy --cluster KIND \
  --backup-receipt /private/path/cutover-receipt.json \
  --identity-preparation /private/path/identity-preparation
./deploy-investment-app-all/deploy-investment-app-all.sh drift --cluster KIND
./deploy-investment-app-all/deploy-investment-app-all.sh status --cluster KIND
```

组件入口位于 `deploy-investment-backend-api/`、`deploy-investment-backend-worker/`、
`deploy-investment-backend-scheduler/`、`deploy-investment-admin-frontend/`、
`deploy-investment-web-frontend/` 和 `deploy-investment-migration/`。每个入口委托给同一个
`deployment/deploy.py`，不会形成分叉 YAML。开发升级只允许全 App 事务，组件入口不可单独 apply。

正式部署会幂等收敛 Investment 专用 RabbitMQ、Redis 和 Knowledge 服务绑定，不恢复旧
Research 双 Backend。重新生成必须写入空目录并逐字比较：

```bash
python3 deployment/render.py --output-dir /tmp/investment-development \
  --release-id kind-b7-20260919 --development-input deployment/development-input.json
diff -ru deployment/bundle /tmp/investment-development
```

`deployment/evidence/` 仅保存迁移历史来源证明，不是活动部署输入。

停写、备份恢复与回执格式见 [共享部署说明](../../scripts/README.md#kind-开发包部署)。
备份脚本默认使用规范 `investment_admin`，不再使用已退役的 `research_admin`。

当前开发 apply 只消费已准备好的 Redis 身份，不自动执行旧供给脚本；它也不重开旧数据库
账号、不重写共享 broker 或 Knowledge 绑定。缺失/漂移须在维护流程中单独核实，不能
用正式路径绕过开发门禁。Redis 历史供给入口为 `prepare-investment-redis-acl-kind.sh`，
其执行涉及共享 ACL 配置，不属于当前开发 apply 的隐含动作。
受管的 `investment-redis-credential` Secret 在 data namespace 持续保留，供 Redis chart
通过 `existingSecret` 引用；不写入 Git。KIND values 中的同一 ACL 声明同时用于运行时
与启动 ConfigMap，仅放行 `investment:*` 键和频道。脚本验证正反向键/PubSub 权限及
独立 Redis 进程从持久配置启动；不重启共享 Redis。安装/升级 Redis chart 前，须先运行
该凭据收敛；缺失 Secret 时渲染会拒绝，不能退化为无密码用户。
