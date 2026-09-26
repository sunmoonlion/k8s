#!/usr/bin/env python3
"""L7 acceptance in the isolated cluster; never uses the default kubeconfig."""
import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import secrets
import shlex
import sys
import time

import yaml

from cluster import Cluster, HERE, json_write, sha

NS = 'sunmoon-infra-check'
OWNER = 'sunmoonai.com/isolated-infra-check'


def verify(c):
    lock = c.validate()
    c.assert_target()
    report = {'started': dt.datetime.now().astimezone().isoformat(),
              'profile_sha256': c.profile_sha, 'manifest_sha256': sha(c.root / 'manifest.lock.json'), 'checks': []}
    stamp = dt.datetime.now().strftime('%Y%m%dT%H%M%S')
    destination = c.root / ('verification-' + stamp + '.json')

    def record(name, detail=True):
        report['checks'].append({'name': name, 'passed': True, 'detail': detail})
        json_write(destination, report)
        print('PASS ' + name, flush=True)

    def apply(*objects):
        c.kub('apply', '--server-side', '--field-manager=sunmoon-infra-check', '-f', '-',
              text_input=yaml.safe_dump_all(objects, sort_keys=False))

    def wait_pod(name):
        c.kub('-n', NS, 'wait', '--for=condition=Ready', 'pod/' + name, '--timeout=120s', timeout=150)

    def eventually(fn, seconds=30):
        until = time.monotonic() + seconds
        while True:
            try:
                return fn()
            except RuntimeError:
                if time.monotonic() >= until:
                    raise
                time.sleep(2)

    try:
        nodes = json.loads(c.kub('get', 'nodes', '-o', 'json'))['items']
        assert len(nodes) == 3
        assert all(n['status']['nodeInfo']['kubeletVersion'] == c.p['kubernetes'] for n in nodes)
        assert all(any(x['type'] == 'Ready' and x['status'] == 'True' for x in n['status']['conditions']) for n in nodes)
        record('three-ready-nodes-at-locked-version', {n['metadata']['name']: n['status']['nodeInfo']['containerRuntimeVersion'] for n in nodes})
        calico = json.loads(c.kub('-n', 'kube-system', 'get', 'daemonset', 'calico-node', '-o', 'json'))
        assert calico['status']['numberReady'] == 3
        assert all(x['imagePullPolicy'] == 'Never' and '@sha256:' in x['image'] for x in calico['spec']['template']['spec']['containers'])
        record('calico-ready-and-images-pinned')
        # A Ready snapshot can miss periodic liveness restarts. Observe beyond
        # the configured 10s * 6 failure threshold before testing traffic.
        def calico_health():
            pods = json.loads(c.kub('-n', 'kube-system', 'get', 'pods', '-l', 'k8s-app=calico-node', '-o', 'json'))['items']
            if len(pods) != 3:
                raise RuntimeError('Expected three stable Calico pods')
            snapshot = {}
            for p in pods:
                statuses = p['status'].get('containerStatuses', [])
                if p['metadata'].get('deletionTimestamp') or not statuses or not all(s['ready'] for s in statuses):
                    raise RuntimeError('Calico is not continuously ready')
                snapshot[p['metadata']['uid']] = {s['name']: s['restartCount'] for s in statuses}
            return snapshot
        stable = calico_health()
        for _ in range(8):
            time.sleep(15)
            if calico_health() != stable:
                raise RuntimeError('Calico restarted or was replaced during the 120s observation')
        record('calico-stable-for-120-seconds', stable)
        existing = c.kub('get', 'namespace', NS, '--ignore-not-found', '-o', 'json')
        if existing.strip():
            raise ValueError('Verification namespace already exists. Inspect and explicitly clean previous test resources first.')
        apply({'apiVersion': 'v1', 'kind': 'Namespace', 'metadata': {'name': NS,
               'labels': {OWNER: 'true', 'pod-security.kubernetes.io/enforce': 'restricted',
                          'pod-security.kubernetes.io/enforce-version': 'v1.36'}}})
        image = next(i['reference'] for i in lock['images'] if i['id'] == 'probe')
        worker, server_node = c.p['name'] + '-worker', c.p['name'] + '-worker2'

        def pod(name, labels, command, node=worker, pvc=False):
            volumes = [{'name': 'data', 'persistentVolumeClaim': {'claimName': 'persistence'}}] if pvc else [{'name': 'data', 'emptyDir': {}}]
            container = {'name': 'probe', 'image': image, 'imagePullPolicy': 'Never', 'command': command,
                'resources': {'requests': {'cpu': '10m', 'memory': '16Mi'}, 'limits': {'cpu': '100m', 'memory': '64Mi'}},
                'securityContext': {'allowPrivilegeEscalation': False, 'readOnlyRootFilesystem': True, 'capabilities': {'drop': ['ALL']}},
                'volumeMounts': [{'name': 'data', 'mountPath': '/data'}]}
            if name == 'echo':
                container['readinessProbe'] = {'httpGet': {'path': '/', 'port': 8080}, 'periodSeconds': 2}
            return {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': name, 'namespace': NS, 'labels': labels},
                    'spec': {'automountServiceAccountToken': False, 'enableServiceLinks': False,
                      'nodeSelector': {'kubernetes.io/hostname': node},
                      'securityContext': {'runAsNonRoot': True, 'runAsUser': 1000, 'runAsGroup': 1000, 'fsGroup': 1000,
                                          'seccompProfile': {'type': 'RuntimeDefault'}},
                      'containers': [container], 'volumes': volumes}}

        apply(pod('echo', {'app': 'echo'}, ['sh', '-ec', 'echo sunmoon-cross-node-ok > /data/index.html; exec httpd -f -p 8080 -h /data'], server_node),
              pod('allowed', {'role': 'client', 'access': 'allowed'}, ['sleep', '3600']),
              pod('denied', {'role': 'client', 'access': 'denied'}, ['sleep', '3600']),
              {'apiVersion': 'v1', 'kind': 'Service', 'metadata': {'name': 'echo', 'namespace': NS},
               'spec': {'selector': {'app': 'echo'}, 'ports': [{'port': 8080, 'targetPort': 8080}]}})
        for name in ['echo', 'allowed', 'denied']:
            wait_pod(name)
        ip = json.loads(c.kub('-n', NS, 'get', 'svc', 'echo', '-o', 'json'))['spec']['clusterIP']
        pod_ip = json.loads(c.kub('-n', NS, 'get', 'pod', 'echo', '-o', 'json'))['status']['podIP']

        def fetch(client, address):
            result = c.kub('-n', NS, 'exec', client, '--', 'wget', '-T', '3', '-qO-', f'http://{address}:8080', timeout=20)
            if result.strip() != 'sunmoon-cross-node-ok':
                raise RuntimeError('Unexpected HTTP payload')

        for client in ['allowed', 'denied']:
            env = c.kub('-n', NS, 'exec', client, '--', 'env')
            assert not any(x.split('=', 1)[0].lower() in ['http_proxy', 'https_proxy', 'all_proxy'] for x in env.splitlines())
            fetch(client, ip)
        fetch('allowed', pod_ip)
        record('cross-node-pod-and-service-connectivity-before-policy')
        c.kub('-n', NS, 'exec', 'allowed', '--', 'nslookup', f'echo.{NS}.svc.cluster.local', timeout=30)
        record('cluster-dns')
        record('test-pods-have-no-proxy')
        apply({'apiVersion': 'networking.k8s.io/v1', 'kind': 'NetworkPolicy',
               'metadata': {'name': 'default-deny', 'namespace': NS},
               'spec': {'podSelector': {}, 'policyTypes': ['Ingress', 'Egress'], 'ingress': [], 'egress': []}})

        def blocked(client):
            url = shlex.quote(f'http://{ip}:8080')
            command = f'code=0; out="$(wget -T 3 -qO- {url} 2>&1)" || code=$?; [ "$code" -ne 0 ] || exit 42; case "$out" in *"timed out"*) echo EXPECTED_TIMEOUT ;; *) printf "%s\\n" "$out"; exit 43 ;; esac'
            result = c.kub('-n', NS, 'exec', client, '--', 'sh', '-c', command, timeout=20)
            if result.strip() != 'EXPECTED_TIMEOUT':
                raise RuntimeError('Network denial was not a timeout')

        eventually(lambda: blocked('allowed'))
        eventually(lambda: blocked('denied'))
        record('default-deny-blocks-both-working-clients')
        apply({'apiVersion': 'networking.k8s.io/v1', 'kind': 'NetworkPolicy',
               'metadata': {'name': 'allow-selected-client-egress', 'namespace': NS},
               'spec': {'podSelector': {'matchLabels': {'role': 'client', 'access': 'allowed'}}, 'policyTypes': ['Egress'],
                 'egress': [{'to': [{'podSelector': {'matchLabels': {'app': 'echo'}}}], 'ports': [{'protocol': 'TCP', 'port': 8080}]},
                            {'to': [{'namespaceSelector': {'matchLabels': {'kubernetes.io/metadata.name': 'kube-system'}},
                                     'podSelector': {'matchLabels': {'k8s-app': 'kube-dns'}}}],
                             'ports': [{'protocol': 'UDP', 'port': 53}, {'protocol': 'TCP', 'port': 53}]}]}},
              {'apiVersion': 'networking.k8s.io/v1', 'kind': 'NetworkPolicy',
               'metadata': {'name': 'allow-selected-client-ingress', 'namespace': NS},
               'spec': {'podSelector': {'matchLabels': {'app': 'echo'}}, 'policyTypes': ['Ingress'],
                 'ingress': [{'from': [{'podSelector': {'matchLabels': {'role': 'client', 'access': 'allowed'}}}],
                              'ports': [{'protocol': 'TCP', 'port': 8080}]}]}})
        eventually(lambda: fetch('allowed', ip))
        fetch('allowed', pod_ip)
        blocked('denied')
        c.kub('-n', NS, 'exec', 'allowed', '--', 'nslookup', f'echo.{NS}.svc.cluster.local', timeout=30)
        record('exact-allow-restores-selected-client-only')
        # Keep default-deny installed while testing storage. The helper runs in its own system namespace.
        cm = json.loads(c.kub('-n', 'local-path-storage', 'get', 'cm', 'local-path-config', '-o', 'json'))
        helper = yaml.safe_load(cm['data']['helperPod.yaml'])
        for container in helper['spec']['containers']:
            container['image'] = image
            container['imagePullPolicy'] = 'Never'
        c.kub('-n', 'local-path-storage', 'patch', 'configmap', 'local-path-config', '--type=merge',
              '-p', json.dumps({'data': {'helperPod.yaml': yaml.safe_dump(helper)}}))
        # The provisioner reloads its config; observe a fresh pod before creating the claim.
        c.kub('-n', 'local-path-storage', 'rollout', 'restart', 'deployment/local-path-provisioner')
        c.kub('-n', 'local-path-storage', 'rollout', 'status', 'deployment/local-path-provisioner', '--timeout=120s', timeout=150)
        marker = secrets.token_hex(16)
        apply({'apiVersion': 'v1', 'kind': 'PersistentVolumeClaim', 'metadata': {'name': 'persistence', 'namespace': NS},
               'spec': {'storageClassName': 'standard', 'accessModes': ['ReadWriteOnce'], 'resources': {'requests': {'storage': '64Mi'}}}},
              pod('pvc-writer', {'app': 'storage'}, ['sh', '-ec', f'echo {marker} > /data/marker; exec sleep 3600'], pvc=True))
        wait_pod('pvc-writer')
        assert c.kub('-n', NS, 'exec', 'pvc-writer', '--', 'cat', '/data/marker').strip() == marker
        c.kub('-n', NS, 'delete', 'pod', 'pvc-writer', '--wait=true', '--timeout=60s', timeout=90)
        apply(pod('pvc-reader', {'app': 'storage'}, ['sleep', '3600'], pvc=True))
        wait_pod('pvc-reader')
        assert c.kub('-n', NS, 'exec', 'pvc-reader', '--', 'cat', '/data/marker').strip() == marker
        record('pvc-data-survives-test-pod-replacement', 'local-path on one worker; not node-failure HA')
        before = json.loads((c.root / 'old-cluster-before.json').read_text())
        assert before == c.old_snapshot()
        record('old-cluster-identity-ports-kubeconfig-storage-unchanged')
        # Actual readiness is checked separately; unchanged identity alone is insufficient.
        old_nodes = json.loads(c.run(['docker', 'exec', 'kind-control-plane', 'kubectl', '--kubeconfig',
            '/etc/kubernetes/admin.conf', '--request-timeout=20s', 'get', 'nodes', '-o', 'json']))['items']
        assert len(old_nodes) == 3 and all(any(x['type'] == 'Ready' and x['status'] == 'True' for x in n['status']['conditions']) for n in old_nodes)
        record('old-three-nodes-still-ready', 'Used the old control-plane node kubectl to avoid client/server version skew')
        report['passed'] = True
        report['completed'] = dt.datetime.now().astimezone().isoformat()
        json_write(destination, report)
        print('VERIFICATION PASSED ' + str(destination))
    except BaseException as error:
        report['passed'] = False
        report['error_type'] = type(error).__name__
        json_write(destination, report)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', default=str(HERE / 'profile.json'))
    parser.add_argument('--artifacts')
    args = parser.parse_args()
    c = Cluster(args.profile, args.artifacts)
    with open(c.root / '.operation.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        verify(c)


if __name__ == '__main__':
    main()
