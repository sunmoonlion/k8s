# ============================================================================
# Celery Worker 镜像 Dockerfile（单后端架构）
# ============================================================================
# 说明：
# - 这是一个轻量级的基础设施镜像，只包含 Celery 运行时
# - 应用代码通过 Init Container 从后端镜像提取并挂载到 /app/app
# - 不包含应用代码，代码在运行时通过 volume 挂载
#
# 为什么使用 venv 而不是 hatch？
# ============================================================================
# 1. 不需要项目代码：此镜像不包含应用代码（代码在运行时挂载），hatch 需要项目代码
# 2. 只需要安装依赖：直接用 pip install 即可，不需要项目打包
# 3. 更简单轻量：不需要安装 pipx 和 hatch，减少镜像体积和复杂度
# 4. 更快速：构建步骤更少，不需要创建 pyproject.toml 和配置环境
#
# 如果未来需要项目代码，可以考虑使用 hatch，但目前 venv 更合适
# ============================================================================

# ============================================================================
# 多阶段构建：构建阶段（包含编译工具）
# ============================================================================
# 使用多阶段构建的原因：
# 1. 减小镜像体积：编译工具（build-essential，~300MB）只在构建阶段需要
# 2. 提高安全性：运行时不包含编译工具，减少攻击面
# 3. 保持功能：依赖包在构建阶段编译好，运行阶段直接使用
# ============================================================================
FROM python:3.11-slim AS builder

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

# 安装编译工具（用于编译 Python 包）
RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 创建虚拟环境并安装依赖（需要编译的包在这里编译）
# 使用 Python 标准 venv 模块，不需要 hatch：
# - venv 是 Python 标准库，无需额外安装
# - 不需要项目代码或 pyproject.toml
# - 直接使用 pip 安装依赖即可
RUN python -m venv /app/.venv && \
    /app/.venv/bin/pip install --no-cache-dir --upgrade pip setuptools && \
    /app/.venv/bin/pip install --no-cache-dir \
        celery \
        redis \
        sqlalchemy \
        psycopg[binary] \
        tenacity \
        pydantic \
        pydantic-settings \
        alembic && \
    /app/.venv/bin/pip cache purge

# ============================================================================
# 运行阶段（不包含编译工具，镜像更小）
# ============================================================================
# 运行阶段只包含运行时需要的文件：
# - Python 基础镜像（~188MB）
# - 已编译的虚拟环境（~100-150MB）
# - 启动脚本
# 总大小约 450-500MB，比单阶段构建（~774MB）小约 300MB
# ============================================================================
FROM python:3.11-slim

WORKDIR /app

ENV C_FORCE_ROOT=1 \
    PATH=/app/.venv/bin:$PATH \
    PYTHONPATH=/app \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 从构建阶段复制虚拟环境（已编译好的包）
# 只复制 .venv 目录，不包含编译工具，大幅减小镜像体积
COPY --from=builder /app/.venv /app/.venv

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

