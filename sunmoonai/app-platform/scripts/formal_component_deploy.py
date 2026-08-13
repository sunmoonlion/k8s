"""Shared component operations for committed App Platform releases."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Callable

import yaml


RUNTIME_COMPONENTS = {
    "backend-api",
    "backend-worker",
    "backend-scheduler",
    "admin-frontend",
    "web-frontend",
}
COMPONENTS = (
    "all",
    "prerequisites",
    "migration",
    "network-policies",
    *sorted(RUNTIME_COMPONENTS),
    "ingress",
)


def apply_runtime_component(
    *,
    args: Any,
    data: dict[str, Any],
    bundle: Path,
    component: str,
    run: Callable[..., Any],
    apply_file: Callable[..., None],
    dry_run: bool = False,
) -> str:
    if component not in RUNTIME_COMPONENTS:
        raise ValueError(f"unsupported runtime component: {component}")
    name = f"{data['resource_app']}-{component}"
    documents = [
        item
        for item in yaml.safe_load_all(
            (bundle / "20-runtime.yaml").read_text(encoding="utf-8")
        )
        if item and item.get("metadata", {}).get("name") == name
    ]
    if not any(item.get("kind") == "Deployment" for item in documents):
        raise ValueError(f"missing Deployment/{name}")
    payload = yaml.safe_dump_all(
        documents, sort_keys=False, allow_unicode=True
    )
    apply_items = ["apply"]
    if dry_run:
        apply_items.append("--dry-run=server")
    apply_items.extend(("-f", "-"))
    run(args, *apply_items, input_text=payload)
    if component in {"backend-api", "admin-frontend", "web-frontend"}:
        apply_file(args, "40-ingress.yaml", dry_run=dry_run)
    if not dry_run:
        run(
            args,
            "rollout",
            "status",
            f"deployment/{name}",
            "-n",
            data["namespace"],
            f"--timeout={args.timeout}s",
        )
    return name


def report(component: str, **extra: Any) -> None:
    print(
        json.dumps(
            {
                "task": "app-platform-component-deploy",
                "result": "passed",
                "component": component,
                "credentials_printed": False,
                **extra,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
