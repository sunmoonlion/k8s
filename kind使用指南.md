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
cd k8s/utils
./kind-setup.sh create
```

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
# 使用项目脚本
./kind-setup.sh status

# 或直接使用 kubectl（需已通过连接管理器或 KUBECONFIG 指向 Kind）
kubectl cluster-info
kubectl get nodes
```

---

## 3. 连接 Kind 集群

### 3.1 使用连接管理器（推荐）

确保 `k8s-admin.conf` 中 `cluster_mode=kind`、`default_cluster=KIND`，然后：

```bash
cd k8s/utils
./k8s-connection-manager.sh
```

脚本会按当前模式切换到 Kind 的 kubeconfig，后续 `kubectl` 即针对 Kind 集群。

### 3.2 直接使用 kubeconfig

Kind 创建后通常已写入默认的 `~/.kube/config`；若使用独立文件（如 `~/.kube/kind-config`）：

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

## 5. 常用操作

| 操作     | 命令 |
|----------|------|
| 创建集群 | `./kind-setup.sh create` 或 `kind create cluster --name kind` |
| 删除集群 | `./kind-setup.sh delete` 或 `kind delete cluster --name kind` |
| 查看状态 | `./kind-setup.sh status` 或 `kind get clusters`、`kubectl get nodes` |
| 加载镜像 | `kind load docker-image <image>:<tag> --name kind` |

---

## 6. 切换回远程集群

1. 编辑 `k8s/utils/k8s-admin.conf`：
   - `cluster_mode=remote`
   - `default_cluster=C1`（或 C2 等）
2. 运行连接管理器：`./k8s-connection-manager.sh`，再使用 `kubectl` 即连接对应远程集群。

---

## 7. 优势与限制

### 7.1 优势

- 本地开发、调试，无需占用远程资源。
- 与远程环境隔离，可随意删除重建。
- 启动快，适合做功能验证与 CI。

### 7.2 限制

- 资源受宿主机限制；节点实为容器，不适合压测或大规模负载。
- 镜像需通过 `kind load` 或可访问的仓库提供，不能直接“像云上一样”无限拉取。
- 持久化存储依赖 volume 或 hostPath 等，删除集群后数据不保留，重要数据需外部备份或仅作临时使用。

---

## 8. 故障排除

### 8.1 Docker 未运行

```bash
docker info   # 若报错，先启动 Docker
# Linux: sudo systemctl start docker
# 或通过 Docker Desktop 启动
```

### 8.2 集群创建失败

- 检查资源：`docker system df`，必要时 `docker system prune` 释放空间。
- 删除后重建：`kind delete cluster --name kind`，再执行 `./kind-setup.sh create` 或等价命令。

### 8.3 kubectl 无法连接

- 确认当前 context：`kubectl config current-context`，应为 Kind 对应 context。
- 若 kubeconfig 丢失或错误，重新导出：`kind get kubeconfig --name kind > ~/.kube/kind-config`，并设置 `KUBECONFIG` 或合并到默认 config。

### 8.4 镜像拉取/找不到镜像

- 确认镜像已在本地：`docker images | grep <镜像名>`。
- 确认已加载到 Kind：`kind load docker-image <image>:<tag> --name kind`。
- 若使用私有仓库，检查集群内 imagePullSecrets 与节点网络/解析。

---

## 9. 参考资源

- Kind 官方文档：https://kind.sigs.k8s.io/
- Kind GitHub：https://github.com/kubernetes-sigs/kind
- Kubernetes 文档：https://kubernetes.io/docs/

---

## 10. 与本项目其他文档的关系

- **迁移指南.md**：说明如何从“仅支持远程集群”迁移到“同时支持 Kind”，以及哪些配置与步骤在 Kind 上跳过、哪些可复用。
- **KIND-README.md**：与本文档互补，侧重快速上手与脚本用法，可一并查阅。
