#!/usr/bin/env python3
"""Render one local ONLYOFFICE resource; no Kubernetes calls or random secrets."""
import base64
import json
import os
from pathlib import Path
import re
import sys
import tempfile

try:
    import yaml
except ImportError:
    raise SystemExit('Rendering requires the provisioned Python PyYAML dependency; no automatic download attempted') from None


VARIABLE = re.compile(r'\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-([^}]*))?\}')


def dns_name(value):
    label = r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
    return (isinstance(value, str) and len(value) <= 253
            and re.fullmatch(label + r'(?:\.' + label + r')*', value))


def expand(value):
    if isinstance(value, dict):
        return {key: expand(item) for key, item in value.items()}
    if isinstance(value, list):
        return [expand(item) for item in value]
    if not isinstance(value, str):
        return value
    def substitute(match):
        result = os.environ.get(match[1]) or match[2]
        if not result:
            raise ValueError('Required resource input is missing')
        return result
    return VARIABLE.sub(substitute, value)


def main():
    template, output = map(Path, sys.argv[1:])
    # Parse before interpolation: a password with quotes/newlines cannot inject YAML.
    resource = expand(yaml.safe_load(template.read_text()))
    if not isinstance(resource, dict) or not resource.get('kind'):
        raise ValueError('Invalid resource template')
    namespace = os.environ.get('NAMESPACE', '')
    if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', namespace):
        raise ValueError('Explicit valid namespace required')
    resource['metadata']['namespace'] = namespace
    if resource['kind'] == 'Secret':
        if resource.get('type') != 'Opaque' or len(resource.get('stringData', {})) != 1:
            raise ValueError('Only the selected ONLYOFFICE Opaque Secret is supported')
        old_key, value = next(iter(resource['stringData'].items()))
        key = os.environ.get('TARGET_SECRET_KEY') or old_key
        name = os.environ.get('SECRET_NAME') or resource['metadata']['name']
        if not re.fullmatch(r'[A-Za-z0-9_.-]{1,253}', key):
            raise ValueError('Invalid Secret data key')
        if not dns_name(name):
            raise ValueError('Invalid Secret name')
        if not isinstance(value, str) or not value:
            raise ValueError('Secret value must be explicitly supplied')
        resource['metadata']['name'] = name
        resource.pop('stringData')
        resource['data'] = {key: base64.b64encode(value.encode()).decode()}
    if resource['kind'] == 'IngressRoute':
        if not dns_name(os.environ.get('UNIFIED_HOST', '')):
            raise ValueError('Invalid route hostname')
        for route in resource['spec']['routes']:
            for service in route.get('services', []):
                if not dns_name(service['name']):
                    raise ValueError('Invalid service name')
                service['port'] = int(service['port'])
                if not 1 <= service['port'] <= 65535:
                    raise ValueError('Invalid service port')
    if output.is_symlink() or not output.parent.is_dir():
        raise ValueError('Unsafe resource output path')
    # JSON is accepted as a Kubernetes manifest; atomic replacement avoids partial YAML.
    fd, temporary = tempfile.mkstemp(prefix='.onlyoffice-render-', dir=output.parent)
    try:
        with os.fdopen(fd, 'w') as handle:
            json.dump(resource, handle, ensure_ascii=True, indent=2)
            handle.write('\n')
        os.replace(temporary, output)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, TypeError, KeyError, AttributeError, yaml.YAMLError):
        # Parser messages may contain private template/configuration values.
        raise SystemExit('Resource rendering failed; check selected template and required inputs (private details suppressed)') from None
