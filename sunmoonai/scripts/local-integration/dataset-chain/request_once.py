#!/usr/bin/env python3
"""采集申请的每一步，和页面经接口做的事一样，只是不经过浏览器登录。在 info 后端的环境里运行。

  request_once.py unwatch  <代码>              把这家公司移出关注清单（为了走「要批准」这条路）
  request_once.py submit   <代码> <用户>        用户提出申请
  request_once.py approve  <申请> <管理员>      管理员批准
  request_once.py progress <申请> <用户>        用户看进度
"""

from __future__ import annotations

import asyncio
import json
import sys

from app.bootstrap.security_requests import build_security_request_service
from app.infrastructure.storage.postgres import get_postgres


def shape(view) -> dict:
    return {
        "request_id": view.request.request_id,
        "security_code": view.request.security_code,
        "kind": view.request.kind.value,
        "status": view.request.status.value,
        "progress": view.progress.value,
        "decided_by": view.request.decided_by,
        "ingestion_id": view.request.ingestion_id,
        "data_version": view.dataset.data_version if view.dataset else None,
        "end_date": view.dataset.end_date if view.dataset else None,
    }


async def main(action: str, first: str, second: str | None) -> dict:
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            service = build_security_request_service(session, postgres.session_factory)
            if action == "unwatch":
                removed = await service.unwatch(
                    first, by="local-integration", note="本机联调：走要批准的路"
                )
                return {"security_code": first, "removed": removed}
            assert second is not None
            if action == "submit":
                view = await service.submit(
                    first,
                    actor_id=second,
                    reason="本机联调",
                    origin_app="investment",
                    origin_ref="local-integration:1",
                )
            elif action == "approve":
                view = await service.approve(first, by=second)
            elif action == "progress":
                view = await service.one_of_mine(first, actor_id=second)
            else:
                raise SystemExit(f"unknown action: {action}")
            return shape(view)
    finally:
        await postgres.shutdown()


if __name__ == "__main__":
    args = sys.argv[1:] + [None]
    print(json.dumps(asyncio.run(main(args[0], args[1], args[2])), ensure_ascii=False))
