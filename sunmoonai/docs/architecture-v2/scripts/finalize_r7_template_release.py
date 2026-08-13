#!/usr/bin/env python3
"""Finalize tpl-app's release manifest only after the complete R7 template gate passes."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

EXPECTED_IMAGES = {
    "backend": "harbor.sunmoonai.com:30443/app-images/tpl-backend@sha256:8b504098427ab5349a04e933e1fdf71e3a8fc11ce0f5b36fff703ad356bad348",
    "admin": "harbor.sunmoonai.com:30443/app-images/tpl-admin-frontend@sha256:cd2b91f54d71586b69c7f3d558066fb8afecf8a701911951076aa3ea5b30ea6b",
    "web": "harbor.sunmoonai.com:30443/app-images/tpl-web-frontend@sha256:a835b1d4dcb8b405233fc901c11452f26f971b9d21c679e3cdee6c0d9bfbf729",
}
COMPONENT_KEYS = {
    "tpl-backend": "backend",
    "tpl-admin-frontend": "admin",
    "tpl-web-frontend": "web",
}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip()


def tracked_files(repo: Path) -> int:
    return git(repo, "ls-files", "-z").count("\0")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tpl-root", type=Path, default=Path("/home/zymun/tpl-app"))
    parser.add_argument(
        "--evidence-dir",
        type=Path,
        default=Path(
            "/home/zymun/k8s/sunmoonai/docs/architecture-v2/evidence/R7-release/template"
        ),
    )
    args = parser.parse_args()
    tpl_root = args.tpl_root.resolve()
    evidence = args.evidence_dir.resolve()
    result = load(evidence / "result.json")
    release = load(evidence / "release.json")
    if result.get("result") != "passed":
        raise SystemExit("R7 template gate has not passed")
    if release.get("images") != EXPECTED_IMAGES:
        raise SystemExit("R7 template gate did not test the frozen image set")

    manifest_path = tpl_root / "template-release-manifest.json"
    manifest = load(manifest_path)
    manifest.update(
        {
            "template_release": "2.0.0",
            "status": "FORMAL_RELEASE",
            "formal_release": True,
            "target_formal_version": "2.0.0",
        }
    )
    manifest["source"].update(
        {
            "branch": "architecture-v2",
            "commit": git(tpl_root, "rev-parse", "HEAD"),
            "tree": git(tpl_root, "rev-parse", "HEAD^{tree}"),
        }
    )
    for component in manifest["default_components"]:
        path = component["path"]
        repo = tpl_root / path
        role = COMPONENT_KEYS[path]
        component.update(
            {
                "commit": git(repo, "rev-parse", "HEAD"),
                "tree": git(repo, "rev-parse", "HEAD^{tree}"),
                "tracked_files": tracked_files(repo),
                "image": EXPECTED_IMAGES[role],
            }
        )
    manifest["kubernetes_scaffold"].update(
        {
            "tree": git(tpl_root, "rev-parse", "HEAD:k8s-deployment"),
            "tracked_files": len(
                git(tpl_root, "ls-files", "k8s-deployment").splitlines()
            ),
        }
    )
    manifest["test_evidence"]["R7"] = (
        "k8s/sunmoonai/docs/architecture-v2/R7-release-closeout.md"
    )
    manifest["test_evidence"]["R7_template_machine"] = (
        "k8s/sunmoonai/docs/architecture-v2/evidence/R7-release/template"
    )
    manifest["release_policy"] = {
        "instance_sync_order": ["info", "knowledge", "investment"],
        "business_changes_before_r4_complete": False,
        "mutable_image_tags_allowed": False,
        "overwrite_v1_1_0_0": False,
        "formal_version": "2.0.0",
        "promotion_method": "exact-digest-alias",
                "observation_window": "closed",
                "irreversible_v1_cleanup_allowed": True,
    }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        json.dumps(
            {
                "task": "architecture-v2-r7-template-release",
                "result": "passed",
                "manifest": str(manifest_path),
                "version": "2.0.0",
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
