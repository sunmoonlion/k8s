# Traefik：集群TLS入口

ingress_namespace运行，固定chart与image取artifacts锁，chart由原生services-chart发布并puller完整拉回核字节。values配置在workload.yaml.j2：该chart使用log/accessLog、根层versionOverride；不沿用旧chart键名。

## 端口与证书

节点NodePort30443→KIND宿主loopback29443→HAProxy公共30443。HAProxy不终止TLS，Traefik消费Ingress对应的受保护证书。单改宿主route不会建立应用Ingress；单改Ingress也不等于公共入口已切换。

config只有services_ingress_enabled，其他资源/port当前在模板和集群配置；不能宣称任意字段都可从config调。内部关系HTTPS链见[service-access](service-access/README.md)。公共入口切换唯一方法在infrastructure/entry README。

## 失败定位

HelmRelease Ready后检查实际Service/Ingress/证书SAN、目标Pod和真实登录。相同域名的旧Ingress可能将流量送到已停止后端，Pod Running不替代入口验收。更改域名/CA联动应用origin与回调及客户端信任；不关闭TLS修复。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_ingress_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../docs/platform-kind-v1/verification.md)。

## 受限CRD与HTTPS上游

traefik_crd_enabled控制原生Kubernetes CRD provider，traefik_crd_namespaces限定入口和数据命名空间；不允许跨命名空间引用或ExternalName服务。标准10份CRD由prepare从锁定chart读取，排除商业Hub CRD，并作为GitOps声明由platform-services拥有；遇到外国已有CRD停止，不自动接管。HelmRelease继续Skip CRD安装/升级，避免重复所有权。

Kibana浏览器路由与内部服务TLS验证配置在[UI组件](../../data-platform/elk/kibana/ui/README.md)。CRD provider配置变化会滚动Traefik，须按当前维护约定部署并回验既有应用入口；关闭provider不删除已存在CRD。
