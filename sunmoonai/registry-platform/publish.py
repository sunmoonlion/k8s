#!/usr/bin/env python3
"""Publish an admitted OCI archive batch by digest. Default prints a local plan.

Same implementation on local/cloud hosts; cloud execution 未经实机验证.
No source downloads, cluster access, Docker load, mutable tags or cleanup of inputs.
"""
import argparse
import hashlib
import http.client
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import tarfile
import tempfile

from client import config, checked_ca, check_registry
from credentials import load_credentials, docker_config
from images import REGISTRY, DIGEST, REPOSITORY, Registry, ImageCheckError


class PublicationError(RuntimeError):
    """Safe local diagnostics; external tool output is never included."""


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise PublicationError('Duplicate JSON field')
        result[key] = value
    return result


def fields(value, expected):
    if not isinstance(value, dict) or set(value) != set(expected.split()):
        raise PublicationError('Unexpected or missing batch fields')


def absolute(value):
    if not isinstance(value, str) or any(c in value for c in '\n\r\0:'):
        raise PublicationError('Invalid local path')
    path = Path(value)
    if not path.is_absolute() or path.resolve() != path:
        raise PublicationError('Absolute paths without symlinks or traversal required')
    return path


def checksum(value):
    if not isinstance(value, str) or not re.fullmatch('[a-f0-9]{64}', value):
        raise PublicationError('A locked SHA256 is required')


def integer(value, low, high):
    if type(value) is not int or not low <= value <= high:
        raise PublicationError('Invalid numeric batch setting')


def file_hash(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify_file(path, sha, size=None):
    absolute(str(path))
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or (size is not None and info.st_size != size):
        raise PublicationError('Required regular file/size differs')
    if file_hash(path) != sha:
        raise PublicationError('File SHA256 differs from admitted batch')


def load_batch(path):
    path = absolute(str(path))
    if not path.is_file() or path.stat().st_size > 1024**2:
        raise PublicationError('Batch exceeds 1 MiB')
    data = json.loads(path.read_bytes(), object_pairs_hook=unique_object)
    fields(data, 'schema tool policy work_root minimum_free_gib timeout_seconds retry_times images')
    if type(data['schema']) is not int or data['schema'] != 1:
        raise PublicationError('Unsupported batch schema')
    for key in ('tool', 'policy'):
        fields(data[key], 'path sha256')
        absolute(data[key]['path'])
        checksum(data[key]['sha256'])
    absolute(data['work_root'])
    integer(data['minimum_free_gib'], 2, 1000)
    integer(data['timeout_seconds'], 30, 7200)
    integer(data['retry_times'], 0, 3)
    if not isinstance(data['images'], list) or not 1 <= len(data['images']) <= 500:
        raise PublicationError('Batch requires 1..500 images')
    targets = set()
    for item in data['images']:
        fields(item, 'archive archive_sha256 archive_bytes manifest_digest destination')
        absolute(item['archive'])
        checksum(item['archive_sha256'])
        integer(item['archive_bytes'], 1, 200 * 1024**3)
        if not isinstance(item['manifest_digest'], str) or not DIGEST.fullmatch(item['manifest_digest']):
            raise PublicationError('Invalid manifest digest')
        destination = item['destination']
        if not isinstance(destination, str) or not destination.startswith(REGISTRY + '/'):
            raise PublicationError('Destination must use the approved registry')
        repository, sep, digest = destination[len(REGISTRY) + 1:].partition('@')
        if not sep or digest != item['manifest_digest'] or '/' not in repository or not REPOSITORY.fullmatch(repository):
            raise PublicationError('Publication requires a full repo@sha256 reference; tags are not accepted')
        if destination in targets:
            raise PublicationError('Duplicate publication destination')
        targets.add(destination)
    return data


def archive_size(item):
    """Inspect metadata without extraction; reject dangerous archive entries."""
    archive = absolute(item['archive'])
    verify_file(archive, item['archive_sha256'], item['archive_bytes'])
    total = 0
    names = set()
    with tarfile.open(archive, 'r:*') as source:
        for member in source:
            name = member.name
            parts = PurePosixPath(name).parts
            if (not parts or name.startswith('/') or '..' in parts or name in names
                    or not (member.isfile() or member.isdir()) or member.pax_headers.get('linkpath')):
                raise PublicationError('Unsafe or duplicate archive member')
            names.add(name)
            if member.isfile():
                if name not in ('oci-layout', 'index.json') and not re.fullmatch('blobs/sha256/[a-f0-9]{64}', name):
                    raise PublicationError('Only OCI layout metadata and SHA256 blobs are admitted')
                total += member.size
                if total > 200 * 1024**3 or len(names) > 100000:
                    raise PublicationError('OCI archive exceeds limits')
        for name in ('oci-layout', 'index.json'):
            member = source.getmember(name)
            if not member.isfile() or member.size > 4 * 1024**2:
                raise PublicationError('Invalid OCI layout metadata')
        layout = json.load(source.extractfile('oci-layout'))
        index = json.load(source.extractfile('index.json'))
        if layout != {'imageLayoutVersion': '1.0.0'}:
            raise PublicationError('Unsupported OCI layout')
        manifests = index.get('manifests', [])
        if (index.get('schemaVersion') != 2 or len(manifests) != 1
                or manifests[0].get('digest') != item['manifest_digest']):
            raise PublicationError('OCI archive must select exactly the locked root manifest')
    return total


def invoke(command, env, timeout):
    # Never print raw tool output: authentication diagnostics may include secrets.
    result = subprocess.run(command, env=env, stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    if result.returncode:
        raise PublicationError('Skopeo failed; publication stopped, no source or remote cleanup performed')
    return result.stdout


def apply(batch, profile, credentials_file):
    tool = absolute(batch['tool']['path'])
    policy = absolute(batch['policy']['path'])
    verify_file(tool, batch['tool']['sha256'])
    verify_file(policy, batch['policy']['sha256'])
    if not os.access(tool, os.X_OK):
        raise PublicationError('Admitted Skopeo binary must be executable')
    work_root = absolute(batch['work_root'])
    if not work_root.is_dir():
        raise PublicationError('Prepare the explicit work directory first')
    # Validate every input before the first registry write.
    sizes = [archive_size(item) for item in batch['images']]
    reserve = batch['minimum_free_gib'] * 1024**3
    if shutil.disk_usage(work_root).free < max(sizes) * 2 + reserve:
        raise PublicationError('Need twice the largest expanded archive plus configured free reserve')
    ca, _ = checked_ca(profile)
    credentials = load_credentials(credentials_file or profile['REGISTRY_CREDENTIALS_FILE'])
    check_registry(profile)
    registry = Registry(profile, credentials_file)
    env = {k: v for k, v in os.environ.items() if k.lower() not in
           ('http_proxy', 'https_proxy', 'all_proxy', 'no_proxy')}
    env.update(NO_PROXY='harbor.sunmoonai.com', no_proxy='harbor.sunmoonai.com')
    # Temporary private auth/CA/work files only; source archives remain untouched.
    with tempfile.TemporaryDirectory(prefix='.sunmoon-publish-', dir=work_root) as temporary:
        temp = Path(temporary)
        auth = temp / 'auth.json'
        fd = os.open(auth, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as stream:
            stream.write(docker_config(credentials))
        certs = temp / 'certs'
        certs.mkdir()
        (certs / 'ca.crt').write_bytes(ca)
        env.update(TMPDIR=str(temp), REGISTRY_AUTH_FILE=str(auth), XDG_RUNTIME_DIR=str(temp),
                   XDG_CACHE_HOME=str(temp / 'cache'), XDG_DATA_HOME=str(temp / 'data'))
        registries = temp / 'registries.conf'
        registries.write_text('unqualified-search-registries = []\n[[registry]]\nprefix = "' +
                              REGISTRY + '"\nlocation = "' + REGISTRY + '"\ninsecure = false\n')
        signature_dir = temp / 'registries.d'
        signature_dir.mkdir()
        base = [str(tool), '--policy', str(policy), '--tmpdir', str(temp),
                '--registries-conf', str(registries), '--registries.d', str(signature_dir),
                '--command-timeout', str(batch['timeout_seconds']) + 's']
        timeout = batch['timeout_seconds'] + 15
        for item in batch['images']:
            raw = invoke(base + ['inspect', '--raw', 'oci-archive:' + item['archive']], env, timeout)
            if 'sha256:' + hashlib.sha256(raw).hexdigest() != item['manifest_digest']:
                raise PublicationError('Source manifest differs from batch; no publication for this item')
        for number, item in enumerate(batch['images']):
            verify_file(Path(item['archive']), item['archive_sha256'], item['archive_bytes'])
            if shutil.disk_usage(work_root).free < sizes[number] * 2 + reserve:
                raise PublicationError('Publication work space fell below the admitted reserve')
            receipt = temp / ('digest-' + str(number))
            invoke(base + ['copy', '--all', '--preserve-digests', '--quiet',
                          '--dest-tls-verify=true', '--dest-cert-dir', str(certs),
                          '--authfile', str(auth), '--retry-times', str(batch['retry_times']),
                          '--digestfile', str(receipt), 'oci-archive:' + item['archive'],
                          'docker://' + item['destination']], env, timeout)
            if receipt.read_text().strip() != item['manifest_digest']:
                raise PublicationError('Copy result digest differs; stop and investigate')
            observed = registry.inspect(item['destination'])
            if observed['state'] != 'exists':
                raise PublicationError('Registry readback failed after publication')
            print(json.dumps({'destination': item['destination'], 'digest': observed['digest'],
                              'copy_completed': True, 'node_ci_pull_verified': False}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch', required=True, type=Path)
    parser.add_argument('--config', type=Path)
    parser.add_argument('--credentials-file', type=Path)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    batch = load_batch(args.batch)
    profile = config(args.config)
    if not args.apply:
        print(json.dumps({'apply': False, 'batch': str(args.batch), 'settings': batch,
                          'credentials_read': False, 'network': False,
                          'input_bytes_verified': False, 'tool_ready': False,
                          'scope': 'OCI archives to immutable digest references; no release aliases'}, indent=2))
        return
    apply(batch, profile, args.credentials_file)


if __name__ == '__main__':
    try:
        main()
    except (PublicationError, ImageCheckError) as error:
        raise SystemExit('Publication stopped: ' + str(error) + '; earlier completed copies may remain') from None
    except (OSError, ValueError, TypeError, KeyError, AttributeError, http.client.HTTPException, tarfile.TarError,
            subprocess.SubprocessError) as error:
        raise SystemExit('Publication stopped: ' + type(error).__name__ +
                         '; check admitted inputs, tool, disk, TLS and credentials; partial remote content may remain') from None
