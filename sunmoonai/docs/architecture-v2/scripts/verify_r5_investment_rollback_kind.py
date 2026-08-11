#!/usr/bin/env python3
"""Verify native Research rollback while retaining the migrated Investment target."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import verify_r5_info_candidate_kind as common
import verify_r5_investment_candidate_kind as investment


def query_source(kubectl: common.Kubectl) -> dict[str, object]:
    tables = (
        "auth_user", "agent_runs", "checkpoints", "agent_sessions",
        "session_events", "checkpoint_blobs", "checkpoint_writes",
        "tool_side_effects", "checkpoint_migrations",
    )
    values = ",".join(f"('{name}')" for name in tables)
    sql = f"""
WITH expected(tablename) AS (VALUES {values}), counts AS (
 SELECT tablename,((xpath('/row/count/text()',query_to_xml(format('SELECT count(*) AS count FROM public.%I',tablename),false,true,'')))[1]::text)::bigint AS row_count FROM expected
), invariants AS (
 SELECT
  (SELECT count(*) FROM agent_runs r LEFT JOIN agent_sessions s ON s.id=r.session_id WHERE s.id IS NULL)+
  (SELECT count(*) FROM session_events e LEFT JOIN agent_sessions s ON s.id=e.session_id WHERE s.id IS NULL)+
  (SELECT count(*) FROM tool_side_effects e LEFT JOIN agent_runs r ON r.id=e.run_id WHERE r.id IS NULL) AS failures
)
SELECT jsonb_build_object(
 'head',(SELECT version_num FROM alembic_version LIMIT 1),
 'counts',(SELECT jsonb_object_agg(tablename,row_count ORDER BY tablename) FROM counts),
 'invariant_failures',(SELECT failures FROM invariants),
 'database_owner',(SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname=current_database())
);"""
    shell = r'''export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"; exec /opt/bitnami/postgresql/bin/psql -U postgres -d research_admin -X -v ON_ERROR_STOP=1 -At -c "$1"'''
    result = kubectl.run(
        "exec", "--quiet", "-n", "data-platform-dev", "postgresql-sunmoonai-0",
        "--", "sh", "-lc", shell, "sh", sql,
    )
    return json.loads(result.stdout.strip())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kubeconfig", default=str(Path.home() / ".kube/kind-config"))
    parser.add_argument("--namespace", default="app-platform-dev")
    args = parser.parse_args()
    common.require(args.namespace == "app-platform-dev", "rollback namespace mismatch")
    kubectl = common.Kubectl(args.kubeconfig, args.namespace)

    expected = {
        **{name: 1 for name in investment.LEGACY},
        "investment-r5-backend-api": 0,
        "investment-r5-backend-worker": 0,
        "investment-r5-backend-scheduler": 0,
        "investment-r5-admin-frontend": 2,
        "investment-r5-web-frontend": 2,
    }
    for name, replicas in expected.items():
        item = kubectl.get_json("deployment", name)
        common.require(item["spec"].get("replicas", 0) == replicas, f"{name} replica drift")
        common.require(item.get("status", {}).get("readyReplicas", 0) == replicas, f"{name} not ready")

    source = query_source(kubectl)
    source_expected = {key: value for key, value in investment.COUNTS.items() if key not in {
        "agent_pilot_requests", "agent_pilot_controls", "outbox_message", "inbox_message",
    }}
    common.require(source["head"] == "20260712_0002", "source migration drift")
    common.require(source["counts"] == source_expected, "source row-count drift")
    common.require(source["invariant_failures"] == 0, "source invariant failure")
    common.require(source["database_owner"] == "research_admin_user_migration", "source owner drift")

    target = investment.query_database(kubectl)
    common.require(target["head"] == "20260809_0004", "rollback downgraded target")
    common.require(target["counts"] == investment.COUNTS, "retained target row-count drift")
    common.require(target["invariant_failures"] == 0, "retained target invariant failure")
    roles = investment.role_state(kubectl)
    common.require(roles == {
        "investment_admin_user": True,
        "investment_backend_user": False,
        "investment_backend_user_migration": False,
        "investment_web_user": True,
        "research_admin_user": True,
        "research_admin_user_migration": True,
        "research_web_user": True,
    }, "rollback role state drift")

    for name in (
        "investment-admin-frontend-ingress", "investment-web-frontend-ingress",
        "investment-admin-backend-ingress", "investment-web-backend-ingress",
    ):
        common.require(
            kubectl.run("get", "ingressroute", name, "-n", args.namespace, check=False).returncode != 0,
            f"formal ingress remained after rollback: {name}",
        )
    for name in (
        "research-admin-backend-ingress", "research-admin-frontend-ingress",
        "research-web-backend-ingress", "research-web-frontend-ingress",
    ):
        kubectl.get_json("ingressroute", name)

    print(json.dumps({
        "task": "R5-V5-investment-rollback-runtime",
        "result": "passed",
        "replicas": expected,
        "source_database": source,
        "retained_target": target,
        "database_roles": roles,
        "target_migration_retained": "20260809_0004",
        "source_database_mutated": False,
        "legacy_assets_deleted": False,
        "credentials_printed": False,
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (common.GateError, subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as exc:
        print(json.dumps({
            "task": "R5-V5-investment-rollback-runtime",
            "result": "failed",
            "error": str(exc),
            "credentials_printed": False,
        }), file=sys.stderr)
        raise SystemExit(1)
