#!/usr/bin/env python3
"""Run the template-owned Web interaction vectors against all three consumers."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

ROOT = Path("/home/zymun/tpl-app")
VECTORS = ROOT / "contracts/web-interaction-v1.consumer-vectors.json"


def run(command: list[str], cwd: Path) -> None:
    environment = {
        **os.environ,
        "WEB_INTERACTION_CONSUMER_VECTORS": str(VECTORS),
    }
    subprocess.run(command, cwd=cwd, env=environment, check=True)


def main() -> None:
    document = json.loads(VECTORS.read_text(encoding="utf-8"))
    if document.get("contract") != "sunmoonai.web-interaction":
        raise SystemExit("unexpected Web interaction contract name")
    if document.get("contract_version") != 1:
        raise SystemExit("unexpected Web interaction contract version")
    for classification in ("valid", "invalid"):
        group = document[classification]
        for kind in ("snapshots", "events", "actions"):
            if not group.get(kind):
                raise SystemExit(f"{classification}.{kind} must not be empty")

    run(
        [
            "pnpm",
            "exec",
            "vitest",
            "run",
            "tests/unit/interaction-consumer-vectors.test.ts",
        ],
        ROOT / "tpl-web-frontend/app",
    )
    run(
        ["uv", "run", "pytest", "-q", "tests/test_interaction_consumer_vectors.py"],
        ROOT / "tpl-web-backend/app",
    )
    run(
        [
            "pnpm",
            "exec",
            "jest",
            "web-interaction.consumer-vectors.spec.ts",
            "--runInBand",
        ],
        ROOT / "tpl-web-backend-nest/app",
    )

    print(
        json.dumps(
            {
                "task": "V5-P0-008B-B6.3-consumer-vectors",
                "result": "passed",
                "contract": document["contract"],
                "contract_version": document["contract_version"],
                "consumers": [
                    "next-web",
                    "fastapi-web",
                    "nest-web",
                ],
                "valid_vectors": sum(
                    len(document["valid"][kind])
                    for kind in ("snapshots", "events", "actions")
                ),
                "invalid_vectors": sum(
                    len(document["invalid"][kind])
                    for kind in ("snapshots", "events", "actions")
                ),
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
