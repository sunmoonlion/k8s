# Secret 管理系统

Kubernetes Secret 生成和管理系统，支持多种 Secret 类型。

## 目录结构

```
secret-management/
├── cert-secret.conf          # Secret 管理配置
├── lib/
│   ├── secret-core.sh        # Secret 生成核心函数库
│   ├── secret-data.sh        # Secret 数据准备库
│   ├── cert-core.sh          # 服务器证书生成函数（基于 CA 生成服务器证书）
│   ├── README-secret-core.md # Secret 生成函数使用指南
│   └── README-cert-core.md   # 证书生成函数使用指南
└── README.md                 # 本文档
```

## 支持的 Secret 类型

1. **TLS Secret** (`kubernetes.io/tls`) - TLS 证书和私钥
2. **Docker Secret** (`kubernetes.io/dockerconfigjson`) - Docker 仓库认证
3. **Opaque Secret** (`Opaque`) - 任意键值对数据
4. **Basic Auth Secret** (`kubernetes.io/basic-auth`) - 基本认证
5. **SSH Auth Secret** (`kubernetes.io/ssh-auth`) - SSH 密钥

## 快速开始

### 生成 TLS Secret

```bash
# 加载 Secret 生成函数
source ~/master/k8s/utils/secret-management/lib/secret-core.sh

# 生成 TLS Secret YAML
generate_tls_secret_yaml \
    --name "my-tls-secret" \
    --namespace "default" \
    --tls-crt /path/to/server.crt \
    --tls-key /path/to/server.key \
    --output my-tls-secret.yaml

# 部署到 Kubernetes
kubectl apply -f my-tls-secret.yaml
```

### 生成 Docker Secret

```bash
source ~/master/k8s/utils/secret-management/lib/secret-core.sh

generate_docker_secret_yaml \
    --name "docker-registry-secret" \
    --namespace "default" \
    --docker-server "registry.example.com" \
    --docker-username "admin" \
    --docker-password "password" \
    --output docker-secret.yaml

kubectl apply -f docker-secret.yaml
```

## 核心函数

### 1. TLS Secret

```bash
generate_tls_secret_yaml \
    --name <secret_name> \
    --namespace <namespace> \
    --tls-crt <cert_path> \
    --tls-key <key_path> \
    [--ca-crt <ca_path>] \
    --output <yaml_path>
```

### 2. Docker Secret

```bash
generate_docker_secret_yaml \
    --name <secret_name> \
    --namespace <namespace> \
    --docker-server <server_url> \
    --docker-username <username> \
    --docker-password <password> \
    [--docker-email <email>] \
    --output <yaml_path>
```

### 3. Opaque Secret

```bash
# 从目录读取所有文件
generate_opaque_secret_yaml \
    --name <secret_name> \
    --namespace <namespace> \
    --data-dir <data_directory> \
    --output <yaml_path>

# 或指定具体文件
generate_opaque_secret_yaml \
    --name <secret_name> \
    --namespace <namespace> \
    --data-file "key1:/path/to/file1" \
    --data-file "key2:/path/to/file2" \
    --output <yaml_path>
```

### 4. Basic Auth Secret

```bash
generate_basic_auth_secret_yaml \
    --name <secret_name> \
    --namespace <namespace> \
    --username <username> \
    --password <password> \
    --output <yaml_path>
```

### 5. SSH Auth Secret

```bash
generate_ssh_auth_secret_yaml \
    --name <secret_name> \
    --namespace <namespace> \
    --ssh-privatekey <private_key_path> \
    [--ssh-publickey <public_key_path>] \
    --output <yaml_path>
```

### 6. 按类型自动选择（推荐）

```bash
generate_secret_yaml_by_type \
    --type "kubernetes.io/tls" \
    --name <secret_name> \
    --namespace <namespace> \
    --tls-crt <cert_path> \
    --tls-key <key_path> \
    --output <yaml_path>
```

## 服务器证书生成

`cert-core.sh` 提供服务器证书生成功能，基于已有的 CA 生成服务器证书。

### 使用示例

```bash
# 加载证书生成函数
source ~/master/k8s/utils/secret-management/lib/cert-core.sh

# 加载 CA 配置（从 ca-management 模块）
source ~/master/k8s/utils/ca-management/ca-management.conf

# 获取 CA 路径
CA_DIR="${ROOT_CA_LOCAL_DIR/#\~/$HOME}"
CA_CERT="$CA_DIR/ca.crt"
CA_KEY="$CA_DIR/ca.key"

# 生成服务器证书
generate_server_cert_from_ca \
    --ca-cert "$CA_CERT" \
    --ca-key "$CA_KEY" \
    --server-cn "myservice.example.com" \
    --server-dns "myservice.example.com,localhost" \
    --server-ips "192.168.1.10 127.0.0.1" \
    --output-dir /path/to/server-cert
```

**注意**：此函数仅生成服务器证书，不生成 CA。CA 的生成和管理请使用 `ca-management` 模块。

## 完整示例

### 生成 TLS Secret（包含服务器证书生成）

```bash
#!/bin/bash

# 1. 加载函数库
source ~/master/k8s/utils/secret-management/lib/cert-core.sh
source ~/master/k8s/utils/secret-management/lib/secret-core.sh
source ~/master/k8s/utils/ca-management/ca-management.conf

# 2. 获取 CA 路径
CA_DIR="${ROOT_CA_LOCAL_DIR/#\~/$HOME}"
CA_CERT="$CA_DIR/ca.crt"
CA_KEY="$CA_DIR/ca.key"

# 3. 生成服务器证书
SERVER_CERT_DIR="/tmp/my-server-cert"
generate_server_cert_from_ca \
    --ca-cert "$CA_CERT" \
    --ca-key "$CA_KEY" \
    --server-cn "myservice.example.com" \
    --server-dns "myservice.example.com" \
    --output-dir "$SERVER_CERT_DIR"

# 4. 生成 TLS Secret YAML
generate_tls_secret_yaml \
    --name "myservice-tls-secret" \
    --namespace "default" \
    --tls-crt "$SERVER_CERT_DIR/server.crt" \
    --tls-key "$SERVER_CERT_DIR/server.key" \
    --output myservice-tls-secret.yaml

# 5. 部署 Secret
kubectl apply -f myservice-tls-secret.yaml
```

## 配置文件

`cert-secret.conf` 用于配置 Secret 相关的默认值（如果需要）。目前主要配置项可通过环境变量或函数参数传递。

## 文档

- **Secret 生成指南**：`lib/README-secret-core.md`
- **证书生成指南**：`lib/README-cert-core.md`

## 设计原则

1. **纯函数设计**：所有函数都是纯函数，无副作用，通过参数传递配置
2. **类型明确**：每种 Secret 类型都有对应的生成函数
3. **灵活配置**：支持参数传递和环境变量配置
4. **独立使用**：可以在任何脚本中加载使用，不依赖特定项目结构
