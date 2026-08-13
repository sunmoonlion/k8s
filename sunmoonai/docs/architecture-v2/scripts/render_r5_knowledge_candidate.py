#!/usr/bin/env python3
"""Render the same-namespace, zero-extra-writer Knowledge R5 candidate."""

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

import render_r5_info_candidate as common
import yaml

BACKEND_IMAGE = (
    "harbor.sunmoonai.com:30443/app-images/knowledge-backend@sha256:"
    "3814dfc08608f32e693736ae72b4b3dbe946493003d5592ce344c636fda6c430"
)
ADMIN_IMAGE = (
    "harbor.sunmoonai.com:30443/app-images/knowledge-admin-frontend@sha256:"
    "07130d859a89b18842ce043178b5477bbb67a3ab183aadfe18baed039bd0b9c2"
)
WEB_IMAGE = (
    "harbor.sunmoonai.com:30443/app-images/knowledge-web-frontend@sha256:"
    "7bdd329bf24e479d1c8f859ef6ed909958bc1479b7296b3b212c2293c7601148"
)
FILES = common.FILES


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--scaffold-root", type=Path, default=common.default_scaffold())
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--release-id", default="r5-knowledge-001")
    parser.add_argument(
        "--admin-origin", default="https://knowledge-admin-r5.sunmoonai.com:30443"
    )
    parser.add_argument(
        "--web-origin", default="https://knowledge-web-r5.sunmoonai.com:30443"
    )
    parser.add_argument(
        "--casdoor-origin", default="https://casdoor.sunmoonai.com:30443"
    )
    parser.add_argument(
        "--casdoor-backchannel-origin",
        default="http://casdoor-sunmoonai.app-platform-dev.svc.cluster.local:8000",
    )
    parser.add_argument("--tls-secret", default="knowledge-r5-tls")
    parser.add_argument("--backend-image", default=BACKEND_IMAGE)
    parser.add_argument("--admin-image", default=ADMIN_IMAGE)
    parser.add_argument("--web-image", default=WEB_IMAGE)
    parser.add_argument(
        "--retrieval-dataset-allowlist",
        required=True,
        help="Comma-separated governed dataset keys enabled for this release.",
    )
    return parser.parse_args()


def config_env(name: str, configmap: str, key: str) -> dict[str, Any]:
    return {
        "name": name,
        "valueFrom": {"configMapKeyRef": {"name": configmap, "key": key}},
    }


def provider_env(retrieval_dataset_allowlist: str) -> list[dict[str, Any]]:
    configmap = "knowledge-admin-backend-config"
    return [
        config_env(name, configmap, name)
        for name in (
            "RAGFLOW_API_BASE",
            "RAGFLOW_PARSE_POLL_INTERVAL_SECONDS",
            "RAGFLOW_PARSE_TIMEOUT_SECONDS",
            "RETRIEVAL_DEFAULT_TENANT_ID",
            "RETRIEVAL_PROVIDER_TIMEOUT_SECONDS",
        )
    ] + [
        {
            "name": "RETRIEVAL_DATASET_ALLOWLIST",
            "value": retrieval_dataset_allowlist,
        },
        common.env_ref(
            "RAGFLOW_API_KEY",
            "knowledge-admin-backend-secret",
            "RAGFLOW_API_KEY",
        )
    ]


def artifact_env() -> list[dict[str, Any]]:
    backend = "knowledge-admin-backend-config"
    s3 = "knowledge-admin-backend-s3"
    return (
        [
            config_env(name, backend, name)
            for name in (
                "ARTIFACT_ALLOWED_CONTENT_TYPES",
                "ARTIFACT_MAX_SIZE_BYTES",
                "ARTIFACT_S3_ALLOWED_BUCKETS",
                "ARTIFACT_S3_ALLOWED_PREFIXES",
            )
        ]
        + [
            config_env(name, s3, name)
            for name in ("S3_ENDPOINT", "S3_FORCE_PATH_STYLE", "S3_REGION")
        ]
        + [
            common.env_ref(
                "S3_ACCESS_KEY_ID", "knowledge-admin-backend-s3", "S3_ACCESS_KEY_ID"
            ),
            common.env_ref(
                "S3_SECRET_ACCESS_KEY",
                "knowledge-admin-backend-s3",
                "S3_SECRET_ACCESS_KEY",
            ),
        ]
    )


def redis_env() -> list[dict[str, Any]]:
    secret = "knowledge-admin-backend-redis-conn"
    return [
        common.env_ref(name, secret, name)
        for name in (
            "REDIS_HOST",
            "REDIS_PORT",
            "REDIS_DB",
            "REDIS_USER",
            "REDIS_PASSWORD",
        )
    ]


def data_egress(*ports: int) -> dict[str, Any]:
    return {
        "to": [
            {
                "namespaceSelector": {
                    "matchLabels": {"sunmoonai.com/data-platform": "true"}
                }
            }
        ],
        "ports": [{"protocol": "TCP", "port": port} for port in ports],
    }


def casdoor_egress() -> dict[str, Any]:
    return {
        "to": [
            {
                "namespaceSelector": {
                    "matchLabels": {"kubernetes.io/metadata.name": "app-platform-dev"}
                },
                "podSelector": {"matchLabels": {"app": "casdoor-sunmoonai"}},
            }
        ],
        "ports": [{"protocol": "TCP", "port": 8000}],
    }


def ragflow_egress() -> dict[str, Any]:
    return {
        "to": [
            {
                "podSelector": {
                    "matchLabels": {
                        "app.kubernetes.io/name": "ragflow",
                        "app.kubernetes.io/instance": "ragflow-sunmoonai",
                        "app.kubernetes.io/component": "ragflow",
                    }
                }
            }
        ],
        "ports": [{"protocol": "TCP", "port": 9380}],
    }


def runtime_policy(
    name: str, component: str, egress: list[dict[str, Any]], namespace: str
) -> dict[str, Any]:
    return {
        "apiVersion": "networking.k8s.io/v1",
        "kind": "NetworkPolicy",
        "metadata": {
            "name": name,
            "namespace": namespace,
            "labels": {
                "sunmoonai.com/app": "knowledge-r5",
                "sunmoonai.com/managed-by": "architecture-v2",
            },
        },
        "spec": {
            "podSelector": {
                "matchLabels": {
                    "sunmoonai.com/app": "knowledge-r5",
                    "app.kubernetes.io/component": component,
                }
            },
            "policyTypes": ["Egress"],
            "egress": egress,
        },
    }


def overlay(
    output: Path, namespace: str, retrieval_dataset_allowlist: str
) -> None:
    prerequisites = common.load_documents(output / "00-prerequisites.yaml")
    prerequisites = [item for item in prerequisites if item.get("kind") != "Namespace"]
    config = common.resource(prerequisites, "ConfigMap", "knowledge-r5-backend-config")[
        "data"
    ]
    config.update(
        {
            "SERVICE_NAME": "knowledge-backend",
            "APP_SLUG": "knowledge",
            "ADMIN_AUTH_POLICY_VERSION": "knowledge-admin-v2",
            "ADMIN_AUTH_SCOPE_ALLOWLIST": "knowledge:admin",
            "WEB_AUTH_POLICY_VERSION": "knowledge-web-v2",
            "CELERY_QUEUE": "knowledge.r5.candidate",
            "AUTH_ALLOWED_ALGORITHMS": "RS256,ES256",
        }
    )
    for surface in ("admin", "web"):
        common.resource(
            prerequisites,
            "ConfigMap",
            f"knowledge-r5-{surface}-frontend-config",
        )["data"]["AUTH_APP"] = "knowledge"
    common.dump_documents(output / "00-prerequisites.yaml", prerequisites)

    migration_docs = common.load_documents(output / "10-migration.yaml")
    migration = next(item for item in migration_docs if item["kind"] == "Job")
    migration_container = migration["spec"]["template"]["spec"]["containers"][0]
    migration_container["env"] = [
        common.env_ref(
            "MIGRATION_DATABASE_URL",
            "knowledge-backend-migration-postgresql-conn",
            "MIGRATION_DATABASE_URL",
        ),
        common.env_ref(
            "DATABASE_URL",
            "knowledge-backend-migration-postgresql-conn",
            "MIGRATION_DATABASE_URL",
        ),
    ]
    common.dump_documents(output / "10-migration.yaml", migration_docs)

    runtime_docs = common.load_documents(output / "20-runtime.yaml")
    api = common.resource(runtime_docs, "Deployment", "knowledge-r5-backend-api")
    api_container = common.container(api, "api")
    api_container["env"] = [
        common.env_ref(
            "DATABASE_URL", "knowledge-backend-postgresql-conn", "DATABASE_URL"
        ),
        *redis_env(),
        common.env_ref(
            "ADMIN_CASDOOR_CLIENT_ID",
            "knowledge-r5-browser-identity",
            "ADMIN_CLIENT_ID",
        ),
        common.env_ref(
            "ADMIN_CASDOOR_CLIENT_SECRET",
            "knowledge-r5-browser-identity",
            "ADMIN_CLIENT_SECRET",
        ),
        common.env_ref(
            "WEB_CASDOOR_CLIENT_ID",
            "knowledge-r5-browser-identity",
            "WEB_CLIENT_ID",
        ),
        common.env_ref(
            "WEB_CASDOOR_CLIENT_SECRET",
            "knowledge-r5-browser-identity",
            "WEB_CLIENT_SECRET",
        ),
        common.env_ref(
            "CELERY_BROKER_URL",
            "celeryworker-knowledge-admin-backend-secret",
            "CELERY_BROKER_URL",
        ),
        *provider_env(retrieval_dataset_allowlist),
    ]
    api_container.setdefault("envFrom", []).extend(
        [
            {"secretRef": {"name": "knowledge-info-ingest-service-binding"}},
            {"secretRef": {"name": "knowledge-active-retrieval-service-binding"}},
        ]
    )

    worker = common.resource(runtime_docs, "Deployment", "knowledge-r5-backend-worker")
    worker["spec"]["replicas"] = 0
    worker_container = common.container(worker, "worker")
    worker_container["env"] = [
        item
        for item in worker_container.get("env", [])
        if item.get("name") == "POD_NAME"
    ] + [
        common.env_ref(
            "DATABASE_URL", "knowledge-backend-postgresql-conn", "DATABASE_URL"
        ),
        common.env_ref(
            "CELERY_BROKER_URL",
            "celeryworker-knowledge-admin-backend-secret",
            "CELERY_BROKER_URL",
        ),
        common.env_ref(
            "CELERY_RESULT_BACKEND",
            "celeryworker-knowledge-admin-backend-secret",
            "CELERY_RESULT_BACKEND",
            optional=True,
        ),
        *provider_env(retrieval_dataset_allowlist),
        *artifact_env(),
    ]

    scheduler = common.resource(
        runtime_docs, "Deployment", "knowledge-r5-backend-scheduler"
    )
    scheduler["spec"]["replicas"] = 0
    common.container(scheduler, "scheduler")["env"] = [
        common.env_ref(
            "DATABASE_URL", "knowledge-backend-postgresql-conn", "DATABASE_URL"
        ),
        common.env_ref(
            "CELERY_BROKER_URL",
            "celeryworker-knowledge-admin-backend-secret",
            "CELERY_BROKER_URL",
        ),
    ]
    runtime_docs = [
        item
        for item in runtime_docs
        if not (
            item.get("kind") == "HorizontalPodAutoscaler"
            and item.get("metadata", {}).get("name") == "knowledge-r5-backend-worker"
        )
    ]
    common.dump_documents(output / "20-runtime.yaml", runtime_docs)

    policies = common.load_documents(output / "30-network-policies.yaml")
    replaced_policy_names = {
        "knowledge-r5-backend-runtime-egress",
        "knowledge-r5-backend-api-egress",
        "knowledge-r5-backend-worker-egress",
        "knowledge-r5-backend-scheduler-egress",
    }
    policies = [
        item for item in policies
        if item.get("metadata", {}).get("name") not in replaced_policy_names
    ]
    policies.extend(
        [
            runtime_policy(
                "knowledge-r5-backend-api-egress",
                "backend-api",
                [data_egress(5432, 6379, 5672), casdoor_egress(), ragflow_egress()],
                namespace,
            ),
            runtime_policy(
                "knowledge-r5-backend-worker-egress",
                "backend-worker",
                [
                    data_egress(5432, 6379, 5672, 80),
                    ragflow_egress(),
                ],
                namespace,
            ),
            runtime_policy(
                "knowledge-r5-backend-scheduler-egress",
                "backend-scheduler",
                [data_egress(5432, 6379, 5672)],
                namespace,
            ),
        ]
    )
    for item in policies:
        item.setdefault("metadata", {})["namespace"] = namespace
    common.dump_documents(output / "30-network-policies.yaml", policies)


def main() -> int:
    args = parse_args()
    scaffold = args.scaffold_root.resolve()
    renderer = scaffold / "scaffold.py"
    if not renderer.is_file():
        raise common.RenderError(f"canonical scaffold not found: {renderer}")
    output = args.output_dir.resolve()
    if output.exists() and any(output.iterdir()):
        raise common.RenderError(f"output directory must be absent or empty: {output}")
    output.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="r5-knowledge-scaffold-") as temp:
        base = Path(temp) / "base"
        command = [
            sys.executable,
            str(renderer),
            "--app",
            "knowledge-r5",
            "--namespace",
            args.namespace,
            "--release-id",
            args.release_id,
            "--backend-image",
            args.backend_image,
            "--admin-image",
            args.admin_image,
            "--web-image",
            args.web_image,
            "--admin-origin",
            args.admin_origin,
            "--web-origin",
            args.web_origin,
            "--casdoor-origin",
            args.casdoor_origin,
            "--casdoor-backchannel-origin",
            args.casdoor_backchannel_origin,
            "--redis-host",
            "redis-sunmoonai-master.data-platform-dev.svc.cluster.local",
            "--tls-secret",
            args.tls_secret,
            "--ingress-namespace",
            "ingress-platform-dev",
            "--admin-client-id",
            "sunmoonai-knowledge-r5-admin",
            "--web-client-id",
            "sunmoonai-knowledge-r5-web",
            "--admin-application",
            "sunmoonai-knowledge-r5-admin",
            "--web-application",
            "sunmoonai-knowledge-r5-web",
            "--output-dir",
            str(base),
        ]
        subprocess.run(command, check=True, capture_output=True, text=True)
        for name in FILES:
            shutil.copy2(base / name, output / name)

    overlay(output, args.namespace, args.retrieval_dataset_allowlist)
    hashes = {
        name: hashlib.sha256((output / name).read_bytes()).hexdigest() for name in FILES
    }
    release = {
        "schema_version": 1,
        "architecture": "app-platform-v2-r5-knowledge-candidate",
        "logical_app": "knowledge",
        "resource_app": "knowledge-r5",
        "namespace": args.namespace,
        "release_id": args.release_id,
        "images": {
            "backend": args.backend_image,
            "admin": args.admin_image,
            "web": args.web_image,
        },
        "origins": {
            "admin": args.admin_origin,
            "web": args.web_origin,
            "casdoor": args.casdoor_origin,
        },
        "retrieval_dataset_allowlist": args.retrieval_dataset_allowlist,
        "resources": list(FILES),
        "sha256": hashes,
        "external_secrets": {
            "runtime_database": "knowledge-backend-postgresql-conn",
            "migration_database": "knowledge-backend-migration-postgresql-conn",
            "browser_identity": "knowledge-r5-browser-identity",
            "info_ingest_binding": "knowledge-info-ingest-service-binding",
            "transition_retrieval_binding": "knowledge-research-retrieval-service-binding",
            "investment_retrieval_binding": "knowledge-investment-retrieval-service-binding",
            "active_retrieval_binding": "knowledge-active-retrieval-service-binding",
            "ragflow_key_source": "knowledge-admin-backend-secret",
            "artifact_source": "knowledge-admin-backend-s3",
        },
        "formal_release": False,
        "touches_v1_resources": False,
    }
    (output / "release.json").write_text(
        json.dumps(release, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"result": "rendered", **release}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        OSError,
        common.RenderError,
        subprocess.CalledProcessError,
        yaml.YAMLError,
    ) as exc:
        print(json.dumps({"result": "failed", "error": str(exc)}), file=sys.stderr)
        raise SystemExit(1)
