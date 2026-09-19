"""One-time post-migration activation of the approved KIND runtime identities.

Fresh names only. A partial/uncertain activation is retained for inspection, not
automatically repaired. Successful same-release retries authenticate again and
compare the complete saved permission catalog. Old logins are NOT retired here.
"""
from __future__ import annotations

import base64
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

import kind_database_rehearsal as common
import kind_identity_prepare as preparation
import development_release

sys.path.insert(0, str(preparation.WORKSPACE / "tpl-app/k8s-deployment"))
import runtime_database_cutover as cutover
import runtime_database_inventory as validation


def inventory_sql(app):
    if app not in common.APPS:
        raise common.RehearsalError("invalid_app")
    names = [app + "_backend_" + r for r in ("api", "worker", "scheduler", "user", "user_migration")]
    literals = ",".join("'" + n + "'" for n in names)
    return f"""SELECT json_build_object(
 'database',current_database(),
 'owner',(SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname=current_database()),
 'database_acl',(SELECT datacl FROM pg_database WHERE datname=current_database()),
 'revisions',(SELECT json_agg(version_num ORDER BY version_num) FROM public.alembic_version),
 'schemas',(SELECT coalesce(json_agg(json_build_object('name',nspname,'owner',pg_get_userbyid(nspowner)) ORDER BY nspname),'[]') FROM pg_namespace WHERE nspname !~ '^pg_' AND nspname<>'information_schema'),
 'schema_acl',(SELECT nspacl FROM pg_namespace WHERE nspname='public'),
 'columns',({common.COLUMNS}),
 'relations',(SELECT coalesce(json_agg(json_build_object('name',c.relname,'owner',pg_get_userbyid(c.relowner),'kind',c.relkind,'rls',c.relrowsecurity,'acl',c.relacl) ORDER BY c.relname),'[]') FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND c.relkind IN ('r','p','S','v','m','f')),
 'roles',(SELECT coalesce(json_agg(json_build_object('name',rolname,'login',rolcanlogin,'super',rolsuper,'create_db',rolcreatedb,'create_role',rolcreaterole,'replication',rolreplication,'bypass_rls',rolbypassrls,'inherit',rolinherit,'valid_until',rolvaliduntil,'limit',rolconnlimit) ORDER BY rolname),'[]') FROM pg_roles WHERE rolname IN ({literals})),
 'memberships',(SELECT coalesce(json_agg(json_build_object('role',pg_get_userbyid(roleid),'member',pg_get_userbyid(member)) ORDER BY roleid,member),'[]') FROM pg_auth_members WHERE pg_get_userbyid(roleid) IN ({literals}) OR pg_get_userbyid(member) IN ({literals})),
 'column_acl_count',(SELECT count(*) FROM pg_attribute a JOIN pg_class c ON a.attrelid=c.oid JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND a.attacl IS NOT NULL),
 'column_acl',(SELECT coalesce(json_agg(json_build_object('table',c.relname,'column',a.attname,'acl',a.attacl) ORDER BY c.relname,a.attname),'[]') FROM pg_attribute a JOIN pg_class c ON a.attrelid=c.oid JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='public' AND a.attacl IS NOT NULL),
 'event_trigger_count',(SELECT count(*) FROM pg_event_trigger),
 'acl_grantees',(SELECT coalesce(json_agg(DISTINCT jsonb_build_object('grantee',CASE WHEN g=0 THEN 'PUBLIC' ELSE pg_get_userbyid(g) END) ORDER BY jsonb_build_object('grantee',CASE WHEN g=0 THEN 'PUBLIC' ELSE pg_get_userbyid(g) END)),'[]') FROM (
   SELECT a.grantee g FROM pg_database d CROSS JOIN LATERAL aclexplode(d.datacl) a WHERE d.datname=current_database()
   UNION SELECT a.grantee FROM pg_namespace n CROSS JOIN LATERAL aclexplode(n.nspacl) a WHERE n.nspname='public'
   UNION SELECT a.grantee FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid CROSS JOIN LATERAL aclexplode(c.relacl) a WHERE n.nspname='public') x),
 'default_acl',({common.DEFAULT_ACL}),
 'functions',(SELECT coalesce(json_agg(json_build_object('name',p.proname,'oid',p.oid,'owner',pg_get_userbyid(p.proowner),'security_definer',p.prosecdef,'acl',p.proacl,'definition',pg_get_functiondef(p.oid),'extension',(SELECT e.extname FROM pg_depend d JOIN pg_extension e ON d.refobjid=e.oid WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.refclassid='pg_extension'::regclass AND d.deptype='e')) ORDER BY p.oid),'[]') FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public'),
 'activity',(SELECT coalesce(json_agg(json_build_object('user',usename,'database',datname) ORDER BY usename,datname),'[]') FROM pg_stat_activity WHERE usename<>'postgres' AND (datname=current_database() OR usename='{app}_backend_user'))
)"""


def admin_sql(args, app, sql):
    return common.kubectl(args, "-n", "data-platform-dev", "exec", "-i", "postgresql-sunmoonai-0", "-c", "postgresql",
        "--", "sh", "-c", common.PG_SHELL, "sh", "psql", "-U", "postgres", "-d", app + "_admin",
        "-X", "-qAt", "-v", "ON_ERROR_STOP=1", data=("SET search_path=pg_catalog;\n" + sql).encode()).decode().strip()


def compile_activation(app, head, inventory, passwords):
    path = Path(__file__).resolve().parents[1] / (app + "-app/deployment/" + app + "_database_policy.py")
    spec = importlib.util.spec_from_file_location("activation_domain_policy", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    principals = {role: app + "_backend_" + role for role in ("api", "worker", "scheduler")}
    principals["migration"] = app + "_backend_user_migration"
    old = app + "_backend_user"
    legacy = {old}
    for row in inventory["default_acl"]:
        for acl in row["acl"]:
            name = acl.split("=", 1)[0]
            if name and name != row["creator"]:
                legacy.add(name)
    if any(not re.fullmatch(app + r"_(backend|admin|web)_user", name) for name in legacy):
        raise common.RehearsalError("unreviewed_legacy_grantee")
    validated = validation.validate_bootstrap(inventory, database=app + "_admin", head=head,
        principals=principals, old_login=old, legacy_grantees=legacy,
        function_owners={app + "_admin_user_migration", "postgres"},
        reviewed_functions=getattr(module, "REVIEWED_DATABASE_FUNCTIONS", {}))
    columns = {name: frozenset(cols) for name, cols in common.column_map(inventory).items()}
    grants = getattr(module, app + "_grants")(schema="public", principals=principals, columns=columns)
    uuid_default = any("uuid_generate_v4()" in str(row["column_default"]) for row in inventory["columns"])
    sql = cutover.cutover_sql(database=app + "_admin", principals=principals, passwords=passwords,
        old_logins=[old], grant_statements=grants, uuid_default=uuid_default, **validated)
    # Lock reviewed tables before the atomic catalog comparison and CREATE ROLE.
    # The SQL compiler owns the rest of this single transaction.
    tables = ",".join('public.' + common.quote_identifier(name) for name in sorted(columns))
    return sql, tables


def permission_fingerprint(inventory):
    return {key: value for key, value in inventory.items() if key != "activity"}


def guarded_transaction(app, raw_inventory, sql, tables):
    digest = hashlib.md5(raw_inventory.encode()).hexdigest()
    guarded = sql.replace("SET LOCAL search_path=pg_catalog;\n", "SET LOCAL search_path=pg_catalog;\n"
        + "LOCK TABLE " + tables + " IN ACCESS EXCLUSIVE MODE;\n"
        + "DO $inventory$ BEGIN IF md5((" + inventory_sql(app) + ")::text) <> '" + digest + "' THEN "
        + "RAISE EXCEPTION 'activation inventory changed'; END IF; END $inventory$;\n", 1)
    if guarded == sql:
        raise common.RehearsalError("compiler_transaction_layout_changed")
    return guarded


def login_probe(args, app, role, password, sql, *, denied=False):
    # Password travels only through stdin, never argv or stdout. Connection
    # is a real TCP password login, not SET ROLE under the administrator.
    if not re.fullmatch(r"[0-9a-f]{48}", password):
        raise common.RehearsalError("invalid_runtime_password")
    name = app + "_backend_" + role
    shell = 'IFS= read -r PGPASSWORD; export PGPASSWORD; exec "$@"'
    argv = ["kubectl", "--kubeconfig", str(args.kubeconfig), "--context", "kind-kind", "--request-timeout=30s",
        "-n", "data-platform-dev", "exec", "-i", "postgresql-sunmoonai-0", "-c", "postgresql", "--",
        "sh", "-c", shell, "sh", "psql", "-h", "127.0.0.1", "-U", name, "-d", app + "_admin", "-X", "-At",
        "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=sqlstate"]
    result = subprocess.run(argv, input=(password + "\nBEGIN;\nSET LOCAL statement_timeout='3s';\n" + sql + ";\nROLLBACK;\n").encode(),
                            capture_output=True, timeout=40)
    okay = (result.returncode != 0 and re.search(rb"ERROR:\s+42501\b", result.stderr)) if denied else result.returncode == 0
    if not okay:
        # Do not print server/driver errors. No business row values are selected.
        common.private_write(common.ERROR_DIR / ("probe-" + role + "-failure.private.log"), result.stdout + result.stderr)
        raise common.RehearsalError("runtime_permission_probe_failed")


def verify_logins(args, app, passwords):
    count = 0
    for role, password in passwords.items():
        probes = [("SELECT 1", False), ("SELECT count(*) FROM public.outbox_message", role == "scheduler"),
                  ("UPDATE public.alembic_version SET version_num=version_num WHERE false", True),
                  ("CREATE TABLE public.cutover_forbidden_probe (id integer)", True),
                  ('SET ROLE "' + app + '_backend_user_migration"', True)]
        if role == "worker":
            probes.append(("SELECT count(*) FROM public.auth_user", True))
        if role != "scheduler":
            probes.append(("UPDATE public.outbox_message SET payload=payload WHERE false", role == "api"))
        for sql, denied in probes:
            login_probe(args, app, role, password, sql, denied=denied)
            count += 1
    return count


def load_preparation(args, release):
    root = getattr(args, "identity_preparation", None)
    if root is None:
        raise common.RehearsalError("identity_preparation_directory_required")
    root = Path(root).absolute()
    if root != root.resolve() or root.stat().st_mode & 0o077:
        raise common.RehearsalError("private_preparation_directory_required")
    plan_raw = preparation.private_read(root / "plan.private.json")
    plan = json.loads(plan_raw)
    applied = json.loads(preparation.private_read(root / "applied.json"))
    app = release["logical_app"]
    bundle = Path(__file__).resolve().parents[1] / (app + "-app/deployment/bundle/release.json")
    if (plan["app"] != app or plan["release_id"] != release["release_id"] or applied.get("applied") is not True
            or applied.get("live_amqp_login_verified") is not True
            or applied["plan_sha256"] != hashlib.sha256(plan_raw).hexdigest()
            or plan["release_sha256"] != hashlib.sha256(bundle.read_bytes()).hexdigest()):
        raise common.RehearsalError("identity_preparation_release_mismatch")
    return root, plan, applied


def activation_sources(app):
    paths = (Path(__file__), Path(cutover.__file__), Path(validation.__file__),
             preparation.WORKSPACE / "tpl-app/k8s-deployment/runtime_database_policy.py",
             Path(__file__).resolve().parents[1] / (app + "-app/deployment/" + app + "_database_policy.py"))
    return {str(path.relative_to(preparation.WORKSPACE)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}


def activate(args, release, run):
    if release.get("formal_release") is True:
        return
    # Recheck the real restored-backup gate and stopped Pods after migration.
    development_release.guard(args, release, run)
    root, plan, applied = load_preparation(args, release)
    app = release["logical_app"]
    # Never mutate caller arguments used by the deployment entry.
    from types import SimpleNamespace
    context = SimpleNamespace(kubeconfig=args.kubeconfig, cluster_uid=plan["cluster_uid"])
    common.verify_kind(context)
    secret = common.get(context, preparation.NS, "secret", app + "-backend-runtime")
    reservation = json.loads(preparation.private_read(root / "reserve-runtime-secret-result.private.json"))
    if secret["data"] != plan["runtime_secret"]["data"] or secret["metadata"]["uid"] != reservation["metadata"]["uid"]:
        raise common.RehearsalError("runtime_secret_changed")
    development_release.verify_runtime_secret_contract(secret, app)
    passwords = {role: unquote(urlsplit(base64.b64decode(secret["data"][role.upper() + "_DATABASE_URL"]).decode()).password)
                 for role in development_release.RUNTIME_ROLES}
    folder = root / "database-activation"
    completed = folder / "complete.json"
    common.ERROR_DIR = root
    raw = admin_sql(context, app, inventory_sql(app))
    current = json.loads(raw)
    if completed.is_file():
        common.ERROR_DIR = folder
        intent = json.loads(preparation.private_read(folder / "intent.json"))
        if intent["source_sha256"] != activation_sources(app) or intent["plan_sha256"] != applied["plan_sha256"]:
            raise common.RehearsalError("activation_source_or_plan_changed")
        previous = json.loads(preparation.private_read(folder / "catalog-after.private.json"))
        if permission_fingerprint(current) != permission_fingerprint(previous):
            raise common.RehearsalError("activated_catalog_drifted")
        verify_logins(context, app, passwords)
        return
    folder.mkdir(mode=0o700)  # Existing incomplete attempt refuses automatic retry.
    common.ERROR_DIR = folder
    sql, tables = compile_activation(app, release["migration_head"], current, passwords)
    guarded = guarded_transaction(app, raw, sql, tables)
    common.private_write(folder / "catalog-before.private.json", preparation.encoded(current))
    common.private_write(folder / "transaction.private.sql", guarded)
    common.private_write(folder / "intent.json", preparation.encoded({"release_id": release["release_id"],
        "plan_sha256": applied["plan_sha256"], "transaction_sha256": hashlib.sha256(guarded.encode()).hexdigest(),
        "source_sha256": activation_sources(app)}))
    admin_sql(context, app, guarded)
    after = json.loads(admin_sql(context, app, inventory_sql(app)))
    common.private_write(folder / "catalog-after.private.json", preparation.encoded(after))
    probes = verify_logins(context, app, passwords)
    common.private_write(completed, preparation.encoded({"probes": probes, "old_logins_retired": False,
                                                        "release_id": release["release_id"]}))
