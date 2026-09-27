# 存储适配、原版本物料和数据保护

> 只有一套部署代码，加上两种建集群的方式。本地把平台和应用跑通，云上除了建集群那一步，其余走的是同一条路。

**云上未经实机验证。** 本单元重写云端 step09，新增可共用的存储对象渲染/创建逻辑、云节点数据盘预检和精确离线镜像消费。没有执行 SSH、挂载、建目录、镜像导入或 Kubernetes API。KIND 的磁盘/节点挂载适配及平台静态卷绑定尚待接入，不能宣布整个存储部署已经完成。

## 发现与修改

旧 step09 共1470行：provisioner未Ready时自动删namespace/RBAC再装，StorageClass每次删后重建，擅自取消其他默认SC，模糊查镜像并在Docker/nerdctl间回退，离线CSI导入失败仍继续，线上取master分支清单。默认检查会创建、删除同名PVC/Pod；部分CSI实现只有占位日志，检查失败可能继续报成功。

新入口仍是 `steps/step09_storage.sh`，调用共用 `cluster-step.sh` → `cluster_control.py`。默认只打印；总控明确传 `--apply`，但物料/流程总门禁仍为false，未放行整个部署。

```bash
# k8s 仓根目录，不 SSH、不调用 API。
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step09_storage.sh --dry-run
CLUSTER=C2 bash sunmoonai/infrastructure/steps/step09_storage.sh --dry-run
python3 sunmoonai/infrastructure/materials/bundle.py verify --scope storage
```

真实执行的顺序：

1. 完整锁/所有物料SHA、配置版本和预登记SSH机器身份通过；每个存储节点有预登记数据文件系统UUID。
2. 控制面核建群记录UID/CA、节点集合/machine-id/IP/版本；检查所有存储对象归属/内容及默认SC冲突。
3. 所有节点做只读存储预检。全部通过后，才逐节点准备目录、记归属和导入2个镜像。
4. 再次核API对象，只创建缺项，等待provisioner就绪，复核对象。无资源覆盖、删除、自动修复或在线下载。

节点/物料检查中断就停止；实际分支未经验证。远程公开程序白名单新增两个存储模块和一份镜像锁，总数15，源码/锁仍按内容摘要发布到root只读目录。

## 两种路径不能混淆

| 用途 | 当前/规划路径 | 本单元行为 |
| --- | --- | --- |
| 云动态卷 | 已有配置 `/data/local-storage`，新增数据挂载点 `/data` | 使用指定新数据盘，提前核UUID；不挂载/格式化 |
| KIND动态卷 | 节点内 `/var/local-path-provisioner`，宿主机各节点独立目录 | 后续KIND适配检查三节点bind和数据盘UUID后使用同一对象渲染器 |
| KIND静态平台卷 | 节点内 `/data/kind-local-storage/<组件>` | 保留原路径；后续按新节点身份生成绑定 |
| 独立Harbor | 宿主机 `/data/harbor` | 完全不由step09操作，不放入新集群PV |

云端新增 `STEP09_LOCAL_STORAGE_MOUNTPOINT` 和 `STEP09_LOCAL_STORAGE_SERVER_n_UUID`；全局初值UUID为空，必须在首次上云盘点后通过私有/集群覆盖配置填实值，不猜测、不采用当前系统盘UUID兜底。支持稀疏节点索引，每台明确是否提供存储。旧自动PVC/Pod检查开关、namespace、在线超时、chart通配目录、节点间补包来源等废弃字段已移除；改用 STEP09_WAIT_TIMEOUT 等待控制器，重复的admin.conf声明只留一处。

云节点要求精确挂载点、ext4/xfs、rw、UUID匹配且不是系统盘的文件系统，拒绝子目录bind冒充整数据盘、嵌套挂载和符号链接。目录及祖先应root拥有且不可被其他用户写；未登记却含数据的目录拒绝接管。脚本不改现有权限、不改fstab、不mount、不mkfs。

归属记录为 `/var/lib/sunmoon/clusters/cN/storage-host.json`，0600，绑定集群UID、节点、路径、挂载点和UUID；在镜像导入前保存，**这是归属记录，不是数据读写验收记录**。同一身份可从导入失败后继续，身份改变须检查，不能删记录绕过。

本机沿用所有者已创建的100GiB动态VHDX和两个bind。**禁止在宿主机旧 `/data/kind-local-storage` 上挂任何东西**。本单元不修改挂载；云端的 `/data` 检查不能拿来代替WSL的bind/服务可见性检查。数据盘和WSL系统盘同一物理C盘，不防硬件故障。

## 原版本镜像复用，不重新下载

以下两个现有包已核SHA、完整manifest/config/layer图及linux/amd64，合计233,228,288字节，继续放原位置，没有复制一份到新批次：

| 组件 | 版本 | 物料根目录相对路径 |
| --- | --- | --- |
| local-path-provisioner | v0.0.32 | images/rancher_local-path-provisioner_v0.0.32.tar |
| helper os-shell | 12-debian-12-r51 | images/bitnami_os-shell_12-debian-12-r51.tar |

身份真源 `materials/storage-images.lock.json`，其SHA被主锁引用；`bundle.py`新增storage范围，精确同步自动包含这两个文件。总清单现在128文件、1,057,716,848字节。最终清理不得把它们当作旧Kubernetes物料移除。

这些旧Docker-save包记录的是**未压缩层的本地OCI manifest摘要**，不能冒充公共仓库原manifest摘要。本次为其定义 `docker.io/sunmoon-offline/<组件>@sha256:...` 离线别名，导入、引用、CRI核验都用同一内容摘要，`imagePullPolicy: Never`。别名不需要也不能从Docker Hub拉取。记录同时保留原tag、config摘要和tar摘要，版本不变；未宣称独立验证了公共仓库发布签名。

`image_import.import_items`复用已有安全导入器：预检全部引用冲突，生成root私有精确OCI副本，再导入containerd的k8s.io namespace并核manifest及CRI；不覆写同名不同摘要，不跨Docker兜底，不删缓存。**实际导入未执行。**

## 共用存储对象与保留策略

`storage_resources.py`生成9个对象，使用独立namespace `sunmoon-local-storage` 和 provisioner名 `sunmoonai.com/local-path`，避免接管KIND内置local-path对象。local-path本体仍为0.0.32，配置差异通过参数表达；本地与云端不复制两份对象模板。

为每个节点明确nodePathMap；禁用节点及未列出的节点路径为空，不能悄悄写到默认目录。provisioner只调度到声明可存储的节点。helper固定现有os-shell、root和Never；创建目录沿用现有0777语义，应用自身文件权限/身份仍须由对应平台控制，不把目录模式当租户隔离措施。

StorageClass固定Retain和WaitForFirstConsumer。teardown明确返回失败、保留目录：即使外部把回收策略改为Delete，也不能通过这份配置自动删卷数据。卷退役必须另走明确批准的清单。PVC声明容量不等于local-path文件系统配额；总磁盘容量、监控、备份及应用用量仍须管理。

已有资源必须带匹配的集群UID/配置SHA，声明字段逐项一致且不在删除中；发现漂移先停，不采用force/overwrite。目标SC默认语义冲突，或另有默认SC而本次要求默认，也停止，不自动取消旧默认。KIND正式适配须明确默认SC策略，不能直接套云端默认值。

对象创建后的部署就绪只证明controller运行和对象存在，返回 `data_io_verified=false`。不在普通部署里自动创建/删除测试PVC或Pod；真实写入、重启保持、节点重建保持、静态卷和备份恢复须在后续获授权的验收阶段完成。

实现参照固定版本 [local-path v0.0.32](https://github.com/rancher/local-path-provisioner/tree/v0.0.32) 的公开API、参数和RBAC范围。未因升级Kubernetes提前升级存储服务，也未声称其1.36兼容性已实机验收。

## 静态卷盘点与尚未完成项

只读解析 `custom-values/*kind-pv*.yaml`，找到8个包含PV的模板、12个PV：PostgreSQL、Redis、redis-nodebull、MongoDB、Neo4j、对象存储、Casdoor，以及历史Harbor的5个卷。记录路径、节点affinity、回收策略和模板SHA，随本单元证据保存。

这些模板仍有旧 `kind-worker` 等固定节点绑定；新main必须根据实际节点身份生成绑定，保持组件内路径，不能直接原样apply旧绑定。**本单元未修改/部署这些模板**。Elasticsearch现存说明采用动态local-path；RabbitMQ说明已禁用持久化——这是已有配置事实，不是本单元改动。

当前云CSI开关false保持。若启用任何云提供商，明确报缺少选定提供商的精确物料/配置及验证，不再把腾讯占位日志或浮动chart当成功。首次选择提供商后再锁CSI/chart/副车镜像；不能给无云机器的环境虚构安装通过。

首次实机核对还必须覆盖：数据盘UUID/重启挂载、实际CRI离线解析、controller/helper启动、动态卷写入保持与Retain、所有静态卷的新节点绑定、KIND三节点挂载及重建不影响宿主Harbor。云端与本地验收分开记录。

总体门禁继续关闭，后续是KIND存储适配、step11/12/13、独立仓库/平台接线。本次没有释放空间；迁移验收后的批准清理仍是必做项，旧容器/卷与回退数据继续保护。

证据：`sunmoonai/scripts/results/luna-storage-bootstrap.20260927.json`。C-D1：不接管/删除现有权威数据；C-R1：源代码、锁及静态模板SHA共同记录；C-R2：新动态存储镜像使用精确本地OCI摘要，无浮动引用。
