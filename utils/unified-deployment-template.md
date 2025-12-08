# 统一部署模板脚本使用说明 - 重构版本

## 概述

`unified-deployment-template.sh` 是一个专注于提供基础设施服务的统一模板脚本。经过重构后，它专注于 Kubernetes 连接管理和镜像检查功能，移除了部署执行逻辑、路径计算和模板变量处理，这些功能现在由各组件独立处理。

**重要更新**：脚本现在位于 `k8s/utils/` 目录下，使用 `k8s-admin.conf` 作为默认配置文件。

## 核心功能

### 1. Kubernetes 连接管理
- **自动连接建立**: 支持跳板机模式和直接访问模式
- **智能环境切换**: 自动在本地和远程集群间切换
- **连接状态管理**: 维护连接状态，支持自动重连
- **环境变量管理**: 自动设置和清理 `KUBECONFIG` 环境变量
- **连接清理**: 脚本退出时自动清理连接资源

### 2. 镜像检查功能
- **远程镜像检查**: 检查远程集群中的镜像
- **镜像仓库检查**: 检查镜像仓库可访问性
- **镜像列表生成**: 生成镜像列表文件

### 3. 基础工具函数
- **日志函数**: 所有日志函数 (log_info, log_success, log_warn, log_error)
- **颜色定义**: 彩色输出支持
- **信号处理**: 优雅退出和资源清理

## 架构设计

### 1. 职责分离

#### 统一模板脚本职责（保留）
- ✅ **Kubernetes 连接管理**
  - SSH 隧道建立
  - kubeconfig 获取和配置
  - 连接状态管理
  - 错误处理和重连机制

- ✅ **镜像检查功能**
  - `check_component_images()`
  - `check_remote_images()`
  - `check_registry_accessibility()`
  - `generate_image_list()`

- ✅ **基础工具函数**
  - 所有日志函数 (log_info, log_success, log_warn, log_error)
  - 颜色定义
  - 信号处理

#### 移除功能（由各组件处理）
- ❌ 部署执行逻辑
- ❌ 路径计算
- ❌ 模板变量处理

### 2. 各组件独立部署

每个组件的 `deploy.sh` 负责自己的部署逻辑：

#### 文件结构
```
component/
├── deploy/
│   ├── deploy-component.sh        # 部署脚本
│   └── deploy-component.conf      # 环境变量配置（保留）
└── resources/
    ├── component/
    │   └── values.yaml            # 官方配置
    └── custom/
        └── values/
            ├── dev-values.yaml     # 开发环境配置
            └── prod-values.yaml    # 生产环境配置
```

#### 配置文件说明
- **`deploy-component.conf`**: 环境变量和基本配置（保留）
- **`dev-values.yaml`**: 开发环境配置，直接写具体值
- **`prod-values.yaml`**: 生产环境配置，直接写具体值
- **官方 `values.yaml`**: 作为基础配置

## 核心函数

### 1. Kubernetes 连接管理函数
```bash
check_kubectl()                        # 检查 kubectl 是否可用
read_k8s_config()                      # 读取 Kubernetes 连接配置
save_k8s_status()                      # 保存连接状态
load_k8s_status()                      # 加载连接状态
clear_k8s_status()                     # 清理连接状态
check_k8s_connection_status()          # 检查连接状态（包含重试逻辑）
start_k8s_connection()                 # 建立 Kubernetes 连接
stop_k8s_connection_quiet()            # 静默停止连接
setup_kubectl_environment()            # 设置 kubectl 环境
cleanup_k8s_connection()               # 清理连接资源
```

### 2. 镜像检查函数
```bash
check_component_images()               # 主镜像检查函数
check_remote_images()                  # 检查远程镜像
check_registry_accessibility()         # 检查镜像仓库
generate_image_list()                  # 生成镜像列表
```

### 3. 工具函数
```bash
log_info()                             # 信息日志
log_success()                          # 成功日志
log_warn()                             # 警告日志
log_error()                            # 错误日志
```

## 配置文件

### k8s-admin.conf

脚本现在使用 `k8s-admin.conf` 作为默认配置文件，支持跳板机模式和直接访问模式：

```ini
# 全局配置
[GLOBAL]
default_mode=direct                    # 默认访问方式 (bastion/direct)
auto_stop=true                         # 自动停止连接
timeout=30                             # 连接超时时间

# 跳板机模式配置
[BASTION]
host=47.103.135.26:1022               # 跳板机地址
user=zym                              # SSH 用户名
secret=~/.ssh/id_rsa                  # 私钥文件路径
api_server=101.126.151.0:1022         # API 服务器地址
api_port=6443                         # Kubernetes API 端口
local_port=6443                       # 本地绑定端口
kubeconfig=~/.kube/cluster-admin.conf # Kubeconfig 保存路径

# 直接访问模式配置
[DIRECT]
host=101.126.151.0:1022               # API 服务器地址
user=zym                              # SSH 用户名
secret=~/.ssh/id_rsa                  # 私钥文件路径
local_port=6443                       # 本地绑定端口
kubeconfig=~/.kube/cluster-admin.conf # Kubeconfig 保存路径
```

## 在组件部署脚本中使用

### 1. 引入统一模板脚本

```bash
#!/bin/bash

# 引入统一部署模板脚本
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"
```

### 2. 使用基础设施服务

```bash
# 设置 Kubernetes 环境
if ! setup_kubectl_environment; then
    log_error "无法建立 Kubernetes 连接"
    exit 1
fi

# 检查镜像
local required_images=$(define_required_images "$environment")
if ! check_component_images "$project_id" "$namespace" "redis" "$environment" "$required_images" "remote"; then
    log_error "镜像检查失败，部署终止"
    exit 1
fi
```

### 3. 完整示例

```bash
#!/bin/bash
set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 导入基础设施服务
source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"

# 加载组件配置文件
source "$SCRIPT_DIR/deploy-redis.conf"

# 定义镜像列表
define_required_images() {
    local environment="$1"
    case "$environment" in
        "production")
            echo "bitnami/redis:8.2.1-debian-12-r0|true"
            ;;
        "development")
            echo "bitnami/redis:8.2.1-debian-12-r0|true"
            ;;
    esac
}

# 部署函数
deploy_redis() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    # 设置 Kubernetes 环境
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        return 1
    fi
    
    # 检查镜像
    if [[ "$dry_run" != "true" ]]; then
        local required_images=$(define_required_images "$environment")
        if ! check_component_images "$project_id" "$namespace" "redis" "$environment" "$required_images" "remote"; then
            log_error "镜像检查失败，部署终止"
            return 1
        fi
    fi
    
    # 构建 Helm 命令（使用固定路径）
    local release_name="${project_id}-redis"
    local chart_path="$PROJECT_ROOT/resources/redis"
    
    # 配置文件列表（使用固定路径）
    local values_files=(
        "$PROJECT_ROOT/resources/redis/values.yaml"
    )
    
    case "$environment" in
        "development")
            values_files+=("$PROJECT_ROOT/resources/custom/values/dev-values.yaml")
            ;;
        "production")
            values_files+=("$PROJECT_ROOT/resources/custom/values/prod-values.yaml")
            ;;
    esac
    
    # 执行部署
    local helm_cmd
    if helm list -n "$namespace" | grep -q "$release_name"; then
        helm_cmd="helm upgrade $release_name $chart_path"
    else
        helm_cmd="helm install $release_name $chart_path"
    fi
    
    helm_cmd="$helm_cmd --namespace $namespace --create-namespace"
    
    # 添加 values 文件
    for values_file in "${values_files[@]}"; do
        if [[ -f "$values_file" ]]; then
            helm_cmd="$helm_cmd -f $values_file"
        fi
    done
    
    helm_cmd="$helm_cmd --wait --timeout=10m"
    if [[ "$dry_run" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
    fi
    
    # 执行部署
    eval "$helm_cmd"
}
```

## Kubernetes 连接管理

### 1. 连接模式

#### 跳板机模式 (Bastion)
- 通过跳板机访问远程 Kubernetes 集群
- 支持 SSH 隧道转发
- 适用于网络隔离环境

#### 直接访问模式 (Direct)
- 直接访问 Kubernetes 集群
- 适用于网络可达环境
- 更简单的连接配置

#### 本地集群模式 (Local)
- 使用本地 Kubernetes 集群
- 适用于本地开发环境

### 2. 环境切换

#### 本地集群
```bash
# 使用本地集群
unset KUBECONFIG
kubectl get nodes
```

#### 远程集群
```bash
# 使用远程集群
export KUBECONFIG=~/.kube/cluster-admin.conf
kubectl get nodes
```

### 3. 自动连接管理

脚本会自动：
- 建立 SSH 隧道连接
- 获取远程 kubeconfig 配置
- 处理 TLS 证书验证
- 设置环境变量
- 验证连接状态
- 清理连接资源

### 4. 连接状态管理

脚本维护连接状态信息：
- 当前连接模式
- 连接时间戳
- 本地端口绑定
- 进程 ID 信息

## 镜像检查功能

### 1. 检查类型

#### 远程镜像检查
- 检查远程集群中的镜像
- 验证镜像是否可用于部署
- 提供详细的缺失镜像信息

#### 镜像仓库检查
- 检查镜像仓库可访问性
- 验证镜像是否可拉取
- 支持多种镜像仓库

#### 镜像列表生成
- 生成镜像列表文件
- 便于镜像管理和导入
- 支持批量操作

### 2. 使用示例

```bash
# 检查远程镜像
check_component_images "project_id" "namespace" "redis" "production" "bitnami/redis:8.2.1-debian-12-r0|true" "remote"

# 检查镜像仓库
check_component_images "project_id" "namespace" "redis" "production" "bitnami/redis:8.2.1-debian-12-r0|true" "registry"

# 生成镜像列表
check_component_images "project_id" "namespace" "redis" "production" "bitnami/redis:8.2.1-debian-12-r0|true" "list"

# 检查所有
check_component_images "project_id" "namespace" "redis" "production" "bitnami/redis:8.2.1-debian-12-r0|true" "all"
```

## 错误处理和调试

### 1. 常见错误

#### 连接错误
- **SSH 连接失败**: 检查网络连接和认证信息
- **权限不足**: 检查 sudo 权限和文件访问权限
- **端口冲突**: 检查本地端口是否被占用

#### 镜像检查错误
- **镜像缺失**: 使用 packages-management.sh 导入镜像
- **仓库不可访问**: 检查网络连接和认证信息
- **节点信息获取失败**: 检查集群状态

### 2. 调试模式

```bash
# 启用详细日志
export DEBUG=true

# 检查连接状态
setup_kubectl_environment

# 检查镜像
check_component_images "project_id" "namespace" "component" "environment" "images" "remote"
```

### 3. 日志级别

- **INFO**: 一般信息
- **SUCCESS**: 成功操作
- **WARN**: 警告信息
- **ERROR**: 错误信息

## 最佳实践

### 1. 组件开发
- 使用固定路径，不做动态计算
- 直接使用具体的 values 文件，不做模板替换
- 在 `deploy-component.conf` 中集中管理所有配置
- 遵循统一的目录结构

### 2. 连接管理
- 使用独立的配置文件管理连接参数
- 避免在脚本中硬编码连接信息
- 定期清理连接状态文件
- 使用 SSH 密钥认证提高安全性

### 3. 镜像管理
- 部署前检查镜像可用性
- 使用镜像列表文件管理镜像
- 定期更新镜像版本
- 建立镜像备份和恢复机制

### 4. 错误处理
- 始终进行前置条件检查
- 提供详细的错误信息
- 实现优雅的错误恢复
- 记录完整的操作日志

## 兼容性说明

### 1. 与旧版本的兼容性
- 保持了原有的连接管理接口
- 支持现有的配置文件格式
- 向后兼容的环境变量

### 2. 迁移指南
- 更新组件脚本的 source 路径（从 `infrastructure/utils/unified-deployment-template/` 改为 `utils/`）
- 检查配置文件路径（现在使用 `k8s-admin.conf`）
- 验证连接参数设置
- 移除模板变量处理逻辑

### 3. 重构后的变化
- 脚本位置：`k8s/utils/unified-deployment-template.sh`
- 配置文件：`k8s/utils/k8s-admin.conf`
- 相关工具：`k8s/utils/storage-manager.sh`、`k8s/utils/k8s-connection-manager.sh`

## 扩展和定制

### 1. 添加新连接模式
1. 在 `start_k8s_connection()` 函数中添加新的连接模式
2. 在配置文件中添加相应的配置项
3. 实现对应的连接建立和清理逻辑

### 2. 扩展镜像检查
1. 在 `check_component_images()` 函数中添加新的检查类型
2. 实现新的检查逻辑
3. 添加相应的配置选项

### 3. 自定义工具函数
1. 在脚本中添加新的工具函数
2. 保持函数命名的一致性
3. 添加相应的文档说明

## 使用说明

### 1. 直接使用脚本

```bash
# 设置 kubectl 环境
./unified-deployment-template.sh setup-kubectl

# 检查镜像
./unified-deployment-template.sh check-images project_id namespace component environment "images" remote

# 清理连接资源
./unified-deployment-template.sh cleanup
```

### 2. 在组件脚本中使用

```bash
# 导入脚本
source "path/to/utils/unified-deployment-template.sh"

# 使用基础设施服务
setup_kubectl_environment
check_component_images "project_id" "namespace" "component" "environment" "images" "remote"
```

---

*最后更新: 2024-12-19*