# Info Architecture v2 声明式部署

本目录是 Info 当前正式运行拓扑的唯一 Git 真相源。`bundle/` 锁定统一
`info-backend` 的 API、Worker、Scheduler、Migration 两个 Next.js 前端、NetworkPolicy
及四条正式 TLS 路由；所有镜像必须使用 Harbor digest。

默认入口：

```bash
./deploy-info-app-all/deploy-info-app-all.sh plan --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh server-dry-run --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh deploy --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh drift --cluster KIND
./deploy-info-app-all/deploy-info-app-all.sh status --cluster KIND
```

`deploy` 按 prerequisites/network policy -> migration -> runtime -> ingress 的顺序收敛，
并确保六个 v1 Deployment 为 0 副本。它只引用集群中预先受管的 Secret，不复制、不输出凭据。
Migration Job 成功后立即删除。

重新生成必须写到空目录并与已提交 `bundle/` 逐字比较：

```bash
python3 architecture-v2/render-formal.py --output-dir /tmp/info-formal
diff -ru architecture-v2/bundle /tmp/info-formal
```

`legacy-v1/` 只保留 R7 观察窗所需的回滚声明；默认部署器不会扫描它。任何私有 state bundle、
手工 `kubectl patch/scale/apply` 或集群当前状态都不能替代本目录。
