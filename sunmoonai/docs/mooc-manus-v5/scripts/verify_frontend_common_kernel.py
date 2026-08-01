#!/usr/bin/env python3
"""Verify B6.1 capability classification and implementation paths."""

from __future__ import annotations

import json
from pathlib import Path


def main() -> None:
    tpl = Path.home() / "tpl-app"
    matrix_path = tpl / "frontend-capability-matrix.json"
    matrix = json.loads(matrix_path.read_text())
    capabilities = matrix["capabilities"]
    common = [item for item in capabilities if item["class"] == "COMMON"]
    if not common:
        raise AssertionError("capability matrix has no COMMON entries")
    for item in common:
        for surface in ("admin", "web"):
            relative = item.get(surface)
            if not relative:
                raise AssertionError(f"{item['id']} has no {surface} implementation")
            if not (tpl / relative).exists():
                raise AssertionError(f"{item['id']} missing {surface} path: {relative}")
    for item in capabilities:
        if item["class"] == "ADMIN_ONLY" and item.get("web"):
            raise AssertionError(f"ADMIN_ONLY capability leaked to Web: {item['id']}")
        if item["class"] == "WEB_ONLY" and item.get("admin"):
            raise AssertionError(f"WEB_ONLY capability leaked to Admin: {item['id']}")
    print(
        json.dumps(
            {
                "task": "V5-P0-008B-B6.1",
                "result": "passed",
                "common_count": len(common),
                "classes": sorted({item["class"] for item in capabilities}),
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
