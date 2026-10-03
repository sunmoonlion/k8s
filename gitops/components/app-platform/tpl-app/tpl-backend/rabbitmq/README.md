# 模板 RabbitMQ 身份

普通配置在上一级 `config.yaml`：`rabbitmq_user`、`rabbitmq_vhost`、`rabbitmq_queue`、`rabbitmq_identity_revision`。当前为 `tpl_runtime`、`tpl`、`tpl.default`；账号/虚拟主机/队列是数据身份，已有部署后修改应安排迁移。AMQP/管理端口沿平台内部接口5672/15672，不另设重复配置。

口令在既定私有目录的 `rabbitmq.yaml`，root0600，独立备份逐字节核对。已有声明后丢失输入不得重新随机生成；Git只保存SOPS密文。`runtime.sops.yaml`只把应用AMQP连接串送到app-platform-dev；平台管理口令仅由messaging-platform-dev的一次性Job挂载，不复制给应用。

沿用仓库根的 `make -C infrastructure application-stage APP=tpl`、提交/发布/晋级及 `application-bootstrap APP=tpl`。新Flux阶段tpl-rabbitmq依赖tpl-redis，使用既有固定后端镜像，不下载新应用镜像。不重启RabbitMQ或改变平台用户。

## 权限与幂等

- 应用无management/administrator标签，仅允许访问自己的tpl虚拟主机；允许配置/读/写该虚拟主机的资源，以支持Celery任务及动态控制/回复队列。此边界隔离不同应用，不隔离同一应用内的API/worker/scheduler；它们共享应用身份。
- 管理API只向本次初始化Job开放。常驻应用只有基础网络策略授予的AMQP5672访问。
- 初始化拒绝外来的同名虚拟主机、不同口令/管理标签/额外虚拟主机权限的同名用户；不会重设旧口令或接管外来数据。已有任务拓扑不同则停止，不删除或覆盖队列。
- 预建持久direct交换机和classic任务队列tpl.default及同名路由；符合本期单节点RabbitMQ。运行阶段设置CELERY_TASK_TOPOLOGY_PREDECLARED=true。单节点持久队列不等于高可用。
- 实际验收使用应用AMQP账号，验证持久任务拓扑存在，在独立临时排他队列完成消息发布/消费/确认，再删除该临时队列；不消费业务任务。另实际验证默认虚拟主机拒绝和管理API拒绝。
- 成功Job保留为Flux期望对象；不直接删除或加TTL。失败按具体归属清理；任务重跑用显式修订。Git回退不自动删除账号、虚拟主机或消息；停用先停应用并暂停该阶段，删除数据另行确认。

上游依据：[RabbitMQ访问控制](https://www.rabbitmq.com/docs/access-control)、[HTTP API](https://www.rabbitmq.com/docs/http-api-reference)、[密码摘要格式](https://www.rabbitmq.com/docs/passwords)。目前采用平台既有内部HTTP/AMQP及NetworkPolicy；尚未宣称实现集群内mTLS。
