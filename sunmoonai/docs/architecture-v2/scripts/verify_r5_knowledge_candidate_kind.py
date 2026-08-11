#!/usr/bin/env python3
"""Deep runtime gate for the zero-extra-writer Knowledge R5 candidate."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import verify_r5_info_candidate_kind as common
import yaml

EXPECTED_REPLICAS = {
    "knowledge-r5-backend-api": 2,
    "knowledge-r5-backend-worker": 0,
    "knowledge-r5-backend-scheduler": 0,
    "knowledge-r5-admin-frontend": 2,
    "knowledge-r5-web-frontend": 2,
}
V1 = {
    "knowledge-admin-backend": {
        "replicas": 1,
        "image": "harbor.sunmoonai.com:30443/app-images/knowledge-admin-backend:p0-004-retrieval-r2-20260715",
    },
    "celeryworker-knowledge-admin-backend": {
        "replicas": 1,
        "image": "harbor.sunmoonai.com:30443/app-images/knowledge-admin-backend:1.0.1",
    },
}
EXPECTED_COUNTS = {
    "auth_user": 1,
    "knowledge_ingestion_job": 38,
    "knowledge_document": 1,
    "knowledge_document_version": 1,
}
CONNECT_PROGRAM = r"""
import json, socket, sys

host, port, expectation = sys.argv[1], int(sys.argv[2]), sys.argv[3]
connected = False
try:
    connection = socket.create_connection((host, port), timeout=5)
    connection.close()
    connected = True
except (TimeoutError, OSError):
    pass
print(json.dumps({"connected": connected, "expected": expectation}))
if connected != (expectation == "allow"):
    raise SystemExit(1)
""".strip()


def query_database(kubectl: common.Kubectl) -> dict[str, Any]:
    sql = """
WITH expected(tablename) AS (
  VALUES ('auth_user'), ('knowledge_ingestion_job'),
         ('knowledge_document'), ('knowledge_document_version')
), counts AS (
  SELECT tablename,
    ((xpath('/row/count/text()', query_to_xml(
      format('SELECT count(*) AS count FROM public.%I', tablename), false, true, ''
    )))[1]::text)::bigint AS row_count
  FROM expected
), invariants AS (
  SELECT
    (SELECT count(*) FROM (
      SELECT idempotency_key FROM knowledge_ingestion_job
      GROUP BY idempotency_key HAVING count(*) > 1
    ) duplicates) +
    (SELECT count(*) FROM (
      SELECT source_app, source_document_id, dataset_key FROM knowledge_document
      GROUP BY source_app, source_document_id, dataset_key HAVING count(*) > 1
    ) duplicates) +
    (SELECT count(*) FROM (
      SELECT knowledge_document_id, source_document_version_id
      FROM knowledge_document_version
      GROUP BY knowledge_document_id, source_document_version_id HAVING count(*) > 1
    ) duplicates) +
    (SELECT count(*) FROM knowledge_document_version version
      JOIN knowledge_document document ON document.id=version.knowledge_document_id
      WHERE version.source_app<>document.source_app
         OR version.source_document_id<>document.source_document_id
         OR version.dataset_key<>document.dataset_key) +
    (SELECT count(*) FROM knowledge_document_version
      WHERE status='indexed' AND (
        provider='' OR provider_dataset_id='' OR provider_document_id=''
      )) AS failures
)
SELECT jsonb_build_object(
  'head', (SELECT version_num FROM alembic_version LIMIT 1),
  'counts', (SELECT jsonb_object_agg(tablename,row_count ORDER BY tablename) FROM counts),
  'invariant_failures', (SELECT failures FROM invariants),
  'not_valid_constraints', (SELECT count(*) FROM pg_constraint
    WHERE connamespace='public'::regnamespace AND NOT convalidated),
  'database_owner', (SELECT pg_get_userbyid(datdba) FROM pg_database
    WHERE datname=current_database()),
  'table_owners', (SELECT jsonb_object_agg(tablename,tableowner ORDER BY tablename)
    FROM pg_tables WHERE schemaname='public'),
  'indexed_bindings', (SELECT count(*) FROM knowledge_document_version
    WHERE status='indexed' AND provider='ragflow'
      AND provider_dataset_id<>'' AND provider_document_id<>'')
);
"""
    shell = r'''psql_bin=/opt/bitnami/postgresql/bin/psql
export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
exec "$psql_bin" -U postgres -d knowledge_admin -X -v ON_ERROR_STOP=1 -At -c "$1"'''
    result = kubectl.run(
        "exec",
        "--quiet",
        "-n",
        "data-platform-dev",
        "postgresql-sunmoonai-0",
        "--",
        "sh",
        "-lc",
        shell,
        "sh",
        sql,
    )
    return json.loads(result.stdout.strip())


def probe_connectivity(
    kubectl: common.Kubectl,
    *,
    deployment: str,
    role: str,
    host: str,
    port: int,
    expectation: str,
) -> dict[str, Any]:
    program = (
        "import sys; "
        f"sys.argv=['probe',{host!r},{str(port)!r},{expectation!r}]; " + CONNECT_PROGRAM
    )
    return common.run_probe_pod(
        kubectl,
        source_kind="deployment",
        source_name=deployment,
        role=role,
        program=program,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", required=True, type=Path)
    parser.add_argument("--kubeconfig", default=str(Path.home() / ".kube/kind-config"))
    parser.add_argument("--namespace", default="app-platform-dev")
    args = parser.parse_args()
    release = json.loads((args.bundle / "release.json").read_text())
    common.require(release["namespace"] == args.namespace, "bundle namespace mismatch")
    kubectl = common.Kubectl(args.kubeconfig, args.namespace)

    deployments: dict[str, dict[str, Any]] = {}
    for name, replicas in EXPECTED_REPLICAS.items():
        item = kubectl.get_json("deployment", name)
        deployments[name] = item
        common.require(
            item["spec"].get("replicas", 0) == replicas, f"{name} replica drift"
        )
        common.require(
            item.get("status", {}).get("readyReplicas", 0) == replicas,
            f"{name} not ready",
        )

    backend_image = release["images"]["backend"]
    for name in (
        "knowledge-r5-backend-api",
        "knowledge-r5-backend-worker",
        "knowledge-r5-backend-scheduler",
    ):
        spec = deployments[name]["spec"]["template"]["spec"]["containers"][0]
        common.require(spec["image"] == backend_image, f"{name} image drift")
        common.require(
            common.env_secret_ref(spec, "DATABASE_URL")
            == ("knowledge-backend-postgresql-conn", "DATABASE_URL"),
            f"{name} database identity drift",
        )

    api_refs = common.container_secret_refs(
        deployments["knowledge-r5-backend-api"]["spec"]["template"]["spec"][
            "containers"
        ][0]
    )
    worker_refs = common.container_secret_refs(
        deployments["knowledge-r5-backend-worker"]["spec"]["template"]["spec"][
            "containers"
        ][0]
    )
    scheduler_refs = common.container_secret_refs(
        deployments["knowledge-r5-backend-scheduler"]["spec"]["template"]["spec"][
            "containers"
        ][0]
    )
    common.require(
        "knowledge-r5-browser-identity" in api_refs, "API lacks browser identity"
    )
    common.require(
        "knowledge-admin-backend-s3" in worker_refs, "Worker lacks Artifact identity"
    )
    common.require(
        "knowledge-admin-backend-s3" not in api_refs, "API inherited Artifact identity"
    )
    common.require(
        "knowledge-admin-backend-s3" not in scheduler_refs,
        "Scheduler inherited Artifact identity",
    )
    common.require(
        "knowledge-admin-backend-secret" in api_refs, "API lacks Provider identity"
    )
    common.require(
        "knowledge-admin-backend-secret" in worker_refs,
        "Worker lacks Provider identity",
    )
    common.require(
        "knowledge-admin-backend-secret" not in scheduler_refs,
        "Scheduler inherited Provider identity",
    )

    migration_name = f"knowledge-r5-backend-migration-{release['release_id']}"
    migration_documents = list(
        yaml.safe_load_all((args.bundle / "10-migration.yaml").read_text())
    )
    migration = next(
        item
        for item in migration_documents
        if item
        and item.get("kind") == "Job"
        and item["metadata"]["name"] == migration_name
    )
    migration_container = migration["spec"]["template"]["spec"]["containers"][0]
    common.require(
        migration_container["image"] == backend_image, "migration image drift"
    )
    common.require(
        common.env_secret_ref(migration_container, "MIGRATION_DATABASE_URL")
        == ("knowledge-backend-migration-postgresql-conn", "MIGRATION_DATABASE_URL"),
        "migration identity drift",
    )
    migration_live = kubectl.run(
        "get", "job", migration_name, "-n", args.namespace, check=False
    )
    common.require(
        migration_live.returncode != 0, "candidate executed formal migration"
    )

    legacy = {}
    for name, expected in V1.items():
        item = kubectl.get_json("deployment", name)
        spec = item["spec"]
        image = spec["template"]["spec"]["containers"][0]["image"]
        common.require(
            spec.get("replicas") == expected["replicas"], f"v1 replica drift: {name}"
        )
        common.require(image == expected["image"], f"v1 image drift: {name}")
        legacy[name] = {"replicas": spec.get("replicas"), "image_unchanged": True}

    principals: dict[str, dict[str, Any]] = {}
    for role, kind, name, expected in (
        (
            "worker",
            "deployment",
            "knowledge-r5-backend-worker",
            "knowledge_backend_user",
        ),
        (
            "scheduler",
            "deployment",
            "knowledge-r5-backend-scheduler",
            "knowledge_backend_user",
        ),
        ("migration", "job", migration_name, "knowledge_backend_user_migration"),
    ):
        principals[role] = common.run_probe_pod(
            kubectl,
            source_kind=kind,
            source_name=name,
            role=role,
            program=common.PRINCIPAL_PROGRAM,
            source_object=migration if role == "migration" else None,
        )
        common.require(
            principals[role].get("principal") == expected, f"{role} principal drift"
        )
        common.require(
            principals[role].get("database") == "knowledge_admin",
            f"{role} database drift",
        )
        common.require(
            principals[role].get("head") == "20260715_0003", f"{role} head drift"
        )

    api_pods = json.loads(
        kubectl.run(
            "get",
            "pods",
            "-n",
            args.namespace,
            "-l",
            "sunmoonai.com/app=knowledge-r5,app.kubernetes.io/component=backend-api",
            "-o",
            "json",
        ).stdout
    )["items"]
    common.require(bool(api_pods), "API Pod absent")
    api_probe = kubectl.run(
        "exec",
        "-n",
        args.namespace,
        api_pods[0]["metadata"]["name"],
        "--",
        "/app/.venv/bin/python",
        "-c",
        common.PRINCIPAL_PROGRAM,
    ).stdout.strip()
    principals["api"] = json.loads(api_probe.splitlines()[-1])
    common.require(
        principals["api"].get("principal") == "knowledge_backend_user",
        "API principal drift",
    )

    policy_runtime = common.network_policy_runtime(kubectl)
    connectivity: dict[str, Any]
    if policy_runtime["enforced"]:
        connectivity = {
            "api_ragflow": probe_connectivity(
                kubectl,
                deployment="knowledge-r5-backend-api",
                role="api-ragflow",
                host="ragflow-sunmoonai-api",
                port=80,
                expectation="allow",
            ),
            "worker_ragflow": probe_connectivity(
                kubectl,
                deployment="knowledge-r5-backend-worker",
                role="worker-ragflow",
                host="ragflow-sunmoonai-api",
                port=80,
                expectation="allow",
            ),
            "scheduler_ragflow": probe_connectivity(
                kubectl,
                deployment="knowledge-r5-backend-scheduler",
                role="scheduler-ragflow",
                host="ragflow-sunmoonai-api",
                port=80,
                expectation="deny",
            ),
            "api_s3": probe_connectivity(
                kubectl,
                deployment="knowledge-r5-backend-api",
                role="api-s3",
                host="minio.data-platform-dev.svc.cluster.local",
                port=80,
                expectation="deny",
            ),
            "worker_s3": probe_connectivity(
                kubectl,
                deployment="knowledge-r5-backend-worker",
                role="worker-s3",
                host="minio.data-platform-dev.svc.cluster.local",
                port=80,
                expectation="allow",
            ),
        }
    else:
        connectivity = {"verified": False, "reason": policy_runtime["limitation"]}

    database = query_database(kubectl)
    common.require(
        database.get("head") == "20260715_0003", "candidate changed database head"
    )
    common.require(
        database.get("counts") == EXPECTED_COUNTS, "database row-count drift"
    )
    common.require(
        database.get("invariant_failures") == 0, "business invariant failure"
    )
    common.require(
        database.get("not_valid_constraints") == 0, "unvalidated constraint present"
    )
    common.require(database.get("indexed_bindings") == 1, "Provider binding drift")

    print(
        json.dumps(
            {
                "task": "R5-K3-knowledge-candidate-runtime",
                "result": "passed",
                "release_id": release["release_id"],
                "replicas": EXPECTED_REPLICAS,
                "candidate_async_writers": 0,
                "migration_applied": False,
                "database": database,
                "principals": principals,
                "connectivity": connectivity,
                "network_policy_runtime": policy_runtime,
                "legacy": legacy,
                "ragflow_mutated": False,
                "credentials_printed": False,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        common.GateError,
        subprocess.CalledProcessError,
        json.JSONDecodeError,
    ) as exc:
        print(
            json.dumps(
                {
                    "task": "R5-K3-knowledge-candidate-runtime",
                    "result": "failed",
                    "error": str(exc),
                    "credentials_printed": False,
                }
            ),
            file=sys.stderr,
        )
        raise SystemExit(1)
