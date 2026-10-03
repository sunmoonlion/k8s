# 模板运行角色

用户参数在上一级 config.yaml；三个角色共用 image.lock.yaml 中同一后端镜像。
API、worker 使用滚动更新，scheduler 单副本 Recreate；迁移仍由独立 Job 完成。
API 探针检查 Redis 与数据库 schema，worker 实际查询自己的队列/注册任务，
scheduler 检查本地进程与最近完成的调度 tick。后二者不把外部依赖故障作为 liveness 重启依据。

应用运行账号分别来自 database、redis、rabbitmq、identity 的 SOPS 声明；只有 API
读取 Redis/browser Secret，前端不持有它们。ConfigMap/私有输入变化参与 Pod 配置摘要以触发滚动。
Celery durable 状态在 PostgreSQL；不启用未配置键隔离的 Redis result backend。
Beat 的本地调度缓存可重建，放在 emptyDir，不作为任务真源。

模板两个域名使用独立 tpl-tls，复用平台 CA，1825 天有效期。私有 TLS 输入和非覆盖备份
归 backend config 的 private_dir/backup_dir 下 tls；Git 仅密文。已发布的身份丢失时
必须恢复备份，不自动重签。域名或证书轮换需要单独安排，不静默替换。
API 对 Casdoor 使用受 NetworkPolicy 限制的内部 HTTP backchannel，公开 issuer 仍为 HTTPS；
内部 HTTP/AMQP 暂无 mTLS，不宣称端到端链路加密。

## 部署和核验

沿用 application-stage → 提交 → flux-release → 晋级源 → application-bootstrap。
application-check 校验全部 Flux 阶段的当前代次和源摘要、五个 Deployment 的镜像/副本、
实际 worker/scheduler 探针和经新 Traefik 的 HTTPS 路由。公开域名仍可能指向原入口，
核验通过 `--connect-to` 指向 cluster_ingress_port，保留 SNI、Host 和 CA 验证。
完整登录、消息业务处理及公开入口切换必须分别验收，不能由 Ready 推定。

## RabbitMQ 4.3 compatibility

Celery 5.6.3 的默认控制/事件队列是非持久非独占，RabbitMQ 4.3默认拒绝创建。
部署通过原生 CELERY_CONFIG_MODULE 加载 ConfigMap 内的 celeryconfig.py，
把这两种临时队列设为 exclusive，连接退出后自动消失；持久业务队列不变。
Worker、scheduler、API和探针读取同一份配置，不开启 RabbitMQ 的废弃特性。
依据：[Celery配置](https://docs.celeryq.dev/en/stable/userguide/configuration.html#control-queue-exclusive)、
[RabbitMQ队列说明](https://www.rabbitmq.com/docs/queues#temporary-queues)。

共用模板与初始化/验收脚本的唯一来源已归 gitops/components/app-platform/common；本组件配置、镜像锁与生成声明仍在本目录。入口仍为原生Make/Ansible/Flux；不再通过tpl专属模板部署实例。
