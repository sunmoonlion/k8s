# Jenkins 访问说明文档

## 概述

本文档说明如何访问部署在Kubernetes集群中的Jenkins服务，包括访问方式、登录凭据获取和常见问题解决。

## 服务信息

- **服务名称**: jenkins-sunmoonai
- **命名空间**: cicd-platform-dev
- **访问方式**: Ingress (Traefik)
- **访问地址**: `https://www.sunmoonai.com/jenkins`
- **Context Path**: `/jenkins`（Jenkins 运行在子路径下）

## 访问方式

### 方法1：通过 Ingress 访问（推荐）

**访问地址**：
- 统一域名：`https://www.sunmoonai.com/jenkins`
- IP 地址：`https://115.190.153.150:30443/jenkins`

**使用步骤**：
1. 在浏览器中访问上述 URL
2. 等待 Jenkins 加载完成
3. 使用登录凭据登录

**注意**：Jenkins 运行在 `/jenkins` 子路径下，所有链接和重定向都会自动包含 `/jenkins` 前缀。

### 方法2：kubectl port-forward（临时，用于调试）

```bash
# 在本地机器上运行
export KUBECONFIG=/home/zym/.kube/cluster-c2-admin.conf
kubectl port-forward -n cicd-platform-dev svc/jenkins-sunmoonai 8080:8080

# 然后访问 http://localhost:8080/jenkins
```

## 登录凭据

### 当前管理员密码

**用户名**: `user`（Bitnami Jenkins 默认用户名）  
**密码**: `zym123`（从 Secret `jenkins-sunmoonai` 读取）

### 密码管理机制

**重要说明**：Jenkins 的密码管理遵循以下规则：

1. **首次初始化**（空 PVC）：
   - Bitnami Jenkins 会使用 Secret `jenkins-sunmoonai` 中的密码创建 `user` 用户（默认用户名）
   - Secret 配置位置：`deploy-jenkins/secrets/jenkins-sunmoonai/deploy-jenkins-sunmoonai/jenkins-sunmoonai.conf`
   - 当前配置：`JENKINS_PASSWORD="zym123"`（使用默认用户名 `user`，不自定义）

2. **已有数据时**（PVC 存在）：
   - Jenkins 检测到 `Detected data from previous deployments`
   - **不会**使用 Secret 中的密码重新初始化
   - 使用 PVC 中已保存的用户和密码（在 Jenkins UI 中设置的密码）

3. **密码持久化**：
   - 用户和密码保存在 PVC `jenkins-sunmoonai` 中
   - 即使执行 `uninstall + deploy`，只要 PVC 存在，密码不会改变
   - 这是正常行为，确保数据持久化

### 重置密码为 Secret 中的值

如果需要强制使用 Secret 中的密码（`admin / zym123`），需要**完全清理**所有资源：

```bash
# 1. 删除所有 Jenkins 资源（包括 PVC，这会删除所有数据！）
export KUBECONFIG=/home/zym/.kube/cluster-c2-admin.conf
kubectl delete deployment,service,secret,pvc jenkins-sunmoonai -n cicd-platform-dev

# 2. 重新部署 Secret
cd ~/master/k8s/sunmoonai/cicd-platform/jenkins/deploy-jenkins/secrets/jenkins-sunmoonai/deploy-jenkins-sunmoonai
./deploy-jenkins-secrets.sh deploy

# 3. 重新部署 Jenkins（会使用 Secret 中的密码初始化）
cd ~/master/k8s/sunmoonai/cicd-platform/jenkins/deploy-jenkins
./deploy-jenkins.sh deploy
```

**⚠️ 警告**：删除 PVC 会**永久删除**所有 Jenkins 数据（Jobs、配置、历史记录等）！

## 密码获取方法

### 方法1：从Secret获取配置密码（推荐）

```bash
# 获取 Secret 中的密码
export KUBECONFIG=/home/zym/.kube/cluster-c2-admin.conf
kubectl get secret jenkins-sunmoonai -n cicd-platform-dev -o jsonpath='{.data.jenkins-password}' | base64 -d && echo ""

# 获取 Secret 中的用户名
kubectl get secret jenkins-sunmoonai -n cicd-platform-dev -o jsonpath='{.data.jenkins-admin-user}' | base64 -d && echo ""
```

**注意**：Secret 中的密码只在**首次初始化**（空 PVC）时生效。如果 Jenkins 已初始化，密码保存在 PVC 中。

### 方法2：从Jenkins容器内获取密码文件

```bash
# 读取 Secret 挂载的密码文件
export KUBECONFIG=/home/zym/.kube/cluster-c2-admin.conf
kubectl get pod -n cicd-platform-dev -l app.kubernetes.io/name=jenkins -o name | head -1 | \
  xargs -I {} kubectl exec {} -n cicd-platform-dev -c jenkins -- \
  cat /opt/bitnami/jenkins/secrets/jenkins-password
```

### 方法3：检查Jenkins初始化状态

```bash
# 查看 Jenkins 是否检测到已有数据
export KUBECONFIG=/home/zym/.kube/cluster-c2-admin.conf
kubectl logs -n cicd-platform-dev -l app.kubernetes.io/name=jenkins -c jenkins | grep -i "detected data"

# 如果显示 "Detected data from previous deployments"，说明已初始化，密码在 PVC 中
# 如果未显示，说明是首次初始化，会使用 Secret 中的密码
```

## 服务状态检查

### 检查Jenkins服务状态

```bash
# 检查服务状态
kubectl --kubeconfig=.kube/cluster-admin.conf get svc jenkins-sunmoonai -n cicd-platform

# 检查pod状态
kubectl --kubeconfig=.kube/cluster-admin.conf get pods -n cicd-platform

# 检查服务详情
kubectl --kubeconfig=.kube/cluster-admin.conf describe svc jenkins-sunmoonai -n cicd-platform
```

### 检查Jenkins日志

```bash
# 查看Jenkins启动日志
kubectl --kubeconfig=.kube/cluster-admin.conf logs jenkins-sunmoonai-<pod-name> -n cicd-platform

# 实时查看日志
kubectl --kubeconfig=.kube/cluster-admin.conf logs jenkins-sunmoonai-<pod-name> -n cicd-platform -f
```

## 常见问题解决

### 问题1：无法访问Jenkins

**症状**: 浏览器显示"无法访问此网站"

**解决方案**:
1. 检查服务状态：`kubectl get svc jenkins-sunmoonai -n cicd-platform`
2. 检查pod状态：`kubectl get pods -n cicd-platform`
3. 检查防火墙设置
4. 尝试不同的节点IP

### 问题2：密码错误

**症状**: 登录时提示用户名或密码错误

**可能原因**：
1. Jenkins 已初始化，密码保存在 PVC 中（不是 Secret 中的密码）
2. 密码在 Jenkins UI 中被修改过

**解决方案**:
1. **如果 Jenkins 是首次初始化**：
   - 使用 Secret 中的密码：`zym123`
   - 用户名：`user`（Bitnami Jenkins 默认用户名）

2. **如果 Jenkins 已初始化**（检测到已有数据）：
   - 密码是之前在 Jenkins UI 中设置的密码
   - 如果忘记密码，需要：
     - 临时禁用安全设置（修改 config.xml）
     - 或完全清理并重新初始化（删除 PVC）

3. **其他尝试**：
   - 清除浏览器缓存和Cookie
   - 使用无痕模式访问
   - 检查 Jenkins 日志确认初始化状态

### 问题3：Jenkins启动失败

**症状**: pod状态为CrashLoopBackOff或Error

**解决方案**:
1. 查看pod日志：`kubectl logs jenkins-sunmoonai-<pod-name> -n cicd-platform`
2. 检查存储权限
3. 检查资源配置

## 配置信息

### 当前配置

- **存储类**: nfs-storage
- **存储大小**: 8Gi
- **CPU限制**: 1核
- **内存限制**: 2Gi
- **CPU请求**: 500m
- **内存请求**: 1Gi

### 已安装插件

- workflow-aggregator
- git
- blueocean
- kubernetes
- docker-workflow

## 安全注意事项

1. **生产环境**: 建议使用Ingress配置HTTPS访问
2. **密码管理**: 首次登录后请修改默认密码
3. **网络安全**: 确保只有授权用户可以访问Jenkins
4. **备份**: 定期备份Jenkins配置和数据

## 维护命令

### 完全清理并重新初始化 Jenkins

**⚠️ 警告**：这会删除所有 Jenkins 数据（Jobs、配置、历史记录等）！

#### 方法1：使用清理脚本（推荐）

```bash
# 使用提供的清理脚本
cd ~/master/k8s/sunmoonai/cicd-platform/jenkins
./cleanup-jenkins.sh

# 脚本会提示确认，输入 "yes" 继续
# 然后按照脚本输出的提示重新部署 Secret 和 Jenkins
```

#### 方法2：手动删除

```bash
export KUBECONFIG=/home/zym/.kube/cluster-c2-admin.conf

# 1. 删除所有 Jenkins 资源（包括 PVC）
kubectl delete deployment,service,secret,pvc jenkins-sunmoonai -n cicd-platform-dev

# 2. 确认资源已删除
kubectl get deployment,service,secret,pvc -n cicd-platform-dev | grep jenkins-sunmoonai || echo "✅ 所有资源已删除"

# 3. 重新部署 Secret
cd ~/master/k8s/sunmoonai/cicd-platform/jenkins/deploy-jenkins/secrets/jenkins-sunmoonai/deploy-jenkins-sunmoonai
./deploy-jenkins-secrets.sh deploy

# 4. 重新部署 Jenkins（会使用 Secret 中的密码初始化）
cd ~/master/k8s/sunmoonai/cicd-platform/jenkins/deploy-jenkins
./deploy-jenkins.sh deploy
```

### 重启Jenkins服务（保留数据）

```bash
# 重启Jenkins deployment（不删除 PVC，数据保留）
export KUBECONFIG=/home/zym/.kube/cluster-c2-admin.conf
kubectl rollout restart deployment jenkins-sunmoonai -n cicd-platform-dev
```

### 更新Jenkins配置

```bash
# 更新Jenkins配置
helm --kubeconfig=.kube/cluster-admin.conf upgrade jenkins-sunmoonai bitnami/jenkins -n cicd-platform -f /path/to/values.yaml
```

### 查看Jenkins版本

```bash
# 查看Jenkins版本信息
kubectl --kubeconfig=.kube/cluster-admin.conf exec jenkins-sunmoonai-<pod-name> -n cicd-platform -- java -jar /opt/bitnami/jenkins/jenkins.war --version
```

## 联系信息

如有问题，请联系系统管理员或查看相关文档。

---  
**最后更新**: 2025-12-03  
**维护人员**: 系统管理员

## 附录：密码管理机制详解

### 为什么 uninstall + deploy 后密码没有改变？

**原因**：Bitnami Jenkins 的初始化逻辑：

1. **首次启动（空 PVC）**：
   - Jenkins 检测到 `/bitnami/jenkins/home` 目录为空
   - 使用 Secret 中的 `JENKINS_USERNAME` 和 `JENKINS_PASSWORD` 创建 admin 用户
   - 日志显示：正常初始化，无 "Detected data" 消息

2. **已有数据时（PVC 存在）**：
   - Jenkins 检测到 `Detected data from previous deployments`
   - **不会**使用 Secret 中的密码重新初始化
   - 使用 PVC 中已保存的用户和密码（在 Jenkins UI 中设置的密码）
   - 这是**正常行为**，确保数据持久化

### 如何确认 Jenkins 的初始化状态？

```bash
# 检查日志
export KUBECONFIG=/home/zym/.kube/cluster-c2-admin.conf
kubectl logs -n cicd-platform-dev -l app.kubernetes.io/name=jenkins -c jenkins | grep -i "detected data"

# 如果显示 "Detected data from previous deployments"：
#   → 已初始化，密码在 PVC 中（不是 Secret 中的密码）
# 如果未显示：
#   → 首次初始化，会使用 Secret 中的密码
```

### 密码存储位置

- **Secret** (`jenkins-sunmoonai`)：
  - 位置：Kubernetes Secret
  - 用途：仅在首次初始化时使用
  - 配置：`deploy-jenkins/secrets/jenkins-sunmoonai/deploy-jenkins-sunmoonai/jenkins-sunmoonai.conf`

- **PVC** (`jenkins-sunmoonai`)：
  - 位置：持久化存储卷
  - 用途：保存所有 Jenkins 数据（包括用户和密码）
  - 路径：`/bitnami/jenkins/home/users/` 和 `/bitnami/jenkins/home/config.xml`

### 最佳实践

1. **日常运维**：
   - 保持 PVC 不删除，数据持久化
   - 密码在 Jenkins UI 中管理
   - Secret 仅作为"初始密码"的配置

2. **完全重置**：
   - 使用 `cleanup-jenkins.sh` 脚本
   - 或手动删除 Deployment + Service + Secret + **PVC**
   - 重新部署后，会使用 Secret 中的密码初始化
