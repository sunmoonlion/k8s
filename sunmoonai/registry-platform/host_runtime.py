#!/usr/bin/env python3
"""Guarded lifecycle for a prepared independent Harbor instance.

Default prints only. create creates stopped containers; start requires separately
reconciled data. stop retains containers/networks/data. No down/rm/prune, implicit
pulls, cluster operations or port cutover. Cloud runtime 未经实机验证.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import stat
import time
import uuid

from host_prepare import docker, load, storage, write, verify_images
from harbor_inputs import sha
from runtime_inspect import read
from runtime_config import OWNER
from rehearsal_retirement import assert_active

ORDER = ['postgresql', 'redis', 'registry', 'registryctl', 'core', 'portal', 'proxy']


def save(path, value):
    temp = path.with_name('.' + path.name + '.' + uuid.uuid4().hex)
    write(temp, (json.dumps(value, indent=2) + '\n').encode())
    os.replace(temp, path)


class Instance:
    def __init__(self, config):
        self.config = config
        self.root = Path(config['runtime']['root'])
        if os.geteuid() != 0 or self.root.resolve() != self.root or self.root.stat().st_uid != 0 or self.root.stat().st_mode & 0o077:
            raise ValueError('Root and exact private instance directory required')
        if json.loads(read(self.root / 'host-config.json')) != config:
            raise ValueError('Configuration differs from the prepared instance')
        self.prep = json.loads(read(self.root / 'preparation.json'))
        if self.prep.get('prepared') is not True or self.prep['runtime'] != config['runtime']:
            raise ValueError('Preparation incomplete or for a different instance')
        self.project = config['runtime']['deployment']
        self.path = self.root / 'runtime-state.json'
        self.state = json.loads(read(self.path)) if self.path.exists() else {
            'schema': 1, 'deployment': self.project, 'created': {}, 'database_reconciled': False, 'started': False}
        if self.state.get('schema') != 1 or self.state.get('deployment') != self.project:
            raise ValueError('Runtime journal belongs to another instance')
        self.compose = ['compose', '-p', self.project, '-f', str(self.root / 'compose.yaml'), '--profile', '*']

    def mode(self):
        mode = self.state.get('service_mode', 'read-only')
        if mode not in ('read-only', 'writable'):
            raise ValueError('Unknown persisted service mode')
        return mode

    def identity(self, role, mode=None):
        mode = self.mode() if mode is None else mode
        if mode not in ('read-only', 'writable'):
            raise ValueError('Explicit service mode required')
        if mode == 'writable' and role in ('registry', 'registryctl', 'core'):
            writer = self.prep.get('writer')
            if not writer or not writer.get('prepared'):
                raise ValueError('Prepared writer generation required')
            return writer['project'], self.state.get('writer_created', {})
        return self.project, self.state['created']

    def immutable(self, mode=None):
        for name, digest in self.prep['immutable_files'].items():
            path = self.root / name
            if (path.resolve() != path or not path.is_relative_to(self.root) or sha(path) != digest
                    or path.stat().st_mode & 0o022):
                raise ValueError('Immutable runtime input changed')
        if docker('compose', 'version', '--short').decode().strip() != '5.1.3':
            raise ValueError('Compose version differs from preparation')
        verify_images(self.prep['images'])
        spec = json.loads(docker(*self.compose, 'config', '--format', 'json'))
        if (self.mode() if mode is None else mode) == 'writable':
            project, _ = self.identity('core', 'writable')
            writer = json.loads(docker('compose', '-p', project, '-f',
                str(self.root / self.prep['writer']['compose']), 'config', '--format', 'json'))
            if set(writer['services']) != {'registry', 'registryctl', 'core'}:
                raise ValueError('Writer service set differs')
            spec['services'].update(writer['services'])
        return spec

    def persist(self):
        save(self.path, self.state)

    def inspect(self, role, spec=None, *, mode=None):
        project, created = self.identity(role, mode)
        name = project + '-' + role
        result = json.loads(docker('inspect', name))[0]
        labels = result['Config'].get('Labels') or {}
        if (labels.get(OWNER) != self.project or labels.get('sunmoonai.registry.role') != role
                or labels.get('com.docker.compose.project') != project
                or result['Image'] != self.prep['images'][role]['id']
                or (role in created and result['Id'] != created[role])):
            raise ValueError('Container identity/ownership differs: ' + role)
        host = result['HostConfig']
        if host['Privileged'] or host['RestartPolicy']['Name'] != 'no' or any(m['Type'] == 'volume' for m in result['Mounts']):
            raise ValueError('Container privilege/restart/volume contract differs: ' + role)
        if spec is not None:
            expected = {v['target'].rstrip('/'): (str(Path(v['source'])), not v.get('read_only', False)) for v in spec['volumes']}
            binds = {v['Destination'].rstrip('/'): (v['Source'], v['RW']) for v in result['Mounts'] if v['Type'] == 'bind'}
            if binds != expected or host['ReadonlyRootfs'] != spec.get('read_only', False):
                raise ValueError('Container bind/root filesystem contract differs: ' + role)
            ports = {'8443/tcp': [{'HostIp': self.config['runtime']['bind_address'], 'HostPort': str(self.config['runtime']['https_port'])}]} if role == 'proxy' else {}
            if (host.get('PortBindings') or {}) != ports:
                raise ValueError('Container published ports differ: ' + role)
            expected_networks = {self.project + ('-backend' if n == 'harbor' else '-frontend') for n in spec['networks']}
            if set(result['NetworkSettings']['Networks']) != expected_networks:
                raise ValueError('Container networks differ: ' + role)
            if role in ('trivy', 'registry-route', 'scan-jobs'):
                if (result['Config'].get('User') != spec['user'] or host.get('CapDrop') != ['ALL']
                        or host.get('CapAdd') or result['Config'].get('Entrypoint') != spec['entrypoint']
                        or (result['Config'].get('Cmd') or []) != (spec.get('command') or [])
                        or (role == 'trivy' and result['Config'].get('Healthcheck', {}).get('Test')
                            != spec['healthcheck']['test'])):
                    raise ValueError('Managed scanner execution contract differs: ' + role)
            values = dict(v.split('=', 1) for v in (result['Config'].get('Env') or []))
            if any(values.get(k) != str(v) for k, v in spec.get('environment', {}).items()):
                raise ValueError('Container environment differs; details withheld')
        return result

    def check(self):
        spec = self.immutable()
        names = set(docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines())
        result = {}
        for role, service in spec['services'].items():
            if self.identity(role)[0] + '-' + role not in names:
                result[role] = 'absent'
            else:
                info = self.inspect(role, service)
                result[role] = info['State']['Status']
        if self.prep.get('writer'):
            inactive = 'read-only' if self.mode() == 'writable' else 'writable'
            other = self.immutable(inactive)
            for role in ('registry', 'registryctl', 'core'):
                name = self.identity(role, inactive)[0] + '-' + role
                result['retained/' + role] = ('absent' if name not in names else
                    self.inspect(role, other['services'][role], mode=inactive)['State']['Status'])
        return result

    def create(self):
        storage(self.config, minimum_gib=20)
        spec = self.immutable()
        if self.state.get('configuration_transition_open') or self.mode() != 'read-only':
            raise ValueError('Incomplete configuration transition requires review')
        status = self.check()
        if any(s not in ('absent', 'created', 'exited') for s in status.values()):
            raise ValueError('Creation requires all owned existing containers stopped')
        networks = set(docker('network', 'ls', '--format', '{{.Name}}').decode().splitlines())
        for network in spec['networks'].values():
            if network['name'] in networks:
                obj = json.loads(docker('network', 'inspect', network['name']))[0]
                if (obj.get('Labels') or {}).get(OWNER) != self.project:
                    raise ValueError('Network name collision; no adoption')
        self.state['intended'] = [self.project + '-' + role for role in spec['services']]
        self.persist()
        docker(*self.compose, 'create', '--no-recreate', '--pull', 'never', '--no-build', timeout=180)
        for role, service in spec['services'].items():
            info = self.inspect(role, service)
            if info['State']['Running']:
                raise ValueError('Creation unexpectedly started a service')
            self.state['created'][role] = info['Id']; self.persist()
        self.state['creation_complete'] = True; self.persist()
        if self.prep.get('writer'):
            from host_mode import create as create_writer
            create_writer(self)
        return self.check()

    def stop(self):
        # Stop remains possible with low disk space; no storage capacity gate.
        errors = []
        for role in ['scan-jobs', 'trivy', 'registry-route', 'proxy', 'portal', 'core', 'jobservice', 'registryctl', 'registry', 'redis', 'postgresql']:
            if role not in self.state['created']:
                continue
            modes = [self.mode()]
            if self.prep.get('writer') and role in ('registry', 'registryctl', 'core'):
                modes.append('read-only' if self.mode() == 'writable' else 'writable')
            for mode in modes:
                _, recorded = self.identity(role, mode)
                if role not in recorded:
                    continue
                try:
                    info = self.inspect(role, mode=mode)
                    if info['State']['Running']:
                        docker('stop', '--time', '60', info['Id'], timeout=75)
                    if self.inspect(role, mode=mode)['State']['Running']:
                        raise ValueError('Service did not stop')
                except Exception:
                    errors.append(mode + '/' + role)
        if self.state.get('init_id'):
            try:
                init = json.loads(docker('inspect', self.state['init_id']))[0]
                labels = init['Config'].get('Labels') or {}
                if (labels.get(OWNER) != self.project or labels.get('sunmoonai.registry.role') != 'database-init'
                        or init['Image'] != self.prep['images']['postgresql']['id']):
                    raise ValueError('Initializer identity differs')
                if init['State']['Running']:
                    docker('stop', '--time', '60', init['Id'], timeout=75)
                if json.loads(docker('inspect', init['Id']))[0]['State']['Running']:
                    raise ValueError('Initializer did not stop')
            except Exception:
                errors.append('database-init')
        self.state['started'] = False; self.state['stop_errors'] = errors; self.persist()
        if errors:
            raise ValueError('Owned services could not be stopped: ' + ','.join(errors))
        return {'stopped_and_retained': sorted(self.state['created'])}

    def start(self, with_jobs=None, *, allow_mode_transition=False):
        assert_active(self.root)
        storage(self.config, minimum_gib=20)
        if with_jobs is None:
            with_jobs = self.mode() == 'writable'
        spec = self.immutable()
        if self.state.get('mode_transition_open') and not allow_mode_transition:
            raise ValueError('Incomplete service mode transition requires explicit recovery')
        if self.mode() == 'writable':
            if set(self.state.get('writer_created', {})) != {'registry', 'registryctl', 'core'}:
                raise ValueError('Writer generation container identities incomplete')
            for role in ('registry', 'registryctl', 'core'):
                if self.inspect(role, mode='read-only')['State']['Running']:
                    raise ValueError('Retained read-only generation must be stopped')
        elif self.prep.get('writer'):
            for role in self.state.get('writer_created', {}):
                if self.inspect(role, mode='writable')['State']['Running']:
                    raise ValueError('Retained writable generation must be stopped')
        if (not self.state.get('creation_complete') or self.state.get('stop_errors')
                or self.state.get('metadata_acceptance_open') or self.state.get('write_acceptance_open')
                or self.state.get('configuration_transition_open')
                or not self.state.get('database_reconciled') or not self.prep['registry'].get('all_file_sha256_match')):
            raise ValueError('Reconciled database and registry content required before Harbor startup')
        for role in spec['services']:
            self.inspect(role, spec['services'][role])
        if self.inspect('jobservice')['State']['Running']:
            raise ValueError('Jobservice must stay stopped during read-only acceptance')
        if with_jobs and (not self.prep.get('scanner') or not self.state.get('scanner_acceptance', {}).get('passed')):
            raise ValueError('Managed Jobservice requires completed scanner acceptance')
        if 'scan-jobs' in spec['services'] and not with_jobs and self.inspect('scan-jobs')['State']['Running']:
            raise ValueError('Managed jobs must stay stopped during read-only startup')
        started = []
        try:
            order = ORDER + (['registry-route', 'trivy'] if self.prep.get('scanner') else [])
            if with_jobs:
                order.append('scan-jobs')
            for role in order:
                info = self.inspect(role, spec['services'][role])
                if not info['State']['Running']:
                    docker('start', info['Id']); started.append(role)
                if role in ('postgresql', 'redis'):
                    deadline = time.monotonic() + 90
                    while True:
                        try:
                            if role == 'postgresql':
                                docker('exec', info['Id'], '/opt/bitnami/postgresql/bin/pg_isready', '-h', '/tmp', '-U', 'postgres', '-d', 'registry')
                            else:
                                rows = [l[len('requirepass '):] for l in read(self.root / 'redis.conf').decode().splitlines() if l.startswith('requirepass ')]
                                if len(rows) != 1:
                                    raise ValueError('Redis credential missing')
                                password = json.loads(rows[0])
                                reply = docker('exec', '-i', info['Id'], '/opt/bitnami/redis/bin/redis-cli', '--raw',
                                               content=('AUTH ' + password + '\nPING\n').encode())
                                if reply.strip().splitlines() != [b'OK', b'PONG']:
                                    raise ValueError('Redis authentication readiness failed')
                            break
                        except ValueError:
                            if time.monotonic() >= deadline or not self.inspect(role)['State']['Running']:
                                raise ValueError('Database/cache readiness deadline or stopped service: ' + role) from None
                            time.sleep(2)
            self.state['started'] = True; self.persist()
        except Exception:
            self.stop(); raise
        return {'started': started, 'health_verified': False, 'write_enabled': self.mode() == 'writable', 'entry_switched': False,
                'managed_jobservice_started': with_jobs}


def main():
    os.umask(0o077)
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('create', 'check', 'start', 'stop'))
    p.add_argument('--config', type=Path, required=True); p.add_argument('--apply', action='store_true')
    p.add_argument('--with-jobs', action='store_true', default=None, help='Start accepted managed Jobservice with the host stack')
    args = p.parse_args(); config = load(args.config.absolute())
    if args.with_jobs and args.action != 'start':
        raise ValueError('--with-jobs is only valid for start')
    if not args.apply:
        print(json.dumps({'dry_run': True, 'action': args.action, 'deployment': config['runtime']['deployment'],
                          'start_requires_reconciliation': True, 'with_jobs': args.with_jobs, 'delete': False, 'entry_switch': False})); return
    fd = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb+') as lock:
        if os.fstat(lock.fileno()).st_uid != 0 or stat.S_IMODE(os.fstat(lock.fileno()).st_mode) != 0o600:
            raise ValueError('Unsafe lifecycle lock')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        instance = Instance(config)
        result = instance.start(with_jobs=args.with_jobs) if args.action == 'start' else getattr(instance, args.action)()
        print(json.dumps({'action': args.action, 'deployment': instance.project, 'result': result}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Host lifecycle stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld')) from None
