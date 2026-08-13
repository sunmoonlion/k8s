#!/usr/bin/env python3
"""Render the complete, credential-free Info Architecture v2 formal bundle."""

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
    parser.add_argument("--release-id", default="r6-info-formal-004")
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
    rendered_routes: list[dict[str, Any]] = []
    for path, priority, service, port in routes:
        route: dict[str, Any] = {
            "kind": "Rule",
            "match": f"Host(`{host}`) && PathPrefix(`{path}`)",
            "services": [{"name": service, "port": port}],
        }
        if priority is not None:
            route["priority"] = priority
        rendered_routes.append(route)
    return {
        "apiVersion": "traefik.io/v1alpha1",
        "kind": "IngressRoute",
        "metadata": {
            "name": name,
            "namespace": "app-platform-dev",
            "labels": {
                "sunmoonai.com/app": "info-r5",
                "sunmoonai.com/managed-by": "app-platform-v2",
            },
        },
        "spec": {
            "entryPoints": ["websecure"],
            "routes": rendered_routes,
            "tls": {"secretName": "info-r5-tls"},
        },
    }


def replace_resource_names(value: Any, mapping: dict[str, str]) -> None:
    """Replace exact Kubernetes resource-name values in a rendered object."""
    if isinstance(value, dict):
        for key, item in value.items():
            if isinstance(item, str) and item in mapping:
                value[key] = mapping[item]
            else:
                replace_resource_names(item, mapping)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            if isinstance(item, str) and item in mapping:
                value[index] = mapping[item]
            else:
                replace_resource_names(item, mapping)


def main() -> int:
    args = parse_args()
    output = args.output_dir.resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError(f"output directory must be absent or empty: {output}")
    output.mkdir(parents=True, exist_ok=True)
    k8s_root = Path(__file__).resolve().parents[4]
    candidate_renderer = (
        k8s_root
        / "sunmoonai/app-platform/scripts/render_info_release_base.py"
    )
    scaffold = k8s_root.parent / "tpl-app/k8s-deployment"

    with tempfile.TemporaryDirectory(prefix="r5-info-formal-") as temporary:
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
                "https://info-admin.sunmoonai.com:30443",
                "--web-origin",
                "https://info.sunmoonai.com:30443",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        for filename in FILES:
            shutil.copy2(candidate / filename, output / filename)

    prerequisites = load(output / "00-prerequisites.yaml")
    backend = named(prerequisites, "ConfigMap", "info-r5-backend-config")["data"]
    backend.update(
        {
            "DEPLOYMENT_ID": args.release_id,
            "CELERY_QUEUE": "info.admin.default",
            "KNOWLEDGE_APP_INGEST_URL": (
                "http://knowledge-r5-backend:8000/"
                "api/internal/v1/knowledge/ingestions"
            ),
            "ALLOWED_HOSTS": (
                "info-r5-backend,info-r5-backend.app-platform-dev,"
                "info-r5-backend.app-platform-dev.svc,"
                "info-r5-backend.app-platform-dev.svc.cluster.local,"
                "info-admin.sunmoonai.com,info.sunmoonai.com,"
                "info-admin-api.sunmoonai.com,info-api.sunmoonai.com"
            ),
        }
    )
    dump(output / "00-prerequisites.yaml", prerequisites)

    images = {
        "backend": (
            "harbor.sunmoonai.com:30443/app-images/info-backend@sha256:"
            "ad279489e13b5efb43f98949000760353e77ff0ccc9d58fc32878ce28b9dd247"
        ),
        "admin": (
            "harbor.sunmoonai.com:30443/app-images/info-admin-frontend@sha256:"
            "defacc2f58584541561ada6ce13918efe4be41e9dd7ef21decd30299cd2f149d"
        ),
        "web": (
            "harbor.sunmoonai.com:30443/app-images/info-web-frontend@sha256:"
            "60f3f70a67630997cc3d0fe9884c166fd5023dac9eed81a3a03b22c5e5c66c52"
        ),
    }
    migration = load(output / "10-migration.yaml")
    migration_job = named(
        migration,
        "Job",
        f"info-r5-backend-migration-{args.release_id}",
    )
    migration_job["spec"]["template"]["spec"]["containers"][0]["image"] = images[
        "backend"
    ]
    dump(output / "10-migration.yaml", migration)
    runtime = load(output / "20-runtime.yaml")
    replace_resource_names(
        runtime,
        {
            "info-admin-backend-redis-conn": "info-backend-redis-conn",
            "celeryworker-info-admin-backend-secret": "info-backend-broker",
            "info-admin-backend-s3": "info-backend-s3",
            "info-admin-backend-elasticsearch": "info-backend-elasticsearch",
        },
    )
    replicas = {
        "info-r5-backend-api": 2,
        "info-r5-backend-worker": 1,
        "info-r5-backend-scheduler": 1,
        "info-r5-admin-frontend": 2,
        "info-r5-web-frontend": 2,
    }
    for deployment, count in replicas.items():
        named(runtime, "Deployment", deployment)["spec"]["replicas"] = count
    deployment_images = {
        "info-r5-backend-api": images["backend"],
        "info-r5-backend-worker": images["backend"],
        "info-r5-backend-scheduler": images["backend"],
        "info-r5-admin-frontend": images["admin"],
        "info-r5-web-frontend": images["web"],
    }
    for deployment, image in deployment_images.items():
        named(runtime, "Deployment", deployment)["spec"]["template"]["spec"][
            "containers"
        ][0]["image"] = image
    config_sources = {
        "info-r5-backend-api": "info-r5-backend-config",
        "info-r5-backend-worker": "info-r5-backend-config",
        "info-r5-backend-scheduler": "info-r5-backend-config",
        "info-r5-admin-frontend": "info-r5-admin-frontend-config",
        "info-r5-web-frontend": "info-r5-web-frontend-config",
    }
    for deployment, config_name in config_sources.items():
        config_data = named(prerequisites, "ConfigMap", config_name).get("data", {})
        config_digest = hashlib.sha256(
            json.dumps(
                config_data, sort_keys=True, separators=(",", ":")
            ).encode()
        ).hexdigest()
        template_metadata = named(runtime, "Deployment", deployment)["spec"][
            "template"
        ].setdefault("metadata", {})
        template_metadata.setdefault("annotations", {})[
            "sunmoonai.com/config-sha256"
        ] = config_digest
    dump(output / "20-runtime.yaml", runtime)

    ingress_routes = [
        ingress(
            "info-r5-admin-route",
            "info-admin.sunmoonai.com",
            [
                ("/api", 100, "info-r5-backend", 8000),
                ("/", 10, "info-r5-admin-frontend", 3000),
            ],
        ),
        ingress(
            "info-r5-web-route",
            "info.sunmoonai.com",
            [
                ("/api", 100, "info-r5-backend", 8000),
                ("/", 10, "info-r5-web-frontend", 3000),
            ],
        ),
        ingress(
            "info-r5-admin-api-route",
            "info-admin-api.sunmoonai.com",
            [("/", None, "info-r5-backend", 8000)],
        ),
        ingress(
            "info-r5-web-api-route",
            "info-api.sunmoonai.com",
            [("/", None, "info-r5-backend", 8000)],
        ),
    ]
    dump(output / "40-ingress.yaml", ingress_routes)

    renderer_inputs = {
        "k8s:sunmoonai/app-platform/scripts/render_info_release_base.py": (
            candidate_renderer
        ),
        "tpl-app:k8s-deployment/scaffold.py": scaffold / "scaffold.py",
    }
    renderer_inputs.update(
        {
            f"tpl-app:k8s-deployment/templates/{path.name}": path
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
        "logical_app": "info",
        "resource_app": "info-r5",
        "namespace": "app-platform-dev",
        "release_id": args.release_id,
        "formal_release": True,
        "images": images,
        "origins": {
            "admin": "https://info-admin.sunmoonai.com:30443",
            "web": "https://info.sunmoonai.com:30443",
            "casdoor": "https://casdoor.sunmoonai.com:30443",
        },
        "resources": list(FILES),
        "sha256": {
            filename: hashlib.sha256((output / filename).read_bytes()).hexdigest()
            for filename in FILES
        },
        "deployment_replicas": replicas,
        "ingress_routes": route_contract,
        "legacy_deployments": [],
        "external_secrets": [
            "harbor-registry-secret",
            "info-r5-tls",
            "info-backend-postgresql-conn",
            "info-backend-migration-postgresql-conn",
            "info-r5-browser-identity",
            "info-backend-redis-conn",
            "info-backend-broker",
            "info-backend-s3",
            "info-backend-elasticsearch",
            "info-knowledge-ingest-client",
        ],
        "forbidden_markers": [
            "info-admin-r5.sunmoonai.com",
            "info-web-r5.sunmoonai.com",
            "info.r5.candidate",
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
