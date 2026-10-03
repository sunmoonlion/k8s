# 首批平台服务

本期使用新体系的 Make/Ansible 准备物料与私有输入，Flux 从已提交、固定摘要的 OCI 声明部署。旧 `sunmoonai` 组件脚本不是运行依赖。

## 固定版本与部署顺序

| 项目 | 版本 / 实现 | 持久化 |
|---|---|---|
| Traefik | 3.7.13，官方 chart 41.6.0；Helm 4.3.0 用于离线 chart 发布 | 无业务数据 |
| PostgreSQL | 18.6-trixie，官方镜像 | worker/static/postgresql，8 GiB PVC |
| Redis | 8.10.2-trixie，官方镜像；AOF everysec | worker2/static/redis，2 GiB PVC |
| RabbitMQ | 4.3.6-management，官方镜像 | worker2/static/rabbitmq，4 GiB PVC |
| Casdoor | 4.12.0，官方镜像 | 独立 PostgreSQL 库/角色；worker/static/casdoor，1 GiB PVC |

版本与 manifest 摘要见 `infrastructure/artifacts/upstream-images.lock.json`，安装包与 chart 摘要见 `files.lock.json`。安装包、OCI 归档、chart 分别存入正式物料目录的 `packages/`、`images/`、`charts/`。五个服务镜像及 chart 已发布至新 Harbor，节点按摘要从 Harbor 拉取。

Flux 顺序：`platform-services`（存储、入口、三个数据服务）→ `casdoor-db`（独立库/角色 Job）→ `casdoor-init`（身份初始化 Job）→ `casdoor`（服务）。数据目录是新集群三个节点独立挂载中的专属子目录；PV 使用 `sunmoon-static`、显式 nodeAffinity、Retain。15 GiB PVC 容量声明不是立即分配 15 GiB；本地 PV 的容量字段不是目录配额，实际占用另行监控。所有阶段 `prune:false`，禁止借配置变更自动删除数据。

本期都是单副本，适用于当前本机验证。跨主机高可用、周期性数据库备份与服务级独立恢复、WSL/KIND 重启与删除重建验收、应用链路并未由本页替代。

## 组件分类和命名空间

| 分类 | KIND 命名空间 | 组件 |
| --- | --- | --- |
| ingress-platform | ingress-platform-dev | Traefik |
| data-platform | data-platform-dev | PostgreSQL、Redis、Casdoor 建库 Job |
| messaging-platform | messaging-platform-dev | RabbitMQ |
| app-platform | app-platform-dev | Casdoor 初始化和服务 |

Flux 仍在 `flux-system`，`platform-system` 只保留基础引导/发布标记。Casdoor 是应用服务，其数据库基础设施归数据平台；库、角色和 Secret 保持独立。命名空间迁移和验收记录见 [调整记录](namespace-layout.md)。

## 配置和 Secret

- 组件字段：`gitops/components/<平台>/<组件>/config.yaml`，包含各组件启用开关、域名、数据库名/角色和卷位置；同目录模板消费这些字段。
- 共享命名空间：`infrastructure/environments/kind/site.yaml`；服务总开关与私有输入/备份路径：`infrastructure/services/config.yaml`。
- `infrastructure/Makefile` 的明确配置列表供所有原生入口使用；不要再只给 Ansible 传旧的单个 site 文件。`make -n <目标>` 可查看完整原生命令。
- 私有输入：`/etc/sunmoon/services/sunmoon-kind/credentials.yaml`，root:root 0600；目录 0700。
- 独立副本：`/mnt/sunmoon-data/backups/services/sunmoon-kind/`，包含输入和 TLS 身份；与系统盘同一物理硬盘，不是机器外灾备。
- Git 只存 SOPS 密文。原始密码表仍只是所有者的集中查阅表；新运行链不读取旧 `.conf` 或密码表，不执行旧脚本。
- 本次一次性按字面值导入原 PostgreSQL 管理员、Casdoor 数据库、Redis、RabbitMQ 用户/密码/cookie 六个字段；没有执行配置文件。新 Casdoor 初始管理员密码单独生成，保存在上述私有输入中，不在对话/日志展示。
- `services-credentials`：有输入时保留；主输入缺失时从备份恢复；只有未声明的全新环境才生成随机凭据。已经存在加密声明却同时丢失输入和备份时拒绝重新生成，要求恢复。
- 修改密码不等于修改运行数据库密码。凭据轮换必须单独编排数据库/客户端更新、验证和备份；当前入口会拒绝私有输入与备份不同，或候选与已提交声明不同，避免把修改静默当成成功。

私有输入字段为 `service_credentials` 下的 `postgresql_password`、`redis_password`、`rabbitmq_username`、`rabbitmq_password`、`rabbitmq_cookie`、`casdoor_db_password`、`casdoor_admin_password`。`casdoor_application_secret` 预留给后续应用注册，本期未用于业务 OAuth 客户端。

Casdoor 的 `/server -export` 在导入初始身份之前退出，因此首次 Job 启动隔离服务、等待可用，再写入 `/files/.initialized-v1`。随后停止初始化进程；正式服务不配置 init_data 导入。存在完成标记时初始化 Job 仅运行无身份覆盖的数据库导出检查，防止集群重建重置管理员。该标记应与 Casdoor 文件卷和数据库一起备份；本次 namespace 迁移已完成四卷冷备份、独立解包与全目录内容/权限比对，但未从该备份启动另一套数据库做业务恢复演练。Casdoor 官方服务仍有内置 schema 初始化行为，不将其冒充业务应用的独立迁移链。

## 字段的维护边界（2026-10-03 逐项核对）

本节明确当前实现支持什么；文件在 config.yaml 中不代表已有数据时可以直接修改。各组件 README 已链接本手册。普通参数、固定约定、初始化身份和凭据分别处理，不把所有字段都宣称为日常开关。

### 用户名、密码与令牌

| 对象 | 当前来源或固定值 | 修改规则 |
| --- | --- | --- |
| PostgreSQL 管理员用户名 | 模板固定 `postgres` | 本期固定管理身份，不作为日常用户名配置；业务使用自己的库与角色 |
| PostgreSQL 管理员密码 | 私有输入 `service_credentials.postgresql_password` | 已有实例必须做数据库、Secret、依赖方和备份的一致轮换；不能只改输入 |
| Redis 用户名 | 当前 requirepass 模式使用默认用户 `default`，没有单独 username 字段 | 这是本期已实现模式；逐应用 ACL 身份尚未实现，不能声称已有隔离账号 |
| Redis 密码 | 私有输入 `redis_password` | 需要 Redis 配置和客户端协调轮换 |
| RabbitMQ 用户名、密码 | 私有输入 `rabbitmq_username`、`rabbitmq_password` | 用户名不是秘密，但与已初始化账号一起保存；已有 broker 的账号变更不能仅改初始配置 |
| RabbitMQ Erlang cookie | 私有输入 `rabbitmq_cookie` | 节点通信身份，不能当普通登录密码修改；已有持久文件会与输入核对 |
| Casdoor 数据库用户名、库名 | 组件 `config.yaml` 中 `casdoor_database_user`、`casdoor_database` | 新环境初始化参数；已有库更名/换角色属于数据与身份迁移，Job 不自动搬数据或修改已有角色密码 |
| Casdoor 数据库密码 | 私有输入 `casdoor_db_password` | 数据库角色、应用配置及备份要一起轮换 |
| Casdoor 管理员用户名 | 初始化与验收固定 `built-in/admin` | 本期固定引导身份，不是可直接修改的普通字段 |
| Casdoor 管理员初始密码 | 私有输入 `casdoor_admin_password` | 初始化一次；修改文件不会更新已有 Casdoor 账号，需账号更新与输入/备份同步 |
| Casdoor 应用密钥 | 私有输入 `casdoor_application_secret` | 当前是预留字段，尚未接入业务 OAuth 客户端，不把生成它记作应用注册完成 |
| Harbor 管理员用户名、密码 | 固定 `admin`；`/etc/sunmoon/registry/private/admin-password` | 与平台凭据分开；已有账号通过 Harbor 受控轮换，不能靠重新运行安装器覆盖 |
| Harbor 内部数据库密码 | `/etc/sunmoon/registry/private/database-password` | 官方仓库内部身份；修改需要配套维护，不与业务 PostgreSQL 密码复用 |
| Harbor publisher / puller | `/etc/sunmoon/registry/private/` 下机器人身份及认证 JSON | Harbor 创建、权限分离；机器人令牌轮换须同步使用方，不能编辑 JSON 冒充远端变更 |

平台私有输入全路径是 `/etc/sunmoon/services/sunmoon-kind/credentials.yaml`，上述简写字段均在 `service_credentials` 下。组件旁的 `*.sops.yaml` 是发布密文，不是明文编辑入口。没有把密码数值复制进本文或普通配置。

现有 `services-credentials` 负责首次生成、已有输入保留和备份恢复；**统一凭据轮换入口尚未实现**。先核对真实账号和备份，再通过显式维护流程轮换，不能宣称修改文件即完成。

### 端口：固定约定与宿主映射分开

| 端口 | 当前值 | 所有者与支持边界 |
| --- | --- | --- |
| PostgreSQL 内部服务 | 5432 | 本期固定；服务、客户端、网络策略和验收采用同一约定 |
| Redis 内部服务 | 6379 | 本期固定；requirepass 配置、服务、探针与策略配套 |
| RabbitMQ AMQP / 管理接口 | 5672 / 15672 | 本期固定；管理接口用于当前原生验收，不表示对外开放 |
| Casdoor 容器 / Service HTTP | 8000 | 本期固定；应用配置、探针、Ingress 后端和网络策略配套 |
| Traefik NodePort | 30443 | 本期固定；与 KIND 节点映射保持一致，与宿主同号端口是不同网络位置 |
| 对外共享 TLS 入口 | 30443 | `infrastructure/entry/config.yaml` 的 `entry_port`；仓库地址/引用和客户端同时依赖它，本期对外契约保持，不是随意可换端口 |
| Harbor 回环后端 | 11443 | `infrastructure/registry/config.yaml` 的 `registry_https_port`；Harbor 与 entry 模板引用同一字段，修改须安排两服务配置/维护 |
| KIND API 宿主映射 | 27443 | `infrastructure/cluster/config.yaml` 的 `cluster_api_port`；建群参数，已有节点不能凭改 YAML 自动重绑端口 |
| KIND 入口宿主映射 | 29443 | 同文件 `cluster_ingress_port`；已有节点需要重建安排；Casdoor 当前验收仍固定使用29443，任意端口支持未贯通 |
| 入口应用后端 | 当前原 worker 的 `172.18.0.5:30443` | `entry/config.yaml` 的 `entry_cluster_backend`；维护切换参数，尚未切到新集群业务入口 |

本期内部端口明确采用上述固定值，不增加未经端到端支持的可调字段。如果后续确需开放端口配置，必须让监听、Service、探针、网络策略、客户端和验收共同引用唯一输入；只把一个常量搬进 config.yaml 不算完成。

### 其余已暴露字段

| 字段 | 分类 | 当前操作边界 |
| --- | --- | --- |
| `services_*_enabled` 及各模块 enabled | 发布选择/动作准入 | 走对应原生入口与依赖检查；Flux `prune:false` 下关闭开关不自动停服或删除已有服务/数据。也不表示任意组合都已完成验收 |
| `casdoor_hostname` | 应当支持的环境参数，当前仅默认值完整走通 | 模板读取它，但 verify-live.py 仍固定域名，已有证书不会因参数改变自动重签；域名变更能力未交付 |
| `*_volume.size` | 存储声明/容量规划 | 本地静态PV的容量声明不是目录配额，也不是自动扩容；已有PV/PVC改容量需要专门流程 |
| `*_volume.node` | 数据放置/迁移 | 移动已有本地卷需要先搬数据并处理亲和性；Casdoor主服务与init仍固定worker，node字段尚未完全贯通，不能直接改成worker2 |
| `*_volume.name/uid/gid` | 持久路径与镜像身份约定 | 当前固定组件名和镜像兼容身份；不是用户账号/登录密码，已有数据不能直接改属主或路径 |
| `rabbitmq_node_hostname` | 持久化节点身份 | 已有Rabbit数据绑定此身份；保持原值，客户端使用新的Service地址。不是普通域名配置 |
| `cluster_name`、命名空间、网段、数据根、kubeconfig | 环境建立/迁移参数 | 当前部分守卫明确限定sunmoon-kind与已批准路径；目录归拢不等于支持任意重命名。已有环境改动须迁移/重建安排 |
| `registry_hostname`、共享 `registry_address` | 仓库对外身份 | 当前固定harbor.sunmoonai.com:30443，证书、镜像引用、拉取认证及守卫均依赖；改域名不是单文件操作 |
| `registry_project` | Compose 实例名称 | 当前sunmoon-registry；不是Harbor中存镜像的platform项目，不用它修改仓库项目名 |
| host `storage_uuid`、挂载/VHD路径、最大容量 | 已创建磁盘的身份与容量事实 | 必须匹配实际磁盘；改数值不能创建、扩盘或更换数据盘 |
| `windows_minimum_free_gib`、容量预算 | 已批准的准入策略 | 常规50GiB，不能用改配置绕过；临时例外需按已约定范围单独授权 |
| 服务/Harbor/SOPS私有输入、运行、备份目录 | 安装布局/恢复边界 | 改路径需先迁移并核对权限与完整性，不得让新空路径触发身份重建 |
| 资源 requests/limits、探针、镜像版本/摘要 | 当前发布实现 | 资源与探针仍在模板/Harbor release策略中，版本在锁文件；独立用户资源规格配置尚未实现，不能描述为已有字段 |
| `registry_log_rotation_approved` | 既定授权记录 | 现批准每容器3份×20MiB；不授权删除镜像、备份或任意改变保留策略 |

### 已确认的未完成项

1. Casdoor域名/入口映射要贯通验收与已有证书变更；当前只保证已部署默认值。
2. Casdoor卷节点要贯通主服务和初始化模板；有数据后的搬迁仍需独立流程。
3. 普通资源规格如要提供用户参数入口，需连同校验、模板和预算接入；目前不能声称已经支持。
4. 凭据轮换、逐应用Redis身份、完整启停和重启/重建持久化验收仍按项目顺序完成。

本节是维护边界的明确与现场代码核对，**没有修改密码、端口、服务配置或运行资源，也没有把上述缺项记作已修复**。

## 入口和操作

新 Traefik 监听新集群 NodePort 30443，经宿主 `127.0.0.1:29443` 验收。Casdoor 域名不变、证书沿用平台 CA 签发，有效期五年。**宿主 30443 的应用分流仍指向原集群，本批不切换。** 浏览器常用域名当前不能据此视作已切到新 Casdoor。

```bash
cd /home/zymun/worktrees/platform-kind-v1/k8s/infrastructure
make services-plan                 # 五个固定镜像来源与目标
make services-credentials          # 初始化/恢复私有输入
make services-materials            # 准备缺失的压缩 OCI 归档
make services-publish              # 发布缺失的 Harbor 内容；不同摘要标签拒绝覆盖
make services-tools services-chart # 校验 Helm；发布并完整拉回核对 chart
make services-render              # 生成 .build/services 下可审查候选，不直接写 Kubernetes
make services-validate-release     # 配置、解密后的 Secret 与已提交晋级版本必须一致
make services-bootstrap            # 已晋级版本的一键部署与实际验收
make services-check                # 实际数据库/消息/身份验收
```

常规容量门槛保持 50 GiB。2026-10-03 所有者为这一批特批 40 GiB、最多新增 5 GiB，使用有期限和操作范围的外部参数，本批结束撤销。后续命名调整另获40GiB/最多1GiB例外，也已撤销；最终统一入口已按默认50GiB完整通过，不作为日常绕过门槛的方法。

`services-bootstrap` 顺序执行凭据检查、离线镜像验证/发布、工具/chart、候选生成、与晋级声明比对、Flux 协调和功能验收。已改配置但未提交发布时明确失败；不会“执行成功但用旧配置”。首次准备依赖已有 Harbor、KIND、Flux/SOPS 及已备齐包，本入口是首批服务单元，完整宿主到应用的一键编排仍是后续交付项。

变更发布流程：修改普通配置或私有输入 → `services-render` → 审查 `.build/services/{core,foundations,data-platform,messaging-platform,ingress-platform,app-platform}` 与 `stages.yaml` → 将候选晋级至 `gitops/components/` 和 `gitops/clusters/kind/services.yaml` → 本地 Git 提交 → `make flux-release` → 将 `.build/flux/source-candidate.yaml` 晋级到 `environments/kind/flux-source.yaml` → `make services-bootstrap`。发布器递归校验各子阶段不存在明文 Secret，发布源只来自 Git 对象。

开关控制新声明包含的工作负载；因 `prune:false`，把开关改 false 不会暗中卸载已经存在的服务/卷。全平台启停和组件退役需要后续生命周期入口，不以该开关替代。

## 验收范围及已知变更

`services-check` 核对拥有的 kube-system UID、当前 Flux generation Ready、四个 PV Bound/Retain/目录，然后执行 PostgreSQL 临时事务读写、Redis 有过期时间的唯一键读写并删除、RabbitMQ 临时队列发布/取回并删除、Casdoor 经 TLS 入口登录和会话读取。同时用唯一临时 Pod 验证 app→PostgreSQL 的完整 DNS、允许客户端连接和无客户端标签时拒绝连接；同一锁定缓存镜像、同一节点，不使用数据库口令做网络探测，按 UID 核对后清理。凭据经私有输入/stdin/cookie 文件传递，临时 cookie 和端口转发在 finally 中清理。

RabbitMQ 使用管理 API 完成真实消息路由/取回，**尚不是业务客户端 AMQP 链路验收**。4.3 默认不再接受非持久非独占队列，验收改为 durable classic + 队列 TTL，不开启废弃功能。后续应用客户端的队列声明需单独核对。[官方队列说明](https://www.rabbitmq.com/docs/queues#durability)

Traefik chart 41.6 使用 `log`、`accessLog`，`versionOverride` 在 values 根层；首次错误已修正。官方 Helm schema/模板校验通过后才晋级修正版本。此前失败记录保留，不能用最后 Ready 覆盖第一次失败事实。

机器侧证据在 `/data/kind-clusters/sunmoon-kind/bootstrap/evidence/services/`；日志归档在相邻带日期目录。数据库与消息验证通过不等于业务 App、完整登录/授权体系、网络策略的客户端覆盖和持久化重建已全部通过。

命名调整实际修复了 RabbitMQ 已有 cookie 被 fsGroup 变成0660的问题：初始化每次校正0600并比较内容，不重写身份；渲染器不再重置已有卷根权限。Flux apply 即使声明无差异，也须等待新源摘要和当前 generation 真正 Ready。旧同域名 Ingress 必须退役，否则可把请求送到已停止后端而返回503；Pod Running不能替代真实登录。

## 2026-10-03 配置归拢

各组件配置、模板、声明和说明已经集中到组件目录，Casdoor的database/init/运行三个阶段共处app-platform/casdoor。原data-platform/casdoor-database、app-platform/casdoor-init、集中services/templates及environments/kind/services.yaml退役，不留转发副本。运行namespace、PV、凭据和版本保持。

配置定位：`make -C infrastructure config`。宿主、KIND、Harbor、入口、Flux各自参数在相应模块config.yaml；共享环境字段才放site.yaml。

本次晋级遇到前次迁移留下的摘要字段冲突：同一个sunmoon-bootstrap名称的Update与Apply仍是不同管理记录。前两次受保护预览在真正写入前停止（API默认provider字段、同值Apply仍共享归属）；最终核对UID/resourceVersion、现摘要、精确已有归属后，只在一次性源声明接管中允许冲突覆盖并晋级已审核摘要。服务端预览要求其余spec与其他管理者字段完整保留；日常tasks/apply.yaml不启用force，后续继续原生SSA发布。没有直接编辑或清空managedFields。[Kubernetes字段归属规则](https://kubernetes.io/docs/reference/using-api/server-side-apply/#conflicts)。

本轮最终：29份Ansible语法、13个Kustomize根通过，原生render与晋级声明/密文比对通过；五Flux阶段已应用255728911c9e141b614fa55ac1b3d750dbe1c3ea711dc67f92bb6fd545fdb6f9，七个Pod身份/重启数、四PV身份/spec保持。本轮没有重跑业务协议验收、停机或迁移数据；现场内容不变不能替代后续业务与重建持久化验收。证据保存在bootstrap/evidence/config-colocation-20261003，临时脚本已退出日常目录。
