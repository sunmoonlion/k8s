# Auth App 快速部署指南

本文档提供 auth-app-bff 和 auth-app-ssr 的快速部署步骤。

## 部署顺序

**必须先部署 auth-app-bff，再部署 auth-app-ssr**

```
1. auth-app-bff (认证服务核心)
   ↓
2. auth-app-ssr (认证服务前端)
```

## 快速部署步骤

### 步骤 1: 部署 auth-app-bff

```bash
cd ~/k8s/sunmoonai/auth-app/auth-app-bff/deploy-auth-app-bff/app/deploy-app

# 部署
./deploy-auth-app-bff.sh deploy sunmoonai app-platform-dev development

# 检查状态
./deploy-auth-app-bff.sh status sunmoonai app-platform-dev development
```

### 步骤 2: 部署 auth-app-ssr

```bash
cd ~/k8s/sunmoonai/auth-app/auth-app-ssr/deploy-auth-app-ssr/app/deploy-app

# 部署
./deploy-auth-app-ssr.sh deploy sunmoonai app-platform-dev development

# 检查状态
./deploy-auth-app-ssr.sh status sunmoonai app-platform-dev development
```

## 部署前检查清单

### auth-app-bff

- [ ] 镜像已构建并推送到 Harbor
- [ ] ConfigMap 配置文件已准备（包含 PORT=3030, SESSION_COOKIE_NAME 等）
- [ ] Secret 配置文件已准备（包含 JWT_SECRET, DATABASE_URL, REDIS_PASSWORD 等）
- [ ] Redis 服务已部署
- [ ] PostgreSQL 数据库已部署
- [ ] 命名空间已创建（app-platform-dev）

### auth-app-ssr

- [ ] 镜像已构建并推送到 Harbor
- [ ] ConfigMap 配置文件已准备（包含 SESSION_COOKIE_NAME 等）
- [ ] Secret 配置文件已准备（通常不需要敏感配置）
- [ ] auth-app-bff 已成功部署
- [ ] 命名空间已创建（app-platform-dev）

## 验证部署

### 1. 检查 Pod 状态

```bash
# 检查 auth-app-bff
kubectl get pods -n app-platform-dev -l app=auth-app-bff

# 检查 auth-app-ssr
kubectl get pods -n app-platform-dev -l app=auth-app-ssr
```

### 2. 检查服务

```bash
# 检查 auth-app-bff Service
kubectl get svc auth-app-bff -n app-platform-dev

# 检查 auth-app-ssr Service
kubectl get svc auth-app-ssr -n app-platform-dev
```

### 3. 检查环境变量

```bash
# 检查 auth-app-bff 环境变量
kubectl exec -it <auth-app-bff-pod> -n app-platform-dev -- env | grep -E "PORT|PREFIX|VERSION|SESSION_COOKIE_NAME"

# 应该看到：
# PORT=3030
# PREFIX=/api
# VERSION=v1
# SESSION_COOKIE_NAME=sunmoonai_session
```

### 4. 测试接口

```bash
# 测试 auth-app-bff 健康检查
kubectl exec -it <auth-app-bff-pod> -n app-platform-dev -- curl http://localhost:3030/api/v1/health

# 测试 auth-app-bff 服务间调用（通过 Service）
kubectl exec -it <auth-app-ssr-pod> -n app-platform-dev -- curl http://auth-app-bff:3030/api/v1/health
```

## 常见问题

### 问题 1: Pod 无法启动

**原因**: ConfigMap 或 Secret 未创建

**解决**:
```bash
# 检查 ConfigMap
kubectl get configmap auth-app-bff-config -n app-platform-dev

# 检查 Secret
kubectl get secret auth-app-bff-secret -n app-platform-dev

# 如果不存在，先部署 ConfigMap 和 Secret
cd ~/k8s/sunmoonai/auth-app/auth-app-bff/deploy-auth-app-bff/configMap/auth-app-bff-config/deploy-auth-app-bff-config
./deploy-auth-app-bff-config.sh deploy sunmoonai app-platform-dev development
```

### 问题 2: 无法连接数据库或 Redis

**原因**: 数据库或 Redis 服务未部署，或连接信息错误

**解决**:
```bash
# 检查数据库连接
kubectl exec -it <auth-app-bff-pod> -n app-platform-dev -- env | grep DATABASE_URL

# 检查 Redis 连接
kubectl exec -it <auth-app-bff-pod> -n app-platform-dev -- env | grep REDIS
```

### 问题 3: 端口不匹配

**原因**: Service 端口与 ConfigMap 中的 PORT 不一致

**解决**: 确保 Service 的 port 和 targetPort 都是 3030（已修复）

## 下一步

部署完成后，可以：

1. **部署业务 BFF**（依赖 auth-app-bff）:
   - portal-app-bff
   - incubator-app-bff
   - llmops-app-bff

2. **部署业务 SSR**（依赖业务 BFF）:
   - portal-app-ssr
   - incubator-app-ssr
   - llmops-app-ssr

## 参考文档

- [详细部署指南](./DEPLOYMENT_GUIDE.md)
- [配置检查清单](./auth-app-bff/CONFIG_CHECKLIST.md)

