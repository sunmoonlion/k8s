#!/usr/bin/env python3
"""Verify the reversible Knowledge R5 rollback state without downgrading data."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import verify_r5_info_candidate_kind as common
import verify_r5_knowledge_candidate_kind as candidate
import verify_r5_knowledge_formal_kind as formal


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kubeconfig", default=str(Path.home() / ".kube/kind-config"))
    parser.add_argument("--namespace", default="app-platform-dev")
    args = parser.parse_args()
    common.require(args.namespace == "app-platform-dev", "rollback namespace mismatch")
    kubectl = common.Kubectl(args.kubeconfig, args.namespace)

    expected = {
        "knowledge-admin-backend": 1,
        "celeryworker-knowledge-admin-backend": 1,
        "knowledge-r5-backend-api": 0,
        "knowledge-r5-backend-worker": 0,
        "knowledge-r5-backend-scheduler": 0,
        "knowledge-r5-admin-frontend": 2,
        "knowledge-r5-web-frontend": 2,
    }
    for name, replicas in expected.items():
        item = kubectl.get_json("deployment", name)
        common.require(item["spec"].get("replicas", 0) == replicas, f"{name} replica drift")
        common.require(item.get("status", {}).get("readyReplicas", 0) == replicas, f"{name} not ready")

    database = candidate.query_database(kubectl)
    common.require(database.get("head") == "20260808_0004", "rollback downgraded migration")
    common.require(database.get("counts") == candidate.EXPECTED_COUNTS, "rollback row-count drift")
    common.require(database.get("invariant_failures") == 0, "rollback invariant failure")
    common.require(database.get("indexed_bindings") == 1, "rollback Provider binding drift")
    common.require(database.get("database_owner") == "knowledge_admin_user_migration", "legacy owner not restored")
    common.require(
        set(database.get("table_owners", {}).values()) == {"knowledge_admin_user_migration"},
        "legacy table owners not restored",
    )
    roles = formal.query_role_state(kubectl)
    common.require(roles == {
        "knowledge_admin_user": True,
        "knowledge_admin_user_migration": True,
        "knowledge_backend_user": False,
        "knowledge_backend_user_migration": False,
    }, "rollback role state drift")

    route = kubectl.get_json("ingressroute", "knowledge-admin-backend-ingress")
    services = route["spec"]["routes"][0]["services"]
    common.require(services == [{"name": "knowledge-admin-backend", "port": 8000}], "legacy ingress not restored")
    for name in ("knowledge-admin-frontend-ingress", "knowledge-web-frontend-ingress"):
        absent = kubectl.run("get", "ingressroute", name, "-n", args.namespace, check=False)
        common.require(absent.returncode != 0, f"formal ingress remained after rollback: {name}")

    queue = formal.queue_state(kubectl)
    print(json.dumps({
        "task": "R5-K5-knowledge-rollback-runtime",
        "result": "passed",
        "replicas": expected,
        "database": database,
        "database_roles": roles,
        "queue": queue,
        "migration_retained": "20260808_0004",
        "v1_assets_deleted": False,
        "ragflow_mutated": False,
        "credentials_printed": False,
    }, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (common.GateError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(json.dumps({
            "task": "R5-K5-knowledge-rollback-runtime",
            "result": "failed",
            "error": str(exc),
            "credentials_printed": False,
        }), file=sys.stderr)
        raise SystemExit(1)
