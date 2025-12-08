# 云存储厂商切换指南

## 支持的云厂商

脚本支持以下云存储厂商：

| 厂商 | 配置值 | 存储服务 | 状态 |
|------|--------|----------|------|
| 阿里云 | `aliyun` | NAS | ✅ 已实现 |
| 腾讯云 | `tencent` | CFS | ⚠️ 待实现 |
| 华为云 | `huawei` | SFS | ⚠️ 待实现 |
| AWS | `aws` | EFS | ⚠️ 待实现 |
| 火山引擎 | `volcengine` | VFS | ✅ 已实现 |

## 切换厂商步骤

### 1. 修改提供商配置

编辑 `deploy.conf`：

```bash
# 选择云厂商
STEP09_CLOUD_PROVIDER="volcengine"    # 火山引擎（默认）
# STEP09_CLOUD_PROVIDER="aliyun"      # 阿里云
# STEP09_CLOUD_PROVIDER="tencent"     # 腾讯云
```

### 2. 填写对应厂商的认证信息

#### 火山引擎VFS配置（默认）
```bash
STEP09_CLOUD_PROVIDER="volcengine"
STEP09_VOLCENGINE_ACCESS_KEY="your-volcengine-access-key"
STEP09_VOLCENGINE_SECRET_KEY="your-volcengine-secret-key"
STEP09_VOLCENGINE_REGION="cn-beijing"
STEP09_VOLCENGINE_VFS_FILESYSTEM_ID="vfs-xxxxxxxxxxxxxxxx"
```

#### 阿里云NAS配置
```bash
STEP09_CLOUD_PROVIDER="aliyun"
STEP09_ALIYUN_ACCESS_KEY="your-aliyun-access-key"
STEP09_ALIYUN_SECRET_KEY="your-aliyun-secret-key"
STEP09_ALIYUN_REGION="cn-beijing"
STEP09_ALIYUN_NAS_FILESYSTEM_ID="your-nas-filesystem-id"
```

#### 腾讯云CFS配置
```bash
STEP09_CLOUD_PROVIDER="tencent"
STEP09_TENCENT_ACCESS_KEY="your-tencent-access-key"
STEP09_TENCENT_SECRET_KEY="your-tencent-secret-key"
STEP09_TENCENT_REGION="ap-beijing"
STEP09_TENCENT_CFS_FILESYSTEM_ID="your-cfs-filesystem-id"
```

### 3. 配置存储类名称

```bash
# 根据厂商设置合适的存储类名称
STEP09_CLOUD_STORAGE_CLASS_NAME="volcengine-vfs"  # 火山引擎（默认）
STEP09_CLOUD_STORAGE_CLASS_NAME="aliyun-nas"      # 阿里云
STEP09_CLOUD_STORAGE_CLASS_NAME="tencent-cfs"     # 腾讯云
```

## 厂商特定配置

### 火山引擎VFS特有配置（默认）
```bash
STEP09_VOLCENGINE_VFS_MOUNT_OPTIONS="nfsvers=3"
STEP09_VOLCENGINE_VFS_PATH="/"
STEP09_VOLCENGINE_VFS_SUBDIR_PREFIX="k8s-pvc"
```

### 阿里云NAS特有配置
```bash
# 阿里云NAS使用标准NFS配置，无需额外参数
```

### 腾讯云CFS特有配置
```bash
# 腾讯云CFS配置（待实现）
STEP09_TENCENT_CFS_MOUNT_OPTIONS="nfsvers=3"
STEP09_TENCENT_CFS_PATH="/"
```

## 部署和验证

### 1. 部署存储
```bash
./k8s/sunmoonai/infrastructure/steps/step09_storage.sh
```

### 2. 验证部署
```bash
# 检查StorageClass
kubectl get storageclass

# 检查CSI驱动
kubectl get pods -n kube-system | grep -E "(aliyun|volcengine|tencent)"

# 创建测试PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: ${STEP09_CLOUD_STORAGE_CLASS_NAME}
EOF
```

## 注意事项

1. **认证信息**：确保使用对应厂商的正确认证信息
2. **地域匹配**：确保文件系统与Kubernetes集群在同一地域
3. **网络连通性**：确保集群节点可以访问云存储服务
4. **权限配置**：确保认证信息有足够的存储权限
5. **成本考虑**：不同厂商的存储成本可能不同

## 故障排查

### 1. CSI驱动未启动
```bash
kubectl get pods -n kube-system | grep csi
kubectl logs -n kube-system deployment/<csi-controller-name>
```

### 2. 认证失败
```bash
# 检查认证信息是否正确
kubectl describe pvc <pvc-name>
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 3. 网络连接问题
```bash
# 检查云存储端点连通性
telnet <storage-endpoint> 2049
```

## 最佳实践

1. **测试环境**：先在测试环境验证配置
2. **备份策略**：配置定期备份
3. **监控告警**：设置存储使用量监控
4. **权限最小化**：使用最小权限原则
5. **文档记录**：记录配置变更和故障处理过程
