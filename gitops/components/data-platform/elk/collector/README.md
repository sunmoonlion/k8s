# 应用日志采集

与 ELK 同一原生 Make→Ansible→Flux/SOPS 链。用户参数在 config.yaml，版本和摘要唯一在 infrastructure/artifacts/upstream-images.lock.json；官方 Fluent Bit 5.1.3，不做派生镜像。独立 elk-collector 阶段依赖 elk-runtime，不重建初始化 Job。

每节点一个非 root DaemonSet，只读节点 /var/log（包含 containers 符号链接及 pods 实际文件），路径仅匹配 app-platform-dev 的 tpl/info/knowledge/investment/casdoor。收集所有后端角色及前端 stdout/stderr，保留 CRI 时间、流、Pod/容器名、集群及节点，不查询 Kubernetes API、不挂服务账号令牌或 Docker socket。

hostPath 连 baseline 都不允许，因此专用 sunmoon-log-collector 命名空间允许该卷类型；业务命名空间仍 restricted。节点原生日志为root:root/0640，目录0750；容器非特权、UID1000/GID0（只利用组读权限，不修改节点日志权限）、无 capability、只读根、禁止提权，仅 DNS 与 Logstash 出站。宿主卷可见范围大于采集匹配范围，部署权限仅供管理员，不允许业务用户在此命名空间建 Pod；没有声称 glob 是隔离权限。

只持 Logstash 接收密码和公开 CA；不持 Elasticsearch 写/读/管理员密码、TLS 私钥或业务秘密。TLS 校验链及主机名；Logstash 入站仅此命名空间/Pod。应用仍负责避免将凭据/BYOK 写日志；本组件不声称任意明文日志均已脱敏。

每节点独立数据盘 static/log-collector 保存读取位点和未送达队列（inode和文件名同时比对，避免建群后inode复用误跳过）；full sync/checksum、无限重试、上行 chunk 达限制暂停读入，不设置删除最旧消息的队列策略。缓冲上限是近似背压阈值，不是磁盘硬配额；长期告警/轮换按空间管理单元处理。至少一次传送可能重复，节点日志已轮转丢失或损坏时不能保证零丢失。

make -C infrastructure services-materials SERVICE_IMAGES=fluent-bit、services-publish SERVICE_IMAGES=fluent-bit 准备发布；services-stage→提交→flux-release→晋级固定 source→services-bootstrap。日常 services-check 核对三节点采集、每个已启用应用角色的真实日志以及 Kibana data view；先装平台时未部署的应用明确列为未验证，已有启用Deployment缺失或不就绪则失败。关闭开关只停止生成阶段，prune:false 不自动删除现有采集器，正式停用须明确回退/停用操作。

参考：[官方发布](https://github.com/fluent/fluent-bit/releases/tag/v5.1.3)、[无 API 元数据](https://docs.fluentbit.io/manual/data-pipeline/filters/kubernetes)、[HTTP TLS 输出](https://docs.fluentbit.io/manual/data-pipeline/outputs/http)、[队列背压](https://docs.fluentbit.io/manual/administration/buffering-and-storage)。公共 Kibana 入口及机器/集群重建验收另行交付。

首次回填历史日志可能返回429。验收仅对此明确拒收响应按官方建议有界指数退避/jitter重试（每请求最多180秒）；不重试可能已经写入的超时请求，不把401/403/其他失败改成成功。
