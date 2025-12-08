# Kubernetes 集群管理工具

## 概述

这个工具用于管理远程 Kubernetes 集群的连接，支持跳板机模式和直接访问模式。工具采用环境变量方式管理集群配置，避免覆盖本地集群配置。

**重要更新**：工具现在位于 `k8s/utils/` 目录下，与其他工具脚本统一管理。

## 主要特性

- ✅ **支持跳板机模式**：通过跳板机访问远程集群
- ✅ **支持直接访问模式**：直接访问远程集群
- ✅ **环境变量管理**：使用 `KUBECONFIG` 环境变量，不覆盖本地配置
- ✅ **自动隧道管理**：自动建立和清理 SSH 隧道
- ✅ **连接状态检查**：实时检查连接状态
- ✅ **交互式操作**：提供交互式菜单进行集群操作

## 文件结构

```
k8s/utils/
├── k8s-connection-manager.sh  # 主管理脚本（手动管理工具）
├── k8s-admin.conf            # 配置文件
├── storage-manager.sh        # 存储管理工具
├── unified-deployment-template.sh  # 统一部署模板
└── k8s-admin-README.md       # 使用说明
```

## 配置说明

### 1. 编辑配置文件

编辑 `k8s-admin.conf` 文件，配置连接信息：

```ini
[GLOBAL]
default_mode=direct
auto_stop=true
timeout=30

[DIRECT]
host=your-server-ip:22
user=your-username
secret=~/.ssh/id_rsa
local_port=6443
kubeconfig=~/.kube/cluster-admin.conf
bind_alias=true
```

### 2. 配置说明

- `host`: 远程服务器地址和端口
- `user`: SSH 用户名
- `secret`: SSH 私钥文件路径
- `local_port`: 本地绑定端口
- `kubeconfig`: 远程集群配置保存路径
- `bind_alias`: 是否绑定域名别名

## 使用方法

### 1. 连接远程集群

```bash
# 运行管理脚本
./k8s-connection-manager.sh

# 脚本会自动：
# 1. 建立 SSH 隧道
# 2. 获取远程 kubeconfig
# 3. 设置环境变量：export KUBECONFIG=~/.kube/cluster-admin.conf
```

### 2. 使用远程集群

连接成功后，所有 `kubectl` 命令都会使用远程集群：

```bash
# 查看节点
kubectl get nodes

# 查看 Pod
kubectl get pods -A

# 部署应用
kubectl apply -f deployment.yaml
```

### 3. 智能环境切换

脚本现在支持智能环境检测：

- **自动使用本地集群**：如果没有远程连接状态且 KUBECONFIG 未设置，脚本会自动使用本地 `~/.kube/config`
- **智能提示**：连接失败时提供详细的操作指导
- **手动切换**：如果需要手动切换，可以使用：

```bash
# 切换到本地集群
unset KUBECONFIG

# 查看当前使用的集群
kubectl cluster-info

# 连接失败时会提供详细的操作指导
# 支持远程自动重连，显式切换到本地集群
```

### 4. 查看当前状态

```bash
# 查看当前使用的集群
echo $KUBECONFIG

# 查看集群信息
kubectl cluster-info

# 查看当前 context
kubectl config current-context
```

## 工作流程

### 1. 连接流程

```bash
# 1. 运行脚本
./k8s-manager.sh

# 2. 选择访问模式
# 3. 建立 SSH 隧道
# 4. 获取远程 kubeconfig
# 5. 设置环境变量
# 6. 进入操作菜单
```

### 2. 环境变量管理

```bash
# 连接远程集群时
export KUBECONFIG=~/.kube/cluster-admin.conf

# 使用本地集群时
unset KUBECONFIG
# 或者
export KUBECONFIG=~/.kube/config
```

### 3. 配置文件管理

- **本地集群配置**：`~/.kube/config`（保持不变）
- **远程集群配置**：`~/.kube/cluster-admin.conf`（动态生成）

## 优势

### 1. 不覆盖本地配置

- ✅ 本地集群配置始终保留
- ✅ 可以随时切换回本地集群
- ✅ 避免意外丢失本地配置

### 2. 灵活的环境管理

- ✅ 通过环境变量控制集群选择
- ✅ 支持多集群并行管理
- ✅ 脚本间配置隔离

### 3. 清晰的配置分离

- ✅ 本地和远程配置完全分离
- ✅ 配置文件职责明确
- ✅ 便于备份和恢复

### 4. 智能环境检测

- ✅ 自动检测当前环境状态
- ✅ 智能提示连接失败时的解决方案
- ✅ 保持远程自动重连功能

## 智能提示功能

### 连接失败时的提示

当 Kubernetes 连接失败时，脚本会提供详细的操作指导：

#### 远程集群连接失败
```
[WARNING] 远程连接不可用
[INFO] 当前环境变量 KUBECONFIG: ~/.kube/cluster-admin.conf
[INFO] 解决方案：
[INFO] 1. 使用本地集群: unset KUBECONFIG
[INFO] 2. 重新连接远程集群: ./k8s-connection-manager.sh
[INFO] 3. 等待自动重连（如果已启用）
```

#### 本地集群连接失败
```
[ERROR] 无法连接到 Kubernetes 集群
[INFO] 当前使用本地集群，但连接失败
[INFO] 请检查本地 Kubernetes 集群是否正常运行
```

## 注意事项

### 1. 环境变量持久性

- 环境变量只在当前 shell 会话中有效
- 新开终端需要重新设置环境变量
- 建议在 shell 配置文件中设置别名

### 2. 配置文件备份

- 定期备份 `~/.kube/config`
- 远程配置会在每次连接时重新生成
- 本地配置不会被修改

### 3. 多用户环境

- 每个用户有独立的 kubeconfig 文件
- 环境变量是用户级别的
- 不同用户可以同时连接不同集群

## 故障排除

### 1. 连接失败

```bash
# 检查 SSH 连接
ssh -i ~/.ssh/id_rsa user@server

# 检查端口是否被占用
netstat -tlnp | grep 6443

# 检查防火墙设置
sudo ufw status
```

### 2. 权限问题

```bash
# 检查 kubeconfig 文件权限
ls -la ~/.kube/

# 修复权限
chmod 600 ~/.kube/config
chmod 600 ~/.kube/cluster-admin.conf
```

### 3. 环境变量问题

```bash
# 检查环境变量
echo $KUBECONFIG

# 重新设置环境变量
export KUBECONFIG=~/.kube/cluster-admin.conf

# 清除环境变量
unset KUBECONFIG
```

## 示例场景

### 场景1：开发环境

```bash
# 1. 连接开发集群
./k8s-connection-manager.sh
# 选择直接访问模式

# 2. 部署应用
kubectl apply -f app.yaml

# 3. 查看状态
kubectl get pods

# 4. 切换回本地集群
unset KUBECONFIG
kubectl get nodes  # 现在使用本地集群
```

### 场景2：生产环境

```bash
# 1. 连接生产集群
./k8s-connection-manager.sh
# 选择跳板机模式

# 2. 执行生产操作
kubectl get nodes -o wide
kubectl get pods -A

# 3. 保持连接状态
# 环境变量已设置，后续命令都使用生产集群
```

### 场景3：多集群管理

```bash
# 1. 连接集群A
./k8s-connection-manager.sh
export KUBECONFIG_A=$KUBECONFIG

# 2. 连接集群B
./k8s-connection-manager.sh
export KUBECONFIG_B=$KUBECONFIG

# 3. 切换集群
export KUBECONFIG=$KUBECONFIG_A  # 使用集群A
export KUBECONFIG=$KUBECONFIG_B  # 使用集群B
unset KUBECONFIG                 # 使用本地集群
```
