# ConfigMap 和 Secret 重构总结

本文档说明所有 app 的 ConfigMap 和 Secret 重构情况。

## 重构完成情况

### ✅ auth-app

#### auth-app-bff
- **ConfigMap**: `/k8s/sunmoonai/auth-app/auth-app-bff/resources/k8s-resource/templates/configMap/auth-app-bff-config.yaml`
  - ✅ `PORT=3030`（联动变量）
  - ✅ `PREFIX=/api`（联动变量）
  - ✅ `VERSION=v1`（联动变量）
  - ✅ `SESSION_COOKIE_NAME=sunmoonai_session`（联动变量）
  - ✅ 其他业务配置（GRPC_PORT, CORS, ERROR_FILTER, Redis 等）

- **Secret**: `/k8s/sunmoonai/auth-app/auth-app-bff/resources/k8s-resource/templates/secret/auth-app-bff-secret.yaml`
  - ✅ `JWT_SECRET`（新增）
  - ✅ `DATABASE_URL`（新增）
  - ✅ `REDIS_PASSWORD`（新增）
  - ✅ 其他敏感配置

#### auth-app-ssr
- **ConfigMap**: `/k8s/sunmoonai/auth-app/auth-app-ssr/resources/k8s-resource/templates/configmap/auth-app-ssr-config.yaml`
  - ✅ `SESSION_COOKIE_NAME=sunmoonai_session`（联动变量，新增）

### ✅ portal-app

#### portal-app-bff
- **ConfigMap**: `/k8s/sunmoonai/portal-app/portal-app-bff/resources/k8s-resource/templates/configmap/portal-app-bff-config.yaml`
  - ✅ `PORT=3000`（联动变量）
  - ✅ `PREFIX=/api`（联动变量）
  - ✅ `VERSION=v1`（联动变量）
  - ✅ `SESSION_COOKIE_NAME=sunmoonai_session`（联动变量）
  - ✅ `AUTH_SERVICE_URL=http://auth-app-bff:3030`（联动变量）

- **Secret**: `/k8s/sunmoonai/portal-app/portal-app-bff/resources/k8s-resource/templates/secret/portal-app-bff-secret.yaml`
  - ✅ `JWT_SECRET`
  - ✅ `DATABASE_URL`

#### portal-app-ssr
- **ConfigMap**: `/k8s/sunmoonai/portal-app/portal-app-ssr/resources/k8s-resource/templates/configmap/portal-app-ssr-config.yaml`
  - ✅ `VUE_APP_BFF_URL=http://portal-app-bff:3000`（联动变量）
  - ✅ `VUE_APP_API_PREFIX=/api`（联动变量）
  - ✅ `VUE_APP_API_VERSION=v1`（联动变量）
  - ✅ `SESSION_COOKIE_NAME=sunmoonai_session`（联动变量）

- **Secret**: `/k8s/sunmoonai/portal-app/portal-app-ssr/resources/k8s-resource/templates/secret/portal-app-ssr-secret.yaml`
  - ✅ 已创建（占位符）

### ✅ incubator-app

#### incubator-app-bff
- **ConfigMap**: `/k8s/sunmoonai/incubator-app/incubator-app-bff/resources/k8s-resource/templates/configmap/incubator-app-bff-config.yaml`
  - ✅ `AUTH_SERVICE_URL=http://auth-app-bff:3030`（联动变量，已更新）
  - ✅ `SESSION_COOKIE_NAME=sunmoonai_session`（联动变量，新增）
  - ✅ `API_V1_STR=/api/v1`（联动变量，新增）
  - ✅ 其他业务配置

- **Secret**: `/k8s/sunmoonai/incubator-app/incubator-app-bff/resources/k8s-resource/templates/secret/incubator-app-bff-secret.yaml`
  - ✅ 已存在，无需修改

#### incubator-app-ssr
- **ConfigMap**: `/k8s/sunmoonai/incubator-app/incubator-app-ssr/resources/k8s-resource/templates/configmap/incubator-app-ssr-config.yaml`
  - ✅ `VUE_APP_BFF_URL=http://incubator-app-bff:8000`（联动变量，新增）
  - ✅ `VUE_APP_API_VERSION=v1`（联动变量，新增）
  - ✅ `SESSION_COOKIE_NAME=sunmoonai_session`（联动变量，新增）

### ✅ llmops-app

#### llmops-app-bff
- **ConfigMap**: `/k8s/sunmoonai/llmops-app/llmops-app-bff/resources/k8s-resource/templates/configmap/llmops-service-config.yaml`
  - ✅ `AUTH_SERVICE_URL=http://auth-app-bff:3030`（联动变量，已更新）
  - ✅ `SESSION_COOKIE_NAME=sunmoonai_session`（联动变量，新增）
  - ✅ `API_V1_STR=/api/v1`（联动变量，新增）
  - ✅ 其他业务配置（Redis, Weaviate, COS, LLM APIs 等）

- **Secret**: `/k8s/sunmoonai/llmops-app/llmops-app-bff/resources/k8s-resource/templates/secret/llmops-service-secret.yaml`
  - ✅ 已存在，包含所有必要的敏感配置

#### llmops-app-ssr
- **ConfigMap**: `/k8s/sunmoonai/llmops-app/llmops-app-ssr/resources/k8s-resource/templates/configmap/llmops-app-ssr-config.yaml`
  - ✅ `VUE_APP_BFF_URL=http://llmops-app-bff:8000`（联动变量，新增）
  - ✅ `VUE_APP_API_VERSION=v1`（联动变量，新增）
  - ✅ `SESSION_COOKIE_NAME=sunmoonai_session`（联动变量，新增）
  - ✅ Nuxt SSR 运行配置（新增）

- **Secret**: `/k8s/sunmoonai/llmops-app/llmops-app-ssr/resources/k8s-resource/templates/secret/llmops-app-ssr-secret.yaml`
  - ✅ 已存在

## 统一参考配置

### ConfigMap 参考
- **位置**: `/k8s/sunmoonai/configmaps/environment-configmap.yaml`
- **说明**: 包含所有服务的联动环境变量参考配置
- **注意**: 此文件仅作为参考，实际部署时应在各 app 的 ConfigMap 中配置

### Secret 参考
- **位置**: `/k8s/sunmoonai/secrets/environment-secret.yaml.example`
- **说明**: 包含所有服务的敏感环境变量参考配置
- **注意**: 此文件仅作为参考，实际部署时应在各 app 的 Secret 中配置

## 核心联动变量

### 所有服务必须一致
- `SESSION_COOKIE_NAME=sunmoonai_session`

### 认证服务（auth-app-bff）
- `PORT=3030` → 业务 BFF 的 `AUTH_SERVICE_URL=http://auth-app-bff:3030`
- `PREFIX=/api`
- `VERSION=v1`

### 业务 BFF → 认证服务
- `AUTH_SERVICE_URL=http://auth-app-bff:3030`（所有业务 BFF）

### SSR → 业务 BFF
- `portal-app-ssr` → `VUE_APP_BFF_URL=http://portal-app-bff:3000`
- `incubator-app-ssr` → `VUE_APP_BFF_URL=http://incubator-app-bff:8000`
- `llmops-app-ssr` → `VUE_APP_BFF_URL=http://llmops-app-bff:8000`

## 部署说明

### 使用各 app 的 ConfigMap 和 Secret

各 app 的 ConfigMap 和 Secret 已包含所有必要的联动环境变量，可直接使用：

1. **auth-app-bff**: 使用 `auth-app-bff-config` 和 `auth-app-bff-secret`
2. **portal-app-bff**: 使用 `portal-app-bff-config` 和 `portal-app-bff-secret`
3. **incubator-app-bff**: 使用 `incubator-app-bff-config` 和 `incubator-app-bff-secret`
4. **llmops-app-bff**: 使用 `llmops-service-config` 和 `llmops-service-secret`
5. **portal-app-ssr**: 使用 `portal-app-ssr-config` 和 `portal-app-ssr-secret`
6. **incubator-app-ssr**: 使用 `incubator-app-ssr-config` 和 `incubator-app-ssr-secret`
7. **llmops-app-ssr**: 使用 `llmops-app-ssr-config` 和 `llmops-app-ssr-secret`

### 在 Deployment 中使用

各 app 的 Deployment 模板已配置使用对应的 ConfigMap 和 Secret：

```yaml
envFrom:
- configMapRef:
    name: {app-name}-config
- secretRef:
    name: {app-name}-secret
```

## 总结

✅ **所有 app 的 ConfigMap 和 Secret 已重构完成**

- ✅ 所有联动环境变量已正确配置
- ✅ 所有 ConfigMap 包含必要的非敏感配置
- ✅ 所有 Secret 包含必要的敏感配置
- ✅ 统一参考配置已更新
- ✅ 所有配置遵循统一的结构和命名规范

所有配置已准备就绪，可直接用于 K8s 部署。

