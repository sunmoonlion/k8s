# 建立 Kubernetes 连接的方法

## 📋 概述

本文档总结了在本地环境中建立远程 Kubernetes 集群连接的方法，适用于需要通过 SSH 隧道访问远程 k8s 集群的场景。

## 🏗️ 项目结构

```
/home/zouyaming/k8s/
├── utils/                                    # 统一工具目录
│   ├── k8s-admin.conf                       # ✅ 配置文件
│   ├── unified-deployment-template.sh       # ✅ 连接管理脚本
│   └── k8s-connection-manager.sh           # 连接管理器
└── sunmoonai/                               # 项目目录
    └── ingress-platform/                    # 入口平台
        └── ingress/
            ├── database/                    # 数据库入口配置
            │   ├── postgres/
            │   │   ├── tcp/
            │   │   │   └── deploy.sh        # 需要连接管理
            │   │   └── web-routes/
            │   │       └── deploy.sh        # 需要连接管理
            │   ├── mongodb/
            │   └── redis/
            └── elk/
                └── deploy-ingress.sh        # 需要连接管理
```

## 🔧 核心组件

### 1. 配置文件：`k8s-admin.conf`

位置：`/home/zouyaming/k8s/utils/k8s-admin.conf`

```ini
# 全局配置
[GLOBAL]
default_mode=direct
auto_stop=true
timeout=30
cluster_mode=remote

# 直接访问模式配置
[DIRECT]
host=115.190.64.131:1022
user=zym
secret=~/.ssh/id_rsa
pass=
sudo_pass=
local_port=6443
remote_api_port=6443
remote_api_host=192.168.2.50
kubeconfig=~/.kube/cluster-admin.conf
bind_alias=true
```

### 2. 连接管理脚本：`unified-deployment-template.sh`

位置：`/home/zouyaming/k8s/utils/unified-deployment-template.sh`

**核心功能**：
- SSH 隧道管理
- 自动重连机制
- 连接状态管理
- 环境变量设置

**关键函数**：
```bash
# 读取配置文件
read_k8s_config()

# 建立连接
setup_kubectl_environment()

# 检查连接状态
check_k8s_connection_status()

# 自动重连
auto_reconnect()
```

## 📝 使用方法

### 1. 在部署脚本中导入连接管理

```bash
#!/bin/bash

# 导入统一部署模板（建立远程 k8s 连接）
source "$(dirname "$0")/../../../../utils/unified-deployment-template.sh"

# 建立远程 k8s 连接
setup_connection() {
    log_info "建立远程 Kubernetes 连接..."
    
    # 读取 Kubernetes 配置
    if ! read_k8s_config; then
        log_error "无法读取 Kubernetes 配置文件"
        exit 1
    fi
    
    # 设置 Kubernetes 环境（建立远程连接）
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        exit 1
    fi
    
    log_success "远程 Kubernetes 连接建立成功"
}

# 在主函数中调用
main() {
    # 建立远程 k8s 连接
    setup_connection
    
    # 执行 kubectl 命令
    kubectl apply -f your-config.yaml --namespace data-platform
}
```

### 2. 路径计算规则

根据项目结构，从不同位置到 `utils/` 目录的相对路径：

| 位置 | 相对路径 |
|------|----------|
| `database/postgres/tcp/` | `../../../../../../utils/` |
| `database/postgres/web-routes/` | `../../../../../../utils/` |
| `database/mongodb/tcp/` | `../../../../../../utils/` |
| `database/mongodb/web-routes/` | `../../../../../../utils/` |
| `database/redis/tcp/` | `../../../../../../utils/` |
| `database/redis/web-routes/` | `../../../../../../utils/` |
| `elk/` | `../../../../utils/` |

**路径计算公式**：
```
从当前位置到 k8s/ 的层级数 + utils/
```

### 3. 连接建立过程

1. **读取配置**：从 `k8s-admin.conf` 读取连接参数
2. **建立 SSH 隧道**：通过 SSH 连接到远程服务器
3. **端口转发**：将本地端口转发到远程 k8s API 端口
4. **获取 kubeconfig**：从远程服务器获取 kubeconfig 文件
5. **设置环境变量**：设置 `KUBECONFIG` 环境变量
6. **状态管理**：保存连接状态，支持自动重连

## 🚀 实际应用示例

### 数据库 TCP 路由部署

```bash
#!/bin/bash
# postgres/tcp/deploy.sh

set -e

# 导入统一部署模板（建立远程 k8s 连接）
source "$(dirname "$0")/../../../../../../utils/unified-deployment-template.sh"

# 建立远程 k8s 连接
setup_connection() {
    log_info "建立远程 Kubernetes 连接..."
    
    if ! read_k8s_config; then
        log_error "无法读取 Kubernetes 配置文件"
        exit 1
    fi
    
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        exit 1
    fi
    
    log_success "远程 Kubernetes 连接建立成功"
}

# 部署函数
deploy() {
    log_info "部署 PostgreSQL TCP 路由..."
    
    if kubectl apply -f postgres-tcp.yaml --namespace data-platform; then
        log_success "PostgreSQL TCP 路由部署成功"
    else
        log_error "PostgreSQL TCP 路由部署失败"
        exit 1
    fi
}

# 主函数
main() {
    local action="${1:-apply}"
    
    # 建立远程 k8s 连接
    setup_connection
    
    case "$action" in
        "apply")
            deploy
            ;;
        "delete")
            kubectl delete -f postgres-tcp.yaml --namespace data-platform
            ;;
        *)
            echo "用法: $0 {apply|delete}"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### ELK Ingress 部署

```bash
#!/bin/bash
# elk/deploy-ingress.sh

set -e

# 导入统一部署模板（建立远程 k8s 连接）
source "$(dirname "$0")/../../../../utils/unified-deployment-template.sh"

# 建立远程 k8s 连接
setup_connection() {
    log_info "建立远程 Kubernetes 连接..."
    
    if ! read_k8s_config; then
        log_error "无法读取 Kubernetes 配置文件"
        exit 1
    fi
    
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        exit 1
    fi
    
    log_success "远程 Kubernetes 连接建立成功"
}

# 主函数
main() {
    local action="${1:-apply}"
    
    # 建立远程 k8s 连接
    setup_connection
    
    case "$action" in
        "apply")
            kubectl apply -f elk-ingress.yaml --namespace data-platform
            ;;
        "delete")
            kubectl delete -f elk-ingress.yaml --namespace data-platform
            ;;
        *)
            echo "用法: $0 {apply|delete}"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## 🔍 连接机制详解

### SSH 隧道建立

```bash
# 直接模式连接
ssh -f -N -L $LOCAL_PORT:$REMOTE_API_HOST:$REMOTE_API_PORT \
    -i $SSH_KEY $USER@$HOST
```

### 环境变量设置

```bash
# 设置 KUBECONFIG 环境变量
export KUBECONFIG=~/.kube/cluster-admin.conf

# 验证连接
kubectl cluster-info
```

### 状态管理

```bash
# 保存连接状态
save_k8s_status() {
    cat > "$STATUS_FILE" << EOF
MODE=$mode
TIMESTAMP=$timestamp
LOCAL_PORT=$local_port
PID=$pid
CURRENT_KUBECONFIG=$CURRENT_KUBECONFIG
EOF
}

# 检查连接状态
check_k8s_connection_status() {
    # 检查进程是否还在运行
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        # 检查端口是否还在监听
        if netstat -tlnp 2>/dev/null | grep -q ":$LOCAL_PORT "; then
            # 测试 kubectl 连接
            if KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get nodes >/dev/null 2>&1; then
                return 0  # 连接正常
            fi
        fi
    fi
    return 1  # 连接异常
}
```

## ⚠️ 注意事项

### 1. 路径计算

- 确保相对路径正确指向 `utils/` 目录
- 不同深度的目录需要不同的相对路径
- 使用 `$(dirname "$0")` 获取脚本所在目录

### 2. 连接管理

- 每次执行脚本都会建立新连接
- 支持自动重连机制
- 脚本结束时自动清理连接

### 3. 错误处理

- 连接失败时脚本会退出
- 提供详细的错误信息
- 支持连接状态检查

### 4. 配置文件

- 确保 `k8s-admin.conf` 配置正确
- SSH 密钥文件路径正确
- 远程服务器信息准确

## 🎯 最佳实践

### 1. 统一连接管理

所有部署脚本都使用相同的连接管理机制，确保一致性。

### 2. 错误处理

```bash
# 建立连接
if ! setup_connection; then
    log_error "无法建立 Kubernetes 连接"
    exit 1
fi

# 执行操作
if kubectl apply -f config.yaml; then
    log_success "操作成功"
else
    log_error "操作失败"
    exit 1
fi
```

### 3. 日志记录

```bash
log_info "建立远程 Kubernetes 连接..."
log_success "远程 Kubernetes 连接建立成功"
log_error "无法建立 Kubernetes 连接"
```

### 4. 资源清理

脚本结束时自动清理 SSH 隧道和连接状态。

## 📚 相关文件

- **配置文件**：`/home/zouyaming/k8s/utils/k8s-admin.conf`
- **连接管理**：`/home/zouyaming/k8s/utils/unified-deployment-template.sh`
- **连接管理器**：`/home/zouyaming/k8s/utils/k8s-connection-manager.sh`
- **使用说明**：`/home/zouyaming/k8s/utils/k8s-admin-README.md`

## 🔄 复用方法

1. **复制连接管理代码**：将 `setup_connection()` 函数复制到新脚本
2. **导入统一模板**：添加 `source` 语句导入连接管理
3. **计算正确路径**：根据脚本位置计算到 `utils/` 的相对路径
4. **在主函数中调用**：在 `main()` 函数开始时调用 `setup_connection()`

---

**文档版本**：v1.0.0  
**最后更新**：2024-09-18  
**适用场景**：本地部署到远程 Kubernetes 集群
