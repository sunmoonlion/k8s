# Valkey：RAGFlow专用队列

与业务Redis独立，存RAGFlow任务/缓存，身份在services_config_dir/valkey.yaml和独立备份。runtime/probe用户取config；default禁用，ragflow_queue可用业务键/流/Lua而禁ACL/CONFIG/FLUSH，probe限sunmoon:acceptance:*。

## 存储与权限

ACL存SHA而非明文，文件只读；AOF everysec、noeviction、worker静态Retain卷/UID999/只读根。当前官方客户端用明文协议，由Calico只允许RAGFlow；无HA或全链路TLS保证。

services-check真实KV读写、错误密码/管理/范围外拒绝，精确清探针。持久任务队列不能按“缓存可重算”随意删除。完整备份恢复/WSL与删群重建尚未验，输入双丢失拒绝重生成，轮换联动客户端/主备。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_valkey_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `valkey_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `valkey_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `valkey_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `valkey_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `valkey_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `valkey_runtime_username` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `valkey_probe_username` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `valkey_maxmemory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `valkey_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `valkey_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `valkey_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `valkey_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。
