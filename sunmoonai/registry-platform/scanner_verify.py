#!/usr/bin/env python3
"""Verify the preserved scanner and pinned DBs in an isolated offline container.

Default prints only. Scans its own public image rootfs; no Harbor/cluster access,
Docker socket bind, host credentials, public network, published port or volume.
Keeps its stopped container and new artifact directory. Cloud 未经实机验证.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile

from prepare_scanner import MANIFEST
from prepare_scanner_candidate import MANIFEST as CANDIDATE_MANIFEST
from prepare_scanner_db import verify

NAME = 'sunmoon-trivy-offline-20260927-v2'
ROOT = Path('/home/zymun/packages-to-be-installed/releases/trivy-offline-trial-20260927-v2')
PROFILES = {
    'original': {'name': NAME, 'root': ROOT, 'image': MANIFEST, 'image_user': '1001',
                 'uid': 1001, 'binary': '/opt/bitnami/harbor-adapter-trivy/bin/trivy'},
    'stable': {'name': 'sunmoon-trivy-stable-offline-20260927',
               'root': ROOT.parent / 'trivy-stable-offline-trial-20260927',
               'image': CANDIDATE_MANIFEST, 'image_user': 'scanner', 'uid': 10000,
               'binary': '/usr/local/bin/trivy'}}


def docker(*args, timeout=60):
    result = subprocess.run(['docker', '--host', 'unix:///var/run/docker.sock', *args],
                            capture_output=True, timeout=timeout)
    if result.returncode:
        raise ValueError('Scanner container command failed; diagnostics withheld')
    return result.stdout


def stage_database(batch, root, uid, checked):
    """Stage verified DBs into a fresh private, writable scanner-owned cache."""
    cache = root / 'cache'; cache.mkdir(mode=0o755)
    for role, artifact in checked['archives'].items():
        directory = cache / role; directory.mkdir(mode=0o755)
        # Trivy's Bolt database opens read/write even with downloads disabled.
        # Only this disposable cache copy is writable; source archives stay intact.
        os.chown(directory, uid, uid); directory.chmod(0o700)
        expected = artifact['members']; found = set()
        with tarfile.open(batch / (role + '-db.tar.gz'), 'r|gz') as archive:
            for item in archive:
                if not item.isfile() or item.name not in expected or item.name in found or item.size != expected[item.name]['bytes']:
                    raise ValueError('Archive changed after verification')
                target = directory / item.name; digest = hashlib.sha256()
                with archive.extractfile(item) as source, target.open('xb') as output:
                    while chunk := source.read(1024**2):
                        digest.update(chunk); output.write(chunk)
                os.chown(target, uid, uid); target.chmod(0o600)
                if digest.hexdigest() != expected[item.name]['sha256']:
                    raise ValueError('Staged database SHA differs')
                found.add(item.name)
        if found != set(expected):
            raise ValueError('Staged database incomplete')
    return cache


def run(batch, root, profile='original'):
    admitted = PROFILES[profile]
    name, manifest, uid = admitted['name'], admitted['image'], admitted['uid']
    if os.geteuid() != 0 or root != admitted['root'] or root.exists() or root.resolve() != root or batch.resolve() != batch:
        raise ValueError('Root and fresh admitted local trial directory required')
    if shutil.disk_usage(root.parent).free < 6 * 1024**3:
        raise ValueError('Need 6 GiB for database stage and scan')
    names = docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines()
    if name in names:
        raise ValueError('Existing trial container retained; no overwrite/restart')
    image = json.loads(docker('image', 'inspect', manifest))[0]
    if (image['Id'] != manifest or image['Architecture'] != 'amd64' or image['Os'] != 'linux'
            or image['Config'].get('Volumes') or image['Config'].get('User') != admitted['image_user']):
        raise ValueError('Admitted original scanner identity/user/volumes differ')
    checked = verify(batch)
    root.mkdir(mode=0o700)
    with (root / 'database-verification.json').open('x') as stream:
        json.dump(checked, stream, indent=2)
    cache = stage_database(batch, root, uid, checked)
    output = root / 'output'; output.mkdir(mode=0o700); os.chown(output, uid, uid)
    args = ['create', '--name', name, '--label', 'sunmoonai.registry.role=scanner-offline-acceptance',
            '--pull', 'never', '--network', 'none', '--restart', 'no', '--user', str(uid) + ':' + str(uid),
            '--read-only', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges:true',
            '--pids-limit', '256', '--memory', '2g', '--cpus', '2',
            '--log-driver', 'local', '--log-opt', 'max-size=10m', '--log-opt', 'max-file=2',
            '--tmpfs', f'/tmp:rw,nosuid,nodev,size=512m,uid={uid},gid={uid},mode=0700',
            '--tmpfs', f'/cache:rw,nosuid,nodev,size=512m,uid={uid},gid={uid},mode=0700']
    for role in ('db', 'java-db'):
        args += ['--mount', 'type=bind,src=' + str(cache / role) + ',dst=/cache/' + role]
    args += ['--mount', 'type=bind,src=' + str(output) + ',dst=/output',
             '--entrypoint', admitted['binary'], manifest,
             'rootfs', '--cache-dir', '/cache', '--scanners', 'vuln', '--skip-db-update',
             '--skip-java-db-update', '--offline-scan', '--skip-version-check',
             '--timeout', '5m', '--list-all-pkgs', '--format', 'json', '--output', '/output/report.json']
    for path in ('/cache', '/output', '/tmp', '/dev', '/sys', '/proc'):
        args += ['--skip-dirs', path]
    args += ['/']
    identity = docker(*args).decode().strip()
    with (root / 'container-id').open('x') as stream:
        stream.write(identity + '\n')
    try:
        info = json.loads(docker('inspect', identity))[0]
        if (info['Image'] != manifest or info['HostConfig']['NetworkMode'] != 'none'
                or info['HostConfig']['Privileged'] or any(m['Type'] == 'volume' for m in info['Mounts'])
                or info['HostConfig'].get('PortBindings')):
            raise ValueError('Offline scanner isolation differs')
        docker('start', identity)
        exit_code = int(docker('wait', identity, timeout=360).strip())
        log_result = subprocess.run(['docker', '--host', 'unix:///var/run/docker.sock', 'logs', identity],
                                    capture_output=True, timeout=30)
        logs = log_result.stdout + log_result.stderr
        with (root / 'scanner.log').open('xb') as stream:
            stream.write(logs)
        if exit_code:
            raise ValueError('Offline scanner failed; inspect private scanner.log')
        path = output / 'report.json'
        if path.is_symlink() or path.stat().st_size > 64 * 1024**2:
            raise ValueError('Unexpected scan report')
        report = json.loads(path.read_bytes())
        results = report.get('Results', [])
        if report.get('SchemaVersion') != 2 or not results or not any(x.get('Packages') for x in results):
            raise ValueError('Successful exit without detected packages is not scan acceptance')
        counts = {}
        for item in results:
            for vuln in item.get('Vulnerabilities') or []:
                level = vuln.get('Severity', 'UNKNOWN'); counts[level] = counts.get(level, 0) + 1
        receipt = {'schema': 1, 'container': name, 'container_id': identity, 'image': manifest,
                   'db_lock_sha256': checked['lock_sha256'], 'network': 'none',
                   'target': 'scanner public image rootfs', 'artifact_type': report.get('ArtifactType'),
                   'report_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                   'package_count': sum(len(x.get('Packages') or []) for x in results),
                   'vulnerability_occurrences_by_severity': counts,
                   'offline_scan_passed': True, 'harbor_jobservice_verified': False,
                   'java_archive_verified': True, 'java_scan_verified': False}
        with (root / 'result.json').open('x') as stream:
            json.dump(receipt, stream, indent=2)
        return receipt
    finally:
        info = json.loads(docker('inspect', identity))[0]
        if info['State']['Running']:
            docker('stop', '--time', '10', identity)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch', type=Path, required=True)
    parser.add_argument('--profile', choices=sorted(PROFILES), default='original')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(); admitted = PROFILES[args.profile]
    if not args.apply:
        print(json.dumps({'dry_run': True, 'root': str(admitted['root']), 'batch': str(args.batch),
                          'container': admitted['name'], 'network': 'none', 'target': 'scanner public image rootfs',
                          'retains_container': True, 'touches_harbor': False})); return
    print(json.dumps(run(args.batch.absolute(), admitted['root'], args.profile), indent=2))


if __name__ == '__main__':
    main()
