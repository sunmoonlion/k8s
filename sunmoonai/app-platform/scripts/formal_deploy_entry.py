#!/usr/bin/env python3
"""Configuration-aware entry point for committed formal App releases."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
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
    parser.add_argument("--backup-receipt", type=Path)
    parser.add_argument("--identity-preparation", type=Path)
    parser.add_argument("--dry-run", nargs="?", const="true", choices=("true", "false"))
    parser.add_argument("action", nargs="?", choices=ACTIONS, default="plan")
    parser.add_argument("compatibility", nargs="*")
    # Allow `--dry-run deploy ...` as well as `deploy ... --dry-run=false`.
    argv = list(sys.argv[1:])
    if sum(value == "--dry-run" or value.startswith("--dry-run=") for value in argv) > 1:
        parser.error("duplicate --dry-run")
    for index, value in enumerate(argv):
        if value == "--dry-run" and (index + 1 == len(argv) or argv[index + 1] not in ("true", "false")):
            argv[index] = "--dry-run=true"
    return parser.parse_args(argv)


def main() -> int:
    args = parse_args()
    try:
        if len(args.compatibility) > 4:
            raise ConfigError("too many compatibility positional arguments")
        positional_mode = args.compatibility[3] if len(args.compatibility) == 4 else None
        inherited_mode = os.environ.get("SUNMOON_DEPLOY_DRY_RUN", "false")
        if positional_mode not in (None, "true", "false") or inherited_mode not in ("true", "false"):
            raise ConfigError("dry_run must be true or false")
        if args.dry_run is not None and positional_mode is not None and args.dry_run != positional_mode:
            raise ConfigError("conflicting named and positional dry_run")
        if inherited_mode == "true" and "false" in (args.dry_run, positional_mode):
            raise ConfigError("cannot disable inherited dry-run")
        if "true" in (args.dry_run, positional_mode, inherited_mode):
            # In particular, legacy `deploy project namespace environment true`
            # must never map to apply or server-dry-run.
            args.action = "plan"
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
        if release.get("formal_release") is False and cluster != "KIND":
            raise ConfigError("development releases can only use the KIND profile")
        validate_release(base, release)
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
            sys.executable, "-B", str(deploy_script), action,
            "--kubeconfig", str(kubeconfig), "--timeout", str(timeout),
            "--component", args.component,
            "--cluster", cluster,
        ]
        if args.backup_receipt:
            command.extend(("--backup-receipt", str(args.backup_receipt.resolve())))
        if args.identity_preparation:
            command.extend(("--identity-preparation", str(args.identity_preparation.resolve())))
        environment = os.environ.copy()
        environment.pop("DEBUG", None)
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        return subprocess.run(command, env=environment, check=False).returncode
    except (ConfigError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"result": "failed", "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
