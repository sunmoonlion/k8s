# infrastructure 全目录升级审查与实施清单

> 只有一套部署代码，加上两种建集群的方式。本地把平台和应用跑通，云上除了建集群那一步，其余走的是同一条路。
>
> **云上升级路径未经实机验证。** 本文的“已读”“静态通过”“已修改”均不代表云上部署通过。

## 后续实施更新（2026-09-27）

[固定物料与节点入口](locked-node-materials.md) 已落实第二批代码：共用配置加载器、移除重复节点配置、公共 SSH 严格身份认证、精确清单同步、五个 systemd/CRI 配置物料和独立新节点安装程序。23 文件已本地校验；实际安装未执行、OS 闭包及 step02/03 调用接线仍未完成。总控变更入口现由版本/物料闭包门禁阻止，避免尚未改完时跑入旧逻辑。

下面第 3–4 节保留首次审查与第一批修正的快照；涉及已整改的配置/common 项，以本节链接中的后续记录为准，其余待改项继续有效。

## 1. 本次审查的范围与证据

2026-09-27，按所有者要求，逐文件阅读 `infrastructure/` 全部 38 个普通文件、11,605 行，包括总控、菜单、配置、公共函数、step00–13、同步、清理、独立运行时工具、物料程序及文档。不是只搜索版本号。阅读时对已有凭据赋值脱敏，未执行部署、重置、清理、SSH 或云端安装命令。

审查基线为本地 luna 提交 `d661840e0c3a49bf1c5e8557236eb3380b0dadb8`。每个文件的 SHA256、行数及静态检查位置见 [完整基线证据](../../scripts/results/luna-infrastructure-audit-baseline.20260927.json)。该证据固定的是**修改前**字节。

基线 23 个 `.sh` 全部 `bash -n` 通过；ShellCheck 0.9.0 共 166 条提示（94 warning、67 info、5 style），只有 3 个脚本零提示。语法检查无法发现大部分下述流程、恢复、版本及数据保护问题。

已追踪目录外的参数解析、集群配置映射，以及 CA、入口、平台调用接口；**不声明已经全量审查所有目录外脚本**。它们在后续接线单元继续审查。

### 逐文件覆盖

下表“项”对应第 3 节。资料性质文件也逐字阅读；JSON 清单核对字段与调用者，下载结果另有物料证据。

| 文件（相对 infrastructure） | 审查项 |
| --- | --- |
| `deploy-infrastructure-all/deploy-infrastructure-all.sh` | A、B、M |
| `deploy-infrastructure-all/deploy-infrastructure-all-menu.sh` | A、B |
| `deploy-infrastructure-all/deploy-infrastructure-all.conf` | A、B、C、M |
| `utils/common.sh` | B、C |
| `fix_permissions.sh` | B |
| `steps/step00_reset.sh` | D |
| `steps/step01_os_baseline.sh` | E |
| `steps/step02_runtime.sh` | F |
| `steps/step03_k8s_binaries.sh` | G |
| `steps/step04_kubeadm_init.sh` | H |
| `steps/step05_cni_install.sh` | I |
| `steps/step06_join_nodes.sh` | J |
| `steps/step07_create_namespaces.sh` | K |
| `steps/step08_validate.sh` | K |
| `steps/step09_storage.sh` | L |
| `steps/step10_k8s_nodes_management.sh` | K |
| `steps/step11_load-initial-images.sh` | M |
| `steps/step12_ca_generation.sh` | M |
| `steps/step13_ingress_and_harbor.sh` | A、M |
| `utils/package-preparation/package-sync.sh` | C、N |
| `utils/package-preparation/package-sync.conf` | B、N |
| `utils/package-preparation/README.md` | N、P |
| `utils/image-cleanup/image-cleanup.sh` | O |
| `utils/image-cleanup/image-cleanup.conf` | O |
| `utils/image-cleanup/periodic-cleanup.sh` | O |
| `utils/image-cleanup/periodic-cleanup.conf` | O |
| `utils/image-cleanup/cron/install-cron.sh` | O |
| `utils/image-cleanup/cron/k8s-image-cleanup.cron.example` | O、P |
| `utils/image-cleanup/README.md` | O、P |
| `utils/setup-runtime-and-disable-socket.sh` | F、O |
| `docs/cloud-provider-switch.md` | L、P |
| `docs/volcengine-vfs-setup.md` | L、P |
| `materials/cluster-artifacts.lock.json` | C |
| `materials/kubeadm-images.lock.json` | C |
| `materials/prepare_public.py` | C |
| `materials/prepare_images.py` | C |
| `materials/inventory.py` | C、O |
| `materials/README.md` | C、P |

## 2. 调用链与统一目标

基线实际调用链：

```text
菜单 → 自己的配置映射、自己维护的步骤列表（漏 step13）
总控 → 另一份配置映射 → package-sync（第三份节点清单）
     → reset → baseline → runtime → binaries → init → CNI → join
     → namespaces → validate → storage → node-policy → image-load
     → CA → ingress
各 step → common → 又加载配置与映射 → SSH/sudo
step12 → 目录外统一证书脚本
step13 → 目录外 ingress-platform 总控
清理/cron/独立 runtime 工具 → 各自的入口、路径及状态判断
```

最终应收敛为：

1. 固定版本和 SHA 清单 → 准备公开物料 → 东京下载并回传 → 本地校验 → 目标机校验。
2. 独立 `registry-platform` 管理 Harbor、原数据、原密钥及证书；参数选择本机或 SSH 主机。云上仓库主机与集群节点分开，不让集群 reset/运行时安装触及仓库主机。
3. 建群适配器：KIND 或 kubeadm；输出明确的 kubeconfig、集群 UID、节点/存储身份和准入结果。
4. 共同的平台入口：仓库信任与地址、命名空间/节点策略/存储资源、入口、平台服务、应用与 CI/CD。云提供商和路径差异由配置表达，不复制整套平台部署。
5. 验收通过后观察、再按批准清单清理；Windows 维护窗口由所有者操作。

**这是一条目标调用链，尚未全部接通。** 当前总控只打印预演输出真实的现有步骤顺序，并明确列出未接通项。

## 3. 发现与必须修改的细节

除第 4 节明确写“已改”的部分，以下均为**待修复/待验证**。定位以基线文件和函数为准；不能把本列表当成已修复清单。

### A. 总控和菜单

- `deploy_all` 把 step00 纳入普通部署，配置却是 `STEP00_ENABLED=true`；无命令默认直接部署。菜单另一条完整部署链不统一遵守开关，且没有 step13。
- 包同步失败只警告然后继续；找不到同步脚本也继续。子步骤有大量错误被吞掉，总控只看退出码仍可能假成功。
- `run_single_step` 用 `declare -f` 接受任意已定义函数，缺少命令白名单。
- CA 位于 Harbor 镜像/DNS 使用之后；独立仓库前置步骤还不存在；集群验证位于存储与入口之前，不能视为最终验收。
- 既有 step13 已取消 Harbor 调用，但 Traefik 子脚本失败或不存在仍返回成功。

### B. 配置、目标身份与公共函数

- 总控、菜单、common、package-sync 重复映射；有的遇到中间缺号就停止，与“不连续节点编号”说明不一致。空字段不覆盖旧值，存在跨配置残留风险；多处 `eval` 把配置值再次当代码解释。
- 两份节点配置含既有凭据字面量。不得贴出、不得复制到新公共文件。后续切换私有配置路径前先核对私有存档，不能以“清理配置”为名丢失唯一凭据；已进入历史的值不会因改文件自动撤销。
- 默认集群可从其他全局文件或 C1 推导；部署必须显式绑定目标，不能把当前默认上下文当作目标证明。
- 公共 SSH 跳过主机身份核对、支持口令出现在命令参数；sudo 失败后可能重跑完整变更命令。应统一主机指纹、非交互认证、超时、一次执行和错误传播。
- 远端 HOME/本机 HOME 混用，`~` 在不同位置展开不一致；`prepare_remote_kubeconfig` 把集群管理员配置设为 0644。需要精确路径、0600 和集群 UID 核验。
- `fix_permissions.sh` 写死 `~/master/k8s`，会作用于另一个工作树。

### C. 物料与版本闭包

- 活动旧配置仍为 K8s 1.30.4、nerdctl-full 2.1.3、Calico chart 3.28.2。不能只把配置数字改成 1.36.4：运行时、二进制格式、kubeadm 配置、镜像清单、网络安装方式都不同。
- 新根目录仍是 `~/packages-to-be-installed`；新版在 `releases/kubeadm-1.36.4-linux-amd64`。7 个工具与 7 个控制面配套镜像已有本机摘要证据；Calico 清单和 3 个镜像复用已验证 KIND 批次。
- 主锁 `closure_complete=false`：OS 依赖闭包、systemd/drop-in、共享 Calico 消费适配未完成；不得宣布备料完毕，不得据此删除旧物料。
- common 将 `tars` 映射为 `tar`；步骤存在“第一个通配匹配”“名字存在即版本正确”“Docker 有镜像即 CRI 有镜像”等错误判断。
- 离线模式多处回退 apt/curl/Helm 在线拉取；缺包应在变更前失败，补料应走准备阶段。
- `prepare_public.py`/`prepare_images.py` 只准备公开物料，`inventory.py` 只盘点，均不等于安装器。镜像的多架构 index、目标平台 manifest、config、tar 各摘要不能混为一谈。

### D. reset 的数据破坏范围

- `cleanup_container_runtime` 不充分服从移除开关，停止/删除 Docker、containerd 与配置；部分开关会删除 `/var/lib/docker`、`/var/lib/containerd`。
- 全局清 iptables/NAT、网桥、etcd/kubelet 等，没有集群/主机归属证明。
- `REMOVE_LOCAL_STORAGE=false` 仍涉及 local-path 与 kubelet 数据路径；启用时还强制清 PV/PVC finalizer。
- 这条历史路径**不能用于本次迁移或回退观察期**；移出普通部署只是第一层修复，直接运行该文件仍有危险操作。没有执行它。

### E. OS 基线

- `step01` 调用未定义的 `get_server_ssh`；原始 rsync/scp 与 common 的端口/认证不一致。
- Ubuntu 包版本和用户路径写死；离线 dpkg 失败后 apt 修复，且多个基线失败被忽略。
- 应核对实际 OS/架构、内核模块、cgroup、时间、交换区及磁盘挂载；不能仅凭命令执行过就放行。

### F. 运行时与独立管理工具

- `step02` 实际只支持 nerdctl-full，其余宣称模式可能空成功；已有二进制即跳过，没有精确版本比对。
- 新基线采用分开的 containerd 2.3.4、runc 1.4.3、nerdctl 2.3.5、crictl 1.36.0，必须重写对应安装分支，不能套用旧 full tar 逻辑。
- containerd 配置每次覆盖，sed 假设旧配置格式；已运行服务只 daemon-reload 不代表新配置生效。CRI、SystemdCgroup、sandbox image、registry hosts 和 endpoint 要成套核对。
- `setup-runtime-and-disable-socket.sh` 从在线仓选版本、覆盖 Docker/containerd 单元及配置、重启服务；卸载会删除 Docker 数据。这不是共享 Docker/KIND/Harbor 主机的安全升级入口，注释中“互不影响”不能采信。

### G. kubeadm/kubelet/kubectl

- `step03` 现有工具即跳过；在线安装不钉版本，离线期待 `.deb`，而新批次已下载二进制。
- `dpkg --force-depends`、离线之后再次 apt 下载会掩盖依赖未闭包。
- worker 没有 admin.conf 不等于未加入集群，不能据此停 kubelet；应检查对应节点/kubelet 的真实身份和状态。
- 新 systemd 服务与 kubeadm drop-in、crictl endpoint、版本校验必须一起实现。

### H. 控制面初始化

- `step04` 生成旧 `kubeadm.k8s.io/v1beta3`，新版本所需 API/字段要依据对应 kubeadm 验证后生成；旧 CoreDNS/etcd/pause 猜测表不能继续兜底。
- 对每个 master 独立 init 不是高可用控制面加入；必须区分首次 init、control-plane join 和 worker join。
- 检查前重启运行时，自动清残留、杀端口进程、清 etcd；API 暂时不可达不能成为重置依据。
- init 失败后自动换一组省略关键参数的命令重试，会丢失网络/证书/CRI 等约束。应保留精确失败状态，显式恢复。
- 离线导入按宽泛目录扫描，不能证明目标版本镜像齐全；忽略 preflight 错误不能代替 OS 依赖准备。

### I. 网络插件

- `step05 --required-artifacts` 在部分 helper 定义前调用它们，本身可能失败。
- 版本表不覆盖新版本；operator/chart 版本与 Calico 版本不能混用；归档按 basename/宽泛 glob 判断会误选其他镜像。
- 离线分支仍可能安装 Helm、更新远端 repo；多个 CNI 名称最后却等待 Calico 组件，部分能力只是名义支持。
- Calico PodCIDR 未可靠地跟 kubeadm 保持一致；节点网络探测按 `/24` 和前 10 个节点推导，不能用于任意云私网。
- 就绪判据只有“至少一个 Ready”不够；需要所有期望节点、DaemonSet 和 DNS/跨节点网络准入。

### J. 节点加入

- `step06` 沿用 pause 3.9 和宽泛镜像导入，多个配置声明（并发/控制面加入等）未兑现。
- join 命令日志含 bootstrap token；应使用受限配置/标准输入，日志不记录凭据。
- 发现旧证书会自动 reset；相同 hostname 不证明同一集群，不能误跳过或误清理。
- 空 join 命令、join 失败和验证占位可能仍成功返回。

### K. 命名空间、节点策略与集群检查

- `step07` 中 `ssh test ... || true` 使判断恒成功；远端 `bash temp; rm temp` 可能以 rm 成功掩盖真实失败。已存在 namespace 不补齐标签；policy/cleanup 有占位实现。
- `step08` 多数查询/等待失败被忽略；只数节点数量，不证明全 Ready、目标版本、运行时一致；验证不是最终验收。
- `step10` 空 taints 跳过，不能撤销此前自己管理的 taint；失败不可靠传播；节点名 fallback 需要真实映射，NoExecute 影响要体现在计划里。
- 这些共同平台能力应被两种建群方式复用，避免继续扩写两套。

### L. 存储（step09 全部 1,470 行已读）

- mkdir 成功不证明挂在数据盘上；必须核对挂载身份、容量、节点归属和静态卷固定路径。
- 云厂商资源声明与实际执行不对应；腾讯分支有占位成功，其他支持项不完整。首次上云前应明确支持的适配器并拒绝未实现项。
- 路径拼接可能把绝对路径前再加 HOME；跨节点 scp 缺少一致端口/身份/摘要校验。
- local-path 已存在就跳过版本核对，失败时自动删除 Deployment/ConfigMap/RBAC/整个 namespace，不是可接受的升级恢复方式。
- 在线路径引用上游 master；离线路径与配置未充分对应。平台存储版本本次保持，必须固定现有清单，只有实际不兼容才逐项论证最小升级。
- StorageClass 删后重建、修改默认类时 kubeconfig 作用域不一致；应比较不可变字段并停止冲突，保护已有 PV。
- 验证使用通用名称删除 Pod/PVC，没有归属标签；只等 Pod 不证明可写及持久。PVC 的 Bound 是 phase，不能使用错误的 condition 判据后仍成功。

### M. 外置 Harbor、信任、入口

- `step11` 默认域名/地址仍可回退旧集群节点；必须读独立仓库主机配置，统一 `harbor.sunmoonai.com:30443`。
- 预置镜像列表仍混入 Harbor 启动组件。仓库自举归 registry-platform；集群只准备自己要用的镜像，平台服务版本保持。
- DNS 失败后继续、先删 hosts 后验证 IP、正则误匹配和丢失同行别名都需修正；必须 TLS 与认证校验，不能仅 getent 成功。
- `verify` 会实际补载和跨节点复制，不是只读核验；必须拆开只读 verify 与显式修复。镜像存在应按摘要判断。
- `step12` 含 force/rotate CA 的管理分支并默认追加其他集群；根 CA 保留和叶证书续期应独立于普通部署，不能顺序运行时意外轮换。
- 统一证书、Docker/containerd 信任、CI/CD secret、推拉、安装启停、备份恢复与总控的目录外接口仍须逐个接线。
- step13 只装入口；本地 30443 SNI 分流仍需维护窗口，云上独立仓库主机不装此代理。

### N. 包同步

- `package-sync.conf` 独立维护节点，可能与实际部署目标不同；需收敛到一份配置。
- `rsync_full` 带 `--delete`；scp 备用路径先 `rm -rf`，失败仍返回成功。同步不应承担清理。
- `get_server_info` 用 eval 展开路径，有本机/远端 HOME 混淆；若干调用未保持目标端口。
- `install-images-on-all-nodes --dry-run` 仍会 SSH 统计/检查远端，未满足“只打印”；只靠第一个已有 tag 就跳过整包，不能证明所有镜像齐全。
- 自动清理配置默认 true（部分未实际接线）；新版改为最终验收后按清单回收。

### O. 清理与运维

- image-cleanup 默认开启，使用 `nerdctl image prune -a -f` 与整类目录删除；无恢复来源证明、回退资产保护，不能用于本次清理。
- 磁盘阈值看执行机根分区，未必是待清节点磁盘；统计成功可能只是被 `|| true` 吞掉错误。
- periodic `--force` 的解析与文档 `execute --force` 不一致，cron 安装无参数就写系统配置，文档路径写死另一检出。
- R3 已取消；旧节点容器/卷和观察期回退资产不得删除。最终只回收批准的构建缓存、完成 Harbor 摘要核验后的 R2、已批准重复文件等；复核再执行并记录实际释放量。
- `inventory.py` 给出候选不等于删除批准；同盘备份和 Harbor 冷备份不能随版本替换删除。

### P. 文档与例子

- 云存储文档引用不存在的 deploy.conf 路径，参数名与脚本不一致；“已实现”并不代表新集群验收。
- 清理文档标“全部测试通过”、默认开启、互不影响，与代码和本次要求不符；旧命令需显著标为历史，不能直接照抄执行。
- 同步文档以安装后立刻清理为推荐，必须改为本次批准的验收/观察/回收顺序。

## 4. 本单元已改与检查边界

已改代码：

- 总控无参数只显示帮助；操作要求显式选择 Cn；普通 deploy 的步骤表移除 step00，即使旧配置开关误开也不自动 reset。配置同时把 `STEP00_ENABLED` 设为 false。
- 菜单只调用同目录总控，复用配置、顺序、开关和错误处理；补上入口选项。保留命令别名，交互菜单的 reset 显示本次禁用。
- 总控配置映射去掉 eval，清理旧节点映射、支持稀疏节点编号；**common 和 package-sync 的旧映射仍待统一**。
- `deploy --dry-run` 只打印现有总控的步骤与开关、配置版本及未完成项；不会运行步骤、SSH、下载或同步。单步 dry-run 只打印目标，不执行该脚本。**直接调用旧步骤/旧工具的 dry-run 不因此自动安全**。
- 包同步脚本缺失或返回失败会停止总控。同步删除逻辑移除；scp 复制失败/无认证返回失败，不再先清空远端目录。
- step13 找不到入口部署脚本或子脚本失败时返回非零；仍需后续独立验收入口可用性。
- 历史镜像清理默认关闭，自动安装后清包默认关闭；本次仍必须在最后完成批准的清理。
- 权限修复只定位当前工作树的 step 文件。

没有把 CLUSTER_VERSION 偷改成 1.36.4 后宣称已升级。旧步骤中的 destructive reset、在线兜底、未闭包依赖及假成功检查仍待下一单元整改，直接旧入口目前不可用作本次升级。配置凭据未在本单元搬动，也未写入新增文档。

本单元机械检查结果见 [修改后检查证据](../../scripts/results/luna-infrastructure-audit-followup.20260927.json)。只执行静态检查及总控只打印预演，不运行实际部署；全目录尚有历史 ShellCheck 提示，不能宣布全目录已经通过。

## 5. 后续实施顺序与完成判据

| 单元 | 具体内容 | 完成判据 |
| --- | --- | --- |
| 1 总控与审查 | 本文覆盖、默认行为、错误传播、只打印入口 | 本单元变更静态通过，预演不调用远端 |
| 2 物料与主机安装 | 单一配置、精确清单同步、OS 闭包、systemd、containerd/工具 | SHA/版本/目标身份均核对；缺料不安装；离线零兜底下载 |
| 3 kubeadm/网络 | 新 API 配置、init/join 分离、精确控制面镜像、Calico 共用清单 | 渲染与目标 kubeadm 校验、干跑不联网；云未实机标识保留 |
| 4 平台共用接线 | Harbor 主机调用、信任、共同平台入口、存储/节点资源 | KIND 与云计划指向同一平台脚本；原平台版本逐项不漂移 |
| 5 本机验收 | 正式 Harbor 生命周期、推拉/CI/CD/备份、正式 KIND | 仓库全目录摘要；集群重建不影响 Harbor 数据；实际入口和认证通过 |
| 6 收尾 | 观察、批准清理、Windows 压缩、手册复盘 | 实际释放量重新盘点；可复制的方法含失败修复和证据 |

回滚本单元仅涉及代码：按本地提交逐项 revert，不执行旧 reset、不回滚任何现场数据。代码回滚不应自动恢复清理开关。

### 首次上云核对清单（未经实机验证）

- [ ] 真实 OS、架构、内核/cgroup、磁盘/挂载、时间、SSH 指纹和专用仓库主机配置核对；仓库主机不在集群重置/运行时目标中。
- [ ] 离线闭包与每个目标文件摘要齐全；本机预演、远端只读预检通过；公网下载禁用后仍可完成。
- [ ] 实际安装后的 runtime/CRI/tools 版本、systemd、sandbox image、cgroup、证书信任与仓库认证通过。
- [ ] init/join 各类节点身份、API SAN、私网地址/CIDR、全节点 Ready、DNS/跨节点流量通过；记录新 UID 与 kubeconfig。
- [ ] 存储挂载身份、固定路径、静态 PV 归属、PVC 写读和 Pod 重建后的数据通过；存储云适配器按真实厂商单独验收。
- [ ] Harbor 在集群外的启停、推拉、恢复与摘要验收；执行集群生命周期不作用仓库数据、证书或服务。
- [ ] 同一平台/应用/CI/CD 路线跑通；回退和机器外备份落点核对；观察后才启用批准的清理。

### 规则对照

| 规则 | 本次落实 |
| --- | --- |
| C-D1 | 保留原 Harbor 权威数据与冷备份；恢复副本不自动切为正式仓库 |
| C-R1/C-R2 | 物料版本、源码基线和摘要成套记录；不把 tag 存在当摘要验收 |
| C-T5 | 交付本地 luna 提交，明确仅代码/静态通过及未验范围 |

## 2026-09-27 后续实施：OS 物料与 step01–03

- 94 个 Ubuntu24.04 依赖包及 9 个签名/索引完成东京准备、本机独立验签；根锁现在126文件824488560字节，SHA通过。
- step01–03 已替换为同一 node-step / node_control 入口，默认只打印；真实调用要求锁完整、版本和主机身份匹配。公开控制代码固定内容摘要、root目录和只读文件，节点再次核验物料。
- OS离线模拟/安装代码已实现，拒绝降级、删包、在线补装、自动dpkg修复；运行时/工具阶段要求匹配OS完成记录。总控精确同步和显式apply接线完成。
- 5个Shell bash-n/ShellCheck、3个Python及远端payload AST、C1/C2三阶段共6组只打印通过；没有云部署。方法 [fresh-node-bootstrap.md](fresh-node-bootstrap.md)，证据 [luna-node-adapters.20260927.json](../../scripts/results/luna-node-adapters.20260927.json)。
- 下文/上文初始审查中的step01–03问题属于实施前基线；这些入口现已替换。其他步骤的未决风险继续有效。云上仍未经实机验证，主锁closure_complete=false；旧1.30.4配置尚未成套切换，不允许绕过门禁。

## 2026-09-27 后续实施：step04–06

三个旧步骤已由固定镜像/kubeadm v1beta4/Calico控制程序替换，详细方法与首次上云边界见 [cluster-bootstrap.md](cluster-bootstrap.md)。总配置集群层已对齐1.36.4/3.32.2/iptables，其他行不变。10镜像归档完整内容验证、配置校验和静态预演通过；没有真实云操作，不能当成运行验收。发布门禁仍因step07–13和独立仓库/平台接线未完成而关闭；实机状态单列not_run。证据 [luna-cluster-adapters.20260927.json](../../scripts/results/luna-cluster-adapters.20260927.json)。
