# PostgreSQL：数据库与受限角色

运行data_namespace，固定内部5432，单实例静态Retain卷。volume字段调整声明节点/size/UID；PG资源与端口目前在workload.yaml.j2，未开放全部用户字段，修改模板须审核调用者/网络策略和峰值。

## 账号与数据

管理用户名固定postgres；口令为services_config_dir/credentials.yaml的service_credentials.postgresql_password，root0600，独立副本services_backup_dir。用户数据库与runtime/migrator账号在各应用backend config；Casdoor/RAGFlow也用独立库/身份，运行账号不借管理员。

应用database Job负责空库/角色初始化，migration Job持迁移身份；API/Worker/Scheduler只有runtime权限。已有库名/角色名更改是迁移，不能重新初始化或仅改口令文件。TLS、账号权限与网络允许范围以当前模板为准，不声称全面数据库传输mTLS。

## 检查与恢复条件

services-check真实PG事务写读和回滚，并用有/无客户端标签的随机Pod检查DNS/连接允许与拒绝；应用检查另核runtime DDL拒绝、schema head。探针按精确身份清理，不删业务表。

备份须覆盖数据库内容及角色/权限、依赖身份和匹配版本；私有口令副本不是数据备份。现有业务全量备份/恢复/轮换统一入口未完成，卷路径/节点/namespace不能直接热改。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_postgresql_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `postgresql_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `postgresql_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `postgresql_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `postgresql_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `postgresql_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。
