#!/usr/bin/env python3
"""Node-side kubeadm/Calico operations. 云上未经实机验证。

Only invoked with a private request file and explicit identity by node_control.
No resets, deletion of data, unpinned pulls or fallback initialization commands.
Join credentials stay in root-private files and the controller's SSH pipe.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import sys
import time

from bundle import below, resolve, sha256, verify
from cluster_config import init_documents, join_document, multi_json, validate, kubeadm_patches
from image_import import import_images, inspect_archive, records
from node_install import host_preflight
from os_install import safe_directory, exact_file
from cluster_resources import execute as resource_execute, identity as resource_identity
from storage_resources import execute as storage_execute, images as storage_images
from storage_host import execute as storage_host_execute


def run(argv, timeout=90, content=None):
    return subprocess.run(argv, input=content, check=True, capture_output=True, timeout=timeout).stdout


def kub(*args, timeout=90, content=None):
    return run(['/usr/local/bin/kubectl', '--kubeconfig=/etc/kubernetes/admin.conf',
                '--request-timeout=30s', *args], timeout=timeout, content=content)


def private_json(path, value):
    exact_file(path, (json.dumps(value, sort_keys=True, indent=2) + '\n').encode(), 0o600)


def ca_pin():
    public = run(['openssl', 'x509', '-in', '/etc/kubernetes/pki/ca.crt', '-pubkey', '-noout'])
    der = run(['openssl', 'pkey', '-pubin', '-outform', 'DER'], content=public)
    return 'sha256:' + hashlib.sha256(der).hexdigest()


def current_cluster(work):
    receipt = json.loads((work / 'init-complete.json').read_text())
    uid = json.loads(kub('get', 'namespace', 'kube-system', '-o', 'json'))['metadata']['uid']
    if uid != receipt['uid'] or ca_pin() != receipt['ca_pin']:
        raise ValueError('Live cluster UID/CA differs from the initialization receipt')
    kub('get', '--raw=/readyz')
    return receipt


def logged(work, phase, argv):
    # kubeadm can print bootstrap credentials. Never forward its output to the
    # terminal or put credentials into argv; retain root-private logs instead.
    log = work / (str(time.time_ns()) + '-' + phase + '.log')
    fd = os.open(log, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as output:
        subprocess.run(argv, check=True, stdout=output, stderr=subprocess.STDOUT, timeout=900)


def installed_journals(data, manifest, hostname, machine_id):
    for phase in ('runtime', 'kubernetes'):
        path = Path('/var/lib/sunmoon/bootstrap') / (data['batch'] + '-' + phase + '.json')
        if path.resolve() != path or path.stat().st_uid != 0 or path.stat().st_mode & 0o022:
            raise ValueError('Unsafe node installation journal')
        journal = json.loads(path.read_text())
        identity = journal['identity']
        if (journal['state'] != 'complete' or identity['hostname'] != hostname
                or identity['machine_id'] != machine_id or identity['manifest_sha256'] != sha256(manifest)):
            raise ValueError('Node installation journal differs from this machine/material lock')
        for entry in identity['files']:
            file = Path(entry['path'])
            if file.resolve() != file or sha256(file) != entry['sha256']:
                raise ValueError('Installed node binary/configuration changed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--request', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--hostname', required=True)
    parser.add_argument('--machine-id', required=True)
    parser.add_argument('--phase', choices=('preflight', 'images', 'init', 'cni', 'ticket', 'join', 'status', 'revoke', 'resources', 'storage-check', 'storage-host'), required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if not args.apply:
        print(json.dumps({'dry_run': True, 'phase': args.phase, 'cloud_validated': False})); return
    if args.request.resolve() != args.request or args.request.stat().st_uid != 0 or args.request.stat().st_mode & 0o077:
        raise ValueError('Request must be root-private, non-symlinked')
    request = json.loads(args.request.read_text())
    profile = validate(request['profile'])
    node = next(n for n in profile['nodes'] if n['name'] == args.hostname)
    data, entries = resolve(args.manifest)
    if data.get('closure_complete') is not True or data.get('pending'):
        raise ValueError('Cluster deployment closure incomplete')
    root = args.root.absolute()
    if root.resolve() != root:
        raise ValueError('Symlinked material root refused')
    verify(root, entries)
    installed_journals(data, args.manifest, args.hostname, args.machine_id)
    work = Path('/var/lib/sunmoon/clusters') / profile['cluster']
    for parent in (work, *work.parents):
        if parent.resolve() != parent or (parent.exists() and (not parent.is_dir()
                or parent.stat().st_uid != 0 or parent.stat().st_mode & 0o022)):
            raise ValueError('Unsafe cluster receipt directory')
    identity = {'profile': profile, 'manifest_sha256': sha256(args.manifest),
                'hostname': args.hostname, 'machine_id': args.machine_id}
    # First check previously recorded ownership before allowing existing state.
    owned = False
    if (work / 'identity.json').exists():
        if json.loads((work / 'identity.json').read_text()) != identity:
            raise ValueError('Cluster/node profile changed; do not overwrite prior state')
        owned = any((work / f).exists() for f in ('init-complete.json', 'join-complete.json'))
    host_preflight(args, allow_owned_cluster=owned)
    run(['systemctl', 'is-active', '--quiet', 'containerd'])
    if owned and node['role'] == 'master':
        current_cluster(work)
    if args.phase == 'preflight':
        addresses = json.loads(run(['ip', '-j', '-4', 'address', 'show']))
        if node['ip'] not in {a['local'] for dev in addresses for a in dev.get('addr_info', []) if a.get('family') == 'inet'}:
            raise ValueError('Configured node IP is not assigned to this host')
        if shutil.disk_usage('/var/lib').free < 4 * 1024**3:
            raise ValueError('Less than 4 GiB available for staged images/runtime data; no cleanup attempted')
        if run(['timedatectl', 'show', '--property=NTPSynchronized', '--value']).decode().strip() != 'yes':
            raise ValueError('Node clock is not synchronized')
        for item in records(args.manifest, data):
            inspect_archive(below(root, item['material_path']), item)
        print(json.dumps({'preflight': True, 'node': node['name']})); return
    safe_directory(work)
    private_json(work / 'identity.json', identity)
    if args.phase == 'images':
        imported = import_images(root, args.manifest, data, work)
        private_json(work / 'images-complete.json', {'images': imported, **identity})
        print(json.dumps({'images': len(imported), 'node': node['name']})); return
    images = json.loads((work / 'images-complete.json').read_text())
    if any(images.get(k) != v for k, v in identity.items()):
        raise ValueError('Image completion belongs to another installation')
    if args.phase in ('storage-check', 'storage-host'):
        record = work / ('init-complete.json' if node['role'] == 'master' else 'join-complete.json')
        receipt = json.loads(record.read_text())
        if receipt['uid'] != request.get('expected_uid') or ca_pin() != receipt['ca_pin']:
            raise ValueError('Storage preparation requires matching cluster UID/CA')
        result = storage_host_execute(root, args.manifest, data, work, request['spec'], node['name'],
                                      receipt['uid'], apply=args.phase == 'storage-host')
        print(json.dumps(result)); return
    if args.phase == 'init':
        if node['role'] != 'master':
            raise ValueError('Initialization only allowed on the single declared master')
        if (work / 'init-complete.json').exists():
            print(json.dumps(current_cluster(work))); return
        docs = init_documents(profile, data)
        patches, proxy_patch = kubeadm_patches(records(args.manifest, data))
        patch_dir = work / 'patches'
        safe_directory(patch_dir)
        if {p.name for p in patch_dir.iterdir()} - set(patches):
            raise ValueError('Unexpected kubeadm patch file retained; inspect before initializing')
        for name, patch in patches.items():
            private_json(patch_dir / name, patch)
        # An expiring bootstrap token is explicit; kubeadm defaults must not
        # create a longer-lived token. It is never printed by this program.
        token = ''.join(secrets.choice('abcdefghijklmnopqrstuvwxyz0123456789') for _ in range(6)) + '.' + secrets.token_hex(8)
        docs[0]['bootstrapTokens'] = [{'token': token, 'ttl': '10m0s',
                                     'usages': ['signing', 'authentication'],
                                     'groups': ['system:bootstrappers:kubeadm:default-node-token']}]
        cfg = work / ('init-' + str(time.time_ns()) + '.yaml')
        exact_file(cfg, multi_json(docs).encode(), 0o600)
        run(['/usr/local/bin/kubeadm', 'config', 'validate', '--config', str(cfg)])
        expected = run(['/usr/local/bin/kubeadm', 'config', 'images', 'list', '--config', str(cfg)]).decode().splitlines()
        if expected != data['kubeadm_images']:
            raise ValueError('kubeadm requires images outside the locked list')
        logged(work, 'init', ['/usr/local/bin/kubeadm', 'init', '--config', str(cfg), '--skip-token-print'])
        # kube-proxy is not a supported v1beta4 patch-directory target. Its
        # initial tag already resolves to the verified local image; pin the
        # DaemonSet before workers join and before reporting init completion.
        kub('-n', 'kube-system', 'patch', 'daemonset', 'kube-proxy', '--type=strategic', '-p', json.dumps(proxy_patch))
        uid = json.loads(kub('get', 'namespace', 'kube-system', '-o', 'json'))['metadata']['uid']
        receipt = {'uid': uid, 'ca_pin': ca_pin(), 'endpoint': profile['endpoint'],
                   'kubeconfig': '/etc/kubernetes/admin.conf', 'kubectl': '/usr/local/bin/kubectl'}
        Path('/etc/kubernetes/admin.conf').chmod(0o600)
        private_json(work / 'init-complete.json', receipt)
        print(json.dumps(receipt)); return
    if args.phase == 'join':
        ticket = request['ticket']
        config = join_document(profile, node, ticket)
        if (work / 'join-complete.json').exists():
            receipt = json.loads((work / 'join-complete.json').read_text())
            if receipt['uid'] != ticket['uid'] or ca_pin() != ticket['ca_pin']:
                raise ValueError('Existing worker belongs to another cluster')
        else:
            cfg = work / ('join-' + str(time.time_ns()) + '.json')
            private_json(cfg, config)
            run(['/usr/local/bin/kubeadm', 'config', 'validate', '--config', str(cfg)])
            logged(work, 'join', ['/usr/local/bin/kubeadm', 'join', '--config', str(cfg)])
            if ca_pin() != ticket['ca_pin']:
                raise ValueError('Joined CA differs from the ticket')
            private_json(work / 'join-complete.json', {'uid': ticket['uid'], 'ca_pin': ticket['ca_pin'], 'node': node['name']})
        print(json.dumps({'joined': node['name'], 'uid': ticket['uid']})); return
    if node['role'] != 'master':
        raise ValueError('This operation requires the declared master')
    receipt = current_cluster(work)
    if request.get('expected_uid') and request['expected_uid'] != receipt['uid']:
        raise ValueError('Controller expected UID differs')
    if args.phase == 'resources':
        if request.get('expected_uid') != receipt['uid']:
            raise ValueError('Resource operations require an explicit expected cluster UID')
        spec = request['spec']
        expected = spec['expected']
        if (expected['version'] != 'v' + data['versions']['kubernetes']
                or [{k: n[k] for k in ('name', 'ip', 'role')} for n in expected['nodes']] != profile['nodes']
                or any(not re.fullmatch(r'[0-9a-f]{32}', n['machine_id']) for n in expected['nodes'])):
            raise ValueError('Resource node/version identities differ from the initialization profile')
        def guarded_kub(*argv, **kwargs):
            current_cluster(work)
            return kub(*argv, **kwargs)
        log = work / ('resources-' + str(time.time_ns()) + '.json')
        try:
            resource_identity(guarded_kub, expected)
            if request['action'] in ('storage', 'storage-preflight'):
                result = storage_execute(guarded_kub, spec, storage_images(args.manifest, data), receipt['uid'],
                                         check_only=request['action'] == 'storage-preflight')
            else:
                result = resource_execute(guarded_kub, request['action'], spec, receipt['uid'])
            current_cluster(work)
        except (OSError, ValueError, KeyError, StopIteration, subprocess.SubprocessError) as error:
            # Kubectl diagnostics may contain private data. Keep them on the
            # target in 0600 files, never forward raw SSH/subprocess output.
            diagnostic = getattr(error, 'stderr', b'') or b''
            if isinstance(diagnostic, bytes):
                diagnostic = diagnostic.decode(errors='replace')
            private_json(log, {'action': request['action'], 'uid': receipt['uid'],
                              'state': 'failed', 'error_type': type(error).__name__,
                              'reason': str(error) if isinstance(error, ValueError) else '', 'stderr': diagnostic})
            raise
        private_json(log, {'action': request['action'], 'uid': receipt['uid'], 'state': 'complete', 'result': result})
        print(json.dumps(result)); return
    if args.phase == 'ticket':
        cni = json.loads((work / 'cni-complete.json').read_text())
        if cni['uid'] != receipt['uid']:
            raise ValueError('Matching Calico completion is required before issuing worker tickets')
        token = run(['/usr/local/bin/kubeadm', 'token', 'create', '--kubeconfig=/etc/kubernetes/admin.conf', '--ttl=10m']).decode().strip()
        if not re.fullmatch(r'[a-z0-9]{6}\.[a-z0-9]{16}', token):
            raise ValueError('Unexpected kubeadm token response')
        # Protocol response: the controller captures this in memory, never logs it.
        print(json.dumps({**receipt, 'token': token})); return
    if args.phase == 'revoke':
        token_id = request['token_id']
        if not re.fullmatch(r'[a-z0-9]{6}', token_id):
            raise ValueError('Invalid bootstrap token identifier')
        run(['/usr/local/bin/kubeadm', 'token', 'delete', token_id, '--kubeconfig=/etc/kubernetes/admin.conf'])
        print(json.dumps({'revoked': True})); return
    if args.phase == 'cni':
        objects = request['calico']
        if objects.get('kind') != 'List' or len(objects['items']) != 38:
            raise ValueError('Unexpected rendered Calico object set')
        path = work / 'calico.json'
        private_json(path, objects)
        for obj in objects['items']:
            argv = ['get', obj['kind'], obj['metadata']['name'], '--ignore-not-found', '-o', 'json']
            if obj['metadata'].get('namespace'):
                argv += ['-n', obj['metadata']['namespace']]
            existing = kub(*argv)
            if existing and json.loads(existing).get('metadata', {}).get('labels', {}).get('sunmoonai.com/cluster-bootstrap') != profile['cluster']:
                raise ValueError('Existing unmanaged Calico object retained')
        logged(work, 'calico', ['/usr/local/bin/kubectl', '--kubeconfig=/etc/kubernetes/admin.conf',
                               '--request-timeout=60s', 'apply', '--server-side', '--field-manager=sunmoon-bootstrap', '-f', str(path)])
        kub('-n', 'kube-system', 'rollout', 'status', 'daemonset/calico-node', '--timeout=300s', timeout=330)
        kub('-n', 'kube-system', 'rollout', 'status', 'deployment/calico-kube-controllers', '--timeout=300s', timeout=330)
        private_json(work / 'cni-complete.json', {'uid': receipt['uid'], 'manifest_sha256': sha256(path)})
        print(json.dumps({'calico_ready': True, 'uid': receipt['uid']})); return
    if args.phase == 'status':
        target = request.get('wait_node')
        if target:
            if target not in {n['name'] for n in profile['nodes']}:
                raise ValueError('Unknown node to await')
            kub('wait', '--for=condition=Ready', 'node/' + target, '--timeout=300s', timeout=330)
        nodes = json.loads(kub('get', 'nodes', '-o', 'json'))['items']
        result = []
        for n in nodes:
            result.append({'name': n['metadata']['name'], 'machine_id': n['status']['nodeInfo']['machineID'],
                           'kubelet_version': n['status']['nodeInfo']['kubeletVersion'],
                           'ips': [a['address'] for a in n['status']['addresses'] if a['type'] == 'InternalIP'],
                           'ready': any(c['type'] == 'Ready' and c['status'] == 'True' for c in n['status']['conditions'])})
        print(json.dumps({**receipt, 'nodes': result})); return


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, StopIteration, subprocess.SubprocessError) as error:
        # Do not stringify subprocess exceptions or captured kubeadm output.
        message = str(error) if isinstance(error, ValueError) else type(error).__name__
        print('Cluster node stopped: ' + message, file=sys.stderr)
        sys.exit(1)
