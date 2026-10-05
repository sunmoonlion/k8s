# MongoDB文档库

data_namespace单实例、内部requireTLS27017、worker2静态Retain卷/UID999、只读根/dropALL/禁SA token。单成员replica set支持事务但不具HA；应用尚未使用root或验收账号。

## 初始化与身份

mongodb.yaml主备保存独立root、内部keyFile和受限验收账号；mongodb-tls主备，Git只存SOPS。官方entrypoint仅空数据目录临时loopback创建root，最终认证/TLS/keyFile；初始化Job创建声明单成员副本集并等待PRIMARY，验证已有config一致，禁止自动reconfig。

headless Service publishNotReadyAddresses支撑初始化DNS，Ready认证TLS ping，init/verify另确认PRIMARY。未初始化状态只对mongosh code94处理，其他异常停止；不把任何出错当新环境。未来业务各自logical DB/权限，不借sunmoon_acceptance用户。

## 真实检查与数据恢复

services-check以限定库随机collection做CRUD、multi-document commit/abort、匿名/错误密码/管理/跨库拒绝，并精确清本次集合。persistence.js是operator nonce限定的create/verify/remove，需真实Pod替换核相同卷后读回；不是自动每次重启数据库。

已有Pod替换持久验收不证明整机/删群/业务驱动/备份恢复。改replica_set/member/用户名、keyFile和init代次先审已有远端状态与主备；不能仅换config重置。容器logs进入标准输出，长期轮换/灾备待共同空间管理。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_mongodb_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `mongodb_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `mongodb_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `mongodb_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `mongodb_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `mongodb_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `mongodb_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `mongodb_replica_set` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `mongodb_acceptance_database` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `mongodb_init_generation` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `mongodb_wiredtiger_cache_gib` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `mongodb_oplog_mib` | 整数 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `mongodb_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `mongodb_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `mongodb_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `mongodb_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。
