#!/usr/bin/env python3
"""Extract the original Trivy image from the admitted cold-backup OCI archive.

Default prints only. No download, Docker import, service change or cleanup.
Cloud installation 未经实机验证; artifact preparation is shared.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import tarfile

SOURCE_SHA = 'eef8fa55e3847e351c1989ccd675c5de4606ca2ee2ed00efc966e27c434b0c61'
INDEX = 'sha256:a87b6dd19800a5e2406a4194a2b431dbda0f05b526496ee7c3aa3fed63dfcde7'
MANIFEST = 'sha256:7c973faed0944ae77350605ea85d5a9d592fd1258e5bd0ad6f3feb701f826d1e'
CONFIG = 'sha256:06e8582c21f1fa03cf855b36bdcf903853f4af12fb3b334839c02477a39200e1'
REFERENCE = 'docker.io/bitnami/harbor-adapter-trivy:2.13.2-debian-12-r2'
ALIAS = 'sunmoon-offline/harbor-trivy:2.13.2-' + MANIFEST[7:23]


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def prepare(source, root):
    if source.resolve() != source or sha(source) != SOURCE_SHA:
        raise ValueError('Original cold-backup image archive differs')
    if root.resolve() != root or root.exists():
        raise ValueError('A new nonsymlink output directory is required')
    if shutil.disk_usage(root.parent).free < 2 * 1024**3:
        raise ValueError('Need 2 GiB artifact preparation headroom')
    root.mkdir(mode=0o750)
    with tarfile.open(source) as src:
        names = src.getnames()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate source archive paths')

        def blob(digest):
            name = 'blobs/' + digest.replace(':', '/')
            member = src.getmember(name)
            if not member.isfile():
                raise ValueError('Expected a regular OCI blob')
            with src.extractfile(member) as stream:
                if 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest() != digest:
                    raise ValueError('OCI blob digest differs')
            return member

        def metadata(digest):
            member = blob(digest)
            if member.size > 1024**2:
                raise ValueError('Unexpected image metadata size')
            return json.load(src.extractfile(member))

        index = metadata(INDEX)
        selected = [x for x in index['manifests'] if x.get('platform') == {'architecture': 'amd64', 'os': 'linux'}]
        if len(selected) != 1 or selected[0]['digest'] != MANIFEST:
            raise ValueError('Original amd64 image identity differs')
        manifest = metadata(MANIFEST)
        if manifest['config']['digest'] != CONFIG:
            raise ValueError('Original config identity differs')
        config = metadata(CONFIG)
        if (config['architecture'], config['os'], config['config'].get('User')) != ('amd64', 'linux', '1001') or config['config'].get('Volumes'):
            raise ValueError('Original platform/user/declared volumes differ')
        descriptors = [manifest['config'], *manifest['layers']]
        members = [blob(MANIFEST)]
        for desc in descriptors:
            member = blob(desc['digest'])
            if member.size != desc['size']:
                raise ValueError('OCI descriptor size differs')
            members.append(member)
        descriptor = {**selected[0], 'annotations': {
            'io.containerd.image.name': 'docker.io/' + ALIAS,
            'org.opencontainers.image.ref.name': ALIAS}}
        archive = root / 'trivy-linux-amd64.tar'
        with tarfile.open(archive, 'x') as out:
            for name, value in [('oci-layout', {'imageLayoutVersion': '1.0.0'}),
                                ('index.json', {'schemaVersion': 2, 'manifests': [descriptor]})]:
                raw = json.dumps(value, separators=(',', ':')).encode()
                entry = tarfile.TarInfo(name); entry.size = len(raw); entry.mode = 0o444
                out.addfile(entry, io.BytesIO(raw))
            for member in members:
                entry = tarfile.TarInfo(member.name); entry.size = member.size; entry.mode = 0o444
                out.addfile(entry, src.extractfile(member))
    receipt = {'schema': 1, 'source': REFERENCE, 'source_archive_sha256': SOURCE_SHA,
               'index_digest': INDEX, 'platform_digest': MANIFEST, 'config_digest': CONFIG,
               'archive_tag': ALIAS, 'path': archive.name, 'bytes': archive.stat().st_size,
               'sha256': sha(archive), 'trivy_version_observed': '0.64.1',
               'adapter_version_reported': 'dev/Unknown', 'volumes': [],
               'provenance': 'Original running KIND image and pinned cold backup; publisher signature not verified',
               'database_included': False, 'scan_verified': False}
    with (root / 'scanner-image.lock.json').open('x') as stream:
        json.dump(receipt, stream, indent=2); stream.write('\n')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if not args.apply:
        print(json.dumps({'dry_run': True, 'source': str(args.source), 'root': str(args.root),
                          'reference': REFERENCE, 'digest': MANIFEST, 'docker_import': False})); return
    print(json.dumps(prepare(args.source.absolute(), args.root.absolute()), indent=2))


if __name__ == '__main__':
    main()
