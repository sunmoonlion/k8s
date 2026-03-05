# registry-push-management 通用镜像管理工具

> 通用的容器镜像加载、打标、推送工具，**Registry 无关**（支持 Harbor、DockerHub、私有仓库等）

**适用范围**：本工具**仅适用于远程集群**（通过 SSH 在远程节点执行 nerdctl load/tag/push），不适用于 Kind。在操作节点上仅使用 **nerdctl（containerd）**，不支持 Docker。

---

## 📋 目录

- [快速开始](#快速开始)
- [核心概念](#核心概念)
- [架构设计](#架构设计)
- [配置说明](#配置说明)
- [使用方法](#使用方法)
  - [菜单式管理工具](#菜单式管理工具)
  - [命令行工具](#命令行工具)
- [多节点推送](#多节点推送)
- [本地 vs 远程推送](#本地-vs-远程推送)
- [常见问题](#常见问题)
- [最佳实践](#最佳实践)

---

## 快速开始

### 菜单式管理工具（推荐）

我们提供了一个交互式菜单工具，方便配置管理和镜像推送：

```bash
cd ~/k8s/utils/registry-push-management
./registry-push-menu.sh
```

**主菜单功能**：
- **配置管理**：查看和编辑所有配置项（22 个配置项）
- **推送操作**：单个镜像推送、批量推送、目录推送
- **工具功能**：连接测试、状态查看、帮助信息

**配置项列表**（按序号选择）：
1. `LOCAL_IMAGE_DIR` - 本地镜像包目录
2. `REGISTRY_URL` - Registry 地址
3. `PROJECT_NAME` - 项目名称
4. `REGISTRY_USERNAME` - Registry 用户名
5. `REGISTRY_PASSWORD` - Registry 密码
6. `REGISTRY_LOGIN_BEFORE_PUSH` - 推送前自动登录
7. `REMOTE_HOST` - 远程节点 IP
8. `REMOTE_USER` - SSH 用户名
9. `REMOTE_SSH_PORT` - SSH 端口
10. `REMOTE_SECRET` - SSH 私钥路径
11. `REMOTE_PASS` - SSH 密码
12. `REMOTE_IMAGE_DIR` - 远程镜像目录
13. `NERDCTL_BIN` - nerdctl 命令路径
14. `CONTAINERD_NAMESPACE` - containerd 命名空间
15. `USE_SUDO` - 使用 sudo
16. `PUSH_RETRY` - 推送重试次数
17. `PUSH_RETRY_INTERVAL` - 重试间隔
18. `HTTP_PROXY` - HTTP 代理
19. `HTTPS_PROXY` - HTTPS 代理
20. `NO_PROXY` - 不使用代理的地址
21. `EXISTENCE_CHECK_TOOL` - 存在性检查工具
22. `REGISTRY_TLS_VERIFY` - TLS 证书校验

### 命令行工具

直接使用 `loadimage.sh` 进行推送：

```bash
./loadimage.sh push-by-ref nginx:1.21
```

---

## 核心概念

### 三个关键位置

```
┌─────────────────────┐
│  1. 本地开发机       │  ← 镜像 tar 文件存储位置
│  (你的笔记本/CI服务器) │  ← 脚本执行入口
└──────┬──────────────┘
       │ SCP 上传
       ▼
┌─────────────────────┐
│  2. 远程节点         │  ← 执行 load/tag/push 的节点
│  (控制平面/工作节点)  │  ← 有 containerd/nerdctl 环境
│  (跳板机)           │  ← 可以访问 Harbor
└──────┬──────────────┘
       │ HTTPS Push
       ▼
┌─────────────────────┐
│  3. 镜像仓库         │  ← Harbor/DockerHub/私有仓库
│  (Registry)         │  ← 存储容器镜像
└─────────────────────┘
```

### 核心流程

```bash
本地 tar 文件
    ↓ (SCP 传输，通过 SSH)
远程节点磁盘 (临时存储)
    ↓ (nerdctl load，解压)
远程节点 containerd 镜像存储
    ↓ (nerdctl tag，重命名)
远程节点 containerd (新标签)
    ↓ (nerdctl push，HTTP/HTTPS)
Registry 存储
    ↓ (清理临时文件)
远程节点临时文件删除 ✅
```

---

## 架构设计

### 设计理念

1. **Registry 无关**: 不绑定任何特定镜像仓库，可推送到任意 Registry
2. **远程执行**: 在有容器运行时的节点执行操作，本地只需 SSH/SCP
3. **自动化**: 一个命令完成上传→加载→打标→推送→清理全流程
4. **灵活配置**: 支持配置文件默认值，也支持命令行参数覆盖

### 为什么要远程推送？

| 考虑因素 | 本地直接推送 | 远程节点推送（推荐）|
|---------|------------|-------------------|
| **本地环境** | ⚠️ 需要 nerdctl（本工具不支持 Docker） | ✅ 只需 SSH/SCP |
| **网络要求** | ⚠️ 需直连 Registry | ✅ 只需连远程节点 |
| **安全性** | ⚠️ Registry 需对外暴露 | ✅ Registry 可内网隔离 |
| **兼容性** | ⚠️ 依赖本地环境 | ✅ 标准化远程环境 |
| **速度** | ✅ 更快（少一次传输） | ⚠️ 多一次 SCP 传输 |
| **适用场景** | 开发调试、快速测试 | 生产部署、CI/CD |

---

## 配置说明

### 配置文件位置

```bash
~/k8s/utils/registry-push-management/loadimage.conf
```

### 核心配置项

```bash
# ============================================================================
# 镜像仓库配置（推送目标）
# ============================================================================
# Registry 地址（不含协议）
# 留空时，使用命令需传入完整 target_ref
REGISTRY_URL=""              # 例如: www.sunmoonai.com:30443
                             #      registry.example.com:5000
                             #      docker.io

# 默认项目名称
PROJECT_NAME="k8s-images"    # 例如: k8s-images, library, prod

# ============================================================================
# Registry 认证（可选）
# ============================================================================
REGISTRY_USERNAME=""         # 例如: admin, robot$project+push
REGISTRY_PASSWORD=""         # 建议用环境变量或外部 secret 注入
REGISTRY_LOGIN_BEFORE_PUSH="false"  # true 时在 push 前自动登录

# ============================================================================
# 远程节点配置（执行 load/tag/push 的节点）
# ============================================================================
REMOTE_HOST=""               # 远程节点 IP，例如: 115.190.64.131
REMOTE_USER="root"           # SSH 用户名
REMOTE_SSH_PORT="22"         # SSH 端口
REMOTE_SECRET=""             # SSH 私钥路径（与密码二选一）
REMOTE_PASS=""               # SSH 密码（与私钥二选一）
REMOTE_IMAGE_DIR="~/packages-to-be-installed/images"  # 远程临时目录

# ============================================================================
# 本地配置
# ============================================================================
LOCAL_IMAGE_DIR="$HOME/packages-to-be-installed/images"  # 本地 tar 文件目录

# ============================================================================
# 容器运行时配置
# ============================================================================
NERDCTL_BIN="nerdctl"        # nerdctl 命令路径
CONTAINERD_NAMESPACE="k8s.io"  # containerd 命名空间
USE_SUDO="true"              # 远程执行是否使用 sudo

# ============================================================================
# 推送可靠性配置
# ============================================================================
PUSH_RETRY="2"               # 推送失败重试次数
PUSH_RETRY_INTERVAL="3"      # 重试间隔（秒）
EXISTENCE_CHECK_TOOL="skopeo"  # 推送前检查工具（skopeo/none）
REGISTRY_TLS_VERIFY="false"  # TLS 证书校验（自签名建议 false）

# ============================================================================
# 网络代理（可选）
# ============================================================================
HTTP_PROXY=""
HTTPS_PROXY=""
NO_PROXY="localhost,127.0.0.1,::1"
```

### 针对 Harbor 的推荐配置

```bash
# 编辑 loadimage.conf，添加以下配置：

# Harbor Registry 地址
REGISTRY_URL="www.sunmoonai.com:30443"
PROJECT_NAME="k8s-images"

# Harbor 认证
REGISTRY_USERNAME="admin"
REGISTRY_PASSWORD="Harbor@12345"
REGISTRY_LOGIN_BEFORE_PUSH="true"

# 远程节点（控制平面）
REMOTE_HOST="115.190.64.131"
REMOTE_USER="zym"
REMOTE_SSH_PORT="1022"
REMOTE_SECRET="~/.ssh/ali_key"
REMOTE_IMAGE_DIR="~/packages-to-be-installed/images"

# 自签名证书
REGISTRY_TLS_VERIFY="false"
```

---

## 使用方法

### 菜单式管理工具

#### 启动菜单

```bash
cd ~/k8s/utils/registry-push-management
./registry-push-menu.sh
```

#### 菜单结构

```
🐳 镜像推送管理工具
================================"
=== 配置管理 ==="
1. 查看配置          # 显示所有 22 个配置项的当前值
2. 编辑配置          # 进入配置编辑子菜单

=== 推送操作 ==="
3. 推送单个镜像      # 交互式推送单个镜像
4. 从清单文件批量推送 # 从文件读取镜像列表批量推送
5. 从目录推送所有镜像 # 推送目录下所有 tar 文件

=== 工具功能 ==="
6. 测试连接          # 测试远程节点和 Registry 连接
7. 查看状态          # 查看本地和远程环境状态
8. 查看帮助          # 显示 loadimage.sh 帮助信息

0. 退出
```

#### 配置编辑示例

```bash
# 1. 启动菜单
./registry-push-menu.sh

# 2. 选择 "2. 编辑配置"
# 3. 查看配置列表，选择要编辑的配置项序号（1-22）
# 4. 输入新值
# 5. 配置自动保存到 loadimage.conf
```

#### 推送操作示例

**推送单个镜像**：
```bash
# 在菜单中选择 "3. 推送单个镜像"
# 输入镜像名（如: nginx:1.21）
# 工具自动查找本地 tar 文件并推送
```

**批量推送**：
```bash
# 创建镜像清单文件
cat > images.txt <<EOF
nginx:1.21
redis:7.0
postgres:14
EOF

# 在菜单中选择 "4. 从清单文件批量推送"
# 输入清单文件路径
```

### 命令行工具

### 基础命令

```bash
# 查看帮助
./loadimage.sh help

# 一步完成：上传→加载→打标→推送（需指定完整参数）
./loadimage.sh upload-load-push \
  <本地tar> <远程IP> <远程目录> <目标引用> \
  [用户] [端口] [密钥] [密码]

# 分步执行
./loadimage.sh load-image <远程tar路径> <远程IP> [用户] [端口] [密钥] [密码]
./loadimage.sh tag-image <源引用> <目标引用> <远程IP> [用户] [端口] [密钥] [密码]
./loadimage.sh push-image <目标引用> <远程IP> [用户] [端口] [密钥] [密码]

# 清理
./loadimage.sh remove-image <镜像引用> <远程IP> [用户] [端口] [密钥] [密码]
./loadimage.sh remove-file <文件路径> <远程IP> [用户] [端口] [密钥] [密码]

# 便捷命令（使用配置文件默认值）
./loadimage.sh push-by-ref <镜像引用> [远程IP] [远程目录] [用户] [端口] [密钥] [密码]
./loadimage.sh push-from-list <清单文件> [远程IP] [远程目录] [用户] [端口] [密钥] [密码]
./loadimage.sh push-from-dir [本地目录] [远程IP] [远程目录] [用户] [端口] [密钥] [密码]
```

### 实战示例

#### 示例 1: 推送单个镜像（使用配置文件默认值）

```bash
# 前提：已在 loadimage.conf 中配置 REGISTRY_URL 和 REMOTE_*

# 推送 nginx:1.21
./loadimage.sh push-by-ref nginx:1.21

# 实际执行：
# 1. 在本地查找 nginx.tar 或 nginx_1.21.tar
# 2. SCP 上传到远程节点
# 3. 在远程节点执行：
#    nerdctl load -i nginx.tar
#    nerdctl tag <源> www.sunmoonai.com:30443/k8s-images/nginx:1.21
#    nerdctl push www.sunmoonai.com:30443/k8s-images/nginx:1.21
# 4. 清理远程临时文件
```

#### 示例 2: 推送单个镜像（显式指定所有参数）

```bash
# 不依赖配置文件，完全显式
./loadimage.sh upload-load-push \
  ~/packages-to-be-installed/images/nginx.tar \
  115.190.64.131 \
  ~/packages-to-be-installed/images \
  www.sunmoonai.com:30443/k8s-images/nginx:1.21 \
  zym \
  1022 \
  ~/.ssh/ali_key \
  ""
```

#### 示例 3: 批量推送（从清单文件）

```bash
# 创建清单文件 images.txt
cat > images.txt <<EOF
nginx:1.21
redis:7.0
postgres:14
# 注释行会被忽略
EOF

# 批量推送
./loadimage.sh push-from-list images.txt

# 每个镜像会自动：
# 1. 查找对应的 tar 文件
# 2. 上传到远程节点
# 3. 推送到 REGISTRY_URL/PROJECT_NAME/镜像名:标签
```

#### 示例 4: 推送目录下所有镜像

```bash
# 推送 LOCAL_IMAGE_DIR 下所有 .tar 和 .tar.gz 文件
./loadimage.sh push-from-dir

# 或指定目录
./loadimage.sh push-from-dir /data/images
```

#### 示例 5: 分步执行（精细控制）

```bash
# 1. 先上传（手动）
scp -i ~/.ssh/ali_key -P 1022 nginx.tar zym@115.190.64.131:~/tmp/

# 2. 加载镜像
./loadimage.sh load-image ~/tmp/nginx.tar 115.190.64.131 zym 1022 ~/.ssh/ali_key ""

# 3. 打标签
./loadimage.sh tag-image \
  docker.io/library/nginx:1.21 \
  www.sunmoonai.com:30443/k8s-images/nginx:1.21 \
  115.190.64.131 zym 1022 ~/.ssh/ali_key ""

# 4. 推送
./loadimage.sh push-image \
  www.sunmoonai.com:30443/k8s-images/nginx:1.21 \
  115.190.64.131 zym 1022 ~/.ssh/ali_key ""
```

---

## 多节点推送

### ❓ 是否支持多节点推送？

**答案：支持，但需要手动循环调用**

工具本身设计为**单次推送到单个远程节点**，但可以通过脚本循环实现多节点推送。

### 多节点推送方案

#### 方案 1: Shell 循环（简单场景）

```bash
#!/bin/bash
# 定义节点列表
NODES=(
  "115.190.64.131:1022:zym:~/.ssh/ali_key"
  "192.168.1.100:22:root:~/.ssh/id_rsa"
  "10.0.0.50:2222:ubuntu:~/.ssh/node3_key"
)

# 镜像列表
IMAGES=(
  "nginx:1.21"
  "redis:7.0"
  "postgres:14"
)

# 循环推送
for node_config in "${NODES[@]}"; do
  IFS=':' read -r host port user key <<< "$node_config"
  
  echo "推送到节点: $host"
  
  for img in "${IMAGES[@]}"; do
    echo "  推送镜像: $img"
    ./loadimage.sh push-by-ref "$img" "$host" ~/tmp "$user" "$port" "$key" ""
  done
done
```

#### 方案 2: 配合基础设施配置（推荐）

```bash
#!/bin/bash
# 从基础设施配置读取节点列表

INFRA_CONFIG="~/k8s/sunmoonai/infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf"
source "$INFRA_CONFIG"

# 镜像列表
IMAGES=(
  "nginx:1.21"
  "redis:7.0"
)

# 循环所有节点
idx=1
while true; do
  host_var="SERVER_${idx}_PUBLIC_IP"
  host="${!host_var:-}"
  
  # 如果没有更多节点，退出
  [[ -z "$host" ]] && break
  
  user_var="SERVER_${idx}_USER"
  user="${!user_var:-root}"
  
  port_var="SERVER_${idx}_SSH_PORT"
  port="${!port_var:-22}"
  
  secret_var="SERVER_${idx}_SECRET"
  secret="${!secret_var:-}"
  
  echo "==== 推送到节点 [$idx]: $user@$host:$port ===="
  
  for img in "${IMAGES[@]}"; do
    echo "  推送镜像: $img"
    ./loadimage.sh push-by-ref "$img" "$host" ~/tmp "$user" "$port" "$secret" ""
  done
  
  idx=$((idx+1))
done

echo "✅ 所有节点推送完成"
```

#### 方案 3: 并行推送（高性能）

```bash
#!/bin/bash
# 使用 GNU parallel 并行推送（需要安装 parallel）

# 节点列表文件 nodes.txt
# 格式: host:port:user:key
cat > nodes.txt <<EOF
115.190.64.131:1022:zym:~/.ssh/ali_key
192.168.1.100:22:root:~/.ssh/id_rsa
10.0.0.50:2222:ubuntu:~/.ssh/node3_key
EOF

# 镜像列表
IMAGES="nginx:1.21 redis:7.0 postgres:14"

# 并行推送（最多 3 个并发）
parallel -j 3 --colsep ':' \
  './loadimage.sh push-by-ref {5} {1} ~/tmp {3} {2} {4} ""' \
  ::: $(cat nodes.txt) \
  ::: $IMAGES

echo "✅ 并行推送完成"
```

### 多节点推送示例：实战场景

```bash
#!/bin/bash
# multi-node-push.sh - 多节点镜像推送脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOADIMAGE_TOOL="$SCRIPT_DIR/loadimage.sh"

# 日志函数
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
ok() { log "✅ $*"; }
err() { log "❌ $*"; }

# 从基础设施配置读取节点
INFRA_CONFIG="~/k8s/sunmoonai/infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf"
if [[ ! -f "$INFRA_CONFIG" ]]; then
  err "基础设施配置文件不存在: $INFRA_CONFIG"
  exit 1
fi

source "$INFRA_CONFIG"

# 镜像清单
IMAGE_LIST="${1:-images.txt}"
if [[ ! -f "$IMAGE_LIST" ]]; then
  err "镜像清单文件不存在: $IMAGE_LIST"
  exit 1
fi

log "开始多节点镜像推送"
log "镜像清单: $IMAGE_LIST"

# 读取镜像列表
mapfile -t IMAGES < <(grep -v '^#' "$IMAGE_LIST" | grep -v '^$')
log "共 ${#IMAGES[@]} 个镜像待推送"

# 遍历所有节点
idx=1
success_count=0
fail_count=0

while true; do
  host_var="SERVER_${idx}_PUBLIC_IP"
  host="${!host_var:-}"
  
  [[ -z "$host" ]] && break
  
  user_var="SERVER_${idx}_USER"
  user="${!user_var:-root}"
  
  port_var="SERVER_${idx}_SSH_PORT"
  port="${!port_var:-22}"
  
  secret_var="SERVER_${idx}_SECRET"
  secret="${!secret_var:-}"
  
  log "==== 节点 [$idx]: $user@$host:$port ===="
  
  node_success=0
  node_fail=0
  
  for img in "${IMAGES[@]}"; do
    log "  推送: $img"
    if "$LOADIMAGE_TOOL" push-by-ref "$img" "$host" ~/tmp "$user" "$port" "$secret" "" 2>&1 | sed 's/^/    /'; then
      ok "    成功: $img"
      ((node_success++))
    else
      err "    失败: $img"
      ((node_fail++))
    fi
  done
  
  log "  节点 [$idx] 统计: 成功 $node_success, 失败 $node_fail"
  
  success_count=$((success_count + node_success))
  fail_count=$((fail_count + node_fail))
  
  idx=$((idx+1))
done

log "========================================"
log "多节点推送完成"
log "总计: 成功 $success_count, 失败 $fail_count"
[[ $fail_count -gt 0 ]] && exit 1 || exit 0
```

使用方法：

```bash
# 创建镜像清单
cat > images.txt <<EOF
nginx:1.21
redis:7.0
postgres:14
EOF

# 执行多节点推送
./multi-node-push.sh images.txt
```

---

## 本地 vs 远程推送

**说明**：本工具仅用于**远程节点**（SSH + nerdctl），不适用于 Kind 或本机直推。若需在 Kind/本机推送，请使用 `push-images-to-harbor.sh` 或按下面「使用 Docker」小节手动操作。

### 本工具不支持的场景（仅作手动参考）

若在**本机**或 Kind 环境需要手动推送，需已安装 **nerdctl** 或 **Docker**。Kind 建议使用 `push-to-harbor/push-images-to-harbor.sh`。

1. ✅ 有容器运行时（nerdctl 或 Docker）
2. ✅ 网络可以访问 Registry
3. ✅ 有必要的证书配置或信任

#### 使用 nerdctl（本地推送）

```bash
# 1. 加载镜像
sudo nerdctl -n k8s.io load -i nginx.tar

# 2. 登录 Registry（如果需要）
echo 'Harbor@12345' | sudo nerdctl login www.sunmoonai.com:30443 \
  -u admin --password-stdin --insecure-registry

# 3. 打标签
sudo nerdctl -n k8s.io tag docker.io/library/nginx:1.21 \
  www.sunmoonai.com:30443/k8s-images/nginx:1.21

# 4. 推送
sudo nerdctl -n k8s.io push www.sunmoonai.com:30443/k8s-images/nginx:1.21 \
  --insecure-registry

# 5. 清理
sudo nerdctl -n k8s.io rmi docker.io/library/nginx:1.21
sudo nerdctl -n k8s.io rmi www.sunmoonai.com:30443/k8s-images/nginx:1.21
```

#### 使用 Docker（手动一次性推送，本机仅 Docker 时）

```bash
# 1. 加载
docker load -i nginx.tar

# 2. 登录
docker login www.sunmoonai.com:30443 -u admin -p Harbor@12345

# 3. 打标签
docker tag nginx:1.21 www.sunmoonai.com:30443/k8s-images/nginx:1.21

# 4. 推送
docker push www.sunmoonai.com:30443/k8s-images/nginx:1.21

# 5. 清理
docker rmi nginx:1.21
docker rmi www.sunmoonai.com:30443/k8s-images/nginx:1.21
```

#### 使用 skopeo（最简单）

```bash
# 直接从 tar 复制到 Registry（一步到位）
skopeo copy \
  docker-archive:nginx.tar \
  docker://www.sunmoonai.com:30443/k8s-images/nginx:1.21 \
  --dest-creds admin:Harbor@12345 \
  --dest-tls-verify=false
```

#### 配置本地为"远程节点"

```bash
# 编辑 loadimage.conf
REMOTE_HOST="127.0.0.1"      # 本地回环
REMOTE_USER="$(whoami)"      # 当前用户
REMOTE_SSH_PORT="22"
REMOTE_SECRET=""             # 本地不需要密钥
REMOTE_PASS=""

# 然后正常使用工具（会通过 SSH localhost 执行）
./loadimage.sh push-by-ref nginx:1.21
```

### 选择建议

| 场景 | 推荐方案 | 理由 |
|------|---------|------|
| **生产部署** | 远程推送 | 安全、统一、易维护 |
| **CI/CD** | 远程推送 | 标准化环境 |
| **快速测试** | 本地推送 | 速度快、步骤少 |
| **开发调试** | 本地推送 | 方便迭代 |
| **离线环境** | 远程推送 | 跳板机方案 |

---

## 常见问题

### Q1: 推送失败，提示证书错误？

**问题**：
```
Error: x509: certificate signed by unknown authority
```

**解决**：
```bash
# 方案 1: 修改配置文件
REGISTRY_TLS_VERIFY="false"

# 方案 2: 命令行指定（nerdctl）
nerdctl push --insecure-registry ...

# 方案 3: 配置 Docker daemon（如果用 Docker）
# /etc/docker/daemon.json
{
  "insecure-registries": ["www.sunmoonai.com:30443"]
}
sudo systemctl restart docker
```

### Q2: SSH 连接远程节点超时？

**检查**：
```bash
# 测试连通性
ssh -i ~/.ssh/ali_key -p 1022 zym@115.190.64.131 "echo OK"

# 检查防火墙
sudo ufw status
sudo firewall-cmd --list-all

# 检查 SSH 服务
sudo systemctl status sshd
```

### Q3: 推送到 Harbor 出现 401 Unauthorized？

**原因**：
- 用户名密码错误
- Harbor 未配置认证

**解决**：
```bash
# 1. 检查 Harbor 认证配置
REGISTRY_USERNAME="admin"
REGISTRY_PASSWORD="Harbor@12345"
REGISTRY_LOGIN_BEFORE_PUSH="true"

# 2. 手动登录测试
nerdctl login www.sunmoonai.com:30443 -u admin -p Harbor@12345 --insecure-registry

# 3. 检查 Harbor 项目权限
# 登录 Harbor UI，确认项目存在且有推送权限
```

### Q4: 推送速度很慢？

**优化**：
```bash
# 1. 使用代理
HTTP_PROXY="http://proxy.example.com:8080"
HTTPS_PROXY="http://proxy.example.com:8080"

# 2. 调整网络参数
# /etc/sysctl.conf
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
sudo sysctl -p

# 3. 使用更快的网络链路
# 确保远程节点与 Registry 在同一内网
```

### Q5: 多节点推送时部分节点失败？

**解决**：
```bash
# 1. 使用重试机制
PUSH_RETRY="3"
PUSH_RETRY_INTERVAL="5"

# 2. 单独推送失败节点
./loadimage.sh push-by-ref nginx:1.21 192.168.1.100 ~/tmp root 22 ~/.ssh/key ""

# 3. 检查失败节点的日志
ssh root@192.168.1.100 "journalctl -u containerd -n 100"
```

### Q6: 镜像 tar 文件找不到？

**问题**：
```
❌ 未找到本地 tar: nginx:1.21
```

**解决**：
```bash
# 工具会按以下顺序查找：
# 1. $LOCAL_IMAGE_DIR/nginx:1.21.tar
# 2. $LOCAL_IMAGE_DIR/nginx_1.21.tar  (转换特殊字符)
# 3. $LOCAL_IMAGE_DIR/nginx:1.21.tar.gz

# 确保文件存在
ls -lh ~/packages-to-be-installed/images/ | grep nginx

# 手动重命名（如果需要）
mv nginx-1.21.tar ~/packages-to-be-installed/images/nginx_1.21.tar
```

### Q7: 远程节点磁盘空间不足？

**检查**：
```bash
# 查看磁盘使用
ssh zym@115.190.64.131 "df -h"

# 清理镜像缓存
ssh zym@115.190.64.131 "sudo nerdctl -n k8s.io image prune -a -f"

# 清理临时文件
ssh zym@115.190.64.131 "rm -rf ~/packages-to-be-installed/images/*.tar"
```

---

## 最佳实践

### 1. 安全配置

```bash
# ✅ 使用 SSH 密钥，不用密码
REMOTE_SECRET="~/.ssh/ali_key"
REMOTE_PASS=""

# ✅ 使用 Robot 账户，不用管理员账户
REGISTRY_USERNAME="robot$k8s-images+push"
REGISTRY_PASSWORD="<robot-token>"

# ✅ Registry 密码通过环境变量注入
export REGISTRY_PASSWORD="Harbor@12345"
# 配置文件中留空
REGISTRY_PASSWORD=""

# ✅ 限制 SSH 密钥权限
chmod 600 ~/.ssh/ali_key
```

### 2. 性能优化

```bash
# ✅ 启用镜像存在性检查（避免重复推送）
EXISTENCE_CHECK_TOOL="skopeo"

# ✅ 自动清理（节省空间）
# 工具会自动清理远程节点的临时文件

# ✅ 使用 tar.gz 压缩（减少传输时间）
# 镜像导出时使用压缩
nerdctl save nginx:1.21 | gzip > nginx_1.21.tar.gz

# ✅ 批量推送时使用清单文件
./loadimage.sh push-from-list images.txt
```

### 3. 可靠性保障

```bash
# ✅ 配置重试
PUSH_RETRY="3"
PUSH_RETRY_INTERVAL="5"

# ✅ 记录日志
./loadimage.sh push-by-ref nginx:1.21 2>&1 | tee push.log

# ✅ 检查推送结果
if ./loadimage.sh push-by-ref nginx:1.21; then
  echo "推送成功"
else
  echo "推送失败" >&2
  exit 1
fi
```

### 4. 生产部署流程

```bash
#!/bin/bash
# production-push-workflow.sh

set -euo pipefail

# 1. 加载配置
source ~/k8s/utils/registry-push-management/loadimage.conf

# 2. 验证环境
echo "验证环境..."
ssh -i "$REMOTE_SECRET" -p "$REMOTE_SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "echo OK" || exit 1
curl -sSf "$HARBOR_API_BASE/api/v2.0/ping" || exit 1

# 3. 准备镜像列表
IMAGE_LIST="/tmp/production-images.txt"
cat > "$IMAGE_LIST" <<EOF
nginx:1.21
redis:7.0
postgres:14
EOF

# 4. 推送镜像
echo "推送镜像..."
./loadimage.sh push-from-list "$IMAGE_LIST" 2>&1 | tee /tmp/push.log

# 5. 验证推送结果
echo "验证推送结果..."
failed=0
while IFS= read -r img; do
  project="$PROJECT_NAME"
  repo="${img%:*}"
  tag="${img##*:}"
  
  url="$HARBOR_API_BASE/api/v2.0/projects/$project/repositories/${repo##*/}/artifacts/$tag"
  if curl -sSf -u "$REGISTRY_USERNAME:$REGISTRY_PASSWORD" "$url" >/dev/null 2>&1; then
    echo "✅ $img"
  else
    echo "❌ $img"
    failed=1
  fi
done < "$IMAGE_LIST"

# 6. 清理
rm -f "$IMAGE_LIST"

# 7. 退出
[[ $failed -eq 0 ]] && echo "✅ 部署成功" || { echo "❌ 部署失败" >&2; exit 1; }
```

### 5. 与 CI/CD 集成

#### Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    environment {
        REGISTRY_URL = 'www.sunmoonai.com:30443'
        REGISTRY_CREDS = credentials('harbor-credentials')
        REMOTE_NODE = '115.190.64.131'
        REMOTE_KEY = credentials('ssh-key')
    }
    
    stages {
        stage('Build Images') {
            steps {
                sh 'docker build -t myapp:${BUILD_NUMBER} .'
                sh 'docker save myapp:${BUILD_NUMBER} -o myapp.tar'
            }
        }
        
        stage('Push to Harbor') {
            steps {
                sh '''
                    cd ~/k8s/utils/registry-push-management
                    ./loadimage.sh upload-load-push \
                        ${WORKSPACE}/myapp.tar \
                        ${REMOTE_NODE} \
                        /tmp \
                        ${REGISTRY_URL}/myproject/myapp:${BUILD_NUMBER} \
                        zym 1022 ${REMOTE_KEY} ""
                '''
            }
        }
    }
}
```

#### GitLab CI

```yaml
push-to-harbor:
  stage: deploy
  script:
    - cd ~/k8s/utils/registry-push-management
    - |
      ./loadimage.sh upload-load-push \
        ${CI_PROJECT_DIR}/myapp.tar \
        ${REMOTE_NODE} \
        /tmp \
        ${REGISTRY_URL}/myproject/myapp:${CI_COMMIT_TAG} \
        zym 1022 ${SSH_PRIVATE_KEY} ""
  only:
    - tags
```

---

## 附录

### A. 与 harbor-image-management 的关系

```
harbor-image.sh (Harbor 专用高层工具)
    ↓ 调用
loadimage.sh (通用底层工具) ← 本工具
    ↓ 执行
远程节点 (nerdctl/containerd)
```

**区别**：
- `loadimage.sh`: **通用工具**，Registry 无关，适用于任何镜像仓库
- `harbor-image.sh`: **Harbor 专用**，封装了 Harbor API 检查、组件管理、批量处理等业务逻辑

### B. 支持的 Registry 类型

- ✅ Harbor（公共/私有）
- ✅ Docker Hub
- ✅ 阿里云容器镜像服务
- ✅ AWS ECR
- ✅ Google GCR
- ✅ 自建私有仓库（需支持 Docker Registry V2 API）

### C. 镜像命名规则

```bash
# 完整格式
<registry>/<project>/<repository>:<tag>

# 示例
www.sunmoonai.com:30443/k8s-images/nginx:1.21
docker.io/library/nginx:1.21
registry.cn-hangzhou.aliyuncs.com/namespace/nginx:1.21

# 组成部分
# - registry: 镜像仓库地址（可选，默认 docker.io）
# - project: 项目/命名空间
# - repository: 镜像仓库名
# - tag: 标签（可选，默认 latest）
```

### D. 相关文档

- [nerdctl 官方文档](https://github.com/containerd/nerdctl)
- [Harbor 官方文档](https://goharbor.io/docs/)
- [Skopeo 使用指南](https://github.com/containers/skopeo)
- [Docker Registry V2 API](https://docs.docker.com/registry/spec/api/)

---

## 许可证

本工具为内部使用工具，版权归属于 SunMoonAI 项目。

---

**最后更新**: 2025-01-08
**维护者**: K8s Platform Team

