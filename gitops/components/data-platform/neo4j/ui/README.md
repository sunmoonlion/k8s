# Neo4j Browser 浏览器入口

用户参数在[config.yaml](config.yaml)。独立hostname、平台CA证书、IngressRoute（Traefik校验上游HTTPS）与NetworkPolicy，登录使用新体系图管理员私有输入（`operator_account_neo4j`，密码表第10项）。

本入口只暴露 Browser 的 HTTPS 页（7473）。Bolt 仍是集群内地址；浏览器里执行查询还需本机`kubectl port-forward`或后续独立TCP入口，不能把数据库协议接到公共30443。关闭开关不删除已有路由或图数据。
