# LLMOps Service (Backend API)

## 架构概述

LLMOps Service 的 Backend API 服务，负责提供 FastAPI 应用和 Celery 任务定义。

## 目录结构

```
llmops-service/
├── build/
│   ├── Dockerfile              # Backend 镜像构建文件
│   ├── .gitignore              # 忽略复制的源代码
│   └── README.md               # 构建说明
├── deploy-llmops-service/
│   └── deploy-llmops-service.sh  # 部署脚本（包含构建逻辑）
└── resources/
    └── web-api.yaml            # Kubernetes 部署配置
```

## 构建流程

### 1. 复制源代码
从 `sunmoonai-llmops-service/app` 复制到 `build/app/`

### 2. 构建镜像
在 `build/` 目录中构建 `sunmoonai-web-api:latest` 镜像

### 3. 部署到 Kubernetes
使用 `web-api.yaml` 部署服务

## 快速开始

### 构建镜像

```bash
cd deploy-llmops-service
./deploy-llmops-service.sh build
```

### 部署到 Kubernetes

```bash
./deploy-llmops-service.sh deploy app-platform-dev
```

### 构建并部署（一步完成）

```bash
./deploy-llmops-service.sh build-deploy app-platform-dev
```

## 架构关系

```
sunmoonai-llmops-service/       ← 源代码项目
  └── app/                       ← 应用代码
           │
           │ 复制源代码
           ▼
llmops-service/build/            ← 构建目录
  └── app/                       ← 复制的源代码（临时）
           │
           │ docker build
           ▼
sunmoonai-web-api:latest         ← Backend 镜像
           │
           │ 被以下服务使用：
           ├── web-api (本服务)
           └── celeryworker (Init Container 提取任务定义)
```

## 与 Celery Worker 的关系

- **Backend 镜像** (`sunmoonai-web-api:latest`) 包含完整的应用代码
- **Celery Worker** 通过 Init Container 从这个镜像提取任务定义代码
- **任务定义** 在 `sunmoonai-llmops-service/app/app/worker/` 中

## 注意事项

1. **源代码路径**：确保 `sunmoonai-llmops-service` 项目在正确的位置（相对于 k8s 目录）
2. **构建前准备**：确保源代码项目已更新
3. **镜像推送**：如果需要推送到镜像仓库，需要在构建后执行 `docker push`

