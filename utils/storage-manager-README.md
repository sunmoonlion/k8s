# Kubernetes 存储管理工具

## 概述

`storage-manager.sh` 是一个专门用于管理 Kubernetes 存储解决方案的脚本。它引用 `unified-deployment-template.sh` 来处理 Kubernetes 连接管理，专注于存储相关的功能。

## 主要特性

- ✅ **多种存储类型支持**
  - Local Path Provisioner (本地存储)
  - 传统 NFS 服务器
  - 阿里云 NAS
  - 腾讯云 CFS
  - 华为云 SFS
  - AWS EFS
  - 火山引擎 VFS

- ✅ **云厂商集成**
  - 自动配置云厂商认证信息
  - 支持 CSI Driver 安装
  - 环境变量管理

- ✅ **存储管理功能**
  - 显示存储状态
  - 创建静态 PV (支持两种绑定方式)
  - 创建测试 PVC
  - 测试存储功能
  - 清理存储资源

- ✅ **用户友好**
  - 交互式菜单
  - 彩色日志输出
  - 详细的操作指导

## 文件结构

```
k8s/utils/
├── storage-manager.sh           # 主脚本
├── k8s-admin.conf              # 连接配置文件
├── unified-deployment-template.sh  # 连接管理脚本
└── storage-manager-README.md   # 使用说明
```

## 使用方法

### 1. 启动脚本

```bash
cd k8s/utils
./storage-manager.sh
```

### 2. 主菜单选项

```
╔══════════════════════════════════════════════════════════════╗
║                Kubernetes 存储管理工具                        ║
║              (基于 unified-deployment-template.sh)            ║
╠══════════════════════════════════════════════════════════════╣
║  1) 显示当前存储状态                                          ║
║  2) 安装 local-path-provisioner                              ║
║  3) 安装 NFS 存储 (支持云厂商)                                ║
║  4) 创建静态 PV                                              ║
║  5) 创建测试 PVC                                             ║
║  6) 测试存储功能                                             ║
║  7) 清理存储资源                                             ║
║  8) 配置云厂商认证                                           ║
║  0) 退出                                                     ║
╚══════════════════════════════════════════════════════════════╝
```

## 存储类型详解

### 1. Local Path Provisioner

适用于开发环境和单节点集群的本地存储解决方案。

**特点：**
- 使用节点本地磁盘
- 简单易用，无需额外配置
- 适合开发和测试环境

**安装方式：**
- 在线安装：从 GitHub 下载 YAML
- 离线安装：使用国内镜像源

### 2. NFS 存储

支持单节点和分布式 NFS 存储方案。

#### 2.1 单节点 NFS 服务器

基于传统 NFS 服务器的共享存储。

**特点：**
- 一个节点作为 NFS 服务器
- 其他节点挂载使用
- 适合小型生产环境

**配置要求：**
- NFS 服务器地址
- 共享路径

#### 2.2 分布式 NFS

每个节点都提供 NFS 服务，实现自由调度。

**特点：**
- 每个节点都提供 NFS 服务
- Pod 可以自由调度到任何节点
- 就近访问，性能更好
- 高可用，单点故障不影响整体

**配置要求：**
- 每个节点的存储路径
- 每个节点的存储大小
- 自动配置节点标签和智能调度

### 3. 阿里云 NAS

阿里云文件存储 NAS 服务。

**特点：**
- 高可用、高可靠
- 自动扩展
- 支持多种协议

**配置要求：**
- NAS 文件系统 ID
- 挂载点地址
- 访问点 ID (可选)
- 阿里云 AccessKey

### 4. 腾讯云 CFS

腾讯云文件存储 CFS 服务。

**特点：**
- 高性能文件存储
- 自动备份
- 跨可用区部署

**配置要求：**
- CFS 文件系统 ID
- 挂载点地址
- 腾讯云 SecretId/SecretKey

### 5. 华为云 SFS

华为云弹性文件服务 SFS。

**特点：**
- 高性能文件存储
- 支持多种协议
- 企业级可靠性

**配置要求：**
- SFS 文件系统 ID
- 挂载点地址
- 华为云 AccessKey

### 6. AWS EFS

亚马逊弹性文件系统 EFS。

**特点：**
- 完全托管的文件系统
- 自动扩展
- 高可用性

**配置要求：**
- EFS 文件系统 ID
- 挂载点地址
- AWS IAM 权限

### 7. 火山引擎 VFS

火山引擎文件存储 VFS 服务。

**特点：**
- 高性能文件存储
- 支持多种协议
- 企业级可靠性
- 字节跳动生态集成

**配置要求：**
- VFS 文件系统 ID
- 挂载点地址
- 火山引擎 AccessKey

### 8. 静态 PV

手动创建的 PersistentVolume，提供最大的灵活性和控制力。

**特点：**
- 完全手动控制存储配置
- 支持精确的存储参数设置
- 可以集成现有存储系统
- 适合高性能和特殊需求场景

**绑定方式：**

#### 8.1 通过 StorageClass 绑定
```yaml
# 静态 PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-static-pv
spec:
  storageClassName: my-static-storage  # 指定 StorageClass
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  local:
    path: /data/my-storage

---
# PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  storageClassName: my-static-storage  # 匹配 PV 的 StorageClass
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

**适用场景：**
- 有多个相同类型的静态 PV
- 需要统一管理
- 简化 PVC 创建

#### 8.2 通过标签选择器绑定
```yaml
# 静态 PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-static-pv
  labels:
    type: high-performance
    node: node1
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  local:
    path: /data/my-storage

---
# PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  selector:
    matchLabels:
      type: high-performance
      node: node1
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

**适用场景：**
- 需要精确控制绑定关系
- 特定的存储需求
- 复杂的标签匹配

**配置要求：**
- PV 名称和配置参数
- 绑定方式选择
- 存储路径和节点信息
- 标签或 StorageClass 配置

## 云厂商认证配置

### 1. 阿里云

```bash
# 设置环境变量
export ALIYUN_ACCESS_KEY_ID="your-access-key-id"
export ALIYUN_ACCESS_KEY_SECRET="your-access-key-secret"
```

### 2. 腾讯云

```bash
# 设置环境变量
export TENCENT_SECRET_ID="your-secret-id"
export TENCENT_SECRET_KEY="your-secret-key"
```

### 3. 华为云

```bash
# 设置环境变量
export HUAWEI_ACCESS_KEY_ID="your-access-key-id"
export HUAWEI_SECRET_ACCESS_KEY="your-secret-access-key"
```

### 4. AWS

```bash
# 设置环境变量
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="your-region"
```

### 5. 火山引擎

```bash
# 设置环境变量
export VOLCENGINE_ACCESS_KEY_ID="your-access-key-id"
export VOLCENGINE_SECRET_ACCESS_KEY="your-secret-access-key"
```

## 使用场景

### 1. 开发环境

```bash
# 1. 安装 local-path-provisioner
./storage-manager.sh
# 选择选项 2

# 2. 创建测试 PVC
# 选择选项 5

# 3. 测试存储功能
# 选择选项 6
```

### 2. 生产环境

```bash
# 1. 配置云厂商认证
./storage-manager.sh
# 选择选项 8

# 2. 安装 NFS 存储
# 选择选项 3
# - 单节点环境：选择"单节点 NFS 服务器"
# - 多节点环境：选择"分布式 NFS"（推荐）

# 3. 安装云厂商 NFS（如需要）
# 选择选项 3，然后选择对应的云厂商

# 4. 创建静态 PV (如需要)
# 选择选项 4
# - 通过 StorageClass 绑定：适合统一管理
# - 通过标签选择器绑定：适合精确控制
```

### 3. 分布式 NFS 配置

```bash
# 1. 安装分布式 NFS
./storage-manager.sh
# 选择选项 3 (安装 NFS 存储)
# 选择选项 2 (分布式 NFS)

# 2. 在每个节点上执行配置命令
# 脚本会提示在每个节点上执行的命令

# 3. 使用智能调度
# 脚本会生成智能调度示例文件
# 使用该配置让 Pod 优先调度到有 NFS 服务的节点
```

### 4. 静态 PV 配置

```bash
# 1. 创建静态 PV
./storage-manager.sh
# 选择选项 4

# 2. 选择绑定方式
# - 通过 StorageClass 绑定：适合统一管理
# - 通过标签选择器绑定：适合精确控制

# 3. 配置参数
# - PV 名称、大小、路径、节点
# - StorageClass 名称或标签配置

# 4. 使用生成的 PVC 示例
# 脚本会自动生成 PVC 示例文件
# 使用该文件创建对应的 PVC
```

### 5. 存储管理

```bash
# 1. 查看存储状态
./storage-manager.sh
# 选择选项 1

# 2. 清理不需要的资源
# 选择选项 7
```

## 注意事项

### 1. 权限要求

- 需要集群管理员权限
- 云厂商需要相应的 IAM 权限
- 确保 kubectl 已正确配置

### 2. 网络要求

- 确保集群可以访问云厂商 API
- 检查防火墙和网络策略
- 验证 DNS 解析

### 3. 存储限制

- 不同存储类型有不同的性能特征
- 注意存储成本和容量规划
- 考虑数据备份和恢复策略

### 4. 安全考虑

- 妥善保管云厂商认证信息
- 使用最小权限原则
- 定期轮换访问密钥

## 故障排除

### 1. 连接问题

```bash
# 检查 kubectl 连接
kubectl cluster-info

# 检查节点状态
kubectl get nodes

# 检查 Pod 状态
kubectl get pods -A
```

### 2. 存储问题

```bash
# 检查 StorageClass
kubectl get storageclass

# 检查 PV/PVC
kubectl get pv,pvc --all-namespaces

# 检查存储相关 Pod
kubectl get pods -A | grep -E "(storage|provisioner)"
```

### 3. 云厂商问题

```bash
# 检查认证信息
echo $ALIYUN_ACCESS_KEY_ID
echo $TENCENT_SECRET_ID
echo $HUAWEI_ACCESS_KEY_ID
echo $AWS_ACCESS_KEY_ID
echo $VOLCENGINE_ACCESS_KEY_ID

# 检查 CSI Driver 状态
kubectl get pods -n nas-storage
kubectl get pods -n cfs-storage
kubectl get pods -n sfs-storage
kubectl get pods -n efs-storage
kubectl get pods -n vfs-storage

# 检查 NFS 存储状态
kubectl get pods -n nfs-storage
kubectl get storageclass | grep nfs

# 检查静态 PV 状态
kubectl get pv
kubectl get pvc --all-namespaces
kubectl describe pv <pv-name>
kubectl describe pvc <pvc-name>
```
```

## 最佳实践

### 1. 存储选择

- **开发环境**：使用 local-path-provisioner
- **测试环境**：使用单节点 NFS 或分布式 NFS
- **生产环境**：使用分布式 NFS 或云厂商 NFS
- **企业级**：使用云厂商 NFS 或企业级存储
- **特殊需求**：使用静态 PV（高性能、特定配置、现有存储集成）

### 2. 配置管理

- 使用环境变量管理认证信息
- 定期更新访问密钥
- 备份重要配置

### 3. 监控和维护

- 定期检查存储状态
- 监控存储使用情况
- 及时清理不需要的资源

### 4. 安全加固

- 使用 RBAC 控制访问权限
- 启用存储加密
- 实施网络策略

---

*最后更新: 2024-12-19*
