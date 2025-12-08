# Traefik iptables 端口转发配置说明

## 概述

由于 Kubernetes NodePort 的限制（端口范围 30000-32767），Traefik 使用 NodePort 30080/30443 暴露 HTTP/HTTPS 服务。  
如果希望外部通过标准的 80/443 端口访问，需要在**每个 Kubernetes 节点**上配置 iptables 转发规则。

## 脚本位置

```
k8s/sunmoonai/ingress-platform/traefik/setup-iptables-forward.sh
```

## 执行位置

**重要：此脚本必须在每个 Kubernetes 节点上以 root 权限执行**

### 为什么要在节点上执行？

- iptables 规则需要修改节点的网络配置
- 需要 root 权限才能修改 iptables
- 每个节点都需要配置，因为 Traefik Pod 可能调度到任意节点

### 执行方式

#### 方式1：自动配置（推荐）⭐

**Traefik 部署脚本已集成自动配置功能**，在 Traefik 部署成功后会自动在所有节点上配置 iptables 转发规则并持久化。

**使用方法**：

```bash
# 直接部署 Traefik，会自动配置所有节点的 iptables
./deploy-traefik/deploy-traefik.sh deploy sunmoonai
```

**自动配置功能**：
- ✅ 自动获取所有 Kubernetes 节点
- ✅ 自动通过 SSH 连接每个节点
- ✅ 自动复制脚本到节点
- ✅ 自动执行配置并持久化规则
- ✅ 显示详细的配置结果统计

**配置控制**：

```bash
# 禁用自动配置（通过环境变量）
AUTO_CONFIG_IPTABLES=false ./deploy-traefik/deploy-traefik.sh deploy sunmoonai

# 或在配置文件中设置（deploy-traefik.conf）
AUTO_CONFIG_IPTABLES="false"
```

**节点配置说明**：

自动配置功能会从 `deploy-infrastructure-all.conf` 配置文件中读取节点信息：
- `SERVER_n_PUBLIC_IP`: 节点公网 IP（用于 SSH 连接）
- `SERVER_n_USER`: SSH 用户名
- `SERVER_n_SECRET`: SSH 私钥路径
- `SERVER_n_SSH_PORT`: SSH 端口
- `SERVER_n_PASS`: SSH 密码（可选）

**多集群支持**：

配置文件支持多集群配置（通过 `C{数字}_*` 前缀），脚本会根据 `CLUSTER` 环境变量自动选择对应的配置：

```bash
# 使用集群1配置（C1_SERVER_n_*）
CLUSTER=C1 ./deploy-traefik/deploy-traefik.sh deploy sunmoonai

# 使用集群2配置（C2_SERVER_n_*）
CLUSTER=C2 ./deploy-traefik/deploy-traefik.sh deploy sunmoonai
```

**集群配置映射机制**：

脚本会自动将 `C{数字}_SERVER_n_*` 映射到 `SERVER_n_*`，例如：
- `C1_SERVER_1_PUBLIC_IP` → `SERVER_1_PUBLIC_IP`
- `C1_SERVER_1_USER` → `SERVER_1_USER`
- `C1_SERVER_1_SECRET` → `SERVER_1_SECRET`
- `C1_SERVER_1_SSH_PORT` → `SERVER_1_SSH_PORT`
- 等等...

这样，当 `CLUSTER=C1` 时，脚本会自动使用 `C1_SERVER_n_*` 配置；当 `CLUSTER=C2` 时，会自动使用 `C2_SERVER_n_*` 配置。

**环境变量覆盖**（可选）：

如果节点配置不在 `deploy-infrastructure-all.conf` 中，可通过环境变量覆盖：
- `SSH_USER`: SSH 用户名（会被 `SERVER_n_USER` 覆盖）
- `SSH_KEY`: SSH 私钥路径（会被 `SERVER_n_SECRET` 覆盖）
- `SSH_PORT`: SSH 端口（会被 `SERVER_n_SSH_PORT` 覆盖）
- `SSH_PASSWORD`: SSH 密码（会被 `SERVER_n_PASS` 覆盖）

#### 方式2：手动在节点上执行

如果自动配置失败或需要手动配置，可以按以下步骤操作：

1. **将脚本复制到节点**：
   ```bash
   # 从部署机器复制到节点
   scp setup-iptables-forward.sh root@<节点IP>:/tmp/
   ```

2. **在节点上执行**：
   ```bash
   # SSH 到节点
   ssh root@<节点IP>
   
   # 执行脚本（添加规则并持久化）
   sudo /tmp/setup-iptables-forward.sh add --persist
   ```

#### 方式3：使用 Ansible 批量执行

```yaml
- name: 配置 iptables 转发规则
  hosts: k8s_nodes
  become: yes
  tasks:
    - name: 复制脚本到节点
      copy:
        src: setup-iptables-forward.sh
        dest: /tmp/setup-iptables-forward.sh
        mode: '0755'
    
    - name: 执行转发规则配置并持久化
      command: /tmp/setup-iptables-forward.sh add --persist
```

## 脚本用法

```bash
# 添加转发规则（80 -> 30080, 443 -> 30443）
sudo ./setup-iptables-forward.sh add

# 添加转发规则并自动持久化（推荐）
sudo ./setup-iptables-forward.sh add --persist

# 或使用环境变量自动持久化
AUTO_PERSIST=true sudo ./setup-iptables-forward.sh add

# 删除转发规则
sudo ./setup-iptables-forward.sh remove

# 查看当前规则
sudo ./setup-iptables-forward.sh list
```

**参数说明**：
- `add`: 添加转发规则（默认操作）
- `add --persist`: 添加转发规则并自动持久化（推荐）
- `remove`: 删除转发规则
- `list`: 列出当前规则

## 转发规则说明

脚本会创建以下 iptables 规则：

1. **PREROUTING 规则**（外部访问）：
   ```bash
   iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 30080
   iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 30443
   ```

2. **OUTPUT 规则**（本地访问）：
   ```bash
   iptables -t nat -A OUTPUT -p tcp -d <节点IP> --dport 80 -j REDIRECT --to-port 30080
   iptables -t nat -A OUTPUT -p tcp -d <节点IP> --dport 443 -j REDIRECT --to-port 30443
   ```

## 持久化配置

**重要：iptables 规则在节点重启后会丢失！**

### 自动持久化（推荐）⭐

**脚本已支持自动持久化功能**，使用 `--persist` 参数即可：

```bash
# 添加规则并自动持久化
sudo ./setup-iptables-forward.sh add --persist
```

脚本会自动：
1. 优先使用 `netfilter-persistent`（如果已安装）
2. 否则使用 `iptables-save` 保存到 `/etc/iptables/rules.v4`
3. 确保规则在节点重启后自动加载

**自动配置功能已集成持久化**：使用 Traefik 部署脚本的自动配置功能时，规则会自动持久化。

### 手动持久化方法

如果需要手动配置持久化，可以使用以下方法：

#### 方法1：使用 iptables-persistent（推荐）

```bash
# 安装 iptables-persistent
apt-get update
apt-get install -y iptables-persistent

# 保存当前规则
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

# 或使用 netfilter-persistent
netfilter-persistent save
```

#### 方法2：使用 systemd 服务

创建 `/etc/systemd/system/traefik-iptables-forward.service`：

```ini
[Unit]
Description=Traefik iptables port forwarding
After=network.target

[Service]
Type=oneshot
ExecStart=/path/to/setup-iptables-forward.sh add
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

启用服务：
```bash
systemctl enable traefik-iptables-forward.service
systemctl start traefik-iptables-forward.service
```

#### 方法3：在节点初始化脚本中添加

如果使用云平台或自动化工具（如 Terraform、Ansible），可以在节点初始化时自动执行。

## 验证配置

### 1. 检查 iptables 规则

```bash
# 查看 PREROUTING 规则
iptables -t nat -L PREROUTING -n --line-numbers | grep -E "REDIRECT|dpt:(80|443)"

# 查看 OUTPUT 规则
iptables -t nat -L OUTPUT -n --line-numbers | grep -E "REDIRECT|dpt:(80|443)"
```

### 2. 测试端口转发

```bash
# 测试 HTTP 转发
curl -I http://<节点IP>/

# 测试 HTTPS 转发
curl -I https://<节点IP>/
```

### 3. 检查 Traefik 服务

```bash
# 检查 NodePort 服务
kubectl get svc -n ingress-platform-dev traefik

# 检查 Traefik Pod 状态
kubectl get pods -n ingress-platform-dev -l app.kubernetes.io/name=traefik
```

## 注意事项

1. **推荐使用自动配置**：Traefik 部署脚本已集成自动配置功能，推荐使用自动配置，无需手动操作

2. **每个节点都需要配置**：Traefik Pod 可能调度到任意节点，所有节点都需要配置转发规则（自动配置会自动处理）

3. **SSH 访问要求**：自动配置需要部署机器能够通过 SSH 访问所有节点（使用密钥或密码认证）

4. **防火墙配置**：确保节点的防火墙允许 80/443 端口入站流量

5. **规则持久化**：节点重启后规则会丢失，自动配置已包含持久化功能（使用 `--persist` 参数）

6. **规则冲突**：如果节点上已有其他服务占用 80/443 端口，需要先处理冲突

7. **负载均衡器**：如果使用外部负载均衡器（如云平台的 LB），可以在 LB 层面配置端口映射，无需在节点上配置 iptables

8. **禁用自动配置**：如果不想使用自动配置，可设置 `AUTO_CONFIG_IPTABLES=false` 环境变量或修改配置文件

## 故障排查

### 问题1：规则不生效

```bash
# 检查规则是否存在
sudo iptables -t nat -L PREROUTING -n | grep REDIRECT

# 检查端口是否被占用
sudo netstat -tlnp | grep -E ':(80|443)'

# 检查 Traefik NodePort 服务
kubectl get svc -n ingress-platform-dev traefik
```

### 问题2：规则在重启后丢失

确保已配置持久化（见上方"持久化配置"部分）

### 问题3：本地访问不生效

检查 OUTPUT 规则是否正确配置：
```bash
sudo iptables -t nat -L OUTPUT -n | grep REDIRECT
```

## 相关文件

- 脚本：`setup-iptables-forward.sh`
- Traefik 配置：`resources/custom-values/dev-values.yaml`
- 部署脚本：`deploy-traefik/deploy-traefik.sh`

## 参考

- [iptables 官方文档](https://www.netfilter.org/documentation/)
- [Kubernetes NodePort 文档](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport)
- [Traefik 官方文档](https://doc.traefik.io/traefik/)

