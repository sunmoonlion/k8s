#!/usr/bin/env python3
"""Read-only admission of shared Harbor runtime rendering; no installation.

Default prints a plan without private inputs or Docker. --check reads explicitly
selected existing official inputs, images and TLS leaves, then renders in memory.
Cloud shapes only: SSH/host deployment 未经实机验证. Never prints private outputs.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import stat
import subprocess
import sys

import yaml
from harbor_inputs import MAP, cert_pair, sha
from official_prepare import nested
from certificates import openssl_verify
from runtime_config import IMAGES, PG_REFERENCE, REDIS_REFERENCE, render
from runtime_files import render as render_files

HERE = Path(__file__).resolve().parent


def public_images(installer):
    lock = json.loads((HERE / 'artifacts.lock.json').read_text())['artifacts'][0]
    if installer.resolve() != installer or installer.stat().st_size != lock['bytes'] or sha(installer) != lock['sha256']:
        raise ValueError('Official offline installer size/SHA differs')
    outer, inner = nested(installer)
    with outer, inner:
        for item in inner:
            if item.name == 'manifest.json':
                manifest = json.load(inner.extractfile(item)); break
        else:
            raise ValueError('Official image manifest missing')
    selected = {}
    for role, name in IMAGES.items():
        matches = [m for m in manifest if m.get('RepoTags') == ['goharbor/' + name + ':v2.13.2']]
        if len(matches) != 1:
            raise ValueError('Official runtime image absent or ambiguous')
        selected[role] = matches[0]
    configs = {}; wanted = {v['Config'] for v in selected.values()}
    outer, inner = nested(installer)
    with outer, inner:
        for item in inner:
            if item.name not in wanted:
                continue
            if item.name in configs or not item.isfile() or item.size > 1024 * 1024:
                raise ValueError('Unexpected official image config entry')
            raw = inner.extractfile(item).read()
            if hashlib.sha256(raw).hexdigest() + '.json' != item.name:
                raise ValueError('Official image config SHA differs')
            configs[item.name] = json.loads(raw)
    if set(configs) != wanted:
        raise ValueError('Incomplete official image metadata')
    return {role: {'reference': item['RepoTags'][0], 'id': 'sha256:' + item['Config'].removesuffix('.json'),
                   'volumes': list(configs[item['Config']]['config'].get('Volumes') or {}),
                   'architecture': configs[item['Config']]['architecture'], 'os': configs[item['Config']]['os']}
            for role, item in selected.items()}


def dependencies():
    records = {}
    for role, reference in [('postgresql', PG_REFERENCE), ('redis', REDIS_REFERENCE)]:
        result = subprocess.run(['docker', '--host', 'unix:///var/run/docker.sock', 'image', 'inspect', reference],
                                capture_output=True, check=True, timeout=20)
        image = json.loads(result.stdout)[0]
        if reference not in image.get('RepoDigests', []):
            raise ValueError('Original database/cache image digest differs')
        records[role] = {'reference': reference, 'id': image['Id'], 'volumes': list(image['Config'].get('Volumes') or {}),
                         'architecture': image['Architecture'], 'os': image['Os']}
    return records


def read(path):
    if not path.is_absolute() or path.resolve() != path:
        raise ValueError('Explicit non-symlinked input path required')
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o022 or info.st_size > 2 * 1024 * 1024:
        raise ValueError('Unexpected input type/mode/size')
    return path.read_bytes()


def inspect(args):
    source, tls = args.source, args.tls_batch
    for path in (source, tls):
        if not path or not path.is_absolute() or path.resolve() != path or not path.is_dir() or path.stat().st_mode & 0o077:
            raise ValueError('Explicit private input directories required')
    if not json.loads(read(source / 'generator-state.json')).get('completed'):
        raise ValueError('Official generator did not complete')
    receipt = json.loads(read(source / 'inputs-receipt.json'))
    preserved = {}
    for name in MAP:
        raw = read(source / 'private' / name)
        if hashlib.sha256(raw).hexdigest() != receipt['private_files']['private/' + name]['sha256']:
            raise ValueError('Original preserved input changed')
        preserved[name] = raw
    manifest = json.loads(read(tls / 'manifest.json'))
    ca = read(tls / 'ca.crt')
    if hashlib.sha256(ca).hexdigest() != args.ca_sha256 or manifest['ca_sha256'] != args.ca_sha256:
        raise ValueError('Explicit original CA pin differs')
    certificate, key = read(tls / 'harbor/tls.crt'), read(tls / 'harbor/tls.key')
    if (tls / 'harbor/tls.key').stat().st_mode & 0o077 or hashlib.sha256(certificate).hexdigest() != manifest['leaves']['harbor']['certificate_sha256']:
        raise ValueError('Harbor leaf or private key permissions differ')
    cert_pair(certificate, key, 'Harbor HTTPS')
    openssl_verify(tls / 'ca.crt', tls / 'harbor/tls.crt', 'harbor.sunmoonai.com')
    records = {**public_images(args.installer), **dependencies()}
    upstream = yaml.safe_load(read(source / 'compose/docker-compose.yml'))
    generated = {}
    for path in (source / 'generated-config').rglob('*'):
        if path.is_symlink():
            raise ValueError('Symlink in generated configuration')
        if path.is_file():
            generated[str(path.relative_to(source / 'generated-config'))] = read(path)
    results = []
    # Ephemeral credential only validates byte mapping, never persists or replaces
    # a credential. Real preparation must generate once into its private batch.
    password = secrets.token_urlsafe(32)
    compose_version = subprocess.run(['docker', 'compose', 'version', '--short'], capture_output=True,
                                     check=True, timeout=20).stdout.decode().strip()
    if compose_version != '5.1.3':
        raise ValueError('Review the Compose tool version before reusing this admission')
    for platform, ip, port in [('wsl', '127.0.0.1', 18443), ('cloud', '10.50.0.5', 30443)]:
        for write_enabled in (False, True):
            site = {'schema': 1, 'deployment': 'sunmoon-harbor-main-20260927',
                    'root': '/data/harbor/instances/sunmoon-harbor-main-20260927',
                    'platform': platform, 'bind_address': ip, 'https_port': port, 'write_enabled': write_enabled}
            compose = render(upstream, site, records)
            files = render_files(generated, preserved, {'certificate': certificate, 'key': key, 'ca': ca}, password, write_enabled)
            for name, original in [('signing/secretkey', 'core_key'), ('signing/private_key.pem', 'token_key'),
                                   ('signing/root.crt', 'token_cert'), ('config/registry/passwd', 'registry_htpasswd')]:
                if files[name] != preserved[original]:
                    raise ValueError('Runtime preparation altered an original identity')
            if any(s.get('restart') != 'no' or s.get('privileged') or s.get('network_mode') or
                   any(v['type'] != 'bind' for v in s['volumes']) for s in compose['services'].values()):
                raise ValueError('Runtime isolation differs')
            # Parse stdin without resolving env files: the prospective installation
            # does not exist. No private env values or new files enter Compose.
            parsed = subprocess.run(['docker', 'compose', '--project-directory', str(source), '--profile', '*',
                '-f', '-', 'config', '--no-env-resolution', '--format', 'json'], input=json.dumps(compose).encode(),
                capture_output=True, check=True, timeout=20)
            resolved = json.loads(parsed.stdout)
            if set(resolved['services']) != set(compose['services']):
                raise ValueError('Compose parsed a different runtime service set')
            results.append({'platform': platform, 'write_enabled': write_enabled, 'services': sorted(compose['services']),
                            'private_file_count': len(files), 'original_identities_preserved': True,
                            'jobs_default_enabled': 'profiles' not in compose['services']['jobservice']})
    return {'read_only': True, 'installer_sha256': sha(args.installer), 'images': records,
            'in_memory_renderings': results, 'ca_sha256': args.ca_sha256,
            'leaf_sha256': manifest['leaves']['harbor']['certificate_sha256'],
            'services_started': False, 'files_written': False, 'registry_or_database_copied': False,
            'compose_version': compose_version, 'compose_config_parsed_without_env_resolution': True,
            'docker_compose_runtime_checked': False, 'cloud_execution': '未经实机验证'}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check', action='store_true')
    p.add_argument('--source', type=Path)
    p.add_argument('--tls-batch', type=Path)
    p.add_argument('--installer', type=Path)
    p.add_argument('--ca-sha256')
    args = p.parse_args()
    if not args.check:
        print(json.dumps({'dry_run': True, 'source': str(args.source) if args.source else None,
            'version': '2.13.2', 'postgresql': '17.6', 'redis': '8.2.1',
            'private_inputs_read': False, 'docker_called': False, 'install_or_start': False})); return
    if not args.installer:
        raise ValueError('Explicit official installer required')
    print(json.dumps(inspect(args), indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Runtime inspection stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld')) from None
