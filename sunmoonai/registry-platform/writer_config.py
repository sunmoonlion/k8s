"""Shared writer configuration renderer for acceptance and managed lifecycle.

Writes only a new private config directory; no service startup or API mutation.
Cloud 未经实机验证. Original readonly configuration and images remain unchanged.
"""
import copy
import json
import yaml
from host_prepare import directory, docker, write
from runtime_files import env
from runtime_inspect import read

ROLES = ('registry', 'registryctl', 'core')

def prepare(instance, target, project):
    spec = instance.immutable('read-only')
    directory(target); directory(target / 'registry', 10000, 0o750)
    for source in (instance.root / 'config/registry').iterdir():
        if not source.is_file() or source.resolve() != source:
            raise ValueError('Unexpected registry configuration entry')
        write(target / 'registry' / source.name, read(source), uid=10000, mode=0o640)
    path = target / 'registry/config.yml'; registry = yaml.safe_load(read(path))
    if (registry['storage']['maintenance']['readonly']['enabled'] is not True
            or registry['storage']['maintenance']['uploadpurging']['enabled'] is not False
            or registry['storage']['delete']['enabled'] is not False):
        raise ValueError('Original registry protections differ')
    registry['storage']['maintenance']['readonly']['enabled'] = False
    # Preserve the initial copy as evidence; publish the changed copy atomically.
    path.rename(target / 'registry-config-before.yml')
    write(path, yaml.safe_dump(registry, sort_keys=False).encode(), uid=10000, mode=0o640)
    write(target / 'core.env', env(read(instance.root / 'config/core/env'), {'READ_ONLY': 'false'}), uid=10000, mode=0o640)
    services = {}
    for role in ROLES:
        item = copy.deepcopy(spec['services'][role]); item.pop('environment', None)
        # Use original env_file definitions; parsed Compose contains secrets only in memory.
        original = yaml.safe_load(read(instance.root / 'compose.yaml'))['services'][role]
        item['env_file'] = copy.deepcopy(original.get('env_file', []))
        if original.get('environment'):
            item['environment'] = copy.deepcopy(original['environment'])
        if role == 'core':
            item['env_file'] = [{'path': str(target / 'core.env'), 'format': 'raw'}]
        item['container_name'] = project + '-' + role
        item['networks'] = {'harbor': {'aliases': [role]}}
        for bind in item['volumes']:
            if bind['target'] == '/storage':
                bind['read_only'] = False
            elif bind['target'] == '/etc/registry':
                bind['source'] = str(target / 'registry')
        services[role] = item
    compose = {'name': project, 'services': services, 'networks': {'harbor': {
        'name': instance.project + '-backend', 'external': True}}}
    write(target / 'compose.yaml', yaml.safe_dump(compose, sort_keys=False).encode())
    args = ['compose', '-p', project, '-f', str(target / 'compose.yaml')]
    parsed = json.loads(docker(*args, 'config', '--format', 'json'))
    names = set(docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines())
    if any(s['container_name'] in names for s in services.values()):
        raise ValueError('Write trial container collision')
    return project, args, parsed

