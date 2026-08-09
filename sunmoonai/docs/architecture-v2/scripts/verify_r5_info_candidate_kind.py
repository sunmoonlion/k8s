#!/usr/bin/env python3
"""Fail-closed runtime gate for the non-writing Info R5 candidate.

The gate never prints Secret values.  Worker, scheduler and migration database
principals are checked with short-lived read-only probe Pods cloned from the
deployed workload specifications; candidate async writers remain scaled to 0.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import uuid
from copy import deepcopy
from pathlib import Path
from typing import Any

import yaml


EXPECTED_REPLICAS_BY_MODE = {
    "candidate": {
        "info-r5-backend-api": 2,
        "info-r5-backend-worker": 0,
        "info-r5-backend-scheduler": 0,
        "info-r5-admin-frontend": 2,
        "info-r5-web-frontend": 2,
    },
    "formal": {
        "info-r5-backend-api": 2,
        "info-r5-backend-worker": 1,
        "info-r5-backend-scheduler": 1,
        "info-r5-admin-frontend": 2,
        "info-r5-web-frontend": 2,
    },
}
V1_DEPLOYMENTS = (
    "info-admin-backend",
    "celeryworker-info-admin-backend",
    "info-admin-frontend",
    "info-web-backend",
    "nodebullworker-info-web-backend",
    "info-web-frontend",
)
EXPECTED_COUNTS = {
    "auth_user": 1,
    "crawl_job": 25,
    "delivery_outbox_message": 16,
    "distribution_record": 22,
    "extracted_content": 30,
    "inbox_message": 0,
    "info_collector": 1,
    "info_document": 8,
    "info_document_version": 16,
    "info_source": 7,
    "outbox_message": 0,
    "raw_artifact": 56,
}
PRINCIPAL_PROGRAM = r"""
import asyncio, json
from sqlalchemy import text
from app.infrastructure.storage.postgres import get_postgres

async def main():
    postgres = get_postgres()
    await postgres.init()
    try:
        async with postgres.session_factory() as session:
            row = (await session.execute(text(
                "SELECT current_user, current_database(), "
                "(SELECT version_num FROM alembic_version LIMIT 1)"
            ))).one()
            print(json.dumps({"principal": row[0], "database": row[1], "head": row[2]}))
    finally:
        await postgres.shutdown()

asyncio.run(main())
""".strip()
WORKER_IDENTITY_PROGRAM = r"""
import asyncio, json
import httpx
from app.infrastructure.external.knowledge_app import ServiceTokenProvider
from core.config import get_settings

async def main():
    settings = get_settings()
    provider = ServiceTokenProvider(settings)
    token = await provider.get_token()
    async with httpx.AsyncClient(timeout=settings.knowledge_app_timeout_seconds) as client:
        response = await client.post(
            settings.knowledge_app_ingest_url,
            json={},
            headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
        )
    print(json.dumps({"status": response.status_code, "token_printed": False}))

asyncio.run(main())
""".strip()
DENIED_EGRESS_PROGRAM = r"""
import json, socket

try:
    connection = socket.create_connection(("knowledge-admin-backend", 8000), timeout=5)
    connection.close()
except (TimeoutError, OSError):
    print(json.dumps({"denied": True}))
else:
    print(json.dumps({"denied": False}))
""".strip()


class GateError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--kubeconfig", default=str(Path.home() / ".kube/kind-config"))
    parser.add_argument("--namespace", default="app-platform-dev")
    parser.add_argument("--mode", choices=("candidate", "formal"), default="candidate")
    parser.add_argument(
        "--baseline-runtime",
        type=Path,
        default=Path(__file__).parents[1] / "evidence/R5-info-baseline/runtime.txt",
    )
    return parser.parse_args()


class Kubectl:
    def __init__(self, kubeconfig: str, namespace: str):
        self.kubeconfig = kubeconfig
        self.namespace = namespace

    def run(
        self,
        *args: str,
        stdin: str | None = None,
        check: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env.pop("DEBUG", None)
        return subprocess.run(
            [
                "kubectl",
                "--kubeconfig",
                self.kubeconfig,
                "--request-timeout=20s",
                *args,
            ],
            input=stdin,
            text=True,
            capture_output=True,
            check=check,
            env=env,
        )

    def get_json(self, kind: str, name: str) -> dict[str, Any]:
        return json.loads(
            self.run("get", kind, name, "-n", self.namespace, "-o", "json").stdout
        )

    def delete_pod(self, name: str) -> None:
        self.run(
            "delete",
            "pod",
            name,
            "-n",
            self.namespace,
            "--ignore-not-found=true",
            "--wait=true",
            check=False,
        )


def require(condition: bool, message: str) -> None:
    if not condition:
        raise GateError(message)


def container_secret_refs(container: dict[str, Any]) -> set[str]:
    names = {
        item["secretRef"]["name"]
        for item in container.get("envFrom", [])
        if item.get("secretRef", {}).get("name")
    }
    names.update(
        item["valueFrom"]["secretKeyRef"]["name"]
        for item in container.get("env", [])
        if item.get("valueFrom", {}).get("secretKeyRef", {}).get("name")
    )
    return names


def env_secret_ref(container: dict[str, Any], env_name: str) -> tuple[str, str] | None:
    for item in container.get("env", []):
        if item.get("name") != env_name:
            continue
        ref = item.get("valueFrom", {}).get("secretKeyRef")
        if ref:
            return ref.get("name", ""), ref.get("key", "")
    return None


def baseline_deployments(path: Path) -> dict[str, dict[str, Any]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    try:
        position = lines.index("section=deployments")
        deployments = json.loads(lines[position + 1])
    except (ValueError, IndexError, json.JSONDecodeError) as exc:
        raise GateError(f"cannot parse baseline runtime evidence: {path}") from exc
    return {item["name"]: item for item in deployments}


def run_probe_pod(
    kubectl: Kubectl,
    *,
    source_kind: str,
    source_name: str,
    role: str,
    program: str,
    source_object: dict[str, Any] | None = None,
) -> dict[str, Any]:
    source = source_object or kubectl.get_json(source_kind, source_name)
    template = (
        source["spec"]["template"]
        if source_kind == "deployment"
        else source["spec"]["template"]
    )
    name = f"info-r5-principal-{role}-{uuid.uuid4().hex[:8]}"
    pod = {
        "apiVersion": "v1",
        "kind": "Pod",
        "metadata": {
            "name": name,
            "namespace": kubectl.namespace,
            "labels": deepcopy(template.get("metadata", {}).get("labels", {})),
        },
        "spec": deepcopy(template["spec"]),
    }
    pod["metadata"]["labels"]["sunmoonai.com/probe"] = "database-principal"
    spec = pod["spec"]
    spec["restartPolicy"] = "Never"
    spec.pop("terminationGracePeriodSeconds", None)
    require(len(spec["containers"]) == 1, f"{source_name} must have one container")
    container = spec["containers"][0]
    container["command"] = ["/app/.venv/bin/python", "-c"]
    container["args"] = [program]
    container.pop("readinessProbe", None)
    container.pop("livenessProbe", None)
    container.pop("startupProbe", None)
    container.pop("lifecycle", None)
    container.setdefault("env", []).append(
        {"name": "PYTHONDONTWRITEBYTECODE", "value": "1"}
    )

    kubectl.delete_pod(name)
    try:
        kubectl.run("apply", "-f", "-", stdin=json.dumps(pod))
        deadline = time.monotonic() + 120
        phase = ""
        while time.monotonic() < deadline:
            result = kubectl.run(
                "get",
                "pod",
                name,
                "-n",
                kubectl.namespace,
                "-o",
                "jsonpath={.status.phase}",
                check=False,
            )
            phase = result.stdout.strip()
            if phase in {"Succeeded", "Failed"}:
                break
            time.sleep(2)
        logs = kubectl.run(
            "logs", name, "-n", kubectl.namespace, check=False
        ).stdout.strip()
        require(phase == "Succeeded", f"{role} principal probe phase={phase} logs={logs[-500:]}")
        return json.loads(logs.splitlines()[-1])
    finally:
        kubectl.delete_pod(name)


def query_database(kubectl: Kubectl) -> dict[str, Any]:
    sql = """
WITH expected(tablename) AS (
  VALUES ('auth_user'), ('crawl_job'), ('delivery_outbox_message'),
         ('distribution_record'), ('extracted_content'), ('inbox_message'),
         ('info_collector'), ('info_document'), ('info_document_version'),
         ('info_source'), ('outbox_message'), ('raw_artifact')
), counts AS (
  SELECT tablename,
    ((xpath('/row/count/text()', query_to_xml(
      format('SELECT count(*) AS count FROM public.%I', tablename), false, true, ''
    )))[1]::text)::bigint AS row_count
  FROM expected
), invariants AS (
  SELECT
    (SELECT count(*) FROM info_document d LEFT JOIN info_document_version v
      ON v.id=d.current_version_id WHERE d.current_version_id IS NOT NULL AND v.id IS NULL) +
    (SELECT count(*) FROM info_document d JOIN info_document_version v
      ON v.id=d.current_version_id WHERE v.document_id<>d.id) +
    (SELECT count(*) FROM distribution_record r JOIN info_document_version v
      ON v.id=r.document_version_id WHERE v.document_id<>r.document_id) +
    (SELECT count(*) FROM (SELECT document_id,version_no FROM info_document_version
      GROUP BY document_id,version_no HAVING count(*)>1) x) +
    (SELECT count(*) FROM (SELECT issuer,subject FROM auth_user
      GROUP BY issuer,subject HAVING count(*)>1) x) +
    (SELECT count(*) FROM (SELECT topic,idempotency_key FROM delivery_outbox_message
      GROUP BY topic,idempotency_key HAVING count(*)>1) x) +
    (SELECT count(*) FROM raw_artifact WHERE size_bytes<0) +
    (SELECT count(*) FROM extracted_content WHERE size_bytes<0) AS failures
)
SELECT jsonb_build_object(
  'head', (SELECT version_num FROM alembic_version LIMIT 1),
  'counts', (SELECT jsonb_object_agg(tablename,row_count ORDER BY tablename) FROM counts),
  'invariant_failures', (SELECT failures FROM invariants),
  'delivery_states', (SELECT jsonb_object_agg(state,n ORDER BY state)
    FROM (SELECT state,count(*) AS n FROM delivery_outbox_message GROUP BY state) s),
  'not_valid_constraints', (SELECT count(*) FROM pg_constraint
    WHERE connamespace='public'::regnamespace AND NOT convalidated),
  'database_owner', (SELECT pg_get_userbyid(datdba) FROM pg_database
    WHERE datname=current_database()),
  'schema_owner', (SELECT pg_get_userbyid(nspowner) FROM pg_namespace
    WHERE nspname='public'),
  'table_owners', (SELECT jsonb_object_agg(tablename,tableowner ORDER BY tablename)
    FROM pg_tables WHERE schemaname='public'),
  'roles', (SELECT jsonb_object_agg(rolname,rolcanlogin ORDER BY rolname)
    FROM pg_roles WHERE rolname IN (
      'info_admin_user','info_admin_user_migration',
      'info_backend_user','info_backend_user_migration'
    ))
);
"""
    shell = r'''psql_bin=/opt/bitnami/postgresql/bin/psql
export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
exec "$psql_bin" -U postgres -d info_admin -X -v ON_ERROR_STOP=1 -At -c "$1"'''
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


def query_legacy_web_database(kubectl: Kubectl) -> dict[str, Any]:
    sql = """
SELECT jsonb_build_object(
  'database', current_database(),
  'public_tables', (SELECT count(*) FROM pg_tables WHERE schemaname='public'),
  'role_can_login', (SELECT rolcanlogin FROM pg_roles WHERE rolname='info_web_user'),
  'role_can_connect', has_database_privilege('info_web_user','info_web','CONNECT'),
  'role_can_create_schema_objects', has_schema_privilege('info_web_user','public','CREATE')
);
"""
    shell = r'''psql_bin=/opt/bitnami/postgresql/bin/psql
export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"
exec "$psql_bin" -U postgres -d info_web -X -v ON_ERROR_STOP=1 -At -c "$1"'''
    result = kubectl.run(
        "exec", "--quiet", "-n", "data-platform-dev", "postgresql-sunmoonai-0",
        "--", "sh", "-lc", shell, "sh", sql,
    )
    return json.loads(result.stdout.strip())


def network_policy_runtime(kubectl: Kubectl) -> dict[str, Any]:
    daemonsets = json.loads(
        kubectl.run("get", "daemonset", "-n", "kube-system", "-o", "json").stdout
    )["items"]
    names = sorted(item["metadata"]["name"] for item in daemonsets)
    enforcement_cnis = ("calico", "cilium", "antrea", "weave", "kube-router")
    enforced = any(any(token in name.lower() for token in enforcement_cnis) for name in names)
    return {
        "enforced": enforced,
        "detected_daemonsets": names,
        "limitation": None if enforced else "kindnet-does-not-enforce-networkpolicy",
    }


def main() -> int:
    args = parse_args()
    release = json.loads((args.bundle / "release.json").read_text(encoding="utf-8"))
    require(release["namespace"] == args.namespace, "bundle namespace mismatch")
    kubectl = Kubectl(args.kubeconfig, args.namespace)
    expected_replicas = EXPECTED_REPLICAS_BY_MODE[args.mode]

    deployments: dict[str, dict[str, Any]] = {}
    for name, replicas in expected_replicas.items():
        item = kubectl.get_json("deployment", name)
        deployments[name] = item
        require(item["spec"].get("replicas", 0) == replicas, f"{name} replica drift")
        require(item.get("status", {}).get("readyReplicas", 0) == replicas, f"{name} is not ready")

    backend_image = release["images"]["backend"]
    for name in ("info-r5-backend-api", "info-r5-backend-worker", "info-r5-backend-scheduler"):
        container = deployments[name]["spec"]["template"]["spec"]["containers"][0]
        require(container["image"] == backend_image, f"{name} backend image drift")
        require(
            env_secret_ref(container, "DATABASE_URL")
            == ("info-backend-postgresql-conn", "DATABASE_URL"),
            f"{name} runtime database Secret drift",
        )

    api_refs = container_secret_refs(
        deployments["info-r5-backend-api"]["spec"]["template"]["spec"]["containers"][0]
    )
    worker_refs = container_secret_refs(
        deployments["info-r5-backend-worker"]["spec"]["template"]["spec"]["containers"][0]
    )
    scheduler_refs = container_secret_refs(
        deployments["info-r5-backend-scheduler"]["spec"]["template"]["spec"]["containers"][0]
    )
    require("info-knowledge-ingest-client" in worker_refs, "worker lacks downstream identity")
    require("info-knowledge-ingest-client" not in api_refs, "API inherited downstream identity")
    require("info-knowledge-ingest-client" not in scheduler_refs, "scheduler inherited downstream identity")

    migration_name = f"info-r5-backend-migration-{release['release_id']}"
    migration_result = kubectl.run(
        "get", "job", migration_name, "-n", args.namespace, "-o", "json", check=False
    )
    if migration_result.returncode == 0:
        migration = json.loads(migration_result.stdout)
        require(migration.get("status", {}).get("succeeded") == 1, "migration Job did not succeed")
        migration_job_state = "succeeded"
    else:
        migration_documents = list(
            yaml.safe_load_all((args.bundle / "10-migration.yaml").read_text(encoding="utf-8"))
        )
        migration = next(
            item for item in migration_documents
            if item and item.get("kind") == "Job" and item["metadata"]["name"] == migration_name
        )
        migration_job_state = "ttl_expired_after_head_observed"
    migration_spec = migration["spec"]["template"]["spec"]
    migration_container = migration_spec["containers"][0]
    require(migration_container["image"] == backend_image, "migration image drift")
    require(
        env_secret_ref(migration_container, "MIGRATION_DATABASE_URL")
        == ("info-backend-migration-postgresql-conn", "MIGRATION_DATABASE_URL"),
        "migration database Secret drift",
    )

    baseline = baseline_deployments(args.baseline_runtime)
    v1 = {}
    for name in V1_DEPLOYMENTS:
        item = kubectl.get_json("deployment", name)
        current = item["spec"]["template"]["spec"]["containers"][0]["image"]
        expected = baseline[name]["containers"][0]["image"]
        require(current == expected, f"v1 image drift: {name}")
        expected_v1_replicas = baseline[name]["replicas"] if args.mode == "candidate" else 0
        require(item["spec"].get("replicas", 0) == expected_v1_replicas, f"v1 replica drift: {name}")
        v1[name] = {"replicas": item["spec"].get("replicas", 0), "image_unchanged": True}

    principals = {}
    for role, kind, name, expected_principal in (
        ("worker", "deployment", "info-r5-backend-worker", "info_backend_user"),
        ("scheduler", "deployment", "info-r5-backend-scheduler", "info_backend_user"),
        ("migration", "job", migration_name, "info_backend_user_migration"),
    ):
        principals[role] = run_probe_pod(
            kubectl,
            source_kind=kind,
            source_name=name,
            role=role,
            program=PRINCIPAL_PROGRAM,
            source_object=migration if role == "migration" else None,
        )
        require(
            principals[role].get("principal") == expected_principal,
            f"{role} used wrong database principal",
        )
        require(principals[role].get("database") == "info_admin", f"{role} used wrong database")
        require(principals[role].get("head") == "20260809_0005", f"{role} observed wrong Alembic head")
    api_pods = json.loads(
        kubectl.run(
            "get", "pods", "-n", args.namespace,
            "-l", "sunmoonai.com/app=info-r5,app.kubernetes.io/component=backend-api",
            "-o", "json",
        ).stdout
    )["items"]
    require(bool(api_pods), "API Pod absent")
    api_name = api_pods[0]["metadata"]["name"]
    api_probe = kubectl.run(
        "exec", "-n", args.namespace, api_name, "--",
        "/app/.venv/bin/python", "-c", PRINCIPAL_PROGRAM,
    ).stdout.strip()
    principals["api"] = json.loads(api_probe.splitlines()[-1])
    require(principals["api"].get("principal") == "info_backend_user", "API used wrong database principal")

    worker_identity = run_probe_pod(
        kubectl,
        source_kind="deployment",
        source_name="info-r5-backend-worker",
        role="worker-identity",
        program=WORKER_IDENTITY_PROGRAM,
    )
    require(worker_identity.get("status") == 422, "worker service identity did not reach Knowledge validation")
    require(worker_identity.get("token_printed") is False, "worker probe token output policy failed")
    policy_runtime = network_policy_runtime(kubectl)
    denied_egress = {}
    if policy_runtime["enforced"]:
        for role in ("api", "scheduler"):
            denied_egress[role] = run_probe_pod(
                kubectl,
                source_kind="deployment",
                source_name=f"info-r5-backend-{role}",
                role=f"{role}-knowledge-deny",
                program=DENIED_EGRESS_PROGRAM,
            )
            require(denied_egress[role].get("denied") is True, f"{role} could reach Knowledge")
    else:
        denied_egress = {
            "api": {"verified": False, "reason": policy_runtime["limitation"]},
            "scheduler": {"verified": False, "reason": policy_runtime["limitation"]},
        }

    database = query_database(kubectl)
    legacy_web_database = query_legacy_web_database(kubectl)
    require(database.get("head") == "20260809_0005", "database head drift")
    require(database.get("counts") == EXPECTED_COUNTS, "database row-count drift")
    require(database.get("invariant_failures") == 0, "business invariant failure")
    require(database.get("delivery_states") == {"completed": 16}, "delivery state drift")
    require(database.get("not_valid_constraints") == 0, "unvalidated constraint present")
    if args.mode == "formal":
        require(database.get("database_owner") == "info_backend_user_migration", "database owner drift")
        require(database.get("schema_owner") == "info_backend_user_migration", "schema owner drift")
        require(
            set(database.get("table_owners", {}).values()) == {"info_backend_user_migration"},
            "table owner drift",
        )
        require(database.get("roles") == {
            "info_admin_user": False,
            "info_admin_user_migration": False,
            "info_backend_user": True,
            "info_backend_user_migration": True,
        }, "database role login state drift")
        require(legacy_web_database == {
            "database": "info_web",
            "public_tables": 0,
            "role_can_login": False,
            "role_can_connect": False,
            "role_can_create_schema_objects": False,
        }, "legacy info_web role is not sealed")

        expected_routes = {
            "info-admin-frontend-ingress": [
                (100, "info-r5-backend", 8000),
                (10, "info-r5-admin-frontend", 3000),
            ],
            "info-web-frontend-ingress": [
                (100, "info-r5-backend", 8000),
                (10, "info-r5-web-frontend", 3000),
            ],
            "info-admin-backend-ingress": [(None, "info-r5-backend", 8000)],
            "info-web-backend-ingress": [(None, "info-r5-backend", 8000)],
        }
        for route_name, expected in expected_routes.items():
            route = kubectl.get_json("ingressroute", route_name)
            observed = [
                (item.get("priority"), item["services"][0]["name"], item["services"][0]["port"])
                for item in route["spec"]["routes"]
            ]
            require(observed == expected, f"formal IngressRoute drift: {route_name}")
            require(route["spec"].get("tls", {}).get("secretName") == "info-r5-tls", f"TLS Secret drift: {route_name}")

    print(json.dumps({
        "task": "R5-I3-info-candidate-runtime" if args.mode == "candidate" else "R5-I4-info-formal-runtime",
        "result": "passed",
        "release_id": release["release_id"],
        "migration_job_state": migration_job_state,
        "replicas": expected_replicas,
        "async_writers_enabled": args.mode == "formal",
        "single_writer": args.mode == "formal",
        "database": database,
        "legacy_web_database": legacy_web_database,
        "principals": principals,
        "worker_service_identity": worker_identity,
        "knowledge_egress_denied": denied_egress,
        "network_policy_runtime": policy_runtime,
        "production_network_policy_gate_satisfied": policy_runtime["enforced"],
        "worker_only_downstream_identity": True,
        "v1": v1,
        "credentials_printed": False,
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (GateError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(json.dumps({
            "task": "R5-I3-info-candidate-runtime",
            "result": "failed",
            "error": str(exc),
            "credentials_printed": False,
        }), file=sys.stderr)
        raise SystemExit(1)
