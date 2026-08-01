#!/usr/bin/env python3
"""Verify the Architecture v2 pre-refactor Harbor image lock.

This command is read-only. It verifies that every locked digest exists, that
the historical 1.0.0 tags still point to the accepted release digests, and
that target repositories referenced by live KIND workload specs are covered
by the lock.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROMOTE_PATH = SCRIPT_DIR / "promote_v1_0_0.py"
LOCK_PATH = (
    SCRIPT_DIR.parents[1]
    / "architecture-v2"
    / "pre-refactor-image-lock.json"
)


def load_promotion_module():
    spec = importlib.util.spec_from_file_location("v1_promotion", PROMOTE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {PROMOTE_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


PROMOTION = load_promotion_module()


def load_lock() -> dict:
    if not LOCK_PATH.exists():
        raise RuntimeError(f"image lock missing: {LOCK_PATH}")
    payload = json.loads(LOCK_PATH.read_text())
    if payload.get("schema_version") != 1:
        raise RuntimeError("unsupported image lock schema")
    return payload


def workload_images(kubeconfig: str) -> set[str]:
    command = [
        "kubectl",
        "--kubeconfig",
        kubeconfig,
        "get",
        "deployment,statefulset,daemonset,cronjob,job,pod",
        "--all-namespaces",
        "-o",
        "json",
    ]
    payload = json.loads(subprocess.check_output(command))
    images: set[str] = set()
    for item in payload.get("items") or []:
        spec = item.get("spec") or {}
        candidates = [spec]
        template = spec.get("template") or {}
        if template:
            candidates.append(template.get("spec") or {})
        job_template = spec.get("jobTemplate") or {}
        job_pod = ((job_template.get("spec") or {}).get("template") or {}).get(
            "spec"
        ) or {}
        if job_pod:
            candidates.append(job_pod)
        for pod_spec in candidates:
            for key in ("initContainers", "containers", "ephemeralContainers"):
                for container in pod_spec.get(key) or []:
                    image = container.get("image")
                    if image:
                        images.add(image)
    return images


def parse_target_image(image: str, target_repositories: set[str]):
    prefix = f"{PROMOTION.REGISTRY}/{PROMOTION.PROJECT}/"
    if not image.startswith(prefix):
        return None
    value = image[len(prefix) :]
    if "@" in value:
        repository, reference = value.rsplit("@", 1)
    else:
        repository, separator, reference = value.rpartition(":")
        if not separator:
            repository, reference = value, "latest"
    if repository not in target_repositories:
        return None
    return repository, reference


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--kubeconfig",
        default=str(Path.home() / ".kube" / "kind-config"),
    )
    args = parser.parse_args()

    payload = load_lock()
    locked_pairs: set[tuple[str, str]] = set()
    target_repositories: set[str] = set()
    for item in payload.get("artifacts") or []:
        repository = item["repository"]
        digest = item["digest"]
        pair = (repository, digest)
        if pair in locked_pairs:
            raise RuntimeError(
                f"duplicate locked artifact: repository={repository} digest={digest}"
            )
        locked_pairs.add(pair)
        target_repositories.add(repository)
        artifact = PROMOTION.artifact(repository, digest)
        if artifact.get("digest") != digest:
            raise RuntimeError(
                f"locked digest mismatch: repository={repository} digest={digest}"
            )

    release_pairs = set(PROMOTION.IMAGES.items())
    react_release = PROMOTION.artifact(
        "tpl-admin-frontend-react", PROMOTION.TAG
    )["digest"]
    release_pairs.add(("tpl-admin-frontend-react", react_release))
    missing_release_locks = release_pairs - locked_pairs
    if missing_release_locks:
        raise RuntimeError(
            f"release digests missing from lock: {sorted(missing_release_locks)}"
        )
    for repository, digest in sorted(release_pairs):
        current = PROMOTION.artifact(repository, PROMOTION.TAG)
        if current.get("digest") != digest:
            raise RuntimeError(
                f"release tag moved: repository={repository} "
                f"expected={digest} actual={current.get('digest')}"
            )

    live_pairs: set[tuple[str, str]] = set()
    for image in workload_images(args.kubeconfig):
        parsed = parse_target_image(image, target_repositories)
        if parsed is None:
            continue
        repository, reference = parsed
        digest = (
            reference
            if reference.startswith("sha256:")
            else PROMOTION.artifact(repository, reference)["digest"]
        )
        live_pairs.add((repository, digest))
    missing_live_locks = live_pairs - locked_pairs
    if missing_live_locks:
        raise RuntimeError(
            f"live workload digests missing from lock: {sorted(missing_live_locks)}"
        )

    print(
        json.dumps(
            {
                "result": "passed",
                "locked_artifacts": len(locked_pairs),
                "release_artifacts": len(release_pairs),
                "live_artifacts": len(live_pairs),
                "credentials_printed": False,
                "mutation_performed": False,
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
