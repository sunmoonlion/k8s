# Kind 使用指南

本文档介绍在本项目中如何安装、创建、连接和使用 Kind（Kubernetes in Docker）本地集群，以及常见限制与故障排除。关于“从远程集群迁移到 Kind”的策略，请参阅 **《迁移指南.md》**。

---

## 1. 前置要求

### 1.1 Docker

Kind 在 Docker 中运行节点，必须先安装并启动 Docker：

```bash
# 检查 Docker 是否运行
docker info

# 若未安装，请参考：https://docs.docker.com/get-docker/
```

### 1.2 Kind

```bash
# Linux（示例：v0.20.0）
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# macOS（Homebrew）
brew install kind

# 验证
kind version
```

更多安装方式：https://kind.sigs.k8s.io/docs/user/quick-start/#installation

### 1.3 kubectl

已随本项目使用 Kubernetes 的机器通常已安装；若未安装请参考：https://kubernetes.io/docs/tasks/tools/

---

## 2. 与本项目配置集成

### 2.1 k8s-admin.conf 中的 Kind 配置

在 `k8s/utils/k8s-admin.conf` 中：

- **集群模式**：`cluster_mode=kind` 表示使用 Kind，与 `remote`（远程 SSH 隧道）区分。
- **默认集群**：使用 Kind 时设置 `default_cluster=KIND`。
- **[KIND] 段**：指定 Kind 集群名称和 kubeconfig 路径。

示例：

```ini
[GLOBAL]
cluster_mode=kind
default_cluster=KIND

[KIND]
cluster_name=kind
kubeconfig=~/.kube/kind-config
```

### 2.2 创建 Kind 集群

**方式一：使用项目脚本（推荐）**

```bash
cd k8s/sunmoonai/kind-infrastructure
./kind-up.sh
```
（会创建集群并做命名空间、NFS 初始化；集群已存在则跳过创建。）

**方式二：手动创建单节点集群**

```bash
kind create cluster --name kind
```

**方式三：使用配置文件（多节点）**

创建 `kind-config.yaml`，例如 1 个 control-plane + 2 个 worker：

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

然后执行：

```bash
kind create cluster --name kind --config kind-config.yaml
```

如需端口映射、挂载、kubeadm 补丁等，可在 `nodes` 下为对应节点配置 `extraPortMappings`、`extraMounts`、`kubeadmConfigPatches`，详见 Kind 官方文档。

### 2.3 验证集群

```bash
# 查看集群与节点（需已通过连接管理器或 KUBECONFIG 指向 Kind）
kind get clusters
kubectl cluster-info
kubectl get nodes
```

---

## 3. 连接 Kind 集群

### 3.0 多集群时：由配置指向当前集群

本项目支持**多个集群**（Kind、C1、C2 等）。**当前操作哪个集群由配置决定**，无需每次手动 `export KUBECONFIG`：

- **配置来源**：`k8s/utils/k8s-admin.conf` 中的 `cluster_mode`、`default_cluster` 以及各段（如 `[KIND]`、`[C1_BASTION]`）的 kubeconfig 路径。
- **谁按配置建连**：
  - **部署脚本**（如 deploy-postgresql.sh、deploy-sunmoonai-all）：会 source 统一部署模板，在执行 kubectl/Helm 前调用 `setup_kubectl_environment()`，该函数会读 k8s-admin.conf，若为 Kind 则设置 KUBECONFIG 并写状态；若为远程则建隧道并写 config。**直接运行部署脚本即可，脚本会按配置连到当前集群。**
  - **连接管理器**：单独运行 `k8s-connection-manager.sh` 时，同样读 k8s-admin.conf，按当前模式（kind/远程）建连并设置 KUBECONFIG，适合在某一终端里“先连上再手敲 kubectl”的场景。
- **切换集群**：改 k8s-admin.conf 的 `cluster_mode` 与 `default_cluster`（如 `kind`/`KIND` 或 `remote`/`C1`），再跑部署脚本或连接管理器，即切换到对应集群。

因此：**用 Kind 时只需在 k8s-admin.conf 里设好 `cluster_mode=kind`、`default_cluster=KIND` 和 `[KIND]` 段，部署时无需手动 export；只有在当前终端想临时手敲 kubectl 且未跑连接管理器时，才需手动 `export KUBECONFIG=~/.kube/kind-config`。**

### 3.1 使用连接管理器（可选）

若希望在某一终端里“先连上集群再手敲 kubectl”，可运行连接管理器：

确保 `k8s-admin.conf` 中 `cluster_mode=kind`、`default_cluster=KIND`，然后：

```bash
cd k8s/utils
./k8s-connection-manager.sh
```

脚本会按当前模式切换到 Kind 的 kubeconfig，该终端后续 `kubectl` 即针对 Kind 集群。

### 3.2 直接指定 kubeconfig（可选）

仅在**当前终端临时使用 kubectl**、且未通过连接管理器或部署脚本建连时，可手动指定 Kind 的 kubeconfig：

```bash
export KUBECONFIG=~/.kube/kind-config
kubectl get nodes
```

### 3.3 获取 kubeconfig 到文件

若需导出当前 Kind 集群的 kubeconfig：

```bash
kind get kubeconfig --name kind > ~/.kube/kind-config
```

---

## 4. 镜像使用

Kind 节点使用本机 Docker 的镜像；若镜像在本地 Docker 中不存在，Pod 会拉取失败。两种常用方式：

### 4.1 从公网拉取后加载到 Kind

```bash
docker pull nginx:latest
kind load docker-image nginx:latest --name kind
```

### 4.2 使用私有仓库（如 Harbor）

- 在宿主机配置 Docker 登录与 `/etc/hosts`（如 `harbor.example.com`），然后 `docker pull` 再 `kind load docker-image`。
- 或在集群内配置 imagePullSecrets，并确保 Kind 节点能访问该仓库（网络/域名解析）。

批量加载示例（按需替换镜像名）：

```bash
for img in image1:tag1 image2:tag2; do
  docker pull "$img" && kind load docker-image "$img" --name kind
done
```

---

## 5. Kind 上 local-path 的用法

### 5.1 什么是 local-path

- **local-path** 指 Rancher 的 [local-path-provisioner](https://github.com/rancher/local-path-provisioner)：用节点本地目录做**动态 PV 供给**。
- 在 **Kind** 里常用：没有 NFS/云盘时，用节点（容器）里的目录当“磁盘”，满足 PVC 需求。
- 特点：实现简单、无需额外存储服务、适合单节点/开发/CI；**数据在节点本地**，节点没了数据也没了，不适合生产多节点高可用。

### 5.2 在本项目中如何安装（Kind 集群，默认 NFS）

1. **WSL 上**（一次性）：执行 `k8s/sunmoonai/kind-infrastructure/wsl-setup-nfs-server.sh`，安装并导出 NFS（`/data/kind-nfs`）。
2. **每次要用 Kind 时**（含首次）：执行 **`./k8s/sunmoonai/kind-infrastructure/kind-up.sh`**。该脚本会创建集群（已存在则跳过）、设置 KUBECONFIG、执行命名空间 + NFS 初始化，完成后即可部署应用。

详见下文 **5.7 现成集群平台初始化（设计说明）**。

### 5.3 应用如何使用（Helm / PVC）

本项目中 **Kind 与远程**均使用 **nfs-2**，由各组件 values（如 dev-values）中的 `storageClassName: nfs-2` 指定，部署脚本无需对 Kind 做额外覆盖。

### 5.4 直接写 PVC 的示例

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: my-namespace
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-2
  resources:
    requests:
      storage: 1Gi
```

### 5.5 小结

| 项目       | 说明 |
|------------|------|
| **安装**   | WSL 上运行 `wsl-setup-nfs-server.sh`；Kind 内运行 `apply-nfs-existing-cluster.sh`，创建 StorageClass **nfs-2**。 |
| **StorageClass 名** | **nfs-2**（与远程 dev 一致）。 |
| **Helm 组件** | 由 values（如 dev-values）指定 `storageClassName: nfs-2`，Kind 与远程一致。 |
| **注意**   | 数据在 WSL 文件系统，换节点可见；WSL 重启后 NFS 服务需再起，若 WSL IP 变化需重设 `KIND_NFS_SERVER_HOST` 并重跑 apply-nfs。 |

### 5.6 NFS 可选环境变量与排错

**可选环境变量**：`KIND_NFS_SERVER_HOST`（默认 172.17.0.1）、`KIND_NFS_PATH`（默认 `/data/kind-nfs`）、`KIND_NFS_STORAGE_CLASS_NAME`（默认 `nfs-2`）。若 Provisioner Pod 挂载失败（如 access denied），可在 WSL 的 `/etc/exports` 中为导出加上 **insecure**，并执行 `exportfs -ra`、重启 `nfs-kernel-server`；若连接超时，可把 `KIND_NFS_SERVER_HOST` 设为 WSL 的 IP（如 `hostname -I` 或默认网关 `ip route show default | awk '{print $3}'`）后重跑 `apply-nfs-existing-cluster.sh`。

### 5.7 现成集群平台初始化（设计说明）

在 **Kind 或任意已有集群**上，用最少脚本复现「平台层」核心能力，并与远程部署（deploy-infrastructure-all）在名单与约定上保持一致。不修改 deploy-infrastructure-all 主流程，仅通过「对现成集群」的独立脚本完成。

**目标与范围**

- **目标**：为 Kind（或当前 KUBECONFIG 指向的集群）创建与远程**相同**的命名空间集合，以及可用的 NFS 存储（StorageClass **nfs-2**），使同一套应用/平台部署命令在 Kind 与远程上都能找到相同 namespace 和 StorageClass。
- **范围**：命名空间 + NFS 存储。脚本的输入仅为「当前 KUBECONFIG」；执行前由用户或连接管理器已设好 KUBECONFIG。

**与远程一致的含义**

| 维度       | 一致 | 不一致（刻意简化） |
|------------|------|--------------------|
| **配置来源** | 与远程**同源**：读 `deploy-infrastructure-all/deploy-infrastructure-all.conf` 中 Step07、Step09 相关变量。 | 不读 SERVER_*、不依赖 SSH/节点列表。 |
| **命名空间** | 名单（environments × platforms）、命名规则（`platform-environment`）、是否应用策略与 Step07 一致。 | 执行方式：本机 `kubectl`，不 SSH。 |
| **存储**     | NFS：StorageClass **nfs-2**，与远程 dev 常用一致。 | 不做云 CSI；NFS 服务在 WSL 上由 `wsl-setup-nfs-server.sh` 配置。 |

**脚本一：命名空间**（`sunmoonai/kind-infrastructure/apply-namespaces-existing-cluster.sh`）

- **职责**：根据「环境列表 × 平台列表」创建命名空间 `platform-environment`，可选应用策略（与 Step07 的 `NAMESPACE_PLATFORM_APPLY_POLICIES` 一致）。
- **配置**：从 **deploy-infrastructure-all.conf** 读取 `NAMESPACE_PLATFORM_ENVIRONMENTS`、`NAMESPACE_PLATFORM_PLATFORMS`、`NAMESPACE_PLATFORM_APPLY_POLICIES`；若 conf 不存在则使用脚本内默认值（与 conf 默认一致）。
- **行为**：解析上述变量，对每个 `(platform, environment)` 若 namespace 不存在则 `kubectl create namespace`，并执行策略（当前 Step07 为占位/日志）。

**脚本二：NFS 存储**（`sunmoonai/kind-infrastructure/apply-nfs-existing-cluster.sh`）

- **职责**：在已存在的 Kind 集群内部署 nfs-subdir-external-provisioner，连接 WSL 宿主机 NFS（需先运行 `wsl-setup-nfs-server.sh`），创建 StorageClass **nfs-2**。
- **前置**：WSL 已安装并 export `/data/kind-nfs`；当前 KUBECONFIG 指向目标集群。
- **行为**：Helm 安装 provisioner，`nfs.server` 默认 `172.17.0.1`（可设 `KIND_NFS_SERVER_HOST`），`nfs.path` 默认 `/data/kind-nfs`（可设 `KIND_NFS_PATH`）。

**使用方式与入口**

- **唯一入口**：**`kind-up.sh`** 依次执行「创建集群 → 命名空间 → NFS」，直接调用上述两个脚本；新手只需在 WSL 跑一次 `wsl-setup-nfs-server.sh`，之后每次跑 `kind-up.sh` 即可。
- **谁设 KUBECONFIG**：由 `kind-up.sh` 设置，或用户手动 `export KUBECONFIG=...`，或先运行连接管理器再执行脚本。

**参考**：策略与切换见《策略.md》；迁移节奏见《迁移指南.md》；远程 Step07/Step09 实现见 `sunmoonai/infrastructure/steps/step07_create_namespaces.sh`、`step09_storage.sh` 及 `deploy-infrastructure-all/deploy-infrastructure-all.conf`。

---

## 6. 常用操作

### 6.1 睡眠/唤醒后：先检查再决定是否重建

合上笔记本或系统睡眠后，**不一定**要马上跑 `kind-up.sh`。部分环境下 WSL 唤醒后 Docker 和 Kind 仍在，可先检查：

```bash
export KUBECONFIG=~/.kube/kind-config
kubectl get nodes
```

- **能正常列出节点**：说明集群还在，直接继续用或跑连接管理器即可，**无需重建、无需重新部署**。
- **报错或连接失败**：再执行下面的「一键恢复」。

这样可减少“每次唤醒都重建 + 整批重新部署”的情况。

### 6.2 一键恢复（集群真的没了时）

关 WSL、关机或检查后发现集群已不可用时，执行（与首次使用相同）：

```bash
cd k8s/sunmoonai/kind-infrastructure
./kind-up.sh
```

一条命令完成「创建集群 + 命名空间 + NFS」。

执行后当前终端已设置 `KUBECONFIG`，之后需**重新部署**各应用（PostgreSQL、Redis 等），每个组件会花一定时间。若经常需要完整重建且部署很慢，见下文「部署太慢时的替代方案」。

### 6.3 其他操作

| 操作     | 命令 |
|----------|------|
| 创建集群并初始化 | `cd k8s/sunmoonai/kind-infrastructure && ./kind-up.sh` |
| 删除集群 | `kind delete cluster --name kind` |
| 查看状态 | `kind get clusters`、`kubectl get nodes` |
| 加载镜像 | `kind load docker-image <image>:<tag> --name kind` |

---

## 7. 切换回远程集群

1. 编辑 `k8s/utils/k8s-admin.conf`：
   - `cluster_mode=remote`
   - `default_cluster=C1`（或 C2 等）
2. 运行连接管理器：`./k8s-connection-manager.sh`，再使用 `kubectl` 即连接对应远程集群。

---

## 8. 优势与限制

### 8.1 优势

- 本地开发、调试，无需占用远程资源。
- 与远程环境隔离，可随意删除重建。
- 启动快，适合做功能验证与 CI。

### 8.2 限制

- 资源受宿主机限制；节点实为容器，不适合压测或大规模负载。
- 镜像需通过 `kind load` 或可访问的仓库提供，不能直接“像云上一样”无限拉取。
- 持久化存储依赖 volume 或 hostPath 等，删除集群后数据不保留，重要数据需外部备份或仅作临时使用。
- **关 WSL、关机、合上笔记本或系统睡眠后**集群可能消失；唤醒后建议先 `kubectl get nodes` 检查，能通则不必重建（见 6.1）。**只关终端、且电脑不睡眠不关机**时 Kind 会一直存在。

**部署太慢时的替代方案**：若经常需要重建且每个组件部署时间长、几乎没法用，可考虑：
- **日常开发改用小型远程 K8s**：一台长期在线的虚拟机或小节点跑 K8s，本机用 k8s-admin 连过去，睡眠不影响集群；Kind 只做临时验证或 CI。
- **插电时关闭睡眠**：在电源选项中设置「接通电源时从不睡眠」，在办公室/家里插电工作时不会因睡眠丢集群；只有合上电脑带走后才需要下次唤醒时检查或重建。

---

## 9. 故障排除

### 9.1 Docker 未运行

```bash
docker info   # 若报错，先启动 Docker
# Linux: sudo systemctl start docker
# 或通过 Docker Desktop 启动
```

### 9.2 集群创建失败

- 检查资源：`docker system df`，必要时 `docker system prune` 释放空间。
- 删除后重建：`kind delete cluster --name kind`，再执行 `./kind-up.sh`（在 `k8s/sunmoonai/kind-infrastructure` 目录下）。

### 9.3 kubectl 无法连接

- 确认当前 context：`kubectl config current-context`，应为 Kind 对应 context。
- 若 kubeconfig 丢失或错误，重新导出：`kind get kubeconfig --name kind > ~/.kube/kind-config`，并设置 `KUBECONFIG` 或合并到默认 config。

### 9.4 镜像拉取/找不到镜像

- 确认镜像已在本地：`docker images | grep <镜像名>`。
- 确认已加载到 Kind：`kind load docker-image <image>:<tag> --name kind`。
- 若使用私有仓库，检查集群内 imagePullSecrets 与节点网络/解析。

---

## 10. 参考资源

- Kind 官方文档：https://kind.sigs.k8s.io/
- Kind GitHub：https://github.com/kubernetes-sigs/kind
- Kubernetes 文档：https://kubernetes.io/docs/

---

## 11. 与本项目其他文档的关系

- **迁移指南.md**：说明如何从“仅支持远程集群”迁移到“同时支持 Kind”，以及哪些配置与步骤在 Kind 上跳过、哪些可复用。
- **策略.md**：集群模式与策略切换。
- **kind-infrastructure/README.md**：Kind 脚本目录说明与使用步骤，与本文档一致。
- **KIND-README.md**（若存在）：与本文档互补，侧重快速上手与脚本用法，可一并查阅。
