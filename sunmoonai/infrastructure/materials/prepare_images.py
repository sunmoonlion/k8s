#!/usr/bin/env python3
"""Resolve and archive the locked kubeadm image set on a download host.

Default only prints the plan. --apply uses registry inspection, docker pull/tag/save
only; never starts containers, installs a cluster or cleans host images/volumes.
Cloud cluster deployment remains 未经实机验证.
"""
import argparse
import fcntl
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import time


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def save(path, data):
    temporary = path.with_name(path.name + '.next')
    if temporary.is_symlink() or path.is_symlink():
        raise RuntimeError('Symlink state refused')
    temporary.write_text(json.dumps(data, indent=2) + '\n')
    temporary.replace(path)


def run(root, arguments, timeout=120):
    minimum = 8 if arguments[:2] == ['docker', 'pull'] else 6
    if shutil.disk_usage(root).free < minimum * 1024**3:
        raise RuntimeError(f'Need {minimum} GiB headroom; existing material retained')
    result = subprocess.run(arguments, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError('Public image operation failed: ' + ' '.join(arguments[:4]))
    return result.stdout


def raw_manifest(root, reference, expected):
    raw = run(root, ['docker', 'buildx', 'imagetools', 'inspect', '--raw', reference])
    # CLI may append a newline; accept only a byte representation matching digest.
    for data in [raw, raw.removesuffix(b'\n')]:
        if 'sha256:' + hashlib.sha256(data).hexdigest() == expected:
            return json.loads(data)
    raise RuntimeError('Registry manifest bytes differ from descriptor')


def prepare(root, manifest):
    state_path = root / 'kubeadm-images.lock.json'
    state = json.loads(state_path.read_text()) if state_path.exists() else {
        'schema': 1, 'batch': manifest['batch'], 'sources': manifest['kubeadm_images'],
        'platform': 'linux/amd64', 'images': [], 'complete': False,
    }
    if state['batch'] != manifest['batch'] or state['sources'] != manifest['kubeadm_images']:
        raise RuntimeError('Existing image batch differs; no overwrite')
    for source in state['sources']:
        item = next((i for i in state['images'] if i['source'] == source), None)
        repository = source.rsplit(':', 1)[0]
        if item is None:
            description = run(root, ['docker', 'buildx', 'imagetools', 'inspect', source]).decode()
            digest = re.search(r'^Digest:\s+(sha256:[0-9a-f]{64})\s*$', description, re.MULTILINE)
            if not digest:
                raise RuntimeError('Missing registry index digest')
            index = digest.group(1)
            body = raw_manifest(root, repository + '@' + index, index)
            choices = [m['digest'] for m in body.get('manifests', [])
                       if m.get('platform', {}).get('os') == 'linux'
                       and m.get('platform', {}).get('architecture') == 'amd64']
            if len(choices) != 1:
                raise RuntimeError('Expected one linux/amd64 image manifest')
            platform = choices[0]
            body = raw_manifest(root, repository + '@' + platform, platform)
            name = repository.rsplit('/', 1)[1]
            item = {'source': source, 'index_digest': index, 'platform_digest': platform,
                    'reference': repository + '@' + platform,
                    'config_digest': body['config']['digest'],
                    'archive_tag': 'sunmoon-offline/' + name + ':' + platform[7:23],
                    'path': 'images/' + name + '-linux-amd64.tar'}
            state['images'].append(item)
            save(state_path, state)  # Freeze remote identity before fetching layers.
        target = root / item['path']
        if target.resolve() != target or target.parent != root / 'images':
            raise RuntimeError('Unexpected archive target')
        if target.exists():
            if sha(target) != item.get('sha256'):
                raise RuntimeError('Existing archive lacks matching checksum; preserve it')
            continue
        # First interrupted preparation called this config digest docker_image_id.
        if 'config_digest' not in item:
            item['config_digest'] = item['docker_image_id']
        run(root, ['docker', 'pull', '--platform', 'linux/amd64', item['reference']], timeout=600)
        actual = json.loads(run(root, ['docker', 'image', 'inspect', item['reference']]))[0]
        # Classic Docker exposes the config digest as ID; containerd image store
        # exposes the platform manifest digest. Verify both identities explicitly.
        if (actual['Id'] not in {item['config_digest'], item['platform_digest']}
                or item['reference'] not in actual.get('RepoDigests', [])
                or actual['Architecture'] != 'amd64' or actual['Os'] != 'linux'):
            raise RuntimeError('Pulled image config/platform differs from locked manifest')
        item['docker_image_id'] = actual['Id']
        alias = run(root, ['docker', 'image', 'ls', '--no-trunc', '--format', '{{.ID}}', item['archive_tag']]).decode().strip()
        if alias and alias != actual['Id']:
            raise RuntimeError('Existing archive alias belongs to another image')
        run(root, ['docker', 'tag', item['reference'], item['archive_tag']])
        partial = target.with_name(target.name + '.' + str(time.time_ns()) + '.partial')
        run(root, ['docker', 'save', '--platform', 'linux/amd64', '--output', str(partial), item['archive_tag']], timeout=300)
        with tarfile.open(partial) as archive:
            manifest_file = archive.extractfile('manifest.json')
            exported = json.load(manifest_file)
            if len(exported) != 1 or exported[0].get('RepoTags') != [item['archive_tag']]:
                raise RuntimeError('Unexpected exported image set')
            config = archive.extractfile(exported[0]['Config'])
            if 'sha256:' + hashlib.file_digest(config, 'sha256').hexdigest() != item['config_digest']:
                raise RuntimeError('Exported configuration differs from registry manifest')
        item['sha256'] = sha(partial)
        item['bytes'] = partial.stat().st_size
        save(state_path, state)
        partial.rename(target)
        print('Verified archive ' + source, flush=True)
    state['complete'] = True
    save(state_path, state)
    print(json.dumps({'complete': True, 'images': len(state['images']),
                      'bytes': sum(i['bytes'] for i in state['images']), 'cluster_installed': False}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    if not manifest['kubeadm_images'] or any(not re.fullmatch(r'registry\.k8s\.io/[a-z0-9/_-]+:[a-zA-Z0-9.-]+', i)
                                           for i in manifest['kubeadm_images']):
        raise RuntimeError('Only explicit public kubeadm image references accepted')
    root = args.root.expanduser().absolute()
    if root.resolve() != root:
        raise RuntimeError('Symlink root refused')
    if not args.apply:
        print(json.dumps({'dry_run': True, 'root': str(root), 'images': manifest['kubeadm_images'],
                          'actions': ['resolve', 'pull by digest', 'export', 'hash'], 'install': False})); return
    root.mkdir(parents=True, exist_ok=True)
    images = root / 'images'
    if images.is_symlink():
        raise RuntimeError('Symlink images directory refused')
    images.mkdir(exist_ok=True)
    lock = root / '.image-download.lock'
    if lock.is_symlink():
        raise RuntimeError('Symlink lock refused')
    with lock.open('a') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        prepare(root, manifest)


if __name__ == '__main__':
    main()
