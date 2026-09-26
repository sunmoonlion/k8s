#!/usr/bin/env python3
"""Render private, staged restore manifests. Never contacts or mutates a cluster."""
import argparse
import base64
import copy
import hashlib
import json
import os
from pathlib import Path
import tarfile

NS = 'harbor-restore-20260926'
NODE = 'sunmoon-kind-136-worker'
HOST = 'harbor-restore.sunmoonai.com'
ADDRESS = '10.97.60.20'
ROOT = '/var/local-path-provisioner/' + NS
OLD_NS = 'cicd-platform-dev'
OLD_ENDPOINT = 'https://harbor.sunmoonai.com:30443'
ENDPOINT = 'https://' + HOST + ':18443'
CLAIMS = {
    'harbor-sunmoonai-registry-dev-pvc': 'registry',
    'harbor-sunmoonai-database-dev-pvc': 'database',
    'harbor-sunmoonai-redis-dev-pvc': 'redis',
    'harbor-sunmoonai-jobservice-dev-pvc': 'jobservice',
    'harbor-sunmoonai-trivy-dev-pvc': 'trivy',
    'data-sunmoonai-harbor-trivy-0': 'trivy-active',
}


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024**2), b''): h.update(chunk)
    return h.hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def resource(kind, name, spec=None, version='v1'):
    value = {'apiVersion': version, 'kind': kind, 'metadata': {'name': name, 'namespace': NS}}
    if spec is not None: value['spec'] = spec
    return value


def metadata(obj):
    old = obj.get('metadata', {})
    obj['metadata'] = {k: old[k] for k in ['name', 'labels'] if k in old}
    obj['metadata']['namespace'] = NS
    obj.pop('status', None)


def rewrite(value):
    if isinstance(value, str): return value.replace(OLD_NS + '.svc', NS + '.svc').replace(OLD_ENDPOINT, ENDPOINT)
    if isinstance(value, dict): return {k: rewrite(v) for k, v in value.items()}
    if isinstance(value, list): return [rewrite(v) for v in value]
    return value


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch', type=Path, default=Path.home() / 'packages-to-be-installed/releases/harbor-preserve-20260926')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    backup = args.batch / 'backup-20260926T145600Z'
    prep = args.batch / 'preparation'
    verification = json.loads((backup / 'verification.json').read_text())
    if not verification['file_checks_passed']: raise RuntimeError('Backup verification missing')
    # Rendering checks metadata inputs; executor must recheck every archive before restore.
    for item in verification['files']:
        if item['path'].endswith(('resources-private.json', 'traefik-tls-secret.json')):
            if sha(args.batch / item['path']) != item['sha256']: raise RuntimeError('Backup input changed')
    source = json.loads((backup / 'resources-private.json').read_text())['items']
    supplement = json.loads((prep / 'storage-addendum.json').read_text())
    if sha(prep / supplement['path']) != supplement['sha256']:
        raise RuntimeError('Storage metadata addendum changed')
    source.extend(json.loads((prep / supplement['path']).read_text())['items'])
    pins = {}
    for path in sorted((prep / 'images').glob('*.tar')):
        with tarfile.open(path) as archive:
            index = json.load(archive.extractfile('index.json'))
            for item in index['manifests']:
                ref = item['annotations']['io.containerd.image.name']
                selected = item
                if 'index' in item['mediaType'] or 'manifest.list' in item['mediaType']:
                    body = json.load(archive.extractfile('blobs/sha256/' + item['digest'].split(':')[1]))
                    choices = [m for m in body['manifests'] if m.get('platform', {}).get('os') == 'linux' and m.get('platform', {}).get('architecture') == 'amd64']
                    if len(choices) != 1: raise RuntimeError('Ambiguous bootstrap platform')
                    selected = choices[0]
                archive.getmember('blobs/sha256/' + selected['digest'].split(':')[1])
                pins[ref] = ref.rsplit(':', 1)[0] + '@' + selected['digest']
    ns = resource('Namespace', NS)
    ns['metadata'] = {'name': NS, 'labels': {'sunmoonai.com/purpose': 'harbor-restore'}}
    # Original policies are additive and could re-open egress: replace them entirely.
    policy = resource('NetworkPolicy', 'restore-isolation', {
        'podSelector': {}, 'policyTypes': ['Ingress', 'Egress'],
        'ingress': [{'from': [{'podSelector': {}}]}],
        'egress': [{'to': [{'podSelector': {}}]}, {'to': [{'namespaceSelector': {'matchLabels': {'kubernetes.io/metadata.name': 'kube-system'}},
                    'podSelector': {'matchLabels': {'k8s-app': 'kube-dns'}}}],
                   'ports': [{'protocol': 'UDP', 'port': 53}, {'protocol': 'TCP', 'port': 53}]}]}, 'networking.k8s.io/v1')
    gateway_access = resource('NetworkPolicy', 'restore-gateway-node-access', {
        'podSelector': {'matchLabels': {'app': 'restore-gateway'}}, 'policyTypes': ['Ingress'],
        'ingress': [{'from': [{'ipBlock': {'cidr': ip + '/32'}} for ip in ['172.18.0.5', '172.18.0.6', '172.18.0.7']],
                     'ports': [{'protocol': 'TCP', 'port': 8443}]}]}, 'networking.k8s.io/v1')
    items = [ns, policy, gateway_access]
    changes = []
    workloads = []
    for original in source:
        kind = original['kind']
        name = original['metadata']['name']
        if kind not in ['ConfigMap', 'Secret', 'Service', 'ServiceAccount', 'PersistentVolumeClaim', 'Deployment', 'StatefulSet']:
            continue
        if kind == 'Secret' and original.get('type') in ['helm.sh/release.v1', 'kubernetes.io/service-account-token']:
            continue
        o = rewrite(copy.deepcopy(original))
        metadata(o)
        if kind == 'Secret':
            for key, encoded in o.get('data', {}).items():
                try: value = base64.b64decode(encoded, validate=True).decode()
                except (UnicodeError, ValueError): continue
                changed = rewrite(value)
                if changed != value:
                    o['data'][key] = base64.b64encode(changed.encode()).decode()
                    changes.append({'resource': name, 'field': key, 'change': 'internal endpoint rewrite; secret value omitted'})
        if kind == 'ConfigMap':
            for key in ['HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY']:
                if key in o.get('data', {}): o['data'][key] = ''
            if name == 'sunmoonai-harbor-trivy-envvars':
                o['data']['SCANNER_TRIVY_SKIP_UPDATE'] = 'true'
                o['data']['SCANNER_TRIVY_SKIP_JAVA_DB_UPDATE'] = 'true'
            # Eliminate automatic upload purge on the restore copy.
            if name == 'sunmoonai-harbor-registry':
                text = o['data']['config.yml']
                if 'uploadpurging:' in text:
                    text = text.replace('uploadpurging:\n      enabled: true', 'uploadpurging:\n      enabled: false')
                o['data']['config.yml'] = text
        if kind == 'Service':
            s = o['spec']
            headless = s.get('clusterIP') == 'None'
            for key in ['clusterIP', 'clusterIPs', 'ipFamilies', 'ipFamilyPolicy', 'healthCheckNodePort', 'externalTrafficPolicy']:
                s.pop(key, None)
            if headless: s['clusterIP'] = 'None'
            s['type'] = 'ClusterIP'
            for port in s['ports']: port.pop('nodePort', None)
        if kind == 'PersistentVolumeClaim':
            if name not in CLAIMS: raise RuntimeError('Unknown claim: ' + name)
            key = CLAIMS[name]
            o['spec']['volumeName'] = NS + '-' + key
            o['spec']['storageClassName'] = ''
            o['spec'].pop('selector', None)
            pv = resource('PersistentVolume', NS + '-' + key, {
                'capacity': o['spec']['resources']['requests'], 'accessModes': ['ReadWriteOnce'],
                'persistentVolumeReclaimPolicy': 'Retain', 'storageClassName': '',
                'hostPath': {'path': ROOT + '/' + key, 'type': 'Directory'},
                'claimRef': {'name': name, 'namespace': NS},
                'nodeAffinity': {'required': {'nodeSelectorTerms': [{'matchExpressions': [
                    {'key': 'kubernetes.io/hostname', 'operator': 'In', 'values': [NODE]}]}]}}})
            pv['metadata'].pop('namespace')
            items.append(pv)
        if kind in ['Deployment', 'StatefulSet']:
            o['spec']['replicas'] = 0
            pod = o['spec']['template']
            metadata(pod)
            pod['metadata'].pop('namespace', None)
            s = pod['spec']
            for key in ['hostAliases', 'affinity', 'nodeName']: s.pop(key, None)
            s['nodeSelector'] = {'kubernetes.io/hostname': NODE}
            s['automountServiceAccountToken'] = False
            if s.get('hostNetwork') or s.get('hostPID'): raise RuntimeError('Unexpected host namespace access')
            for container in s.get('initContainers', []) + s['containers']:
                container['image'] = pins[container['image']]
                container['imagePullPolicy'] = 'Never'
            for claim in o['spec'].get('volumeClaimTemplates', []):
                metadata(claim)
                claim['metadata'].pop('namespace', None)
                claim['spec']['storageClassName'] = ''
            workloads.append(name)
            changes.append({'resource': name, 'change': 'zero replicas; independent node; remove old hostAliases; pin amd64 image; Never pull'})
        items.append(o)
    tls = json.loads((prep / 'private/traefik-tls-secret.json').read_text())
    metadata(tls)
    tls['metadata']['name'] = 'restore-serving-tls'
    items.append(tls)
    nginx = '''pid /tmp/nginx.pid;
error_log /dev/stderr info;
events { worker_connections 128; }
http {
  access_log /dev/stdout;
  client_body_temp_path /tmp/client_temp;
  proxy_temp_path /tmp/proxy_temp;
  server {
    listen 8443 ssl;
    server_name harbor-restore.sunmoonai.com localhost;
    ssl_certificate /tls/tls.crt;
    ssl_certificate_key /tls/tls.key;
    client_max_body_size 0;
    proxy_read_timeout 300s;
    proxy_buffering off;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-Proto https;
    location ~ ^/(api/|service/|v2/?|chartrepo/|c/) { proxy_pass http://sunmoonai-harbor-core:80; }
    location / { proxy_pass http://sunmoonai-harbor-portal:80; }
  }
}
'''
    cm = resource('ConfigMap', 'restore-gateway')
    cm['data'] = {'nginx.conf': nginx}
    items.append(cm)
    gateway = resource('Deployment', 'restore-gateway', {'replicas': 0, 'selector': {'matchLabels': {'app': 'restore-gateway'}},
        'template': {'metadata': {'labels': {'app': 'restore-gateway'}}, 'spec': {
            'nodeSelector': {'kubernetes.io/hostname': NODE}, 'automountServiceAccountToken': False,
            'securityContext': {'runAsUser': 1001, 'runAsGroup': 1001, 'fsGroup': 1001},
            'containers': [{'name': 'gateway', 'image': pins['docker.io/bitnami/harbor-portal:2.13.2-debian-12-r1'],
                'imagePullPolicy': 'Never', 'command': ['/opt/bitnami/nginx/sbin/nginx'],
                'args': ['-c', '/restore/nginx.conf', '-g', 'daemon off;'],
                'securityContext': {'allowPrivilegeEscalation': False, 'readOnlyRootFilesystem': True, 'capabilities': {'drop': ['ALL']}},
                'resources': {'requests': {'cpu': '50m', 'memory': '64Mi'}, 'limits': {'cpu': '250m', 'memory': '128Mi'}},
                'ports': [{'containerPort': 8443}],
                'readinessProbe': {'tcpSocket': {'port': 8443}, 'initialDelaySeconds': 3},
                'volumeMounts': [{'name': 'config', 'mountPath': '/restore', 'readOnly': True},
                                 {'name': 'tls', 'mountPath': '/tls', 'readOnly': True}, {'name': 'tmp', 'mountPath': '/tmp'}]}],
            'volumes': [{'name': 'config', 'configMap': {'name': 'restore-gateway'}},
                        {'name': 'tls', 'secret': {'secretName': 'restore-serving-tls'}}, {'name': 'tmp', 'emptyDir': {}}]}}}, 'apps/v1')
    items.append(gateway)
    items.append(resource('Service', 'restore-gateway', {'type': 'ClusterIP', 'clusterIP': ADDRESS,
        'selector': {'app': 'restore-gateway'}, 'ports': [{'name': 'https', 'port': 18443, 'targetPort': 8443}]}))
    encoded = json.dumps(items)
    if OLD_NS in encoded or '101.126.151.0' in encoded or OLD_ENDPOINT in encoded:
        raise RuntimeError('Old target remains in rendered resources')
    if {i['metadata']['name'] for i in items if i['kind'] == 'PersistentVolumeClaim'} != set(CLAIMS):
        raise RuntimeError('Incomplete claim set')
    output = args.output.expanduser()
    output.mkdir(parents=True, mode=0o700, exist_ok=False)
    write(output / 'manifests-private.json', {'apiVersion': 'v1', 'kind': 'List', 'items': items})
    plan = {'scope': 'render only; no cluster changes', 'namespace': NS, 'node': NODE,
            'kubeconfig': '~/.kube/sunmoon-kind-136.config', 'endpoint': ENDPOINT,
            'gateway_cluster_ip': ADDRESS, 'host_access': '127.0.0.1:18443 via kubectl port-forward',
            'storage_root': ROOT, 'claims': CLAIMS, 'images': pins, 'changes': changes,
            'resources': [{'kind': i['kind'], 'name': i['metadata']['name']} for i in items],
            'initial_replicas': 0, 'jobservice_during_first_validation': 0,
            'backup_verification_sha256': sha(backup / 'verification.json'),
            'storage_addendum_sha256': supplement['sha256'],
            'private_manifests_sha256': sha(output / 'manifests-private.json')}
    write(output / 'plan.json', plan)
    print(json.dumps({'resources': len(items), 'pinned_images': len(pins), 'output': str(output),
                      'private_manifests_sha256': plan['private_manifests_sha256']}))


if __name__ == '__main__':
    main()
