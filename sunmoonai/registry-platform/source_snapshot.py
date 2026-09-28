#!/usr/bin/env python3
"""Bounded old-KIND Harbor logical snapshot with durable service recovery.

Default plan; check is read-only. capture --apply briefly freezes the old Harbor
writers, exports PG17.6 and verifies every registry file against a retained,
independently restored archive, then ALWAYS restores the source services.
recover --apply resumes recovery only. Never switches entry, stops KIND nodes,
deletes data, or treats this temporary snapshot as final cutover admission.
"""
import argparse
import base64
from contextlib import contextmanager
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import ssl
import stat
import time
import urllib.request as http

import entry_handoff as old
from entry_reconcile import CONFIG, equal_catalog, policy
from harbor_inputs import MAP
from host_backup import read_manifest, sha, verify_tar
from host_identity_verify import collect as identities
from host_prepare import directory, load, storage, write
from host_restore import pg
from host_runtime import Instance, save as atomic_save
from host_verify import Catalog, NoRedirect
from runtime_inspect import read
from runtime_config import PG_BIN
from harbor_cold_backup import set_readonly

NS = 'cicd-platform-dev'
PREFIX = 'sunmoonai-harbor-'
PG_POD = PREFIX + 'postgresql-0'
BASE = Path('/data/harbor/source-snapshots')
REGISTRY = Path('/data/kind-local-storage/harbor/registry')
ARCHIVE = Path('/data/harbor/backups/host-main-20260927-v1')
STOP = ['jobservice', 'trivy', 'core', 'portal', 'registry']
RECOVER = ['registry', 'core', 'portal', 'trivy', 'jobservice']
KINDS = {n: ('statefulset' if n in ('trivy', 'postgresql', 'redis-master') else 'deployment')
         for n in STOP + ['postgresql', 'redis-master']}


class RecoveryDeadline(BaseException):
    """Must not be swallowed by per-service recovery retry handlers."""


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def save(path, value):
    atomic_save(path, value)
    sync_directory(path.parent)


def node_identity(value):
    return {**value, 'mounts': sorted(value['mounts'], key=lambda m: m['Destination'])}


@contextmanager
def recovery_budget():
    def expired(signum, frame):
        raise RecoveryDeadline('Automatic recovery exceeded 10 minutes; use recover with the retained journal')
    handlers = {s: signal.getsignal(s) for s in (signal.SIGINT, signal.SIGTERM, signal.SIGALRM)}
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    signal.signal(signal.SIGALRM, expired)
    signal.alarm(600)
    try:
        yield
    finally:
        signal.alarm(0)
        for sig, handler in handlers.items():
            signal.signal(sig, handler)


def guard(state=None):
    if old.kub('get', 'ns', 'kube-system')['metadata']['uid'] != old.UID:
        raise ValueError('Old cluster UID changed')
    if state:
        if old.sha(old.KUBECONFIG) != state['kubeconfig_sha256']:
            raise ValueError('Old kubeconfig changed; cannot recover automatically')
        for item in state['nodes']:
            if node_identity(old.node(item['name'])) != node_identity(item):
                raise ValueError('Old node identity/network/mounts changed; no automatic adoption')


def api(credentials):
    if (credentials.resolve() != credentials or credentials.stat().st_mode & 0o077
            or old.sha(old.CA) != old.CA_SHA):
        raise ValueError('Private explicit credentials and original CA required')
    addresses = {v[4][0] for v in socket.getaddrinfo('harbor.sunmoonai.com', 30443, type=socket.SOCK_STREAM)}
    if not addresses or not addresses <= {'127.0.0.1', '::1'}:
        raise ValueError('Old Harbor hostname no longer resolves to this host')
    c = Catalog.__new__(Catalog)
    c.auth = json.loads(read(credentials)).get('auths', {}).get('harbor.sunmoonai.com:30443', {}).get('auth')
    if not c.auth:
        raise ValueError('Existing owner Docker credential required')
    c.base = 'https://harbor.sunmoonai.com:30443/api/v2.0'
    c.client = http.build_opener(http.ProxyHandler({}), NoRedirect(),
                                http.HTTPSHandler(context=ssl.create_default_context(cafile=str(old.CA))))
    c.calls = 0
    c.deadline = time.monotonic() + 2400
    return c


def spec_sha(resource):
    spec = dict(resource['spec'])
    spec.pop('replicas', None)
    return hashlib.sha256(json.dumps(spec, sort_keys=True).encode()).hexdigest()


def controller(suffix, saved=None):
    value = old.kub('-n', NS, 'get', KINDS[suffix], PREFIX + suffix)
    if saved and (value['metadata']['uid'] != saved['uid'] or spec_sha(value) != saved['spec_sha256']):
        raise ValueError('Old controller changed: ' + suffix)
    return value


class SourceDatabase(pg.Rehearsal):
    """Same inventory encoding as host restore, using a pinned old Pod transport."""
    def __init__(self, pod_uid):
        self.pod_uid = pod_uid

    def command(self, *args, stdin=None):
        guard()
        pod = old.kub('-n', NS, 'get', 'pod', PG_POD)
        if pod['metadata']['uid'] != self.pod_uid or pod['status']['phase'] != 'Running':
            raise ValueError('Source PostgreSQL Pod replaced or stopped')
        # The password stays inside the existing Pod; no value in argv/logs.
        shell = 'export PGPASSWORD; PGPASSWORD="$(cat "$POSTGRES_PASSWORD_FILE")"; export PGOPTIONS="-c default_transaction_read_only=on"; exec "$@"'
        return old.kub_raw('-n', NS, 'exec', '-i', PG_POD, '-c', 'postgresql', '--',
                           'sh', '-ec', shell, 'sh', *args, stdin=stdin, timeout=150)

    def psql_raw(self, container, sql, database='registry'):
        return self.command(PG_BIN + 'psql', '-X', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1',
                            '-U', 'postgres', '-d', database, '-At', stdin=sql.encode()).decode()

    def schema(self, container):
        return self.command(PG_BIN + 'pg_dump', '-h', '127.0.0.1', '-U', 'postgres',
                            '--schema-only', 'registry').decode()


def secrets_equal(config):
    seen = {}
    for key, (name, field) in MAP.items():
        if name not in seen:
            seen[name] = old.kub('-n', NS, 'get', 'secret', name)['data']
        raw = base64.b64decode(seen[name][field], validate=True)
        if raw != read(Path(config['source']) / 'private' / key):
            raise ValueError('Source secret differs from preserved host input; no silent adoption')
    return seen


def archive_record():
    record = read_manifest(ARCHIVE / 'backup.json')
    if not record.get('complete') or not record.get('restore_verified'):
        raise ValueError('Independently restored retained archive required')
    target = ARCHIVE / 'volumes/registry.tar'
    if sha(target) != record['files']['volumes/registry.tar']['sha256']:
        raise ValueError('Retained registry archive SHA changed')
    verify_tar(target, record['registry'])
    return record


def inspect_source(credentials, verify_archive=True):
    config = load(CONFIG)
    storage(config, minimum_gib=20)
    instance = Instance(config)
    if instance.mode() != 'read-only' or any(v not in ('created', 'exited') for v in instance.check().values()):
        raise ValueError('New Harbor must remain stopped and read-only')
    entry = old.inspect()
    if old.kub('-n', NS, 'get', 'hpa')['items']:
        raise ValueError('Autoscalers present; manual freeze not safe')
    controls = {}
    for suffix in KINDS:
        obj = controller(suffix)
        if obj['spec'].get('replicas') != 1 or obj.get('status', {}).get('readyReplicas') != 1:
            raise ValueError('Source controller must be 1/1 Ready: ' + suffix)
        containers = obj['spec']['template']['spec']['containers']
        if any(c.get('imagePullPolicy') == 'Always' for c in containers):
            raise ValueError('Source recovery would require an unconditional image pull')
        controls[suffix] = {'uid': obj['metadata']['uid'], 'kind': KINDS[suffix],
                            'replicas': 1, 'spec_sha256': spec_sha(obj)}
    pod = old.kub('-n', NS, 'get', 'pod', PG_POD)
    database = SourceDatabase(pod['metadata']['uid'])
    if database.psql(None, 'SHOW server_version_num;') != '170006':
        raise ValueError('Source PG version differs from 17.6')
    # Prove the path being hashed is the path used by the actual registry PVC.
    template = controller('registry')['spec']['template']['spec']
    claim = next(v['persistentVolumeClaim']['claimName'] for v in template['volumes'] if v['name'] == 'registry-data')
    pvc = old.kub('-n', NS, 'get', 'pvc', claim)
    pv = old.kub('get', 'pv', pvc['spec']['volumeName'])
    if pv['spec'].get('hostPath', {}).get('path') != str(REGISTRY):
        raise ValueError('Registry PV hostPath differs')
    pods = old.kub('-n', NS, 'get', 'pods')['items']
    registry_pods = [v for v in pods if v['metadata']['name'].startswith(PREFIX + 'registry-')]
    worker = next(v for v in entry['nodes'] if v['name'] == 'kind-worker')
    if (len(registry_pods) != 1 or registry_pods[0]['spec']['nodeName'] != worker['name']
            or not any(m['Type'] == 'bind' and m['Source'] == '/data/kind-local-storage'
                       and m['Destination'] == '/data/kind-local-storage' and m['RW'] for m in worker['mounts'])):
        raise ValueError('Registry source is not the verified worker host bind')
    if REGISTRY.resolve() != REGISTRY or not REGISTRY.is_dir():
        raise ValueError('Unsafe registry root')
    secret_values = secrets_equal(config)
    c = api(credentials)
    user, _ = c.get('/users/current')
    settings, _ = c.get('/configurations')
    if user.get('sysadmin_flag') is not True or type(settings['read_only']['value']) is not bool:
        raise ValueError('Administrator and explicit readonly state required')
    record = archive_record() if verify_archive else None
    state = {'schema': 1, 'cluster_uid': old.UID, 'kubeconfig_sha256': old.sha(old.KUBECONFIG),
             'nodes': entry['nodes'], 'controllers': controls, 'pg_pod_uid': pod['metadata']['uid'],
             'registry_pv_uid': pv['metadata']['uid'], 'registry_claim': claim,
             'registry_identity': [REGISTRY.stat().st_dev, REGISTRY.stat().st_ino],
             'original_read_only': settings['read_only']['value'], 'mutation_intent': False,
             'services_restored': False, 'completed': False, 'created_at': now()}
    return state, c, database, record, secret_values


def scale(state, suffix, replicas):
    guard(state)
    obj = controller(suffix, state['controllers'][suffix])
    old.kub_raw('-n', NS, 'scale', KINDS[suffix] + '/' + PREFIX + suffix,
                '--replicas=' + str(replicas), '--current-replicas=' + str(obj['spec']['replicas']),
                '--resource-version=' + obj['metadata']['resourceVersion'])


def stopped(state):
    guard(state)
    for suffix in STOP:
        if controller(suffix, state['controllers'][suffix])['spec']['replicas'] != 0:
            raise ValueError('Source writer desired replicas no longer zero')
    pods = old.kub('-n', NS, 'get', 'pods')['items']
    return not any(any(p['metadata']['name'].startswith(PREFIX + suffix + '-') for suffix in STOP) for p in pods)


def content(state, expected):
    if [REGISTRY.stat().st_dev, REGISTRY.stat().st_ino] != state['registry_identity']:
        raise ValueError('Source registry path identity changed')
    actual = {}
    for path in sorted(REGISTRY.rglob('*')):
        before = path.lstat()
        if path.resolve() != path or before.st_dev != REGISTRY.stat().st_dev:
            raise ValueError('Source registry contains symlink/nested mount')
        if stat.S_ISDIR(before.st_mode):
            continue
        if not stat.S_ISREG(before.st_mode):
            raise ValueError('Source registry contains a special file')
        digest = sha(path)
        after = path.stat()
        if (before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns):
            raise ValueError('Source registry changed while frozen')
        actual[str(path.relative_to(REGISTRY))] = {'bytes': after.st_size, 'sha256': digest}
    wanted = {k: {f: v[f] for f in ('bytes', 'sha256')} for k, v in expected.items()}
    if actual != wanted:
        raise ValueError('Source registry differs from retained archive; fresh layer backup required before migration')
    return {'files': len(actual), 'bytes': sum(v['bytes'] for v in actual.values()), 'all_sha256_equal': True}


def recover(root, state, credentials):
    print('Restoring original Harbor controllers and readonly setting', flush=True)
    guard(state)
    state['phase'] = 'restoring-source'
    save(root / 'state.json', state)
    failures = []
    for suffix in RECOVER:
        try:
            scale(state, suffix, state['controllers'][suffix]['replicas'])
        except Exception:
            failures.append(suffix)
    # Start all intended services before readiness waits to avoid dependency deadlocks.
    for suffix in RECOVER:
        try:
            old.kub_raw('-n', NS, 'rollout', 'status', KINDS[suffix] + '/' + PREFIX + suffix,
                        '--timeout=60s', timeout=70)
        except Exception:
            failures.append(suffix + ':readiness')
    c = api(credentials)
    end = time.monotonic() + 120
    while True:
        try:
            health, _ = c.get('/health')
            if health.get('status') == 'healthy':
                break
        except Exception:
            pass
        if time.monotonic() > end:
            failures.append('health')
            break
        time.sleep(3)
    for suffix, original in state['controllers'].items():
        obj = controller(suffix, original)
        if obj['spec']['replicas'] != original['replicas'] or obj.get('status', {}).get('readyReplicas') != original['replicas']:
            failures.append(suffix + ':replicas')
    if failures:
        state['recovery_failures'] = failures
        save(root / 'state.json', state)
        raise ValueError('Source recovery incomplete; retain readonly and use recover for this attempt')
    # Validate the original catalog before reopening writes.
    if (root / 'catalog-before.json').exists():
        if not equal_catalog(json.loads(read(root / 'catalog-before.json')), c.collect()):
            raise ValueError('Recovered source catalog differs; keep writes frozen')
    set_readonly(c, state['original_read_only'])
    guard(state)
    state.update(services_restored=True, restored_at=now(), phase='source-restored', recovery_failures=[])
    save(root / 'state.json', state)


def capture(root, credentials):
    state, c, database, record, secret_values = inspect_source(credentials)
    if root.exists():
        raise ValueError('Fresh snapshot attempt required; use recover for an interrupted attempt')
    directory(root)
    sync_directory(root.parent)
    state['attempt'] = root.name
    save(root / 'state.json', state)
    def interrupted(signum, frame):
        raise RuntimeError('Snapshot interrupted; restoring source')
    previous = {s: signal.signal(s, interrupted) for s in (signal.SIGTERM, signal.SIGINT, signal.SIGALRM)}
    try:
        # 25 minute work budget, then <=10 minute recovery. No permanent freeze.
        signal.alarm(1500)
        state.update(mutation_intent=True, phase='freezing-source')
        save(root / 'state.json', state)
        guard(state)
        print('Source preflight passed; freezing Harbor writes and draining tasks', flush=True)
        set_readonly(c, True)
        deadline = time.monotonic() + 180
        while True:
            workers, _ = c.get('/jobservice/pools/all/workers')
            queues, _ = c.get('/jobservice/queues')
            count = int(database.psql(None, "SELECT count(*) FROM task WHERE status NOT IN ('Success','Error','Stopped');"))
            if count + sum(bool(v.get('job_id')) for v in workers) + sum(v.get('count', 0) for v in queues) == 0:
                break
            if time.monotonic() > deadline:
                raise ValueError('Source jobs did not drain; no forced cancellation')
            time.sleep(3)
        for suffix in STOP[:2]:
            scale(state, suffix, 0)
        save(root / 'catalog-before.json', c.collect())
        save(root / 'identity-before.json', identities(c))
        save(root / 'policy-before.json', policy(c))
        save(root / 'secrets.json', secret_values)
        for suffix in STOP[2:]:
            scale(state, suffix, 0)
        deadline = time.monotonic() + 180
        while not stopped(state):
            if time.monotonic() > deadline:
                raise ValueError('Writer pods did not stop gracefully')
            time.sleep(2)
        if int(database.psql(None, "SELECT count(*) FROM pg_stat_activity WHERE datname='registry' AND backend_type='client backend' AND pid<>pg_backend_pid();")):
            raise ValueError('Unexpected remaining database client during source freeze')
        if int(database.psql(None, "SELECT count(*) FROM task WHERE status NOT IN ('Success','Error','Stopped');")):
            raise ValueError('Tasks appeared while stopping writers; restore source before retry')
        state.update(phase='exporting', writers_stopped_at=now())
        save(root / 'state.json', state)
        print('Source writers stopped; exporting PG17.6 and checking every registry file', flush=True)
        before = database.inventory(None)
        save(root / 'inventory.json', before)
        write(root / 'registry.dump', database.command(PG_BIN + 'pg_dump', '-h', '127.0.0.1', '-U', 'postgres', '-Fc', '--create', 'registry'))
        write(root / 'globals.sql', database.command(PG_BIN + 'pg_dumpall', '-h', '127.0.0.1', '-U', 'postgres', '--globals-only'))
        state['registry'] = content(state, record['registry']['files'])
        after = database.inventory(None)
        save(root / 'inventory-after.json', after)
        if before != after or not stopped(state):
            raise ValueError('Source changed across frozen export; snapshot not complete')
        secrets_equal(load(CONFIG))
        state['files'] = {p.name: {'bytes': p.stat().st_size, 'sha256': sha(p)}
                          for p in root.iterdir() if p.is_file() and p.name != 'state.json'}
        state['registry_archive'] = str(ARCHIVE / 'volumes/registry.tar')
        state['registry_archive_sha256'] = record['files']['volumes/registry.tar']['sha256']
        state.update(completed=True, completed_at=now(), final_cutover_admission=False,
                     database_version='17.6', inventory_equal_across_export=True,
                     archive_reference_only=True, independent_restore_verified=False)
        save(root / 'state.json', state)
        print('Frozen logical export and complete registry comparison passed', flush=True)
    finally:
        signal.alarm(0)
        # SIGINT/SIGTERM must not interrupt source recovery a second time.
        try:
            if state['mutation_intent']:
                with recovery_budget():
                    recover(root, state, credentials)
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)
    return public(state)


def public(state):
    return {k: state[k] for k in ('attempt', 'completed', 'services_restored', 'phase',
            'registry', 'inventory_equal_across_export', 'final_cutover_admission',
            'independent_restore_verified') if k in state}


def main():
    os.umask(0o077)
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('check', 'capture', 'recover'), nargs='?', default='check')
    p.add_argument('--attempt', default='20260928-v1')
    p.add_argument('--docker-credentials', type=Path)
    p.add_argument('--apply', action='store_true')
    args = p.parse_args()
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,50}', args.attempt):
        raise ValueError('Unsafe attempt name')
    if not args.apply:
        print(json.dumps({'dry_run': True, 'action': args.action, 'source': old.UID,
            'attempt': args.attempt, 'work_budget_minutes': 25, 'automatic_recovery_budget_minutes': 10,
            'always_attempt_source_recovery': True,
            'old_nodes_stopped': False, 'entry_switch': False, 'registry_archive_reused_only_if_all_files_equal': True})); return
    if os.geteuid() != 0 or args.docker_credentials is None:
        raise ValueError('Root and explicit existing credential path required')
    # Refuse an absent data mount before opening paths on its underlying system disk.
    # Recovery may run under disk pressure and must not depend on the 20 GiB work reserve.
    storage(load(CONFIG), minimum_gib=0 if args.action == 'recover' else 20)
    fd = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb+') as lock:
        info = os.fstat(fd)
        if info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o600:
            raise ValueError('Unsafe lifecycle lock')
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        credentials = args.docker_credentials.absolute()
        root = BASE / args.attempt
        if args.action == 'check':
            state, _, _, record, _ = inspect_source(credentials)
            print(json.dumps({'read_only': True, 'preflight_passed': True,
                'controllers_ready': len(state['controllers']), 'database': '17.6',
                'registry_archive_files': len(record['registry']['files']), 'source_modified': False})); return
        if args.action == 'capture':
            if not BASE.exists():
                directory(BASE)
                sync_directory(BASE.parent)
            if BASE.resolve() != BASE or BASE.stat().st_uid != 0 or BASE.stat().st_mode & 0o077:
                raise ValueError('Unsafe snapshot base')
            for prior in BASE.iterdir():
                journal = prior / 'state.json'
                if journal.exists():
                    previous = read_manifest(journal)
                    if previous.get('mutation_intent') and not previous.get('services_restored'):
                        raise ValueError('An earlier snapshot needs recover first: ' + prior.name)
            result = capture(root, credentials)
        else:
            state = read_manifest(root / 'state.json')
            if state.get('schema') != 1 or state.get('attempt') != args.attempt or state.get('cluster_uid') != old.UID:
                raise ValueError('Source recovery journal identity differs')
            if state.get('mutation_intent') and not state.get('services_restored'):
                with recovery_budget():
                    recover(root, state, credentials)
            result = public(state)
        print(json.dumps(result, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (Exception, RecoveryDeadline) as error:
        raise SystemExit('Source snapshot stopped: ' + (str(error) if isinstance(error, (ValueError, RecoveryDeadline))
                         else type(error).__name__ + '; private diagnostics withheld')) from None
