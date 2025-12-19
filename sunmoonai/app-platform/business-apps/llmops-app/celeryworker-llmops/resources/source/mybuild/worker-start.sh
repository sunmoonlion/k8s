#!/usr/bin/env bash
set -e

# ============================================================================
# Celery Worker 启动脚本（单后端架构）
# ============================================================================
# 说明：
# - 应用代码通过 Init Container 挂载到 /app/app
# - 从环境变量读取队列名称和并发数
# - 监听单个队列
# ============================================================================

echo "=========================================="
echo "启动 Celery Worker (LLMOps)"
echo "=========================================="

# 检查必要的环境变量
# 注意：这些环境变量应该在 Kubernetes 部署时通过 celeryworker-llmops.yaml 设置
if [ -z "$CELERY_BROKER_URL" ]; then
    echo "⚠️  警告: CELERY_BROKER_URL 未设置"
    echo "   请在 Kubernetes Deployment 中设置 CELERY_BROKER_URL 环境变量"
    echo "   例如: amqp://user:password@rabbitmq-host:5672//"
fi

if [ -z "$CELERY_RESULT_BACKEND" ]; then
    echo "⚠️  警告: CELERY_RESULT_BACKEND 未设置"
    echo "   请在 Kubernetes Deployment 中设置 CELERY_RESULT_BACKEND 环境变量"
    echo "   例如: redis://redis-host:6379/0"
fi

# 执行启动前脚本
# 注意：celeryworker_pre_start.py 在镜像中（/app/celeryworker_pre_start.py）
# 它会导入 app.db.session（从挂载的应用代码 /app/app 中）
# 使用 venv 中的 Python（PATH 已包含 /app/.venv/bin）
echo ""
echo "执行 celeryworker_pre_start.py..."
if python /app/celeryworker_pre_start.py; then
    echo "✅ celeryworker_pre_start.py 执行成功"
else
    echo "❌ celeryworker_pre_start.py 执行失败"
    exit 1
fi

# 从环境变量读取队列名称（单队列）
# 注意：这些环境变量应该在 Kubernetes 部署时通过 celeryworker-llmops.yaml 设置
# 如果没有设置，使用合理的默认值（可以根据实际需求调整）
QUEUE="${CELERY_QUEUE:-llmops-queue}"
CONCURRENCY="${CELERY_CONCURRENCY:-2}"

# 验证队列配置
if [ -z "$QUEUE" ]; then
    echo "❌ 错误: CELERY_QUEUE 未设置且无默认值"
    echo "   请在 Kubernetes Deployment 中设置 CELERY_QUEUE 环境变量"
    exit 1
fi

# 验证并发数配置
if ! [[ "$CONCURRENCY" =~ ^[0-9]+$ ]]; then
    echo "❌ 错误: CELERY_CONCURRENCY 必须是数字，当前值: $CONCURRENCY"
    echo "   请在 Kubernetes Deployment 中设置 CELERY_CONCURRENCY 环境变量（例如: 2）"
    exit 1
fi

# 验证并发数是否大于 0
if [ "$CONCURRENCY" -le 0 ]; then
    echo "❌ 错误: CELERY_CONCURRENCY 必须大于 0，当前值: $CONCURRENCY"
    exit 1
fi

echo ""
echo "=========================================="
echo "配置信息："
echo "=========================================="
echo "  队列: $QUEUE"
echo "  并发数: $CONCURRENCY"
echo "  Broker: ${CELERY_BROKER_URL:-未设置}"
echo "  Result Backend: ${CELERY_RESULT_BACKEND:-未设置}"
echo "  PYTHONPATH: ${PYTHONPATH:-未设置}"
echo "=========================================="
echo ""

# 检查 app.worker 模块是否存在
if [ ! -f "/app/app/worker/__init__.py" ] && [ ! -f "/app/app/worker.py" ]; then
    echo "⚠️  警告: 未找到 app.worker 模块，可能代码未正确挂载"
    echo "检查 /app/app 目录内容:"
    ls -la /app/app/ 2>/dev/null || echo "  /app/app 目录不存在"
fi

# 启动 Celery Worker，监听单个队列
# 使用 venv 中的 celery 命令（PATH 已包含 /app/.venv/bin）
echo "启动 Celery Worker..."
echo "命令: celery -A app.worker worker -l info -Q $QUEUE -c $CONCURRENCY"
echo ""

exec celery -A app.worker worker \
    -l info \
    -Q "$QUEUE" \
    -c "$CONCURRENCY"

