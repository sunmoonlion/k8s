# K8s 环境变量部署指南

本文档说明如何将各 app 的环境变量转换为 K8s ConfigMap 和 Secret，并确保服务间联动。

## 目录

1. [联动环境变量清单](#联动环境变量清单)
2. [ConfigMap 配置](#configmap-配置)
3. [Secret 配置](#secret-配置)
4. [Deployment 配置示例](#deployment-配置示例)
5. [部署步骤](#部署步骤)

---

## 联动环境变量清单

### 核心联动变量（必须一致）

| 环境变量 | auth-app-bff | portal-app-bff | incubator-app-bff | llmops-app-bff | portal-app-ssr | incubator-app-ssr | llmops-app-ssr |
|---------|--------------|----------------|-------------------|----------------|----------------|-------------------|----------------|
| **SESSION_COOKIE_NAME** | ✅ `sunmoonai_session` | ✅ `sunmoonai_session` | ✅ `sunmoonai_session` | ✅ `sunmoonai_session` | ✅ `sunmoonai_session` | ✅ `sunmoonai_session` | ✅ `sunmoonai_session` |
| **AUTH_SERVICE_URL** | ❌ 不需要 | ✅ `http://auth-app-bff:3030` | ✅ `http://auth-app-bff:3030` | ✅ `http://auth-app-bff:3030` | ❌ 不需要 | ❌ 不需要 | ❌ 不需要 |
| **BFF_URL** | ❌ 不需要 | ❌ 不需要 | ❌ 不需要 | ❌ 不需要 | ✅ `http://portal-app-bff:3000` | ✅ `http://incubator-app-bff:8000` | ✅ `http://llmops-app-bff:8000` |
| **API_PREFIX** | ✅ `/api` | ✅ `/api` | ❌ (在 API_V1_STR) | ❌ (在 API_V1_STR) | ✅ `/api` | ❌ 不需要 | ❌ 不需要 |
| **API_VERSION** | ✅ `v1` | ✅ `v1` | ❌ (在 API_V1_STR) | ❌ (在 API_V1_STR) | ✅ `v1` | ✅ `v1` | ✅ `v1` |

### 服务端口配置

| 服务 | 环境变量 | 默认值 | K8s Service 名称 |
|------|---------|--------|-----------------|
| **auth-app-bff** | `PORT` | `3030` | `auth-app-bff:3030` |
| **portal-app-bff** | `PORT` | `3000` | `portal-app-bff:3000` |
| **incubator-app-bff** | (FastAPI 默认) | `8000` | `incubator-app-bff:8000` |
| **llmops-app-bff** | (FastAPI 默认) | `8000` | `llmops-app-bff:8000` |

---

## ConfigMap 配置

### 文件位置

`/home/zym/k8s/sunmoonai/configmaps/environment-configmap.yaml`

### 包含的配置

- 所有服务的端口、前缀、版本配置
- Session Cookie 名称
- SSR 的 BFF URL 配置
- 其他非敏感配置

### 使用方法

```bash
# 创建 ConfigMap
kubectl apply -f k8s/sunmoonai/configmaps/environment-configmap.yaml

# 查看 ConfigMap
kubectl get configmap sunmoonai-environment-config -o yaml
```

### 在 Deployment 中使用

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portal-app-bff
spec:
  template:
    spec:
      containers:
      - name: portal-app-bff
        env:
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: PORTAL_PORT
        - name: PREFIX
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: PORTAL_PREFIX
        - name: VERSION
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: PORTAL_VERSION
        - name: SESSION_COOKIE_NAME
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: SESSION_COOKIE_NAME
        - name: AUTH_SERVICE_URL
          value: "http://auth-app-bff:3030"  # 使用 K8s Service 名称
```

---

## Secret 配置

### 文件位置

`/home/zym/k8s/sunmoonai/secrets/environment-secret.yaml.example`

### 包含的配置

- 所有服务的密钥（SECRET_KEY、JWT_SECRET 等）
- 数据库密码
- Redis 密码
- 第三方 API 密钥（LLM APIs、COS、GitHub OAuth 等）

### 创建 Secret

**方式 1：使用 kubectl 命令（推荐）**

```bash
# 创建 Secret（逐个指定）
kubectl create secret generic sunmoonai-environment-secret \
  --from-literal=AUTH_SECRET_KEY='your-secret-key' \
  --from-literal=AUTH_JWT_SECRET='your-jwt-secret' \
  --from-literal=AUTH_DATABASE_URL='postgresql://user:password@postgres:5432/auth_db' \
  --namespace=default

# 从文件创建（推荐）
kubectl create secret generic sunmoonai-environment-secret \
  --from-env-file=secret-values.txt \
  --namespace=default
```

**方式 2：使用 sealed-secrets（推荐用于生产环境）**

```bash
# 安装 sealed-secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# 创建 SealedSecret
kubectl create secret generic sunmoonai-environment-secret \
  --from-env-file=secret-values.txt \
  --dry-run=client -o yaml | \
  kubectl seal -o yaml > sealed-secret.yaml

# 应用 SealedSecret
kubectl apply -f sealed-secret.yaml
```

### 在 Deployment 中使用

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-app-bff
spec:
  template:
    spec:
      containers:
      - name: auth-app-bff
        env:
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: sunmoonai-environment-secret
              key: AUTH_SECRET_KEY
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: sunmoonai-environment-secret
              key: AUTH_JWT_SECRET
```

---

## Deployment 配置示例

### auth-app-bff Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-app-bff
spec:
  template:
    spec:
      containers:
      - name: auth-app-bff
        env:
        # 从 ConfigMap 读取
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: AUTH_PORT
        - name: PREFIX
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: AUTH_PREFIX
        - name: VERSION
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: AUTH_VERSION
        - name: SESSION_COOKIE_NAME
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: SESSION_COOKIE_NAME
        # 从 Secret 读取
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: sunmoonai-environment-secret
              key: AUTH_SECRET_KEY
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: sunmoonai-environment-secret
              key: AUTH_JWT_SECRET
```

### portal-app-bff Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portal-app-bff
spec:
  template:
    spec:
      containers:
      - name: portal-app-bff
        env:
        # 从 ConfigMap 读取
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: PORTAL_PORT
        - name: PREFIX
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: PORTAL_PREFIX
        - name: VERSION
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: PORTAL_VERSION
        - name: SESSION_COOKIE_NAME
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: SESSION_COOKIE_NAME
        # 联动配置：调用 auth-app-bff
        - name: AUTH_SERVICE_URL
          value: "http://auth-app-bff:3030"  # 使用 K8s Service 名称
        # 从 Secret 读取
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: sunmoonai-environment-secret
              key: PORTAL_JWT_SECRET
```

### incubator-app-bff Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incubator-app-bff
spec:
  template:
    spec:
      containers:
      - name: incubator-app-bff
        env:
        # 从 ConfigMap 读取
        - name: API_V1_STR
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: INCUBATOR_API_V1_STR
        - name: SESSION_COOKIE_NAME
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: SESSION_COOKIE_NAME
        # 联动配置：调用 auth-app-bff
        - name: AUTH_SERVICE_URL
          value: "http://auth-app-bff:3030"  # 使用 K8s Service 名称
        # 从 Secret 读取
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: sunmoonai-environment-secret
              key: INCUBATOR_SECRET_KEY
```

### portal-app-ssr Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portal-app-ssr
spec:
  template:
    spec:
      containers:
      - name: portal-app-ssr
        env:
        # 从 ConfigMap 读取
        - name: VUE_APP_BFF_URL
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: PORTAL_SSR_BFF_URL
        - name: VUE_APP_API_PREFIX
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: PORTAL_SSR_API_PREFIX
        - name: VUE_APP_API_VERSION
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: PORTAL_SSR_API_VERSION
        - name: SESSION_COOKIE_NAME
          valueFrom:
            configMapKeyRef:
              name: sunmoonai-environment-config
              key: SESSION_COOKIE_NAME
```

---

## 部署步骤

### 1. 准备环境变量文件

为每个 app 创建 `.env.example` 文件（已完成）：
- `/home/zym/app/auth-app-bff/.env.example`
- `/home/zym/app/portal-app-bff/.env.example`
- `/home/zym/app/incubator-app-bff/.env.example`
- `/home/zym/app/llmops-app-bff/.env.example`
- `/home/zym/app/portal-app-ssr/.env.example`
- `/home/zym/app/incubator-app-ssr/.env.example`
- `/home/zym/app/llmops-app-ssr/.env.example`

### 2. 创建 ConfigMap

```bash
# 应用 ConfigMap
kubectl apply -f k8s/sunmoonai/configmaps/environment-configmap.yaml

# 验证
kubectl get configmap sunmoonai-environment-config
```

### 3. 创建 Secret

```bash
# 创建 secret-values.txt 文件（包含所有敏感值）
# 然后创建 Secret
kubectl create secret generic sunmoonai-environment-secret \
  --from-env-file=secret-values.txt \
  --namespace=default

# 验证
kubectl get secret sunmoonai-environment-secret
```

### 4. 更新 Deployment

在各自的 Deployment 配置中引用 ConfigMap 和 Secret（见上方示例）。

### 5. 验证联动

```bash
# 检查各服务的环境变量
kubectl exec -it <pod-name> -- env | grep -E "PORT|PREFIX|VERSION|SESSION_COOKIE_NAME|AUTH_SERVICE_URL|BFF_URL"

# 检查服务间通信
kubectl exec -it <portal-app-bff-pod> -- curl http://auth-app-bff:3030/api/v1/auth/me
```

---

## 注意事项

1. **K8s Service 名称**：在 K8s 中，服务间调用使用 Service 名称，而不是 `localhost`
   - 开发环境：`http://localhost:3030`
   - K8s 环境：`http://auth-app-bff:3030`

2. **端口一致性**：
   - `auth-app-bff` 的 `PORT=3030` → 业务 BFF 的 `AUTH_SERVICE_URL=http://auth-app-bff:3030`
   - `portal-app-bff` 的 `PORT=3000` → SSR 的 `BFF_URL=http://portal-app-bff:3000`

3. **Session Cookie 名称**：所有服务必须使用相同的 `SESSION_COOKIE_NAME`

4. **Secret 安全**：
   - 不要将 Secret 文件提交到 Git
   - 使用 sealed-secrets 或 external-secrets 管理
   - 定期轮换密钥

---

## 总结

✅ **已完成：**
1. 为所有 app 创建了 `.env.example` 文件
2. 创建了 K8s ConfigMap 配置
3. 创建了 K8s Secret 配置示例
4. 统一了所有联动环境变量

📝 **下一步：**
1. 根据实际环境修改 ConfigMap 和 Secret 的值
2. 在各自的 Deployment 中引用 ConfigMap 和 Secret
3. 部署并验证服务间联动

