#!/usr/bin/env python3
"""Formal KIND preparation only: plan/render/check; never creates a cluster.

Reuse the accepted isolated artifact batch, without writing into that batch.
check probes the local Docker socket and storage read-only. No remote commands,
downloads, cleanup, implicit kubeconfig or automatic recreation.
"""
import argparse
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys

import yaml
from configuration import CONFIG, CONFIG_PATH, CONFIG_SHA256, IDENTITY_SHA256

HERE = Path(__file__).resolve().parent
ISOLATED = HERE.parent / 'isolated'
NAME = CONFIG['cluster']
UUID = CONFIG['storage_uuid']
MATERIALS = Path(CONFIG['materials_root'])
STORAGE = Path('/data/kind-clusters') / NAME
KUBECONFIG = Path(CONFIG['kubeconfig'])
GUARD = Path('/opt/sunmoon/admin/storage/storage-20260927-v2/check-storage-mounts.sh')
POD_CIDR, SERVICE_CIDR, API_PORT = CONFIG['pod_cidr'], CONFIG['service_cidr'], CONFIG['api_port']
LIMITS, TIMEOUTS = CONFIG['limits'], CONFIG['timeouts']
GIB = 1024**3


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def accepted():
    lock = json.loads((ISOLATED / 'artifacts.lock.json').read_text())
    profile = json.loads((ISOLATED / 'profile.json').read_text())
    if (lock['profile_sha256'] != sha(ISOLATED / 'profile.json')
            or profile['kubernetes'] != 'v1.36.4' or profile['kind'] != 'v0.33.0'
            or profile['calico'] != 'v3.32.2' or lock['files'] != profile['files']):
        raise ValueError('Accepted material profile changed; review formal preparation first')
    return lock


def document(lock):
    node = next(i for i in lock['images'] if i['id'] == 'node')
    nodes = []
    for suffix, role in [('control-plane', 'control-plane'), ('worker', 'worker'), ('worker2', 'worker')]:
        nodes.append({'role': role, 'image': node['archive_tag'], 'extraMounts': [
            {'hostPath': str(STORAGE / suffix / 'local-path'), 'containerPath': '/var/local-path-provisioner'},
            {'hostPath': str(STORAGE / suffix / 'static'), 'containerPath': '/data/kind-local-storage'},
        ]})
    # The public TLS port belongs to the host SNI proxy, never to a KIND node.
    nodes[0]['extraPortMappings'] = [dict(item) for item in CONFIG['port_mappings']]
    return {'kind': 'Cluster', 'apiVersion': 'kind.x-k8s.io/v1alpha4', 'name': NAME,
            'networking': {'apiServerAddress': '127.0.0.1', 'apiServerPort': API_PORT,
                           'disableDefaultCNI': True, 'podSubnet': POD_CIDR,
                           'serviceSubnet': SERVICE_CIDR, 'kubeProxyMode': 'iptables'},
            'nodes': nodes}


def plan(lock):
    return {'schema': 1, 'cluster': NAME, 'phase': 'preparation-only', 'dry_run': True,
            'configuration': str(CONFIG_PATH), 'configuration_sha256': CONFIG_SHA256,
            'identity_sha256': IDENTITY_SHA256, 'limits': LIMITS, 'timeouts': TIMEOUTS,
            'kubernetes': '1.36.4', 'kind': '0.33.0', 'calico': '3.32.2',
            'storage_uuid': UUID, 'materials': str(MATERIALS), 'kubeconfig': str(KUBECONFIG),
            'kubectl': str(MATERIALS / 'bin/kubectl'), 'registry': 'harbor.sunmoonai.com:30443',
            'kind_config': document(lock), 'automatic_delete': False, 'creation_implemented': True,
            'creation_runtime_verified': False,
            'ready_for_creation': False,
            'remaining_gates': ['new managed Harbor backup independently restored',
                'owner maintenance window: WSL compression and old control-plane downtime',
                'formal SNI 30443 and Harbor acceptance (P3)',
                'formal creator/CNI live acceptance and storage-gated startup integration',
                'fresh capacity/port/network admission at actual creation'],
            'after_creation': ['record kube-system UID and explicit kubeconfig without changing inbox',
                'verify six actual Docker mounts and local-path StorageClass',
                'render static PV nodeAffinity with actual main node names',
                'registry trust and real image pull; shared platform deployment',
                'prove Harbor data survives cluster rebuild', 'final approved cleanup']}


def run(argv):
    env = {k: v for k, v in os.environ.items()
           if k.lower() not in ('http_proxy', 'https_proxy', 'all_proxy', 'no_proxy')
           and k not in ('KUBECONFIG', 'DOCKER_HOST', 'DOCKER_CONTEXT')}
    result = subprocess.run(argv, env=env, capture_output=True, timeout=60)
    if result.returncode:
        # Never print captured command output; future kubeconfig or Docker data
        # must not leak via an exception's stdout/stderr representation.
        raise ValueError('Read-only command failed: ' + Path(argv[0]).name)
    return result.stdout


def docker(*args):
    return run(['docker', '--host', 'unix:///var/run/docker.sock', *args])


def material_check(lock):
    if MATERIALS.resolve() != MATERIALS:
        raise ValueError('Material root must not be symlinked')
    actual = json.loads((MATERIALS / 'manifest.lock.json').read_text())
    if actual != lock:
        raise ValueError('Local material manifest differs from the committed acceptance lock')
    checked = []
    for item in lock['files'] + lock['images'] + lock['generated']:
        path = MATERIALS / item['path']
        if (path.resolve() != path or not path.is_relative_to(MATERIALS)
                or '..' in path.parts or not path.is_file() or sha(path) != item['sha256']):
            raise ValueError('Material is missing/changed: ' + item['path'])
        checked.append(item['path'])
    return checked


def physical_capacity():
    command = ("$ErrorActionPreference='Stop'; $d=Get-PSDrive -Name C; "
        "$v=Get-Item -LiteralPath 'C:\\wsl-disks\\sunmoon-data.vhdx'; "
        "[pscustomobject]@{CFreeBytes=$d.Free;DataVhdLength=$v.Length} | ConvertTo-Json -Compress")
    value = json.loads(run(['/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe',
        '-NoProfile', '-NonInteractive', '-Command', command]).decode('utf-8-sig'))
    if any(type(value.get(k)) is not int or value[k] < 0 for k in ('CFreeBytes', 'DataVhdLength')):
        raise ValueError('Physical capacity result schema changed')
    value['remaining_data_growth_bytes'] = max(0, 100 * GIB - value['DataVhdLength'])
    # Initial cluster-only allowance, not a lifetime capacity promise or a
    # reservation for the independent Harbor restore/platform deployment.
    value['initial_node_budget_bytes'] = LIMITS['initial_node_gib'] * GIB
    value['metadata_margin_bytes'] = LIMITS['metadata_margin_gib'] * GIB
    value['projected_c_free_bytes'] = (value['CFreeBytes'] - value['remaining_data_growth_bytes']
                                     - value['initial_node_budget_bytes'] - value['metadata_margin_bytes'])
    value['minimum_c_free_bytes'] = LIMITS['windows_reserve_gib'] * GIB
    return value


def check(lock):
    report = plan(lock)
    report['dry_run'] = False
    report['read_only'] = True
    report['verified_materials'] = material_check(lock)
    blockers = []
    if os.geteuid() != 0:
        raise ValueError('Read-only storage/Docker inspection requires root')
    if (GUARD.resolve() != GUARD or GUARD.stat().st_uid != 0 or GUARD.stat().st_mode & 0o022):
        raise ValueError('Published storage guard ownership/path changed')
    report['storage'] = json.loads(run(['bash', str(GUARD), '--layout', 'sunmoon-data',
        '--expected-uuid', UUID, '--min-free-gib', str(LIMITS['data_reserve_gib']), '--require-service-visibility']))
    for path in (STORAGE, KUBECONFIG):
        if path.resolve() != path or path.exists() or path.is_symlink():
            blockers.append('Fresh target already exists or has a symlink: ' + str(path))
    ids = docker('ps', '-aq', '--filter', 'label=io.x-k8s.kind.cluster=' + NAME).decode().split()
    if ids:
        blockers.append('Formal node containers already exist; no adoption/recreation')
    ports = [{'listenAddress': '127.0.0.1', 'hostPort': API_PORT},
             *document(lock)['nodes'][0]['extraPortMappings']]
    report['ports'] = []
    for item in ports:
        free = True
        with socket.socket() as sock:
            try:
                sock.bind((item['listenAddress'], item['hostPort']))
            except OSError:
                free = False
        report['ports'].append({'address': item['listenAddress'], 'port': item['hostPort'], 'free': free})
        if not free:
            blockers.append('Port occupied: ' + str(item['hostPort']))
    routes = json.loads(run(['ip', '-j', 'route', 'show', 'table', 'all']))
    networks = [r['dst'] for r in routes if r.get('dst') not in (None, 'default')]
    report['existing_clusters'] = []
    for name in ('kind', 'sunmoon-kind-136'):
        # Node labels and running state are checked before this GET-only exec.
        node = name + '-control-plane'
        info = json.loads(docker('inspect', node))[0]
        if info['Config']['Labels'].get('io.x-k8s.kind.cluster') != name or not info['State']['Running']:
            raise ValueError('Existing control-plane identity/running state differs: ' + node)
        raw = docker('exec', node, 'kubectl', '--kubeconfig', '/etc/kubernetes/admin.conf',
            '--request-timeout=20s', '-n', 'kube-system', 'get', 'configmap', 'kubeadm-config',
            '-o', 'jsonpath={.data.ClusterConfiguration}')
        config = yaml.safe_load(raw)
        current = [config['networking']['podSubnet'], config['networking']['serviceSubnet']]
        networks.extend(current)
        report['existing_clusters'].append({'name': name, 'networks': current})
    for wanted in (POD_CIDR, SERVICE_CIDR):
        proposed = ipaddress.ip_network(wanted)
        for current in networks:
            existing = ipaddress.ip_network(current, strict=False)
            if existing.version == proposed.version and existing.overlaps(proposed):
                blockers.append('Network overlaps: ' + wanted + ' / ' + current)
    available = next(int(line.split()[1]) * 1024 for line in Path('/proc/meminfo').read_text().splitlines()
                     if line.startswith('MemAvailable:'))
    docker_root = docker('info', '--format', '{{.DockerRootDir}}').decode().strip()
    report['capacity'] = {'memory_available_bytes': available,
        'docker_filesystem_free_bytes': shutil.disk_usage(docker_root).free,
        'data_filesystem_free_bytes': shutil.disk_usage('/data/kind-clusters').free,
        'initial_data_budget_bytes': LIMITS['initial_data_gib'] * GIB,
        'minimum_data_free_after_budget_bytes': LIMITS['data_reserve_gib'] * GIB,
        'physical_windows': physical_capacity()}
    if available < LIMITS['memory_free_gib'] * GIB:
        blockers.append('Available memory below configured reserve')
    if report['capacity']['docker_filesystem_free_bytes'] < LIMITS['docker_free_gib'] * GIB:
        blockers.append('Docker filesystem free below configured reserve')
    if report['capacity']['data_filesystem_free_bytes'] < (LIMITS['initial_data_gib'] + LIMITS['data_reserve_gib']) * GIB:
        blockers.append('Data disk lacks configured initial budget plus reserve')
    if report['capacity']['physical_windows']['projected_c_free_bytes'] < LIMITS['windows_reserve_gib'] * GIB:
        blockers.append('Initial cluster budget and full data disk would violate configured C reserve')
    report['blockers'] = blockers + report['remaining_gates']
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', nargs='?', default='plan', choices=('plan', 'render', 'check'))
    args = parser.parse_args()
    lock = accepted()
    if args.action == 'render':
        print(yaml.safe_dump(document(lock), sort_keys=False), end='')
        return
    value = check(lock) if args.action == 'check' else plan(lock)
    print(json.dumps(value, indent=2, ensure_ascii=False))
    if args.action == 'check' and not value['ready_for_creation']:
        sys.exit(2)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, subprocess.TimeoutExpired) as error:
        print('STOP: ' + str(error), file=sys.stderr)
        sys.exit(1)
