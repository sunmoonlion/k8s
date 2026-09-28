#!/usr/bin/env python3
"""Manual research Demo consumer. No build, publication, KIND load or implicit target.

Cloud execution 未经实机验证. Defaults to a plan; wrapper admits the target before --apply.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time

try:
    import yaml
except ImportError:
    raise SystemExit('Provisioned PyYAML dependency required') from None

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parents[1] / 'registry-platform'))
from credentials import REGISTRY, docker_config, load_credentials, read_private  # noqa: E402
from images import Registry, REPOSITORY, DIGEST  # noqa: E402
from client import config  # noqa: E402
from pull_secret import Target, dns_name  # noqa: E402


def business_values(filename):
    # Parse data, never source/eval the .env file or perform interpolation.
    values = {}
    for line in read_private(filename).decode('utf-8').splitlines():
        text = line.strip()
        if not text or text.startswith('#'):
            continue
        if text.startswith('export '):
            text = text[7:]
        key, separator, value = text.partition('=')
        key = key.strip()
        if not separator or not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', key):
            raise ValueError('Invalid private environment record')
        if key not in ('DEEPSEEK_API_KEY', 'DEEPSEEK_BASE_URL', 'DEEPSEEK_DEFAULT_MODEL'):
            continue
        if key in values:
            raise ValueError('Duplicate private environment key')
        value = value.strip()
        if value.startswith(('"', "'")):
            if len(value) < 2 or value[-1] != value[0]:
                raise ValueError('Invalid private quoting')
            value = value[1:-1]
        if any(c in value for c in ('\0', '\r', '\n')):
            raise ValueError('Invalid private environment value')
        values[key] = value
    if not values.get('DEEPSEEK_API_KEY'):
        raise ValueError('Explicit nonempty API key required')
    return values


def resources(namespace, host, image, pull_name, values, auth):
    runtime = list(yaml.safe_load_all((ROOT / 'k8s/20-runtime.yaml').read_text()))
    routes = list(yaml.safe_load_all((ROOT / 'k8s/30-ingress.yaml').read_text()))
    expected = [('ConfigMap', 'question-data-config'), ('Deployment', 'question-data'),
                ('Service', 'question-data'), ('ServersTransport', 'question-data-transport'),
                ('IngressRoute', 'question-data-route')]
    documents = runtime + routes
    if [(d['kind'], d['metadata']['name']) for d in documents] != expected:
        raise ValueError('Unexpected Demo resource set')
    for document in documents:
        document['metadata']['namespace'] = namespace
    cm, deployment, _service = runtime
    for key in ('DEEPSEEK_BASE_URL', 'DEEPSEEK_DEFAULT_MODEL'):
        if values.get(key):
            cm['data'][key] = values[key]
    pod = deployment['spec']['template']['spec']
    container, = pod['containers']
    container['image'] = image
    container['imagePullPolicy'] = 'IfNotPresent'
    pod['imagePullSecrets'] = [{'name': pull_name}]
    route, = routes[1]['spec']['routes']
    route['match'] = f'Host(`{host}`) && PathPrefix(`/`)'
    secret = {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {
                  'name': 'question-data-secret', 'namespace': namespace}, 'type': 'Opaque',
              'data': {'DEEPSEEK_API_KEY': base64.b64encode(values['DEEPSEEK_API_KEY'].encode()).decode()}}
    config_digest = hashlib.sha256(json.dumps({'config': cm['data'], 'secret': secret['data']},
                                             sort_keys=True).encode()).hexdigest()
    deployment['spec']['template']['metadata'].setdefault('annotations', {})[
        'sunmoonai.com/demo-config-sha256'] = config_digest
    pull = {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {'name': pull_name, 'namespace': namespace},
            'type': 'kubernetes.io/dockerconfigjson',
            'data': {'.dockerconfigjson': base64.b64encode(docker_config(auth).encode()).decode()}}
    return pull, secret, documents


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('action', choices=('deploy', 'status', 'uninstall'))
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    inherited = os.environ.get('SUNMOON_DEPLOY_DRY_RUN', 'false')
    if inherited not in ('true', 'false') or (args.apply and inherited == 'true'):
        parser.error('Invalid or conflicting inherited dry-run')
    if not args.apply:
        print(f'Plan: Demo {args.action}; no credentials, cluster or filesystem writes')
        return
    namespace = dns_name(os.environ['QUESTION_DATA_NAMESPACE'])
    target = Target()
    target.check()
    if args.action == 'status':
        raw = target.command('get', 'deployment', 'question-data', '-n', namespace, '-o', 'json')
        deployment = json.loads(raw)
        print(json.dumps({'namespace': namespace, 'name': 'question-data',
                          'desired': deployment['spec']['replicas'],
                          'ready': deployment.get('status', {}).get('readyReplicas', 0)}))
        return
    if args.action == 'uninstall':
        # Pull identity may be shared with other apps. Never delete it or the namespace.
        for kind, name in [('ingressroute.traefik.io', 'question-data-route'),
                           ('serverstransport.traefik.io', 'question-data-transport'),
                           ('deployment', 'question-data'), ('service', 'question-data'),
                           ('configmap', 'question-data-config'), ('secret', 'question-data-secret')]:
            target.check()
            target.command('delete', kind, name, '-n', namespace, '--ignore-not-found', '--wait=false')
        print('Demo uninstall submitted; shared pull Secret, namespaces and volumes retained')
        return
    wait_seconds = int(os.environ['QUESTION_DATA_WAIT_SECONDS'])
    if not 10 <= wait_seconds <= 3600:
        raise ValueError('Readiness deadline must be 10..3600 seconds')
    image = os.environ['QUESTION_DATA_IMAGE']
    prefix = REGISTRY + '/'
    repository, separator, digest = image.partition('@')
    if (not image.startswith(prefix) or separator != '@' or not DIGEST.fullmatch(digest)
            or not REPOSITORY.fullmatch(repository.removeprefix(prefix))):
        raise ValueError('Explicit published Harbor image digest required')
    host = dns_name(os.environ['QUESTION_DATA_HOST'], subdomain=True)
    pull_name = dns_name(os.environ['QUESTION_DATA_PULL_SECRET'], subdomain=True)
    if pull_name == 'question-data-secret':
        raise ValueError('Business and registry identities must differ')
    values = business_values(os.environ['DEEPSEEK_ENV_FILE'])
    profile = config(None)
    auth = load_credentials(profile['REGISTRY_CREDENTIALS_FILE'])
    registry = Registry(profile, profile['REGISTRY_CREDENTIALS_FILE'])
    if registry.inspect(image)['state'] != 'exists':
        raise ValueError('Published Demo image missing')
    pull, secret, documents = resources(namespace, host, image, pull_name, values, auth)
    target.command('get', 'namespace', namespace)
    target.command('get', 'crd', 'ingressroutes.traefik.io', 'serverstransports.traefik.io')
    for manager, document in [('sunmoon-registry', pull), ('sunmoon-question-data', secret),
                              *[('sunmoon-question-data', doc) for doc in documents]]:
        target.check()
        target.command('apply', '--server-side', '--field-manager=' + manager, '-n', namespace,
                       '-f', '-', payload=json.dumps(document))
    # Confirm the two submitted credentials without printing their values.
    for expected in (pull, secret):
        target.check()
        found = target.secret(namespace, expected['metadata']['name'])
        if not found or found.get('type') != expected['type'] or found.get('data') != expected['data']:
            raise ValueError('Credential readback differs')
    # Preserve the former deployment readiness wait without unbounded follow/log calls.
    deadline = time.monotonic() + wait_seconds
    while time.monotonic() < deadline:
        target.check()
        deployment = json.loads(target.command('get', 'deployment', 'question-data', '-n', namespace, '-o', 'json'))
        desired = deployment['spec']['replicas']
        status = deployment.get('status', {})
        actual_image = deployment['spec']['template']['spec']['containers'][0]['image']
        if (desired > 0 and actual_image == image
                and status.get('observedGeneration', 0) >= deployment['metadata']['generation']
                and status.get('updatedReplicas', 0) == desired
                and status.get('readyReplicas', 0) == desired
                and status.get('availableReplicas', 0) == desired):
            print('Demo Deployment available and Secrets read back; external route and actual model request not verified')
            return
        time.sleep(min(2, max(0, deadline - time.monotonic())))
    raise ValueError('Deployment did not become ready before the configured deadline')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        raise SystemExit('Demo operation failed; inspect target, configuration, private files, '
                         'image and resource ownership. Private diagnostics suppressed; earlier writes may remain.') from None
