"""Shared ingress TLS Secret installation; cloud 未经实机验证。

Consumes owner-supplied signed leaves. Never signs, rotates or deletes a CA,
updates an existing Secret, restarts a service, or prints key/Secret payloads.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile

from registry_consumer import ca_bytes

CERT = re.compile(rb'-----BEGIN CERTIFICATE-----[A-Za-z0-9+/=\r\n]+-----END CERTIFICATE-----')
KEY = re.compile(rb'\s*-----BEGIN (?:RSA |EC )?PRIVATE KEY-----[A-Za-z0-9+/=\r\n]+-----END (?:RSA |EC )?PRIVATE KEY-----\s*')
LABEL = 'sunmoonai.com/cluster-uid'


def read_file(value, private=False, limit=65536):
    path = Path(value).expanduser()
    if not path.is_absolute() or path.resolve() != path:
        raise ValueError('TLS input must be an absolute non-symlinked file')
    if private and any((parent / '.git').exists() for parent in path.parents):
        raise ValueError('Private TLS inputs must stay outside Git checkouts')
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if (not stat.S_ISREG(info.st_mode) or not 0 < info.st_size <= limit
                or info.st_uid not in (0, os.geteuid()) or info.st_mode & 0o022
                or (private and info.st_mode & 0o077)):
            raise ValueError('TLS input ownership, permissions or size is invalid')
        raw = stream.read(limit + 1)
        if len(raw) != info.st_size:
            raise ValueError('TLS input changed while reading')
    return raw


def load_bundle(value, registry):
    """Only called for actual installation/inspection, never a print-only plan."""
    descriptor = json.loads(read_file(value, private=True))
    if set(descriptor) != {'schema', 'certificates'} or descriptor['schema'] != 1:
        raise ValueError('Unsupported TLS bundle descriptor')
    entries = descriptor['certificates']
    if not isinstance(entries, list) or not 1 <= len(entries) <= 2:
        raise ValueError('Declare one or two ingress namespace certificates explicitly')
    result = []
    for item in entries:
        if set(item) != {'namespace', 'name', 'certificate_file', 'certificate_sha256', 'private_key_file', 'dns_names'}:
            raise ValueError('Unexpected TLS descriptor fields')
        public = {k: item[k] for k in ('namespace', 'name', 'certificate_sha256', 'dns_names')}
        cert = read_file(item['certificate_file'])
        key = read_file(item['private_key_file'], private=True, limit=32768)
        result.append({**public, 'certificate': base64.b64encode(cert).decode(), 'key': base64.b64encode(key).decode()})
    payload = {'registry': registry, 'entries': result}
    validate_payload(payload)
    return payload


def openssl(*arguments, content=None):
    result = subprocess.run(['/usr/bin/openssl', *arguments], input=content, capture_output=True,
                            timeout=20, env={'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'})
    if result.returncode:
        # OpenSSL diagnostics and key input never enter exceptions or logs.
        raise ValueError('TLS cryptographic validation failed; input retained')
    return result.stdout


def validate_payload(payload):
    ca = ca_bytes(payload['registry'])
    entries = payload['entries']
    if not isinstance(entries, list) or not 1 <= len(entries) <= 2:
        raise ValueError('Invalid ingress TLS entry count')
    seen = set()
    for item in entries:
        if set(item) != {'namespace', 'name', 'certificate_sha256', 'dns_names', 'certificate', 'key'}:
            raise ValueError('Unexpected TLS payload fields')
        if item['namespace'] not in ('ingress-platform-dev', 'ingress-platform-prod') or item['name'] != 'traefik-tls-secret':
            raise ValueError('Unexpected ingress TLS Secret target')
        identity = (item['namespace'], item['name'])
        if identity in seen:
            raise ValueError('Duplicate ingress TLS target')
        seen.add(identity)
        names = item['dns_names']
        if not isinstance(names, list) or len(names) != 2 or set(names) != {'sunmoonai.com', '*.sunmoonai.com'}:
            raise ValueError('Ingress leaf must explicitly cover sunmoonai.com and its wildcard')
        cert = base64.b64decode(item['certificate'], validate=True)
        key = base64.b64decode(item['key'], validate=True)
        if (not 0 < len(cert) <= 65536 or not 0 < len(key) <= 32768
                or not re.fullmatch(r'[a-f0-9]{64}', item['certificate_sha256'])
                or hashlib.sha256(cert).hexdigest() != item['certificate_sha256']
                or not KEY.fullmatch(key)):
            raise ValueError('TLS certificate SHA or unencrypted PEM key format differs')
        chain = CERT.findall(cert)
        if not chain or CERT.sub(b'', cert).strip():
            raise ValueError('Certificate chain must contain only PEM certificates, leaf first')
        leaf = chain[0] + b'\n'
        if b'CA:TRUE' in openssl('x509', '-noout', '-ext', 'basicConstraints', content=leaf):
            raise ValueError('CA certificate cannot be installed as a service leaf')
        sans = openssl('x509', '-noout', '-ext', 'subjectAltName', content=leaf).decode('ascii')
        if not set(names).issubset(set(re.findall(r'DNS:([^,\s]+)', sans))):
            raise ValueError('Required DNS SANs missing from ingress certificate')
        openssl('x509', '-noout', '-checkend', '86400', content=leaf)
        cert_public = openssl('x509', '-pubkey', '-noout', content=leaf)
        key_public = openssl('pkey', '-pubout', '-passin', 'pass:', content=key)
        if cert_public != key_public:
            raise ValueError('Ingress certificate and key do not match')
        # Only public certificates enter temporary files; private key uses stdin.
        with tempfile.TemporaryDirectory(prefix='sunmoon-tls-public-') as directory:
            root = Path(directory)
            (root / 'ca.pem').write_bytes(ca)
            (root / 'leaf.pem').write_bytes(leaf)
            (root / 'chain.pem').write_bytes(cert)
            for name in names:
                openssl('verify', '-CAfile', str(root / 'ca.pem'), '-no-CApath', '-no-CAstore',
                        '-purpose', 'sslserver', '-auth_level', '2', '-verify_hostname',
                        name.replace('*', 'sunmoon-tls-check'), '-untrusted', str(root / 'chain.pem'),
                        str(root / 'leaf.pem'))
    return ca


def check_existing(actual, desired):
    metadata = actual.get('metadata', {})
    if (metadata.get('deletionTimestamp') or metadata.get('ownerReferences') or actual.get('type') != desired['type']
            or any(metadata.get('labels', {}).get(k) != v for k, v in desired['metadata']['labels'].items())
            or any(metadata.get('annotations', {}).get(k) != v for k, v in desired['metadata']['annotations'].items())
            or actual.get('data') != desired['data']):
        raise ValueError('Existing TLS Secret differs or is unowned; no update or adoption')


def execute(kub, payload, uid, verify_only=False):
    """Adapter must check recorded cluster UID/CA before EVERY API request."""
    if not re.fullmatch(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', uid):
        raise ValueError('Explicit cluster UID required for TLS resources')
    ca = validate_payload(payload)
    desired, missing = [], []
    for item in payload['entries']:
        namespace = json.loads(kub('get', 'namespace', item['namespace'], '-o', 'json'))
        meta = namespace['metadata']
        if (meta.get('deletionTimestamp') or meta.get('labels', {}).get(LABEL) != uid
                or meta.get('labels', {}).get('managed-by') != 'infrastructure'
                or namespace.get('status', {}).get('phase') != 'Active'):
            raise ValueError('TLS target namespace is not active and owned by this cluster')
        obj = {'apiVersion': 'v1', 'kind': 'Secret', 'type': 'kubernetes.io/tls', 'metadata': {
            'namespace': item['namespace'], 'name': item['name'],
            'labels': {LABEL: uid, 'app.kubernetes.io/managed-by': 'sunmoon-bootstrap'},
            'annotations': {'sunmoonai.com/certificate-sha256': item['certificate_sha256'],
                            'sunmoonai.com/ca-sha256': hashlib.sha256(ca).hexdigest()}},
            'data': {'tls.crt': item['certificate'], 'tls.key': item['key'], 'ca.crt': base64.b64encode(ca).decode()}}
        desired.append(obj)
        raw = kub('-n', item['namespace'], 'get', 'secret', item['name'], '--ignore-not-found', '-o', 'json')
        if raw.strip():
            check_existing(json.loads(raw), obj)
        else:
            missing.append(obj)
    if verify_only and missing:
        raise ValueError('TLS Secret missing; inspection never creates it')
    # All cryptographic, namespace and existing-resource checks precede creation.
    for obj in missing:
        kub('create', '-f', '-', content=json.dumps(obj).encode())
    for obj in desired:
        actual = json.loads(kub('-n', obj['metadata']['namespace'], 'get', 'secret', obj['metadata']['name'], '-o', 'json'))
        check_existing(actual, obj)
    return {'tls_secrets': [o['metadata']['namespace'] + '/' + o['metadata']['name'] for o in desired],
            'created': len(missing), 'existing_secrets_updated': False, 'ca_generated_or_rotated': False,
            'leaf_issued': False, 'service_restarted': False, 'scope': 'certificate inputs and Secret bytes; not ingress handshake acceptance'}
