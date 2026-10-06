# 模板应用RabbitMQ身份

普通字段rabbitmq_user/vhost/queue/identity_revision在[后端config](../config.yaml)，平台端口来自[RabbitMQ组件](../../../../messaging-platform/rabbitmq/README.md)。账号、vhost和持久队列改名是数据迁移，不是普通开关。

## 输入和隔离

private_dir/rabbitmq.yaml与backup_dir保存相同原口令，root0600且非覆盖；runtime.sops只给应用AMQP身份，平台管理口令只在messaging_namespace的一次性Job。已有声明后输入丢失须恢复，不能重设用户密码。

应用无management/administrator标签，仅自己的vhost内configure/read/write，API/Worker/Scheduler共享此应用边界。Job精确管理API访问，常驻应用仅AMQP。外来同名用户/vhost、额外权限、坏口令或拓扑漂移停止，不接管、不覆盖、不消费业务任务。

## 任务拓扑与验收

预建持久direct交换机、classic任务队列及同名路由，运行CELERY_TASK_TOPOLOGY_PREDECLARED=true；单节点持久不代表HA。Celery临时控制/事件队列采用exclusive兼容RabbitMQ4.3，详见[运行角色](../runtime/README.md)，不启用废弃特性。

application-stage→发布/显式晋级→bootstrap协调rabbitmq阶段，依赖Redis，不重启RabbitMQ。实际应用账号在独立临时排他队列发布/消费/确认，再仅删除该队列；核默认vhost及管理API拒绝，不读正式消息。

成功Job留为期望对象，不TTL；停用先暂停应用与相关阶段，Git回退不删账号/消息。内部HTTP/AMQP当前无mTLS，依赖NetworkPolicy。源模板见[共用初始化](../../../common/backend/rabbitmq/workload.yaml.j2)，完整操作见[应用维护](../../../../../../infrastructure/applications/README.md)。
