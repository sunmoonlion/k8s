#!/usr/bin/env python3
"""Audit or explicitly reclaim two owner-approved historical registry copies.

Produces a concrete proposal for an owner exception to end-of-migration cleanup.
Default prints only. Apply requires the exact approved audit SHA. Hashes every
candidate file and fully verifies its independently restored backup first.
"""
import argparse
import datetime as dt
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import stat

from host_backup import read_manifest, sha, verify_backup
from host_prepare import docker, directory, write
from host_runtime import save
from rehearsal_retirement import MARKER

BACKUP = Path('/data/harbor/backups/host-main-20260927-v1')
NEW_BACKUP = Path('/var/backups/sunmoon-harbor/host-managed-20260927-v1')
TARGETS = [Path('/data/harbor/candidates/harbor-2.13.2-20260927/recovery/registry'),
           Path('/data/harbor/instances/sunmoon-harbor-backup-20260927/registry')]
JOURNAL = Path('/data/harbor/reclaim-history/registry-copies-20260928-v1')


def audit():
    if os.geteuid() != 0:
        raise ValueError('Root required for read-only private backup/content checks')
    backup = verify_backup(BACKUP)
    if not backup.get('restore_verified'):
        raise ValueError('Historical copy needs its independently verified restoration source')
    expected = {name: {k: v[k] for k in ('bytes', 'sha256')}
                for name, v in backup['registry']['files'].items()}
    if any(not name.startswith('docker/registry/') or '..' in Path(name).parts for name in expected):
        raise ValueError('Historical registry archive layout differs')
    ids = docker('ps', '-aq', '--no-trunc').decode().split()
    containers = json.loads(docker('inspect', *ids)) if ids else []
    results = []
    for root in TARGETS:
        if root.resolve() != root or root.stat().st_dev != Path('/data/harbor').stat().st_dev:
            raise ValueError('Candidate path/device changed')
        consumers = []
        for container in containers:
            for mount in container['Mounts']:
                if mount['Type'] != 'bind':
                    continue
                source = Path(mount['Source'])
                if source.is_relative_to(root) or root.is_relative_to(source):
                    consumers.append({'name': container['Name'].lstrip('/'), 'id': container['Id'],
                        'running': container['State']['Running'], 'restart': container['HostConfig']['RestartPolicy']['Name']})
        if any(c['running'] or c['restart'] != 'no' for c in consumers):
            raise ValueError('A live/auto-restarting container still depends on the proposed copy')
        actual = {}; allocated = root.stat().st_blocks * 512
        for path in sorted(root.rglob('*')):
            before = path.lstat()
            if path.resolve() != path or before.st_dev != root.stat().st_dev:
                raise ValueError('Candidate contains symlinks or nested filesystems')
            allocated += before.st_blocks * 512
            if stat.S_ISDIR(before.st_mode):
                continue
            if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
                raise ValueError('Candidate contains special files/shared hardlinks; cannot estimate unique release')
            digest = sha(path)
            after = path.stat()
            if (before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns):
                raise ValueError('Candidate changed during content audit')
            actual[str(path.relative_to(root))] = {'bytes': after.st_size, 'sha256': digest}
        if actual != expected:
            raise ValueError('Historical registry copy differs from the complete backup: ' + str(root))
        results.append({'path': str(root), 'files': len(actual), 'content_bytes': sum(x['bytes'] for x in actual.values()),
                        'allocated_bytes': allocated, 'full_content_matches_backup': True, 'consumers': consumers})
    new = read_manifest(NEW_BACKUP / 'backup.json')
    capacity = os.statvfs('/data/harbor')
    free = capacity.f_bavail * capacity.f_frsize
    required = new['registry']['content_bytes'] + new['runtime']['content_bytes'] + 22 * 1024**3
    return {'schema': 1, 'observed_at': dt.datetime.now(dt.timezone.utc).isoformat(), 'read_only': True,
        'backup': str(BACKUP), 'backup_manifest_sha256': sha(BACKUP / 'backup.json'),
        'backup_fully_verified': True, 'backup_independently_restored': True,
        'candidates': results, 'allocated_release_estimate_bytes': sum(r['allocated_bytes'] for r in results),
        'data_free_bytes': free, 'new_restore_required_bytes_including_reserve': required,
        'current_shortfall_bytes': max(0, required - free),
        'projected_free_after_reclaim_and_restore_budget_bytes': free + sum(r['allocated_bytes'] for r in results) - required,
        'minimum_retained_data_reserve_bytes': 20 * 1024**3,
        'owner_exception_required': True, 'reclaim_executed': False,
        'impact': 'The listed historical rehearsal containers must remain stopped; future rehearsals need fresh restoration.',
        'preserved': ['old KIND nodes and volumes', 'old /data/kind-local-storage', 'all backup archives',
                      'current main Harbor', 'candidate source config/private/generated files'],
        'not_claimed': ['immediate Windows C disk release', 'hardware-failure protection', 'new backup restored']}


def reclaim(approved_path, approved_sha):
    if os.geteuid() != 0 or not approved_path or sha(approved_path) != approved_sha:
        raise ValueError('Root and exact approved audit file SHA required')
    approved = json.loads(approved_path.read_text())
    if [r['path'] for r in approved['candidates']] != [str(t) for t in TARGETS] or approved['reclaim_executed']:
        raise ValueError('Approved audit scope differs')
    lock_path = Path('/data/harbor/.instance-preparation.lock')
    fd = os.open(lock_path, os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb+') as handle:
        info = os.fstat(handle.fileno())
        if info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o600:
            raise ValueError('Unsafe shared lifecycle lock')
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if JOURNAL.exists():
            info = JOURNAL.lstat()
            if (JOURNAL.resolve() != JOURNAL or not stat.S_ISDIR(info.st_mode)
                    or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o700):
                raise ValueError('Unsafe existing reclamation journal')
            state = read_manifest(JOURNAL / 'state.json')
            if state['approved_audit_sha256'] != approved_sha:
                raise ValueError('Existing reclamation belongs to a different scope')
            if state.get('completed'):
                return state
            backup = verify_backup(BACKUP)
            if sha(BACKUP / 'backup.json') != approved['backup_manifest_sha256']:
                raise ValueError('Preserved backup changed during interrupted reclamation')
        else:
            fresh = audit()
            if (fresh['backup_manifest_sha256'] != approved['backup_manifest_sha256']
                    or fresh['candidates'] != approved['candidates']):
                raise ValueError('Content, allocation or consumers changed since owner-approved audit')
            spec = importlib.util.spec_from_file_location('formal_storage_plan',
                Path(__file__).resolve().parents[1] / 'kind-infrastructure/formal/prepare.py')
            module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
            physical = module.physical_capacity()
            if physical['projected_c_free_bytes'] < physical['minimum_c_free_bytes']:
                raise ValueError('Physical C reserve no longer sufficient for the next stage')
            if JOURNAL.parent.resolve() != JOURNAL.parent:
                raise ValueError('Unsafe reclamation journal path')
            if not JOURNAL.parent.exists():
                directory(JOURNAL.parent)
            directory(JOURNAL)
            write(JOURNAL / 'approved-audit.json', approved_path.read_bytes())
            write(JOURNAL / 'fresh-audit.json', (json.dumps(fresh, indent=2)+'\n').encode())
            state = {'schema':1, 'approved_audit_sha256':approved_sha, 'completed':False,
                     'before_free_bytes':fresh['data_free_bytes'], 'physical_admission':physical,
                     'targets':[], 'target_measurements':{}}
            save(JOURNAL / 'state.json', state)
            backup = read_manifest(BACKUP / 'backup.json')
        # The marker is outside each reclaimed registry tree. All supported
        # startup paths refuse it, while stopping/inspection remain available.
        marker = {'schema':1, 'reason':'owner-approved duplicate registry copy reclamation',
                  'journal':str(JOURNAL), 'backup':str(BACKUP), 'approved_audit_sha256':approved_sha}
        for root in TARGETS:
            path = root.parent / MARKER
            if path.exists() or path.is_symlink():
                if read_manifest(path) != marker:
                    raise ValueError('Existing retirement marker belongs to another operation')
            else:
                write(path, (json.dumps(marker,indent=2)+'\n').encode())
        ids = docker('ps', '-aq', '--no-trunc').decode().split()
        containers = json.loads(docker('inspect', *ids))
        consumers = {c['id'] for r in approved['candidates'] for c in r['consumers']}
        seen = set()
        for c in containers:
            overlaps = any(m['Type'] == 'bind' and any(Path(m['Source']).is_relative_to(t)
                           or t.is_relative_to(Path(m['Source'])) for t in TARGETS) for m in c['Mounts'])
            if overlaps and (c['Id'] not in consumers or c['State']['Running'] or c['HostConfig']['RestartPolicy']['Name'] != 'no'):
                raise ValueError('A changed/live container uses a reclamation target')
            if overlaps:
                seen.add(c['Id'])
        if seen != consumers:
            raise ValueError('Approved container consumer set changed')
        expected = backup['registry']['files']
        for root in TARGETS:
            if root.resolve() != root or root.stat().st_dev != Path('/data/harbor').stat().st_dev:
                raise ValueError('Reclamation target identity/device changed')
            measurement = state['target_measurements'].get(str(root))
            if measurement is None:
                capacity = os.statvfs(root)
                measurement = {'before_free_bytes':capacity.f_bavail * capacity.f_frsize}
                state['target_measurements'][str(root)] = measurement
                save(JOURNAL / 'state.json', state)
            paths = sorted(root.rglob('*'))
            # Entire remaining set verified before unlink; a partial previous run
            # may have removed expected members but may not introduce new ones.
            regular = []
            for path in paths:
                info = path.lstat()
                if path.resolve() != path or info.st_dev != root.stat().st_dev:
                    raise ValueError('Refusing symlink or filesystem crossing')
                if stat.S_ISDIR(info.st_mode):
                    continue
                record = expected.get(str(path.relative_to(root)))
                if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or not record
                        or info.st_size != record['bytes'] or sha(path) != record['sha256']):
                    raise ValueError('Remaining file differs from the preserved backup')
                regular.append((path, info.st_ino, info.st_size, info.st_mtime_ns, info.st_dev))
            for path, inode, size, mtime, device in regular:
                info = path.lstat()
                if not stat.S_ISREG(info.st_mode) or (info.st_ino,info.st_size,info.st_mtime_ns,info.st_dev) != (inode,size,mtime,device):
                    raise ValueError('Candidate changed before unlink')
                path.unlink()
            for path in sorted(paths, key=lambda v:len(v.parts), reverse=True):
                if path.exists():
                    if not path.is_dir() or path.is_symlink():
                        raise ValueError('Unexpected remaining file; stop without broad removal')
                    path.rmdir()
            if any(root.iterdir()):
                raise ValueError('Approved registry tree did not become empty')
            if str(root) not in state['targets']:
                os.sync()
                capacity = os.statvfs(root)
                measurement['after_free_bytes'] = capacity.f_bavail * capacity.f_frsize
                measurement['net_free_increase_bytes'] = measurement['after_free_bytes'] - measurement['before_free_bytes']
                measurement['empty_root_retained'] = True
                state['targets'].append(str(root)); save(JOURNAL / 'state.json', state)
        capacity = os.statvfs('/data/harbor')
        state.update(completed=True, after_free_bytes=capacity.f_bavail*capacity.f_frsize,
                     containers_deleted=False, volumes_deleted=False, backups_deleted=False,
                     main_harbor_changed=False, retirement_markers_written=True)
        state['net_free_increase_bytes'] = state['after_free_bytes'] - state['before_free_bytes']
        save(JOURNAL / 'state.json', state)
        return state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--reclaim', action='store_true')
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--approved-audit', type=Path)
    parser.add_argument('--audit-sha256')
    args = parser.parse_args()
    if args.check and (args.reclaim or args.apply):
        raise ValueError('Read-only check and reclamation must be separate invocations')
    if args.apply:
        if not args.reclaim:
            raise ValueError('--apply only belongs to explicit --reclaim')
        print(json.dumps(reclaim(args.approved_audit, args.audit_sha256), indent=2)); return
    value = audit() if args.check else {'dry_run': True, 'targets': [str(t) for t in TARGETS],
        'delete': False, 'requires_owner_exception_before_reclaim': True}
    print(json.dumps(value, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Space audit stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; raw diagnostics withheld')) from None
