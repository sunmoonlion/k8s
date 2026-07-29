#!/usr/bin/env python3
"""Exercise and record a real same-runtime rollback for one P0-009 app.

The pre-migration Vue/React-Router/Nest images are intentionally not injected
into the new Next/FastAPI manifests.  Git replay from the freeze tag validates
that whole-stack recovery path.  This script validates the operational path:
candidate -> compatible frozen template runtime -> the exact candidate digest.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path("/home/zymun")
TPL_MANIFEST = ROOT / "tpl-app/template-release-manifest.json"
K8S = ROOT / "k8s"
IMAGE_RE = re.compile(r"^harbor\.sunmoonai\.com:30443/app-images/.+@sha256:[0-9a-f]{64}$")
PHASES = {"info": "b", "knowledge": "c", "research": "d"}
TASKS = {
    "info": "V5-P0-009B-rollback",
    "knowledge": "V5-P0-009C-rollback-drill",
    "research": "V5-P0-009D-rollback",
}
COMPONENTS = (
    ("admin-backend", "tpl-admin-backend", "backend"),
    ("admin-frontend", "tpl-admin-frontend", "frontend"),
    ("web-backend", "tpl-web-backend", "backend"),
    ("web-frontend", "tpl-web-frontend", "frontend"),
)


def run(command: list[str]) -> str:
    environment = dict(os.environ)
    environment.pop("DEBUG", None)
    completed = subprocess.run(
        command,
        check=True,
        text=True,
        capture_output=True,
        env=environment,
    )
    return completed.stdout.strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", choices=sorted(PHASES), required=True)
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument(
        "--kubeconfig",
        default=str(Path.home() / ".kube/kind-config"),
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    kubectl = os.environ.get("KUBECTL_BIN", "kubectl")
    prefix = [kubectl, "--kubeconfig", args.kubeconfig]
    phase = PHASES[args.app]
    manifest: dict[str, Any] = json.loads(TPL_MANIFEST.read_text())
    defaults = {
        item["module"]: item for item in manifest["default_components"]
    }
    drills: list[dict[str, Any]] = []

    for surface, template_module, container in COMPONENTS:
        deployment = f"{args.app}-{surface}-p0-009{phase}"
        get_image = prefix + [
            "get",
            "deployment",
            deployment,
            "-n",
            args.namespace,
            "-o",
            f"jsonpath={{.spec.template.spec.containers[?(@.name=='{container}')].image}}",
        ]
        candidate = run(get_image)
        if not IMAGE_RE.fullmatch(candidate):
            raise RuntimeError(
                f"{deployment} candidate is not digest pinned: {candidate!r}"
            )

        item = defaults[template_module]
        repository = item["image"].rsplit(":", 1)[0]
        rollback = f"{repository}@{item['digest']}"
        if not IMAGE_RE.fullmatch(rollback):
            raise RuntimeError(f"invalid template rollback image: {rollback!r}")

        set_image = prefix + [
            "set",
            "image",
            f"deployment/{deployment}",
            f"{container}={{image}}",
            "-n",
            args.namespace,
        ]
        rollout = prefix + [
            "rollout",
            "status",
            f"deployment/{deployment}",
            "-n",
            args.namespace,
            "--timeout=240s",
        ]

        run([part.format(image=rollback) for part in set_image])
        run(rollout)
        observed_rollback = run(get_image)
        if observed_rollback != rollback:
            raise RuntimeError(
                f"{deployment} rollback mismatch: {observed_rollback!r}"
            )

        run([part.format(image=candidate) for part in set_image])
        run(rollout)
        observed_candidate = run(get_image)
        if observed_candidate != candidate:
            raise RuntimeError(
                f"{deployment} restore mismatch: {observed_candidate!r}"
            )

        drills.append(
            {
                "deployment": deployment,
                "container": container,
                "path": [candidate, rollback, candidate],
                "rollback_rollout": "passed",
                "candidate_restore_rollout": "passed",
            }
        )

    result = {
        "task": TASKS[args.app],
        "result": "passed",
        "method": "same-runtime digest rollback plus exact candidate restore",
        "pre_migration_git_recovery": {
            "tag": "p0-009a-pre-20260729",
            "validated_by": "V5-P0-009E deterministic binary patch replay",
        },
        "drills": drills,
        "business_traffic_switched": False,
        "credentials_printed": False,
        "tokens_printed": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
