# 任务：MongoDB 按 App Backend 自动配置

## 目标

所有 App 共享 Data Platform 的 MongoDB 物理实例，但每个 Backend 使用独立
数据库、用户、密码和 Kubernetes Secret。业务代码只能使用本 Backend 的连接
Secret，不能使用 MongoDB 管理员账号。

## 当前状态

- [x] `tpl-app` 的 Admin Backend 和 Web Backend 默认启用 MongoDB。
- [x] 支持使用 Kubernetes 临时客户端 Pod 执行初始化，无需本机安装 `mongosh`。
- [x] 自动创建独立数据库、用户和 `readWrite`、`dbAdmin` 权限。
- [x] 自动生成 `<backend>-mongodb-conn` Secret。
- [x] K8s 工作负载通过 `envFrom` 引用 MongoDB Secret。
- [x] 已同步到 `info-app`、`research-app`、`investment-app` 和 `tools-app`。
- [x] Kind 中八个 Backend 的 MongoDB 资源已完成初始化。
- [x] 初始化日志不输出包含密码的 MongoDB URI。
- [ ] 在远程集群重建时执行相同的自动初始化和连通性验证。
- [ ] 增加定期权限审计、密码轮换和备份恢复演练。

## 隔离规则

1. App 是领域边界，Backend 是领域内的数据写入责任单元。
2. 每个 Backend 只能直接访问自己的 MongoDB 数据库。
3. 跨 Backend 和跨 App 读取必须通过 API、事件或任务接口。
4. MongoDB 管理员凭据只供平台初始化脚本使用。
5. Secret 名称、数据库名和用户名必须由模板确定，不能由业务代码临时创建。
