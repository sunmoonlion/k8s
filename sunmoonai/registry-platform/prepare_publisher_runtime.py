#!/usr/bin/env python3
"""Stage the signed Ubuntu Skopeo package and libraries without host installation.

Plans by default. No package maintainer scripts, sudo, network or service actions.
Shared Ubuntu 24.04 amd64 tool runtime; cloud execution 未经实机验证.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile

MATERIALS = Path(__file__).resolve().parents[1] / 'infrastructure/materials'
sys.path.insert(0, str(MATERIALS))
from verify_os import verify_os
from bundle import read_lock

LIBRARY = re.compile(r'(?:usr/)?lib/x86_64-linux-gnu/([^/]+\.so(?:\.[A-Za-z0-9.+_-]+)*)')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


LAUNCHER = '''#!/usr/bin/python3 -I
# Generated from signed Ubuntu packages. No host installation; cloud 未经实机验证.
import hashlib,json,os,sys
from pathlib import Path
root=Path(__file__).absolute().parent.parent
if root.resolve()!=root: raise SystemExit('Publisher runtime path contains symlinks')
lock=root/'runtime.lock.json'
raw=lock.read_bytes()
if hashlib.sha256(raw).hexdigest()!='LOCK_SHA': raise SystemExit('Publisher runtime lock differs')
data=json.loads(raw)
for entry in data['files']:
    p=root/entry['path']
    if p.resolve()!=p or not p.is_file(): raise SystemExit('Publisher runtime file missing/symlinked')
    with p.open('rb') as f: actual=hashlib.file_digest(f,'sha256').hexdigest()
    if p.stat().st_size!=entry['bytes'] or actual!=entry['sha256']:
        raise SystemExit('Publisher runtime bytes differ')
for entry in data['links']:
    p=root/entry['path']
    if not p.is_symlink() or os.readlink(p)!=entry['target']:
        raise SystemExit('Publisher runtime library link differs')
loader=str(root/'lib/ld-linux-x86-64.so.2')
env=dict(os.environ)
for key in ('LD_PRELOAD','LD_LIBRARY_PATH','LD_AUDIT'):
    env.pop(key,None)
env['LC_ALL']='C'
os.execve(loader,[loader,'--inhibit-cache','--library-path',str(root/'lib'),
                 str(root/'libexec/skopeo'),*sys.argv[1:]],env)
'''


def prepare(source, output):
    lock = read_lock(source / 'os-dependencies.lock.json')
    if lock.get('root_packages') != ['skopeo', 'ca-certificates']:
        raise ValueError('Expected isolated registry-publisher package set')
    verification = verify_os(source, lock, Path('/usr/share/keyrings/ubuntu-archive-keyring.gpg'))
    if output.exists():
        raise ValueError('Runtime output already exists; retain it and inspect instead of overwriting')
    ancestor = output.parent
    while not ancestor.exists():
        ancestor = ancestor.parent
    if shutil.disk_usage(ancestor).free < 2 * lock['total_bytes'] + 2 * 1024**3:
        raise ValueError('Insufficient runtime staging space; no cleanup attempted')
    output.mkdir(parents=True)
    for name in ('bin', 'lib', 'libexec'):
        (output / name).mkdir()
    aliases = {}
    origins = {}
    # Extract only Skopeo and shared libraries, never OS configuration, services or scripts.
    for package in lock['files']:
        process = subprocess.Popen(['dpkg-deb', '--fsys-tarfile', str(source / package['path'])],
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        try:
            with tarfile.open(fileobj=process.stdout, mode='r|') as archive:
                for member in archive:
                    name = member.name.removeprefix('./')
                    match = LIBRARY.fullmatch(name)
                    if name == 'usr/bin/skopeo' and member.isfile():
                        relative = 'libexec/skopeo'
                    elif match and member.isfile():
                        relative = 'lib/' + match[1]
                    elif match and member.issym():
                        target = Path(member.linkname).name
                        if not re.fullmatch(r'[A-Za-z0-9._+-]+', target):
                            raise ValueError('Unexpected shared-library symlink target')
                        relative = 'lib/' + match[1]
                        if relative in aliases and aliases[relative] != target:
                            raise ValueError('Conflicting library alias')
                        aliases[relative] = target
                        continue
                    else:
                        continue
                    path = output / relative
                    if path.exists():
                        # No overwrite even when multiple packages contain the same path.
                        with archive.extractfile(member) as stream:
                            incoming = hashlib.file_digest(stream, 'sha256').hexdigest()
                        if incoming != sha(path):
                            raise ValueError('Conflicting runtime file in package set')
                    else:
                        with archive.extractfile(member) as src, path.open('xb') as dest:
                            while block := src.read(1024**2):
                                dest.write(block)
                        path.chmod(0o555)
                    origins.setdefault(relative, []).append(package['package'])
            if process.wait(timeout=30):
                raise ValueError('dpkg-deb failed while reading signed package')
        finally:
            process.stdout.close()
            if process.poll() is None:
                process.kill()
                process.wait()
    for relative, target in aliases.items():
        path = output / relative
        if path.exists():
            raise ValueError('Library alias collides with a regular file')
        # Flatten only library paths; every alias must resolve to an included regular file.
        seen = set()
        current = 'lib/' + target
        while current in aliases:
            if current in seen:
                raise ValueError('Cyclic library aliases')
            seen.add(current)
            current = 'lib/' + aliases[current]
        if not (output / current).is_file():
            raise ValueError('Library alias target not included')
        path.symlink_to(target)
    if not (output / 'lib/ld-linux-x86-64.so.2').is_file() or not (output / 'libexec/skopeo').is_file():
        raise ValueError('Runtime loader or Skopeo missing')
    records = [{'path': name, 'sha256': sha(output / name), 'bytes': (output / name).stat().st_size,
                'packages': names} for name, names in sorted(origins.items())]
    data = {'schema': 1, 'profile': 'ubuntu-24.04-amd64',
            'source_lock_sha256': sha(source / 'os-dependencies.lock.json'),
            'skopeo_package': next(x['version'] for x in lock['files'] if x['package'] == 'skopeo'),
            'files': records, 'links': [{'path': k, 'target': v} for k, v in sorted(aliases.items())],
            'os_signatures_verified': verification['signatures'], 'host_installed': False,
            'cloud_validated': False}
    with (output / 'runtime.lock.json').open('x') as stream:
        json.dump(data, stream, indent=2)
        stream.write('\n')
    launcher = output / 'bin/skopeo'
    launcher.write_text(LAUNCHER.replace('LOCK_SHA', sha(output / 'runtime.lock.json')))
    launcher.chmod(0o555)
    print(json.dumps({'tool': {'path': str(launcher), 'sha256': sha(launcher)},
                      'skopeo_package': data['skopeo_package'], 'runtime_files': len(records),
                      'runtime_links': len(aliases), 'host_installed': False,
                      'tool_execution_verified': False}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    for path in (args.source, args.output):
        if not path.is_absolute() or path.resolve() != path:
            parser.error('Absolute non-symlink source/output paths required')
    if not args.apply:
        print(json.dumps({'apply': False, 'source': str(args.source), 'output': str(args.output),
                          'host_install': False, 'signature_verification': 'required before extraction'}))
        return
    if os.uname().machine != 'x86_64' or os.geteuid() == 0:
        raise ValueError('Use an unprivileged amd64 Ubuntu user')
    prepare(args.source, args.output)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, tarfile.TarError, subprocess.SubprocessError) as error:
        raise SystemExit('Publisher runtime preparation stopped: ' + str(error)) from None
