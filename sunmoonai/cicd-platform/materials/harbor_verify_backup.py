#!/usr/bin/env python3
"""Verify cold backup files and registry blob bytes; does not restore services."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import tarfile
import time

from harbor_cold_backup import digest, write


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('backup', type=Path)
    args = parser.parse_args()
    root = args.backup.resolve()
    state = json.loads((root / 'state.json').read_text())
    if not all(state.get(k) for k in ['backup_complete', 'services_restored', 'catalog_unchanged']):
        raise RuntimeError('Cold backup or service recovery incomplete')
    checked = []
    for folder, manifest in [(root, {'artifacts': state['archives']}),
                             (root.parent / 'preparation', json.loads((root.parent / 'preparation/preparation.json').read_text())),
                             (root.parent / 'preparation', json.loads((root.parent / 'preparation/tls-addendum.json').read_text()))]:
        for item in manifest['artifacts']:
            path = (folder / item['path']).resolve()
            if not path.is_relative_to(folder) or path.stat().st_size != item['bytes'] or digest(path) != item['sha256']:
                raise RuntimeError('File integrity mismatch: ' + item['path'])
            checked.append({'path': str(path.relative_to(root.parent)), 'sha256': item['sha256'], 'bytes': item['bytes']})
    catalog = json.loads((root / 'catalog-before.json').read_text())
    required = {a['digest'] for p in catalog['projects'] for r in p['repositories'] for a in r['artifacts']}
    blobs = set()
    last = time.monotonic()
    with tarfile.open(root / 'volumes/registry.tar', 'r|') as archive:
        for member in archive:
            parts = PurePosixPath(member.name).parts
            if member.isfile() and 'blobs' in parts and parts[-1] == 'data':
                if len(parts[-2]) != 64 or parts[-4] != 'sha256':
                    raise RuntimeError('Unrecognized registry blob layout')
                h = hashlib.sha256()
                with archive.extractfile(member) as stream:
                    for block in iter(lambda: stream.read(1024**2), b''): h.update(block)
                if h.hexdigest() != parts[-2]:
                    raise RuntimeError('Registry blob content digest mismatch')
                blobs.add('sha256:' + h.hexdigest())
                if time.monotonic() - last > 20:
                    print('Verified registry blobs', len(blobs), flush=True)
                    last = time.monotonic()
    if not required <= blobs: raise RuntimeError('Catalog references absent manifest blobs')
    # Manifest layer/config closure must also exist, not just catalog manifests.
    descriptor_refs = set()
    with tarfile.open(root / 'volumes/registry.tar', 'r|') as archive:
        for member in archive:
            parts = PurePosixPath(member.name).parts
            if member.isfile() and parts[-1] == 'data' and 'blobs' in parts and 'sha256:' + parts[-2] in required:
                if member.size > 32 * 1024**2: raise RuntimeError('Unexpectedly large image manifest')
                manifest = json.load(archive.extractfile(member))
                entries = manifest.get('manifests', []) + manifest.get('layers', [])
                if manifest.get('config'): entries.append(manifest['config'])
                if manifest.get('subject'): entries.append(manifest['subject'])
                descriptor_refs.update(e['digest'] for e in entries)
    if not descriptor_refs <= blobs:
        raise RuntimeError('Image manifest references absent layer/config blobs')
    for name in ['state.json', 'catalog-before.json', 'catalog-after.json', 'resources-private.json',
                 'backup-script.py', 'RECOVER-SERVICES.txt']:
        path = root / name
        checked.append({'path': str(path.relative_to(root.parent)), 'sha256': digest(path), 'bytes': path.stat().st_size})
    report = {'file_checks_passed': True, 'files': checked, 'registry_blobs_verified': len(blobs),
              'catalog_manifest_digests_present': len(required), 'descriptor_digests_present': len(descriptor_refs),
              'isolated_restore_verified': False}
    write(root / 'verification.json', report)
    print(json.dumps({k: v for k, v in report.items() if k != 'files'}))


if __name__ == '__main__':
    main()
