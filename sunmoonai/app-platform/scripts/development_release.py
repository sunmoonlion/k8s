"""KIND-only development mode for the existing render/deploy pipeline."""
from __future__ import annotations

import ast
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

import yaml

ARCHITECTURE = "app-platform-v2-development"
SHA = re.compile(r"[0-9a-f]{40}")
DIGEST = re.compile(r"[^\s]+@sha256:[0-9a-f]{64}")
ROLES = {"backend": "backend", "admin": "admin-frontend", "web": "web-frontend"}


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
    receipt_path = getattr(args, "backup_receipt", None)
    if not receipt_path:
        raise ValueError("development upgrade requires --backup-receipt after a restore rehearsal")
    receipt = json.loads(Path(receipt_path).read_text())
    namespace = json.loads(run(args, "get", "namespace", "kube-system", "-o", "json", capture=True).stdout)
    if (receipt.get("cluster_uid") != namespace["metadata"]["uid"]
            or receipt.get("logical_app") != release["logical_app"]
            or receipt.get("release_id") != release["release_id"]
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
