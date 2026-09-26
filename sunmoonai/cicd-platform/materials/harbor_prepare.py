#!/usr/bin/env python3
"""Read-only recovery preparation. Does not stop Harbor or back up live volumes."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess as sp
import tarfile

KUBE = ['kubectl', '--kubeconfig', '/home/zymun/.kube/kind-config']
NS = 'cicd-platform-dev'
RELEASE = 'sunmoonai-harbor'


def run(args):
    result = sp.run(args, capture_output=True, timeout=120)
    if result.returncode:
        raise RuntimeError('Read-only preparation command failed: ' + args[0])
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = args.output.expanduser()
    os.umask(0o077)
    root.mkdir(parents=True, exist_ok=False, mode=0o700)
    if shutil.disk_usage(root).free < 20 * 1024**3:
        raise RuntimeError('Insufficient disk reserve')
    for name in ('private', 'images', 'charts'):
        (root / name).mkdir(mode=0o700)
    resources = json.loads(run(KUBE + ['-n', NS, 'get',
        'deployment,statefulset,service,configmap,secret,serviceaccount,role,rolebinding,networkpolicy,ingress,pvc,pdb,hpa', '-o', 'json']))['items']
    def owned(obj):
        m = obj['metadata']
        return (m.get('labels', {}).get('app.kubernetes.io/instance') == RELEASE
                or m['name'].startswith(('sunmoonai-harbor', 'harbor-sunmoonai', 'sh.helm.release.v1.sunmoonai-harbor.')))
    selected = [obj for obj in resources if owned(obj)]
    names = set()
    def references(obj):
        if isinstance(obj, dict):
            for key, value in obj.items():
                if key in ('secretName', 'serviceAccountName') and isinstance(value, str):
                    names.add(value)
                if key in ('secretRef', 'secretKeyRef', 'configMapRef', 'configMapKeyRef', 'configMap', 'secret') and isinstance(value, dict):
                    names.add(value.get('name', value.get('secretName', '')))
                if key == 'imagePullSecrets':
                    names.update(v['name'] for v in value)
                references(value)
        elif isinstance(obj, list):
            for value in obj: references(value)
    while True:
        references(selected)
        extra = [obj for obj in resources if obj['metadata']['name'] in names and obj not in selected]
        if not extra: break
        selected.extend(extra)
    volumes = {obj['spec']['volumeName'] for obj in selected if obj['kind'] == 'PersistentVolumeClaim'}
    pvs = json.loads(run(KUBE + ['get', 'pv', '-o', 'json']))['items']
    selected.extend(obj for obj in pvs if obj['metadata']['name'] in volumes)
    selected.append(json.loads(run(KUBE + ['get', 'namespace', NS, '-o', 'json'])))
    (root / 'private/resources.json').write_text(json.dumps({'apiVersion': 'v1', 'kind': 'List', 'items': selected}, indent=2) + '\n')
    for action, filename, extra in [('values', 'helm-values.yaml', ['--all']), ('manifest', 'helm-manifest.yaml', [])]:
        (root / 'private' / filename).write_bytes(run(['helm', '--kubeconfig', '/home/zymun/.kube/kind-config',
             'get', action, RELEASE, '-n', NS] + extra))
    chart = Path(__file__).resolve().parents[1] / 'harbor/resources/harbor'
    with tarfile.open(root / 'charts/harbor-27.0.3-source.tar', 'w') as archive:
        archive.add(chart, arcname='harbor', recursive=True)
    pods = json.loads(run(KUBE + ['-n', NS, 'get', 'pods', '-o', 'json']))['items']
    images, seen = {}, set()
    for pod in pods:
        if not owned(pod): continue
        node = pod['spec']['nodeName']
        for c in pod['spec'].get('initContainers', []) + pod['spec']['containers']:
            if c['image'] not in seen:
                seen.add(c['image'])
                images.setdefault(node, []).append(c['image'])
    index = {'created_at': dt.datetime.now(dt.timezone.utc).isoformat(),
             'status': 'recovery inputs only; volume backup NOT performed',
             'resources': [{'kind': o['kind'], 'name': o['metadata']['name']} for o in selected],
             'bootstrap_images': images, 'artifacts': []}
    (root / 'preparation.json').write_text(json.dumps(index, indent=2) + '\n')
    for node, refs in images.items():
        target = root / 'images' / (node + '-harbor-amd64.tar')
        with target.with_suffix('.tar.partial').open('wb') as stream:
            proc = sp.run(['docker', 'exec', node, 'ctr', '-n', 'k8s.io', 'images', 'export',
                           '--platform', 'linux/amd64', '--skip-manifest-json', '-', *refs],
                          stdout=stream, stderr=sp.PIPE, timeout=600)
        if proc.returncode:
            raise RuntimeError('Node image export failed; partial file retained: ' + node)
        target.with_suffix('.tar.partial').rename(target)
        print('Exported bootstrap images from', node, 'count', len(refs), flush=True)
    for p in sorted(root.rglob('*')):
        if p.is_file() and p.name != 'preparation.json':
            h = hashlib.sha256()
            with p.open('rb') as stream:
                for chunk in iter(lambda: stream.read(1024**2), b''): h.update(chunk)
            index['artifacts'].append({'path': str(p.relative_to(root)), 'bytes': p.stat().st_size, 'sha256': h.hexdigest()})
    (root / 'preparation.json').write_text(json.dumps(index, indent=2) + '\n')
    print('Prepared', len(selected), 'resource records and', len(seen), 'bootstrap image references')
    print('Private recovery inputs:', root)


if __name__ == '__main__':
    main()
