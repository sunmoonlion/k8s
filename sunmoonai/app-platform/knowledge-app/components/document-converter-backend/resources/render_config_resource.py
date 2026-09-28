#!/usr/bin/env python3
"""Local Secret/ConfigMap rendering; never validate by contacting Kubernetes."""
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
    raise SystemExit('Provisioned Python PyYAML dependency required; no automatic download') from None


TOKEN = re.compile(r'\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-([^}]*))?\}')


def expand(item):
    if isinstance(item, dict):
        return {key: expand(value) for key, value in item.items()}
    if isinstance(item, list):
        return [expand(value) for value in item]
    if not isinstance(item, str):
        return item
    def value(match):
        if match[1] not in os.environ and match[2] is None:
            raise ValueError('Resource input missing')
        # Explicit empty optional telemetry values remain empty; template defaults retain shell semantics.
        return os.environ.get(match[1]) or match[2] or ''
    return TOKEN.sub(value, item)


def main():
    kind, template, output, namespace, name = sys.argv[1:]
    if kind not in ('Secret', 'ConfigMap') or not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', namespace):
        raise ValueError('Invalid resource target')
    document = expand(yaml.safe_load(Path(template).read_text()))
    if document['kind'] != kind or document['metadata']['name'] != name:
        raise ValueError('Template identity differs from the deployment resource')
    document['metadata']['namespace'] = namespace
    if kind == 'Secret':
        if document.get('type') != 'Opaque' or set(document.get('stringData', {})) != {'SENTRY_DSN'}:
            raise ValueError('Unexpected Secret schema')
        values = document.pop('stringData')
        document['data'] = {key: base64.b64encode(value.encode()).decode() for key, value in values.items()}
    elif not all(isinstance(value, str) for value in document['data'].values()):
        raise ValueError('ConfigMap values must be strings')
    destination = Path(output)
    if destination.is_symlink() or not destination.parent.is_dir():
        raise ValueError('Unsafe output path')
    fd, temporary = tempfile.mkstemp(prefix='.dc-render-', dir=destination.parent)
    try:
        with os.fdopen(fd, 'w') as handle:
            json.dump(document, handle, ensure_ascii=True, indent=2)
            handle.write('\n')
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, AttributeError, yaml.YAMLError):
        raise SystemExit('Resource rendering failed; check template, target and inputs. Private details suppressed.') from None
