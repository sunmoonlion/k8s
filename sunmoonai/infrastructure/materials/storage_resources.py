"""Shared local-path storage rendering and additive installation.

Cloud 未经实机验证. Existing platform versions, explicit OCI archives, Retain.
No CSI placeholder success, destructive recovery or automatically created PVCs.
"""
import hashlib
import json
from pathlib import Path
import re
import time

from bundle import below, read_lock


NAMESPACE = 'sunmoon-local-storage'
PROVISIONER = 'sunmoonai.com/local-path'


def images(manifest, data):
    child = data['storage_image_lock']
    lock = read_lock(below(manifest.parent, child['path']), child['sha256'])
    if lock['complete'] is not True or lock['platform'] != 'linux/amd64':
        raise ValueError('Storage images incomplete')
    result = lock['images']
    if {(i['name'], i['version']) for i in result} != {
            ('local-path-provisioner', 'v0.0.32'), ('os-shell', '12-debian-12-r51')} or len(result) != 2:
        raise ValueError('Storage component version changed outside the approved scope')
    return result


def validate(spec):
    if type(spec['timeout']) is not int or not 1 <= spec['timeout'] <= 600:
        raise ValueError('Storage readiness timeout must be 1..600 seconds')
    if spec['cloud_enabled']:
        raise ValueError('Cloud CSI requires a selected provider, exact materials and a validated profile; no placeholder installation')
    if not spec['local_enabled']:
        raise ValueError('This storage profile requires explicit local storage enablement')
    if spec['version'] != 'v0.0.32' or spec['helper'] != 'bitnami/os-shell:12-debian-12-r51' or spec['pull_policy'] != 'Never':
        raise ValueError('Storage versions/pull policy differ from the existing offline material lock')
    if spec['reclaim'] != 'Retain' or spec['binding'] != 'WaitForFirstConsumer':
        raise ValueError('Storage requires Retain and WaitForFirstConsumer')
    if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', spec['class_name']):
        raise ValueError('Invalid StorageClass name')
    names = {n['name'] for n in spec['expected']['nodes']}
    if set(spec['paths']) != names or not any(n['enabled'] for n in spec['paths'].values()):
        raise ValueError('Explicit storage eligibility is required for every node')
    for node in spec['paths'].values():
        mount, path = Path(node['mountpoint']), Path(node['path'])
        if (not re.fullmatch(r'/[A-Za-z0-9_/-]+', str(path)) or '..' in path.parts
                or not re.fullmatch(r'/[A-Za-z0-9_/-]+', str(mount)) or '..' in mount.parts
                or str(path) != node['path'] or str(mount) != node['mountpoint']
                or not path.is_relative_to(mount) or path == mount or mount == Path('/')):
            raise ValueError('Storage path must be a normalized child of an explicit data mount')
        if any(path == p or p in path.parents or path in p.parents for p in (
                Path('/data/kind-local-storage'), Path('/data/harbor'), Path('/var/lib/docker'),
                Path('/var/lib/kubelet'), Path('/var/lib/containerd'), Path('/etc'))):
            raise ValueError('Dynamic storage overlaps a protected/static data path')
    return spec


def render(spec, image_records, uid):
    validate(spec)
    refs = {i['name']: i['reference'] for i in image_records}
    account = 'sunmoon-local-path'
    labels = {'app.kubernetes.io/name': account}
    objects = []

    def obj(kind, name, api='v1', namespaced=True, **body):
        meta = {'name': name, 'labels': {'sunmoonai.com/storage-uid': uid}}
        if namespaced:
            meta['namespace'] = NAMESPACE
        value = {'apiVersion': api, 'kind': kind, 'metadata': meta, **body}
        meta['annotations'] = {'sunmoonai.com/storage-spec-sha256': hashlib.sha256(
            json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()}
        objects.append(value)

    obj('Namespace', NAMESPACE, namespaced=False)
    obj('ServiceAccount', account)
    rbac = 'rbac.authorization.k8s.io/v1'
    obj('Role', account, rbac, rules=[{'apiGroups': [''], 'resources': ['pods'],
                                    'verbs': ['get', 'list', 'watch', 'create', 'patch', 'update', 'delete']}])
    obj('ClusterRole', account, rbac, namespaced=False, rules=[
        {'apiGroups': [''], 'resources': ['nodes', 'persistentvolumeclaims', 'configmaps', 'pods', 'pods/log'], 'verbs': ['get', 'list', 'watch']},
        {'apiGroups': [''], 'resources': ['persistentvolumes'], 'verbs': ['get', 'list', 'watch', 'create', 'patch', 'update', 'delete']},
        {'apiGroups': [''], 'resources': ['events'], 'verbs': ['create', 'patch']},
        {'apiGroups': ['storage.k8s.io'], 'resources': ['storageclasses'], 'verbs': ['get', 'list', 'watch']}])
    for kind, role in [('RoleBinding', 'Role'), ('ClusterRoleBinding', 'ClusterRole')]:
        obj(kind, account, rbac, namespaced=kind == 'RoleBinding',
            roleRef={'apiGroup': 'rbac.authorization.k8s.io', 'kind': role, 'name': account},
            subjects=[{'kind': 'ServiceAccount', 'name': account, 'namespace': NAMESPACE}])
    paths = [{'node': n, 'paths': [p['path']] if p['enabled'] else []} for n, p in sorted(spec['paths'].items())]
    paths.append({'node': 'DEFAULT_PATH_FOR_NON_LISTED_NODES', 'paths': []})
    helper = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': 'helper-pod'}, 'spec': {
        'priorityClassName': 'system-node-critical',
        'tolerations': [{'key': 'node.kubernetes.io/disk-pressure', 'operator': 'Exists', 'effect': 'NoSchedule'}],
        'containers': [{'name': 'helper-pod', 'image': refs['os-shell'], 'imagePullPolicy': 'Never',
                        'securityContext': {'runAsUser': 0, 'allowPrivilegeEscalation': False}}]}}
    obj('ConfigMap', 'local-path-config', data={
        'config.json': json.dumps({'nodePathMap': paths}, sort_keys=True),
        'helperPod.yaml': json.dumps(helper),
        'setup': '#!/bin/sh\nset -eu\nmkdir -m 0777 -p "$VOL_DIR"\n',
        # Retain is mandatory. Even an externally altered Delete policy must
        # not turn this helper into an automatic data removal path.
        'teardown': '#!/bin/sh\necho "Data retained; explicit volume retirement required" >&2\nexit 1\n'})
    obj('StorageClass', spec['class_name'], 'storage.k8s.io/v1', namespaced=False,
        provisioner=PROVISIONER, reclaimPolicy='Retain', volumeBindingMode='WaitForFirstConsumer')
    objects[-1]['metadata']['annotations']['storageclass.kubernetes.io/is-default-class'] = str(spec['default']).lower()
    eligible = [name for name, path in spec['paths'].items() if path['enabled']]
    obj('Deployment', account, 'apps/v1', spec={
        'replicas': 1, 'strategy': {'type': 'Recreate'}, 'selector': {'matchLabels': labels},
        'template': {'metadata': {'labels': labels}, 'spec': {
            'serviceAccountName': account,
            'affinity': {'nodeAffinity': {'requiredDuringSchedulingIgnoredDuringExecution': {'nodeSelectorTerms': [
                {'matchExpressions': [{'key': 'kubernetes.io/hostname', 'operator': 'In', 'values': eligible}]}]}}},
            'containers': [{'name': 'provisioner', 'image': refs['local-path-provisioner'], 'imagePullPolicy': 'Never',
                'command': ['local-path-provisioner', 'start', '--config', '/etc/config/config.json',
                            '--provisioner-name', PROVISIONER, '--service-account-name', account,
                            '--helper-image', refs['os-shell']],
                'env': [{'name': 'POD_NAMESPACE', 'valueFrom': {'fieldRef': {'fieldPath': 'metadata.namespace'}}},
                        {'name': 'CONFIG_MOUNT_PATH', 'value': '/etc/config/'}],
                'resources': {'requests': {'cpu': '10m', 'memory': '32Mi'}, 'limits': {'memory': '128Mi'}},
                'volumeMounts': [{'name': 'config', 'mountPath': '/etc/config/', 'readOnly': True}]}],
            'volumes': [{'name': 'config', 'configMap': {'name': 'local-path-config'}}]}}})
    for value in objects:
        annotations = value['metadata']['annotations']
        annotations.pop('sunmoonai.com/storage-spec-sha256')
        annotations['sunmoonai.com/storage-spec-sha256'] = hashlib.sha256(
            json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return objects


def contains(actual, desired):
    if isinstance(desired, dict):
        return isinstance(actual, dict) and all(k in actual and contains(actual[k], v) for k, v in desired.items())
    if isinstance(desired, list):
        return isinstance(actual, list) and len(actual) == len(desired) and all(contains(a, b) for a, b in zip(actual, desired))
    return actual == desired


def preflight(kub, objects, spec):
    classes = json.loads(kub('get', 'storageclasses', '-o', 'json'))['items']
    for storage_class in classes:
        if storage_class['metadata']['name'] == spec['class_name']:
            effective_default = any(storage_class['metadata'].get('annotations', {}).get(key) == 'true' for key in (
                'storageclass.kubernetes.io/is-default-class', 'storageclass.beta.kubernetes.io/is-default-class'))
            if effective_default != spec['default']:
                raise ValueError('Existing StorageClass default semantics differ; retained')
    if spec['default'] and any(c['metadata']['name'] != spec['class_name'] and any(
            c['metadata'].get('annotations', {}).get(k) == 'true' for k in (
                'storageclass.kubernetes.io/is-default-class', 'storageclass.beta.kubernetes.io/is-default-class')) for c in classes):
        raise ValueError('Another default StorageClass exists; will not change its annotation')
    missing = []
    for obj in objects:
        argv = ['get', obj['kind'], obj['metadata']['name'], '--ignore-not-found', '-o', 'json']
        if obj['metadata'].get('namespace'):
            argv += ['-n', obj['metadata']['namespace']]
        raw = kub(*argv)
        if raw.strip():
            actual = json.loads(raw)
            if actual['metadata'].get('deletionTimestamp') or not contains(actual, obj):
                raise ValueError('Existing storage resource differs; retained: ' + obj['kind'] + '/' + obj['metadata']['name'])
        else:
            missing.append(obj)
    return missing


def execute(kub, spec, records, uid, check_only=False):
    objects = render(spec, records, uid)
    missing = preflight(kub, objects, spec)
    if check_only:
        return {'storage_preflight': True, 'missing_objects': len(missing)}
    for obj in missing:
        kub('create', '-f', '-', content=json.dumps(obj).encode())
    deadline = time.monotonic() + spec['timeout']
    while True:
        obj = json.loads(kub('-n', NAMESPACE, 'get', 'deployment', 'sunmoon-local-path', '-o', 'json'))
        status = obj.get('status', {})
        if (not obj['metadata'].get('deletionTimestamp') and status.get('observedGeneration', 0) >= obj['metadata']['generation']
                and all(status.get(k, 0) == 1 for k in ('replicas', 'updatedReplicas', 'readyReplicas', 'availableReplicas'))):
            break
        if time.monotonic() >= deadline:
            raise ValueError('Storage provisioner readiness timed out; resources retained for diagnosis')
        time.sleep(min(3, max(0, deadline - time.monotonic())))
    if preflight(kub, objects, spec):
        raise ValueError('Storage resources disappeared during installation')
    return {'storage_ready': True, 'created_objects': len(missing), 'class': spec['class_name'],
            'reclaim': 'Retain', 'data_io_verified': False, 'static_volumes_changed': False}
