#!/usr/bin/env python3
"""Render the credential-free Knowledge R5 formal cutover overlay."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
from typing import Any

import yaml


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-bundle", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def load_documents(path: Path) -> list[dict[str, Any]]:
    return [
        item
        for item in yaml.safe_load_all(path.read_text(encoding="utf-8"))
        if item
    ]


def resource(
    items: list[dict[str, Any]], kind: str, name: str
) -> dict[str, Any]:
    matches = [
        item
        for item in items
        if item.get("kind") == kind and item["metadata"]["name"] == name
    ]
    if len(matches) != 1:
        raise SystemExit(f"resource mismatch: {kind}/{name}")
    return matches[0]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    args = parse_args()
    candidate = args.candidate_bundle.resolve()
    output = args.output.resolve()
    release = json.loads((candidate / "release.json").read_text(encoding="utf-8"))
    if (
        release.get("resource_app") != "knowledge-r5"
        or release.get("logical_app") != "knowledge"
    ):
        raise SystemExit("candidate bundle identity mismatch")
    output.mkdir(parents=True, exist_ok=True)
    prerequisites = load_documents(candidate / "00-prerequisites.yaml")
    names = (
        "knowledge-r5-backend-config",
        "knowledge-r5-admin-frontend-config",
        "knowledge-r5-web-frontend-config",
    )
    config_maps = [
        resource(prerequisites, "ConfigMap", name) for name in names
    ]
    backend = config_maps[0]["data"]
    backend.update(
        {
            "DEPLOYMENT_ID": "r5-knowledge-formal-001",
            "ADMIN_CASDOOR_REDIRECT_URI": "https://knowledge-admin.sunmoonai.com:30443/api/auth/admin/callback",
            "ADMIN_FRONTEND_BASE_URL": "https://knowledge-admin.sunmoonai.com:30443",
            "ADMIN_FRONTEND_ALLOWED_ORIGINS": "https://knowledge-admin.sunmoonai.com:30443",
            "WEB_CASDOOR_REDIRECT_URI": "https://knowledge.sunmoonai.com:30443/api/auth/web/callback",
            "WEB_FRONTEND_BASE_URL": "https://knowledge.sunmoonai.com:30443",
            "WEB_FRONTEND_ALLOWED_ORIGINS": "https://knowledge.sunmoonai.com:30443",
            "ALLOWED_HOSTS": (
                "knowledge-r5-backend,knowledge-r5-backend.app-platform-dev,"
                "knowledge-r5-backend.app-platform-dev.svc,"
                "knowledge-r5-backend.app-platform-dev.svc.cluster.local,"
                "knowledge-admin.sunmoonai.com,knowledge.sunmoonai.com,"
                "knowledge-admin-api.sunmoonai.com"
            ),
            "CELERY_QUEUE": "knowledge.admin.default",
        }
    )
    config_maps[1]["data"].update(
        {
            "APP_ORIGIN": "https://knowledge-admin.sunmoonai.com:30443",
            "DEPLOYMENT_ID": "r5-knowledge-formal-001-admin",
        }
    )
    config_maps[2]["data"].update(
        {
            "APP_ORIGIN": "https://knowledge.sunmoonai.com:30443",
            "DEPLOYMENT_ID": "r5-knowledge-formal-001-web",
        }
    )
    overlay = output / "50-formal-config.yaml"
    overlay.write_text(
        yaml.safe_dump_all(config_maps, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )
    shutil.copy2(candidate / "release.json", output / "candidate-release.json")
    manifest = {
        "schema_version": 1,
        "task": "R5-K4-knowledge-formal-overlay",
        "result": "rendered",
        "candidate_release_id": release["release_id"],
        "formal_release_id": "r5-knowledge-formal-001",
        "logical_app": "knowledge",
        "resource_app": "knowledge-r5",
        "formal_origins": {
            "admin": "https://knowledge-admin.sunmoonai.com:30443",
            "web": "https://knowledge.sunmoonai.com:30443",
        },
        "formal_queue": "knowledge.admin.default",
        "retrieval_dataset_allowlist": release["retrieval_dataset_allowlist"],
        "overlay": overlay.name,
        "overlay_sha256": digest(overlay),
        "contains_credentials": False,
    }
    (output / "formal-release.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
