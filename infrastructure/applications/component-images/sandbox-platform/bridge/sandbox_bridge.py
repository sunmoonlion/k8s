"""沙箱侧出站桥（0003-sandbox 的 sidecar）。

在 pod 里监听回环 ws://127.0.0.1:PORT（app-server 的 execServerUrl 指向它）；app-server 每连一次，就向会合点 /sandbox 出站一条流，
先发 hello（user、token、codex 版本），收到 welcome 后两头透传。会合点拒绝时把原因写日志并关掉本地连接，让 app-server 看到断连。
环境变量：RELAY_URL、RELAY_USER、RELAY_TOKEN、CODEX_VERSION、BRIDGE_PORT（默认 47002）、BRIDGE_SOFTWARE。
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import sys

import websockets
from websockets.asyncio.client import connect
from websockets.asyncio.server import ServerConnection, serve

RELAY_PROTOCOL = 1
log = logging.getLogger("sandbox-bridge")


def env(name: str, default: str | None = None) -> str:
    v = os.environ.get(name, default)
    if v is None:
        sys.exit(f"missing env {name}")
    return v


async def pipe(src, dst):
    try:
        async for m in src:
            await dst.send(m)
    except websockets.ConnectionClosed:
        pass
    finally:
        try: await dst.close()
        except Exception: pass


async def handle(local: ServerConnection):
    relay_url = env("RELAY_URL").rstrip("/") + "/sandbox"
    hello = json.dumps({"type": "hello", "proto": RELAY_PROTOCOL, "role": "sandbox", "user": env("RELAY_USER"), "token": env("RELAY_TOKEN"),
                        "codex": env("CODEX_VERSION"), "software": os.environ.get("BRIDGE_SOFTWARE", "sandbox-bridge/0.1.0")})
    log.info("app-server connected; dialing %s", relay_url)
    try:
        async with connect(relay_url, max_size=None, ping_interval=20, ping_timeout=20) as up:
            await up.send(hello)
            first = json.loads(await asyncio.wait_for(up.recv(), 20))
            if first.get("type") != "welcome":
                log.error("relay refused: %s", first.get("reason", first))
                await local.close(code=1011, reason=str(first.get("reason", "relay refused"))[:120]); return
            log.info("paired conn=%s", first.get("conn"))
            await asyncio.gather(pipe(local, up), pipe(up, local))
    except Exception as e:
        log.error("bridge error: %s", e)
        try: await local.close(code=1011, reason=str(e)[:120])
        except Exception: pass
    log.info("stream closed")


async def main():
    logging.basicConfig(level=os.environ.get("BRIDGE_LOG", "INFO"), format="%(asctime)s %(levelname)s %(message)s")
    port = int(os.environ.get("BRIDGE_PORT", "47002"))
    async with serve(handle, "127.0.0.1", port, max_size=None):
        log.info("listening ws://127.0.0.1:%d -> %s", port, env("RELAY_URL"))
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
