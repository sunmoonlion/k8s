#!/usr/bin/env python3
"""Render one route locally; no environment interpolation or API access."""
import json
import os
from pathlib import Path
import re
import sys
import tempfile

try:
    import yaml
except ImportError:
    raise SystemExit('Provisioned PyYAML dependency required; no automatic download') from None


def main():
    template, output, namespace, host, service = sys.argv[1:]
    label = r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
    if (not re.fullmatch(label, namespace) or not re.fullmatch(label, service)
            or len(host) > 253 or not all(re.fullmatch(label, part) for part in host.split('.'))):
        raise ValueError('Invalid route identity')
    raw = Path(template).read_text()
    variables = set(re.findall(r'{{([^}]+)}}', raw))
    if variables != {'NAMESPACE', 'UNIFIED_HOST', 'SERVICE_NAME'}:
        raise ValueError('Unexpected template variables')
    # Replace placeholders with safe sentinel text BEFORE parsing, not live values.
    for variable in variables:
        raw = raw.replace('{{' + variable + '}}', 'SUNMOON_' + variable)
    document = yaml.safe_load(raw)
    if document['kind'] != 'IngressRoute' or document['metadata']['name'] != 'ragflow-ingress':
        raise ValueError('Unexpected template identity')
    document['metadata']['namespace'] = namespace
    route, = document['spec']['routes']
    route['match'] = f'Host(`{host}`)'
    backend, = route['services']
    backend['name'] = service
    if backend['port'] != 80:
        raise ValueError('Backend port differs from the chart contract')
    path = Path(output)
    if path.is_symlink() or not path.parent.is_dir():
        raise ValueError('Unsafe output path')
    fd, temporary = tempfile.mkstemp(prefix='.ragflow-route-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as handle:
            json.dump(document, handle, indent=2)
            handle.write('\n')
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, AttributeError, yaml.YAMLError):
        raise SystemExit('RAGFlow route rendering failed; check template and configuration') from None
