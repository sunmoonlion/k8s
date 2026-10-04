# ELK：单节点 KIND 部署

用户参数在本目录 config.yaml，版本/摘要唯一来自 infrastructure/artifacts/upstream-images.lock.json。
Elasticsearch、Kibana、Logstash 使用各自目录里的模板和渲染声明；initialize 只负责受控身份初始化，runtime 汇总后两者。

统一链：make -C infrastructure services-materials/services-publish SERVICE_IMAGES=elasticsearch,kibana,logstash → services-stage → 本地提交 → flux-release → services-bootstrap。
services-bootstrap 部署已经晋级的固定声明；首次准备或修改参数仍须 stage、提交和晋级。各步骤都复用原生 Make/Ansible/Flux。

三个服务均在 data-platform-dev，独立静态 Retain 卷：20Gi ES、2Gi Kibana、4Gi Logstash。这是单节点开发配置，不提供高可用或跨磁盘灾备。
内部端口 ES 9200、Kibana 5601、Logstash TLS HTTP 8080；只提供 ClusterIP，本单元没有公开域名入口或自动日志采集器。

私有账号和 Kibana 三个加密密钥：/etc/sunmoon/services/sunmoon-kind/elk.yaml；独立非覆盖备份 /mnt/sunmoon-data/backups/services/sunmoon-kind/elk.yaml。
初始化管理员仅挂在 ES 和一次性 Job；Kibana 只持 kibana_system，Logstash 只持 sunmoon_log_writer。写账号仅允许 sunmoon-logs-* 索引；独立 reader 身份可读日志和访问 Kibana。
TLS 每服务独立，平台 CA 签发；公钥链和主机名校验开启，Secret 仅以 SOPS 密文入 Git。修改密码/初始化逻辑需设计显式旋转与增加 elk_init_generation，不可改旧不可变 Job 伪装成功。

ES 所需 vm.max_map_count 在宿主唯一文件 /etc/sysctl.d/90-sunmoon-elasticsearch.conf 持久声明，渲染时仅补足该参数；无特权 Pod。
Logstash 持久队列上限512MiB，每条确认写检查点；容器日志仅标准输出。索引自动删除/ILM尚未启用，须纳入所有者确认的长期删除策略。

验收将覆盖 TLS、认证拒绝、实际 Logstash → ES 写入与检索、越权拒绝、Kibana 状态及重复部署。重启/灾备和所有应用日志接入属于后续单元，不以 Pod Ready 代替这些结论。
回退：晋级前先保存当前 flux-source.yaml；失败恢复原源并原生 flux-source-apply。新阶段 prune=false/deletionPolicy=Orphan，回退不会自动删数据；停新服务需声明副本0并晋级，保留新卷。

规则对照：C-D1 日志只是观测副本；C-D3/C-I3 账号与卷独立；C-R1/C-R2 三镜像和声明按固定摘要发布；已有应用和核心对象必须保持不变。

## 全应用日志采集

节点采集器配置、实现及实际日志对照在 [collector](collector/README.md)，同一 services-stage/bootstrap/check 链。Kibana 保存固定 SunMoon application logs 数据视图（sunmoon-logs-*、@timestamp）；用户可以按 kubernetes.pod_name、container_name、node、stream 过滤。公共 Kibana 域名入口另行切换，不能把内网 API/data view 验收写成浏览器入口已交付。
