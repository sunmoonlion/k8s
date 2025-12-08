# Secret Management 系统调用分析

## 一、实际参数传递方式（代码实现）

### 实际调用示例：Traefik TLS Secret

#### 1. 配置文件定义（generate-server-cert.conf）
```bash
# 共享CA路径（从全局配置读取，或使用默认值）
ROOT_CA_LOCAL_DIR="${ROOT_CA_LOCAL_DIR:-~/k8s/certs/ca/shared}"
```

**关键点**：
- 使用 `${ROOT_CA_LOCAL_DIR:-默认值}` 语法
- 如果环境变量 `ROOT_CA_LOCAL_DIR` 已设置，使用环境变量的值
- 否则使用默认值 `~/k8s/certs/ca/shared`

#### 2. 脚本加载配置（generate-server-cert.sh）
```bash
# 加载配置
CONFIG_FILE="$SCRIPT_DIR/generate-server-cert.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"  # ← 这里加载配置，ROOT_CA_LOCAL_DIR 变量被设置
fi
```

#### 3. 路径展开和构建（generate-server-cert.sh）
```bash
main() {
    # 获取共享CA路径
    local ca_dir="${ROOT_CA_LOCAL_DIR/#\~/$HOME}"  # ← 展开 ~ 符号
    local ca_cert="$ca_dir/ca.crt"                # ← 构建证书路径
    local ca_key="$ca_dir/ca.key"                  # ← 构建私钥路径
    
    # 检查CA是否存在
    if [[ ! -f "$ca_cert" || ! -f "$ca_key" ]]; then
        log_error "共享CA不存在，无法生成服务器证书"
        exit 1
    fi
```

**关键点**：
- `${ROOT_CA_LOCAL_DIR/#\~/$HOME}` 将 `~/k8s/certs/ca/shared` 展开为 `/home/zym/k8s/certs/ca/shared`
- 使用 `${变量/#模式/替换}` 语法进行字符串替换

#### 4. 作为命令行参数传递（generate-server-cert.sh）
```bash
    # 调用证书生成函数
    generate_server_cert_from_ca \
        --ca-cert "$ca_cert" \      # ← 传递 CA 证书路径
        --ca-key "$ca_key" \        # ← 传递 CA 私钥路径
        --server-cn "${SERVER_CN}" \
        --server-dns "${SERVER_DNS:-}" \
        --server-ips "${SERVER_IPS:-}" \
        --output-dir "$output_dir" \
        --days "${SERVER_DAYS:-365}" \
        --key-size "${SERVER_KEY_SIZE:-2048}"
```

**实际传递的路径示例**：
- `--ca-cert "/home/zym/k8s/certs/ca/shared/ca.crt"`
- `--ca-key "/home/zym/k8s/certs/ca/shared/ca.key"`

### 另一种方式：deploy-traefik-tls-secret.sh（不直接调用证书生成）

```bash
# 获取共享CA（用于包含在Secret中）
local ca_dir="${ROOT_CA_LOCAL_DIR/#\~/$HOME}"  # ← 从变量读取（可能从配置文件加载）
local ca_cert="$ca_dir/ca.crt"

# 使用 prepare_tls_secret_data 准备数据
local prepare_args=(
    --tls-crt "$server_cert_dir"
    --tls-key "$server_cert_dir"
)

if [[ -f "$ca_cert" ]]; then
    prepare_args+=(--ca-crt "$ca_cert")  # ← 可选参数，如果CA存在则添加
fi

# 调用函数
temp_data_dir=$(prepare_tls_secret_data "${prepare_args[@]}")
```

### 参数传递的完整流程

```
┌─────────────────────────────────────────────────────────┐
│ 1. 配置源（优先级从高到低）                                │
├─────────────────────────────────────────────────────────┤
│ a) 环境变量: export ROOT_CA_LOCAL_DIR="/custom/path"    │
│ b) 组件配置文件: generate-server-cert.conf               │
│    ROOT_CA_LOCAL_DIR="${ROOT_CA_LOCAL_DIR:-~/k8s/...}" │
│ c) 全局配置文件: ca-management/ca-management.conf        │
│    ROOT_CA_LOCAL_DIR="${ROOT_CA_LOCAL_DIR:-~/k8s/...}" │
│ d) 默认值: ~/k8s/certs/ca/shared                        │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 2. 脚本加载配置                                            │
├─────────────────────────────────────────────────────────┤
│ source "$SCRIPT_DIR/generate-server-cert.conf"          │
│ → 变量 ROOT_CA_LOCAL_DIR 被设置到当前 shell 环境         │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 3. 路径展开                                                │
├─────────────────────────────────────────────────────────┤
│ local ca_dir="${ROOT_CA_LOCAL_DIR/#\~/$HOME}"           │
│ → 将 ~ 替换为 $HOME 的完整路径                          │
│ → 例如: ~/k8s/certs/ca/shared                          │
│      → /home/zym/k8s/certs/ca/shared                    │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 4. 构建文件路径                                            │
├─────────────────────────────────────────────────────────┤
│ local ca_cert="$ca_dir/ca.crt"                          │
│ local ca_key="$ca_dir/ca.key"                           │
│ → ca_cert = "/home/zym/k8s/certs/ca/shared/ca.crt"     │
│ → ca_key  = "/home/zym/k8s/certs/ca/shared/ca.key"     │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 5. 作为命令行参数传递                                      │
├─────────────────────────────────────────────────────────┤
│ generate_server_cert_from_ca \                          │
│     --ca-cert "$ca_cert" \                              │
│     --ca-key "$ca_key" \                                │
│     --server-cn "..." \                                 │
│     ...                                                  │
│ → 函数内部通过 $1, $2 等位置参数解析                     │
│ → 最终使用 openssl 命令生成证书                          │
└─────────────────────────────────────────────────────────┘
```

### 环境变量覆盖示例

如果需要在运行时覆盖 CA 路径：

```bash
# 方式1：通过环境变量
export ROOT_CA_LOCAL_DIR="/custom/ca/path"
bash generate-server-cert.sh

# 方式2：在命令行中设置
ROOT_CA_LOCAL_DIR="/custom/ca/path" bash generate-server-cert.sh
```

### get_ca_paths() 辅助函数的实现

```bash
# secret-management/lib/cert-core.sh
get_ca_paths() {
    # 优先从 ca-management 配置文件读取
    local ca_config_file="$HOME/k8s/utils/ca-management/ca-management.conf"
    local ca_dir=""
    
    if [[ -f "$ca_config_file" ]]; then
        source "$ca_config_file"  # ← 加载配置，设置 ROOT_CA_LOCAL_DIR
        ca_dir="${ROOT_CA_LOCAL_DIR:-~/k8s/certs/ca/shared}"
    else
        ca_dir="${ROOT_CA_LOCAL_DIR:-~/k8s/certs/ca/shared}"
    fi
    
    # 展开路径
    ca_dir="${ca_dir/#\~/$HOME}"  # ← 展开 ~ 符号
    
    local ca_cert="$ca_dir/ca.crt"
    local ca_key="$ca_dir/ca.key"
    
    # 验证文件存在
    if [[ ! -f "$ca_cert" ]]; then
        log_error "CA证书不存在: $ca_cert"
        return 1
    fi
    
    if [[ ! -f "$ca_key" ]]; then
        log_error "CA私钥不存在: $ca_key"
        return 1
    fi
    
    # 返回路径（用|分隔）
    echo "$ca_cert|$ca_key"
    return 0
}
```

**使用方式**：
```bash
CA_PATHS=$(get_ca_paths)
if [[ $? -ne 0 ]]; then
    exit 1
fi

IFS='|' read -r CA_CERT CA_KEY <<< "$CA_PATHS"
# 现在 CA_CERT 和 CA_KEY 包含完整路径
```

## 二、调用位置汇总

### 数据平台组件（已补齐）

#### Kibana
- **路径**: `data-platform/kibana/deploy-kibana/secrets/`
- **Secret 列表**:
  - `harbor-registry-secret/` - Harbor 镜像拉取 Secret
  - `kibana-elasticsearch-secret/` - Kibana 连接 Elasticsearch 的认证 Secret
  - `deploy-secrets-all/` - 统一部署脚本

#### Logstash
- **路径**: `data-platform/logstash/deploy-logstash/secrets/`
- **Secret 列表**:
  - `harbor-registry-secret/` - Harbor 镜像拉取 Secret
  - `logstash-elasticsearch-secret/` - Logstash 连接 Elasticsearch 的认证 Secret
  - `deploy-secrets-all/` - 统一部署脚本

**状态**：已补齐，使用统一模式管理 Secret。

---

### 1. TLS Secret 相关（使用证书生成功能）

#### Traefik TLS Secret
- **路径**: `~/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/`
- **脚本**: 
  - `server-cert/generate-server-cert/generate-server-cert.sh` - 生成服务器证书
  - `deploy-traefik-tls-secret/deploy-traefik-tls-secret.sh` - 部署 TLS Secret
- **功能**: 
  - 使用 `generate_server_cert_from_ca` 生成服务器证书
  - 使用 `generate_tls_secret_yaml` 生成 Secret YAML

### 2. Opaque Secret 相关（非证书类型）

#### 数据平台组件
- **PostgreSQL**:
  - `data-platform/postgresql/deploy-postgresql/secrets/postgresql-auth-secret/`
  - `data-platform/postgresql/deploy-postgresql/secrets/postgresql-mydb-secret/`
  - `data-platform/postgresql/deploy-postgresql/secrets/harbor-registry-secret/`

- **MongoDB**:
  - `data-platform/mongodb/deploy-mongodb/secrets/mongodb-auth-secret/`
  - `data-platform/mongodb/deploy-mongodb/secrets/mongodb-mydb-secret/`
  - `data-platform/mongodb/deploy-mongodb/secrets/harbor-registry-secret/`

- **Redis**:
  - `data-platform/redis/deploy-redis/secrets/redis-auth-secret/`
  - `data-platform/redis/deploy-redis/secrets/redis-myapp-secret/`
  - `data-platform/redis/deploy-redis/secrets/harbor-registry-secret/`

- **Neo4j**:
  - `data-platform/neo4j/deploy-neo4j/secrets/neo4j-secrets/`

- **Elasticsearch**:
  - `data-platform/elasticsearch/deploy-elasticsearch/secrets/elasticsearch-myapp-secret/`

#### CI/CD 平台组件
- **Harbor**:
  - `cicd-platform/harbor/deploy-harbor/secrets/harbor-secret/`

#### 消息平台组件
- **RabbitMQ**:
  - `messaging-platform/rabbitmq/deploy-rabbitmq/secrets/rabbitmq-auth-secret/`
  - `messaging-platform/rabbitmq/deploy-rabbitmq/secrets/harbor-registry-secret/`

## 二、CA 路径传递方式

### 方式1：从 ca-management.conf 读取（推荐）

**配置文件位置**: `~/k8s/utils/ca-management/ca-management.conf`

```bash
# ca-management.conf 中定义
ROOT_CA_LOCAL_DIR="${ROOT_CA_LOCAL_DIR:-~/k8s/certs/ca/shared}"
```

**使用方式**:

#### 方式1.1：直接加载配置文件
```bash
# 加载 CA 配置
source ~/k8s/utils/ca-management/ca-management.conf

# 展开路径
CA_DIR="${ROOT_CA_LOCAL_DIR/#\~/$HOME}"
CA_CERT="$CA_DIR/ca.crt"
CA_KEY="$CA_DIR/ca.key"

# 使用 CA 生成服务器证书
generate_server_cert_from_ca \
    --ca-cert "$CA_CERT" \
    --ca-key "$CA_KEY" \
    --server-cn "myservice.example.com" \
    --output-dir /path/to/output
```

#### 方式1.2：使用辅助函数 get_ca_paths（推荐）
```bash
# 加载 secret-management 的证书生成函数
source ~/k8s/utils/secret-management/lib/cert-core.sh

# 获取 CA 路径（自动从 ca-management.conf 读取）
CA_PATHS=$(get_ca_paths)
if [[ $? -ne 0 ]]; then
    exit 1
fi

IFS='|' read -r CA_CERT CA_KEY <<< "$CA_PATHS"

# 使用 CA 生成服务器证书
generate_server_cert_from_ca \
    --ca-cert "$CA_CERT" \
    --ca-key "$CA_KEY" \
    --server-cn "myservice.example.com" \
    --output-dir /path/to/output
```

### 方式2：在组件配置文件中设置默认值

**示例**: `traefik-tls-secret/server-cert/generate-server-cert/generate-server-cert.conf`

```bash
# 共享CA路径（从全局配置读取，或使用默认值）
ROOT_CA_LOCAL_DIR="${ROOT_CA_LOCAL_DIR:-~/k8s/certs/ca/shared}"
```

**使用方式**:
```bash
# 加载组件配置文件（会读取 ROOT_CA_LOCAL_DIR）
source "$SCRIPT_DIR/generate-server-cert.conf"

# 展开路径
local ca_dir="${ROOT_CA_LOCAL_DIR/#\~/$HOME}"
local ca_cert="$ca_dir/ca.crt"
local ca_key="$ca_dir/ca.key"

# 使用 CA 生成服务器证书
generate_server_cert_from_ca \
    --ca-cert "$ca_cert" \
    --ca-key "$ca_key" \
    --server-cn "${SERVER_CN}" \
    --output-dir "$output_dir"
```

### 方式3：硬编码路径（不推荐，但可行）

```bash
# 必须与 ca-management.conf 中的 ROOT_CA_LOCAL_DIR 一致
CA_CERT="$HOME/k8s/certs/ca/shared/ca.crt"
CA_KEY="$HOME/k8s/certs/ca/shared/ca.key"

generate_server_cert_from_ca \
    --ca-cert "$CA_CERT" \
    --ca-key "$CA_KEY" \
    --server-cn "myservice.example.com" \
    --output-dir /path/to/output
```

## 三、实际调用示例分析

### 示例1：Traefik TLS Secret（完整流程）

**文件**: `traefik-tls-secret/server-cert/generate-server-cert/generate-server-cert.sh`

```bash
# 1. 加载证书生成函数（注意：使用的是 ca-management 的 cert-core.sh）
source "$PROJECT_ROOT/utils/ca-management/lib/cert-core.sh"

# 2. 加载组件配置文件（包含 ROOT_CA_LOCAL_DIR）
source "$SCRIPT_DIR/generate-server-cert.conf"

# 3. 获取共享CA路径
local ca_dir="${ROOT_CA_LOCAL_DIR/#\~/$HOME}"
local ca_cert="$ca_dir/ca.crt"
local ca_key="$ca_dir/ca.key"

# 4. 检查CA是否存在
if [[ ! -f "$ca_cert" || ! -f "$ca_key" ]]; then
    log_error "共享CA不存在，无法生成服务器证书"
    exit 1
fi

# 5. 调用证书生成函数
generate_server_cert_from_ca \
    --ca-cert "$ca_cert" \
    --ca-key "$ca_key" \
    --server-cn "${SERVER_CN}" \
    --server-dns "${SERVER_DNS:-}" \
    --server-ips "${SERVER_IPS:-}" \
    --output-dir "$output_dir" \
    --days "${SERVER_DAYS:-365}" \
    --key-size "${SERVER_KEY_SIZE:-2048}"
```

**文件**: `traefik-tls-secret/deploy-traefik-tls-secret/deploy-traefik-tls-secret.sh`

```bash
# 1. 加载 Secret 生成函数
source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"
source "$PROJECT_ROOT/utils/secret-management/lib/secret-data.sh"

# 2. 加载配置
source "$SCRIPT_DIR/deploy-traefik-tls-secret.conf"

# 3. 获取共享CA（用于包含在Secret中）
local ca_dir="${ROOT_CA_LOCAL_DIR/#\~/$HOME}"
local ca_cert="$ca_dir/ca.crt"

# 4. 准备 TLS Secret 数据
prepare_tls_secret_data \
    --tls-crt "$server_cert_dir" \
    --tls-key "$server_cert_dir" \
    --ca-crt "$ca_cert"  # 可选

# 5. 生成 TLS Secret YAML
generate_tls_secret_yaml \
    --name "$SECRET_NAME" \
    --namespace "$namespace" \
    --tls-crt "$temp_data_dir/tls.crt" \
    --tls-key "$temp_data_dir/tls.key" \
    --ca-crt "$temp_data_dir/ca.crt" \
    --output "$secret_yaml"
```

### 示例2：PostgreSQL Auth Secret（非证书类型）

**文件**: `postgresql-auth-secret/deploy-postgresql-auth-secret/deploy-postgresql-auth-secret.sh`

```bash
# 1. 加载 Secret 生成函数
source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"
source "$PROJECT_ROOT/utils/secret-management/lib/secret-data.sh"

# 2. 加载配置
source "$SCRIPT_DIR/deploy-postgresql-auth-secret.conf"

# 3. 准备 Opaque Secret 数据（不需要CA）
local temp_data_dir=$(mktemp -d)
echo -n "${admin_password}" > "$temp_data_dir/admin_password"
echo -n "${dev_password}" > "$temp_data_dir/dev_password"

# 4. 生成 Opaque Secret YAML
generate_opaque_secret_yaml \
    --name "$SECRET_NAME" \
    --namespace "$namespace" \
    --data-dir "$temp_data_dir" \
    --output "$secret_yaml"
```

## 四、总结

### CA 路径传递的统一模式

1. **配置源**: `~/k8s/utils/ca-management/ca-management.conf`
   - 定义 `ROOT_CA_LOCAL_DIR` 变量
   - 默认值: `~/k8s/certs/ca/shared`

2. **传递方式**:
   - **方式1（推荐）**: 使用 `get_ca_paths()` 辅助函数，自动从配置读取并验证
   - **方式2**: 直接加载 `ca-management.conf`，手动展开路径
   - **方式3**: 在组件配置文件中设置默认值，通过环境变量传递

3. **路径展开**:
   - 使用 `${ROOT_CA_LOCAL_DIR/#\~/$HOME}` 将 `~` 展开为完整路径
   - CA 证书: `$CA_DIR/ca.crt`
   - CA 私钥: `$CA_DIR/ca.key`

4. **使用场景**:
   - **需要CA**: TLS Secret 生成（需要 `generate_server_cert_from_ca`）
   - **不需要CA**: Opaque Secret、Docker Secret、Basic Auth Secret 等

### 调用统计

- **TLS Secret 相关**: 1 个（Traefik）
- **Opaque Secret 相关**: 约 15+ 个（PostgreSQL、MongoDB、Redis、Neo4j、Elasticsearch、RabbitMQ、Harbor等）
- **Docker Secret 相关**: 约 5+ 个（Harbor registry secrets）

所有调用都通过 `source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"` 加载核心函数。

