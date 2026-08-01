#!/usr/bin/env python3
"""Compare business Deployment specs with a pre-isolation P0-009 snapshot."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
from pathlib import Path
from typing import Any


def normalized(items: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {
        item["metadata"]["name"]: {
            "generation": item["metadata"].get("generation"),
            "spec_sha256": hashlib.sha256(
                json.dumps(
                    item["spec"],
                    ensure_ascii=False,
                    sort_keys=True,
                    separators=(",", ":"),
                ).encode()
            ).hexdigest(),
        }
        for item in items
        if "p0-009" not in item["metadata"]["name"]
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument(
        "--kubeconfig",
        default=str(Path.home() / ".kube/kind-config"),
    )
    parser.add_argument(
        "--current-snapshot",
        type=Path,
        help="Read the current Deployment list from a captured kubectl JSON file.",
    )
    parser.add_argument(
        "--allow-current-extras",
        action="store_true",
        help=(
            "Compare only names captured by an intentionally scoped baseline; "
            "record, but do not fail on, other current Deployments."
        ),
    )
    args = parser.parse_args()

    if args.current_snapshot:
        current = json.loads(args.current_snapshot.read_text())
    else:
        kubectl = os.environ.get("KUBECTL_BIN", "kubectl")
        environment = dict(os.environ)
        environment.pop("DEBUG", None)
        current = json.loads(
            subprocess.run(
                [
                    kubectl,
                    "--kubeconfig",
                    args.kubeconfig,
                    "get",
                    "deployment",
                    "-n",
                    args.namespace,
                    "-o",
                    "json",
                ],
                check=True,
                text=True,
                capture_output=True,
                env=environment,
            ).stdout
        )
    baseline = json.loads(args.baseline.read_text())
    before = normalized(baseline["items"])
    current_all = normalized(current["items"])
    current_extras = sorted(current_all.keys() - before.keys())
    after = (
        {name: current_all[name] for name in before.keys() & current_all.keys()}
        if args.allow_current_extras
        else current_all
    )
    added = [] if args.allow_current_extras else current_extras
    removed = sorted(before.keys() - after.keys())
    changed = sorted(
        name for name in before.keys() & after.keys() if before[name] != after[name]
    )
    passed = not (added or removed or changed)
    result = {
        "task": "V5-P0-009-business-deployments-unchanged",
        "result": "passed" if passed else "failed",
        "comparison": "metadata.generation plus complete Deployment spec",
        "baseline": str(args.baseline),
        "baseline_scope": (
            "captured deployment names"
            if args.allow_current_extras
            else "complete non-P0-009 deployment set"
        ),
        "deployment_count": len(before),
        "before": before,
        "after": after,
        "current_extras_outside_baseline_scope": current_extras,
        "added": added,
        "removed": removed,
        "changed": changed,
        "business_traffic_switched": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
