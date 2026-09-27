#!/usr/bin/env python3
"""Transfer exactly the locked public cluster files, without deletion.

Default: print only, never SSH. --apply: local checksum verification, strict SSH
host checking, remote immutable-file preflight, resumable rsync, remote SHA256.
No source repository, credentials, containers, services or cleanup is involved.
Cloud execution 未经实机验证.
"""
import argparse
import json
import re
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

from bundle import resolve, verify

# This payload is our code, not downloaded input. JSON is passed on stdin,
# never interpolated as Python or Shell source. Check every existing parent.
REMOTE = r'''
import hashlib,json,sys
from pathlib import Path
payload=json.load(sys.stdin)
if sys.version_info < (3,11): raise SystemExit('Remote Python >=3.11 required before transfer')
root=Path(payload['root']).expanduser().absolute()
if root.name!='packages-to-be-installed' or root.resolve()!=root:
    raise SystemExit('Remote material root identity/path refused')
for entry in payload['files']:
    path=root/entry['path']
    if path.resolve()!=path or not path.is_relative_to(root):
        raise SystemExit('Symlink/escaping remote material path refused')
    if path.exists():
        if not path.is_file(): raise SystemExit('Remote artifact is not a regular file')
        with path.open('rb') as f: digest=hashlib.file_digest(f,'sha256').hexdigest()
        if digest!=entry['sha256']: raise SystemExit('Existing remote material differs; preserved')
    elif payload['mode']=='verify':
        raise SystemExit('Remote material missing after transfer')
if payload['mode']=='prepare': root.mkdir(parents=True,exist_ok=True)
print(json.dumps({'mode':payload['mode'],'files':len(payload['files']),'passed':True}))
'''


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest', type=Path, default=Path(__file__).resolve().with_name('cluster-artifacts.lock.json'))
    p.add_argument('--root', type=Path, default=Path.home()/'packages-to-be-installed')
    p.add_argument('--host', required=True, help='Explicit SSH user@hostname (key or agent authentication)')
    p.add_argument('--port', type=int, default=22)
    p.add_argument('--identity', type=Path)
    p.add_argument('--remote-root', default='packages-to-be-installed')
    p.add_argument('--apply', action='store_true')
    a = p.parse_args()
    if not re.fullmatch(r'[a-z_][a-z0-9_-]*@[A-Za-z0-9][A-Za-z0-9.-]*', a.host) or not 1 <= a.port <= 65535:
        raise ValueError('Invalid SSH destination/port')
    remote = a.remote_root
    if remote.startswith('~/'): remote = remote[2:]
    if not re.fullmatch(r'[A-Za-z0-9_./-]+', remote) or '..' in Path(remote).parts or Path(remote).name != 'packages-to-be-installed':
        raise ValueError('Remote root must name an explicit packages-to-be-installed directory')
    root = a.root.expanduser().absolute()
    if root.resolve() != root or not root.is_dir():
        raise ValueError('Local material root missing or symlinked')
    data, files = resolve(a.manifest)
    ssh = ['ssh', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
           '-o', 'ConnectTimeout=10', '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=3',
           '-p', str(a.port)]
    if a.identity:
        identity = a.identity.expanduser().absolute()
        ssh += ['-o', 'IdentitiesOnly=yes', '-i', str(identity)]
    if not a.apply:
        print(json.dumps({'dry_run': True, 'cloud_status': '未经实机验证', 'batch': data['batch'],
                          'closure_complete': data['closure_complete'], 'install': False,
                          'files_verified': False, 'files': [x['path'] for x in files],
                          'ssh': ssh + [a.host], 'remote_root': remote,
                          'order': ['local SHA256', 'remote existing-file SHA256/no-symlink preflight',
                                    'rsync exact list with partial-dir; no delete', 'remote all-file SHA256']},
                         ensure_ascii=False, indent=2))
        return
    if a.identity and not identity.is_file():
        raise ValueError('Explicit SSH identity file missing')
    files = verify(root, files)
    payload = {'root': remote, 'files': files, 'mode': 'prepare'}
    remote_command = 'python3 -c ' + shlex.quote(REMOTE)
    subprocess.run(ssh + [a.host, remote_command], input=json.dumps(payload), text=True, check=True, timeout=1800)
    with tempfile.TemporaryDirectory(prefix='sunmoon-material-transfer-') as temp:
        listing = Path(temp)/'files'
        listing.write_bytes(b'\0'.join(x['path'].encode() for x in files)+b'\0')
        subprocess.run(['rsync', '-rlt', '--relative', '--checksum', '--from0', '--files-from='+str(listing),
                        '--partial-dir=.sunmoon-partial', '--delay-updates',
                        '-e', shlex.join(ssh), str(root)+'/', a.host+':'+remote+'/'],
                       check=True, timeout=3600)
    payload['mode'] = 'verify'
    subprocess.run(ssh + [a.host, remote_command], input=json.dumps(payload), text=True, check=True, timeout=1800)
    print(json.dumps({'transferred_and_verified': True, 'files': len(files), 'install': False,
                      'closure_complete': data['closure_complete']}))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f'Locked material transfer failed: {error}', file=sys.stderr)
        sys.exit(1)
