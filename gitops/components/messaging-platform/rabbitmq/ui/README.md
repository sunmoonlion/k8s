# RabbitMQ 管理台浏览器入口

用户参数在[config.yaml](config.yaml)。独立hostname、平台CA证书、IngressRoute与NetworkPolicy，登录使用新体系broker管理员私有输入（`operator_account_rabbitmq`，用户名 `platform`，密码表第11项）。不另建账号。管理插件已在官方`rabbitmq:*-management`镜像中。

公开入口走宿主30443 SNI，域名由本配置的origin唯一指定；[入口](../../../../../infrastructure/entry/README.md)引用同一hostname。关闭`rabbitmq_ui_enabled`停止新增声明，不自动删除已部署路由或证书。

AMQP不经此入口；应用继续走集群内5672。
