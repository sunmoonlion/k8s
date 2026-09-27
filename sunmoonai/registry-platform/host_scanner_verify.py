#!/usr/bin/env python3
"""Register managed official Trivy, scan one image and verify restart persistence.

Default plan only. Bounded local candidate metadata writes, logical backup,
registry layers stay read-only. Stops/retains all services. No old Harbor writes,
public cutover, token rotation, image patching or cleanup. Cloud 未经实机验证.
"""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import time

from host_prepare import docker, load, write
from host_runtime import Instance, save
from host_verify import client
from runtime_inspect import read
from scanner_adapter_verify import request, DIGEST, REPOSITORY, REPORT_MEDIA
from scanner_jobservice_verify import preflight

NAME = 'sunmoon-trivy'
URL = 'http://trivy:8080'


def ready(instance, credentials):
    deadline = time.monotonic() + 180
    while True:
        try:
            c = client(instance, credentials, time.monotonic() + 900)
            config, _ = c.get('/configurations')
            if config['read_only']['value'] is not True:
                raise ValueError('Read-only candidate required')
            return c
        except Exception:
            if time.monotonic() >= deadline:
                raise ValueError('Candidate readiness deadline') from None
            time.sleep(2)


def baseline(instance, c):
    result = preflight(instance, c)
    if (result['retention_project_count'] or result['preheat_policy_count'] or result['enabled_webhook_count']
            or any(v['trigger'].get('type') != 'manual' for v in result['replication_triggers'])
            or len(result['schedules']) != 2
            or {v['vendor_type'] for v in result['schedules']} != {'SYSTEM_ARTIFACT_CLEANUP', 'EXECUTION_SWEEP'}
            or any(v['cron'] != '0 0 0 * * *' for v in result['schedules'])
            or dt.datetime.now(dt.timezone.utc).hour in (0, 23)):
        raise ValueError('Candidate scheduled-task baseline requires review')
    for role in ('core',):
        if docker('exec', instance.inspect(role)['Id'], 'date', '+%z').strip() != b'+0000':
            raise ValueError('UTC scheduling required')
    for role in ('registry', 'registryctl'):
        if not any(m['Destination'] == '/storage' and not m['RW'] for m in instance.inspect(role)['Mounts']):
            raise ValueError('Registry storage must stay physically read-only')
    for role in ('db', 'java-db'):
        meta = json.loads(read(instance.root / 'scanner/cache' / role / 'metadata.json'))
        updated = dt.datetime.fromisoformat(meta['UpdatedAt'].replace('Z', '+00:00'))
        age = (dt.datetime.now(dt.timezone.utc) - updated).total_seconds()
        if not -600 <= age <= (48 if role == 'db' else 168) * 3600:
            raise ValueError('Scanner database stale; prepare a fresh offline batch')
    return result


def registration(c):
    rows = c.pages('/scanners')
    if len(rows) != 1 or rows[0].get('name') != NAME or rows[0].get('url') != URL or rows[0].get('disabled'):
        raise ValueError('Managed scanner registration differs')
    uid = rows[0]['uuid']
    if not re.fullmatch(r'[a-fA-F0-9-]{36}', uid) or rows[0].get('is_default') is not True:
        raise ValueError('Managed default scanner identity differs')
    projects = c.pages('/projects')
    for project in projects:
        selected, _ = c.get('/projects/' + str(int(project['project_id'])) + '/scanner')
        if selected.get('uuid') != uid:
            raise ValueError('Project scanner mapping differs')
    return uid, len(projects)


def verify(instance, credentials, resume=False, existing_registration=False):
    if existing_registration and (not instance.prep.get('restored_from') or instance.state.get('scanner_acceptance')):
        raise ValueError('Existing-registration verification requires a fresh restored instance')
    target = instance.root / ('scanner/recovery-verification-v1' if existing_registration else
                              'scanner/registration-v2' if resume else 'scanner/registration-v1')
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,62}', NAME):
        raise ValueError('Scanner machine name must not contain whitespace or commas')
    previous_attempt = None
    if resume:
        previous_attempt = json.loads(read(instance.root / 'scanner/registration-v1/result.json'))
        if previous_attempt.get('passed') or previous_attempt.get('metadata_read_only_restored') is not True:
            raise ValueError('Resume requires the stopped, read-only first attempt')
    if not instance.prep.get('scanner') or target.exists():
        raise ValueError('Prepared scanner and fresh registration receipt required')
    if any(v not in ('created', 'exited') for v in instance.check().values()):
        raise ValueError('All candidate services must initially be stopped')
    target.mkdir(mode=0o700)
    receipt = {'schema': 1, 'passed': False, 'entry_switched': False, 'registry_writes_enabled': False}
    api_open = False; c = None
    try:
        instance.start(); c = ready(instance, credentials)
        before = baseline(instance, c)
        write(target / 'preflight.json', json.dumps(before).encode())
        if previous_attempt is None and not existing_registration and before['scanner_count']:
            raise ValueError('Expected empty scanner registration baseline; no adoption')
        if previous_attempt is not None:
            existing = c.pages('/scanners')
            if (len(existing) != 1 or existing[0].get('uuid') != previous_attempt['registration_uuid']
                    or existing[0].get('name') != 'Sunmoon Trivy' or existing[0].get('url') != URL):
                raise ValueError('Only our exact failed registration may be renamed')
        if existing_registration:
            restored_uuid, _ = registration(c)
        # Only the installation-owned namespace is admitted; recovery preserves its records.
        rows = [s[len('requirepass '):] for s in read(instance.root / 'redis.conf').decode().splitlines() if s.startswith('requirepass ')]
        ns = instance.prep['scanner']['job_namespace']
        command = ('AUTH ' + json.loads(rows[0]) + '\nSELECT 2\nEVAL "return #redis.call(\'KEYS\',ARGV[1])" 0 {' + ns + '}:*\n').encode()
        queue = docker('exec', '-i', instance.inspect('redis')['Id'], '/opt/bitnami/redis/bin/redis-cli', '--raw', content=command).strip().splitlines()
        if (len(queue) != 3 or queue[:2] != [b'OK', b'OK'] or not queue[2].isdigit()
                or (previous_attempt is None and not existing_registration and queue[2] != b'0')):
            raise ValueError('Managed job namespace not empty or not authenticated; needs review')
        receipt['retained_owned_queue_keys_before'] = int(queue[2])
        dump = docker('exec', instance.inspect('postgresql')['Id'], '/opt/bitnami/postgresql/bin/pg_dump',
                      '-h', '/tmp', '-U', 'postgres', '-Fc', 'registry', timeout=90)
        if not dump.startswith(b'PGDMP'):
            raise ValueError('Logical backup format differs')
        write(target / 'database-before.dump', dump)
        receipt['database_before_sha256'] = hashlib.sha256(dump).hexdigest()
        headers = {'Authorization': 'Basic ' + c.auth, 'Content-Type': 'application/json'}
        instance.state['metadata_acceptance_open'] = str(target); instance.persist(); api_open = True
        status, _ = request(c.client, c.base + '/configurations', 'PUT', {'read_only': False}, headers)
        if status != 200:
            raise ValueError('Candidate metadata write mode failed')
        if existing_registration:
            uid = restored_uuid
            receipt['registration_uuid'] = uid
            receipt['restored_registration_verified'] = True
        else:
            endpoint = '/scanners' if previous_attempt is None else '/scanners/' + previous_attempt['registration_uuid']
            status, _ = request(c.client, c.base + endpoint, 'POST' if previous_attempt is None else 'PUT', {
                'name': NAME, 'description': 'Managed official Trivy; host registry lifecycle', 'url': URL,
                'disabled': False, 'skip_certVerify': False, 'use_internal_addr': False}, headers)
            rows = c.pages('/scanners')
            if status != (201 if previous_attempt is None else 200) or len(rows) != 1 or rows[0].get('name') != NAME or rows[0].get('url') != URL:
                raise ValueError('Scanner creation response differs')
            uid = rows[0]['uuid']
            if not re.fullmatch(r'[a-fA-F0-9-]{36}', uid):
                raise ValueError('Scanner UUID invalid')
            receipt['registration_uuid'] = uid; save(target / 'result.json', receipt)
            status, _ = request(c.client, c.base + '/scanners/' + uid, 'PATCH', {'is_default': True}, headers)
            if status != 200 or registration(c)[0] != uid:
                raise ValueError('Default scanner mapping failed')
        metadata, _ = c.get('/scanners/' + uid + '/metadata')
        write(target / 'metadata.json', json.dumps(metadata).encode())
        if metadata.get('scanner', {}).get('version') != 'v0.72.0':
            raise ValueError('Unexpected managed scanner version')
        job = instance.inspect('scan-jobs')['Id']; docker('start', job)
        deadline = time.monotonic() + 90
        while True:
            try:
                pools, _ = c.get('/jobservice/pools')
                if pools:
                    break
            except Exception:
                pass
            if time.monotonic() > deadline:
                raise ValueError('Managed Jobservice readiness deadline')
            time.sleep(2)
        artifact_path = '/projects/k8s-images/repositories/nginx/artifacts/' + DIGEST
        old, _ = c.get(artifact_path, {'with_scan_overview': 'true'})
        previous = old.get('scan_overview', {}).get(REPORT_MEDIA, {}).get('report_id')
        status, _ = request(c.client, c.base + artifact_path + '/scan', 'POST', None, headers)
        if status != 202:
            raise ValueError('Managed scan not accepted')
        deadline = time.monotonic() + 420
        while True:
            artifact, _ = c.get(artifact_path, {'with_scan_overview': 'true'})
            overview = artifact.get('scan_overview', {}).get(REPORT_MEDIA, {})
            if overview.get('report_id') != previous and overview.get('scan_status') == 'Success':
                break
            if (overview.get('report_id') != previous and overview.get('scan_status') in ('Error', 'Stopped')) or time.monotonic() > deadline:
                raise ValueError('Managed scan failed or exceeded deadline')
            time.sleep(2)
        report, _ = c.get(artifact_path + '/additions/vulnerabilities')
        actual = report.get(REPORT_MEDIA, {})
        if (artifact.get('digest') != DIGEST or actual.get('scanner') != overview.get('scanner')
                or not isinstance(actual.get('vulnerabilities'), list)
                or any(v.get('artifact_digests') != [DIGEST] for v in actual['vulnerabilities'])):
            raise ValueError('Managed report identity differs')
        raw = json.dumps(report, sort_keys=True).encode(); write(target / 'report.json', raw)
        receipt.update(scan_status='Success', report_sha256=hashlib.sha256(raw).hexdigest(),
                       target=REPOSITORY + '@' + DIGEST, report_id=overview['report_id'],
                       vulnerability_occurrences=len(actual['vulnerabilities']))
    finally:
        if api_open:
            try:
                info = instance.inspect('scan-jobs')
                if info['State']['Running']:
                    docker('stop', '--time', '30', info['Id'])
                status, _ = request(c.client, c.base + '/configurations', 'PUT', {'read_only': True}, headers)
                settings, _ = c.get('/configurations')
                if status != 200 or settings['read_only']['value'] is not True:
                    raise ValueError('Candidate read-only restore failed')
                receipt['metadata_read_only_restored'] = True
                instance.state['metadata_acceptance_open'] = False; instance.persist()
            finally:
                instance.stop(); save(target / 'result.json', receipt)
        else:
            instance.stop()
    # Restart Core: manual registration must survive WITH_TRIVY=False startup.
    try:
        instance.start(); c = ready(instance, credentials)
        actual_uid, count = registration(c)
        if actual_uid != receipt['registration_uuid']:
            raise ValueError('Default scanner changed after restart')
        receipt.update(passed=True, projects_verified=count, survives_core_restart=True,
                       permanent_registration=True, original_jobservice_stayed_stopped=True)
        instance.state['scanner_acceptance'] = receipt; instance.persist()
    finally:
        instance.stop(); save(target / 'result.json', receipt)
    return {**receipt, 'all_services_stopped_and_retained': True}


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--docker-credentials', type=Path)
    parser.add_argument('--apply', action='store_true')
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--resume-registration', action='store_true')
    modes.add_argument('--existing-registration', action='store_true', help='Validate preserved scanner after an independent restore')
    args = parser.parse_args(); config = load(args.config.absolute())
    if not args.apply:
        print(json.dumps({'dry_run': True, 'registration_name': NAME, 'url': URL,
                          'registry_storage_read_only': True, 'checks_restart': True, 'entry_switch': False,
                          'existing_registration': args.existing_registration})); return
    if args.docker_credentials is None:
        raise ValueError('Existing owner credential file required')
    descriptor = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(descriptor, 'rb+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps(verify(Instance(config), args.docker_credentials.absolute(), args.resume_registration, args.existing_registration), indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Managed scanner verification stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld')) from None
