# K8s 持久化方式及本项目持久化方案设计

更新时间：2026-09-28。本文取代 2026-04-14 版的项目方案和操作说明，旧内容通过 Git 历史查询。

**统一目标：只有一套部署代码，加上两种建集群的方式。本地把平台和应用跑通，云上除了建集群那一步，其余走的是同一条路。**

本页是持久化架构与日常操作索引，具体配置以被链接的配置文件为准。当前正在整理和迁移，不能把目标拓扑当成已经部署完成。

## 一、先分清几个概念

| 概念 | 说明 | 能否保证数据不丢 |
| --- | --- | --- |
| 容器可写层 | 容器自身文件系统的写入层 | 不作为业务持久化位置 |
| `emptyDir` | 同一个 Pod 内的临时共享目录 | Pod 删除后不保留 |
| `hostPath` | 把 Kubernetes 节点上的目录挂给 Pod；也可作为 PV 的后端 | 取决于那台节点和目录是否保留，不提供副本 |
| `local` PV | 使用 `spec.local.path` 的本地持久卷，需要节点亲和性 | 节点本地存储，不自动跨节点复制 |
| PV / PVC | PV 描述存储资源，PVC 申请并绑定资源 | 资源对象存在不等于底层数据已备份 |
| StorageClass | 描述供应方式、绑定时机和回收策略 | 名字不代表实际介质或高可用能力 |

旧版把 Local Volume 写成 `hostPath + nodeAffinity`，概念不准确。项目现有静态模板中的 `spec.hostPath` 仍是 hostPath 类型；给它加节点亲和性不会变成 `spec.local`。原理见 [Kubernetes Volumes](https://kubernetes.io/docs/concepts/storage/volumes/#local)。

静态供应是预先创建 PV；动态供应由 provisioner 根据 PVC 创建资源。`volumeName` 指定目标 PV，仍须满足绑定条件。Helm 的 `existingClaim` 是引用已有 PVC 的 chart 参数。`Retain` 表示释放后保留底层存储待处理，不会自动完成重绑定；`Delete` 可能删除供应出的存储。见 [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)。

`WaitForFirstConsumer` 能结合 Pod 的调度要求安排卷绑定，但不能为本地数据提供副本。动态供应也需要容量、权限、回收和恢复管理。见 [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)。

## 二、当前实际状态与目标

下表依据迁移记录和已提交实现整理；本次文档修改没有重新操作现场。

| 对象 | 当前记录 | 后续安排 |
| --- | --- | --- |
| 旧 `kind` | 仍承载公开入口、旧 Harbor 和当前 inbox | 保留节点和卷；维护切换及观察期完成前不删除 |
| `sunmoon-kind-136` | 一次性验证环境，未按新方案挂宿主数据目录 | 不承载正式数据；不能直接当正式环境 |
| `sunmoon-kind-main` | 配置/创建/启停代码已准备，尚未正式建群 | 1 控制面 + 2 worker，每节点两条独立宿主挂载 |
| 100 GiB 独立 VHDX | 已创建并完成过 UUID、bind、systemd/Docker 可见性核验 | 每次启动仍检查；完整重启恢复验收尚未完成 |
| 宿主 Harbor | 独立实例恢复和受管备份恢复已验，候选停止保留 | 正式 30443 入口、真实 Docker/节点/CI 推拉仍待验收 |
| 云端 | 没有可实操的服务器 | 统一代码、打印演练和静态核对；未经实机验证 |

旧 `kind-worker2` 没有对应宿主目录挂载，其沙箱持久卷在节点关联的 Docker 存储里。**不能因为“没有业务数据要迁”就删它或清理 Docker 卷。**

## 三、本地数据的完整路径

### 3.1 Windows、WSL、节点、Pod 是不同层

```text
Windows C 盘（同一块物理硬盘）
├─ Ubuntu 系统 VHDX
│  ├─ WSL 系统、Docker 运行时数据
│  └─ /data/kind-local-storage    旧数据，禁止覆盖挂载/清空
└─ C:\wsl-disks\sunmoon-data.vhdx    动态扩展，上限 100 GiB，ext4
   └─ /mnt/sunmoon-data
      ├─ kind-clusters  ← bind 到 /data/kind-clusters
      │  └─ sunmoon-kind-main
      │     ├─ control-plane/{static,local-path}
      │     ├─ worker/{static,local-path}
      │     └─ worker2/{static,local-path}
      └─ harbor         ← bind 到 /data/harbor
         └─ 独立 Harbor 实例及受管数据
```

数据盘和系统盘虽然是两个 VHDX，仍在同一块 C 盘物理硬盘上，**不能防硬件故障**。100 GiB 是 KIND 数据与 Harbor 共同使用的上限，不是每个节点各有 100 GiB。PV 里的容量声明也不等于给本地目录配置了磁盘配额。

物理盘容量门禁会扣除数据 VHDX 长满后的潜在增长、建群预算和余量，要求 C 盘仍剩至少 50 GiB。删除 Linux 文件不等于 Windows 立即释放同样空间；VHDX 压缩另按维护窗口进行。

### 3.2 三节点、六条挂载

正式节点的宿主目录互相独立，但节点内路径保持现有静态卷所需的名字：

| 节点后缀 | 宿主路径（都在 `/data/kind-clusters/sunmoon-kind-main/` 下） | 节点容器内路径 |
| --- | --- | --- |
| `control-plane` | `control-plane/static` | `/data/kind-local-storage` |
| `control-plane` | `control-plane/local-path` | `/var/local-path-provisioner` |
| `worker` | `worker/static` | `/data/kind-local-storage` |
| `worker` | `worker/local-path` | `/var/local-path-provisioner` |
| `worker2` | `worker2/static` | `/data/kind-local-storage` |
| `worker2` | `worker2/local-path` | `/var/local-path-provisioner` |

例：Pod 使用 `sunmoon-kind-main-worker` 上的 `/data/kind-local-storage/postgresql` 时，底层应是新数据盘的 `kind-clusters/sunmoon-kind-main/worker/static/postgresql`。

这里的**节点内** `/data/kind-local-storage` 和 WSL 上受保护的**旧宿主** `/data/kind-local-storage` 是不同位置。不能因为字符串相同就把旧宿主目录挂给新节点。

给三节点挂盘不表示默认把数据库调度到控制面；数据库仍按污点、资源和 PV 节点亲和性调度。相同组件名在三个节点目录中是三份不同数据，不自动同步。

### 3.3 挂载先于服务

启动 Harbor 或正式 KIND 之前，检查预期 UUID、根挂载、两条 bind 以及 systemd/Docker 的实际挂载视图。缺盘时不能创建一个空目录冒充挂载，否则服务会把数据写进系统盘。

Windows 当前采用登录触发的无窗口任务，不再每分钟检查。统一服务启动入口有按需检查和附盘接线；正常挂载不调用 Windows。维护标记、任务禁用、附盘失败或视图不一致时拒绝启动。完整 Windows/WSL 重启及缺盘恢复仍待实测。

管理员发布、计划任务、维护暂停与恢复以 [存储操作索引](sunmoonai/kind-infrastructure/mount/README.md) 和 [数据盘操作卡](sunmoonai/kind-infrastructure/docs/owner-data-disk-100g.md) 为准。本文不再保留旧 D/E 盘操作命令。

## 四、集群内业务数据

### 4.1 静态卷继续保留，节点绑定必须更新

现有组件配置和静态模板继续作为共享部署代码的输入，不为了换集群顺便升级数据库版本。

实际静态资源为 PostgreSQL、Redis（含 NodeBull）、MongoDB、Neo4j、对象存储和 Casdoor。Jenkins、RabbitMQ、pgAdmin 的同名文件只有注释，Elasticsearch 的文件只说明动态供应；这四个空文件和无效调用已删除，不能把文件名当成已持久化的证据。Harbor 不属于新集群内的正式组件。

部署前逐组件核对：

1. `nodeAffinity` 使用实际正式节点名，不能仍绑定 `kind-worker`。
2. hostPath 仍为 `/data/kind-local-storage/<组件>`，落在所选节点的 `static` 挂载中。
3. PV/PVC 名称、命名空间、storageClassName、容量、访问模式和 chart 的 existingClaim 一致。
4. 组件 UID/GID、fsGroup 与目录权限相符；按组件准备目录，不能沿用全目录 `chmod -R 777`。
5. 明确回收策略。保留数据的卷使用审核过的 Retain 方案，处理 Released/claimRef 时不能仅凭 PVC 同名就假定安全。

实际模板例子：[PostgreSQL 静态 PV/PVC](sunmoonai/data-platform/postgresql/resources/custom-values/postgresql-kind-pv-pvc.yaml)。模板使用节点占位符，经 [正式静态卷适配器](sunmoonai/kind-infrastructure/formal/README.md#静态卷与组件部署) 渲染。节点选择统一在 `formal/static-storage.json`；实际创建前核目标和六条数据盘挂载，只创建缺失资源，现存卷不自动改绑。代码已接入组件入口，真实部署/权限/读写验收仍未完成。

### 4.2 动态 local-path

KIND 的动态卷目录也要持久挂载，不能只保护静态数据库路径。建群后需核 provisioner 的真实配置、生成 PV 的路径/节点绑定，以及 `standard`、`local-path` 两个类各自的回收策略，不能只检查存在一个 StorageClass 名字。

仓库的 [local-path 类声明](sunmoonai/kind-infrastructure/manifests/storageclass-local-path.yaml) 采用 Retain 和 WaitForFirstConsumer；它存在于仓库不代表已经安装进新 main，也不代表另一个默认类采用相同策略。

### 4.3 重建不是自动恢复

宿主数据目录保留，只解决数据字节可能仍在的问题。重建还需恢复或重新绑定 PV/PVC、正确节点亲和性、命名空间、Secret/证书和组件配置，核目录权限及数据库一致性。动态目录名含旧 PVC 身份时，更不能重新申请一个空卷就当恢复完成。

本次旧业务数据不迁移是所有者选择；这个选择不等于允许随意删除旧节点、卷或 Harbor 镜像。以后如果已有业务数据，重建必须按备份恢复流程操作。

## 五、Harbor 在集群外独立持久化

本地与云端统一使用 [registry-platform](sunmoonai/registry-platform/README.md)。本地在 WSL 宿主运行，数据位于 `/data/harbor`；云上目标是独立仓库主机。所有集群都是使用方，`harbor_enabled=false`，统一地址 `harbor.sunmoonai.com:30443`。

Harbor 的镜像层、数据库、配置、证书、加密密钥及必要任务状态共同组成恢复对象。迁移先保持 Harbor 2.13.2、既定数据库/Redis 版本，使用逻辑导出导入、镜像层复制和全目录摘要比对。升级是独立步骤。

本地 30443 由按域名分流的 TLS 直通代理接管：Harbor 域名转宿主 Harbor，其他域名转集群入口。云端仓库独立主机不需要这一本地共用端口代理。正式入口目前尚未切换。

**停止或重建 KIND 不应触碰 `/data/harbor` 或 Harbor 容器。** 这项结构要求已经进入实现，但重建独立性还要实际验收。关闭 WSL、重启 Docker、宿主磁盘故障仍可能同时影响 KIND 与 Harbor。

验收至少包括：重建前后 Harbor 全目录/镜像 digest、数据库与账号可用性一致；宿主服务不被建群脚本启停或删除；重建后节点信任、DNS、代理绕行、imagePullSecrets 和真实拉取重新通过。不能用一次 HTTP `/v2/` 返回正常代替全部验收。

## 六、云端共用与边界

云上通过 kubeadm 建群，本地通过 KIND 建群；平台和应用继续共用部署逻辑，以明确配置选择存储能力。云端实际数据目录位于对应主机/磁盘，不应像旧文档一样统称为“节点容器内”。

当前没有云服务器，云端新流程未经实机验证。旧 `fast-ssd` 名称和 prod-values 中的副本数是配置输入，不证明已经存在对应 CSI、高可用数据库或可恢复备份。

首次上云需核：数据盘与文件系统、真实 StorageClass/驱动、可用区和节点亲和性、权限与容量、卷回收策略、恢复流程、独立 Harbor 主机和使用方信任。具体核对入口见 [云端升级审计](sunmoonai/infrastructure/docs/infrastructure-upgrade-audit.md)。

## 七、备份与清理

| 层次 | 范围与目的 | 当前边界 |
| --- | --- | --- |
| 同盘备份 | 数据库一致性备份、对象存储、私有配置，以及 Harbor 完整恢复材料；防误删、升级失败 | 与原数据同物理硬盘，不能防整盘损坏；容量和恢复演练要单独核验 |
| 机器外备份 | 所有者指定的数据库、对象存储、`~/private` | 移动硬盘或加密上传对象存储的落点待定；不默认外传完整镜像层 |

机器外备份接口和恢复密钥管理见 [主方案](sunmoonai/kind-infrastructure/docs/storage-and-harbor-placement-decision.md)，Harbor 已做的备份恢复见 [宿主备份](sunmoonai/registry-platform/docs/host-backup.md)。本页不把预留接口写成已经运行的任务。

最终必须清理本次重构临时目录、文件及东京下载中转物料，按 [回收方案](sunmoonai/kind-infrastructure/docs/wsl-space-reclamation-plan.md) 逐项核验并记录实际释放量。正式离线物料、必要备份和未达退出条件的旧节点/卷/历史代码继续保护。禁止全局 system/container/volume prune；不在本文提供直接清空数据目录的日常命令。

## 八、日常从哪里改、从哪里操作

| 事项 | 唯一入口 |
| --- | --- |
| 正式 KIND 参数、网段、端口、等待时间、容量门槛 | [formal/deploy-kind.json](sunmoonai/kind-infrastructure/formal/deploy-kind.json)；[操作说明](sunmoonai/kind-infrastructure/formal/README.md) |
| 平台开关、组件配置、私有凭据引用 | [配置对照](sunmoonai/operations/configuration.md) |
| 存储检查、按需附盘、持久化任务 | [mount](sunmoonai/kind-infrastructure/mount/README.md) |
| Harbor 安装、启停、镜像数据与恢复 | [registry-platform](sunmoonai/registry-platform/README.md) |
| 全部运维命令导航 | [仓库 README](README.md) 与 `./sunmoon help` |
| 临时保留的旧实现及退出条件 | [legacy](legacy/README.md) |

默认计划示例：

```bash
./sunmoon storage ensure
./sunmoon kind prepare
./sunmoon kind prepare render
./sunmoon kind lifecycle start
./sunmoon harbor client login
./sunmoon platform plan --cluster KIND
```

这些默认命令只打印计划/配置，不启动服务、不生成 Secret、不清理数据。实际动作仍须满足对应准入条件；不要绕过统一入口运行旧的重建或清理脚本。
