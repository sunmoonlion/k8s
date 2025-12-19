# APP 平台组件开发总结

## 目录

- [概述](#概述)
- [LLMOps App BFF 组件](#llmops-app-bff-组件)
  - [组件架构](#组件架构)
  - [目录结构](#目录结构)
  - [构建流程](#构建流程)
  - [部署流程](#部署流程)
  - [配置文件说明](#配置文件说明)
  - [开发决策与设计](#开发决策与设计)
  - [使用指南](#使用指南)

---

## 概述

APP 平台（`app-platform`）是 SunMoonAI 平台中的应用服务层，负责部署和管理各种应用服务。本文档系统总结了 `llmops-app-bff` 组件的开发过程、架构设计和使用方法。

### 统一的开发流程

所有 APP 平台组件遵循统一的开发流程：

1. **源代码开发** (`resources/source/`)
   - 开发应用代码（如 `app.py`、`requirements.txt`）
   - 编写 Dockerfile
   - 源代码和 Dockerfile 统一存放在 `resources/source/` 目录

2. **构建镜像**
   - 使用 `resources/source/Dockerfile` 构建 Docker 镜像
   - 推送到镜像仓库（如 Harbor）

3. **创建 Kubernetes 模板** (`resources/custom-values/templates/`)
   - 创建主应用模板（Deployment、Service）：`templates/app/应用名.yaml`
   - 创建 ConfigMap 模板：`templates/configmap/资源名.yaml`
   - 创建 Secret 模板：`templates/secret/资源名.yaml`
   - 创建 Ingress 模板：`templates/ingress/ingress.yaml`
   - 创建 Middleware 模板：`templates/middleware/资源名.yaml`
   - 模板文件使用占位符（如 `${VAR}`、`${VAR:-default}`）

4. **配置 YAML 生成** (`resources/custom-values/`)
   - 配置 `generate.conf`：定义需要生成的资源和模板路径
   - 运行 `generate.sh`：根据模板生成最终的 YAML 文件
   - 生成的 YAML 文件存放在 `resources/custom-values/` 目录

5. **部署** (`deploy-*/`)
   - 使用部署脚本应用生成的 YAML 文件
   - 部署脚本会自动检查并生成 YAML（如果缺失）

**目录结构示例**：
```
*-app/
└── *-bff/
    ├── resources/
    │   ├── source/                          # 1. 源代码和 Dockerfile
    │   │   ├── app.py
    │   │   ├── requirements.txt
    │   │   └── Dockerfile
    │   └── custom-values/                   # 3-4. YAML 生成
    │       ├── generate.sh                   # YAML 生成脚本
    │       ├── generate.conf                # 生成配置
    │       ├── templates/                   # 模板文件目录
    │       │   ├── app/
    │       │   │   └── 应用名.yaml         # 主应用模板
    │       │   ├── configmap/
    │       │   ├── secret/
    │       │   ├── ingress/
    │       │   └── middleware/
    │       └── *-generated.yaml             # 生成的 YAML（不提交）
    └── deploy-*/                            # 5. 部署脚本
        ├── deploy-应用名.sh
        └── deploy-应用名.conf
```

---

## LLMOps App BFF 组件

### 组件架构

LLMOps App BFF 是 SunMoonAI 平台的 Backend API 服务，基于 FastAPI 框架，提供 RESTful API 接口和 Celery 任务定义。

#### 架构特点

1. **独立构建与部署**：LLMOps App BFF 作为独立的应用服务，拥有自己的构建和部署流程
2. **镜像管理**：使用 Harbor 作为镜像仓库，支持镜像版本管理
3. **配置分离**：构建配置（`build.conf`）和部署配置（`deploy-llmops-bff.conf`）分离
4. **环境支持**：支持 dev 和 prod 环境，通过命名空间隔离
5. **与 Celery Worker 协作**：Backend 镜像包含完整的应用代码，Celery Worker 通过 Init Container 从该镜像提取任务定义

#### 架构关系图

```
sunmoonai-llmops-service/       ← 源代码项目
  ├── app/                       ← 应用代码（FastAPI + Celery 任务定义）
  └── build/                     ← 构建脚本和配置
      ├── Dockerfile
      ├── build.conf
      └── build-image.sh
           │
           │ 复制源代码（一次性操作，用于参考）
           ▼
llmops-app-bff/resources/
  └── source/                    ← 源代码（版本控制，用于参考）
           │
           │ 镜像构建（在源代码项目中执行）
           ▼
sunmoonai-llmops-service/build/
  └── build-image.sh             ← 构建脚本
           │
           │ docker build
           ▼
llmops-app-bff:1.0.0             ← 本地镜像
           │
           │ docker tag & push
           ▼
harbor.sunmoonai.com:30443/
  k8s-images/llmops-app-bff:1.0.0  ← Harbor 镜像
           │
           │ Kubernetes 拉取
           ▼
Kubernetes Pod (llmops-app-bff)  ← 运行中的应用
```

---

### 目录结构

```
llmops-app-bff/
├── deploy-llmops-bff/                        # 部署相关
│   ├── deploy-llmops-bff.sh                 # 主部署脚本（使用生成的 YAML）
│   └── deploy-llmops-bff.conf               # 部署配置（Harbor、Ingress、Secrets 等）
│
├── resources/                                 # Kubernetes 资源
│   ├── custom-values/                        # YAML 生成目录
│   │   ├── generate.sh                       # YAML 生成脚本
│   │   ├── generate.conf                     # 生成配置文件
│   │   ├── .gitignore                        # 忽略生成的 YAML 文件
│   │   ├── templates/                        # 统一模板文件目录
│   │   │   ├── app/
│   │   │   │   └── llmops-app-bff.yaml      # 主应用模板（Deployment + Service）
│   │   │   ├── configmap/
│   │   │   │   └── llmops-service-config.yaml  # 注意：文件名可能仍使用旧名称
│   │   │   ├── secret/
│   │   │   │   └── llmops-service-secret.yaml   # 注意：文件名可能仍使用旧名称
│   │   │   ├── ingress/
│   │   │   │   └── ingress.yaml
│   │   │   └── middleware/
│   │   │       └── *.yaml
│   │   └── *-generated.yaml                  # 生成的 YAML 文件（不提交）
│   └── source/                                # 源代码（版本控制）
│       └── app/                               # 应用代码
│           ├── main.py
│           ├── requirements.txt
│           └── ...
│
└── README.md                                 # 组件说明文档
```

**注意**：
- 构建相关文件（Dockerfile、build.conf）在源代码项目中（如 `sunmoonai-llmops-service/build/`）
- 镜像构建使用源代码项目中的构建脚本
- `resources/source/` 目录存放应用源代码，用于版本控制和参考

---

### 构建流程

#### 1. 源代码准备

源代码和 Dockerfile 存放在 `resources/source/` 目录中，这样可以：
- 源代码、Dockerfile 和依赖文件统一管理
- 确保构建的一致性（源代码版本可控）
- 支持离线构建场景

**开发流程**：
1. **源代码开发**：在 `resources/source/` 中开发应用代码（如 `app.py`、`requirements.txt`）
2. **编写 Dockerfile**：在 `resources/source/` 中编写 `Dockerfile`
3. **构建镜像**：使用 Dockerfile 构建 Docker 镜像
4. **创建 Kubernetes 模板**：在 `resources/custom-values/templates/` 中创建模板文件
   - 主应用模板：`templates/app/应用名.yaml`（包含 Deployment 和 Service）
   - ConfigMap 模板：`templates/configmap/资源名.yaml`
   - Secret 模板：`templates/secret/资源名.yaml`
   - Ingress 模板：`templates/ingress/ingress.yaml`
   - Middleware 模板：`templates/middleware/资源名.yaml`
5. **配置 YAML 生成**：在 `generate.conf` 中配置需要生成的资源
6. **生成 YAML**：运行 `generate.sh` 生成最终的 YAML 文件
7. **部署**：使用部署脚本部署到 Kubernetes（会自动生成 YAML 如果缺失）

```bash
# 首次或更新时，复制源代码
cp -r /path/to/sunmoonai-llmops-service/app/* k8s/sunmoonai/app-platform/business-apps/llmops-app/llmops-app-bff/resources/source/
```

#### 2. 构建过程

构建流程在源代码项目中执行：

1. **构建镜像**：在源代码项目（如 `sunmoonai-llmops-service/build/`）中使用构建脚本
2. **执行构建**：运行 `build-image.sh build-push` 构建并推送镜像
3. **生成镜像**：生成 `llmops-app-bff:1.0.0` 本地镜像
4. **推送到 Harbor**：自动推送到 Harbor 镜像仓库

**注意**：镜像构建不在 k8s 配置目录中执行，而是在源代码项目的 `build/` 目录中执行。

#### 3. Dockerfile 说明

```dockerfile
FROM ghcr.io/br3ndonland/inboard:fastapi-0.68-python3.11

# 复制应用代码
COPY ./app/ /app/
WORKDIR /app/

# 使用 Hatch 管理依赖
ENV HATCH_ENV_TYPE_VIRTUAL_PATH=.venv
RUN hatch env prune && hatch env create production && pip install --upgrade setuptools

# 安装额外依赖
RUN bash -c "pip install argon2_cffi"

# FastAPI 应用配置
ENV APP_MODULE=app.main:app \
    PRE_START_PATH=/app/prestart.sh \
    PROCESS_MANAGER=gunicorn \
    WITH_RELOAD=false
```

**关键点**：
- 基于 `inboard:fastapi` 镜像，提供 FastAPI 运行环境
- 使用 Hatch 管理 Python 依赖（从 `pyproject.toml` 读取）
- 支持 `prestart.sh` 脚本（数据库初始化等）

---

### 部署流程

#### 命令说明

| 命令 | 功能 | 说明 |
|------|------|------|
| `deploy` | 部署服务 | 部署到 Kubernetes（需要先构建并推送镜像到 Harbor） |
| `undeploy` | 卸载服务 | 删除 Deployment、Service、Secrets、ConfigMaps、Ingress |
| `status` | 查看状态 | 显示 Pods、Services、ConfigMaps、Secrets 状态 |

**注意**：镜像构建在源代码项目中执行，不在部署脚本中。部署前需要确保镜像已构建并推送到 Harbor。

#### deploy 命令详细流程

```bash
./deploy-llmops-bff.sh deploy dev app-platform-dev
```

**前置条件**：确保镜像已构建并推送到 Harbor

执行步骤：

1. **生成 YAML 文件**（如果缺失）
   ```bash
   auto_generate_yaml()
   - 检查生成的 YAML 文件是否存在
   - 如果不存在，自动运行 generate.sh 生成
   ```

2. **部署到 Kubernetes**
   ```bash
   deploy_web_api()
   - 检查命名空间
   - 部署 Secrets 和 ConfigMaps（使用生成的 YAML）
   - 部署 Deployment 和 Service（使用 Harbor 镜像，使用生成的 YAML）
   - 部署 Ingress（如果启用，使用生成的 YAML）
   ```

**镜像构建**：
- 在源代码项目中执行（如 `sunmoonai-llmops-service/build/`）
- 使用 `build-image.sh build-push` 构建并推送镜像
- 部署脚本不负责构建镜像

#### 环境支持

- **dev 环境**：`app-platform-dev` 命名空间
- **prod 环境**：`app-platform-prod` 命名空间

通过命令行参数指定：
```bash
./deploy-llmops-bff.sh deploy dev app-platform-dev  # dev 环境
./deploy-llmops-bff.sh deploy prod app-platform-prod  # prod 环境
```

---

### 配置文件说明

#### 1. deploy-llmops-bff/deploy-llmops-bff.conf（部署配置）

**注意**：构建配置（`build.conf`、`Dockerfile`）在源代码项目中（如 `sunmoonai-llmops-service/build/`），不在 k8s 配置目录中。

```conf
# 基础配置
LLMOPS_BFF_PROJECT_ID="sunmoonai"
LLMOPS_BFF_NAMESPACE="app-platform-dev"
ENVIRONMENT="development"

# 源代码配置
# 源代码目录（统一使用 resources/source/）
SOURCE_DIR="resources/source"

# Harbor 镜像仓库配置
LLMOPS_BFF_IMAGE_REGISTRY="harbor.sunmoonai.com:30443"
LLMOPS_BFF_IMAGE_PROJECT="k8s-images"
LLMOPS_BFF_IMAGE_PULL_SECRET_NAME="harbor-registry-secret"

# 访问与端口配置
LLMOPS_BFF_TLS_ENABLED="true"
LLMOPS_BFF_UNIFIED_HOST="llmops.sunmoonai.com"
LLMOPS_BFF_NODE_IP="101.126.151.0"

# 子级部署控制
secrets_enabled="true"
ingress_enabled="true"

# 部署优先级
secrets_priority=2000
ingress_priority=100
```

**关键配置**：
- `SOURCE_DIR`：源代码目录路径（统一使用 `resources/source/`，用于参考）
- Harbor 配置：部署时使用 Harbor 镜像（需要先构建并推送）
- Ingress 配置：支持 HTTPS（30443 端口）、统一域名、IP 访问

**注意**：镜像构建在源代码项目中执行，不在部署配置中控制。

#### 3. resources/custom-values/generate.conf（YAML 生成配置）

```bash
# 格式：资源类型:模板路径:输出文件名:是否启用
GENERATE_RESOURCES=(
    "app:templates/app/llmops-app-bff.yaml:llmops-app-bff-generated.yaml:true"
    "configmap:templates/configmap/llmops-service-config.yaml:llmops-service-config-generated.yaml:true"
    "secret:templates/secret/llmops-service-secret.yaml:llmops-service-secret-generated.yaml:true"
    "ingress:templates/ingress/ingress.yaml:llmops-app-bff-ingress-generated.yaml:true"
)
```

**关键点**：
- 所有模板文件统一在 `templates/` 目录下，按资源类型分类
- 路径相对于 `custom-values/` 目录
- 生成的 YAML 文件存放在 `custom-values/` 目录

#### 4. resources/custom-values/templates/app/llmops-app-bff.yaml（主应用模板）

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llmops-app-bff
  namespace: ${NAMESPACE:-app-platform-dev}
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: llmops-app-bff
        image: ${LLMOPS_BFF_FULL_IMAGE_NAME}  # Harbor 镜像路径
        imagePullPolicy: ${IMAGE_PULL_POLICY:-IfNotPresent}
        envFrom:
        - configMapRef:
            name: llmops-app-bff-config
        - secretRef:
            name: llmops-app-bff-secret
---
apiVersion: v1
kind: Service
metadata:
  name: llmops-app-bff
  namespace: ${NAMESPACE:-app-platform-dev}
spec:
  type: ClusterIP
```

**关键点**：
- 使用占位符（`${VAR}`、`${VAR:-default}`）动态设置镜像名称和命名空间
- 通过 ConfigMap 和 Secret 注入配置
- 支持健康检查（liveness 和 readiness probes）
- 模板文件会被 `generate.sh` 处理，生成最终的 YAML 文件

---

### 开发决策与设计

#### 1. 源代码管理策略

**决策**：使用 `resources/source/` 目录统一管理源代码和 Dockerfile

**原因**：
- 源代码、Dockerfile 和依赖文件统一管理，结构清晰
- 确保构建的一致性（源代码版本可控）
- 支持离线构建场景
- 符合标准的容器化应用开发流程：源代码 → 镜像 → 模板 → 生成 YAML → 部署

**实现**：
- 源代码和 Dockerfile 存放在 `resources/source/` 目录
- 构建时直接使用 `resources/source/Dockerfile` 构建镜像
- Kubernetes 资源模板存放在 `resources/custom-values/templates/` 目录

#### 2. 构建与部署配置分离

**决策**：构建配置在源代码项目中，部署配置在 k8s 配置目录中

**原因**：
- 构建配置关注镜像名称、标签、推送开关，属于源代码项目的一部分
- 部署配置关注 Harbor、Ingress、Secrets 等，属于 k8s 配置的一部分
- 职责清晰，便于维护
- 构建和部署可以独立进行

**实现**：
- 构建配置：在源代码项目中（如 `sunmoonai-llmops-service/build/build.conf`）
- 部署配置：在 k8s 配置目录中（`deploy-llmops-bff/deploy-llmops-bff.conf`）

#### 3. 构建与部署分离

**决策**：镜像构建在源代码项目中执行，部署脚本只负责部署

**原因**：
- 构建和部署职责分离，构建由源代码项目管理
- 部署脚本专注于 Kubernetes 资源部署
- 支持独立构建和部署流程

**实现**：
- 镜像构建：在源代码项目中使用 `build/build-image.sh` 脚本
- 部署脚本：只负责部署到 Kubernetes，不执行构建
- 部署前需要确保镜像已构建并推送到 Harbor

#### 4. YAML 生成机制

**决策**：使用统一的 YAML 生成机制，将模板与部署逻辑分离

**原因**：
- 模板文件与部署逻辑分离，职责清晰
- 支持环境变量替换和占位符处理
- 自动验证生成的 YAML 文件
- 部署脚本可以自动生成 YAML（如果缺失）

**实现**：
- 所有模板文件统一在 `resources/custom-values/templates/` 目录下
- 使用 `generate.sh` 和 `generate.conf` 生成 YAML 文件
- 生成的 YAML 文件存放在 `resources/custom-values/` 目录
- 部署脚本自动检查并生成 YAML（如果缺失）

#### 5. Secrets 和 ConfigMaps 模板管理

**决策**：使用统一的模板目录管理 Secrets 和 ConfigMaps

**原因**：
- 所有模板文件统一位置，便于管理
- 通过 `generate.conf` 配置生成顺序
- 支持环境变量替换

**实现**：
```
resources/custom-values/templates/
├── configmap/
│   └── llmops-service-config.yaml  # 模板文件名（可能使用旧名称）
└── secret/
    └── llmops-service-secret.yaml  # 模板文件名（可能使用旧名称）
```

**注意**：模板文件名可能仍使用 `llmops-service-*`，但生成的资源名称（在模板中定义）应为 `llmops-app-bff-config` 和 `llmops-app-bff-secret`。

#### 6. Ingress 配置对齐

**决策**：Ingress 配置与其他组件对齐（统一域名、IP 访问、HTTPS）

**原因**：
- 保持平台配置的一致性
- 支持多种访问方式（域名、IP、统一域名）
- 使用 Traefik 作为 Ingress Controller

**实现**：
- Ingress 模板存放在 `resources/custom-values/templates/ingress/ingress.yaml`
- Middleware 模板存放在 `resources/custom-values/templates/middleware/` 目录
- 支持 HTTPS（30443 端口）
- 支持统一域名路由（`www.sunmoonai.com/api/v1`）
- 支持 IP 访问（`101.126.151.0/api/v1`）
- 支持外部域名（`llmops.sunmoonai.com/api/v1`）

---

### 使用指南

#### 快速开始

1. **准备源代码**
   ```bash
   cd k8s/sunmoonai/app-platform/business-apps/llmops-app/llmops-app-bff
   cp -r /path/to/sunmoonai-llmops-service/app/* resources/source/
   ```

2. **创建 Kubernetes 模板**
   ```bash
   # 创建主应用模板
   mkdir -p resources/custom-values/templates/app
   # 编辑 resources/custom-values/templates/app/llmops-app-bff.yaml
   
   # 创建 ConfigMap 和 Secret 模板
   mkdir -p resources/custom-values/templates/{configmap,secret}
   # 编辑相应的模板文件
   
   # 创建 Ingress 模板
   mkdir -p resources/custom-values/templates/ingress
   # 编辑 resources/custom-values/templates/ingress/ingress.yaml
   ```

3. **配置 YAML 生成**
   ```bash
   # 编辑 resources/custom-values/generate.conf
   # 配置需要生成的资源和模板路径
   ```

4. **生成 YAML 文件**（可选，部署时会自动生成）
   ```bash
   cd resources/custom-values
   ./generate.sh
   ```

5. **构建镜像**（在源代码项目中执行）
   ```bash
   cd /path/to/sunmoonai-llmops-service/build
   ./build-image.sh build-push
   ```

6. **部署服务**
   ```bash
   cd k8s/sunmoonai/app-platform/business-apps/llmops-app/llmops-app-bff/deploy-llmops-bff
   ./deploy-llmops-bff.sh deploy dev app-platform-dev
   ```

#### 常用操作

**查看状态**
```bash
./deploy-llmops-bff.sh status dev app-platform-dev
```

**卸载服务**
```bash
./deploy-llmops-bff.sh undeploy dev app-platform-dev
```

**更新代码并重新部署**
```bash
# 1. 更新源代码
cp -r /path/to/sunmoonai-llmops-service/app/* ../resources/source/

# 2. 更新模板文件（如果需要）
# 编辑 resources/custom-values/templates/ 下的模板文件

# 3. 重新生成 YAML（可选，部署时会自动生成）
cd ../resources/custom-values
./generate.sh

# 4. 重新构建镜像（在源代码项目中）
cd /path/to/sunmoonai-llmops-service/build
./build-image.sh build-push

# 5. 重新部署
cd k8s/sunmoonai/app-platform/business-apps/llmops-app/llmops-app-bff/deploy-llmops-bff
./deploy-llmops-bff.sh deploy dev app-platform-dev
```

#### 配置说明

**修改镜像版本**
编辑源代码项目中的 `build/build.conf`（如 `sunmoonai-llmops-service/build/build.conf`）：
```conf
LLMOPS_BFF_TAG="1.0.1"
```

**修改 Harbor 配置**
编辑 `deploy-llmops-bff/deploy-llmops-bff.conf`：
```conf
LLMOPS_BFF_IMAGE_REGISTRY="harbor.sunmoonai.com:30443"
LLMOPS_BFF_IMAGE_PROJECT="k8s-images"
```

**构建镜像**
在源代码项目中执行构建：
```bash
cd /path/to/sunmoonai-llmops-service/build
./build-image.sh build-push
```

**修改 Ingress 配置**
编辑 `deploy-llmops-bff/deploy-llmops-bff.conf`：
```conf
LLMOPS_BFF_UNIFIED_HOST="llmops.sunmoonai.com"
LLMOPS_BFF_NODE_IP="101.126.151.0"
```

**修改模板文件**
编辑 `resources/custom-values/templates/` 下的模板文件，然后重新生成 YAML：
```bash
cd resources/custom-values
./generate.sh
```

**修改生成配置**
编辑 `resources/custom-values/generate.conf`，添加或修改需要生成的资源：
```bash
GENERATE_RESOURCES=(
    "app:templates/app/llmops-app-bff.yaml:llmops-app-bff-generated.yaml:true"
    # 添加新资源...
)
```

#### 故障排查

**镜像推送失败**
- 检查 Harbor 配置是否正确
- 确认已登录 Harbor：`docker login harbor.sunmoonai.com:30443`
- 检查网络连接

**Pod 无法启动**
- 检查镜像是否已推送到 Harbor
- 检查生成的 YAML 文件是否存在：`ls resources/custom-values/*-generated.yaml`
- 检查 Secrets 和 ConfigMaps 是否已部署
- 查看 Pod 日志：`kubectl logs -n app-platform-dev -l app=llmops-app-bff`

**YAML 生成失败**
- 检查模板文件中的占位符是否正确
- 检查 `generate.sh` 中是否设置了相应的环境变量
- 查看生成脚本的错误输出
- 使用 `kubectl apply --dry-run=client` 验证生成的 YAML

**Ingress 无法访问**
- 检查 Ingress 是否已部署：`kubectl get ingressroute -n app-platform-dev`
- 检查 Traefik 是否正常运行
- 检查域名解析和防火墙规则

---

## 总结

LLMOps Service 组件的开发遵循了以下原则：

1. **配置分离**：构建配置和部署配置分离，职责清晰
2. **模板与部署分离**：使用 YAML 生成机制，模板文件与部署逻辑分离
3. **统一模板管理**：所有模板文件统一在 `resources/custom-values/templates/` 目录下
4. **自动化流程**：构建、推送、YAML 生成、部署全流程自动化
5. **环境支持**：支持 dev 和 prod 环境，通过命名空间隔离
6. **错误处理**：关键步骤失败时提供清晰的错误信息

### 新架构优势

- **职责清晰**：模板文件只负责定义资源结构，生成脚本负责变量替换，部署脚本只负责部署
- **易于维护**：所有模板文件统一位置，便于查找和管理
- **自动化**：部署脚本自动检查并生成 YAML（如果缺失），无需手动操作
- **可扩展**：通过 `generate.conf` 轻松添加新的资源类型

该组件为 APP 平台的其他组件提供了参考模板，可以基于此模板快速开发新的应用服务。更多关于 YAML 生成机制的详细信息，请参考 [YAML生成机制说明.md](./YAML生成机制说明.md)。

