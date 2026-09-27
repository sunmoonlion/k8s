#!/usr/bin/env python3
"""Fresh formal KIND creator. Default prints only; never deletes or recreates.

Creation requires the independently restored managed Harbor backup, a running
owned public SNI entry serving the new readonly Harbor, and the old control-plane
already stopped by a separately approved maintenance operation. This tool never
performs that cutover. Actual creation/CNI installation remain unverified.
"""
import argparse
import fcntl
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import socket
import ssl
import stat
import subprocess
import sys
import time

import yaml
import prepare as p

PLATFORM = p.HERE.parents[1]
sys.path.insert(0, str(PLATFORM / 'registry-platform'))
sys.path.insert(0, str(PLATFORM / 'infrastructure/materials'))
from host_prepare import load as load_harbor, storage, directory, write
from host_runtime import Instance, save
from host_backup import backup_path, read_manifest, verify_backup
from sni_proxy import Proxy, load as load_entry, upstream_identity
from sni_verify import request
from cluster_config import calico_for_network

STATE_ROOT = p.STORAGE / '.state'
STATE_FILE = STATE_ROOT / 'state.json'
HARBOR_CONFIG = PLATFORM / 'registry-platform/config/harbor-main-local.json'
OLD_SNAPSHOT = PLATFORM / 'scripts/results/luna-entry-handoff-inspection.20260927.json'
BACKUP = Path('/var/backups/sunmoon-harbor/host-managed-20260927-v1')
SUFFIXES = ('control-plane', 'worker', 'worker2')
LOG_FAILURES = False


def run(argv, *, timeout=120, content=None, source=None):
    env = {k: v for k, v in os.environ.items() if k.lower() not in
        {'http_proxy', 'https_proxy', 'all_proxy', 'no_proxy'}
        and k not in ('KUBECONFIG', 'DOCKER_CONTEXT', 'KIND_EXPERIMENTAL_PROVIDER')}
    env.update(DOCKER_HOST='unix:///var/run/docker.sock', KIND_EXPERIMENTAL_PROVIDER='docker')
    stream = source.open('rb') if source else None
    try:
        result = subprocess.run([str(v) for v in argv], input=content, stdin=stream,
                                env=env, capture_output=True, timeout=timeout)
    finally:
        if stream:
            stream.close()
    if result.returncode:
        if LOG_FAILURES and STATE_ROOT.is_dir():
            write(STATE_ROOT / ('failure-' + str(time.time_ns()) + '.log'), result.stdout + result.stderr)
        raise ValueError('Command failed; no automatic deletion: ' + Path(str(argv[0])).name)
    return result.stdout


def docker(*args, **kwargs):
    return run(['docker', '--host', 'unix:///var/run/docker.sock', *args], **kwargs)


def protected_nodes():
    expected = json.loads(OLD_SNAPSHOT.read_text())
    result = []
    for record in expected['nodes']:
        info = json.loads(docker('inspect', record['name']))[0]
        mounts = [{k: m.get(k) for k in ('Type', 'Name', 'Source', 'Destination', 'RW')} for m in info['Mounts']]
        if (info['Id'] != record['id'] or info['Image'] != record['image_id']
                or info['Config']['Labels'].get('io.x-k8s.kind.cluster') != 'kind'
                or (info['HostConfig']['PortBindings'] or {}) != record['ports']
                or sorted(mounts, key=lambda m:m['Destination']) != sorted(record['mounts'], key=lambda m:m['Destination'])):
            raise ValueError('Protected old node identity/ports/mounts differ')
        running = info['State']['Running']
        if running != (record['name'] != 'kind-control-plane'):
            raise ValueError('Maintenance requires stopped old control-plane and running old workers')
        if running:
            network = info['NetworkSettings']['Networks']['kind']
            if network['NetworkID'] != record['network_id'] or network['IPAddress'] != record['ip']:
                raise ValueError('Protected worker network/address differs from the maintenance snapshot')
        result.append({'name': record['name'], 'id': info['Id'], 'running': running})
    return result


def entry_gate(entry_path):
    # The negative case checks the private receipt first, before reading 20GB.
    backup = backup_path(BACKUP)
    receipt = read_manifest(backup / 'backup.json')
    if not receipt.get('complete') or not receipt.get('restore_verified'):
        raise ValueError('Managed Harbor backup independent restoration has not passed')
    receipt = verify_backup(backup)
    instance = Instance(load_harbor(HARBOR_CONFIG))
    restored_preparation = read_manifest(backup / 'source-preparation.json')
    if (receipt['source'] != instance.project or instance.mode() != 'read-only'
            or not restored_preparation.get('writer') or not restored_preparation.get('scanner')
            or not instance.state.get('database_reconciled')
            or any(instance.state.get(k) for k in ('mode_transition_open', 'configuration_transition_open',
                                                  'write_acceptance_open', 'metadata_acceptance_open'))):
        raise ValueError('Reconciled readonly Harbor without unfinished transitions required')
    statuses = instance.check()
    if any(statuses.get(role) != 'running' for role in ('postgresql', 'redis', 'registry', 'registryctl', 'core', 'portal', 'proxy')):
        raise ValueError('Owned new Harbor base services must already be running')
    if entry_path is None:
        raise ValueError('Explicit already-accepted public entry profile required')
    config = load_entry(entry_path)
    if config['mode'] not in ('transition', 'formal') or config['listen'] != '0.0.0.0:30443':
        raise ValueError('Public entry required; a candidate port cannot admit formal creation')
    proxy = Proxy(config)
    proxy.immutable(); upstream_identity(config)
    if not proxy.inspect()['State']['Running']:
        raise ValueError('Owned public entry is not running')
    context = ssl.create_default_context(cafile=str(instance.root / 'ca-download/ca.crt'))
    response = request(30443, context, '/v2/')
    expected = hashlib.sha256(ssl.PEM_cert_to_DER_cert((instance.root / 'tls/server.crt').read_text())).hexdigest()
    if (response['status'] != 401 or response['certificate_der_sha256'] != expected
            or 'realm="https://harbor.sunmoonai.com:30443/service/token"' not in (response['challenge'] or '')):
        raise ValueError('Canonical public entry does not serve the pinned new Harbor')
    return {'proxy_id': proxy.state['container_id'], 'backup_sha256': p.sha(backup / 'backup.json'),
            'leaf_der_sha256': expected, 'harbor': instance.project}


def preflight(entry_path):
    lock = p.accepted()
    p.material_check(lock)
    storage(load_harbor(HARBOR_CONFIG), minimum_gib=22)
    # Fail before creating paths, importing images or stopping anything.
    gate = entry_gate(entry_path)
    old = protected_nodes()
    if any(path.exists() or path.is_symlink() or path.resolve() != path for path in (p.STORAGE, p.KUBECONFIG)):
        raise ValueError('Fresh target storage/kubeconfig required; no recreation or adoption')
    if p.STORAGE.parent.stat().st_uid != 0 or p.STORAGE.parent.stat().st_mode & 0o022:
        raise ValueError('Root-owned storage parent must not be writable by other users')
    if docker('ps', '-aq', '--filter', 'label=io.x-k8s.kind.cluster=' + p.NAME).strip():
        raise ValueError('Target node containers already exist')
    for item in [{'hostPort': p.API_PORT, 'listenAddress': '127.0.0.1'},
                 *p.document(lock)['nodes'][0]['extraPortMappings']]:
        with socket.socket() as sock:
            sock.bind((item['listenAddress'], item['hostPort']))
    routes = json.loads(run(['ip', '-j', 'route', 'show', 'table', 'all']))
    networks = ['10.244.0.0/16', '10.96.0.0/16', '10.245.0.0/16', '10.97.0.0/16']
    networks += [r['dst'] for r in routes if r.get('dst') not in (None, 'default')]
    for cidr in (p.POD_CIDR, p.SERVICE_CIDR):
        for existing in networks:
            proposed, current = ipaddress.ip_network(cidr), ipaddress.ip_network(existing, strict=False)
            if proposed.version == current.version and proposed.overlaps(current):
                raise ValueError('Proposed network conflicts with an existing route/cluster range')
    available = next(int(s.split()[1]) * 1024 for s in Path('/proc/meminfo').read_text().splitlines() if s.startswith('MemAvailable:'))
    docker_root = docker('info', '--format', '{{.DockerRootDir}}').decode().strip()
    physical = p.physical_capacity()
    if available < 16 * p.GIB or shutil.disk_usage(docker_root).free < 30 * p.GIB or physical['projected_c_free_bytes'] < 50 * p.GIB:
        raise ValueError('Insufficient physical/virtual capacity for initial cluster budget')
    return lock, {'entry': gate, 'old_nodes': old, 'physical_capacity': physical}


class Cluster:
    def __init__(self):
        if (os.geteuid() != 0 or STATE_ROOT.resolve() != STATE_ROOT or STATE_ROOT.stat().st_uid != 0
                or STATE_ROOT.stat().st_mode & 0o077 or STATE_FILE.resolve() != STATE_FILE
                or STATE_FILE.stat().st_uid != 0 or STATE_FILE.stat().st_mode & 0o077):
            raise ValueError('Private root-owned formal state required')
        self.state = json.loads(STATE_FILE.read_text())
        if self.state.get('schema') != 1 or self.state['cluster'] != p.NAME or self.state['material_lock_sha256'] != p.sha(p.ISOLATED / 'artifacts.lock.json'):
            raise ValueError('Formal state/material identity changed')
        self.lock = p.accepted()
        rendered = yaml.safe_dump(p.document(self.lock), sort_keys=False).encode()
        if (p.sha(STATE_ROOT / 'kind.yaml') != self.state['kind_config_sha256']
                or hashlib.sha256(rendered).hexdigest() != self.state['kind_config_sha256']):
            raise ValueError('Recorded KIND configuration differs from current renderer')

    def persist(self):
        save(STATE_FILE, self.state)

    def nodes(self):
        names = [p.NAME + '-' + suffix for suffix in SUFFIXES]
        ids = docker('ps', '-aq', '--no-trunc', '--filter', 'label=io.x-k8s.kind.cluster=' + p.NAME).decode().split()
        if set(ids) != set(self.state['nodes'].values()) or len(ids) != 3:
            raise ValueError('Recorded exact three node IDs required')
        for name, desired in zip(names, p.document(self.lock)['nodes']):
            obj = json.loads(docker('inspect', name))[0]
            required = {(m['hostPath'], m['containerPath']) for m in desired['extraMounts']}
            mounts = {(m['Source'], m['Destination']) for m in obj['Mounts'] if m['Type'] == 'bind' and m['RW']}
            if (obj['Id'] != self.state['nodes'][name] or obj['Image'] != self.state['node_image_id']
                    or obj['Config']['Labels'].get('io.x-k8s.kind.cluster') != p.NAME
                    or not obj['State']['Running'] or obj['HostConfig']['RestartPolicy']['Name'] != 'no'
                    or not required <= mounts):
                raise ValueError('Formal node identity/image/running/restart/mount contract differs')
        return names

    def kub(self, *args, content=None):
        if p.KUBECONFIG.resolve() != p.KUBECONFIG or p.sha(p.KUBECONFIG) != self.state['kubeconfig_sha256']:
            raise ValueError('Explicit formal kubeconfig changed')
        tool = next(v for v in self.lock['files'] if v['path'] == 'bin/kubectl')
        if p.sha(p.MATERIALS / 'bin/kubectl') != tool['sha256']:
            raise ValueError('Formal kubectl changed')
        prefix = [p.MATERIALS / 'bin/kubectl', '--kubeconfig', p.KUBECONFIG,
                  '--context', 'kind-' + p.NAME, '--request-timeout=30s']
        if self.state.get('uid'):
            current = run([*prefix, 'get', 'namespace', 'kube-system', '-o', 'json'])
            if json.loads(current)['metadata']['uid'] != self.state['uid']:
                raise ValueError('Formal cluster UID changed')
        return run([*prefix, *args], content=content, timeout=360)

    def install_cni(self):
        if (self.state.get('phase') not in ('created-before-cni', 'cni-ready')
                or not re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', self.state.get('uid') or '')):
            raise ValueError('Completed creation and recorded UID required before CNI installation')
        storage(load_harbor(HARBOR_CONFIG), minimum_gib=20)
        p.material_check(self.lock)
        nodes = self.nodes()
        version = json.loads(self.kub('version', '-o', 'json'))
        if any(version.get(k, {}).get('gitVersion') != 'v1.36.4' for k in ('clientVersion', 'serverVersion')):
            raise ValueError('Explicit client/server must both be Kubernetes 1.36.4')
        for node in nodes:
            for item in self.lock['images']:
                if not item['id'].startswith('calico-'):
                    continue
                docker('exec', '-i', node, 'ctr', '-n', 'k8s.io', 'images', 'import', '--platform',
                       'linux/amd64', '-', source=p.MATERIALS / item['path'], timeout=240)
                docker('exec', node, 'ctr', '-n', 'k8s.io', 'images', 'tag', '--force',
                       'docker.io/' + item['archive_tag'], item['reference'])
                docker('exec', node, 'crictl', 'inspecti', item['reference'])
        source = next(v for v in self.lock['files'] if v['path'] == 'charts/calico-upstream.yaml')
        data = {'shared_calico_materials': [{'material_root_relative_path': source['path'], 'sha256': source['sha256']},
                *[i for i in self.lock['images'] if i['id'].startswith('calico-')]]}
        objects = calico_for_network(p.POD_CIDR, p.NAME, data, p.MATERIALS, detection='interface=eth0')
        for namespace, kind, name in [('kube-system', 'deployment', 'coredns'), ('kube-system', 'daemonset', 'kube-proxy'),
                                      ('local-path-storage', 'deployment', 'local-path-provisioner')]:
            self.kub('-n', namespace, 'patch', kind, name, '--type=json', '-p',
                json.dumps([{'op': 'add', 'path': '/spec/template/spec/containers/0/imagePullPolicy', 'value': 'Never'}]))
        self.kub('apply', '--server-side', '--field-manager=sunmoon-bootstrap', '-f', '-', content=json.dumps(objects).encode())
        self.kub('wait', '--for=condition=Ready', 'nodes', '--all', '--timeout=300s')
        for resource in ('ds/calico-node', 'deployment/calico-kube-controllers', 'deployment/coredns', 'ds/kube-proxy'):
            self.kub('-n', 'kube-system', 'rollout', 'status', resource, '--timeout=180s')
        self.state['phase'] = 'cni-ready'; self.persist()
        return {'phase': self.state['phase'], 'uid': self.state['uid'], 'business_acceptance': False}


def create(entry_path):
    lock, admitted = preflight(entry_path)
    directory(p.STORAGE)
    directory(STATE_ROOT)
    for suffix in SUFFIXES:
        directory(p.STORAGE / suffix, mode=0o750)
        for leaf in ('static', 'local-path'):
            directory(p.STORAGE / suffix / leaf, mode=0o750)
    document = yaml.safe_dump(p.document(lock), sort_keys=False).encode()
    write(STATE_ROOT / 'kind.yaml', document)
    node = next(i for i in lock['images'] if i['id'] == 'node')
    state = {'schema': 1, 'cluster': p.NAME, 'phase': 'creating', 'nodes': {}, 'uid': None,
        'material_lock_sha256': p.sha(p.ISOLATED / 'artifacts.lock.json'),
        'kind_config_sha256': hashlib.sha256(document).hexdigest(),
        'node_image_id': node['docker_image_id'], 'admission': admitted}
    save(STATE_FILE, state)
    try:
        docker('load', '--input', str(p.MATERIALS / node['path']), timeout=300)
        if docker('image', 'inspect', '--format', '{{.Id}}', node['archive_tag']).decode().strip() != node['docker_image_id']:
            raise ValueError('Loaded KIND node identity differs from lock')
        run([p.MATERIALS / 'bin/kind', 'create', 'cluster', '--name', p.NAME, '--config', STATE_ROOT / 'kind.yaml',
             '--image', node['archive_tag'], '--kubeconfig', p.KUBECONFIG, '--retain', '--wait', '0s'], timeout=600)
        config = yaml.safe_load(p.KUBECONFIG.read_text())
        if (len(config['clusters']) != 1 or config['clusters'][0]['name'] != 'kind-' + p.NAME
                or config['clusters'][0]['cluster']['server'] != 'https://127.0.0.1:' + str(p.API_PORT)
                or config['clusters'][0]['cluster'].get('insecure-skip-tls-verify')
                or config['clusters'][0]['cluster'].get('proxy-url')
                or any(any(k in u['user'] for k in ('exec', 'auth-provider')) for u in config['users'])):
            raise ValueError('Created kubeconfig identity differs')
        account = pwd.getpwnam('zymun')
        os.chown(p.KUBECONFIG, account.pw_uid, account.pw_gid); os.chmod(p.KUBECONFIG, 0o600)
        state['kubeconfig_sha256'] = p.sha(p.KUBECONFIG)
    finally:
        # Even a partial create is retained. Disable restart for owned new nodes;
        # subsequent startup must go through a separate storage-gated operation.
        for suffix in SUFFIXES:
            name = p.NAME + '-' + suffix
            ids = docker('ps', '-aq', '--filter', 'name=^/' + name + '$').decode().split()
            if not ids:
                continue
            obj = json.loads(docker('inspect', name))[0]
            if obj['Config']['Labels'].get('io.x-k8s.kind.cluster') != p.NAME or obj['Image'] != node['docker_image_id']:
                raise ValueError('Partial create ownership changed; manual inspection required')
            docker('update', '--restart=no', obj['Id'])
            state['nodes'][name] = obj['Id']; save(STATE_FILE, state)
    cluster = Cluster()
    cluster.nodes()
    uid = json.loads(cluster.kub('get', 'namespace', 'kube-system', '-o', 'json'))['metadata']['uid']
    cluster.state.update(uid=uid, phase='created-before-cni'); cluster.persist()
    if protected_nodes() != admitted['old_nodes']:
        raise ValueError('Protected old nodes changed during creation')
    return {'phase': cluster.state['phase'], 'uid': uid, 'kubeconfig': str(p.KUBECONFIG), 'ready': False}


def main():
    global LOG_FAILURES
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('create', 'install-cni', 'preflight'))
    parser.add_argument('--entry-config', type=Path)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if args.action == 'preflight':
        _, result = preflight(args.entry_config)
        print(json.dumps(result, indent=2)); return
    if not args.apply:
        print(json.dumps({'dry_run': True, 'action': args.action, 'cluster': p.NAME,
            'requires': ['independently restored backup', 'owned public entry with new readonly Harbor',
                         'old control-plane already stopped', 'fresh storage/ports/capacity'],
            'delete': False, 'stop_old_nodes': False, 'runtime_verified': False}, indent=2)); return
    if os.geteuid() != 0:
        raise ValueError('Root required for formal creation and mount ownership')
    LOG_FAILURES = True
    storage(load_harbor(HARBOR_CONFIG), minimum_gib=20)
    path = Path('/data/kind-clusters/.formal-create.lock')
    descriptor = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'rb+') as handle:
        info = os.fstat(handle.fileno())
        if info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o600 or not stat.S_ISREG(info.st_mode):
            raise ValueError('Unsafe creation lock')
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        result = create(args.entry_config) if args.action == 'create' else Cluster().install_cni()
        print(json.dumps(result, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Formal KIND stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld')) from None
