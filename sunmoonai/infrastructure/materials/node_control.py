#!/usr/bin/env python3
"""Publish audited node installer and invoke one phase over strict SSH.

Default is print-only, without SSH. Cloud 未经实机验证. Actual use requires a
complete lock, all local materials, and explicit pre-recorded machine identity.
Only the public installer/locks are published, never a repository or secrets.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys

from bundle import resolve, verify

PUBLIC_FILES = ("node_install.py", "os_install.py", "verify_os.py", "prepare_os.py",
                "bundle.py", "cluster_config.py", "cluster_node.py", "image_import.py",
                "cluster-artifacts.lock.json", "kubeadm-images.lock.json", "os-dependencies.lock.json")

REMOTE = r'''
import base64,hashlib,json,os,pwd,re,socket,stat,sys,time
from pathlib import Path
p=json.load(sys.stdin)
if os.geteuid()!=0 or sys.version_info<(3,11): raise SystemExit('Root and Python >=3.11 required')
if socket.gethostname()!=p['hostname'] or Path('/etc/machine-id').read_text().strip()!=p['machine_id']:
    raise SystemExit('Recorded machine identity differs; no control files published')
if 'microsoft' in os.uname().release.lower() or Path('/.dockerenv').exists():
    raise SystemExit('WSL/container is not a fresh cloud node')
cluster_phases={'preflight','images','init','cni','ticket','join','status','revoke'}
if p['phase'] not in cluster_phases|{'os','runtime','kubernetes'}: raise SystemExit('Unknown node phase')
protected=['/var/lib/docker','/data/harbor']
if p['phase'] not in cluster_phases: protected+=['/etc/kubernetes','/var/lib/kubelet','/var/lib/etcd']
for value in protected:
    path=Path(value)
    if path.exists() and (value in ('/var/lib/docker','/data/harbor') or not path.is_dir() or any(path.iterdir())):
        raise SystemExit('Existing service or cluster state refused')
root=Path(p['remote_root'])
if not root.is_absolute(): root=Path(pwd.getpwnam(p['user']).pw_dir)/root
if root.resolve()!=root or root.name!='packages-to-be-installed' or not root.is_dir():
    raise SystemExit('Invalid/missing remote material root')
expected={'node_install.py','os_install.py','verify_os.py','prepare_os.py','bundle.py',
          'cluster_config.py','cluster_node.py','image_import.py',
          'cluster-artifacts.lock.json','kubeadm-images.lock.json','os-dependencies.lock.json'}
if set(p['files'])!=expected: raise SystemExit('Unexpected public control file set')
contents={}
identity={}
for name,record in p['files'].items():
    raw=base64.b64decode(record['base64'],validate=True)
    if hashlib.sha256(raw).hexdigest()!=record['sha256']: raise SystemExit('Public code checksum differs')
    contents[name]=raw
    identity[name]=record['sha256']
release=hashlib.sha256(json.dumps(identity,sort_keys=True,separators=(',',':')).encode()).hexdigest()
if release!=p['release']: raise SystemExit('Code release identity differs')
destination=Path('/opt/sunmoon/bootstrap')/release
for directory in reversed((destination,*destination.parents)):
    if directory.resolve()!=directory: raise SystemExit('Symlinked control directory refused')
    if not directory.exists(): directory.mkdir(mode=0o755)
    st=directory.stat()
    if not stat.S_ISDIR(st.st_mode) or st.st_uid!=0 or st.st_mode & 0o022:
        raise SystemExit('Control directory must be root owned and not writable by others')
if set(x.name for x in destination.iterdir())-expected: raise SystemExit('Unexpected control files retained; inspect manually')
for name,raw in contents.items():
    path=destination/name
    if path.is_symlink(): raise SystemExit('Symlinked control file refused')
    if path.exists():
        st=path.stat()
        if not path.is_file() or st.st_uid!=0 or st.st_mode & 0o222 or path.read_bytes()!=raw:
            raise SystemExit('Existing code differs or is writable; retained')
    else:
        fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o444)
        with os.fdopen(fd,'wb') as f:
            f.write(raw);f.flush();os.fchmod(f.fileno(),0o444);os.fsync(f.fileno())
entry='cluster_node.py' if p['phase'] in cluster_phases else ('os_install.py' if p['phase']=='os' else 'node_install.py')
argv=['/usr/bin/python3','-B','-E','-s',str(destination/entry),
      '--manifest',str(destination/'cluster-artifacts.lock.json'),'--root',str(root),
      '--hostname',p['hostname'],'--machine-id',p['machine_id'],'--apply']
if p['phase']!='os': argv+=['--phase',p['phase']]
if p['phase'] in cluster_phases:
    request_dir=Path('/var/lib/sunmoon/requests')/release
    for directory in reversed((request_dir,*request_dir.parents)):
        if directory.resolve()!=directory: raise SystemExit('Symlinked request directory')
        if not directory.exists(): directory.mkdir(mode=0o700)
        st=directory.stat()
        if not directory.is_dir() or st.st_uid!=0 or st.st_mode & 0o022: raise SystemExit('Unsafe request directory')
    request=request_dir/('request-'+str(time.time_ns())+'.json')
    fd=os.open(request,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'w') as f: json.dump(p['request'],f)
    argv+=['--request',str(request)]
else:
    print(json.dumps({'public_release':release,'phase':p['phase'],'identity_checked':True}),flush=True)
os.execve(argv[0],argv,{'PATH':'/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
                       'LC_ALL':'C','PYTHONDONTWRITEBYTECODE':'1'})
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=("os", "runtime", "kubernetes"), required=True)
    parser.add_argument("--root", type=Path, default=Path.home() / "packages-to-be-installed")
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, default=22)
    parser.add_argument("--identity", type=Path)
    parser.add_argument("--hostname", default="")
    parser.add_argument("--machine-id", default="")
    parser.add_argument("--remote-root", default="packages-to-be-installed")
    parser.add_argument("--expected-kubernetes", required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z_][a-z0-9_-]*@[A-Za-z0-9][A-Za-z0-9.-]*", args.host) or not 1 <= args.port <= 65535:
        raise ValueError("Invalid SSH destination")
    remote_root = args.remote_root.removeprefix("~/")
    if (not re.fullmatch(r"[A-Za-z0-9_./-]+", remote_root)
            or ".." in Path(remote_root).parts or Path(remote_root).name != "packages-to-be-installed"):
        raise ValueError("Invalid remote material directory")
    directory = Path(__file__).resolve().parent
    manifest = directory / "cluster-artifacts.lock.json"
    data, entries = resolve(manifest)
    files, identities = {}, {}
    for name in PUBLIC_FILES:
        path = directory / name
        if path.is_symlink():
            raise ValueError("Symlinked public control file")
        raw = path.read_bytes()
        identities[name] = hashlib.sha256(raw).hexdigest()
        files[name] = {"sha256": identities[name], "base64": base64.b64encode(raw).decode()}
    release = hashlib.sha256(json.dumps(identities, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    ssh = ["ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=10",
           "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=3", "-p", str(args.port)]
    if args.identity:
        ssh += ["-o", "IdentitiesOnly=yes", "-i", str(args.identity.expanduser().absolute())]
    if not args.apply:
        print(json.dumps({"dry_run": True, "cloud_status": "未经实机验证", "phase": args.phase,
                          "host": args.host, "public_release": release, "public_files": identities,
                          "remote_root": remote_root, "configured_version": args.expected_kubernetes,
                          "locked_version": data["versions"]["kubernetes"],
                          "closure_complete": data["closure_complete"],
                          "machine_identity_configured": bool(args.hostname and args.machine_id),
                          "required_before_apply": ["complete lock and version match", "all local SHA256",
                              "explicit hostname and machine-id", "remote OS baseline", "remote material SHA256"],
                          "ssh_started": False}, ensure_ascii=False, indent=2))
        return
    if data.get("closure_complete") is not True or data.get("pending"):
        raise ValueError("Installation closure incomplete")
    if args.expected_kubernetes.removeprefix("v") != data["versions"]["kubernetes"]:
        raise ValueError("Configured Kubernetes differs from lock")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]{0,252}", args.hostname) or not re.fullmatch(r"[0-9a-f]{32}", args.machine_id):
        raise ValueError("Explicit, previously recorded hostname and machine-id required")
    if args.identity and not args.identity.expanduser().is_file():
        raise ValueError("Explicit SSH identity missing")
    root = args.root.expanduser().absolute()
    if root.resolve() != root or not root.is_dir():
        raise ValueError("Invalid local material root")
    verify(root, entries)
    payload = {"files": files, "release": release, "phase": args.phase,
               "hostname": args.hostname, "machine_id": args.machine_id,
               "remote_root": remote_root, "user": args.host.split("@", 1)[0]}
    command = "sudo -n /usr/bin/python3 -B -E -s -c " + shlex.quote(REMOTE)
    subprocess.run(ssh + [args.host, command], input=json.dumps(payload), text=True,
                   check=True, timeout=1800)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"Node control stopped: {error}", file=sys.stderr)
        sys.exit(1)
