# Secret 管理系统使用场景对比

## 📋 系统概览

### 1. secret-management（通用 Secret 生成库）
**定位**：通用的 Kubernetes Secret 生成函数库  
**设计理念**：纯函数、无副作用、可独立使用  
**使用方式**：作为函数库被其他脚本调用

### 2. unified-cert-secret-management（统一证书和密钥管理系统）
**定位**：完整的证书和密钥生命周期管理系统  
**设计理念**：自动化、配置驱动、端到端管理  
**使用方式**：独立运行的一键部署工具

---

## 🎯 使用场景对比

### secret-management 使用场景

#### ✅ 适用场景

1. **组件内部 Secret 生成**
   - 组件部署脚本需要生成 Secret 时
   - 例如：RabbitMQ、PostgreSQL、Redis 等组件的认证 Secret
   - 示例：
     ```bash
     # 在 deploy-rabbitmq.sh 中
     source ~/master/k8s/utils/secret-management/lib/secret-core.sh
     
     generate_opaque_secret_yaml \
         --name "rabbitmq-auth-secret" \
         --namespace "messaging-platform-dev" \
         --data-file "rabbitmq-username:username.txt" \
         --data-file "rabbitmq-password:password.txt" \
         --output rabbitmq-auth-secret.yaml
     ```

2. **简单的一次性 Secret 生成**
   - 不需要复杂配置的 Secret
   - 快速生成 Secret YAML 文件
   - 示例：
     ```bash
     source ~/master/k8s/utils/secret-management/lib/secret-core.sh
     
     generate_docker_secret_yaml \
         --name "harbor-registry-secret" \
         --namespace "default" \
         --docker-server "harbor.sunmoonai.com:30443" \
         --docker-username "admin" \
         --docker-password "Harbor@12345" \
         --output harbor-secret.yaml
     ```

3. **自定义 Secret 生成逻辑**
   - 需要灵活控制生成过程
   - 需要在生成前后执行自定义逻辑
   - 示例：
     ```bash
     # 自定义生成流程
     source ~/master/k8s/utils/secret-management/lib/secret-core.sh
     
     # 1. 准备数据
     prepare_data
     
     # 2. 生成 Secret
     generate_secret_yaml_by_type --type "Opaque" ...
     
     # 3. 后处理
     post_process
     ```

4. **基于已有证书生成 TLS Secret**
   - 证书已通过其他方式生成
   - 只需要将证书打包成 Kubernetes Secret
   - 示例：
     ```bash
     source ~/master/k8s/utils/secret-management/lib/secret-core.sh
     
     generate_tls_secret_yaml \
         --name "my-tls-secret" \
         --namespace "default" \
         --tls-crt /path/to/server.crt \
         --tls-key /path/to/server.key \
         --output my-tls-secret.yaml
     ```

#### ❌ 不适用场景

1. **证书生命周期管理**（证书生成、轮换、分发）
2. **多环境证书分发**（K8s、Docker、nerdctl）
3. **自动化证书轮换**
4. **复杂的证书配置管理**

---

### unified-cert-secret-management 使用场景

#### ✅ 适用场景

1. **Traefik 证书管理**
   - Traefik 的 TLS 证书生成、分发、轮换
   - 支持多环境：K8s、Docker、nerdctl
   - 示例：
     ```bash
     cd ~/master/k8s/utils/unified-cert-secret-management
     ./deploy-all.sh rotate TRAEFIK_K1_K1
     ```

2. **Harbor 证书管理**
   - Harbor 的 CA 证书分发到客户端节点
   - 确保客户端能验证 Harbor 的 TLS 证书
   - 示例：
     ```bash
     # 分发 Traefik CA 证书到客户端（Harbor 使用 Traefik 的证书）
     ./deploy-all.sh --cluster C2 rotate TRAEFIK_K1_K1
     ```

3. **定期证书轮换**
   - 自动化证书轮换（建议每月执行）
   - 通过 cron 定时任务执行
   - 示例：
     ```bash
     # 设置每月1号自动轮换
     0 0 1 * * ~/master/k8s/utils/unified-cert-secret-management/deploy-all.sh
     ```

4. **系统初始化时的 CA 证书分发**
   - K8s 系统初始化时，分发 CA 证书到所有节点
   - 通过 `step12_ca_generation.sh` 调用（init 模式）
   - 示例：
     ```bash
     cd ~/master/k8s/sunmoonai/infrastructure
     ./deploy-infrastructure-all.sh  # 内部调用 step12
     ```

5. **证书损坏恢复**
   - 证书泄露或损坏时，强制重新生成
   - 使用 force 模式
   - 示例：
     ```bash
     ./deploy-all.sh force TRAEFIK_K1_K1
     ```

6. **多集群证书管理**
   - 支持多集群配置（C1、C2 等）
   - 统一管理不同集群的证书
   - 示例：
     ```bash
     ./deploy-all.sh --cluster C1 rotate TRAEFIK_K1_K1
     ./deploy-all.sh --cluster C2 rotate TRAEFIK_K1_K1
     ```

#### ❌ 不适用场景

1. **简单的 Secret 生成**（不需要证书管理功能）
2. **组件内部的认证 Secret**（如数据库密码、API 密钥）
3. **一次性 Secret 创建**（不需要生命周期管理）

---

## 📊 功能对比表

| 功能特性 | secret-management | unified-cert-secret-management |
|---------|-------------------|-------------------------------|
| **Secret 类型支持** | ✅ 全部（TLS、Docker、Opaque、Basic Auth、SSH） | ✅ TLS Secret（主要） |
| **证书生成** | ✅ 服务器证书（基于 CA） | ✅ CA + 服务器证书 |
| **证书轮换** | ❌ | ✅ 自动化轮换 |
| **证书分发** | ❌ | ✅ 多环境分发（K8s、Docker、nerdctl） |
| **Kubernetes Secret 部署** | ✅ 生成 YAML | ✅ 生成 + 部署 + 重启组件 |
| **多环境支持** | ❌ | ✅ K8s、Docker、nerdctl |
| **配置管理** | 参数传递 | 配置文件驱动 |
| **自动化程度** | 手动调用函数 | 一键部署 |
| **生命周期管理** | ❌ | ✅ init、rotate、force 模式 |
| **集群支持** | ❌ | ✅ 多集群配置 |
| **使用方式** | 函数库（被调用） | 独立工具（直接运行） |

---

## 🔄 实际使用示例

### 场景 1：组件部署时需要生成认证 Secret

**使用 secret-management**

```bash
# deploy-rabbitmq-auth-secret.sh
source ~/master/k8s/utils/secret-management/lib/secret-core.sh

generate_opaque_secret_yaml \
    --name "rabbitmq-auth-secret" \
    --namespace "messaging-platform-dev" \
    --data-file "rabbitmq-username:username.txt" \
    --data-file "rabbitmq-password:password.txt" \
    --output rabbitmq-auth-secret.yaml

kubectl apply -f rabbitmq-auth-secret.yaml
```

**为什么不使用 unified-cert-secret-management？**
- 这是简单的认证 Secret，不需要证书管理
- 不需要证书生成、分发、轮换等功能
- 使用轻量级的函数库更合适

---

### 场景 2：Traefik 证书轮换

**使用 unified-cert-secret-management**

```bash
cd ~/master/k8s/utils/unified-cert-secret-management
./deploy-all.sh rotate TRAEFIK_K1_K1
```

**执行流程**：
1. 生成新的服务器证书（CA 证书保持不变）
2. 创建/更新 Kubernetes TLS Secret
3. 部署 Secret 到 K8s 集群
4. 重启 Traefik 组件
5. 分发 CA 证书到所有客户端节点（K8s、Docker、nerdctl）

**为什么不使用 secret-management？**
- 需要证书生成、分发、轮换等完整生命周期管理
- 需要多环境支持
- 需要自动化部署和组件重启

---

### 场景 3：Harbor 客户端证书配置

**使用 unified-cert-secret-management**

```bash
# 分发 Traefik CA 证书到客户端节点
# （Harbor 使用 Traefik 的证书，客户端需要信任 Traefik 的 CA）
cd ~/master/k8s/utils/unified-cert-secret-management
./deploy-all.sh --cluster C2 rotate TRAEFIK_K1_K1
```

**结果**：
- CA 证书分发到 `/etc/containerd/certs.d/harbor.sunmoonai.com:30443/ca.crt`
- containerd/nerdctl 可以验证 Harbor 的 TLS 证书

**为什么不使用 secret-management？**
- 需要证书分发到多个节点
- 需要配置 containerd 的证书目录
- 需要自动化处理

---

### 场景 4：基于已有证书创建 TLS Secret

**使用 secret-management**

```bash
# 证书已通过其他方式生成，只需要打包成 Secret
source ~/master/k8s/utils/secret-management/lib/secret-core.sh

generate_tls_secret_yaml \
    --name "my-service-tls-secret" \
    --namespace "default" \
    --tls-crt /path/to/server.crt \
    --tls-key /path/to/server.key \
    --output my-service-tls-secret.yaml

kubectl apply -f my-service-tls-secret.yaml
```

**为什么不使用 unified-cert-secret-management？**
- 证书已存在，不需要生成
- 不需要证书分发
- 只需要简单的 Secret 生成功能

---

## 🎯 选择指南

### 选择 secret-management 当：

1. ✅ 需要生成**非证书类 Secret**（Opaque、Docker、Basic Auth、SSH）
2. ✅ 证书已存在，只需要**打包成 Secret**
3. ✅ 组件内部需要**灵活的 Secret 生成逻辑**
4. ✅ 需要**轻量级**的函数库，不想要复杂的配置
5. ✅ 只需要**生成 YAML 文件**，不需要自动化部署

### 选择 unified-cert-secret-management 当：

1. ✅ 需要**完整的证书生命周期管理**（生成、分发、轮换）
2. ✅ 需要**多环境证书分发**（K8s、Docker、nerdctl）
3. ✅ 需要**自动化证书轮换**
4. ✅ 需要**Traefik、Harbor 等服务的证书管理**
5. ✅ 需要**一键部署**和组件自动重启
6. ✅ 需要**多集群证书管理**

---

## 🔗 两者关系

### 协作关系

`unified-cert-secret-management` 内部可能会调用 `secret-management` 的函数来生成 Kubernetes Secret：

```bash
# unified-cert-secret-management 内部可能这样使用：
source ~/master/k8s/utils/secret-management/lib/secret-core.sh

generate_tls_secret_yaml \
    --name "$SECRET_NAME" \
    --namespace "$SECRET_NAMESPACE" \
    --tls-crt "$SERVER_CERT_PATH" \
    --tls-key "$SERVER_KEY_PATH" \
    --output "$SECRET_YAML_PATH"
```

### 职责划分

- **secret-management**：提供 Secret 生成的**基础能力**（函数库）
- **unified-cert-secret-management**：提供证书管理的**完整解决方案**（端到端工具）

---

## 📝 总结

| 系统 | 定位 | 主要用途 | 使用方式 |
|------|------|---------|---------|
| **secret-management** | 通用 Secret 生成库 | 组件内部 Secret 生成 | 作为函数库被调用 |
| **unified-cert-secret-management** | 证书生命周期管理系统 | Traefik/Harbor 证书管理 | 独立运行的工具 |

**核心区别**：
- `secret-management` 是**工具库**，提供基础能力
- `unified-cert-secret-management` 是**完整解决方案**，提供端到端管理

**使用原则**：
- 简单 Secret → 使用 `secret-management`
- 证书管理 → 使用 `unified-cert-secret-management`
- 组件内部 Secret → 使用 `secret-management`
- 系统级证书管理 → 使用 `unified-cert-secret-management`

