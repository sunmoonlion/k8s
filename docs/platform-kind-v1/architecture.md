# 新体系架构与维护约束

## 适用范围与目标

第一期是单机WSL中的KIND开发环境，以固定来源、声明所有权、权限分离、可恢复身份和可审查操作构建长期维护的部署代码。代码主体位于infrastructure/gitops/docs；目前尚无云上实机路径或HA交付，不能将单机KIND宣称为付费生产高可用环境。

长期目标是一套平台/应用部署代码与两种建群方式：本地KIND、后续云端建群；建群以后的组件声明与维护流程共用。云端、VM演练及生产RPO/RTO/HA目标另行审定。[验收边界](verification.md)记录当前实际覆盖。

## 职责与所有权

| 层 | 唯一责任/入口 |
|---|---|
| 宿主 | WSL、Docker、真实挂载与峰值容量；host preflight/capacity |
| 仓库 | WSL独立官方Harbor+Compose+systemd；registry |
| 公共TLS | HAProxy按SNI直通，Harbor与应用共用30443；entry |
| 建群 | 固定KIND节点/CNI、三节点mount、CA/DNS、API身份receipt；cluster |
| 发布控制 | 固定Git对象→Harbor OCI候选→显式晋级→Flux；flux |
| 身份 | 私有主备/SOPS、运行与初始化分权；模块prepare及独立Job |
| 平台/应用 | 就近config+template+rendered+sops；Make/Ansible准备，Flux依赖调和 |

Make是公开入口，Ansible编排模块，专用校验程序只处理有限输入/探针，Flux拥有集群声明。不新增平行CLI、转接旧体系或另设部署状态机。配置准备与发布晋级分别有明确副作用；[总入口](../../infrastructure/README.md)提供导航。

## 配置归属

用户配置、实现与README同职责放置，适用于宿主/Harbor/入口/KIND/Flux/服务/应用；版本、共享环境和源码锁保持单一来源。

- 共享身份/命名空间/物料根：[site](../../infrastructure/environments/kind/site.yaml)。
- 版本与文件/镜像摘要：[artifacts](../../infrastructure/artifacts/README.md)。
- 应用固定parent/gitlink：[sources](../../infrastructure/applications/sources.yaml)。
- 已晋级revision/OCI digest：[flux-source](../../infrastructure/environments/kind/flux-source.yaml)。
- 普通用户名、域名、port、资源、代次：组件config；口令与私钥不入普通配置或说明。

## 平台、应用与命名空间

| 目录归属 | 运行位置 |
|---|---|
| data-platform | data_namespace：数据库、对象存储、检索/模型、ELK、应用建库Job |
| messaging-platform | messaging_namespace：RabbitMQ及应用broker初始化 |
| ingress-platform | ingress_namespace：Traefik |
| app-platform/auth-app/casdoor | app_namespace：Casdoor init/runtime；其database Job用data_namespace |
| app-platform/tpl/info/knowledge/investment-app | 同app_namespace：后端API/Worker/Scheduler、Web、Admin |
| foundations/core | 跨namespace基础对象/组合；Flux对象位于flux-system |

目录保留平台→应用→组件层；common是共享机制，不通过Tpl组件转接其他应用。platform-system保存基础引导/发布标记，不是所有业务运行namespace。共享对象只由foundations声明，避免一份资源多管理者。

## 存储与身份恢复

数据VHDX动态230GiB/ext4，挂/mnt/sunmoon-data，bind新kind-clusters/harbor子目录；三节点各独立static/dynamic目录，静态节点路径保留/data/kind-local-storage/<组件>。旧宿主同名路径禁止覆盖挂载。[存储说明](../../gitops/components/foundations/README.md)与[host](../../infrastructure/host/README.md)记录责任。

静态PV为Retain、有节点约束；声明size不是硬配额。数据库主数据、对象原文版本、Harbor密钥/层/账号、Casdoor文件/marker、age/TLS/许可证和初始化输入各需相应备份。派生索引可重建不等于已实现重建或允许任意删除。

主与独立备份同在一块物理C盘，不防硬件故障；机器外数据库/对象/身份备份落点待定。已有身份双丢失拒绝重新生成，Git退回不回滚数据库schema/账号和持久数据。

## 网络、TLS与在线构建

公共30443→HAProxy SNI→Harbor11443或KIND29443；HAProxy不持私钥，服务端验证CA/SAN和认证。节点私有仓库信任与DNS另由cluster配置并实际拉取核验。未知域名默认仍指原始kind-worker过渡后端，原始kind继续保护。

默认拒绝网络、标签授权、非root/只读根/cap drop/禁SA token；采集器hostPath和入口host network属于注明职责的有限例外。当前Infinity/Valkey及应用AMQP的明文协议由策略限制，不宣称全面mTLS。

建群/仓库引导保留离线物料；应用依赖国内在线直连优先，仅下载网络失败本次自动配套切官方源+现有HTTPS_PROXY一次，代理不可用非交互退出。Harbor直连，TLS/签名/依赖hash不关闭；[构建手册](../../infrastructure/applications/README.md#下载失败与代理)为唯一流程。

## 版本、发布与升级准入

部署按固定linux/amd64 manifest及文件SHA，锁记录解析时间和来源，不追踪latest。官方镜像优先，RAGFlow必要最小派生受官方源SHA守卫，独立记录派生身份。工具容器与源码release可能有明确例外；不复制版本BOM到手册。

发布从已提交Git对象递归校验声明/密文，生成不可变OCI候选；显式晋级后才协调。升级须审配套版本/迁移、完整物料、主备/数据、回退与验收；不能只改tag认为schema及接口兼容。历史结论在[verification](verification.md)，日常源指针只在flux-source。

源码、不可变物料、运行数据各有不同所有权。多仓与子模块关系以sources锁定，维护修改只在相应本地分支提交；推回由所有者的同步流程执行，不自动push。原始kind及其被引用资产保留，新流程不接管旧环境；已退役试验资产不成为新运行依赖。

## 操作语义与交付要求

plan可能读现有身份/文件；render准备目录、证书、身份与模型；stage修改声明，Knowledge provider准备可能创建远端dataset；check可能写随机探针并精确清理。维护手册必须说明副作用、成功/停止条件和恢复。

关闭开关不自动停服，prune=false/Orphan不自动删除新增阶段；Completed Job还由Flux持有。禁止为清状态删PVC/节点卷、重新生成身份、清managedFields或日常force apply。

当前开发维护2小时；容量10GiB，仍扣除230GiB数据盘未来增长与本操作预算。对外服务时重定维护、容量与恢复目标。镜像GC/缓存/备份/日志索引策略先批准，保护在用与回退资源。整套部署/启停/开机、持久化重启/删群和长期空间管理的完成条件明确列在[未完成项](verification.md#未完成项)。
