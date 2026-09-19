"""Exercise fresh identities and old-login retirement on restored business data.

No kubectl, no live DB connection; only owned network=none disposable PostgreSQL.
Uses the template transaction compiler and the App's reviewed grant overlay.
"""
import argparse
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys

import kind_database_rehearsal as common

WORKSPACE = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(WORKSPACE / "tpl-app/k8s-deployment"))
import runtime_database_cutover as cutover


def probe(container, database, username, password, statement, *, denied=False, login_denied=False):
    result = subprocess.run(["docker", "exec", "-i", "-e", "PGPASSWORD", container,
        "psql", "-h", "127.0.0.1", "-U", username, "-d", database, "-X", "-A", "-t",
        "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=sqlstate"],
        input=("BEGIN;\n" + statement + ";\nROLLBACK;\n").encode(), capture_output=True,
        env={**os.environ, "PGPASSWORD":password}, timeout=20)
    if login_denied:
        valid = result.returncode != 0 and b"not permitted to log in" in result.stderr
    elif denied:
        valid = result.returncode != 0 and re.search(rb"ERROR:\s+42501\b", result.stderr)
    else:
        valid = result.returncode == 0
    if not valid:
        common.private_write(common.ERROR_DIR / ("probe-"+secrets.token_hex(6)+".private.log"),result.stdout+result.stderr)
        raise common.RehearsalError("isolated_identity_probe_failed")


def exercise(app, baseline, old_secret, container, admin_password):
    from sqlalchemy.engine import make_url
    db = app + "_admin"
    policy_path = Path(__file__).resolve().parents[1] / (app+"-app/deployment") / (app+"_database_policy.py")
    spec = importlib.util.spec_from_file_location("app_policy", policy_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    compiler = getattr(module, app+"_grants")
    principals = {role:app+"_backend_"+role for role in ("api","worker","scheduler")}
    principals["migration"] = app+"_backend_user_migration"
    columns = common.column_map({"columns":json.loads(common.docker_pg(container,admin_password,db,common.COLUMNS))})
    grants = compiler(schema="public",principals=principals,columns={k:frozenset(v) for k,v in columns.items()})
    defaults = baseline["catalog"]["default_acl"]
    creators = {d["creator"] for d in defaults} | {principals["migration"]}
    old_name = app+"_backend_user"
    # Reviewed existing defaults only mention this App's legacy grantees.
    legacy = {entry.split("=",1)[0] for d in defaults for entry in d["acl"]} | {old_name}
    if any(not re.fullmatch(app+r"_(backend|admin|web)_user", name) for name in legacy):
        raise common.RehearsalError("unreviewed_default_acl_grantee")
    if any(name != "postgres" and not re.fullmatch(app+r"_(backend|admin)_user_migration", name) for name in creators):
        raise common.RehearsalError("unreviewed_default_acl_creator")
    passwords = {r:secrets.token_hex(24) for r in ("api","worker","scheduler")}
    uuid_default = any("uuid_generate_v4()" in str(c["column_default"]) for c in baseline["catalog"]["columns"])
    old = make_url(base64.b64decode(old_secret["data"]["DATABASE_URL"]).decode())
    if old.username != old_name or old.database != db:
        raise common.RehearsalError("unexpected_old_identity")
    probe(container,db,old_name,old.password,"SELECT 1")
    sql = cutover.cutover_sql(database=db,principals=principals,passwords=passwords,
        old_logins=[old_name],acl_creators=creators,legacy_grantees=legacy,
        grant_statements=grants,uuid_default=uuid_default)
    common.docker_pg(container,admin_password,db,sql)
    probe_count = 1
    for role in passwords:
        def check(statement, denied=False):
            nonlocal probe_count
            probe(container,db,principals[role],passwords[role],statement,denied=denied)
            probe_count += 1
        check("SELECT 1")
        check('SELECT count(*) FROM public.outbox_message',denied=role=="scheduler")
        check('UPDATE public.alembic_version SET version_num=version_num WHERE false',denied=True)
        check('CREATE TABLE public.cutover_forbidden_probe (id integer)',denied=True)
        check('SET ROLE "'+principals["migration"]+'"',denied=True)
        if role == "worker":
            check('SELECT count(*) FROM public.auth_user',denied=True)
        if role != "scheduler":
            check('UPDATE public.outbox_message SET payload=payload WHERE false',denied=role=="api")
        if uuid_default and role != "scheduler":
            check('SELECT public.uuid_generate_v4()')
    # New grants must not require disabling the old identity prematurely.
    probe(container,db,old_name,old.password,"SELECT count(*) FROM public.outbox_message")
    # Exercise closed creator defaults; ephemeral table exists only in this copy.
    common.docker_pg(container,admin_password,db,
        'SET ROLE "'+principals["migration"]+'"; CREATE TABLE public.cutover_future_probe (id integer); RESET ROLE;')
    for role in passwords:
        probe(container,db,principals[role],passwords[role],"SELECT * FROM public.cutover_future_probe",denied=True)
    common.docker_pg(container,admin_password,db,"DROP TABLE public.cutover_future_probe;")
    common.docker_pg(container,admin_password,db,cutover.retirement_sql(database=db,old_logins=[old_name],legacy_grantees=legacy))
    probe(container,db,old_name,old.password,"SELECT 1",login_denied=True)
    for role in passwords:
        probe(container,db,principals[role],passwords[role],"SELECT 1")
    return {"fresh_role_login_and_permissions":True,"creator_defaults_closed":True,
            "old_login_denied_after_new_verified":True,"probes":probe_count+8,
            "broker_tested":False,"cross_database_access_tested":False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backup",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args = parser.parse_args()
    backup, output = args.backup.absolute(), args.output.absolute()
    if backup != backup.resolve() or output != output.resolve() or not output.parent.is_dir():
        raise common.RehearsalError("invalid_private_path")
    receipt = json.loads((backup/"rehearsal.json").read_text())
    app = receipt["app"]
    if app not in common.APPS or len(receipt["iterations"]) != 2:
        raise common.RehearsalError("invalid_backup_rehearsal")
    dump = (backup/"database.dump").read_bytes()
    if hashlib.sha256(dump).hexdigest() != receipt["sha256"]:
        raise common.RehearsalError("backup_digest_changed")
    if subprocess.run(["git","-C",str(output.parent),"rev-parse","--show-toplevel"],capture_output=True).returncode == 0:
        raise common.RehearsalError("private_output_inside_git")
    output.mkdir(mode=0o700)
    common.ERROR_DIR = output
    sources = [Path(__file__),Path(common.__file__),Path(cutover.__file__),
               Path(__file__).resolve().parents[1] / (app+"-app/deployment") / (app+"_database_policy.py")]
    common.private_write(output/"sources.json",common.encoded({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}))
    common.private_write(output/"database.dump",dump)
    def read(name):
        return json.loads((backup/name).read_text())
    baseline, roles = read("baseline.private.json"), read("roles.private.json")
    config = read("configmap--"+app+"-backend-config.private.json")
    migration = read("secret--"+app+"-backend-migration-postgresql-conn.private.json")
    old_secret = read("secret--"+app+"-backend-postgresql-conn.private.json")
    run_args = argparse.Namespace(app=app,output=output,image=receipt["image"],head=receipt["iterations"][0]["migration_head"])
    results = [common.restore_and_migrate(run_args,baseline,roles,config,migration,i,
        post_migration=lambda container,password:exercise(app,baseline,old_secret,container,password)) for i in (1,2)]
    result = {"app":app,"live_writes":False,"iterations":results,"business_cutover":False}
    common.private_write(output/"identity-rehearsal.json",common.encoded(result))
    print(common.encoded(result))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(common.encoded({"status":"failed","reason":str(exc) if isinstance(exc,common.RehearsalError) else type(exc).__name__}))
        raise SystemExit(1)
