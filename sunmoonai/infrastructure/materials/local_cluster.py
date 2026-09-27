"""Explicit local Kubernetes connection shared by platform resource adapters.

No implicit kubeconfig, automatic version fallback or deployment-closure bypass.
Never logs a kubeconfig, Secret, private key or Kubernetes command output.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

from bundle import resolve, sha256, verify
from registry_consumer import ca_bytes
from tls_resources import read_file


def arguments(parser):
    parser.add_argument('--root', type=Path, default=Path.home() / 'packages-to-be-installed')
    parser.add_argument('--kubectl', type=Path)
    parser.add_argument('--kubeconfig', type=Path)
    parser.add_argument('--expected-uid')
    parser.add_argument('--ca-file', type=Path)
    parser.add_argument('--ca-sha256')


def locked():
    manifest = Path(__file__).resolve().with_name('cluster-artifacts.lock.json')
    data, entries = resolve(manifest)
    return manifest, data, entries


def connect(args, scopes=()):
    manifest, data, entries = locked()
    if data.get('closure_complete') is not True or data.get('pending'):
        raise ValueError('Deployment closure incomplete; no API contacted')
    if not re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', args.expected_uid or ''):
        raise ValueError('Recorded target cluster UID required')
    for path in (args.kubectl, args.kubeconfig, args.ca_file):
        if not path or not path.is_absolute() or path.resolve() != path or not path.is_file():
            raise ValueError('Explicit absolute non-symlinked target files required')
    tool = next(e for e in entries if e['scope'] == 'tools' and e['path'].endswith('/bin/kubectl'))
    if (sha256(args.kubectl) != tool['sha256'] or args.kubectl.stat().st_mode & 0o022
            or args.kubectl.stat().st_uid not in (0, os.geteuid())):
        raise ValueError('Kubectl differs from the locked tool or has unsafe ownership/mode')
    config_raw = read_file(str(args.kubeconfig), private=True, limit=1024 * 1024)
    config_sha = hashlib.sha256(config_raw).hexdigest()
    root = args.root.expanduser().absolute()
    if root.resolve() != root or not root.is_dir():
        raise ValueError('Explicit non-symlinked material root required')
    verify(root, [e for e in entries if e['scope'] in scopes])
    registry = {'address': 'harbor.sunmoonai.com:30443', 'version': '2.13.2',
                'ca_sha256': args.ca_sha256 or '', 'ca_base64': base64.b64encode(read_file(str(args.ca_file))).decode()}
    ca_bytes(registry)
    command = [str(args.kubectl), '--kubeconfig=' + str(args.kubeconfig), '--request-timeout=30s']

    def raw(*argv, content=None):
        if (hashlib.sha256(read_file(str(args.kubeconfig), private=True, limit=1024 * 1024)).hexdigest() != config_sha
                or sha256(args.kubectl) != tool['sha256']):
            raise ValueError('Local target configuration or kubectl changed during deployment')
        return subprocess.run(command + list(argv), input=content, capture_output=True, check=True, timeout=40).stdout

    config = json.loads(raw('config', 'view', '--minify', '-o', 'json'))
    clusters = config.get('clusters', [])
    users = config.get('users', [])
    if (len(clusters) != 1 or clusters[0]['cluster'].get('insecure-skip-tls-verify')
            or clusters[0]['cluster'].get('proxy-url')
            or not clusters[0]['cluster'].get('server', '').startswith('https://')
            or len(users) != 1 or any(k in users[0]['user'] for k in ('exec', 'auth-provider'))):
        raise ValueError('One explicit TLS-verified API server and static credentials required')

    def guarded(*argv, **kwargs):
        uid = json.loads(raw('get', 'namespace', 'kube-system', '-o', 'json'))['metadata']['uid']
        if uid != args.expected_uid:
            raise ValueError('Live cluster UID differs from the recorded target')
        return raw(*argv, **kwargs)

    version = json.loads(guarded('version', '-o', 'json'))
    if any(version.get(k, {}).get('gitVersion') != 'v' + data['versions']['kubernetes'] for k in ('clientVersion', 'serverVersion')):
        raise ValueError('Client/server versions differ from the lock')
    return guarded, root, manifest, data, registry
