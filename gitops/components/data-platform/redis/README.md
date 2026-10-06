# Redis：应用ACL与持久化

data_namespace单实例、内部6379，静态Retain卷。平台default/探针身份与每应用runtime账号分离；平台口令在services_config_dir/credentials.yaml的redis_password，应用在各自private_dir/redis.yaml，并独立备份。

## 持久ACL是服务数据

init只在缺失时建立原default规则；主进程先umask077再exec，配置读取/data/users.acl，ACL SAVE后的文件须UID999/0600。仅initContainer chmod不能约束主进程后续原子保存；ACL文件和AOF都必须随卷恢复。

应用独立Job核口令摘要、限定键前缀/必要channel与命令权限，再ACL SAVE。已有同名账号不符就失败，不默默轮换或接管。FLUSHALL只可ACL DRYRUN检查拒绝，禁止为验收实际清库。

## 检查与变更

services-check写读带TTL随机键并删除；application-check另核真实应用认证/隔离、default、ACL文件权限和主进程0077。Job旧成功不代替当前进程认证。

已有Tpl账号随声明滚动Pod替换、相同ACL摘要/PVC/认证的实测见验收边界；这不是WSL或删群恢复。需要重启维护时先备ACL/AOF、核原Pod/PVC身份，仅按明确范围操作；当前无全平台统一重启target。

轮换须协调持久ACL、主备口令、Secret与所有客户端，不能只改redis.yaml。size非磁盘配额；不把Redis卷当可随意删除的缓存。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_redis_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `redis_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `redis_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `redis_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `redis_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `redis_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。
