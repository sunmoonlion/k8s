#!/usr/bin/env python3
"""Prepare public Ubuntu dependencies in isolated APT directories; never install.

Default prints a plan. --apply downloads only, without sudo, dpkg installation,
host APT configuration changes, services, or cleanup. Cloud 未经实机验证.
An empty dpkg status prevents the download host's installed packages from
silently satisfying dependencies. Signed official snapshot indexes pin inputs.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT_PACKAGES = (
    "python3", "rsync", "iproute2", "iptables", "conntrack", "socat",
    "ethtool", "kmod", "mount", "util-linux", "procps", "libseccomp2",
    "ca-certificates", "openssl", "jq", "tar", "gzip", "systemd",
    "systemd-sysv", "systemd-timesyncd",
)
KEYRING = Path("/usr/share/keyrings/ubuntu-archive-keyring.gpg")


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def create_exact(path, content):
    if path.is_symlink():
        raise ValueError("Symlink refused: " + str(path))
    raw = content.encode()
    if path.exists():
        if path.read_bytes() != raw:
            raise ValueError("Existing different input retained: " + str(path))
    else:
        with path.open("xb") as stream:
            stream.write(raw)


def paragraphs(raw):
    for block in raw.strip().split("\n\n"):
        record = {}
        for line in block.splitlines():
            if line and not line[0].isspace() and ": " in line:
                key, value = line.split(": ", 1)
                record[key] = value
        if record:
            yield record


def run_logged(command, env, root, phase, timeout):
    log = root / "logs" / f"{time.time_ns()}-{phase}.log"
    print(json.dumps({"phase": phase, "log": str(log)}), flush=True)
    with log.open("xb") as output:
        result = subprocess.run(command, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"{phase} failed ({result.returncode}); retained log {log}")
    return log


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True,
                        help="Dedicated new OS material batch directory")
    parser.add_argument("--snapshot", default="20260927T000000Z")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    root = args.root.expanduser().absolute()
    if root.resolve() != root or not re.fullmatch(r"/[A-Za-z0-9_./-]+", str(root)):
        raise ValueError("Root must be an absolute, non-symlink path without special characters")
    if not re.fullmatch(r"[0-9]{8}T[0-9]{6}Z", args.snapshot):
        raise ValueError("Invalid snapshot timestamp")
    if root.name != "ubuntu-24.04-amd64-" + args.snapshot:
        raise ValueError("Dedicated root basename must include profile and snapshot")
    url = "https://snapshot.ubuntu.com/ubuntu/" + args.snapshot
    print(json.dumps({"dry_run": not args.apply, "root": str(root), "source": url,
                      "roots": ROOT_PACKAGES, "installed_status": "empty isolated file",
                      "host_install": False, "cloud_validated": False}), flush=True)
    if not args.apply:
        return
    if os.geteuid() == 0:
        raise ValueError("Run the downloader as an unprivileged user, without sudo")
    if os.uname().machine != "x86_64" or not KEYRING.is_file():
        raise ValueError("Requires amd64 Ubuntu download host and its trusted archive keyring")
    for command in ("apt-get", "apt-cache", "apt-config", "dpkg-deb"):
        if not shutil.which(command):
            raise ValueError("Missing download tool: " + command)
    ancestor = root
    while not ancestor.exists():
        ancestor = ancestor.parent
    if shutil.disk_usage(ancestor).free < 6 * 1024**3:
        raise ValueError("Less than 6 GiB free; no cleanup attempted")
    if root.exists() and not (root / "sunmoon-os-download.json").is_file():
        raise ValueError("Existing directory is not an owned OS download batch")
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    create_exact(root / "sunmoon-os-download.json", json.dumps({
        "schema": 1, "snapshot": args.snapshot, "roots": ROOT_PACKAGES,
        "keyring_sha256": digest(KEYRING)}, sort_keys=True) + "\n")
    for relative in ("etc/parts", "etc/sourceparts", "etc/preferencesparts",
                     "state/lists/partial", "cache/archives/partial", "logs", "evidence"):
        directory = root / relative
        if directory.resolve() != directory:
            raise ValueError("Symlinked work directory refused")
        directory.mkdir(parents=True, exist_ok=True)
    for relative in ("etc/main", "etc/preferences", "state/status"):
        create_exact(root / relative, "")
    sources = "".join(
        f"deb [arch=amd64 signed-by={KEYRING}] {url} {suite} main universe\n"
        for suite in ("noble", "noble-updates", "noble-security"))
    create_exact(root / "etc/sources.list", sources)
    config = f'''Dir::Etc "{root}/etc";
Dir::Etc::main "main";
Dir::Etc::parts "parts";
Dir::Etc::sourcelist "sources.list";
Dir::Etc::sourceparts "sourceparts";
Dir::Etc::preferences "preferences";
Dir::Etc::preferencesparts "preferencesparts";
Dir::State "{root}/state";
Dir::State::status "{root}/state/status";
Dir::State::lists "lists";
Dir::State::extended_states "extended_states";
Dir::Cache "{root}/cache";
Dir::Cache::archives "archives";
Dir::Cache::pkgcache "pkgcache.bin";
Dir::Cache::srcpkgcache "srcpkgcache.bin";
Dir::Log "{root}/logs";
APT::Architecture "amd64";
APT::Architectures {{ "amd64"; }};
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::Get::AllowUnauthenticated "false";
APT::Update::Error-Mode "any";
Acquire::Languages "none";
Acquire::Retries "2";
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
Acquire::https::Verify-Peer "true";
Acquire::https::Verify-Host "true";
Acquire::Check-Valid-Until "true";
Acquire::AllowInsecureRepositories "false";
Acquire::AllowDowngradeToInsecureRepositories "false";
'''
    create_exact(root / "apt.conf", config)
    env = {**os.environ, "APT_CONFIG": str(root / "apt.conf"), "LC_ALL": "C"}
    before = digest(Path("/var/lib/dpkg/status"))
    config_dump = subprocess.check_output(["apt-config", "dump"], env=env, text=True)
    if any(x in config_dump for x in ("Pre-Invoke", "Post-Invoke", "Pre-Install-Pkgs")):
        raise ValueError("APT hooks detected; isolation failed")
    create_exact(root / "evidence/apt-config.txt", config_dump)
    existing_lock = root / "os-dependencies.lock.json"
    if existing_lock.exists():
        locked = json.loads(existing_lock.read_text())
        if locked.get("complete") is not True or locked.get("snapshot") != args.snapshot:
            raise ValueError("Existing lock is incomplete or for another snapshot")
        for item in locked["files"] + locked["indexes"]:
            path = root / item["path"]
            if (not path.is_relative_to(root) or path.resolve() != path
                    or digest(path) != item["sha256"] or path.stat().st_size != item["bytes"]):
                raise ValueError("Completed batch changed; preserved for inspection")
        print(json.dumps({"complete": True, "reused": True, "files": len(locked["files"])}))
        return
    run_logged(["apt-get", "update"], env, root, "indexes", 600)
    simulate = run_logged(["apt-get", "--simulate", "--no-install-recommends", "install", *ROOT_PACKAGES],
                          env, root, "resolve", 120)
    run_logged(["apt-get", "--download-only", "--assume-yes", "--no-install-recommends",
                "install", *ROOT_PACKAGES], env, root, "download", 1800)
    planned = set(re.findall(r"^Inst ([^ :]+)(?::amd64)? ", simulate.read_text(), re.M))
    if not set(ROOT_PACKAGES).issubset(planned):
        raise ValueError("Empty-status resolution did not include every root package")
    files, packages = [], set()
    for archive in sorted((root / "cache/archives").glob("*.deb")):
        if archive.is_symlink():
            raise ValueError("Symlink archive refused")
        raw = subprocess.check_output(["dpkg-deb", "-f", str(archive)], text=True)
        info = next(paragraphs(raw))
        name, version, arch = info["Package"], info["Version"], info["Architecture"]
        if name in packages or arch not in ("amd64", "all"):
            raise ValueError("Duplicate package or wrong architecture")
        metadata = subprocess.check_output(["apt-cache", "show", f"{name}={version}"], env=env, text=True)
        size, sha = archive.stat().st_size, digest(archive)
        matching = [r for r in paragraphs(metadata) if r.get("SHA256") == sha
                    and r.get("Size") == str(size) and r.get("Architecture") == arch]
        if not matching:
            raise ValueError("Archive differs from signed index: " + name)
        source = matching[0]["Filename"]
        if not source.startswith("pool/") or ".." in source.split("/"):
            raise ValueError("Unexpected upstream archive path")
        files.append({"path": str(archive.relative_to(root)), "package": name,
                      "version": version, "architecture": arch, "sha256": sha,
                      "bytes": size, "url": url + "/" + source})
        packages.add(name)
    if packages != planned:
        raise ValueError("Archive set differs from resolved dependency set")
    after = digest(Path("/var/lib/dpkg/status"))
    if before != after or (root / "state/status").stat().st_size:
        raise ValueError("Host or isolated dpkg status changed; investigate before accepting")
    indexes = [{"path": str(p.relative_to(root)), "sha256": digest(p), "bytes": p.stat().st_size}
               for p in sorted((root / "state/lists").iterdir()) if p.is_file() and p.name != "lock"]
    lock = {"schema": 1, "profile": "ubuntu-24.04-amd64", "snapshot": args.snapshot,
            "complete": True, "deployment_validated": False, "root_packages": ROOT_PACKAGES,
            "host_dpkg_status_unchanged": True, "host_dpkg_status_sha256": before,
            "keyring_sha256": digest(KEYRING), "source": url, "files": files,
            "indexes": indexes, "total_bytes": sum(f["bytes"] for f in files)}
    create_exact(existing_lock, json.dumps(lock, indent=2) + "\n")
    print(json.dumps({"complete": True, "packages": len(files), "bytes": lock["total_bytes"],
                      "lock": str(existing_lock), "host_installed": False}), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, KeyError, subprocess.SubprocessError) as error:
        print(f"OS material preparation stopped: {error}", file=sys.stderr)
        sys.exit(1)
