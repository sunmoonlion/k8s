# 部署目录与组件命名空间调整

## 范围与当前状态

所有者已确认命名方案。本次只改新工作树 k8s；宿主 Harbor、原始 kind、物料 release ID 和对外域名/端口不变。

- 部署代码根已从 `platform/` 移到 `infrastructure/`；没有兼容转发目录。Make/Ansible、KIND、官方 Harbor Compose、Flux OCI/SOPS 的职责保持原架构。
- 组件模板和验收入口已改为下表。**运行资源尚未迁移，GitOps 已发布源仍是旧命名空间**；未晋级候选前，不得把代码改名当作运行验收通过。
- Ansible 虚拟环境已从本地锁定缓存重装入口；物料 `releases/platform-kind-v1`、Harbor `platform` 项目、分支和工作树名称均是发布身份，不随代码目录改名。

| 组件 | GitOps 分类 | 当前命名空间 | 目标命名空间 |
| --- | --- | --- | --- |
| Traefik | ingress-platform | ingress-system | ingress-platform-dev |
| PostgreSQL、Redis | data-platform | platform-system | data-platform-dev |
| RabbitMQ | messaging-platform | platform-system | messaging-platform-dev |
| Casdoor 初始化与服务 | app-platform | platform-system | app-platform-dev |
| Casdoor 建库 Job | data-platform/casdoor-database | platform-system | data-platform-dev |
| Flux | 集群引导 | flux-system | flux-system |

运维分类留名 `ops-platform-dev`，有组件才创建。`platform-system` 保留引导基础对象，不再放上述业务基础服务。Casdoor 管理员、数据库角色/口令、TLS、初始化标记保持原值；PG 管理凭据只出现在 data-platform-dev。应用连接使用 `postgresql.data-platform-dev.svc.cluster.local` 等完整地址。

## 实现与发布

普通配置唯一输入为 `infrastructure/environments/kind/services.yaml`。`services/layout.yaml` 只定义源码分类路径。原有组件开关继续保留。

`make -C infrastructure services-render` 经原生模板生成 `.build/services` 候选；Secret 重新通过 SOPS 加密，不能直接文本替换密文的 namespace（MAC 会不匹配）。Kustomize 公共 core 组合 foundations、data、messaging、ingress 分类；Casdoor 建库、初始化和运行按依赖分阶段。

所有新工作负载命名空间带 restricted 准入、无自动 API token 的运行身份、拉取身份、资源默认值、默认拒绝及 DNS 放行。跨命名空间访问必须同时匹配 namespaceSelector 与 podSelector，只放行明确端口。Traefik 的集群 API/RBAC 由官方 chart 管理。

发布须先审核候选、提交 GitOps、通过 `flux-release` 将该提交打为固定摘要 OCI，再晋级 `environments/kind/flux-source.yaml`；`services-validate-release` 拒绝候选与已晋级声明不一致。不能直接把未提交工作区当成运行真源。

## 数据边界

四个 PV 保持原名字、Retain、节点亲和性和宿主目录，数据不移动：

| PV | 节点静态子目录 | 新 claim 命名空间 |
| --- | --- | --- |
| sunmoon-kind-postgresql | worker/static/postgresql | data-platform-dev |
| sunmoon-kind-redis | worker2/static/redis | data-platform-dev |
| sunmoon-kind-rabbitmq | worker2/static/rabbitmq | messaging-platform-dev |
| sunmoon-kind-casdoor | worker/static/casdoor | app-platform-dev |

命名空间不能原地改名。维护中需要删除**旧命名空间中的四个 PVC 对象**并重绑定，保留四个 PV 及其全部数据。先确认原 Pod 全停止，才允许释放 claim；禁止强删 finalizer、禁止同时启动两份读写相同目录的服务。

RabbitMQ 的磁盘恢复要求相同节点名，不能随服务 DNS 自动改名。[官方备份恢复约束](https://www.rabbitmq.com/docs/backup)。本次保持已存在的 `rabbit@rabbitmq-0.rabbitmq-headless.platform-system.svc.cluster.local` 为持久内部身份；单节点 Pod 通过 hostAliases 将它解析到自身回环地址，不依赖旧 namespace/Service。客户端只访问新 messaging 命名空间中的 Service。该配置明确限定当前单节点架构，未来扩为多节点必须另设计发现和节点身份，不能复制本回环映射。

## 维护顺序与停止条件

维护尚未开始。按所有者此前约定，停服窗口及容量例外单独确认后执行：只影响新集群五个服务及回环 29443，原始 kind 的应用入口和外置 Harbor 持续运行。建议维护 20 分钟，失败恢复另留 10 分钟；执行前重新核对数据大小和备份耗时。

1. 重新核对新集群 UID `67d27d4a-f9ad-4f01-a37f-225144cacaef`、四个 PV/PVC UID/claimRef/Retain/节点、本次源摘要和五组件身份；有漂移就停止，不依据旧回执盲做。记录原 Flux/Helm suspend 值和副本数，所有记录在私有证据目录。
2. 候选先完成全部 Kustomize 构建、SOPS 备份密钥解密核对、依赖与 NetworkPolicy 检查，发布 OCI；此时不晋级运行源。
3. 暂停 Flux 根、四个子 Kustomization 和 Traefik HelmRelease，确认调谐已暂停；停止新 Casdoor，然后停止 PG/Redis/Rabbit，等相关 Pod 完全退出，旧 Job Pod 退出。暂停调谐本身不等于停服。
4. 对四个静态数据子目录做一致性冷备份，并保存资源/源指针和私有输入；解包到独立恢复目录，逐文件摘要、路径、UID/GID 比对。两份私有凭据/密钥也必须一致。任一失败，先恢复原副本与调谐，不进行绑定切换。
5. 创建并核对目标 namespace 的基础对象；仅删除列明的旧四个 PVC，等待 Released，再用 UID 条件保护的 patch 将每个 PV claimRef 换为目标 claim（去掉旧 claim UID/resourceVersion）。创建对应目标 PVC，原 PV UID/宿主路径不变；不能对旧 Bound PVC 直接改 namespace。
6. 根保持暂停时晋级并确认新 OCI 源就绪；恢复根，核对新路径和目标 namespace 后恢复四子阶段。Traefik 由同一个 HelmRelease targetNamespace 变更负责卸载旧 release 再安装新 release，确认旧 NodePort 已释放；不要另执行 helm install 造成端口或集群 RBAC 冲突。恢复其 helm 调谐以允许 core 健康等待完成。[Flux targetNamespace 行为](https://fluxcd.io/flux/components/helm/helmreleases/#target-namespace)。
7. 用 `services-check` 验实际 imageID、四卷绑定、PG/Redis 读写、Rabbit 发布消费、Casdoor TLS 登录与会话；新应用到数据库的跨 namespace 访问和未授权访问拒绝需实测。再重复执行 `services-bootstrap` 验幂等；这不是整项目全部业务验收。
8. 成功后按清单移除旧服务对象与旧 Secret（保留 platform-system 的引导对象）、退役旧候选目录；保留本次恢复点到本单元验收结束。最后更新事实状态和证据，撤销容量例外。不得笼统删除 namespace 或整个数据目录。

停止条件：容量不足、cluster/PV UID 漂移、备份核对失败、旧写入 Pod 未退出、目标 namespace 已有不明资源、Rabbit 内部身份不一致、PVC 未在规定节点绑定、任一步超出窗口。

## 回退

恢复前先暂停新声明调谐，停止所有目标命名空间写入者，再释放目标 PVC，按记录把同一 PV 重绑原 platform-system 下的 claim。源回到 `sha256:bbf06e3c5cf779e394c7eece654c3361e8b4632356b029900ad785fd06e8a438`（声明提交 `7468cd01d939e10dc612f81a0e5cbb780b3dc2d7`）。恢复原调谐及副本，Traefik targetNamespace 回到 ingress-system。此次不改变数据库版本/schema；仍先对照数据后决定是否需要从冷备份恢复，绝不在写入者运行时覆盖目录。

若文件已被破坏，只在上述写入者全部停下且精确路径再核对后恢复冷备份，并重复全目录摘要和协议验收；备份本身不删除。原始 kind 和 Harbor 不作为这次 namespace 回退的变更对象。

## 容量与待批准动作

2026-10-03 03:54:50 UTC 只读盘点：四个目录实际逻辑大小合计 68,502,356 字节（约65.33MiB）；RabbitMQ 队列清单为空。冷备份加解包核对约需其两倍，另留配置制品、日志及数据库运行增长，建议本单元新增预算上限1GiB，迁移复用当前节点镜像缓存、不更换软件版本。

C 盘实测空闲114,323,898,368字节，数据盘未来增长66,936,897,536字节；未扣本单元预算余44.13GiB，低于正常50GiB。前批40GiB例外已经撤销。新的运行维护需明确批准本单元40GiB门槛、最多新增1GiB，结束恢复50GiB；没有批准前只能准备代码和只读盘点。

待批准：上述新服务维护窗口、四个旧 PVC 对象的保数据重绑定、该单元容量例外。命名方案本身已经批准，不重复征求。

## 已做的检查

29个原生 playbook 语法检查、源码 YAML/Python 解析通过。独立临时目录中使用同一原生模板渲染公共声明，6任务全部成功；56个对象的唯一性、组件namespace、PV Retain/claim映射和Flux路径存在性核对通过。新路径 `make services-plan` 只读运行成功。未执行服务迁移；完整SOPS候选构建、维护中的备份恢复与迁移后的协议验收仍未完成。

旧 `.build/services/{core,casdoor-db,casdoor-init,casdoor}` 中20个生成文件已与当前Git发布逐字节核对后退役；chart-source保留。实际声明及运行源均未删除，下一次由已改模板重新生成分类候选。
