# Neo4j Community图实例

data_namespace单实例、UID7474、worker2静态Retain卷，认证与图数据在/data。内部HTTPS与强制TLS Bolt端口取config，HTTP禁用；非root/只读根/无联网插件，当前不开放公共入口或四App业务访问。

## 身份和权限边界

neo4j.yaml在services_config_dir及独立backup，官方NEO4J_AUTH_FILE读取；TLS主备与CA核一致。Community当前管理员用于限定基础验收，不作为4应用共享多租户权限方案；业务接入需明确图拥有者/受限服务，细粒度RBAC或多租户另定Enterprise/实例隔离。

## 失败rollout的受控恢复

enableServiceLinks=false避免Kubernetes注入NEO4J_PORT_*被官方入口当数据库配置。启动/readiness按Bolt监听，成功交付仍须真实TLS/查询。

原生flux-source-apply包含recover-rollout.yaml：先从晋级Git对象核正确模板，有限等待Flux写入锁镜像/环境/探针（上限15分钟）；首次无控制器跳过。只在旧revision未Ready且失败重启时，核控制器UID/节点/Retain卷，以UID/resourceVersion前置条件正常删除该失败Pod，让同控制器重建；不删健康/当前Pod、不强杀、不删卷。

neo4j_failed_rollout_recovery可关闭，API前置冲突报错后重核，不能强行覆盖。数据目录权限只处理明确需要的输入，不递归chown全图数据。

## 验收范围

services-check严格CA/SAN、认证拒绝、实际节点关系提交/读回、事务回滚（选定Query API DELETE实际200且随后计数0）、Bolt TLS版本协商；版本只筛Neo4j Kernel，不能拿Cypher行误比。只清本次nonce图节点，不证明完整Bolt驱动会话、业务图/插件、HA或灾备。回退须保留匹配身份和卷，参考共同Flux方法。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_neo4j_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `neo4j_failed_rollout_recovery` | 开关 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `neo4j_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `neo4j_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `neo4j_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `neo4j_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `neo4j_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `neo4j_heap` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `neo4j_pagecache` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `neo4j_https_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `neo4j_bolt_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `neo4j_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `neo4j_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `neo4j_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `neo4j_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。
