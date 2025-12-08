import os
from celery import Celery

# 从环境变量读取 Broker URL，如果没有则使用默认值
broker_url = os.getenv("CELERY_BROKER_URL", "amqp://guest@queue//")

# 从环境变量读取 Result Backend（可选）
result_backend = os.getenv("CELERY_RESULT_BACKEND")

# 创建 Celery 应用
if result_backend:
    celery_app = Celery("worker", broker=broker_url, backend=result_backend)
else:
    celery_app = Celery("worker", broker=broker_url)

# 从环境变量读取队列名称，如果没有则使用默认值
default_queue = os.getenv("CELERY_QUEUE", "llmops-queue")
celery_app.conf.task_routes = {"app.worker.*": default_queue}
