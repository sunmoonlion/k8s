#!/usr/bin/env python3
"""Read-only offline Ubuntu signature/index/package verification; no installation.

Trust comes from the verifier host's preinstalled Ubuntu archive keyring, not a
key downloaded alongside the packages. Cloud installation 未经实机验证.
"""
import argparse
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlsplit

from bundle import below, read_lock, sha256, verify
from prepare_os import paragraphs


def verify_os(root, lock, keyring):
    if lock.get("schema") != 1 or lock.get("complete") is not True or lock.get("profile") != "ubuntu-24.04-amd64":
        raise ValueError("Unsupported/incomplete OS lock")
    snapshot = lock["snapshot"]
    if not re.fullmatch(r"[0-9]{8}T[0-9]{6}Z", snapshot):
        raise ValueError("Invalid snapshot")
    source = "https://snapshot.ubuntu.com/ubuntu/" + snapshot
    if lock["source"] != source:
        raise ValueError("Unexpected OS source")
    if root.resolve() != root or not root.is_dir():
        raise ValueError("Invalid OS batch directory")
    verify(root, lock["files"] + lock["indexes"])
    index_records = {item["path"]: item for item in lock["indexes"]}
    prefix = f"state/lists/snapshot.ubuntu.com_ubuntu_{snapshot}_dists_"
    signed_packages = {}
    signatures = []
    expected_indexes = set()
    for suite in ("noble", "noble-updates", "noble-security"):
        name = prefix + suite + "_InRelease"
        expected_indexes.add(name)
        if name not in index_records:
            raise ValueError("Missing signed Release")
        result = subprocess.run(["gpgv", "--keyring", str(keyring), "--output", "-",
                                 str(below(root, name))], capture_output=True, timeout=30)
        if result.returncode:
            raise ValueError("Ubuntu Release signature rejected: " + suite)
        release = result.stdout.decode()
        fields = next(paragraphs(release))
        if fields.get("Suite") != suite or fields.get("Codename") != "noble" or fields.get("Origin") != "Ubuntu":
            raise ValueError("Signed Release identity mismatch")
        now = datetime.now(timezone.utc)
        if parsedate_to_datetime(fields["Date"]) > now:
            raise ValueError("Release date is in the future")
        if fields.get("Valid-Until") and parsedate_to_datetime(fields["Valid-Until"]) < now:
            raise ValueError("Signed Release expired; prepare a new approved snapshot batch")
        section = re.search(r"^SHA256:\n((?: .+\n)+)", release, re.M)
        if not section:
            raise ValueError("Signed Release lacks SHA256")
        hashes = {}
        for line in section[1].splitlines():
            sha, size, path = line.split()
            hashes[path] = (sha, int(size))
        for component in ("main", "universe"):
            upstream = f"{component}/binary-amd64/Packages"
            local = prefix + suite + "_" + upstream.replace("/", "_")
            expected_indexes.add(local)
            item = index_records.get(local)
            if item is None or hashes.get(upstream) != (item["sha256"], item["bytes"]):
                raise ValueError("Packages index differs from signed Release")
            for package in paragraphs(below(root, local).read_text()):
                if "SHA256" in package:
                    key = (package["Package"], package["Version"], package["Architecture"],
                           package["SHA256"], int(package["Size"]))
                    signed_packages.setdefault(key, set()).add(package["Filename"])
        signatures.append({"suite": suite, "verified": True, "release_sha256": sha256(below(root, name))})
    if set(index_records) != expected_indexes:
        raise ValueError("Unexpected index set")
    packages = set()
    for item in lock["files"]:
        key = (item["package"], item["version"], item["architecture"], item["sha256"], item["bytes"])
        if item["package"] in packages or item["architecture"] not in ("amd64", "all"):
            raise ValueError("Duplicate or wrong-architecture package")
        expected_urls = {source + "/" + name for name in signed_packages.get(key, ())}
        if item["url"] not in expected_urls or urlsplit(item["url"]).hostname != "snapshot.ubuntu.com":
            raise ValueError("Package identity differs from signed index: " + item["package"])
        packages.add(item["package"])
    if not set(lock["root_packages"]).issubset(packages):
        raise ValueError("Root dependency missing")
    return {"schema": 1, "profile": lock["profile"], "snapshot": snapshot,
            "packages": len(packages), "package_bytes": sum(f["bytes"] for f in lock["files"]),
            "indexes": len(index_records), "index_bytes": sum(f["bytes"] for f in lock["indexes"]),
            "keyring_sha256": sha256(keyring), "signatures": signatures,
            "all_package_hashes_verified": True, "installed": False,
            "dependency_resolution": "download host empty-status APT; target host still requires offline preflight",
            "cloud_validated": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--lock", type=Path, default=Path(__file__).resolve().with_name("os-dependencies.lock.json"))
    parser.add_argument("--keyring", type=Path, default=Path("/usr/share/keyrings/ubuntu-archive-keyring.gpg"))
    args = parser.parse_args()
    print(json.dumps(verify_os(args.root.expanduser().absolute(), read_lock(args.lock), args.keyring), indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"OS verification stopped: {error}", file=sys.stderr)
        sys.exit(1)
