#!/usr/bin/env python3
"""Prepare the official stable scanner image, independently of Harbor services.

Only public GHCR data, no Docker/service/SSH/cleanup. Default prints the plan.
Local/cloud material preparation shared; cloud deployment 未经实机验证.
"""
import argparse
import fcntl
import io
import json
from pathlib import Path
import re
import shutil
import tarfile
import uuid

from prepare_scanner_db import request, auth, sha

REPOSITORY = 'goharbor/trivy-adapter-photon'
SOURCE = 'ghcr.io/' + REPOSITORY + ':v2.15.2'
MANIFEST = 'sha256:215c07b71c37fc7fc16e02d9185d936dcb8884a80e810817c2cd058bbd7c4e98'
CONFIG = 'sha256:00f2535bcde46ebeaa3b260601841a2ebc493b940a311e77dc3010e6b94aa4e2'
ALIAS = 'sunmoon-offline/harbor-scanner:v2.15.2-' + MANIFEST[7:23]
ACCEPT = 'application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'


def prepare(root):
    blobs = root / 'blobs' / 'sha256'
    blobs.mkdir(parents=True, exist_ok=True)
    if blobs.resolve() != blobs:
        raise ValueError('Symlink blob directory refused')
    token = auth(REPOSITORY)
    records = {}

    def fetch(digest, size=None, manifest=False):
        if not re.fullmatch(r'sha256:[a-f0-9]{64}', digest):
            raise ValueError('Invalid fixed image digest')
        target = blobs / digest[7:]
        if target.resolve() != target:
            raise ValueError('Symlink content path refused')
        if not target.exists():
            if shutil.disk_usage(root).free < (size or 1024**2) + 6 * 1024**3:
                raise ValueError('Need declared download bytes plus 6 GiB headroom')
            partial = target.with_name(target.name + '.' + uuid.uuid4().hex + '.partial')
            request('https://ghcr.io/v2/' + REPOSITORY + ('/manifests/' if manifest else '/blobs/') + digest,
                    token, partial, size or 1024**2, accept=ACCEPT)
            if sha(partial) != digest[7:] or (size is not None and partial.stat().st_size != size):
                raise ValueError('Downloaded image differs; partial retained')
            partial.rename(target)
        if sha(target) != digest[7:] or (size is not None and target.stat().st_size != size):
            raise ValueError('Existing image differs; no overwrite')
        records[digest] = target.stat().st_size
        return target

    manifest = json.loads(fetch(MANIFEST, manifest=True).read_bytes())
    if (manifest.get('schemaVersion') != 2 or manifest.get('mediaType') not in ACCEPT.split(', ')
            or manifest['config']['digest'] != CONFIG):
        raise ValueError('Pinned official manifest/config differ')
    items = [manifest['config'], *manifest['layers']]
    if any(type(x.get('size')) is not int or x['size'] < 0 for x in items) or sum(x['size'] for x in items) > 512 * 1024**2:
        raise ValueError('Unexpected compressed image size')
    for item in items:
        fetch(item['digest'], item['size'])
    config = json.loads((blobs / CONFIG[7:]).read_bytes())
    if (config.get('architecture'), config.get('os')) != ('amd64', 'linux'):
        raise ValueError('Unexpected scanner image platform')
    target = root / 'scanner-linux-amd64.tar'
    receipt_path = root / 'scanner-candidate.lock.json'
    if target.exists() or receipt_path.exists():
        if target.resolve() != target or receipt_path.resolve() != receipt_path:
            raise ValueError('Symlink receipt/archive refused')
        receipt = json.loads(receipt_path.read_bytes())
        if receipt['platform_digest'] != MANIFEST or receipt['sha256'] != sha(target) or receipt['bytes'] != target.stat().st_size:
            raise ValueError('Existing scanner archive differs')
        return receipt
    if shutil.disk_usage(root).free < sum(records.values()) + 6 * 1024**3:
        raise ValueError('Need archive space plus 6 GiB headroom')
    with tarfile.open(target, 'x') as archive:
        desc = {'mediaType': manifest['mediaType'], 'digest': MANIFEST, 'size': records[MANIFEST],
                'platform': {'os': 'linux', 'architecture': 'amd64'},
                'annotations': {'io.containerd.image.name': 'docker.io/' + ALIAS, 'org.opencontainers.image.ref.name': ALIAS}}
        for name, value in [('oci-layout', {'imageLayoutVersion': '1.0.0'}),
                            ('index.json', {'schemaVersion': 2, 'manifests': [desc]})]:
            raw = json.dumps(value, separators=(',', ':')).encode()
            entry = tarfile.TarInfo(name); entry.size = len(raw); entry.mode = 0o444
            archive.addfile(entry, io.BytesIO(raw))
        for digest, size in sorted(records.items()):
            entry = tarfile.TarInfo('blobs/sha256/' + digest[7:]); entry.size = size; entry.mode = 0o444
            with (blobs / digest[7:]).open('rb') as stream:
                archive.addfile(entry, stream)
    receipt = {'schema': 1, 'source': SOURCE, 'platform_digest': MANIFEST, 'config_digest': CONFIG,
               'archive_tag': ALIAS, 'path': target.name, 'sha256': sha(target), 'bytes': target.stat().st_size,
               'platform': 'linux/amd64', 'volumes': sorted(config['config'].get('Volumes') or {}),
               'user': config['config'].get('User'), 'entrypoint': config['config'].get('Entrypoint'),
               'cmd': config['config'].get('Cmd'), 'expected_adapter_version': '0.38.0',
               'expected_trivy_version': '0.72.0', 'harbor_core_version_unchanged': '2.13.2',
               'formal_admission': False, 'provenance': 'Official stable GHCR manifest/blob SHA256; publisher signature not verified'}
    with receipt_path.open('x') as stream:
        json.dump(receipt, stream, indent=2); stream.write('\n')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(); root = args.root.expanduser().absolute()
    if root.resolve() != root:
        raise ValueError('Nonsymlink material directory required')
    if not args.apply:
        print(json.dumps({'dry_run': True, 'root': str(root), 'source': SOURCE, 'digest': MANIFEST,
                          'harbor_core_version': '2.13.2', 'starts_services': False})); return
    root.mkdir(parents=True, exist_ok=True)
    if (root / '.prepare.lock').resolve() != root / '.prepare.lock':
        raise ValueError('Symlink lock refused')
    with (root / '.prepare.lock').open('a') as guard:
        fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps(prepare(root), indent=2))


if __name__ == '__main__':
    main()
