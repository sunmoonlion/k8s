# 镜像清理模块使用指南

## 概述

镜像清理模块是一个**完全独立**的基础设施运维工具，用于定期清理 Kubernetes 集群各节点上未使用的镜像缓存和包文件。

**重要特性**：
- ✅ **完全独立**：不依赖 Harbor 任何代码
- ✅ **模块化设计**：清理功能和定时任务分离
- ✅ **灵活配置**：多级开关控制
- ✅ **条件执行**：支持磁盘使用率检查

## 设计原则

### 1. 完全独立
- ✅ **不修改任何 Harbor 相关代码**
- ✅ 创建全新的、独立的镜像清理模块
- ✅ 不依赖 `harbor-image.sh` 或 `harbor-image.conf`
- ✅ Harbor 代码保持原样，继续使用

### 2. 职责分离
- Harbor 镜像管理工具：继续负责 Harbor 相关的镜像推送和管理（不变）
- 镜像清理模块：独立的基础设施运维功能（新增）

## 架构设计

### 文件组织结构

```
infrastructure/utils/image-cleanup/
├── image-cleanup.sh          # 核心清理脚本（完全独立，不依赖 Harbor）
├── image-cleanup.conf        # 清理配置（清理策略、节点配置等）
├── periodic-cleanup.sh       # 定时任务包装脚本
├── periodic-cleanup.conf     # 定时任务配置（开关、执行时间等）
├── cron/
│   ├── k8s-image-cleanup.cron.example  # Cron配置示例
│   └── install-cron.sh                 # Cron安装脚本
└── README.md                 # 本文档
```

### 依赖关系

```
periodic-cleanup.sh（定时任务包装）
    ↓
    ├─→ periodic-cleanup.conf（定时任务配置）
    └─→ image-cleanup.sh（核心清理脚本）
            ↓
            ├─→ image-cleanup.conf（清理配置）
            └─→ deploy-infrastructure-all.conf（节点配置）
```

**关键点**：
- ✅ `image-cleanup.sh` 完全独立，不依赖 Harbor
- ✅ `periodic-cleanup.sh` 只依赖 `image-cleanup.sh`
- ✅ 配置分离：清理配置 vs 定时任务配置
- ✅ 开关控制：`PERIODIC_CLEANUP_ENABLED` 控制定时任务

### 与 Harbor 的关系

**重要**：此模块与 Harbor 完全独立，互不影响。

- ✅ **完全独立**：不依赖 Harbor 任何代码
- ✅ **Harbor 不变**：Harbor 相关代码和配置保持不变
- ✅ **共享资源**：都从 `deploy-infrastructure-all.conf` 读取节点配置（但不依赖 Harbor 代码）
- ✅ **可以并存**：两套系统可以同时使用，互不影响

## 快速开始

### 1. 配置清理策略

编辑 `image-cleanup.conf`：

```bash
# 启用清理功能
CLEANUP_ENABLED="true"

# 清理策略
CLEANUP_IMAGES="true"                     # 清理镜像缓存
CLEANUP_PACKAGES="true"                   # 清理包文件
CLEANUP_PACKAGE_TYPES="debs,tars,charts,images"

# 磁盘使用率阈值
CLEANUP_DISK_THRESHOLD="75"               # >= 75% 才清理

# 容器运行时配置
CONTAINERD_NAMESPACE="k8s.io"
NERDCTL_BIN="nerdctl"
```

### 2. 配置定时任务

编辑 `periodic-cleanup.conf`：

```bash
# 启用定时任务（重要：控制定时任务开关）
PERIODIC_CLEANUP_ENABLED="true"

# 执行时间（Cron格式）
PERIODIC_CLEANUP_SCHEDULE="0 2 * * *"    # 每天凌晨 2:00

# 执行模式
EXECUTION_MODE="conditional"              # conditional（条件执行）或 always（总是执行）
```

### 3. 安装定时任务

```bash
# 使用安装脚本（推荐）
cd ~/master/k8s/sunmoonai/infrastructure/utils/image-cleanup
sudo ./cron/install-cron.sh install

# 或手动安装
sudo cp cron/k8s-image-cleanup.cron.example /etc/cron.d/k8s-image-cleanup
sudo systemctl restart cron
```

### 4. 手动测试

```bash
# 测试清理功能
./image-cleanup.sh cleanup-all-nodes

# 测试定时任务（检查开关和条件）
./periodic-cleanup.sh execute

# 强制执行（忽略开关和条件）
./periodic-cleanup.sh execute --force

# 查看配置
./image-cleanup.sh show-config
```

## 配置说明

### image-cleanup.conf（清理配置）

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `CLEANUP_ENABLED` | 是否启用清理功能 | `true` |
| `CLEANUP_IMAGES` | 是否清理镜像缓存 | `true` |
| `CLEANUP_PACKAGES` | 是否清理包文件 | `true` |
| `CLEANUP_PACKAGE_TYPES` | 清理的包类型（逗号分隔） | `debs,tars,charts,images` |
| `CLEANUP_DISK_THRESHOLD` | 磁盘使用率阈值（%） | `75` |
| `CONTAINERD_NAMESPACE` | containerd 命名空间 | `k8s.io` |
| `NERDCTL_BIN` | nerdctl 命令路径 | `nerdctl` |
| `LOG_FILE` | 日志文件路径 | `/var/log/k8s-image-cleanup.log` |
| `LOG_LEVEL` | 日志级别 | `INFO` |

### periodic-cleanup.conf（定时任务配置）

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `PERIODIC_CLEANUP_ENABLED` | **是否启用定时任务（重要开关）** | `true` |
| `PERIODIC_CLEANUP_SCHEDULE` | Cron 执行时间 | `0 2 * * *` |
| `EXECUTION_MODE` | 执行模式（conditional/always） | `conditional` |
| `LOG_FILE` | 日志文件路径 | `/var/log/k8s-image-cleanup.log` |
| `CRON_USER` | Cron 任务运行用户 | `zym` |

**配置优先级**：
```
环境变量 > periodic-cleanup.conf > image-cleanup.conf > 默认值
```

## 使用方式

### 手动执行清理

```bash
# 清理所有节点
./image-cleanup.sh cleanup-all-nodes

# 检查磁盘使用率
./image-cleanup.sh check-disk-usage

# 显示配置
./image-cleanup.sh show-config

# 显示帮助
./image-cleanup.sh help
```

### 定时任务执行

```bash
# 执行定时清理（检查开关和条件）
./periodic-cleanup.sh execute

# 强制执行（忽略开关和条件）
./periodic-cleanup.sh execute --force
```

### Cron 管理

```bash
# 安装 Cron 配置
sudo ./cron/install-cron.sh install

# 卸载 Cron 配置
sudo ./cron/install-cron.sh uninstall

# 查看状态
./cron/install-cron.sh status
```

## 执行流程

```
Cron 触发（每天凌晨 2:00）
    ↓
periodic-cleanup.sh 检查 PERIODIC_CLEANUP_ENABLED（定时任务开关）
    ├─ false → 退出，记录日志
    └─ true → 继续
        ↓
检查 EXECUTION_MODE
    ├─ always → 跳过磁盘检查
    └─ conditional → 检查磁盘使用率
        ├─ 不满足 → 退出，记录日志
        └─ 满足 → 继续
            ↓
调用 image-cleanup.sh cleanup-all-nodes
    ↓
检查 CLEANUP_ENABLED（清理功能开关）
    ├─ false → 退出
    └─ true → 执行清理
        ↓
遍历所有节点（从 deploy-infrastructure-all.conf 读取）
    ↓
对每个节点执行：
    ├─ 清理镜像缓存（如果 CLEANUP_IMAGES=true）
    │   └─ nerdctl -n k8s.io image prune -a -f
    └─ 清理包文件（如果 CLEANUP_PACKAGES=true）
        └─ rm -rf debs/* tars/* charts/* images/*.tar*
```

## 开关控制机制

### 定时任务开关
- **位置**：`periodic-cleanup.conf` 中的 `PERIODIC_CLEANUP_ENABLED`
- **作用**：控制定时任务是否执行
- **默认**：`true`
- **说明**：即使 Cron 配置了执行时间，如果此开关为 `false`，定时任务也不会执行

### 清理功能开关
- **位置**：`image-cleanup.conf` 中的 `CLEANUP_ENABLED`
- **作用**：控制是否执行清理操作
- **默认**：`true`

### 执行模式
- **conditional**：检查磁盘使用率，只有达到阈值才执行
- **always**：总是执行，忽略磁盘使用率检查

## 功能模块说明

### image-cleanup.sh（核心清理脚本）

**职责**：
- 读取节点配置（从 `deploy-infrastructure-all.conf`）
- 通过 SSH 连接各节点
- 执行清理操作（镜像、包文件）
- **不依赖任何 Harbor 相关脚本**

**接口**：
```bash
./image-cleanup.sh cleanup-all-nodes    # 清理所有节点
./image-cleanup.sh check-disk-usage    # 检查磁盘使用率
./image-cleanup.sh show-config          # 显示配置
./image-cleanup.sh help                 # 显示帮助
```

### periodic-cleanup.sh（定时任务包装）

**职责**：
- 读取 `periodic-cleanup.conf` 配置
- 检查定时任务开关
- 调用 `image-cleanup.sh` 执行清理
- 记录日志

**接口**：
```bash
./periodic-cleanup.sh execute           # 执行定时清理（检查开关和条件）
./periodic-cleanup.sh execute --force   # 强制执行（忽略开关和条件）
```

## 日志查看

```bash
# 实时查看日志
tail -f /var/log/k8s-image-cleanup.log

# 查看最近日志
tail -n 100 /var/log/k8s-image-cleanup.log

# 查看特定时间段的日志
grep "2025-11-12" /var/log/k8s-image-cleanup.log

# 查看系统日志（Cron执行记录）
grep CRON /var/log/syslog | grep periodic-cleanup
```

## 故障排查

### 检查配置

```bash
# 显示清理配置
./image-cleanup.sh show-config

# 检查定时任务配置
cat periodic-cleanup.conf

# 检查 Cron 配置
./cron/install-cron.sh status

# 检查 Cron 服务状态
sudo systemctl status cron
```

### 测试脚本

```bash
# 测试脚本语法
bash -n image-cleanup.sh
bash -n periodic-cleanup.sh

# 手动执行测试
./image-cleanup.sh cleanup-all-nodes
./periodic-cleanup.sh execute --force
```

### 检查权限

```bash
# 检查脚本权限
ls -l image-cleanup.sh periodic-cleanup.sh

# 检查日志文件权限
ls -l /var/log/k8s-image-cleanup.log

# 检查 Cron 配置文件权限
ls -l /etc/cron.d/k8s-image-cleanup
```

### 检查 SSH 连接

```bash
# 测试 SSH 连接到节点
ssh -i <secret> user@node_ip "echo 'SSH connection OK'"
```

## 常见问题

### Q: 定时任务不执行？
A: 检查以下配置：
1. `PERIODIC_CLEANUP_ENABLED` 是否为 `true`（在 `periodic-cleanup.conf` 中）
2. Cron 配置是否正确安装（`sudo ./cron/install-cron.sh status`）
3. 磁盘使用率是否达到阈值（如果使用 conditional 模式）
4. 查看日志文件：`tail -f /var/log/k8s-image-cleanup.log`

### Q: 清理不执行？
A: 检查以下配置：
1. `CLEANUP_ENABLED` 是否为 `true`（在 `image-cleanup.conf` 中）
2. `CLEANUP_IMAGES` 或 `CLEANUP_PACKAGES` 是否为 `true`
3. SSH 连接是否正常
4. 节点配置是否正确（从 `deploy-infrastructure-all.conf` 读取）

### Q: 如何修改执行时间？
A: 编辑 `periodic-cleanup.conf` 中的 `PERIODIC_CLEANUP_SCHEDULE`，然后重新安装 Cron：
```bash
sudo ./cron/install-cron.sh install
```

### Q: 如何临时禁用定时任务？
A: 编辑 `periodic-cleanup.conf`，设置：
```bash
PERIODIC_CLEANUP_ENABLED="false"
```
Cron 仍会触发脚本，但脚本会检查开关后退出。

### Q: 定时任务和 Harbor 的关系？
A: **完全独立**。定时任务不依赖 Harbor 任何代码，Harbor 代码保持不变。两套系统可以并存，互不影响。

## 文件清单

```
infrastructure/utils/image-cleanup/
├── image-cleanup.sh          # 核心清理脚本（完全独立，不依赖 Harbor）
├── image-cleanup.conf        # 清理配置
├── periodic-cleanup.sh       # 定时任务包装脚本
├── periodic-cleanup.conf    # 定时任务配置（含开关）
├── cron/
│   ├── k8s-image-cleanup.cron.example  # Cron配置示例
│   └── install-cron.sh                 # Cron安装脚本
└── README.md                 # 本文档
```

## 实现状态

✅ **所有文件已创建并测试通过**

- ✅ 核心清理脚本：`image-cleanup.sh`
- ✅ 清理配置：`image-cleanup.conf`
- ✅ 定时任务包装：`periodic-cleanup.sh`
- ✅ 定时任务配置：`periodic-cleanup.conf`
- ✅ Cron 安装脚本：`cron/install-cron.sh`
- ✅ 完整文档：`README.md`

## 优势

1. **完全解耦**：镜像清理功能独立，不依赖 Harbor
2. **职责清晰**：Harbor 工具只负责 Harbor 相关功能
3. **配置分离**：清理配置和定时任务配置分开
4. **易于维护**：模块化设计，便于扩展和维护
5. **灵活控制**：多级开关控制，灵活配置

---

**最后更新**: 2025-11-12
