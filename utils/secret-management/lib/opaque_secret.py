#!/usr/bin/env python3
"""Apply business Secret data from a NUL-delimited stdin pipe, never a YAML file.

Called by opaque-deploy.sh. Default prints a plan without reading stdin or API.
Uses the same bound Kubernetes target as registry Secrets. Cloud: 未经实机验证.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'sunmoonai' / 'registry-platform'))
from pull_secret import SecretError, Target, dns_name  # noqa: E402


def read_data():
    limit = 1024 * 1024
    raw = sys.stdin.buffer.read(limit + 1)
    if not raw or len(raw) > limit or not raw.endswith(b'\0'):
        raise SecretError('Secret input is missing, truncated or too large')
    parts = raw[:-1].split(b'\0')
    if len(parts) % 2:
        raise SecretError('Secret input must contain key/value pairs')
    data = {}
    for key, value in zip(parts[::2], parts[1::2]):
        key = key.decode('ascii')
        if not re.fullmatch(r'[a-zA-Z0-9._-]{1,253}', key) or key in data or not value:
            raise SecretError('Secret keys are invalid, duplicated or have empty values')
        data[key] = base64.b64encode(value).decode('ascii')
    # Include base64 expansion and metadata headroom before attempting the API.
    if len(json.dumps(data).encode()) > limit - 8192:
        raise SecretError('Encoded Secret exceeds the permitted payload size')
    return data


def restart_existing_workloads(target, namespace, names):
    # Secret preparation precedes Helm installation on a fresh cluster. A genuine
    # NotFound is expected then; permission/network/restart failures must propagate.
    for name in names:
        target.check()
        for kind in ('deployment', 'statefulset'):
            found = target.command('get', kind, name, '-n', namespace, '-o', 'name', '--ignore-not-found').strip()
            if found:
                target.command('rollout', 'restart', kind + '/' + name, '-n', namespace)
                break
        else:
            print(f'Restart skipped: workload absent {namespace}/{name}; install/readiness still required')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--namespace', required=True)
    parser.add_argument('--name', required=True)
    parser.add_argument('--restart-mode', choices=('none', 'always', 'existing-changed'), default='none')
    parser.add_argument('--restart', action='append', default=[])
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    dns_name(args.namespace)
    dns_name(args.name, subdomain=True)
    for name in args.restart:
        dns_name(name, subdomain=True)
    if not args.apply:
        print(f'Plan: deploy Opaque Secret {args.namespace}/{args.name}; no input or API read')
        return
    if os.environ.get('SUNMOON_DEPLOY_DRY_RUN', 'false') != 'false':
        raise SecretError('Cannot apply with inherited dry-run or invalid mode')
    expected = read_data()
    target = Target()
    target.check()
    target.command('get', 'namespace', args.namespace, '-o', 'name')
    existing = target.secret(args.namespace, args.name)
    if existing is not None and (existing.get('type') != 'Opaque'
                                or existing.get('metadata', {}).get('deletionTimestamp')):
        raise SecretError('Existing Secret has the wrong type or is being deleted')
    payload = {'apiVersion': 'v1', 'kind': 'Secret',
               'metadata': {'name': args.name, 'namespace': args.namespace},
               'type': 'Opaque', 'data': expected}
    target.check()
    target.command('apply', '--server-side', '--field-manager=sunmoon-business-secret', '-f', '-',
                   payload=json.dumps(payload))
    target.check()
    actual = target.secret(args.namespace, args.name)
    if (not actual or actual.get('type') != 'Opaque'
            or actual.get('metadata', {}).get('deletionTimestamp')
            or any(actual.get('data', {}).get(key) != value for key, value in expected.items())):
        raise SecretError('Secret read-back differs; deployment is not accepted')
    changed = existing is not None and existing.get('data', {}) != actual.get('data', {})
    if args.restart_mode == 'always' or (args.restart_mode == 'existing-changed' and changed):
        restart_existing_workloads(target, args.namespace, args.restart)
    print(f'Business Secret applied and read back: {args.namespace}/{args.name}; '
          'workload readiness and database login not checked')


if __name__ == '__main__':
    try:
        main()
    except SecretError as exc:
        raise SystemExit(str(exc)) from None
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        raise SystemExit('Invalid business Secret input or response; private details suppressed') from None
