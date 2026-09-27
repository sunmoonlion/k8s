#!/usr/bin/env python3
"""Add official scanner services to a stopped, reconciled host Harbor instance.

Default plan only. Shared runtime layout for WSL/cloud; cloud 未经实机验证.
Preserves original configuration and all containers; no registry write enable,
image modification, service startup, registration, public port or cleanup.
"""
import argparse
import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
from urllib.parse import quote

import yaml
from host_prepare import directory, docker, load, storage, write, verify_images
from host_runtime import Instance, save
from prepare_scanner_candidate import MANIFEST, CONFIG
from prepare_scanner_db import verify
from scanner_verify import stage_database
from runtime_config import common, bind
from runtime_inspect import read

ROLES = ('registry-route', 'trivy', 'scan-jobs')


def services(site, images):
    root = Path(site['root']); outputs = {}
    for role in ROLES:
        item = common(role, images[role]['id'], site)
        item.update(user='10000:10000', read_only=True, cap_drop=['ALL'], volumes=[],
                    tmpfs=['/tmp:rw,nosuid,nodev,size=64m,uid=10000,gid=10000,mode=0700'])
        outputs[role] = item
    route = outputs['registry-route']
    route.update(user='101:101', entrypoint=['nginx'],
                 command=['-c', '/etc/sunmoon/nginx.conf', '-g', 'daemon off;'],
                 networks={'harbor': {'aliases': ['harbor.sunmoonai.com']}},
                 tmpfs=['/tmp:rw,noexec,nosuid,nodev,size=16m,uid=101,gid=101,mode=0700'],
                 volumes=[bind(root / 'scanner/route.conf', '/etc/sunmoon/nginx.conf')])
    scanner = outputs['trivy']
    scanner.update(mem_limit='2g', entrypoint=['/home/scanner/bin/scanner-trivy'], command=[],
                   env_file=[{'path': str(root / 'scanner/env'), 'format': 'raw'}],
                   volumes=[bind(root / 'ca-download/ca.crt', '/trust/ca.crt'),
                            bind(root / 'scanner/cache/db', '/cache/db', True),
                            bind(root / 'scanner/cache/java-db', '/cache/java-db', True)],
                   tmpfs=['/tmp:rw,nosuid,nodev,size=512m,uid=10000,gid=10000,mode=0700',
                          '/cache:rw,nosuid,nodev,size=512m,uid=10000,gid=10000,mode=0700',
                          '/reports:rw,noexec,nosuid,nodev,size=128m,uid=10000,gid=10000,mode=0700'],
                   healthcheck={'test': ['CMD', 'curl', '--fail', '--silent', '--show-error',
                                        'http://127.0.0.1:8080/probe/healthy'],
                                'interval': '30s', 'timeout': '5s', 'retries': 3})
    jobs = outputs['scan-jobs']
    jobs.update(entrypoint=['/harbor/harbor_jobservice'], command=['-c', '/etc/jobservice/config.yml'],
                networks={'harbor': {'aliases': ['jobservice']}},
                env_file=[{'path': str(root / 'config/jobservice/env'), 'format': 'raw'}],
                environment={'JOB_SERVICE_POOL_REDIS_NAMESPACE': 'sunmoon_host_jobs_v1',
                             'JOB_SERVICE_POOL_WORKERS': '1', 'SSL_CERT_FILE': '/trust/ca.crt'},
                volumes=[bind(root / 'config/jobservice/config.yml', '/etc/jobservice/config.yml'),
                         bind(root / 'ca-download/ca.crt', '/trust/ca.crt'),
                         bind(root / 'scanner/job-logs', '/var/log/jobs', True)])
    return outputs


def prepare(instance, batch, resume=False):
    storage(instance.config, minimum_gib=24)
    if instance.prep.get('scanner') or (instance.state.get('configuration_transition_open') and not resume):
        raise ValueError('Scanner already prepared or transition needs review; no overwrite')
    if any(v not in ('created', 'exited') for v in instance.check().values()):
        raise ValueError('All owned services must be stopped')
    if not instance.state.get('read_only_acceptance', {}).get('completed'):
        raise ValueError('Reconciled read-only Harbor required')
    checked = verify(batch)
    root = instance.root; target = root / 'scanner'; history = root / 'before-scanner'
    if resume:
        if (instance.state.get('configuration_transition_open') != 'scanner-v1'
                or not target.is_dir() or not history.is_dir()
                or {p.name for p in target.iterdir()} != {'cache', 'job-logs'}
                or any(read(root / n) != read(history / n) for n in ('compose.yaml', 'preparation.json'))):
            raise ValueError('Resume only admits the unchanged pre-activation cache stage')
        for role, record in checked['archives'].items():
            for name, expected in record['members'].items():
                path = target / 'cache' / role / name
                if path.resolve() != path or path.stat().st_size != expected['bytes']:
                    raise ValueError('Retained cache identity differs')
                with path.open('rb') as stream:
                    if hashlib.file_digest(stream, 'sha256').hexdigest() != expected['sha256']:
                        raise ValueError('Retained cache SHA differs')
    elif target.exists() or history.exists():
        raise ValueError('Existing preparation attempt retained')
    scanner = json.loads(docker('image', 'inspect', MANIFEST))[0]
    route_lock = json.loads((Path(__file__).parent / 'sni-image.lock.json').read_bytes())
    route = json.loads(docker('image', 'inspect', route_lock['platform_digest']))[0]
    if (scanner['Id'] != MANIFEST or scanner['Config'].get('User') != 'scanner'
            or scanner['Config'].get('Volumes') or route['Config'].get('Volumes')):
        raise ValueError('Admitted official image identity/volumes differ')
    def record(image, reference):
        return {'id': image['Id'], 'reference': reference, 'volumes': list(image['Config'].get('Volumes') or {}),
                'architecture': image['Architecture'], 'os': image['Os']}
    images = {'trivy': record(scanner, 'ghcr.io/goharbor/trivy-adapter-photon@' + MANIFEST),
              'registry-route': record(route, route_lock['reference']),
              'scan-jobs': copy.deepcopy(instance.prep['images']['jobservice'])}
    verify_images(images)
    names = set(docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines())
    if any(instance.project + '-' + role in names for role in ROLES):
        raise ValueError('Scanner container name collision')
    net = json.loads(docker('network', 'inspect', instance.project + '-backend'))[0]
    if net.get('Containers'):
        raise ValueError('Backend must have no running endpoints while preparing')
    if not resume:
        directory(history)
        for name in ('compose.yaml', 'preparation.json', 'runtime-state.json'):
            write(history / name, read(root / name))
    instance.state['configuration_transition_open'] = 'scanner-v1'; instance.persist()
    if not resume:
        directory(target)
        stage_database(batch, target, 10000, checked)
        directory(target / 'job-logs', 10000, 0o750)
    # This is a public material lock, already SHA-verified; not a private secret input.
    public_lock = (batch / 'scanner-db.lock.json').read_bytes()
    if hashlib.sha256(public_lock).hexdigest() != checked['lock_sha256']:
        raise ValueError('Public DB lock changed after verification')
    write(target / 'db-lock.json', public_lock)
    write(target / 'db-verification.json', json.dumps(checked).encode())
    rows = [v[len('requirepass '):] for v in read(root / 'redis.conf').decode().splitlines() if v.startswith('requirepass ')]
    if len(rows) != 1:
        raise ValueError('Redis authentication configuration ambiguous')
    env = {'SCANNER_LOG_LEVEL': 'warn', 'SCANNER_API_SERVER_ADDR': ':8080',
           'SCANNER_API_SERVER_METRICS_ENABLED': 'false', 'SCANNER_TRIVY_CACHE_DIR': '/cache',
           'SCANNER_TRIVY_REPORTS_DIR': '/reports', 'SCANNER_TRIVY_SKIP_UPDATE': 'true',
           'SCANNER_TRIVY_SKIP_JAVA_DB_UPDATE': 'true', 'SCANNER_TRIVY_OFFLINE_SCAN': 'true',
           'SCANNER_TRIVY_INSECURE': 'false', 'SCANNER_TRIVY_SECURITY_CHECKS': 'vuln',
           'SCANNER_TRIVY_IGNORE_UNFIXED': 'false', 'SCANNER_TRIVY_TIMEOUT': '5m0s',
           'TRIVY_SKIP_VERSION_CHECK': 'true', 'SCANNER_JOB_QUEUE_WORKER_CONCURRENCY': '1',
           'SCANNER_REDIS_URL': 'redis://:' + quote(json.loads(rows[0]), safe='') + '@redis:6379/5',
           'SCANNER_STORE_REDIS_NAMESPACE': 'sunmoon_host_trivy_v1:store',
           'SCANNER_JOB_QUEUE_REDIS_NAMESPACE': 'sunmoon_host_trivy_v1:queue',
           'SCANNER_STORE_REDIS_SCAN_JOB_TTL': '1h', 'SSL_CERT_FILE': '/trust/ca.crt', 'SSL_CERT_DIR': '/trust'}
    write(target / 'env', ''.join(k + '=' + v + '\n' for k, v in env.items()).encode())
    write(target / 'route.conf', b'''worker_processes 1;
pid /tmp/nginx.pid;
error_log /dev/stderr warn;
events { worker_connections 256; }
stream { server { listen 30443; proxy_connect_timeout 5s; proxy_timeout 600s; proxy_pass proxy:8443; } }
''', mode=0o444)
    compose = yaml.safe_load(read(root / 'compose.yaml'))
    compose['services'].update(services(instance.config['runtime'], images))
    write(root / 'compose-with-scanner.new', yaml.safe_dump(compose, sort_keys=False).encode())
    # Parse the exact candidate Compose before activating any configuration.
    docker('compose', '-p', instance.project, '-f', str(root / 'compose-with-scanner.new'),
           '--profile', '*', 'config', '--format', 'json')
    prep = copy.deepcopy(instance.prep); prep['images'].update(images)
    prep['scanner'] = {'schema': 1, 'roles': list(ROLES), 'image_manifest': MANIFEST,
                       'image_config': CONFIG, 'db_lock_sha256': checked['lock_sha256'],
                       'job_namespace': 'sunmoon_host_jobs_v1', 'registry_read_only': True,
                       'official_image_unchanged': True, 'registration_separate_step': True}
    for name in ('scanner/env', 'scanner/route.conf', 'scanner/db-lock.json', 'scanner/db-verification.json'):
        prep['immutable_files'][name] = hashlib.sha256(read(root / name)).hexdigest()
    prep['immutable_files']['compose.yaml'] = hashlib.sha256(read(root / 'compose-with-scanner.new')).hexdigest()
    write(root / 'preparation-with-scanner.new', (json.dumps(prep, indent=2) + '\n').encode())
    os.replace(root / 'compose-with-scanner.new', root / 'compose.yaml')
    os.replace(root / 'preparation-with-scanner.new', root / 'preparation.json')
    instance.prep = prep
    instance.state['creation_complete'] = False
    instance.state['configuration_transition_open'] = False; instance.persist()
    instance.create()  # --no-recreate retains every previously admitted container.
    return {'prepared': True, 'roles': list(ROLES), 'services_started': False,
            'registry_writes_enabled': False, 'entry_switched': False,
            'original_configuration_retained': str(history), 'image_manifest': MANIFEST}


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--batch', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--resume-before-activation', action='store_true')
    args = parser.parse_args(); config = load(args.config.absolute())
    if not args.apply:
        print(json.dumps({'dry_run': True, 'roles': list(ROLES), 'batch': str(args.batch),
                          'image': MANIFEST, 'starts_services': False, 'retains_containers': True})); return
    descriptor = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(descriptor, 'rb+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps(prepare(Instance(config), args.batch.absolute(), args.resume_before_activation), indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Scanner preparation stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld')) from None
