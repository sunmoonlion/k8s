# Kibana应用日志视图

elk-data-view依赖elk-runtime，config维护固定id和generation。专用elk-data-view.yaml主备保存服务口令，不复用人工reader；权限限default空间indexPatterns及索引metadata，无日志读写或ES管理。

## 初始化与代次

短initContainer限定使用ES管理员创建/核专属角色/用户，未知对象拒绝接管，不重置密码；主Job只持服务身份/CA，通过可信TLS调用data_views API。只在不存在时创建固定title/@timestamp，已有则严格核对；allowNoIndex支持先平台后应用。仅DNS/Kibana/ES网络，无TLS私钥。

重复部署成功Job不重跑。更改id/口令/不可变Job输入、或删除视图后恢复，需要显式新generation审阅发布；不能把view check作为修复器。services-check只读核视图存在/正确。

已实测采用现有视图并验证权限拒绝；首次空视图创建与整机重建分支仍未验收。公共Kibana入口另交付；此Job不删日志/索引，也不负责保留策略。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `elk_log_data_view_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `elk_log_data_view_id` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `elk_log_data_view_generation` | 文本/表达式 | 固定身份或初始化代次；变更前审核来源/迁移，不用递增代次掩盖失败。 |
| `elk_log_data_view_user` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../../../docs/platform-kind-v1/verification.md)。
