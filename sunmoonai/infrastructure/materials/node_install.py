#!/usr/bin/env python3
"""Offline fresh-node runtime/tool installer. Cloud 未经实机验证.

Default prints only. --apply requires a complete material closure, explicit host
identity, Ubuntu 24.04 amd64/systemd/cgroup-v2, and a dedicated fresh kubeadm node.
No Docker/Harbor/WSL host, cluster reset, download, file overwrite or deletion.
This is not an in-place upgrade tool for an existing Kubernetes node.
"""
import argparse
import hashlib
import io
import json
import os
import platform
import re
import shutil
import socket
import subprocess
import sys
import tarfile
from pathlib import Path
from bundle import below, resolve, sha256, verify

CONFIG_TARGETS = {
    'runtime': {'containerd.toml': '/etc/containerd/config.toml',
                'containerd.service': '/etc/systemd/system/containerd.service',
                'crictl.yaml': '/etc/crictl.yaml'},
    'kubernetes': {'kubelet.service': '/etc/systemd/system/kubelet.service',
                   '10-kubeadm.conf': '/etc/systemd/system/kubelet.service.d/10-kubeadm.conf'},
}


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=90).stdout


def host_preflight(args, baseline_ready=True, allow_owned_cluster=False):
    if os.geteuid() != 0 or platform.machine() != 'x86_64' or platform.system() != 'Linux':
        raise ValueError('Root on Linux amd64 is required')
    if 'microsoft' in platform.release().lower() or Path('/.dockerenv').exists():
        raise ValueError('WSL/container installation refused')
    if not args.machine_id or Path('/etc/machine-id').read_text().strip() != args.machine_id:
        raise ValueError('Explicit machine ID does not match')
    if not args.hostname or socket.gethostname() != args.hostname:
        raise ValueError('Explicit hostname does not match')
    release = dict(line.split('=', 1) for line in Path('/etc/os-release').read_text().splitlines() if '=' in line)
    if release.get('ID', '').strip('"') != 'ubuntu' or release.get('VERSION_ID', '').strip('"') != '24.04':
        raise ValueError('This OS profile supports Ubuntu 24.04 only; prepare another closure for other OSes')
    if not Path('/run/systemd/system').is_dir() or not Path('/sys/fs/cgroup/cgroup.controllers').is_file():
        raise ValueError('systemd and cgroup v2 required')
    if shutil.which('docker') or Path('/var/lib/docker').exists() or Path('/data/harbor').exists():
        raise ValueError('Docker/Harbor host refused')
    if baseline_ready:
        for command in ('ip', 'iptables', 'conntrack', 'socat', 'modprobe', 'sysctl', 'systemctl'):
            if not shutil.which(command): raise ValueError('Missing preinstalled OS dependency: '+command)
        if len(Path('/proc/swaps').read_text().splitlines()) > 1:
            raise ValueError('Swap must be disabled by the explicit OS baseline stage')
        if run(['sysctl', '-n', 'net.ipv4.ip_forward']).strip() != '1':
            raise ValueError('OS baseline ip_forward is not ready')
    for name in (() if allow_owned_cluster else ('/etc/kubernetes', '/var/lib/kubelet', '/var/lib/etcd')):
        path = Path(name)
        if path.exists() and (not path.is_dir() or any(path.iterdir())):
            raise ValueError('Existing cluster state refused; no reset attempted')


def no_symlink(path):
    if path.resolve() != path:
        raise ValueError('Symlinked install destination refused: '+str(path))


def content_for(root, batch, versions, phase, entries):
    """Extract only allowlisted regular members into memory, never tar.extract."""
    base = root/'releases'/batch
    expected = {e['path']: e for e in entries}
    def locked_bytes(relative):
        entry = expected[f'releases/{batch}/{relative}']
        raw = below(base, relative).read_bytes()
        if hashlib.sha256(raw).hexdigest() != entry['sha256']:
            raise ValueError('Material changed after preflight')
        if entry['bytes'] is not None and len(raw) != entry['bytes']:
            raise ValueError('Material size changed after preflight')
        return raw
    files = []
    if phase == 'runtime':
        archives = [
            (f'tars/containerd-{versions["containerd"]}-linux-amd64.tar.gz',
             {'bin/containerd': 'containerd', 'bin/ctr': 'ctr', 'bin/containerd-shim-runc-v2': 'containerd-shim-runc-v2'}),
            (f'tars/nerdctl-{versions["nerdctl"]}-linux-amd64.tar.gz', {'nerdctl': 'nerdctl'}),
            (f'tars/crictl-v{versions["crictl"]}-linux-amd64.tar.gz', {'crictl': 'crictl'}),
        ]
        for archive, members in archives:
            with tarfile.open(fileobj=io.BytesIO(locked_bytes(archive))) as tf:
                for member_name, name in members.items():
                    matches = [m for m in tf.getmembers() if m.name == member_name]
                    if len(matches) != 1 or not matches[0].isfile() or matches[0].size > 256*1024**2:
                        raise ValueError('Unexpected archive member')
                    files.append((Path('/usr/local/bin')/name, tf.extractfile(matches[0]).read(), 0o755))
        files.append((Path('/usr/local/bin/runc'), locked_bytes(f'bin/runc-{versions["runc"]}.amd64'), 0o755))
    else:
        for name in ('kubeadm', 'kubelet', 'kubectl'):
            files.append((Path('/usr/local/bin')/name, locked_bytes('bin/'+name), 0o755))
    for name, target in CONFIG_TARGETS[phase].items():
        files.append((Path(target), locked_bytes('configuration/'+name), 0o644))
    return files


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--phase', choices=('runtime', 'kubernetes'), required=True)
    p.add_argument('--manifest', type=Path, default=Path(__file__).resolve().with_name('cluster-artifacts.lock.json'))
    p.add_argument('--root', type=Path, default=Path.home()/'packages-to-be-installed')
    p.add_argument('--hostname', help='Expected real node hostname, never auto-approved')
    p.add_argument('--machine-id', help='Expected /etc/machine-id from approved host inventory')
    p.add_argument('--apply', action='store_true')
    a = p.parse_args()
    data, entries = resolve(a.manifest)
    root = a.root.expanduser().absolute()
    if root.resolve() != root or not root.is_dir(): raise ValueError('Material root missing/symlinked')
    if not a.apply:
        print(json.dumps({'dry_run': True, 'phase': a.phase, 'versions': data['versions'],
                          'cloud_status': '未经实机验证', 'closure_complete': data['closure_complete'],
                          'pending': data['pending'], 'file_install': list(CONFIG_TARGETS[a.phase].values()),
                          'binary_directory': '/usr/local/bin', 'host_identity_required': True,
                          'operations': ['verify complete closure and all material SHA256',
                                         'fresh dedicated host and completed OS baseline', 'check all existing destinations',
                                         'exclusive file creation with journal', 'verify binary versions',
                                         'daemon-reload; enable runtime or kubelet',
                                         'start containerd only in runtime phase; kubelet waits for kubeadm'],
                          'deletion': False, 'overwrite': False}, ensure_ascii=False, indent=2))
        return
    if data.get('closure_complete') is not True or data.get('pending'):
        raise ValueError('Material/deployment closure incomplete; installation refused before host mutation')
    verify(root, entries)
    host_preflight(a)
    os_lock_sha = data['os_dependency_lock']['sha256']
    os_journal = Path('/var/lib/sunmoon/bootstrap')/(data['batch']+'-os-'+os_lock_sha[:16])/'complete.json'
    no_symlink(os_journal)
    baseline = json.loads(os_journal.read_text())
    if (os_journal.stat().st_uid != 0 or os_journal.stat().st_mode & 0o022
            or baseline.get('state') != 'complete' or baseline.get('hostname') != a.hostname
            or baseline.get('machine_id') != a.machine_id
            or baseline.get('manifest_sha256') != sha256(a.manifest)
            or baseline.get('os_lock_sha256') != os_lock_sha):
        raise ValueError('Matching completed OS baseline is required')
    if a.phase == 'kubernetes':
        runtime_journal = Path('/var/lib/sunmoon/bootstrap')/(data['batch']+'-runtime.json')
        no_symlink(runtime_journal)
        prior = json.loads(runtime_journal.read_text())
        if (prior['state'] != 'complete' or prior['identity']['machine_id'] != a.machine_id
                or prior['identity']['manifest_sha256'] != sha256(a.manifest)):
            raise ValueError('Matching completed runtime installation is required')
        run(['systemctl', 'is-active', '--quiet', 'containerd'])
    files = content_for(root, data['batch'], data['versions'], a.phase, entries)
    identity = {'machine_id': a.machine_id, 'hostname': a.hostname, 'phase': a.phase,
                'manifest_sha256': sha256(a.manifest),
                'files': [{'path': str(p), 'sha256': hashlib.sha256(raw).hexdigest(), 'mode': mode} for p, raw, mode in files]}
    journal_path = Path('/var/lib/sunmoon/bootstrap')/(data['batch']+'-'+a.phase+'.json')
    no_symlink(journal_path)
    if journal_path.exists():
        journal = json.loads(journal_path.read_text())
        if journal['identity'] != identity: raise ValueError('Existing installer journal has another identity')
    else:
        journal = {'identity': identity, 'state': 'prepared', 'created': []}
        if a.phase == 'runtime':
            runtime = Path('/var/lib/containerd')
            if runtime.exists() and (not runtime.is_dir() or any(runtime.iterdir())):
                raise ValueError('Existing runtime data refused; no cleanup attempted')
            if subprocess.run(['systemctl', 'is-active', '--quiet', 'containerd'], check=False).returncode == 0:
                raise ValueError('Unowned running runtime refused')
    # Validate every destination before the first write. Never replace a file.
    for dest, raw, mode in files:
        no_symlink(dest)
        if dest.exists() and (not dest.is_file() or dest.read_bytes() != raw or dest.stat().st_mode & 0o777 != mode or dest.stat().st_uid != 0):
            raise ValueError('Existing install file differs; preserved: '+str(dest))
    journal_path.parent.mkdir(parents=True, exist_ok=True)
    def save_journal():
        temp = journal_path.with_name(journal_path.name+'.new')
        with temp.open('x') as stream:
            json.dump(journal, stream, indent=2); stream.write('\n'); stream.flush(); os.fsync(stream.fileno())
        os.replace(temp, journal_path)
    save_journal()
    for dest, raw, mode in files:
        if not dest.exists():
            dest.parent.mkdir(parents=True, exist_ok=True)
            fd = os.open(dest, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)
            with os.fdopen(fd, 'wb') as stream:
                stream.write(raw); stream.flush(); os.fchmod(stream.fileno(), mode); os.fsync(stream.fileno())
            journal['created'].append(str(dest)); save_journal()
    versions = data['versions']
    checks = (('containerd', ['--version'], versions['containerd']), ('runc', ['--version'], versions['runc']),
              ('nerdctl', ['--version'], versions['nerdctl']), ('crictl', ['--version'], versions['crictl'])) if a.phase == 'runtime' else (
                  ('kubeadm', ['version', '-o', 'short'], versions['kubernetes']),
                  ('kubelet', ['--version'], versions['kubernetes']),
                  ('kubectl', ['version', '--client', '-o', 'json'], versions['kubernetes']))
    for binary, args, version in checks:
        output = run(['/usr/local/bin/'+binary, *args])
        if not re.search(r'(?<![0-9.])v?'+re.escape(version)+r'(?![0-9.])', output):
            raise ValueError('Installed version check failed: '+binary)
    run(['systemctl', 'daemon-reload'])
    service = 'containerd' if a.phase == 'runtime' else 'kubelet'
    run(['systemctl', 'enable', service])
    if a.phase == 'runtime':
        run(['systemctl', 'start', 'containerd'])
        run(['systemctl', 'is-active', '--quiet', 'containerd'])
        info = json.loads(run(['/usr/local/bin/crictl', 'info']))
        if not any(c['type'] == 'RuntimeReady' and c['status'] is True for c in info['status']['conditions']):
            raise ValueError('CRI RuntimeReady is not true')
    journal['state'] = 'complete'; save_journal()
    print(json.dumps({'phase': a.phase, 'state': 'complete', 'journal': str(journal_path),
                      'cluster_ready': False, 'cloud_status': 'Requires separate cluster acceptance'}))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, tarfile.TarError) as error:
        print(f'Offline node installation stopped: {error}', file=sys.stderr)
        sys.exit(1)
