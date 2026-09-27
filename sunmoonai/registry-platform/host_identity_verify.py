#!/usr/bin/env python3
"""Compare selected identity/authorization settings of old and restored Harbor.

Default prints only. --apply uses GET APIs, starts/stops only the admitted local
read-only candidate. No credentials/permissions changed. Cloud 未经实机验证.
"""
import argparse
import copy
import fcntl
import json
import os
from pathlib import Path
import time

from host_prepare import load, write
from host_runtime import Instance
from host_verify import client

ROOT = Path('/home/zymun/packages-to-be-installed/releases/harbor-identity-20260927-v2')
USER = ('user_id', 'username', 'sysadmin_flag', 'admin_role', 'deleted')
ROBOT = ('id', 'name', 'level', 'disable', 'duration', 'expires_at', 'permissions')
MEMBER = ('id', 'project_id', 'entity_id', 'entity_name', 'entity_type', 'role_id', 'role_name')
SETTINGS = ('auth_mode', 'project_creation_restriction', 'self_registration', 'token_expiration',
            'robot_name_prefix', 'robot_token_duration', 'scan_all_policy', 'with_notary')


def normalize(value):
    if isinstance(value, dict):
        return {k: normalize(v) for k, v in sorted(value.items())}
    if isinstance(value, list):
        return sorted((normalize(v) for v in value), key=lambda v: json.dumps(v, sort_keys=True))
    return value


def selected(rows, fields):
    return normalize([{k: r[k] for k in fields if k in r} for r in rows])


def collect(c):
    user, _ = c.get('/users/current')
    if user.get('sysadmin_flag') is not True:
        raise ValueError('Existing system administrator required for full visibility')
    config, _ = c.get('/configurations')
    result = {'users': selected(c.pages('/users'), USER),
              'robots': selected(c.pages('/robots'), ROBOT),
              # scan_all_policy is a direct object in Harbor's ConfigurationsResponse;
              # other selected settings are typed ConfigItems with value/editable.
              'settings': {k: (config[k] if k == 'scan_all_policy' else config[k]['value'])
                           for k in SETTINGS if k in config}, 'projects': {}}
    for project in c.pages('/projects'):
        identity = str(int(project['project_id']))
        metadata, _ = c.get('/projects/' + identity + '/metadatas/')
        members = c.pages('/projects/' + identity + '/members')
        result['projects'][project['name']] = {
            'id': project['project_id'], 'owner_id': project.get('owner_id'),
            'metadata': metadata, 'members': selected(members, MEMBER),
            # Harbor 2.13.2 ListRobot defaults to system accounts. Project
            # accounts require both case-sensitive query keys below.
            'robots': selected(c.pages('/robots', {'q': 'Level=project,ProjectID=' + identity}), ROBOT)}
    return normalize(result)


def verify(instance, credentials):
    if ROOT.exists() or ROOT.resolve() != ROOT or any(v not in ('created', 'exited') for v in instance.check().values()):
        raise ValueError('Fresh result directory and stopped candidate required')
    ROOT.mkdir(mode=0o700)
    result = None
    try:
        instance.start()
        ready = time.monotonic() + 180
        while True:
            try:
                target = client(instance, credentials, time.monotonic() + 600)
                config, _ = target.get('/configurations')
                if config['read_only']['value'] is not True:
                    raise ValueError('Candidate is not read-only')
                break
            except Exception:
                if time.monotonic() >= ready:
                    raise ValueError('Candidate TLS/API readiness deadline') from None
                time.sleep(2)
        # The same verified hostname/CA/auth is used at the old local entry;
        # only the known port changes. Both use GET, no credential refresh.
        source = copy.copy(target)
        source.base = 'https://harbor.sunmoonai.com:30443/api/v2.0'
        before = collect(source); after = collect(target)
        write(ROOT / 'source.json', json.dumps(before, sort_keys=True).encode())
        write(ROOT / 'target.json', json.dumps(after, sort_keys=True).encode())
        differences = [key for key in sorted(before.keys() | after.keys()) if before.get(key) != after.get(key)]
        result = {'schema': 1, 'identity_settings_equal': not differences, 'different_sections': differences,
                  'source_counts': {'users': len(before['users']), 'robots': len(before['robots']),
                                    'projects': len(before['projects']),
                                    'project_members': sum(len(p['members']) for p in before['projects'].values())},
                  'target_counts': {'users': len(after['users']), 'robots': len(after['robots']),
                                    'projects': len(after['projects']),
                                    'project_members': sum(len(p['members']) for p in after['projects'].values())},
                  'compared_fields': {'users': USER, 'robots': ROBOT, 'project_members': MEMBER, 'settings': SETTINGS},
                  'existing_admin_auth_verified_at_both': True,
                  'robot_token_auth_verified': False, 'ordinary_user_login_verified': False,
                  'scanner_registration_included': False, 'credentials_changed': False,
                  'entry_switched': False, 'push_verified': False,
                  'consistency': 'Live GET comparison; source is not write-frozen'}
    finally:
        instance.stop()
    result['candidate_stopped_and_retained'] = True
    write(ROOT / 'result.json', (json.dumps(result, indent=2) + '\n').encode())
    if differences:
        raise ValueError('Identity settings differ; see private snapshots and public section counts')
    return result


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--docker-credentials', type=Path)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(); config = load(args.config.absolute())
    if not args.apply:
        print(json.dumps({'dry_run': True, 'deployment': config['runtime']['deployment'],
                          'action': 'GET users, robots, project members/metadata and selected configurations',
                          'changes_credentials': False, 'starts_jobservice': False})); return
    if args.docker_credentials is None or config['runtime']['deployment'] != 'sunmoon-harbor-main-20260927':
        raise ValueError('Explicit owner credentials and local candidate required')
    descriptor = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(descriptor, 'rb+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps(verify(Instance(config), args.docker_credentials.absolute()), indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Identity verification stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld')) from None
