#!/usr/bin/env python3
"""Read-only cluster material resolver shared by transfer and installation.

No download, extraction, container, service, or deletion operations. A successful
verify checks the selected files only; --require-complete additionally requires
all deployment closure gates in the root lock. Cloud 未经实机验证.
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path, PurePosixPath

HEX = re.compile(r"[0-9a-f]{64}\Z")
SCOPES = ("tools", "images", "calico", "configuration", "os", "storage", "ingress")


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def relative_path(value):
    if not isinstance(value, str) or not value or any(c in value for c in "\x00\r\n\\"):
        raise ValueError("Invalid material path")
    path = PurePosixPath(value)
    if path.is_absolute() or any(p in (".", "..") for p in value.split("/")):
        raise ValueError("Material path must be a normalized relative path")
    if str(path) != value or not re.fullmatch(r"[A-Za-z0-9_.@/+:%~-]+", value):
        raise ValueError("Unsupported character in material path")
    return path


def below(root, relative):
    path = root / relative_path(relative)
    if path.resolve() != path or not path.is_relative_to(root):
        raise ValueError("Symlink or escaping material path refused")
    return path


def read_lock(path, expected=None):
    if path.is_symlink() or not path.is_file():
        raise ValueError("Lock file missing or symlinked")
    raw = path.read_bytes()
    if expected is not None and hashlib.sha256(raw).hexdigest() != expected:
        raise ValueError("Child lock checksum differs from root lock")
    return json.loads(raw)


def resolve(manifest):
    manifest = manifest.expanduser().absolute()
    if manifest.resolve() != manifest:
        raise ValueError("Symlinked manifest path refused")
    data = read_lock(manifest)
    if data.get("schema") != 1:
        raise ValueError("Unsupported root lock schema")
    batch = str(relative_path(data["batch"]))
    if "/" in batch:
        raise ValueError("Batch must be one directory name")
    base = f"releases/{batch}"
    entries = []

    def add(scope, record, path):
        digest = record.get("sha256", "")
        if not HEX.fullmatch(digest):
            raise ValueError("Every artifact must have a locked SHA256")
        relative_path(path)
        size = record.get("bytes")
        if size is not None and (type(size) is not int or size <= 0):
            raise ValueError("Invalid locked file size")
        entries.append({"scope": scope, "path": path, "sha256": digest, "bytes": size})

    for record in data["files"]:
        add("tools", record, f"{base}/{relative_path(record['path'])}")
    child = data["kubeadm_image_archive_lock"]
    if not HEX.fullmatch(child["sha256"]):
        raise ValueError("Invalid image lock SHA256")
    images = read_lock(below(manifest.parent, child["path"]), child["sha256"])
    if images.get("schema") != 1 or images.get("batch") != batch or images.get("platform") != "linux/amd64" or images.get("complete") is not True:
        raise ValueError("Image lock is incomplete or for another batch/platform")
    sources = [item["source"] for item in images["images"]]
    if sources != data["kubeadm_images"] or len(set(sources)) != len(sources):
        raise ValueError("Kubeadm source set differs between locks")
    for record in images["images"]:
        for field in ("platform_digest", "config_digest", "index_digest"):
            if not re.fullmatch(r"sha256:[0-9a-f]{64}", record.get(field, "")):
                raise ValueError("Incomplete image identity")
        add("images", record, f"{base}/{relative_path(record['path'])}")
    for record in data["shared_calico_materials"]:
        add("calico", record, record["material_root_relative_path"])
    for record in data.get("configuration_files", []):
        add("configuration", record, f"{base}/{relative_path(record['path'])}")
    if "storage_image_lock" in data:
        child = data['storage_image_lock']
        storage = read_lock(below(manifest.parent, child['path']), child['sha256'])
        if storage.get('complete') is not True or storage.get('platform') != 'linux/amd64':
            raise ValueError('Storage image lock incomplete or unsupported')
        for record in storage['images']:
            add('storage', record, record['material_path'])
    if 'ingress_image_lock' in data:
        child = data['ingress_image_lock']
        ingress = read_lock(below(manifest.parent, child['path']), child['sha256'])
        if ingress.get('complete') is not True or ingress.get('platform') != 'linux/amd64':
            raise ValueError('Ingress image lock incomplete or unsupported')
        for record in ingress['images']:
            add('ingress', record, record['material_path'])
    if 'ingress_resource_lock' in data:
        child = data['ingress_resource_lock']
        resources = read_lock(below(manifest.parent, child['path']), child['sha256'])
        if (resources.get('schema') != 1 or resources.get('complete') is not True
                or resources.get('traefik_version') != 'v' + data['versions']['traefik']
                or resources.get('chart_version') != data['versions']['traefik_chart']
                or resources.get('kubernetes_version') != data['versions']['kubernetes']):
            raise ValueError('Ingress resource versions differ from root lock')
        if {r['name'] for r in resources['files']} != {'crds.json', 'dev.json', 'prod.json'}:
            raise ValueError('Expected CRDs and both ingress profiles')
        for record in resources['files'] + resources['archives']:
            add('ingress', record, record['material_path'])
    if "os_dependency_lock" in data:
        child = data["os_dependency_lock"]
        if not HEX.fullmatch(child["sha256"]):
            raise ValueError("Invalid OS lock SHA256")
        os_lock = read_lock(below(manifest.parent, child["path"]), child["sha256"])
        if (os_lock.get("schema") != 1 or os_lock.get("complete") is not True
                or os_lock.get("profile") != "ubuntu-24.04-amd64"
                or not re.fullmatch(r"[0-9]{8}T[0-9]{6}Z", os_lock.get("snapshot", ""))):
            raise ValueError("Incomplete or unsupported OS dependency lock")
        prefix = f"{base}/os/{os_lock['profile']}-{os_lock['snapshot']}"
        packages = []
        for record in os_lock["files"]:
            if record["architecture"] not in ("amd64", "all") or not record["version"]:
                raise ValueError("Wrong OS package architecture/version")
            packages.append(record["package"])
            add("os", record, f"{prefix}/{relative_path(record['path'])}")
        if len(set(packages)) != len(packages) or not set(os_lock["root_packages"]).issubset(packages):
            raise ValueError("Missing or duplicate OS package identity")
        for record in os_lock["indexes"]:
            add("os", record, f"{prefix}/{relative_path(record['path'])}")
    paths = [entry["path"] for entry in entries]
    if len(paths) != len(set(paths)):
        raise ValueError("Duplicate material path in lock")
    return data, entries


def verify(root, entries):
    results = []
    for entry in entries:
        path = below(root, entry["path"])
        if not path.is_file():
            raise ValueError(f"Missing material: {entry['path']}")
        size = path.stat().st_size
        if entry["bytes"] is not None and size != entry["bytes"]:
            raise ValueError(f"Material size mismatch: {entry['path']}")
        if sha256(path) != entry["sha256"]:
            raise ValueError(f"Material SHA256 mismatch: {entry['path']}")
        results.append({**entry, "bytes": size})
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("plan", "verify", "files", "checksums"))
    parser.add_argument("--manifest", type=Path, default=Path(__file__).resolve().with_name("cluster-artifacts.lock.json"))
    parser.add_argument("--root", type=Path, default=Path.home() / "packages-to-be-installed")
    parser.add_argument("--scope", choices=("all", *SCOPES), default="all")
    parser.add_argument("--require-complete", action="store_true")
    parser.add_argument("--expected-kubernetes", help="Require deployment configuration to match the root lock")
    parser.add_argument("--null", action="store_true", help="NUL-separated paths for rsync --from0 --files-from")
    args = parser.parse_args()
    root = args.root.expanduser().absolute()
    if root.resolve() != root or not root.is_dir():
        raise ValueError("Material root must be an existing non-symlink directory")
    data, entries = resolve(args.manifest)
    if args.expected_kubernetes and args.expected_kubernetes.removeprefix("v") != data["versions"]["kubernetes"]:
        raise ValueError("Deployment Kubernetes version differs from the material lock")
    if args.require_complete and (data.get("closure_complete") is not True or data.get("pending")):
        raise ValueError("Deployment closure incomplete; installation is not admitted")
    if args.scope != "all":
        entries = [e for e in entries if e["scope"] == args.scope]
    if not entries:
        raise ValueError("Selected scope has no locked files")
    # Machine-readable transfer lists are emitted only after complete local
    # checksum verification of the selected set. No guessed/globbed paths.
    if args.action != "plan":
        entries = verify(root, entries)
    if args.action == "files":
        sys.stdout.write(("\0" if args.null else "\n").join(e["path"] for e in entries) + ("\0" if args.null else "\n"))
    elif args.action == "checksums":
        for entry in entries:
            print(f"{entry['sha256']}  {entry['path']}")
    else:
        print(json.dumps({"schema": 1, "action": args.action, "batch": data["batch"],
                          "versions": data["versions"], "root": str(root),
                          "files_verified": args.action == "verify",
                          "closure_complete": data.get("closure_complete") is True,
                          "pending": data.get("pending", []), "install_admitted": False,
                          "files": entries}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Material validation failed: {error}", file=sys.stderr)
        sys.exit(1)
