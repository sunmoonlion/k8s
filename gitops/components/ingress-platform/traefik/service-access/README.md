# 内部关系HTTPS

为Casdoor关系token和Knowledge内部摄入/检索提供cluster-local HTTPS transport，主机名由config的service_access_hosts引用app_namespace。运行调用者通过专用网络标签与CA验证，不能复用浏览器/管理员令牌。

## 身份与责任

TLS私钥由prepare生成/备份后SOPS发布，仅Traefik消费；客户端只挂公共CA。域名、SAN、service/route与网络策略必须一起更新，不能把service_access_enabled=false当关闭现有route。

浏览器公网HTTPS、现有应用Casdoor HTTP backchannel和这里的关系服务HTTPS是不同调用路径，手册不把所有历史backchannel宣称mTLS。关系调用实际身份验收见common/backend/service-identity及Knowledge provider说明。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `service_access_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `service_access_hosts.casdoor` | 文本/表达式 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `service_access_hosts.knowledge` | 文本/表达式 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../../docs/platform-kind-v1/verification.md)。
