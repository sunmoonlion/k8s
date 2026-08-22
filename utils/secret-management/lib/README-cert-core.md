# 证书生成核心函数库使用指南

## 概述

`cert-core.sh` 提供**服务器证书生成**的核心函数（基于已有 CA），所有函数都是纯函数设计，通过参数传递所有配置。

⚠️ **重要**：此模块只提供服务器证书生成，**不提供 CA 生成功能**。CA 的生成和管理请使用 `~/master/k8s/utils/ca-management/` 模块。

## 重要：CA路径配置一致性

⚠️ **必须确保CA存放路径和调用路径一致！**

### 统一配置路径

CA路径统一在 `ca-management/ca-management.conf` 中配置：

```bash
# ca-management/ca-management.conf
ROOT_CA_LOCAL_DIR="${ROOT_CA_LOCAL_DIR:-~/master/k8s/certs/ca/shared}"
```

### 使用流程

#### 步骤1：生成CA（使用统一路径）

```bash
cd ~/master/k8s/utils/ca-management

# 自动读取 ca-management/ca-management.conf 中的 ROOT_CA_LOCAL_DIR
./generate-ca.sh

# 或者手动指定路径（会覆盖配置文件）
./generate-ca.sh --output-dir ~/master/k8s/certs/ca/shared
```

CA会生成到：`~/master/k8s/certs/ca/shared/ca.crt` 和 `ca.key`

#### 步骤2：组件使用CA生成服务器证书（使用相同路径）

**方式1：使用辅助函数（推荐）**

```bash
source ~/master/k8s/utils/secret-management/lib/cert-core.sh

# 加载配置文件（包含 ROOT_CA_LOCAL_DIR）
source ~/master/k8s/utils/ca-management/ca-management.conf

# 使用辅助函数获取CA路径
CA_PATHS=$(get_ca_paths)
if [[ $? -ne 0 ]]; then
    exit 1
fi

IFS='|' read -r CA_CERT CA_KEY <<< "$CA_PATHS"

# 使用获取到的CA路径生成服务器证书
generate_server_cert_from_ca \
    --ca-cert "$CA_CERT" \
    --ca-key "$CA_KEY" \
    --server-cn "postgresql-c1.sunmoonai.com" \
    --server-dns "postgresql-c1.sunmoonai.com" \
    --output-dir "$SECRET_DIR/server-cert"
```

**方式2：直接从配置文件读取（推荐）**

```bash
source ~/master/k8s/utils/secret-management/lib/cert-core.sh

# 加载配置文件
source ~/master/k8s/utils/ca-management/ca-management.conf

# 展开路径
CA_DIR="${ROOT_CA_LOCAL_DIR/#\~/$HOME}"
CA_CERT="$CA_DIR/ca.crt"
CA_KEY="$CA_DIR/ca.key"

# 检查CA是否存在
if [[ ! -f "$CA_CERT" || ! -f "$CA_KEY" ]]; then
    log_error "CA不存在，请先运行: ./generate-ca.sh"
    exit 1
fi

# 使用CA生成服务器证书
generate_server_cert_from_ca \
    --ca-cert "$CA_CERT" \
    --ca-key "$CA_KEY" \
    --server-cn "postgresql-c1.sunmoonai.com" \
    --output-dir "$SECRET_DIR/server-cert"
```

**方式3：硬编码路径（不推荐，但可行）**

```bash
# 必须与 ca-management/ca-management.conf 中的 ROOT_CA_LOCAL_DIR 一致
CA_CERT="$HOME/k8s/certs/ca/shared/ca.crt"
CA_KEY="$HOME/k8s/certs/ca/shared/ca.key"

generate_server_cert_from_ca \
    --ca-cert "$CA_CERT" \
    --ca-key "$CA_KEY" \
    --server-cn "postgresql-c1.sunmoonai.com" \
    --output-dir "$SECRET_DIR/server-cert"
```

## 函数列表

### 1. generate_server_cert_from_ca
使用CA生成服务器证书

**参数：**
- `--ca-cert`: CA证书文件路径（必需）
- `--ca-key`: CA私钥文件路径（必需）
- `--server-cn`: 服务器CN（必需）
- `--server-dns`: DNS列表（逗号分隔，可选）
- `--server-ips`: IP列表（空格分隔，可选）
- `--output-dir`: 输出目录（必需）
- `--days`: 有效期（天，默认：365）
- `--key-size`: 密钥长度（默认：2048）

**示例：**
```bash
generate_server_cert_from_ca \
    --ca-cert ~/master/k8s/certs/ca/shared/ca.crt \
    --ca-key ~/master/k8s/certs/ca/shared/ca.key \
    --server-cn "postgresql-c1.sunmoonai.com" \
    --server-dns "postgresql-c1.sunmoonai.com,postgresql.sunmoonai.com" \
    --server-ips "115.190.64.131 192.168.2.50" \
    --output-dir ~/master/k8s/certs/server/postgresql \
    --days 365 \
    --key-size 2048
```

### 2. get_ca_paths（辅助函数）
从配置读取CA路径并验证

**返回值：**
- 成功：输出 `ca_cert_path|ca_key_path`
- 失败：返回错误码1，输出错误信息

**示例：**
```bash
CA_PATHS=$(get_ca_paths)
if [[ $? -eq 0 ]]; then
    IFS='|' read -r CA_CERT CA_KEY <<< "$CA_PATHS"
    echo "CA证书: $CA_CERT"
    echo "CA私钥: $CA_KEY"
fi
```

## 路径配置检查清单

✅ **确保一致性：**

1. **生成CA时**：
   ```bash
   # 使用配置文件中的路径
   ./generate-ca.sh
   
   # 或手动指定（必须与配置一致）
   ./generate-ca.sh --output-dir ~/master/k8s/certs/ca/shared
   ```

2. **组件调用时**：
   ```bash
   # 加载 secret-management 的证书生成函数
   source ~/master/k8s/utils/secret-management/lib/cert-core.sh
   
   # 方式1：从配置文件读取（推荐）
   source ~/master/k8s/utils/ca-management/ca-management.conf
   CA_DIR="${ROOT_CA_LOCAL_DIR/#\~/$HOME}"
   CA_CERT="$CA_DIR/ca.crt"
   CA_KEY="$CA_DIR/ca.key"
   
   # 方式2：使用辅助函数（推荐）
   CA_PATHS=$(get_ca_paths)
   IFS='|' read -r CA_CERT CA_KEY <<< "$CA_PATHS"
   ```

3. **配置文件**：
   ```bash
   # ca-management/ca-management.conf
   ROOT_CA_LOCAL_DIR="${ROOT_CA_LOCAL_DIR:-~/master/k8s/certs/ca/shared}"
   ```

## 常见问题

### Q: 如何生成CA证书？
**A:** 此模块不提供CA生成功能。请使用 `ca-management` 模块：
```bash
cd ~/master/k8s/utils/ca-management
./generate-ca.sh
```

### Q: CA路径不一致导致找不到文件？
**A:** 确保：
1. `generate-ca.sh` 使用 `ca-management/ca-management.conf` 中的 `ROOT_CA_LOCAL_DIR`
2. 组件调用时也从同一配置文件读取该路径
3. 使用 `get_ca_paths()` 辅助函数自动验证路径

### Q: 如何修改CA存放路径？
**A:** 
1. 修改 `ca-management/ca-management.conf` 中的 `ROOT_CA_LOCAL_DIR`
2. 重新运行 `~/master/k8s/utils/ca-management/generate-ca.sh`（会在新路径生成CA）
3. 确保所有组件都从配置文件读取路径

### Q: 多个组件都需要CA，如何保证路径一致？
**A:** 所有组件都从 `ca-management/ca-management.conf` 读取 `ROOT_CA_LOCAL_DIR`，确保使用同一个配置源。

