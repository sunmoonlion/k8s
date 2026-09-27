# kubeadm 初始化、Calico 和节点加入

只有一套部署代码和两种建群方式。本页是 kubeadm 入口的 step04–06；KIND 复用相同版本与 Calico 物料，平台服务版本保持现状。

**云上未经实机验证。** 本轮没有 SSH 到部署节点，没有导入镜像、初始化/加入集群、创建令牌或应用 Calico。已完成代码、静态预演、配置格式及现有归档完整性核验。

## 入口和范围

三个步骤统一进入 `utils/cluster-step.sh` → `materials/cluster_control.py` → 严格 SSH 的公开控制程序发布 → `cluster_node.py`。省略参数或 `--dry-run` 只打印；真实分支必须显式 `--apply`，并满足完整发布门禁和每台节点预先登记的 hostname/machine-id。

```bash
# 在 k8s 仓根目录；以下不发起 SSH。
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step04_kubeadm_init.sh --dry-run
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step05_cni_install.sh --dry-run
CLUSTER=C1 bash sunmoonai/infrastructure/steps/step06_join_nodes.sh --dry-run
```

支持当前配置的单控制面、IPv4、iptables kube-proxy、Calico VXLAN；拒绝多控制面或自定义旧 CNI 模式，不能把现有三节点设计称为控制面高可用。以后多控制面要另补负载均衡、证书分发和加入验证，不静默当作普通 worker。

总配置只更新三个字段：Kubernetes1.36.4、Calico3.32.2、iptables。`STEP03_K8S_VERSION` 空值继续继承 `CLUSTER_VERSION`；`STEP05_CALICO_CHART_VERSION` 暂留旧字段名，但新路径用固定 manifest，不再装旧 operator chart。其他配置字节保持，未改平台版本或凭据。

管理机需要 Python≥3.11、PyYAML（沿用现有 KIND 工具环境）、SSH/rsync；云节点只用标准库和已锁二进制，不在线安装 Python 模块。

## 物料与导入

- 精确解析根锁中的7个控制面归档和共享的3个 Calico 归档，无 glob、模糊 grep 或“取第一个 tar”。
- 核 tar SHA/大小、linux/amd64 manifest、config 与全部 layer SHA；本次10归档共104个内容引用、72个不同 blob 全通过。
- 节点从已核内容生成 root 私有的 OCI 传输副本，固定标签直接指向锁定的架构 manifest。再次核副本，才交给 containerd 的 `k8s.io` namespace。
- 已存在同名不同摘要时停止，不覆盖、不删镜像；导入后检查 ctr 目标摘要、实际 manifest 内容和 CRI 对标签/摘要两种引用的解析。
- 同时建立原 registry 的标签与 `@sha256` 引用。pause 的摘要引用与 containerd 配置一致。所有节点都先导入10个镜像，随后才初始化控制面。
- 此导入分支未实际执行，不能把归档内容检查称为运行时导入成功。首次上云须核对解包、CRI 缓存和实际 Pod 使用的 imageID。

## kubeadm 与网络配置

使用 v1beta4、明确版本、API地址、Pod/Service CIDR、节点IP、CRI socket和镜像策略。核心镜像来源为锁；本机1.36.4 `config validate` 已通过，`config images list` 与7个锁定引用逐项一致。

要求 Pod/Service CIDR 不重叠，节点IP不落在二者内。显式控制面 endpoint 优先；未填时取唯一 master 的 LOCAL_IP:6443。保留额外 `STEP04_APISERVER_CERT_SANS`。配置不含网络探测猜测、预检忽略、自动重置、强杀进程或失败后另跑一条 init。

Calico 从同一份3.32.2锁定 YAML 在管理机渲染为38个 JSON 对象。采用 VXLAN、关闭IPIP/BPF，使用节点显式 InternalIP；不再把 LOCAL_IP 猜成 /24，也不假定云网卡叫 eth0。镜像固定架构摘要、`imagePullPolicy: Never`，kubeadm 节点注册也采用 Never。初始化为四个静态控制面Pod和CoreDNS生成摘要/Never补丁；kube-proxy不支持该patch目录目标，因此在init后、worker加入前通过API固定摘要/Never。其首次启动标签已预先核对本地缓存，补丁和实际Pod行为仍待实机确认。

仅接管带本次 bootstrap 标签的已有 Calico 资源；发现未管理的同名资源就停。使用 server-side apply，同一 field-manager，不强夺冲突字段；等待 daemonset 和 controller deployment rollout。这里只验证组件就绪，跨节点通信、DNS和网络策略仍须实机验收。

依据：[Kubernetes1.36 v1beta4 API](https://v1-36.docs.kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/)、[containerd2.3.4 import 实现](https://github.com/containerd/containerd/blob/v2.3.4/cmd/ctr/commands/images/import.go)、[Calico3.32地址选择](https://docs.tigera.io/calico/latest/networking/ipam/ip-autodetection)。

## 身份、令牌和中断

每阶段核节点安装完成记录、实际二进制/配置 SHA、物料锁和机器身份。预检要求至少4GiB可用空间和已同步时钟，不自行清理。持久记录在 `/var/lib/sunmoon/clusters/cN/`，变更 profile/锁/机器就拒绝沿用。

初始化后记录 kube-system UID、CA公钥摘要、API endpoint；后续每个控制面操作检查 live UID/CA及 readyz。已有未登记或半初始化的状态停止，保留现场，不给出 reset 作为自动恢复动作。若 kubeadm 成功而写完成记录前中断，也须人工核实后恢复记录，不能盲目重复初始化。

每个worker单独签发加入令牌，有效10分钟，避免慢节点耗尽下一节点的令牌时间。凭据只通过捕获的 SSH stdin/stdout 协议在内存流转；节点请求、kubeadm配置和日志为root私有文件，凭据不进命令参数、终端或 Git。JoinConfiguration 固定 endpoint 和 CA 摘要，不允许跳过CA验证。worker按顺序加入，每个都核 machine-id/IP/kubelet版本/Ready，最后核所有节点集合；成功或失败均尝试撤销本轮令牌。撤销失败则流程失败，令牌仍受10分钟到期约束。

初始化自身短时令牌也为10分钟。过期请求/日志保留供检查，不自动清文件；后续日志保留策略另行统一。

用户要求的五年证书续签针对 Harbor，未扩大到 Kubernetes 凭据。此处保留 kubeadm 默认叶证书一年、CA十年，证书续期/到期监控仍需运维接线。

## kubeconfig 与首次上云检查

新云集群管理员配置留在节点 `/etc/kubernetes/admin.conf`，0600；匹配工具 `/usr/local/bin/kubectl`。不复制覆盖任意用户默认配置，不下载到本机。后续统一平台入口须在同一身份/UID门禁下使用它。

首次可用云主机时，除 [新节点前置检查](fresh-node-bootstrap.md) 外，还须：

1. 确认不是仓库主机，核所有节点身份、内网路由、API endpoint/SAN、无网段冲突，以及安全组、VXLAN连通性和MTU；不照抄历史云IP。
2. 先在专用新节点核OCI实际导入的platform/config/layer与CRI解析，确认没有外网拉取。
3. init后记录UID/CA、公私配置权限、控制面组件状态；无需重复init确认幂等。
4. Calico后核master就绪，worker加入后核所有节点和kube-system组件，再验跨节点Pod/DNS/网络策略。
5. 检查日志/终端无凭据输出、令牌撤销和过期行为；对中断场景按记录人工判断，不自动reset。
6. 实机证据齐全后才改“未经实机验证”标记；多控制面、双栈、网络差异不能外推本次结果。

主锁 `closure_complete` 是物料与部署代码的发布门禁，真实验收状态另记 `validation_status`，避免以后首次上云陷入“尚未安装却必须先实机验收”的循环。当前仍false，原因是step07–13及独立Harbor/平台接线未完成；不能跳过这些审查就手工放开完整总控。

本地 inbox 仍在旧 KIND：`~/.kube/kind-config`，kubectl为 `~/packages-to-be-installed/releases/kubectl-1.27.3-existing-kind-linux-amd64/bin/kubectl`。本轮没有切换集群、入口或数据，也未执行最终清理。
