# 信息应用

普通配置在本目录与三个组件的config.yaml；镜像由各组件image.lock.yaml固定。命名空间唯一来自环境app_namespace（app-platform-dev），不派生info-app-dev。每应用独立数据库、迁移角色、Redis键前缀、RabbitMQ vhost和Web/Admin身份，秘密在私有输入和SOPS。

后端API/Worker/Scheduler复用同一固定镜像。共用声明模板在../common，原生make application-stage/bootstrap/check APP=info直接调用同一Ansible流程，不通过tpl应用或新增CLI。具体命令见infrastructure/applications/README.md。

本单元先验收运行、真实身份/消息和schema；原文对象存储、搜索与knowledge分发是后续业务依赖。STORAGE_BACKEND明确为s3，未配置对象存储时业务应明确失败，禁止回退容器本地目录。SEARCH_BACKEND目前disabled，不宣称索引/分发业务已通过。公开域名切换另需入口维护。
