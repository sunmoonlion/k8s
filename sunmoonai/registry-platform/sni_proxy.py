#!/usr/bin/env python3
"""WSL-only SNI lifecycle preparation; default prints only.

No TLS keys, cluster access, deletion, restart policy, global network changes or
30443 handoff. Public proxy preparation/creation leave it stopped; public start
requires the separate maintenance procedure and is not implemented here.
Cloud registry hosts do not use this proxy.
"""
import argparse
import fcntl
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import socket
import stat
import sys
import tarfile

from host_prepare import docker, directory, storage, write
from host_runtime import save
from runtime_inspect import read

HERE = Path(__file__).resolve().parent
BASE = Path('/data/harbor/entry-proxy')
OWNER = 'sunmoonai.registry.sni'
COMMAND = ['-c', '/etc/sunmoon/nginx.conf', '-g', 'daemon off;']
TMPFS = {'/tmp': 'rw,noexec,nosuid,nodev,size=16m,mode=1777',
         '/var/cache/nginx': 'rw,noexec,nosuid,nodev,size=16m,uid=101,gid=101'}


def load(path):
    config = json.loads(read(path.absolute()))
    fields = {'schema', 'deployment', 'mode', 'storage_uuid', 'material_root',
              'listen', 'harbor_upstream', 'default_upstream'}
    transition = config.get('mode') in ('transition-candidate', 'transition')
    if transition:
        fields.add('upstream_node')
    if set(config) != fields or config['schema'] != 1:
        raise ValueError('Unexpected SNI profile')
    if not re.fullmatch(r'sunmoon-sni-[a-z0-9-]{1,50}', config['deployment']):
        raise ValueError('Explicit owned deployment name required')
    if not re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', config['storage_uuid']):
        raise ValueError('Data disk UUID required')
    expected = {'candidate': ('127.0.0.1:28443', '127.0.0.1:30443'),
                'formal': ('0.0.0.0:30443', '127.0.0.1:19443')}
    if transition:
        node = config['upstream_node']
        if (set(node) != {'name', 'id', 'ip', 'network_id'} or node['name'] != 'kind-worker'
                or any(not re.fullmatch(r'[0-9a-f]{64}', node[k]) for k in ('id', 'network_id'))
                or ipaddress.IPv4Address(node['ip']) not in ipaddress.IPv4Network('172.18.0.0/16')):
            raise ValueError('Explicit old worker identity and local KIND IPv4 required')
        expected.update({'transition-candidate': ('127.0.0.1:38443', node['ip'] + ':30443'),
                         'transition': ('0.0.0.0:30443', node['ip'] + ':30443')})
    if (config['mode'] not in expected or (config['listen'], config['default_upstream']) != expected[config['mode']]
            or config['harbor_upstream'] != '127.0.0.1:18443'):
        raise ValueError('Only the declared candidate/transition/formal WSL routing shapes are admitted')
    path = Path(config['material_root'])
    if not path.is_absolute() or path.resolve() != path:
        raise ValueError('Explicit nonsymlink material root required')
    return config


def upstream_identity(config):
    if config['mode'] not in ('transition-candidate', 'transition'):
        return
    expected = config['upstream_node']
    actual = json.loads(docker('inspect', expected['name']))[0]
    network = actual['NetworkSettings']['Networks']['kind']
    if (actual['Id'] != expected['id'] or actual['Name'] != '/' + expected['name']
            or (actual['Config'].get('Labels') or {}).get('io.x-k8s.kind.cluster') != 'kind'
            or not actual['State']['Running'] or network['IPAddress'] != expected['ip']
            or network['NetworkID'] != expected['network_id']):
        raise ValueError('Transition worker identity/address changed; re-inspect, never silently retarget')


def render(config):
    # No HTTP block, TLS termination, resolver, private key, regex or PROXY header.
    return ('''worker_processes 2;
pid /tmp/nginx.pid;
error_log /dev/stderr warn;
worker_shutdown_timeout 60s;
events { worker_connections 2048; }
stream {
    log_format route 'upstream=$upstream_addr status=$status sent=$bytes_sent received=$bytes_received seconds=$session_time';
    access_log /dev/stdout route;
    map $ssl_preread_server_name $destination {
        harbor.sunmoonai.com HARBOR;
        default DEFAULT;
    }
    server {
        listen LISTEN;
        ssl_preread on;
        preread_buffer_size 64k;
        preread_timeout 10s;
        proxy_connect_timeout 5s;
        proxy_timeout 3600s;
        proxy_socket_keepalive on;
        proxy_next_upstream off;
        proxy_pass $destination;
    }
}
'''.replace('HARBOR', config['harbor_upstream']).replace('DEFAULT', config['default_upstream'])
        .replace('LISTEN', config['listen'])).encode()


def image_record():
    return json.loads(read(HERE / 'sni-image.lock.json'))


def image_identity(record):
    info = json.loads(docker('image', 'inspect', record['archive_tag']))[0]
    if (info['Id'] not in {record['platform_digest'], record['config_digest']}
            or info['Architecture'] != 'amd64' or info['Os'] != 'linux'
            or info['Config'].get('Volumes')):
        raise ValueError('SNI image identity/platform/implicit volumes differ')
    return info['Id']


def prepare(config):
    storage({'runtime': {'platform': 'wsl'}, 'storage_uuid': config['storage_uuid']}, minimum_gib=2)
    upstream_identity(config)
    root = BASE / config['deployment']
    if root.exists():
        return Proxy(config).check()
    if BASE.resolve() != BASE:
        raise ValueError('Symlink proxy parent refused')
    if not BASE.exists():
        directory(BASE)
    if BASE.stat().st_uid != 0 or BASE.stat().st_mode & 0o077:
        raise ValueError('Private root-owned proxy parent required')
    record = image_record(); archive = Path(config['material_root']) / record['path']
    if archive.resolve() != archive:
        raise ValueError('Symlink material refused')
    sys.path.insert(0, str(HERE.parent / 'infrastructure/materials'))
    from image_import import inspect_archive
    graph = inspect_archive(archive, record)
    names = docker('image', 'ls', '--format', '{{.Repository}}:{{.Tag}}').decode().splitlines()
    if record['archive_tag'] not in names:
        docker('load', '--input', str(archive), timeout=180)
    image_id = image_identity(record)
    with tarfile.open(archive) as stream:
        raw = stream.extractfile('blobs/sha256/' + record['config_digest'][7:]).read()
    if hashlib.sha256(raw).hexdigest() != record['config_digest'][7:]:
        raise ValueError('Image config content differs')
    actual = json.loads(docker('image', 'inspect', image_id))[0]
    if actual['RootFS']['Layers'] != json.loads(raw)['rootfs']['diff_ids']:
        raise ValueError('Loaded image filesystem differs')
    if config['deployment'] in docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines():
        raise ValueError('Existing container name is not adopted')
    directory(root)
    write(root / 'profile.json', (json.dumps(config, indent=2) + '\n').encode())
    write(root / 'nginx.conf', render(config), mode=0o444)
    write(root / 'state.json', (json.dumps({'schema': 1, 'profile': config, 'image': image_id,
          'image_record': record, 'config_sha256': hashlib.sha256(render(config)).hexdigest(),
          'graph': graph, 'container_id': None}) + '\n').encode())
    return {'prepared': True, 'root': str(root), 'image': image_id}


class Proxy:
    def __init__(self, config):
        self.config = config; self.root = BASE / config['deployment']
        if (os.geteuid() != 0 or self.root.resolve() != self.root or self.root.stat().st_uid != 0
                or self.root.stat().st_mode & 0o077):
            raise ValueError('Exact private root-owned proxy directory required')
        self.state = json.loads(read(self.root / 'state.json'))
        if (self.state.get('schema') != 1 or self.state['profile'] != config
                or json.loads(read(self.root / 'profile.json')) != config):
            raise ValueError('Proxy ownership/profile differs')

    def immutable(self):
        raw = read(self.root / 'nginx.conf')
        if raw != render(self.config) or hashlib.sha256(raw).hexdigest() != self.state['config_sha256']:
            raise ValueError('Proxy config content changed')
        if self.state['image_record'] != image_record() or image_identity(image_record()) != self.state['image']:
            raise ValueError('Proxy image changed')

    def inspect(self):
        info = json.loads(docker('inspect', self.config['deployment']))[0]
        h = info['HostConfig']; c = info['Config']
        if (info['Id'] != self.state['container_id'] or info['Image'] != self.state['image']
                or (c.get('Labels') or {}).get(OWNER) != self.config['deployment']
                or c.get('Entrypoint') != ['nginx'] or c.get('Cmd') != COMMAND or c.get('User') != '101:101'
                or h['NetworkMode'] != 'host' or h['Privileged'] or not h['ReadonlyRootfs']
                or h['RestartPolicy']['Name'] != 'no' or h.get('PortBindings')
                or h.get('CapDrop') != ['ALL'] or h.get('CapAdd')
                or h.get('SecurityOpt') != ['no-new-privileges'] or h.get('Tmpfs') != TMPFS
                or h.get('PidMode') or h.get('Devices') or h.get('Binds')
                or h.get('PidsLimit') != 128 or h.get('Memory') != 256 * 1024**2):
            raise ValueError('Proxy container identity or security contract differs')
        binds = [v for v in info['Mounts'] if v['Type'] != 'tmpfs']
        if len(binds) != 1 or (binds[0]['Type'], binds[0]['Source'], binds[0]['Destination'], binds[0]['RW']) != (
                'bind', str(self.root / 'nginx.conf'), '/etc/sunmoon/nginx.conf', False):
            raise ValueError('Proxy must mount only its public config, no volumes or TLS keys')
        return info

    def check(self):
        self.immutable()
        if self.state['container_id'] is None:
            return {'prepared': True, 'container': 'not_created'}
        info = self.inspect()
        return {'container': info['State']['Status'], 'container_id': info['Id'],
                'listen': self.config['listen'], 'running': info['State']['Running'],
                'public_start_implemented': False}

    def create(self):
        self.immutable()
        if self.state['container_id']:
            return self.check()
        name = self.config['deployment']
        if name in docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines():
            raise ValueError('Unrecorded container exists; no adoption or removal')
        args = ['create', '--name', name, '--label', OWNER + '=' + name, '--pull', 'never',
                '--network', 'host', '--read-only', '--user', '101:101', '--cap-drop', 'ALL',
                '--security-opt', 'no-new-privileges', '--restart', 'no', '--pids-limit', '128',
                '--memory', '256m', '--memory-swap', '256m', '--stop-timeout', '65',
                '--log-driver', 'json-file', '--log-opt', 'max-size=10m', '--log-opt', 'max-file=3',
                '--mount', 'type=bind,source=' + str(self.root / 'nginx.conf') + ',target=/etc/sunmoon/nginx.conf,readonly']
        for path, options in TMPFS.items():
            args += ['--tmpfs', path + ':' + options]
        cid = docker(*args, '--entrypoint', 'nginx', self.state['image'], *COMMAND).decode().strip()
        self.state['container_id'] = cid; save(self.root / 'state.json', self.state)
        return self.check()

    def start(self):
        if self.config['mode'] not in ('candidate', 'transition-candidate'):
            raise ValueError('Public proxy start requires the separate approved maintenance procedure')
        storage({'runtime': {'platform': 'wsl'}, 'storage_uuid': self.config['storage_uuid']}, minimum_gib=2)
        upstream_identity(self.config)
        self.immutable(); info = self.inspect()
        if info['State']['Running']:
            return self.check()
        address, port = self.config['listen'].split(':')
        with socket.socket() as sock:
            sock.bind((address, int(port)))  # Refuse an occupied candidate port.
        docker('start', info['Id'])
        try:
            docker('exec', info['Id'], 'nginx', '-t', '-c', '/etc/sunmoon/nginx.conf')
            version = docker('exec', info['Id'], 'nginx', '-v')  # version is normally stderr
            del version
            if not self.inspect()['State']['Running']:
                raise ValueError('Proxy exited during startup')
        except Exception:
            self.stop(); raise
        return self.check()

    def stop(self):
        # Low space or config drift must not prevent stopping this exact owned ID.
        info = self.inspect()
        if info['State']['Running']:
            docker('stop', '--time', '65', info['Id'], timeout=80)
        if self.inspect()['State']['Running']:
            raise ValueError('Proxy did not stop')
        return {'stopped_and_retained': info['Id']}


def main():
    os.umask(0o077)
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('render', 'prepare', 'create', 'check', 'start', 'stop'))
    p.add_argument('--config', required=True, type=Path); p.add_argument('--apply', action='store_true')
    args = p.parse_args(); config = load(args.config)
    if args.action == 'render':
        print(render(config).decode(), end=''); return
    if not args.apply:
        print(json.dumps({'dry_run': True, 'action': args.action, 'profile': config,
                          'public_prepare_create_stop_implemented': True,
                          'public_start_implemented': False, 'delete': False, 'cloud_proxy': False})); return
    if args.action == 'start' and config['mode'] not in ('candidate', 'transition-candidate'):
        raise ValueError('Formal 30443 handoff requires the separate approved maintenance procedure')
    fd = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb+') as lock:
        if os.fstat(lock.fileno()).st_uid != 0 or stat.S_IMODE(os.fstat(lock.fileno()).st_mode) != 0o600:
            raise ValueError('Unsafe lifecycle lock')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        result = prepare(config) if args.action == 'prepare' else getattr(Proxy(config), args.action)()
        print(json.dumps(result, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('SNI operation stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; diagnostics withheld')) from None
