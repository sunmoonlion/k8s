#!/usr/bin/env python3
"""Managed readonly/writable Harbor generations; default prints only.

Reuses official pinned images and one data directory. Retains both generations,
never deletes containers/data, and blocks normal startup on interrupted changes.
Cloud shared generation/API code 未经实机验证; WSL uses loopback18443, cloud
uses its explicit private host30443 with the same strict TLS and identity checks.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import time

from host_prepare import docker, load, storage, write
from host_runtime import Instance, save
from host_verify import client
from host_write_verify import api
from runtime_inspect import read
from writer_config import prepare as render_writer, ROLES


def create(instance):
    if (instance.mode() != 'read-only' or not instance.prep.get('writer')
            or instance.state.get('configuration_transition_open') not in (None, False, 'writer-v1')
            or instance.state.get('mode_transition_open') or instance.state.get('write_acceptance_open')
            or instance.state.get('metadata_acceptance_open')):
        raise ValueError('Prepared writer and readonly mode required')
    spec = instance.immutable('writable')
    if any(s not in ('created', 'exited', 'absent') for s in instance.check().values()):
        raise ValueError('Both generations must be stopped during creation')
    writer = instance.prep['writer']; project = writer['project']
    # Compose never removes/recreates an existing container.
    docker('compose', '-p', project, '-f', str(instance.root / writer['compose']),
           'create', '--no-recreate', '--pull', 'never', '--no-build', timeout=120)
    for role in ROLES:
        obj = instance.inspect(role, spec['services'][role], mode='writable')
        if obj['State']['Running']:
            raise ValueError('Creation unexpectedly started writer')
        instance.state.setdefault('writer_created', {})[role] = obj['Id']; instance.persist()
    instance.state['configuration_transition_open'] = False; instance.persist()
    return {'writer_created': True, 'services_started': False, 'mode': instance.mode()}


def prepare(instance):
    storage(instance.config, minimum_gib=20)
    if (instance.prep.get('writer') or instance.state.get('configuration_transition_open')
            or instance.state.get('write_acceptance_open') or instance.state.get('mode_transition_open')
            or instance.mode() != 'read-only' or not instance.state.get('write_acceptance', {}).get('passed')
            or any(s not in ('created','exited') for s in instance.check().values())):
        raise ValueError('Stopped accepted readonly instance without an existing transition required')
    target = instance.root / 'writer-v1'
    project, _, _ = render_writer(instance, target, instance.project + '-writer-v1')
    write(target / 'preparation-before.json', read(instance.root / 'preparation.json'))
    write(target / 'state-before.json', read(instance.root / 'runtime-state.json'))
    instance.state['configuration_transition_open'] = 'writer-v1'; instance.persist()
    instance.prep['writer'] = {'schema':1, 'prepared':True, 'project':project,
                              'compose':'writer-v1/compose.yaml', 'roles':list(ROLES)}
    for path in target.rglob('*'):
        if path.is_file():
            if path.resolve() != path or path.stat().st_mode & 0o022:
                raise ValueError('Writer configuration path/mode differs')
            instance.prep['immutable_files'][str(path.relative_to(instance.root))] = hashlib.sha256(read(path)).hexdigest()
    save(instance.root / 'preparation.json', instance.prep)
    return create(instance)


def ready(instance, credentials):
    deadline = time.monotonic() + 180
    while True:
        try:
            c = client(instance, credentials, time.monotonic() + 900)
            if type(api(c, '/configurations')['read_only']['value']) is not bool:
                raise ValueError('Harbor mode response differs')
            return c
        except Exception:
            if time.monotonic() >= deadline:
                raise ValueError('Managed Harbor TLS/API readiness deadline') from None
            time.sleep(2)


def switch(instance, mode, credentials, leave_running=False):
    storage(instance.config, minimum_gib=20)
    if (not instance.prep.get('writer') or instance.state.get('configuration_transition_open')
            or instance.state.get('metadata_acceptance_open') or instance.state.get('write_acceptance_open')
            or (instance.state.get('mode_transition_open') and mode != 'read-only')):
        raise ValueError('Prepared generation required; unfinished transition may recover only to readonly')
    if mode == 'writable' and not instance.state.get('write_acceptance', {}).get('passed'):
        raise ValueError('Writable mode requires completed push/pull acceptance')
    before = instance.mode()
    # Stop both generations before changing aliases or effective mount contracts.
    instance.stop()
    if any(s not in ('created','exited') for s in instance.check().values()):
        raise ValueError('Both generations must be present and stopped')
    receipt_path = instance.root / 'writer-v1' / ('mode-' + str(time.time_ns()) + '.json')
    record = {'schema':1, 'from':before, 'to':mode, 'completed':False, 'entry_switched':False,
              'rollback_is_mode_change_only':True}
    instance.state['mode_transition_open'] = str(receipt_path); instance.persist()
    save(receipt_path, record)
    try:
        instance.state['service_mode'] = mode; instance.persist()
        # Jobs start only after the API mode is confirmed below.
        instance.start(with_jobs=False, allow_mode_transition=True)
        c = ready(instance, credentials)
        dump = docker('exec', instance.inspect('postgresql')['Id'], '/opt/bitnami/postgresql/bin/pg_dump',
                      '-h','/tmp','-U','postgres','-Fc','registry',timeout=90)
        if not dump.startswith(b'PGDMP'):
            raise ValueError('Pre-mode metadata export invalid')
        write(receipt_path.with_suffix('.dump'), dump)
        record['metadata_dump_sha256'] = hashlib.sha256(dump).hexdigest()
        api(c, '/configurations', 'PUT', {'read_only':mode == 'read-only'})
        if api(c, '/configurations')['read_only']['value'] is not (mode == 'read-only'):
            raise ValueError('API mode does not match managed generation')
        for role in ('registry','registryctl'):
            mounts = [m for m in instance.inspect(role)['Mounts'] if m['Destination'] == '/storage']
            if len(mounts) != 1 or mounts[0]['RW'] is not (mode == 'writable'):
                raise ValueError('Registry filesystem mode differs from API mode')
        if mode == 'writable':
            instance.start(with_jobs=True, allow_mode_transition=True)
            deadline = time.monotonic() + 90
            while True:
                try:
                    if api(c, '/jobservice/pools'):
                        break
                except ValueError:
                    pass
                if time.monotonic() >= deadline:
                    raise ValueError('Managed Jobservice readiness deadline')
                time.sleep(2)
        record.update(completed=True, api_read_only=mode == 'read-only', jobs_started=mode == 'writable')
        instance.state['mode_transition_open'] = False
        instance.state['service_mode_acceptance'] = record; instance.persist()
    finally:
        if not leave_running or not record['completed']:
            instance.stop()
        record['left_running'] = leave_running and record['completed']
        save(receipt_path, record)
    return record


def backup(instance, destination, credentials):
    from host_backup import backup_path, cold_backup, members, mutable_paths, admit_capacity
    import stat
    destination = backup_path(destination)
    if destination.exists():
        raise ValueError('Backup destination exists; no overwrite')
    # Admission before any downtime: a fresh complete archive, no hidden reuse.
    size = sum(info.st_size for _, info in members(instance.root, ('registry', *mutable_paths(instance)))
               if stat.S_ISREG(info.st_mode))
    admit_capacity(instance.config, destination, size)
    if instance.state.get('mode_transition_open'):
        raise ValueError('Recover the incomplete mode change before backup')
    original_mode = instance.mode()
    was_running = any(v == 'running' for v in instance.check().values())
    switch(instance, 'read-only', credentials)
    try:
        result = cold_backup(instance, destination, credentials)
    finally:
        # Re-enable only the previous mode, never implicitly promote readonly.
        switch(instance, original_mode, credentials, leave_running=was_running)
    receipt = {'backup': result, 'original_mode_restored': original_mode,
               'previous_running_state_restored': was_running, 'destination':str(destination)}
    save(instance.root / 'writer-v1' / ('backup-run-' + str(time.time_ns()) + '.json'),receipt)
    return receipt


def main():
    os.umask(0o077)
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('prepare','create','read-only','writable','backup'))
    p.add_argument('--config', type=Path, required=True)
    p.add_argument('--docker-credentials', type=Path)
    p.add_argument('--backup', type=Path)
    p.add_argument('--leave-running', action='store_true')
    p.add_argument('--apply', action='store_true'); args=p.parse_args()
    config=load(args.config.absolute())
    if args.leave_running and args.action not in ('read-only','writable'):
        raise ValueError('--leave-running requires an explicit mode')
    if not args.apply:
        print(json.dumps({'dry_run':True,'action':args.action,'leave_running':args.leave_running,
            'retains_both_generations':True,'entry_switch':False,'cloud_verified':False}));return
    with os.fdopen(os.open('/data/harbor/.instance-preparation.lock',os.O_RDWR|os.O_NOFOLLOW),'rb+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        instance=Instance(config)
        if args.action in ('prepare','create'):
            result=prepare(instance) if args.action=='prepare' else create(instance)
        else:
            if not args.docker_credentials:
                raise ValueError('Explicit existing owner credential file required')
            if args.action == 'backup':
                if not args.backup:
                    raise ValueError('Explicit new backup destination required')
                result=backup(instance,args.backup,args.docker_credentials)
            else:
                result=switch(instance,args.action,args.docker_credentials,args.leave_running)
        print(json.dumps(result,indent=2))


if __name__=='__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Managed mode stopped: '+(str(error) if isinstance(error,ValueError)
            else type(error).__name__+'; private diagnostics withheld')) from None
