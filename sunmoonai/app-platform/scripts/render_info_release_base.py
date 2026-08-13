#!/usr/bin/env python3
"""Render the Info R5 same-namespace candidate from the canonical v2 scaffold.

The canonical scaffold intentionally models a fresh App.  R5 is different: it
must run beside the v1 Info workloads in ``app-platform-dev`` and it must reuse
already prepared, role-specific Secrets without copying credentials into a
combined Secret.  This renderer keeps the scaffold topology, then applies the
small, explicit Info migration overlay below.
"""

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

BACKEND_IMAGE = (
    "harbor.sunmoonai.com:30443/app-images/info-backend@sha256:"
    "ee962dff40dd0ebee6969f084dceac10a9283814df7af45d1da6e114047bea0d"
)
ADMIN_IMAGE = (
    "harbor.sunmoonai.com:30443/app-images/info-admin-frontend@sha256:"
    "defacc2f58584541561ada6ce13918efe4be41e9dd7ef21decd30299cd2f149d"
)
WEB_IMAGE = (
    "harbor.sunmoonai.com:30443/app-images/info-web-frontend@sha256:"
    "60f3f70a67630997cc3d0fe9884c166fd5023dac9eed81a3a03b22c5e5c66c52"
)
FILES = (
    "00-prerequisites.yaml",
    "10-migration.yaml",
    "20-runtime.yaml",
    "30-network-policies.yaml",
    "40-ingress.yaml",
)


class RenderError(RuntimeError):
    pass


def default_scaffold() -> Path:
    return Path(__file__).resolve().parents[4] / "tpl-app" / "k8s-deployment"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--scaffold-root", type=Path, default=default_scaffold())
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--release-id", default="r5-info-candidate-001")
    parser.add_argument(
        "--admin-origin", default="https://info-admin-r5.sunmoonai.com:30443"
    )
    parser.add_argument(
        "--web-origin", default="https://info-web-r5.sunmoonai.com:30443"
    )
    parser.add_argument(
        "--casdoor-origin", default="https://casdoor.sunmoonai.com:30443"
    )
    parser.add_argument(
        "--casdoor-backchannel-origin",
        default="http://casdoor-sunmoonai.app-platform-dev.svc.cluster.local:8000",
    )
    parser.add_argument("--tls-secret", default="info-r5-tls")
    parser.add_argument("--backend-image", default=BACKEND_IMAGE)
    parser.add_argument("--admin-image", default=ADMIN_IMAGE)
    parser.add_argument("--web-image", default=WEB_IMAGE)
    return parser.parse_args()


def load_documents(path: Path) -> list[dict[str, Any]]:
    return [item for item in yaml.safe_load_all(path.read_text()) if item]


def dump_documents(path: Path, documents: list[dict[str, Any]]) -> None:
    path.write_text(
        yaml.safe_dump_all(documents, sort_keys=False, explicit_start=False),
        encoding="utf-8",
    )


def resource(documents: list[dict[str, Any]], kind: str, name: str) -> dict[str, Any]:
    matches = [
        item
        for item in documents
        if item.get("kind") == kind and item.get("metadata", {}).get("name") == name
    ]
    if len(matches) != 1:
        raise RenderError(f"expected one {kind}/{name}, found {len(matches)}")
    return matches[0]


def container(deployment: dict[str, Any], name: str) -> dict[str, Any]:
    containers = deployment["spec"]["template"]["spec"]["containers"]
    matches = [item for item in containers if item.get("name") == name]
    if len(matches) != 1:
        raise RenderError(f"expected one container {name}, found {len(matches)}")
    return matches[0]


def env_ref(name: str, secret: str, key: str, *, optional: bool = False) -> dict[str, Any]:
    key_ref: dict[str, Any] = {"name": secret, "key": key}
    if optional:
        key_ref["optional"] = True
    return {"name": name, "valueFrom": {"secretKeyRef": key_ref}}


def redis_env() -> list[dict[str, Any]]:
    secret = "info-admin-backend-redis-conn"
    return [
        env_ref("REDIS_HOST", secret, "REDIS_HOST"),
        env_ref("REDIS_PORT", secret, "REDIS_PORT"),
        env_ref("REDIS_DB", secret, "REDIS_DB"),
        env_ref("REDIS_USER", secret, "REDIS_USER"),
        env_ref("REDIS_PASSWORD", secret, "REDIS_PASSWORD"),
    ]


def add_info_storage(container_spec: dict[str, Any]) -> None:
    env_from = container_spec.setdefault("envFrom", [])
    env_from.extend(
        (
            {"configMapRef": {"name": "info-admin-backend-s3"}},
            {"secretRef": {"name": "info-admin-backend-s3"}},
            {"configMapRef": {"name": "info-admin-backend-elasticsearch"}},
            {"secretRef": {"name": "info-admin-backend-elasticsearch"}},
        )
    )
    container_spec.setdefault("volumeMounts", []).append(
        {
            "name": "elasticsearch-ca",
            "mountPath": "/etc/elasticsearch/ca",
            "readOnly": True,
        }
    )


def data_egress() -> list[dict[str, Any]]:
    return [
        {
            "to": [
                {
                    "namespaceSelector": {
                        "matchLabels": {
                            "sunmoonai.com/data-platform": "true"
                        }
                    }
                }
            ],
            "ports": [
                {"protocol": "TCP", "port": 5432},
                {"protocol": "TCP", "port": 6379},
                {"protocol": "TCP", "port": 5672},
            ],
        }
    ]


def casdoor_egress() -> dict[str, Any]:
    return {
        "to": [
            {
                "namespaceSelector": {
                    "matchLabels": {
                        "kubernetes.io/metadata.name": "app-platform-dev"
                    }
                },
                "podSelector": {"matchLabels": {"app": "casdoor-sunmoonai"}},
            }
        ],
        "ports": [{"protocol": "TCP", "port": 8000}],
    }


def runtime_policy(name: str, component: str, egress: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "apiVersion": "networking.k8s.io/v1",
        "kind": "NetworkPolicy",
        "metadata": {
            "name": name,
            "namespace": "app-platform-dev",
            "labels": {
                "sunmoonai.com/app": "info-r5",
                "sunmoonai.com/managed-by": "app-platform-v2",
            },
        },
        "spec": {
            "podSelector": {
                "matchLabels": {
                    "sunmoonai.com/app": "info-r5",
                    "app.kubernetes.io/component": component,
                }
            },
            "policyTypes": ["Egress"],
            "egress": egress,
        },
    }


def overlay(output: Path, namespace: str) -> None:
    prerequisites = load_documents(output / "00-prerequisites.yaml")
    prerequisites = [item for item in prerequisites if item.get("kind") != "Namespace"]
    backend_config = resource(prerequisites, "ConfigMap", "info-r5-backend-config")
    data = backend_config["data"]
    data.update(
        {
            "SERVICE_NAME": "info-backend",
            "APP_SLUG": "info",
            "ADMIN_AUTH_POLICY_VERSION": "info-admin-v2",
            "ADMIN_AUTH_SCOPE_ALLOWLIST": "info:admin",
            "WEB_AUTH_POLICY_VERSION": "info-web-v2",
            # I3 is a read-only/identity candidate. It must not consume the v1
            # production queue before the I4 single-writer cutover.
            "CELERY_QUEUE": "info.r5.candidate",
            "STORAGE_BACKEND": "s3",
            "SEARCH_BACKEND": "elasticsearch",
            "ELASTICSEARCH_INDEX": "info-information",
            "DELIVERY_OUTBOX_BATCH_SIZE": "50",
            "DELIVERY_OUTBOX_LEASE_SECONDS": "30",
            "DELIVERY_OUTBOX_ACK_TIMEOUT_SECONDS": "300",
            "DELIVERY_OUTBOX_RETRY_BASE_SECONDS": "5",
            "DELIVERY_OUTBOX_RETRY_MAX_SECONDS": "300",
            "KNOWLEDGE_APP_INGEST_URL": (
                "http://knowledge-admin-backend:8000/"
                "api/internal/v1/knowledge/ingestions"
            ),
            "KNOWLEDGE_APP_SERVICE_APPLICATION": "sunmoonai-info-knowledge-ingest",
            "KNOWLEDGE_APP_SERVICE_SCOPE": "knowledge:ingest",
            "KNOWLEDGE_APP_TIMEOUT_SECONDS": "20",
        }
    )
    for name in ("info-r5-admin-frontend-config", "info-r5-web-frontend-config"):
        resource(prerequisites, "ConfigMap", name)["data"]["AUTH_APP"] = "info"
    dump_documents(output / "00-prerequisites.yaml", prerequisites)

    migration_docs = load_documents(output / "10-migration.yaml")
    migration_job = next(item for item in migration_docs if item["kind"] == "Job")
    migration_container = migration_job["spec"]["template"]["spec"]["containers"][0]
    migration_container["env"] = [
        env_ref(
            "MIGRATION_DATABASE_URL",
            "info-backend-migration-postgresql-conn",
            "MIGRATION_DATABASE_URL",
        ),
        env_ref(
            "DATABASE_URL",
            "info-backend-migration-postgresql-conn",
            "MIGRATION_DATABASE_URL",
        ),
    ]
    dump_documents(output / "10-migration.yaml", migration_docs)

    runtime_docs = load_documents(output / "20-runtime.yaml")
    api = resource(runtime_docs, "Deployment", "info-r5-backend-api")
    api_container = container(api, "api")
    api_container["env"] = [
        env_ref("DATABASE_URL", "info-backend-postgresql-conn", "DATABASE_URL"),
        *redis_env(),
        env_ref(
            "ADMIN_CASDOOR_CLIENT_ID",
            "info-r5-browser-identity",
            "ADMIN_CLIENT_ID",
        ),
        env_ref(
            "ADMIN_CASDOOR_CLIENT_SECRET",
            "info-r5-browser-identity",
            "ADMIN_CLIENT_SECRET",
        ),
        env_ref(
            "WEB_CASDOOR_CLIENT_ID",
            "info-r5-browser-identity",
            "WEB_CLIENT_ID",
        ),
        env_ref(
            "WEB_CASDOOR_CLIENT_SECRET",
            "info-r5-browser-identity",
            "WEB_CLIENT_SECRET",
        ),
        env_ref(
            "CELERY_BROKER_URL",
            "celeryworker-info-admin-backend-secret",
            "CELERY_BROKER_URL",
        ),
    ]
    add_info_storage(api_container)
    api["spec"]["template"]["spec"].setdefault("volumes", []).append(
        {
            "name": "elasticsearch-ca",
            "secret": {
                "secretName": "info-admin-backend-elasticsearch",
                "items": [{"key": "ca.crt", "path": "ca.crt"}],
            },
        }
    )

    worker = resource(runtime_docs, "Deployment", "info-r5-backend-worker")
    worker["spec"]["replicas"] = 0
    worker_container = container(worker, "worker")
    worker_container["env"] = [
        item for item in worker_container.get("env", []) if item.get("name") == "POD_NAME"
    ] + [
        env_ref("DATABASE_URL", "info-backend-postgresql-conn", "DATABASE_URL"),
        *redis_env(),
        env_ref(
            "CELERY_BROKER_URL",
            "celeryworker-info-admin-backend-secret",
            "CELERY_BROKER_URL",
        ),
        env_ref(
            "CELERY_RESULT_BACKEND",
            "celeryworker-info-admin-backend-secret",
            "CELERY_RESULT_BACKEND",
            optional=True,
        ),
    ]
    worker_container.setdefault("envFrom", []).append(
        {"secretRef": {"name": "info-knowledge-ingest-client"}}
    )
    add_info_storage(worker_container)
    worker["spec"]["template"]["spec"].setdefault("volumes", []).append(
        {
            "name": "elasticsearch-ca",
            "secret": {
                "secretName": "info-admin-backend-elasticsearch",
                "items": [{"key": "ca.crt", "path": "ca.crt"}],
            },
        }
    )

    scheduler = resource(runtime_docs, "Deployment", "info-r5-backend-scheduler")
    scheduler["spec"]["replicas"] = 0
    scheduler_container = container(scheduler, "scheduler")
    scheduler_container["env"] = [
        env_ref("DATABASE_URL", "info-backend-postgresql-conn", "DATABASE_URL"),
        env_ref(
            "CELERY_BROKER_URL",
            "celeryworker-info-admin-backend-secret",
            "CELERY_BROKER_URL",
        ),
    ]
    runtime_docs = [
        item
        for item in runtime_docs
        if not (
            item.get("kind") == "HorizontalPodAutoscaler"
            and item.get("metadata", {}).get("name")
            == "info-r5-backend-worker"
        )
    ]
    dump_documents(output / "20-runtime.yaml", runtime_docs)

    policies = load_documents(output / "30-network-policies.yaml")
    replaced_policy_names = {
        "info-r5-backend-runtime-egress",
        "info-r5-backend-api-egress",
        "info-r5-backend-worker-egress",
        "info-r5-backend-scheduler-egress",
    }
    policies = [
        item for item in policies
        if item.get("metadata", {}).get("name") not in replaced_policy_names
    ]
    provider = {
        "to": [
            {
                "podSelector": {
                    "matchLabels": {"sunmoonai.com/internal-provider": "true"}
                }
            }
        ],
        "ports": [{"protocol": "TCP", "port": 8000}],
    }
    internet_tls = {
        "to": [{"ipBlock": {"cidr": "0.0.0.0/0"}}],
        "ports": [{"protocol": "TCP", "port": 443}],
    }
    policies.extend(
        (
            runtime_policy(
                "info-r5-backend-api-egress",
                "backend-api",
                [*data_egress(), casdoor_egress()],
            ),
            runtime_policy(
                "info-r5-backend-worker-egress",
                "backend-worker",
                [*data_egress(), casdoor_egress(), provider, internet_tls],
            ),
            runtime_policy(
                "info-r5-backend-scheduler-egress",
                "backend-scheduler",
                data_egress(),
            ),
        )
    )
    for item in policies:
        item.setdefault("metadata", {})["namespace"] = namespace
    dump_documents(output / "30-network-policies.yaml", policies)


def main() -> int:
    args = parse_args()
    scaffold = args.scaffold_root.resolve()
    renderer = scaffold / "scaffold.py"
    if not renderer.is_file():
        raise RenderError(f"canonical scaffold not found: {renderer}")
    output = args.output_dir.resolve()
    if output.exists() and any(output.iterdir()):
        raise RenderError(f"output directory must be absent or empty: {output}")
    output.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="r5-info-scaffold-") as temp:
        base = Path(temp) / "base"
        command = [
            sys.executable,
            str(renderer),
            "--app",
            "info-r5",
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
            "sunmoonai-info-r5-admin",
            "--web-client-id",
            "sunmoonai-info-r5-web",
            "--admin-application",
            "sunmoonai-info-r5-admin",
            "--web-application",
            "sunmoonai-info-r5-web",
            "--output-dir",
            str(base),
        ]
        subprocess.run(command, check=True, capture_output=True, text=True)
        for name in FILES:
            shutil.copy2(base / name, output / name)

    overlay(output, args.namespace)
    hashes = {
        name: hashlib.sha256((output / name).read_bytes()).hexdigest()
        for name in FILES
    }
    release = {
        "schema_version": 1,
        "architecture": "app-platform-v2-r5-info-candidate",
        "logical_app": "info",
        "resource_app": "info-r5",
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
            "runtime_database": "info-backend-postgresql-conn",
            "migration_database": "info-backend-migration-postgresql-conn",
            "browser_identity": "info-r5-browser-identity",
            "worker_downstream_identity": "info-knowledge-ingest-client",
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
    except (OSError, RenderError, subprocess.CalledProcessError, yaml.YAMLError) as exc:
        print(json.dumps({"result": "failed", "error": str(exc)}), file=sys.stderr)
        raise SystemExit(1)
