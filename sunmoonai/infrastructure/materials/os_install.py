#!/usr/bin/env python3
"""Offline OS baseline for fresh dedicated Ubuntu nodes. 云上未经实机验证。

Default only prints. Explicit --apply requires complete locks, recorded machine
identity and a clean dedicated host. No downloads, downgrades, package removal,
cluster reset, automatic dpkg repair, hostname change or disk/volume operations.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from bundle import below, read_lock, resolve, sha256, verify
from node_install import host_preflight
from verify_os import verify_os

BASELINE = {
    "/etc/modules-load.d/90-sunmoon-kubernetes.conf": "overlay\nbr_netfilter\n",
    "/etc/sysctl.d/90-sunmoon-kubernetes.conf": (
        "net.ipv4.ip_forward = 1\nnet.bridge.bridge-nf-call-iptables = 1\n"
        "net.bridge.bridge-nf-call-ip6tables = 1\n"),
}


def run(argv, env=None, timeout=120):
    return subprocess.run(argv, env=env, check=True, text=True, capture_output=True, timeout=timeout).stdout


def safe_directory(path):
    for directory in reversed((path, *path.parents)):
        if directory.resolve() != directory:
            raise ValueError("Symlinked OS work path refused")
        if not directory.exists():
            directory.mkdir(mode=0o755)
        stat = directory.stat()
        if not directory.is_dir() or stat.st_uid != 0 or stat.st_mode & 0o022:
            raise ValueError("OS work path must be root-owned and not writable by others")


def exact_file(path, raw, mode=0o644):
    if path.resolve() != path:
        raise ValueError("Symlinked OS file refused")
    if path.exists():
        stat = path.stat()
        if not path.is_file() or path.read_bytes() != raw or stat.st_uid != 0 or stat.st_mode & 0o777 != mode:
            raise ValueError("Different existing OS file retained: " + str(path))
        return
    safe_directory(path.parent)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)
    with os.fdopen(fd, "wb") as output:
        output.write(raw); output.flush(); os.fchmod(output.fileno(), mode); os.fsync(output.fileno())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=Path(__file__).resolve().with_name("cluster-artifacts.lock.json"))
    parser.add_argument("--root", type=Path, default=Path.home() / "packages-to-be-installed")
    parser.add_argument("--hostname")
    parser.add_argument("--machine-id")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    data, entries = resolve(args.manifest)
    child = data["os_dependency_lock"]
    lock = read_lock(below(args.manifest.resolve().parent, child["path"]), child["sha256"])
    if not args.apply:
        print(json.dumps({"dry_run": True, "cloud_status": "未经实机验证", "profile": lock["profile"],
                          "packages": len(lock["files"]), "closure_complete": data["closure_complete"],
                          "configurations": BASELINE, "download": False,
                          "order": ["identity/OS/locks/signatures", "no swap or competing clock daemon",
                                    "root-owned verified package stage", "offline apt simulation/no downgrade or removal",
                                    "offline install", "kernel parameters and NTP", "journal"]}, ensure_ascii=False, indent=2))
        return
    if data.get("closure_complete") is not True or data.get("pending"):
        raise ValueError("Deployment closure incomplete")
    host_preflight(args, baseline_ready=False)
    root = args.root.expanduser().absolute()
    if root.resolve() != root or not root.is_dir():
        raise ValueError("Invalid material root")
    verify(root, entries)
    batch = below(root, f"releases/{data['batch']}/os/{lock['profile']}-{lock['snapshot']}")
    verify_os(batch, lock, Path("/usr/share/keyrings/ubuntu-archive-keyring.gpg"))
    if len(Path("/proc/swaps").read_text().splitlines()) > 1:
        raise ValueError("Active swap refused; provision the dedicated node without swap first")
    for line in Path("/etc/fstab").read_text().splitlines():
        fields = line.split()
        if fields and not fields[0].startswith("#") and len(fields) >= 3 and fields[2] == "swap":
            raise ValueError("fstab swap refused; no automatic fstab rewrite")
    if run(["dpkg", "--audit"]).strip():
        raise ValueError("dpkg has unfinished work; automatic repair refused")
    if run(["dpkg", "--print-foreign-architectures"]).strip():
        raise ValueError("This fresh-node OS profile does not support foreign package architectures")
    installed = {}
    query = run(["dpkg-query", "-W", "-f=${Package}\t${Version}\t${db:Status-Status}\n"])
    for line in query.splitlines():
        name, version, status = line.split("\t")
        if status == "installed":
            installed[name] = version
    if set(installed) & {"chrony", "ntp", "ntpsec", "openntpd"}:
        raise ValueError("Competing clock daemon installed; choose an explicit compatible baseline")
    for item in lock["files"]:
        if item["package"] in installed:
            compare = subprocess.run(["dpkg", "--compare-versions", installed[item["package"]], "gt", item["version"]], check=False)
            if compare.returncode not in (0, 1):
                raise ValueError("Cannot compare package versions")
            if compare.returncode == 0:
                raise ValueError("Installed package newer than snapshot; downgrade refused: " + item["package"])
    for name, content in BASELINE.items():
        path = Path(name)
        if path.resolve() != path or (path.exists() and (not path.is_file()
                or path.read_text() != content or path.stat().st_uid != 0 or path.stat().st_mode & 0o777 != 0o644)):
            raise ValueError("Existing OS baseline differs; retained: " + name)
    # Pin a root-owned staging copy before apt/dpkg can consume any user-writable
    # material. Retain it and logs for interrupted-install inspection/rollback.
    work = Path("/var/lib/sunmoon/bootstrap") / (data["batch"] + "-os-" + child["sha256"][:16])
    safe_directory(work)
    identity = {"schema": 1, "hostname": args.hostname, "machine_id": args.machine_id,
                "manifest_sha256": sha256(args.manifest), "os_lock_sha256": child["sha256"]}
    exact_file(work / "identity.json", (json.dumps(identity, sort_keys=True) + "\n").encode())
    packages = []
    for item in lock["files"]:
        raw = below(batch, item["path"]).read_bytes()
        if __import__("hashlib").sha256(raw).hexdigest() != item["sha256"]:
            raise ValueError("Package changed while staging")
        staged = work / "debs" / Path(item["path"]).name
        exact_file(staged, raw, 0o444)
        packages.append(str(staged))
    for relative in ("etc/parts", "etc/sourceparts", "etc/preferencesparts", "state/lists", "cache/archives/partial", "logs"):
        safe_directory(work / relative)
    for relative in ("etc/main", "etc/preferences", "etc/sources.list"):
        exact_file(work / relative, b"")
    config = f'''Dir::Etc "{work}/etc";
Dir::Etc::main "main";
Dir::Etc::parts "parts";
Dir::Etc::sourcelist "sources.list";
Dir::Etc::sourceparts "sourceparts";
Dir::Etc::preferences "preferences";
Dir::Etc::preferencesparts "preferencesparts";
Dir::State "{work}/state";
Dir::State::status "/var/lib/dpkg/status";
Dir::Cache "{work}/cache";
Dir::Log "{work}/logs";
APT::Architecture "amd64";
APT::Install-Recommends "false";
APT::Get::Download "false";
APT::Get::Remove "false";
DPkg::Options {{ "--force-confdef"; "--force-confold"; }};
'''
    exact_file(work / "apt.conf", config.encode())
    env = {"PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "LC_ALL": "C",
           "DEBIAN_FRONTEND": "noninteractive", "APT_CONFIG": str(work / "apt.conf")}
    dumped = run(["apt-config", "dump"], env)
    if any(x in dumped for x in ("Pre-Invoke", "Post-Invoke", "Pre-Install-Pkgs")):
        raise ValueError("Unexpected inherited APT hook")
    command = ["apt-get", "--no-download", "--no-remove", "--no-install-recommends", "install", *packages]
    simulation = run(["apt-get", "--simulate", *command[1:]], env)
    if re.search(r"^(Remv|Purg) ", simulation, re.M):
        raise ValueError("Package removal planned; refused")
    allowed = {(x["package"], x["version"]) for x in lock["files"]}
    planned = {(name.removesuffix(":amd64"), version) for name, version in re.findall(
        r"^Inst (\S+)(?: \[[^\]]+\])? \((\S+)", simulation, re.M)}
    if not planned.issubset(allowed):
        raise ValueError("APT simulation requests a package outside the lock")
    stamp = str(__import__("time").time_ns())
    exact_file(work / "logs" / (stamp + "-simulation.txt"), simulation.encode())
    # No retries: maintainer scripts may already have changed the fresh host.
    # Any error stops with the journal and apt log preserved for inspection.
    with (work / "logs" / (stamp + "-install.txt")).open("xb") as log:
        subprocess.run(["apt-get", "--assume-yes", *command[1:]], env=env, check=True,
                       stdout=log, stderr=subprocess.STDOUT, timeout=1800)
    for item in lock["files"]:
        actual = run(["dpkg-query", "-W", "-f=${Version}\t${db:Status-Status}", item["package"]]).strip()
        if actual != item["version"] + "\tinstalled":
            raise ValueError("Installed package identity differs: " + item["package"])
    for module in ("overlay", "br_netfilter"):
        run(["modprobe", module])
    for name, content in BASELINE.items():
        exact_file(Path(name), content.encode())
    run(["sysctl", "-p", "/etc/sysctl.d/90-sunmoon-kubernetes.conf"])
    if "nf_tables" not in run(["iptables", "--version"]):
        raise ValueError("Expected nft iptables backend; no automatic firewall switch")
    run(["systemctl", "enable", "--now", "systemd-timesyncd"])
    run(["systemctl", "is-active", "--quiet", "systemd-timesyncd"])
    if run(["timedatectl", "show", "--property=NTPSynchronized", "--value"]).strip() != "yes":
        raise ValueError("Clock has not synchronized; do not proceed to kubeadm yet")
    host_preflight(args)
    exact_file(work / "complete.json", (json.dumps({**identity, "state": "complete"}, sort_keys=True) + "\n").encode())
    print(json.dumps({"state": "complete", "journal": str(work), "packages": len(packages), "cluster_ready": False}))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"Offline OS installation stopped: {error}", file=sys.stderr)
        sys.exit(1)
