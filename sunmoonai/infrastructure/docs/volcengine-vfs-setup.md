# 火山引擎VFS云存储配置指南

## 概述

本指南将帮助您配置火山引擎VFS（文件存储）作为Kubernetes集群的云存储解决方案。

## 前置条件

1. **火山引擎账号**：拥有火山引擎账号并开通VFS服务
2. **Kubernetes集群**：已部署的Kubernetes集群
3. **网络连通性**：集群节点能够访问火山引擎VFS服务

## 配置步骤

### 1. 获取火山引擎认证信息

1. 登录[火山引擎控制台](https://console.volcengine.com/)
2. 进入"访问控制" -> "访问密钥管理"
3. 创建访问密钥，记录：
   - AccessKey
   - SecretKey

### 2. 创建VFS文件系统

1. 进入"文件存储" -> "VFS"
2. 创建文件系统：
   - 选择与Kubernetes集群相同的地域
   - 选择合适的存储类型和容量
   - 记录文件系统ID

### 3. 配置deploy.conf

编辑 `k8s/sunmoonai/infrastructure/config/deploy.conf`：

```bash
# 启用云存储
STEP09_CLOUD_STORAGE_ENABLED=true

# 云存储提供商
STEP09_CLOUD_PROVIDER="volcengine"

# 火山引擎认证信息
STEP09_CLOUD_ACCESS_KEY="your-access-key-here"
STEP09_CLOUD_SECRET_KEY="your-secret-key-here"
STEP09_CLOUD_REGION="cn-beijing"
STEP09_CLOUD_FILESYSTEM_ID="vfs-xxxxxxxxxxxxxxxx"

# 存储类配置
STEP09_CLOUD_STORAGE_CLASS_NAME="volcengine-vfs"
STEP09_CLOUD_STORAGE_DEFAULT_CLASS=false
```

### 4. 网络配置

确保Kubernetes集群节点可以访问VFS：

```bash
# 检查网络连通性
telnet <vfs-endpoint> 2049

# 检查安全组规则
# 开放端口：2049, 111, 20048, 20049
```

### 5. 部署存储

运行存储配置脚本：

```bash
# 在线部署
./k8s/sunmoonai/infrastructure/steps/step09_storage.sh

# 离线部署（需要预先准备资源）
PACKAGES_DEPLOY_MODE=offline ./k8s/sunmoonai/infrastructure/steps/step09_storage.sh
```

## 离线部署资源准备

### 1. 下载Helm Chart

```bash
helm repo add volcengine https://volcengine.github.io/helm-charts
helm repo update
helm pull volcengine/vfs-csi-driver
```

### 2. 拉取镜像

```bash
# CSI驱动镜像
docker pull volcengine/vfs-csi-driver:v1.2.0
docker save volcengine/vfs-csi-driver:v1.2.0 -o volcengine_vfs-csi-driver_v1.2.0.tar

# CSI Provisioner镜像
docker pull registry.k8s.io/sig-storage/csi-provisioner:v3.4.0
docker save registry.k8s.io/sig-storage/csi-provisioner:v3.4.0 -o registry.k8s.io_sig-storage_csi-provisioner_v3.4.0.tar
```

### 3. 上传资源

将资源上传到所有节点的 `~/packages-to-be-installed/` 目录：

```
packages-to-be-installed/
├── charts/
│   └── volcengine-vfs-csi-driver-*.tgz
└── images/
    ├── volcengine_vfs-csi-driver_v1.2.0.tar
    └── registry.k8s.io_sig-storage_csi-provisioner_v3.4.0.tar
```

## 验证部署

### 1. 检查StorageClass

```bash
kubectl get storageclass volcengine-vfs
```

### 2. 创建测试PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-volcengine-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: volcengine-vfs
```

### 3. 检查PVC状态

```bash
kubectl get pvc test-volcengine-pvc
kubectl describe pvc test-volcengine-pvc
```

## 使用示例

### 在Deployment中使用

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: test-volcengine-pvc
```

### 在StatefulSet中使用

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteMany"]
      storageClassName: volcengine-vfs
      resources:
        requests:
          storage: 10Gi
```

## 故障排查

### 1. CSI驱动未启动

```bash
kubectl get pods -n kube-system | grep volcengine
kubectl logs -n kube-system deployment/volcengine-vfs-controller
```

### 2. PVC无法绑定

```bash
kubectl describe pvc <pvc-name>
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 3. 网络连接问题

```bash
# 检查VFS端点连通性
telnet <vfs-endpoint> 2049

# 检查DNS解析
nslookup <vfs-endpoint>
```

## 配置参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `STEP09_CLOUD_PROVIDER` | 云存储提供商 | `volcengine` |
| `STEP09_CLOUD_ACCESS_KEY` | 火山引擎AccessKey | 必填 |
| `STEP09_CLOUD_SECRET_KEY` | 火山引擎SecretKey | 必填 |
| `STEP09_CLOUD_REGION` | 火山引擎地域 | 必填 |
| `STEP09_CLOUD_FILESYSTEM_ID` | VFS文件系统ID | 必填 |
| `STEP09_VOLCENGINE_VFS_MOUNT_OPTIONS` | 挂载选项 | `nfsvers=3` |
| `STEP09_VOLCENGINE_VFS_PATH` | 挂载路径 | `/` |
| `STEP09_VOLCENGINE_VFS_SUBDIR_PREFIX` | 子目录前缀 | `k8s-pvc` |

## 注意事项

1. **地域匹配**：确保VFS文件系统与Kubernetes集群在同一地域
2. **网络访问**：确保集群节点可以访问VFS服务
3. **权限配置**：使用最小权限原则配置AccessKey
4. **成本控制**：合理配置存储容量和访问模式
5. **备份策略**：建议配置定期备份策略

## 支持

如遇到问题，请检查：

1. 火山引擎VFS服务状态
2. 网络连通性
3. 认证信息正确性
4. Kubernetes集群状态
5. CSI驱动日志
