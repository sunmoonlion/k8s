#!/usr/bin/env python3
"""KIND adapter consuming the same signed TLS bundle as cloud step12.

Default print-only. No issuance, CA rotation, Secret overwrite or service restart.
"""
import argparse
import json
import subprocess
import sys

from local_cluster import arguments, connect, locked
from tls_resources import execute, load_bundle


def main():
    p = argparse.ArgumentParser(description=__doc__)
    actions = p.add_mutually_exclusive_group()
    actions.add_argument('--apply', action='store_true')
    actions.add_argument('--verify', action='store_true')
    actions.add_argument('--dry-run', action='store_true')
    arguments(p)
    p.add_argument('--tls-bundle')
    args = p.parse_args()
    if not (args.apply or args.verify):
        _, data, _ = locked()
        print(json.dumps({'dry_run': True, 'adapter': 'local', 'implementation': 'tls_resources.execute',
            'closure_complete': data['closure_complete'], 'api_calls': False, 'private_inputs_read': False,
            'requires': ['recorded cluster UID', 'SHA-pinned kubectl and private kubeconfig',
                         'public CA file and SHA', 'private signed TLS bundle', 'owned namespaces'],
            'ca_rotated': False, 'existing_secrets_overwritten': False})); return
    if not args.tls_bundle:
        raise ValueError('Explicit private TLS bundle required')
    # Gate closure and pin CA/cluster identity; then validate all certificate
    # inputs before any Secret operation.
    guarded, _, _, _, registry = connect(args)
    payload = load_bundle(args.tls_bundle, registry)
    result = execute(guarded, payload, args.expected_uid, verify_only=args.verify)
    print(json.dumps({'uid': args.expected_uid, **result}))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, StopIteration, subprocess.SubprocessError) as error:
        print('Local TLS stopped: ' + (str(error) if isinstance(error, ValueError) else type(error).__name__), file=sys.stderr)
        sys.exit(1)
