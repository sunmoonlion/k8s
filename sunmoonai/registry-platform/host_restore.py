#!/usr/bin/env python3
"""Logical PG17.6 restoration into a NEW, stopped independent Harbor instance.

Default plan. --apply initializes an empty target and restores pinned exports;
reconciles every table/sequence/role/schema using the existing inventory helper.
Always stops/retains owned init and PG containers. Never starts Harbor or deletes
anything. Cloud host execution 未经实机验证.
"""
import argparse
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import subprocess

from host_prepare import docker, load, storage, write
from host_runtime import Instance
from harbor_inputs import sha
from runtime_inspect import read
from runtime_config import OWNER, PG_BIN

loader = importlib.util.spec_from_file_location('sunmoon_pg_inventory', Path(__file__).with_name('database-rehearsal.py'))
pg = importlib.util.module_from_spec(loader); loader.loader.exec_module(pg)


def restore(instance):
    storage(instance.config, minimum_gib=20)
    spec = instance.immutable()
    if not instance.state.get('creation_complete') or instance.state.get('database_reconciled') or instance.state.get('restore_attempted'):
        raise ValueError('One new created, unreconciled instance required; failed attempts are retained')
    if any(s not in ('created', 'exited') for s in instance.check().values()):
        raise ValueError('All instance containers must be stopped before logical restore')
    if any((instance.root / 'database').iterdir()):
        raise ValueError('Database target must be empty; never restore over existing PG data')
    exports = Path(instance.config['logical_export'])
    for name, digest in instance.config['logical_sha256'].items():
        if sha(exports / name) != digest:
            raise ValueError('Frozen logical export changed')
    if not json.loads(read(exports / 'state.json')).get('completed'):
        raise ValueError('Source logical export reconciliation is incomplete')
    expected_raw = read(exports / 'inventory.json')
    expected = json.loads(expected_raw)
    if expected.get('server_version_num') != '170006':
        raise ValueError('Logical inventory must be from PostgreSQL17.6')
    name = instance.project + '-database-init'
    if name in docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines():
        raise ValueError('Database initializer name collision')
    instance.state.update(restore_attempted=True, init_name=name, init_id=None,
                          inventory_sha256=__import__('hashlib').sha256(expected_raw).hexdigest())
    instance.persist()
    write(instance.root / 'database-baseline.json', expected_raw)
    service = spec['services']['postgresql']
    argv = ['create', '--name', name, '--label', OWNER + '=' + instance.project,
            '--label', 'sunmoonai.registry.role=database-init', '--network=none', '--restart=no', '--pull=never',
            '--user', '1001:1001', '--read-only', '--cap-drop=ALL', '--security-opt=no-new-privileges',
            '--log-driver=none', '--memory=1g', '--cpus=2', '--pids-limit=128',
            '--tmpfs', '/tmp:rw,nosuid,nodev,noexec,size=128m,mode=1777']
    for key, value in service['environment'].items():
        argv += ['--env', key + '=' + value]
    for mount in service['volumes']:
        argv += ['--mount', 'type=bind,src=' + mount['source'] + ',dst=' + mount['target'] + (',readonly' if mount.get('read_only') else '')]
    argv += ['--entrypoint', PG_BIN + 'initdb', service['image'], '-D', '/bitnami/postgresql/data', '-U', 'postgres',
             '--auth-local=trust', '--auth-host=reject', '--locale=C', '--encoding=UTF8']
    initializer = None
    try:
        initializer = docker(*argv).decode().strip()
        instance.state['init_id'] = initializer; instance.persist()
        actual = json.loads(docker('inspect', initializer))[0]
        if (actual['Image'] != service['image'] or actual['HostConfig']['NetworkMode'] != 'none'
                or any(m['Type'] == 'volume' for m in actual['Mounts']) or actual['HostConfig'].get('PortBindings')):
            raise ValueError('Initializer isolation differs; will not start')
        docker('start', initializer)
        if docker('wait', initializer, timeout=90).decode().strip() != '0':
            raise ValueError('PostgreSQL initializer failed; private data retained')
        database = instance.inspect('postgresql', service)['Id']
        docker('start', database)
        inventory = pg.Rehearsal(instance.root, exports)
        inventory.ready(database)
        # Existing helper uses the explicitly forced local Docker endpoint below.
        globals_sql = read(exports / 'globals.sql').decode()
        if globals_sql.count('CREATE ROLE postgres;\n') != 1:
            raise ValueError('Unexpected original global-role export; no blind SQL rewriting')
        inventory.psql(database, globals_sql.replace('CREATE ROLE postgres;\n', ''), 'postgres')
        with (exports / 'registry.dump').open('rb') as stream:
            result = subprocess.run(['docker', '--host', 'unix:///var/run/docker.sock', 'exec', '-i', database,
                PG_BIN + 'pg_restore', '-h', '/tmp', '-U', 'postgres', '--exit-on-error', '--create', '--dbname=postgres'],
                stdin=stream, capture_output=True, timeout=180)
        if result.returncode:
            raise ValueError('Logical restore failed; private diagnostics withheld')
        restored = inventory.inventory(database)
        if restored != expected:
            raise ValueError('Restored tables/rows/roles/schema/sequences differ from the frozen logical inventory')
        for filename, digest in instance.config['logical_sha256'].items():
            if sha(exports / filename) != digest:
                raise ValueError('Logical export changed while restoring')
        instance.state['database_reconciled'] = True
        instance.state['restored_inventory'] = {'tables': len(restored['tables']),
            'rows': sum(t['rows'] for t in restored['tables']), 'server_version_num': restored['server_version_num']}
        instance.persist()
    finally:
        if initializer is None:
            # Recover a created initializer if execution was interrupted before ID persistence.
            names = docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines()
            if name in names:
                initializer = name
        if initializer:
            actual = json.loads(docker('inspect', initializer))[0]
            labels = actual['Config'].get('Labels') or {}
            if labels.get(OWNER) != instance.project or labels.get('sunmoonai.registry.role') != 'database-init':
                raise ValueError('Initializer ownership changed; refusing to stop another container')
            if actual['State']['Running']:
                docker('stop', '--time', '60', actual['Id'], timeout=75)
        instance.stop()
    return {'database_reconciled': instance.state['database_reconciled'], **instance.state['restored_inventory'],
            'all_instance_containers_stopped': True, 'harbor_started': False, 'source_data_changed': False}


def main():
    os.umask(0o077)
    os.environ['DOCKER_HOST'] = 'unix:///var/run/docker.sock'
    os.environ.pop('DOCKER_CONTEXT', None)
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config', type=Path, required=True); p.add_argument('--apply', action='store_true')
    args = p.parse_args(); config = load(args.config.absolute())
    if not args.apply:
        print(json.dumps({'dry_run': True, 'deployment': config['runtime']['deployment'], 'database': '17.6',
                          'empty_target_required': True, 'start_harbor': False, 'stop_after_restore': True})); return
    with Path('/data/harbor/.instance-preparation.lock').open('rb+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps(restore(Instance(config)), indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Host database restore stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld; data retained')) from None
