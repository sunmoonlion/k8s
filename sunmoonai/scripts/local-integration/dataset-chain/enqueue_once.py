#!/usr/bin/env python3
"""登记一个采集批次并排队，和管理接口做的事一样，只是不经过浏览器登录。在 info 后端的环境里运行。"""

from __future__ import annotations

import asyncio
import json
import sys

from app.bootstrap.securities import request_security_ingestion
from app.infrastructure.storage.postgres import get_postgres


async def main(code: str) -> dict:
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            batch = await request_security_ingestion(
                session, postgres.session_factory, code
            )
            return {"ingestion_id": str(batch.id), "status": batch.status}
    finally:
        await postgres.shutdown()


if __name__ == "__main__":
    print(json.dumps(asyncio.run(main(sys.argv[1]))))
