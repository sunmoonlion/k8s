#!/usr/bin/env python3
"""Read-only old-entry inventory and bounded TLS checks; default prints a plan.

No stop/start, API mutation, secrets query, credentials, download or cleanup.
This snapshot is preparation evidence, not permission to cut over an entry.
"""
import argparse
import datetime as dt
import hashlib
import http.client
import ipaddress
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess

import yaml

from host_prepare import docker

UID = '5d71ab3a-ea5a-4535-adc6-d7698d820249'
TOOL = Path('/home/zymun/packages-to-be-installed/releases/kubectl-1.27.3-existing-kind-linux-amd64/bin/kubectl')
TOOL_SHA = 'ebafd9850219b73760675984df1d7cdb675e4695a43fdf9dfcce41d5066fe8d5'
KUBECONFIG = Path('/home/zymun/.kube/kind-config')
CA = Path('/data/harbor/instances/sunmoon-harbor-main-20260927/ca-download/ca.crt')
CA_SHA = '30fe0e56df354899ccf7e66d5d730b87946b8010db21852a2e4520997a51b0ec'
PORTS = {30080: 80, 30443: 30443, 30444: 30444, 30445: 30445, 30446: 30446}
SERVICE = ('ingress-platform-dev', 'traefik-sunmoonai')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def kub(*args):
    # Pin the executable and static kubeconfig before every GET. The old client
    # stays separate from the 1.36 tool and the user's current context.
    if TOOL.resolve() != TOOL or sha(TOOL) != TOOL_SHA:
        raise ValueError('Old kubectl differs from the accepted 1.27.3 tool')
    if KUBECONFIG.resolve() != KUBECONFIG or KUBECONFIG.stat().st_mode & 0o077:
        raise ValueError('Explicit private kubeconfig required')
    config = yaml.safe_load(KUBECONFIG.read_text())
    target = next(c['context'] for c in config['contexts'] if c['name'] == 'kind-kind')
    cluster = next(c['cluster'] for c in config['clusters'] if c['name'] == target['cluster'])
    user = next(c['user'] for c in config['users'] if c['name'] == target['user'])
    if (cluster['server'] != 'https://127.0.0.1:43001'
            or cluster.get('insecure-skip-tls-verify') or cluster.get('proxy-url')
            or any(k in user for k in ('exec', 'auth-provider', 'tokenFile'))):
        raise ValueError('Old API endpoint/TLS/static credentials differ')
    env = {k: v for k, v in os.environ.items()
           if k.lower() not in ('http_proxy', 'https_proxy', 'all_proxy', 'no_proxy') and k != 'KUBECONFIG'}
    result = subprocess.run([str(TOOL), '--kubeconfig', str(KUBECONFIG), '--context', 'kind-kind',
        '--request-timeout=20s', *args, '-o', 'json'], capture_output=True, env=env, timeout=30)
    if result.returncode:
        raise ValueError('Old API read failed; raw output withheld')
    return json.loads(result.stdout)


def node(name):
    info = json.loads(docker('inspect', name))[0]
    if ((info['Config'].get('Labels') or {}).get('io.x-k8s.kind.cluster') != 'kind'
            or info['Name'] != '/' + name or not info['State']['Running']):
        raise ValueError('Old node identity/running state differs: ' + name)
    network = info['NetworkSettings']['Networks']['kind']
    ipaddress.IPv4Address(network['IPAddress'])
    return {'name': name, 'id': info['Id'], 'ip': network['IPAddress'],
            'network_id': network['NetworkID'], 'image_id': info['Image'],
            'ports': info['HostConfig']['PortBindings'] or {},
            'mounts': [{k: m.get(k) for k in ('Type', 'Name', 'Source', 'Destination', 'RW')}
                       for m in info['Mounts']]}


def tls_request(address, hostname, path, context):
    connection = http.client.HTTPSConnection(hostname, 30443, timeout=15, context=context)
    try:
        connection.sock = context.wrap_socket(socket.create_connection((address, 30443), timeout=15),
                                              server_hostname=hostname)
        digest = hashlib.sha256(connection.sock.getpeercert(binary_form=True)).hexdigest()
        connection.request('GET', path, headers={'Host': hostname + ':30443', 'Connection': 'close'})
        response = connection.getresponse()
        content = response.read(1024**2 + 1)
        if len(content) > 1024**2:
            raise ValueError('Entry response exceeded 1 MiB limit')
        return {'status': response.status, 'certificate_der_sha256': digest,
                'body_sha256': hashlib.sha256(content).hexdigest(),
                'challenge': response.getheader('WWW-Authenticate')}, content
    finally:
        connection.close()


def inspect():
    if os.geteuid() != 0:
        raise ValueError('Read-only Docker and private CA inspection requires root')
    namespace = kub('get', 'namespace', 'kube-system')
    if namespace['metadata']['uid'] != UID:
        raise ValueError('Old kube-system UID differs; no automatic adoption')
    nodes = [node(n) for n in ('kind-control-plane', 'kind-worker', 'kind-worker2')]
    if len({n['network_id'] for n in nodes}) != 1:
        raise ValueError('Old node Docker network differs')
    expected = {str(k) + '/tcp': [{'HostIp': '0.0.0.0', 'HostPort': str(v)}] for k, v in PORTS.items()}
    expected['6443/tcp'] = [{'HostIp': '127.0.0.1', 'HostPort': '43001'}]
    if nodes[0]['ports'] != expected or any(n['ports'] for n in nodes[1:]):
        raise ValueError('Old entry port mapping changed')
    namespace, name = SERVICE
    service = kub('-n', namespace, 'get', 'service', name)
    ports = service['spec']['ports']
    if (service['spec']['type'] != 'NodePort' or service['spec'].get('externalTrafficPolicy') != 'Cluster'
            or {p['nodePort'] for p in ports} != set(PORTS)
            or any(p['protocol'] != 'TCP' for p in ports)):
        raise ValueError('Old ingress service NodePorts/policy changed')
    endpoints = kub('-n', namespace, 'get', 'endpoints', name)
    addresses = [a for subset in endpoints.get('subsets', []) for a in subset.get('addresses', [])]
    if not addresses or any(a.get('nodeName') not in ('kind-worker', 'kind-worker2') for a in addresses):
        raise ValueError('Ingress endpoints must be ready and outside the stopping control-plane')
    if CA.resolve() != CA or sha(CA) != CA_SHA:
        raise ValueError('Original CA differs from the accepted certificate authority')
    context = ssl.create_default_context(cafile=str(CA))
    samples = []
    # Compare the public path with both proposed worker next hops. Body hashes
    # are evidence only; dynamic health bodies need not be byte-identical.
    for address in ('127.0.0.1', nodes[1]['ip'], nodes[2]['ip']):
        registry, _ = tls_request(address, 'harbor.sunmoonai.com', '/v2/', context)
        health, raw = tls_request(address, 'harbor.sunmoonai.com', '/api/v2.0/health', context)
        ordinary, _ = tls_request(address, 'sunmoonai.com', '/', context)
        if (registry['status'] != 401 or 'realm="https://harbor.sunmoonai.com:30443/service/token"'
                not in (registry['challenge'] or '') or health['status'] != 200
                or json.loads(raw).get('status') != 'healthy'):
            raise ValueError('Old registry/health probe failed through ' + address)
        samples.append({'address': address, 'registry': registry, 'health': health, 'ordinary_tls': ordinary})
    for field in ('registry', 'health', 'ordinary_tls'):
        if len({s[field]['certificate_der_sha256'] for s in samples}) != 1:
            raise ValueError('Worker and published entry certificates differ: ' + field)
    if kub('get', 'namespace', 'kube-system')['metadata']['uid'] != UID:
        raise ValueError('Old UID changed during inspection')
    return {'schema': 1, 'observed_at': dt.datetime.now(dt.timezone.utc).isoformat(), 'read_only': True,
        'old_cluster_uid': UID, 'kubeconfig_sha256': sha(KUBECONFIG), 'nodes': nodes,
        'service': {'namespace': namespace, 'name': name, 'uid': service['metadata']['uid'],
                    'policy': 'Cluster', 'ports': ports},
        'ready_endpoints': [{'ip': a['ip'], 'node': a['nodeName']} for a in addresses],
        'tls_probes': samples, 'proposed_transition_default': nodes[1]['ip'] + ':30443',
        'control_plane_stopped': False, 'entry_switched': False,
        'remaining': ['recheck after WSL restart; node IPs may change',
            'worker health after old control-plane stop remains untested',
            '80 and 30444-30446 unavailable during the proposed TLS-only transition',
            'freeze source writes and reconcile latest Harbor data before cutover',
            'new backup restore, maintenance approval and formal creator remain pending']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    value = inspect() if args.check else {'dry_run': True, 'old_cluster_uid': UID,
        'scope': 'GET-only old API, Docker inspect and credential-free strict TLS reads',
        'stop_or_start': False, 'entry_switched': False}
    print(json.dumps(value, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Entry inspection stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; raw diagnostics withheld')) from None
