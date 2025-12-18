# ============================================================================
# Celery Worker 镜像 Dockerfile（单后端架构）
# ============================================================================
# 说明：
# - 这是一个轻量级的基础设施镜像，只包含 Celery 运行时
# - 应用代码通过 Init Container 从后端镜像提取并挂载到 /app/app
# - 不包含应用代码，代码在运行时通过 volume 挂载
# ============================================================================

# 使用精确的 Python 版本
FROM python:3.11-slim

# ============================================================================
# 代理配置（可选，仅在国内网络环境需要）
# ============================================================================
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

# ============================================================================
# 系统依赖安装
# ============================================================================
# 某些 Python 包（如 cryptography、neomodel 等）可能需要编译工具
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 对于 neomodel（如果需要 libgeos，根据实际需要取消注释）
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends \
#     libgeos-dev \
#     && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Python 环境配置
# ============================================================================
WORKDIR /app

# 安装 pipx 和 hatch
ARG PIPX_VERSION=1.2.0
ARG HATCH_VERSION=1.7.0

ENV C_FORCE_ROOT=1 \
    HATCH_ENV_TYPE_VIRTUAL_PATH=.venv \
    HATCH_VERSION=$HATCH_VERSION \
    PATH=/opt/pipx/bin:/app/.venv/bin:$PATH \
    PIPX_BIN_DIR=/opt/pipx/bin \
    PIPX_HOME=/opt/pipx/home \
    PIPX_VERSION=$PIPX_VERSION \
    PYTHONPATH=/app

# 安装 pipx 和 hatch
RUN python -m pip install --no-cache-dir --upgrade pip "pipx==$PIPX_VERSION" && \
    pipx install "hatch==$HATCH_VERSION"

# 创建虚拟环境并安装 Celery 和基础依赖
# 注意：不复制应用代码，代码会在运行时通过 Init Container 挂载到 /app/app
RUN hatch env prune && \
    hatch env create production && \
    hatch run pip install --no-cache-dir --upgrade pip setuptools && \
    # 安装 Celery 和基础依赖（应用代码会在运行时挂载）
    hatch run pip install --no-cache-dir \
        celery \
        redis \
        sqlalchemy \
        psycopg[binary] \
        tenacity \
        pydantic \
        pydantic-settings \
        alembic

# ============================================================================
# 启动脚本和预启动脚本
# ============================================================================
# 复制 worker-start.sh 脚本（不依赖应用代码）
COPY worker-start.sh /app/worker-start.sh
RUN chmod +x /app/worker-start.sh

# 复制 celeryworker_pre_start.py 脚本
# 注意：此脚本会导入 app.db.session，应用代码会在运行时挂载到 /app/app
COPY celeryworker_pre_start.py /app/celeryworker_pre_start.py

# 暴露端口（Celery Flower 监控端口，如果需要）
EXPOSE 5555

# 运行 Celery Worker
CMD ["bash", "/app/worker-start.sh"]

