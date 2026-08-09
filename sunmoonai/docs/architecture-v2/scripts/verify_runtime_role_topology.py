#!/usr/bin/env python3
"""Verify Architecture v2 source and runtime-role topology without reading secrets."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


REQUIRED_BOOTSTRAPS = ("api.py", "worker.py", "scheduler.py", "migration.py")
INSTANCE_APPS = ("info", "knowledge", "investment")
PROHIBITED_TEMPLATE_PATHS = (
    "celeryworker-tpl-admin-backend",
    "nodebullworker-tpl-web-backend",
    "docs-worker",
    "k8s-scaffold",
    "dev-to-prod-deploy",
    "tpl-web-backend",
)


def submodule_paths(gitmodules: Path) -> set[str]:
    return set(re.findall(r"^\s*path\s*=\s*(\S+)\s*$", gitmodules.read_text(), re.M))


def check_backend(backend: Path, app: str, errors: list[str]) -> dict[str, object]:
    bootstrap = backend / "app" / "app" / "bootstrap"
    missing = [name for name in REQUIRED_BOOTSTRAPS if not (bootstrap / name).is_file()]
    if missing:
        errors.append(f"{app}: missing bootstrap files: {', '.join(missing)}")

    tasks = backend / "app" / "app" / "tasks"
    task_modules = sorted(
        path.name for path in tasks.glob("*.py") if path.name != "__init__.py"
    )
    if not task_modules:
        errors.append(f"{app}: no Backend task modules")

    worker_text = (bootstrap / "worker.py").read_text() if (bootstrap / "worker.py").is_file() else ""
    scheduler_text = (
        (bootstrap / "scheduler.py").read_text()
        if (bootstrap / "scheduler.py").is_file()
        else ""
    )
    if "celery_app" not in worker_text:
        errors.append(f"{app}: worker bootstrap does not expose celery_app")
    if "celery_app" not in scheduler_text:
        errors.append(f"{app}: scheduler bootstrap does not expose celery_app")

    return {
        "backend": str(backend),
        "bootstraps": list(REQUIRED_BOOTSTRAPS),
        "task_modules": task_modules,
    }


def check_template_backend_identity(backend: Path, errors: list[str]) -> None:
    build_conf = (backend / "mybuild" / "build.conf").read_text()
    expected_tokens = (
        'BACKEND_IMAGE="tpl-backend"',
        'BACKEND_TAG="architecture-v2-dev"',
    )
    for token in expected_tokens:
        if token not in build_conf:
            errors.append(f"tpl: build identity missing: {token}")

    active_identity_files = (
        backend / "mybuild" / "build.conf",
        backend / "mybuild" / "build-image.sh",
        backend / "mybuild" / "push-image.sh",
        backend / "search-access-bootstrap" / "config" / "access.json",
        backend / "storage-access-bootstrap" / "config" / "access.json",
    )
    for path in active_identity_files:
        text = path.read_text()
        if "tpl-admin-backend" in text or "ADMIN_BACKEND_IMAGE" in text:
            errors.append(f"tpl: legacy backend identity remains in {path.relative_to(backend)}")


def check_instance_backend_identity(backend: Path, app: str, errors: list[str]) -> None:
    build_conf = (backend / "mybuild" / "build.conf").read_text()
    expected_tokens = (
        f'BACKEND_IMAGE="{app}-backend"',
        'BACKEND_TAG="architecture-v2-dev"',
    )
    for token in expected_tokens:
        if token not in build_conf:
            errors.append(f"{app}: build identity missing: {token}")
    if "ADMIN_BACKEND_IMAGE" in build_conf:
        errors.append(f"{app}: legacy ADMIN_BACKEND_IMAGE remains")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--workspace-root",
        type=Path,
        default=Path(__file__).resolve().parents[5],
    )
    args = parser.parse_args()
    workspace = args.workspace_root.resolve()
    errors: list[str] = []
    report: dict[str, object] = {}

    template = workspace / "tpl-app"
    template_backend = template / "tpl-backend"
    report["tpl"] = check_backend(template_backend, "tpl", errors)
    check_template_backend_identity(template_backend, errors)

    for path in PROHIBITED_TEMPLATE_PATHS:
        if (template / path).exists():
            errors.append(f"tpl: prohibited v1 path remains: {path}")

    tpl_paths = submodule_paths(template / ".gitmodules")
    default_paths = {"tpl-backend", "tpl-admin-frontend", "tpl-web-frontend"}
    if not default_paths.issubset(tpl_paths):
        errors.append("tpl: default three components are not all registered")

    runtime_template = template / "k8s-scaffold-v2" / "templates" / "20-runtime.yaml.tpl"
    runtime_text = runtime_template.read_text()
    required_runtime_tokens = (
        "__APP__-backend-api",
        "__APP__-backend-worker",
        "__APP__-backend-scheduler",
        "app.bootstrap.api:app",
        "app.bootstrap.worker:celery_app",
        "app.bootstrap.scheduler:celery_app",
    )
    for token in required_runtime_tokens:
        if token not in runtime_text:
            errors.append(f"scaffold: missing runtime token: {token}")

    for app in INSTANCE_APPS:
        parent = workspace / f"{app}-app"
        backend = parent / f"{app}-backend"
        report[app] = check_backend(backend, app, errors)
        check_instance_backend_identity(backend, app, errors)
        expected = {
            f"{app}-backend",
            f"{app}-admin-frontend",
            f"{app}-web-frontend",
        }
        actual = submodule_paths(parent / ".gitmodules")
        if actual != expected:
            errors.append(
                f"{app}: active parent topology mismatch: expected={sorted(expected)} "
                f"actual={sorted(actual)}"
            )

    k8s = workspace / "k8s" / "sunmoonai" / "app-platform"
    if (k8s / "tools-app").exists():
        errors.append("k8s: retired tools-app source directory still exists")

    result = {
        "task": "architecture-v2-runtime-role-topology",
        "result": "failed" if errors else "passed",
        "runtime_roles": ["api", "worker", "scheduler", "migration"],
        "same_backend_image": True,
        "independent_worker_source_projects": False,
        "apps": report,
        "errors": errors,
        "credentials_printed": False,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
