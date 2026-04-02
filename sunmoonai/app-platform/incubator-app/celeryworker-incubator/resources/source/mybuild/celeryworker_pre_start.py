"""
Celery Worker 启动前检查脚本（单后端架构）

说明：
- 此脚本在 Celery Worker 启动前执行，用于检查数据库连接
- 应用代码通过 Init Container 挂载到 /app/app
- 脚本放在 /app/ 目录，可以导入 app.db.session（因为 PYTHONPATH=/app）
"""
import logging

from tenacity import after_log, before_log, retry, stop_after_attempt, wait_fixed
from sqlalchemy.sql import text

# 导入数据库会话（从挂载的应用代码中）
from app.db.session import SessionLocal

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

max_tries = 60 * 5  # 5 minutes
wait_seconds = 1


@retry(
    stop=stop_after_attempt(max_tries),
    wait=wait_fixed(wait_seconds),
    before=before_log(logger, logging.INFO),
    after=after_log(logger, logging.WARN),
)
def init() -> None:
    """初始化并检查数据库连接"""
    try:
        # Try to create session to check if DB is awake
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        logger.info("数据库连接检查成功")
    except Exception as e:
        logger.error(f"数据库连接检查失败: {e}")
        raise e
    finally:
        if 'db' in locals():
            db.close()


def main() -> None:
    """主函数"""
    logger.info("==========================================")
    logger.info("Celery Worker 启动前检查")
    logger.info("==========================================")
    logger.info("检查数据库连接...")
    init()
    logger.info("✅ Celery Worker 启动前检查完成")


if __name__ == "__main__":
    main()

