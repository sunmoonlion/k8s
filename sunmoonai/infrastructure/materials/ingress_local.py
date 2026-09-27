#!/usr/bin/env python3
"""KIND ingress adapter for the same implementation as cloud step13.

Default print-only. Explicit tool, kubeconfig, cluster UID and public CA required.
Does not create clusters, import node images, operate Harbor or change host ports.
"""
import argparse
import base64
import json
from pathlib import Path
import re
import subprocess
import sys

from bundle import resolve, sha256, verify
from ingress_resources import execute
from tls_resources import read_file
from registry_consumer import ca_bytes


def main():
    p = argparse.ArgumentParser(description=__doc__)
    actions = p.add_mutually_exclusive_group()
    actions.add_argument('--apply', action='store_true')
    actions.add_argument('--verify', action='store_true')
    actions.add_argument('--dry-run', action='store_true')
    p.add_argument('--profile', choices=('dev', 'prod'), default='dev')
    p.add_argument('--root', type=Path, default=Path.home() / 'packages-to-be-installed')
    p.add_argument('--kubectl', type=Path)
    p.add_argument('--kubeconfig', type=Path)
    p.add_argument('--expected-uid')
    p.add_argument('--ca-file', type=Path)
    p.add_argument('--ca-sha256')
    p.add_argument('--timeout', type=int, default=300)
    args = p.parse_args()
    manifest = Path(__file__).resolve().with_name('cluster-artifacts.lock.json')
    data, entries = resolve(manifest)
    if not 1 <= args.timeout <= 600:
        raise ValueError('Timeout must be 1..600 seconds')
    if not (args.apply or args.verify):
        print(json.dumps({'dry_run': True, 'adapter': 'local', 'profile': args.profile,
                          'version': data['versions']['traefik'], 'chart': data['versions']['traefik_chart'],
                          'closure_complete': data['closure_complete'], 'api_calls': False,
                          'requires': ['recorded cluster UID', 'SHA-pinned kubectl and private kubeconfig',
                                       'public CA file and SHA', 'owned TLS Secret', 'node images loaded by digest'],
                          'implementation': 'ingress_resources.execute', 'harbor_changed': False})); return
    if data.get('closure_complete') is not True or data.get('pending'):
        raise ValueError('Deployment closure incomplete; no API contacted')
    if not re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', args.expected_uid or ''):
        raise ValueError('Recorded target cluster UID required')
    for path in (args.kubectl, args.kubeconfig, args.ca_file):
        if not path or not path.is_absolute() or path.resolve() != path or not path.is_file():
            raise ValueError('Explicit absolute non-symlinked target files required')
    if args.kubeconfig.stat().st_mode & 0o077:
        raise ValueError('Kubeconfig must be private (0600)')
    tool = next(e for e in entries if e['scope'] == 'tools' and e['path'].endswith('/bin/kubectl'))
    if sha256(args.kubectl) != tool['sha256']:
        raise ValueError('Kubectl differs from the locked version')
    root = args.root.expanduser().absolute()
    if root.resolve() != root or not root.is_dir():
        raise ValueError('Explicit non-symlinked material root required')
    verify(root, [e for e in entries if e['scope'] == 'ingress'])
    registry = {'address': 'harbor.sunmoonai.com:30443', 'version': '2.13.2',
                'ca_sha256': args.ca_sha256 or '', 'ca_base64': base64.b64encode(read_file(str(args.ca_file))).decode()}
    ca_bytes(registry)
    command = [str(args.kubectl), '--kubeconfig=' + str(args.kubeconfig), '--request-timeout=30s']

    def raw(*argv, content=None):
        return subprocess.run(command + list(argv), input=content, capture_output=True, check=True, timeout=40).stdout

    config = json.loads(raw('config', 'view', '--minify', '-o', 'json'))
    clusters = config.get('clusters', [])
    if (len(clusters) != 1 or clusters[0]['cluster'].get('insecure-skip-tls-verify')
            or not clusters[0]['cluster'].get('server', '').startswith('https://')):
        raise ValueError('One explicit TLS-verified API server required')

    def guarded(*argv, **kwargs):
        uid = json.loads(raw('get', 'namespace', 'kube-system', '-o', 'json'))['metadata']['uid']
        if uid != args.expected_uid:
            raise ValueError('Live cluster UID differs from the recorded target')
        return raw(*argv, **kwargs)

    version = json.loads(guarded('version', '-o', 'json'))
    if any(version.get(k, {}).get('gitVersion') != 'v' + data['versions']['kubernetes'] for k in ('clientVersion', 'serverVersion')):
        raise ValueError('Client/server versions differ from the lock')
    spec = {'profile': args.profile, 'timeout': args.timeout, 'registry': registry, 'verify_only': args.verify}
    result = execute(guarded, root, manifest, data, spec, args.expected_uid)
    print(json.dumps({'uid': args.expected_uid, **result}))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, StopIteration, subprocess.SubprocessError) as error:
        # No Secret or subprocess output in diagnostics.
        print('Local ingress stopped: ' + (str(error) if isinstance(error, ValueError) else type(error).__name__), file=sys.stderr)
        sys.exit(1)
