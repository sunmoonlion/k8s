#!/usr/bin/env python3
"""Build the machine-readable Architecture v2 release manifest from verified inputs."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

APPS = ("info", "knowledge", "investment")
COMPONENTS = ("backend", "admin-frontend", "web-frontend")
EXPECTED_HEADS = {
    "info": "20260811_0006",
    "knowledge": "20260811_0005",
    "investment": "20260811_0005",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip()


def repo_record(path: Path, workspace: Path) -> dict[str, Any]:
    return {
        "path": str(path.relative_to(workspace)),
        "branch": git(path, "branch", "--show-current"),
        "commit": git(path, "rev-parse", "HEAD"),
        "tree": git(path, "rev-parse", "HEAD^{tree}"),
        "tracked_files": int(git(path, "ls-files", "-z").count("\0")),
    }


def tagged_image(image: str) -> dict[str, str]:
    repository, digest = image.split("@sha256:", 1)
    return {
        "repository": repository,
        "tag": f"{repository}:2.0.0",
        "digest": f"sha256:{digest}",
        "immutable": image,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace-root", type=Path, default=Path("/home/zymun"))
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(
            "/home/zymun/k8s/sunmoonai/docs/architecture-v2/evidence/R7-release/release-manifest.json"
        ),
    )
    args = parser.parse_args()
    workspace = args.workspace_root.resolve()
    k8s = workspace / "k8s"
    evidence = k8s / "sunmoonai/docs/architecture-v2/evidence/R7-release"

    gate = load(evidence / "result.json")
    if gate.get("result") != "passed":
        raise SystemExit("R7 release gate has not passed")
    template_gate = load(evidence / "template/result.json")
    if template_gate.get("result") != "passed":
        raise SystemExit("R7 template gate has not passed")
    template_release = load(evidence / "template/release.json")
    template_manifest = load(workspace / "tpl-app/template-release-manifest.json")
    if template_manifest.get("formal_release") is not True:
        raise SystemExit("template release manifest is not formal")

    sources: list[dict[str, Any]] = [repo_record(workspace / "tpl-app", workspace)]
    sources.extend(
        repo_record(workspace / "tpl-app" / f"tpl-{component}", workspace)
        for component in COMPONENTS
    )
    for app in APPS:
        parent = workspace / f"{app}-app"
        sources.append(repo_record(parent, workspace))
        sources.extend(
            repo_record(parent / f"{app}-{component}", workspace)
            for component in COMPONENTS
        )

    images: dict[str, dict[str, str]] = {
        f"tpl-{role}": tagged_image(image)
        for role, image in template_release["images"].items()
    }
    app_releases: dict[str, Any] = {}
    for app in APPS:
        release_path = (
            k8s
            / f"sunmoonai/app-platform/{app}-app/architecture-v2/bundle/release.json"
        )
        release = load(release_path)
        app_releases[app] = {
            "release_id": release["release_id"],
            "release_sha256": sha256(release_path),
            "migration_head": EXPECTED_HEADS[app],
            "images": release["images"],
        }
        for role, image in release["images"].items():
            images[f"{app}-{role}"] = tagged_image(image)

    evidence_records: dict[str, dict[str, str]] = {}
    for path in sorted(evidence.rglob("*")):
        if path.is_file() and path != args.output:
            evidence_records[str(path.relative_to(k8s))] = {"sha256": sha256(path)}

    manifest = {
        "schema_version": 1,
        "architecture": "app-platform-v2",
        "version": "2.0.0",
        "release_date": "2026-08-13",
        "branch": "architecture-v2",
        "status": "FORMAL_RELEASE",
        "source_repositories": sources,
        "deployment_bundle": {
            "repository": "k8s",
            "baseline_commit": "6abcbc9d7a34a64d7cbb0f5e11a5c58e3d08a55e",
            "note": (
                "R6 committed the formal bundles; the R7 tag adds release gates, "
                "role-scoped template policy verification and immutable evidence"
            ),
        },
        "template": {
            "manifest_sha256": sha256(
                workspace / "tpl-app/template-release-manifest.json"
            ),
            "release_id": template_release["release_id"],
            "gate_sha256": sha256(evidence / "template/result.json"),
        },
        "apps": app_releases,
        "images": images,
        "evidence": evidence_records,
        "rollback_protection": {
            "status": "ACTIVE_OBSERVATION_WINDOW",
            "pre_refactor_source_lock": "sunmoonai/docs/architecture-v2/pre-refactor-source-lock.json",
            "pre_refactor_image_lock": "sunmoonai/docs/architecture-v2/pre-refactor-image-lock.json",
            "legacy_deployments_scaled_to_zero": True,
            "legacy_public_ingress_removed": True,
            "legacy_databases_secrets_pvcs_images_retained": True,
            "irreversible_retirement_authorized": False,
        },
        "security": {
            "contains_credentials": False,
            "credentials_printed": False,
            "tokens_printed": False,
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        json.dumps(
            {"result": "passed", "output": str(args.output), "images": len(images)},
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
