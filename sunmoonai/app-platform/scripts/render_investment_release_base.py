#!/usr/bin/env python3
"""Render the same-namespace, zero-extra-writer Investment R5 candidate."""

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

import render_info_release_base as common
import yaml

BACKEND_IMAGE = (
    "harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:"
    "edc52084c243703a68ab9b422d8ad0e1d2ff8519e6a25190b8b52fe8c1e1ed10"
)
ADMIN_IMAGE = (
    "harbor.sunmoonai.com:30443/app-images/investment-admin-frontend@sha256:"
    "15d8253d2125045f38ea8bd159df77642250214b3bd72e8733cedbd50464f41d"
)
WEB_IMAGE = (
    "harbor.sunmoonai.com:30443/app-images/investment-web-frontend@sha256:"
    "d3ac86bdea887ed3be4ab2b61a8928bdf23086e20137c02e0ec2ca520ae51a0a"
)
FILES = common.FILES


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--scaffold-root", type=Path, default=common.default_scaffold())
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--release-id", default="r5-investment-001")
    parser.add_argument(
        "--admin-origin", default="https://investment-admin-r5.sunmoonai.com:30443"
    )
    parser.add_argument(
        "--web-origin", default="https://investment-web-r5.sunmoonai.com:30443"
    )
    parser.add_argument(
        "--casdoor-origin", default="https://casdoor.sunmoonai.com:30443"
    )
    parser.add_argument(
        "--casdoor-backchannel-origin",
        default="http://casdoor-sunmoonai.app-platform-dev.svc.cluster.local:8000",
    )
    parser.add_argument("--tls-secret", default="investment-r5-tls")
    parser.add_argument("--backend-image", default=BACKEND_IMAGE)
    parser.add_argument("--admin-image", default=ADMIN_IMAGE)
    parser.add_argument("--web-image", default=WEB_IMAGE)
    return parser.parse_args()


def config_env(name: str, configmap: str, key: str) -> dict[str, Any]:
    return {
        "name": name,
        "valueFrom": {"configMapKeyRef": {"name": configmap, "key": key}},
    }


def redis_env() -> list[dict[str, Any]]:
    secret = "investment-backend-redis-conn"
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


def knowledge_egress(namespace: str) -> dict[str, Any]:
    return {
        "to": [
            {
                "namespaceSelector": {
                    "matchLabels": {"kubernetes.io/metadata.name": namespace}
                },
                "podSelector": {
                    "matchLabels": {
                        "sunmoonai.com/app": "knowledge-r5",
                        "app.kubernetes.io/component": "backend-api",
                    }
                }
            }
        ],
        "ports": [{"protocol": "TCP", "port": 8000}],
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
                "sunmoonai.com/app": "investment-r5",
                "sunmoonai.com/managed-by": "app-platform-v2",
            },
        },
        "spec": {
            "podSelector": {
                "matchLabels": {
                    "sunmoonai.com/app": "investment-r5",
                    "app.kubernetes.io/component": component,
                }
            },
            "policyTypes": ["Egress"],
            "egress": egress,
        },
    }


def overlay(output: Path, namespace: str) -> None:
    prerequisites = common.load_documents(output / "00-prerequisites.yaml")
    prerequisites = [item for item in prerequisites if item.get("kind") != "Namespace"]
    config = common.resource(prerequisites, "ConfigMap", "investment-r5-backend-config")[
        "data"
    ]
    config.update(
        {
            "SERVICE_NAME": "investment-backend",
            "APP_SLUG": "investment",
            "ADMIN_AUTH_POLICY_VERSION": "investment-admin-v2",
            "ADMIN_AUTH_SCOPE_ALLOWLIST": "investment:admin",
            "WEB_AUTH_POLICY_VERSION": "investment-web-v2",
            "CELERY_QUEUE": "investment.r5.candidate",
            "AUTH_ALLOWED_ALGORITHMS": "RS256,ES256",
            "AGENT_V4_TRAFFIC_ENABLED": "false",
            "AGENT_PILOT_ENABLED": "false",
            "AGENT_REDIS_KEY_PREFIX": "investment:r5:agent",
            "KNOWLEDGE_RETRIEVAL_URL": (
                "http://knowledge-r5-backend:8000/"
                "api/internal/v1/knowledge/retrievals"
            ),
            "KNOWLEDGE_RETRIEVAL_SERVICE_APPLICATION": (
                "sunmoonai-investment-knowledge-retrieve"
            ),
            "KNOWLEDGE_RETRIEVAL_SERVICE_DISCOVERY_URL": (
                "https://casdoor.sunmoonai.com:30443/"
                ".well-known/openid-configuration"
            ),
            "KNOWLEDGE_RETRIEVAL_SERVICE_BACKCHANNEL_ENDPOINT": (
                "http://casdoor-sunmoonai.app-platform-dev.svc.cluster.local:8000"
            ),
            "KNOWLEDGE_RETRIEVAL_SERVICE_SCOPE": "knowledge:retrieve",
            "KNOWLEDGE_RETRIEVAL_TIMEOUT_SECONDS": "20",
        }
    )
    for surface in ("admin", "web"):
        common.resource(
            prerequisites,
            "ConfigMap",
            f"investment-r5-{surface}-frontend-config",
        )["data"]["AUTH_APP"] = "investment"
    common.dump_documents(output / "00-prerequisites.yaml", prerequisites)

    migration_docs = common.load_documents(output / "10-migration.yaml")
    migration = next(item for item in migration_docs if item["kind"] == "Job")
    migration_container = migration["spec"]["template"]["spec"]["containers"][0]
    migration_container["env"] = [
        common.env_ref(
            "MIGRATION_DATABASE_URL",
            "investment-backend-migration-postgresql-conn",
            "MIGRATION_DATABASE_URL",
        ),
        common.env_ref(
            "DATABASE_URL",
            "investment-backend-migration-postgresql-conn",
            "MIGRATION_DATABASE_URL",
        ),
    ]
    common.dump_documents(output / "10-migration.yaml", migration_docs)

    runtime_docs = common.load_documents(output / "20-runtime.yaml")
    api = common.resource(runtime_docs, "Deployment", "investment-r5-backend-api")
    api_container = common.container(api, "api")
    api_container["env"] = [
        common.env_ref(
            "DATABASE_URL", "investment-backend-postgresql-conn", "DATABASE_URL"
        ),
        *redis_env(),
        common.env_ref(
            "ADMIN_CASDOOR_CLIENT_ID",
            "investment-r5-browser-identity",
            "ADMIN_CLIENT_ID",
        ),
        common.env_ref(
            "ADMIN_CASDOOR_CLIENT_SECRET",
            "investment-r5-browser-identity",
            "ADMIN_CLIENT_SECRET",
        ),
        common.env_ref(
            "WEB_CASDOOR_CLIENT_ID",
            "investment-r5-browser-identity",
            "WEB_CLIENT_ID",
        ),
        common.env_ref(
            "WEB_CASDOOR_CLIENT_SECRET",
            "investment-r5-browser-identity",
            "WEB_CLIENT_SECRET",
        ),
        common.env_ref(
            "CELERY_BROKER_URL",
            "investment-backend-broker",
            "CELERY_BROKER_URL",
        ),
    ]

    worker = common.resource(runtime_docs, "Deployment", "investment-r5-backend-worker")
    worker["spec"]["replicas"] = 0
    worker_container = common.container(worker, "worker")
    worker_container["env"] = [
        item
        for item in worker_container.get("env", [])
        if item.get("name") == "POD_NAME"
    ] + [
        common.env_ref(
            "DATABASE_URL", "investment-backend-postgresql-conn", "DATABASE_URL"
        ),
        common.env_ref(
            "CELERY_BROKER_URL",
            "investment-backend-broker",
            "CELERY_BROKER_URL",
        ),
        common.env_ref(
            "CELERY_RESULT_BACKEND",
            "investment-backend-broker",
            "CELERY_RESULT_BACKEND",
            optional=True,
        ),
        *redis_env(),
    ]
    worker_container.setdefault("envFrom", []).append(
        {"secretRef": {"name": "investment-knowledge-retrieval-client"}}
    )

    scheduler = common.resource(
        runtime_docs, "Deployment", "investment-r5-backend-scheduler"
    )
    scheduler["spec"]["replicas"] = 0
    common.container(scheduler, "scheduler")["env"] = [
        common.env_ref(
            "DATABASE_URL", "investment-backend-postgresql-conn", "DATABASE_URL"
        ),
        common.env_ref(
            "CELERY_BROKER_URL",
            "investment-backend-broker",
            "CELERY_BROKER_URL",
        ),
    ]
    runtime_docs = [
        item
        for item in runtime_docs
        if not (
            item.get("kind") == "HorizontalPodAutoscaler"
            and item.get("metadata", {}).get("name") == "investment-r5-backend-worker"
        )
    ]
    common.dump_documents(output / "20-runtime.yaml", runtime_docs)

    policies = common.load_documents(output / "30-network-policies.yaml")
    replaced_policy_names = {
        "investment-r5-backend-runtime-egress",
        "investment-r5-backend-api-egress",
        "investment-r5-backend-worker-egress",
        "investment-r5-backend-scheduler-egress",
    }
    policies = [
        item for item in policies
        if item.get("metadata", {}).get("name") not in replaced_policy_names
    ]
    policies.extend(
        [
            runtime_policy(
                "investment-r5-backend-api-egress",
                "backend-api",
                [data_egress(5432, 6379, 5672), casdoor_egress()],
                namespace,
            ),
            runtime_policy(
                "investment-r5-backend-worker-egress",
                "backend-worker",
                [
                    data_egress(5432, 6379, 5672),
                    casdoor_egress(),
                    knowledge_egress(namespace),
                ],
                namespace,
            ),
            runtime_policy(
                "investment-r5-backend-scheduler-egress",
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

    with tempfile.TemporaryDirectory(prefix="r5-investment-scaffold-") as temp:
        base = Path(temp) / "base"
        command = [
            sys.executable,
            str(renderer),
            "--app",
            "investment-r5",
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
            "sunmoonai-investment-r5-admin",
            "--web-client-id",
            "sunmoonai-investment-r5-web",
            "--admin-application",
            "sunmoonai-investment-r5-admin",
            "--web-application",
            "sunmoonai-investment-r5-web",
            "--output-dir",
            str(base),
        ]
        subprocess.run(command, check=True, capture_output=True, text=True)
        for name in FILES:
            shutil.copy2(base / name, output / name)

    overlay(output, args.namespace)
    hashes = {
        name: hashlib.sha256((output / name).read_bytes()).hexdigest() for name in FILES
    }
    release = {
        "schema_version": 1,
        "architecture": "app-platform-v2-r5-investment-candidate",
        "logical_app": "investment",
        "resource_app": "investment-r5",
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
        "resources": list(FILES),
        "sha256": hashes,
        "external_secrets": {
            "runtime_database": "investment-backend-postgresql-conn",
            "migration_database": "investment-backend-migration-postgresql-conn",
            "browser_identity": "investment-r5-browser-identity",
            "redis": "investment-backend-redis-conn",
            "broker": "investment-backend-broker",
            "knowledge_retrieval_client": "investment-knowledge-retrieval-client",
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
