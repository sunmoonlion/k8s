#!/usr/bin/env python3
"""Read-only verification of an OCI image archive; no extraction or network."""
import argparse
import hashlib
import json
import re
import tarfile
from pathlib import PurePosixPath


def verify(path, expected):
    blobs, documents, names = {}, {}, set()
    index, layout, docker_manifest = None, None, None
    with tarfile.open(path, 'r|*') as archive:
        for member in archive:
            name = member.name.removeprefix('./')
            if member.isdir():
                continue
            if (not member.isfile() or name in names or
                    PurePosixPath(name).is_absolute() or '..' in PurePosixPath(name).parts):
                raise ValueError(f'Unsupported or duplicate archive entry: {name}')
            names.add(name)
            stream = archive.extractfile(member)
            if name.startswith('blobs/'):
                if not re.fullmatch(r'blobs/sha256/[a-f0-9]{64}', name):
                    raise ValueError(f'Unsupported blob identity: {name}')
                digest = hashlib.sha256()
                small = bytearray() if member.size <= 4 * 1024 * 1024 else None
                while chunk := stream.read(1024 * 1024):
                    digest.update(chunk)
                    if small is not None:
                        small.extend(chunk)
                value = 'sha256:' + digest.hexdigest()
                if value != 'sha256:' + name.rsplit('/', 1)[1]:
                    raise ValueError(f'Blob digest mismatch: {name}')
                blobs[value] = member.size
                if small is not None:
                    try:
                        document = json.loads(small)
                        if isinstance(document, dict):
                            documents[value] = document
                    except (ValueError, UnicodeDecodeError):
                        pass
            elif name in ('index.json', 'oci-layout', 'manifest.json'):
                if member.size > 4 * 1024 * 1024:
                    raise ValueError('Oversized archive metadata')
                document = json.load(stream)
                if name == 'index.json':
                    index = document
                elif name == 'oci-layout':
                    layout = document
                else:
                    docker_manifest = document
            elif name != 'repositories':
                raise ValueError(f'Unexpected archive metadata: {name}')
    if not isinstance(layout, dict) or layout.get('imageLayoutVersion') != '1.0.0':
        raise ValueError('Missing or unsupported OCI layout marker')
    if not isinstance(index, dict) or index.get('schemaVersion') != 2:
        raise ValueError('Missing OCI index')
    reachable, manifests = set(), []

    def visit(descriptor):
        digest = descriptor['digest']
        if blobs.get(digest) != descriptor['size']:
            raise ValueError(f'Missing or wrong-size referenced blob: {digest}')
        if digest in reachable:
            return
        reachable.add(digest)
        document = documents.get(digest, {})
        if 'manifests' in document:
            for child in document['manifests']:
                visit(child)
        elif 'config' in document and 'layers' in document:
            visit(document['config'])
            for layer in document['layers']:
                visit(layer)
            config = documents.get(document['config']['digest'], {})
            if config.get('os') != 'linux' or config.get('architecture') != 'amd64':
                raise ValueError(f'Unexpected platform: {digest}')
            diff_ids = config.get('rootfs', {}).get('diff_ids', [])
            if len(diff_ids) != len(document['layers']):
                raise ValueError(f'Layer count mismatch: {digest}')
            for layer, diff_id in zip(document['layers'], diff_ids):
                if layer.get('mediaType') == 'application/vnd.oci.image.layer.v1.tar' and layer['digest'] != diff_id:
                    raise ValueError(f'Uncompressed layer differs from rootfs identity: {digest}')
            manifests.append({'manifest_digest': digest,
                              'config_digest': document['config']['digest'],
                              'layers': len(document['layers'])})

    for descriptor in index.get('manifests', []):
        visit(descriptor)
    if {m['manifest_digest'] for m in manifests} != set(expected):
        raise ValueError('Archive does not contain exactly the expected image manifests')
    for manifest in manifests:
        expected_config = expected[manifest['manifest_digest']]
        if expected_config and manifest['config_digest'] != expected_config:
            raise ValueError('Unexpected image configuration')
    if docker_manifest is not None:
        expected_compatibility = {}
        for digest in expected:
            selected = documents[digest]
            config_path = 'blobs/' + selected['config']['digest'].replace(':', '/')
            expected_compatibility[config_path] = [
                'blobs/' + layer['digest'].replace(':', '/') for layer in selected['layers']]
        if (not isinstance(docker_manifest, list) or len(docker_manifest) != len(manifests) or
                {m.get('Config'): m.get('Layers') for m in docker_manifest} != expected_compatibility):
            raise ValueError('Docker compatibility metadata differs from OCI manifest')
    result = {'format': 'oci', 'verified_blobs': len(blobs)}
    result['image' if len(manifests) == 1 else 'images'] = manifests[0] if len(manifests) == 1 else manifests
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--expected-manifest')
    group.add_argument('--harbor-lock')
    args = parser.parse_args()
    try:
        expected = {args.expected_manifest: None}
        if args.harbor_lock:
            with open(args.harbor_lock, encoding='utf-8') as lock_file:
                lock = json.load(lock_file)
            expected = {m['archive_manifest_digest']: m['config_digest'] for m in lock['images']}
        print(json.dumps(verify(args.archive, expected), sort_keys=True))
    except (ValueError, KeyError, TypeError, OSError, tarfile.TarError) as exc:
        parser.exit(1, f'Archive verification failed: {exc}\n')
