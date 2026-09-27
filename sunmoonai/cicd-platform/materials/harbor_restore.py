#!/usr/bin/env python3
"""Execute the approved 20260926 isolated restore in explicit, resumable stages."""
import argparse
import base64
import datetime as dt
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess as sp
import tarfile
import time

from harbor_restore_plan import NS, NODE, ROOT, HOST, ADDRESS, CLAIMS, sha
from harbor_cold_backup import write

BATCH = Path.home() / 'packages-to-be-installed/releases/harbor-preserve-20260926'
BACKUP = BATCH / 'backup-20260926T145600Z'
PLAN = BATCH / 'restore-plan-20260926'
RUN = BATCH / 'restore-run-20260926'
KUBE = ['kubectl', '--kubeconfig', str(Path.home() / '.kube/sunmoon-kind-136.config')]


def command(args, data=None, timeout=120, stream=None):
    stamp = dt.datetime.now().strftime('%H%M%S%f')
    try:
        p = sp.run(args, input=data, stdin=stream, capture_output=True, timeout=timeout)
    except sp.TimeoutExpired as exc:
        (RUN / (stamp + '.log')).write_bytes((exc.stdout or b'') + (exc.stderr or b''))
        write(RUN / (stamp + '.json'), {'command': args, 'timeout_seconds': timeout})
        raise RuntimeError('Command timed out; private log ' + stamp + '.log') from None
    (RUN / (stamp + '.log')).write_bytes(p.stdout + p.stderr)
    write(RUN / (stamp + '.json'), {'command': args, 'returncode': p.returncode})
    if p.returncode: raise RuntimeError('Command failed; private log ' + stamp + '.log')
    return p.stdout


def apply(items, dry=False):
    args = KUBE + ['apply', '--server-side', '--field-manager=harbor-restore', '-f', '-']
    if dry: args.append('--dry-run=server')
    command(args, json.dumps({'apiVersion': 'v1', 'kind': 'List', 'items': items}).encode())


def normalize_images(source, target, pins):
    with tarfile.open(source) as old:
        index = json.load(old.extractfile('index.json'))
        for desc in index['manifests']:
            ref = desc['annotations']['io.containerd.image.name']
            pin = pins[ref]
            digest = pin.split('@')[1]
            raw = old.extractfile('blobs/sha256/' + digest.split(':')[1]).read()
            body = json.loads(raw)
            desc.clear()
            desc.update({'mediaType': body['mediaType'], 'digest': digest, 'size': len(raw),
                'platform': {'os': 'linux', 'architecture': 'amd64'},
                'annotations': {'io.containerd.image.name': pin, 'org.opencontainers.image.ref.name': pin}})
        with tarfile.open(target, 'w') as new:
            for member in old:
                if member.name == 'index.json':
                    raw = json.dumps(index).encode(); member.size = len(raw)
                    new.addfile(member, io.BytesIO(raw))
                else:
                    new.addfile(member, old.extractfile(member) if member.isfile() else None)


def prepare():
    plan = json.loads((PLAN / 'plan.json').read_text())
    if sha(PLAN / 'manifests-private.json') != plan['private_manifests_sha256']:
        raise RuntimeError('Approved manifest changed')
    if shutil.disk_usage(BATCH).free < 100 * 1024**3: raise RuntimeError('Disk reserve')
    current = json.loads(command(KUBE + ['get', 'ns', '-o', 'json']))['items']
    if any(x['metadata']['name'] == NS for x in current): raise RuntimeError('Target namespace exists')
    pv = json.loads(command(KUBE + ['get', 'pv', '-o', 'json']))['items']
    if any(x['metadata']['name'].startswith(NS) for x in pv): raise RuntimeError('Target PV exists')
    services = json.loads(command(KUBE + ['get', 'svc', '-A', '-o', 'json']))['items']
    if any(x['spec'].get('clusterIP') == ADDRESS for x in services): raise RuntimeError('Gateway IP occupied')
    command(['docker', 'exec', NODE, 'test', '!', '-e', ROOT])
    v = json.loads((BACKUP / 'verification.json').read_text())
    for item in v['files']:
        p = BATCH / item['path']
        if sha(p) != item['sha256']: raise RuntimeError('Backup file mismatch: ' + item['path'])
    items = json.loads((PLAN / 'manifests-private.json').read_text())['items']
    initial = [o for o in items if o['kind'] in ['Namespace', 'NetworkPolicy']]
    apply(initial)
    uid = json.loads(command(KUBE + ['get', 'ns', NS, '-o', 'json']))['metadata']['uid']
    write(RUN / 'state.json', {'namespace_uid': uid, 'stage': 'namespace-created', 'volumes': [], 'images': []})
    apply(items, dry=True)
    for source in sorted((BATCH / 'preparation/images').glob('*.tar')):
        target = RUN / source.name
        normalize_images(source, target, plan['images'])
        with target.open('rb') as stream:
            command(['docker', 'exec', '-i', NODE, 'ctr', '-n', 'k8s.io', 'images', 'import',
                     '--platform', 'linux/amd64', '--digests', '-'], stream=stream, timeout=600)
        print('Imported pinned bootstrap archive', target.name, flush=True)
    for pin in plan['images'].values():
        command(['docker', 'exec', NODE, 'crictl', 'inspecti', pin])
    state = json.loads((RUN / 'state.json').read_text())
    state['images'] = list(plan['images'].values()); state['stage'] = 'images-imported'
    write(RUN / 'state.json', state)
    restore_data(items, state)


def restore_data(items, state):
    command(['docker', 'exec', NODE, 'mkdir', '-p', ROOT])
    for name in CLAIMS.values():
        path = ROOT + '/' + name
        archive_path = BACKUP / 'volumes' / (name + '.tar')
        with tarfile.open(archive_path) as archive:
            for member in archive:
                parts = PurePosixPath(member.name)
                if parts.is_absolute() or '..' in parts.parts or member.isdev():
                    raise RuntimeError('Unsafe archive member')
                if member.issym() or member.islnk():
                    raise RuntimeError('Archive links need explicit review')
        command(['docker', 'exec', NODE, 'mkdir', path])
        with archive_path.open('rb') as stream:
            command(['docker', 'exec', '-i', NODE, 'tar', '--numeric-owner', '--acls', '--xattrs',
                     '-C', path, '-xpf', '-'], stream=stream, timeout=600)
        state['volumes'].append(name); write(RUN / 'state.json', state)
        print('Restored independent volume', name, flush=True)
    version = command(['docker', 'exec', NODE, 'cat', ROOT + '/database/data/PG_VERSION']).decode().strip()
    if version != '17': raise RuntimeError('Wrong PostgreSQL data version')
    apply(items)
    state['stage'] = 'data-restored-zero-replicas'; write(RUN / 'state.json', state)
    print('Data restored; workloads remain stopped', flush=True)


def start():
    for kind, suffix in [('statefulset', 'postgresql'), ('statefulset', 'redis-master'),
                         ('deployment', 'registry'), ('deployment', 'core'), ('deployment', 'portal'),
                         ('statefulset', 'trivy'), ('deployment', 'gateway')]:
        name = 'restore-gateway' if suffix == 'gateway' else 'sunmoonai-harbor-' + suffix
        command(KUBE + ['-n', NS, 'scale', kind + '/' + name, '--replicas=1'])
        print('Starting', name, flush=True)
        command(KUBE + ['-n', NS, 'rollout', 'status', kind + '/' + name, '--timeout=180s'], timeout=200)
    state = json.loads((RUN / 'state.json').read_text()); state['stage'] = 'read-path-running'
    write(RUN / 'state.json', state)


def stop():
    items = json.loads((PLAN / 'manifests-private.json').read_text())['items']
    for o in items:
        if o['kind'] in ['Deployment', 'StatefulSet']:
            command(KUBE + ['-n', NS, 'scale', o['kind'].lower() + '/' + o['metadata']['name'], '--replicas=0'])
    command(KUBE + ['-n', NS, 'wait', '--for=delete', 'pod', '--all', '--timeout=180s'], timeout=200)
    state = json.loads((RUN / 'state.json').read_text()); state['stage'] = 'stopped-data-retained'
    write(RUN / 'state.json', state)


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare', 'start', 'stop'])
    args = parser.parse_args()
    if args.action == 'prepare': RUN.mkdir(mode=0o700, exist_ok=False)
    else:
        state = json.loads((RUN / 'state.json').read_text())
        actual = json.loads(command(KUBE + ['get', 'ns', NS, '-o', 'json']))
        if actual['metadata']['uid'] != state['namespace_uid']: raise RuntimeError('Namespace identity changed')
    with (RUN / 'restore.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        globals()[args.action]()


if __name__ == '__main__':
    main()
