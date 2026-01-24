# Kind 本地集群使用指南

## 概述

本指南介绍如何将 Kubernetes 配置从远程集群切换到 Kind (Kubernetes in Docker) 本地集群。

## 前置要求

### 1. 安装 Docker

确保 Docker 已安装并正在运行：

```bash
# 检查 Docker 状态
docker info

# 如果未安装，请参考：https://docs.docker.com/get-docker/
```

### 2. 安装 Kind

```bash
# Linux/macOS
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# macOS (使用 Homebrew)
brew install kind

# 验证安装
kind version
```

更多安装方法：https://kind.sigs.k8s.io/docs/user/quick-start/#installation

### 3. 安装 kubectl

```bash
# 如果未安装，请参考：https://kubernetes.io/docs/tasks/tools/
```

## 配置说明

### 1. 修改配置文件

配置文件位置：`k8s/utils/k8s-admin.conf`

已添加以下配置：

```ini
[GLOBAL]
# 集群模式选择
cluster_mode=kind
# 默认集群
default_cluster=KIND

[KIND]
# Kind 集群名称
cluster_name=kind
# Kubeconfig 保存路径
kubeconfig=~/.kube/kind-config
```

### 2. 创建 Kind 集群

使用提供的脚本创建集群：

```bash
cd k8s/utils
./kind-setup.sh create
```

或手动创建：

```bash
kind create cluster --name kind
```

### 3. 验证集群

```bash
# 查看集群状态
./kind-setup.sh status

# 或使用 kubectl
kubectl cluster-info
kubectl get nodes
```

## 使用方法

### 方法 1: 使用连接管理器（推荐）

```bash
cd k8s/utils
./k8s-connection-manager.sh
```

脚本会自动检测到 kind 模式并连接。

### 方法 2: 直接使用 kubectl

Kind 会自动配置 `~/.kube/config`，可以直接使用：

```bash
kubectl get nodes
kubectl get pods -A
```

### 方法 3: 使用环境变量

如果配置了单独的 kubeconfig：

```bash
export KUBECONFIG=~/.kube/kind-config
kubectl get nodes
```

## 常用操作

### 创建集群

```bash
./kind-setup.sh create
```

### 删除集群

```bash
./kind-setup.sh delete
```

### 查看集群状态

```bash
./kind-setup.sh status
```

### 加载镜像到 Kind

Kind 集群无法直接使用远程镜像，需要先加载到本地：

```bash
# 从 Docker Hub 拉取镜像
docker pull nginx:latest

# 加载到 Kind 集群
kind load docker-image nginx:latest --name kind
```

### 使用配置文件创建集群

创建 `kind-config.yaml`：

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
```

然后使用配置文件创建：

```bash
kind create cluster --name kind --config kind-config.yaml
```

## 切换回远程集群

如果需要切换回远程集群：

1. 修改 `k8s-admin.conf`：
   ```ini
   [GLOBAL]
   cluster_mode=remote
   default_cluster=C1  # 或 C2
   ```

2. 运行连接管理器：
   ```bash
   ./k8s-connection-manager.sh
   ```

## 优势与限制

### 优势

- ✅ **本地开发**：无需网络连接，快速迭代
- ✅ **资源隔离**：不影响远程生产环境
- ✅ **快速重置**：可以快速删除和重建集群
- ✅ **成本低**：无需远程服务器资源

### 限制

- ⚠️ **资源限制**：受本地机器资源限制
- ⚠️ **镜像加载**：需要手动加载镜像到集群
- ⚠️ **持久化存储**：数据在删除集群后会丢失
- ⚠️ **网络功能**：某些网络功能可能受限

## 故障排除

### 问题 1: Docker 未运行

```bash
# 检查 Docker 状态
docker info

# 启动 Docker（根据系统不同）
sudo systemctl start docker  # Linux
# 或通过 Docker Desktop 启动
```

### 问题 2: 集群创建失败

```bash
# 检查 Docker 资源
docker system df

# 清理未使用的资源
docker system prune

# 重新创建集群
./kind-setup.sh delete
./kind-setup.sh create
```

### 问题 3: kubectl 无法连接

```bash
# 检查 kubeconfig
kubectl config current-context

# 重新获取 kubeconfig
kind get kubeconfig --name kind > ~/.kube/config
```

### 问题 4: 镜像拉取失败

Kind 集群无法直接访问外部镜像仓库，需要：

1. 先拉取到本地 Docker：
   ```bash
   docker pull <image>
   ```

2. 加载到 Kind：
   ```bash
   kind load docker-image <image> --name kind
   ```

## 参考资源

- Kind 官方文档：https://kind.sigs.k8s.io/
- Kind GitHub：https://github.com/kubernetes-sigs/kind
- Kubernetes 文档：https://kubernetes.io/docs/

## 下一步

1. ✅ 创建 Kind 集群
2. ✅ 配置 kubeconfig
3. ✅ 测试部署应用
4. ✅ 验证功能正常

祝你使用愉快！🚀

