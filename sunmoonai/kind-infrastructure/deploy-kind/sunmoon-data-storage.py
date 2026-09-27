#!/usr/bin/env python3
"""SUNMOON_DATA_LAYOUT_V1: explicit setup/mount, read-only check, default dry-run.

Local WSL only. New VHDX creation/formatting belongs to the owner in Windows.
Never unmount, format, start Docker, or touch the legacy storage path.
"""
import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path('/mnt/sunmoon-data')
BINDS = {Path('/data/kind-clusters'): ROOT / 'kind-clusters', Path('/data/harbor'): ROOT / 'harbor'}
OLD = Path('/data/kind-local-storage')
GIB = 1024**3


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=30).stdout.strip()


def canonical(path):
    if path.resolve() != path:
        raise RuntimeError(f'Symlink path refused: {path}')


def mount_info(path, exact=True):
    p = subprocess.run(['findmnt', '--json', '--mountpoint' if exact else '--target', str(path),
                        '--output', 'TARGET,SOURCE,FSTYPE,UUID,OPTIONS,MAJ:MIN,FSROOT'],
                       capture_output=True, text=True, timeout=10)
    if p.returncode == 1 and not p.stdout.strip():
        return None
    if p.returncode:
        raise RuntimeError(f'findmnt failed: {path}')
    rows = json.loads(p.stdout).get('filesystems', [])
    if len(rows) != 1:
        raise RuntimeError(f'Expected one mount, refuse stacked/ambiguous mounts: {path}')
    return rows[0]


def identity(path):
    st = path.stat()
    return [st.st_dev, st.st_ino]


def legacy_identity():
    canonical(OLD)
    return {'inode': identity(OLD), 'mount': mount_info(OLD, exact=False)}


def check_root(uuid, minimum):
    canonical(ROOT)
    info = mount_info(ROOT)
    if not info or info['target'] != str(ROOT) or info['fstype'] != 'ext4' or info.get('uuid', '').lower() != uuid:
        raise RuntimeError('Data mount absent or wrong ext4 UUID; do not fall back to system disk')
    if info.get('fsroot') != '/' or 'rw' not in info['options'].split(','):
        raise RuntimeError('Data filesystem must be the writable filesystem root')
    if ROOT.stat().st_dev == Path('/').stat().st_dev:
        raise RuntimeError('Data mount is on the WSL system filesystem')
    fs = os.statvfs(ROOT)
    if fs.f_bavail*fs.f_frsize < minimum*GIB:
        raise RuntimeError(f'Data filesystem has less than {minimum} GiB available')
    return info


def check(uuid, minimum):
    result = {'layout': 'SUNMOON_DATA_LAYOUT_V1', 'expected_uuid': uuid,
              'root': check_root(uuid, minimum), 'binds': []}
    for target, source in BINDS.items():
        canonical(target)
        canonical(source)
        info = mount_info(target)
        if not info or info['target'] != str(target) or info['fstype'] != 'ext4':
            raise RuntimeError(f'Exact bind mount missing: {target}')
        if 'rw' not in info['options'].split(',') or identity(target) != identity(source):
            raise RuntimeError(f'Bind source inode/device mismatch or read-only: {target}')
        if source.stat().st_dev != ROOT.stat().st_dev:
            raise RuntimeError(f'Source is on a different filesystem: {source}')
        result['binds'].append({'target': str(target), 'source': str(source), 'identity': identity(source)})
    result['legacy_storage'] = legacy_identity()
    result['available_bytes'] = os.statvfs(ROOT).f_bavail*os.statvfs(ROOT).f_frsize
    return result


def entries(uuid):
    return [f'UUID={uuid} {ROOT} ext4 defaults,nofail,x-systemd.device-timeout=10s 0 2'] + [
        f'{src} {dst} none bind,nofail,x-systemd.requires={ROOT} 0 0' for dst, src in BINDS.items()]


def fstab_state(uuid):
    path = Path('/etc/fstab')
    canonical(path)
    text = path.read_text()
    expected = {line.split()[1]: line.split() for line in entries(uuid)}
    found = {}
    for line in text.splitlines():
        parts = line.split('#', 1)[0].split()
        if len(parts) < 2 or parts[1] not in expected:
            continue
        if parts[1] in found or parts != expected[parts[1]]:
            raise RuntimeError(f'Conflicting fstab row: {parts[1]}; manual review required')
        found[parts[1]] = parts
    return text, [line for line in entries(uuid) if line.split()[1] not in found]


def ensure_empty_unmounted(path):
    canonical(path)
    if path.exists() and (not path.is_dir() or next(path.iterdir(), None) is not None):
        raise RuntimeError(f'Unmounted target is not an empty directory: {path}')


def apply(action, uuid, minimum):
    if os.geteuid() != 0:
        raise RuntimeError('Owner must run setup/mount as root through the approved PowerShell workflow')
    with open('/run/lock/sunmoon-data.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        old = legacy_identity()
        devices = run('blkid', '-t', 'UUID='+uuid, '-o', 'device').splitlines()
        if len(devices) != 1:
            raise RuntimeError('Expected exactly one attached device with this UUID')
        device = devices[0]
        if run('blkid', '-s', 'TYPE', '-o', 'value', device) != 'ext4':
            raise RuntimeError('Expected ext4; this script never formats disks')
        if int(run('blockdev', '--getsize64', device)) != 100*GIB:
            raise RuntimeError('Device is not the owner-approved 100 GiB disk')
        original, missing = fstab_state(uuid)
        if action == 'mount' and missing:
            raise RuntimeError('fstab setup incomplete; mount mode never edits configuration')
        for target in [ROOT, *BINDS]:
            if not mount_info(target):
                ensure_empty_unmounted(target)
        if mount_info(ROOT):
            check_root(uuid, minimum)
        elif any(mount_info(target) for target in BINDS):
            raise RuntimeError('Bind present without main data mount; manual review required')
        # Reject existing incorrect binds before changing anything else.
        for target, source in BINDS.items():
            if mount_info(target):
                canonical(source)
                if not source.exists() or identity(target) != identity(source):
                    raise RuntimeError(f'Existing bind mismatch: {target}')
        if action == 'setup':
            for target in [ROOT, *BINDS]:
                target.mkdir(parents=True, exist_ok=True, mode=0o755)
            if missing:
                stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
                backup = Path('/etc/fstab.before-sunmoon-data.'+stamp)
                with backup.open('x') as stream:
                    stream.write(original)
                    stream.flush()
                    os.fsync(stream.fileno())
                shutil.copystat('/etc/fstab', backup)
                fd, name = tempfile.mkstemp(prefix='.fstab.sunmoon-', dir='/etc')
                with os.fdopen(fd, 'w') as stream:
                    stream.write(original.rstrip('\n')+'\n\n'+'\n'.join(missing)+'\n')
                    stream.flush()
                    os.fsync(stream.fileno())
                shutil.copystat('/etc/fstab', name)
                if Path('/etc/fstab').read_text() != original:
                    raise RuntimeError('fstab changed concurrently; preserved temporary file for review')
                os.replace(name, '/etc/fstab')
                run('systemctl', 'daemon-reload')
        if not mount_info(ROOT):
            run('mount', str(ROOT))
        check_root(uuid, minimum)
        for target, source in BINDS.items():
            canonical(source)
            if action == 'setup':
                source.mkdir(exist_ok=True, mode=0o755)
            if not source.is_dir():
                raise RuntimeError(f'Data directory missing: {source}')
            if not mount_info(target):
                run('mount', str(target))
        if legacy_identity() != old:
            raise RuntimeError('Legacy path identity drifted; stop, do not unmount anything automatically')
        return check(uuid, minimum)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['check', 'setup', 'mount'])
    parser.add_argument('--expected-uuid', required=True)
    parser.add_argument('--min-free-gib', type=int, default=10)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    uuid = args.expected_uuid.lower()
    if not re.fullmatch(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', uuid) or args.min_free_gib < 1:
        parser.error('A real filesystem UUID and positive free-space floor are required')
    if args.action != 'check' and not args.apply:
        print(json.dumps({'dry_run': True, 'action': args.action, 'fstab_rows': entries(uuid),
                          'expected_disk_gib': 100, 'min_free_gib': args.min_free_gib,
                          'legacy_path': 'protected; never mounted/unmounted/modified'}))
        return
    result = check(uuid, args.min_free_gib) if args.action == 'check' else apply(args.action, uuid, args.min_free_gib)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
        raise SystemExit('[sunmoon-data] FAIL: '+str(exc)) from None
