#!/usr/bin/env python3
"""Render the complete credential-free Investment Architecture v2 release."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

import yaml

FILES = (
    "00-prerequisites.yaml",
    "10-migration.yaml",
    "20-runtime.yaml",
    "30-network-policies.yaml",
    "40-ingress.yaml",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--release-id", default="r6-investment-formal-002")
    return parser.parse_args()


def load(path: Path) -> list[dict[str, Any]]:
    return [item for item in yaml.safe_load_all(path.read_text(encoding="utf-8")) if item]


def dump(path: Path, items: list[dict[str, Any]]) -> None:
    path.write_text(
        yaml.safe_dump_all(items, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )


def named(items: list[dict[str, Any]], kind: str, name: str) -> dict[str, Any]:
    matches = [
        item
        for item in items
        if item.get("kind") == kind and item.get("metadata", {}).get("name") == name
    ]
    if len(matches) != 1:
        raise RuntimeError(f"expected one {kind}/{name}, found {len(matches)}")
    return matches[0]


def ingress(
    name: str, host: str, routes: list[tuple[str, int | None, str, int]]
) -> dict[str, Any]:
    rendered: list[dict[str, Any]] = []
    for path, priority, service, port in routes:
        route: dict[str, Any] = {
            "kind": "Rule",
            "match": f"Host(`{host}`) && PathPrefix(`{path}`)",
            "services": [{"name": service, "port": port}],
        }
        if priority is not None:
            route["priority"] = priority
        rendered.append(route)
    return {
        "apiVersion": "traefik.io/v1alpha1",
        "kind": "IngressRoute",
        "metadata": {
            "name": name,
            "namespace": "app-platform-dev",
            "labels": {
                "sunmoonai.com/app": "investment-r5",
                "sunmoonai.com/managed-by": "architecture-v2",
            },
        },
        "spec": {
            "entryPoints": ["websecure"],
            "routes": rendered,
            "tls": {"secretName": "investment-r5-tls"},
        },
    }


def main() -> int:
    args = parse_args()
    output = args.output_dir.resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError(f"output directory must be absent or empty: {output}")
    output.mkdir(parents=True, exist_ok=True)

    k8s_root = Path(__file__).resolve().parents[4]
    candidate_renderer = (
        k8s_root
        / "sunmoonai/docs/architecture-v2/scripts/render_r5_investment_candidate.py"
    )
    scaffold = k8s_root.parent / "tpl-app/k8s-scaffold-v2"
    with tempfile.TemporaryDirectory(prefix="r5-investment-formal-") as temporary:
        candidate = Path(temporary) / "candidate"
        subprocess.run(
            [
                sys.executable,
                str(candidate_renderer),
                "--output-dir",
                str(candidate),
                "--scaffold-root",
                str(scaffold),
                "--release-id",
                args.release_id,
                "--admin-origin",
                "https://investment-admin.sunmoonai.com:30443",
                "--web-origin",
                "https://investment.sunmoonai.com:30443",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        for filename in FILES:
            shutil.copy2(candidate / filename, output / filename)

    prerequisites = load(output / "00-prerequisites.yaml")
    backend = named(prerequisites, "ConfigMap", "investment-r5-backend-config")["data"]
    backend.update(
        {
            "DEPLOYMENT_ID": args.release_id,
            "CELERY_QUEUE": "investment.default",
            "ADMIN_CASDOOR_REDIRECT_URI": (
                "https://investment-admin.sunmoonai.com:30443/api/auth/admin/callback"
            ),
            "ADMIN_FRONTEND_BASE_URL": "https://investment-admin.sunmoonai.com:30443",
            "ADMIN_FRONTEND_ALLOWED_ORIGINS": (
                "https://investment-admin.sunmoonai.com:30443"
            ),
            "WEB_CASDOOR_REDIRECT_URI": (
                "https://investment.sunmoonai.com:30443/api/auth/web/callback"
            ),
            "WEB_FRONTEND_BASE_URL": "https://investment.sunmoonai.com:30443",
            "WEB_FRONTEND_ALLOWED_ORIGINS": "https://investment.sunmoonai.com:30443",
            "ALLOWED_HOSTS": (
                "investment-r5-backend,investment-r5-backend.app-platform-dev,"
                "investment-r5-backend.app-platform-dev.svc,"
                "investment-r5-backend.app-platform-dev.svc.cluster.local,"
                "investment-admin.sunmoonai.com,investment.sunmoonai.com,"
                "investment-admin-api.sunmoonai.com,investment-api.sunmoonai.com"
            ),
        }
    )
    named(
        prerequisites, "ConfigMap", "investment-r5-admin-frontend-config"
    )["data"].update(
        {
            "APP_ORIGIN": "https://investment-admin.sunmoonai.com:30443",
            "DEPLOYMENT_ID": f"{args.release_id}-admin",
        }
    )
    named(
        prerequisites, "ConfigMap", "investment-r5-web-frontend-config"
    )["data"].update(
        {
            "APP_ORIGIN": "https://investment.sunmoonai.com:30443",
            "DEPLOYMENT_ID": f"{args.release_id}-web",
        }
    )
    dump(output / "00-prerequisites.yaml", prerequisites)

    images = {
        "backend": (
            "harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:"
            "b50ffde5a79fc4f1f2b78bbe74f7dbbfb02570514096ea67a7b5d5dde6526272"
        ),
        "admin": (
            "harbor.sunmoonai.com:30443/app-images/investment-admin-frontend@sha256:"
            "15d8253d2125045f38ea8bd159df77642250214b3bd72e8733cedbd50464f41d"
        ),
        "web": (
            "harbor.sunmoonai.com:30443/app-images/investment-web-frontend@sha256:"
            "d3ac86bdea887ed3be4ab2b61a8928bdf23086e20137c02e0ec2ca520ae51a0a"
        ),
    }
    migration = load(output / "10-migration.yaml")
    migration_job = named(
        migration,
        "Job",
        f"investment-r5-backend-migration-{args.release_id}",
    )
    migration_job["spec"]["template"]["spec"]["containers"][0]["image"] = images[
        "backend"
    ]
    dump(output / "10-migration.yaml", migration)

    runtime = load(output / "20-runtime.yaml")
    replicas = {
        "investment-r5-backend-api": 2,
        "investment-r5-backend-worker": 1,
        "investment-r5-backend-scheduler": 1,
        "investment-r5-admin-frontend": 2,
        "investment-r5-web-frontend": 2,
    }
    for deployment, count in replicas.items():
        named(runtime, "Deployment", deployment)["spec"]["replicas"] = count
    deployment_images = {
        "investment-r5-backend-api": images["backend"],
        "investment-r5-backend-worker": images["backend"],
        "investment-r5-backend-scheduler": images["backend"],
        "investment-r5-admin-frontend": images["admin"],
        "investment-r5-web-frontend": images["web"],
    }
    config_sources = {
        "investment-r5-backend-api": "investment-r5-backend-config",
        "investment-r5-backend-worker": "investment-r5-backend-config",
        "investment-r5-backend-scheduler": "investment-r5-backend-config",
        "investment-r5-admin-frontend": "investment-r5-admin-frontend-config",
        "investment-r5-web-frontend": "investment-r5-web-frontend-config",
    }
    for deployment, image in deployment_images.items():
        item = named(runtime, "Deployment", deployment)
        item["spec"]["template"]["spec"]["containers"][0]["image"] = image
        config_data = named(
            prerequisites, "ConfigMap", config_sources[deployment]
        ).get("data", {})
        digest = hashlib.sha256(
            json.dumps(config_data, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        item["spec"]["template"].setdefault("metadata", {}).setdefault(
            "annotations", {}
        )["sunmoonai.com/config-sha256"] = digest
    dump(output / "20-runtime.yaml", runtime)

    ingress_routes = [
        ingress(
            "investment-r5-admin-route",
            "investment-admin.sunmoonai.com",
            [
                ("/api", 100, "investment-r5-backend", 8000),
                ("/", 10, "investment-r5-admin-frontend", 3000),
            ],
        ),
        ingress(
            "investment-r5-web-route",
            "investment.sunmoonai.com",
            [
                ("/api", 100, "investment-r5-backend", 8000),
                ("/", 10, "investment-r5-web-frontend", 3000),
            ],
        ),
        ingress(
            "investment-r5-admin-api-route",
            "investment-admin-api.sunmoonai.com",
            [("/", None, "investment-r5-backend", 8000)],
        ),
        ingress(
            "investment-r5-web-api-route",
            "investment-api.sunmoonai.com",
            [("/", None, "investment-r5-backend", 8000)],
        ),
    ]
    dump(output / "40-ingress.yaml", ingress_routes)

    renderer_inputs = {
        "k8s:sunmoonai/docs/architecture-v2/scripts/render_r5_investment_candidate.py": (
            candidate_renderer
        ),
        "tpl-app:k8s-scaffold-v2/scaffold.py": scaffold / "scaffold.py",
    }
    renderer_inputs.update(
        {
            f"tpl-app:k8s-scaffold-v2/templates/{path.name}": path
            for path in sorted((scaffold / "templates").glob("*.tpl"))
        }
    )
    route_contract = {
        item["metadata"]["name"]: [
            {
                "match": route["match"],
                "priority": route.get("priority"),
                "services": route["services"],
            }
            for route in item["spec"]["routes"]
        ]
        for item in ingress_routes
    }
    release = {
        "schema_version": 2,
        "architecture": "app-platform-v2-formal",
        "logical_app": "investment",
        "resource_app": "investment-r5",
        "namespace": "app-platform-dev",
        "release_id": args.release_id,
        "formal_release": True,
        "images": images,
        "origins": {
            "admin": "https://investment-admin.sunmoonai.com:30443",
            "web": "https://investment.sunmoonai.com:30443",
            "casdoor": "https://casdoor.sunmoonai.com:30443",
        },
        "resources": list(FILES),
        "sha256": {
            filename: hashlib.sha256((output / filename).read_bytes()).hexdigest()
            for filename in FILES
        },
        "deployment_replicas": replicas,
        "ingress_routes": route_contract,
        "legacy_deployments": [
            "research-admin-backend",
            "celeryworker-research-admin-backend",
            "research-admin-frontend",
            "research-web-backend",
            "nodebullworker-research-web-backend",
            "research-web-frontend",
        ],
        "external_secrets": [
            "harbor-registry-secret",
            "investment-r5-tls",
            "investment-backend-postgresql-conn",
            "investment-backend-migration-postgresql-conn",
            "investment-r5-browser-identity",
            "investment-backend-redis-conn",
            "investment-backend-broker",
            "investment-knowledge-retrieval-client",
        ],
        "knowledge_binding": "knowledge-active-retrieval-service-binding",
        "forbidden_markers": [
            "investment-admin-r5.sunmoonai.com",
            "investment-web-r5.sunmoonai.com",
            "investment.r5.candidate",
            "research-admin-backend-postgresql-conn",
        ],
        "contains_credentials": False,
        "renderer_inputs_sha256": {
            name: hashlib.sha256(path.read_bytes()).hexdigest()
            for name, path in renderer_inputs.items()
        },
    }
    (output / "release.json").write_text(
        json.dumps(release, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"result": "rendered", **release}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
