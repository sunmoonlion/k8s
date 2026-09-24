"""会合点 v1 的行为测试：配对、拒绝、透传、健康。跑法（仓根或本目录）：
   python -m unittest sunmoonai/relay-platform/relay/tests/test_relay.py      （需要 websockets>=13）"""
from __future__ import annotations

import asyncio
import json
import os
import sys
import unittest
import urllib.request

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import relay as relay_mod  # noqa: E402
from websockets.asyncio.client import connect  # noqa: E402
from websockets.asyncio.server import serve  # noqa: E402

TOKENS = {"u1": {"agent": "A1", "sandbox": "S1"}, "u2": {"agent": "A2", "sandbox": "S2"}}


def hello(role, user, token, codex="0.155.1", conn=None, proto=1):
    h = {"type": "hello", "proto": proto, "role": role, "user": user, "token": token, "codex": codex, "software": "test"}
    if conn: h["conn"] = conn
    return json.dumps(h)


class RelayTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.relay = relay_mod.Relay(tokens=TOKENS)
        self.server = await serve(self.relay.handler, "127.0.0.1", 0, max_size=None, process_request=self.relay.process_request)
        self.port = self.server.sockets[0].getsockname()[1]
        self.url = f"ws://127.0.0.1:{self.port}"
        self.open_ws = []

    async def asyncTearDown(self):
        for w in self.open_ws:
            try: await w.close()
            except Exception: pass
        self.server.close(); await self.server.wait_closed()

    async def agent(self, user="u1", token="A1", codex="0.155.1"):
        """连上控制通道，返回 (ctrl_ws, 一个协程：收到 open 后开数据流并返回它)"""
        ctrl = await connect(self.url + "/agent"); self.open_ws.append(ctrl)
        await ctrl.send(hello("agent", user, token, codex))
        first = json.loads(await ctrl.recv())
        return ctrl, first

    async def open_data_on_request(self, ctrl, user="u1", token="A1", codex="0.155.1"):
        msg = json.loads(await asyncio.wait_for(ctrl.recv(), 5))
        self.assertEqual(msg["type"], "open")
        data = await connect(self.url + f"/agent-data?conn={msg['conn']}"); self.open_ws.append(data)
        await data.send(hello("agent", user, token, codex, conn=msg["conn"]))
        return data

    async def sandbox(self, user="u1", token="S1", codex="0.155.1"):
        sb = await connect(self.url + "/sandbox"); self.open_ws.append(sb)
        await sb.send(hello("sandbox", user, token, codex))
        return sb

    async def test_pair_and_pipe_both_ways(self):
        ctrl, first = await self.agent()
        self.assertEqual(first["type"], "welcome")
        sb = await self.sandbox()
        data = await self.open_data_on_request(ctrl)
        welcome = json.loads(await asyncio.wait_for(sb.recv(), 5))
        self.assertEqual(welcome["type"], "welcome"); self.assertTrue(welcome["conn"])
        await sb.send('{"id":1,"method":"fs/readFile"}')
        self.assertEqual(await asyncio.wait_for(data.recv(), 5), '{"id":1,"method":"fs/readFile"}')
        await data.send('{"id":1,"result":{}}')
        self.assertEqual(await asyncio.wait_for(sb.recv(), 5), '{"id":1,"result":{}}')
        await data.send(b"\x00\x01binary")
        self.assertEqual(await asyncio.wait_for(sb.recv(), 5), b"\x00\x01binary")
        self.assertEqual(self.relay.stats["paired"], 1)

    async def test_bad_agent_token_is_rejected(self):
        ctrl, first = await self.agent(token="wrong")
        self.assertEqual(first, {"type": "reject", "reason": "bad token"})

    async def test_wrong_protocol_is_rejected(self):
        ctrl = await connect(self.url + "/agent"); self.open_ws.append(ctrl)
        await ctrl.send(hello("agent", "u1", "A1", proto=99))
        self.assertEqual(json.loads(await ctrl.recv())["type"], "reject")

    async def test_sandbox_without_agent_is_rejected(self):
        sb = await self.sandbox()
        self.assertEqual(json.loads(await sb.recv()), {"type": "reject", "reason": "agent offline"})

    async def test_sandbox_of_another_user_cannot_reach_this_agent(self):
        await self.agent(user="u1")
        sb = await self.sandbox(user="u2", token="S2")
        self.assertEqual(json.loads(await sb.recv())["reason"], "agent offline")

    async def test_codex_version_mismatch_is_rejected(self):
        await self.agent(codex="0.155.1")
        sb = await self.sandbox(codex="0.156.0")
        r = json.loads(await sb.recv())
        self.assertEqual(r["type"], "reject"); self.assertIn("codex version mismatch", r["reason"])

    async def test_data_stream_with_unknown_conn_is_rejected(self):
        data = await connect(self.url + "/agent-data?conn=nope"); self.open_ws.append(data)
        await data.send(hello("agent", "u1", "A1", conn="nope"))
        self.assertEqual(json.loads(await data.recv())["reason"], "unknown conn")

    async def test_agent_not_opening_stream_times_out(self):
        relay_mod.OPEN_TIMEOUT = 0.3
        try:
            ctrl, _ = await self.agent()
            sb = await self.sandbox()
            r = json.loads(await asyncio.wait_for(sb.recv(), 5))
            self.assertEqual(r["reason"], "agent did not open the stream")
        finally:
            relay_mod.OPEN_TIMEOUT = 15

    async def test_newer_agent_replaces_older(self):
        old, _ = await self.agent()
        new, first = await self.agent()
        self.assertEqual(first["type"], "welcome")
        await asyncio.wait_for(old.wait_closed(), 5)
        self.assertIs(self.relay.agents["u1"].ws is not None, True)

    async def test_healthz(self):
        await self.agent()
        body = await asyncio.get_running_loop().run_in_executor(None, lambda: urllib.request.urlopen(f"http://127.0.0.1:{self.port}/healthz", timeout=5).read())
        j = json.loads(body)
        self.assertTrue(j["ok"]); self.assertEqual(j["agents"], 1)


    async def test_admin_channel_registers_and_revokes_users(self):
        self.relay.admin_token = "ADMIN-SECRET-0123456789"
        # bad admin token
        ws = await connect(self.url + "/admin"); self.open_ws.append(ws)
        await ws.send(json.dumps({"type": "hello", "role": "admin", "token": "wrong"}))
        self.assertEqual(json.loads(await ws.recv())["type"], "reject")
        # good admin token: set tokens for a new user, then the agent can connect
        admin = await connect(self.url + "/admin"); self.open_ws.append(admin)
        await admin.send(json.dumps({"type": "hello", "role": "admin", "token": "ADMIN-SECRET-0123456789"}))
        self.assertEqual(json.loads(await admin.recv())["role"], "admin")
        await admin.send(json.dumps({"type": "set_tokens", "user": "u3", "agent": "A3-" + "x" * 16, "sandbox": "S3-" + "y" * 16}))
        self.assertEqual(json.loads(await admin.recv())["type"], "ok")
        a, first = await self.agent("u3", "A3-" + "x" * 16)
        self.assertEqual(first["type"], "welcome")
        self.assertEqual(len(self.relay.agents), 1)
        await admin.send(json.dumps({"type": "list"}))
        self.assertIn("u3", json.loads(await admin.recv())["users"])
        # invalid registrations are refused
        for bad in ({"type": "set_tokens", "user": "Bad User", "agent": "a" * 20, "sandbox": "b" * 20},
                    {"type": "set_tokens", "user": "u4", "agent": "short", "sandbox": "b" * 20},
                    {"type": "set_tokens", "user": "u4", "agent": "a" * 20, "sandbox": "a" * 20}):
            await admin.send(json.dumps(bad))
            self.assertEqual(json.loads(await admin.recv())["type"], "error")
        # revoke closes the online agent and forgets the tokens
        await admin.send(json.dumps({"type": "revoke", "user": "u3"}))
        self.assertEqual(json.loads(await admin.recv())["type"], "ok")
        with self.assertRaises(Exception):
            await asyncio.wait_for(a.recv(), 3)
        self.assertNotIn("u3", self.relay.tokens)
        ws2 = await connect(self.url + "/agent"); self.open_ws.append(ws2)
        await ws2.send(hello("agent", "u3", "A3-" + "x" * 16))
        self.assertEqual(json.loads(await ws2.recv())["type"], "reject")

    async def test_admin_channel_disabled_without_token(self):
        ws = await connect(self.url + "/admin"); self.open_ws.append(ws)
        await ws.send(json.dumps({"type": "hello", "role": "admin", "token": ""}))
        self.assertEqual(json.loads(await ws.recv())["type"], "reject")

    def test_state_file_round_trip(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "state.json")
            relay = relay_mod.Relay(tokens={"u1": TOKENS["u1"]}, state_path=path)
            relay.admin_apply({"type": "set_tokens", "user": "dyn", "agent": "a" * 20, "sandbox": "b" * 20})
            loaded = relay_mod.load_tokens(None, path)
            self.assertEqual(loaded["dyn"]["agent"], "a" * 20)

if __name__ == "__main__":
    unittest.main()
