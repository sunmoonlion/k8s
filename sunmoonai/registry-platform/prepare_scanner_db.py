#!/usr/bin/env python3
"""Pin/download official Trivy DB OCI data artifacts on an authorized relay.

Default prints only. No Docker, database execution, extraction, installation,
SSH or cleanup. resolve freezes HTTPS manifests; download only uses those pins.
Cloud installation 未经实机验证. Tokens remain in memory/stdin.
"""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import uuid

SOURCES = {'db': ('aquasecurity/trivy-db', '2', 'application/vnd.aquasec.trivy.db.layer.v1.tar+gzip'),
           'java-db': ('aquasecurity/trivy-java-db', '1', 'application/vnd.aquasec.trivy.javadb.layer.v1.tar+gzip')}
MAXIMUM = 2 * 1024**3


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def request(url, token='', target=None, maximum=1024**2):
    if not url.startswith('https://ghcr.io/'):
        raise ValueError('Only the official GHCR endpoint is admitted')
    headers = 'header = "Accept: application/vnd.oci.image.manifest.v1+json"\n'
    if token:
        if not re.fullmatch(r'[A-Za-z0-9_.=/+-]+', token):
            raise ValueError('Unexpected anonymous token encoding')
        headers += 'header = "Authorization: Bearer ' + token + '"\n'
    args = ['curl', '--fail', '--silent', '--show-error', '--location', '--proto', '=https',
            '--proto-redir', '=https', '--connect-timeout', '15', '--max-time', '240',
            '--retry', '2', '--retry-max-time', '720', '--max-filesize', str(maximum)]
    if target:
        args += ['--output', str(target)]
    result = subprocess.run(args + ['--config', '-', url], input=headers.encode(),
                            capture_output=True, timeout=780)
    if result.returncode:
        raise ValueError('Official HTTPS download failed; partial retained, private diagnostics withheld')
    return result.stdout


def auth(repository):
    return json.loads(request('https://ghcr.io/token?service=ghcr.io&scope=repository:' + repository + ':pull'))['token']


def descriptor(value):
    if (not re.fullmatch(r'sha256:[a-f0-9]{64}', value.get('digest', ''))
            or type(value.get('size')) is not int or not 0 <= value['size'] <= MAXIMUM):
        raise ValueError('Invalid OCI data descriptor')


def validate_manifest(raw, role):
    manifest = json.loads(raw)
    if (manifest.get('schemaVersion') != 2 or manifest.get('mediaType') != 'application/vnd.oci.image.manifest.v1+json'
            or len(manifest.get('layers', [])) != 1
            or manifest['layers'][0]['mediaType'] != SOURCES[role][2]):
        raise ValueError('Unexpected official database artifact layout')
    for item in [manifest['config'], *manifest['layers']]:
        descriptor(item)
    if sum(x['size'] for x in [manifest['config'], *manifest['layers']]) > MAXIMUM:
        raise ValueError('Database artifact exceeds preparation bound')
    return manifest


def save(path, value):
    with path.open('x') as stream:
        json.dump(value, stream, indent=2); stream.write('\n')


def resolve(root):
    if root.exists():
        raise ValueError('Resolution requires a NEW batch; never refresh existing pins in place')
    root.mkdir(mode=0o750)
    pins = {'schema': 1, 'resolved_at': dt.datetime.now(dt.timezone.utc).isoformat(),
            'provenance': 'Official GHCR HTTPS; content digest pinned; publisher signature not verified',
            'artifacts': {}, 'trivy_version_target': '0.64.1'}
    for role, (repository, tag, _) in SOURCES.items():
        raw = request('https://ghcr.io/v2/' + repository + '/manifests/' + tag, auth(repository))
        manifest = validate_manifest(raw, role)
        with (root / (role + '-manifest.json')).open('xb') as stream:
            stream.write(raw)
        pins['artifacts'][role] = {'repository': repository, 'tag': tag,
            'manifest_digest': 'sha256:' + hashlib.sha256(raw).hexdigest(),
            'manifest_bytes': len(raw), 'compressed_bytes': sum(x['size'] for x in manifest['layers'])}
    save(root / 'scanner-db.lock.json', pins)
    return pins


def download(root):
    lock = root / 'scanner-db.lock.json'
    if lock.resolve() != lock or lock.stat().st_size > 1024**2:
        raise ValueError('Invalid database lock path/size')
    pins = json.loads(lock.read_bytes())
    if pins.get('schema') != 1 or set(pins.get('artifacts', {})) != set(SOURCES):
        raise ValueError('Both locked database artifacts required')
    receipt = {'schema': 1, 'lock_sha256': sha(lock), 'files': {}, 'extracted': False, 'scan_verified': False}
    if (root / '.download.lock').resolve() != root / '.download.lock':
        raise ValueError('Symlink lock refused')
    with (root / '.download.lock').open('a') as guard:
        fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
        for role, (repository, tag, _) in SOURCES.items():
            pin = pins['artifacts'][role]
            path = root / (role + '-manifest.json')
            if (pin['repository'] != repository or pin['tag'] != tag or path.resolve() != path
                    or path.stat().st_size > 1024**2 or path.stat().st_size != pin['manifest_bytes']
                    or 'sha256:' + sha(path) != pin['manifest_digest']):
                raise ValueError('Frozen official manifest changed')
            manifest = validate_manifest(path.read_bytes(), role)
            token = auth(repository)
            for kind, item in [('config', manifest['config']), ('db.tar.gz', manifest['layers'][0])]:
                target = root / (role + '-' + kind)
                if target.resolve() != target:
                    raise ValueError('Symlink output refused')
                if not target.exists():
                    if shutil.disk_usage(root).free < item['size'] + 6 * 1024**3:
                        raise ValueError('Need declared download bytes plus 6 GiB headroom')
                    partial = target.with_name(target.name + '.' + uuid.uuid4().hex + '.partial')
                    request('https://ghcr.io/v2/' + repository + '/blobs/' + item['digest'], token, partial, item['size'])
                    if partial.stat().st_size != item['size'] or 'sha256:' + sha(partial) != item['digest']:
                        raise ValueError('Downloaded database differs; partial retained')
                    partial.rename(target)
                if target.stat().st_size != item['size'] or 'sha256:' + sha(target) != item['digest']:
                    raise ValueError('Existing database differs; no overwrite')
                receipt['files'][target.name] = {'bytes': item['size'], 'sha256': item['digest'][7:]}
        destination = root / 'download-receipt.json'
        if destination.exists():
            if destination.resolve() != destination or json.loads(destination.read_bytes()) != receipt:
                raise ValueError('Existing download receipt differs')
        else:
            save(destination, receipt)
    return receipt


def verify(root):
    """Read all compressed and uncompressed bytes, without extracting any file."""
    lock = root / 'scanner-db.lock.json'
    receipt_path = root / 'download-receipt.json'
    for path in (lock, receipt_path):
        if path.resolve() != path or path.stat().st_size > 1024**2:
            raise ValueError('Invalid artifact receipt path/size')
    pins, receipt = json.loads(lock.read_bytes()), json.loads(receipt_path.read_bytes())
    expected_files = {role + '-' + suffix for role in SOURCES for suffix in ('config', 'db.tar.gz')}
    if (pins.get('schema') != 1 or set(pins.get('artifacts', {})) != set(SOURCES)
            or receipt.get('schema') != 1 or receipt.get('lock_sha256') != sha(lock)
            or set(receipt.get('files', {})) != expected_files):
        raise ValueError('Both locked database artifacts and complete receipt required')
    now = dt.datetime.now(dt.timezone.utc)
    result = {'schema': 1, 'lock_sha256': sha(lock), 'checked_at': now.isoformat(),
              'archives': {}, 'extracted': False, 'scan_verified': False}
    for role, (repository, tag, _) in SOURCES.items():
        pin = pins['artifacts'][role]
        path = root / (role + '-manifest.json')
        if (pin['repository'] != repository or pin['tag'] != tag or path.resolve() != path
                or path.stat().st_size != pin['manifest_bytes'] or path.stat().st_size > 1024**2
                or 'sha256:' + sha(path) != pin['manifest_digest']):
            raise ValueError('Frozen database manifest differs')
        manifest = validate_manifest(path.read_bytes(), role)
        for suffix, item in [('config', manifest['config']), ('db.tar.gz', manifest['layers'][0])]:
            path = root / (role + '-' + suffix)
            if (path.resolve() != path or path.stat().st_size != item['size']
                    or 'sha256:' + sha(path) != item['digest']
                    or receipt['files'][path.name] != {'bytes': item['size'], 'sha256': item['digest'][7:]}):
                raise ValueError('Database blob or receipt differs')
        expected = {'metadata.json', 'trivy.db' if role == 'db' else 'trivy-java.db'}
        members, total, metadata = {}, 0, None
        with tarfile.open(root / (role + '-db.tar.gz'), 'r|gz') as archive:
            for item in archive:
                if not item.isfile() or item.name not in expected or item.name in members:
                    raise ValueError('Unexpected database archive member/type')
                total += item.size
                if total > 16 * 1024**3 or (item.name == 'metadata.json' and item.size > 65536):
                    raise ValueError('Database unpacked size exceeds bound')
                with archive.extractfile(item) as stream:
                    if item.name == 'metadata.json':
                        raw = stream.read(); metadata = json.loads(raw)
                        digest = hashlib.sha256(raw).hexdigest()
                    else:
                        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
                members[item.name] = {'bytes': item.size, 'sha256': digest}
        if set(members) != expected or metadata.get('Version') != int(tag):
            raise ValueError('Incomplete archive or incompatible database schema')
        updated = dt.datetime.fromisoformat(metadata['UpdatedAt'].replace('Z', '+00:00'))
        next_update = dt.datetime.fromisoformat(metadata['NextUpdate'].replace('Z', '+00:00'))
        age = (now - updated).total_seconds()
        maximum_age = (48 if role == 'db' else 7 * 24) * 3600
        if age < -600 or age > maximum_age or next_update <= updated:
            raise ValueError('Database age/timestamp gate failed; prepare a new batch')
        result['archives'][role] = {'members': members, 'uncompressed_bytes': total,
                                   'metadata': metadata, 'age_seconds': int(age),
                                   'maximum_age_seconds': maximum_age}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['resolve', 'download', 'verify'])
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(); root = args.root.expanduser().absolute()
    if root.resolve() != root:
        raise ValueError('Nonsymlink batch directory required')
    if not args.apply:
        print(json.dumps({'dry_run': True, 'action': args.action, 'root': str(root),
                          'sources': SOURCES, 'extract': False, 'install': False})); return
    print(json.dumps({'resolve': resolve, 'download': download, 'verify': verify}[args.action](root), indent=2))


if __name__ == '__main__':
    main()
