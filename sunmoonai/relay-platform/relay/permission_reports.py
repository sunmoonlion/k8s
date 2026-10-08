"""local-permission-v1: bounded, credential-free control-plane reports.

This module validates wire shape only. The workstation owns permission decisions;
the workbench owns session binding and durable audit. The relay stores neither.
"""
from __future__ import annotations

import re
import time

CAPABILITY = "local-permission-v1"
NOTICE_CAPABILITY = "pairing-notice-v1"
REPORT_TTL = 60
MAX_REPORTS_PER_AGENT = 32
MAX_REPORTS_TOTAL = 1024
UUID = re.compile(r"[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\Z")
DIGEST = re.compile(r"[0-9a-f]{64}\Z")
CONN = re.compile(r"[0-9a-f]{8}\Z")


def valid_report(value: object, *, now: float | None = None) -> bool:
    if not isinstance(value, dict) or set(value) != {
        "id", "conn", "threadId", "requestDigest", "permissionDigest",
        "decision", "scope", "expiresAt",
    }:
        return False
    for key, pattern in (("id", UUID), ("threadId", UUID), ("conn", CONN),
                         ("requestDigest", DIGEST), ("permissionDigest", DIGEST)):
        if not isinstance(value[key], str) or not pattern.fullmatch(value[key]):
            return False
    scope = value["scope"]
    if not isinstance(scope, dict) or set(scope) != {"sandbox", "network"}:
        return False
    if scope["sandbox"] not in ("read-only", "workspace-write", "danger-full-access") or type(scope["network"]) is not bool:
        return False
    if scope["sandbox"] == "danger-full-access" and value["decision"] != "denied":
        return False
    expires = value["expiresAt"]
    now = time.time() if now is None else now
    return (value["decision"] in ("approved", "denied") and type(expires) is int
            and now < expires <= now + 7200)
