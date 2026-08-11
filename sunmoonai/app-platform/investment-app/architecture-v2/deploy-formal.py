#!/usr/bin/env python3
"""Plan, validate, reconcile and inspect the committed Investment release."""

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
GATE = K8S_ROOT / "sunmoonai/app-platform/scripts/verify-architecture-v2-instance.py"
SCRIPTS = K8S_ROOT / "sunmoonai/docs/architecture-v2/scripts"
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
    result.extend(("--request-timeout=30s", *items))
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
    subprocess.run([sys.executable, str(GATE), "--bundle", str(BUNDLE)], check=True)
    return json.loads((BUNDLE / "release.json").read_text(encoding="utf-8"))


def helper(args: argparse.Namespace, script: str, *items: str) -> None:
    command_line = ["bash", str(SCRIPTS / script), *items]
    if args.kubeconfig:
        command_line.extend(("--kubeconfig", str(args.kubeconfig)))
    env = os.environ.copy()
    env.pop("DEBUG", None)
    subprocess.run(command_line, check=True, env=env)


def reconcile_external_state(args: argparse.Namespace) -> None:
    helper(args, "prepare_r5_investment_broker_kind.sh", "--apply", "--no-restart")
    helper(args, "prepare_r5_investment_redis_acl_kind.sh", "--apply", "--no-restart")
    helper(
        args,
        "reconcile_r5_knowledge_active_retrieval_binding_kind.sh",
        "--caller",
        "investment",
    )


def external_secret_gate(args: argparse.Namespace, data: dict[str, Any]) -> None:
    missing = [
        name
        for name in data["external_secrets"]
        if run(
            args,
            "get",
            "secret",
            name,
            "-n",
            data["namespace"],
            check=False,
            capture=True,
        ).returncode
    ]
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
    for filename in data["resources"]:
        apply_file(args, filename, dry_run=True)
    print(json.dumps({"result": "passed", "action": "server-dry-run"}))


def set_formal_database_roles(args: argparse.Namespace) -> None:
    sql = (
        "ALTER ROLE investment_backend_user LOGIN; "
        "ALTER ROLE investment_backend_user_migration LOGIN; "
        "ALTER ROLE research_admin_user NOLOGIN; "
        "ALTER ROLE research_admin_user_migration NOLOGIN; "
        "ALTER ROLE research_web_user NOLOGIN; "
        "ALTER ROLE investment_admin_user NOLOGIN; "
        "ALTER ROLE investment_web_user NOLOGIN;"
    )
    shell = (
        'export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"; '
        'exec /opt/bitnami/postgresql/bin/psql -U postgres -d postgres '
        '-X -v ON_ERROR_STOP=1 -c "$1"'
    )
    run(
        args,
        "exec",
        "--quiet",
        "-n",
        "data-platform-dev",
        "postgresql-sunmoonai-0",
        "--",
        "sh",
        "-lc",
        shell,
        "sh",
        sql,
    )


def apply(args: argparse.Namespace, data: dict[str, Any]) -> None:
    namespace = data["namespace"]
    reconcile_external_state(args)
    external_secret_gate(args, data)
    apply_file(args, "00-prerequisites.yaml")
    apply_file(args, "30-network-policies.yaml")

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
    set_formal_database_roles(args)
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
        if run(
            args,
            "get",
            "deployment",
            deployment,
            "-n",
            namespace,
            check=False,
            capture=True,
        ).returncode == 0:
            run(args, "scale", "deployment", deployment, "--replicas=0", "-n", namespace)

    run(
        args,
        "delete",
        "ingressroute",
        "investment-r5-admin",
        "investment-r5-web",
        "-n",
        namespace,
        "--ignore-not-found=true",
        "--wait=true",
    )
    run(args, "delete", "job", migration, "-n", namespace, "--wait=true")
    print(
        json.dumps(
            {
                "task": "architecture-v2-investment-formal-reconcile",
                "result": "passed",
                "release_id": data["release_id"],
                "knowledge_active_caller": "investment",
                "legacy_replicas": 0,
                "migration_job_cleaned": True,
                "candidate_ingress_cleaned": True,
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
    active = run(
        args,
        "get",
        "secret",
        data["knowledge_binding"],
        "-n",
        namespace,
        "-o",
        "jsonpath={.metadata.labels.sunmoonai\\.com/active-caller}",
        capture=True,
    ).stdout
    if drifted or legacy_nonzero or active != "investment":
        raise DeployError(
            "declarative drift "
            f"files={drifted} legacy_nonzero={legacy_nonzero} active_caller={active!r}"
        )
    print(json.dumps({"result": "passed", "action": "drift", "drift": False}))


def status(args: argparse.Namespace, data: dict[str, Any]) -> None:
    run(
        args,
        "get",
        "deployment,service,ingressroute,networkpolicy",
        "-n",
        data["namespace"],
        "-l",
        f"sunmoonai.com/app={data['resource_app']}",
        "-o",
        "wide",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "action", choices=("plan", "server-dry-run", "apply", "status", "drift")
    )
    parser.add_argument("--kubeconfig", type=Path)
    parser.add_argument("--kubectl", default="kubectl")
    parser.add_argument("--timeout", type=int, default=300)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        data = release()
        if args.action == "plan":
            print(
                json.dumps(
                    {"result": "passed", "action": "plan", **data},
                    ensure_ascii=False,
                    indent=2,
                )
            )
        elif args.action == "server-dry-run":
            server_dry_run(args, data)
        elif args.action == "apply":
            apply(args, data)
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
