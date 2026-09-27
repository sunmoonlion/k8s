#!/usr/bin/env python3
"""Locked OCI image validation/import helpers. Cloud import 未经实机验证.

Reads exact archives; never pulls, replaces conflicting references, or deletes.
Import is called only after the node controller's identity and closure gates.
"""
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile

from bundle import below, read_lock, sha256


def records(manifest, data):
    child = data['kubeadm_image_archive_lock']
    images = read_lock(below(manifest.parent, child['path']), child['sha256'])['images']
    result = [{**i, 'material_path': f"releases/{data['batch']}/{i['path']}"} for i in images]
    result += [{**i, 'material_path': i['material_root_relative_path']}
               for i in data['shared_calico_materials'] if 'source' in i]
    if len(result) != 10 or len({i['source'] for i in result}) != 10:
        raise ValueError('Expected seven kubeadm and three Calico images')
    return result


def inspect_archive(path, item):
    """Verify the amd64 manifest's complete content graph without extraction."""
    if sha256(path) != item['sha256'] or path.stat().st_size != item['bytes']:
        raise ValueError('Archive identity differs: ' + item['source'])
    with tarfile.open(path, 'r:*') as archive:
        members = archive.getmembers()
        names = {m.name: m for m in members}
        if len(names) != len(members):
            raise ValueError('Duplicate tar members')
        required = {}

        def blob(digest, expected_size=None, json_data=False):
            if not re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
                raise ValueError('Unsupported OCI digest')
            name = 'blobs/sha256/' + digest[7:]
            member = names.get(name)
            if member is None or not member.isfile() or (expected_size is not None and member.size != expected_size):
                raise ValueError('Missing/non-regular/wrong-sized OCI blob')
            if json_data and member.size > 4 * 1024 * 1024:
                raise ValueError('Oversized image metadata')
            with archive.extractfile(member) as stream:
                if json_data:
                    raw = stream.read()
                    actual = hashlib.sha256(raw).hexdigest()
                else:
                    actual = hashlib.file_digest(stream, 'sha256').hexdigest()
            if actual != digest[7:]:
                raise ValueError('OCI content digest mismatch')
            required[name] = member.size
            return json.loads(raw) if json_data else None

        manifest = blob(item['platform_digest'], json_data=True)
        config = manifest['config']
        if item.get('config_digest', config['digest']) != config['digest']:
            raise ValueError('Locked image config differs')
        cfg = blob(config['digest'], config['size'], True)
        if cfg.get('os') != 'linux' or cfg.get('architecture') != 'amd64':
            raise ValueError('Image is not linux/amd64')
        for layer in manifest['layers']:
            blob(layer['digest'], layer['size'])
        return {'source': item['source'], 'platform_digest': item['platform_digest'],
                'config_digest': config['digest'], 'manifest_media_type': manifest['mediaType'],
                'blobs': required, 'layers': len(manifest['layers'])}


def write_import_archive(source, target, item, graph):
    """Root-owned OCI archive with only the verified platform and exact name."""
    descriptor = {'mediaType': graph['manifest_media_type'], 'digest': item['platform_digest'],
                  'size': graph['blobs']['blobs/sha256/' + item['platform_digest'][7:]],
                  'platform': {'os': 'linux', 'architecture': 'amd64'},
                  'annotations': {'io.containerd.image.name': item['source'],
                                  'org.opencontainers.image.ref.name': item['source']}}
    # Never rewrite the original archive or extract paths supplied by it.
    with source.open('rb') as raw:
        if hashlib.file_digest(raw, 'sha256').hexdigest() != item['sha256']:
            raise ValueError('Source changed before import staging')
        raw.seek(0)
        with tarfile.open(fileobj=raw) as original, target.open('xb') as output, tarfile.open(fileobj=output, mode='w') as staged:
            for name, value in [('oci-layout', {'imageLayoutVersion': '1.0.0'}),
                                ('index.json', {'schemaVersion': 2, 'manifests': [descriptor]})]:
                content = json.dumps(value, separators=(',', ':')).encode()
                header = tarfile.TarInfo(name); header.size = len(content); header.mode = 0o444
                staged.addfile(header, io.BytesIO(content))
            for name, size in graph['blobs'].items():
                member = original.getmember(name)
                if not member.isfile() or member.size != size:
                    raise ValueError('Source changed during staging')
                header = tarfile.TarInfo(name); header.size = size; header.mode = 0o444
                with original.extractfile(member) as stream:
                    staged.addfile(header, stream)
    target.chmod(0o400)
    # Re-read staged blobs before containerd gets the file; closes source races.
    staged_item = {**item, 'sha256': sha256(target), 'bytes': target.stat().st_size}
    inspect_archive(target, staged_item)


def ctr(*args):
    result = subprocess.run(['/usr/local/bin/ctr', '--address', '/run/containerd/containerd.sock',
                             '--namespace', 'k8s.io', *args], check=True, capture_output=True, timeout=300)
    return result.stdout


def references():
    result = {}
    for line in ctr('images', 'list').decode().splitlines()[1:]:
        columns = line.split()
        if len(columns) < 3 or not re.fullmatch(r'sha256:[0-9a-f]{64}', columns[2]):
            raise ValueError('Unexpected ctr image listing format')
        result[columns[0]] = columns[2]
    return result


def import_images(root, manifest, data, work):
    items = records(manifest, data)
    graphs = [inspect_archive(below(root, i['material_path']), i) for i in items]
    existing = references()
    for item in items:
        for name in (item['source'], item['reference']):
            if name in existing and existing[name] != item['platform_digest']:
                raise ValueError('Conflicting image reference retained: ' + name)
    for item, graph in zip(items, graphs):
        stage = work / ('image-' + item['platform_digest'][7:] + '.tar')
        if stage.resolve() != stage:
            raise ValueError('Symlinked image stage')
        if stage.exists():
            if stage.stat().st_uid != 0 or stage.stat().st_mode & 0o077:
                raise ValueError('Image stage must be root private')
            # Metadata identity is checked again; content must be the original
            # locked platform, regardless of the transport archive encoding.
            inspect_archive(stage, {**item, 'sha256': sha256(stage), 'bytes': stage.stat().st_size})
        else:
            write_import_archive(below(root, item['material_path']), stage, item, graph)
        if item['source'] not in references():
            ctr('images', 'import', '--local', '--platform', 'linux/amd64', '--label', 'io.cri-containerd.image=managed', str(stage))
        actual = references()
        if actual.get(item['source']) != item['platform_digest']:
            raise ValueError('Imported target descriptor differs')
        if item['reference'] not in actual:
            ctr('images', 'tag', item['source'], item['reference'])
        if references().get(item['reference']) != item['platform_digest']:
            raise ValueError('Digest reference differs after tagging')
        # Read actual stored content, not a Docker image ID or name substring.
        blob = ctr('content', 'get', item['platform_digest'])
        if hashlib.sha256(blob).hexdigest() != item['platform_digest'][7:]:
            raise ValueError('Runtime manifest content differs')
        for name in (item['source'], item['reference']):
            cri = subprocess.run(['/usr/local/bin/crictl', 'inspecti', name],
                                 check=True, capture_output=True, text=True, timeout=60)
            if not json.loads(cri.stdout).get('status', {}).get('id'):
                raise ValueError('CRI cannot resolve imported image')
    return [{'source': i['source'], 'digest': i['platform_digest']} for i in items]
