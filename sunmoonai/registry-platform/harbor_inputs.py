#!/usr/bin/env python3
"""Prepare immutable private inputs for official Harbor 2.13.2 generation.

Plan by default. Check reads pinned backups; stage writes a fresh candidate only.
Never executes install.sh/prepare wrappers, loads images, restores data, or starts
services. Cloud/SSH transport is not implemented here: 未经实机验证.
"""
import argparse
import base64
import copy
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import ssl
import subprocess
import tarfile

import bcrypt
from cryptography import x509
from cryptography.hazmat.primitives import serialization
import yaml

HERE = Path(__file__).resolve().parent
EXPECTED_ROOT = Path('/data/harbor/candidates/harbor-2.13.2-20260927')
PINS = {
    'backup-20260926T145600Z/resources-private.json': '6821473f45358d7fcc5c033913eebd127274f2c1a000f5109cf9b8e1b0181b87',
    'preparation/private/traefik-tls-secret.json': '8ff2da37ba94419c3851ef341302346b45fcb9851403a841c977c16421ca5909',
    'preparation/private/harbor-client-ca.crt': '30fe0e56df354899ccf7e66d5d730b87946b8010db21852a2e4520997a51b0ec',
}
MAP = {
    'core_secret': ('sunmoonai-harbor-core', 'secret'),
    'core_key': ('sunmoonai-harbor-core', 'secretKey'),
    'token_key': ('sunmoonai-harbor-core', 'tls.key'),
    'token_cert': ('sunmoonai-harbor-core', 'tls.crt'),
    'csrf_key': ('sunmoonai-harbor-core-envvars', 'CSRF_KEY'),
    'registry_username': ('sunmoonai-harbor-core-envvars', 'REGISTRY_CREDENTIAL_USERNAME'),
    'registry_password': ('sunmoonai-harbor-core-envvars', 'REGISTRY_CREDENTIAL_PASSWORD'),
    'jobservice_secret': ('sunmoonai-harbor-jobservice', 'secret'),
    'registry_http_secret': ('sunmoonai-harbor-registry', 'REGISTRY_HTTP_SECRET'),
    'registry_htpasswd': ('sunmoonai-harbor-registry', 'REGISTRY_HTPASSWD'),
    'database_password': ('sunmoonai-harbor-postgresql', 'postgres-password'),
    'admin_password': ('harbor-secret', 'HARBOR_ADMIN_PASSWORD'),
}


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def site_config(path):
    site = json.loads(path.read_text())
    if site.get('version') != '2.13.2' or site.get('external_url') != 'https://harbor.sunmoonai.com:30443':
        raise RuntimeError('Version/external URL differs from the approved migration')
    if site.get('platform') != 'wsl' or Path(site['root']) != EXPECTED_ROOT or site.get('bind_address') != '127.0.0.1' or site.get('https_port') != 18443:
        raise RuntimeError('Only the reviewed local candidate is admitted; cloud is not implemented')
    if (site.get('database_host'), site.get('database_port'), site.get('database_name'), site.get('database_user'), site.get('database_version')) != ('postgresql', 5432, 'registry', 'postgres', '17.6'):
        raise RuntimeError('Database settings differ from the reviewed target')
    if site.get('data_uuid') != 'a28de356-4ba1-4a21-93f5-744b9b9d8be0':
        raise RuntimeError('Storage UUID differs from approved disk')
    if EXPECTED_ROOT.resolve() != EXPECTED_ROOT:
        raise RuntimeError('Candidate path contains symlinks')
    return site


def cert_pair(cert_bytes, key_bytes, name):
    cert = x509.load_pem_x509_certificate(cert_bytes)
    key = serialization.load_pem_private_key(key_bytes, password=None)
    def public(obj):
        return obj.public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    if public(cert.public_key()) != public(key.public_key()):
        raise RuntimeError(name+' certificate/key mismatch')
    now = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)
    if not cert.not_valid_before <= now < cert.not_valid_after:
        raise RuntimeError(name+' certificate not currently valid')
    return cert


def read_inputs(batch):
    if batch.resolve() != batch:
        raise RuntimeError('Backup batch must be an absolute nonsymlink path')
    for name, expected in PINS.items():
        path = batch/name
        if path.resolve() != path or sha(path) != expected:
            raise RuntimeError('Frozen private input integrity mismatch: '+name)
    resources = json.loads((batch/'backup-20260926T145600Z/resources-private.json').read_text())['items']
    secrets = {}
    for item in resources:
        if item['kind'] == 'Secret':
            name = item['metadata']['name']
            if name in secrets:
                raise RuntimeError('Duplicate secret name in frozen resources')
            secrets[name] = item.get('data', {})
    def value(name, key):
        return base64.b64decode(secrets[name][key], validate=True)
    result = {key: value(*source) for key, source in MAP.items()}
    if len(result['core_key']) != 16:
        raise RuntimeError('Core encryption key must preserve exactly 16 bytes')
    if result['database_password'] != value('sunmoonai-harbor-core-envvars', 'POSTGRESQL_PASSWORD'):
        raise RuntimeError('Source database passwords disagree')
    if result['registry_password'] != value('sunmoonai-harbor-jobservice-envvars', 'REGISTRY_CREDENTIAL_PASSWORD'):
        raise RuntimeError('Source registry passwords disagree')
    username, password_hash = result['registry_htpasswd'].strip().split(b':', 1)
    if username != result['registry_username'] or not bcrypt.checkpw(result['registry_password'], password_hash):
        raise RuntimeError('Registry htpasswd does not match original client credential')
    tls = json.loads((batch/'preparation/private/traefik-tls-secret.json').read_text())['data']
    result['tls_cert'] = base64.b64decode(tls['tls.crt'], validate=True)
    result['tls_key'] = base64.b64decode(tls['tls.key'], validate=True)
    result['ca'] = (batch/'preparation/private/harbor-client-ca.crt').read_bytes()
    token = cert_pair(result['token_cert'], result['token_key'], 'Token')
    tls_cert = cert_pair(result['tls_cert'], result['tls_key'], 'TLS')
    dns = tls_cert.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName)
    if not any(d == 'harbor.sunmoonai.com' or d == '*.sunmoonai.com' for d in dns):
        raise RuntimeError('TLS certificate does not cover the Harbor domain')
    for key in ['core_secret', 'jobservice_secret', 'csrf_key', 'registry_username', 'registry_password', 'registry_http_secret', 'database_password', 'admin_password']:
        if not result[key] or any(ch in result[key] for ch in [b'\x00', b'\r', b'\n']):
            raise RuntimeError('Secret cannot be represented safely in generated env: '+key)
        result[key].decode('utf-8')
    report = {'input_integrity': True, 'core_key_bytes': 16, 'registry_password_verified': True,
              'database_password_consistent': True, 'token_keypair_verified': True,
              'tls_keypair_and_hostname_verified': True,
              'tls_expires_at': tls_cert.not_valid_after.isoformat()+'Z',
              'token_expires_at': token.not_valid_after.isoformat()+'Z',
              'preserved_fields': sorted(result)}
    return result, report


def installer_template(installer):
    lock = json.loads((HERE/'artifacts.lock.json').read_text())['artifacts'][0]
    if installer.resolve() != installer or installer.stat().st_size != lock['bytes'] or sha(installer) != lock['sha256']:
        raise RuntimeError('Official installer integrity mismatch')
    with tarfile.open(installer, 'r:gz') as archive:
        member = archive.getmember('harbor/harbor.yml.tmpl')
        if not member.isfile() or member.size > 1024**2:
            raise RuntimeError('Unexpected installer config template')
        template = yaml.safe_load(archive.extractfile(member))
    if template.get('_version') != '2.13.0':
        raise RuntimeError('Unexpected upstream configuration schema')
    return template


def render(template, site, inputs):
    config = copy.deepcopy(template)
    root = Path(site['root'])
    config.update({'hostname': 'harbor.sunmoonai.com', 'external_url': site['external_url'],
                   'data_volume': str(root/'data'), 'harbor_admin_password': inputs['admin_password'].decode()})
    config['https'].update({'port': site['https_port'], 'certificate': str(root/'private/tls_cert'),
                            'private_key': str(root/'private/tls_key')})
    config['http']['port'] = 18080  # Generation only; final candidate Compose must remove HTTP exposure.
    config['external_database'] = {'harbor': {'host': site['database_host'], 'port': site['database_port'],
        'db_name': site['database_name'], 'username': site['database_user'],
        'password': inputs['database_password'].decode(), 'ssl_mode': 'disable',
        'max_idle_conns': 5, 'max_open_conns': 30}}
    config.pop('database', None)  # The admitted external PostgreSQL 17.6 is mandatory.
    config['log']['local']['location'] = str(root/'logs')
    config['log']['local']['rotate_count'] = 5
    config['log']['local']['rotate_size'] = '20M'
    config['trivy'].update({'skip_update': True, 'skip_java_db_update': True, 'offline_scan': True})
    config['proxy'] = {'http_proxy': '', 'https_proxy': '', 'no_proxy': '127.0.0.1,localhost,postgresql,redis,core,registry,registryctl,portal,jobservice', 'components': []}
    return config


def write_new(path, raw, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with path.open('xb') as stream:
        stream.write(raw)
        stream.flush()
        os.fsync(stream.fileno())
    os.chmod(path, mode)


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['plan', 'check', 'stage'])
    parser.add_argument('--site', type=Path, default=HERE/'config/harbor-candidate-local.json')
    parser.add_argument('--batch', type=Path, required=True)
    parser.add_argument('--installer', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    site = site_config(args.site)
    if args.action == 'plan' or (args.action == 'stage' and not args.apply):
        print(json.dumps({'dry_run': True, 'root': site['root'], 'source': str(args.batch),
                          'external_url': site['external_url'], 'preserved_fields': list(MAP),
                          'operations': ['verify pinned frozen inputs', 'fresh private files', 'render official harbor.yml'],
                          'start_services': False, 'restore_database_or_registry': False}, indent=2))
        return
    inputs, report = read_inputs(args.batch)
    template = installer_template(args.installer)
    config = render(template, site, inputs)
    report.update({'official_template_verified': True, 'external_database': 'PostgreSQL 17.6',
                   'external_url': site['external_url'], 'services_started': False})
    if args.action == 'check':
        print(json.dumps(report, indent=2))
        return
    if os.geteuid() != 0:
        raise RuntimeError('Staging on the admitted data disk requires root')
    guard = subprocess.run(['bash', '/opt/sunmoon/admin/storage/storage-20260927-v2/check-storage-mounts.sh',
        '--layout', 'sunmoon-data', '--expected-uuid', site['data_uuid'], '--min-free-gib', '40',
        '--require-service-visibility'], capture_output=True, timeout=30)
    if guard.returncode:
        raise RuntimeError('Data filesystem guard failed; no fallback to the system disk')
    root = Path(site['root'])
    root.mkdir(parents=True, exist_ok=False, mode=0o700)
    for name, raw in inputs.items():
        write_new(root/'private'/name, raw)
    # Seed official stable secret paths before prepare; original snapshots remain private/.
    seeds = {'data/secret/keys/secretkey': 'core_key',
             'data/secret/core/private_key.pem': 'token_key',
             'data/secret/registry/root.crt': 'token_cert'}
    for destination, name in seeds.items():
        write_new(root/destination, inputs[name])
    raw = yaml.safe_dump(config, sort_keys=False).encode()
    write_new(root/'input/harbor.yml', raw)
    write_new(root/'compose/harbor.yml', raw)
    context = ssl.create_default_context(cafile=str(root/'private/ca'))
    context.load_cert_chain(str(root/'private/tls_cert'), str(root/'private/tls_key'))
    verify = subprocess.run(['openssl', 'verify', '-CAfile', str(root/'private/ca'),
        '-verify_hostname', 'harbor.sunmoonai.com', str(root/'private/tls_cert')], capture_output=True, timeout=15)
    if verify.returncode:
        raise RuntimeError('Original TLS chain verification failed; staged files retained, no services started')
    for destination, name in seeds.items():
        if (root/destination).read_bytes() != inputs[name]:
            raise RuntimeError('Staged key bytes differ from original')
    files = {str(p.relative_to(root)): {'sha256': sha(p), 'bytes': p.stat().st_size}
             for p in sorted(root.rglob('*')) if p.is_file()}
    receipt = {'at': dt.datetime.now(dt.timezone.utc).isoformat(), 'root': str(root), 'site': site,
               'source_pins': PINS, 'private_files': files,
               'report': {**report, 'tls_chain_verified': True, 'staged': True}}
    write_new(root/'inputs-receipt.json', (json.dumps(receipt, indent=2)+'\n').encode())
    # Only status/field names leave the private directory; no secret hashes/values.
    print(json.dumps({**receipt['report'], 'private_file_count': len(files), 'root': str(root)}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        # Third-party parser errors may contain parts of secret-bearing YAML.
        message = str(exc) if isinstance(exc, RuntimeError) else type(exc).__name__+'; details withheld'
        raise SystemExit('[harbor-inputs] FAIL: '+message) from None
