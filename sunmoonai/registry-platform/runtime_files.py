"""Normalize private official Harbor configuration bytes for the shared runtime.

Pure transformation: no files, commands, passwords or certificates are emitted.
The host installer supplies pinned original inputs and validated HTTPS leaves.
"""
import json
import re
from urllib.parse import parse_qsl, quote, urlsplit, urlunsplit
from pathlib import PurePosixPath

import yaml


def env(raw, changes):
    lines = raw.decode().splitlines()
    for key, value in changes.items():
        indices = [i for i, line in enumerate(lines) if line.startswith(key + '=')]
        if len(indices) != 1 or not isinstance(value, str) or any(c in value for c in '\r\n\x00'):
            raise ValueError('Missing, ambiguous or unsafe generated environment field: ' + key)
        lines[indices[0]] = key + '=' + value
    return ('\n'.join(lines) + '\n').encode()


def redis_url(value, password):
    parsed = urlsplit(value)
    if parsed.scheme != 'redis' or parsed.hostname != 'redis' or parsed.port not in (None, 6379):
        raise ValueError('Generated Redis URL must refer to the private Redis service')
    if (parsed.fragment or parsed.path not in ('', '/0', '/1', '/2')
            or parse_qsl(parsed.query, keep_blank_values=True, strict_parsing=True)
            not in ([], [('idle_timeout_seconds', '30')])):
        raise ValueError('Unexpected Redis URL options need explicit review')
    return urlunsplit(('redis', ':' + quote(password, safe='') + '@redis:6379', parsed.path, parsed.query, ''))


def render(generated, preserved, tls, redis_password, write_enabled):
    if (type(write_enabled) is not bool or not isinstance(redis_password, str) or len(redis_password) < 32
            or not re.fullmatch(r'[A-Za-z0-9_-]{32,128}', redis_password)):
        raise ValueError('Explicit runtime mode and a strong private Redis credential required')
    keys = {'core_secret', 'jobservice_secret', 'registry_username', 'registry_password', 'csrf_key',
            'database_password', 'admin_password', 'registry_http_secret', 'registry_htpasswd',
            'core_key', 'token_key', 'token_cert'}
    if set(preserved) != keys or len(preserved['core_key']) != 16 or set(tls) != {'certificate', 'key', 'ca'}:
        raise ValueError('Required preserved identities or validated TLS inputs missing')
    output = {}
    for name, raw in generated.items():
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or str(path) != name or not isinstance(raw, bytes):
            raise ValueError('Unsafe generated configuration path')
        output['config/' + name] = raw
    value = lambda key: preserved[key].decode()
    shared = {'CORE_SECRET': value('core_secret'), 'JOBSERVICE_SECRET': value('jobservice_secret')}
    credentials = {'REGISTRY_CREDENTIAL_USERNAME': value('registry_username'), 'REGISTRY_CREDENTIAL_PASSWORD': value('registry_password')}
    core = 'config/core/env'
    fields = dict(line.split('=', 1) for line in output[core].decode().splitlines() if '=' in line)
    cache = {k: redis_url(fields[k], redis_password) for k in ('_REDIS_URL_CORE', '_REDIS_URL_REG')}
    output[core] = env(output[core], {**shared, **credentials, **cache, 'CSRF_KEY': value('csrf_key'),
        'POSTGRESQL_PASSWORD': value('database_password'), 'HARBOR_ADMIN_PASSWORD': value('admin_password'),
        'READ_ONLY': str(not write_enabled).lower()})
    output['config/jobservice/env'] = env(output['config/jobservice/env'], {**shared, **credentials})
    output['config/registryctl/env'] = env(output['config/registryctl/env'], shared)
    registry = yaml.safe_load(output['config/registry/config.yml'])
    if registry['storage']['filesystem']['rootdirectory'] != '/storage' or registry['redis']['addr'] != 'redis:6379':
        raise ValueError('Unexpected registry storage or cache endpoint')
    registry['http']['secret'] = value('registry_http_secret')
    registry['redis']['password'] = redis_password
    registry['storage']['maintenance']['readonly'] = {'enabled': not write_enabled}
    registry['storage']['maintenance']['uploadpurging']['enabled'] = False
    # Retention/GC is enabled only after its own policy and backup acceptance.
    registry['storage']['delete']['enabled'] = False
    output['config/registry/config.yml'] = yaml.safe_dump(registry, sort_keys=False).encode()
    output['config/registry/passwd'] = preserved['registry_htpasswd']
    jobs = yaml.safe_load(output['config/jobservice/config.yml'])
    pool = jobs['worker_pool']['redis_pool']
    pool['redis_url'] = redis_url(pool['redis_url'], redis_password)
    output['config/jobservice/config.yml'] = yaml.safe_dump(jobs, sort_keys=False).encode()
    # Mountpoint must exist inside the read-only parent configuration bind.
    output['config/registry/root.crt'] = preserved['token_cert']
    output['signing/root.crt'] = preserved['token_cert']
    output['signing/private_key.pem'] = preserved['token_key']
    output['signing/secretkey'] = preserved['core_key']
    output['tls/server.crt'] = tls['certificate']
    output['tls/server.key'] = tls['key']
    output['ca-download/ca.crt'] = tls['ca']
    output['config/shared/trust-certificates/sunmoon-root-ca.crt'] = tls['ca']
    output['redis.conf'] = ('bind 0.0.0.0\nprotected-mode yes\ndir /data\nsave ""\n'
        'appendonly yes\nappendfsync everysec\nrequirepass ' + json.dumps(redis_password) + '\n').encode()
    pg = {'postgresql.conf': "listen_addresses = '*'\nunix_socket_directories = '/tmp'\nhba_file = '/sunmoon-config/pg_hba.conf'\nident_file = '/sunmoon-config/pg_ident.conf'\nshared_preload_libraries = 'pgaudit'\nlogging_collector = off\nmax_connections = 100\n",
          'pg_hba.conf': 'local all postgres trust\nhost registry postgres 0.0.0.0/0 md5\n',
          'pg_ident.conf': '', 'passwd': 'postgres:x:1001:1001:PostgreSQL:/tmp:/bin/false\n',
          'group': 'postgres:x:1001:\n'}
    output.update({'pg-config/' + name: raw.encode() for name, raw in pg.items()})
    nginx = output['config/nginx/nginx.conf'].decode()
    if 'ssl_certificate /etc/cert/server.crt;' not in nginx or 'ssl_certificate_key /etc/cert/server.key;' not in nginx:
        raise ValueError('Official nginx TLS paths differ from the admitted leaf mounts')
    return output


def file_permissions(name):
    # Return owner/group/mode, applied only to a NEW installation by the installer.
    if name.startswith('pg-config/') or name == 'redis.conf':
        return 1001, 1001, 0o400
    return 10000, 10000, 0o400 if name.startswith(('signing/', 'tls/')) else 0o640
