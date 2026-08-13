#!/usr/bin/env python3
"""Validate one committed Architecture v2 formal instance bundle.

This is the shared completion gate for Info, Knowledge and Investment.  An R5
instance is not complete merely because a live cluster was patched: the Git
bundle must be self-contained, immutable, formal, and describe the complete
steady-state runtime and ingress contract.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

import yaml

IMMUTABLE_IMAGE = re.compile(r"^[^\s]+@sha256:[0-9a-f]{64}$")


class GateError(RuntimeError):
    pass


def documents(path: Path) -> list[dict[str, Any]]:
    return [item for item in yaml.safe_load_all(path.read_text(encoding="utf-8")) if item]


def resource(
    resources: dict[tuple[str, str], dict[str, Any]], kind: str, name: str
) -> dict[str, Any]:
    try:
        return resources[(kind, name)]
    except KeyError as exc:
        raise GateError(f"missing {kind}/{name}") from exc


def load(bundle: Path) -> tuple[dict[str, Any], dict[tuple[str, str], dict[str, Any]]]:
    release_path = bundle / "release.json"
    if not release_path.is_file():
        raise GateError("missing release.json")
    release = json.loads(release_path.read_text(encoding="utf-8"))
    if release.get("schema_version") != 2:
        raise GateError("unsupported formal release schema")
    if release.get("architecture") != "app-platform-v2-formal":
        raise GateError("bundle is not an Architecture v2 formal release")
    if release.get("formal_release") is not True:
        raise GateError("formal_release must be true")
    renderer_inputs = release.get("renderer_inputs_sha256")
    if not isinstance(renderer_inputs, dict) or not renderer_inputs:
        raise GateError("renderer input provenance is missing")
    if any(not re.fullmatch(r"[0-9a-f]{64}", str(value)) for value in renderer_inputs.values()):
        raise GateError("renderer input provenance contains an invalid SHA-256")

    hashes = release.get("sha256")
    filenames = release.get("resources")
    if not isinstance(hashes, dict) or not isinstance(filenames, list):
        raise GateError("release resources/hashes are missing")
    if set(hashes) != set(filenames):
        raise GateError("release resources and hashes do not have identical keys")

    indexed: dict[tuple[str, str], dict[str, Any]] = {}
    for filename in filenames:
        path = bundle / filename
        if not path.is_file():
            raise GateError(f"missing resource file: {filename}")
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != hashes[filename]:
            raise GateError(f"resource hash mismatch: {filename}")
        for item in documents(path):
            metadata = item.get("metadata", {})
            key = (str(item.get("kind", "")), str(metadata.get("name", "")))
            if not all(key) or key in indexed:
                raise GateError(f"invalid or duplicate resource identity: {key}")
            indexed[key] = item
            labels = metadata.get("labels", {})
            if labels.get("sunmoonai.com/managed-by") != "app-platform-v2":
                raise GateError(f"resource is outside Architecture v2 ownership: {key}")
    return release, indexed


def verify(bundle: Path) -> dict[str, Any]:
    release, resources = load(bundle)
    desired = release.get("deployment_replicas")
    images = release.get("images")
    if not isinstance(desired, dict) or not isinstance(images, dict):
        raise GateError("deployment_replicas/images contract is missing")
    for name, replicas in desired.items():
        deployment = resource(resources, "Deployment", name)
        if deployment.get("spec", {}).get("replicas") != replicas:
            raise GateError(f"replica contract mismatch: {name}")
        containers = deployment["spec"]["template"]["spec"]["containers"]
        for container in containers:
            image = container.get("image")
            if not IMMUTABLE_IMAGE.fullmatch(str(image)):
                raise GateError(f"mutable image in Deployment/{name}")
            if image not in images.values():
                raise GateError(f"unlocked image in Deployment/{name}")

    expected_routes = release.get("ingress_routes")
    if not isinstance(expected_routes, dict):
        raise GateError("ingress_routes contract is missing")
    for name, expected in expected_routes.items():
        ingress = resource(resources, "IngressRoute", name)
        actual = [
            {
                "match": route.get("match"),
                "priority": route.get("priority"),
                "services": route.get("services"),
            }
            for route in ingress.get("spec", {}).get("routes", [])
        ]
        if actual != expected:
            raise GateError(f"ingress route contract mismatch: {name}")
        if not ingress.get("spec", {}).get("tls", {}).get("secretName"):
            raise GateError(f"strict TLS Secret is missing: {name}")

    legacy = set(release.get("legacy_deployments", []))
    active = {name for kind, name in resources if kind == "Deployment"}
    overlap = sorted(legacy & active)
    if overlap:
        raise GateError(f"legacy deployments leaked into formal bundle: {overlap}")

    text = "\n".join(
        (bundle / name).read_text(encoding="utf-8") for name in release["resources"]
    )
    for marker in release.get("forbidden_markers", []):
        if marker in text:
            raise GateError(f"forbidden candidate/legacy marker found: {marker}")

    return {
        "task": "app-platform-v2-declarative-instance-gate",
        "result": "passed",
        "logical_app": release["logical_app"],
        "resource_app": release["resource_app"],
        "release_id": release["release_id"],
        "deployments": desired,
        "ingress_routes": sorted(expected_routes),
        "legacy_deployments_in_bundle": [],
        "credentials_in_release": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True, type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.bundle.resolve()), ensure_ascii=False, indent=2))
        return 0
    except (GateError, OSError, ValueError, yaml.YAMLError) as exc:
        print(json.dumps({"result": "failed", "error": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
