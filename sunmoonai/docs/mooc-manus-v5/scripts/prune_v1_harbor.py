#!/usr/bin/env python3
"""Prune V5 image artifacts while protecting release and live K8s digests."""

from __future__ import annotations

import argparse
import importlib.util
import json
import subprocess
import sys
import urllib.parse
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROMOTE_PATH = SCRIPT_DIR / "promote_v1_0_0.py"
CONFIRMATION = "DELETE-UNREFERENCED-V1-ARTIFACTS"


def load_promotion_module():
    spec = importlib.util.spec_from_file_location("v1_promotion", PROMOTE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {PROMOTE_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


PROMOTION = load_promotion_module()
TARGET_REPOSITORIES = set(PROMOTION.IMAGES) | {"tpl-admin-frontend-react"}


def kubernetes_images(kubeconfig: str) -> set[str]:
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
    for item in payload["items"]:
        spec = item.get("spec") or {}
        pod_spec = (spec.get("template") or {}).get("spec") or spec
        for key in ("initContainers", "containers", "ephemeralContainers"):
            for container in pod_spec.get(key) or []:
                image = container.get("image")
                if image:
                    images.add(image)
    return images


def parse_target_image(image: str) -> tuple[str, str] | None:
    prefix = f"{PROMOTION.REGISTRY}/{PROMOTION.PROJECT}/"
    if not image.startswith(prefix):
        return None
    value = image[len(prefix) :]
    if "@" in value:
        repository, reference = value.rsplit("@", 1)
    else:
        repository, separator, reference = value.rpartition(":")
        if not separator:
            reference = "latest"
            repository = value
    if repository not in TARGET_REPOSITORIES:
        return None
    return repository, reference


def list_artifacts(repository: str) -> list[dict]:
    encoded_repository = urllib.parse.quote(repository, safe="")
    artifacts: list[dict] = []
    page = 1
    while True:
        status, body = PROMOTION.harbor(
            "GET",
            f"/api/v2.0/projects/{PROMOTION.PROJECT}/repositories/"
            f"{encoded_repository}/artifacts?page={page}&page_size=100&with_tag=true",
        )
        if status != 200:
            raise RuntimeError(
                f"artifact list failed: repository={repository} status={status}"
            )
        batch = json.loads(body)
        artifacts.extend(batch)
        if len(batch) < 100:
            return artifacts
        page += 1


def live_digests(kubeconfig: str) -> dict[str, set[str]]:
    result = {repository: set() for repository in TARGET_REPOSITORIES}
    for image in sorted(kubernetes_images(kubeconfig)):
        parsed = parse_target_image(image)
        if parsed is None:
            continue
        repository, reference = parsed
        digest = (
            reference
            if reference.startswith("sha256:")
            else PROMOTION.artifact(repository, reference)["digest"]
        )
        result[repository].add(digest)
    return result


def release_digests() -> dict[str, set[str]]:
    result = {
        repository: {digest}
        for repository, digest in PROMOTION.IMAGES.items()
    }
    result["tpl-admin-frontend-react"] = {
        PROMOTION.artifact("tpl-admin-frontend-react", PROMOTION.TAG)["digest"]
    }
    return result


def delete_artifact(repository: str, digest: str) -> None:
    encoded_repository = urllib.parse.quote(repository, safe="")
    encoded_digest = urllib.parse.quote(digest, safe="")
    status, _ = PROMOTION.harbor(
        "DELETE",
        f"/api/v2.0/projects/{PROMOTION.PROJECT}/repositories/"
        f"{encoded_repository}/artifacts/{encoded_digest}",
    )
    if status not in (200, 202):
        raise RuntimeError(
            f"artifact deletion failed: repository={repository} "
            f"digest={digest} status={status}"
        )


def referenced_closure(artifacts: list[dict], roots: set[str]) -> set[str]:
    by_digest = {artifact["digest"]: artifact for artifact in artifacts}
    protected = set(roots)
    pending = list(roots)
    while pending:
        digest = pending.pop()
        artifact = by_digest.get(digest)
        if artifact is None:
            continue
        for reference in artifact.get("references") or []:
            child = reference.get("child_digest")
            if child and child not in protected:
                protected.add(child)
                pending.append(child)
        for accessory in artifact.get("accessories") or []:
            child = accessory.get("digest")
            if child and child not in protected:
                protected.add(child)
                pending.append(child)
    return protected


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--kubeconfig",
        default=str(Path.home() / ".kube" / "kind-config"),
    )
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--confirm")
    args = parser.parse_args()
    if args.execute and args.confirm != CONFIRMATION:
        raise SystemExit(f"--execute requires --confirm {CONFIRMATION}")

    releases = release_digests()
    live = live_digests(args.kubeconfig)
    candidates: list[tuple[str, str, list[str]]] = []
    protected_count = 0

    for repository in sorted(TARGET_REPOSITORIES):
        artifacts = list_artifacts(repository)
        roots = releases[repository] | live[repository]
        protected = referenced_closure(artifacts, roots)
        for artifact in artifacts:
            digest = artifact["digest"]
            tags = sorted(tag["name"] for tag in artifact.get("tags") or [])
            if digest in protected:
                protected_count += 1
                reasons = []
                if digest in releases[repository]:
                    reasons.append("release")
                if digest in live[repository]:
                    reasons.append("live")
                if digest not in roots:
                    reasons.append("referenced-child")
                print(
                    "KEEP"
                    f"\t{repository}\t{digest}\t{','.join(tags) or '-'}"
                    f"\t{'+'.join(reasons)}"
                )
            else:
                candidates.append((repository, digest, tags))
                print(
                    f"DELETE\t{repository}\t{digest}\t{','.join(tags) or '-'}"
                )

    if args.execute:
        for repository, digest, _ in candidates:
            delete_artifact(repository, digest)
            print(f"DELETED\t{repository}\t{digest}")

    print(
        json.dumps(
            {
                "result": "executed" if args.execute else "dry-run",
                "repositories": len(TARGET_REPOSITORIES),
                "protected_artifacts": protected_count,
                "delete_candidates": len(candidates),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
