# ELK：日志接收、索引与查询

ES/Logstash/Kibana取同一artifacts配套锁，data_namespace单实例静态Retain数据。config各volume/resources/heap/port/sysctl/index_prefix；prepare设置宿主max_map_count有副作用。单实例不是HA。

## 身份、协议与日志

私有elk.yaml/TLS在services_config_dir，独立副本services_backup_dir。elastic管理员、Logstash ES写身份、人工read身份、HTTP ingest身份分别隔离；Kibana data-view另独立身份，不借reader口令。内部ES/Logstash/Kibana TLS严格CA/SAN。

真实应用采集由[collector](collector/README.md)三节点DaemonSet提供，只收app namespace日志；视图由[data-view](kibana/data-view/README.md)声明Job初始化。浏览器入口、独立人工只读账号和真实登录检查在[UI组件](kibana/ui/README.md)，当前部署/验证状态见验收边界；内部管理API成功不能代替公开入口检查。

## 验收、背压与恢复

services-check写一个nonce事件，经Logstash入ES，用独立reader读回，检查writer读/管理/外部索引拒绝，最后精确删本次文档；查Kibana认证API。collector开启时核每个已启用应用角色真实CRI日志/元数据对应及固定data-view，只读检查不修复视图。

首次历史日志回填可能429；仅明确429拒收按有界指数退避/jitter重试（每请求180秒），不重放可能已写的超时，也不把401/403改成成功。collector缓存、Logstash队列、ES索引与Kibanametadata恢复职责不同；不要删缓冲“解决”容量。

公共UI协议已验收，宿主DNS/浏览器仍待完成。日志索引retention/轮转/备份/告警、整机/删群恢复仍待交付。磁盘容量、heap及资源变更先核峰值/调度、审阅发布，再真实读写链验收。

### 节点重启后的初始化

Elasticsearch初始化的TLS副本必须可重复生成：emptyDir会在节点重启后保留旧文件，普通cp无法覆盖0440副本。模板采用`cp --remove-destination`，每次只替换自己的三个临时副本，保留源Secret及0440。2026-10-05实际镜像内重复复制及摘要检查通过，修复已暂存但尚未发布到当前Flux源；现网临时恢复不能代替发布及再次重启验收。出现prepare-config失败时先查复制错误，不删除PVC或重置密码。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_elk_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `services_elasticsearch_enabled` | 文本/表达式 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `services_kibana_enabled` | 文本/表达式 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `services_logstash_enabled` | 文本/表达式 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `elasticsearch_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `elasticsearch_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `elasticsearch_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `elasticsearch_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `elasticsearch_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `kibana_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `kibana_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `kibana_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `kibana_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `kibana_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `logstash_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `logstash_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `logstash_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `logstash_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `logstash_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `elasticsearch_heap` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `elasticsearch_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `elasticsearch_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `elasticsearch_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `elasticsearch_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `kibana_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `kibana_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `kibana_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `kibana_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `logstash_heap` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `logstash_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `logstash_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `logstash_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `logstash_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `elasticsearch_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `kibana_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `logstash_ingest_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `elk_index_prefix` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `elk_init_generation` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `elk_logstash_writer` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `elk_log_reader` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `elk_ingest_username` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `elk_max_map_count` | 整数 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `elk_logstash_max_content_bytes` | 整数 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。
