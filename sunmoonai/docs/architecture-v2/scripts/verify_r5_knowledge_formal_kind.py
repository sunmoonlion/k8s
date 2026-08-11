#!/usr/bin/env python3
"""Fail-closed runtime gate for the formal Knowledge Architecture v2 cutover."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import verify_r5_info_candidate_kind as common
import verify_r5_knowledge_candidate_kind as candidate


EXPECTED_REPLICAS = {
    "knowledge-r5-backend-api": 2,
    "knowledge-r5-backend-worker": 1,
    "knowledge-r5-backend-scheduler": 1,
    "knowledge-r5-admin-frontend": 2,
    "knowledge-r5-web-frontend": 2,
}
LEGACY_REPLICAS = {
    "knowledge-admin-backend": 0,
    "celeryworker-knowledge-admin-backend": 0,
}


def literal_env(container: dict[str, Any], name: str) -> str | None:
    matches = [item for item in container.get("env", []) if item.get("name") == name]
    common.require(len(matches) == 1, f"{name} is absent or duplicated")
    return matches[0].get("value")


def query_role_state(kubectl: common.Kubectl) -> dict[str, bool]:
    sql = """
SELECT jsonb_object_agg(rolname, rolcanlogin ORDER BY rolname)
FROM pg_roles
WHERE rolname IN (
  'knowledge_admin_user', 'knowledge_admin_user_migration',
  'knowledge_backend_user', 'knowledge_backend_user_migration'
);
"""
    shell = r'''export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
exec /opt/bitnami/postgresql/bin/psql -U postgres -d knowledge_admin -X -v ON_ERROR_STOP=1 -At -c "$1"'''
    result = kubectl.run(
        "exec", "--quiet", "-n", "data-platform-dev", "postgresql-sunmoonai-0",
        "--", "sh", "-lc", shell, "sh", sql,
    )
    return json.loads(result.stdout.strip())


def deployment_principal(
    kubectl: common.Kubectl, deployment: str, expected: str
) -> dict[str, Any]:
    probe = common.run_probe_pod(
        kubectl,
        source_kind="deployment",
        source_name=deployment,
        role=deployment,
        program=common.PRINCIPAL_PROGRAM,
    )
    common.require(probe.get("principal") == expected, f"{deployment} principal drift")
    common.require(probe.get("database") == "knowledge_admin", f"{deployment} database drift")
    common.require(probe.get("head") == "20260808_0004", f"{deployment} migration drift")
    return probe


def queue_state(kubectl: common.Kubectl) -> dict[str, Any]:
    shell = r'''
curl --fail --silent --show-error \
  --user "$RABBITMQ_USERNAME:$(cat "$RABBITMQ_PASSWORD_FILE")" \
  http://127.0.0.1:15672/api/queues/knowledge-development/knowledge.admin.default
'''
    raw = kubectl.run(
        "exec", "--quiet", "-n", "messaging-platform-dev",
        "rabbitmq-sunmoonai-0", "-c", "rabbitmq", "--", "sh", "-lc", shell,
    ).stdout
    item = json.loads(raw)
    result = {
        "messages_ready": item.get("messages_ready"),
        "messages_unacknowledged": item.get("messages_unacknowledged"),
        "consumers": item.get("consumers"),
    }
    common.require(result["messages_ready"] == 0, "Knowledge queue is not drained")
    common.require(result["messages_unacknowledged"] == 0, "Knowledge queue has in-flight messages")
    common.require(result["consumers"] == 1, "Knowledge queue must have exactly one consumer")
    return result


def ingress_summary(kubectl: common.Kubectl) -> dict[str, Any]:
    expected = {
        "knowledge-admin-frontend-ingress": [
            ("Host(`knowledge-admin.sunmoonai.com`) && PathPrefix(`/api`)", "knowledge-r5-backend", 8000),
            ("Host(`knowledge-admin.sunmoonai.com`) && PathPrefix(`/`)", "knowledge-r5-admin-frontend", 3000),
        ],
        "knowledge-web-frontend-ingress": [
            ("Host(`knowledge.sunmoonai.com`) && PathPrefix(`/api`)", "knowledge-r5-backend", 8000),
            ("Host(`knowledge.sunmoonai.com`) && PathPrefix(`/`)", "knowledge-r5-web-frontend", 3000),
        ],
        "knowledge-admin-backend-ingress": [
            ("Host(`knowledge-admin-api.sunmoonai.com`) && PathPrefix(`/`)", "knowledge-r5-backend", 8000),
        ],
    }
    summary: dict[str, Any] = {}
    for name, routes in expected.items():
        item = kubectl.get_json("ingressroute", name)
        actual = [
            (
                route.get("match"),
                route["services"][0].get("name"),
                route["services"][0].get("port"),
            )
            for route in item["spec"].get("routes", [])
        ]
        common.require(actual == routes, f"{name} route drift")
        common.require(
            item["spec"].get("tls", {}).get("secretName") == "knowledge-r5-tls",
            f"{name} TLS secret drift",
        )
        summary[name] = actual
    return summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True, type=Path)
    parser.add_argument("--overlay", required=True, type=Path)
    parser.add_argument("--kubeconfig", default=str(Path.home() / ".kube/kind-config"))
    parser.add_argument("--namespace", default="app-platform-dev")
    args = parser.parse_args()
    release = json.loads((args.bundle / "release.json").read_text(encoding="utf-8"))
    formal = json.loads((args.overlay / "formal-release.json").read_text(encoding="utf-8"))
    common.require(args.namespace == "app-platform-dev", "formal namespace mismatch")
    common.require(formal["candidate_release_id"] == release["release_id"], "release lineage drift")
    kubectl = common.Kubectl(args.kubeconfig, args.namespace)

    deployments: dict[str, dict[str, Any]] = {}
    for name, replicas in EXPECTED_REPLICAS.items():
        item = kubectl.get_json("deployment", name)
        deployments[name] = item
        common.require(item["spec"].get("replicas", 0) == replicas, f"{name} replica drift")
        common.require(item.get("status", {}).get("readyReplicas", 0) == replicas, f"{name} not ready")
    for name, replicas in LEGACY_REPLICAS.items():
        item = kubectl.get_json("deployment", name)
        common.require(item["spec"].get("replicas", 0) == replicas, f"legacy writer active: {name}")
        common.require(item.get("status", {}).get("readyReplicas", 0) == replicas, f"legacy workload not frozen: {name}")

    for name in ("knowledge-r5-backend-api", "knowledge-r5-backend-worker", "knowledge-r5-backend-scheduler"):
        container = deployments[name]["spec"]["template"]["spec"]["containers"][0]
        common.require(container["image"] == release["images"]["backend"], f"{name} image drift")
        common.require(
            common.env_secret_ref(container, "DATABASE_URL")
            == ("knowledge-backend-postgresql-conn", "DATABASE_URL"),
            f"{name} database identity drift",
        )
    api = deployments["knowledge-r5-backend-api"]["spec"]["template"]["spec"]["containers"][0]
    worker = deployments["knowledge-r5-backend-worker"]["spec"]["template"]["spec"]["containers"][0]
    common.require(literal_env(api, "RETRIEVAL_DATASET_ALLOWLIST") == release["retrieval_dataset_allowlist"], "API retrieval allowlist drift")
    common.require(literal_env(worker, "RETRIEVAL_DATASET_ALLOWLIST") == release["retrieval_dataset_allowlist"], "Worker retrieval allowlist drift")

    config = kubectl.get_json("configmap", "knowledge-r5-backend-config")["data"]
    common.require(config.get("DEPLOYMENT_ID") == "r5-knowledge-formal-001", "formal deployment ID drift")
    common.require(config.get("CELERY_QUEUE") == "knowledge.admin.default", "formal queue drift")
    common.require(config.get("ADMIN_FRONTEND_BASE_URL") == formal["formal_origins"]["admin"], "Admin origin drift")
    common.require(config.get("WEB_FRONTEND_BASE_URL") == formal["formal_origins"]["web"], "Web origin drift")

    database = candidate.query_database(kubectl)
    common.require(database.get("head") == "20260808_0004", "formal migration absent")
    common.require(database.get("counts") == candidate.EXPECTED_COUNTS, "database row-count drift")
    common.require(database.get("invariant_failures") == 0, "business invariant failure")
    common.require(database.get("not_valid_constraints") == 0, "unvalidated constraint present")
    common.require(database.get("indexed_bindings") == 1, "Provider binding drift")
    common.require(database.get("database_owner") == "knowledge_backend_user_migration", "database owner drift")
    common.require(
        set(database.get("table_owners", {}).values()) == {"knowledge_backend_user_migration"},
        "table owner drift",
    )
    roles = query_role_state(kubectl)
    common.require(roles == {
        "knowledge_admin_user": False,
        "knowledge_admin_user_migration": False,
        "knowledge_backend_user": True,
        "knowledge_backend_user_migration": True,
    }, "database role state drift")

    principals = {
        name: deployment_principal(kubectl, name, "knowledge_backend_user")
        for name in ("knowledge-r5-backend-api", "knowledge-r5-backend-worker", "knowledge-r5-backend-scheduler")
    }
    result = {
        "task": "R5-K4-knowledge-formal-runtime",
        "result": "passed",
        "release_id": release["release_id"],
        "formal_release_id": formal["formal_release_id"],
        "replicas": EXPECTED_REPLICAS,
        "legacy_replicas": LEGACY_REPLICAS,
        "database": database,
        "database_roles": roles,
        "principals": principals,
        "queue": queue_state(kubectl),
        "ingress": ingress_summary(kubectl),
        "single_writer": True,
        "ragflow_mutated": False,
        "credentials_printed": False,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (common.GateError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(json.dumps({
            "task": "R5-K4-knowledge-formal-runtime",
            "result": "failed",
            "error": str(exc),
            "credentials_printed": False,
        }), file=sys.stderr)
        raise SystemExit(1)
