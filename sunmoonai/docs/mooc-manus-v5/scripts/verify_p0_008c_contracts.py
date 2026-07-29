#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1] / "contracts"
WEB_ROOT = ROOT / "research-agent-web" / "v1"
RUNTIME_ROOT = ROOT / "research-runtime" / "v1"


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise AssertionError(f"{path} must contain a JSON object")
    return value


def verify_manifest(root: Path) -> dict[str, Any]:
    manifest = load(root / "contract-manifest.json")
    files = manifest.get("files")
    if not isinstance(files, dict) or not files:
        raise AssertionError(f"{root}: manifest files must be a non-empty object")
    for relative, expected in files.items():
        if not isinstance(relative, str) or not isinstance(expected, str):
            raise AssertionError(f"{root}: invalid manifest entry")
        target = root / relative
        actual = hashlib.sha256(target.read_bytes()).hexdigest()
        if actual != expected:
            raise AssertionError(
                f"{target}: sha256 mismatch expected={expected} actual={actual}"
            )
        schema = load(target)
        if schema.get("additionalProperties") is not False and "oneOf" not in schema:
            raise AssertionError(f"{target}: browser/runtime request must be exact-field")
    return manifest


def main() -> None:
    web = verify_manifest(WEB_ROOT)
    runtime = verify_manifest(RUNTIME_ROOT)

    if web["contract"] != "sunmoonai.research.agent-web":
        raise AssertionError("unexpected browser contract owner")
    if runtime["contract"] != "sunmoonai.research.runtime":
        raise AssertionError("unexpected runtime contract owner")
    if web["major"] != 1 or runtime["major"] != 1:
        raise AssertionError("pilot contracts must start at major 1")

    browser_boundary = web["browser_boundary"]
    if browser_boundary["service_token"] != "forbidden":
        raise AssertionError("browser must never hold the Runtime service token")
    if runtime["identity"]["browser_token_forwarding"] != "forbidden":
        raise AssertionError("Web BFF must not forward the browser token")
    if runtime["pilot_boundary"] != {
        "enabled_by_default": False,
        "stable_traffic": False,
        "m1_production_runtime": False,
        "disposable_after_gate_p0": True,
    }:
        raise AssertionError("Runtime candidate pilot boundary drifted")

    web_routes = web["routes"]
    runtime_routes = runtime["routes"]
    if len(set(web_routes.values())) != len(web_routes):
        raise AssertionError("browser routes must be unique")
    if len(set(runtime_routes.values())) != len(runtime_routes):
        raise AssertionError("runtime routes must be unique")
    if not all("/internal/v1/research/" in route for route in runtime_routes.values()):
        raise AssertionError("Runtime routes must remain on the internal namespace")

    print(
        json.dumps(
            {
                "task": "V5-P0-008C.1",
                "result": "passed",
                "browser_contract": web["contract"],
                "runtime_contract": runtime["contract"],
                "browser_service_token": "forbidden",
                "runtime_default_enabled": False,
                "stable_traffic": False,
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
