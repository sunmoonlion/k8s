# RabbitMQ：身份、vhost与队列

messaging_namespace单实例、内部AMQP5672/管理15672。管理台浏览器入口见同目录[ui](ui/README.md)。应用各有独立用户、vhost和队列，字段在backend config；平台管理员/cookie在services_config_dir/credentials.yaml的rabbitmq_username/password/cookie，主备一致、root0600。

## 持久节点身份

rabbitmq_node_hostname沿用含platform-system的已初始化节点名，这是持久数据身份，与现在messaging_namespace客户端DNS不同。不能因目录/namespace调整机械更名。cookie每次核字节与0600权限，fsGroup曾改变权限的修正保留，不重写既有cookie。

RabbitMQ4.3队列约束要求非持久队列采用独占等支持语义；应用Celery控制/事件队列配置为exclusive。管理API探针用durable classic和队列TTL，不开启废弃功能绕过。

## 真实验收与恢复

services-check用管理API创建本次队列、发布/消费并精确删除；应用check另外通过真实AMQP跑API→Worker与Scheduler限定tick。两者均不是全业务任务完成；当前应用AMQP不是mTLS，以网络策略/vhost/身份隔离。

改vhost/user/queue或cookie须服务端、持久身份、客户端、主备同步；关闭开关不删除broker。卷、队列和用户属于数据/身份，恢复需一致备份和匹配版本，不能将队列残留当普通构建缓存清理。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_rabbitmq_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `rabbitmq_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `rabbitmq_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `rabbitmq_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `rabbitmq_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `rabbitmq_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `rabbitmq_node_hostname` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。
