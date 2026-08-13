#!/usr/bin/env python3
"""Configuration-aware entry point for committed formal App releases."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

from deployment_config import ConfigError, load_base, load_profile, resolve_inside, validate_release


ACTIONS = (
    "config", "deploy", "validate", "validate-resources", "plan",
    "server-dry-run", "apply", "status", "logs", "drift", "uninstall", "cleanup",
)
ACTION_MAP = {
    "deploy": "apply", "validate": "server-dry-run",
    "validate-resources": "server-dry-run", "logs": "status",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-root", required=True, type=Path)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--cluster")
    parser.add_argument("--kubeconfig", type=Path)
    parser.add_argument("--timeout", type=int)
    parser.add_argument("--component", default="all")
    parser.add_argument("action", nargs="?", choices=ACTIONS, default="plan")
    parser.add_argument("compatibility", nargs="*")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        app_root = args.app_root.resolve()
        config_path = args.config.resolve()
        base = load_base(config_path)
        cluster = (args.cluster or base["DEFAULT_PROFILE"]).upper()
        profile_name = "production" if cluster == "PRODUCTION" else cluster
        profile_path = config_path.parent / "profiles" / f"{profile_name}.conf"
        profile = load_profile(profile_path)
        bundle = resolve_inside(app_root, base["BUNDLE_DIR"], field="BUNDLE_DIR")
        deploy_script = resolve_inside(app_root, base["DEPLOY_SCRIPT"], field="DEPLOY_SCRIPT")
        release_path = bundle / "release.json"
        if not release_path.is_file() or not deploy_script.is_file():
            raise ConfigError("configured bundle or deployment script does not exist")
        release = json.loads(release_path.read_text(encoding="utf-8"))
        validate_release(base, release)
        if len(args.compatibility) > 4:
            raise ConfigError("too many compatibility positional arguments")
        if len(args.compatibility) >= 2 and args.compatibility[1] != base["NAMESPACE"]:
            raise ConfigError(
                f"namespace is locked by the release: {base['NAMESPACE']}"
            )
        configured_kubeconfig = (
            args.kubeconfig
            or (Path(os.environ["KUBECONFIG"]) if os.environ.get("KUBECONFIG") else None)
            or Path(profile["KUBECONFIG"])
        )
        kubeconfig = configured_kubeconfig.expanduser().resolve()
        timeout = args.timeout or int(profile["TIMEOUT"])
        effective = {
            "result": "passed", "action": "config", "app": base["APP"],
            "cluster": cluster, "namespace": base["NAMESPACE"],
            "release_id": base["RELEASE_ID"], "bundle": str(bundle),
            "deploy_script": str(deploy_script), "kubeconfig": str(kubeconfig),
            "timeout": timeout, "component": args.component,
            "immutable_release_validated": True, "credentials_printed": False,
        }
        if args.action == "config":
            print(json.dumps(effective, ensure_ascii=False, indent=2))
            return 0
        if args.action in {"uninstall", "cleanup"}:
            raise ConfigError(
                "formal releases cannot be deleted from the default entry; use the gated rollback/retirement workflow"
            )
        action = ACTION_MAP.get(args.action, args.action)
        command = [
            sys.executable, str(deploy_script), action,
            "--kubeconfig", str(kubeconfig), "--timeout", str(timeout),
            "--component", args.component,
        ]
        environment = os.environ.copy()
        environment.pop("DEBUG", None)
        return subprocess.run(command, env=environment, check=False).returncode
    except (ConfigError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"result": "failed", "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
