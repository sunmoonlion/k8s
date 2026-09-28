#!/usr/bin/env python3
"""Deploy a pull Secret using private credentials and an explicitly bound target.

Default: print a plan. Cloud execution: 未经实机验证.
Secret payloads stay in memory/stdin; subprocess diagnostics are never printed.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

from credentials import REGISTRY, docker_config, load_credentials


class SecretError(Exception):
    pass


def dns_name(value, *, subdomain=False):
    limit = 253 if subdomain else 63
    label = r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
    pattern = label + (r'(?:\.' + label + r')*' if subdomain else '')
    if len(value) > limit or not re.fullmatch(pattern, value):
        raise SecretError('Invalid Secret name, namespace or workload name')
    return value


class Target:
    def __init__(self):
        pairs = [('CLUSTER', 'SUNMOON_DEPLOY_BOUND_CLUSTER'),
                 ('KUBECONFIG', 'SUNMOON_DEPLOY_BOUND_KUBECONFIG'),
                 ('SUNMOON_KUBECTL', 'SUNMOON_DEPLOY_BOUND_KUBECTL'),
                 ('SUNMOON_EXPECTED_CLUSTER_UID', 'SUNMOON_DEPLOY_BOUND_UID')]
        if os.environ.get('SUNMOON_DEPLOY_TARGET_REQUIRED') != '1' or any(
                not os.environ.get(a) or os.environ.get(a) != os.environ.get(b)
                for a, b in pairs):
            raise SecretError('Target must be admitted by the shared deployment entry')
        self.config = Path(os.environ['KUBECONFIG'])
        self.tool = Path(os.environ['SUNMOON_KUBECTL'])
        self.uid = os.environ['SUNMOON_EXPECTED_CLUSTER_UID']
        if (not self.config.is_absolute() or not self.tool.is_absolute()
                or self.config.resolve() != self.config or self.tool.resolve() != self.tool
                or not self.tool.is_file() or not os.access(self.tool, os.X_OK)
                or not re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', self.uid)):
            raise SecretError('Invalid explicit target')

    def command(self, *args, payload=None):
        if hashlib.sha256(self.config.read_bytes()).hexdigest() != os.environ.get(
                'SUNMOON_DEPLOY_BOUND_CONFIG_SHA256'):
            raise SecretError('Kubeconfig changed after admission')
        try:
            result = subprocess.run(
                [str(self.tool), '--kubeconfig', str(self.config), '--request-timeout=10s', *args],
                input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True, timeout=25, check=False)
        except (OSError, subprocess.TimeoutExpired):
            raise SecretError('Kubernetes command could not complete; no fallback attempted') from None
        if result.returncode:
            # API errors can include submitted Secret data. Keep all raw output private.
            raise SecretError('Kubernetes request failed; check access, connectivity and field ownership. '
                              'Raw output suppressed because it may contain credentials.')
        return result.stdout

    def check(self):
        uid = self.command('get', 'ns', 'kube-system', '-o', 'jsonpath={.metadata.uid}')
        if uid != self.uid:
            raise SecretError('Cluster UID changed; operation refused')

    def secret(self, namespace, name):
        raw = self.command('get', 'secret', name, '-n', namespace, '-o', 'json', '--ignore-not-found')
        return json.loads(raw) if raw.strip() else None


def restart_workloads(target, namespace, names):
    # Preserve configured restarts, but distinguish NotFound from authorization/network errors.
    for name in names:
        target.check()
        for kind in ('deployment', 'statefulset'):
            found = target.command('get', kind, name, '-n', namespace, '-o', 'name', '--ignore-not-found').strip()
            if found:
                target.command('rollout', 'restart', kind + '/' + name, '-n', namespace)
                break
        else:
            raise SecretError('Configured restart workload is missing; Secret may already be updated')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('deploy', 'status', 'uninstall'))
    parser.add_argument('--namespace', required=True)
    parser.add_argument('--name', required=True)
    parser.add_argument('--restart', action='append', default=[])
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    dns_name(args.namespace)
    dns_name(args.name, subdomain=True)
    for name in args.restart:
        dns_name(name, subdomain=True)
    if not args.apply:
        print(f'Plan: {args.action} pull Secret {args.namespace}/{args.name}; registry={REGISTRY}')
        return
    if os.environ.get('SUNMOON_DEPLOY_DRY_RUN', 'false') != 'false':
        raise SecretError('Cannot execute with inherited dry-run or invalid mode')
    target = Target()
    expected = None
    if args.action == 'deploy':
        path = os.environ.get('REGISTRY_CREDENTIALS_FILE')
        if not path:
            raise SecretError('REGISTRY_CREDENTIALS_FILE is required; legacy passwords are not used')
        expected = base64.b64encode(docker_config(load_credentials(path)).encode()).decode()
    target.check()
    existing = target.secret(args.namespace, args.name)
    if existing is not None and (existing.get('type') != 'kubernetes.io/dockerconfigjson'
                                or existing.get('metadata', {}).get('deletionTimestamp')):
        raise SecretError('Existing Secret has the wrong type or is being deleted')
    if args.action == 'status':
        if existing is None:
            raise SecretError('Pull Secret does not exist')
        # Validate the registry key without displaying data or requiring local credentials.
        raw = base64.b64decode(existing['data']['.dockerconfigjson'], validate=True)
        auths = json.loads(raw).get('auths', {})
        if set(auths) != {REGISTRY} or not isinstance(auths[REGISTRY], dict):
            raise SecretError('Pull Secret does not exclusively target the approved registry')
        print(f'Pull Secret present: {args.namespace}/{args.name}; registry={REGISTRY}; login not checked')
        return
    target.check()
    if args.action == 'uninstall':
        target.command('delete', 'secret', args.name, '-n', args.namespace, '--ignore-not-found', '--wait=false')
        print(f'Pull Secret deletion requested: {args.namespace}/{args.name}')
        return
    payload = {'apiVersion': 'v1', 'kind': 'Secret',
               'metadata': {'name': args.name, 'namespace': args.namespace},
               'type': 'kubernetes.io/dockerconfigjson', 'data': {'.dockerconfigjson': expected}}
    target.command('apply', '--server-side', '--field-manager=sunmoon-registry', '-f', '-',
                   payload=json.dumps(payload))
    target.check()
    actual = target.secret(args.namespace, args.name)
    if (not actual or actual.get('type') != payload['type']
            or actual.get('data', {}).get('.dockerconfigjson') != expected):
        raise SecretError('Secret read-back differs; deployment is not accepted')
    restart_workloads(target, args.namespace, args.restart)
    print(f'Pull Secret deployed and read back: {args.namespace}/{args.name}; registry={REGISTRY}; login not checked')


if __name__ == '__main__':
    try:
        main()
    except SecretError as exc:
        raise SystemExit(str(exc)) from None
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        # Never include credential contents, JSON parse errors or API objects in logs.
        raise SystemExit('Pull Secret input or response is invalid; private details suppressed') from None
