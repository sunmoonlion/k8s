#!/usr/bin/env python3
"""Selected Document Converter resource rendering; no Kubernetes calls."""
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


def dns_name(value):
    if not isinstance(value, str) or not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', value):
        raise ValueError('Invalid resource name')
    return value


def integer(value, minimum=1, maximum=65535):
    if not isinstance(value, (str, int)) or not re.fullmatch(r'[0-9]+', str(value)):
        raise ValueError('Integer required')
    number = int(value)
    if not minimum <= number <= maximum:
        raise ValueError('Integer outside allowed range')
    return number


def enabled(key):
    value = os.environ.get(key)
    if value not in ('true', 'false'):
        raise ValueError('Explicit middleware boolean required')
    return value == 'true'


def normalize(documents, selection, namespace, name):
    expected = {'Secret': ['Secret'], 'ConfigMap': ['ConfigMap'],
                'Namespace': ['Namespace'], 'PersistentVolumeClaim': ['PersistentVolumeClaim'],
                'App': ['Deployment', 'Service'], 'Ingress': ['Middleware', 'IngressRoute'],
                'Middleware': ['Middleware', 'IngressRoute']}
    if selection not in expected or [d['kind'] for d in documents] != expected[selection]:
        raise ValueError('Unexpected resource set')
    for document in documents:
        metadata = document['metadata']
        if document['kind'] == 'Namespace':
            metadata['name'] = namespace
            metadata.pop('namespace', None)
        else:
            metadata['namespace'] = namespace
        dns_name(metadata['name'])
        if selection not in ('Ingress', 'Middleware') and metadata['name'] != (namespace if selection == 'Namespace' else name):
            raise ValueError('Template identity differs from selected resource')
    if selection == 'Secret':
        document = documents[0]
        if document.get('type') != 'Opaque' or set(document.get('stringData', {})) != {'SENTRY_DSN'}:
            raise ValueError('Unexpected Secret schema')
        values = document.pop('stringData')
        document['data'] = {key: base64.b64encode(value.encode()).decode() for key, value in values.items()}
    elif selection == 'ConfigMap':
        if not all(isinstance(value, str) for value in documents[0]['data'].values()):
            raise ValueError('ConfigMap values must be strings')
    elif selection == 'PersistentVolumeClaim':
        spec = documents[0]['spec']
        if spec['accessModes'] not in ([v] for v in ('ReadWriteOnce', 'ReadWriteMany', 'ReadOnlyMany', 'ReadWriteOncePod')):
            raise ValueError('Invalid PVC access mode')
        dns_name(spec['storageClassName'])
        if not re.fullmatch(r'[1-9][0-9]*(?:[KMGTPE]i?|m)?', spec['resources']['requests']['storage']):
            raise ValueError('Invalid PVC storage quantity')
    elif selection == 'App':
        deployment, service = documents
        deployment['spec']['replicas'] = integer(deployment['spec']['replicas'], 0, 1000)
        pod = deployment['spec']['template']['spec']
        container, = pod['containers']
        # Check precisely the reference later inspected by the parent, without registry remapping.
        if not re.fullmatch(r'harbor\.sunmoonai\.com:30443/[a-z0-9._/-]+:[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}', container['image']):
            raise ValueError('Explicit image in the approved registry required')
        if container['imagePullPolicy'] not in ('Always', 'IfNotPresent', 'Never'):
            raise ValueError('Invalid image pull policy')
        for item in pod['imagePullSecrets']:
            dns_name(item['name'])
        for item in container['envFrom']:
            dns_name(next(iter(item.values()))['name'])
        container['ports'][0]['containerPort'] = integer(container['ports'][0]['containerPort'])
        for probe in ('livenessProbe', 'readinessProbe'):
            container[probe]['httpGet']['port'] = integer(container[probe]['httpGet']['port'])
        for port in service['spec']['ports']:
            port['port'] = integer(port['port'])
            port['targetPort'] = integer(port['targetPort'])
    elif selection in ('Ingress', 'Middleware'):
        middleware, route = documents
        if (middleware['metadata']['name'] != 'document-converter-stripprefix'
                or route['metadata']['name'] != 'document-converter-ingress'):
            raise ValueError('Unexpected route identity')
        strip, rate = enabled('USE_STRIP_PREFIX'), enabled('USE_RATE_LIMIT')
        host = os.environ['UNIFIED_HOST']
        if len(host) > 253 or not all(re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', part) for part in host.split('.')):
            raise ValueError('Invalid route host')
        for item in route['spec']['routes']:
            item['match'] = f'Host(`{host}`) && PathPrefix(`/document-converter`)'
            for backend in item['services']:
                dns_name(backend['name'])
                backend['port'] = integer(backend['port'])
            item['middlewares'] = ([{'name': 'document-converter-stripprefix'}] if strip else
                                   [{'name': 'document-converter-rate-limit'}] if rate else [])
        if selection == 'Middleware':
            if not strip:
                raise ValueError('StripPrefix disabled; external rate-limit is not managed here')
            return [middleware]
        return [middleware, route] if strip else [route]
    return documents


def main():
    kind, template, output, namespace, name = sys.argv[1:]
    dns_name(namespace)
    documents = [expand(d) for d in yaml.safe_load_all(Path(template).read_text()) if d is not None]
    documents = normalize(documents, kind, namespace, name)
    document = documents[0] if len(documents) == 1 else {'apiVersion': 'v1', 'kind': 'List', 'items': documents}
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
    except (OSError, ValueError, KeyError, TypeError, AttributeError, IndexError, yaml.YAMLError):
        raise SystemExit('Resource rendering failed; check template, target and inputs. Private details suppressed.') from None
