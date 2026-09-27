# 建群后的共用资源与就绪检查

> 只有一套部署代码，加上两种建集群的方式。本地把平台和应用跑通，云上除了建集群那一步，其余走的是同一条路。+
**云上未经实机验证。** 本单元完成 step07、08、10，以及本地命名空间入口。只进行了静态检查、物料摘要核验和只打印演练，没有 SSH、集群 API 调用或实际资源变更。其他平台入口仍在接线，不能据此宣布部署流程已全部统一。

## 一份实现、两个调用入口

`materials/cluster_resources.py` 是命名空间、节点污点和基础就绪检查的实现。它不选集群、不读默认 kubeconfig、不使用 SSH。调用者提供每次 API 操作前都核对 UID 的 kubectl 函数。

| 入口 | 目标证明 | 调用 |
| --- | --- | --- |
| 云端 step07/08/10 | 原建群记录、SSH 主机、machine-id、锁定工具、集群 UID/CA、节点集合/IP/版本 | cluster-step → cluster_control → cluster_node → cluster_resources |
| 本地命名空间 | 显式工具绝对路径及 SHA、私有 kubeconfig、预先记录的 UID、TLS 和客户端/服务端版本 | apply-namespaces-existing-cluster → resources_local → cluster_resources |

云端管理员配置保持 `/etc/kubernetes/admin.conf`、0600，不为非特权 SSH 账号改成可公开读取。SSH 只发布精确白名单的12个公共代码/锁文件；本轮增加 `cluster_resources.py`。资源操作结果/失败信息留在 `/var/lib/sunmoon/clusters/cN/resources-<时间>.json`，0600；不打印原始子进程 stderr。

本地入口继续读取同一基础设施配置，可指定 `INFRA_CONFIG_FILE` 和 Git 外 `INFRA_PRIVATE_CONFIG_FILE`；只导出4个命名空间字段，支持对应 `KIND_` 覆盖，不导出整份配置或凭据。云端仍使用已有统一加载器。

## 只打印的方法

在 k8s 仓根目录运行；这些命令不会连 SSH 或 Kubernetes：

```bash
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step07_create_namespaces.sh --dry-run
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step08_validate.sh --dry-run
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step10_k8s_nodes_management.sh --dry-run
bash sunmoonai/kind-infrastructure/apply-namespaces-existing-cluster.sh --dry-run
```

省略动作也是只打印。云端总控明确传 `--apply`，但整个部署仍被 `closure_complete=false` 阻止；后续 [step09](storage-bootstrap.md) 已完成云端代码接线；[step11使用方](registry-consumer.md)及[step12证书消费](tls-consumer.md)也已接线；剩余 step13、KIND存储/证书适配、独立仓库主机前置步骤和平台接线必须先完成。不得手改门禁提前执行旧存储/证书逻辑。

本地实际使用参数形状如下；目标 UID 必须来自建群记录，不能临时读当前默认上下文并把它当成预期目标：

```bash
# 新正式集群完成身份登记、存储及仓库前置后才执行。占位变量需取真实记录。
bash sunmoonai/kind-infrastructure/apply-namespaces-existing-cluster.sh --apply \
  --kubectl "$LOCKED_KUBECTL_ABSOLUTE_PATH" \
  --kubeconfig "$RECORDED_PRIVATE_KUBECONFIG" \
  --expected-uid "$RECORDED_CLUSTER_UID"
```

旧 `kind-up.sh` 已加显式工具/UID前置参数并调用新接口，缺参数在任何原有主机操作前停止。它仍是历史建群器，**不能用于本次正式建群**：旧创建/存储/重建逻辑尚未统一；新建集群的 UID 不可能在创建前已知，正式建群入口将分开“创建并登记身份”和“调用共用平台入口”两个阶段。不要为绕过检查而伪造 UID。

## 命名空间

当前配置是 dev/prod × 7个平台，共14个命名空间。仅创建不存在的对象，并记录平台、组件、环境、管理者和集群 UID 标签；已有对象必须逐项匹配且未在删除中。全部已有对象检查完才开始创建，拒绝自动接管、覆盖标签或删除重建。创建后等待 Active。

历史 `NAMESPACE_PLATFORM_APPLY_POLICIES=true` 只输出占位日志，没有配额或网络策略清单。本轮把它改为 false，实际未删除任何策略；若重新设 true，程序明确拒绝“假应用”。后续策略必须有可审查的具体清单。本次命名空间创建不代表租户网络隔离或资源配额验收。

本地旧入口顺带创建 StorageClass 的行为已移出。StorageClass/PV/PVC 统一由后续存储步骤处理；不能因为命名空间创建成功就推断存储可用。

## Step08 的通过条件与边界

- 节点集合与配置一致，machine-id、InternalIP、kubelet版本匹配；kubectl和API服务端都为锁定1.36.4。
- 全部节点 Ready，未被 cordon，无 MemoryPressure/DiskPressure/PIDPressure/NetworkUnavailable。
- CoreDNS、Calico controller、Calico node、kube-proxy 都存在，控制器已观察当前 generation，期望/更新/就绪/可用副本一致；两个关键 DaemonSet 覆盖全部声明节点。
- 控制面四个静态组件的 mirror Pod 存在；kube-system 的 Pod 为 Running 且 Ready，已成功结束的 Job Pod 可接受。删除中、Pending、Failed、未Ready不能通过。
- 等待预算来自 STEP08_WAIT_TIMEOUT（1–600秒），单次API请求另有30秒超时；API/权限/身份错误立即失败，不当作“资源不存在”，不自动修复。

这是节点和 kube-system 的基础准入，**不等于**存储、DNS功能、跨节点通信、网络策略、Harbor、入口、应用或业务端到端验收。仍须在实机分别验证这些条件。

## Step10 的变更范围

只添加明确配置、尚不存在的 NoSchedule/PreferNoSchedule 污点。现有同键/效果不同值时报错；不删除原控制面污点，不覆盖任何冲突，不 cordon/drain。NoExecute 会驱逐已有工作负载，不进入普通初始化路径。

先检查全部节点冲突，再使用带 `resourceVersion` 条件的 JSON Patch 保留原 taint 列表并补缺项，发生并发修改就失败、不自动重试。最后重新核身份和污点。当前三个节点的额外污点均为空，因此实际分支只检查，不产生节点 patch。旧 STEP10_KUBECTL_VERSION=1.30.4 已去除，此步骤消费同一1.36.4工具锁。

条件更新依据：[Kubernetes API 的资源版本及条件更新](https://kubernetes.io/docs/reference/using-api/api-concepts/)、[Deployment 状态字段](https://kubernetes.io/docs/reference/kubernetes-api/apps/deployment-v1/)。

## 中断、回退与首次实机核对

创建中断可能留下部分命名空间，下一次相同身份调用会复核归属后仅补缺项；外部创建了无归属的同名对象则停止，不能自动覆盖。污点补丁中断同理保留现场。没有自动删除来“回滚”的路径。代码可回退到本单元父提交，但不能因此恢复旧脚本对实际集群的破坏性操作。

首次实机分别检查：

1. 目标 UID/证书/节点身份与创建记录一致；当前旧 KIND 不能借这个新入口升级或补标。
2. Namespace 数量、标签、Active 状态；不宣称占位策略已生效。
3. Step08 输出与实际 nodes、kube-system workloads/Pod 状态一致；跨节点与DNS另验。
4. 原 taint 与现有资源保持，冲突/权限错误阻止后续步骤；无删除和自动修复。
5. 敏感信息只在目标root私有文件，管理终端和证据无凭据；本地 kubeconfig 无 TLS 跳过。
6. 本地存储/入口/正式Harbor尚未接通时，不能把本单元判为整体迁移成功。

约束对应：C-D1 保留原Harbor唯一主档和旧数据；C-R1 固定基线/主锁/代码证据；C-R2 本单元不改任何平台镜像或发布bundle。物料回收仍放最终迁移验收之后，必须完成且不得清容器/卷。

静态及演练证据：`sunmoonai/scripts/results/luna-post-bootstrap-resources.20260927.json`。
