#!/usr/bin/env python3
"""Cloud cluster phase controller. Default print-only; 云上未经实机验证。

Shell exports only an allowlist of topology fields, not its complete config.
No token in arguments/logs/files on the management machine. No reset or cleanup.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

from bundle import resolve, verify
from cluster_config import validate, init_documents, calico_objects, multi_json
from node_control import PUBLIC_FILES, REMOTE
from cluster_resources import namespaces, taints


def resource_spec(phase, profile, connections, data):
    step = {'namespaces': '07', 'health': '08', 'taints': '10'}[phase]
    enabled = os.environ.get(f'SM_STEP{step}_ENABLED')
    if enabled not in ('true', 'false'):
        raise ValueError('Explicit resource step enable/disable required')
    if os.environ.get(f'SM_STEP{step}_TARGET') != 'master':
        raise ValueError('Resource operations must run on the declared master')
    if os.environ.get(f'SM_STEP{step}_REMOTE_KUBECONFIG') not in ('', '/etc/kubernetes/admin.conf'):
        raise ValueError('Resources require the root-private initialization kubeconfig')
    timeout = int(os.environ.get('SM_RESOURCE_TIMEOUT', '300'))
    if not 1 <= timeout <= 600:
        raise ValueError('Readiness timeout must be 1..600 seconds')
    expected_count = os.environ.get('SM_EXPECTED_NODE_COUNT')
    if expected_count and int(expected_count) != len(profile['nodes']):
        raise ValueError('Expected node count differs from declared topology')
    expected = {'version': 'v' + data['versions']['kubernetes'], 'nodes': [
        {**n, 'machine_id': connections[n['name']]['machine_id']} for n in profile['nodes']]}
    spec = {'timeout': timeout, 'expected': expected}
    if phase == 'namespaces':
        flags = [os.environ.get('SM_NAMESPACE_ENABLED'), os.environ.get('SM_NAMESPACE_POLICIES')]
        if any(v not in ('true', 'false') for v in flags):
            raise ValueError('Explicit namespace booleans required')
        enabled = 'true' if enabled == 'true' and flags[0] == 'true' else 'false'
        spec.update(environments=os.environ['SM_NAMESPACE_ENVIRONMENTS'],
                    platforms=os.environ['SM_NAMESPACE_PLATFORMS'], policies=flags[1] == 'true')
        namespaces(spec['environments'], spec['platforms'], spec['policies'])
    if phase == 'taints':
        indices = os.environ['SM_NODE_INDICES'].split()
        spec['taints'] = {n['name']: os.environ.get(f'SM_NODE_{i}_TAINTS', '') for i, n in zip(indices, profile['nodes'])}
        for value in spec['taints'].values():
            taints(value)
    return enabled == 'true', spec


def inputs():
    nodes, connections = [], {}
    indices = os.environ['SM_NODE_INDICES'].split()
    if not indices or any(not re.fullmatch(r'[1-9][0-9]*', i) for i in indices) or len(set(indices)) != len(indices):
        raise ValueError('Explicit unique node indices required')
    for i in indices:
        get = lambda k: os.environ.get(f'SM_NODE_{i}_{k}', '')
        name = get('EXPECTED_HOSTNAME') or get('CLUSTER_HOSTNAME')
        n = {'name': name, 'ip': get('LOCAL_IP'), 'role': get('TYPE')}
        nodes.append(n)
        connections[name] = {'host': get('USER') + '@' + (get('PUBLIC_IP') or get('LOCAL_IP')),
                             'port': int(get('SSH_PORT') or '22'), 'identity': get('SECRET'),
                             'machine_id': get('MACHINE_ID'), 'hostname': get('EXPECTED_HOSTNAME'),
                             'root': get('DIR').removeprefix('~/') or 'packages-to-be-installed'}
    master = next((n for n in nodes if n['role'] == 'master'), None)
    if master is None:
        raise ValueError('No master configured')
    profile = {'cluster': os.environ['CLUSTER'].lower(), 'nodes': nodes,
               'pod_cidr': os.environ.get('SM_POD_CIDR') or '10.244.0.0/16',
               'service_cidr': os.environ.get('SM_SERVICE_CIDR') or '10.96.0.0/12',
               'endpoint': os.environ.get('SM_ENDPOINT') or master['ip'] + ':6443',
               'api_sans': [s.strip() for s in os.environ.get('SM_API_SANS', '').split(',') if s.strip()],
               'proxy_mode': 'iptables'}
    return validate(profile), connections


def controls(directory):
    files, identities = {}, {}
    for name in PUBLIC_FILES:
        path = directory / name
        if path.resolve() != path:
            raise ValueError('Symlinked public control program')
        raw = path.read_bytes()
        identities[name] = hashlib.sha256(raw).hexdigest()
        files[name] = {'base64': base64.b64encode(raw).decode(), 'sha256': identities[name]}
    release = hashlib.sha256(json.dumps(identities, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return files, release


def check_connection(c):
    if not re.fullmatch(r'[a-z_][a-z0-9_-]*@[A-Za-z0-9][A-Za-z0-9.-]*', c['host']) or not 1 <= c['port'] <= 65535:
        raise ValueError('Invalid SSH target')
    if not c['hostname'] or not re.fullmatch(r'[0-9a-f]{32}', c['machine_id']):
        raise ValueError('All nodes need pre-recorded hostname and machine-id')
    if c['identity'] and not Path(c['identity']).expanduser().is_file():
        raise ValueError('Configured SSH key missing')
    if (not re.fullmatch(r'[A-Za-z0-9_./-]+', c['root']) or '..' in Path(c['root']).parts
            or Path(c['root']).name != 'packages-to-be-installed'):
        raise ValueError('Invalid remote material root')


def call(c, files, release, phase, request):
    ssh = ['ssh', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', 'ConnectTimeout=10',
           '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=3', '-p', str(c['port'])]
    if c['identity']:
        ssh += ['-o', 'IdentitiesOnly=yes', '-i', str(Path(c['identity']).expanduser())]
    payload = {'files': files, 'release': release, 'phase': phase, 'request': request,
               'hostname': c['hostname'], 'machine_id': c['machine_id'],
               'remote_root': c['root'], 'user': c['host'].split('@', 1)[0]}
    # Output may be a private join ticket. Capture it, parse it, never print raw.
    result = subprocess.run(ssh + [c['host'], 'sudo -n /usr/bin/python3 -B -E -s -c ' + shlex.quote(REMOTE)],
                            input=json.dumps(payload), text=True, capture_output=True, timeout=1800)
    if result.returncode:
        if result.returncode == 255:
            raise RuntimeError(f'SSH transport failed for {c["hostname"]}; check connectivity, known_hosts and key authentication; not retried')
        raise RuntimeError(f'Remote phase {phase} failed for {c["hostname"]}; inspect root-private node logs')
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=('init', 'cni', 'join', 'namespaces', 'health', 'taints'), required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    directory = Path(__file__).resolve().parent
    manifest = directory / 'cluster-artifacts.lock.json'
    data, entries = resolve(manifest)
    root = Path(os.environ.get('INFRA_MATERIAL_ROOT', str(Path.home() / 'packages-to-be-installed'))).expanduser().absolute()
    profile, connections = inputs()
    calico = calico_objects(profile, data, root)
    master = next(n for n in profile['nodes'] if n['role'] == 'master')
    configured_version = os.environ.get('SM_KUBERNETES', '').removeprefix('v')
    configured_calico = os.environ.get('SM_CALICO', '').removeprefix('v')
    resource = args.phase in ('namespaces', 'health', 'taints')
    enabled, spec = resource_spec(args.phase, profile, connections, data) if resource else (True, None)
    order = {'init': ['all node preflight', 'all node exact image import', 'single master init'],
             'cni': ['master UID check', 'owned Calico resources only', 'Calico rollouts'],
             'join': ['master UID check', 'ten-minute pinned-CA ticket', 'sequential worker joins',
                      'node machine-id/IP/version/Ready check', 'revoke ticket'],
             'namespaces': ['pinned UID/CA and all node identities', 'check all namespace owners', 'create missing only', 'verify Active'],
             'health': ['pinned UID/CA', 'all node identities/Ready', 'core controller rollouts and system Pod readiness'],
             'taints': ['pinned UID/CA and all node identities', 'preflight all taint conflicts', 'resourceVersion conditional patch', 'verify']}[args.phase]
    if not args.apply:
        print(json.dumps({'dry_run': True, 'phase': args.phase, 'cloud_status': '未经实机验证',
                          'profile': profile, 'kubeadm_configuration': init_documents(profile, data),
                          'configured_kubernetes': configured_version, 'locked_kubernetes': data['versions']['kubernetes'],
                          'configured_calico': configured_calico, 'locked_calico': data['versions']['calico'],
                          'configured_proxy_mode': os.environ.get('SM_PROXY_MODE', ''),
                          'closure_complete': data['closure_complete'], 'calico_objects': len(calico['items']),
                          'machine_identities_configured': all(c['hostname'] and c['machine_id'] for c in connections.values()),
                          'enabled': enabled, 'resource_spec': spec,
                          'order': order, 'ssh_started': False}, ensure_ascii=False, indent=2)); return
    if not enabled:
        print(json.dumps({'phase': args.phase, 'skipped': True, 'reason': 'explicit configuration', 'ssh_started': False})); return
    if data.get('closure_complete') is not True or data.get('pending'):
        raise ValueError('Deployment closure incomplete; no SSH started')
    if configured_version != data['versions']['kubernetes'] or configured_calico != data['versions']['calico']:
        raise ValueError('Configured Kubernetes/Calico version differs from lock')
    if os.environ.get('SM_PROXY_MODE') != 'iptables' or os.environ.get('SM_CNI') != 'calico':
        raise ValueError('Explicit iptables + Calico profile required')
    if os.environ.get('SM_CALICO_AUTODETECTION') not in ('auto', 'kubernetes-internal-ip'):
        raise ValueError('Legacy custom address detection needs an explicit profile update')
    if root.resolve() != root or not root.is_dir():
        raise ValueError('Invalid material root')
    verify(root, entries)
    subprocess.run([str(root / 'releases' / data['batch'] / 'bin/kubeadm'), 'config', 'validate', '--config=/dev/stdin'],
                   input=multi_json(init_documents(profile, data)), text=True, check=True, capture_output=True, timeout=30)
    for c in connections.values():
        check_connection(c)
    files, release = controls(directory)
    invoke = lambda name, phase, extra=None: call(connections[name], files, release, phase, {'profile': profile, **(extra or {})})
    if args.phase == 'init':
        for n in profile['nodes']:
            invoke(n['name'], 'preflight')
        for n in profile['nodes']:
            invoke(n['name'], 'images')
        receipt = invoke(master['name'], 'init')
        print(json.dumps({'phase': 'init', **receipt})); return
    status = invoke(master['name'], 'status')
    uid = status['uid']
    if resource:
        result = invoke(master['name'], 'resources', {'expected_uid': uid, 'action': args.phase, 'spec': spec})
        print(json.dumps({'phase': args.phase, 'uid': uid, **result})); return
    if args.phase == 'cni':
        print(json.dumps(invoke(master['name'], 'cni', {'expected_uid': uid, 'calico': calico}))); return
    for n in profile['nodes']:
        if n['role'] != 'worker':
            continue
        # Mint per worker so a slow first node cannot consume the second
        # node's ticket lifetime on an unreliable management connection.
        ticket = invoke(master['name'], 'ticket', {'expected_uid': uid})
        try:
            invoke(n['name'], 'join', {'ticket': ticket})
            status = invoke(master['name'], 'status', {'expected_uid': uid, 'wait_node': n['name']})
            actual = next((v for v in status['nodes'] if v['name'] == n['name']), None)
            if (not actual or not actual['ready'] or actual['machine_id'] != connections[n['name']]['machine_id']
                    or actual['ips'] != [n['ip']] or actual['kubelet_version'] != 'v' + data['versions']['kubernetes']):
                raise ValueError('Joined worker identity/IP/version/Ready differs')
        finally:
            invoke(master['name'], 'revoke', {'expected_uid': uid, 'token_id': ticket['token'].split('.')[0]})
    actual_names = {v['name'] for v in status['nodes']}
    if actual_names != {v['name'] for v in profile['nodes']} or not all(v['ready'] for v in status['nodes']):
        raise ValueError('Final node membership/readiness differs')
    for n in profile['nodes']:
        actual = next(v for v in status['nodes'] if v['name'] == n['name'])
        if (actual['machine_id'] != connections[n['name']]['machine_id'] or actual['ips'] != [n['ip']]
                or actual['kubelet_version'] != 'v' + data['versions']['kubernetes']):
            raise ValueError('Final node identity/address/version differs')
    print(json.dumps({'phase': 'join', 'uid': uid, 'nodes': status['nodes'], 'kubeconfig': status['kubeconfig'], 'kubectl': status['kubectl']}))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        message = str(error) if isinstance(error, (ValueError, RuntimeError)) else type(error).__name__
        print('Cluster control stopped: ' + message, file=sys.stderr)
        sys.exit(1)
