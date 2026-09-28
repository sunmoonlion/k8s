#!/usr/bin/env python3
"""Inspect selected local resources and pin the verified image digest; no API calls."""
import json
import os
import tempfile
from pathlib import Path
import re
import sys


def dependencies(data):
    items = data['items'] if data.get('kind') == 'List' else [data]
    managed = {item['metadata']['name'] for item in items if item['kind'] == 'Middleware'}
    routes = [item for item in items if item['kind'] == 'IngressRoute']
    if len(routes) != 1:
        raise ValueError('Exactly one route required')
    dependencies = set()
    for route in routes[0]['spec']['routes']:
        dependencies.update(('service', item['name']) for item in route['services'])
        dependencies.update(('middleware.traefik.io', item['name'])
                            for item in route.get('middlewares', []) if item['name'] not in managed)
    for kind, name in sorted(dependencies):
        if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', name):
            raise ValueError('Invalid dependency name')
        print(f'{kind}:{name}')


def main():
    action, filename = sys.argv[1:]
    path = Path(filename)
    if path.is_symlink():
        raise ValueError('Symlink output refused')
    data = json.loads(path.read_text())
    if action == 'dependencies':
        dependencies(data)
        return
    items = data['items'] if data.get('kind') == 'List' else [data]
    deployments = [item for item in items if item['kind'] == 'Deployment']
    if len(deployments) != 1 or deployments[0]['metadata']['name'] != 'document-converter':
        raise ValueError('Unexpected workload')
    container, = deployments[0]['spec']['template']['spec']['containers']
    reference = container['image']
    if action == 'image':
        print(reference)
        return
    if action != 'pin-image':
        raise ValueError('Unknown metadata action')
    result, = json.load(sys.stdin)['results']
    if (result['reference'] != reference or result['state'] != 'exists'
            or not re.fullmatch(r'sha256:[a-f0-9]{64}', result['digest'])):
        raise ValueError('Manifest check differs from rendered image')
    repository = reference.rsplit(':', 1)[0]
    if not repository.startswith('harbor.sunmoonai.com:30443/'):
        raise ValueError('Unexpected registry')
    container['image'] = repository + '@' + result['digest']
    fd, temporary = tempfile.mkstemp(prefix='.dc-pin-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as handle:
            json.dump(data, handle, indent=2)
            handle.write('\n')
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, IndexError, AttributeError):
        raise SystemExit('Invalid rendered resource metadata or manifest result') from None
