# Kubernetes 升级：本地验证与离线物料方案

日期：2026-09-26。状态：供所有者讨论的具体方案，尚未创建新集群或切换现有环境。

## 1. 目标与已确认边界

项目仍面向未来云端运行，当前以 WSL 内 KIND 为开发和验证环境。继续沿用 `~/packages-to-be-installed` 物料体系。所有者已同意升级准备方向，并要求先了解现场、讨论方案，确定后实施。

云端没有需要保留的数据，不等于本地开发数据可以删除。当前 `kind` 集群、`~/.kube/kind-config`、`/data/kind-local-storage` 以及现有物料均保留。现有 C1/C2 暂不连接或变更。

本轮建议先交付一个独立的基础设施验证集群，验证版本、离线安装和网络策略；业务迁移、CI/CD、监控和最后的业务端到端测试按后续单元推进。

## 2. 现场核对

取证基线：`k8s` 仓 `luna` 分支，`7896b33941206f55db18a73adf63849cd8136fad`。检查开始时工作树干净，可本地提交。

| 对象 | 已核实事实 | 对方案的影响 |
| --- | --- | --- |
| 现有 KIND | 集群名 `kind`，1 个控制平面、2 个 worker；Kubernetes 1.27.3，containerd 1.7.1 | 新集群使用独立名称和 kubeconfig |
| KIND 配置 | `deploy-kind.conf` 设置 `RECREATE_KIND_CLUSTER_IF_EXISTS=true`；`kind-up.sh` 会删除同名集群 | 新流程拒绝覆盖或删除已有集群 |
| 现有持久卷 | worker 挂载 `/data/kind-local-storage` | 新集群不挂载此目录，不复用旧 PVC 数据 |
| 主机端口 | 旧集群使用 80、30443–30446；候选 16443、18080、18443 当前未监听 | 新 API 使用回环独立端口；初期不发布业务入口 |
| 当前 CNI | 默认 kindnet；项目现状文档明确其不执行 NetworkPolicy | 新集群从创建时使用能执行策略的 CNI |
| 云端基线 | 配置 Kubernetes 1.30.4；已有 deb 同版本，Calico 3.28.2，crictl 1.30.0 | 新物料独立存放，不能混进旧目录让通配符误选 |
| 本机资源快照 | WSL 6.6.114.1；内存 94 GiB，available 72 GiB；物料/Docker 所在盘可用 548 GiB | 当前有余量并行建立小型空集群；创建前再检查 |
| 网络准备 | 统一入口 `sunmoon-network`；完整下载、镜像拉取和离线导入路径已验证 | 准备阶段有限重试，部署阶段只消费完整物料 |

已有脚本需要改造的具体位置：

- `kind-infrastructure/kind-up.sh`：读取共享集群名、可能删除同名集群，创建与平台初始化耦合。
- `deploy-kind/build-kind-node-image/build-kind-node-image.sh`：批量复制全部 tar，`ctr import ... || true` 忽略错误，随后改写共享 `kind-cluster.yaml`。
- `infrastructure/steps/step02_runtime.sh`：通配符选择 nerdctl 包，crictl 未识别版本默认回到 1.30。
- `infrastructure/steps/step03_k8s_binaries.sh`：离线包按 `kube*.deb` 处理；包含依赖修复的联网路径，不能仅凭 offline 标签断言完全离线。
- `infrastructure/steps/step05_cni_install.sh`：未覆盖新版本时默认 Calico 3.28.2，兼容性判断也主要覆盖 1.28–1.30。
- `infrastructure/utils/package-preparation/package-sync.sh`：部分备用传输失败被忽略，存在清空目标目录再复制的路径。恢复云端部署前须单独修正。

这轮只作代码审阅，没有执行上述部署、重建或远程同步入口。

## 3. 建议采用的版本组合

| 部件 | 建议锁定 | 依据 |
| --- | --- | --- |
| KIND CLI | 0.33.0 | 官方发布包含对应节点镜像；本机已缓存并验证此 CLI 二进制 |
| Kubernetes | 1.36.4 | 当前受维护分支中的补丁版本，与下述 CNI 的测试矩阵重合 |
| 节点镜像 | `kindest/node:v1.36.4@sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed` | KIND 0.33.0 官方发布列出的确切镜像 |
| kubectl | 1.36.4，批次内独立工具路径 | 与新服务端保持一致；不覆盖旧环境调用入口 |
| Calico | 3.32.2，固定安装清单和全部镜像摘要 | Calico 3.32 官方测试范围包括 Kubernetes 1.36；补丁版本仍须本机实测 |
| 数据面 | 首轮采用 iptables + VXLAN，保留 kube-proxy | 控制本轮变量，先验证网络隔离和 WSL 内核条件 |

此组合是基于官方兼容范围的工程建议，尚不是本项目的实测结论。KIND 0.33.0 默认镜像是 Kubernetes 1.37.0，因此创建入口必须显式传入锁定镜像，不依赖默认值。Calico 当前公布的测试范围到 1.36，首轮采用该交集。

Kubernetes 跨多个小版本的原地升级不能跳版本；本方案是并行新建再迁移。单机 KIND 的多个节点共用同一台主机，不能据此宣称获得云端故障域高可用。

参考：

- [KIND 0.33.0 发布和节点摘要](https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0)。
- [Kubernetes 维护版本](https://kubernetes.io/releases/)和[版本偏差与升级规则](https://kubernetes.io/releases/version-skew-policy/)。
- [Calico 3.32 系统和 Kubernetes 要求](https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements)、[3.32.2 发布](https://github.com/projectcalico/calico/releases/tag/v3.32.2)和[KIND 安装方式](https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind)。

## 4. 验证集群的隔离方式

| 项目 | 建议值与约束 |
| --- | --- |
| 名称 | `sunmoon-kind-136`；已存在则失败并报告，不能自动删建 |
| 规模 | 1 控制平面 + 2 worker，用于跨节点网络和调度验证 |
| kubeconfig | `~/.kube/sunmoon-kind-136.config`；每条命令明确指定，不改变默认 context |
| API | `127.0.0.1:16443`；创建前检查占用 |
| Pod / Service CIDR | 候选 `10.245.0.0/16` / `10.97.0.0/16`；先与本机、Docker、旧集群和可见 VPN 路由核对，再锁定 |
| CNI | `disableDefaultCNI: true`；安装 Calico 后才要求全部节点 Ready |
| 入口端口 | 基础验证阶段不映射业务 NodePort；将来需要时再使用独立入口配置 |
| 存储 | 初期只使用新节点自身的临时存储；不得挂载旧数据目录或给现有 local-path 配置改路径 |
| Registry | 优先导入固定摘要离线镜像；如使用现有 Harbor，按任务单独校验信任链与授权 |
| 代理 | 仅物料准备阶段通过统一入口联网；节点和测试 Pod 不自动继承通用 Windows 代理 |
| 资源 | 创建前保留至少 16 GiB available 内存与 30 GiB 可用磁盘作为首轮准入余量；这是操作阈值，不是运行时配额 |

独立 Kubernetes 集群仍共享 Docker 守护进程、主机内核和可能的 Docker `kind` 网络。跨集群地址不得混淆；新集群建立时不重启宿主 Docker、不重写宿主防火墙或旧 CNI。创建脚本必须检查 kubeconfig 指向的 API 和集群名称，防止命令作用到旧集群。

## 5. 离线物料如何升级

候选批次目录：

```text
~/packages-to-be-installed/releases/kind-1.36.4-calico-3.32.2-linux-amd64/
  manifest.lock.json
  checksums.sha256
  tars/       # 对应工具或发布归档
  images/     # 节点、Calico、验证用镜像归档
  charts/     # 使用的安装发布物；无用项不下载
  debs/       # 本轮 KIND 不需要 kubeadm/kubelet 的 deb
  bin/        # 校验后安装到批次内的 kind/kubectl，不替换全局工具
```

这不是把原物料目录整体复制一份。先确定本轮实际依赖闭包，再逐项准备：

1. KIND CLI、kubectl、官方节点镜像、Calico 安装物和对应镜像、网络与存储验证所需小镜像。
2. 安装清单先固定版本并记录文件 SHA256，再从清单提取精确镜像；镜像解析到 registry digest 后锁定。发布方提供校验文件的资产须先验证；自行记录的 SHA256 只能证明字节一致，不能冒充发布方签名。
3. manifest 记录来源、版本、平台、相对路径、文件 SHA256、镜像索引及平台摘要；凭据只引用私有文件，不写入物料清单。
4. 下载写入临时文件，校验后发布；一次失败不改变锁定版本或自动切换来源。默认串行，最多 3 次尝试，日志保留。
5. 已下载物料逐项校验后可复用；新批次验证通过前，旧批次和现有部署入口保持可用。
6. `offline` 模式先完成全量预检，缺文件、摘要不匹配或架构不符立即失败，不能静默回退公网。

新 KIND 使用官方节点镜像，再单独导入本轮镜像；首轮不把所有旧平台镜像烘焙进一个自定义节点镜像。这样可以单独追踪节点与业务依赖，减少家庭网络反复下载的代价。

目前只缓存校验了 KIND CLI；新节点镜像、Calico 物料及它们的完整锁文件尚未准备，不把候选版本清单称作可离线部署的完整包。

## 6. 建议执行单元与完成条件

### A. 物料与入口

在 `kind-infrastructure` 下增加独立入口，提供显式 profile、物料根目录和 `plan`。不调用旧自动重建流程。实现精确物料校验、有界下载、已有集群保护、目标 kubeconfig 检查。共用物料格式留给未来 `infrastructure` 复用。

完成条件：版本和摘要锁定；完整依赖闭包可校验；缺失、错误摘要、目标冲突会在修改前失败；可审阅计划明确列出所用物料、目标集群、端口、路径与执行动作。

### B. 并行新建与基础验收

先创建指定镜像的三个节点并导入 Calico，安装网络插件，再进行基础验收。关闭默认 CNI 的集群在安装 CNI 前未 Ready 属于预期阶段，不得误判创建失败并反复删除重建。

完成条件：

- 三节点 Ready，实际组件版本与锁文件一致。
- DNS、ClusterIP、跨节点 Pod 通信通过。
- 在新集群专用测试命名空间中验证默认拒绝与精确放行；使用没有代理变量的测试 Pod，实际被拒绝与实际成功都须有证据。
- 测试 PVC 可写，替换测试 Pod 后数据仍在；明确 local-path 的单机/单节点边界。
- 离线部署动作没有请求未声明公网来源，缺物料会停止。
- kubeconfig、旧集群节点、旧入口和旧持久化路径保持符合基线。

这些是基础设施验收，不替代最后的业务端到端测试。

### C. 平台兼容与业务迁移（另一个单元）

逐项核对 Helm chart、CRD、准入 webhook、Pod 安全约束、存储、Harbor/Traefik 和业务 manifests 对新 Kubernetes 的兼容性。按现有发布门禁部署验证，先确定本地数据如何保留或重新初始化，再讨论切换。

集群升起来不能当作项目升级完成。旧环境退役、入口切换、正式数据恢复或删除都需要明确的后续方案。

### D. 回到企业级能力建设

在可验证的基础设施上推进 CI/CD → 监控与高可用设计 → 业务端到端测试。届时重新评估旧任务中的具体工具是否仍维护、是否适合当前架构，不直接照抄旧 Jenkins/Kaniko 选型。

## 7. 失败处理与回退

- 准备阶段失败：保留已通过校验的文件和失败日志，继续使用现有集群。
- 创建或 CNI 安装失败：停止在新集群这一侧，保存事件、组件状态和非敏感日志，不自动删除失败现场。
- 网络策略拒绝必要流量：修正明确的策略或来源地址并重验，不以全放通把验收变绿。
- 新集群需要清理：按精确名称列出新增容器、卷、镜像与路径，得到对应授权后处理；不执行全局 prune。
- 旧环境尚未切换时，回退就是继续使用旧 kubeconfig 和入口；后续业务切换必须另有数据一致性方案。

## 8. 规则对照与本次待确认内容

| 规则 | 本方案处理 |
| --- | --- |
| C-R1 / C-R2 | 版本、来源、镜像 digest 与物料文件 SHA256 一起锁定；不改变正式 bundle 规则 |
| C-T7 / C-T8 | 只创建本地基础验证集群；保持未来薄边缘、深处出站的拓扑要求 |
| C-D1 / C-D3 | 不迁移现有业务库，不跨 App 复用凭据；新测试数据独立 |
| C-A7 | CNI 与网络策略要实际验证，未通过不宣称隔离已成立 |

需要所有者定下的具体新增选择：**采用 Kubernetes 1.36.4 + KIND 0.33.0 + Calico 3.32.2，先完成 A、B 两个单元，建立 `sunmoon-kind-136` 独立验证集群。**

提出这个确认是遵循所有者“了解情况后讨论方案，确定后实施”的要求；此前同意的网络整理和升级准备无需再次批准。当前文件是讨论稿，本轮只完成现场核对与方案整理。
