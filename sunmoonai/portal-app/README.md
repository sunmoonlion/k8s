# Portal App K8s 部署配置

本文档说明 Portal App 的 K8s 部署配置结构。

## 目录结构

```
portal-app/
├── portal-app-bff/          # Portal 业务 BFF (NestJS)
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
│   ├── deploy-portal-bff/    # 部署脚本目录
│   └── CONFIG_CHECKLIST.md   # 配置检查清单
│
└── portal-app-ssr/          # Portal SSR (Nuxt)
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
    ├── deploy-portal-ssr/    # 部署脚本目录
    └── CONFIG_CHECKLIST.md   # 配置检查清单
```

## 联动环境变量

### portal-app-bff

| 环境变量 | 值 | 说明 |
|---------|-----|------|
| `PORT` | `3000` | HTTP 服务端口（SSR 的 BFF_URL 需要与此端口一致） |
| `PREFIX` | `/api` | API 前缀（SSR 调用时使用） |
| `VERSION` | `v1` | API 版本（SSR 调用时使用） |
| `SESSION_COOKIE_NAME` | `sunmoonai_session` | Session Cookie 名称（必须与 auth-app-bff 和 SSR 一致） |
| `AUTH_SERVICE_URL` | `http://auth-app-bff:3030` | 认证服务地址（必须与 auth-app-bff 的 PORT 一致） |

### portal-app-ssr

| 环境变量 | 值 | 说明 |
|---------|-----|------|
| `VUE_APP_BFF_URL` | `http://portal-app-bff:3000` | 业务 BFF 地址（必须与 portal-app-bff 的 PORT 一致） |
| `VUE_APP_API_PREFIX` | `/api` | API 前缀（必须与 portal-app-bff 的 PREFIX 一致） |
| `VUE_APP_API_VERSION` | `v1` | API 版本（必须与 portal-app-bff 的 VERSION 一致） |
| `SESSION_COOKIE_NAME` | `sunmoonai_session` | Session Cookie 名称（必须与 auth-app-bff 和业务 BFF 一致） |

## 部署步骤

### 1. 准备环境变量

确保以下联动环境变量已正确配置：

- `AUTH_SERVICE_URL=http://auth-app-bff:3030`（portal-app-bff）
- `VUE_APP_BFF_URL=http://portal-app-bff:3000`（portal-app-ssr）
- `SESSION_COOKIE_NAME=sunmoonai_session`（所有服务）

### 2. 创建 ConfigMap 和 Secret

参考 `incubator-app` 的部署脚本，创建 ConfigMap 和 Secret。

### 3. 部署服务

使用部署脚本或直接使用 `kubectl apply` 部署：

```bash
# 部署 portal-app-bff
kubectl apply -f portal-app-bff/resources/k8s-resource/templates/app/portal-app-bff.yaml

# 部署 portal-app-ssr
kubectl apply -f portal-app-ssr/resources/k8s-resource/templates/app/portal-app-ssr.yaml
```

## 参考

- `incubator-app/` - 参考实现
- `/home/zym/k8s/sunmoonai/docs/environment-variables-k8s-deployment.md` - 环境变量部署指南
- `/home/zym/k8s/sunmoonai/configmaps/environment-configmap.yaml` - 统一 ConfigMap 配置

