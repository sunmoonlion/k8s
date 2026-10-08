"""Real loopback control frames; no Codex or production credentials required."""
import asyncio
import json
import time
import uuid
import unittest
from copy import deepcopy

import test_relay
from permission_reports import valid_report, MAX_REPORTS_PER_AGENT


def report(conn):
    return {
        "id": str(uuid.uuid4()), "conn": conn, "threadId": str(uuid.uuid4()),
        "requestDigest": "a" * 64, "permissionDigest": "b" * 64,
        "decision": "approved", "scope": {"sandbox": "workspace-write", "network": False},
        "expiresAt": int(time.time()) + 300,
    }


class PermissionTests(unittest.IsolatedAsyncioTestCase):
    asyncSetUp = test_relay.RelayTests.asyncSetUp
    asyncTearDown = test_relay.RelayTests.asyncTearDown
    agent = test_relay.RelayTests.agent
    sandbox = test_relay.RelayTests.sandbox
    open_data_on_request = test_relay.RelayTests.open_data_on_request
    async def paired(self):
        ctrl, welcome = await self.agent()
        self.assertIn("local-permission-v1", welcome["capabilities"])
        self.relay.agents["u1"].machine = {"name": "fixture"}
        sb = await self.sandbox()
        data = await self.open_data_on_request(ctrl)
        paired = json.loads(await sb.recv())
        return ctrl, sb, data, paired["conn"]

    async def wait_pending(self, count=1):
        for _ in range(100):
            agent = self.relay.agents.get("u1")
            if agent and len(agent.permission_reports) == count:
                return
            await asyncio.sleep(.01)
        self.fail("pending report count did not converge")

    async def test_report_is_not_acknowledged_until_workbench_receipt(self):
        ctrl, _, _, conn = await self.paired()
        item = report(conn)
        await ctrl.send(json.dumps({"type": "permission_report", "report": item}))
        await self.wait_pending()
        with self.assertRaises(TimeoutError):
            await asyncio.wait_for(ctrl.recv(), .05)
        agents = self.relay.admin_apply({"type": "agents"})["agents"]
        queued = agents["u1"]["permission_reports"]
        self.assertEqual(queued[0]["report"], item)
        self.assertEqual(self.relay.admin_apply({"type": "permission_receipts", "receipts": [
            {"receipt": queued[0]["receipt"], "status": "recorded"},
        ]}), {"type": "ok"})
        self.assertEqual(json.loads(await asyncio.wait_for(ctrl.recv(), 1)), {
            "type": "permission_receipt", "id": item["id"], "status": "recorded",
        })
        self.assertNotIn("permission_reports", self.relay.admin_apply({"type": "agents"})["agents"]["u1"])

    async def test_duplicate_is_idempotent_and_changed_payload_closes_agent(self):
        ctrl, _, _, conn = await self.paired()
        item = report(conn)
        for _ in range(2):
            await ctrl.send(json.dumps({"type": "permission_report", "report": item}))
        await self.wait_pending()
        item["scope"]["network"] = True
        await ctrl.send(json.dumps({"type": "permission_report", "report": item}))
        await asyncio.wait_for(ctrl.wait_closed(), 2)
        self.assertEqual(ctrl.close_code, 1008)

    async def test_unbound_connection_and_unknown_fields_are_rejected(self):
        ctrl, _, _, conn = await self.paired()
        item = report(conn)
        item["conn"] = "00000000" if conn != "00000000" else "ffffffff"
        await ctrl.send(json.dumps({"type": "permission_report", "report": item}))
        await asyncio.wait_for(ctrl.wait_closed(), 2)
        self.assertEqual(ctrl.close_code, 1008)

    async def test_queue_is_bounded_and_receipts_expire(self):
        ctrl, _, _, conn = await self.paired()
        for _ in range(MAX_REPORTS_PER_AGENT):
            await ctrl.send(json.dumps({"type": "permission_report", "report": report(conn)}))
        await self.wait_pending(MAX_REPORTS_PER_AGENT)
        extra = report(conn)
        await ctrl.send(json.dumps({"type": "permission_report", "report": extra}))
        self.assertEqual(json.loads(await asyncio.wait_for(ctrl.recv(), 1))["status"], "rejected")
        for item in self.relay.agents["u1"].permission_reports.values():
            item["deadline"] = 0
        self.assertNotIn("permission_reports", self.relay.admin_apply({"type": "agents"})["agents"]["u1"])

    async def test_stale_receipt_does_not_reach_replacement_agent(self):
        ctrl, _, _, conn = await self.paired()
        await ctrl.send(json.dumps({"type": "permission_report", "report": report(conn)}))
        await self.wait_pending()
        receipt = next(iter(self.relay.agents["u1"].permission_reports))
        new, _ = await self.agent()
        self.relay.admin_apply({"type": "permission_receipts", "receipts": [{"receipt": receipt, "status": "recorded"}]})
        with self.assertRaises(TimeoutError):
            await asyncio.wait_for(new.recv(), .05)

    async def test_mismatch_notifies_agent_without_disconnecting_it(self):
        ctrl, _ = await self.agent()
        sb = await self.sandbox(codex="0.156.0")
        self.assertEqual(json.loads(await ctrl.recv()), {"type": "notice", "code": "codex_version_mismatch"})
        self.assertEqual(json.loads(await sb.recv())["type"], "reject")
        self.assertIsNone(ctrl.close_code)

    def test_strict_schema_rejects_credential_fields_and_ambiguous_values(self):
        good = report("01234567")
        self.assertTrue(valid_report(good))
        for key, value in [("token", "synthetic"), ("expiresAt", True), ("expiresAt", int(time.time()) - 1),
                           ("expiresAt", int(time.time()) + 7201), ("threadId", "not-uuid"), ("decision", "yes"),
                           ("requestDigest", "a" * 64 + "\n")]:
            bad = deepcopy(good); bad[key] = value
            self.assertFalse(valid_report(bad))
        for scope in [{"sandbox": "danger-full-access", "network": False}, {"sandbox": "read-only", "network": "false"},
                      {"sandbox": "read-only", "network": False, "env": {}}]:
            self.assertFalse(valid_report(good | {"scope": scope}))
