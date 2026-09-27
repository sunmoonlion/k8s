#!/usr/bin/env python3
"""Preflight the isolated Harbor scan chain without starting Jobservice.

Default prints only. GET APIs and Redis DBSIZE only; candidate start/stop uses the
owned lifecycle. No changes to registry data, accounts or old Harbor. 云上未经实机验证.
"""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
import re
from pathlib import Path
import time
from urllib.parse import urlsplit, unquote

import yaml

from host_prepare import docker, load, write
from host_runtime import Instance
from host_verify import client
from runtime_inspect import read


def preflight(instance, c):
    settings, _ = c.get('/configurations')
    if settings['read_only']['value'] is not True or instance.inspect('jobservice')['State']['Running']:
        raise ValueError('Preflight requires read-only API and stopped Jobservice')
    schedules = c.pages('/schedules')
    replication = c.pages('/replication/policies')
    scanners = c.pages('/scanners')
    projects = c.pages('/projects')
    retention = 0; preheat = 0; webhooks = 0
    for project in projects:
        identity = str(int(project['project_id']))
        meta, _ = c.get('/projects/' + identity + '/metadatas/')
        if meta.get('retention_id'):
            retention += 1
        preheat += len(c.pages('/projects/' + project['name'] + '/preheat/policies'))
        policies = c.pages('/projects/' + identity + '/webhook/policies')
        if not isinstance(policies, list):
            raise ValueError('Unexpected webhook policy list schema')
        webhooks += sum(v.get('enabled', False) for v in policies)
    jobs = yaml.safe_load(read(instance.root / 'config/jobservice/config.yml'))
    parsed = urlsplit(jobs['worker_pool']['redis_pool']['redis_url'])
    if (parsed.scheme != 'redis' or parsed.hostname != 'redis' or parsed.port != 6379
            or parsed.path not in ('/1', '/2') or not parsed.password):
        raise ValueError('Unexpected candidate job queue Redis endpoint')
    command = ('AUTH ' + unquote(parsed.password) + '\nSELECT ' + parsed.path[1:] + '\nDBSIZE\n').encode()
    rows = docker('exec', '-i', instance.inspect('redis')['Id'], '/opt/bitnami/redis/bin/redis-cli', '--raw',
                  content=command).strip().splitlines()
    if len(rows) != 3 or rows[:2] != [b'OK', b'OK'] or not rows[2].isdigit():
        raise ValueError('Candidate queue DB count could not be authenticated')
    result = {'schema': 1, 'deployment': instance.project, 'read_only': True,
              'schedule_count': len(schedules), 'replication_policy_count': len(replication),
              'schedules': [{k: v.get(k) for k in ('id', 'vendor_type', 'vendor_id', 'cron')} for v in schedules],
              'replication_triggers': [{'id': v.get('id'), 'enabled': v.get('enabled'),
                                       'trigger': v.get('trigger'), 'replicate_deletion': v.get('replicate_deletion')}
                                      for v in replication],
              'retention_project_count': retention, 'preheat_policy_count': preheat,
              'enabled_webhook_count': webhooks, 'scanner_count': len(scanners),
              'jobservice_redis_db': int(parsed.path[1:]), 'jobservice_redis_key_count': int(rows[2]),
              'jobservice_started': False,
              'old_tasks_absent': not (schedules or replication or retention or preheat or webhooks or int(rows[2])),
              'core_startup_system_jobs_review_required': True,
              'harbor_jobservice_verified': False}
    return result


def verify_chain(instance, c, root, prefix, request, repository, digest, report_media, adapter_report, create_jobservice):
    """Write scan metadata only in the candidate; registry remains physically RO.

    Jobservice and API write mode are restored in finally; an interrupted window
    leaves a persistent flag that blocks ordinary instance startup for review.
    """
    before = preflight(instance, c)
    write(root / 'harbor-preflight.json', json.dumps(before).encode())
    allowed = {'SYSTEM_ARTIFACT_CLEANUP', 'EXECUTION_SWEEP'}
    if (before['scanner_count'] or before['jobservice_redis_db'] != 2
            or before['retention_project_count'] or before['preheat_policy_count'] or before['enabled_webhook_count']
            or any(v['trigger'].get('type') != 'manual' for v in before['replication_triggers'])
            or len(before['schedules']) != 2
            or {v['vendor_type'] for v in before['schedules']} != allowed
            or any(v['cron'] != '0 0 0 * * *' for v in before['schedules'])):
        raise ValueError('Candidate task baseline differs; no Jobservice start or config mutation')
    # Both preserved system schedules run at midnight; keep this bounded trial
    # away from that window and require UTC in both actual service processes.
    if dt.datetime.now(dt.timezone.utc).hour in (0, 23):
        raise ValueError('Scan acceptance must be outside UTC midnight scheduling window')
    core = instance.inspect('core')['Id']
    if docker('exec', core, 'date', '+%z').strip() != b'+0000':
        raise ValueError('Candidate Core scheduling timezone is not the admitted UTC')
    for role in ('registry', 'registryctl'):
        spec = instance.inspect(role)
        if not any(m['Destination'] == '/storage' and m['Type'] == 'bind' and not m['RW'] for m in spec['Mounts']):
            raise ValueError('Registry storage must remain physically read-only')
    registry = yaml.safe_load(read(instance.root / 'config/registry/config.yml'))
    if (registry['storage']['maintenance']['readonly']['enabled'] is not True
            or registry['storage']['delete']['enabled'] is not False):
        raise ValueError('Registry read-only/delete controls differ')
    dump = docker('exec', instance.inspect('postgresql')['Id'], '/opt/bitnami/postgresql/bin/pg_dump',
                  '-h', '/tmp', '-U', 'postgres', '-Fc', 'registry', timeout=90)
    if not dump.startswith(b'PGDMP'):
        raise ValueError('Candidate metadata backup did not produce a custom PostgreSQL dump')
    write(root / 'database-before-scan.dump', dump)
    receipt = {'schema': 1, 'passed': False, 'registry_storage_read_only': True,
               'database_before_sha256': hashlib.sha256(dump).hexdigest(),
               'metadata_read_only_restored': False, 'temporary_scanner_removed': False}
    write(root / 'harbor-chain-intent.json', json.dumps(receipt).encode())
    headers = {'Authorization': 'Basic ' + c.auth, 'Content-Type': 'application/json'}
    registration = None; result = None; job_id = None
    instance.state['metadata_acceptance_open'] = str(root); instance.persist()
    try:
        status, _ = request(c.client, c.base + '/configurations', 'PUT', {'read_only': False}, headers)
        settings, _ = c.get('/configurations')
        if status != 200 or settings['read_only']['value'] is not False:
            raise ValueError('Candidate scan metadata could not be enabled')
        payload = {'name': prefix, 'description': 'Isolated migration acceptance; remove after scan',
                   'url': 'http://' + prefix + '-scanner:8080', 'disabled': False,
                   'skip_certVerify': False, 'use_internal_addr': False}
        status, _ = request(c.client, c.base + '/scanners', 'POST', payload, headers)
        rows = c.pages('/scanners')
        if status != 201 or len(rows) != 1 or rows[0].get('name') != prefix or rows[0].get('url') != payload['url']:
            raise ValueError('Candidate scanner registration differs')
        registration = rows[0]['uuid']
        if not re.fullmatch(r'[a-fA-F0-9-]{36}', registration):
            raise ValueError('Invalid scanner registration identity')
        receipt['temporary_registration'] = registration
        write(root / 'harbor-registration.json', json.dumps(receipt).encode())
        status, _ = request(c.client, c.base + '/scanners/' + registration, 'PATCH', {'is_default': True}, headers)
        chosen, _ = c.get('/projects/k8s-images/scanner')
        if status != 200 or chosen.get('uuid') != registration:
            raise ValueError('Candidate project did not select the trial scanner')
        metadata, _ = c.get('/scanners/' + registration + '/metadata')
        write(root / 'harbor-scanner-metadata.json', json.dumps(metadata).encode())
        job_id = create_jobservice()
        if docker('exec', job_id, 'date', '+%z').strip() != b'+0000':
            raise ValueError('Jobservice timezone differs from the admitted UTC')
        ready = time.monotonic() + 90
        while True:
            try:
                pools, _ = c.get('/jobservice/pools')
                if not pools:
                    raise ValueError('No Jobservice pool ready')
                break
            except Exception:
                if time.monotonic() > ready:
                    raise ValueError('Candidate Jobservice readiness deadline') from None
                time.sleep(2)
        artifact_path = '/projects/k8s-images/repositories/nginx/artifacts/' + digest
        print('Submitting scan through Harbor 2.13.2 Core and Jobservice', flush=True)
        status, _ = request(c.client, c.base + artifact_path + '/scan', 'POST', None, headers)
        if status != 202:
            raise ValueError('Harbor did not accept the scan')
        deadline = time.monotonic() + 420
        while True:
            artifact, _ = c.get(artifact_path, {'with_scan_overview': 'true'})
            overview = artifact.get('scan_overview', {}).get(report_media, {})
            if overview.get('scan_status') == 'Success':
                break
            if overview.get('scan_status') in ('Error', 'Stopped') or time.monotonic() > deadline:
                raise ValueError('Harbor scan failed or exceeded deadline')
            time.sleep(3)
        report, _ = c.get(artifact_path + '/additions/vulnerabilities')
        write(root / 'harbor-artifact-observed.json', json.dumps(artifact).encode())
        write(root / 'harbor-report-observed.json', json.dumps(report).encode())
        actual = report.get(report_media, {})
        # Harbor 2.13.2 normalizes the adapter response into pkg/scan/vuln.Report:
        # no top-level artifact member; each finding receives artifact_digests.
        if (artifact.get('digest') != digest or not overview.get('report_id')
                or actual.get('scanner', {}).get('name') != 'Trivy'
                or actual.get('scanner') != overview.get('scanner')
                or not isinstance(actual.get('vulnerabilities'), list)
                or any(v.get('artifact_digests') != [digest] for v in actual['vulnerabilities'])):
            raise ValueError('Harbor persisted scan report identity differs')
        def findings(value):
            return sorted(json.dumps({k: v.get(k) for k in ('id', 'package', 'version', 'fix_version', 'severity')}, sort_keys=True)
                          for v in value['vulnerabilities'])
        if findings(actual) != findings(adapter_report):
            raise ValueError('Harbor report differs from the direct adapter result')
        raw = json.dumps(report, sort_keys=True).encode()
        write(root / 'harbor-report.json', raw)
        result = {'passed': True, 'core_version': '2.13.2', 'jobservice_version': '2.13.2',
                  'scan_status': 'Success', 'same_findings_as_adapter': True,
                  'report_sha256': hashlib.sha256(raw).hexdigest(),
                  'vulnerability_occurrences': len(actual['vulnerabilities']),
                  'database_before_sha256': receipt['database_before_sha256'],
                  'registry_storage_read_only': True, 'permanent_scanner_registration': False,
                  'formal_admission': False}
        receipt.update(result)
    finally:
        errors = []
        try:
            if job_id is not None:
                info = json.loads(docker('inspect', job_id))[0]
                if ((info['Config'].get('Labels') or {}).get('sunmoonai.registry.scanner-trial') != prefix
                        or info['Image'] != instance.prep['images']['jobservice']['id']):
                    raise ValueError('Trial Jobservice identity changed')
                if info['State']['Running']:
                    docker('stop', '--time', '30', job_id)
        except Exception:
            errors.append('jobservice-stop')
        try:
            rows = c.pages('/scanners')
            ours = [v for v in rows if v.get('name') == prefix and v.get('url') == 'http://' + prefix + '-scanner:8080']
            if len(ours) > 1 or (registration is not None and any(v['uuid'] != registration for v in ours)):
                raise ValueError('Temporary scanner identity differs')
            for row in ours:
                if not re.fullmatch(r'[a-fA-F0-9-]{36}', row['uuid']):
                    raise ValueError('Invalid temporary scanner identity')
                request(c.client, c.base + '/scanners/' + row['uuid'], 'DELETE', None, headers)
            if c.pages('/scanners'):
                raise ValueError('Scanner baseline not restored')
            receipt['temporary_scanner_removed'] = True
        except Exception:
            errors.append('scanner-registration')
        try:
            request(c.client, c.base + '/configurations', 'PUT', {'read_only': True}, headers)
            settings, _ = c.get('/configurations')
            if settings['read_only']['value'] is not True:
                raise ValueError('Read-only API was not restored')
            receipt['metadata_read_only_restored'] = True
        except Exception:
            errors.append('read-only-api')
        receipt['cleanup_errors'] = errors
        write(root / 'harbor-chain-result.json', json.dumps(receipt).encode())
        if not errors:
            instance.state['metadata_acceptance_open'] = False; instance.persist()
        if errors:
            raise ValueError('Candidate acceptance requires review: ' + ','.join(errors))
    return {**result, 'temporary_scanner_removed': True, 'metadata_read_only_restored': True}


def main():
    os.umask(0o077)
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config', type=Path, required=True)
    p.add_argument('--docker-credentials', type=Path)
    p.add_argument('--apply', action='store_true')
    args = p.parse_args(); config = load(args.config.absolute())
    if not args.apply:
        print(json.dumps({'dry_run': True, 'deployment': config['runtime']['deployment'],
                          'action': 'GET schedules, policies and scanner registrations; Redis DBSIZE',
                          'starts_jobservice': False, 'entry_switch': False})); return
    if args.docker_credentials is None or config['runtime']['deployment'] != 'sunmoon-harbor-main-20260927':
        raise ValueError('Explicit local acceptance instance and owner credentials required')
    fd = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        instance = Instance(config)
        if any(s not in ('created', 'exited') for s in instance.check().values()):
            raise ValueError('Candidate must initially be stopped')
        try:
            instance.start(); deadline = time.monotonic() + 180
            while True:
                try:
                    c = client(instance, args.docker_credentials.absolute(), deadline + 300)
                    c.get('/configurations'); break
                except Exception:
                    if time.monotonic() > deadline:
                        raise ValueError('Candidate readiness deadline') from None
                    time.sleep(2)
            result = preflight(instance, c)
            write(instance.root / ('scanner-jobservice-preflight-' + str(time.time_ns()) + '.json'), json.dumps(result).encode())
        finally:
            instance.stop()
        print(json.dumps({**result, 'candidate_stopped': True}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Scanner Jobservice preflight stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld')) from None
