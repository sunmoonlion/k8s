#!/usr/bin/env python3
"""Stage locked public node configuration files into the offline material root.

Default prints a plan. --apply only creates absent matching configuration files;
never overwrites existing bytes, installs a service or changes host configuration.
"""
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path
from bundle import below, resolve, sha256


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest', type=Path, default=Path(__file__).resolve().with_name('cluster-artifacts.lock.json'))
    p.add_argument('--root', type=Path, default=Path.home()/'packages-to-be-installed')
    p.add_argument('--apply', action='store_true')
    a = p.parse_args()
    data, entries = resolve(a.manifest)
    root = a.root.expanduser().absolute()
    if root.resolve() != root or not root.is_dir():
        raise ValueError('Existing material root required; symlinks refused')
    staged = []
    # Check the complete source/destination set before creating the first file.
    for entry in entries:
        if entry['scope'] != 'configuration': continue
        relative = entry['path'].removeprefix('releases/'+data['batch']+'/')
        source = below(a.manifest.expanduser().absolute().parent, relative)
        raw = source.read_bytes()
        if hashlib.sha256(raw).hexdigest() != entry['sha256'] or len(raw) != entry['bytes']:
            raise ValueError('Source configuration differs from lock')
        dest = below(root, entry['path'])
        if dest.exists() and (not dest.is_file() or sha256(dest) != entry['sha256']):
            raise ValueError('Existing configuration differs; preserved')
        staged.append((entry, dest, raw))
    for entry, dest, raw in staged:
        if a.apply:
            dest.parent.mkdir(parents=True, exist_ok=True)
            if not dest.exists():
                fd = os.open(dest, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o644)
                with os.fdopen(fd, 'wb') as stream:
                    stream.write(raw)
                    stream.flush()
                    os.fsync(stream.fileno())
            if sha256(dest) != entry['sha256']: raise ValueError('Final staged SHA256 differs')
    print(json.dumps({'dry_run': not a.apply, 'batch': data['batch'], 'files': [x[0] for x in staged],
                      'installed': False, 'services_started': False}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f'Configuration staging failed: {error}', file=sys.stderr)
        sys.exit(1)
