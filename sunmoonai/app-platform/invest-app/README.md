# Portal App K8s 部署配置

本文档说明 Portal App 的 K8s 部署配置结构。

## 目录结构

```
portal-app/
├── portal-app-backend/          # Portal 业务 BFF (NestJS)
│   ├── resources/
│   │   └── k8s-resource/
│   │       └── templates/    # K8s 资源模板
│   │           ├── app/      # Deployment + Service
│   │           ├── configmap/ # ConfigMap
│   │           ├── secret/    # Secret
│   │           ├── ingress/  # IngressRoute
│   │           ├── namespace/# Namespace
│   │           ├── pvc/      # PersistentVolumeClaim
│   │           └── middleware/# Middleware
│   ├── deploy-portal-backend/    # 部署脚本目录
│   └── CONFIG_CHECKLIST.md   # 配置检查清单
│
└── portal-app-front/          # Portal SSR (Nuxt)
    ├── resources/
    │   └── k8s-resource/
    │       └── templates/    # K8s 资源模板
    │           ├── app/      # Deployment + Service
    │           ├── configmap/ # ConfigMap
    │           ├── secret/    # Secret
    │           ├── ingress/  # IngressRoute
    │           ├── namespace/# Namespace
    │           ├── pvc/      # PersistentVolumeClaim
    │           └── middleware/# Middleware
    ├── deploy-portal-front/    # 部署脚本目录
    └── CONFIG_CHECKLIST.md   # 配置检查清单
```

## 联动环境变量

### portal-app-backend

| 环境变量 | 值 | 说明 |
|---------|-----|------|
| `PORT` | `3000` | HTTP 服务端口（SSR 的 BFF_URL 需要与此端口一致） |
| `PREFIX` | `/api` | API 前缀（SSR 调用时使用） |
| `VERSION` | `v1` | API 版本（SSR 调用时使用） |
| `SESSION_COOKIE_NAME` | `sunmoonai_session` | Session Cookie 名称（必须与 auth-app-backend 和 SSR 一致） |
| `AUTH_SERVICE_URL` | `http://auth-app-backend:3030` | 认证服务地址（必须与 auth-app-backend 的 PORT 一致） |

### portal-app-front

| 环境变量 | 值 | 说明 |
|---------|-----|------|
| `VUE_APP_BFF_URL` | `http://portal-app-backend:3000` | 业务 BFF 地址（必须与 portal-app-backend 的 PORT 一致） |
| `VUE_APP_API_PREFIX` | `/api` | API 前缀（必须与 portal-app-backend 的 PREFIX 一致） |
| `VUE_APP_API_VERSION` | `v1` | API 版本（必须与 portal-app-backend 的 VERSION 一致） |
| `SESSION_COOKIE_NAME` | `sunmoonai_session` | Session Cookie 名称（必须与 auth-app-backend 和业务 BFF 一致） |

## 部署步骤

### 1. 准备环境变量

确保以下联动环境变量已正确配置：

- `AUTH_SERVICE_URL=http://auth-app-backend:3030`（portal-app-backend）
- `VUE_APP_BFF_URL=http://portal-app-backend:3000`（portal-app-front）
- `SESSION_COOKIE_NAME=sunmoonai_session`（所有服务）

### 2. 创建 ConfigMap 和 Secret

参考 `incubator-app` 的部署脚本，创建 ConfigMap 和 Secret。

### 3. 部署服务

使用部署脚本或直接使用 `kubectl apply` 部署：

```bash
# 部署 portal-app-backend
kubectl apply -f portal-app-backend/resources/k8s-resource/templates/app/portal-app-backend.yaml

# 部署 portal-app-front
kubectl apply -f portal-app-front/resources/k8s-resource/templates/app/portal-app-front.yaml
```

## 参考

- `incubator-app/` - 参考实现
- `~/k8s/sunmoonai/docs/environment-variables-k8s-deployment.md` - 环境变量部署指南
- `~/k8s/sunmoonai/configmaps/environment-configmap.yaml` - 统一 ConfigMap 配置

