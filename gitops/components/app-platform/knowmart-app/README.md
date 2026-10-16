# knowmart-app

knowmart：分身（knowbot）的存放与「请」，现在只做私有模式（只能请自己的分身，后端强制按所有者过滤，界面叫「我的分身」）。现在是空应用：模板的骨架、认证与运行角色，没有业务功能。设计见 [0018](../../../../docs/dev-investment-agent/tree-build/SDD/modules/0018-advisor-market.md) 与 [0026](../../../../docs/dev-investment-agent/tree-build/SDD/modules/0026-knowlab.md)「一之二」。

## 配置导航

本目录保留平台→应用→前后端组件层级，所有运行角色使用环境app_namespace（当前app-platform-dev），不派生独立应用命名空间。

| 用户要改什么 | 权威位置 |
|---|---|
| 应用部署开关 | 本目录config.yaml |
| 数据库/运行与迁移用户名、Redis前缀、RabbitMQ vhost、Job代次、API端口及角色资源 | [后端](knowmart-backend/README.md) |
| Web域名、端口、副本、OAuth公开客户端 | [Web前端](knowmart-web-frontend/README.md) |
| Admin域名、端口、副本、OAuth公开客户端 | [Admin前端](knowmart-admin-frontend/README.md) |
| 口令、TLS私钥和机器人身份 | 后端private_dir及非覆盖独立backup_dir，Git只保存SOPS |
| 源码/构建网络 | [构建与部署手册](../../../../infrastructure/applications/README.md) |

字段职责在组件就近说明；端口和用户名是普通配置，password/client_secret不填进config.yaml。当前值与镜像摘要以配置和锁文件为准，手册不另维护BOM。

## 日常维护

从k8s根执行，仅查看计划先用：

```sh
make -C infrastructure application-deployment-plan APP=knowmart
```

修改配置、重建源码、声明stage、发布/显式晋级以及一键部署已晋级应用使用[同一应用流程](../../../../infrastructure/applications/README.md)；共用模板归[common](../common/README.md)，不经过knowmart转接。应用bootstrap不替你构建镜像或批准未提交的配置。

enabled=false只关闭本模块准入，不能停止Flux现有对象、删除身份或数据。停止/卸载及数据清理须审核晋级声明和真实依赖，不能批量删Job/PVC。

## 验收边界

**尚未部署**：2026-10-16 由 tpl-app 实例化的空应用，第一次发布与浏览器核对在 qwen-003 D 段；做完前这里不写任何「已验」。

## 应用字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `knowmart_deployment.enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
