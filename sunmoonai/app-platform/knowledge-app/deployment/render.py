#!/usr/bin/env python3
"""Render the complete credential-free Knowledge Architecture v2 release."""

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
    parser.add_argument("--release-id", default="v20-knowledge-stable-001")
    parser.add_argument("--retrieval-dataset-allowlist", default="codex-smoke")
    return parser.parse_args()


def load(path: Path) -> list[dict[str, Any]]:
    return [item for item in yaml.safe_load_all(path.read_text(encoding="utf-8")) if item]


def dump(path: Path, items: list[dict[str, Any]]) -> None:
    path.write_text(yaml.safe_dump_all(items, sort_keys=False, allow_unicode=True), encoding="utf-8")


def named(items: list[dict[str, Any]], kind: str, name: str) -> dict[str, Any]:
    matches = [
        item for item in items
        if item.get("kind") == kind and item.get("metadata", {}).get("name") == name
    ]
    if len(matches) != 1:
        raise RuntimeError(f"expected one {kind}/{name}, found {len(matches)}")
    return matches[0]


def ingress(name: str, host: str, routes: list[tuple[str, int | None, str, int]]) -> dict[str, Any]:
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
                "sunmoonai.com/app": "knowledge-r5",
                "sunmoonai.com/managed-by": "app-platform-v2",
            },
        },
        "spec": {
            "entryPoints": ["websecure"],
            "routes": rendered,
            "tls": {"secretName": "knowledge-r5-tls"},
        },
    }


def replace_legacy_config_refs(runtime: list[dict[str, Any]]) -> None:
    for item in runtime:
        if item.get("kind") != "Deployment":
            continue
        for container in item["spec"]["template"]["spec"].get("containers", []):
            for env in container.get("env", []):
                ref = env.get("valueFrom", {}).get("configMapKeyRef")
                if ref and ref.get("name") in {
                    "knowledge-admin-backend-config",
                    "knowledge-admin-backend-s3",
                }:
                    ref["name"] = "knowledge-r5-backend-config"


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


def replace_resource_prefixes(value: Any, mapping: dict[str, str]) -> Any:
    """Replace rollout-only prefixes while preserving the rendered structure."""
    if isinstance(value, dict):
        for key, item in list(value.items()):
            target_key = replace_resource_prefixes(key, mapping)
            rendered_item = replace_resource_prefixes(item, mapping)
            if target_key != key:
                del value[key]
            value[target_key] = rendered_item
        return value
    if isinstance(value, list):
        for index, item in enumerate(value):
            value[index] = replace_resource_prefixes(item, mapping)
        return value
    if isinstance(value, str):
        for source, target in mapping.items():
            value = value.replace(source, target)
    return value


def main() -> int:
    args = parse_args()
    if not args.retrieval_dataset_allowlist.strip() or "*" in args.retrieval_dataset_allowlist:
        raise RuntimeError("retrieval dataset allowlist must be explicit and governed")
    output = args.output_dir.resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError(f"output directory must be absent or empty: {output}")
    output.mkdir(parents=True, exist_ok=True)
    k8s_root = Path(__file__).resolve().parents[4]
    candidate_renderer = k8s_root / "sunmoonai/app-platform/scripts/render_knowledge_release_base.py"
    scaffold = k8s_root.parent / "tpl-app/k8s-deployment"

    with tempfile.TemporaryDirectory(prefix="r5-knowledge-formal-") as temporary:
        candidate = Path(temporary) / "candidate"
        subprocess.run(
            [
                sys.executable,
                str(candidate_renderer),
                "--output-dir", str(candidate),
                "--scaffold-root", str(scaffold),
                "--release-id", args.release_id,
                "--admin-origin", "https://knowledge-admin.sunmoonai.com:30443",
                "--web-origin", "https://knowledge.sunmoonai.com:30443",
                "--retrieval-dataset-allowlist", args.retrieval_dataset_allowlist,
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        for filename in FILES:
            shutil.copy2(candidate / filename, output / filename)

    prerequisites = load(output / "00-prerequisites.yaml")
    backend = named(prerequisites, "ConfigMap", "knowledge-r5-backend-config")["data"]
    backend.update({
        "DEPLOYMENT_ID": args.release_id,
        "CELERY_QUEUE": "knowledge.admin.default",
        "ALLOWED_HOSTS": (
            "knowledge-r5-backend,knowledge-r5-backend.app-platform-dev,"
            "knowledge-r5-backend.app-platform-dev.svc,"
            "knowledge-r5-backend.app-platform-dev.svc.cluster.local,"
            "knowledge-admin.sunmoonai.com,knowledge.sunmoonai.com,"
            "knowledge-admin-api.sunmoonai.com"
        ),
        "RAGFLOW_API_BASE": "http://ragflow-sunmoonai-api:80",
        "RAGFLOW_PARSE_POLL_INTERVAL_SECONDS": "1.0",
        "RAGFLOW_PARSE_TIMEOUT_SECONDS": "120",
        "RETRIEVAL_DEFAULT_TENANT_ID": "sunmoonai",
        "RETRIEVAL_PROVIDER_TIMEOUT_SECONDS": "15",
        "ARTIFACT_ALLOWED_CONTENT_TYPES": "text/markdown,text/plain",
        "ARTIFACT_MAX_SIZE_BYTES": "52428800",
        "ARTIFACT_S3_ALLOWED_BUCKETS": "development-info-originals",
        "ARTIFACT_S3_ALLOWED_PREFIXES": "info/original/",
        "S3_ENDPOINT": "http://minio.data-platform-dev.svc.cluster.local",
        "S3_FORCE_PATH_STYLE": "true",
        "S3_REGION": "us-east-1",
    })
    dump(output / "00-prerequisites.yaml", prerequisites)

    images = {
        "backend": "harbor.sunmoonai.com:30443/app-images/knowledge-backend@sha256:38ef7c29a43e4a47a339ba06c6dd77bd0a31277035d1df31b0fc2ca69cd862c0",
        "admin": "harbor.sunmoonai.com:30443/app-images/knowledge-admin-frontend@sha256:07130d859a89b18842ce043178b5477bbb67a3ab183aadfe18baed039bd0b9c2",
        "web": "harbor.sunmoonai.com:30443/app-images/knowledge-web-frontend@sha256:7bdd329bf24e479d1c8f859ef6ed909958bc1479b7296b3b212c2293c7601148",
    }
    migration = load(output / "10-migration.yaml")
    migration_job = named(
        migration,
        "Job",
        f"knowledge-r5-backend-migration-{args.release_id}",
    )
    migration_job["spec"]["template"]["spec"]["containers"][0]["image"] = images[
        "backend"
    ]
    dump(output / "10-migration.yaml", migration)

    runtime = load(output / "20-runtime.yaml")
    replicas = {
        "knowledge-r5-backend-api": 2,
        "knowledge-r5-backend-worker": 1,
        "knowledge-r5-backend-scheduler": 1,
        "knowledge-r5-admin-frontend": 2,
        "knowledge-r5-web-frontend": 2,
    }
    for deployment, count in replicas.items():
        named(runtime, "Deployment", deployment)["spec"]["replicas"] = count
    deployment_images = {
        "knowledge-r5-backend-api": images["backend"],
        "knowledge-r5-backend-worker": images["backend"],
        "knowledge-r5-backend-scheduler": images["backend"],
        "knowledge-r5-admin-frontend": images["admin"],
        "knowledge-r5-web-frontend": images["web"],
    }
    config_sources = {
        "knowledge-r5-backend-api": "knowledge-r5-backend-config",
        "knowledge-r5-backend-worker": "knowledge-r5-backend-config",
        "knowledge-r5-backend-scheduler": "knowledge-r5-backend-config",
        "knowledge-r5-admin-frontend": "knowledge-r5-admin-frontend-config",
        "knowledge-r5-web-frontend": "knowledge-r5-web-frontend-config",
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
    replace_legacy_config_refs(runtime)
    replace_resource_names(
        runtime,
        {
            "knowledge-admin-backend-redis-conn": "knowledge-backend-redis-conn",
            "celeryworker-knowledge-admin-backend-secret": "knowledge-backend-broker",
            "knowledge-admin-backend-secret": "knowledge-ragflow-provider",
            "knowledge-admin-backend-s3": "knowledge-backend-s3",
        },
    )
    dump(output / "20-runtime.yaml", runtime)

    ingress_routes = [
        ingress("knowledge-r5-admin-route", "knowledge-admin.sunmoonai.com", [
            ("/api", 100, "knowledge-r5-backend", 8000),
            ("/", 10, "knowledge-r5-admin-frontend", 3000),
        ]),
        ingress("knowledge-r5-web-route", "knowledge.sunmoonai.com", [
            ("/api", 100, "knowledge-r5-backend", 8000),
            ("/", 10, "knowledge-r5-web-frontend", 3000),
        ]),
        ingress("knowledge-r5-admin-api-route", "knowledge-admin-api.sunmoonai.com", [
            ("/", None, "knowledge-r5-backend", 8000),
        ]),
    ]
    dump(output / "40-ingress.yaml", ingress_routes)

    renderer_inputs = {
        "k8s:sunmoonai/app-platform/scripts/render_knowledge_release_base.py": candidate_renderer,
        "tpl-app:k8s-deployment/scaffold.py": scaffold / "scaffold.py",
    }
    renderer_inputs.update({
        f"tpl-app:k8s-deployment/templates/{path.name}": path
        for path in sorted((scaffold / "templates").glob("*.tpl"))
    })
    stable_prefixes = {"knowledge-r5": "knowledge"}
    for filename in FILES:
        documents = load(output / filename)
        replace_resource_prefixes(documents, stable_prefixes)
        dump(output / filename, documents)
    replace_resource_prefixes(ingress_routes, stable_prefixes)
    replicas = {
        replace_resource_prefixes(name, stable_prefixes): count
        for name, count in replicas.items()
    }

    prerequisites = load(output / "00-prerequisites.yaml")
    runtime = load(output / "20-runtime.yaml")
    stable_config_sources = {
        "knowledge-backend-api": "knowledge-backend-config",
        "knowledge-backend-worker": "knowledge-backend-config",
        "knowledge-backend-scheduler": "knowledge-backend-config",
        "knowledge-admin-frontend": "knowledge-admin-frontend-config",
        "knowledge-web-frontend": "knowledge-web-frontend-config",
    }
    for deployment, config_name in stable_config_sources.items():
        config_data = named(prerequisites, "ConfigMap", config_name).get("data", {})
        digest = hashlib.sha256(
            json.dumps(config_data, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        item = named(runtime, "Deployment", deployment)
        item["spec"]["template"].setdefault("metadata", {}).setdefault(
            "annotations", {}
        )["sunmoonai.com/config-sha256"] = digest
    dump(output / "20-runtime.yaml", runtime)
    release = {
        "schema_version": 2,
        "architecture": "app-platform-v2-formal",
        "logical_app": "knowledge",
        "resource_app": "knowledge",
        "namespace": "app-platform-dev",
        "release_id": args.release_id,
        "formal_release": True,
        "images": images,
        "origins": {
            "admin": "https://knowledge-admin.sunmoonai.com:30443",
            "web": "https://knowledge.sunmoonai.com:30443",
            "casdoor": "https://casdoor.sunmoonai.com:30443",
        },
        "retrieval_dataset_allowlist": args.retrieval_dataset_allowlist,
        "resources": list(FILES),
        "sha256": {filename: hashlib.sha256((output / filename).read_bytes()).hexdigest() for filename in FILES},
        "deployment_replicas": replicas,
        "ingress_routes": {
            item["metadata"]["name"]: [
                {"match": route["match"], "priority": route.get("priority"), "services": route["services"]}
                for route in item["spec"]["routes"]
            ] for item in ingress_routes
        },
        "legacy_deployments": [],
        "external_secrets": [
            "harbor-registry-secret", "knowledge-tls",
            "knowledge-backend-postgresql-conn", "knowledge-backend-migration-postgresql-conn",
            "knowledge-browser-identity", "knowledge-backend-redis-conn",
            "knowledge-backend-broker", "knowledge-ragflow-provider",
            "knowledge-backend-s3", "knowledge-info-ingest-service-binding",
            "knowledge-investment-retrieval-service-binding",
            "knowledge-active-retrieval-service-binding",
        ],
        "protected_provider_resources": ["ragflow-sunmoonai"],
        "forbidden_markers": ["knowledge-admin-r5.sunmoonai.com", "knowledge-web-r5.sunmoonai.com", "knowledge.r5.candidate"],
        "contains_credentials": False,
        "renderer_inputs_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in renderer_inputs.items()},
    }
    (output / "release.json").write_text(json.dumps(release, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"result": "rendered", **release}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
