# 为什么只有节点2可以访问 Harbor？

## 问题描述

虽然所有节点都配置了 iptables 转发规则（443 -> 30443），但是：
- ✅ 将 `harbor.sunmoonai.com` 映射到节点2 (101.126.151.0) 可以访问
- ❌ 将 `harbor.sunmoonai.com` 映射到节点1 (115.190.64.131) 或节点3 (115.190.61.238) 无法访问

## 根本原因

### 当前架构

1. **Traefik Pod 只运行在节点2**
   ```
   NAME                                 READY   STATUS    NODE
   traefik-sunmoonai-79c6c55dbd-l456v   1/1     Running   hsy-local-2 (101.126.151.0)
   ```

2. **Traefik 使用 Deployment，只有1个副本**
   ```yaml
   deployment:
     enabled: true
     kind: Deployment
     replicas: 1  # 只有1个副本
   ```

3. **所有节点都配置了 iptables 转发规则**
   - ✅ 节点1: 443 -> 30443 (eth0)
   - ✅ 节点2: 443 -> 30443 (eth0)
   - ✅ 节点3: 443 -> 30443 (eth0)

### 流量路径分析

#### 访问节点2 (101.126.151.0:443) ✅ 成功

```
外部请求 -> 节点2:443 
  -> iptables PREROUTING (443 -> 30443)
  -> Kubernetes NodePort 30443
  -> 直接到达节点2上的 Traefik Pod ✅
```

**结果：** 流量不需要跨节点转发，直接到达 Pod，成功！

#### 访问节点1/3 (115.190.64.131:443 或 115.190.61.238:443) ❌ 失败

```
外部请求 -> 节点1/3:443
  -> iptables PREROUTING (443 -> 30443) ✅
  -> Kubernetes NodePort 30443
  -> Kubernetes 尝试将流量转发到节点2的 Pod ❌ (超时或失败)
```

**结果：** 流量需要跨节点转发，但转发过程失败或超时！

### 为什么跨节点转发失败？

可能的原因：

1. **网络配置问题**
   - 节点之间的网络可能不允许跨节点的 NodePort 转发
   - 防火墙规则可能阻止了跨节点流量

2. **Kubernetes 网络策略**
   - 可能存在 NetworkPolicy 限制了跨节点流量
   - CNI 插件配置可能不支持跨节点转发

3. **iptables 规则冲突**
   - 虽然 PREROUTING 规则正确，但可能有其他规则干扰
   - OUTPUT 规则可能不完整

4. **NodePort 转发机制限制**
   - Kubernetes NodePort 的跨节点转发可能在某些网络配置下不工作
   - 特别是在使用某些 CNI 插件时

## 解决方案

### 方案1：将 Traefik 改为 DaemonSet（推荐）⭐

**优点：**
- 每个节点都有 Traefik Pod
- 不需要跨节点转发
- 所有节点都可以直接提供服务
- 高可用性更好

**缺点：**
- 资源消耗增加（每个节点一个 Pod）
- 需要确保所有节点都可以调度 Pod

**实施步骤：**

1. 修改 `dev-values.yaml`：
   ```yaml
   deployment:
     enabled: false  # 禁用 Deployment
   
   daemonSet:
     enabled: true   # 启用 DaemonSet
   ```

2. 重新部署：
   ```bash
   cd ~/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik
   ./deploy-traefik.sh deploy sunmoonai
   ```

### 方案2：增加 Traefik 副本数

**优点：**
- 保持 Deployment 模式
- 多个 Pod 分布在多个节点
- 提高可用性

**缺点：**
- 仍然可能有跨节点转发问题
- 需要确保 Pod 可以调度到多个节点

**实施步骤：**

1. 修改 `dev-values.yaml`：
   ```yaml
   deployment:
     enabled: true
     kind: Deployment
     replicas: 3  # 增加到3个副本
   ```

2. 添加节点选择器或容忍度，确保 Pod 分布在多个节点：
   ```yaml
   # 移除或修改节点选择器，允许 Pod 调度到所有节点
   # nodeSelector: {}
   ```

3. 重新部署：
   ```bash
   cd ~/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik
   ./deploy-traefik.sh deploy sunmoonai
   ```

### 方案3：使用 LoadBalancer（如果云平台支持）

**优点：**
- 自动负载均衡
- 不需要手动配置 iptables
- 可以使用标准端口（如果云平台支持）

**缺点：**
- 需要云平台支持
- 可能产生额外费用

### 方案4：修复跨节点转发（如果必须使用单副本）

如果必须保持单副本 Deployment，需要：

1. **检查网络配置**
   ```bash
   # 检查节点之间的网络连通性
   kubectl get nodes -o wide
   ping <节点2内网IP>  # 从节点1/3测试
   ```

2. **检查防火墙规则**
   ```bash
   # 确保节点之间的 NodePort 流量不被阻止
   # 检查 UFW、iptables、安全组等
   ```

3. **检查 CNI 配置**
   ```bash
   # 检查 CNI 插件是否支持跨节点转发
   kubectl get pods -n kube-system | grep -E "calico|flannel|weave"
   ```

4. **检查 Kubernetes 网络策略**
   ```bash
   # 检查是否有 NetworkPolicy 限制流量
   kubectl get networkpolicies -A
   ```

## 验证步骤

### 验证方案1（DaemonSet）

部署后验证：

```bash
# 检查 Pod 分布
kubectl get pod -n ingress-platform-dev -l app.kubernetes.io/name=traefik -o wide

# 应该看到每个节点都有一个 Pod
# NAME                                 NODE
# traefik-sunmoonai-xxx-1              hsy-local-1
# traefik-sunmoonai-xxx-2              hsy-local-2
# traefik-sunmoonai-xxx-3              hsy-local-3

# 测试所有节点的443端口
for node in 115.190.64.131 101.126.151.0 115.190.61.238; do
    echo "测试节点 $node:443"
    curl -k -v --connect-timeout 3 -m 5 -H "Host: harbor.sunmoonai.com" https://$node:443 2>&1 | grep -E "HTTP/|SSL" | head -2
done
```

### 验证方案2（多副本）

部署后验证：

```bash
# 检查 Pod 分布
kubectl get pod -n ingress-platform-dev -l app.kubernetes.io/name=traefik -o wide

# 应该看到多个 Pod 分布在不同的节点
# NAME                                 NODE
# traefik-sunmoonai-xxx-1              hsy-local-1
# traefik-sunmoonai-xxx-2              hsy-local-2
# traefik-sunmoonai-xxx-3              hsy-local-3
```

## 推荐方案

**推荐使用方案1（DaemonSet）**，因为：

1. ✅ **最简单可靠**：每个节点都有 Pod，不需要跨节点转发
2. ✅ **高可用性**：即使某个节点故障，其他节点仍可提供服务
3. ✅ **性能更好**：流量直接到达本地 Pod，无需跨节点转发
4. ✅ **符合 Ingress Controller 最佳实践**：大多数生产环境都使用 DaemonSet

## 总结

**问题根源：**
- Traefik 只有1个副本，只运行在节点2
- 访问节点1/3时，需要跨节点转发，但转发失败

**解决方案：**
- 推荐：将 Traefik 改为 DaemonSet（每个节点一个 Pod）
- 备选：增加 Traefik 副本数，让 Pod 分布在多个节点
- 如果必须单副本：需要修复跨节点转发问题（网络配置、防火墙等）

**当前状态：**
- ✅ iptables 转发规则已正确配置在所有节点
- ✅ NodePort 30443 在所有节点都可以访问
- ❌ 跨节点转发失败，导致只有节点2可以访问

