#!/usr/bin/env python3
"""Prepare public offline ingress JSON from the SHA-pinned official chart. No API calls.

Default prints only. --write creates exact new output files (no overwrite).
Cloud deployment 未经实机验证. Helm is a preparation tool, not a node dependency.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import tarfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--helm', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=Path.home() / 'packages-to-be-installed')
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    repo = here.parents[2]
    material = repo / 'sunmoonai/infrastructure/materials'
    source_lock = here / 'sources.lock.json'
    source = json.loads(source_lock.read_text())
    root = args.root.expanduser().absolute()
    if root.resolve() != root:
        raise ValueError('Symlinked material root refused')
    archive_path = root / 'releases' / source['batch'] / source['files'][0]['path']
    if archive_path.resolve() != archive_path or digest(archive_path) != source['files'][0]['sha256']:
        raise ValueError('Official chart archive checksum differs')
    values_file = here / 'values.json'
    image_lock = material / 'ingress-images.lock.json'
    image = json.loads(image_lock.read_text())['images'][0]
    if (image['version'] != source['traefik_version'] or image['source'] != source['public_images'][0]
            or image['reference'] != 'docker.io/library/traefik@' + image['platform_digest']):
        raise ValueError('Image identity differs from approved ingress source')
    if (not args.helm.is_absolute() or args.helm.resolve() != args.helm or not args.helm.is_file()
            or not args.output.is_absolute() or args.output.resolve() != args.output):
        raise ValueError('Explicit non-symlinked absolute Helm/output paths required')
    sources = [Path(__file__).resolve(), values_file, image_lock, source_lock]
    if any(p.resolve() != p for p in sources):
        raise ValueError('Symlinked chart input refused')
    identities = [{'path': str(p.relative_to(repo)), 'sha256': digest(p)} for p in sources]
    if not args.write:
        print(json.dumps({'dry_run': True, 'chart': source['chart_version'], 'traefik': source['traefik_version'], 'kubernetes': '1.36.4',
                          'source_files': len(identities), 'helm_sha256': digest(args.helm), 'api_calls': False})); return
    import yaml
    with tempfile.TemporaryDirectory(prefix='sunmoon-chart-') as temp_chart:
        chart_root = Path(temp_chart)
        with tarfile.open(archive_path) as archive:
            members = archive.getmembers()
            if len({m.name for m in members}) != len(members):
                raise ValueError('Duplicate chart paths')
            for member in members:
                if (not (member.isfile() or member.isdir()) or member.size > 16 * 1024**2
                        or not (chart_root / member.name).resolve().is_relative_to(chart_root / 'traefik')):
                    raise ValueError('Unsafe chart member')
            archive.extractall(chart_root, filter='data')
        prepare(args, source, chart_root / 'traefik', image, values_file, identities, archive_path, yaml)


def prepare(args, source, chart, image, values_file, identities, archive_path, yaml):
    crd_directory = chart / 'crds'
    chart_meta = yaml.safe_load((chart / 'Chart.yaml').read_text())
    if chart_meta['version'] != source['chart_version'] or chart_meta['appVersion'] != source['traefik_version'] or image['version'] != source['traefik_version']:
        raise ValueError('Existing chart/platform versions changed')
    version = subprocess.check_output([str(args.helm), 'version', '--short'], text=True, timeout=20).strip()
    if version != 'v3.19.0+g3d8990f':
        raise ValueError('Preparation requires the recorded existing Helm 3.19.0 build')
    outputs = {}
    crds = [yaml.safe_load(p.read_text()) for p in sorted(crd_directory.glob('traefik.io_*.yaml'))]
    if len(crds) != 10 or any(o['kind'] != 'CustomResourceDefinition' or o['spec']['group'] != 'traefik.io' for o in crds):
        raise ValueError('Expected ten version-matched Traefik Proxy CRDs')
    outputs['crds.json'] = {'apiVersion': 'v1', 'kind': 'List', 'items': crds}
    for profile in ('dev', 'prod'):
        values = json.loads(values_file.read_text())
        values['image']['digest'] = image['platform_digest']
        if profile == 'prod':
            values['deployment']['replicas'] = 3
            values['resources']['requests'].update(cpu='500m', memory='512Mi')
            values['resources']['limits'].update(cpu='1000m', memory='1Gi')
        namespace = 'ingress-platform-' + profile
        values['providers']['kubernetesCRD']['defaultTLSResourcesNamespace'] = namespace
        # Permit internal cross-provider routes only in the operator namespace.
        values['providers']['kubernetesCRD']['crossProviderNamespaces'] = [namespace]
        values['providers']['kubernetesIngress']['crossProviderNamespaces'] = [namespace]
        with tempfile.TemporaryDirectory(prefix='sunmoon-ingress-render-') as temp:
            path = Path(temp); (path / 'values.json').write_text(json.dumps(values))
            env = {**os.environ, 'KUBECONFIG': '/dev/null', 'HELM_CONFIG_HOME': temp + '/config',
                   'HELM_CACHE_HOME': temp + '/cache', 'HELM_DATA_HOME': temp + '/data', 'HELM_PLUGINS': temp + '/plugins'}
            result = subprocess.run([str(args.helm), 'template', 'traefik-sunmoonai', str(chart),
                                     '--namespace', namespace, '--kube-version', '1.36.4', '--skip-tests',
                                     '--values', str(path / 'values.json')], capture_output=True, text=True, check=True, timeout=60, env=env)
            objects = [o for o in yaml.safe_load_all(result.stdout) if o]
        deployments = [o for o in objects if o['kind'] == 'Deployment']
        if len(deployments) != 1:
            raise ValueError('Exactly one ingress Deployment required')
        pod = deployments[0]['spec']['template']['spec']
        containers = pod['containers']
        if len(containers) != 1 or containers[0]['image'] != image['reference'] or pod.get('initContainers'):
            raise ValueError('Unexpected chart image/container set')
        if containers[0]['imagePullPolicy'] != 'Never':
            raise ValueError('Offline ingress must not pull implicitly')
        objects.append({'apiVersion': 'traefik.io/v1alpha1', 'kind': 'Middleware', 'metadata': {
            'name': 'traefik-buffering-sunmoonai', 'namespace': namespace}, 'spec': {'buffering': {
                'maxRequestBodyBytes': 2147483648, 'memRequestBodyBytes': 20971520,
                'maxResponseBodyBytes': 2147483648, 'memResponseBodyBytes': 20971520,
                'retryExpression': 'IsNetworkError() && Attempts() <= 2'}}})
        allowed = {'ServiceAccount','ClusterRole','ClusterRoleBinding','Service','Deployment','IngressClass','TLSStore','Middleware'}
        if any(o['kind'] not in allowed or (o['metadata'].get('annotations') or {}).get('helm.sh/hook') for o in objects):
            raise ValueError('Unexpected ingress chart resource/hook; no output published')
        for obj in objects:
            obj['metadata'].setdefault('labels', {})['app.kubernetes.io/managed-by'] = 'sunmoon-bootstrap'
        outputs[profile + '.json'] = {'apiVersion': 'v1', 'kind': 'List', 'items': objects}
    lock = {'schema': 1, 'complete': True, 'chart_version': source['chart_version'], 'traefik_version': source['traefik_version'],
            'kubernetes_version': '1.36.4', 'preparation': {'helm_version': version, 'helm_sha256': digest(args.helm),
            'yaml_version': yaml.__version__, 'source_files': identities, 'chart_sha256': digest(archive_path), 'api_calls': False},
            'archives': [{'material_path': 'releases/' + source['batch'] + '/' + source['files'][0]['path'],
                          'bytes': archive_path.stat().st_size, 'sha256': digest(archive_path)}], 'files': []}
    serialized = {}
    for name, obj in outputs.items():
        raw = (json.dumps(obj, sort_keys=True, indent=2) + '\n').encode()
        serialized[name] = raw
        lock['files'].append({'name': name, 'material_path': 'releases/' + source['batch'] + '/rendered/' + name,
                              'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(), 'objects': len(obj['items'])})
    serialized['ingress-resources.lock.json'] = (json.dumps(lock, ensure_ascii=False, indent=2) + '\n').encode()
    args.output.mkdir(parents=True, exist_ok=True)
    for name, raw in serialized.items():
        path = args.output / name
        if path.exists() and (path.is_symlink() or path.read_bytes() != raw):
            raise ValueError('Existing output differs; choose a new preparation directory')
    for name, raw in serialized.items():
        path = args.output / name
        if not path.exists():
            with path.open('xb') as f: f.write(raw)
    print(json.dumps({'prepared': True, 'objects': {k: len(v['items']) for k,v in outputs.items()}, 'api_calls': False}))


if __name__ == '__main__':
    main()
