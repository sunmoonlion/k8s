# ArgoCD 部署脚本

## 概述

本项目提供了基于 Bitnami ArgoCD 3.1.1 的 Kubernetes 部署脚本，使用统一部署模板进行管理。ArgoCD 是一个基于 GitOps 的 Kubernetes 持续交付工具，用于自动化应用程序的部署和同步。

## 架构

```
argocd/
├── deploy/
│   ├── deploy-argocd.conf      # 配置文件
│   ├── deploy-argocd.sh        # 部署脚本
│   └── README.md              # 本文档
└── resources/
    ├── argo-cd/               # 官方 Helm Chart
    └── custom/
        └── values/
            ├── values-base/    # 基础配置模板
            ├── values-dev/     # 开发环境配置
            └── values-prod/    # 生产环境配置
```

## 特性

- **统一部署模板**: 基于 `COMPONENT_DEVELOPMENT_GUIDE.md` 规范
- **多环境支持**: 开发环境和生产环境配置分离
- **镜像预检查**: 自动检查所需镜像在集群中的可用性
- **远程集群支持**: 支持本地和远程 Kubernetes 集群
- **安全配置**: 包含认证、TLS、网络策略等安全特性
- **监控集成**: 支持 Prometheus 监控和 ServiceMonitor
- **自动扩缩容**: 支持 HPA 自动扩缩容
- **备份支持**: 支持定时备份到 S3 存储
- **高可用配置**: 支持多副本部署和反亲和性
- **GitOps 工作流**: 支持基于 Git 的应用程序管理

## 使用方法

### 基本部署

```bash
# 部署到开发环境
./deploy-argocd.sh deploy sunmoonai cicd-platform development

# 部署到生产环境
./deploy-argocd.sh deploy sunmoonai cicd-platform production

# 干运行模式
./deploy-argocd.sh deploy sunmoonai cicd-platform production true
```

### 升级部署

```bash
# 升级到最新版本
./deploy-argocd.sh upgrade sunmoonai cicd-platform production
```

### 其他操作

```bash
# 检查状态
./deploy-argocd.sh status sunmoonai cicd-platform

# 查看日志
./deploy-argocd.sh logs sunmoonai cicd-platform

# 卸载
./deploy-argocd.sh uninstall sunmoonai cicd-platform
```

## 配置说明

### 环境变量

主要配置在 `deploy-argocd.conf` 文件中：

- `ARGOCD_PROJECT_ID`: 项目标识
- `ARGOCD_NAMESPACE`: 部署命名空间
- `ARGOCD_USERNAME`: ArgoCD 用户名
- `ARGOCD_PASSWORD`: ArgoCD 密码
- `ARGOCD_IMAGE_VERSION`: ArgoCD 镜像版本

### 环境特定配置

#### 开发环境
- 单副本部署
- 较小的资源配置
- 禁用监控和备份
- 启用详细日志
- 使用 ClusterIP 服务
- 禁用 TLS 加密

#### 生产环境
- 多副本部署（2-5个）
- 较大的资源配置
- 启用监控和备份
- 启用网络策略
- 使用 LoadBalancer 服务
- 启用 TLS 加密
- 启用高可用配置

## 镜像要求

部署前需要确保以下镜像在集群中可用：

- `bitnami/argo-cd:3.1.1-debian-12-r0`
- `bitnami/dex:2.43.1-debian-12-r8`
- `bitnami/os-shell:12-debian-12-r51`
- `bitnami/redis:8.2.1-debian-12-r0`

## 连接信息

### 服务连接
- **集群内**: `argocd-sunmoonai.cicd-platform.svc.cluster.local:80`
- **Web 界面**: `http://argocd-sunmoonai.cicd-platform.svc.cluster.local:80`

### 认证信息
- **用户名**: `admin`
- **密码**: `sunmoonai_argocd_2025!`

## 核心组件

### ArgoCD Server
- 提供 Web UI 和 API 服务
- 处理用户认证和授权
- 管理应用程序状态

### Repository Server
- 处理 Git 仓库操作
- 解析 Helm charts 和 Kustomize
- 支持多种仓库类型

### Application Controller
- 监控应用程序状态
- 执行同步操作
- 管理资源生命周期

### Redis
- 提供缓存和会话存储
- 支持高可用部署

## 监控

### 健康检查
```bash
# 检查 Pod 状态
kubectl get pods -n cicd-platform -l app.kubernetes.io/name=argocd

# 检查服务状态
kubectl get svc -n cicd-platform -l app.kubernetes.io/name=argocd

# 查看日志
kubectl logs -n cicd-platform -l app.kubernetes.io/name=argocd

# API 健康检查
curl http://argocd-sunmoonai.cicd-platform.svc.cluster.local:80/healthz
```

### Prometheus 监控
生产环境启用了 ServiceMonitor，可以通过 Prometheus 监控：
- 指标端点: `/metrics`
- 抓取间隔: 30秒

## 故障排除

### 常见问题

1. **无法访问 Web UI**
   - 检查服务类型和端口配置
   - 验证网络策略设置
   - 确认防火墙规则

2. **同步失败**
   - 检查 Git 仓库连接
   - 验证认证信息
   - 查看应用控制器日志

3. **认证问题**
   - 检查管理员密码
   - 验证 Dex 配置（如果启用）
   - 确认 TLS 证书

4. **性能问题**
   - 调整并行度限制
   - 优化资源配置
   - 检查 Redis 连接

### 日志查看

```bash
# 查看 ArgoCD 日志
kubectl logs -n cicd-platform -l app.kubernetes.io/name=argocd

# 查看特定 Pod 日志
kubectl logs -n cicd-platform <pod-name>

# 实时查看日志
kubectl logs -n cicd-platform -l app.kubernetes.io/name=argocd -f
```

## 最佳实践

### GitOps 工作流
- 使用 Git 作为单一真实来源
- 自动化部署流程
- 实施代码审查
- 使用分支策略

### 安全
- 使用强密码
- 启用 TLS 加密
- 配置网络策略
- 定期更新镜像版本

### 监控
- 设置告警规则
- 监控同步状态
- 跟踪资源使用情况
- 监控应用程序健康状态

### 备份
- 定期备份配置和数据
- 测试恢复流程
- 监控备份状态

## CLI 工具使用

### 安装 ArgoCD CLI
```bash
# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# macOS
brew install argocd
```

### 基本命令
```bash
# 登录
argocd login argocd-sunmoonai.cicd-platform.svc.cluster.local:80

# 获取用户信息
argocd account get-user-info

# 列出应用程序
argocd app list

# 同步应用程序
argocd app sync <app-name>

# 获取应用程序状态
argocd app get <app-name>
```

## 版本信息

- **ArgoCD 版本**: 3.1.1
- **Chart 版本**: 11.0.0
- **镜像版本**: 3.1.1-debian-12-r0
- **Dex 版本**: 2.43.1-debian-12-r8
- **Redis 版本**: 8.2.1-debian-12-r0

## 许可证

本项目基于 Apache 2.0 许可证开源。
