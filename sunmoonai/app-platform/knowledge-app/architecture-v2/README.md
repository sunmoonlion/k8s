# Knowledge Architecture v2 声明式部署

本目录是 Knowledge 正式运行拓扑的唯一 Git 真相源。`bundle/` 锁定统一
`knowledge-backend` 的 API、Worker、Scheduler、Migration、两个 Next.js 前端、
NetworkPolicy 与正式 TLS 路由；所有镜像均使用 Harbor digest。

默认入口：

```bash
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh plan --cluster KIND
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh server-dry-run --cluster KIND
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh deploy --cluster KIND
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh drift --cluster KIND
./deploy-knowledge-app-all/deploy-knowledge-app-all.sh status --cluster KIND
```

`deploy` 按 prerequisites/network policy → migration → runtime → ingress 收敛，
并确保旧 API 与旧 Worker 为 0 副本。它只引用预先受管的 Secret，不复制或输出凭据。
Migration Job 成功后立即删除。

RAGFlow 是 Knowledge 之外的受保护 Provider。正式 bundle 仅声明访问策略和 Provider
连接参数，不创建、不更新、不删除 RAGFlow 工作负载、数据集、文档或向量数据。

重新生成必须写到空目录并与已提交 `bundle/` 逐字比较：

```bash
python3 architecture-v2/render-formal.py --output-dir /tmp/knowledge-formal
diff -ru architecture-v2/bundle /tmp/knowledge-formal
```

`LEGACY-V1-RUNTIME.md` 只记录 R7 观察窗内的回退资产。默认部署器不会扫描旧目录；
私有备份、手工 `kubectl patch/scale/apply` 或集群当前状态均不能替代本目录。
