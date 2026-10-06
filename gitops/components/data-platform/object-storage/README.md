# AIStor：对象原文与版本

data_namespace单实例，S3端口与console端口分别由config声明；内部S3须TLS。控制台浏览器入口见同目录[ui](ui/README.md)，S3 API不经公共入口。

## 许可、root与应用身份

许可证来源object_storage_license_file；prepare检查并非覆盖地复制到services_config_dir与services_backup_dir的minio.license。许可秘密不贴日志，格式正确不能证明S3可写，必须经过实际S3操作。

root口令在object-storage.yaml、TLS在object-storage-tls，均由私有根及独立副本保护；Git只存SOPS。应用各自bucket/user，Info原文版本为业务权威，Knowledge只读限定前缀；RAGFlow只写派生桶，不借root权限。

## 真实检查与版本清理

services-check创建本次随机bucket、启用版本、写读字节/VersionId/摘要，最后仅删除本次bucket全部版本再删桶。mc返回0仍须逐行确认JSON status不是error。应用S3检查另用实际API身份写两个版本并读回，对跨bucket/版本管理拒绝，再由有权探针清除精确VersionId。

业务版本保留、备份、整机/删群持久化仍另验；禁止套probe的版本清理到正式桶。root/应用口令及许可轮换须同步实际服务与主备，不能只换config或提高Job代次。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_object_storage_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `object_storage_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `object_storage_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `object_storage_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `object_storage_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `object_storage_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `object_storage_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `object_storage_console_port` | 整数 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `object_storage_region` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `object_storage_license_file` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `object_storage_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `object_storage_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `object_storage_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `object_storage_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。
