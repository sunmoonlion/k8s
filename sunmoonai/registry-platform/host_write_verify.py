#!/usr/bin/env python3
"""Bounded candidate registry push/pull acceptance; default plan only.

Uses separate retained write containers and a private canary project. Never
changes the original Compose/configs, old Harbor, DNS, port30443 or KIND.
Restores API read-only, disables the temporary robot and stops all candidates.
Cloud 未经实机验证. This is acceptance, not permanent write promotion.
"""
import argparse
import base64
import fcntl
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import tarfile
import time
import urllib.error
import urllib.parse as url
import urllib.request as http

from host_prepare import docker, load, storage, write
from host_runtime import Instance, save
from host_verify import artifact_records, catalog_identity, client
from host_scanner_verify import baseline, ready
from runtime_inspect import read
from runtime_config import OWNER

PROJECT = 'migration-canary-20260927'
REPO = PROJECT + '/transport-v1'
TAG = 'acceptance-v1'
BASE = 'https://harbor.sunmoonai.com:18443'
ROLES = ('registry', 'registryctl', 'core')
ATTEMPT = 'v1'


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def exchange(c, path, method='GET', raw=None, headers=None):
    # All requests, including token and upload Location, stay on the candidate.
    if not path.startswith('/') or path.startswith('//'):
        raise ValueError('Only explicit candidate paths allowed')
    endpoint = url.urlsplit(c.base)
    if (endpoint.scheme != 'https' or endpoint.hostname != 'harbor.sunmoonai.com'
            or endpoint.port not in (18443,30443) or endpoint.path != '/api/v2.0'
            or endpoint.query or endpoint.fragment or endpoint.username or endpoint.password):
        raise ValueError('Unexpected configured registry API target')
    req = http.Request(c.base.removesuffix('/api/v2.0') + path, data=raw, method=method, headers=headers or {})
    try:
        response = c.client.open(req, timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        body = response.read(2 * 1024**2 + 1)
        if len(body) > 2 * 1024**2:
            raise ValueError('Acceptance response exceeds limit')
        return response.code, response.headers, body


def api(c, path, method='GET', value=None, expected=200):
    status, _, body = exchange(c, '/api/v2.0' + path, method,
        None if value is None else json.dumps(value).encode(),
        {'Authorization': 'Basic ' + c.auth, 'Content-Type': 'application/json'})
    if status != expected:
        raise ValueError('Candidate API status differs: ' + str(status) + ' ' + method + ' ' + path)
    return json.loads(body) if body else None


def token(c, auth, repository, actions):
    status, headers, _ = exchange(c, '/v2/' + repository + '/manifests/' + TAG)
    challenge = dict(re.findall(r'(\w+)="([^"]+)"', headers.get('WWW-Authenticate', '')))
    if (status != 401 or challenge.get('realm') != 'https://harbor.sunmoonai.com:30443/service/token'
            or challenge.get('service') != 'harbor-registry'):
        raise ValueError('Private registry challenge differs')
    status, _, raw = exchange(c, '/service/token?' + url.urlencode({
        'service': 'harbor-registry', 'scope': 'repository:' + repository + ':' + actions}),
        headers={'Authorization': 'Basic ' + auth})
    if status != 200:
        raise ValueError('Candidate scoped token request failed: ' + str(status))
    value = json.loads(raw).get('token')
    if not isinstance(value, str) or not value:
        raise ValueError('Scoped token missing')
    return {'Authorization': 'Bearer ' + value}


def upload_path(location):
    parsed = url.urlsplit(location)
    if ((parsed.scheme, parsed.netloc) not in (('', ''), ('https', 'harbor.sunmoonai.com:30443'),
            ('https', 'harbor.sunmoonai.com:18443')) or parsed.fragment
            or not parsed.path.startswith('/v2/' + REPO + '/blobs/uploads/')):
        raise ValueError('Upload Location escaped candidate repository')
    return parsed.path + ('?' + parsed.query if parsed.query else '')


def transport(c, auth, pull_auth):
    headers = token(c, auth, REPO, 'pull,push')
    stream = io.BytesIO()
    content = b'Sunmoon host registry migration transport acceptance\n'
    with tarfile.open(fileobj=stream, mode='w', format=tarfile.USTAR_FORMAT) as archive:
        info = tarfile.TarInfo('sunmoon-canary.txt'); info.size = len(content); info.mode = 0o444
        archive.addfile(info, io.BytesIO(content))
    tar = stream.getvalue(); layer = gzip.compress(tar, mtime=0)
    config = json.dumps({'architecture': 'amd64', 'os': 'linux', 'config': {},
        'rootfs': {'type': 'layers', 'diff_ids': [digest(tar)]},
        'history': [{'created_by': 'sunmoon registry transport acceptance'}]}, separators=(',', ':')).encode()
    manifest = json.dumps({'schemaVersion': 2, 'mediaType': 'application/vnd.oci.image.manifest.v1+json',
        'config': {'mediaType': 'application/vnd.oci.image.config.v1+json', 'size': len(config), 'digest': digest(config)},
        'layers': [{'mediaType': 'application/vnd.oci.image.layer.v1.tar+gzip', 'size': len(layer), 'digest': digest(layer)}]},
        separators=(',', ':')).encode()
    for blob in (config, layer):
        status, response, _ = exchange(c, '/v2/' + REPO + '/blobs/uploads/', 'POST', b'', headers)
        if status != 202:
            raise ValueError('Blob upload initialization failed: ' + str(status))
        path = upload_path(response.get('Location', ''))
        path += ('&' if '?' in path else '?') + url.urlencode({'digest': digest(blob)})
        status, response, _ = exchange(c, path, 'PUT', blob, {**headers, 'Content-Type': 'application/octet-stream'})
        if status != 201 or response.get('Docker-Content-Digest') != digest(blob):
            raise ValueError('Blob commit status/digest differs: ' + str(status))
    media = 'application/vnd.oci.image.manifest.v1+json'
    status, response, _ = exchange(c, '/v2/' + REPO + '/manifests/' + TAG, 'PUT', manifest,
                                  {**headers, 'Content-Type': media})
    if status != 201 or response.get('Docker-Content-Digest') != digest(manifest):
        raise ValueError('Manifest push status/digest differs: ' + str(status))
    pulls = token(c, pull_auth, REPO, 'pull')
    for path, original, accept in [('manifests/' + digest(manifest), manifest, media),
                                  ('blobs/' + digest(config), config, 'application/octet-stream'),
                                  ('blobs/' + digest(layer), layer, 'application/octet-stream')]:
        status, _, raw = exchange(c, '/v2/' + REPO + '/' + path, headers={**pulls, 'Accept': accept})
        if status != 200 or raw != original:
            raise ValueError('Authenticated pull bytes differ: ' + str(status))
    status, _, _ = exchange(c, '/v2/' + REPO + '/manifests/' + digest(manifest), headers={'Accept': media})
    if status != 401:
        raise ValueError('Private canary unexpectedly allowed anonymous pull')
    # A robot granted only pull cannot upload. Harbor2.13.2 derives actions
    # from account grants, so requesting scope=pull with a writer is not narrowing.
    status, _, _ = exchange(c, '/v2/' + REPO + '/blobs/uploads/', 'POST', b'', pulls)
    if status not in (401, 403):
        raise ValueError('Pull-only robot upload expected401/403, actual ' + str(status))
    return {'reference': 'harbor.sunmoonai.com:30443/' + REPO + '@' + digest(manifest),
            'manifest_digest': digest(manifest), 'layer_digest': digest(layer),
            'config_digest': digest(config), 'pushed_bytes': len(config) + len(layer) + len(manifest),
            'all_pulled_bytes_equal': True, 'anonymous_pull_denied': True, 'pull_only_robot_push_denied': True}


def prepare(instance, target):
    from writer_config import prepare as render_writer
    return render_writer(instance, target, instance.project + '-write-' + ATTEMPT)


def inspect(instance, project, role, service):
    obj = json.loads(docker('inspect', project + '-' + role))[0]
    host = obj['HostConfig']; labels = obj['Config'].get('Labels') or {}
    mounts = {m['Destination'].rstrip('/'): (m['Type'], m['Source'], m['RW']) for m in obj['Mounts'] if m['Type'] != 'tmpfs'}
    expected = {m['target'].rstrip('/'): ('bind', m['source'], not m.get('read_only', False)) for m in service['volumes']}
    actual_env = dict(s.split('=', 1) for s in obj['Config']['Env'] if '=' in s)
    if (obj['Image'] != instance.prep['images'][role]['id'] or labels.get(OWNER) != instance.project
            or labels.get('com.docker.compose.project') != project or labels.get('sunmoonai.registry.role') != role
            or host['Privileged'] or host['RestartPolicy']['Name'] != 'no' or host.get('PortBindings')
            or host['ReadonlyRootfs'] != service.get('read_only', False)
            or set(host.get('CapDrop') or []) != set(service.get('cap_drop') or [])
            or {v.removeprefix('CAP_') for v in (host.get('CapAdd') or [])}
            != {v.removeprefix('CAP_') for v in (service.get('cap_add') or [])}
            or mounts != expected or set(obj['NetworkSettings']['Networks']) != {instance.project + '-backend'}
            or any(actual_env.get(k) != str(v) for k, v in service.get('environment', {}).items())):
        raise ValueError('Write candidate identity/binds/ports/environment differs: ' + role)
    return obj


def verify(instance, credentials, backup):
    storage(instance.config, minimum_gib=20)
    if (instance.mode() != 'read-only' or not instance.state.get('scanner_acceptance', {}).get('passed')
            or instance.state.get('write_acceptance_open')
            or any(v not in ('created', 'exited') for v in instance.check().values())):
        raise ValueError('Stopped accepted candidate required; interrupted write windows need review')
    from host_backup import backup_path, read_manifest
    backup = backup_path(backup)
    record = read_manifest(backup / 'backup.json')
    if (record.get('complete') is not True or record.get('source') != instance.project
            or record.get('storage_uuid') != instance.config['storage_uuid']):
        raise ValueError('Completed same-instance cold backup required')
    target = instance.root / ('write-acceptance-' + ATTEMPT)
    if target.exists():
        raise ValueError('Prior write acceptance retained; no automatic retry or overwrite')
    project, args, spec = prepare(instance, target)
    result = {'schema': 1, 'passed': False, 'entry_switched': False, 'original_configs_unchanged': False,
              'robot_disabled': False, 'read_only_restored': False, 'containers_stopped': False}
    c = None; robots = []; created = False; armed = False
    try:
        instance.start(); c = ready(instance, credentials); baseline(instance, c)
        before = c.collect(); write(target / 'catalog-before.json', json.dumps(before).encode())
        if any(p['name'] == PROJECT for p in before['projects']):
            raise ValueError('Canary project already exists; no adoption')
        dump = docker('exec', instance.inspect('postgresql')['Id'], '/opt/bitnami/postgresql/bin/pg_dump',
                      '-h', '/tmp', '-U', 'postgres', '-Fc', 'registry', timeout=90)
        if not dump.startswith(b'PGDMP'):
            raise ValueError('Pre-write database logical export invalid')
        write(target / 'database-before.dump', dump)
        result['database_before_sha256'] = hashlib.sha256(dump).hexdigest()
        instance.state['write_acceptance_open'] = str(target); instance.persist(); armed = True
        # Original containers remain intact; only PG/Redis remain running.
        for role in ('trivy','registry-route','proxy','portal','core','registryctl','registry'):
            obj = instance.inspect(role)
            if obj['State']['Running']:
                docker('stop', '--time', '45', obj['Id'], timeout=60)
        created = True  # also stop partial Compose creation after a failure
        docker(*args, 'create', '--no-recreate', '--pull', 'never', '--no-build', timeout=120)
        for role in ROLES:
            obj = inspect(instance, project, role, spec['services'][role])
            if obj['State']['Running']:
                raise ValueError('Candidate was unexpectedly started during creation')
            result.setdefault('container_ids', {})[role] = obj['Id']
            save(target / 'result.json', result)
        for role in ROLES:
            docker('start', inspect(instance, project, role, spec['services'][role])['Id'])
        for role in ('portal','proxy'):
            docker('start', instance.inspect(role)['Id'])
        deadline = time.monotonic() + 180
        while True:
            try:
                c = client(instance, credentials, time.monotonic() + 900)
                if type(api(c, '/configurations')['read_only']['value']) is not bool:
                    raise ValueError('Candidate read-only flag missing')
                break
            except Exception:
                if time.monotonic() >= deadline:
                    raise ValueError('Write candidate TLS/API readiness deadline') from None
                time.sleep(2)
        api(c, '/configurations', 'PUT', {'read_only': False})
        if api(c, '/configurations')['read_only']['value'] is not False:
            raise ValueError('Candidate API write mode did not open')
        api(c, '/projects', 'POST', {'project_name': PROJECT, 'metadata': {'public': 'false'}}, 201)
        for name, actions in (('writer', ('pull','push')), ('reader', ('pull',))):
            robot = api(c, '/robots', 'POST', {'name': name + '-' + ATTEMPT,
                'description': 'One-day migration acceptance only', 'level': 'project', 'duration': 1,
                'permissions': [{'kind': 'project', 'namespace': PROJECT,
                    'access': [{'resource': 'repository', 'action': a, 'effect': 'allow'} for a in actions]}]}, 201)
            robots.append(robot)
            write(target / (name + '-private.json'), json.dumps(robot).encode())
            result['robot_ids'] = [int(r['id']) for r in robots]; save(target / 'result.json', result)
        auths = [base64.b64encode((r['name'] + ':' + r['secret']).encode()).decode() for r in robots]
        result['transport'] = transport(c, *auths)
        deadline = time.monotonic() + 60
        while True:
            after = c.collect()
            canary = [p for p in after['projects'] if p['name'] == PROJECT]
            if canary and any(r['artifacts'] for r in canary[0]['repositories']):
                break
            if time.monotonic() > deadline:
                raise ValueError('Pushed artifact absent from Harbor catalog')
            time.sleep(2)
        after['projects'] = [p for p in after['projects'] if p['name'] != PROJECT]
        if catalog_identity(before) != catalog_identity(after) or artifact_records(before, True) != artifact_records(after, True):
            raise ValueError('Original catalog changed outside canary project')
        result['original_catalog_preserved'] = True
        result['passed'] = True
    finally:
        failures = []
        if c is not None and armed:
            disabled = []
            for robot in robots:
                try:
                    current = api(c, '/robots/' + str(int(robot['id'])))
                    current['disable'] = True
                    api(c, '/robots/' + str(int(robot['id'])), 'PUT', current)
                    disabled.append(api(c, '/robots/' + str(int(robot['id'])))['disable'] is True)
                    if not disabled[-1]:
                        failures.append('robot-disable')
                except Exception:
                    failures.append('robot-disable')
            result['robot_disabled'] = len(disabled) == len(robots) and all(disabled)
            try:
                api(c, '/configurations', 'PUT', {'read_only': True})
                result['read_only_restored'] = api(c, '/configurations')['read_only']['value'] is True
                if not result['read_only_restored']:
                    failures.append('api-read-only')
            except Exception:
                failures.append('api-read-only')
        if created:
            names = set(docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines())
            for role in reversed(ROLES):
                if project + '-' + role not in names:
                    continue
                try:
                    obj = inspect(instance, project, role, spec['services'][role])
                    if obj['State']['Running']:
                        docker('stop', '--time', '45', obj['Id'], timeout=60)
                    if inspect(instance, project, role, spec['services'][role])['State']['Running']:
                        failures.append(role)
                except Exception:
                    failures.append(role)
        try:
            instance.stop(); instance.immutable()
            result['original_configs_unchanged'] = True
        except Exception:
            failures.append('original-stop-or-config')
        result['containers_stopped'] = not any(v not in ('created','exited') for v in instance.check().values()) and not failures
        result['recovery_errors'] = failures
        if not failures and armed:
            instance.state['write_acceptance_open'] = False
            instance.state['write_acceptance'] = {k:v for k,v in result.items() if k != 'container_ids'}
            instance.persist()
        result['passed'] = result['passed'] and not failures
        save(target / 'result.json', result)
        if failures:
            raise ValueError('Write acceptance stopped; private recovery journal retained: ' + ','.join(failures))
    return result


def main():
    global ATTEMPT, PROJECT, REPO, TAG
    os.umask(0o077)
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config', type=Path, required=True)
    p.add_argument('--backup', type=Path, required=True)
    p.add_argument('--docker-credentials', type=Path)
    p.add_argument('--attempt', choices=('v1', 'v2'), default='v1')
    p.add_argument('--apply', action='store_true'); args = p.parse_args()
    ATTEMPT = args.attempt
    if ATTEMPT != 'v1':
        PROJECT += '-' + ATTEMPT
        REPO = PROJECT + '/transport-' + ATTEMPT
        TAG = 'acceptance-' + ATTEMPT
    config = load(args.config.absolute())
    if not args.apply:
        print(json.dumps({'dry_run': True, 'project': PROJECT, 'repository': REPO, 'target_port':18443,
            'temporary_write_containers': list(ROLES), 'robot_days':1, 'restores_read_only':True,
            'retains_all_data_and_containers':True, 'entry_switch':False})); return
    if not args.docker_credentials:
        raise ValueError('Explicit existing owner credential file required')
    fd = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps(verify(Instance(config), args.docker_credentials, args.backup), indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Write acceptance stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld')) from None
