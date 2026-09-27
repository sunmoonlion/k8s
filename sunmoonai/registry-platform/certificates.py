#!/usr/bin/env python3
"""Issue separate Harbor/ingress TLS leaves using an explicitly pinned existing CA.

Default prints only; issue --apply creates one new private batch outside Git.
check is read-only and needs no CA private key. Never installs certificates,
rotates a CA, distributes signing keys, contacts SSH or restarts services.
Cloud distribution/lifecycle 未经实机验证.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import uuid

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID, ExtendedKeyUsageOID

NAMES = {'harbor': ['harbor.sunmoonai.com'], 'ingress': ['sunmoonai.com', '*.sunmoonai.com']}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def five_years_after(now):
    try:
        return now.replace(year=now.year + 5)
    except ValueError:
        return now.replace(year=now.year + 5, day=28)


def public(key):
    return key.public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)


def path_guard(path, outside_git=False):
    if not path.is_absolute() or path.resolve() != path:
        raise ValueError('Absolute non-symlinked paths required')
    if outside_git and any((parent / '.git').exists() for parent in [path, *path.parents]):
        raise ValueError('New certificate batches must stay outside Git checkouts')
    for parent in path.parents:
        if parent.exists() and parent.stat().st_mode & 0o022:
            raise ValueError('Certificate path has a group/other-writable parent')
    return path


def read(path, private=False):
    path_guard(path)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if (not stat.S_ISREG(info.st_mode) or not 0 < info.st_size <= 65536
                or info.st_uid not in (os.geteuid(), 0) or info.st_mode & 0o022
                or (private and info.st_mode & 0o077)):
            raise ValueError('Certificate input ownership, mode or size invalid')
        raw = stream.read(65537)
        if len(raw) != info.st_size:
            raise ValueError('Certificate input changed during read')
    return raw


def ca_input(path, expected):
    raw = read(path)
    if not re.fullmatch(r'[a-f0-9]{64}', expected) or sha(raw) != expected:
        raise ValueError('CA certificate differs from the explicit SHA256 pin')
    certs = x509.load_pem_x509_certificates(raw)
    if len(certs) != 1:
        raise ValueError('Exactly one existing root CA certificate required')
    cert = certs[0]
    if not cert.extensions.get_extension_for_class(x509.BasicConstraints).value.ca or cert.subject != cert.issuer:
        raise ValueError('Pinned certificate must be the existing root CA')
    try:
        if not cert.extensions.get_extension_for_class(x509.KeyUsage).value.key_cert_sign:
            raise ValueError('CA key usage does not allow certificate signing')
    except x509.ExtensionNotFound:
        pass  # Preserve the owner's original CA, whose KeyUsage may be absent.
    now = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)
    if not cert.not_valid_before <= now < cert.not_valid_after:
        raise ValueError('Existing CA is not currently valid')
    return raw, cert


def write(path, raw):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(raw); stream.flush(); os.fsync(stream.fileno())


def openssl_verify(ca, leaf, hostname):
    result = subprocess.run(['/usr/bin/openssl', 'verify', '-CAfile', str(ca), '-no-CApath', '-no-CAstore',
        '-purpose', 'sslserver', '-auth_level', '2', '-verify_hostname', hostname, str(leaf)],
        capture_output=True, timeout=20, env={'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'})
    if result.returncode:
        raise ValueError('Leaf chain/hostname verification failed; private diagnostics withheld')


def check(root, expected_ca, minimum_days=90):
    path_guard(root, outside_git=True)
    if not root.is_dir() or root.stat().st_mode & 0o077 or root.stat().st_uid != os.geteuid():
        raise ValueError('Certificate batch must be a private directory owned by the caller')
    receipt = json.loads(read(root / 'manifest.json', private=True))
    if receipt.get('schema') != 1 or receipt.get('ca_sha256') != expected_ca or set(receipt.get('leaves', {})) != set(NAMES):
        raise ValueError('Certificate receipt differs from expected scope/CA')
    ca_raw, ca = ca_input(root / 'ca.crt', expected_ca)
    issued = dt.datetime.strptime(receipt['issued_utc'], '%Y-%m-%dT%H:%M:%SZ')
    expires = five_years_after(issued)
    if receipt.get('validity_calendar_years') != 5:
        raise ValueError('Receipt does not describe the approved five-year lifetime')
    results = {}
    for role, names in NAMES.items():
        crt = read(root / role / 'tls.crt'); key_raw = read(root / role / 'tls.key', private=True)
        leaves = x509.load_pem_x509_certificates(crt)
        if len(leaves) != 1:
            raise ValueError('Exactly one leaf certificate required')
        leaf = leaves[0]
        key = serialization.load_pem_private_key(key_raw, password=None)
        usage = leaf.extensions.get_extension_for_class(x509.KeyUsage).value
        if (not isinstance(key, rsa.RSAPrivateKey) or key.key_size != 4096
                or public(key.public_key()) != public(leaf.public_key())
                or leaf.issuer != ca.subject or leaf.not_valid_after > ca.not_valid_after
                or leaf.not_valid_after != expires
                or leaf.not_valid_before != max(issued - dt.timedelta(minutes=5), ca.not_valid_before)
                or receipt['leaves'][role].get('expires_utc') != expires.isoformat() + 'Z'
                or receipt['leaves'][role].get('dns_names') != names
                or not usage.digital_signature or not usage.key_encipherment
                or any((usage.content_commitment, usage.data_encipherment, usage.key_agreement,
                        usage.key_cert_sign, usage.crl_sign))
                or leaf.extensions.get_extension_for_class(x509.BasicConstraints).value.ca
                or leaf.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName) != names
                or list(leaf.extensions.get_extension_for_class(x509.ExtendedKeyUsage).value) != [ExtendedKeyUsageOID.SERVER_AUTH]
                or sha(crt) != receipt['leaves'][role]['certificate_sha256']):
            raise ValueError('Leaf identity, SAN, key or issuer mismatch')
        remaining = (leaf.not_valid_after - dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)).total_seconds()
        if remaining < minimum_days * 86400:
            raise ValueError('Leaf certificate is within the configured renewal warning window')
        for name in names:
            openssl_verify(root / 'ca.crt', root / role / 'tls.crt', name.replace('*', 'sunmoon-tls-check'))
        results[role] = {'dns_names': names, 'certificate_sha256': sha(crt),
                         'expires_utc': leaf.not_valid_after.isoformat() + 'Z', 'remaining_days': int(remaining / 86400)}
    if public(serialization.load_pem_private_key(read(root / 'harbor/tls.key', True), None).public_key()) == public(
            serialization.load_pem_private_key(read(root / 'ingress/tls.key', True), None).public_key()):
        raise ValueError('Harbor and ingress must have separate leaf keys')
    return {'verified': True, 'ca_sha256': sha(ca_raw), 'leaves': results, 'installed': False}


def issue(args):
    root = path_guard(args.output, outside_git=True)
    if (root.exists() or not root.parent.is_dir() or root.parent.stat().st_mode & 0o077
            or root.parent.stat().st_uid != os.geteuid()):
        raise ValueError('Choose a new batch under an existing private (0700) directory')
    if not args.ca_cert or not args.ca_key:
        raise ValueError('Existing CA certificate and private signing key are required')
    ca_raw, ca = ca_input(args.ca_cert, args.ca_sha256)
    key_raw = read(args.ca_key, private=True)
    ca_key = serialization.load_pem_private_key(key_raw, password=None)
    if not isinstance(ca_key, rsa.RSAPrivateKey) or ca_key.key_size < 3072 or public(ca_key.public_key()) != public(ca.public_key()):
        raise ValueError('Original CA key does not match pinned RSA CA')
    now = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None).replace(microsecond=0)
    expires = five_years_after(now)
    if expires > ca.not_valid_after:
        raise ValueError('CA does not cover the requested five calendar years; no CA renewal attempted')
    stage = root.with_name('.' + root.name + '.staging-' + uuid.uuid4().hex)
    stage.mkdir(mode=0o700)
    write(stage / 'ca.crt', ca_raw)
    receipt = {'schema': 1, 'issued_utc': now.isoformat() + 'Z', 'validity_calendar_years': 5,
               'ca_sha256': args.ca_sha256, 'ca_unchanged': True, 'leaves': {}, 'installed': False}
    for role, names in NAMES.items():
        key = rsa.generate_private_key(public_exponent=65537, key_size=4096)
        leaf = (x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, names[0])]))
            .issuer_name(ca.subject).public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(max(now - dt.timedelta(minutes=5), ca.not_valid_before)).not_valid_after(expires)
            .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
            .add_extension(x509.KeyUsage(digital_signature=True, content_commitment=False, key_encipherment=True,
                data_encipherment=False, key_agreement=False, key_cert_sign=False, crl_sign=False,
                encipher_only=False, decipher_only=False), critical=True)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
            .add_extension(x509.SubjectAlternativeName([x509.DNSName(n) for n in names]), critical=False)
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), critical=False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(ca.public_key()), critical=False)
            .sign(ca_key, hashes.SHA256()))
        directory = stage / role; directory.mkdir(mode=0o700)
        crt = leaf.public_bytes(serialization.Encoding.PEM)
        write(directory / 'tls.crt', crt)
        write(directory / 'tls.key', key.private_bytes(serialization.Encoding.PEM,
              serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        receipt['leaves'][role] = {'dns_names': names, 'certificate_sha256': sha(crt),
                                  'expires_utc': expires.isoformat() + 'Z'}
    # Paths in the consumer descriptor refer to the final immutable batch.
    descriptor = {'schema': 1, 'certificates': [{'namespace': 'ingress-platform-' + profile,
        'name': 'traefik-tls-secret', 'certificate_file': str(root / 'ingress/tls.crt'),
        'certificate_sha256': receipt['leaves']['ingress']['certificate_sha256'],
        'private_key_file': str(root / 'ingress/tls.key'), 'dns_names': NAMES['ingress']} for profile in ('dev', 'prod')]}
    write(stage / 'ingress-bundle.json', (json.dumps(descriptor, indent=2) + '\n').encode())
    write(stage / 'manifest.json', (json.dumps(receipt, indent=2) + '\n').encode())
    result = check(stage, args.ca_sha256)
    # Recheck original CA input bytes, including the key, without exposing hashes of keys.
    if read(args.ca_cert) != ca_raw or read(args.ca_key, True) != key_raw:
        raise ValueError('CA input changed during signing; staged batch retained')
    if root.exists():
        raise ValueError('Destination appeared during signing; staged batch retained')
    stage.rename(root)
    return {**result, 'batch': str(root), 'original_ca_unchanged': True, 'services_changed': False}


def main():
    os.umask(0o077)
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('issue', 'check'))
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--ca-cert', type=Path)
    p.add_argument('--ca-key', type=Path)
    p.add_argument('--ca-sha256', required=True)
    p.add_argument('--minimum-days', type=int, default=90)
    p.add_argument('--apply', action='store_true')
    args = p.parse_args()
    if not 1 <= args.minimum_days <= 365:
        raise ValueError('Renewal warning window must be 1..365 days')
    if args.action == 'check':
        if args.apply or args.ca_key:
            raise ValueError('Read-only check does not accept --apply or CA private key')
        print(json.dumps(check(args.output, args.ca_sha256, args.minimum_days), indent=2)); return
    if not args.apply:
        path_guard(args.output, outside_git=True)
        print(json.dumps({'dry_run': True, 'batch': str(args.output), 'dns_names': NAMES,
            'years': 5, 'separate_leaf_keys': True, 'existing_ca_only': True, 'ca_private_key_read': False,
            'installs_or_restarts': False}, indent=2)); return
    print(json.dumps(issue(args), indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Certificate operation stopped: ' + (str(error) if isinstance(error, ValueError)
                          else type(error).__name__ + '; private diagnostics withheld')) from None
