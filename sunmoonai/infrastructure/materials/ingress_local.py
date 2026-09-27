#!/usr/bin/env python3
"""KIND ingress adapter for the same implementation as cloud step13.

Default print-only. Explicit tool, kubeconfig, cluster UID and public CA required.
Does not create clusters, import node images, operate Harbor or change host ports.
"""
import argparse
import json
import subprocess
import sys

from ingress_resources import execute
from local_cluster import arguments, connect, locked


def main():
    p = argparse.ArgumentParser(description=__doc__)
    actions = p.add_mutually_exclusive_group()
    actions.add_argument('--apply', action='store_true')
    actions.add_argument('--verify', action='store_true')
    actions.add_argument('--dry-run', action='store_true')
    p.add_argument('--profile', choices=('dev', 'prod'), default='dev')
    arguments(p)
    p.add_argument('--timeout', type=int, default=300)
    args = p.parse_args()
    _, data, _ = locked()
    if not 1 <= args.timeout <= 600:
        raise ValueError('Timeout must be 1..600 seconds')
    if not (args.apply or args.verify):
        print(json.dumps({'dry_run': True, 'adapter': 'local', 'profile': args.profile,
                          'version': data['versions']['traefik'], 'chart': data['versions']['traefik_chart'],
                          'closure_complete': data['closure_complete'], 'api_calls': False,
                          'requires': ['recorded cluster UID', 'SHA-pinned kubectl and private kubeconfig',
                                       'public CA file and SHA', 'owned TLS Secret', 'node images loaded by digest'],
                          'implementation': 'ingress_resources.execute', 'harbor_changed': False})); return
    guarded, root, manifest, data, registry = connect(args, scopes=('ingress',))
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
