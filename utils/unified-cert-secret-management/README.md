# 统一证书和密钥管理系统

一个基于5层架构的自动化证书和密钥管理工具，支持Harbor、Traefik等服务的证书生成、分发、部署、轮换和Kubernetes Secret管理。

## 🚀 快速开始

### 推荐使用方式：证书轮换

```bash
cd ~/master/k8s/utils/unified-cert-secret-management
./deploy-all.sh
```

或者使用兼容性脚本（已合并到 deploy-all.sh）：

```bash
./rotate-certs.sh  # 向后兼容，实际调用 deploy-all.sh
```

这个命令会自动：
- 读取配置文件中的所有已启用组合
- 为每个组合生成新证书（遵循X.509标准规范）
- 部署到服务端（K8s集群）
- 分发CA证书到所有客户端节点
- 更新Kubernetes Secret
- 重启相关组件以应用新证书

### 查看帮助信息

```bash
./deploy-all.sh --help
```

## 🔄 运行模式

系统支持三种运行模式，针对不同的使用场景：

### 1. 初始化模式 (init)
- **用途**: K8s系统初始化时的CA证书生成和分发
- **CA证书**: 如果不存在则生成，已存在则跳过（保护根证书）
- **服务器证书**: 不生成（由各组件独立管理）
- **Secret部署**: 不执行
- **组件重启**: 不执行（组件尚未运行）
- **使用场景**: 通过`step12_ca_generation.sh`调用，仅用于初始化CA证书

### 2. 轮换模式 (rotate) - 默认
- **用途**: 定期轮换证书，更新现有Secret
- **CA证书**: 如果已存在则跳过生成（CA证书有效期10年，不应频繁更换）
- **服务器证书**: 总是重新生成（定期轮换，有效期1年）
- **Secret部署**: 更新现有Secret
- **组件重启**: 重启相关组件以应用新证书
- **使用场景**: 定期证书轮换，cron定时任务

> **⚠️ 重要提示：rotate 模式的行为说明**
> 
> rotate 模式**不会改变 CA 证书**（如果 CA 已存在则跳过生成）。因此，当服务器证书生成开关（`GENERATE_SERVER_CERT_ENABLED`）设为 `false` 时：
> - 如果 CA 证书已存在：运行 rotate 模式**不会改变任何东西**（CA 跳过，服务器证书不生成）
> - 如果 CA 证书不存在：会生成 CA 证书，但不会生成服务器证书
> 
> 这意味着，如果您的配置中 `GENERATE_SERVER_CERT_ENABLED=false` 且 CA 证书已存在，运行 rotate 模式实际上是一个空操作，不会产生任何变化。

### 3. 强制更新模式 (force)
- **用途**: 强制重新生成和部署所有证书
- **CA证书**: 删除已存在的CA证书和私钥，强制重新生成
- **服务器证书**: 删除已存在的服务器证书和私钥，强制重新生成
- **Secret部署**: 更新现有Secret
- **组件重启**: 重启相关组件以应用新证书
- **使用场景**: 证书损坏、CA证书泄露或需要完全重新生成证书链

### 模式对比表

| 模式 | CA证书处理 | 服务器证书处理 | Secret部署 | 组件重启 |
|------|-----------|--------------|-----------|---------|
| init | 生成（如不存在）| 不生成 | 不执行 | 否 |
| rotate | 跳过（如已存在）| 重新生成 | 更新 | 是 |
| force | 删除并重新生成 | 删除并重新生成 | 更新 | 是 |

## 📋 系统特性

### ✨ 核心功能
- **标准证书生成**：遵循X.509标准和现代浏览器要求
  - CN使用根域名（不使用通配符）
  - 通配符域名放在SANs（Subject Alternative Names）中
  - keyUsage不包含dataEncipherment（避免浏览器兼容性问题）
- **证书轮换**：支持定期轮换服务器证书
- **自动化部署**：一键部署所有已配置的证书组合
- **多环境支持**：K8s、Docker、nerdctl等不同客户端环境
- **Kubernetes集成**：自动创建和更新TLS Secret
- **智能客户端处理**：
  - Docker客户端：分发证书后自动重启Docker服务
  - containerd/nerdctl客户端：证书动态加载，无需重启

### 🔧 技术特性
- **5层架构设计**：服务类型_服务端环境_服务端节点_客户端环境_客户端节点
- **插件化部署**：不同服务类型使用专门的部署插件
- **配置驱动**：所有参数通过`cert-secret.conf`配置文件管理
- **错误隔离**：单个组合失败不影响其他组合
- **集群配置支持**：通过`C1_*`、`C2_*`前缀支持多集群配置

## 🏗️ 系统架构

```
统一证书和密钥管理系统
├── 主入口脚本
│   ├── deploy-all.sh          # 一键部署所有证书 ⭐推荐（已合并所有功能）
│   ├── rotate-certs.sh        # 兼容性包装脚本（已合并到 deploy-all.sh）
│   └── cert-secret.conf       # 所有配置参数
├── 核心库 (lib/)
│   ├── common.sh              # 公共函数和配置管理
│   ├── ssh.sh                 # SSH连接和文件传输
│   ├── cert.sh                # 证书生成和管理
│   │   └── generate_ca_certificate()  # CA证书生成和归档（统一处理）
│   └── secret-data.sh         # Kubernetes Secret管理
├── 部署脚本 (scripts/)
│   ├── deploy-server.sh       # 服务端部署脚本
│   ├── deploy-client.sh       # 客户端部署脚本
│   └── plugins/               # 环境特定部署插件
│       ├── server/            # 服务端插件
│       │   ├── traefik-K-deploy-server.sh
│       │   └── traefik-C-deploy-server.sh
│       └── client/            # 客户端插件
│           ├── traefik-K-deploy-client.sh
│           ├── traefik-D-deploy-client.sh
│           └── traefik-N-deploy-client.sh
└── 证书规范模板 (lib/cert-conf-template/)
    ├── server-specifications  # 服务器证书规范模板
    └── ca-specifications      # CA证书规范模板
```

### 职责划分

系统采用清晰的职责划分，确保各组件各司其职：

#### 核心库职责（lib/cert.sh）
- **CA证书归档**：`generate_ca_certificate()` 函数统一处理CA证书的生成和归档
  - 检查归档目录中是否存在CA证书（归档目录为唯一依据）
  - 如果存在，复制到临时目录供使用
  - 如果不存在，生成新CA证书并立即归档
  - 所有模式（init/rotate/force）都通过此函数统一处理

#### 服务端脚本职责（scripts/plugins/server/*）
- **CA证书生成**：调用 `generate_ca_certificate()` 生成CA证书
- **服务器证书生成**：生成服务器证书（如果启用）
- **服务器证书归档**：归档服务器证书到指定目录
- **Secret管理**：生成、归档和部署Kubernetes Secret
- **组件重启**：重启使用Secret的组件（rotate/force模式）
- **不负责**：CA证书分发（由客户端脚本负责）

#### 客户端脚本职责（scripts/plugins/client/*）
- **CA证书分发**：分发CA证书到所有客户端节点
  - K8s环境：支持多节点分发（通过 `CLIENT_NODES` 配置）
  - Docker环境：单节点分发，自动重启Docker服务
  - nerdctl环境：单节点分发，证书动态加载
- **不负责**：证书生成、归档和Secret管理（由服务端脚本负责）

#### 运行模式说明
- **init/rotate/force模式**：只影响CA证书的生成逻辑（是否存在、是否强制重新生成）
- **职责划分**：不受运行模式影响，服务端和客户端的职责始终不变

## 📖 详细使用方法

### 1. 证书轮换（推荐）

```bash
# 轮换所有已配置的证书组合（默认rotate模式）
./deploy-all.sh
# 或
./deploy-all.sh rotate

# 强制更新所有证书（force模式）
./deploy-all.sh force

# 查看帮助信息
./deploy-all.sh --help
```

**执行流程**：
1. 自动发现所有已启用的组合（如：TRAEFIK_K1_K1、TRAEFIK_K1_D1等）
2. **服务端脚本执行**：
   - 调用 `generate_ca_certificate()` 处理CA证书（归档目录为唯一依据）
   - 生成新的服务器证书（CA证书已存在则跳过生成）
   - 归档服务器证书到指定目录
   - 创建/更新Kubernetes TLS Secret
   - 部署Secret到K8s集群
   - 重启相关组件以应用新证书
3. **客户端脚本执行**：
   - 分发CA证书到所有客户端节点
   - K8s环境：分发到所有配置的节点（`CLIENT_NODES`）
   - Docker客户端：自动重启Docker服务
   - containerd/nerdctl客户端：证书动态加载，无需重启
4. 显示部署结果和状态

### 2. 不同运行模式

```bash
# 证书轮换（默认，CA证书已存在则跳过）
./deploy-all.sh
# 或
./deploy-all.sh rotate

# 强制更新（删除所有证书并重新生成）
./deploy-all.sh force

# 初始化部署（仅生成和分发CA证书）
./deploy-all.sh init

# 使用集群配置
./deploy-all.sh --cluster C1 rotate

# 处理特定组合
./deploy-all.sh rotate TRAEFIK_K1_K1

# 组合使用
./deploy-all.sh --cluster C1 force TRAEFIK
```

### 3. 单个组合部署

```bash
# 部署Traefik K8s环境到K8s客户端
./scripts/deploy-server.sh traefik k8s 1 k8s 1
./scripts/deploy-client.sh traefik k8s 1 k8s 1

# 部署Traefik K8s环境到Docker客户端
./scripts/deploy-server.sh traefik k8s 1 docker 1
./scripts/deploy-client.sh traefik k8s 1 docker 1
```

### 4. 通过K8s基础设施部署

```bash
# 在K8s系统初始化时自动调用（init模式）
cd ~/master/k8s/sunmoonai/infrastructure
./deploy-infrastructure-all.sh
```

## 🔧 配置说明

### 5层架构编码

系统使用5位编码标识不同的部署组合：

```
TRAEFIK_K1_K1 = TRAEFIK-K-1-K-1
├── TRAEFIK: Traefik (服务类型)
├── K: K8s (服务端环境)  
├── 1: 节点1 (服务端节点)
├── K: K8s (客户端环境)
└── 1: 节点1 (客户端节点)
```

### 支持的组合类型

| 服务类型 | 服务端环境 | 客户端环境 | 示例组合 |
|---------|-----------|-----------|----------|
| Traefik (TRAEFIK) | K8s (K) | K8s (K) | TRAEFIK_K1_K1 |
| Traefik (TRAEFIK) | K8s (K) | Docker (D) | TRAEFIK_K1_D1 |
| Traefik (TRAEFIK) | K8s (K) | nerdctl (N) | TRAEFIK_K1_N1 |

### 证书配置规范

系统遵循X.509标准和现代浏览器要求：

#### 服务器证书配置
```bash
# CN使用根域名（标准做法）
TRAEFIK_K1_K1_SERVER_CN="sunmoonai.com"

# 通配符域名放在DNS列表中（SANs）
TRAEFIK_K1_K1_SERVER_DNS_2="*.sunmoonai.com"
TRAEFIK_K1_K1_SERVER_DNS_3="localhost"

# IP地址列表
TRAEFIK_K1_K1_SERVER_IP_1="115.190.64.131"
TRAEFIK_K1_K1_SERVER_IP_2="192.168.3.89"
TRAEFIK_K1_K1_SERVER_IP_3="127.0.0.1"
```

**生成的证书结构**：
- CN = `sunmoonai.com`（主域名）
- DNS.1 = `sunmoonai.com`（自动从CN设置）
- DNS.2 = `*.sunmoonai.com`（通配符，覆盖所有子域名）
- DNS.3 = `localhost`（本地开发）
- IP.1 = `115.190.64.131`
- IP.2 = `192.168.3.89`
- IP.3 = `127.0.0.1`
- keyUsage = `digitalSignature, keyEncipherment`（不包含dataEncipherment）

#### CA证书配置
```bash
# CA证书配置（有效期10年）
TRAEFIK_K1_K1_CA_CN="SunMoonAI Root CA"
TRAEFIK_K1_K1_CA_DAYS="3650"
TRAEFIK_K1_K1_CA_KEY_SIZE="4096"
```

### 配置文件结构示例

```bash
# 启用配置
TRAEFIK_K1_K1_ENABLED="true"

# 服务端配置
TRAEFIK_K1_K1_SERVER_HOST="115.190.64.131"
TRAEFIK_K1_K1_SERVER_PORT="1022"
TRAEFIK_K1_K1_SERVER_USERNAME="zym"
TRAEFIK_K1_K1_SERVER_SSH_KEY="~/.ssh/id_rsa"

# CA证书配置
TRAEFIK_K1_K1_CA_CN="SunMoonAI Root CA"
TRAEFIK_K1_K1_CA_DAYS="3650"
TRAEFIK_K1_K1_CA_KEY_SIZE="4096"

# 服务器证书配置（遵循server-specifications规范）
TRAEFIK_K1_K1_SERVER_CN="sunmoonai.com"
TRAEFIK_K1_K1_SERVER_DAYS="365"
TRAEFIK_K1_K1_SERVER_KEY_SIZE="4096"
TRAEFIK_K1_K1_SERVER_DNS_2="*.sunmoonai.com"
TRAEFIK_K1_K1_SERVER_DNS_3="localhost"
TRAEFIK_K1_K1_SERVER_IP_1="115.190.64.131"
TRAEFIK_K1_K1_SERVER_IP_2="192.168.3.89"
TRAEFIK_K1_K1_SERVER_IP_3="127.0.0.1"

# 客户端配置（K8s环境）
TRAEFIK_K1_K1_CLIENT_NODES="node1,node2,node3"
TRAEFIK_K1_K1_CLIENT_NODE_HOSTS="115.190.64.131,101.126.151.0,115.190.61.238"
TRAEFIK_K1_K1_CLIENT_CONTAINERD_PATH="/etc/containerd/certs.d/www.sunmoonai.com:30443"

# 客户端配置（Docker环境）
TRAEFIK_K1_D1_CLIENT_HOST="60.204.132.69"
TRAEFIK_K1_D1_CLIENT_DOCKER_PATH="/etc/docker/certs.d/www.sunmoonai.com:30443"

# Kubernetes Secret配置
TRAEFIK_K1_K1_SECRET_0_TYPE="kubernetes.io/tls"
TRAEFIK_K1_K1_SECRET_0_NAME="traefik-tls-secret"
TRAEFIK_K1_K1_SECRET_0_NAMESPACE="ingress-platform-dev"
TRAEFIK_K1_K1_SECRET_0_APPLY_REMOTE="false"
TRAEFIK_K1_K1_SECRET_0_RESTART_COMPONENTS="false"
TRAEFIK_K1_K1_SECRET_0_RESTART_COMPONENTS_LIST="traefik-sunmoonai"
```

## 🔄 工作流程

### 初始化模式流程 (init)

**服务端脚本执行**：
1. 调用 `generate_ca_certificate()` 生成CA证书
   - 检查归档目录中是否存在CA证书（归档目录为唯一依据）
   - 如果不存在，生成新CA证书并立即归档到归档目录
   - 如果已存在，从归档目录复制到临时目录
   - **注意**：CA证书归档由 `generate_ca_certificate()` 函数统一处理
2. 跳过服务器证书生成
3. 跳过Secret部署
4. 跳过组件重启

**客户端脚本执行**：
1. 分发CA证书到所有客户端节点
   - K8s环境：分发到所有配置的节点（`CLIENT_NODES`）
   - Docker环境：分发到单个节点，自动重启Docker服务
   - nerdctl环境：分发到单个节点，证书动态加载

### 轮换模式流程 (rotate)

**服务端脚本执行**：
1. 调用 `generate_ca_certificate()` 处理CA证书
   - 检查归档目录中是否存在CA证书
   - 如果已存在，从归档目录复制到临时目录，跳过生成（保护根证书）
   - 如果不存在，生成新CA证书并立即归档
   - **注意**：CA证书归档由 `generate_ca_certificate()` 函数统一处理
2. 生成服务器证书（如果启用）
3. 归档服务器证书到指定目录
4. 生成并归档Kubernetes Secret YAML
5. 部署Secret到远程K8s集群
6. 重启相关组件以应用新证书

**客户端脚本执行**：
1. 分发CA证书到所有客户端节点
   - K8s环境：分发到所有配置的节点（`CLIENT_NODES`）
   - Docker环境：分发到单个节点，自动重启Docker服务
   - nerdctl环境：分发到单个节点，证书动态加载

### 强制更新模式流程 (force)

**服务端脚本执行**：
1. 调用 `generate_ca_certificate()` 处理CA证书
   - 删除归档目录中已存在的CA证书和私钥
   - 强制重新生成CA证书并立即归档
   - **注意**：CA证书归档由 `generate_ca_certificate()` 函数统一处理
2. 删除已存在的服务器证书和私钥
3. 强制重新生成服务器证书
4. 归档服务器证书到指定目录
5. 生成并归档Kubernetes Secret YAML
6. 部署Secret到远程K8s集群
7. 重启相关组件以应用新证书

**客户端脚本执行**：
1. 分发CA证书到所有客户端节点
   - K8s环境：分发到所有配置的节点（`CLIENT_NODES`）
   - Docker环境：分发到单个节点，自动重启Docker服务
   - nerdctl环境：分发到单个节点，证书动态加载

### 关键原则

1. **CA证书归档**：统一由 `generate_ca_certificate()` 函数处理，服务端脚本不重复归档
2. **服务器证书归档**：由服务端脚本处理
3. **CA证书分发**：统一由客户端脚本处理，所有模式都如此
4. **职责分离**：服务端负责证书生成和Secret管理，客户端负责证书分发

## 🎯 使用场景

### 场景1：Traefik证书管理

```bash
# 为Traefik配置TLS证书
# 1. 编辑配置文件，启用TRAEFIK_K1_K1组合
# 2. 运行一键部署
./rotate-certs.sh

# 结果：
# - 生成Traefik的CA证书和服务器证书
# - 部署到K8s集群
# - 分发CA证书到所有客户端节点
# - 创建/更新Kubernetes TLS Secret
```

### 场景2：定期证书轮换

```bash
# 定期执行证书轮换（建议每月执行）
# 可以设置cron任务
0 0 1 * * ~/master/k8s/utils/unified-cert-secret-management/deploy-all.sh

# 结果：
# - 生成全新的服务器证书（CA证书保持不变）
# - 自动更新所有组件
# - 重启相关组件以应用新证书
# - 无需人工干预
```

### 场景3：证书损坏恢复

```bash
# 证书损坏或泄露时，强制重新生成所有证书
./rotate-certs.sh force

# 结果：
# - 删除所有现有证书（包括CA证书）
# - 强制重新生成完整的证书链
# - 更新所有Secret和组件
# - 重启相关组件以应用新证书
```

### 场景4：多环境部署

```bash
# 同时为多个环境部署证书
# 配置文件中启用多个组合：
# TRAEFIK_K1_K1_ENABLED="true"  # Traefik -> K8s
# TRAEFIK_K1_D1_ENABLED="true"  # Traefik -> Docker
# TRAEFIK_K1_D2_ENABLED="true"  # Traefik -> Docker (节点2)

./deploy-all.sh

# 结果：
# - 自动处理所有启用的组合
# - 每个组合独立部署
# - 错误隔离，单个失败不影响其他
```

## 🔍 状态检查

### 检查已配置的组合

```bash
# 查看所有启用的组合
grep "_ENABLED=\"true\"" cert-secret.conf
```

### 检查证书状态

```bash
# 检查本地临时证书
ls -la /tmp/*-ca-certs/
ls -la /tmp/*-server-certs/

# 检查归档证书
ls -la ~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/
ls -la ~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/server-cert/
```

### 检查Kubernetes Secret

```bash
# 检查TLS Secret
kubectl get secrets -n ingress-platform-dev | grep tls

# 查看Secret详情
kubectl describe secret traefik-tls-secret -n ingress-platform-dev
```

### 检查客户端证书

```bash
# 检查K8s客户端containerd证书
ls -la /etc/containerd/certs.d/www.sunmoonai.com:30443/

# 检查Docker客户端证书
ls -la /etc/docker/certs.d/www.sunmoonai.com:30443/

# 验证证书内容
openssl x509 -in /etc/docker/certs.d/www.sunmoonai.com:30443/ca.crt -text -noout
```

## ⚠️ 重要注意事项

### 1. 运行模式选择
- **init模式**：仅用于K8s系统初始化，只生成和分发CA证书
- **rotate模式**：用于定期维护，CA证书已存在则跳过（保护根证书）
- **force模式**：用于紧急情况，会删除并重新生成所有证书（包括CA）
- **重要**：运行模式只影响CA证书的生成逻辑，不影响服务端和客户端的职责划分

### 2. CA证书保护
- CA证书有效期10年，不应频繁更换
- rotate模式会跳过已存在的CA证书，避免意外覆盖
- 更换CA证书会导致所有由其签发的服务器证书失效
- 只有在force模式下才会强制重新生成CA证书
- **CA证书归档**：统一由 `generate_ca_certificate()` 函数处理，归档目录为唯一依据

### 2.1. 职责划分原则
- **CA证书归档**：由 `generate_ca_certificate()` 函数统一处理，服务端脚本不重复归档
- **服务器证书归档**：由服务端脚本处理
- **CA证书分发**：统一由客户端脚本负责，所有模式都如此
- **职责分离**：服务端负责证书生成和Secret管理，客户端负责证书分发

### 3. 客户端证书分发
- **职责划分**：CA证书分发统一由客户端脚本负责，不受运行模式影响
- **K8s客户端**：支持多节点分发（通过 `CLIENT_NODES` 配置），证书动态加载，无需重启
- **Docker客户端**：单节点分发，分发后自动重启Docker服务（证书需要重启才能生效）
- **nerdctl客户端**：单节点分发，证书动态加载，无需重启（每次操作时自动读取）

### 4. 组件重启
- 只有在rotate和force模式下才会重启组件
- 组件重启由`RESTART_COMPONENTS`配置控制
- 重启优先级由`RESTART_PRIORITY`配置控制（数字越小优先级越高）
- **多 Secret 支持**：`restart_components()` 函数会处理所有启用的 Secret（SECRET_0, SECRET_1, SECRET_2...）的重启配置
  - 对于每个启用的 Secret，如果 `RESTART_COMPONENTS="true"`，则会重启对应的组件列表
  - 多个 Secret 的组件列表会自动去重，避免重复重启同一个组件
  - 例如：如果 SECRET_0 配置重启 `traefik-sunmoonai`，SECRET_1 配置重启 `harbor-core`，两者都会被重启

### 5. 证书规范
- CN必须使用根域名（不使用通配符）
- 通配符域名必须放在SANs中
- keyUsage不包含dataEncipherment（避免浏览器兼容性问题）

## 🛠️ 故障排除

### 常见问题

#### 1. CA证书已存在，跳过生成
**现象**：rotate模式下提示"CA证书已存在，跳过生成"

**原因**：这是正常行为，rotate模式会保护已存在的CA证书

**解决**：
- 如果确实需要重新生成CA证书，使用force模式：
  ```bash
  ./rotate-certs.sh force
  ```

#### 2. Docker客户端证书不生效
**现象**：Docker客户端分发证书后，仍然无法连接

**原因**：Docker需要重启服务才能加载新证书

**解决**：
- 系统会自动重启Docker服务
- 如果自动重启失败，手动重启：
  ```bash
  sudo systemctl restart docker
  ```

#### 3. 证书生成失败
```bash
# 检查OpenSSL
openssl version

# 检查权限
ls -la /tmp/*-certs/

# 检查CA证书是否存在
ls -la /tmp/*-ca-certs/ca.crt
```

#### 4. Kubernetes Secret创建失败
```bash
# 检查kubectl配置
kubectl config current-context

# 检查权限
kubectl auth can-i create secrets -n ingress-platform-dev
```

### 调试模式

```bash
# 启用详细日志
set -x
./deploy-all.sh
```

### 查看运行模式

```bash
# 查看帮助信息（包含所有用法）
./deploy-all.sh --help

# 查看当前模式
echo $TLS_MODE
```

### 测试不同模式

```bash
# 测试初始化模式
./deploy-all.sh init

# 测试轮换模式
./deploy-all.sh rotate

# 测试强制模式
./deploy-all.sh force
```

### 清理和重置

```bash
# 清理临时文件
rm -rf /tmp/*-ca-certs/
rm -rf /tmp/*-server-certs/

# 清理归档证书（谨慎操作）
rm -rf ~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/*
rm -rf ~/master/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/server-cert/*

# 删除Kubernetes Secret
kubectl delete secret traefik-tls-secret -n ingress-platform-dev
```

## 📊 监控和维护

### 证书有效期监控

```bash
# 检查CA证书有效期
openssl x509 -in /tmp/TRAEFIK_K1-ca-certs/ca.crt -noout -dates

# 检查服务器证书有效期
openssl x509 -in /tmp/TRAEFIK_K1-server-certs/server.crt -noout -dates
```

### 自动轮换设置

```bash
# 设置每月1号自动轮换证书
echo "0 0 1 * * ~/master/k8s/utils/unified-cert-secret-management/deploy-all.sh" | crontab -

# 查看cron任务
crontab -l
```

### 日志记录

```bash
# 记录部署日志
./deploy-all.sh 2>&1 | tee /var/log/cert-rotation-$(date +%Y%m%d).log
```

## 📝 最佳实践

### 1. 证书轮换策略
- **定期轮换**：建议每月轮换一次服务器证书
- **CA证书保护**：CA证书不应频繁更换，除非泄露或损坏
- **自动化**：使用cron任务自动执行轮换
- **监控**：记录轮换日志和结果

### 2. 安全考虑
- **私钥保护**：确保私钥文件权限正确（600）
- **证书备份**：定期备份重要证书
- **访问控制**：限制对证书文件的访问
- **证书规范**：遵循X.509标准和现代浏览器要求

### 3. 运维建议
- **测试环境**：先在测试环境验证
- **分批部署**：大规模部署时分批进行
- **回滚准备**：保留旧证书以便回滚
- **监控告警**：设置证书过期告警

## 🎉 总结

统一证书和密钥管理系统提供了完整的证书和密钥生命周期管理：

- **标准证书生成**：遵循X.509标准和现代浏览器要求
- **证书轮换**：`./deploy-all.sh` 自动处理所有证书轮换
- **K8s集成**：通过step12自动调用初始化模式
- **多环境支持**：K8s、Docker、nerdctl等
- **Kubernetes Secret管理**：自动创建和更新TLS Secret
- **智能客户端处理**：Docker自动重启，containerd动态加载
- **组件重启**：自动重启相关组件以应用新证书
- **错误隔离**：单个失败不影响整体
- **易于扩展**：插件化架构支持新服务类型
- **统一接口**：所有功能已合并到 `deploy-all.sh`，支持命令行参数
- **清晰的职责划分**：
  - CA证书归档：由 `generate_ca_certificate()` 函数统一处理
  - 服务器证书归档：由服务端脚本处理
  - CA证书分发：统一由客户端脚本负责（所有模式）
  - 职责分离：服务端负责证书生成和Secret管理，客户端负责证书分发

推荐使用 `./deploy-all.sh` 进行日常的证书轮换！🚀

**注意**：`rotate-certs.sh` 已合并到 `deploy-all.sh`，保留仅为向后兼容。
