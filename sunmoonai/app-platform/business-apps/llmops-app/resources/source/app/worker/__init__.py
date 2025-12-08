from app.core.celery_app import celery_app

from .tests import test_celery
from . import llmops_tasks  # 导入 LLMOps 任务，确保 Celery 注册这些任务
