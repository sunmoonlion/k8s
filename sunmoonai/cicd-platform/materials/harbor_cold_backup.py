#!/usr/bin/env python3
"""Approved, fixed-scope Harbor cold backup with persisted service recovery."""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess as sp
import sys
import tarfile
import time
import urllib.request as http

from harbor_inventory import Catalog
from harbor_prepare import KUBE, NS, RELEASE

CONTROLLERS = [('deployment', 'sunmoonai-harbor-' + n) for n in ['jobservice', 'core', 'portal', 'registry']]
CONTROLLERS += [('statefulset', 'sunmoonai-harbor-' + n) for n in ['trivy', 'postgresql', 'redis-master']]
VOLUMES = [(n, 'kind-worker', '/data/kind-local-storage/harbor/' + n)
           for n in ['registry', 'database', 'redis', 'jobservice', 'trivy']]
VOLUMES += [('trivy-active', 'kind-worker2', '/var/local-path-provisioner/pvc-c0fef3d5-b9e0-46fb-8cc2-d380423897e9_cicd-platform-dev_data-sunmoonai-harbor-trivy-0')]


def write(path, data):
    temporary = path.with_suffix(path.suffix + '.tmp')
    with temporary.open('w') as stream:
        json.dump(data, stream, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)


def run(args, timeout=120):
    result = sp.run(args, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError('Command failed: ' + shlex.join(args[:8]))
    return result.stdout


def kube(args):
    return json.loads(run(KUBE + ['-n', NS] + args + ['-o', 'json']))


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024**2), b''): h.update(chunk)
    return h.hexdigest()


def set_readonly(client, value):
    request = http.Request(client.base + '/configurations', method='PUT',
        headers={'Authorization': 'Basic ' + client.auth, 'Content-Type': 'application/json'},
        data=json.dumps({'read_only': value}).encode())
    with client.client.open(request, timeout=20) as response:
        if response.status != 200: raise RuntimeError('Read-only update failed')
    actual, _ = client.get('/configurations')
    if actual['read_only']['value'] is not value:
        raise RuntimeError('Read-only verification failed')


def scale(state, kind, name, replicas):
    actual = kube(['get', kind, name])
    saved = next(c for c in state['controllers'] if c['name'] == name)
    if actual['metadata']['uid'] != saved['uid']:
        raise RuntimeError('Controller identity changed: ' + name)
    run(KUBE + ['-n', NS, 'scale', kind + '/' + name, '--replicas=' + str(replicas),
                '--resource-version=' + actual['metadata']['resourceVersion']])
    print('Scaled', name, replicas, flush=True)


def wait_stopped(names, timeout=180):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        pods = kube(['get', 'pods'])['items']
        if not any(any(p['metadata']['name'].startswith(n + '-') for n in names) for p in pods):
            return
        time.sleep(2)
    raise RuntimeError('Pods did not stop gracefully; no force deletion attempted')


def restore(root, state):
    signal.alarm(0)
    client = Catalog('harbor.sunmoonai.com:30443')
    state['phase'] = 'restoring-services'
    write(root / 'state.json', state)
    order = ['postgresql', 'redis-master', 'registry', 'core', 'portal', 'trivy', 'jobservice']
    failures = []
    for suffix in order:
        row = next(c for c in state['controllers'] if c['name'] == 'sunmoonai-harbor-' + suffix)
        try:
            scale(state, row['kind'], row['name'], row['replicas'])
            run(KUBE + ['-n', NS, 'rollout', 'status', row['kind'] + '/' + row['name'], '--timeout=60s'], timeout=70)
        except Exception as exc:
            failures.append({'resource': row['name'], 'error': str(exc)})
            state['recovery_warnings'] = failures
            write(root / 'state.json', state)
    deadline = time.monotonic() + 120
    while True:
        health, _ = client.get('/health')
        if health.get('status') == 'healthy': break
        if time.monotonic() > deadline: raise RuntimeError('Harbor did not recover healthy status')
        time.sleep(3)
    set_readonly(client, state['original_read_only'])
    for row in state['controllers']:
        actual = kube(['get', row['kind'], row['name']])
        if actual['spec']['replicas'] != row['replicas'] or actual.get('status', {}).get('readyReplicas', 0) != row['replicas']:
            raise RuntimeError('Controller recovery incomplete: ' + row['name'])
    state['services_restored'] = True
    state['restored_at'] = dt.datetime.now(dt.timezone.utc).isoformat()
    write(root / 'state.json', state)
    print('Original Harbor services and read_only restored', flush=True)


def catalog_identity(catalog):
    return {'projects': sorted(p['name'] for p in catalog['projects']),
            'repositories': sorted((p['name'], r['name']) for p in catalog['projects'] for r in p['repositories']),
            'artifacts': sorted((p['name'], r['name'], a['digest'], tuple(sorted(a['tags'])),
                   tuple(sorted(v['child_digest'] for v in (a['references'] or []))))
                  for p in catalog['projects'] for r in p['repositories'] for a in r['artifacts'])}


def active_tasks(client):
    workers, _ = client.get('/jobservice/pools/all/workers')
    queues, _ = client.get('/jobservice/queues')
    sql = "SELECT count(*) FROM task WHERE status NOT IN ('Success','Error','Stopped')"
    command = 'PGPASSWORD="$(cat "$POSTGRES_PASSWORD_FILE")" psql -U postgres -d registry -At -c ' + shlex.quote(sql)
    count = int(run(KUBE + ['-n', NS, 'exec', 'sunmoonai-harbor-postgresql-0', '-c', 'postgresql', '--', 'sh', '-ec', command]).strip())
    return count + sum(bool(w.get('job_id')) for w in workers) + sum(q.get('count', 0) for q in queues)


def backup(root):
    root.mkdir(mode=0o700, parents=True, exist_ok=False)
    (root / 'volumes').mkdir(mode=0o700)
    prep = root.parent / 'preparation'
    index = json.loads((prep / 'preparation.json').read_text())
    for item in index['artifacts']:
        if digest(prep / item['path']) != item['sha256']:
            raise RuntimeError('Recovery input hash mismatch')
    if shutil.disk_usage(root).free < 100 * 1024**3: raise RuntimeError('Disk reserve below 100 GiB')
    if kube(['get', 'hpa'])['items']: raise RuntimeError('HPA present; review before backup')
    claims = kube(['get', 'pvc'])['items']
    pv_names = {c['spec']['volumeName'] for c in claims if 'harbor' in c['metadata']['name']}
    paths = {v['spec'].get('hostPath', {}).get('path') for v in json.loads(run(KUBE + ['get', 'pv', '-o', 'json']))['items'] if v['metadata']['name'] in pv_names}
    if paths != {v[2] for v in VOLUMES}: raise RuntimeError('Storage paths differ from approved scope')
    mount_info = json.loads(run(['docker', 'inspect', 'kind-worker']))[0]['Mounts']
    if not any(m['Source'] == '/data/kind-local-storage' and m['Destination'] == '/data/kind-local-storage' and m['Type'] == 'bind' for m in mount_info):
        raise RuntimeError('Source host mount changed')
    client = Catalog('harbor.sunmoonai.com:30443')
    health, _ = client.get('/health')
    if health.get('status') != 'healthy': raise RuntimeError('Harbor is not healthy')
    cfg, _ = client.get('/configurations')
    state = {'started_at': dt.datetime.now(dt.timezone.utc).isoformat(), 'phase': 'preflight',
             'original_read_only': cfg['read_only']['value'], 'controllers': [],
             'services_restored': False, 'archives': [], 'backup_complete': False}
    for kind, name in CONTROLLERS:
        obj = kube(['get', kind, name])
        if obj['spec']['replicas'] != 1: raise RuntimeError('Expected preapproved replica count 1')
        for container in obj['spec']['template']['spec']['containers']:
            if container.get('imagePullPolicy') == 'Always':
                raise RuntimeError('Restart requires online image resolution; review before stopping')
        state['controllers'].append({'kind': kind, 'name': name, 'uid': obj['metadata']['uid'], 'replicas': obj['spec']['replicas']})
    write(root / 'state.json', state)
    recovery = 'python3 ' + shlex.quote(str(Path(__file__).resolve())) + ' --resume-services ' + shlex.quote(str(root))
    (root / 'RECOVER-SERVICES.txt').write_text('Run locally after interruption; uses existing Docker auth and explicit old kubeconfig:\n' + recovery + '\n')
    shutil.copy2(Path(__file__), root / 'backup-script.py')
    changed = False
    error = None
    try:
        # Persist state BEFORE the first mutation so interruption is recoverable.
        state['phase'] = 'setting-read-only'
        write(root / 'state.json', state)
        changed = True
        set_readonly(client, True)
        deadline = time.monotonic() + 180
        while active_tasks(client):
            if time.monotonic() > deadline: raise RuntimeError('Active tasks did not drain')
            time.sleep(5)
        frozen = Catalog('harbor.sunmoonai.com:30443').collect()
        write(root / 'catalog-before.json', frozen)
        original = json.loads((prep / 'private/resources.json').read_text())
        fresh = []
        for obj in original['items']:
            args = KUBE + (['-n', NS] if obj['kind'] not in ('Namespace', 'PersistentVolume') else [])
            fresh.append(json.loads(run(args + ['get', obj['kind'], obj['metadata']['name'], '-o', 'json'])))
        write(root / 'resources-private.json', {'apiVersion': 'v1', 'kind': 'List', 'items': fresh})
        stopped_at = time.monotonic()
        signal.alarm(35 * 60)
        state['phase'] = 'stopping-services'
        write(root / 'state.json', state)
        for suffix in ['jobservice', 'trivy', 'core', 'portal', 'registry']:
            kind = 'statefulset' if suffix == 'trivy' else 'deployment'
            scale(state, kind, 'sunmoonai-harbor-' + suffix, 0)
            wait_stopped(['sunmoonai-harbor-' + suffix])
        for suffix in ['postgresql', 'redis-master']:
            scale(state, 'statefulset', 'sunmoonai-harbor-' + suffix, 0)
            wait_stopped(['sunmoonai-harbor-' + suffix])
        run(['docker', 'exec', 'kind-worker', 'test', '!', '-e', '/data/kind-local-storage/harbor/database/data/postmaster.pid'])
        state['phase'] = 'copying-static-volumes'
        write(root / 'state.json', state)
        for name, node, source in VOLUMES:
            if time.monotonic() - stopped_at > 1800: raise RuntimeError('Archive budget exhausted; restore services')
            if shutil.disk_usage(root).free < 70 * 1024**3: raise RuntimeError('Backup disk budget exhausted')
            if sum(p.stat().st_size for p in root.rglob('*') if p.is_file()) >= 30 * 1024**3:
                raise RuntimeError('Backup size budget exhausted')
            wait_stopped([c['name'] for c in state['controllers']], timeout=5)
            path = root / 'volumes' / (name + '.tar')
            partial = path.with_suffix('.tar.partial')
            with partial.open('wb') as stream:
                result = sp.run(['docker', 'exec', node, 'tar', '--numeric-owner', '--acls', '--xattrs',
                    '-C', source, '-cpf', '-', '.'], stdout=stream, stderr=sp.PIPE, timeout=1200)
                stream.flush()
                os.fsync(stream.fileno())
            if result.returncode: raise RuntimeError('Volume archive failed: ' + name)
            with tarfile.open(partial) as archive: count = sum(1 for _ in archive)
            item = {'name': name, 'node': node, 'source': source, 'path': str(path.relative_to(root)),
                    'bytes': partial.stat().st_size, 'sha256': digest(partial), 'tar_members': count}
            partial.rename(path)
            state['archives'].append(item)
            write(root / 'state.json', state)
            print('Archived', name, item['bytes'], 'bytes', flush=True)
        state['backup_complete'] = len(state['archives']) == 6
        state['archive_seconds'] = round(time.monotonic() - stopped_at, 1)
        write(root / 'state.json', state)
    except BaseException as exc:
        error = exc
        state['failure'] = type(exc).__name__ + ': ' + str(exc)
        write(root / 'state.json', state)
    finally:
        if changed:
            restore(root, state)
    if error: raise error
    after = Catalog('harbor.sunmoonai.com:30443').collect()
    write(root / 'catalog-after.json', after)
    state['catalog_unchanged'] = catalog_identity(frozen) == catalog_identity(after)
    state['phase'] = 'backup-complete-services-restored' if state['catalog_unchanged'] else 'catalog-difference-needs-review'
    write(root / 'state.json', state)
    if not state['catalog_unchanged']: raise RuntimeError('Catalog changed; investigate before acceptance')
    print('Cold backup complete; isolated restore NOT yet performed:', root, flush=True)


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--output', type=Path)
    group.add_argument('--resume-services', type=Path)
    args = parser.parse_args()
    root = (args.output or args.resume_services).expanduser().resolve()
    if root.parent != Path('/home/zymun/packages-to-be-installed/releases/harbor-preserve-20260926'):
        raise RuntimeError('Output outside approved backup batch')
    with (root.parent / '.backup.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        def interrupted(signum, frame): raise InterruptedError('Signal ' + str(signum))
        signal.signal(signal.SIGTERM, interrupted)
        signal.signal(signal.SIGALRM, interrupted)
        if args.resume_services: restore(root, json.loads((root / 'state.json').read_text()))
        else: backup(root)


if __name__ == '__main__':
    main()
