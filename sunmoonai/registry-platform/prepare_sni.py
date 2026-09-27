#!/usr/bin/env python3
"""Prepare the pinned public SNI image as OCI without Docker pull/unpack.

Default prints only. Intended for the authorized Tokyo download relay; no SSH,
credentials from disk, containers, package installation or cleanup. HTTPS only.
"""
import argparse
import fcntl
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import time

SOURCE = 'docker.io/library/nginx:1.30.5-alpine'
INDEX = 'sha256:0985e772fb9f729e6fa0980da05fca5d9c468e870eed43071545afa9d2e27d94'
MANIFEST = 'sha256:8f84ed99befc3891b8f329c5c202785278a2cfb7c25107d57fb2a134a3117433'
BATCH = 'nginx-sni-1.30.5-linux-amd64'
ALIAS = 'sunmoon-offline/nginx-sni:1.30.5-' + MANIFEST[7:23]


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def headroom(root):
    # Direct compressed download + archive: at most 512 MiB each, no unpacking.
    # Existing 8 GiB Docker-pull guard is not used or changed by this method.
    if shutil.disk_usage(root).free < 6 * 1024**3:
        raise ValueError('Need 6 GiB free for direct download/archive')


def curl(url, token='', target=None, maximum=4 * 1024**2):
    args = ['curl', '--fail', '--silent', '--show-error', '--location', '--proto', '=https',
            '--proto-redir', '=https', '--connect-timeout', '15', '--max-time', '180',
            '--retry', '2', '--retry-max-time', '540', '--max-filesize', str(maximum)]
    # Short-lived anonymous pull token stays in stdin, never argv/logs/files.
    headers = 'header = "Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json"\n'
    if token:
        if not re.fullmatch(r'[a-zA-Z0-9_.-]+', token):
            raise ValueError('Unexpected anonymous token encoding')
        headers += 'header = "Authorization: Bearer ' + token + '"\n'
    if target:
        args += ['--output', str(target)]
    result = subprocess.run(args + ['--config', '-', url], input=headers.encode(),
                            capture_output=True, timeout=580)
    if result.returncode:
        raise ValueError('HTTPS public download failed; partial retained, diagnostics withheld')
    return result.stdout


def prepare(root):
    headroom(root)
    blobs = root / 'blobs' / 'sha256'
    blobs.mkdir(parents=True, exist_ok=True)
    if blobs.resolve() != blobs:
        raise ValueError('Symlink blob directory refused')
    token = json.loads(curl('https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/nginx:pull'))['token']
    metadata = {}

    def fetch(digest, size=None, manifest=False):
        if not re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
            raise ValueError('Invalid digest')
        target = blobs / digest[7:]
        if target.is_symlink():
            raise ValueError('Symlink blob refused')
        if not target.exists():
            headroom(root)
            partial = target.with_name(target.name + '.' + str(time.time_ns()) + '.partial')
            curl('https://registry-1.docker.io/v2/library/nginx/' + ('manifests/' if manifest else 'blobs/') + digest,
                 token, partial, size or 4 * 1024**2)
            if sha(partial) != digest[7:] or (size is not None and partial.stat().st_size != size):
                raise ValueError('Downloaded content mismatch; partial retained')
            partial.rename(target)
        if sha(target) != digest[7:] or (size is not None and target.stat().st_size != size):
            raise ValueError('Existing content differs; no overwrite')
        metadata[digest] = target.stat().st_size
        return target

    index = json.loads(fetch(INDEX, manifest=True).read_bytes())
    candidates = [m for m in index['manifests'] if m.get('platform', {}).get('os') == 'linux'
                  and m.get('platform', {}).get('architecture') == 'amd64']
    if len(candidates) != 1 or candidates[0]['digest'] != MANIFEST:
        raise ValueError('Pinned index/amd64 manifest differ')
    manifest = json.loads(fetch(MANIFEST, candidates[0]['size'], True).read_bytes())
    records = [manifest['config'], *manifest['layers']]
    if sum(i['size'] for i in records) > 512 * 1024**2:
        raise ValueError('Image larger than admitted compressed size')
    for record in records:
        fetch(record['digest'], record['size'])
    config = json.loads((blobs / manifest['config']['digest'][7:]).read_bytes())
    if config['os'] != 'linux' or config['architecture'] != 'amd64':
        raise ValueError('Unexpected image architecture')
    descriptor = {**candidates[0], 'annotations': {
        'org.opencontainers.image.ref.name': ALIAS,
        'io.containerd.image.name': 'docker.io/' + ALIAS}}
    archive_path = root / 'nginx-linux-amd64.tar'
    lock_path = root / 'sni-image.lock.json'
    if archive_path.exists() or lock_path.exists():
        previous = json.loads(lock_path.read_text())
        if (previous['platform_digest'] != MANIFEST or previous['sha256'] != sha(archive_path)
                or previous['bytes'] != archive_path.stat().st_size):
            raise ValueError('Existing archive receipt differs; retain and inspect')
        return previous
    headroom(root)
    partial = root / ('nginx-linux-amd64.' + str(time.time_ns()) + '.partial')
    with tarfile.open(partial, 'x') as archive:
        for name, value in [('oci-layout', {'imageLayoutVersion': '1.0.0'}),
                            ('index.json', {'schemaVersion': 2, 'manifests': [descriptor]})]:
            raw = json.dumps(value, separators=(',', ':')).encode()
            info = tarfile.TarInfo(name); info.size = len(raw); info.mode = 0o444
            archive.addfile(info, io.BytesIO(raw))
        for digest, size in sorted(metadata.items()):
            info = tarfile.TarInfo('blobs/sha256/' + digest[7:]); info.size = size; info.mode = 0o444
            with (blobs / digest[7:]).open('rb') as stream:
                archive.addfile(info, stream)
    receipt = {'schema': 1, 'batch': BATCH, 'source': SOURCE, 'index_digest': INDEX,
               'platform_digest': MANIFEST, 'reference': 'docker.io/library/nginx@' + MANIFEST,
               'config_digest': manifest['config']['digest'], 'archive_tag': ALIAS,
               'path': archive_path.name, 'sha256': sha(partial), 'bytes': partial.stat().st_size,
               'nginx_version': '1.30.5', 'layers': len(manifest['layers']),
               'volumes': sorted(config.get('config', {}).get('Volumes') or {}),
               'provenance': 'Official Docker Hub HTTPS pinned index + amd64 manifest; no publisher signature verified'}
    with lock_path.open('x') as stream:
        json.dump(receipt, stream, indent=2); stream.write('\n')
    partial.rename(archive_path)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(); root = args.root.expanduser().absolute()
    if root.resolve() != root:
        raise ValueError('Symlink root refused')
    if not args.apply:
        print(json.dumps({'dry_run': True, 'root': str(root), 'source': SOURCE, 'digest': MANIFEST,
                          'method': 'HTTPS compressed OCI blobs; no Docker pull or unpack', 'minimum_free_gib': 6})); return
    root.mkdir(parents=True, exist_ok=True)
    lock = root / '.download.lock'
    if lock.is_symlink():
        raise ValueError('Symlink lock refused')
    with lock.open('a') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps(prepare(root), indent=2))


if __name__ == '__main__':
    main()
