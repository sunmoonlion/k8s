#!/usr/bin/env python3
"""Verify P0-009A freeze inventory without mutating business apps."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

K8S = Path("/home/zymun/master/k8s")
TPL = Path("/home/zymun/master/tpl-app")
FREEZE = K8S / "sunmoonai/docs/evidence/v5/V5-P0-009A/freeze.json"
MANIFEST = TPL / "template-release-manifest.json"
TAG = "p0-009a-pre-20260729"


def git(cwd: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(cwd), *args], text=True).strip()


def main() -> None:
    freeze = json.loads(FREEZE.read_text())
    manifest = json.loads(MANIFEST.read_text())
    assert freeze["result"] == "passed"
    assert freeze["template_release_id"] == manifest["template_release_id"]
    assert freeze["policy"]["serial_order"] == ["info", "knowledge", "research"]
    assert freeze["policy"]["business_code_changes_in_009a"] is False
    assert set(freeze["policy"]["excluded_from_instances"]) == {
        "tpl-admin-frontend-react",
        "tpl-admin-frontend-vue",
        "tpl-web-backend-nest",
    }

    defaults = {c["module"] for c in manifest["default_components"]}
    assert defaults == {
        "tpl-admin-frontend",
        "tpl-admin-backend",
        "tpl-web-frontend",
        "tpl-web-backend",
    }

    for app, meta in freeze["apps"].items():
        root = Path(f"/home/zymun/{app}-app")
        assert git(root, "rev-list", "-n", "1", TAG) == meta["parent_commit"]
        assert meta["serial_order_index"] in (1, 2, 3)
        assert meta["status"] == "FROZEN_NOT_STARTED_SYNC"
        for name, module in meta["modules"].items():
            path = root / name
            assert git(path, "rev-list", "-n", "1", TAG) == module["commit"]
            assert module["pre_migration_tag"] == TAG
            assert module["keep"], f"{name} must keep domain assets"
            plan = module["plan"]
            assert plan["to_template"] in defaults
            if name.endswith("web-backend"):
                assert plan["action"] == "REPLACE_WITH_FASTAPI_DEFAULT"
                assert plan["to_template"] == "tpl-web-backend"

    # No business app HEAD movement required by 009A beyond tags.
    print(
        json.dumps(
            {
                "task": "V5-P0-009A",
                "result": "passed",
                "template_release_id": freeze["template_release_id"],
                "apps": list(freeze["apps"]),
                "pre_migration_tag": TAG,
                "next_task": freeze["next_task"],
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
