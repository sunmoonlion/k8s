# APP 平台组件开发总结

## 目录

- [概述](#概述)
- [LLMOps Service 组件](#llmops-service-组件)
  - [组件架构](#组件架构)
  - [目录结构](#目录结构)
  - [构建流程](#构建流程)
  - [部署流程](#部署流程)
  - [配置文件说明](#配置文件说明)
  - [开发决策与设计](#开发决策与设计)
  - [使用指南](#使用指南)

---

## 概述

APP 平台（`app-platform`）是 SunMoonAI 平台中的应用服务层，负责部署和管理各种应用服务。本文档系统总结了 `llmops-service` 组件的开发过程、架构设计和使用方法。

### 统一的开发流程

所有 APP 平台组件遵循统一的开发流程：

1. **源代码开发** (`resources/source/`)
   - 开发应用代码（如 `app.py`、`requirements.txt`）
   - 编写 Dockerfile
   - 源代码和 Dockerfile 统一存放在 `resources/source/` 目录

2. **构建镜像**
   - 使用 `resources/source/Dockerfile` 构建 Docker 镜像
   - 推送到镜像仓库（如 Harbor）

3. **开发 Kubernetes 配置** (`resources/`)
   - 根据镜像创建 `deployment.yaml`
   - 创建 `service.yaml` 等资源配置
   - 配置环境变量、资源限制等

4. **部署** (`deploy-*/`)
   - 使用部署脚本应用 Kubernetes 配置
   - 执行部署到目标集群

**目录结构示例**：
```
*-app/
└── *-bff/
    ├── resources/
    │   ├── source/              # 1. 源代码和 Dockerfile
    │   │   ├── app.py
    │   │   ├── requirements.txt
    │   │   └── Dockerfile
    │   ├── deployment.yaml      # 3. Kubernetes 配置
    │   └── service.yaml
    └── deploy-*/                 # 4. 部署脚本
```

---

## LLMOps Service 组件

### 组件架构

LLMOps Service 是 SunMoonAI 平台的 Backend API 服务，基于 FastAPI 框架，提供 RESTful API 接口和 Celery 任务定义。

#### 架构特点

1. **独立构建与部署**：LLMOps Service 作为独立的应用服务，拥有自己的构建和部署流程
2. **镜像管理**：使用 Harbor 作为镜像仓库，支持镜像版本管理
3. **配置分离**：构建配置（`build.conf`）和部署配置（`deploy-llmops-service.conf`）分离
4. **环境支持**：支持 dev 和 prod 环境，通过命名空间隔离
5. **与 Celery Worker 协作**：Backend 镜像包含完整的应用代码，Celery Worker 通过 Init Container 从该镜像提取任务定义

#### 架构关系图

```
sunmoonai-llmops-service/       ← 源代码项目
  └── app/                       ← 应用代码（FastAPI + Celery 任务定义）
           │
           │ 复制源代码（一次性操作）
           ▼
llmops-service/resources/
  └── source/                    ← 源代码和 Dockerfile（版本控制）
           │
           │ 构建时复制（临时）
           ▼
llmops-service/build/
  └── app/                       ← 临时构建目录（.gitignore）
           │
           │ docker build
           ▼
llmops-service:1.0.0             ← 本地镜像
           │
           │ docker tag & push
           ▼
harbor.sunmoonai.com:30443/
  k8s-images/llmops-service:1.0.0  ← Harbor 镜像
           │
           │ Kubernetes 拉取
           ▼
Kubernetes Pod (llmops-service)  ← 运行中的应用
```

---

### 目录结构

```
llmops-service/
├── build/                                    # 构建相关
│   ├── Dockerfile                            # Backend 镜像构建文件
│   ├── build.conf                            # 构建配置（镜像名称、标签、推送开关）
│   ├── .gitignore                            # 忽略临时构建文件
│   └── README.md                             # 构建说明文档
│
├── deploy-llmops-service/                    # 部署相关
│   ├── deploy-llmops-service.sh              # 主部署脚本
│   ├── deploy-llmops-service.conf            # 部署配置（Harbor、Ingress、Secrets 等）
│   ├── ingress/                              # Ingress 配置
│   │   ├── ingress.yaml                      # Traefik IngressRoute
│   │   ├── middleware.yaml                   # Traefik Middleware
│   │   └── deploy-ingress/                  # Ingress 部署脚本
│   └── secrets/                              # Secrets 和 ConfigMaps
│       ├── llmops-service-secret/            # Secret 配置
│       ├── llmops-service-config/            # ConfigMap 配置
│       └── deploy-secrets-all/               # 统一部署脚本
│
├── resources/                                 # Kubernetes 资源
│   ├── llmops-service.yaml                   # Deployment 和 Service 定义
│   └── source/                                # 源代码和 Dockerfile（版本控制）
│
└── README.md                                 # 组件说明文档
```

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
4. **开发 Kubernetes 配置**：在 `resources/` 中创建 `deployment.yaml`、`service.yaml` 等
5. **部署**：使用部署脚本部署到 Kubernetes

```bash
# 首次或更新时，复制源代码
cp -r /path/to/sunmoonai-llmops-service/app/* k8s/sunmoonai/app-platform/business-apps/llmops-app/resources/source/
```

#### 2. 构建过程

构建流程由 `deploy-llmops-service.sh` 脚本自动化处理：

1. **构建镜像**：使用 `resources/source/Dockerfile` 构建镜像
2. **执行构建**：在 `build/` 目录执行 `docker build`
3. **生成镜像**：生成 `llmops-service:1.0.0` 本地镜像
4. **可选推送**：如果 `PUSH_IMAGES_AFTER_BUILD=true`，自动推送到 Harbor

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
| `build` | 仅构建镜像 | 根据 `build.conf` 中的 `PUSH_IMAGES_AFTER_BUILD` 决定是否推送 |
| `deploy` | 部署服务 | 根据 `BUILD_IMAGE_BEFORE_DEPLOY` 决定是否构建镜像，然后部署到 Kubernetes |
| `undeploy` | 卸载服务 | 删除 Deployment、Service、Secrets、ConfigMaps、Ingress |
| `status` | 查看状态 | 显示 Pods、Services、ConfigMaps、Secrets 状态 |

#### deploy 命令详细流程

```bash
./deploy-llmops-service.sh deploy dev app-platform-dev
```

执行步骤（根据 `BUILD_IMAGE_BEFORE_DEPLOY` 配置）：

**当 `BUILD_IMAGE_BEFORE_DEPLOY=true` 时**（默认，开发环境推荐）：

1. **构建镜像**
   ```bash
   build_backend_image()
   - 检查源代码目录
   - 复制源代码到 build/app/
   - 执行 docker build
   - 生成 llmops-service:1.0.0 镜像
   ```

2. **推送到 Harbor**（强制，失败则报错）
   ```bash
   - docker tag llmops-service:1.0.0 harbor.sunmoonai.com:30443/k8s-images/llmops-service:1.0.0
   - docker push harbor.sunmoonai.com:30443/k8s-images/llmops-service:1.0.0
   ```

3. **部署到 Kubernetes**
   ```bash
   deploy_web_api()
   - 检查命名空间
   - 部署 Secrets 和 ConfigMaps
   - 部署 Deployment 和 Service
   - 部署 Ingress（如果启用）
   ```

**当 `BUILD_IMAGE_BEFORE_DEPLOY=false` 时**（生产环境推荐）：

1. **跳过构建和推送**
   - 直接从 Harbor 拉取已存在的镜像
   - 提示确保镜像已存在于 Harbor 仓库中

2. **部署到 Kubernetes**
   ```bash
   deploy_web_api()
   - 检查命名空间
   - 部署 Secrets 和 ConfigMaps
   - 部署 Deployment 和 Service（使用 Harbor 镜像）
   - 部署 Ingress（如果启用）
   ```

#### 环境支持

- **dev 环境**：`app-platform-dev` 命名空间
- **prod 环境**：`app-platform-prod` 命名空间

通过命令行参数指定：
```bash
./deploy-llmops-service.sh deploy dev app-platform-dev  # dev 环境
./deploy-llmops-service.sh deploy prod app-platform-prod  # prod 环境
```

---

### 配置文件说明

#### 1. build/build.conf（构建配置）

```conf
# 镜像名称和标签
LLMOPS_SERVICE_IMAGE="llmops-service"
LLMOPS_SERVICE_TAG="1.0.0"

# 源代码路径
SOURCE_DIR="../resources/source"

# 构建选项
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."

# 镜像推送配置
PUSH_IMAGES_AFTER_BUILD="false"  # build 命令是否自动推送
```

**关键配置**：
- `LLMOPS_SERVICE_IMAGE` 和 `LLMOPS_SERVICE_TAG`：定义镜像名称和版本
- `PUSH_IMAGES_AFTER_BUILD`：控制 `build` 命令是否自动推送镜像

#### 2. deploy-llmops-service/deploy-llmops-service.conf（部署配置）

```conf
# 基础配置
LLMOPS_SERVICE_PROJECT_ID="sunmoonai"
LLMOPS_SERVICE_NAMESPACE="app-platform-dev"
ENVIRONMENT="development"

# 源代码配置
# 源代码目录（统一使用 resources/source/）
SOURCE_DIR="resources/source"

# Harbor 镜像仓库配置
LLMOPS_SERVICE_IMAGE_REGISTRY="harbor.sunmoonai.com:30443"
LLMOPS_SERVICE_IMAGE_PROJECT="k8s-images"
LLMOPS_SERVICE_IMAGE_PULL_SECRET_NAME="harbor-registry-secret"

# 访问与端口配置
LLMOPS_SERVICE_TLS_ENABLED="true"
LLMOPS_SERVICE_UNIFIED_HOST="llmops.sunmoonai.com"
LLMOPS_SERVICE_NODE_IP="101.126.151.0"

# 子级部署控制
secrets_enabled="true"
ingress_enabled="true"

# 部署优先级
secrets_priority=2000
ingress_priority=100

# 部署前构建镜像开关
BUILD_IMAGE_BEFORE_DEPLOY="true"
```

**关键配置**：
- `SOURCE_DIR`：源代码目录路径（统一使用 `resources/source/`）
- `BUILD_IMAGE_BEFORE_DEPLOY`：是否在部署前构建镜像（`true`=构建并推送，`false`=直接使用 Harbor 镜像）
- Harbor 配置：`deploy` 命令使用 Harbor 镜像
- Ingress 配置：支持 HTTPS（30443 端口）、统一域名、IP 访问

#### 3. resources/llmops-service.yaml（Kubernetes 资源）

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llmops-service
  namespace: ${NAMESPACE:-app-platform-dev}
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: llmops-service
        image: ${LLMOPS_SERVICE_FULL_IMAGE_NAME}  # Harbor 镜像路径
        imagePullPolicy: ${IMAGE_PULL_POLICY:-IfNotPresent}
        envFrom:
        - configMapRef:
            name: llmops-service-config
        - secretRef:
            name: llmops-service-secret
```

**关键点**：
- 使用环境变量替换（`envsubst`）动态设置镜像名称和命名空间
- 通过 ConfigMap 和 Secret 注入配置
- 支持健康检查（liveness 和 readiness probes）

---

### 开发决策与设计

#### 1. 源代码管理策略

**决策**：使用 `resources/source/` 目录统一管理源代码和 Dockerfile

**原因**：
- 源代码、Dockerfile 和依赖文件统一管理，结构清晰
- 确保构建的一致性（源代码版本可控）
- 支持离线构建场景
- 符合标准的容器化应用开发流程：源代码 → 镜像 → 配置 → 部署

**实现**：
- 源代码和 Dockerfile 存放在 `resources/source/` 目录
- 构建时直接使用 `resources/source/Dockerfile` 构建镜像
- Kubernetes 资源配置存放在 `resources/` 目录（如 `deployment.yaml`、`service.yaml`）

#### 2. 构建与部署配置分离

**决策**：构建配置（`build.conf`）和部署配置（`deploy-llmops-service.conf`）分离

**原因**：
- 构建配置关注镜像名称、标签、推送开关
- 部署配置关注 Harbor、Ingress、Secrets 等
- 职责清晰，便于维护

**实现**：
- `build.conf`：镜像名称、标签、`PUSH_IMAGES_AFTER_BUILD`
- `deploy-llmops-service.conf`：Harbor 配置、Ingress 配置、Secrets 配置

#### 3. deploy 命令灵活构建策略

**决策**：`deploy` 命令根据 `BUILD_IMAGE_BEFORE_DEPLOY` 开关决定是否构建镜像

**原因**：
- 支持开发环境自动构建最新代码（`BUILD_IMAGE_BEFORE_DEPLOY=true`）
- 支持生产环境使用已构建好的稳定镜像（`BUILD_IMAGE_BEFORE_DEPLOY=false`）
- 提供灵活的部署选项，适应不同场景需求

**实现**：
- `BUILD_IMAGE_BEFORE_DEPLOY=true`（默认）：构建镜像 → 推送到 Harbor → 部署到 Kubernetes
- `BUILD_IMAGE_BEFORE_DEPLOY=false`：直接从 Harbor 拉取镜像 → 部署到 Kubernetes
- 推送失败时立即报错并退出
- `build` 命令可选推送（根据 `PUSH_IMAGES_AFTER_BUILD` 配置）

#### 4. Secrets 和 ConfigMaps 统一管理

**决策**：使用多层级结构管理 Secrets 和 ConfigMaps

**原因**：
- 每个 Secret/ConfigMap 有独立的部署脚本和配置
- 统一部署脚本管理所有 Secrets 和 ConfigMaps
- 支持优先级控制部署顺序

**实现**：
```
secrets/
├── llmops-service-secret/
│   ├── llmops-service-secret.yaml
│   └── deploy-llmops-service-secret/
│       ├── deploy-llmops-service-secret.sh
│       └── deploy-llmops-service-secret.conf
├── llmops-service-config/
│   └── deploy-llmops-service-config/
│       ├── deploy-llmops-service-config.sh
│       └── deploy-llmops-service-config.conf
└── deploy-secrets-all/
    ├── deploy-secrets-all.sh
    └── deploy-secrets-all.conf
```

#### 5. Ingress 配置对齐

**决策**：Ingress 配置与其他组件对齐（统一域名、IP 访问、HTTPS）

**原因**：
- 保持平台配置的一致性
- 支持多种访问方式（域名、IP、统一域名）
- 使用 Traefik 作为 Ingress Controller

**实现**：
- 支持 HTTPS（30443 端口）
- 支持统一域名路由（`www.sunmoonai.com/api/v1`）
- 支持 IP 访问（`101.126.151.0/api/v1`）
- 支持外部域名（`llmops.sunmoonai.com/api/v1`）

---

### 使用指南

#### 快速开始

1. **准备源代码**
   ```bash
   cd k8s/sunmoonai/app-platform/business-apps/llmops-app
   cp -r /path/to/sunmoonai-llmops-service/app/* resources/source/
   ```

2. **构建镜像**
   ```bash
   cd deploy-llmops-service
   ./deploy-llmops-service.sh build
   ```

3. **部署服务**
   ```bash
   ./deploy-llmops-service.sh deploy dev app-platform-dev
   ```

#### 常用操作

**查看状态**
```bash
./deploy-llmops-service.sh status dev app-platform-dev
```

**卸载服务**
```bash
./deploy-llmops-service.sh undeploy dev app-platform-dev
```

**更新代码并重新部署**
```bash
# 1. 更新源代码
cp -r /path/to/sunmoonai-llmops-service/app/* ../resources/source/

# 2. 重新部署（会自动构建和推送）
./deploy-llmops-service.sh deploy dev app-platform-dev
```

#### 配置说明

**修改镜像版本**
编辑 `build/build.conf`：
```conf
LLMOPS_SERVICE_TAG="1.0.1"
```

**修改 Harbor 配置**
编辑 `deploy-llmops-service/deploy-llmops-service.conf`：
```conf
LLMOPS_SERVICE_IMAGE_REGISTRY="harbor.sunmoonai.com:30443"
LLMOPS_SERVICE_IMAGE_PROJECT="k8s-images"
```

**修改部署前构建行为**
编辑 `deploy-llmops-service/deploy-llmops-service.conf`：
```conf
BUILD_IMAGE_BEFORE_DEPLOY="true"   # true=构建并推送，false=直接使用 Harbor 镜像
```

**修改 Ingress 配置**
编辑 `deploy-llmops-service/deploy-llmops-service.conf`：
```conf
LLMOPS_SERVICE_UNIFIED_HOST="llmops.sunmoonai.com"
LLMOPS_SERVICE_NODE_IP="101.126.151.0"
```

#### 故障排查

**镜像推送失败**
- 检查 Harbor 配置是否正确
- 确认已登录 Harbor：`docker login harbor.sunmoonai.com:30443`
- 检查网络连接

**Pod 无法启动**
- 检查镜像是否已推送到 Harbor
- 检查 Secrets 和 ConfigMaps 是否已部署
- 查看 Pod 日志：`kubectl logs -n app-platform-dev -l app=llmops-service`

**Ingress 无法访问**
- 检查 Ingress 是否已部署：`kubectl get ingressroute -n app-platform-dev`
- 检查 Traefik 是否正常运行
- 检查域名解析和防火墙规则

---

## 总结

LLMOps Service 组件的开发遵循了以下原则：

1. **配置分离**：构建配置和部署配置分离，职责清晰
2. **自动化流程**：构建、推送、部署全流程自动化
3. **环境支持**：支持 dev 和 prod 环境，通过命名空间隔离
4. **统一管理**：Secrets、ConfigMaps、Ingress 统一管理
5. **错误处理**：关键步骤失败时提供清晰的错误信息

该组件为 APP 平台的其他组件提供了参考模板，可以基于此模板快速开发新的应用服务。

