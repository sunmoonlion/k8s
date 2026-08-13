#!/usr/bin/env python3
"""Plan, validate, reconcile and inspect the committed Info formal release."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


class DeployError(RuntimeError):
    pass


ROOT = Path(__file__).resolve().parent
BUNDLE = ROOT / "bundle"
K8S_ROOT = ROOT.parents[3]
GATE = K8S_ROOT / "sunmoonai/app-platform/scripts/verify-formal-instance.py"
SCRIPTS = K8S_ROOT / "sunmoonai/app-platform/scripts"
sys.path.insert(0, str(SCRIPTS))
import formal_component_deploy as component_deploy
STEADY_FILES = (
    "00-prerequisites.yaml",
    "20-runtime.yaml",
    "30-network-policies.yaml",
    "40-ingress.yaml",
)


def command(args: argparse.Namespace, *items: str) -> list[str]:
    result = [args.kubectl]
    if args.kubeconfig:
        result.extend(("--kubeconfig", str(args.kubeconfig)))
    result.extend((f"--request-timeout={max(args.timeout, 30)}s", *items))
    return result


def run(
    args: argparse.Namespace,
    *items: str,
    check: bool = True,
    capture: bool = False,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.pop("DEBUG", None)
    return subprocess.run(
        command(args, *items),
        check=check,
        capture_output=capture,
        text=True,
        input=input_text,
        env=env,
    )


def release() -> dict[str, Any]:
    subprocess.run(
        [sys.executable, str(GATE), "--bundle", str(BUNDLE)], check=True
    )
    return json.loads((BUNDLE / "release.json").read_text(encoding="utf-8"))


def external_secret_gate(args: argparse.Namespace, data: dict[str, Any]) -> None:
    namespace = data["namespace"]
    missing: list[str] = []
    for name in data["external_secrets"]:
        result = run(
            args,
            "get",
            "secret",
            name,
            "-n",
            namespace,
            check=False,
            capture=True,
        )
        if result.returncode:
            missing.append(name)
    if missing:
        raise DeployError(f"missing external Secrets: {missing}")


def apply_file(args: argparse.Namespace, filename: str, *, dry_run: bool = False) -> None:
    items = ["apply"]
    if dry_run:
        items.append("--dry-run=server")
    items.extend(("-f", str(BUNDLE / filename)))
    run(args, *items)


def server_dry_run(args: argparse.Namespace, data: dict[str, Any]) -> None:
    external_secret_gate(args, data)
    if args.component != "all":
        apply_file(args, "00-prerequisites.yaml", dry_run=True)
        if args.component == "network-policies":
            apply_file(args, "30-network-policies.yaml", dry_run=True)
        elif args.component == "migration":
            apply_file(args, "10-migration.yaml", dry_run=True)
        elif args.component == "ingress":
            apply_file(args, "40-ingress.yaml", dry_run=True)
        elif args.component in component_deploy.RUNTIME_COMPONENTS:
            apply_file(args, "30-network-policies.yaml", dry_run=True)
            component_deploy.apply_runtime_component(
                args=args,
                data=data,
                bundle=BUNDLE,
                component=args.component,
                run=run,
                apply_file=apply_file,
                dry_run=True,
            )
        component_deploy.report(args.component, action="server-dry-run")
        return
    for filename in data["resources"]:
        apply_file(args, filename, dry_run=True)
    print(json.dumps({"result": "passed", "action": "server-dry-run"}))


def run_migration(args: argparse.Namespace, data: dict[str, Any]) -> None:
    namespace = data["namespace"]
    migration = f"{data['resource_app']}-backend-migration-{data['release_id']}"
    run(
        args,
        "delete",
        "job",
        migration,
        "-n",
        namespace,
        "--ignore-not-found=true",
        "--wait=true",
    )
    apply_file(args, "10-migration.yaml")
    completed = run(
        args,
        "wait",
        "--for=condition=complete",
        f"job/{migration}",
        "-n",
        namespace,
        f"--timeout={args.timeout}s",
        check=False,
    )
    if completed.returncode:
        run(args, "logs", f"job/{migration}", "-n", namespace, "--tail=100", check=False)
        raise DeployError("migration Job failed or timed out")
    run(args, "logs", f"job/{migration}", "-n", namespace, "--tail=100")
    run(args, "delete", "job", migration, "-n", namespace, "--wait=true")


def apply_component(args: argparse.Namespace, data: dict[str, Any]) -> None:
    external_secret_gate(args, data)
    apply_file(args, "00-prerequisites.yaml")
    if args.component == "prerequisites":
        component_deploy.report(args.component)
    elif args.component == "network-policies":
        apply_file(args, "30-network-policies.yaml")
        component_deploy.report(args.component)
    elif args.component == "migration":
        run_migration(args, data)
        component_deploy.report(args.component, migration_job_cleaned=True)
    elif args.component == "ingress":
        apply_file(args, "40-ingress.yaml")
        component_deploy.report(args.component)
    else:
        apply_file(args, "30-network-policies.yaml")
        name = component_deploy.apply_runtime_component(
            args=args,
            data=data,
            bundle=BUNDLE,
            component=args.component,
            run=run,
            apply_file=apply_file,
        )
        component_deploy.report(args.component, deployment=name)


def apply(args: argparse.Namespace, data: dict[str, Any]) -> None:
    namespace = data["namespace"]
    external_secret_gate(args, data)
    apply_file(args, "00-prerequisites.yaml")
    apply_file(args, "30-network-policies.yaml")

    run_migration(args, data)

    apply_file(args, "20-runtime.yaml")
    apply_file(args, "40-ingress.yaml")
    for deployment in data["deployment_replicas"]:
        run(
            args,
            "rollout",
            "status",
            f"deployment/{deployment}",
            "-n",
            namespace,
            f"--timeout={args.timeout}s",
        )

    for deployment in data["legacy_deployments"]:
        exists = run(
            args,
            "get",
            "deployment",
            deployment,
            "-n",
            namespace,
            check=False,
            capture=True,
        )
        if exists.returncode == 0:
            run(args, "scale", "deployment", deployment, "--replicas=0", "-n", namespace)
    print(
        json.dumps(
            {
                "task": "app-platform-info-formal-reconcile",
                "result": "passed",
                "release_id": data["release_id"],
                "legacy_replicas": 0,
                "migration_job_cleaned": True,
                "credentials_printed": False,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


def drift(args: argparse.Namespace, data: dict[str, Any]) -> None:
    namespace = data["namespace"]
    drifted: list[str] = []
    for filename in STEADY_FILES:
        result = run(
            args,
            "diff",
            "-f",
            str(BUNDLE / filename),
            check=False,
            capture=True,
        )
        if result.returncode not in (0, 1):
            sys.stderr.write(result.stderr)
            raise DeployError(f"kubectl diff failed: {filename}")
        if result.returncode == 1:
            drifted.append(filename)
            sys.stdout.write(result.stdout)
    legacy_nonzero: dict[str, int] = {}
    for name in data["legacy_deployments"]:
        result = run(
            args,
            "get",
            "deployment",
            name,
            "-n",
            namespace,
            "-o",
            "jsonpath={.spec.replicas}",
            check=False,
            capture=True,
        )
        if result.returncode == 0 and int(result.stdout or "0") != 0:
            legacy_nonzero[name] = int(result.stdout)
    if drifted or legacy_nonzero:
        raise DeployError(
            f"declarative drift files={drifted} legacy_nonzero={legacy_nonzero}"
        )
    print(json.dumps({"result": "passed", "action": "drift", "drift": False}))


def status(args: argparse.Namespace, data: dict[str, Any]) -> None:
    namespace = data["namespace"]
    run(
        args,
        "get",
        "deployment,service,ingressroute,networkpolicy",
        "-n",
        namespace,
        "-l",
        f"sunmoonai.com/app={data['resource_app']}",
        "-o",
        "wide",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("plan", "server-dry-run", "apply", "status", "drift"))
    parser.add_argument("--kubeconfig", type=Path)
    parser.add_argument("--kubectl", default="kubectl")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--component", choices=component_deploy.COMPONENTS, default="all")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        data = release()
        if args.action == "plan":
            print(json.dumps({"result": "passed", "action": "plan", **data}, ensure_ascii=False, indent=2))
        elif args.action == "server-dry-run":
            server_dry_run(args, data)
        elif args.action == "apply":
            if args.component == "all":
                apply(args, data)
            else:
                apply_component(args, data)
        elif args.action == "status":
            status(args, data)
        else:
            drift(args, data)
        return 0
    except (DeployError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(json.dumps({"result": "failed", "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
