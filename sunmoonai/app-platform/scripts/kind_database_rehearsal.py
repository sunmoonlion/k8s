"""Bounded live read-only backup, isolated restore and candidate migration.

No live DDL/DML, role changes, Kubernetes apply, broker writes or queue replay.
Run with an App's existing venv (asyncpg + SQLAlchemy). All private artifacts
are exclusive-created mode 0600 in a new mode 0700 directory outside Git.
Disposable databases have no external network, including during migrations.
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import copy
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import select
import subprocess
import time

APPS = ("info", "knowledge", "investment")
PG_IMAGE = "sha256:dbd371582fbbb100b22b891e485f4559187362348c1d4b5d0a2191134807516b"
LABEL = "sunmoonai.kind-backup-rehearsal"
ERROR_DIR = None
PG_SHELL = ('export PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")"; '
            'exec "$@"')


class RehearsalError(RuntimeError):
    pass


def quote_identifier(value):
    if not re.fullmatch(r"[a-z][a-z0-9_]{0,62}", value):
        raise RehearsalError("unsafe_identifier")
    return '"' + value + '"'


def private_write(path, data):
    path = Path(path)
    if isinstance(data, str):
        data = data.encode()
    with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600), "wb") as stream:
        stream.write(data)


def encoded(value):
    return json.dumps(value, ensure_ascii=False, indent=2, default=str) + "\n"


def run(argv, *, data=None, env=None, timeout=90):
    result = subprocess.run(argv, input=data, capture_output=True, env=env, timeout=timeout)
    if result.returncode:
        if ERROR_DIR is not None:
            private_write(ERROR_DIR / ("command-error-" + secrets.token_hex(6) + ".private.log"),
                          result.stdout + result.stderr)
        # Neither argv, stderr nor exception detail is safe to print here.
        raise RehearsalError(f"command_failed:{Path(argv[0]).name}:{result.returncode}")
    return result.stdout


def kubectl(args, *parts, data=None):
    return run(["kubectl", "--kubeconfig", str(args.kubeconfig), "--context", "kind-kind",
                "--request-timeout=30s", *parts], data=data)


def get(args, namespace, kind, name):
    return json.loads(kubectl(args, "-n", namespace, "get", kind, name, "-o", "json"))


def verify_kind(args):
    uid = json.loads(kubectl(args, "get", "namespace", "kube-system", "-o", "json"))["metadata"]["uid"]
    nodes = json.loads(kubectl(args, "get", "nodes", "-o", "json"))["items"]
    if uid != args.cluster_uid or not nodes or any(
        not node.get("spec", {}).get("providerID", "").startswith("kind://") for node in nodes
    ):
        raise RehearsalError("wrong_cluster")


def quiescence(args):
    """Read-only maintenance observation; never scales/terminates anything.

    Exact deployments must exist and be zero. Also inspect unlabelled legacy
    Pods/Jobs/CronJobs by App name so a missing label cannot hide a writer.
    Operators must keep the maintenance window exclusive between observations.
    """
    if args.app not in APPS:
        raise RehearsalError("invalid_app")
    prefix = args.app + "-"
    expected = {prefix + "backend-" + r for r in ("api", "worker", "scheduler")}
    def resources(kind):
        return json.loads(kubectl(args, "-n", "app-platform-dev", "get", kind, "-o", "json"))["items"]
    deployments = resources("deployments")
    writers = [d for d in deployments if d["metadata"]["name"].startswith(prefix)
               and "backend" in d["metadata"]["name"]]
    if not expected <= {d["metadata"]["name"] for d in writers} or any(
        d.get("spec", {}).get("replicas", 1) != 0 or any(d.get("status", {}).get(k, 0)
            for k in ("replicas", "readyReplicas", "availableReplicas", "updatedReplicas")) for d in writers
    ):
        raise RehearsalError("maintenance_writers_not_stopped")
    for pod in resources("pods"):
        meta = pod["metadata"]
        if (meta["name"].startswith(prefix) and pod.get("status", {}).get("phase") not in ("Succeeded", "Failed")
                and not any(meta["name"].startswith(prefix + r + "-frontend-") for r in ("admin", "web"))):
            raise RehearsalError("maintenance_app_pod_remains")
    for job in resources("jobs"):
        if job["metadata"]["name"].startswith(prefix) and job.get("status", {}).get("active", 0):
            raise RehearsalError("maintenance_app_job_active")
    for cron in resources("cronjobs"):
        if cron["metadata"]["name"].startswith(prefix) and (
                cron.get("spec", {}).get("suspend") is not True or cron.get("status", {}).get("active")):
            raise RehearsalError("maintenance_app_cron_not_suspended")
    sql = ("SELECT count(*) FROM pg_stat_activity WHERE usename <> 'postgres' AND "
           "(datname='" + args.app + "_admin' OR usename LIKE '" + args.app + "\\_%' ESCAPE '\\');")
    clients = kubectl(args, "-n", "data-platform-dev", "exec", "-i", "postgresql-sunmoonai-0", "-c", "postgresql",
        "--", "sh", "-c", PG_SHELL, "sh", "psql", "-U", "postgres", "-d", "postgres", "-X", "-qAt",
        "-v", "ON_ERROR_STOP=1", data=sql.encode())
    if clients.strip() != b"0":
        raise RehearsalError("maintenance_database_clients_remain")
    return sorted(({"name": d["metadata"]["name"], "uid": d["metadata"]["uid"], "spec": d["spec"]}
                   for d in writers), key=lambda d: d["name"])


async def verify_unchanged_snapshot(args, port, password, baseline):
    import asyncpg
    conn = await asyncpg.connect(host="127.0.0.1", port=port, user="postgres", password=password,
                                 database=args.app + "_admin", command_timeout=60)
    try:
        async with conn.transaction(isolation="repeatable_read", readonly=True):
            catalog = {key: json.loads(await conn.fetchval(sql)) for key, sql in CATALOG.items()}
            if comparable_catalog(catalog) != comparable_catalog(baseline["catalog"]):
                raise RehearsalError("maintenance_backup_catalog_changed")
            for name, columns in column_map(catalog).items():
                if json.loads(await conn.fetchval(row_fingerprint_sql(name, columns))) != baseline["rows"][name]:
                    raise RehearsalError("maintenance_backup_rows_changed")
    finally:
        await conn.close()


@contextmanager
def port_forward(args):
    process = subprocess.Popen([
        "kubectl", "--kubeconfig", str(args.kubeconfig), "--context", "kind-kind",
        "-n", "data-platform-dev", "port-forward", "--address=127.0.0.1",
        "service/postgresql-sunmoonai", "0:5432",
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        if not select.select([process.stdout], [], [], 20)[0]:
            raise RehearsalError("port_forward_timeout")
        line = process.stdout.readline().decode()
        match = re.fullmatch(r"Forwarding from 127\.0\.0\.1:(\d+) -> 5432\n", line)
        if not match:
            raise RehearsalError("port_forward_invalid")
        yield int(match[1])
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


TABLES = """SELECT coalesce(json_agg(q ORDER BY tablename),'[]') FROM
 (SELECT tablename,tableowner FROM pg_tables WHERE schemaname='public') q"""
COLUMNS = """SELECT coalesce(json_agg(q ORDER BY table_name,ordinal_position),'[]') FROM
 (SELECT table_name,column_name,ordinal_position,data_type,udt_name,is_nullable,column_default
  FROM information_schema.columns WHERE table_schema='public') q"""
CONSTRAINTS = """SELECT coalesce(json_agg(q ORDER BY table_name,name),'[]') FROM
 (SELECT c.relname AS table_name,x.conname AS name,pg_get_constraintdef(x.oid) AS definition
  FROM pg_constraint x JOIN pg_class c ON c.oid=x.conrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public') q"""
INDEXES = """SELECT coalesce(json_agg(q ORDER BY tablename,indexname),'[]') FROM
 (SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public') q"""
TRIGGERS = """SELECT coalesce(json_agg(q ORDER BY table_name,name),'[]') FROM
 (SELECT c.relname AS table_name,t.tgname AS name,pg_get_triggerdef(t.oid) AS definition,
  t.tgenabled AS enabled FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal) q"""
ACL = """SELECT coalesce(json_agg(q ORDER BY relname),'[]') FROM
 (SELECT c.relname,c.relkind,CASE WHEN c.relacl IS NULL THEN NULL ELSE
   ARRAY(SELECT entry::text FROM unnest(c.relacl) entry ORDER BY entry::text) END AS acl,
  pg_get_userbyid(c.relowner) AS owner
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind IN ('r','p','S','v','m')) q"""
DEFAULT_ACL = """SELECT coalesce(json_agg(q ORDER BY creator,schema,kind),'[]') FROM
 (SELECT pg_get_userbyid(d.defaclrole) AS creator,coalesce(n.nspname,'<global>') AS schema,
  d.defaclobjtype AS kind,ARRAY(SELECT entry::text FROM unnest(d.defaclacl) entry
   ORDER BY entry::text) AS acl FROM pg_default_acl d
  LEFT JOIN pg_namespace n ON n.oid=d.defaclnamespace) q"""
CATALOG = {"tables": TABLES, "columns": COLUMNS, "constraints": CONSTRAINTS,
           "indexes": INDEXES, "triggers": TRIGGERS, "acl": ACL, "default_acl": DEFAULT_ACL}


# A table ACL that holds exactly the owner's default privileges is the same as NULL (acldefault).
# pg_dump does not emit it, so a restore yields NULL. Proven on KIND 2026-09-25 (B5 catalog diff:
# two tables, baseline [owner=arwdDxtm/owner], restored null). "arwdDxt" is the pre-PG17 default.
OWNER_DEFAULT_TABLE_PRIVILEGES = ("arwdDxtm", "arwdDxt")


def comparable_catalog(catalog):
    """Only normalize proven rewrites: PG's varchar-literal-array -> text[] rewrite, and a table
    ACL equal to the owner's default privileges (-> NULL, which is what pg_dump restores).

    ACL arrays are sorted by SQL, not dropped; any grant to another role, or a partial owner grant,
    keeps failing. Unknown expression rewrites keep failing. Original catalogs remain saved for
    review, never overwritten.
    """
    result = copy.deepcopy(catalog)
    for entry in result.get("acl", []):
        owner, acl = entry.get("owner"), entry.get("acl")
        if (entry.get("relkind") in ("r", "p") and owner and isinstance(acl, list) and len(acl) == 1
                and acl[0] in {f"{owner}={p}/{owner}" for p in OWNER_DEFAULT_TABLE_PRIVILEGES}):
            entry["acl"] = None
    literal = r"'[a-z_]+'::character varying"
    pattern = re.compile(r"\(ARRAY\[(" + literal + r"(?:, " + literal + r")*)\]\)::text\[\]")
    for constraint in result.get("constraints", []):
        constraint["definition"] = pattern.sub(
            lambda match: "ARRAY[" + ", ".join("(" + part + ")::text" for part in match[1].split(", ")) + "]",
            constraint["definition"],
        )
    return result


def row_fingerprint_sql(table, columns):
    projection = ",".join(quote_identifier(name) for name in columns)
    return ("SELECT json_build_object('count',count(*),'md5',md5(coalesce("
            "string_agg(row_to_json(t)::text,E'\\n' ORDER BY row_to_json(t)::text),''))) "
            f"FROM (SELECT {projection} FROM public.{quote_identifier(table)}) t")


def column_map(catalog):
    result = {}
    for row in catalog["columns"]:
        result.setdefault(row["table_name"], []).append(row["column_name"])
    return result


async def snapshot(args, port, password):
    import asyncpg
    db = args.app + "_admin"
    conn = await asyncpg.connect(host="127.0.0.1", port=port, user="postgres",
                                 password=password, database=db, command_timeout=60)
    try:
        async with conn.transaction(isolation="repeatable_read", readonly=True):
            await conn.execute("SET LOCAL statement_timeout=60000")
            snapshot_id = await conn.fetchval("SELECT pg_export_snapshot()")
            catalog = {key: json.loads(await conn.fetchval(sql)) for key, sql in CATALOG.items()}
            for table in catalog["tables"]:
                count = await conn.fetchval(f'SELECT count(*) FROM public.{quote_identifier(table["tablename"])}')
                if count > 100_000:
                    raise RehearsalError("snapshot_row_bound_exceeded")
            fingerprints = {name: json.loads(await conn.fetchval(row_fingerprint_sql(name, cols)))
                            for name, cols in column_map(catalog).items()}
            revisions = list(await conn.fetch("SELECT version_num FROM alembic_version"))
            # Only roles referenced by these App histories, never all cluster credentials.
            roles = [dict(row) for row in await conn.fetch("""
                SELECT rolname,rolsuper,rolinherit,rolcreaterole,rolcreatedb,rolcanlogin,
                       rolreplication,rolbypassrls,rolconnlimit,rolpassword,rolvaliduntil
                FROM pg_authid WHERE rolname ~ '^(info|knowledge|investment|research)_'
                ORDER BY rolname
            """)]
            archive = await asyncio.to_thread(kubectl, args, "-n", "data-platform-dev", "exec", "-i",
                "postgresql-sunmoonai-0", "-c", "postgresql", "--", "sh", "-c", PG_SHELL, "sh",
                "pg_dump", "-U", "postgres", "--no-password", "--format=custom", "--create",
                "--snapshot=" + snapshot_id, db)
            if not archive.startswith(b"PGDMP"):
                raise RehearsalError("invalid_dump")
        private_write(args.output / "database.dump", archive)
        private_write(args.output / "roles.private.json", encoded(roles))
        baseline = {"catalog": catalog, "rows": fingerprints,
                    "revisions": [row["version_num"] for row in revisions]}
        private_write(args.output / "baseline.private.json", encoded(baseline))
        return baseline, roles, hashlib.sha256(archive).hexdigest()
    finally:
        await conn.close()


def role_sql(roles):
    statements = []
    for role in roles:
        name = quote_identifier(role["rolname"])
        if role["rolsuper"] or role["rolcreaterole"] or role["rolcreatedb"] or role["rolreplication"] or role["rolbypassrls"]:
            raise RehearsalError("unexpected_privileged_business_role")
        if role["rolconnlimit"] != -1 or role["rolvaliduntil"] is not None:
            raise RehearsalError("unsupported_role_lifetime_or_limit")
        password = role["rolpassword"]
        if password is not None and not re.fullmatch(r"[A-Za-z0-9+/=$:.-]+", password):
            raise RehearsalError("unsupported_password_hash")
        clause = "NULL" if password is None else "'" + password + "'"
        statements.append(f"CREATE ROLE {name} {'LOGIN' if role['rolcanlogin'] else 'NOLOGIN'} "
                          f"{'INHERIT' if role['rolinherit'] else 'NOINHERIT'} PASSWORD {clause};")
    return "\n".join(statements)


def docker_pg(container, password, database, sql=None, *args, data=None):
    env = {**os.environ, "PGPASSWORD": password}
    if sql is not None:
        return run(["docker", "exec", "-i", "-e", "PGPASSWORD", container,
                    "psql", "-h", "127.0.0.1", "-U", "postgres", "-d", database,
                    "-X", "-A", "-t", "-v", "ON_ERROR_STOP=1"], data=sql.encode(), env=env)
    return run(["docker", "exec", "-i", "-e", "PGPASSWORD", container, *args], data=data, env=env)


@contextmanager
def isolated_postgres(token):
    password = secrets.token_hex(24)
    env = {**os.environ, "POSTGRESQL_PASSWORD": password}
    container = run(["docker", "create", "--pull=never", "--network=none", "--memory=1g", "--cpus=2",
                     "--label", LABEL + "=" + token, "--name", "kind-rehearsal-" + token,
                     "-e", "POSTGRESQL_PASSWORD", "-e", "POSTGRESQL_DATABASE=rehearsal", PG_IMAGE], env=env).decode().strip()
    try:
        run(["docker", "start", container])
        deadline = time.monotonic() + 45
        while True:
            try:
                # Bitnami briefly accepts connections on its initialization
                # server, then shuts that server down. Wait for final PID 1.
                run(["docker", "exec", container, "sh", "-c",
                     'test "$(cat /proc/1/comm)" = postgres'])
                docker_pg(container, password, "postgres", "SELECT 1;")
                break
            except RehearsalError:
                if time.monotonic() >= deadline:
                    raise
                time.sleep(.25)
        yield container, password
    finally:
        if ERROR_DIR is not None:
            private_write(ERROR_DIR / ("postgres-" + token + ".private.log"),
                          run(["docker", "logs", container]))
        observed = json.loads(run(["docker", "inspect", container]))[0]
        if (observed["Config"]["Labels"].get(LABEL) != token
                or observed["HostConfig"]["NetworkMode"] != "none"
                or observed["Image"] != PG_IMAGE
                or any(m["Type"] != "volume" for m in observed["Mounts"])):
            raise RehearsalError("refuse_cleanup_unowned_container")
        run(["docker", "rm", "-f", "-v", container])


def restore_and_migrate(args, baseline, roles, config, migration_secret, iteration, post_migration=None):
    from sqlalchemy.engine import make_url
    app = args.app
    db = app + "_admin"
    token = secrets.token_hex(10)
    with isolated_postgres(token) as (container, password):
        docker_pg(container, password, "postgres", role_sql(roles))
        docker_pg(container, password, "postgres", None, "pg_restore", "-h", "127.0.0.1", "-U", "postgres",
                  "--exit-on-error", "--create", "--dbname=postgres", data=(args.output / "database.dump").read_bytes())
        restored = {key: json.loads(docker_pg(container, password, db, sql)) for key, sql in CATALOG.items()}
        if comparable_catalog(restored) != comparable_catalog(baseline["catalog"]):
            private_write(args.output / f"restore-{iteration}-catalog.private.json", encoded(restored))
            raise RehearsalError("restored_catalog_mismatch")
        before = {name: json.loads(docker_pg(container, password, db, row_fingerprint_sql(name, cols)))
                  for name, cols in column_map(restored).items()}
        if before != baseline["rows"]:
            raise RehearsalError("restored_rows_mismatch")
        migration_url = make_url(base64.b64decode(migration_secret["data"]["MIGRATION_DATABASE_URL"]).decode())
        if migration_url.database != db or migration_url.username != app + "_backend_user_migration":
            raise RehearsalError("unexpected_migration_identity")
        values = {**config["data"], "MIGRATION_DATABASE_URL": migration_url.set(host="127.0.0.1", port=5432).render_as_string(hide_password=False)}
        values["DATABASE_URL"] = values["MIGRATION_DATABASE_URL"]
        command = ["docker", "run", "--rm", "--pull=never", "--network=container:" + container,
                   "--read-only", "--tmpfs", "/tmp", "--cap-drop=ALL", "--security-opt=no-new-privileges",
                   "--memory=768m", "--cpus=2"]
        for key in values:
            command.extend(("-e", key))
        command.extend((args.image, "python", "-m", "app.bootstrap.migration", "upgrade", "head"))
        result = subprocess.run(command, env={**os.environ, **values}, capture_output=True, timeout=120)
        private_write(args.output / f"migration-{iteration}.private.log", result.stdout + result.stderr)
        if result.returncode:
            raise RehearsalError("isolated_migration_failed")
        revisions = json.loads(docker_pg(container, password, db,
            "SELECT json_agg(version_num) FROM alembic_version"))
        if revisions != [args.head]:
            raise RehearsalError("wrong_migrated_head")
        # Compare ALL original columns/rows. New migration columns are checked
        # by the migration's invariants, never discarded from the restore check.
        for name, cols in column_map(restored).items():
            if name == "alembic_version":
                continue
            after = json.loads(docker_pg(container, password, db, row_fingerprint_sql(name, cols)))
            if after != before[name]:
                raise RehearsalError("migration_changed_existing_rows:" + name)
        extra = post_migration(container, password) if post_migration else {}
        if post_migration:
            for name, cols in column_map(restored).items():
                if name != "alembic_version" and json.loads(docker_pg(container, password, db,
                        row_fingerprint_sql(name, cols))) != before[name]:
                    raise RehearsalError("identity_rehearsal_changed_existing_rows:" + name)
        return {"restore_catalog_equal": True, "restore_all_rows_equal": True,
                "migration_head": args.head, "original_business_columns_preserved": True,
                "network": "none", "owned_disposable_cleaned_on_exit": True, **extra}


def main():
    global ERROR_DIR
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", choices=APPS, required=True)
    parser.add_argument("--kubeconfig", type=Path, required=True)
    parser.add_argument("--cluster-uid", required=True)
    parser.add_argument("--image", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cutover-release", type=Path,
                        help="Emit a cutover receipt only for a stopped, unchanged App and this exact release")
    args = parser.parse_args()
    if not re.fullmatch(r"harbor\.sunmoonai\.com:30443/app-images/" + args.app + r"-backend@sha256:[0-9a-f]{64}", args.image):
        raise RehearsalError("immutable_app_image_required")
    if not re.fullmatch(r"[0-9]{8}_[0-9]{4}", args.head):
        raise RehearsalError("invalid_head")
    args.output = args.output.absolute()
    if args.output != args.output.resolve() or not args.output.parent.is_dir():
        raise RehearsalError("output_parent_missing_or_symlink")
    if subprocess.run(["git", "-C", str(args.output.parent), "rev-parse", "--show-toplevel"],
                      capture_output=True).returncode == 0:
        raise RehearsalError("backup_must_be_outside_git")
    args.output.mkdir(mode=0o700)
    ERROR_DIR = args.output
    verify_kind(args)
    release = None
    if args.cutover_release is not None:
        import development_release
        release = json.loads(args.cutover_release.read_text())
        development_release.validate(release)
        if (release["logical_app"] != args.app or release["images"]["backend"] != args.image
                or release["migration_head"] != args.head):
            raise RehearsalError("cutover_release_mismatch")
        stopped = quiescence(args)
        private_write(args.output / "quiescence-before.private.json", encoded(stopped))
    print(encoded({"stage": "backup_started", "app": args.app, "output": str(args.output)}), flush=True)
    admin = get(args, "data-platform-dev", "secret", "postgresql-auth-secret")
    password = base64.b64decode(admin["data"]["admin_password"]).decode()
    config = get(args, "app-platform-dev", "configmap", args.app + "-backend-config")
    migration_secret = get(args, "app-platform-dev", "secret", args.app + "-backend-migration-postgresql-conn")
    for kind in ("deployment", "configmap", "service", "networkpolicy", "ingressroute", "secret"):
        names = kubectl(args, "-n", "app-platform-dev", "get", kind, "-o", "name").decode().splitlines()
        for name in names:
            if name.split("/", 1)[1].startswith(args.app + "-"):
                private_write(args.output / (name.replace("/", "--") + ".private.json"),
                              kubectl(args, "-n", "app-platform-dev", "get", name, "-o", "json"))
    private_write(args.output / "rabbitmq-app-definitions.private.json",
                  encoded(get(args, "messaging-platform-dev", "secret", "rabbitmq-app-definitions")))
    with port_forward(args) as port:
        baseline, roles, digest = asyncio.run(snapshot(args, port, password))
    print(encoded({"stage": "consistent_dump_saved", "app": args.app, "sha256": digest,
                   "tables": len(baseline["rows"]), "rows": {k:v["count"] for k,v in baseline["rows"].items()}}), flush=True)
    # Two independent restores demonstrate return to the exact old baseline and
    # repeatable forward migration, without downgrade/delete on the live DB.
    iterations = [restore_and_migrate(args, baseline, roles, config, migration_secret, i) for i in (1, 2)]
    result = {"app": args.app, "cluster_uid": args.cluster_uid, "image": args.image,
              "backup_file": str(args.output / "database.dump"), "sha256": digest,
              "online_preparation_only": True, "live_writes": False,
              "iterations": iterations, "objects_backed_up": False,
              "cutover_backup_receipt": False}
    private_write(args.output / "rehearsal.json", encoded(result))
    if release is not None:
        if quiescence(args) != stopped:
            raise RehearsalError("maintenance_workloads_changed")
        with port_forward(args) as port:
            asyncio.run(verify_unchanged_snapshot(args, port, password, baseline))
        if quiescence(args) != stopped:
            raise RehearsalError("maintenance_workloads_changed")
        receipt = {**result, "logical_app": args.app, "release_id": release["release_id"],
                   "release_content_sha256": development_release.release_content_sha256(release),
                   "online_preparation_only": False, "cutover_backup_receipt": True,
                   "restore_verified": True, "stopped_workloads_verified": True,
                   "rows_unchanged_after_restore": True}
        private_write(args.output / "cutover-receipt.json", encoded(receipt))
        print(encoded({"cutover_receipt": str(args.output / "cutover-receipt.json"), "app": args.app}), flush=True)
    print(encoded(result), flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        # Closed error vocabulary; never print SQL/credentials/driver messages.
        reason = str(exc) if isinstance(exc, RehearsalError) else type(exc).__name__
        print(encoded({"status": "failed", "reason": reason}), flush=True)
        raise SystemExit(1)
