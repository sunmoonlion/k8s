"""工作台服务流 /service（0022，账 87）：配对、能力检查、限数、帧上限、open 带 kind。跑法见 test_relay.py。"""
from __future__ import annotations

import asyncio
import json
import unittest

import test_relay
from websockets.asyncio.client import connect

TOKENS = {"u1": {"agent": "A1", "sandbox": "S1", "workbench": "W1"}}


def agent_hello(capabilities=("service-v1",)):
    h = {"type": "hello", "proto": 1, "role": "agent", "user": "u1", "token": "A1", "codex": "0.155.1", "software": "test"}
    if capabilities is not None:
        h["capabilities"] = list(capabilities)
    return json.dumps(h)


def workbench_hello(token="W1", **extra):
    return json.dumps({"type": "hello", "proto": 1, "role": "workbench", "user": "u1", "token": token, "software": "workbench", **extra})


class ServiceTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.relay = test_relay.relay_mod.Relay(tokens={u: dict(e) for u, e in TOKENS.items()})
        self.server = await test_relay.serve(self.relay.handler, "127.0.0.1", 0, max_size=None, process_request=self.relay.process_request)
        self.port = self.server.sockets[0].getsockname()[1]
        self.url = f"ws://127.0.0.1:{self.port}"
        self.open_ws = []

    asyncTearDown = test_relay.RelayTests.asyncTearDown

    async def agent(self, capabilities=("service-v1",)):
        ctrl = await connect(self.url + "/agent"); self.open_ws.append(ctrl)
        await ctrl.send(agent_hello(capabilities))
        self.assertEqual(json.loads(await ctrl.recv())["type"], "welcome")
        return ctrl

    async def workbench(self, token="W1"):
        wb = await connect(self.url + "/service"); self.open_ws.append(wb)
        await wb.send(workbench_hello(token))
        return wb

    async def open_data(self, ctrl):
        msg = json.loads(await asyncio.wait_for(ctrl.recv(), 5))
        data = await connect(self.url + f"/agent-data?conn={msg['conn']}"); self.open_ws.append(data)
        await data.send(json.dumps({"type": "hello", "proto": 1, "role": "agent", "user": "u1", "token": "A1", "codex": "0.155.1", "software": "test", "conn": msg["conn"]}))
        return msg, data

    async def test_pairs_with_capable_agent_and_open_carries_kind(self):
        ctrl = await self.agent()
        wb = await self.workbench()
        msg, data = await self.open_data(ctrl)
        self.assertEqual(msg, {"type": "open", "conn": msg["conn"], "kind": "service"})
        welcome = json.loads(await asyncio.wait_for(wb.recv(), 5))
        self.assertEqual(welcome["type"], "welcome"); self.assertEqual(welcome["kind"], "service"); self.assertEqual(welcome["conn"], msg["conn"])
        await wb.send('{"jsonrpc":"2.0","id":1,"method":"service/hello"}')
        self.assertEqual(await asyncio.wait_for(data.recv(), 5), '{"jsonrpc":"2.0","id":1,"method":"service/hello"}')
        await data.send('{"jsonrpc":"2.0","id":1,"result":{"roots":[]}}')
        self.assertEqual(await asyncio.wait_for(wb.recv(), 5), '{"jsonrpc":"2.0","id":1,"result":{"roots":[]}}')
        self.assertEqual(self.relay.agents["u1"].service_streams, 1)
        self.assertEqual(self.relay.agents["u1"].streams, 0)
        self.assertEqual(self.relay.stats["service_paired"], 1)

    async def test_sandbox_open_has_no_kind(self):
        ctrl = await self.agent()
        sb = await connect(self.url + "/sandbox"); self.open_ws.append(sb)
        await sb.send(test_relay.hello("sandbox", "u1", "S1"))
        msg, _ = await self.open_data(ctrl)
        self.assertNotIn("kind", msg)

    async def test_agent_without_capability_is_rejected(self):
        await self.agent(capabilities=None)
        wb = await self.workbench()
        self.assertEqual(json.loads(await wb.recv()), {"type": "reject", "reason": "agent has no service channel"})

    async def test_agent_offline_is_rejected(self):
        wb = await self.workbench()
        self.assertEqual(json.loads(await wb.recv()), {"type": "reject", "reason": "agent offline"})

    async def test_wrong_role_and_bad_token(self):
        await self.agent()
        wb = await connect(self.url + "/service"); self.open_ws.append(wb)
        await wb.send(test_relay.hello("sandbox", "u1", "S1"))
        self.assertEqual(json.loads(await wb.recv())["reason"], "role sandbox on workbench path")
        wb2 = await self.workbench(token="nope")
        self.assertEqual(json.loads(await wb2.recv()), {"type": "reject", "reason": "bad token"})

    async def test_service_stream_limit_per_user(self):
        ctrl = await self.agent()
        for _ in range(test_relay.relay_mod.MAX_SERVICE_STREAMS_PER_USER):
            wb = await self.workbench(); await self.open_data(ctrl)
            self.assertEqual(json.loads(await asyncio.wait_for(wb.recv(), 5))["type"], "welcome")
        extra = await self.workbench()
        self.assertEqual(json.loads(await extra.recv()), {"type": "reject", "reason": "too many service streams"})
        # 沙箱流不受服务流计数影响
        sb = await connect(self.url + "/sandbox"); self.open_ws.append(sb)
        await sb.send(test_relay.hello("sandbox", "u1", "S1")); await self.open_data(ctrl)
        self.assertEqual(json.loads(await asyncio.wait_for(sb.recv(), 5))["type"], "welcome")

    async def test_oversized_frame_closes_the_service_stream(self):
        ctrl = await self.agent()
        wb = await self.workbench()
        _, data = await self.open_data(ctrl)
        json.loads(await asyncio.wait_for(wb.recv(), 5))
        await wb.send("x" * (test_relay.relay_mod.SERVICE_MAX_FRAME + 1))
        with self.assertRaises(Exception):
            await asyncio.wait_for(wb.recv(), 5)
        with self.assertRaises(Exception):
            await asyncio.wait_for(data.recv(), 5)
        for _ in range(100):
            if self.relay.agents["u1"].service_streams == 0: break
            await asyncio.sleep(.01)
        self.assertEqual(self.relay.agents["u1"].service_streams, 0)

    async def test_admin_agents_lists_capabilities(self):
        await self.agent(capabilities=("service-v1", "bad name!", "x" * 40))
        agents = self.relay.admin_apply({"type": "agents"})["agents"]
        self.assertEqual(agents["u1"]["capabilities"], ["service-v1"])
