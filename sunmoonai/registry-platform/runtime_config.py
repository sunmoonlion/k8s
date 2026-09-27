"""Render the shared cluster-independent Harbor runtime (no filesystem/API calls).

Consumes the official 2.13.2 generator output and admitted immutable image IDs.
Host preparation must supply the files and reconcile restored data before start.
Cloud runtime/SSH 未经实机验证. This module never runs Compose or starts services.
"""
import copy
import ipaddress
from pathlib import PurePosixPath
import re

VERSION = '2.13.2'
IMAGES = {'core': 'harbor-core', 'registry': 'registry-photon', 'registryctl': 'harbor-registryctl',
          'portal': 'harbor-portal', 'proxy': 'nginx-photon', 'jobservice': 'harbor-jobservice'}
PG_REFERENCE = 'bitnami/postgresql@sha256:dbd371582fbbb100b22b891e485f4559187362348c1d4b5d0a2191134807516b'
REDIS_REFERENCE = 'bitnami/redis@sha256:0d2c5324b7373522e1fce60d657d60c851aa2921b211fd795f20c8515bee429e'
PG_BIN = '/opt/bitnami/postgresql/bin/'
OWNER = 'sunmoonai.registry.deployment'


def validate_site(site):
    if set(site) != {'schema', 'deployment', 'root', 'platform', 'bind_address', 'https_port', 'write_enabled'}:
        raise ValueError('Unexpected runtime site fields')
    if site['schema'] != 1 or not re.fullmatch(r'sunmoon-harbor-[a-z0-9][a-z0-9-]{0,39}', site['deployment']):
        raise ValueError('Explicit versioned Harbor deployment name required')
    root = PurePosixPath(site['root'])
    if (str(root) != site['root'] or root.parent != PurePosixPath('/data/harbor/instances')
            or root.name != site['deployment']):
        raise ValueError('Each deployment needs its own directory under /data/harbor/instances')
    address = ipaddress.IPv4Address(site['bind_address'])
    if site['platform'] == 'wsl':
        if str(address) != '127.0.0.1' or site['https_port'] != 18443:
            raise ValueError('Local Harbor publishes loopback 18443 behind the SNI proxy')
    elif site['platform'] == 'cloud':
        if not any(address in ipaddress.IPv4Network(net) for net in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')) or site['https_port'] != 30443:
            raise ValueError('Cloud Harbor requires its independent host private IPv4 and port 30443')
    else:
        raise ValueError('Runtime platform must be wsl or cloud')
    if type(site['write_enabled']) is not bool:
        raise ValueError('Explicit Harbor write mode required')
    return root


def bind(source, target, writable=False):
    return {'type': 'bind', 'source': str(source), 'target': str(target), 'read_only': not writable,
            'bind': {'create_host_path': False}}


def image_id(record, reference):
    if (set(record) not in ({'reference', 'id', 'volumes', 'architecture', 'os'},
                            {'reference', 'id', 'volumes', 'architecture', 'os', 'source_config_sha256'}) or record['reference'] != reference
            or not re.fullmatch(r'sha256:[a-f0-9]{64}', record['id'])
            or record['architecture'] != 'amd64' or record['os'] != 'linux'
            or not isinstance(record['volumes'], list) or len(record['volumes']) != len(set(record['volumes']))):
        raise ValueError('Runtime image differs from its admitted offline identity/platform')
    if 'source_config_sha256' in record and not re.fullmatch(r'[a-f0-9]{64}', record['source_config_sha256']):
        raise ValueError('Original image config digest missing')
    for volume in record['volumes']:
        path = PurePosixPath(volume)
        if not path.is_absolute() or '..' in path.parts:
            raise ValueError('Invalid image volume declaration')
    return record['id']


def common(role, identity, site):
    # Autostart must be arranged by a storage-gated host unit, never Docker restart.
    return {'image': identity, 'container_name': site['deployment'] + '-' + role,
            'labels': {OWNER: site['deployment'], 'sunmoonai.registry.role': role, 'sunmoonai.registry.version': VERSION},
            'restart': 'no', 'pull_policy': 'never', 'networks': ['harbor'],
            'security_opt': ['no-new-privileges:true'], 'mem_limit': '1g', 'cpus': 2, 'pids_limit': 256,
            'logging': {'driver': 'local', 'options': {'max-size': '10m', 'max-file': '3'}}}


def cover_volumes(service, record, tmpfs_allowed):
    targets = {m['target'].rstrip('/') for m in service['volumes']}
    extra = {v.rstrip('/') for v in record['volumes']} - targets
    if extra != set(tmpfs_allowed):
        raise ValueError('Unaccounted-for image volume; refusing implicit Docker volume')
    if extra:
        service['tmpfs'] = [v + ':rw,nosuid,nodev,size=32m,uid=10000,gid=10000,mode=0750' for v in sorted(extra)]


def render(upstream, site, records):
    root = validate_site(site)
    if set(records) != set(IMAGES) | {'postgresql', 'redis'}:
        raise ValueError('Expected the six official Harbor images plus original PostgreSQL/Redis')
    if set(upstream.get('services', {})) != set(IMAGES) | {'redis', 'log'}:
        raise ValueError('Official generator service list differs; review before normalization')
    project = site['deployment']
    output = {'name': project, 'services': {}, 'networks': {
        'harbor': {'name': project + '-backend', 'internal': True, 'labels': {OWNER: project}},
        'frontend': {'name': project + '-frontend', 'driver': 'bridge',
                     'driver_opts': {'com.docker.network.bridge.enable_ip_masquerade': 'false'},
                     'labels': {OWNER: project}}}}
    allowed = {
        'registry': {'/storage', '/etc/registry', '/etc/registry/root.crt', '/harbor_cust_cert'},
        'registryctl': {'/storage', '/etc/registry', '/etc/registryctl/config.yml', '/harbor_cust_cert'},
        'core': {'/etc/core/ca', '/data', '/etc/core/certificates', '/etc/core/app.conf',
                 '/etc/core/private_key.pem', '/etc/core/key', '/harbor_cust_cert'},
        'portal': {'/etc/nginx/nginx.conf'},
        'proxy': {'/etc/nginx', '/etc/cert', '/harbor_cust_cert'},
        'jobservice': {'/var/log/jobs', '/etc/jobservice/config.yml', '/harbor_cust_cert'}}
    data_paths = {'/storage': 'registry', '/data': 'core-data', '/etc/core/ca': 'ca-download',
                  '/etc/core/private_key.pem': 'signing/private_key.pem', '/etc/core/key': 'signing/secretkey',
                  '/etc/registry/root.crt': 'signing/root.crt', '/etc/cert': 'tls', '/var/log/jobs': 'job-logs'}
    for role, name in IMAGES.items():
        original = upstream['services'][role]
        reference = 'goharbor/' + name + ':v' + VERSION
        if original.get('image') != reference:
            raise ValueError('Official generator image version changed')
        # Explicitly allow only the generator fields consumed here. Never carry
        # arbitrary upstream privileges, ports, host networking or root mounts.
        if set(original) - {'image', 'container_name', 'restart', 'cap_drop', 'cap_add', 'volumes',
                            'networks', 'depends_on', 'logging', 'env_file', 'ports', 'stop_grace_period'}:
            raise ValueError('Unexpected upstream service fields need review: ' + role)
        record = records[role]
        service = common(role, image_id(record, reference), site)
        service['cap_drop'] = ['ALL']
        caps = original.get('cap_add', [])
        if not isinstance(caps, list) or set(caps) - {'CHOWN', 'SETGID', 'SETUID', 'DAC_OVERRIDE', 'NET_BIND_SERVICE'}:
            raise ValueError('Unexpected official service capability')
        if caps:
            service['cap_add'] = copy.deepcopy(caps)
        if role in ('core', 'registryctl', 'jobservice'):
            service['env_file'] = [{'path': str(root / 'config' / role / 'env'), 'format': 'raw'}]
        volumes, targets = [], set()
        for item in original.get('volumes', []):
            if isinstance(item, str):
                parts = item.split(':')
                if len(parts) not in (2, 3) or (len(parts) == 3 and parts[2] not in ('z', 'ro')):
                    raise ValueError('Unexpected official bind syntax')
                source, target = parts[:2]
            elif isinstance(item, dict) and item.get('type') == 'bind' and not (set(item) - {'type', 'source', 'target', 'read_only'}):
                source, target = item['source'], item['target']
            else:
                raise ValueError('Expected explicit official bind mount')
            target = target.rstrip('/')
            if target in targets or target not in allowed[role]:
                raise ValueError('Unexpected or duplicate runtime mount target')
            targets.add(target)
            if source.startswith('./common/config/'):
                relative = PurePosixPath(source.removeprefix('./common/config/'))
                if relative.is_absolute() or '..' in relative.parts:
                    raise ValueError('Unsafe generated config path')
                source = root / 'config' / relative
            elif target in data_paths:
                source = root / data_paths[target]
            else:
                raise ValueError('Unmapped official service volume')
            writable = target in ('/data', '/var/log/jobs') or (target == '/storage' and site['write_enabled'])
            volumes.append(bind(source, target, writable))
        if targets != allowed[role]:
            raise ValueError('Required runtime bind missing')
        service['volumes'] = volumes
        extra = {'portal': {'/run', '/var/cache/nginx', '/var/log/nginx'},
                 'proxy': {'/run', '/var/cache/nginx', '/var/log/nginx'},
                 'registryctl': {'/var/lib/registry'}}.get(role, set())
        cover_volumes(service, record, extra)
        if role == 'proxy':
            service['networks'] = ['harbor', 'frontend']
            service['ports'] = [{'target': 8443, 'published': str(site['https_port']),
                                 'host_ip': site['bind_address'], 'protocol': 'tcp'}]
        if role == 'jobservice' and not site['write_enabled']:
            service['profiles'] = ['jobs-after-reconciliation']
        output['services'][role] = service
    redis = common('redis', image_id(records['redis'], REDIS_REFERENCE), site)
    redis.update(user='1001:1001', entrypoint=['/opt/bitnami/redis/bin/redis-server'], command=['/etc/sunmoon-redis.conf'],
                 read_only=True, cap_drop=['ALL'], mem_limit='512m', cpus=1, pids_limit=128,
                 volumes=[bind(root / 'redis', '/data', True), bind(root / 'redis.conf', '/etc/sunmoon-redis.conf')])
    cover_volumes(redis, records['redis'], set())
    redis['tmpfs'] = ['/tmp:rw,nosuid,nodev,noexec,size=32m,mode=1777']
    output['services']['redis'] = redis
    pg = common('postgresql', image_id(records['postgresql'], PG_REFERENCE), site)
    pg.update(user='1001:1001', entrypoint=[PG_BIN + 'postgres'],
              command=['-D', '/bitnami/postgresql/data', '-c', 'config_file=/sunmoon-config/postgresql.conf'],
              environment={'LD_PRELOAD': '/opt/bitnami/common/lib/libnss_wrapper.so',
                           'NSS_WRAPPER_PASSWD': '/sunmoon-config/passwd', 'NSS_WRAPPER_GROUP': '/sunmoon-config/group'},
              volumes=[bind(root / 'database', '/bitnami/postgresql', True), bind(root / 'pg-config', '/sunmoon-config'),
                       bind(root / 'pg-config', '/docker-entrypoint-initdb.d'), bind(root / 'pg-config', '/docker-entrypoint-preinitdb.d')],
              read_only=True, cap_drop=['ALL'], shm_size='128m', pids_limit=128)
    if set(records['postgresql']['volumes']) != {'/bitnami/postgresql', '/docker-entrypoint-initdb.d', '/docker-entrypoint-preinitdb.d'}:
        raise ValueError('Original PostgreSQL declared volumes differ')
    cover_volumes(pg, records['postgresql'], set())
    pg['tmpfs'] = ['/tmp:rw,nosuid,nodev,noexec,size=128m,mode=1777']
    output['services']['postgresql'] = pg
    return output
