# 模板应用运行角色

API/Worker/Scheduler使用上级image.lock同一固定后端镜像，配置在[后端config](../config.yaml)。模板唯一来源为[common runtime](../../../common/backend/runtime/workload.yaml.j2)，生成workload与SOPS留本目录。

## 进程与持久状态

API与Worker滚动，Scheduler单副本Recreate。API readiness核Redis及schema；Worker实际查自己的队列/任务注册，Scheduler核进程及最近成功tick，不把外部依赖故障作为后两者liveness重启原因。迁移仅独立Job，运行镜像不启动自动迁移。

配置/输入摘要触发Pod滚动。API读取Redis/browser秘密；其它角色只拿所需业务身份，前端不持它们。Celery durable状态在PostgreSQL，不启用无键隔离的Redis result backend；Beat本地调度缓存放emptyDir可重建，不能当任务真源。

## RabbitMQ4.3兼容

所选Celery默认控制/事件队列为非持久非独占，RabbitMQ4.3默认拒绝。CELERY_CONFIG_MODULE读取ConfigMap celeryconfig.py，将这两种临时队列设exclusive，连接退出消失；业务持久队列保持。API/Worker/Scheduler及探针都取同份配置，不开启RabbitMQ废弃特性。

## TLS与验收

Web/Admin证书复用平台CA，TLS输入private_dir/tls和独立backup，Git仅SOPS；已发布身份丢失先恢复，域名/证书轮换显式安排。普通Casdoorbackchannel为内部HTTP，公开issuerHTTPS；内部HTTP/AMQP不宣称mTLS。

application-check核Flux源与当前代次、五个Deployment摘要/副本、真实worker/scheduler及保留SNI/Host/CA的新TraefikHTTPS路由；public检查才证明宿主30443指向正确目标。模板已实际验登录/消息，但未配置业务provider仍503/provider_unavailable。

操作与恢复见[应用维护](../../../../../../infrastructure/applications/README.md)，历史范围见[验收边界](../../../../../../docs/platform-kind-v1/verification.md#应用与业务链路)。Git回退不能代替数据库回退或恢复已失身份。
