# Investment Architecture v2 部署入口

本目录保存 Investment Architecture v2 正式运行态的唯一 Git 真相源。旧 Research 产品只作为
R7 观察窗内的原生回滚资产保留；默认入口绝不部署旧 Admin/Web 双 Backend。

唯一部署模型：

```text
investment-admin-frontend (Next.js) ─┐
                                     ├─ investment-backend (FastAPI)
investment-web-frontend   (Next.js) ─┘       ├─ API
                                             ├─ Celery Worker
                                             └─ Celery Scheduler
```

`architecture-v2/bundle/` 锁定统一 Backend 的 API、Worker、Scheduler、Migration、双 Next.js
前端、正式 TLS 路由和最小 NetworkPolicy；镜像全部使用 `repository@sha256:digest`。

默认入口：

```bash
./deploy-investment-app-all/deploy-investment-app-all.sh plan --cluster KIND
./deploy-investment-app-all/deploy-investment-app-all.sh server-dry-run --cluster KIND
./deploy-investment-app-all/deploy-investment-app-all.sh deploy --cluster KIND
./deploy-investment-app-all/deploy-investment-app-all.sh drift --cluster KIND
./deploy-investment-app-all/deploy-investment-app-all.sh status --cluster KIND
```

`deploy` 会幂等收敛专用 RabbitMQ/Redis、激活 Investment→Knowledge 身份、运行 Migration、
部署五个正式工作负载，并把旧 Research 六组件保持为 0 副本。它不会重建或覆盖
`investment_admin` 业务数据，也不会删除 `research_admin`、旧 Secret、PVC 或镜像。

重新生成必须写入空目录并与已提交 bundle 逐字比较：

```bash
python3 architecture-v2/render-formal.py --output-dir /tmp/investment-formal
diff -ru architecture-v2/bundle /tmp/investment-formal
```

`release-inputs.json` 只保留 R4 历史来源证明，不是部署入口。原生回滚必须走受保护的 R5/R7
专用流程；私有备份、手工 patch 或集群当前状态均不能替代本目录。
