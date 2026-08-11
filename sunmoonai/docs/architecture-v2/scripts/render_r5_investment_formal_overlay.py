#!/usr/bin/env python3
"""Render the credential-free Investment R5 formal cutover overlay."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
from typing import Any

import yaml


def load(path: Path) -> list[dict[str, Any]]:
    return [item for item in yaml.safe_load_all(path.read_text()) if item]


def one(items: list[dict[str, Any]], kind: str, name: str) -> dict[str, Any]:
    found=[i for i in items if i.get("kind")==kind and i["metadata"]["name"]==name]
    if len(found)!=1: raise SystemExit(f"resource mismatch: {kind}/{name}")
    return found[0]


def main() -> int:
    parser=argparse.ArgumentParser(); parser.add_argument("--candidate-bundle",type=Path,required=True); parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args(); candidate=args.candidate_bundle.resolve(); output=args.output.resolve()
    release=json.loads((candidate/"release.json").read_text())
    if release.get("logical_app")!="investment" or release.get("resource_app")!="investment-r5": raise SystemExit("candidate identity mismatch")
    output.mkdir(parents=True,exist_ok=True)
    prerequisites=load(candidate/"00-prerequisites.yaml")
    backend=one(prerequisites,"ConfigMap","investment-r5-backend-config")["data"]
    admin=one(prerequisites,"ConfigMap","investment-r5-admin-frontend-config")["data"]
    web=one(prerequisites,"ConfigMap","investment-r5-web-frontend-config")["data"]
    backend.update({
        "DEPLOYMENT_ID":"r5-investment-formal-001",
        "ADMIN_CASDOOR_REDIRECT_URI":"https://investment-admin.sunmoonai.com:30443/api/auth/admin/callback",
        "ADMIN_FRONTEND_BASE_URL":"https://investment-admin.sunmoonai.com:30443",
        "ADMIN_FRONTEND_ALLOWED_ORIGINS":"https://investment-admin.sunmoonai.com:30443",
        "WEB_CASDOOR_REDIRECT_URI":"https://investment.sunmoonai.com:30443/api/auth/web/callback",
        "WEB_FRONTEND_BASE_URL":"https://investment.sunmoonai.com:30443",
        "WEB_FRONTEND_ALLOWED_ORIGINS":"https://investment.sunmoonai.com:30443",
        "ALLOWED_HOSTS":"investment-r5-backend,investment-r5-backend.app-platform-dev,investment-r5-backend.app-platform-dev.svc,investment-r5-backend.app-platform-dev.svc.cluster.local,investment-admin.sunmoonai.com,investment.sunmoonai.com,investment-admin-api.sunmoonai.com,investment-api.sunmoonai.com",
        "CELERY_QUEUE":"investment.default",
    })
    admin.update({"APP_ORIGIN":"https://investment-admin.sunmoonai.com:30443","DEPLOYMENT_ID":"r5-investment-formal-001-admin"})
    web.update({"APP_ORIGIN":"https://investment.sunmoonai.com:30443","DEPLOYMENT_ID":"r5-investment-formal-001-web"})
    overlay=output/"50-formal-config.yaml"
    overlay.write_text(yaml.safe_dump_all([one(prerequisites,"ConfigMap",n) for n in ("investment-r5-backend-config","investment-r5-admin-frontend-config","investment-r5-web-frontend-config")],sort_keys=False,allow_unicode=True))
    shutil.copy2(candidate/"release.json",output/"candidate-release.json")
    manifest={
        "schema_version":1,"task":"R5-V4-investment-formal-overlay","result":"rendered",
        "candidate_release_id":release["release_id"],"formal_release_id":"r5-investment-formal-001",
        "logical_app":"investment","resource_app":"investment-r5",
        "formal_origins":{"admin":"https://investment-admin.sunmoonai.com:30443","web":"https://investment.sunmoonai.com:30443"},
        "formal_queue":"investment.default","overlay":overlay.name,
        "overlay_sha256":hashlib.sha256(overlay.read_bytes()).hexdigest(),"contains_credentials":False,
    }
    (output/"formal-release.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(manifest,ensure_ascii=False,indent=2)); return 0


if __name__=="__main__": raise SystemExit(main())
