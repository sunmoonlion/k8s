"""KIND-only development mode for the existing render/deploy pipeline."""
from __future__ import annotations

import ast
import base64
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlsplit

import yaml

ARCHITECTURE = "app-platform-v2-development"
SHA = re.compile(r"[0-9a-f]{40}")
DIGEST = re.compile(r"[^\s]+@sha256:[0-9a-f]{64}")
ROLES = {"backend": "backend", "admin": "admin-frontend", "web": "web-frontend"}
IDENTITY_MODE = "independent-v1"
RUNTIME_ROLES = ("api", "worker", "scheduler")


def release_content_sha256(release):
    return hashlib.sha256(json.dumps(release, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def validate(release: dict[str, Any]) -> None:
    if release.get("architecture") != ARCHITECTURE or release.get("formal_release") is not False:
        raise ValueError("development release must explicitly be non-formal")
    if release.get("deployment_target") != "KIND" or release.get("namespace") != "app-platform-dev":
        raise ValueError("development release is restricted to KIND/app-platform-dev")
    app = release.get("logical_app")
    if app not in ("info", "knowledge", "investment") or release.get("resource_app") != app:
        raise ValueError("invalid development App identity")
    lock = release.get("development_source_lock", {})
    if (lock.get("kind") != "development-source-lock" or lock.get("formal_release") is not False
            or lock.get("repository") != app + "-app"):
        raise ValueError("development source lock is missing or belongs to another App")
    components = lock.get("components", [])
    if len(components) != 3 or {c.get("path") for c in components} != {app + "-" + c for c in ROLES.values()}:
        raise ValueError("development source lock must contain exactly three components")
    for component in components:
        if not SHA.fullmatch(str(component.get("commit", ""))) or not SHA.fullmatch(str(component.get("tree", ""))):
            raise ValueError("development source lock requires full commit and tree IDs")
    if set(release.get("images", {})) != set(ROLES):
        raise ValueError("development release must lock all three images")
    for role, image in release["images"].items():
        prefix = f"harbor.sunmoonai.com:30443/app-images/{app}-{ROLES[role]}@sha256:"
        if not DIGEST.fullmatch(str(image)) or not image.startswith(prefix):
            raise ValueError("development images must be App-owned immutable Harbor digests")
    if not re.fullmatch(r"[0-9]{8}_[0-9]{4}", str(release.get("migration_head", ""))):
        raise ValueError("development release must lock the Alembic head")
    if release.get("runtime_identity_mode") not in (None, IDENTITY_MODE):
        raise ValueError("unknown development runtime identity mode")
    upgrade = release.get("runtime_identity_upgrade")
    if upgrade is not None:
        # Image-only upgrade: reuse the applied identity preparation of an earlier
        # release (declared and pinned here); the backup receipt is still per release.
        if (release.get("runtime_identity_mode") != IDENTITY_MODE or not isinstance(upgrade, dict)
                or set(upgrade) != {"prepared_release_id", "preparation_plan_sha256"}
                or not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", str(upgrade["prepared_release_id"]))
                or upgrade["prepared_release_id"] == release.get("release_id")
                or not re.fullmatch(r"[0-9a-f]{64}", str(upgrade["preparation_plan_sha256"]))):
            raise ValueError("invalid runtime identity upgrade declaration")


def verify_runtime_secret_contract(secret: dict[str, Any], app: str) -> None:
    """Structural gate only: live authentication/permission probes are separate.

    Never echo connection strings, passwords, or parsing exception details.
    This KIND cutover intentionally supports no Celery result backend.
    """
    try:
        if app not in ("info", "knowledge", "investment"):
            raise ValueError()
        if (secret["metadata"]["name"] != f"{app}-backend-runtime"
                or secret["metadata"]["namespace"] != "app-platform-dev"):
            raise ValueError()
        data = secret["data"]
        expected = {f"{role.upper()}_{key}" for role in RUNTIME_ROLES
                    for key in ("DATABASE_URL", "CELERY_BROKER_URL")}
        if set(data) != expected:
            raise ValueError()
        passwords = set()
        for role in RUNTIME_ROLES:
            for key in ("DATABASE_URL", "CELERY_BROKER_URL"):
                raw = base64.b64decode(data[f"{role.upper()}_{key}"], validate=True).decode()
                if any(c.isspace() or ord(c) < 32 for c in raw):
                    raise ValueError()
                url = urlsplit(raw)
                database = key == "DATABASE_URL"
                if (url.scheme not in (("postgresql", "postgresql+asyncpg") if database else ("amqp",))
                        or url.hostname != ("postgresql-sunmoonai.data-platform-dev.svc.cluster.local" if database
                                            else "rabbitmq-sunmoonai.messaging-platform-dev.svc.cluster.local")
                        or url.port != (5432 if database else 5672)
                        or unquote(url.username or "") != (f"{app}_backend_{role}" if database else f"{app}-backend-{role}-v2")
                        or unquote(url.path) != (f"/{app}_admin" if database else f"/{app}-development")
                        or url.query or url.fragment):
                    raise ValueError()
                password = unquote(url.password or "")
                if len(password) < 32 or password in passwords:
                    raise ValueError()
                passwords.add(password)
    except (KeyError, TypeError, ValueError, AttributeError):
        raise ValueError("independent runtime Secret contract failed; credentials not displayed") from None


def runtime_secret_gate(args: Any, release: dict[str, Any], run: Any) -> None:
    if release.get("runtime_identity_mode") != IDENTITY_MODE:
        raise ValueError("development apply requires explicit independent-v1 runtime identities")
    try:
        result = run(args, "get", "secret", release["logical_app"] + "-backend-runtime",
                     "-n", release["namespace"], "-o", "json", capture=True)
        if getattr(result, "returncode", 0):
            raise ValueError()
        secret = json.loads(result.stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        raise ValueError("cannot read independent runtime Secret; apply refused") from None
    verify_runtime_secret_contract(secret, release["logical_app"])


def existing_retrieval_binding_gate(args: Any, release: dict[str, Any], run: Any) -> None:
    """Consume the approved existing binding without reapplying/restarting it."""
    try:
        secrets = []
        for name in ("knowledge-investment-retrieval-service-binding", "knowledge-active-retrieval-service-binding"):
            result = run(args, "get", "secret", name, "-n", release["namespace"], "-o", "json", capture=True)
            if getattr(result, "returncode", 0):
                raise ValueError()
            secrets.append(json.loads(result.stdout))
        source, active = secrets
        required = {"RETRIEVAL_AUTH_" + key for key in (
            "CASDOOR_APPLICATION", "DISCOVERY_URL", "BACKCHANNEL_ENDPOINT", "AUDIENCE", "SUBJECT_ALLOWLIST", "REQUIRED_SCOPE")}
        if (not required <= source["data"].keys() or source["data"] != active["data"]
                or any(not base64.b64decode(source["data"][key], validate=True) for key in required)
                or active["metadata"]["labels"]["sunmoonai.com/active-caller"] != "investment"
                or active["metadata"]["annotations"]["architecture.sunmoonai.com/source-secret"]
                != "knowledge-investment-retrieval-service-binding"):
            raise ValueError()
    except (OSError, ValueError, KeyError, TypeError, AttributeError, subprocess.SubprocessError):
        raise ValueError("existing retrieval binding missing or drifted; no automatic reconciliation") from None


def render(output: Path, input_path: Path, k8s_root: Path) -> None:
    """Finish the existing renderer output; keep one canonical bundle per App."""
    source = json.loads(input_path.read_text())
    release_path = output / "release.json"
    release = json.loads(release_path.read_text())
    app = release["logical_app"]
    if source.get("kind") != "kind-development-release-input" or source.get("logical_app") != app:
        raise ValueError("wrong development release input")
    source_root = k8s_root.parent / (app + "-app")
    source_lock = json.loads((source_root / "development-source-lock.json").read_text())
    if source.get("development_source_lock") != source_lock:
        raise ValueError("release input differs from the App development source lock")
    for component in source_lock["components"]:
        repo = source_root / component["path"]
        for revision, expected in (("HEAD", component["commit"]), ("HEAD^{tree}", component["tree"])):
            actual = subprocess.check_output(["git", "-C", str(repo), "rev-parse", revision], text=True).strip()
            if actual != expected:
                raise ValueError("source checkout does not match the development lock")
        if subprocess.check_output(["git", "-C", str(repo), "status", "--porcelain"], text=True).strip():
            raise ValueError("cannot render a development release from dirty source")
    revisions, parents = set(), set()
    for migration in (source_root / (app + "-backend/app/alembic/versions")).glob("*.py"):
        for node in ast.parse(migration.read_text()).body:
            if isinstance(node, ast.Assign) and isinstance(node.value, ast.Constant):
                names = {target.id for target in node.targets if isinstance(target, ast.Name)}
                if "revision" in names:
                    revisions.add(node.value.value)
                if "down_revision" in names and node.value.value is not None:
                    parents.add(node.value.value)
    if revisions - parents != {source.get("migration_head")}:
        raise ValueError("migration head does not match the locked backend source")
    previous_images = release["images"]
    release.update(architecture=ARCHITECTURE, formal_release=False, deployment_target="KIND",
                   development_source_lock=source_lock, images=source["images"],
                   migration_head=source["migration_head"])
    release.pop("runtime_identity_mode", None)
    if "runtime_identity_mode" in source:
        release["runtime_identity_mode"] = source["runtime_identity_mode"]
    release.pop("runtime_identity_upgrade", None)
    if "runtime_identity_upgrade" in source:
        release["runtime_identity_upgrade"] = source["runtime_identity_upgrade"]
    validate(release)
    replacements = {previous_images[role]: release["images"][role] for role in ROLES}
    for filename in release["resources"]:
        path = output / filename
        docs = list(yaml.safe_load_all(path.read_text()))
        for doc in docs:
            if not doc:
                continue
            if doc.get("kind") == "ConfigMap" and doc["metadata"]["name"] == app + "-backend-config":
                for key in list(doc.get("data", {})):
                    if key.startswith("DELIVERY_OUTBOX_"):
                        del doc["data"][key]
                if release.get("runtime_identity_mode") == IDENTITY_MODE:
                    doc["data"]["CELERY_TASK_TOPOLOGY_PREDECLARED"] = "true"
            template = doc.get("spec", {}).get("template", {})
            for container in template.get("spec", {}).get("containers", []):
                if container.get("image") in replacements:
                    container["image"] = replacements[container["image"]]
        path.write_text(yaml.safe_dump_all(docs, sort_keys=False, allow_unicode=True))
    configs = {doc["metadata"]["name"]: doc.get("data", {}) for doc in
               yaml.safe_load_all((output / "00-prerequisites.yaml").read_text()) if doc.get("kind") == "ConfigMap"}
    runtime_path = output / "20-runtime.yaml"
    runtime = list(yaml.safe_load_all(runtime_path.read_text()))
    for doc in runtime:
        if doc.get("kind") != "Deployment":
            continue
        name = doc["metadata"]["name"]
        role = "admin" if name.endswith("admin-frontend") else "web" if name.endswith("web-frontend") else "backend"
        config_name = app + ("-backend-config" if role == "backend" else "-" + ROLES[role] + "-config")
        annotations = doc["spec"]["template"].setdefault("metadata", {}).setdefault("annotations", {})
        annotations["sunmoonai.com/config-sha256"] = hashlib.sha256(json.dumps(configs[config_name], sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        annotations["sunmoonai.com/source-commit"] = next(c["commit"] for c in source_lock["components"] if c["path"] == app + "-" + ROLES[role])
    runtime_path.write_text(yaml.safe_dump_all(runtime, sort_keys=False, allow_unicode=True))
    release["sha256"] = {name: hashlib.sha256((output / name).read_bytes()).hexdigest() for name in release["resources"]}
    release["renderer_inputs_sha256"]["development-release-input"] = hashlib.sha256(input_path.read_bytes()).hexdigest()
    release["renderer_inputs_sha256"]["k8s:sunmoonai/app-platform/scripts/development_release.py"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    release_path.write_text(json.dumps(release, ensure_ascii=False, indent=2) + "\n")


def guard(args: Any, release: dict[str, Any], run: Any) -> None:
    """Enforce the target even when deploy.py is called without the shell entry."""
    if release.get("formal_release") is True:
        return
    validate(release)
    if getattr(args, "cluster", None) != "KIND":
        raise ValueError("development deployment requires explicit --cluster KIND")
    if args.action == "plan":
        return
    nodes = json.loads(run(args, "get", "nodes", "-o", "json", capture=True).stdout)["items"]
    if not nodes or any(not node.get("spec", {}).get("providerID", "").startswith("kind://") for node in nodes):
        raise ValueError("refusing development deployment to a non-KIND cluster")
    if args.action != "apply":
        return
    if args.component != "all":
        raise ValueError("development upgrades require the complete App transaction")
    # This release performs a one-time identity bootstrap after migration.
    # Require a bound, completed broker preparation before any deployment write.
    from kind_database_activation import load_preparation
    load_preparation(args, release)
    receipt_path = getattr(args, "backup_receipt", None)
    if not receipt_path:
        raise ValueError("development upgrade requires --backup-receipt after a restore rehearsal")
    receipt = json.loads(Path(receipt_path).read_text())
    namespace = json.loads(run(args, "get", "namespace", "kube-system", "-o", "json", capture=True).stdout)
    if (receipt.get("cluster_uid") != namespace["metadata"]["uid"]
            or receipt.get("logical_app") != release["logical_app"]
            or receipt.get("release_id") != release["release_id"]
            or receipt.get("release_content_sha256") != release_content_sha256(release)
            or receipt.get("cutover_backup_receipt") is not True
            or receipt.get("online_preparation_only") is not False
            or receipt.get("stopped_workloads_verified") is not True
            or receipt.get("rows_unchanged_after_restore") is not True
            or receipt.get("image") != release["images"]["backend"]
            or len(receipt.get("iterations", [])) != 2
            or any(r.get("restore_catalog_equal") is not True or r.get("restore_all_rows_equal") is not True
                   or r.get("migration_head") != release["migration_head"] for r in receipt.get("iterations", []))
            or receipt.get("restore_verified") is not True):
        raise ValueError("backup receipt does not match this App/release/cluster")
    backup = Path(receipt["backup_file"])
    if not backup.is_file() or hashlib.sha256(backup.read_bytes()).hexdigest() != receipt.get("sha256"):
        raise ValueError("backup file is missing or its digest changed")
    deployments = json.loads(run(args, "get", "deployments", "-n", release["namespace"],
                                 "-l", "sunmoonai.com/app=" + release["logical_app"], "-o", "json", capture=True).stdout)
    for item in deployments["items"]:
        if "-backend-" in item["metadata"]["name"] and (
                item.get("spec", {}).get("replicas", 1) != 0 or item.get("status", {}).get("replicas", 0) != 0):
            raise ValueError("stop old API/Worker/Scheduler and wait for termination before migration")
    pods = json.loads(run(args, "get", "pods", "-n", release["namespace"],
                          "-l", "sunmoonai.com/app=" + release["logical_app"], "-o", "json", capture=True).stdout)
    for pod in pods["items"]:
        component = pod.get("metadata", {}).get("labels", {}).get("app.kubernetes.io/component", "")
        if component in ("backend-api", "backend-worker", "backend-scheduler"):
            raise ValueError("old backend Pods still exist; wait for complete termination")
    runtime_secret_gate(args, release, run)
    from kind_database_rehearsal import quiescence
    from types import SimpleNamespace
    quiescence(SimpleNamespace(app=release["logical_app"], kubeconfig=args.kubeconfig))
