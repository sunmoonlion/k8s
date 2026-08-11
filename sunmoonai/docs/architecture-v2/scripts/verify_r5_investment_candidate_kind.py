#!/usr/bin/env python3
"""Deep runtime gate for the zero-extra-writer Investment R5 candidate."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml

import verify_r5_info_candidate_kind as common

REPLICAS_CANDIDATE = {
    "investment-r5-backend-api": 2,
    "investment-r5-backend-worker": 0,
    "investment-r5-backend-scheduler": 0,
    "investment-r5-admin-frontend": 2,
    "investment-r5-web-frontend": 2,
}
LEGACY = (
    "research-admin-backend", "celeryworker-research-admin-backend",
    "research-admin-frontend", "research-web-backend",
    "nodebullworker-research-web-backend", "research-web-frontend",
)
COUNTS = {
    "auth_user": 2, "agent_runs": 28, "checkpoints": 160,
    "agent_sessions": 29, "session_events": 278, "checkpoint_blobs": 40,
    "checkpoint_writes": 363, "tool_side_effects": 21,
    "checkpoint_migrations": 10, "agent_pilot_requests": 0,
    "agent_pilot_controls": 0, "outbox_message": 0, "inbox_message": 0,
}
PRINCIPAL_PROGRAM = r"""
import asyncio, json
from sqlalchemy import text
from app.infrastructure.storage.postgres import get_postgres

async def main():
    postgres=get_postgres(); await postgres.init()
    try:
        async with postgres.session_factory() as session:
            row=(await session.execute(text("SELECT current_user,current_database(),(SELECT version_num FROM alembic_version LIMIT 1)"))).one()
            print(json.dumps({"principal":row[0],"database":row[1],"head":row[2]}))
    finally:
        await postgres.shutdown()
asyncio.run(main())
""".strip()
IDENTITY_PROGRAM = r"""
import asyncio, json
import httpx
from app.infrastructure.external.knowledge_retrieval import RetrievalServiceTokenProvider
from core.config import get_settings

async def main():
    settings=get_settings(); token=await RetrievalServiceTokenProvider(settings).get_token()
    async with httpx.AsyncClient(timeout=20) as client:
        response=await client.post(settings.knowledge_retrieval_url,json={},headers={"Authorization":f"Bearer {token}","Accept":"application/json"})
    print(json.dumps({"status":response.status_code,"token_printed":False}))
asyncio.run(main())
""".strip()


def parse_args() -> argparse.Namespace:
    parser=argparse.ArgumentParser()
    parser.add_argument("--bundle",required=True,type=Path)
    parser.add_argument("--kubeconfig",default=str(Path.home()/".kube/kind-config"))
    parser.add_argument("--namespace",default="app-platform-dev")
    parser.add_argument("--mode",choices=("candidate","formal"),default="candidate")
    parser.add_argument("--baseline",type=Path,default=Path(__file__).parents[1]/"evidence/R5-investment-baseline/legacy-research-topology.json")
    return parser.parse_args()


def baseline(path: Path) -> dict[str, dict[str, Any]]:
    items=json.loads(path.read_text())["items"]
    return {item["metadata"]["name"]:{
        "replicas":item["spec"].get("replicas",1),
        "image":item["spec"]["template"]["spec"]["containers"][0]["image"],
    } for item in items if item.get("kind")=="Deployment"}


def query_database(k: common.Kubectl) -> dict[str, Any]:
    table_values=", ".join(f"('{name}')" for name in COUNTS)
    sql=f"""
WITH expected(tablename) AS (VALUES {table_values}), counts AS (
 SELECT tablename,((xpath('/row/count/text()',query_to_xml(format('SELECT count(*) AS count FROM public.%I',tablename),false,true,'')))[1]::text)::bigint AS row_count FROM expected
), invariants AS (
 SELECT
  (SELECT count(*) FROM agent_runs r LEFT JOIN agent_sessions s ON s.id=r.session_id WHERE s.id IS NULL)+
  (SELECT count(*) FROM session_events e LEFT JOIN agent_sessions s ON s.id=e.session_id WHERE s.id IS NULL)+
  (SELECT count(*) FROM tool_side_effects e LEFT JOIN agent_runs r ON r.id=e.run_id WHERE r.id IS NULL)+
  (SELECT count(*) FROM (SELECT issuer,subject FROM auth_user GROUP BY issuer,subject HAVING count(*)>1)x)+
  (SELECT count(*) FROM (SELECT session_id,sequence_no FROM session_events GROUP BY session_id,sequence_no HAVING count(*)>1)x)+
  (SELECT count(*) FROM (SELECT session_id,idempotency_key FROM agent_runs WHERE idempotency_key IS NOT NULL GROUP BY session_id,idempotency_key HAVING count(*)>1)x) AS failures
)
SELECT jsonb_build_object(
 'head',(SELECT version_num FROM alembic_version LIMIT 1),
 'counts',(SELECT jsonb_object_agg(tablename,row_count ORDER BY tablename) FROM counts),
 'invariant_failures',(SELECT failures FROM invariants),
 'not_valid_constraints',(SELECT count(*) FROM pg_constraint WHERE connamespace='public'::regnamespace AND NOT convalidated),
 'database_owner',(SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname=current_database()),
 'table_owners',(SELECT jsonb_object_agg(tableowner,n) FROM (SELECT tableowner,count(*) n FROM pg_tables WHERE schemaname='public' GROUP BY tableowner)o)
);"""
    shell=r'''export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"; exec /opt/bitnami/postgresql/bin/psql -U postgres -d investment_admin -X -v ON_ERROR_STOP=1 -At -c "$1"'''
    result=k.run("exec","--quiet","-n","data-platform-dev","postgresql-sunmoonai-0","--","sh","-lc",shell,"sh",sql)
    return json.loads(result.stdout.strip())


def role_state(k: common.Kubectl) -> dict[str, bool]:
    sql="SELECT jsonb_object_agg(rolname,rolcanlogin ORDER BY rolname) FROM pg_roles WHERE rolname IN ('investment_backend_user','investment_backend_user_migration','research_admin_user','research_admin_user_migration','research_web_user','investment_admin_user','investment_web_user');"
    shell=r'''export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"; exec /opt/bitnami/postgresql/bin/psql -U postgres -d postgres -X -v ON_ERROR_STOP=1 -At -c "$1"'''
    return json.loads(k.run("exec","--quiet","-n","data-platform-dev","postgresql-sunmoonai-0","--","sh","-lc",shell,"sh",sql).stdout.strip())


def main() -> int:
    args=parse_args(); release=json.loads((args.bundle/"release.json").read_text())
    common.require(release["logical_app"]=="investment","release identity drift")
    k=common.Kubectl(args.kubeconfig,args.namespace)
    replicas=dict(REPLICAS_CANDIDATE)
    if args.mode=="formal":
        replicas["investment-r5-backend-worker"]=1
        replicas["investment-r5-backend-scheduler"]=1
    live: dict[str,dict[str,Any]]={}
    for name,count in replicas.items():
        item=k.get_json("deployment",name); live[name]=item
        common.require(item["spec"].get("replicas",0)==count,f"replica drift: {name}")
        common.require(item.get("status",{}).get("readyReplicas",0)==count,f"not ready: {name}")
    for name in ("investment-r5-backend-api","investment-r5-backend-worker","investment-r5-backend-scheduler"):
        c=live[name]["spec"]["template"]["spec"]["containers"][0]
        common.require(c["image"]==release["images"]["backend"],f"image drift: {name}")
        common.require(common.env_secret_ref(c,"DATABASE_URL")==('investment-backend-postgresql-conn','DATABASE_URL'),f"DB identity drift: {name}")
    api_refs=common.container_secret_refs(live["investment-r5-backend-api"]["spec"]["template"]["spec"]["containers"][0])
    worker_refs=common.container_secret_refs(live["investment-r5-backend-worker"]["spec"]["template"]["spec"]["containers"][0])
    scheduler_refs=common.container_secret_refs(live["investment-r5-backend-scheduler"]["spec"]["template"]["spec"]["containers"][0])
    common.require("investment-knowledge-retrieval-client" in worker_refs,"Worker lacks retrieval identity")
    common.require("investment-knowledge-retrieval-client" not in api_refs,"API inherited retrieval identity")
    common.require("investment-knowledge-retrieval-client" not in scheduler_refs,"Scheduler inherited retrieval identity")

    migration_name=f"investment-r5-backend-migration-{release['release_id']}"
    result=k.run("get","job",migration_name,"-n",args.namespace,"-o","json",check=False)
    migration_documents=[item for item in yaml.safe_load_all((args.bundle/"10-migration.yaml").read_text()) if item]
    declared_migrations=[item for item in migration_documents if item.get("kind")=="Job" and item.get("metadata",{}).get("name")==migration_name]
    common.require(len(declared_migrations)==1,"declared migration Job drift")
    if result.returncode==0:
        migration=json.loads(result.stdout)
        common.require(migration.get("status",{}).get("succeeded")==1,"migration did not succeed")
        migration_job_cleaned=False
    else:
        common.require(args.mode=="formal","migration Job absent")
        migration=declared_migrations[0]
        migration_job_cleaned=True
    mc=migration["spec"]["template"]["spec"]["containers"][0]
    common.require(common.env_secret_ref(mc,"MIGRATION_DATABASE_URL")==('investment-backend-migration-postgresql-conn','MIGRATION_DATABASE_URL'),"migration identity drift")

    expected_legacy=baseline(args.baseline); observed_legacy={}
    for name in LEGACY:
        item=k.get_json("deployment",name); image=item["spec"]["template"]["spec"]["containers"][0]["image"]
        expected_count=expected_legacy[name]["replicas"] if args.mode=="candidate" else 0
        common.require(item["spec"].get("replicas",0)==expected_count,f"legacy replica drift: {name}")
        common.require(image==expected_legacy[name]["image"],f"legacy image drift: {name}")
        observed_legacy[name]={"replicas":item["spec"].get("replicas",0),"image_unchanged":True}

    principals={}
    for role,kind,name,expected in (
        ("worker","deployment","investment-r5-backend-worker","investment_backend_user"),
        ("scheduler","deployment","investment-r5-backend-scheduler","investment_backend_user"),
        ("migration","job",migration_name,"investment_backend_user_migration"),
    ):
        principals[role]=common.run_probe_pod(k,source_kind=kind,source_name=name,role=f"investment-{role}",program=PRINCIPAL_PROGRAM,source_object=migration if role=="migration" else None)
        common.require(principals[role]=={"principal":expected,"database":"investment_admin","head":"20260809_0004"},f"principal drift: {role}")
    api_pods=json.loads(k.run("get","pods","-n",args.namespace,"-l","sunmoonai.com/app=investment-r5,app.kubernetes.io/component=backend-api","-o","json").stdout)["items"]
    common.require(bool(api_pods),"API Pod absent")
    raw=k.run("exec","-n",args.namespace,api_pods[0]["metadata"]["name"],"--","/app/.venv/bin/python","-c",PRINCIPAL_PROGRAM).stdout.strip()
    principals["api"]=json.loads(raw.splitlines()[-1])
    common.require(principals["api"]=={"principal":"investment_backend_user","database":"investment_admin","head":"20260809_0004"},"API principal drift")

    identity=common.run_probe_pod(k,source_kind="deployment",source_name="investment-r5-backend-worker",role="investment-retrieval-identity",program=IDENTITY_PROGRAM)
    common.require(identity=={"status":422,"token_printed":False},"Investment service identity did not reach Knowledge validation")
    database=query_database(k)
    common.require(database["head"]=="20260809_0004","database head drift")
    common.require(database["counts"]==COUNTS,"database row-count drift")
    common.require(database["invariant_failures"]==0,"business invariant failure")
    common.require(database["not_valid_constraints"]==0,"unvalidated constraint present")
    common.require(database["database_owner"]=="investment_backend_user_migration","database owner drift")
    common.require(set(database["table_owners"].keys())=={"investment_backend_user_migration"},"table owner drift")
    roles=role_state(k)
    if args.mode=="formal":
        common.require(roles=={
            "investment_admin_user":False,"investment_backend_user":True,
            "investment_backend_user_migration":True,"investment_web_user":False,
            "research_admin_user":False,"research_admin_user_migration":False,
            "research_web_user":False,
        },"formal database role state drift")
        routes={
            "investment-admin-frontend-ingress":[("investment-r5-backend",8000),("investment-r5-admin-frontend",3000)],
            "investment-web-frontend-ingress":[("investment-r5-backend",8000),("investment-r5-web-frontend",3000)],
            "investment-admin-backend-ingress":[("investment-r5-backend",8000)],
            "investment-web-backend-ingress":[("investment-r5-backend",8000)],
        }
        for name,expected in routes.items():
            route=k.get_json("ingressroute",name)
            observed=[(r["services"][0]["name"],r["services"][0]["port"]) for r in route["spec"]["routes"]]
            common.require(observed==expected,f"formal route drift: {name}")
            common.require(route["spec"].get("tls",{}).get("secretName")=="investment-r5-tls",f"formal TLS drift: {name}")
    policy=common.network_policy_runtime(k)
    task="R5-V3-investment-candidate-runtime" if args.mode=="candidate" else "R5-V4-investment-formal-runtime"
    print(json.dumps({"task":task,"result":"passed","release_id":release["release_id"],"replicas":replicas,"async_writers_enabled":args.mode=="formal","single_writer":args.mode=="formal","migration_job_cleaned":migration_job_cleaned,"database":database,"database_roles":roles,"principals":principals,"worker_service_identity":identity,"legacy_research":observed_legacy,"network_policy_runtime":policy,"network_policy_packet_gate":"required-separately-on-calico","credentials_printed":False},indent=2,sort_keys=True))
    return 0


if __name__=="__main__":
    try: raise SystemExit(main())
    except (common.GateError,subprocess.CalledProcessError,json.JSONDecodeError,KeyError,yaml.YAMLError) as exc:
        print(json.dumps({"task":"R5-V3-investment-candidate-runtime","result":"failed","error":str(exc),"credentials_printed":False}),file=sys.stderr)
        raise SystemExit(1)
