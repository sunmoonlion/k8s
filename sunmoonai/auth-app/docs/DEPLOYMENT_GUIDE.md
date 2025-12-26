# Auth App 部署指南

本文档说明如何部署 auth-app-bff 和 auth-app-ssr。

## 部署顺序

**必须先部署 auth-app-bff，再部署 auth-app-ssr**，因为：
1. auth-app-ssr 需要调用 auth-app-bff 进行认证
2. auth-app-bff 是认证服务的核心，其他服务都依赖它

## 前置条件

### 1. 基础设施准备

- ✅ Kubernetes 集群已就绪
- ✅ Redis 服务已部署（用于 Session 存储）
- ✅ PostgreSQL 数据库已部署（用于用户数据存储）
- ✅ Harbor 镜像仓库已配置
- ✅ Traefik Ingress 已部署（用于路由）

### 2. 镜像准备

确保镜像已构建并推送到 Harbor：

```bash
# 构建并推送 auth-app-bff 镜像
cd /home/zym/app/auth-app-bff
# 根据实际构建脚本执行
# 例如：npm run build && docker build -t harbor.sunmoonai.com:30443/k8s-images/auth-app-bff:1.0.0 .

# 构建并推送 auth-app-ssr 镜像
cd /home/zym/app/auth-app-ssr
# 根据实际构建脚本执行
# 例如：npm run build && docker build -t harbor.sunmoonai.com:30443/k8s-images/auth-app-ssr:1.0.0 .
```

### 3. 配置文件准备

准备部署配置文件（`.conf` 文件），包含：
- 命名空间
- 镜像信息
- 环境变量
- 其他配置

---

## 部署步骤

### 步骤 1: 部署 auth-app-bff

#### 1.1 准备配置文件

创建或修改配置文件：
`/home/zym/k8s/sunmoonai/auth-app/auth-app-bff/deploy-auth-app-bff/app/deploy-app/deploy-auth-app-bff.conf`

```bash
# 项目配置
AUTH_BFF_PROJECT_ID=sunmoonai
AUTH_BFF_NAMESPACE=app-platform-dev
ENVIRONMENT=development

# 镜像配置
AUTH_BFF_IMAGE_REGISTRY=harbor.sunmoonai.com:30443
AUTH_BFF_IMAGE_PROJECT=k8s-images
AUTH_BFF_IMAGE=auth-app-bff
AUTH_BFF_TAG=1.0.0

# 环境变量（联动配置）
PORT=3030
PREFIX=/api
VERSION=v1
SESSION_COOKIE_NAME=sunmoonai_session
GRPC_PORT=40001
CORS=true
ERROR_FILTER=true

# Redis 配置
REDIS_HOST=redis
REDIS_PORT=6379
```

#### 1.2 准备 Secret 配置

创建 Secret 配置文件：
`/home/zym/k8s/sunmoonai/auth-app/auth-app-bff/deploy-auth-app-bff/secret/auth-app-bff-secret/deploy-auth-app-bff-secret/deploy-auth-app-bff-secret.conf`

```bash
# 敏感配置（必须修改）
SECRET_KEY=your-secret-key-here
JWT_SECRET=your-jwt-secret-here
DATABASE_URL=postgresql://user:password@postgres:5432/auth_db
REDIS_PASSWORD=your-redis-password

# 其他敏感配置
TOTP_SECRET_KEY=your-totp-secret-key
POSTGRES_PASSWORD=your-postgres-password
NEO4J_PASSWORD=your-neo4j-password
FIRST_SUPERUSER=admin@example.com
FIRST_SUPERUSER_PASSWORD=your-admin-password
SMTP_USER=your-smtp-user
SMTP_PASSWORD=your-smtp-password
SENTRY_DSN=your-sentry-dsn
```

#### 1.3 执行部署

```bash
cd /home/zym/k8s/sunmoonai/auth-app/auth-app-bff/deploy-auth-app-bff/app/deploy-app
./deploy-auth-app-bff.sh deploy sunmoonai app-platform-dev development
```

#### 1.4 验证部署

```bash
# 检查 Pod 状态
kubectl get pods -n app-platform-dev -l app=auth-app-bff

# 检查 Service
kubectl get svc -n app-platform-dev -l app=auth-app-bff

# 检查 ConfigMap
kubectl get configmap auth-app-bff-config -n app-platform-dev

# 检查 Secret
kubectl get secret auth-app-bff-secret -n app-platform-dev

# 查看 Pod 日志
kubectl logs -n app-platform-dev -l app=auth-app-bff -f

# 测试接口（在 Pod 内或通过 Ingress）
kubectl exec -it <auth-app-bff-pod> -n app-platform-dev -- curl http://localhost:3030/api/v1/health
```

---

### 步骤 2: 部署 auth-app-ssr

#### 2.1 准备配置文件

创建或修改配置文件：
`/home/zym/k8s/sunmoonai/auth-app/auth-app-ssr/deploy-auth-app-ssr/app/deploy-app/deploy-auth-app-ssr.conf`

```bash
# 项目配置
AUTH_SSR_PROJECT_ID=sunmoonai
AUTH_SSR_NAMESPACE=app-platform-dev
ENVIRONMENT=development

# 镜像配置
AUTH_SSR_IMAGE_REGISTRY=harbor.sunmoonai.com:30443
AUTH_SSR_IMAGE_PROJECT=k8s-images
AUTH_SSR_IMAGE=auth-app-ssr
AUTH_SSR_TAG=1.0.0

# 环境变量（联动配置）
SESSION_COOKIE_NAME=sunmoonai_session
NODE_ENV=production
APP_ENV=production
NITRO_HOST=0.0.0.0
NITRO_PORT=3000
```

#### 2.2 准备 Secret 配置

创建 Secret 配置文件：
`/home/zym/k8s/sunmoonai/auth-app/auth-app-ssr/deploy-auth-app-ssr/secret/auth-app-ssr-secret/deploy-auth-app-ssr-secret/deploy-auth-app-ssr-secret.conf`

```bash
# SSR 通常不需要敏感配置，但可以添加
# API_TOKEN=changeme
```

#### 2.3 执行部署

```bash
cd /home/zym/k8s/sunmoonai/auth-app/auth-app-ssr/deploy-auth-app-ssr/app/deploy-app
./deploy-auth-app-ssr.sh deploy sunmoonai app-platform-dev development
```

#### 2.4 验证部署

```bash
# 检查 Pod 状态
kubectl get pods -n app-platform-dev -l app=auth-app-ssr

# 检查 Service
kubectl get svc -n app-platform-dev -l app=auth-app-ssr

# 检查 ConfigMap
kubectl get configmap auth-app-ssr-config -n app-platform-dev

# 查看 Pod 日志
kubectl logs -n app-platform-dev -l app=auth-app-ssr -f

# 测试访问（通过 Ingress）
curl https://auth-app-ssr.sunmoonai.com/
```

---

## 部署后验证

### 1. 检查服务状态

```bash
# 检查所有资源
kubectl get all -n app-platform-dev -l app=auth-app-bff
kubectl get all -n app-platform-dev -l app=auth-app-ssr

# 检查 Ingress
kubectl get ingressroute -n app-platform-dev | grep auth-app
```

### 2. 测试认证流程

#### 2.1 测试登录

```bash
# 通过 auth-app-ssr 登录
curl -X POST https://auth-app-ssr.sunmoonai.com/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}' \
  -c cookies.txt

# 检查 Cookie
cat cookies.txt | grep sunmoonai_session
```

#### 2.2 测试认证

```bash
# 使用 Cookie 访问受保护接口
curl https://auth-app-ssr.sunmoonai.com/api/v1/auth/me \
  -b cookies.txt
```

### 3. 检查联动配置

```bash
# 检查 auth-app-bff 的环境变量
kubectl exec -it <auth-app-bff-pod> -n app-platform-dev -- env | grep -E "PORT|PREFIX|VERSION|SESSION_COOKIE_NAME"

# 检查 auth-app-ssr 的环境变量
kubectl exec -it <auth-app-ssr-pod> -n app-platform-dev -- env | grep -E "SESSION_COOKIE_NAME"
```

---

## 常见问题

### 1. Pod 无法启动

**检查项：**
- ConfigMap 和 Secret 是否已创建
- 镜像是否正确推送到 Harbor
- 环境变量是否正确配置
- 数据库和 Redis 连接是否正常

**排查命令：**
```bash
# 查看 Pod 事件
kubectl describe pod <pod-name> -n app-platform-dev

# 查看 Pod 日志
kubectl logs <pod-name> -n app-platform-dev
```

### 2. 无法连接 auth-app-bff

**检查项：**
- Service 是否正确创建
- Service 的端口是否正确（3030）
- 网络策略是否允许访问

**排查命令：**
```bash
# 检查 Service
kubectl get svc auth-app-bff -n app-platform-dev

# 测试连接（在 Pod 内）
kubectl exec -it <auth-app-ssr-pod> -n app-platform-dev -- curl http://auth-app-bff:3030/api/v1/health
```

### 3. Cookie 无法设置

**检查项：**
- `SESSION_COOKIE_NAME` 是否一致
- Cookie Domain 配置是否正确
- Ingress 配置是否正确

**排查命令：**
```bash
# 检查响应头
curl -I https://auth-app-ssr.sunmoonai.com/api/v1/login

# 检查 Cookie 设置
curl -v https://auth-app-ssr.sunmoonai.com/api/v1/login 2>&1 | grep -i set-cookie
```

---

## 下一步

部署完成后，可以：

1. **部署业务 BFF**：
   - portal-app-bff
   - incubator-app-bff
   - llmops-app-bff

2. **部署业务 SSR**：
   - portal-app-ssr
   - incubator-app-ssr
   - llmops-app-ssr

3. **验证 SSO**：
   - 测试跨子域名的 Cookie 共享
   - 验证单点登录功能

---

## 参考文档

- [ConfigMap 配置清单](../auth-app-bff/CONFIG_CHECKLIST.md)
- [环境变量使用指南](../../docs/environment-variables-usage-guide.md)
- [Session + Cookie 系统说明](../auth_refactoring-plan/implementation-guide.md#2-session--cookie-系统完整说明)

