#!/usr/bin/env python3
"""Render the credential-free Info R5 formal cutover overlay."""

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
    return [item for item in yaml.safe_load_all(path.read_text(encoding="utf-8")) if item]


def resource(items: list[dict[str, Any]], kind: str, name: str) -> dict[str, Any]:
    return next(item for item in items if item.get("kind") == kind and item["metadata"]["name"] == name)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    args = parse_args()
    candidate = args.candidate_bundle.resolve()
    output = args.output.resolve()
    release = json.loads((candidate / "release.json").read_text(encoding="utf-8"))
    if release.get("resource_app") != "info-r5" or release.get("logical_app") != "info":
        raise SystemExit("candidate bundle identity mismatch")
    output.mkdir(parents=True, exist_ok=True)
    prerequisites = load_documents(candidate / "00-prerequisites.yaml")
    names = (
        "info-r5-backend-config",
        "info-r5-admin-frontend-config",
        "info-r5-web-frontend-config",
    )
    config_maps = [resource(prerequisites, "ConfigMap", name) for name in names]
    backend = config_maps[0]["data"]
    backend.update(
        {
            "DEPLOYMENT_ID": "r5-info-formal-001",
            "ADMIN_CASDOOR_REDIRECT_URI": "https://info-admin.sunmoonai.com:30443/api/auth/admin/callback",
            "ADMIN_FRONTEND_BASE_URL": "https://info-admin.sunmoonai.com:30443",
            "ADMIN_FRONTEND_ALLOWED_ORIGINS": "https://info-admin.sunmoonai.com:30443",
            "WEB_CASDOOR_REDIRECT_URI": "https://info.sunmoonai.com:30443/api/auth/web/callback",
            "WEB_FRONTEND_BASE_URL": "https://info.sunmoonai.com:30443",
            "WEB_FRONTEND_ALLOWED_ORIGINS": "https://info.sunmoonai.com:30443",
            "ALLOWED_HOSTS": (
                "info-r5-backend,info-r5-backend.app-platform-dev,"
                "info-r5-backend.app-platform-dev.svc,"
                "info-r5-backend.app-platform-dev.svc.cluster.local,"
                "info-admin.sunmoonai.com,info.sunmoonai.com,"
                "info-admin-api.sunmoonai.com,info-api.sunmoonai.com"
            ),
            "CELERY_QUEUE": "info.admin.default",
        }
    )
    config_maps[1]["data"].update(
        {
            "APP_ORIGIN": "https://info-admin.sunmoonai.com:30443",
            "DEPLOYMENT_ID": "r5-info-formal-001-admin",
        }
    )
    config_maps[2]["data"].update(
        {
            "APP_ORIGIN": "https://info.sunmoonai.com:30443",
            "DEPLOYMENT_ID": "r5-info-formal-001-web",
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
        "task": "R5-I4-info-formal-overlay",
        "result": "rendered",
        "candidate_release_id": release["release_id"],
        "formal_release_id": "r5-info-formal-001",
        "logical_app": "info",
        "resource_app": "info-r5",
        "formal_origins": {
            "admin": "https://info-admin.sunmoonai.com:30443",
            "web": "https://info.sunmoonai.com:30443",
        },
        "formal_queue": "info.admin.default",
        "overlay": overlay.name,
        "overlay_sha256": digest(overlay),
        "contains_credentials": False,
    }
    (output / "formal-release.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
