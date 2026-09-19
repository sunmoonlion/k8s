"""KIND-only, fresh-name broker/runtime Secret preparation, never DB activation.

Old identities, queues and messages are preserved. Default is plan only. The
apply path records intent before every write, stops on uncertain outcomes, and
never retries/rolls back automatically. Raw material stays outside Git, 0600.
This is an operator safety workflow, not authorization against administrators.
"""
from __future__ import annotations

import argparse
import base64
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import secrets
import select
import stat
import subprocess
import sys
import re
import urllib.error
import urllib.request
from urllib.parse import quote, urlsplit, urlunsplit

import development_release
import kind_database_rehearsal as common

WORKSPACE = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(WORKSPACE / "tpl-app/k8s-deployment"))
import runtime_broker_cutover as broker
import runtime_broker_probe as broker_probe

NS = "app-platform-dev"
BROKER_NS = "messaging-platform-dev"
MARKER = "sunmoonai.com/runtime-identity-cutover"
QUEUES = {"info": "info.admin.default", "knowledge": "knowledge.admin.default", "investment": "investment.default"}


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def b64(value):
    return base64.b64encode(value.encode() if isinstance(value, str) else value).decode()


def private_read(path):
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), "rb") as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise common.RehearsalError("private_file_permissions_invalid")
        raw = stream.read(16_000_001)
        if len(raw) > 16_000_000:
            raise common.RehearsalError("private_file_too_large")
        return raw


def source_hashes():
    paths = (Path(__file__), Path(common.__file__), Path(broker.__file__), Path(development_release.__file__),
             WORKSPACE / "tpl-app/k8s-deployment/runtime_broker_policy.py", Path(broker_probe.__file__))
    return {str(path.relative_to(WORKSPACE)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}


def require_fresh_database_names(args):
    names = [args.app + "_backend_" + role for role in development_release.RUNTIME_ROLES]
    sql = "SELECT count(*) FROM pg_roles WHERE rolname IN (" + ",".join("'" + n + "'" for n in names) + ");"
    value = common.kubectl(args, "-n", "data-platform-dev", "exec", "-i", "postgresql-sunmoonai-0", "-c", "postgresql",
        "--", "sh", "-c", common.PG_SHELL, "sh", "psql", "-U", "postgres", "-d", "postgres", "-X", "-At",
        "-v", "ON_ERROR_STOP=1", data=sql.encode())
    if value.strip() != b"0":
        raise common.RehearsalError("new_database_name_conflict")


def runtime_secret(app, release_id, passwords):
    data = {}
    for role in development_release.RUNTIME_ROLES:
        data[role.upper() + "_DATABASE_URL"] = b64(
            f"postgresql+asyncpg://{app}_backend_{role}:{passwords['database'][role]}"
            f"@postgresql-sunmoonai.data-platform-dev.svc.cluster.local:5432/{app}_admin")
        data[role.upper() + "_CELERY_BROKER_URL"] = b64(
            f"amqp://{app}-backend-{role}-v2:{passwords['broker'][role]}"
            f"@rabbitmq-sunmoonai.messaging-platform-dev.svc.cluster.local:5672/{app}-development")
    result = {"apiVersion": "v1", "kind": "Secret", "type": "Opaque", "metadata": {
        "name": app + "-backend-runtime", "namespace": NS,
        "labels": {"sunmoonai.com/app": app},
        "annotations": {MARKER: "prepared-not-database-activated", "sunmoonai.com/release-id": release_id}}, "data": data}
    development_release.verify_runtime_secret_contract(result, app)
    return result


def startup_patch(secret, definitions):
    """Optimistic concurrency; never replace unrelated Secret keys/metadata."""
    return [
        {"op": "test", "path": "/metadata/uid", "value": secret["metadata"]["uid"]},
        {"op": "test", "path": "/metadata/resourceVersion", "value": secret["metadata"]["resourceVersion"]},
        {"op": "test", "path": "/data/load_definition.json", "value": secret["data"]["load_definition.json"]},
        {"op": "replace", "path": "/data/load_definition.json", "value": b64(encoded(definitions))},
    ]


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise common.RehearsalError("broker_redirect_refused")


def verify_amqp(args, secret):
    """Only connection/channel opens on the fixed KIND service; no messages."""
    process = subprocess.Popen(["kubectl", "--kubeconfig", str(args.kubeconfig), "--context", "kind-kind",
        "-n", BROKER_NS, "port-forward", "--address=127.0.0.1", "service/rabbitmq-sunmoonai", "0:5672"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        if not select.select([process.stdout], [], [], 20)[0]:
            raise common.RehearsalError("amqp_forward_timeout")
        match = re.fullmatch(rb"Forwarding from 127\.0\.0\.1:(\d+) -> 5672\n", process.stdout.readline())
        if not match:
            raise common.RehearsalError("amqp_forward_failed")
        urls = {}
        for role in development_release.RUNTIME_ROLES:
            endpoint = urlsplit(base64.b64decode(secret["data"][role.upper() + "_CELERY_BROKER_URL"]).decode())
            urls[role] = urlunsplit(endpoint._replace(netloc=endpoint.username + ":" + endpoint.password
                + "@127.0.0.1:" + match[1].decode()))
        return broker_probe.verify_logins(urls, "/")
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


@contextmanager
def broker_api(args):
    auth = common.get(args, BROKER_NS, "secret", "rabbitmq-auth-secret")["data"]
    token = b64(base64.b64decode(auth["rabbitmq-username"]) + b":" + base64.b64decode(auth["rabbitmq-password"]))
    process = subprocess.Popen(["kubectl", "--kubeconfig", str(args.kubeconfig), "--context", "kind-kind",
        "-n", BROKER_NS, "port-forward", "--address=127.0.0.1", "service/rabbitmq-sunmoonai", "0:15672"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        if not select.select([process.stdout], [], [], 20)[0]:
            raise common.RehearsalError("broker_forward_timeout")
        match = re.fullmatch(rb"Forwarding from 127\.0\.0\.1:(\d+) -> 15672\n", process.stdout.readline())
        if not match:
            raise common.RehearsalError("broker_forward_failed")
        endpoint = "http://127.0.0.1:" + match[1].decode() + "/api/"
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        def api(method, path, body=None, *, missing=False):
            request = urllib.request.Request(endpoint + path, data=None if body is None else encoded(body),
                method=method, headers={"Authorization": "Basic " + token, "Content-Type": "application/json"})
            try:
                with opener.open(request, timeout=15) as response:
                    raw = response.read(10_000_001)
                    if len(raw) > 10_000_000:
                        raise common.RehearsalError("broker_response_overflow")
                    return json.loads(raw) if raw else None
            except urllib.error.HTTPError as exc:
                if missing and exc.code == 404:
                    return None
                raise common.RehearsalError("broker_http_failed:" + str(exc.code)) from None
            except (OSError, ValueError):
                raise common.RehearsalError("broker_request_failed") from None
        yield api
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def apply_preparation(plan, *, create_secret, patch_secret, get_secret, api, journal):
    """Injectable sequencer; first uncertain result stops all subsequent writes.

    The Secret create is also a same-App reservation (AlreadyExists is fatal).
    This cannot provide a transaction with RabbitMQ or exclude a privileged
    administrator writing concurrently; no automatic recovery is attempted.
    """
    for name in plan["new_names"]:
        if api("GET", "users/" + quote(name, safe=""), missing=True) is not None:
            raise common.RehearsalError("new_broker_name_conflict")
    journal("reserve-runtime-secret-intent", plan["runtime_secret"])
    created = create_secret(plan["runtime_secret"])
    journal("reserve-runtime-secret-result", created)
    journal("startup-cas-intent", plan["startup_patch"])
    updated = patch_secret(plan["startup_patch"])
    journal("startup-cas-result", updated)
    current = get_secret()
    if json.loads(base64.b64decode(current["data"]["load_definition.json"])) != plan["startup_definitions"]:
        raise common.RehearsalError("startup_readback_mismatch")
    for index, operation in enumerate(plan["operations"]):
        journal(f"broker-{index}-intent", operation)
        api(operation["method"], operation["path"], operation["body"])
        journal(f"broker-{index}-result", {"http_success": True})
    for operation in plan["operations"]:
        actual = api("GET", operation["path"])
        if any(actual.get(k) != v for k, v in operation["body"].items()):
            raise common.RehearsalError("broker_readback_mismatch")
    for name in plan["new_names"]:
        permissions = api("GET", "users/" + quote(name, safe="") + "/permissions")
        if len(permissions) != 1 or permissions[0]["vhost"] != plan["vhost"]:
            raise common.RehearsalError("new_user_has_unexpected_vhost_access")
    journal("broker-prepared", {"database_activated": False, "old_identities_retired": False})


def execute_saved(args):
    output = args.output.absolute()
    if output != output.resolve() or not output.is_dir() or output.stat().st_mode & 0o077:
        raise common.RehearsalError("private_plan_directory_required")
    if not re.fullmatch(r"[0-9a-f]{64}", args.expected_plan_sha256 or ""):
        raise common.RehearsalError("explicit_plan_digest_required")
    raw = private_read(output / "plan.private.json")
    if hashlib.sha256(raw).hexdigest() != args.expected_plan_sha256:
        raise common.RehearsalError("plan_digest_changed")
    plan = json.loads(raw)
    bundle = Path(__file__).resolve().parents[1] / (args.app + "-app/deployment/bundle/release.json")
    if (plan["app"] != args.app or plan["cluster_uid"] != args.cluster_uid
            or plan["release_sha256"] != hashlib.sha256(bundle.read_bytes()).hexdigest()
            or plan["source_sha256"] != source_hashes()):
        raise common.RehearsalError("plan_target_or_source_changed")
    common.ERROR_DIR = output
    common.verify_kind(args)
    require_fresh_database_names(args)
    development_release.verify_runtime_secret_contract(plan["runtime_secret"], args.app)
    with broker_api(args) as api:
        startup = common.get(args, BROKER_NS, "secret", "rabbitmq-app-definitions")
        names = {role: args.app + "-backend-" + role + "-v2" for role in development_release.RUNTIME_ROLES}
        users = [{"name": operation["path"].removeprefix("users/"), **operation["body"]}
                 for operation in plan["operations"][:3]]
        rechecked = broker.preparation_plan(json.loads(base64.b64decode(startup["data"]["load_definition.json"])),
            api("GET", "definitions"), vhost=args.app + "-development", queue=QUEUES[args.app], principals=names, users=users)
        if (rechecked["operations"] != plan["operations"] or rechecked["startup"] != plan["startup_definitions"]
                or startup_patch(startup, rechecked["startup"]) != plan["startup_patch"]
                or plan["new_names"] != list(names.values()) or plan["vhost"] != args.app + "-development"):
            raise common.RehearsalError("plan_no_longer_matches_live_state")
        def journal(name, value):
            common.private_write(output / (name + ".private.json"), encoded(value))
        apply_preparation(plan,
            create_secret=lambda value: json.loads(common.kubectl(args, "create", "-f", "-", "-o", "json", data=encoded(value))),
            patch_secret=lambda value: json.loads(common.kubectl(args, "-n", BROKER_NS, "patch", "secret", "rabbitmq-app-definitions",
                "--type=json", "--patch-file=/dev/stdin", "-o", "json", data=encoded(value))),
            get_secret=lambda: common.get(args, BROKER_NS, "secret", "rabbitmq-app-definitions"), api=api, journal=journal)
    proof = verify_amqp(args, plan["runtime_secret"])
    common.private_write(output / "amqp-proof.json", encoded(proof))
    summary = {"app": args.app, "plan_sha256": args.expected_plan_sha256, "applied": True,
               "database_activated": False, "old_identities_retired": False, "queues_changed": False,
               "live_amqp_login_verified": True, "credentials_printed": False}
    common.private_write(output / "applied.json", encoded(summary))
    print(common.encoded(summary))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", choices=common.APPS, required=True)
    parser.add_argument("--kubeconfig", type=Path, required=True)
    parser.add_argument("--cluster-uid", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--rehearsal", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--expected-plan-sha256")
    args = parser.parse_args()
    if args.apply:
        return execute_saved(args)
    if args.rehearsal is None or args.expected_plan_sha256 is not None:
        raise common.RehearsalError("plan_requires_rehearsal_not_execution_digest")
    output = args.output.absolute()
    if output != output.resolve() or not output.parent.is_dir() or subprocess.run(
            ["git", "-C", str(output.parent), "rev-parse", "--show-toplevel"], capture_output=True).returncode == 0:
        raise common.RehearsalError("private_output_path_required")
    output.mkdir(mode=0o700)
    common.ERROR_DIR = output
    common.verify_kind(args)
    require_fresh_database_names(args)
    bundle = Path(__file__).resolve().parents[1] / (args.app + "-app/deployment/bundle")
    release = json.loads((bundle / "release.json").read_text())
    development_release.validate(release)
    if release.get("runtime_identity_mode") != development_release.IDENTITY_MODE:
        raise common.RehearsalError("independent_candidate_required")
    common.run([sys.executable, "-B", str(Path(__file__).with_name("verify-formal-instance.py")), "--bundle", str(bundle)])
    receipt = json.loads((args.rehearsal / "rehearsal.json").read_text())
    if (receipt["app"] != args.app or receipt["cluster_uid"] != args.cluster_uid
            or receipt["image"] != release["images"]["backend"] or len(receipt["iterations"]) != 2
            or any(not r["restore_catalog_equal"] or not r["restore_all_rows_equal"]
                   or r["migration_head"] != release["migration_head"] for r in receipt["iterations"])
            or hashlib.sha256((args.rehearsal / "database.dump").read_bytes()).hexdigest() != receipt["sha256"]):
        raise common.RehearsalError("preparation_rehearsal_mismatch")
    existing = common.kubectl(args, "-n", NS, "get", "secret", args.app + "-backend-runtime",
                              "--ignore-not-found=true", "-o", "name")
    if existing.strip():
        raise common.RehearsalError("runtime_secret_already_exists")
    startup = common.get(args, BROKER_NS, "secret", "rabbitmq-app-definitions")
    passwords = {kind: {role: secrets.token_hex(24) for role in development_release.RUNTIME_ROLES}
                 for kind in ("database", "broker")}
    names = {role: args.app + "-backend-" + role + "-v2" for role in development_release.RUNTIME_ROLES}
    users = [{"name": names[role], "tags": [], "hashing_algorithm": "rabbit_password_hashing_sha256",
              "password_hash": broker.password_hash(passwords["broker"][role], secrets.token_bytes(4))} for role in names]
    with broker_api(args) as api:
        live = api("GET", "definitions")
        prepared = broker.preparation_plan(json.loads(base64.b64decode(startup["data"]["load_definition.json"])), live,
            vhost=args.app + "-development", queue=QUEUES[args.app], principals=names, users=users)
        plan = {"app": args.app, "cluster_uid": args.cluster_uid, "release_id": release["release_id"],
                "source_sha256": source_hashes(),
                "release_sha256": hashlib.sha256((bundle / "release.json").read_bytes()).hexdigest(),
                "vhost": args.app + "-development", "new_names": list(names.values()),
                "runtime_secret": runtime_secret(args.app, release["release_id"], passwords),
                "startup_definitions": prepared["startup"], "startup_patch": startup_patch(startup, prepared["startup"]),
                "operations": prepared["operations"], "database_activated": False}
        common.private_write(output / "startup-before.private.json", encoded(startup))
        common.private_write(output / "live-before.private.json", encoded(live))
        common.private_write(output / "plan.private.json", encoded(plan))
        digest = hashlib.sha256(encoded(plan)).hexdigest()
        summary = {"app": args.app, "plan_sha256": digest, "applied": args.apply, "database_activated": False,
                   "old_identities_retired": False, "queues_changed": False, "credentials_printed": False}
        common.private_write(output / "result.json", encoded(summary))
        print(common.encoded(summary))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(common.encoded({"status": "failed", "reason": str(exc) if isinstance(exc, common.RehearsalError) else type(exc).__name__}))
        raise SystemExit(1)
