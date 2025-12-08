# Secret 生成核心函数库使用指南

## 概述

`secret-core.sh` 提供了5种Secret类型的YAML生成函数，所有函数都是纯函数设计，通过参数传递所有配置，不依赖组合代码。

## 支持的Secret类型

1. `kubernetes.io/tls` - TLS证书和私钥
2. `kubernetes.io/dockerconfigjson` - Docker镜像拉取认证
3. `Opaque` - 通用数据
4. `kubernetes.io/basic-auth` - 基本认证
5. `kubernetes.io/ssh-auth` - SSH认证

## 使用方式

### 方式1：直接调用特定函数（推荐）

根据Secret类型直接调用对应的函数：

```bash
#!/bin/bash
# 组件部署脚本示例

source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"

# TLS Secret
generate_tls_secret_yaml \
    --name "traefik-tls-secret" \
    --namespace "ingress-platform-dev" \
    --tls-crt "$SERVER_CERT_DIR/server.crt" \
    --tls-key "$SERVER_CERT_DIR/server.key" \
    --ca-crt "$CA_DIR/ca.crt" \
    --output "traefik-tls-secret.yaml"

# Docker Secret
generate_docker_secret_yaml \
    --name "harbor-secret" \
    --namespace "cicd-platform-dev" \
    --docker-server "harbor.sunmoonai.com" \
    --docker-username "admin" \
    --docker-password "Harbor@12345" \
    --docker-email "admin@sunmoonai.com" \
    --output "harbor-secret.yaml"

# Opaque Secret（从数据目录）
generate_opaque_secret_yaml \
    --name "postgresql-auth-secret" \
    --namespace "data-platform-dev" \
    --data-dir "/path/to/data/dir" \
    --output "postgresql-auth-secret.yaml"

# Opaque Secret（从指定文件）
generate_opaque_secret_yaml \
    --name "postgresql-mydb-secret" \
    --namespace "data-platform-dev" \
    --data-file "admin_password:/path/to/admin_password.txt" \
    --data-file "dev_password:/path/to/dev_password.txt" \
    --output "postgresql-mydb-secret.yaml"

# Basic Auth Secret
generate_basic_auth_secret_yaml \
    --name "basic-auth-secret" \
    --namespace "default" \
    --username "admin" \
    --password "admin123" \
    --output "basic-auth-secret.yaml"

# SSH Auth Secret
generate_ssh_auth_secret_yaml \
    --name "ssh-secret" \
    --namespace "default" \
    --ssh-privatekey "/path/to/id_rsa" \
    --ssh-publickey "/path/to/id_rsa.pub" \
    --output "ssh-secret.yaml"
```

### 方式2：根据配置类型自动调用（推荐）

使用 `generate_secret_yaml_by_type` 函数，根据配置的类型自动调用相应函数：

```bash
#!/bin/bash
# 组件部署脚本 - 根据配置自动调用

source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"

# 读取配置
SECRET_TYPE="kubernetes.io/tls"  # 从配置文件读取
SECRET_NAME="traefik-tls-secret"
SECRET_NAMESPACE="ingress-platform-dev"

# 根据类型自动调用相应函数
generate_secret_yaml_by_type \
    --type "$SECRET_TYPE" \
    --name "$SECRET_NAME" \
    --namespace "$SECRET_NAMESPACE" \
    --tls-crt "$SERVER_CERT_DIR/server.crt" \
    --tls-key "$SERVER_CERT_DIR/server.key" \
    --output "traefik-tls-secret.yaml"
```

### 完整示例：组件部署脚本

```bash
#!/bin/bash
# postgresql-tls-secret/deploy-postgresql-tls-secret/deploy-postgresql-tls-secret.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")")")")"

# 加载Secret生成函数
source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"

# 加载配置
source "$SCRIPT_DIR/deploy-postgresql-tls-secret.conf"

main() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    # 1. 获取服务器证书路径
    local server_cert_dir="$SECRET_DIR/server-cert"
    local server_crt="$server_cert_dir/server.crt"
    local server_key="$server_cert_dir/server.key"
    
    # 检查证书是否存在
    if [[ ! -f "$server_crt" || ! -f "$server_key" ]]; then
        log_error "服务器证书不存在，请先运行证书生成脚本"
        exit 1
    fi
    
    # 2. 获取CA路径
    local ca_cert="${ROOT_CA_LOCAL_DIR/#\~/$HOME}/ca.crt"
    
    # 3. 根据配置类型自动生成Secret YAML
    local secret_yaml="$SECRET_DIR/postgresql-tls-secret.yaml"
    
    generate_secret_yaml_by_type \
        --type "$SECRET_TYPE" \
        --name "$SECRET_NAME" \
        --namespace "$namespace" \
        --tls-crt "$server_crt" \
        --tls-key "$server_key" \
        --ca-crt "$ca_cert" \
        --output "$secret_yaml"
    
    # 4. 部署Secret
    if [[ "$dry_run" != "true" ]]; then
        kubectl apply -f "$secret_yaml"
        log_success "Secret已部署: $SECRET_NAME"
    fi
}

main "$@"
```

## 函数列表

### 1. generate_tls_secret_yaml
生成TLS Secret YAML

**参数：**
- `--name`: Secret名称（必需）
- `--namespace`: 命名空间（必需）
- `--tls-crt`: TLS证书文件路径（必需）
- `--tls-key`: TLS私钥文件路径（必需）
- `--ca-crt`: CA证书文件路径（可选）
- `--output`: 输出YAML文件路径（必需）

### 2. generate_docker_secret_yaml
生成Docker认证Secret YAML

**参数：**
- `--name`: Secret名称（必需）
- `--namespace`: 命名空间（必需）
- `--docker-server`: Docker服务器地址（必需）
- `--docker-username`: Docker用户名（必需）
- `--docker-password`: Docker密码（必需）
- `--docker-email`: Docker邮箱（可选）
- `--output`: 输出YAML文件路径（必需）

### 3. generate_opaque_secret_yaml
生成Opaque Secret YAML

**参数：**
- `--name`: Secret名称（必需）
- `--namespace`: 命名空间（必需）
- `--data-dir`: 数据目录路径（与--data-file二选一）
- `--data-file`: 数据文件（格式：key:path，可多个）
- `--output`: 输出YAML文件路径（必需）

### 4. generate_basic_auth_secret_yaml
生成Basic Auth Secret YAML

**参数：**
- `--name`: Secret名称（必需）
- `--namespace`: 命名空间（必需）
- `--username`: 用户名（必需）
- `--password`: 密码（必需）
- `--output`: 输出YAML文件路径（必需）

### 5. generate_ssh_auth_secret_yaml
生成SSH Auth Secret YAML

**参数：**
- `--name`: Secret名称（必需）
- `--namespace`: 命名空间（必需）
- `--ssh-privatekey`: SSH私钥文件路径（必需）
- `--ssh-publickey`: SSH公钥文件路径（可选）
- `--output`: 输出YAML文件路径（必需）

### 6. generate_secret_yaml_by_type（推荐）
根据类型自动调用相应函数

**参数：**
- `--type`: Secret类型（必需）
- `--name`: Secret名称（必需）
- `--namespace`: 命名空间（必需）
- `--output`: 输出YAML文件路径（必需）
- 其他参数根据类型传递

## 注意事项

1. 所有函数都是纯函数，不修改外部状态
2. 所有参数都通过命令行参数传递，不依赖环境变量或配置文件
3. 函数会自动创建输出目录
4. TLS和SSH类型的Secret会设置600权限
5. Base64编码使用 `-w 0` 选项（单行输出）

