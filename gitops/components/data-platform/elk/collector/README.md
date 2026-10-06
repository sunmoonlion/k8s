# 三节点应用日志采集

独立elk-collector阶段依赖elk-runtime，每节点DaemonSet从只读/var/log匹配四应用各角色与Casdoor stdout/stderr，保留CRI时间/stream/Pod/container/node/cluster。无Kubernetes API查询、SA token或Docker socket。

## 有限宿主访问与凭据

hostPath需专用sunmoon-log-collector命名空间例外；业务namespace仍restricted。日志root0640/目录0750，容器UID1000/GID0只利用组读、非特权/drop ALL/根只读/禁止提权，仅DNS与Logstash出站；不改宿主日志权限。glob范围不等于隔离权限，业务用户不可在本namespace建Pod。

仅持Logstash接收口令与公开CA，不持ES写/读/admin、私钥或业务秘密。应用仍须避免日志含凭据/BYOK，采集器不保证任意日志均脱敏。

## 偏移、待发送块与背压

每节点独立static/log-collector保存offset和未发队列，inode/文件名同核、full sync/checksum，重试不删除最旧消息；chunk达上限暂停读入，配置上限是近似阈值而非硬配额。至少一次可能重复，原日志已轮转/损坏不能保证零丢失。

services-check核三节点Ready、安全挂载/实际imageID、每个启用Deployment的对应真实日志及Kibana视图；尚未部署角色明确报告不覆盖，已启用缺Pod/不Ready失败。禁止删除state制造干净列表，保留策略与告警另行批准实现。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `elk_collector_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `elk_collector_namespace` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `elk_collector_applications` | 列表 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `elk_collector_state_directory` | 文本/表达式 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `elk_collector_memory_chunks` | 整数 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `elk_collector_resources.requests.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `elk_collector_resources.requests.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `elk_collector_resources.limits.cpu` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `elk_collector_resources.limits.memory` | 文本/表达式 | 运行资源/性能；发布晋级后生效，检查调度、峰值和吞吐。 |
| `elk_collector_read_from_head` | 开关 | 以本目录实现和下文限制为准；通过候选审阅、发布、晋级生效。 |
| `elk_collector_initial_budget_bytes` | 整数 | 操作预算/限时；调整须匹配真实峰值及当前容量检查。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../../docs/platform-kind-v1/verification.md)。
