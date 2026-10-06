#!/usr/bin/env python3
"""Check/attach the existing data filesystem; never create, format or resize it."""
import json
import os
from pathlib import Path
import subprocess
import sys


def output(*argv):
    return subprocess.check_output(argv, text=True, stderr=subprocess.PIPE, timeout=30).strip()


def mount(path, exact=True):
    p = subprocess.run(['findmnt', '--json', '--mountpoint' if exact else '--target', str(path),
                        '--output', 'TARGET,SOURCE,FSTYPE,UUID,FSROOT'],
                       capture_output=True, text=True, timeout=10)
    if p.returncode == 1 and not p.stdout.strip():
        return None
    if p.returncode:
        raise ValueError('Cannot inspect mount: ' + str(path))
    rows = json.loads(p.stdout)['filesystems']
    if len(rows) != 1:
        raise ValueError('Ambiguous mount: ' + str(path))
    return rows[0]


def identity(path):
    info = Path(path).stat()
    return (info.st_dev, info.st_ino)


def config():
    path = Path(sys.argv[2])
    info = path.lstat()
    if path.resolve() != path or info.st_uid != 0 or info.st_mode & 0o022:
        raise ValueError('Storage configuration must be root owned and immutable to ordinary users')
    cfg = json.loads(path.read_text())
    if cfg['mounts'] != [{'target': '/mnt/sunmoon-data', 'fsroot': '/'},
                         {'target': '/data/kind-clusters', 'fsroot': '/kind-clusters'},
                         {'target': '/data/harbor', 'fsroot': '/harbor'}]:
        raise ValueError('Unsupported storage layout')
    if Path('/mnt/c/wsl-disks/sunmoon-data.maintenance').exists():
        raise ValueError('Storage maintenance is active')
    return cfg


def check(cfg):
    for item in cfg['mounts']:
        path = Path(item['target'])
        if path.resolve() != path:
            raise ValueError('Symlink mount path: ' + str(path))
        row = mount(path)
        expected = dict(target=str(path), fstype='ext4', uuid=cfg['uuid'], fsroot=item['fsroot'])
        if not row or any(row.get(key) != value for key, value in expected.items()):
            raise ValueError('Wrong/missing UUID or bind root: ' + str(path))
        if identity(path)[0] == identity('/')[0]:
            raise ValueError('Data directory is on the WSL system filesystem')
        if item['fsroot'] != '/' and identity(path) != identity('/mnt/sunmoon-data' + item['fsroot']):
            raise ValueError('Bind directory identity mismatch: ' + str(path))
    if int(output('blockdev', '--getsize64', mount('/mnt/sunmoon-data')['source'])) != cfg['maximum_gib'] * 1024**3:
        raise ValueError('Data block device capacity differs from configuration')
    pids = [1]
    pid = int(output('systemctl', 'show', 'docker.service', '--property=MainPID', '--value'))
    if pid:
        pids.append(pid)
    for pid in pids:
        for item in cfg['mounts']:
            row = output('nsenter', '--target', str(pid), '--mount', '--', 'stat', '-c', '%d:%i', item['target'])
            if row != ':'.join(map(str, identity(item['target']))):
                raise ValueError('Service mount namespace mismatch: ' + str(pid) + ' ' + item['target'])
    print(json.dumps({'storage_verified': True, 'uuid': cfg['uuid'], 'services_started': False}))


def repair(cfg):
    if os.readlink('/proc/self/ns/mnt') != os.readlink('/proc/1/ns/mnt'):
        raise ValueError('Mount repair must execute in the PID 1 mount namespace')
    old = (identity('/data/kind-local-storage'), mount('/data/kind-local-storage', False))
    devices = output('blkid', '-t', 'UUID=' + cfg['uuid'], '-o', 'device').splitlines()
    if len(devices) != 1 or int(output('blockdev', '--getsize64', devices[0])) != cfg['maximum_gib'] * 1024**3:
        raise ValueError('Existing data device is absent, ambiguous or the wrong size')
    lines = [line.split() for line in Path('/etc/fstab').read_text().splitlines()
             if line.strip() and not line.lstrip().startswith('#')]
    for item in cfg['mounts']:
        path = Path(item['target'])
        source = 'UUID=' + cfg['uuid'] if item['fsroot'] == '/' else '/mnt/sunmoon-data' + item['fsroot']
        entries = [line for line in lines if len(line) >= 4 and line[1] == str(path)]
        if len(entries) != 1 or entries[0][0] != source or entries[0][2] != ('ext4' if item['fsroot'] == '/' else 'none'):
            raise ValueError('Existing fstab entry differs: ' + str(path))
        row = mount(path)
        if row:
            if row.get('uuid') != cfg['uuid'] or row.get('fsroot') != item['fsroot']:
                raise ValueError('Refuse to replace an existing mount: ' + str(path))
        else:
            if path.resolve() != path or not path.is_dir() or any(path.iterdir()):
                raise ValueError('Unmounted target is not an empty directory: ' + str(path))
            output('mount', str(path))
    if old != (identity('/data/kind-local-storage'), mount('/data/kind-local-storage', False)):
        raise ValueError('Protected legacy path identity changed')
    check(cfg)


if __name__ == '__main__':
    try:
        if len(sys.argv) != 3 or sys.argv[1] not in ('check', 'mount') or os.geteuid() != 0:
            raise ValueError('Usage as root: storage.py check|mount ROOT_OWNED_CONFIG')
        cfg = config()
        (repair if sys.argv[1] == 'mount' else check)(cfg)
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit('Storage blocked: ' + (str(error) if isinstance(error, ValueError) else type(error).__name__)) from None
