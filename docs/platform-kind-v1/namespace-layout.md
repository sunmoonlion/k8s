# 部署目录与组件命名空间调整

## 范围与当前状态

所有者已确认命名方案。本次只改新工作树 k8s；宿主 Harbor、原始 kind、物料 release ID 和对外域名/端口不变。

- 部署代码根已从 `platform/` 移到 `infrastructure/`；没有兼容转发目录。Make/Ansible、KIND、官方 Harbor Compose、Flux OCI/SOPS 的职责保持原架构。
- 组件模板、GitOps声明和实际运行资源已按下表迁移；五服务Ready、零重启，两初始化Job完成，四卷Bound且原PV UID保留。实际协议与统一入口验收已通过。
- Ansible 虚拟环境已从本地锁定缓存重装入口；物料 `releases/platform-kind-v1`、Harbor `platform` 项目、分支和工作树名称均是发布身份，不随代码目录改名。

| 组件 | GitOps 分类 | 迁移前命名空间 | 当前命名空间 |
| --- | --- | --- | --- |
| Traefik | ingress-platform | ingress-system | ingress-platform-dev |
| PostgreSQL、Redis | data-platform | platform-system | data-platform-dev |
| RabbitMQ | messaging-platform | platform-system | messaging-platform-dev |
| Casdoor 初始化与服务 | app-platform | platform-system | app-platform-dev |
| Casdoor 建库 Job | app-platform/casdoor/database | platform-system | data-platform-dev |
| Flux | 集群引导 | flux-system | flux-system |

运维分类留名 `ops-platform-dev`，有组件才创建。`platform-system` 保留引导基础对象，不再放上述业务基础服务。Casdoor 管理员、数据库角色/口令、TLS、初始化标记保持原值；PG 管理凭据只出现在 data-platform-dev。应用连接使用 `postgresql.data-platform-dev.svc.cluster.local` 等完整地址。

## 实现与发布

普通配置现已按职责归拢到各组件 `config.yaml`；共享命名空间在 `infrastructure/environments/kind/site.yaml`。`services/layout.yaml` 只定义分类路径和派生引用。原有开关保留。下方迁移证据保持历史原样；本次目录归拢不再次迁移运行命名空间。

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

本次维护已获得单独批准并完成。以下保留经过本次修正的操作顺序：只影响新集群五个服务及回环 29443，原始 kind 的应用入口和外置 Harbor 持续运行。批准维护20分钟、失败恢复另10分钟；本次从停服计时到协议通过回执为898秒（14分58秒），未执行回退。后续维护仍须重新核对现场并单独约定窗口。

1. 重新核对新集群 UID `67d27d4a-f9ad-4f01-a37f-225144cacaef`、四个 PV/PVC UID/claimRef/Retain/节点、本次源摘要和五组件身份；有漂移就停止，不依据旧回执盲做。记录原 Flux/Helm suspend 值和副本数，所有记录在私有证据目录。
2. 候选先完成全部 Kustomize 构建、SOPS 备份密钥解密核对、依赖与 NetworkPolicy 检查，发布 OCI；此时不晋级运行源。
3. 暂停 Flux 根、四个子 Kustomization 和 Traefik HelmRelease，确认调谐已暂停；停止新 Casdoor，然后停止 PG/Redis/Rabbit，等相关 Pod 完全退出，旧 Job Pod 退出。暂停调谐本身不等于停服。
4. 对四个静态数据子目录做一致性冷备份，并保存资源/源指针和私有输入；解包到独立恢复目录，逐文件摘要、路径、UID/GID 比对。两份私有凭据/密钥也必须一致。任一失败，先恢复原副本与调谐，不进行绑定切换。
5. 创建并核对目标 namespace 的基础对象；仅删除列明的旧四个 PVC，等待 Released，再用 UID 条件保护的 patch 将每个 PV claimRef 换为目标 claim（去掉旧 claim UID/resourceVersion）。创建对应目标 PVC，原 PV UID/宿主路径不变；不能对旧 Bound PVC 直接改 namespace。
6. 根保持暂停时晋级并确认新 OCI 源就绪；临时更新源摘要时明确使用原管理者 `--field-manager=sunmoon-bootstrap`，避免交回原生SSA入口时冲突；恢复根，核对新路径和目标 namespace 后恢复四子阶段。Traefik 由同一个 HelmRelease targetNamespace 变更负责卸载旧 release 再安装新 release，确认旧 NodePort 已释放；不要另执行 helm install 造成端口或集群 RBAC 冲突。恢复其 helm 调谐以允许 core 健康等待完成。[Flux targetNamespace 行为](https://fluxcd.io/flux/components/helm/helmreleases/#target-namespace)。
7. 新Casdoor就绪后先保存并删除旧namespace的同域名Ingress，避免旧已停后端仍命中路由。用 `services-check` 验实际 imageID、四卷绑定、PG/Redis 读写、Rabbit 发布消费、Casdoor TLS 登录与会话；新应用到数据库的跨 namespace 访问和未授权访问拒绝需实测。再重复执行 `services-bootstrap` 验幂等；这不是整项目全部业务验收。
8. 成功后按清单移除旧服务对象与旧 Secret（保留 platform-system 的引导对象）、退役旧候选目录；保留本次恢复点到本单元验收结束。最后更新事实状态和证据，撤销容量例外。不得笼统删除 namespace 或整个数据目录。

停止条件：容量不足、cluster/PV UID 漂移、备份核对失败、旧写入 Pod 未退出、目标 namespace 已有不明资源、Rabbit 内部身份不一致、PVC 未在规定节点绑定、任一步超出窗口。

## 回退

恢复前先暂停新声明调谐，停止所有目标命名空间写入者，再释放目标 PVC，按记录把同一 PV 重绑原 platform-system 下的 claim。源回到 `sha256:bbf06e3c5cf779e394c7eece654c3361e8b4632356b029900ad785fd06e8a438`（声明提交 `7468cd01d939e10dc612f81a0e5cbb780b3dc2d7`）。恢复原调谐及副本，Traefik targetNamespace 回到 ingress-system。此次不改变数据库版本/schema；仍先对照数据后决定是否需要从冷备份恢复，绝不在写入者运行时覆盖目录。

若文件已被破坏，只在上述写入者全部停下且精确路径再核对后恢复冷备份，并重复全目录摘要和协议验收；备份本身不删除。原始 kind 和 Harbor 不作为这次 namespace 回退的变更对象。

## 容量与批准记录

2026-10-03 03:54:50 UTC 只读盘点：四个目录实际逻辑大小合计 68,502,356 字节（约65.33MiB）；RabbitMQ 队列清单为空。冷备份加解包核对约需其两倍，另留配置制品、日志及数据库运行增长，本单元批准新增预算上限1GiB，迁移复用当前节点镜像缓存、不更换软件版本。

C 盘实测空闲114,323,898,368字节，数据盘未来增长66,936,897,536字节；未扣本单元预算余44.13GiB，低于正常50GiB。前批40GiB例外已经撤销。所有者随后明确批准本单元40GiB门槛、最多新增1GiB，现已撤销临时参数并将归档参数标记过期。

本单元窗口、四个旧PVC对象的保数据重绑定及容量例外均已明确批准并执行。最新04:39:10Z容量读数扣增长及16MiB验收预算后余61,735,886,848字节（约57.49GiB），正常50GiB门槛重新可用。C盘空闲在运行期间增加约13GiB，来源未核实，不能归因于本次迁移或计为清理收益。

## 已做的检查

29个原生 playbook 语法检查、源码 YAML/Python 解析通过。独立临时目录中使用同一原生模板渲染公共声明，6任务全部成功；56个对象的唯一性、组件namespace、PV Retain/claim映射和Flux路径存在性核对通过。新路径 `make services-plan` 只读运行成功。随后完整SOPS候选核对ok107 changed0 failed0；冷备份独立解包、协议和网络边界检查、统一入口重复执行、旧对象清理后的复验均通过。

旧 `.build/services/{core,casdoor-db,casdoor-init,casdoor}` 中20个生成文件已与当前Git发布逐字节核对后退役；chart-source保留。候选现已按新分类重新生成、提交和发布，旧GitOps services目录已退役。

## 实际执行结果与边界

- 当前源 `sha256:9d231384742cc015f19793f7748117871cd154d3895af4e454cb1aa0cf7a12f0`，声明提交 `447fceddf6eb8416bd5a475ef6d6fef6d1ca3e99`。初次分类声明947ee03a随后由Rabbit权限修复取代，不能把首次失败写成成功。
- 冷归档 `volumes.tar` 为71,198,720字节，SHA256 `895b072a527e2d65f8c19e6d321ad35a5c3f3d07075cd694f01fd9992de96c4e`；独立解包核对1,619项内容、路径、UID/GID和权限一致。四个原PV UID、节点和物理路径不变；cookie值、凭据、TLS证书和Casdoor初始化标记保留。
- 遇到并修复：fsGroup改变已有Rabbit cookie权限；一次性维护patch抢占源digest字段管理权；无diff的原生apply未等待仍在协调的新摘要；旧同域名Ingress残留造成503。对应失败及成功记录均归档；没有以最后Ready覆盖这些失败。
- `services-bootstrap`九段全部failed0，持久配置/凭据/声明无变更；chart的changed2是创建/删除本次临时工作目录，验收changed1是写回执。撤销例外后，默认50GiB门槛下再次完整通过。
- 除已删旧路由、四个PVC和两个旧Job外，逐一核对原声明归属及UID后退役27个旧对象；遍历全部可列举命名空间资源确认无业务对象后删除空的ingress-system。platform-system的引导基础保留。
- 宿主Harbor十容器healthy、Harbor及入口systemd active；原kind控制面仍停止、两worker仍运行。宿主30443应用分流未切换，只验了新回环29443路径。
- 本轮没有验证完整业务App、AMQP客户端链路、从冷备份启动独立数据库、WSL/KIND重启或删除重建；整项目统一生命周期及长期空间管理仍在后续队列。

证据位置：`/data/kind-clusters/sunmoon-kind/bootstrap/evidence/namespace-layout-20261003/`，最新协议回执在相邻`services/latest.json`。数据备份和秘密不入Git。冷归档及摘要保留；核对完成的临时解包副本和本次/tmp工作文件在归档后移除。正式`.tools/.venv/.build`分别是已安装工具、依赖和可复现候选，不是另一套部署系统。

最终逐引用审计还将凭据丢失保护中的旧Secret路径更新为`gitops/components/data-platform/postgresql-auth.sops.yaml`，避免主输入和备份同时丢失时误判新环境；原生凭据检查ok21 changed0 failed0。25份临时文件已归档并逐字节核对后移除，两处/tmp目录及冷恢复解包副本也已清理，冷归档保留。
