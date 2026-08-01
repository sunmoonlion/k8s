#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True
    ).strip()


def tracked_files(repo: Path) -> set[str]:
    output = git(repo, "ls-files", "app")
    return set(output.splitlines()) if output else set()


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path(__file__).resolve().parents[1]
        / "tpl-backend-capability-manifest.json",
    )
    parser.add_argument("--tpl-root", type=Path, default=Path("/home/zymun/tpl-app"))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1 or manifest.get("status") != "accepted":
        raise SystemExit("manifest schema/status is not accepted v1")

    repos: dict[str, Path] = {}
    tracked: dict[str, set[str]] = {}
    for name, source in manifest["sources"].items():
        repo = args.tpl_root / source["repository_directory"]
        if not (repo / ".git").exists():
            raise SystemExit(f"missing source repository: {repo}")
        baseline = source["baseline_commit"]
        subprocess.run(
            ["git", "-C", str(repo), "merge-base", "--is-ancestor", baseline, "HEAD"],
            check=True,
        )
        repos[name] = repo
        tracked[name] = tracked_files(repo)

    actual_admin_only = sorted(tracked["admin"] - tracked["web"])
    actual_web_only = sorted(tracked["web"] - tracked["admin"])
    actual_common_different = sorted(
        path
        for path in tracked["admin"] & tracked["web"]
        if digest(repos["admin"] / path) != digest(repos["web"] / path)
    )
    coverage = manifest["coverage"]
    expected = {
        "admin_only_tracked": actual_admin_only,
        "web_only_tracked": actual_web_only,
        "common_different_tracked": actual_common_different,
    }
    for key, actual in expected.items():
        declared = sorted(coverage[key])
        if declared != actual:
            missing = sorted(set(actual) - set(declared))
            stale = sorted(set(declared) - set(actual))
            raise SystemExit(f"coverage mismatch {key}: missing={missing} stale={stale}")

    capability_ids: set[str] = set()
    referenced: dict[str, set[str]] = {"admin": set(), "web": set()}
    for capability in manifest["capabilities"]:
        capability_id = capability["id"]
        if capability_id in capability_ids:
            raise SystemExit(f"duplicate capability id: {capability_id}")
        capability_ids.add(capability_id)
        if not capability.get("target") or not capability.get("acceptance"):
            raise SystemExit(f"capability lacks target/acceptance: {capability_id}")
        for source in capability["sources"]:
            repo_name = source["repository"]
            path = source["path"]
            if repo_name not in repos:
                raise SystemExit(f"unknown repository in {capability_id}: {repo_name}")
            if path not in tracked[repo_name]:
                raise SystemExit(f"untracked/missing source in {capability_id}: {repo_name}:{path}")
            referenced[repo_name].add(path)

    for path in coverage["admin_only_tracked"]:
        if path not in referenced["admin"]:
            raise SystemExit(f"unmapped Admin-only path: {path}")
    for path in coverage["web_only_tracked"]:
        if path not in referenced["web"]:
            raise SystemExit(f"unmapped Web-only path: {path}")
    for path in coverage["common_different_tracked"]:
        absent = [name for name in repos if path not in referenced[name]]
        if absent:
            raise SystemExit(f"unmapped differing path {path} for repositories={absent}")

    result = {
        "task": "architecture-v2-tpl-backend-capability-manifest",
        "result": "passed",
        "capabilities": len(capability_ids),
        "admin_only": len(actual_admin_only),
        "web_only": len(actual_web_only),
        "common_different": len(actual_common_different),
        "credentials_printed": False,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
