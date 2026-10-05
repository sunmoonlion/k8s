# 信息应用后端

API、Worker、Scheduler共用本目录image.lock.yaml固定的后端镜像；配置、生成声明及SOPS就近维护，模板由common直接渲染。


## 用户名、口令与端口

| 输入 | 位置/责任 |
|---|---|
| database、runtime/migrator user、Redis user/key_pattern、RabbitMQ user/vhost/queue | config.yaml；独立应用身份，既有数据后改名属于迁移 |
| API port、副本、worker_concurrency及resources | config.yaml；与Service/探针/网络策略一起渲染 |
| PostgreSQL/Redis/RabbitMQ内部端口 | 平台组件config；不再复制到应用配置 |
| 数据库两个独立口令 | private_dir/credentials.yaml |
| Redis、RabbitMQ口令 | private_dir/redis.yaml、rabbitmq.yaml |
| Web/Admin两个独立client secret | private_dir/identity.yaml；公开origin/client_id取各自前端配置 |
| TLS证书私钥 | private_dir/tls；复用平台CA，SOPS发布 |

private_dir与backup_dir由本config固定；首次生成root0600输入，再在独立数据盘非覆盖逐字节备份。已有声明后主备丢失须恢复，不随机重建。备份不一致、外来同名数据库/角色、已有身份漂移均停止；编辑密码文件不是已完成轮换。秘密生命周期见[SOPS与私有输入](../../../../../infrastructure/flux/secrets.md)。

## 部署阶段与权限

database/创建独立库和账号，migration/用迁移身份执行固定镜像的迁移并检查expected_schema_revision。运行身份仅连接、schema使用、表CRUD/sequence，禁止DDL和写alembic元数据；初始化不接管外来同名库/角色。数据库扩展取database_extensions（若声明），迁移前核源码head，不能随意改预期版本以放过失败。

redis/创建独立持久ACL，拒绝default和跨键前缀/管理；rabbitmq/创建独立vhost及持久任务拓扑，无平台管理权限；identity/注册Web/Admin精确回调。平台管理员只给所属命名空间一次性初始化Job，不复制到常驻业务Secret。

runtime/启动三个角色；API与Worker滚动，单副本Scheduler Recreate。API检查Redis/schema，Worker检查队列/任务注册，Scheduler检查进程与最近tick；外部依赖异常不作为Worker/Scheduler liveness重启理由。业务运行不自动迁移。异步session提交后行为与消息探针见[共用机制](../../common/README.md)。

Job输入/镜像改变须审核并更新对应revision，经发布晋级生成新Job；旧成功Job仍为期望对象时不可删除或TTL。Git回退不回退schema、账号、消息或外部身份。

## 应用特定依赖

object_storage开启Info原文桶与版本化；端点取平台组件配置，口令为s3.yaml。domain_runtime_env选择s3且当前搜索disabled，依赖不可用时拒绝原文写入，不回退容器本地目录。knowledge_service为独立knowledge:ingest关系；机制见[对象存储](../../common/backend/storage/README.md)及[服务身份](../../common/backend/service-identity/README.md)。

## 操作与恢复

```sh
make -C infrastructure application-deployment-plan APP=info
make -C infrastructure application-check APP=info
```

plan只读；check会创建限定随机数据库/消息/业务探针并精确清理，失败保留现场，不是纯查看。配置候选、构建、固定发布及bootstrap统一见[应用维护流程](../../../../../infrastructure/applications/README.md)。口令备份不是数据库备份；既有数据更新先准备数据库与外部依赖恢复路径，不能拿Git回退代替。

基础运行、登录/消息、实际原文两版本读回及跨应用认证投递已验；完整爬取、发布、搜索和分发业务未全验。 记录见[验收边界](../../../../../docs/platform-kind-v1/verification.md#应用与业务链路)。

## 后端字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `info_backend_deployment.database` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.database_runtime_user` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.database_migrator_user` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.database_extensions` | 列表 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.database_bootstrap_revision` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `info_backend_deployment.migration_job_revision` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `info_backend_deployment.expected_schema_revision` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `info_backend_deployment.private_dir` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `info_backend_deployment.backup_dir` | 文本/表达式 | 目录责任；已有输入/数据需完整恢复和路径守卫，不能换空目录重建身份。 |
| `info_backend_deployment.deploy_budget_bytes` | 整数 | 操作预算/限时；调整须匹配真实峰值及当前容量检查。 |
| `info_backend_deployment.redis_user` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.redis_key_pattern` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `info_backend_deployment.redis_identity_revision` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `info_backend_deployment.rabbitmq_user` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.rabbitmq_vhost` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `info_backend_deployment.rabbitmq_queue` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `info_backend_deployment.rabbitmq_identity_revision` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `info_backend_deployment.identity_organization` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.identity_revision` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `info_backend_deployment.api_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `info_backend_deployment.api_replicas` | 整数 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.worker_replicas` | 整数 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.worker_concurrency` | 整数 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.scheduler_replicas` | 整数 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.api.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.api.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.api.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.api.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.worker.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.worker.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.worker.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.worker.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.scheduler.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.scheduler.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.scheduler.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.resources.scheduler.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `info_backend_deployment.celery_control_queue_exclusive` | 开关 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `info_backend_deployment.celery_event_queue_exclusive` | 开关 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `info_backend_deployment.object_storage.enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `info_backend_deployment.object_storage.user` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.object_storage.bucket` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.object_storage.job_revision` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `info_backend_deployment.domain_runtime_env.STORAGE_BACKEND` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `info_backend_deployment.domain_runtime_env.SEARCH_BACKEND` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `info_backend_deployment.knowledge_service.enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `info_backend_deployment.knowledge_service.application` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.knowledge_service.client_id` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.knowledge_service.organization` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.knowledge_service.scope` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `info_backend_deployment.knowledge_service.job_revision` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `info_backend_deployment.knowledge_service.token_seconds` | 整数 | 身份相关参数；秘密值留私有输入，不作为文件编辑即完成轮换的承诺。 |
