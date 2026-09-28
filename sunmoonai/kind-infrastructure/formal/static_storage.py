#!/usr/bin/env python3
"""Render/ensure static storage for the approved formal KIND identity.

Default renders only. Apply creates missing resources, never patches existing
volumes/claims or deletes data. This is a KIND adapter, not cloud storage setup.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess

import yaml
from configuration import CONFIG, unique_fields

ROOT = Path(__file__).resolve().parents[3]
NODE_ROLES = ('control-plane', 'worker', 'worker2')
NODES = [CONFIG['cluster'] + '-' + role for role in NODE_ROLES]
COMPONENTS = ('postgresql', 'redis', 'redis-nodebull', 'mongodb', 'neo4j', 'object-storage', 'casdoor')
UUID = re.compile(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}')


class StorageError(RuntimeError):
    pass


def run(command, content=None):
    environment = {k: v for k, v in os.environ.items() if not k.startswith('DOCKER_')}
    result = subprocess.run(command, input=content, text=True, capture_output=True,
                            env=environment, timeout=30)
    if result.returncode:
        raise StorageError('Storage command failed; no fallback, patch or cleanup: ' + Path(command[0]).name)
    return result.stdout


def docker(*args):
    return run(['docker', '--host', 'unix:///var/run/docker.sock', *args])


def node_for(component):
    path = Path(os.environ.get('SUNMOON_KIND_STORAGE_CONFIG') or Path(__file__).with_name('static-storage.json'))
    if not path.is_absolute() or path.resolve() != path or not path.is_file():
        raise StorageError('Use an absolute regular storage profile without symlinks')
    data = json.loads(path.read_text(), object_pairs_hook=unique_fields)
    if (set(data) != {'schema', 'nodes'} or type(data['schema']) is not int or data['schema'] != 1
            or not isinstance(data['nodes'], dict) or set(data['nodes']) != set(COMPONENTS)
            or any(value not in ('worker', 'worker2') for value in data['nodes'].values())):
        raise StorageError('Storage profile must explicitly map every component to a worker')
    return CONFIG['cluster'] + '-' + data['nodes'][component]


def resources(component, namespace, node):
    parent = ('app-platform/auth-app/casdoor' if component == 'casdoor'
              else 'data-platform/' + ('redis' if component == 'redis-nodebull' else component))
    suffix = '-kind-pv.yaml' if component == 'object-storage' else '-kind-pv-pvc.yaml'
    path = ROOT / 'sunmoonai' / parent / 'resources/custom-values' / (component + suffix)
    documents = [d for d in yaml.safe_load_all(path.read_text()) if d]
    if [d.get('kind') for d in documents] != (
            ['PersistentVolume'] if component == 'object-storage' else ['PersistentVolume', 'PersistentVolumeClaim']):
        raise StorageError('Expected the component static PV and optional PVC only')
    pv = documents[0]
    spec = pv['spec']
    if (pv.get('apiVersion') != 'v1' or spec['hostPath']['path'] != '/data/kind-local-storage/' + component
            or spec['hostPath'].get('type') not in ('Directory', 'DirectoryOrCreate')
            or spec['persistentVolumeReclaimPolicy'] != 'Retain'):
        raise StorageError('Static path/type/Retain contract differs')
    expression = spec['nodeAffinity']['required']['nodeSelectorTerms']
    if expression != [{'matchExpressions': [{'key': 'kubernetes.io/hostname', 'operator': 'In',
                                             'values': ['__KIND_STATIC_NODE__']}]}]:
        raise StorageError('Static template must contain exactly the managed node placeholder')
    expression[0]['matchExpressions'][0]['values'] = [node]
    if len(documents) == 2:
        pvc = documents[1]
        if pvc.get('apiVersion') != 'v1' or pvc['spec']['volumeName'] != pv['metadata']['name']:
            raise StorageError('PVC must explicitly select its own PV')
        pvc['metadata']['namespace'] = namespace
        spec['claimRef'] = {'name': pvc['metadata']['name'], 'namespace': namespace}
    if component == 'object-storage':
        documents.insert(0, {'apiVersion': 'storage.k8s.io/v1', 'kind': 'StorageClass',
                            'metadata': {'name': spec['storageClassName']},
                            'provisioner': 'kubernetes.io/no-provisioner',
                            'reclaimPolicy': 'Retain', 'volumeBindingMode': 'Immediate'})
    return documents


class Target:
    def __init__(self, args):
        self.args = args
        self.kubeconfig = Path(args.kubeconfig or '')
        self.tool = Path(args.kubectl or '')
        if (not UUID.fullmatch(args.expected_uid or '')
                or not self.kubeconfig.is_absolute() or not self.kubeconfig.is_file()
                or self.kubeconfig.resolve() != Path(CONFIG['kubeconfig']).resolve()
                or not self.tool.is_absolute() or not self.tool.is_file() or not os.access(self.tool, os.X_OK)):
            raise StorageError('Explicit formal kubeconfig, executable kubectl and expected UID required')
        self.config_hash = hashlib.sha256(self.kubeconfig.read_bytes()).hexdigest()
        self.observed = {}
        self.identity()

    def kubectl(self, *args, content=None):
        if hashlib.sha256(self.kubeconfig.read_bytes()).hexdigest() != self.config_hash:
            raise StorageError('Kubeconfig changed during storage preparation')
        return run([str(self.tool), '--kubeconfig', str(self.kubeconfig), '--request-timeout=15s', *args], content)

    def identity(self):
        uid = self.kubectl('get', 'ns', 'kube-system', '-o', 'jsonpath={.metadata.uid}')
        if uid != self.args.expected_uid:
            raise StorageError('Cluster UID mismatch')

    def mounts(self):
        nodes = json.loads(self.kubectl('get', 'nodes', '-o', 'json'))['items']
        if {n['metadata']['name'] for n in nodes} != set(NODES):
            raise StorageError('Target must be the three approved formal KIND nodes')
        for node in nodes:
            if (not node.get('spec', {}).get('providerID', '').startswith('kind://')
                    or node['metadata'].get('labels', {}).get('kubernetes.io/hostname') != node['metadata']['name']
                    or not any(c['type'] == 'Ready' and c['status'] == 'True'
                               for c in node.get('status', {}).get('conditions', []))):
                raise StorageError('Formal nodes must have matching hostnames and be Ready KIND nodes')
        containers = json.loads(docker('inspect', *NODES))
        if {c['Name'].lstrip('/') for c in containers} != set(NODES):
            raise StorageError('Docker node set differs')
        identities = set()
        for container in containers:
            name = container['Name'].lstrip('/')
            role = name.removeprefix(CONFIG['cluster'] + '-')
            if (not container['State']['Running']
                    or container['Config'].get('Labels', {}).get('io.x-k8s.kind.cluster') != CONFIG['cluster']):
                raise StorageError('Formal Docker node identity differs')
            for directory, target in (('static', '/data/kind-local-storage'),
                                      ('local-path', '/var/local-path-provisioner')):
                source = Path('/data/kind-clusters') / CONFIG['cluster'] / role / directory
                matches = [m for m in container['Mounts'] if m['Destination'] == target]
                if (len(matches) != 1 or matches[0]['Type'] != 'bind' or not matches[0]['RW']
                        or matches[0]['Source'] != str(source) or source.resolve() != source):
                    raise StorageError('A formal node storage bind is missing or differs')
                uuid = run(['findmnt', '-n', '-o', 'UUID', '-T', str(source)]).strip()
                if uuid != CONFIG['storage_uuid']:
                    raise StorageError('Formal node data is not on the approved data disk')
                info = source.stat()
                if not stat.S_ISDIR(info.st_mode) or (info.st_dev, info.st_ino) in identities:
                    raise StorageError('Each of the six storage roots must be an independent directory')
                identities.add((info.st_dev, info.st_ino))
                space = os.statvfs(source)
                if space.f_flag & os.ST_RDONLY:
                    raise StorageError('Data disk is read-only')
                if space.f_bavail * space.f_frsize < CONFIG['limits']['data_reserve_gib'] * 1024**3:
                    raise StorageError('Data disk is below the configured free reserve')
                if any(m['Destination'].startswith(target + '/') for m in container['Mounts']):
                    raise StorageError('An extra Docker mount hides part of the admitted storage root')
                actual = docker('exec', name, 'stat', '-c', '%d:%i', target).strip()
                if actual != f'{info.st_dev}:{info.st_ino}':
                    raise StorageError('Container storage bind differs from the current host mount')

    def existing(self, desired):
        kind, meta = desired['kind'], desired['metadata']
        args = ['get', kind, meta['name'], '--ignore-not-found', '-o', 'json']
        if kind == 'PersistentVolumeClaim':
            args += ['-n', meta['namespace']]
        raw = self.kubectl(*args)
        if not raw.strip():
            self.observed.pop((kind, meta['name']), None)
            return False
        actual = json.loads(raw)
        self.observed[(kind, meta['name'])] = actual
        if (actual['metadata'].get('deletionTimestamp')
                or actual['metadata'].get('annotations', {}).get('sunmoonai.com/storage-cluster-uid') != self.args.expected_uid
                or actual.get('status', {}).get('phase') in ('Released', 'Failed', 'Lost')
                or actual.get('spec', {}).get('volumeMode', 'Filesystem') != 'Filesystem'):
            raise StorageError('Existing storage is unmanaged, terminating or unsafe to reuse')
        claim = actual.get('spec', {}).get('claimRef')
        if claim and claim.get('namespace') != self.args.namespace:
            raise StorageError('Existing PV is reserved for another namespace')
        if kind == 'StorageClass':
            if any(actual.get(key) != desired[key] for key in ('provisioner', 'reclaimPolicy', 'volumeBindingMode')):
                raise StorageError('Existing static StorageClass differs')
            return True
        for key, value in desired['spec'].items():
            observed = actual['spec'].get(key, '' if key == 'storageClassName' else None)
            if key == 'claimRef' and isinstance(observed, dict):
                observed = {field: observed.get(field) for field in ('name', 'namespace')}
            if observed != value:
                raise StorageError('Existing storage spec differs; migration requires a separate decision')
        return True


def ensure(args, docs, node):
    target = Target(args)
    target.kubectl('get', 'namespace', args.namespace, '-o', 'name')
    target.mounts()
    role = node.removeprefix(CONFIG['cluster'] + '-')
    host_path = Path('/data/kind-clusters') / CONFIG['cluster'] / role / 'static' / args.component
    if host_path.resolve() != host_path or host_path.is_symlink():
        raise StorageError('Component storage path must not follow a symlink')
    if host_path.exists():
        info = host_path.stat()
        actual = docker('exec', node, 'stat', '-c', '%d:%i', '/data/kind-local-storage/' + args.component).strip()
        if not stat.S_ISDIR(info.st_mode) or actual != f'{info.st_dev}:{info.st_ino}':
            raise StorageError('Existing component directory differs between host and node')
    for document in docs:
        document['metadata'].setdefault('annotations', {})['sunmoonai.com/storage-cluster-uid'] = args.expected_uid
    # Inspect all existing resources before any writes, including directory preparation.
    known = [target.existing(document) for document in docs]
    for document in docs:
        if document['kind'] != 'PersistentVolume' or 'claimRef' not in document['spec']:
            continue
        pv = target.observed.get(('PersistentVolume', document['metadata']['name']), {})
        claim_uid = pv.get('spec', {}).get('claimRef', {}).get('uid')
        pvc_name = document['spec']['claimRef']['name']
        pvc = target.observed.get(('PersistentVolumeClaim', pvc_name), {})
        if claim_uid and claim_uid != pvc.get('metadata', {}).get('uid'):
            raise StorageError('PV claim UID differs; never reclaim or rebind automatically')
    if args.component == 'object-storage':
        target.identity()
        # Only a newly created directory is chowned. Existing data is never recursively touched.
        docker('exec', node, 'sh', '-eu', '-c',
               'p=/data/kind-local-storage/object-storage; test ! -L "$p"; '
               'if test -e "$p"; then test -d "$p"; '
               'test "$(stat -c %u:%g:%a "$p")" = 1000:1000:770; '
               'else mkdir -m 0770 "$p"; chown 1000:1000 "$p"; fi')
    results = []
    for document, exists in zip(docs, known):
        target.identity()
        if not exists:
            target.kubectl('create', '-f', '-', content=json.dumps(document))
        if not target.existing(document):
            raise StorageError('Storage resource is absent after ensure')
        results.append({'kind': document['kind'], 'name': document['metadata']['name'],
                        'action': 'reused' if exists else 'created'})
    print(json.dumps({'node': node, 'resources': results, 'data_deleted': False}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', nargs='?', default='render', choices=('render', 'node', 'ensure'))
    parser.add_argument('--component', required=True, choices=COMPONENTS)
    parser.add_argument('--namespace', required=True)
    parser.add_argument('--kubeconfig')
    parser.add_argument('--kubectl')
    parser.add_argument('--expected-uid')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', args.namespace):
        raise StorageError('Invalid namespace')
    if args.apply and args.action != 'ensure':
        raise StorageError('Only ensure accepts apply')
    node = node_for(args.component)
    docs = resources(args.component, args.namespace, node)
    if args.action == 'node':
        print(node)
    elif args.apply:
        ensure(args, docs, node)
    else:
        print(yaml.safe_dump_all(docs, sort_keys=False), end='')


if __name__ == '__main__':
    try:
        main()
    except StorageError as error:
        raise SystemExit('Static storage stopped: ' + str(error)) from None
    except (OSError, ValueError, TypeError, KeyError, AttributeError, yaml.YAMLError,
            subprocess.SubprocessError) as error:
        raise SystemExit('Static storage stopped: ' + type(error).__name__ +
                         '; partial new resources may remain; no automatic cleanup') from None
