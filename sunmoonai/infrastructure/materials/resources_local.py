#!/usr/bin/env python3
"""Local namespace adapter using the same implementation as cloud step07.

Default print-only. No current-context fallback, storage changes or SSH.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from bundle import resolve, sha256
from cluster_resources import namespaces, execute


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--apply', action='store_true')
    action.add_argument('--dry-run', action='store_true')
    parser.add_argument('--kubectl', type=Path)
    parser.add_argument('--kubeconfig', type=Path)
    parser.add_argument('--expected-uid')
    args = parser.parse_args()
    data, entries = resolve(Path(__file__).resolve().parent / 'cluster-artifacts.lock.json')
    flags = [os.environ.get('SM_NAMESPACE_ENABLED'), os.environ.get('SM_NAMESPACE_POLICIES')]
    if any(f not in ('true', 'false') for f in flags):
        raise ValueError('Explicit namespace booleans required')
    spec = {'environments': os.environ['SM_NAMESPACE_ENVIRONMENTS'],
            'platforms': os.environ['SM_NAMESPACE_PLATFORMS'], 'policies': flags[1] == 'true', 'timeout': 300}
    objects = namespaces(spec['environments'], spec['platforms'], spec['policies'])
    if not args.apply:
        print(json.dumps({'dry_run': True, 'adapter': 'local', 'enabled': flags[0] == 'true',
                          'namespaces': objects, 'version': data['versions']['kubernetes'],
                          'requires': ['explicit kubectl/kubeconfig/expected UID', 'locked kubectl SHA',
                                       'matching TLS-verified server version', 'existing namespace owner check'],
                          'api_calls': False, 'storage_changes': False}, ensure_ascii=False, indent=2)); return
    if flags[0] == 'false':
        print(json.dumps({'skipped': True, 'reason': 'explicit configuration', 'api_calls': False})); return
    if not args.kubectl or not args.kubeconfig or not re.fullmatch(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', args.expected_uid or ''):
        raise ValueError('Explicit --kubectl, --kubeconfig and recorded --expected-uid required')
    for path in (args.kubectl, args.kubeconfig):
        if not path.is_absolute() or path.resolve() != path or not path.is_file():
            raise ValueError('Expected absolute regular, non-symlinked target files')
    if args.kubeconfig.stat().st_mode & 0o077:
        raise ValueError('Kubeconfig must be private (0600)')
    tool = next(e for e in entries if e['scope'] == 'tools' and e['path'].endswith('/bin/kubectl'))
    if sha256(args.kubectl) != tool['sha256']:
        raise ValueError('Kubectl checksum differs from cluster lock')
    command = [str(args.kubectl), '--kubeconfig=' + str(args.kubeconfig), '--request-timeout=30s']

    def raw(*argv, content=None):
        return subprocess.run(command + list(argv), input=content, capture_output=True, check=True, timeout=40).stdout

    # Capture config privately: never print certs, credentials or plugin output.
    config = json.loads(raw('config', 'view', '--minify', '-o', 'json'))
    clusters = config.get('clusters', [])
    if (len(clusters) != 1 or clusters[0]['cluster'].get('insecure-skip-tls-verify')
            or not clusters[0]['cluster'].get('server', '').startswith('https://')):
        raise ValueError('One explicit TLS-verified API server required')

    def guarded(*argv, **kwargs):
        actual = json.loads(raw('get', 'namespace', 'kube-system', '-o', 'json'))['metadata']['uid']
        if actual != args.expected_uid:
            raise ValueError('Live cluster UID differs from recorded target')
        return raw(*argv, **kwargs)

    version = json.loads(guarded('version', '-o', 'json'))
    if any(version.get(k, {}).get('gitVersion') != 'v' + data['versions']['kubernetes'] for k in ('clientVersion', 'serverVersion')):
        raise ValueError('Client/server version differs from the locked target')
    result = execute(guarded, 'namespaces', spec, args.expected_uid)
    guarded('get', '--raw=/readyz')
    print(json.dumps({'uid': args.expected_uid, **result}))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, StopIteration, subprocess.SubprocessError) as error:
        message = str(error) if isinstance(error, ValueError) else type(error).__name__
        print('Local resource operation stopped: ' + message, file=sys.stderr)
        sys.exit(1)
