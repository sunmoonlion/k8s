# Knowledge 正式声明式部署

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

组件入口与 Info 使用相同操作合同，位于 `deploy-knowledge-backend-api/`、
`deploy-knowledge-backend-worker/`、`deploy-knowledge-backend-scheduler/`、
`deploy-knowledge-admin-frontend/`、`deploy-knowledge-web-frontend/` 和
`deploy-knowledge-migration/`。它们共享本目录的 digest 锁和部署实现，不维护第二份 YAML。

`deploy` 按 prerequisites/network policy → migration → runtime → ingress 收敛。旧 v1 API、
Worker 和双 Backend 部署生成器已在 R7 后退役收口中删除；默认入口不会重建它们。它只引用
预先受管的 Secret，不复制或输出凭据。
Migration Job 成功后立即删除。

RAGFlow 是 Knowledge 之外的受保护 Provider。正式 bundle 仅声明访问策略和 Provider
连接参数，不创建、不更新、不删除 RAGFlow 工作负载、数据集、文档或向量数据。

重新生成必须写到空目录并与已提交 `bundle/` 逐字比较：

```bash
python3 deployment/render.py --output-dir /tmp/knowledge-formal
diff -ru deployment/bundle /tmp/knowledge-formal
```

v1 声明保留在 Git 历史、`2.0.0` 标签和 R5/R7 证据中，不再复制到活动目录。私有备份、
手工 `kubectl patch/scale/apply` 或集群当前状态均不能替代本目录。
