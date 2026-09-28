#!/usr/bin/env python3
"""只做登记这一步（不重新建数据集），把结果按稳定的错误码打印出来。在 info 后端的环境里运行。"""

from __future__ import annotations

import asyncio
import json
import sys

from sqlalchemy import select

from app.bootstrap.securities import build_dataset_registration_service
from app.domain.securities.registration import RegistrationError
from app.infrastructure.models.securities import SecurityDataset
from app.infrastructure.storage.postgres import get_postgres


async def main(code: str) -> dict:
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            record = (
                await session.execute(
                    select(SecurityDataset)
                    .where(
                        SecurityDataset.security_code == code,
                        SecurityDataset.status == "published",
                    )
                    .order_by(SecurityDataset.built_at.desc())
                    .limit(1)
                )
            ).scalar_one()
            record_id = str(record.id)
        service = build_dataset_registration_service(postgres.session_factory)
        try:
            done = await service.register(record_id)
            result = {"registered": done.registered, "error": None}
        except RegistrationError as exc:
            result = {
                "registered": False,
                "error": exc.code,
                "detail": exc.detail,
                "retryable": exc.retryable,
            }
        async with postgres.session_factory() as session:
            row = await session.get(SecurityDataset, record.id)
            result["recorded_error"] = row.knowledge_registration_error
            result["recorded_at"] = row.knowledge_registered_at is not None
        return result
    finally:
        await postgres.shutdown()


if __name__ == "__main__":
    print(json.dumps(asyncio.run(main(sys.argv[1])), ensure_ascii=False))
