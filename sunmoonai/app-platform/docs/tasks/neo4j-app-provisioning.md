# 任务：Neo4j App 接入与隔离

## 目标

Neo4j 作为 Data Platform 的可选图数据库能力，由需要图模型的 App 显式启用。
平台负责连接、凭据、权限和重建流程，业务 App 负责自己的图数据模型。

## 当前结论

Kind 当前运行 Neo4j `5.26.11 Community`。Community 版本不具备 Enterprise
的多数据库和细粒度角色隔离能力，因此暂不能按 PostgreSQL、MongoDB 的方式为
每个 Backend 自动创建独立数据库、用户和授权。

在隔离能力满足前，不把 Neo4j 默认启用到 `tpl-app`，也不向四个 App 分发共享
管理员凭据或伪装成独立租户的连接 Secret。

## 实施阶段

- [x] 确认平台已有 Neo4j Helm 部署和 Kind 实例。
- [x] 检测当前实例版本为 Community。
- [x] 修复 Neo4j Chart 的 Secret key 映射，使声明的密码文件名与实际挂载一致。
- [ ] 决定长期方案：Neo4j Enterprise 多数据库，或每个需要强隔离的 App 独立实例。
- [ ] 实现能力检测；隔离能力不足时自动配置必须明确失败。
- [ ] 在 `tpl-app` 增加默认关闭的 Neo4j 配置和部署注入。
- [ ] 为实际使用 Neo4j 的 Backend 创建独立连接 Secret。
- [ ] 分别验证 Kind 和远程集群的重建、备份、恢复和权限审计。

## 启用门槛

只有同时满足以下条件才允许某个 Backend 启用 Neo4j：

1. 已明确该 Backend 是相关图数据的唯一写入者。
2. 数据库或实例级隔离已经落实。
3. 应用凭据不具备管理员权限，也不能访问其他 App 的图数据。
4. Secret 能由集群重建流程自动恢复。
5. 已确定备份、恢复、迁移和版本升级方案。
