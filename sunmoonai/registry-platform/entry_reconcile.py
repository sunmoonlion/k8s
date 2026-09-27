#!/usr/bin/env python3
"""Live GET reconciliation before the separately approved entry maintenance.

Default prints only. Apply starts/stops only the existing readonly host candidate.
No source write freeze, API mutation, data synchronization or public cutover.
Private snapshots are retained; a passing live observation is not a frozen gate.
"""
import argparse
import copy
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import stat
import time

import entry_handoff
from host_backup import read_manifest
from host_identity_verify import collect as identities
from host_prepare import directory, load
from host_runtime import Instance, save
from host_verify import artifact_records, catalog_identity, client
from runtime_inspect import read

HERE = Path(__file__).resolve().parent
CONFIG = HERE / 'config/harbor-main-local.json'
BACKUP = Path('/var/backups/sunmoon-harbor/host-managed-20260927-v1')
CANARIES = {'migration-canary-20260927', 'migration-canary-20260927-v2'}


def equal_catalog(a, b):
    return catalog_identity(a) == catalog_identity(b) and artifact_records(a, True) == artifact_records(b, True)


def subset(catalog, names):
    return {'projects': [p for p in catalog['projects'] if p['name'] in names]}


def policy(c):
    # Capture policy definitions, not volatile execution history. Raw fields may
    # contain private destinations; none are emitted in the public result.
    schedules = c.pages('/schedules')
    return {'replication': c.pages('/replication/policies'),
            'schedules': [{k:r.get(k) for k in ('id','vendor_type','vendor_id','cron')} for r in schedules]}


def canonical(value):
    if isinstance(value, dict):
        return {k:canonical(v) for k,v in sorted(value.items())}
    if isinstance(value, list):
        return sorted([canonical(v) for v in value], key=lambda v:json.dumps(v,sort_keys=True))
    return value


def equal_policy(source, target):
    values = []
    # Harbor v2.13.2 pkg/reg/manager.go constructs ID 0 "Local" from
    # config.InternalCoreURL(). Only these exact reviewed topology endpoints
    # may differ; remote URLs/credentials, triggers and every other field remain.
    for value, endpoint in ((source,'http://sunmoonai-harbor-core:80'),
                            (target,'http://core:8080')):
        value = copy.deepcopy(value)
        for item in value['replication']:
            for side in ('src_registry','dest_registry'):
                registry = item.get(side)
                if registry and registry.get('id') == 0:
                    if (registry.get('type') != 'harbor' or registry.get('name') != 'Local'
                            or registry.get('url') != endpoint):
                        raise ValueError('Local replication endpoint differs from reviewed topology')
                    registry['url'] = '__local_harbor_core__'
        values.append(canonical(value))
    return values[0] == values[1]


def compare(source_catalog, target_catalog, source_identity, target_identity, backup_catalog):
    source_names = {p['name'] for p in source_catalog['projects']}
    target_names = {p['name'] for p in target_catalog['projects']}
    if source_names & CANARIES or target_names - source_names != CANARIES:
        raise ValueError('Project differences extend beyond the two recorded acceptance projects')
    checks = {'original_catalog_equal':equal_catalog(source_catalog, subset(target_catalog, source_names)),
              'candidate_catalog_matches_verified_backup':equal_catalog(target_catalog, backup_catalog)}
    filtered = copy.deepcopy(target_identity)
    filtered['projects'] = {k:v for k,v in filtered['projects'].items() if k in source_names}
    checks['original_identity_settings_equal'] = source_identity == filtered
    ids = []
    for name in sorted(CANARIES):
        project = target_identity['projects'][name]
        if project['metadata'].get('public') != 'false':
            raise ValueError('Acceptance project became public')
        for robot in project['robots']:
            if (robot.get('disable') is not True or robot.get('level') != 'project'
                    or not robot.get('permissions')
                    or any(v.get('namespace') != name or v.get('kind') != 'project' for v in robot['permissions'])):
                raise ValueError('Acceptance robot enabled or extends beyond its project')
            ids.append(robot['id'])
    if sorted(ids) != [6,7,8]:
        raise ValueError('Acceptance robot IDs differ from the retained write receipts')
    checks['acceptance_robots_disabled_and_scoped'] = True
    return checks


def run(credentials, attempt):
    instance = Instance(load(CONFIG))
    if (instance.project != 'sunmoon-harbor-main-20260927' or instance.mode() != 'read-only'
            or any(v not in ('created','exited') for v in instance.check().values())):
        raise ValueError('Stopped readonly main candidate required')
    record = read_manifest(BACKUP / 'backup.json')
    if not record.get('restore_verified') or record.get('source') != instance.project:
        raise ValueError('Independently restored same-source managed backup required')
    baseline = json.loads(read(BACKUP / 'catalog-before.json'))
    root = instance.root / ('entry-reconcile-' + attempt)
    if root.exists() or root.resolve() != root:
        raise ValueError('Fresh private receipt directory required; no overwrite')
    old_before = entry_handoff.inspect()
    directory(root)
    save(root / 'entry-before.json', old_before)
    result = {'schema':1, 'passed':False, 'source_frozen':False, 'source_modified':False,
              'entry_switched':False, 'attempt':attempt, 'started_at':dt.datetime.now(dt.timezone.utc).isoformat()}
    try:
        instance.start()
        end = time.monotonic()+180
        while True:
            try:
                target = client(instance,credentials,time.monotonic()+1200)
                settings,_ = target.get('/configurations')
                if settings['read_only']['value'] is not True:
                    raise ValueError('Candidate must stay readonly')
                break
            except Exception:
                if time.monotonic()>end:
                    raise ValueError('Candidate TLS/API readiness deadline') from None
                time.sleep(2)
        source = copy.copy(target); source.base = 'https://harbor.sunmoonai.com:30443/api/v2.0'
        src = source.collect(); dst = target.collect()
        src_id, dst_id = identities(source), identities(target)
        src_policy, dst_policy = policy(source), policy(target)
        for name,value in [('source-catalog',src),('target-catalog',dst),('source-identity',src_id),
                           ('target-identity',dst_id),('source-policy',src_policy),('target-policy',dst_policy)]:
            save(root / (name+'.json'), value)
        checks = compare(src,dst,src_id,dst_id,baseline)
        checks['policy_definitions_equal_with_expected_local_endpoint_mapping'] = equal_policy(src_policy,dst_policy)
        print('Initial catalog/identity comparison finished; checking source stability',flush=True)
        src_again = source.collect(); ids_again = identities(source); policies_again = policy(source)
        save(root / 'source-catalog-after.json',src_again)
        save(root / 'source-identity-after.json',ids_again)
        save(root / 'source-policy-after.json',policies_again)
        checks['source_observed_stable'] = (equal_catalog(src,src_again) and src_id==ids_again
                                           and canonical(src_policy)==canonical(policies_again))
        old_after = entry_handoff.inspect(); save(root / 'entry-after.json',old_after)
        def node_identity(item):
            return {**item,'mounts':sorted(item['mounts'],key=lambda m:m['Destination'])}
        checks['old_node_identities_unchanged'] = ([node_identity(n) for n in old_before['nodes']]
                                                 == [node_identity(n) for n in old_after['nodes']])
        result.update(checks=checks, passed=all(checks.values()), source_catalog=src['summary'],
                      target_catalog=dst['summary'], source_users=len(src_id['users']),
                      source_system_robots=len(src_id['robots']),
                      source_project_robots=sum(len(p['robots']) for p in src_id['projects'].values()),
                      recorded_extra_projects=sorted(CANARIES), candidate_extra_disabled_robots=3,
                      candidate_five_year_tls_verified=True, source_original_ca_tls_verified=True,
                      local_replication_endpoint_mapping={'from':'http://sunmoonai-harbor-core:80',
                                                          'to':'http://core:8080','registry_id':0},
                      synchronized=False, frozen_cutover_admitted=False,
                      coverage='catalog, selected users/members/settings, system and project robots, replication and schedules',
                      not_verified=['full database equivalence','unchanged password hashes/robot secrets',
                                    'source write freeze','public cutover','business applications'])
        if not result['passed']:
            raise ValueError('Live source/candidate reconciliation differs; private snapshots retained')
    finally:
        try:
            instance.stop()
            result['candidate_stopped'] = True
        finally:
            result['finished_at'] = dt.datetime.now(dt.timezone.utc).isoformat()
            save(root / 'result.json',result)
    return result


def main():
    os.umask(0o077)
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--attempt',default='20260928-v1')
    p.add_argument('--docker-credentials',type=Path)
    p.add_argument('--apply',action='store_true')
    args=p.parse_args()
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,45}',args.attempt):
        raise ValueError('Invalid receipt attempt')
    if not args.apply:
        print(json.dumps({'dry_run':True,'action':'GET source/candidate catalog and identity reconciliation',
                          'candidate_start_stop':True,'source_mutations':False,'cutover':False})); return
    if os.geteuid()!=0 or args.docker_credentials is None:
        raise ValueError('Root and explicit private owner credential file required')
    fd=os.open('/data/harbor/.instance-preparation.lock',os.O_RDWR|os.O_NOFOLLOW)
    with os.fdopen(fd,'rb+') as lock:
        info=os.fstat(fd)
        if info.st_uid!=0 or stat.S_IMODE(info.st_mode)!=0o600:
            raise ValueError('Unsafe lifecycle lock')
        fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
        print(json.dumps(run(args.docker_credentials.absolute(),args.attempt),indent=2))


if __name__=='__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Entry reconciliation stopped: '+(str(error) if isinstance(error,ValueError)
                         else type(error).__name__+'; private diagnostics withheld')) from None
