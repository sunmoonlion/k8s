"""Production ASGI entry for the pinned upstream image; no schema initialization."""
import asyncio
import base64
import json
import logging
import os
import signal
import sys
import threading
from pathlib import Path


def initialize_logging():
    # Upstream worker prints configuration. Redact known private values before
    # any log handler (including upstream rotating files) receives the record.
    from ruamel.yaml import YAML
    private = YAML(typ='safe').load(Path('/ragflow/conf/service_conf.yaml').read_text())
    sensitive = []

    def collect(obj):
        if isinstance(obj, dict):
            for key, value in obj.items():
                if key in {'password', 'secret_key', 'api_key', 'http_app_key'} and isinstance(value, str) and len(value) >= 12:
                    sensitive.append(value)
                collect(value)
        elif isinstance(obj, list):
            for value in obj:
                collect(value)
    collect(private)
    bootstrap = Path('/run/bootstrap/input.json')
    if bootstrap.exists():
        sensitive.extend(v for k,v in json.loads(bootstrap.read_text()).items() if k.endswith(('_password','_token')) and isinstance(v,str))
    sensitive.extend(base64.b64encode(value.encode()).decode() for value in list(sensitive))
    factory = logging.getLogRecordFactory()

    def redact(value):
        for secret in sensitive:
            value = value.replace(secret, '[redacted]')
        return value

    def record_factory(*args, **kwargs):
        record = factory(*args, **kwargs)
        record.msg = redact(record.getMessage())
        record.args = ()
        if record.exc_info:
            record.exc_text = redact(logging.Formatter().formatException(record.exc_info))
        return record

    logging.setLogRecordFactory(record_factory)
    logging.basicConfig(level=logging.INFO, stream=sys.stdout)
    return private


async def main():
    private = initialize_logging()
    from common import settings
    from api.db.db_models import DB
    # Assert the database boundary in the real runtime connection.
    with DB.connection_context():
        row = DB.execute_sql("SELECT current_user, has_schema_privilege(current_user, 'public', 'CREATE'), has_database_privilege(current_user, current_database(), 'CREATE')").fetchone()
        if row[0] != private['postgres']['user'] or row[1] or row[2]:
            raise RuntimeError('RAGFlow runtime must not hold database DDL privileges')
        DB.execute_sql('SELECT 1 FROM "user" LIMIT 1').fetchall()

    if sys.argv[1] == 'worker':
        # Direct upstream process bypasses entrypoint.sh's unconditional DDL.
        # The shipped torch package is required before the upstream installer
        # helper is reached; runtime network policy and pip offline mode also
        # prohibit startup dependency downloads.
        import torch  # noqa: F401
        from rag.svr import task_executor
        from common.log_utils import init_root_logger
        init_root_logger('task_executor_common_0')
        task_executor.CONSUMER_NAME = 'task_executor_common_0'

        async def health():
            while True:
                rows = await asyncio.to_thread(task_executor.REDIS_CONN.REDIS.zrange, task_executor.CONSUMER_NAME, -1, -1, withscores=True)
                import time
                if rows and time.time()-rows[0][1] < 60:
                    Path('/tmp/worker-ready').touch()
                await asyncio.sleep(10)
        ticker = asyncio.create_task(health())
        try:
            await task_executor.main()
        finally:
            ticker.cancel()
            await asyncio.gather(ticker, return_exceptions=True)
        return

    from api.apps import app
    from api.db.runtime_config import RuntimeConfig
    from api.ragflow_server import update_progress, stop_event, GlobalPluginManager
    from rag.utils.redis_conn import REDIS_CONN
    from hypercorn.asyncio import serve
    from hypercorn.config import Config
    RuntimeConfig.DEBUG = False
    RuntimeConfig.init_env()
    RuntimeConfig.init_config(JOB_SERVER_HOST=settings.HOST_IP, HTTP_PORT=settings.HOST_PORT)
    GlobalPluginManager.load_plugins()

    from quart import request, abort
    @app.before_request
    async def restrict_surface():
        if request.path != '/sunmoon/ready' and not request.path.startswith('/api/v1/'):
            abort(404)

    @app.get('/sunmoon/ready')
    async def ready():
        with DB.connection_context():
            DB.execute_sql('SELECT 1').fetchone()
        REDIS_CONN.REDIS.ping()
        return {'ready': True}

    @app.before_serving
    async def start_progress():
        stop_event.clear()
        threading.Thread(target=update_progress, name='ragflow-progress', daemon=True).start()

    @app.after_serving
    async def stop_progress():
        stop_event.set()

    cfg = Config()
    cfg.bind = ['0.0.0.0:9380']
    cfg.certfile = '/run/tls/server.crt'
    cfg.keyfile = '/run/tls/server.key'
    cfg.accesslog = None
    cfg.errorlog = '-'
    cfg.graceful_timeout = 60
    cfg.read_timeout = 120
    await serve(app, cfg)


if __name__ == '__main__':
    if len(sys.argv) != 2 or sys.argv[1] not in {'api', 'worker'}:
        raise SystemExit('Expected api or worker role')
    asyncio.run(main())
