# 跨集群Harbor TLS认证分析

## 📋 场景说明

**目标**：集群2的节点能够通过TLS认证访问集群1的Harbor服务

**前提条件**：
- 集群1部署了Harbor服务（通过Traefik暴露，使用TLS）
- 集群2需要访问集群1的Harbor
- 两个集群需要共享相同的CA证书

## 🔍 当前架构分析

### CA证书生成机制

1. **CA证书基于服务端前缀生成**
   - 服务端前缀（server_prefix）= 前三层：`SERVICE_SERVERENV_SERVERNODE`
   - 例如：`TRAEFIK_K1`（Traefik服务，K8s环境，节点1）
   - 所有使用相同服务端前缀的组合共享同一个CA证书

2. **CA证书归档机制**
   - CA证书的归档目录由 `LOCAL_CA_CERT_DIR` 配置决定
   - 归档目录是CA证书存在的唯一依据
   - 如果归档目录相同，多个集群会共享同一个CA证书

3. **客户端证书分发机制**
   - 客户端脚本根据组合的前缀找到对应的CA证书
   - 例如：`TRAEFIK_K1_K1` → 使用 `TRAEFIK_K1` 的CA证书
   - 分发到客户端节点的containerd/Docker证书目录

### 当前配置分析

#### 集群1配置
```bash
# 服务端前缀：TRAEFIK_K1
TRAEFIK_K1_K1_LOCAL_CA_CERT_DIR="~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca"

# 客户端节点配置
C1_TRAEFIK_K1_K1_CLIENT_NODES="node1,node2,node3"
C1_TRAEFIK_K1_K1_CLIENT_NODE_HOSTS="115.190.64.131,101.126.151.0,115.190.61.238"
C1_TRAEFIK_K1_K1_CLIENT_CONTAINERD_PATH="/etc/containerd/certs.d/harbor.sunmoonai.com:30443"
```

#### 集群2配置
```bash
# 客户端节点配置
C2_TRAEFIK_K1_K1_CLIENT_NODES="node1,node2,node3"
C2_TRAEFIK_K1_K1_CLIENT_NODE_HOSTS="115.190.37.57,115.190.153.150,115.190.86.211"
# 注意：C2_TRAEFIK_K1_K1_CLIENT_CONTAINERD_PATH 未配置，会使用默认值
```

## ✅ 可行性分析

### 方案1：共享归档目录（推荐）

**原理**：
- 集群1和集群2使用相同的服务端前缀（`TRAEFIK_K1`）
- 集群2使用集群1的归档目录配置
- 两个集群共享同一个CA证书

**配置要求**：
1. 集群2必须使用集群1的归档目录：
   ```bash
   # 在 cert-secret.conf 中添加集群2的归档目录配置
   C2_TRAEFIK_K1_K1_LOCAL_CA_CERT_DIR="~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca"
   ```
   或者，如果集群2和集群1在同一台机器上，直接使用相同的路径。

2. 集群2的客户端节点配置：
   ```bash
   C2_TRAEFIK_K1_K1_CLIENT_NODES="node1,node2,node3"
   C2_TRAEFIK_K1_K1_CLIENT_NODE_HOSTS="115.190.37.57,115.190.153.150,115.190.86.211"
   C2_TRAEFIK_K1_K1_CLIENT_CONTAINERD_PATH="/etc/containerd/certs.d/harbor.sunmoonai.com:30443"
   ```

**执行流程**：
1. 集群1部署时，生成CA证书并归档到共享目录
2. 集群1的客户端脚本分发CA证书到集群1的节点
3. 集群2部署时，检测到归档目录中已存在CA证书，直接使用（不重新生成）
4. 集群2的客户端脚本分发CA证书到集群2的节点
5. 集群2的节点现在信任集群1的Harbor服务器证书

**优点**：
- ✅ 自动共享CA证书
- ✅ 无需手动复制证书
- ✅ 符合当前架构设计

**缺点**：
- ⚠️ 需要确保归档目录可访问（如果集群2在不同机器上，需要共享存储或手动同步）

### 方案2：手动同步CA证书

**原理**：
- 集群1生成CA证书后，手动复制到集群2的归档目录
- 集群2使用自己的归档目录，但内容与集群1相同

**配置要求**：
1. 集群2使用自己的归档目录：
   ```bash
   C2_TRAEFIK_K1_K1_LOCAL_CA_CERT_DIR="~/master/k8s/cluster2/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca"
   ```

2. 手动同步CA证书：
   ```bash
   # 从集群1复制CA证书到集群2
   scp ~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt \
       user@cluster2:~/master/k8s/cluster2/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/
   scp ~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.key \
       user@cluster2:~/master/k8s/cluster2/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/
   ```

**优点**：
- ✅ 集群2有独立的归档目录
- ✅ 不依赖共享存储

**缺点**：
- ⚠️ 需要手动同步证书
- ⚠️ 证书更新时需要重新同步

## 🎯 推荐方案

**推荐使用方案1（共享归档目录）**，原因：
1. 符合当前架构设计（CA证书基于服务端前缀共享）
2. 自动化程度高，无需手动操作
3. 证书更新时自动同步

## 📝 实施步骤

### 步骤1：配置集群2的归档目录

在 `cert-secret.conf` 中添加：

```bash
# 集群2使用集群1的归档目录（共享CA证书）
C2_TRAEFIK_K1_K1_LOCAL_CA_CERT_DIR="~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca"
```

**注意**：如果集群2在不同机器上，需要：
- 使用共享存储（NFS等），或
- 使用绝对路径指向集群1的归档目录（如果可访问），或
- 使用方案2手动同步

### 步骤2：配置集群2的客户端节点

确保集群2的客户端节点配置正确：

```bash
C2_TRAEFIK_K1_K1_CLIENT_NODES="node1,node2,node3"
C2_TRAEFIK_K1_K1_CLIENT_NODE_HOSTS="115.190.37.57,115.190.153.150,115.190.86.211"
C2_TRAEFIK_K1_K1_CLIENT_NODE_PORTS="1022,1022,1022"
C2_TRAEFIK_K1_K1_CLIENT_NODE_USERNAMES="zym,zym,zym"
C2_TRAEFIK_K1_K1_CLIENT_NODE_SSH_KEYS="~/.ssh/id_rsa,~/.ssh/id_rsa,~/.ssh/id_rsa"
C2_TRAEFIK_K1_K1_CLIENT_CONTAINERD_PATH="/etc/containerd/certs.d/harbor.sunmoonai.com:30443"
```

### 步骤3：部署集群2的客户端

```bash
# 设置集群2环境变量
export CLUSTER=C2

# 部署集群2的客户端（只分发CA证书）
cd ~/master/k8s/utils/unified-cert-secret-management
./deploy-all.sh --cluster C2 rotate TRAEFIK_K1_K1
```

### 步骤4：验证

在集群2的节点上验证CA证书：

```bash
# 检查CA证书是否存在
ls -la /etc/containerd/certs.d/harbor.sunmoonai.com:30443/ca.crt

# 验证证书内容
openssl x509 -in /etc/containerd/certs.d/harbor.sunmoonai.com:30443/ca.crt -text -noout

# 测试Harbor连接
crictl pull harbor.sunmoonai.com:30443/library/nginx:latest
```

## ⚠️ 注意事项

1. **归档目录访问**：
   - 如果集群2在不同机器上，确保归档目录可访问
   - 可以使用共享存储（NFS）或定期同步

2. **CA证书更新**：
   - 如果集群1更新CA证书（force模式），集群2需要重新分发
   - 建议在集群1更新后，立即在集群2重新运行客户端部署脚本

3. **服务器证书**：
   - 集群1的Harbor服务器证书必须由共享的CA证书签发
   - 如果集群1使用自己的CA证书签发服务器证书，集群2的节点才能信任

4. **域名解析**：
   - 确保集群2的节点能够解析 `harbor.sunmoonai.com`
   - 可以通过DNS或 `/etc/hosts` 配置

## 🔄 工作流程总结

```
集群1部署：
1. 生成CA证书 → 归档到共享目录
2. 生成服务器证书（由CA证书签发）
3. 部署到Traefik（使用服务器证书）
4. 分发CA证书到集群1的节点

集群2部署：
1. 检测到共享目录中已存在CA证书 → 直接使用（不重新生成）
2. 分发CA证书到集群2的节点
3. 集群2的节点现在信任集群1的Harbor服务器证书 ✅
```

## ✅ 结论

**是的，如果保持CA证书一样，集群2就能通过集群1的Harbor的TLS认证。**

关键点：
1. ✅ 使用相同的服务端前缀（`TRAEFIK_K1`）
2. ✅ 使用相同的归档目录（共享CA证书）
3. ✅ 集群2的客户端脚本分发CA证书到集群2的节点
4. ✅ 集群1的Harbor服务器证书由共享的CA证书签发

这样，集群2的节点就会信任集群1的Harbor服务器证书，实现跨集群TLS认证。

