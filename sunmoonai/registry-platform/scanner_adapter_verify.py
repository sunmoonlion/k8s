#!/usr/bin/env python3
"""Local Trivy adapter acceptance against the restored read-only Harbor 2.13.2.

Default is a plan. Uses a fresh cache, internal Docker network, scoped pull token
and preserved CA. Retains stopped containers/evidence. No old registry mutation,
credential rotation, entry cutover, image push or cloud execution. 云上未经实机验证.
"""
import argparse
import fcntl
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import urllib.error
import urllib.parse as url
import urllib.request as http

from host_prepare import docker, load, write
from host_runtime import Instance, save
from host_verify import client
from prepare_scanner_candidate import MANIFEST
from prepare_scanner_db import verify
from recovery_verify import ACCEPT, BASE
from runtime_inspect import read
from scanner_verify import stage_database
from sni_proxy import image_identity, image_record

ROOT = Path('/home/zymun/packages-to-be-installed/releases/trivy-adapter-trial-20260927-v2')
PREFIX = 'sunmoon-trivy-adapter-20260927-v2'
REPOSITORY = 'k8s-images/nginx'
DIGEST = 'sha256:c97ddadf7d610991aded1178ca552543d835f1c4e28284caf46c9f98f66c4a7a'
MEDIA = 'application/vnd.oci.image.manifest.v1+json'
REPORT_MEDIA = 'application/vnd.security.vulnerability.report; version=1.1'


class RejectRedirect(http.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(opener, endpoint, method='GET', body=None, headers=None):
    req = http.Request(endpoint, method=method, data=None if body is None else json.dumps(body).encode(),
                       headers=headers or {})
    try:
        with opener.open(req, timeout=30) as response:
            status, raw = response.status, response.read(64 * 1024**2 + 1)
    except urllib.error.HTTPError as error:
        if error.code == 302:
            return 302, None
        raise ValueError('Adapter acceptance HTTP status ' + str(error.code) + '; response withheld') from None
    if len(raw) > 64 * 1024**2:
        raise ValueError('HTTP response exceeds acceptance bound')
    return status, json.loads(raw) if raw else None


def pull_token(c):
    endpoint = BASE + '/v2/' + REPOSITORY + '/manifests/' + DIGEST
    try:
        with c.client.open(http.Request(endpoint, headers={'Accept': ACCEPT}), timeout=20):
            raise ValueError('Selected private image is anonymously accessible')
    except urllib.error.HTTPError as error:
        if error.code != 401:
            raise ValueError('Private image authentication challenge missing') from None
        challenge = dict(re.findall(r'(\w+)="([^"]+)"', error.headers.get('WWW-Authenticate', '')))
    if (challenge.get('realm') != 'https://harbor.sunmoonai.com:30443/service/token'
            or challenge.get('service') != 'harbor-registry'):
        raise ValueError('Unexpected authentication realm or audience')
    # The canonical realm is routed ONLY to the restored candidate. No DNS or
    # owner Docker configuration changes; no administrator password in scanner.
    endpoint = BASE + '/service/token?' + url.urlencode({
        'service': challenge['service'], 'scope': 'repository:' + REPOSITORY + ':pull'})
    _, token = request(c.client, endpoint, headers={'Authorization': 'Basic ' + c.auth})
    token = token.get('token')
    if not isinstance(token, str) or not token:
        raise ValueError('Scoped pull token absent')
    endpoint = BASE + '/v2/' + REPOSITORY + '/manifests/' + DIGEST
    with c.client.open(http.Request(endpoint, headers={'Accept': ACCEPT, 'Authorization': 'Bearer ' + token}), timeout=20) as response:
        raw = response.read(1024**2)
        if ('sha256:' + hashlib.sha256(raw).hexdigest() != DIGEST
                or response.headers.get('Docker-Content-Digest') != DIGEST
                or json.loads(raw).get('mediaType') != MEDIA):
            raise ValueError('Selected manifest SHA/media type differs')
    return token


def base_args(name, network, memory='256m'):
    return ['create', '--name', name, '--label', 'sunmoonai.registry.scanner-trial=' + PREFIX,
            '--pull', 'never', '--network', network, '--restart', 'no', '--read-only',
            '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges:true',
            '--pids-limit', '256', '--memory', memory, '--cpus', '2',
            '--log-driver', 'local', '--log-opt', 'max-size=10m', '--log-opt', 'max-file=2']


def run(config, credentials, batch, harbor_jobservice=False):
    instance = Instance(config)
    if (config['runtime']['deployment'] != 'sunmoon-harbor-main-20260927'
            or config['runtime']['platform'] != 'wsl' or config['runtime']['write_enabled']
            or os.geteuid() != 0 or ROOT.exists() or ROOT.resolve() != ROOT
            or batch.resolve() != batch or shutil.disk_usage(ROOT.parent).free < 8 * 1024**3):
        raise ValueError('Stopped read-only local candidate, fresh trial and 8 GiB free required')
    if any(state not in ('created', 'exited') for state in instance.check().values()):
        raise ValueError('All candidate containers must initially be stopped')
    network = instance.project + '-backend'
    net = json.loads(docker('network', 'inspect', network))[0]
    if (not net['Internal'] or net['Driver'] != 'bridge'
            or (net.get('Labels') or {}).get('sunmoonai.registry.deployment') != instance.project):
        raise ValueError('Expected owned internal backend network')
    names = docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines()
    if any(PREFIX + suffix in names for suffix in ('-route', '-scanner')):
        raise ValueError('Existing trial containers retained; no overwrite')
    for identity in net.get('Containers', {}):
        info = json.loads(docker('inspect', identity))[0]
        if 'harbor.sunmoonai.com' in (info['NetworkSettings']['Networks'][network].get('Aliases') or []):
            raise ValueError('Canonical registry network alias already owned')
    image = json.loads(docker('image', 'inspect', MANIFEST))[0]
    if (image['Id'] != MANIFEST or image['Architecture'] != 'amd64' or image['Os'] != 'linux'
            or image['Config'].get('User') != 'scanner' or image['Config'].get('Volumes')):
        raise ValueError('Stable scanner image identity/user/implicit volumes differ')
    route_image = image_identity(image_record())
    print('Verifying pinned offline databases before staging', flush=True)
    checked = verify(batch)
    ROOT.mkdir(mode=0o700)
    write(ROOT / 'database-verification.json', json.dumps(checked).encode())
    cache = stage_database(batch, ROOT, 10000, checked)
    write(ROOT / 'ca.crt', read(instance.root / 'ca-download/ca.crt'), mode=0o444)
    # TLS passthrough only inside this backend; scanner token requests cannot
    # accidentally reach old host :30443. No host port or TLS private key.
    nginx = b'''worker_processes 1;
pid /tmp/nginx.pid;
error_log /dev/stderr warn;
events { worker_connections 256; }
stream { server { listen 30443; proxy_connect_timeout 5s; proxy_timeout 600s; proxy_pass proxy:8443; } }
'''
    write(ROOT / 'nginx.conf', nginx, mode=0o444)
    rows = [s[len('requirepass '):] for s in read(instance.root / 'redis.conf').decode().splitlines() if s.startswith('requirepass ')]
    if len(rows) != 1:
        raise ValueError('Candidate Redis authentication configuration missing')
    env = {
        'SCANNER_LOG_LEVEL': 'warn', 'SCANNER_API_SERVER_ADDR': ':8080',
        'SCANNER_API_SERVER_METRICS_ENABLED': 'false',
        'SCANNER_TRIVY_CACHE_DIR': '/cache', 'SCANNER_TRIVY_REPORTS_DIR': '/reports',
        'SCANNER_TRIVY_SKIP_UPDATE': 'true', 'SCANNER_TRIVY_SKIP_JAVA_DB_UPDATE': 'true',
        'SCANNER_TRIVY_OFFLINE_SCAN': 'true', 'SCANNER_TRIVY_INSECURE': 'false',
        'SCANNER_TRIVY_SECURITY_CHECKS': 'vuln', 'SCANNER_TRIVY_IGNORE_UNFIXED': 'false',
        'SCANNER_TRIVY_TIMEOUT': '5m0s', 'TRIVY_SKIP_VERSION_CHECK': 'true',
        'SCANNER_REDIS_URL': 'redis://:' + url.quote(json.loads(rows[0]), safe='') + '@redis:6379/5',
        'SCANNER_STORE_REDIS_NAMESPACE': PREFIX + ':store',
        'SCANNER_JOB_QUEUE_REDIS_NAMESPACE': PREFIX + ':queue',
        'SCANNER_STORE_REDIS_SCAN_JOB_TTL': '1h', 'SCANNER_JOB_QUEUE_WORKER_CONCURRENCY': '1',
        'SSL_CERT_FILE': '/trust/ca.crt', 'SSL_CERT_DIR': '/trust'}
    write(ROOT / 'scanner.env', ''.join(k + '=' + v + '\n' for k, v in env.items()).encode())
    state = {'schema': 1, 'created': {}, 'images': {}, 'completed': False,
             'formal_admission': False, 'harbor_jobservice_verified': False}
    save(ROOT / 'state.json', state)
    result = None
    try:
        instance.start()
        ready = time.monotonic() + 180
        while True:
            try:
                c = client(instance, credentials, time.monotonic() + 900)
                settings, _ = c.get('/configurations')
                if settings['read_only']['value'] is not True:
                    raise ValueError('Candidate API must remain read-only')
                break
            except Exception:
                if time.monotonic() > ready:
                    raise ValueError('Candidate TLS/API readiness deadline') from None
                time.sleep(2)
        args = base_args(PREFIX + '-route', network)
        args += ['--network-alias', 'harbor.sunmoonai.com', '--user', '101:101',
                 '--tmpfs', '/tmp:rw,noexec,nosuid,nodev,size=16m,mode=1777',
                 '--mount', 'type=bind,src=' + str(ROOT / 'nginx.conf') + ',dst=/etc/sunmoon/nginx.conf,readonly',
                 '--entrypoint', 'nginx', route_image, '-c', '/etc/sunmoon/nginx.conf', '-g', 'daemon off;']
        create(state, 'route', args, route_image, network)
        args = base_args(PREFIX + '-scanner', network, '2g')
        args += ['--user', '10000:10000', '--env-file', str(ROOT / 'scanner.env'),
                 '--tmpfs', '/tmp:rw,nosuid,nodev,size=512m,uid=10000,gid=10000,mode=0700',
                 '--tmpfs', '/cache:rw,nosuid,nodev,size=512m,uid=10000,gid=10000,mode=0700',
                 '--tmpfs', '/reports:rw,noexec,nosuid,nodev,size=128m,uid=10000,gid=10000,mode=0700',
                 '--mount', 'type=bind,src=' + str(ROOT / 'ca.crt') + ',dst=/trust/ca.crt,readonly']
        for role in ('db', 'java-db'):
            args += ['--mount', 'type=bind,src=' + str(cache / role) + ',dst=/cache/' + role]
        args += ['--entrypoint', '/home/scanner/bin/scanner-trivy', MANIFEST]
        create(state, 'scanner', args, MANIFEST, network)
        info = json.loads(docker('inspect', state['created']['scanner']))[0]
        address = info['NetworkSettings']['Networks'][network]['IPAddress']
        if not ipaddress.ip_address(address).is_private:
            raise ValueError('Scanner IP must be on the inspected private bridge')
        endpoint = 'http://' + address + ':8080/api/v1'
        opener = http.build_opener(http.ProxyHandler({}), RejectRedirect())
        ready = time.monotonic() + 60
        while True:
            try:
                _, metadata = request(opener, endpoint + '/metadata')
                break
            except Exception:
                if time.monotonic() > ready:
                    raise ValueError('Scanner metadata readiness deadline') from None
                time.sleep(2)
        props = metadata.get('properties', {})
        if not any(v.get('type') == 'vulnerability' and MEDIA in v.get('consumes_mime_types', [])
                   and REPORT_MEDIA in v.get('produces_mime_types', []) for v in metadata.get('capabilities', [])):
            raise ValueError('Adapter vulnerability request/report media types incompatible')
        for name in ('SCANNER_TRIVY_SKIP_UPDATE', 'SCANNER_TRIVY_SKIP_JAVA_DB_UPDATE', 'SCANNER_TRIVY_OFFLINE_SCAN'):
            if props.get('env.' + name) != 'true':
                raise ValueError('Adapter did not enable required offline setting')
        if props.get('env.SCANNER_TRIVY_INSECURE') != 'false':
            raise ValueError('Adapter TLS verification is not enabled')
        write(ROOT / 'metadata.json', json.dumps(metadata).encode())
        token = pull_token(c)
        print('Submitting one authenticated private-image scan through the adapter API', flush=True)
        status, accepted = request(opener, endpoint + '/scan', 'POST', {
            'registry': {'url': 'https://harbor.sunmoonai.com:30443', 'authorization': 'Bearer ' + token},
            'artifact': {'repository': REPOSITORY, 'digest': DIGEST, 'mime_type': MEDIA}},
            {'Content-Type': 'application/vnd.scanner.adapter.scan.request+json; version=1.0'})
        if status != 202 or not re.fullmatch(r'[A-Za-z0-9_-]{1,128}', accepted.get('id', '')):
            raise ValueError('Adapter did not accept a bounded scan identifier')
        state['scan_id'] = accepted['id']; save(ROOT / 'state.json', state)
        deadline = time.monotonic() + 360
        while True:
            status, report = request(opener, endpoint + '/scan/' + state['scan_id'] + '/report',
                                     headers={'Accept': REPORT_MEDIA})
            if status == 200:
                break
            if status != 302 or time.monotonic() > deadline:
                raise ValueError('Adapter report status/deadline failed')
            time.sleep(3)
        if (report.get('artifact', {}).get('digest') != DIGEST
                or report.get('scanner', {}).get('name') != 'Trivy'
                or not isinstance(report.get('vulnerabilities'), list)):
            raise ValueError('Report artifact/scanner/schema differs')
        raw = json.dumps(report, sort_keys=True).encode()
        write(ROOT / 'report.json', raw)
        counts = {}
        for row in report['vulnerabilities']:
            level = row['severity']; counts[level] = counts.get(level, 0) + 1
        result = {'completed': True, 'harbor_core_version': '2.13.2', 'scanner_image': MANIFEST,
                  'scanner': metadata.get('scanner'), 'adapter_version': props.get('org.label-schema.version'),
                  'repository': REPOSITORY, 'digest': DIGEST, 'db_lock_sha256': checked['lock_sha256'],
                  'private_image_anonymous_denied': True, 'tls_verification_enabled': True,
                  'administrator_credential_not_sent_to_scanner': True,
                  'offline_settings_verified': True, 'network_internal': True,
                  'published_ports': [], 'report_sha256': hashlib.sha256(raw).hexdigest(),
                  'vulnerability_occurrences_by_severity': counts,
                  'harbor_jobservice_verified': False, 'formal_admission': False,
                  'entry_switched': False, 'push_verified': False}
        if harbor_jobservice:
            from scanner_jobservice_verify import verify_chain
            result['harbor_chain'] = verify_chain(instance, c, ROOT, PREFIX, request,
                                                  REPOSITORY, DIGEST, REPORT_MEDIA, report,
                                                  lambda: create_jobservice(instance, state, network))
            result['harbor_jobservice_verified'] = result['harbor_chain']['passed']
        state.update(result)
    finally:
        errors = []
        for role in ('jobservice', 'scanner', 'route'):
            identity = state['created'].get(role)
            if identity:
                try:
                    info = json.loads(docker('inspect', identity))[0]
                    if (info['Id'] != identity or info['Image'] != state['images'][role]
                            or (info['Config'].get('Labels') or {}).get('sunmoonai.registry.scanner-trial') != PREFIX):
                        raise ValueError('Trial container identity changed')
                    if info['State']['Running']:
                        docker('stop', '--time', '10', identity)
                    logs = subprocess.run(['docker', '--host', 'unix:///var/run/docker.sock', 'logs', identity],
                                          capture_output=True, timeout=30)
                    write(ROOT / (role + '.log'), logs.stdout + logs.stderr)
                except Exception:
                    errors.append(role)
        try:
            instance.stop()
        except Exception:
            errors.append('harbor')
        state['stop_errors'] = errors; state['stopped_and_retained'] = not errors
        save(ROOT / 'state.json', state)
        if errors:
            raise ValueError('Acceptance shutdown needs inspection: ' + ','.join(errors))
    return {**result, 'stopped_and_retained': True}


def create(state, role, args, image, network):
    identity = docker(*args).decode().strip()
    state['created'][role] = identity; state['images'][role] = image
    save(ROOT / 'state.json', state)
    info = json.loads(docker('inspect', identity))[0]
    host = info['HostConfig']
    if (info['Image'] != image or host['NetworkMode'] != network or host.get('PortBindings')
            or host['Privileged'] or not host['ReadonlyRootfs'] or host['CapDrop'] != ['ALL']
            or host['RestartPolicy']['Name'] != 'no' or any(m['Type'] == 'volume' for m in info['Mounts'])):
        raise ValueError('Trial container isolation differs')
    docker('start', identity)


def create_jobservice(instance, state, network):
    """Use a fresh queue namespace, preserving the prior trial's Redis records."""
    if instance.inspect('jobservice')['State']['Running']:
        raise ValueError('Original candidate Jobservice must stay stopped')
    name = PREFIX + '-jobservice'
    if name in docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines():
        raise ValueError('Trial Jobservice name already exists')
    # The only queue namespace admitted here is this freshly created trial name.
    rows = [s[len('requirepass '):] for s in read(instance.root / 'redis.conf').decode().splitlines() if s.startswith('requirepass ')]
    command = ('AUTH ' + json.loads(rows[0]) + '\nSELECT 2\nEVAL "return #redis.call(\'KEYS\',ARGV[1])" 0 {' + PREFIX + '}:*\n').encode()
    checked = docker('exec', '-i', instance.inspect('redis')['Id'], '/opt/bitnami/redis/bin/redis-cli', '--raw', content=command)
    if checked.strip().splitlines() != [b'OK', b'OK', b'0']:
        raise ValueError('Fresh trial job queue namespace required')
    output = ROOT / 'job-logs'; output.mkdir(mode=0o700); os.chown(output, 10000, 10000)
    image = instance.prep['images']['jobservice']['id']
    spec = json.loads(docker('image', 'inspect', image))[0]
    volumes = {v.rstrip('/') for v in (spec['Config'].get('Volumes') or {})}
    if spec['Config'].get('User') != 'harbor' or volumes - {'/var/log/jobs'}:
        raise ValueError('Jobservice image user/implicit volumes changed')
    args = base_args(name, network, '1g')
    args += ['--network-alias', 'jobservice', '--user', '10000:10000',
             '--env-file', str(instance.root / 'config/jobservice/env'),
             '--env', 'JOB_SERVICE_POOL_REDIS_NAMESPACE=' + PREFIX,
             '--env', 'JOB_SERVICE_POOL_WORKERS=1', '--env', 'SSL_CERT_FILE=/trust/ca.crt',
             '--tmpfs', '/tmp:rw,noexec,nosuid,nodev,size=64m,uid=10000,gid=10000,mode=0700']
    for source, target, ro in ((instance.root / 'config/jobservice/config.yml', '/etc/jobservice/config.yml', True),
                               (ROOT / 'ca.crt', '/trust/ca.crt', True), (output, '/var/log/jobs', False)):
        args += ['--mount', 'type=bind,src=' + str(source) + ',dst=' + target + (',readonly' if ro else '')]
    args += ['--entrypoint', '/harbor/harbor_jobservice', image, '-c', '/etc/jobservice/config.yml']
    create(state, 'jobservice', args, image, network)
    info = json.loads(docker('inspect', state['created']['jobservice']))[0]
    values = dict(v.split('=', 1) for v in info['Config']['Env'])
    if values.get('JOB_SERVICE_POOL_REDIS_NAMESPACE') != PREFIX:
        raise ValueError('Trial Jobservice namespace differs')
    return info['Id']


def main():
    global ROOT, PREFIX
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--batch', type=Path, required=True)
    parser.add_argument('--docker-credentials', type=Path)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--harbor-jobservice', action='store_true',
                        help='Separate trial: bounded candidate metadata writes and owned Jobservice scan')
    args = parser.parse_args(); config = load(args.config.absolute())
    if args.harbor_jobservice:
        ROOT = ROOT.parent / 'trivy-harbor-chain-20260927-v3'
        PREFIX = 'sunmoon-trivy-harbor-chain-20260927-v3'
    if not args.apply:
        print(json.dumps({'dry_run': True, 'root': str(ROOT), 'harbor': config['runtime']['deployment'],
                          'image': MANIFEST, 'target': REPOSITORY + '@' + DIGEST,
                          'auxiliary_containers': 3 if args.harbor_jobservice else 2, 'internal_network_only': True,
                          'jobservice_start': args.harbor_jobservice,
                          'candidate_metadata_writes': args.harbor_jobservice,
                          'registry_storage_stays_read_only': True,
                          'entry_switch': False, 'retains_all_containers': True})); return
    if args.docker_credentials is None:
        raise ValueError('Explicit existing owner credential file required')
    descriptor = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(descriptor, 'rb+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps(run(config, args.docker_credentials.absolute(), args.batch.absolute(), args.harbor_jobservice), indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Scanner adapter acceptance stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld')) from None
