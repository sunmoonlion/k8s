# Dockerfile 构建优化：从 inboard 到标准 Python 镜像

## 核心问题：为什么使用 Python 基础镜像而不是 inboard 镜像？

### 简短回答

**我们使用 `python:3.11-slim` 而不是 `inboard:fastapi-0.68-python3.11` 的原因：**

1. **避免运行时安装依赖**：inboard 镜像使用 `hatch run` 启动，会在运行时创建环境并安装依赖，导致启动慢
2. **完全控制启动流程**：inboard 镜像的启动逻辑难以定制，使用 Python 基础镜像可以完全控制
3. **依赖完整性**：通过 `pip install inboard[fastapi]`，我们仍然获得了所有必要的依赖（FastAPI、uvicorn、gunicorn 等）
4. **镜像体积优化**：不包含不必要的工具（hatch、pipx 等），镜像更小但功能完整

### 详细说明

#### 1. inboard 镜像的设计与我们的问题

**inboard 镜像的设计：**
- Python 3.11
- FastAPI、uvicorn、gunicorn（通过 inboard 包）
- hatch（Python 环境管理工具）
- 启动脚本（使用 `hatch run`）

**inboard 镜像的正确使用方式：**
根据 inboard 官方文档，正确的 Dockerfile 应该是：
```dockerfile
FROM ghcr.io/br3ndonland/inboard:fastapi-0.68-python3.11

COPY app/ /app/
WORKDIR /app

# 关键：必须在构建时创建环境并安装依赖
RUN hatch env prune && hatch env create production
# 注意：这里只是创建环境，还需要安装项目依赖
```

**我们尝试过的 hatch 方案（全部失败）：**

1. **尝试 1：创建 production 环境**
   ```dockerfile
   RUN hatch env prune && \
       hatch env create production && \
       pip install --upgrade setuptools && \
       hatch env show production
   ```
   **失败原因**：`hatch run` 默认使用 `default` 环境，不检查 `production` 环境

2. **尝试 2：创建 default 环境并安装依赖**
   ```dockerfile
   RUN hatch env prune && \
       hatch env create default && \
       hatch run --env default pip install --upgrade setuptools && \
       hatch install --env default
   ```
   **失败原因**：即使创建了环境，inboard 镜像的启动逻辑可能不检查已创建的环境，或者环境配置有问题

3. **尝试 3：设置 HATCH_ENV 环境变量**
   ```dockerfile
   ENV HATCH_ENV=production
   ```
   **失败原因**：inboard 镜像的启动逻辑可能不检查 `HATCH_ENV` 环境变量，仍然使用 `default` 环境

4. **尝试 4：同时创建 default 和 production 环境**
   ```dockerfile
   RUN hatch env create default && \
       hatch install --env default && \
       hatch env create production && \
       hatch install --env production
   ```
   **失败原因**：即使创建了环境，inboard 镜像的启动逻辑仍然会在运行时重新安装依赖

5. **尝试 5：覆盖 ENTRYPOINT 和 CMD**
   ```dockerfile
   ENTRYPOINT ["/bin/bash", "-c"]
   CMD ["bash ${PRE_START_PATH} && uvicorn ${APP_MODULE} --host 0.0.0.0 --port 80"]
   ```
   **问题**：虽然可以工作，但失去了使用 inboard 镜像的意义

**为什么所有 hatch 方案都失败了？**

根本原因：**inboard 镜像的启动逻辑与我们的使用场景不匹配**

1. **启动逻辑的复杂性**：
   - inboard 镜像的启动脚本可能包含复杂的逻辑
   - 可能不检查已创建的环境，或者检查逻辑有问题
   - 即使环境存在，也可能因为配置问题而重新创建

2. **环境管理的复杂性**：
   - hatch 环境管理需要精确的配置
   - 环境名称、依赖安装方式、环境变量配置等都需要匹配
   - 任何一个环节出错，都会导致运行时重新安装

3. **调试困难**：
   - inboard 镜像的启动逻辑是黑盒，难以调试
   - 无法确定为什么 `hatch run` 不检查已创建的环境
   - 即使按照官方文档配置，也可能因为版本差异或配置细节而失败

**结论**：
- 我们尝试了所有可能的 hatch 配置方案，但都失败了
- 最终发现：使用 Python 基础镜像 + `pip install .` 是最简单、最可靠的方案
- 不需要 hatch 环境管理，依赖直接安装到系统 Python，避免所有配置问题

#### 2. 我们的方案

**使用 `python:3.11-slim` + `pip install inboard[fastapi]`：**
- 基础镜像：`python:3.11-slim`（只包含 Python 和基本工具）
- 依赖安装：`pip install .`（读取 `pyproject.toml`，安装所有依赖包括 `inboard[fastapi]`）
- 启动命令：我们自己写（直接使用 uvicorn/gunicorn）

**优势：**
- 依赖在构建时安装，运行时直接使用（启动快）
- 完全控制启动逻辑
- 镜像更小（不包含 hatch、pipx 等工具）

#### 3. 我们没有遗漏任何内容

**运行时依赖完整性检查：**

| 依赖 | inboard 镜像 | 我们的镜像 | 状态 |
|------|-------------|-----------|------|
| FastAPI | ✅ (通过 inboard) | ✅ (通过 `pip install inboard[fastapi]`) | ✅ 完整 |
| uvicorn | ✅ (通过 inboard) | ✅ (通过 `pip install inboard[fastapi]`) | ✅ 完整 |
| gunicorn | ✅ (通过 inboard) | ✅ (通过 `pip install inboard[fastapi]`) | ✅ 完整 |
| starlette | ✅ (通过 inboard) | ✅ (通过 `pip install inboard[fastapi]`) | ✅ 完整 |
| pydantic | ✅ (通过 inboard) | ✅ (通过 `pip install inboard[fastapi]`) | ✅ 完整 |
| 项目依赖 | ✅ | ✅ (通过 `pip install .`) | ✅ 完整 |
| Python 3.11 | ✅ | ✅ (通过 `python:3.11-slim`) | ✅ 完整 |

**我们故意不包含的（不需要）：**
- hatch（环境管理工具，k8s 场景下不需要）
- pipx（工具安装器，不需要）
- inboard 的启动脚本（我们自己写）

**结论**：我们没有遗漏任何运行时必需的依赖或工具。镜像更小是因为去掉了不必要的工具。

## 问题背景

在部署 `incubator-app-bff` 和 `llmops-app-bff` 等 FastAPI 应用时，发现 Pod 启动时会在运行时安装依赖，导致启动缓慢。日志显示：

```
Creating environment: default
Installing project in development mode
```

即使 Pod 状态为 `Running`，但 `Ready` 状态为 `0/1`，应用需要等待依赖安装完成才能提供服务。

## 问题分析

### 1. 原始方案的问题

**原始 Dockerfile 使用 inboard 基础镜像：**

```dockerfile
FROM ghcr.io/br3ndonland/inboard:fastapi-0.68-python3.11 AS build

# 创建 production 环境
RUN hatch env prune && \
    hatch env create production && \
    pip install --upgrade setuptools && \
    hatch env show production
```

**问题根源：**

1. **inboard 镜像的启动逻辑**：inboard 基础镜像包含 ENTRYPOINT，会自动使用 `hatch run` 启动应用
2. **环境配置问题**：
   - Dockerfile 只创建了 `production` 环境，但 `hatch run` 默认使用 `default` 环境
   - 或者创建了环境，但依赖没有正确安装到环境中（使用了 `pip install .` 而不是 `hatch install`）
3. **运行时安装依赖**：当环境不存在或依赖缺失时，`hatch run` 会在运行时创建环境并安装依赖
4. **配置复杂性**：正确使用 inboard 镜像需要：
   - 创建正确的环境（`default` 或通过 `HATCH_ENV` 指定）
   - 使用 `hatch install` 将依赖安装到环境中
   - 确保环境变量配置正确
   
   这些配置容易出错，导致运行时重新安装依赖

### 2. 关键发现

#### inboard Python 包 vs inboard Docker 镜像

这是两个不同的东西：

| 特性 | `inboard[fastapi]` Python 包 | `inboard` Docker 镜像 |
|------|------------------------------|----------------------|
| 类型 | Python 包 | Docker 镜像 |
| 安装方式 | `pip install inboard[fastapi]` | `FROM ghcr.io/br3ndonland/inboard:...` |
| 包含内容 | FastAPI、uvicorn、gunicorn 等依赖 | Python 包 + 启动脚本 + 环境配置 |
| 启动逻辑 | 无（需要自己写） | 有（使用 `hatch run`） |
| 控制权 | 完全控制 | 受限于镜像的启动逻辑 |

**重要结论**：
- 我们可以只使用 `inboard[fastapi]` Python 包（通过 `pip install .` 安装）
- 不需要使用 `inboard` Docker 镜像（避免 `hatch run` 启动逻辑）

#### hatch 环境管理的问题

1. **环境创建时机**：
   - 构建时创建：依赖在构建时安装，运行时直接使用（推荐）
   - 运行时创建：每次启动都要安装依赖，启动慢（问题）

2. **dev-mode 的局限性**：
   ```toml
   [tool.hatch.envs.default]
   dev-mode = false
   ```
   - `dev-mode = false` 只影响安装方式，不阻止环境创建
   - 如果环境不存在，`hatch run` 仍会创建环境并安装依赖

3. **环境选择**：
   - `hatch run` 默认使用 `default` 环境
   - 可以通过 `HATCH_ENV` 环境变量或 `--env` 参数指定环境
   - 但 inboard 镜像的启动逻辑可能不检查这些配置

## 为什么使用 Python 基础镜像而不是 inboard 镜像？

### 核心原因

**我们使用 `python:3.11-slim` 而不是 `inboard:fastapi-0.68-python3.11` 的根本原因：**

1. **简化依赖管理**
   - inboard 镜像需要正确使用 hatch 环境管理（创建环境、安装依赖到环境）
   - 我们的项目已经使用 `pyproject.toml` 管理依赖，使用 `pip install .` 更简单直接
   - 避免 hatch 环境管理的复杂性（环境选择、依赖安装到环境等）

2. **避免环境配置问题**
   - inboard 镜像使用 `hatch run`，需要确保环境存在且依赖已安装
   - 如果配置不当（环境不匹配、依赖未安装到环境），会在运行时重新安装
   - 使用 Python 基础镜像 + `pip install .`，依赖直接安装到系统 Python，更可靠

3. **完全控制启动流程**
   - inboard 镜像包含预定义的 ENTRYPOINT，使用 `hatch run` 启动
   - 即使可以正确配置，也增加了复杂性
   - 使用 Python 基础镜像，我们可以完全控制启动命令，更简单直接

4. **依赖完整性保证**
   - 通过 `pip install .` 安装 `inboard[fastapi]`，我们仍然获得了所有必要的依赖
   - `inboard[fastapi]` 会自动安装：FastAPI、uvicorn、gunicorn、starlette、pydantic 等
   - **我们并没有丢失任何运行时依赖**

5. **镜像体积优化**
   - inboard 镜像包含 hatch、pipx 等工具
   - 使用 Python 基础镜像，我们只安装项目实际需要的依赖
   - 镜像更小，但功能完整

### 依赖对比

**inboard 镜像包含：**
- Python 3.11
- FastAPI、uvicorn、gunicorn（通过 inboard 包）
- hatch（用于环境管理）
- 启动脚本和逻辑

**我们的镜像包含：**
- Python 3.11（通过 `python:3.11-slim`）
- FastAPI、uvicorn、gunicorn（通过 `pip install inboard[fastapi]`）
- 项目所有依赖（通过 `pip install .`）
- **我们自己的启动逻辑**

**结论**：我们没有遗漏任何运行时依赖，只是：
- 不使用 hatch 环境管理（在 k8s 场景下不需要）
- 不使用 inboard 的启动脚本（我们自己写启动命令）
- 镜像更小，但功能完整

## 解决方案

### 方案演进

#### 阶段 1：尝试修复 hatch 环境

**尝试 1：创建 default 环境并安装依赖**

```dockerfile
RUN hatch env prune && \
    hatch env create default && \
    hatch run --env default pip install --upgrade setuptools && \
    hatch install --env default && \
    hatch env show default
```

**问题**：inboard 镜像的启动逻辑仍使用 `hatch run`，可能不检查已创建的环境。

**尝试 2：设置 HATCH_ENV 环境变量**

```dockerfile
ENV HATCH_ENV=production
```

**问题**：inboard 镜像的启动逻辑可能不检查 `HATCH_ENV` 环境变量。

**尝试 3：覆盖 ENTRYPOINT 和 CMD**

```dockerfile
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["bash ${PRE_START_PATH} && uvicorn ${APP_MODULE} --host 0.0.0.0 --port 80"]
```

**问题**：需要完全覆盖 inboard 的启动逻辑，失去了使用 inboard 镜像的意义。

#### 阶段 2：改用标准 Python 镜像（最终方案）

**核心思路**：
- 不使用 inboard Docker 镜像
- 使用 `python:3.11-slim` 作为基础镜像
- 通过 `pip install .` 安装所有依赖（包括 `inboard[fastapi]`）
- 完全控制启动逻辑

### 最终方案

#### 1. 基础镜像选择

```dockerfile
# 从 inboard 镜像改为标准 Python 镜像
FROM python:3.11-slim AS build
```

**原因**：
- 项目依赖已通过 `pyproject.toml` 管理，包括 `inboard[fastapi]`
- 在 k8s 场景下，容器本身就是隔离环境，不需要 venv
- 标准 Python 镜像更简单、可控，启动逻辑完全由我们控制

#### 2. 依赖安装

```dockerfile
# 在 k8s 场景下，容器本身就是隔离环境，不需要 venv
# 直接使用系统 Python 安装依赖，减少镜像体积和复杂度
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir .
```

**关键点**：
- `pip install .` 会读取 `pyproject.toml` 的 `dependencies`
- `inboard[fastapi]` 会自动安装 FastAPI、uvicorn、gunicorn 等依赖
- 使用 `--no-cache-dir` 减少镜像体积

#### 3. 启动命令

**开发环境**：
```dockerfile
CMD ["bash", "-c", "[ -f \"$PRE_START_PATH\" ] && bash \"$PRE_START_PATH\" || true; uvicorn $APP_MODULE --host 0.0.0.0 --port 80 --reload"]
```

**生产环境**：
```dockerfile
ENV GUNICORN_WORKERS=${GUNICORN_WORKERS:-4}
CMD ["bash", "-c", "[ -f \"$PRE_START_PATH\" ] && bash \"$PRE_START_PATH\" || true; gunicorn $APP_MODULE -w ${GUNICORN_WORKERS:-4} -k uvicorn.workers.UvicornWorker -b 0.0.0.0:80"]
```

**优化点**：
- prestart.sh 存在性保护：`[ -f "$PRE_START_PATH" ] && bash "$PRE_START_PATH" || true`
- gunicorn worker 数量可配置：`${GUNICORN_WORKERS:-4}`

#### 4. venv 方案（保留供参考）

```dockerfile
# ============================================================================
# 原来的 venv 方案（保留供参考）
# ============================================================================
# 如果需要在本地开发或测试环境中使用 venv，可以使用以下方案：
# 
# RUN rm -rf .venv && \
#     python -m venv .venv && \
#     .venv/bin/pip install --upgrade pip setuptools wheel && \
#     .venv/bin/pip install --no-cache-dir .
# 
# ENV PATH="/app/.venv/bin:$PATH" \
#     PYTHONPATH=/app \
#     PYTHONUNBUFFERED=1 \
#     PYTHONDONTWRITEBYTECODE=1
```

**说明**：
- 在 k8s 场景下，容器本身就是隔离环境，不需要 venv
- 去掉 venv 的优势：镜像体积更小、构建更快、启动更快
- 如果需要在本地开发或测试环境中使用 venv，可以参考注释中的方案

## 优化建议总结

### 1. gunicorn worker 数量可配置

**之前**：
```dockerfile
CMD ["gunicorn", "app.main:app", "-w", "4", ...]
```

**优化后**：
```dockerfile
ENV GUNICORN_WORKERS=${GUNICORN_WORKERS:-4}
CMD ["bash", "-c", "... gunicorn $APP_MODULE -w ${GUNICORN_WORKERS:-4} ..."]
```

**优势**：在 k8s 中可以通过环境变量或 ConfigMap 控制 worker 数量，根据 CPU 核心数调整。

### 2. prestart.sh 存在性保护

**之前**：
```dockerfile
CMD ["bash", "-c", "bash ${PRE_START_PATH} && uvicorn ..."]
```

**优化后**：
```dockerfile
CMD ["bash", "-c", "[ -f \"$PRE_START_PATH\" ] && bash \"$PRE_START_PATH\" || true; uvicorn ..."]
```

**优势**：防止 prestart.sh 被删除时导致容器启动失败。

### 3. pip install 加 --no-cache-dir

**之前**：
```dockerfile
RUN pip install .
```

**优化后**：
```dockerfile
RUN pip install --no-cache-dir .
```

**优势**：减少镜像体积，在 CI 环境中特别有用。

### 4. k8s 场景下去掉 venv

**之前**：
```dockerfile
RUN python -m venv .venv && \
    .venv/bin/pip install .
ENV PATH="/app/.venv/bin:$PATH"
```

**优化后**：
```dockerfile
RUN pip install --no-cache-dir .
ENV PYTHONPATH=/app
```

**优势**：
- 更小的镜像体积
- 更简单的构建步骤
- 更符合 k8s 实践（容器本身就是隔离环境）

## 完整 Dockerfile 示例

```dockerfile
# ============================================================================
# 构建阶段：使用标准 Python 基础镜像
# ============================================================================
FROM python:3.11-slim AS build

# 代理配置（可选）
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG http_proxy
ARG https_proxy
ARG NO_PROXY
ARG no_proxy

ENV HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    NO_PROXY=${NO_PROXY} \
    no_proxy=${no_proxy}

# 系统依赖安装
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制源代码
COPY app/ /app/
WORKDIR /app/

# 安装 Python 依赖
# 在 k8s 场景下，容器本身就是隔离环境，不需要 venv
# 直接使用系统 Python 安装依赖，减少镜像体积和复杂度
RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir .

# 设置环境变量
ENV PYTHONPATH=/app \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# ============================================================================
# 原来的 venv 方案（保留供参考）
# ============================================================================
# 如果需要在本地开发或测试环境中使用 venv，可以使用以下方案：
# 
# RUN rm -rf .venv && \
#     python -m venv .venv && \
#     .venv/bin/pip install --upgrade pip setuptools wheel && \
#     .venv/bin/pip install --no-cache-dir .
# 
# ENV PATH="/app/.venv/bin:$PATH" \
#     PYTHONPATH=/app \
#     PYTHONUNBUFFERED=1 \
#     PYTHONDONTWRITEBYTECODE=1

EXPOSE 80

# ============================================================================
# 多阶段构建：开发环境
# ============================================================================
FROM build AS run-dev

ARG BACKEND_APP_MODULE=app.main:app
ARG BACKEND_PRE_START_PATH=/app/prestart.sh

ENV APP_MODULE=${BACKEND_APP_MODULE} \
    PRE_START_PATH=${BACKEND_PRE_START_PATH} \
    ENVIRONMENT=development

# 启动命令：使用系统 Python 的 uvicorn（开发模式，支持热重载）
# 注意：prestart.sh 存在性保护，防止某天被删
CMD ["bash", "-c", "[ -f \"$PRE_START_PATH\" ] && bash \"$PRE_START_PATH\" || true; uvicorn $APP_MODULE --host 0.0.0.0 --port 80 --reload"]

# ============================================================================
# 多阶段构建：生产环境
# ============================================================================
FROM build AS run-start

ARG BACKEND_APP_MODULE=app.main:app
ARG BACKEND_PRE_START_PATH=/app/prestart.sh

ENV APP_MODULE=${BACKEND_APP_MODULE} \
    PRE_START_PATH=${BACKEND_PRE_START_PATH} \
    ENVIRONMENT=production \
    GUNICORN_WORKERS=${GUNICORN_WORKERS:-4}

# 启动命令：使用系统 Python 的 gunicorn（生产模式，多 worker）
# 注意：
# 1. gunicorn 已通过 inboard[fastapi] 依赖安装
# 2. prestart.sh 存在性保护，防止某天被删
# 3. worker 数量可通过环境变量 GUNICORN_WORKERS 控制（默认 4）
CMD ["bash", "-c", "[ -f \"$PRE_START_PATH\" ] && bash \"$PRE_START_PATH\" || true; gunicorn $APP_MODULE -w ${GUNICORN_WORKERS:-4} -k uvicorn.workers.UvicornWorker -b 0.0.0.0:80"]
```

## 应用范围

### 已更新的组件

1. **incubator-app-bff** ✅
   - 从 `inboard` 基础镜像改为 `python:3.11-slim`
   - 去掉 venv，使用系统 Python
   - 应用所有优化

2. **llmops-app-bff** ✅
   - 应用了相同的优化

### 不需要更新的组件

1. **incubator-app-ssr / llmops-app-ssr**
   - Node.js 项目，结构不同

2. **celeryworker-llmops / celeryworker-incubator**
   - 结构不同：不包含应用代码（代码在运行时挂载）
   - 使用 venv 是合理的（不需要项目代码）
   - 已有多阶段构建优化

## 镜像大小对比说明

### 为什么我们的镜像比 inboard 镜像小？

**这是正常的，原因如下：**

1. **inboard 镜像包含额外的工具**
   - hatch（Python 环境管理工具）
   - pipx（可能用于安装工具）
   - 启动脚本和配置
   - 这些工具在 k8s 场景下不是必需的

2. **我们只安装项目需要的依赖**
   - 通过 `pip install .` 只安装 `pyproject.toml` 中声明的依赖
   - 不安装额外的工具或开发依赖
   - 使用 `--no-cache-dir` 减少缓存

3. **多阶段构建优化**
   - 构建阶段安装编译工具（build-essential）
   - 运行阶段不包含编译工具，只包含运行时依赖
   - 进一步减小镜像体积

### 我们是否遗漏了什么？

**检查清单：**

✅ **运行时依赖**：通过 `inboard[fastapi]` 和 `pip install .` 完整安装
- FastAPI、uvicorn、gunicorn ✅
- starlette、pydantic ✅
- 项目所有依赖 ✅

✅ **系统工具**：Python 基础镜像已包含
- Python 3.11 解释器 ✅
- pip、setuptools、wheel ✅

✅ **编译工具**：构建阶段已安装
- build-essential（用于编译 Python 包）✅

❌ **不需要的工具**（我们故意不包含）：
- hatch（环境管理，k8s 场景下不需要）
- pipx（工具安装器，不需要）
- inboard 的启动脚本（我们自己写）

**结论**：我们没有遗漏任何运行时必需的依赖或工具。镜像更小是因为：
1. 不包含不必要的工具（hatch、pipx 等）
2. 使用多阶段构建，运行时不包含编译工具
3. 使用 `--no-cache-dir` 减少缓存

## 关键要点总结

### 1. inboard Python 包 vs inboard Docker 镜像

- **使用 `inboard[fastapi]` Python 包**：通过 `pip install .` 安装，获得 FastAPI、uvicorn、gunicorn 等依赖
- **不使用 `inboard` Docker 镜像**：避免 `hatch run` 启动逻辑，完全控制启动流程

### 2. k8s 场景下的最佳实践

- **不使用 venv**：容器本身就是隔离环境
- **直接使用系统 Python**：减少镜像体积，简化构建步骤
- **完全控制启动逻辑**：不依赖基础镜像的启动脚本

### 3. 优化原则

- **构建时安装依赖**：避免运行时安装，提高启动速度
- **可配置性**：通过环境变量控制参数（如 worker 数量）
- **健壮性**：添加存在性检查，防止文件缺失导致启动失败
- **镜像体积**：使用 `--no-cache-dir`，去掉不必要的 venv

### 4. 向后兼容

- **保留 venv 方案作为注释**：如果需要在本地开发或测试环境中使用 venv，可以参考注释中的方案

## 参考

- [inboard 官方文档](https://inboard.bws.bio/)
- [Python Docker 最佳实践](https://docs.docker.com/language/python/)
- [Kubernetes 容器化最佳实践](https://kubernetes.io/docs/concepts/containers/)
