# App Platform YAML 生成机制说明

## 概述

App Platform 下的所有应用采用统一的 YAML 生成机制，将 Kubernetes 资源模板与部署逻辑分离，实现单一职责原则。

### 架构设计

- **生成脚本** (`generate.sh`)：负责根据模板文件生成最终的 YAML 文件
- **部署脚本** (`deploy-*.sh`)：只负责部署，使用生成的 YAML 文件
- **模板文件**：包含占位符的 Kubernetes 资源定义
- **配置文件** (`generate.conf`)：配置需要生成的资源和模板路径

## 目录结构

```
应用根目录/
├── resources/
│   ├── custom-values/              # 生成脚本和配置目录
│   │   ├── generate.sh             # YAML 生成脚本
│   │   ├── generate.conf           # 生成配置文件
│   │   ├── .gitignore              # 忽略生成的 YAML 文件
│   │   ├── templates/              # 统一模板文件目录
│   │   │   ├── app/                # 主应用模板（Deployment、Service）
│   │   │   │   └── 应用名.yaml
│   │   │   ├── configmap/          # ConfigMap 模板
│   │   │   │   └── *.yaml
│   │   │   ├── secret/              # Secret 模板
│   │   │   │   └── *.yaml
│   │   │   ├── ingress/            # Ingress 模板
│   │   │   │   └── ingress.yaml
│   │   │   └── middleware/         # Middleware 模板
│   │   │       └── *.yaml
│   │   └── *-generated.yaml        # 生成的 YAML 文件（不提交）
│   └── source/                     # 应用源代码
├── deploy-应用名/
│   ├── deploy-应用名.sh            # 部署脚本（使用生成的 YAML）
│   └── deploy-应用名.conf          # 部署配置
```

## 工作流程

### 1. 创建模板文件

手动创建包含占位符的 Kubernetes 资源模板文件。

#### 模板文件位置

所有模板文件统一存放在 `resources/custom-values/templates/` 目录下，按资源类型分类：

- **主应用模板**：`resources/custom-values/templates/app/应用名.yaml`
- **ConfigMap 模板**：`resources/custom-values/templates/configmap/资源名.yaml`
- **Secret 模板**：`resources/custom-values/templates/secret/资源名.yaml`
- **Ingress 模板**：`resources/custom-values/templates/ingress/ingress.yaml`
- **Middleware 模板**：`resources/custom-values/templates/middleware/资源名.yaml`

#### 占位符格式

支持三种占位符格式：

1. **标准环境变量**：`${VAR}`
   ```yaml
   namespace: ${NAMESPACE}
   image: ${IMAGE_NAME}
   ```

2. **带默认值**：`${VAR:-default}`
   ```yaml
   namespace: ${NAMESPACE:-app-platform-dev}
   imagePullPolicy: ${IMAGE_PULL_POLICY:-IfNotPresent}
   ```

3. **Helm 风格**：`{{VAR}}`（会自动转换为 `${VAR}`）
   ```yaml
   namespace: {{NAMESPACE}}
   replicas: {{REPLICAS}}
   ```

#### 模板文件示例

**单资源模板** (`resources/custom-values/templates/app/incubator-app-bff.yaml`)：
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incubator-app-bff
  namespace: ${NAMESPACE:-app-platform-dev}
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: incubator-app-bff
        image: ${INCUBATOR_BFF_FULL_IMAGE_NAME}
        imagePullPolicy: ${IMAGE_PULL_POLICY:-IfNotPresent}
---
apiVersion: v1
kind: Service
metadata:
  name: incubator-app-bff
  namespace: ${NAMESPACE:-app-platform-dev}
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
```

**多资源分离** (`document-converter-app`)：
- `resources/custom-values/templates/app/deployment.yaml` - Deployment 模板
- `resources/custom-values/templates/app/service.yaml` - Service 模板

### 2. 配置生成脚本

在 `resources/custom-values/generate.conf` 中配置需要生成的资源。

#### 配置格式

```bash
# 格式：资源类型:模板路径:输出文件名:是否启用
GENERATE_RESOURCES=(
    "app:templates/app/incubator-app-bff.yaml:incubator-app-bff-generated.yaml:true"
    "configmap:templates/configmap/incubator-app-bff-config.yaml:incubator-app-bff-config-generated.yaml:true"
    "secret:templates/secret/incubator-app-bff-secret.yaml:incubator-app-bff-secret-generated.yaml:true"
    "ingress:templates/ingress/ingress.yaml:incubator-app-bff-ingress-generated.yaml:true"
    "middleware:templates/middleware/资源名.yaml:资源名-middleware-generated.yaml:true"
)
```

#### 路径说明

- **相对路径**：相对于 `custom-values/` 目录
- `templates/` - 模板文件统一目录
- 路径格式：`templates/资源类型/文件名.yaml`

#### 资源类型

- `app` - 应用资源（Deployment、Service、PVC、HPA 等）
- `configmap` - ConfigMap
- `secret` - Secret
- `ingress` - Ingress/IngressRoute
- `middleware` - Traefik Middleware

#### 生成顺序

```bash
# 格式：资源类型1:资源类型2（表示资源类型1需要在资源类型2之前生成）
GENERATE_ORDER=(
    "configmap:app"
    "secret:app"
    "app:ingress"
)
```

### 3. 运行生成脚本

#### 手动生成

```bash
cd resources/custom-values
./generate.sh
```

#### 自动生成

部署脚本会自动检查 YAML 文件是否存在，如果不存在会自动调用 `generate.sh` 生成：

```bash
cd deploy-应用名
./deploy-应用名.sh deploy
```

### 4. 部署应用

部署脚本会使用生成的 YAML 文件进行部署：

```bash
kubectl apply -f resources/custom-values/应用名-generated.yaml
```

## 完整示例

### 示例 1：单文件多资源

**模板文件** (`resources/custom-values/templates/app/incubator-app-bff.yaml`)：
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incubator-app-bff
  namespace: ${NAMESPACE:-app-platform-dev}
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: incubator-app-bff
        image: ${INCUBATOR_BFF_FULL_IMAGE_NAME}
---
apiVersion: v1
kind: Service
metadata:
  name: incubator-app-bff
  namespace: ${NAMESPACE:-app-platform-dev}
spec:
  type: ClusterIP
```

**配置文件** (`resources/custom-values/generate.conf`)：
```bash
GENERATE_RESOURCES=(
    "app:templates/app/incubator-app-bff.yaml:incubator-app-bff-generated.yaml:true"
)
```

**生成结果**：一个文件包含 Deployment 和 Service

### 示例 2：多文件分离

**模板文件**：
- `resources/custom-values/templates/app/deployment.yaml` - Deployment
- `resources/custom-values/templates/app/service.yaml` - Service

**配置文件**：
```bash
GENERATE_RESOURCES=(
    "app:templates/app/deployment.yaml:document-converter-deployment-generated.yaml:true"
    "app:templates/app/service.yaml:document-converter-service-generated.yaml:true"
)
```

**生成结果**：两个独立的 YAML 文件

## 添加新资源

### 添加 PVC

1. **创建模板文件** (`resources/custom-values/templates/app/pvc.yaml`)：
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: incubator-app-bff-pvc
  namespace: ${NAMESPACE:-app-platform-dev}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${STORAGE_SIZE:-10Gi}
  storageClassName: ${STORAGE_CLASS:-standard}
```

2. **更新配置文件** (`generate.conf`)：
```bash
GENERATE_RESOURCES=(
    "app:templates/app/incubator-app-bff.yaml:incubator-app-bff-generated.yaml:true"
    "app:templates/app/pvc.yaml:incubator-app-bff-pvc-generated.yaml:true"  # 新增
)
```

3. **在 generate.sh 中设置环境变量**（如果需要）：
```bash
export STORAGE_SIZE="${STORAGE_SIZE:-10Gi}"
export STORAGE_CLASS="${STORAGE_CLASS:-standard}"
```

### 添加 HPA

1. **创建模板文件** (`resources/custom-values/templates/app/hpa.yaml`)：
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: incubator-app-bff-hpa
  namespace: ${NAMESPACE:-app-platform-dev}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: incubator-app-bff
  minReplicas: ${HPA_MIN_REPLICAS:-1}
  maxReplicas: ${HPA_MAX_REPLICAS:-10}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: ${HPA_CPU_TARGET:-70}
```

2. **更新配置文件**：
```bash
GENERATE_RESOURCES=(
    "app:templates/app/incubator-app-bff.yaml:incubator-app-bff-generated.yaml:true"
    "app:templates/app/hpa.yaml:incubator-app-bff-hpa-generated.yaml:true"  # 新增
)
```

## 环境变量设置

环境变量在 `generate.sh` 中设置，可以从以下来源获取：

1. **部署配置文件** (`deploy-应用名.conf`)：
```bash
DEPLOY_CONFIG="../../deploy-incubator-bff/deploy-incubator-bff.conf"
```

2. **generate.sh 中的默认值**：
```bash
export NAMESPACE="${NAMESPACE:-${INCUBATOR_BFF_NAMESPACE:-app-platform-dev}}"
export INCUBATOR_BFF_FULL_IMAGE_NAME="${INCUBATOR_BFF_IMAGE_REGISTRY}/${INCUBATOR_BFF_IMAGE_PROJECT}/${INCUBATOR_BFF_IMAGE}:${INCUBATOR_BFF_TAG}"
```

3. **命令行环境变量**（优先级最高）

## 占位符处理机制

`generate.sh` 会根据资源类型采用不同的处理方式：

### app 类型
```bash
# 处理 ${VAR:-default} → ${VAR}，然后使用 envsubst
sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$template" | envsubst > "$output"
```

### configmap/secret 类型
```bash
# 直接使用 envsubst
envsubst < "$template" > "$output"
```

### ingress/middleware 类型
```bash
# 处理 {{VAR}} → ${VAR}，然后处理 ${VAR:-default} → ${VAR}
sed -e 's/{{\([^}]*\)}}/${\1}/g' -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$template" | envsubst > "$output"
```

## 验证机制

生成脚本会自动验证生成的 YAML 文件：

```bash
kubectl apply --dry-run=client -f "$yaml_file"
```

如果验证失败，会显示错误信息并退出。

## 与部署脚本的集成

部署脚本会自动检查生成的 YAML 文件是否存在：

```bash
if [ ! -f "$APP_YAML" ]; then
    log_warn "生成的 YAML 文件不存在，自动运行生成脚本..."
    if [ -f "$CUSTOM_VALUES_DIR/generate.sh" ]; then
        bash "$CUSTOM_VALUES_DIR/generate.sh"
    fi
fi
```

这意味着：
- ✅ 可以直接运行部署脚本，无需手动先运行 `generate.sh`
- ✅ `deploy-app-platform-all` 可以正常工作
- ✅ 支持 CI/CD 自动化部署

## 最佳实践

### 1. 模板文件组织

- **统一位置**：所有模板文件统一放在 `resources/custom-values/templates/` 目录下
- **按类型分类**：使用子目录分类（`app/`、`configmap/`、`secret/`、`ingress/`、`middleware/`）
- **相关资源集中**：Deployment 和 Service 可以放在同一个文件
- **独立资源分离**：PVC、HPA、PDB 等可以单独文件

### 2. 占位符使用

- ✅ 使用 `${VAR:-default}` 提供默认值
- ✅ 环境相关的值使用占位符（namespace、镜像地址等）
- ❌ 不要对固定值使用占位符（如 `kind: Deployment`）

### 3. 配置文件管理

- ✅ 所有资源都在 `GENERATE_RESOURCES` 中配置
- ✅ 使用 `GENERATE_ORDER` 控制生成顺序
- ✅ 通过 `:true/:false` 控制资源启用/禁用

### 4. 版本控制

- ✅ 模板文件提交到 Git
- ✅ 生成的 YAML 文件不提交（`.gitignore` 已配置）
- ✅ `generate.sh` 和 `generate.conf` 提交到 Git

## 常见问题

### Q: 如何添加新的资源类型？

A: 在 `generate.conf` 中添加新的条目，资源类型可以是 `app`、`configmap`、`secret`、`ingress`、`middleware` 等。

### Q: 模板文件可以包含多个资源吗？

A: 可以，使用 `---` 分隔多个资源。例如：
```yaml
apiVersion: apps/v1
kind: Deployment
...
---
apiVersion: v1
kind: Service
...
```

### Q: 如何在不同环境使用不同的配置？

A: 通过环境变量设置不同的值，模板文件中的占位符会自动替换。例如：
```bash
export NAMESPACE="app-platform-prod"
export IMAGE_TAG="2.0.0"
./generate.sh
```

### Q: 生成的 YAML 文件在哪里？

A: 所有生成的 YAML 文件都在 `resources/custom-values/` 目录下，文件名以 `-generated.yaml` 结尾。

### Q: 如何调试生成问题？

A: 
1. 检查模板文件中的占位符是否正确
2. 检查 `generate.sh` 中是否设置了相应的环境变量
3. 查看生成脚本的错误输出
4. 使用 `kubectl apply --dry-run=client` 验证生成的 YAML

## 相关文件

- `resources/custom-values/generate.sh` - 生成脚本
- `resources/custom-values/generate.conf` - 配置文件
- `resources/custom-values/.gitignore` - Git 忽略规则
- `deploy-应用名/deploy-应用名.sh` - 部署脚本

## 参考示例

- `incubator-app/incubator-app-bff` - 单文件多资源示例（包含 Deployment + Service）
- `incubator-app/incubator-app-ssr` - SSR 应用示例（端口 3000）
- `document-converter-app/document-converter-bff` - 多文件分离示例（Deployment 和 Service 分离）
- `celeryworker-incubator` - 包含 ConfigMap/Secret/Ingress 的完整示例

## 应用状态

所有应用现在都有完整的主应用模板文件：

### Business Apps
- ✅ `incubator-app/incubator-app-bff` - 主模板已对齐
- ✅ `incubator-app/incubator-app-ssr` - 主模板已创建并对齐
- ✅ `incubator-app/celeryworker-incubator` - 完整模板
- ✅ `llmops-app/llmops-app-bff` - 主模板完整
- ✅ `llmops-app/llmops-app-ssr` - 主模板已创建
- ✅ `llmops-app/celeryworker-llmops` - 完整模板

### Shared Apps
- ✅ `document-converter-app/document-converter-bff` - 多文件分离模板
- ✅ `onlyoffice-docs-app/onlyoffice-docs-bff` - Helm 部署（仅 Ingress/Middleware 模板）
