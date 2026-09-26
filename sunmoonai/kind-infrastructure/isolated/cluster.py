#!/usr/bin/env python3
"""Prepare locked artifacts and operate only the explicitly isolated KIND cluster."""
import argparse
import contextlib
import datetime as dt
import fcntl
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess as sp
import sys
import tempfile
import time

import yaml

HERE = Path(__file__).resolve().parent
PROXY_KEYS = {'http_proxy', 'https_proxy', 'all_proxy', 'no_proxy'}


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def atomic(path, data, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise ValueError(f'Refusing symlink: {path}')
    fd, name = tempfile.mkstemp(prefix='.isolated-', dir=path.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, 'wb') as f:
            f.write(data if isinstance(data, bytes) else data.encode())
            f.flush()
            os.fsync(f.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def json_write(path, value):
    atomic(path, json.dumps(value, indent=2, ensure_ascii=False) + '\n')


def safe_path(root, relative):
    p = Path(relative)
    if p.is_absolute() or '..' in p.parts or not p.parts:
        raise ValueError('Artifact path must be a relative path inside its batch')
    result = root / p
    if result.is_symlink() or not result.resolve().is_relative_to(root.resolve()):
        raise ValueError('Artifact symlink escapes the batch')
    return result


def clean_env():
    env = {k: v for k, v in os.environ.items() if k.lower() not in PROXY_KEYS}
    env.pop('KUBECONFIG', None)
    env.pop('NODE_USE_ENV_PROXY', None)
    return env


class Cluster:
    def __init__(self, profile, artifacts=None):
        self.profile_path = Path(profile).resolve()
        self.p = json.loads(self.profile_path.read_text())
        p = self.p
        # This entry point deliberately has no generic production/cloud target.
        if p['schema'] != 1 or p['name'] != 'sunmoon-kind-136' or p['platform'] != 'linux/amd64':
            raise ValueError('Unsupported isolated profile')
        self.root = Path(artifacts or p['artifacts']).expanduser().resolve()
        self.kubeconfig = Path(p['kubeconfig']).expanduser()
        self.old_kubeconfig = Path(p['old_kubeconfig']).expanduser()
        if self.kubeconfig.resolve() == self.old_kubeconfig.resolve() or self.kubeconfig.is_symlink():
            raise ValueError('New and old kubeconfig must be separate regular paths')
        a, b = [ipaddress.ip_network(p[k]) for k in ['pod_subnet', 'service_subnet']]
        if a.version != 4 or b.version != 4 or a.overlaps(b):
            raise ValueError('Invalid or overlapping cluster networks')
        self.profile_sha = sha(self.profile_path)
        self.kubectl = self.root / 'bin/kubectl'
        self.kind = self.root / 'bin/kind'
        self.logs = self.root / 'logs'

    def run(self, args, timeout=120, tries=1, online=False, stdin_path=None, text_input=None):
        for attempt in range(1, tries + 1):
            name = dt.datetime.now().strftime('%Y%m%dT%H%M%S%f')
            started = time.monotonic()
            print(f'RUN {Path(str(args[0])).name} {args[1]} attempt {attempt}/{tries}', flush=True)
            try:
                with contextlib.ExitStack() as stack:
                    stream = stack.enter_context(open(stdin_path, 'rb')) if stdin_path else None
                    result = sp.run([str(x) for x in args], stdin=stream, input=text_input,
                                    text=True, capture_output=True, timeout=timeout,
                                    env=os.environ.copy() if online else clean_env())
                output = result.stdout + result.stderr
                code = result.returncode
            except sp.TimeoutExpired:
                output, code = 'Command timeout; operation may have left its own partial state.\n', -1
            self.logs.mkdir(parents=True, exist_ok=True, mode=0o700)
            atomic(self.logs / (name + '.log'), output)
            json_write(self.logs / (name + '.json'), {'command': [str(x) for x in args], 'attempt': attempt,
                'exit_code': code, 'seconds': round(time.monotonic() - started, 2), 'online': online})
            if code == 0:
                return result.stdout
            print(f'FAIL exit={code}; log={self.logs / (name + ".log")}', flush=True)
            if attempt < tries:
                time.sleep(attempt * 3)
        raise RuntimeError('Command failed; see the recorded log. No cluster was automatically deleted.')

    def state(self):
        p = self.root / 'preparation.json'
        s = json.loads(p.read_text()) if p.exists() else {'schema': 1, 'profile_sha256': self.profile_sha, 'images': []}
        if s['profile_sha256'] != self.profile_sha:
            raise ValueError('Profile changed: use a different artifact batch')
        return s

    def image_sources(self):
        # Once a batch is accepted, new preparations use its committed registry
        # digests instead of resolving the same Calico version tags again.
        accepted = HERE / 'artifacts.lock.json'
        release = json.loads(accepted.read_text()) if accepted.exists() else {}
        sources = [dict(x) for x in self.p['images']]
        if release.get('profile_sha256') == self.profile_sha:
            images = {x['id']: x for x in release['images']}
            if set(images) != {x['id'] for x in sources}:
                raise ValueError('Accepted image lock/profile mismatch')
            for source in sources:
                locked = images[source['id']]
                if source['source'] != locked['source']:
                    raise ValueError('Accepted image source/profile mismatch')
                source['index_digest'] = locked['index_digest']
        return sources

    def prepare(self):
        self.root.mkdir(parents=True, exist_ok=True)
        os.chmod(self.root, 0o700)
        for name in ['bin', 'images', 'charts', 'tars', 'debs']:
            (self.root / name).mkdir(exist_ok=True)
        if (self.root / 'manifest.lock.json').exists():
            self.validate()
            print('Complete locked batch already exists; verified without network')
            return
        state = self.state()
        for item in self.p['files']:
            target = safe_path(self.root, item['path'])
            if target.exists():
                if sha(target) != item['sha256']:
                    raise ValueError(f'Existing artifact checksum mismatch: {item["path"]}')
            else:
                temporary = target.with_suffix(target.suffix + '.partial')
                self.run(['curl', '--fail', '--silent', '--show-error', '--location', '--proto', '=https',
                          '--proto-redir', '=https', '--connect-timeout', '15', '--max-time', '300',
                          '--output', temporary, item['url']], timeout=320, tries=3, online=True)
                if sha(temporary) != item['sha256']:
                    raise ValueError(f'Download checksum mismatch: {item["path"]}; partial retained for diagnosis')
                os.replace(temporary, target)
            if item['executable']:
                target.chmod(0o700)
        # Resolve once, then persist every digest before downloading its layers.
        for source in self.image_sources():
            item = next((i for i in state['images'] if i['id'] == source['id']), None)
            if item is None:
                source_ref = source['source']
                if source.get('index_digest'):
                    source_ref += '@' + source['index_digest']
                raw = self.run(['docker', 'buildx', 'imagetools', 'inspect', '--raw', source_ref], tries=3, online=True)
                body = json.loads(raw)
                raw_bytes = raw.encode()
                actual = 'sha256:' + hashlib.sha256(raw_bytes).hexdigest()
                if source.get('index_digest') and actual != source['index_digest']:
                    actual = 'sha256:' + hashlib.sha256(raw_bytes.removesuffix(b'\n')).hexdigest()
                    if actual != source['index_digest']:
                        raise ValueError('Upstream index bytes do not match the approved digest')
                if 'manifests' in body:
                    choices = [m['digest'] for m in body['manifests'] if m.get('platform', {}).get('os') == 'linux'
                               and m.get('platform', {}).get('architecture') == 'amd64']
                    if len(choices) != 1:
                        raise ValueError('Expected exactly one linux/amd64 manifest')
                    platform_digest = choices[0]
                else:
                    platform_digest = actual
                repository = source['source'].rsplit(':', 1)[0]
                item = {'id': source['id'], 'source': source['source'], 'index_digest': actual,
                        'platform_digest': platform_digest, 'reference': repository + '@' + platform_digest,
                        'archive_tag': 'sunmoon-offline/' + source['id'] + ':' + platform_digest[7:23],
                        'path': 'images/' + source['id'] + '-linux-amd64.tar'}
                state['images'].append(item)
                json_write(self.root / 'preparation.json', state)
            target = safe_path(self.root, item['path'])
            if target.exists():
                if not item.get('sha256') or sha(target) != item['sha256']:
                    raise ValueError('Existing image archive is unverified or modified')
                continue
            self.run(['docker', 'pull', '--platform', self.p['platform'], item['reference']], timeout=1200, tries=3, online=True)
            item['docker_image_id'] = self.run(['docker', 'image', 'inspect', '--format', '{{.Id}}', item['reference']]).strip()
            self.run(['docker', 'tag', item['reference'], item['archive_tag']])
            temporary = target.with_suffix('.tar.partial')
            self.run(['docker', 'save', '--platform', self.p['platform'], '--output', temporary, item['archive_tag']], timeout=300)
            item['sha256'] = sha(temporary)
            # Persist the hash first: an interrupted rename can safely resume.
            json_write(self.root / 'preparation.json', state)
            os.replace(temporary, target)
        state['files'] = self.p['files']
        state['prepared_at'] = dt.datetime.now().astimezone().isoformat()
        self.render(state)
        state['generated'] = [{'path': f, 'sha256': sha(self.root / f)} for f in ['kind.yaml', 'charts/calico.yaml']]
        json_write(self.root / 'manifest.lock.json', state)
        sums = [f'{i["sha256"]}  {i["path"]}' for i in state['files'] + state['images'] + state['generated']]
        atomic(self.root / 'checksums.sha256', '\n'.join(sums) + '\n')
        self.validate()
        print('PREPARATION COMPLETE ' + str(self.root / 'manifest.lock.json'))

    def render(self, state):
        images = {i['id']: i for i in state['images']}
        kind = {'kind': 'Cluster', 'apiVersion': 'kind.x-k8s.io/v1alpha4', 'name': self.p['name'],
                'networking': {'apiServerAddress': '127.0.0.1', 'apiServerPort': self.p['api_port'],
                    'disableDefaultCNI': True, 'podSubnet': self.p['pod_subnet'], 'serviceSubnet': self.p['service_subnet'],
                    'kubeProxyMode': 'iptables'},
                'nodes': [{'role': role, 'image': images['node']['archive_tag']} for role in ['control-plane', 'worker', 'worker']]}
        atomic(self.root / 'kind.yaml', yaml.safe_dump(kind, sort_keys=False))
        docs = list(yaml.safe_load_all((self.root / 'charts/calico-upstream.yaml').read_text()))
        image_map = {i['source']: i['reference'] for i in state['images'] if i['id'].startswith('calico-')}
        seen = set()
        for obj in docs:
            if not obj:
                continue
            if obj['kind'] == 'ConfigMap' and obj['metadata']['name'] == 'calico-config':
                obj['data']['calico_backend'] = 'vxlan'
            if obj['kind'] not in ['DaemonSet', 'Deployment']:
                continue
            pod = obj['spec']['template']['spec']
            for c in pod.get('initContainers', []) + pod['containers']:
                if c['image'] not in image_map:
                    raise ValueError('Unexpected Calico image in upstream manifest')
                seen.add(c['image'])
                c['image'] = image_map[c['image']]
                c['imagePullPolicy'] = 'Never'
                if c['name'] == 'calico-node':
                    replace = {'CALICO_IPV4POOL_CIDR': self.p['pod_subnet'], 'CALICO_IPV4POOL_IPIP': 'Never',
                               'CALICO_IPV4POOL_VXLAN': 'Always', 'CLUSTER_TYPE': 'k8s', 'FELIX_BPFENABLED': 'false',
                               'IP_AUTODETECTION_METHOD': 'interface=eth0'}
                    c['env'] = [e for e in c['env'] if e['name'] not in replace]
                    c['env'] += [{'name': k, 'value': v} for k, v in replace.items()]
                    c['readinessProbe']['exec']['command'] = ['/bin/calico-node', '-felix-ready']
                    c['livenessProbe']['exec']['command'] = ['/bin/calico-node', '-felix-live']
        if seen != set(image_map):
            raise ValueError('Incomplete Calico dependency closure')
        atomic(self.root / 'charts/calico.yaml', yaml.safe_dump_all(docs, sort_keys=False))

    def validate(self):
        state = json.loads((self.root / 'manifest.lock.json').read_text())
        if state['schema'] != 1 or state['profile_sha256'] != self.profile_sha:
            raise ValueError('Lock file/profile mismatch')
        if {x['id'] for x in state['images']} != {x['id'] for x in self.p['images']}:
            raise ValueError('Incomplete image lock')
        if state['files'] != self.p['files'] or {x['path'] for x in state['generated']} != {'kind.yaml', 'charts/calico.yaml'}:
            raise ValueError('Incomplete file lock')
        for item in state['images'] + state['files'] + state['generated']:
            path = safe_path(self.root, item['path'])
            if not path.is_file() or sha(path) != item['sha256']:
                raise ValueError(f'Missing or invalid offline artifact: {item["path"]}')
        return state

    def kub(self, *args, timeout=120, text_input=None):
        return self.run([self.kubectl, '--kubeconfig', self.kubeconfig, '--context', 'kind-' + self.p['name'],
                         '--request-timeout=30s', *args], timeout=timeout, text_input=text_input)

    def old_snapshot(self):
        # Do not collect Secrets, environment dumps or raw kubeconfig contents.
        snapshot = {'kubeconfig_sha256': sha(self.old_kubeconfig)}
        nodes = [json.loads(line) for line in self.run(['docker', 'ps', '--filter', 'label=io.x-k8s.kind.cluster=kind', '--format', '{{json .}}']).splitlines()]
        snapshot['containers'] = sorted([{'id': x['ID'], 'name': x['Names'], 'ports': x['Ports']} for x in nodes], key=lambda x: x['name'])
        if len(snapshot['containers']) != 3:
            raise ValueError('Expected three existing old KIND nodes')
        snapshot['storage_identity'] = [os.stat('/data/kind-local-storage').st_dev, os.stat('/data/kind-local-storage').st_ino]
        return snapshot

    def preflight(self):
        self.validate()
        if self.kubeconfig.exists():
            raise ValueError('Target kubeconfig already exists; refusing overwrite')
        clusters = self.run([self.kind, 'get', 'clusters']).splitlines()
        if self.p['name'] in clusters:
            raise ValueError('Target cluster already exists; no automatic recreation')
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', self.p['api_port']))
        available = next(int(l.split()[1]) * 1024 for l in Path('/proc/meminfo').read_text().splitlines() if l.startswith('MemAvailable:'))
        docker_root = self.run(['docker', 'info', '--format', '{{.DockerRootDir}}']).strip()
        if available < 16 * 1024**3 or min(shutil.disk_usage(self.root).free, shutil.disk_usage(docker_root).free) < 30 * 1024**3:
            raise ValueError('Insufficient free memory/disk for the agreed parallel cluster')
        routes = json.loads(self.run(['ip', '-j', 'route', 'show', 'table', 'all']))
        old_config = yaml.safe_load(self.run(['docker', 'exec', 'kind-control-plane', 'kubectl',
            '--kubeconfig', '/etc/kubernetes/admin.conf', '--request-timeout=20s', '-n', 'kube-system',
            'get', 'configmap', 'kubeadm-config', '-o', 'jsonpath={.data.ClusterConfiguration}']))
        old_ranges = [old_config['networking']['podSubnet'], old_config['networking']['serviceSubnet']]
        destinations = old_ranges + [x['dst'] for x in routes if x.get('dst') not in (None, 'default')]
        for cidr in [self.p['pod_subnet'], self.p['service_subnet']]:
            proposed = ipaddress.ip_network(cidr)
            for dest in destinations:
                existing = ipaddress.ip_network(dest, strict=False)
                if existing.version == proposed.version and existing.overlaps(proposed):
                    raise ValueError(f'Network overlap: {cidr} / {dest}')
        return self.old_snapshot()

    def assert_target(self):
        if not self.kubeconfig.exists() or self.kubeconfig.is_symlink():
            raise ValueError('Missing/unsafe target kubeconfig')
        c = yaml.safe_load(self.kubeconfig.read_text())
        expected = 'kind-' + self.p['name']
        if len(c.get('clusters', [])) != 1 or c['clusters'][0]['name'] != expected:
            raise ValueError('Unexpected target cluster identity')
        if c['clusters'][0]['cluster']['server'] != f'https://127.0.0.1:{self.p["api_port"]}':
            raise ValueError('Unexpected API endpoint')
        names = sorted(self.run([self.kind, 'get', 'nodes', '--name', self.p['name']]).splitlines())
        if names != sorted(self.node_names()):
            raise ValueError('Unexpected target node set')
        for n in names:
            label = self.run(['docker', 'inspect', '--format', '{{index .Config.Labels "io.x-k8s.kind.cluster"}}', n]).strip()
            if label != self.p['name']:
                raise ValueError('Node ownership mismatch')

    def node_names(self):
        return [self.p['name'] + suffix for suffix in ['-control-plane', '-worker', '-worker2']]

    def create(self):
        old = self.preflight()
        state = self.validate()
        json_write(self.root / 'old-cluster-before.json', old)
        node = next(i for i in state['images'] if i['id'] == 'node')
        self.run(['docker', 'load', '--platform', self.p['platform'], '--input', self.root / node['path']], timeout=300)
        actual = self.run(['docker', 'image', 'inspect', '--format', '{{.Id}}', node['archive_tag']]).strip()
        if actual != node['docker_image_id']:
            raise ValueError('Loaded node tag does not match the locked image identity')
        self.kubeconfig.parent.mkdir(parents=True, exist_ok=True)
        # No --wait for CNI-dependent Node readiness; no deletion on failure.
        self.run([self.kind, 'create', 'cluster', '--name', self.p['name'], '--config', self.root / 'kind.yaml',
                  '--image', node['archive_tag'], '--kubeconfig', self.kubeconfig, '--retain', '--wait', '0s'], timeout=600)
        self.kubeconfig.chmod(0o600)
        self.assert_target()
        for n in self.node_names():
            self.run(['docker', 'exec', n, 'sh', '-ec',
                'for key in HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; do '
                'if [ -n "$(printenv "$key" || true)" ]; then echo "Unexpected proxy variable: $key"; exit 1; fi; done'])
        # These system images are part of the pinned KIND node payload. Never pull them at runtime.
        for namespace, kind, name in [('kube-system', 'deployment', 'coredns'),
                                       ('kube-system', 'daemonset', 'kube-proxy'),
                                       ('local-path-storage', 'deployment', 'local-path-provisioner')]:
            self.kub('-n', namespace, 'patch', kind, name, '--type=json', '-p',
                json.dumps([{'op': 'add', 'path': '/spec/template/spec/containers/0/imagePullPolicy', 'value': 'Never'}]))
        if old != self.old_snapshot():
            raise ValueError('Old cluster identity/entry/storage changed during create')
        print('CREATED: install CNI next; pre-CNI NotReady is expected')

    def install(self):
        state = self.validate()
        self.assert_target()
        for node in self.node_names():
            for item in state['images']:
                if item['id'] == 'node':
                    continue
                self.run(['docker', 'exec', '-i', node, 'ctr', '-n', 'k8s.io', 'images', 'import',
                          '--platform', self.p['platform'], '-'], stdin_path=self.root / item['path'], timeout=180)
                # Docker archives normalize our local namespace to docker.io on import.
                imported_tag = 'docker.io/' + item['archive_tag']
                self.run(['docker', 'exec', node, 'ctr', '-n', 'k8s.io', 'images', 'tag', '--force', imported_tag, item['reference']])
                self.run(['docker', 'exec', node, 'crictl', 'inspecti', item['reference']])
        self.kub('apply', '--server-side', '--field-manager=sunmoon-isolated', '-f', self.root / 'charts/calico.yaml', timeout=180)
        self.kub('wait', '--for=condition=Ready', 'nodes', '--all', '--timeout=300s', timeout=330)
        self.kub('-n', 'kube-system', 'rollout', 'status', 'ds/calico-node', '--timeout=180s', timeout=210)
        self.kub('-n', 'kube-system', 'rollout', 'status', 'deployment/calico-kube-controllers', '--timeout=180s', timeout=210)
        print('CNI INSTALLED')

    def plan(self):
        s = self.validate()
        print(json.dumps({'cluster': self.p['name'], 'kubernetes': self.p['kubernetes'], 'calico': self.p['calico'],
            'kubeconfig': str(self.kubeconfig), 'api': f'127.0.0.1:{self.p["api_port"]}',
            'pod_subnet': self.p['pod_subnet'], 'service_subnet': self.p['service_subnet'],
            'nodes': self.node_names(), 'host_mounts': [], 'business_ports': [], 'mode': 'offline',
            'artifact_manifest': str(self.root / 'manifest.lock.json'),
            'manifest_sha256': sha(self.root / 'manifest.lock.json'),
            'images': [{k: x[k] for k in ['id', 'reference', 'archive_tag', 'sha256']} for x in s['images']],
            'automatic_delete': False}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', default=str(HERE / 'profile.json'))
    parser.add_argument('--artifacts')
    parser.add_argument('action', choices=['prepare', 'validate', 'plan', 'create', 'install-cni'])
    args = parser.parse_args()
    c = Cluster(args.profile, args.artifacts)
    if args.action in ['validate', 'plan']:
        getattr(c, args.action)()
        return
    c.root.mkdir(parents=True, exist_ok=True)
    with open(c.root / '.operation.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        {'prepare': c.prepare, 'create': c.create, 'install-cni': c.install}[args.action]()


if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError, OSError, KeyError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(1)
