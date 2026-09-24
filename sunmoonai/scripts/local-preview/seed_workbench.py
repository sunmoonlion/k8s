"""登录一次之后跑：给每个已登录过的用户登记这台本地机（环境）与预览沙箱。幂等：同名已登记就跳过。

在 backend-api 容器里执行：docker compose exec backend-api python /preview/seed_workbench.py
env：PREVIEW_ROOTS（逗号分隔的白名单根目录，宿主机路径，给代理与网页看的）
"""

from __future__ import annotations

import asyncio
import json
import os
import sys

sys.path.insert(0, "/app")
from sqlalchemy import text  # noqa: E402

from app.infrastructure.storage.postgres import get_postgres  # noqa: E402
from app.infrastructure.workbench.repository import WorkbenchRepository  # noqa: E402

ROOTS = [r for r in os.environ.get("PREVIEW_ROOTS", "").split(",") if r.strip()]
APP_SERVER_URL = os.environ.get("PREVIEW_APP_SERVER_URL", "ws://sandbox:47800")
TOKEN_REF = os.environ.get("PREVIEW_TOKEN_REF", "file:/secrets/app-server-token")
CODEX_VERSION = os.environ.get("PREVIEW_CODEX_VERSION", "0.155.1")


async def main() -> int:
    if not ROOTS:
        print("PREVIEW_ROOTS is empty: set it to the whitelisted directories on the host", file=sys.stderr)
        return 2
    pg = get_postgres()
    await pg.init()
    try:
        async with pg.session_factory() as s:
            users = (await s.execute(text("select id, username, email from auth_user order by created_at"))).mappings().all()
            if not users:
                print("no user has logged in yet: open http://localhost:3000 and log in first", file=sys.stderr)
                return 3
            repo = WorkbenchRepository(s)
            for u in users:
                owner = str(u["id"])
                envs = await repo.list_environments(owner_actor_id=owner)
                sbs = await repo.list_sandboxes(owner_actor_id=owner)
                async with repo.transaction():
                    if not any(e["name"] == "this-pc" for e in envs):
                        await repo.register_environment(
                            owner_actor_id=owner,
                            name="this-pc",
                            agent_version="0.1.0",
                            codex_version=CODEX_VERSION,
                            roots=ROOTS,
                            ceiling={"sandbox": "workspace-write", "network": False},
                        )
                    if not any(sb["app_server_url"] == APP_SERVER_URL for sb in sbs):
                        await repo.register_sandbox(
                            owner_actor_id=owner,
                            app_server_url=APP_SERVER_URL,
                            token_ref=TOKEN_REF,
                            codex_version=CODEX_VERSION,
                        )
                print(json.dumps({"user": u["username"] or u["email"], "roots": ROOTS, "sandbox": APP_SERVER_URL}, ensure_ascii=False))
    finally:
        await pg.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
