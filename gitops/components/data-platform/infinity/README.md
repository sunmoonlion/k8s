# Infinity：RAGFlow专用索引

RAGFlow派生索引，非业务唯一原文，单节点worker静态Retain卷/UID1000，资源、buffer/memindex配额由config。size不是硬配额。infinity_conf.toml.j2跟随锁定上游配置。

## 协议与访问

RAGFlow专用23817；管理23820不公开Service。该版客户端无身份/TLS，Calico限制仅RAGFlow访问，是明确本地边界而非可供任意应用共享的安全接口；不具备HA。

services-check核固定镜像/卷及真实HTTP节点身份，RAGFlow实际上传/解析/中文检索另检查其链路。索引可重建不等于当前已有自动重建入口或可随意删除；变更索引版本/格式须备份/重建方案和检索验收。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_infinity_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `infinity_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `infinity_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `infinity_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `infinity_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `infinity_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `infinity_buffer_size` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `infinity_memindex_quota` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `infinity_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `infinity_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `infinity_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `infinity_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。
