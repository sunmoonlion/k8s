# 知识应用

管理知识摄入与派生检索，RAGFlow为派生索引，Info原文仍是权威。读取精确原文VersionId，不创建第二份权威原文。

## 配置导航

本目录保留平台→应用→前后端组件层级，所有运行角色使用环境app_namespace（当前app-platform-dev），不派生独立应用命名空间。

| 用户要改什么 | 权威位置 |
|---|---|
| 应用部署开关 | 本目录config.yaml |
| 数据库/运行与迁移用户名、Redis前缀、RabbitMQ vhost、Job代次、API端口及角色资源 | [后端](knowledge-backend/README.md) |
| Web域名、端口、副本、OAuth公开客户端 | [Web前端](knowledge-web-frontend/README.md) |
| Admin域名、端口、副本、OAuth公开客户端 | [Admin前端](knowledge-admin-frontend/README.md) |
| 口令、TLS私钥和机器人身份 | 后端private_dir及非覆盖独立backup_dir，Git只保存SOPS |
| 源码/构建网络 | [构建与部署手册](../../../../infrastructure/applications/README.md) |

字段职责在组件就近说明；端口和用户名是普通配置，password/client_secret不填进config.yaml。当前值与镜像摘要以配置和锁文件为准，手册不另维护BOM。

## 日常维护

从k8s根执行，仅查看计划先用：

```sh
make -C infrastructure application-deployment-plan APP=knowledge
```

修改配置、重建源码、声明stage、发布/显式晋级以及一键部署已晋级应用使用[同一应用流程](../../../../infrastructure/applications/README.md)；共用模板归[common](../common/README.md)，不经过tpl转接。应用bootstrap不替你构建镜像或批准未提交的配置。

enabled=false只关闭本模块准入，不能停止Flux现有对象、删除身份或数据。停止/卸载及数据清理须审核晋级声明和真实依赖，不能批量删Job/PVC。

## 验收边界

基础登录、消息及实际Info→Knowledge→Investment中文检索链已验；完整爬取、PDF/其它格式、浏览器全集与恢复演练仍有缺项。 详情及尚待交付项见[验收记录](../../../../docs/platform-kind-v1/verification.md#应用与业务链路)。

## 应用字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `knowledge_deployment.enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
