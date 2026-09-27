"""Shared additive Traefik resource deployment. Cloud 未经实机验证.

Adapters provide a kubectl callback that checks target UID before each API call.
Never adopts/upgrades existing foreign resources, uninstalls Helm, deletes CRDs,
changes host networking, issues certificates or operates Harbor.
"""
import hashlib
import json
import re
import time

from bundle import below, read_lock, verify
from storage_resources import contains
from tls_resources import validate_payload, LABEL

UID_LABEL = 'sunmoonai.com/ingress-cluster-uid'
SPEC_HASH = 'sunmoonai.com/ingress-spec-sha256'
CUSTOM = {'TLSStore': 'tlsstores.traefik.io', 'Middleware': 'middlewares.traefik.io'}
RESOURCES = {**CUSTOM, 'CustomResourceDefinition': 'customresourcedefinitions.apiextensions.k8s.io',
             'ServiceAccount': 'serviceaccounts', 'ClusterRole': 'clusterroles.rbac.authorization.k8s.io',
             'ClusterRoleBinding': 'clusterrolebindings.rbac.authorization.k8s.io',
             'Service': 'services', 'Deployment': 'deployments.apps',
             'IngressClass': 'ingressclasses.networking.k8s.io'}


def clean(value):
    if isinstance(value, dict):
        return {k: clean(v) for k, v in value.items() if v is not None}
    if isinstance(value, list):
        return [clean(v) for v in value]
    return value


def objects(root, manifest, data, profile, uid):
    if profile not in ('dev', 'prod') or not re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', uid):
        raise ValueError('Explicit ingress profile and cluster UID required')
    child = data['ingress_resource_lock']
    lock = read_lock(below(manifest.parent, child['path']), child['sha256'])
    if (lock['traefik_version'] != 'v' + data['versions']['traefik']
            or lock['chart_version'] != data['versions']['traefik_chart']
            or lock['kubernetes_version'] != data['versions']['kubernetes']):
        raise ValueError('Ingress resource versions differ')
    wanted = [i for i in lock['files'] if i['name'] in ('crds.json', profile + '.json')]
    if len(wanted) != 2:
        raise ValueError('Missing ingress resources')
    verify(root, [{'scope': 'ingress', 'path': i['material_path'], 'bytes': i['bytes'], 'sha256': i['sha256']} for i in wanted])
    result = []
    for entry in wanted:
        value = json.loads(below(root, entry['material_path']).read_text())
        if value['kind'] != 'List' or len(value['items']) != entry['objects']:
            raise ValueError('Ingress object count differs')
        result.extend(value['items'])
    result = clean(result)
    if len(result) != 18 or len({(o['kind'], o['metadata'].get('namespace'), o['metadata']['name']) for o in result}) != 18:
        raise ValueError('Expected ten CRDs and eight unique ingress objects')
    for obj in result:
        if obj['kind'] not in RESOURCES or obj['metadata'].get('namespace', 'ingress-platform-' + profile) != 'ingress-platform-' + profile:
            raise ValueError('Unexpected ingress resource kind/namespace')
        meta = obj['metadata']
        meta.setdefault('labels', {})[UID_LABEL] = uid
        meta['labels']['app.kubernetes.io/managed-by'] = 'sunmoon-bootstrap'
        checksum = hashlib.sha256(json.dumps(obj, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        meta.setdefault('annotations', {})[SPEC_HASH] = checksum
    return result


def get(kub, obj):
    args = ['get', RESOURCES[obj['kind']], obj['metadata']['name'], '--ignore-not-found', '-o', 'json']
    if obj['metadata'].get('namespace'):
        args += ['-n', obj['metadata']['namespace']]
    raw = kub(*args)
    return json.loads(raw) if raw.strip() else None


def established(obj):
    return any(c['type'] == 'Established' and c['status'] == 'True' for c in obj.get('status', {}).get('conditions', []))


def preflight(kub, desired, namespace, uid, registry):
    nodes = json.loads(kub('get', 'nodes', '-o', 'json'))['items']
    if not nodes or any(n['metadata'].get('deletionTimestamp') or not any(
            c['type'] == 'Ready' and c['status'] == 'True'
            for c in n.get('status', {}).get('conditions', [])) for n in nodes):
        raise ValueError('All target cluster nodes must be Ready before ingress operations')
    ns = json.loads(kub('get', 'namespace', namespace, '-o', 'json'))
    meta = ns['metadata']
    if (meta.get('deletionTimestamp') or meta.get('labels', {}).get(LABEL) != uid
            or meta.get('labels', {}).get('managed-by') != 'infrastructure'
            or ns.get('status', {}).get('phase') != 'Active'):
        raise ValueError('Ingress namespace must be active and owned by this cluster')
    secret = json.loads(kub('-n', namespace, 'get', 'secret', 'traefik-tls-secret', '-o', 'json'))
    meta = secret['metadata']; annotations = meta.get('annotations', {})
    if (secret.get('type') != 'kubernetes.io/tls' or meta.get('deletionTimestamp') or meta.get('ownerReferences')
            or meta.get('labels', {}).get(LABEL) != uid
            or meta.get('labels', {}).get('app.kubernetes.io/managed-by') != 'sunmoon-bootstrap'
            or annotations.get('sunmoonai.com/ca-sha256') != registry['ca_sha256']):
        raise ValueError('Ingress requires the owned TLS Secret from certificate installation')
    # Read private bytes only in memory; crypto helper suppresses diagnostics.
    validate_payload({'registry': registry, 'entries': [{'namespace': namespace, 'name': 'traefik-tls-secret',
        'certificate_sha256': annotations.get('sunmoonai.com/certificate-sha256', ''),
        'dns_names': ['sunmoonai.com', '*.sunmoonai.com'],
        'certificate': secret['data']['tls.crt'], 'key': secret['data']['tls.key']}]})
    service = next(o for o in desired if o['kind'] == 'Service')
    ports = {p['nodePort'] for p in service['spec']['ports']}
    for other in json.loads(kub('get', 'services', '-A', '-o', 'json'))['items']:
        if (other['metadata'].get('namespace'), other['metadata']['name']) != (namespace, service['metadata']['name']):
            if ports & {p.get('nodePort') for p in other.get('spec', {}).get('ports', [])}:
                raise ValueError('Ingress NodePort already allocated; no service changed')
    for other in json.loads(kub('get', 'ingressclasses.networking.k8s.io', '-o', 'json'))['items']:
        if other['metadata']['name'] != 'traefik' and other['metadata'].get('annotations', {}).get('ingressclass.kubernetes.io/is-default-class') == 'true':
            raise ValueError('Another default IngressClass exists; no automatic takeover')
    missing, crd_ready = [], set()
    for obj in sorted(desired, key=lambda o: o['kind'] != 'CustomResourceDefinition'):
        if obj['kind'] in CUSTOM and CUSTOM[obj['kind']] not in crd_ready:
            missing.append(obj)
            continue
        actual = get(kub, obj)
        if actual is None:
            missing.append(obj)
        elif (actual['metadata'].get('deletionTimestamp') or actual['metadata'].get('ownerReferences')
              or not contains(actual, obj)):
            raise ValueError('Existing ingress resource differs or is unowned; retained: ' + obj['kind'] + '/' + obj['metadata']['name'])
        elif obj['kind'] == 'CustomResourceDefinition' and established(actual):
            crd_ready.add(obj['metadata']['name'])
    return missing


def execute(kub, root, manifest, data, spec, uid):
    profile, timeout = spec['profile'], spec['timeout']
    if not 1 <= timeout <= 600:
        raise ValueError('Ingress wait timeout must be 1..600 seconds')
    desired = objects(root, manifest, data, profile, uid)
    namespace = 'ingress-platform-' + profile
    missing = preflight(kub, desired, namespace, uid, spec['registry'])
    verify_only = spec.get('verify_only', False)
    if verify_only and missing:
        raise ValueError('Ingress resource missing/unestablished; verification never repairs it')
    created = 0
    deadline = time.monotonic() + timeout

    def pause(reason):
        if verify_only or time.monotonic() >= deadline:
            raise ValueError(reason + '; resources retained')
        time.sleep(min(3, max(0, deadline - time.monotonic())))

    for obj in missing:
        if obj['kind'] == 'CustomResourceDefinition':
            kub('create', '-f', '-', content=json.dumps(obj).encode()); created += 1
    for obj in desired:
        if obj['kind'] == 'CustomResourceDefinition':
            while not established(get(kub, obj) or {}):
                pause('Traefik CRD not established')
    # Recheck after discovery becomes available, before creating any workload.
    missing = preflight(kub, desired, namespace, uid, spec['registry'])
    if verify_only and missing:
        raise ValueError('Ingress disappeared during verification')
    for obj in missing:
        kub('create', '-f', '-', content=json.dumps(obj).encode()); created += 1
    deployment = next(o for o in desired if o['kind'] == 'Deployment')
    count = deployment['spec']['replicas']
    while True:
        current = get(kub, deployment) or {}; status = current.get('status', {})
        if (not current.get('metadata', {}).get('deletionTimestamp')
                and status.get('observedGeneration', 0) >= current.get('metadata', {}).get('generation', 1)
                and all(status.get(k, 0) == count for k in ('replicas', 'updatedReplicas', 'readyReplicas', 'availableReplicas'))):
            break
        pause('Traefik Deployment not ready')
    if preflight(kub, desired, namespace, uid, spec['registry']):
        raise ValueError('Ingress resources disappeared before completion')
    return {'ingress_ready': True, 'created_objects': created, 'version': data['versions']['traefik'],
            'namespace': namespace, 'routing_verified': False, 'tls_handshake_verified': False,
            'harbor_changed': False, 'data_volumes_changed': False}
