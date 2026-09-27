"""Shared post-bootstrap resource operations; no SSH or implicit kubeconfig.

Both adapters supply the same guarded kubectl callback. Cloud 未经实机验证。
Only missing namespaces and non-conflicting scheduling taints can be created.
Readiness is read-only; no repair, deletion, forced adoption or eviction.
"""
import json
import re
import time


def csv_names(value):
    values = [v.strip() for v in value.split(',')]
    if (not values or len(set(values)) != len(values)
            or any(not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', v) for v in values)):
        raise ValueError('Expected unique DNS-label names separated by commas')
    return values


def namespaces(environments, platforms, policies=False):
    if policies:
        raise ValueError('Namespace policy placeholder has no manifests; cannot claim policies applied')
    result = []
    for environment in csv_names(environments):
        for platform in csv_names(platforms):
            name = platform + '-' + environment
            if len(name) > 63 or name == 'default' or name.startswith('kube-'):
                raise ValueError('Invalid/reserved namespace name')
            result.append({'apiVersion': 'v1', 'kind': 'Namespace', 'metadata': {
                'name': name, 'labels': {'platform': 'sunmoonai', 'component': platform,
                                       'environment': environment, 'tier': platform,
                                       'managed-by': 'infrastructure'}}})
    if len({o['metadata']['name'] for o in result}) != len(result):
        raise ValueError('Namespace combinations collide')
    return result


def taints(value):
    result, keys = [], set()
    if not value.strip():
        return result
    for item in value.split(','):
        key_value, effect = item.strip().rsplit(':', 1)
        # NoExecute can evict existing workloads. It is not a bootstrap action.
        if effect not in ('NoSchedule', 'PreferNoSchedule'):
            raise ValueError('Only NoSchedule/PreferNoSchedule allowed; eviction needs a separate maintenance operation')
        key, _, val = key_value.partition('=')
        parts = key.split('/')
        if len(parts) > 2 or not re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9_.-]{0,61}[A-Za-z0-9])?', parts[-1]):
            raise ValueError('Invalid taint key')
        if len(parts) == 2 and (len(parts[0]) > 253 or any(
                not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', label) for label in parts[0].split('.'))):
            raise ValueError('Invalid taint key prefix')
        if val and not re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9_.-]{0,61}[A-Za-z0-9])?', val):
            raise ValueError('Invalid taint value')
        if (key, effect) in keys:
            raise ValueError('Duplicate taint key/effect')
        keys.add((key, effect))
        result.append({'key': key, 'value': val, 'effect': effect})
    return result


def identity(kub, expected):
    version = json.loads(kub('version', '-o', 'json'))
    if any(version.get(k, {}).get('gitVersion') != expected['version'] for k in ('clientVersion', 'serverVersion')):
        raise ValueError('Client/server Kubernetes version differs from the locked target')
    nodes = json.loads(kub('get', 'nodes', '-o', 'json'))['items']
    wanted = {n['name']: n for n in expected['nodes']}
    if len(wanted) != len(expected['nodes']) or {n['metadata']['name'] for n in nodes} != set(wanted):
        raise ValueError('Node membership differs from the declared cluster')
    for node in nodes:
        desired = wanted[node['metadata']['name']]
        info = node['status']['nodeInfo']
        ips = sorted(a['address'] for a in node['status']['addresses'] if a['type'] == 'InternalIP')
        if (node['metadata'].get('deletionTimestamp') or info['machineID'] != desired['machine_id']
                or info['kubeletVersion'] != expected['version'] or ips != [desired['ip']]):
            raise ValueError('Node machine-id/IP/version differs from declared identity')
    return nodes


def condition(obj, name):
    return any(c['type'] == name and c['status'] == 'True' for c in obj.get('status', {}).get('conditions', []))


def health(kub, expected, timeout):
    deadline = time.monotonic() + timeout
    while True:
        nodes = identity(kub, expected)
        pending = ['node/' + n['metadata']['name'] for n in nodes if not condition(n, 'Ready')]
        for n in nodes:
            if n.get('spec', {}).get('unschedulable') or any(condition(n, c) for c in ('MemoryPressure', 'DiskPressure', 'PIDPressure', 'NetworkUnavailable')):
                pending.append('node-scheduling/' + n['metadata']['name'])
        controllers = json.loads(kub('-n', 'kube-system', 'get', 'deployments,daemonsets', '-o', 'json'))['items']
        required = {('Deployment', 'coredns'), ('Deployment', 'calico-kube-controllers'),
                    ('DaemonSet', 'calico-node'), ('DaemonSet', 'kube-proxy')}
        found = {(o['kind'], o['metadata']['name']) for o in controllers}
        pending += [kind + '/' + name for kind, name in sorted(required - found)]
        for obj in controllers:
            status = obj.get('status', {})
            ready = not obj['metadata'].get('deletionTimestamp') and status.get('observedGeneration', 0) >= obj['metadata']['generation']
            if obj['kind'] == 'Deployment':
                desired = obj['spec'].get('replicas', 1)
                ready = ready and all(status.get(k, 0) == desired for k in ('replicas', 'updatedReplicas', 'readyReplicas', 'availableReplicas'))
                if (obj['kind'], obj['metadata']['name']) in required:
                    ready = ready and desired > 0
            else:
                desired = status.get('desiredNumberScheduled', 0)
                ready = ready and all(status.get(k, 0) == desired for k in ('currentNumberScheduled', 'updatedNumberScheduled', 'numberReady', 'numberAvailable')) and status.get('numberMisscheduled', 0) == 0
                if (obj['kind'], obj['metadata']['name']) in required:
                    ready = ready and desired == len(nodes)
            if not ready:
                pending.append(obj['kind'] + '/' + obj['metadata']['name'])
        pods = json.loads(kub('-n', 'kube-system', 'get', 'pods', '-o', 'json'))['items']
        for pod in pods:
            phase = pod.get('status', {}).get('phase')
            completed_job = phase == 'Succeeded' and any(o.get('kind') == 'Job' for o in pod['metadata'].get('ownerReferences', []))
            if pod['metadata'].get('deletionTimestamp') or not (completed_job or (phase == 'Running' and condition(pod, 'Ready'))):
                pending.append('pod/' + pod['metadata']['name'])
        # Missing mirror pods must not pass a vacuous "all pods Ready" check.
        master = next(n['name'] for n in expected['nodes'] if n['role'] == 'master')
        names = {p['metadata']['name'] for p in pods}
        for component in ('kube-apiserver', 'kube-controller-manager', 'kube-scheduler', 'etcd'):
            if component + '-' + master not in names:
                pending.append('pod/' + component + '-' + master)
        if not pending:
            return {'ready': True, 'node_count': len(nodes), 'system_pod_count': len(pods),
                    'scope': 'nodes and kube-system only; not storage, ingress, registry or application acceptance'}
        if time.monotonic() >= deadline:
            raise ValueError('Cluster readiness timed out: ' + ', '.join(sorted(set(pending))))
        time.sleep(min(3, max(0, deadline - time.monotonic())))


def ensure_namespaces(kub, objects, uid, timeout):
    desired, missing = [], []
    for source in objects:
        obj = json.loads(json.dumps(source))
        obj['metadata']['labels']['sunmoonai.com/cluster-uid'] = uid
        desired.append(obj)
        raw = kub('get', 'namespace', obj['metadata']['name'], '--ignore-not-found', '-o', 'json')
        if not raw.strip():
            missing.append(obj)
        else:
            check_namespace(json.loads(raw), obj)
    # All pre-existing names checked before the first create; no adoption/patch.
    for obj in missing:
        kub('create', '-f', '-', content=json.dumps(obj).encode())
    deadline = time.monotonic() + timeout
    while True:
        active = True
        for obj in desired:
            actual = json.loads(kub('get', 'namespace', obj['metadata']['name'], '-o', 'json'))
            check_namespace(actual, obj)
            active = active and actual.get('status', {}).get('phase') == 'Active'
        if active:
            return {'namespaces': [o['metadata']['name'] for o in desired], 'created': len(missing), 'policies_applied': False}
        if time.monotonic() >= deadline:
            raise ValueError('Namespace activation timed out; retained for inspection')
        time.sleep(min(2, max(0, deadline - time.monotonic())))


def check_namespace(actual, desired):
    meta = actual['metadata']
    if meta.get('deletionTimestamp') or any(meta.get('labels', {}).get(k) != v for k, v in desired['metadata']['labels'].items()):
        raise ValueError('Existing namespace ownership/labels differ: ' + desired['metadata']['name'])


def ensure_taints(kub, expected, desired):
    nodes = identity(kub, expected)
    patches = []
    for node in nodes:
        name = node['metadata']['name']
        current = node.get('spec', {}).get('taints', [])
        merged = list(current)
        for taint in desired.get(name, []):
            match = next((v for v in current if (v['key'], v['effect']) == (taint['key'], taint['effect'])), None)
            if match and match.get('value', '') != taint['value']:
                raise ValueError('Existing taint conflicts; no overwrite: ' + name)
            if not match:
                merged.append(taint)
        if merged != current:
            patches.append((name, [{'op': 'test', 'path': '/metadata/resourceVersion', 'value': node['metadata']['resourceVersion']},
                                   {'op': 'add', 'path': '/spec/taints', 'value': merged}]))
    for name, patch in patches:
        kub('patch', 'node', name, '--type=json', '-p', json.dumps(patch))
    for node in identity(kub, expected):
        actual = node.get('spec', {}).get('taints', [])
        for wanted in desired.get(node['metadata']['name'], []):
            if not any(v['key'] == wanted['key'] and v['effect'] == wanted['effect'] and v.get('value', '') == wanted['value'] for v in actual):
                raise ValueError('Node taint verification failed')
    return {'node_patches': len(patches), 'existing_taints_preserved': True}


def execute(kub, action, spec, uid):
    """kub must verify the pinned cluster UID before EVERY API operation."""
    timeout = spec['timeout']
    if type(timeout) is not int or not 1 <= timeout <= 600:
        raise ValueError('Readiness timeout must be 1..600 seconds')
    if not re.fullmatch(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', uid):
        raise ValueError('Explicit cluster UID required')
    if action == 'namespaces':
        objects = namespaces(spec['environments'], spec['platforms'], spec['policies'])
        return ensure_namespaces(kub, objects, uid, timeout)
    if action == 'health':
        return health(kub, spec['expected'], timeout)
    if action == 'taints':
        if set(spec['taints']) - {n['name'] for n in spec['expected']['nodes']}:
            raise ValueError('Taints target unknown nodes')
        desired = {n: taints(v) for n, v in spec['taints'].items()}
        return ensure_taints(kub, spec['expected'], desired)
    raise ValueError('Unknown shared resource operation')
