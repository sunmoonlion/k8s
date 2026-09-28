#!/usr/bin/env python3
"""Convert one explicitly selected Docker archive to an immutable OCI publication batch.

Default is a local plan. No registry, Docker daemon, credentials or cluster access.
Cloud execution 未经实机验证. Inputs and incomplete outputs are never removed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import tempfile

from publish import (PublicationError, absolute, archive_size, checksum, fields,
                     file_hash, integer, invoke, load_batch, unique_object, verify_file)
from images import DIGEST, REGISTRY, REPOSITORY


def settings(path):
    path = absolute(str(path))
    if path.stat().st_size > 1024**2:
        raise PublicationError('Settings exceed 1 MiB')
    data = json.loads(path.read_bytes(), object_pairs_hook=unique_object)
    fields(data, 'schema tool work_root minimum_free_gib timeout_seconds retry_times')
    if type(data['schema']) is not int or data['schema'] != 1:
        raise PublicationError('Unsupported settings schema')
    fields(data['tool'], 'path sha256')
    absolute(data['tool']['path'])
    checksum(data['tool']['sha256'])
    absolute(data['work_root'])
    integer(data['minimum_free_gib'], 2, 1000)
    integer(data['timeout_seconds'], 30, 7200)
    integer(data['retry_times'], 0, 3)
    return data


def docker_archive_size(path):
    """Reject ambiguous/malicious inputs before handing the tar to Skopeo."""
    total, members = 0, {}
    with tarfile.open(path, 'r:*') as source:
        for member in source:
            name = member.name
            parts = PurePosixPath(name).parts
            normalized = str(PurePosixPath(name))
            if (name.startswith('/') or '..' in parts or normalized in members
                    or not (member.isfile() or member.isdir()) or member.pax_headers.get('linkpath')):
                raise PublicationError('Unsafe or duplicate Docker archive entry')
            members[normalized] = member
            if member.isfile():
                total += member.size
            if total > 200 * 1024**3 or len(members) > 100000:
                raise PublicationError('Docker archive exceeds limits')
        manifest = members.get('manifest.json')
        if not manifest or not manifest.isfile() or manifest.size > 4 * 1024**2:
            raise PublicationError('Docker archive requires manifest.json')
        entries = json.load(source.extractfile(manifest), object_pairs_hook=unique_object)
        if not isinstance(entries, list) or len(entries) != 1:
            raise PublicationError('Select exactly one image per Docker archive')
        entry = entries[0]
        if not isinstance(entry, dict) or not isinstance(entry.get('Layers'), list):
            raise PublicationError('Invalid Docker archive manifest')
        for name in [entry.get('Config'), *entry['Layers']]:
            if not isinstance(name, str) or name not in members or not members[name].isfile():
                raise PublicationError('Missing Docker archive config or layer')
    return total


def write_json(path, value):
    with path.open('x') as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')


def prepare(args, data):
    archive = absolute(str(args.archive))
    output = absolute(str(args.output_directory))
    work = absolute(data['work_root'])
    tool = absolute(data['tool']['path'])
    verify_file(tool, data['tool']['sha256'])
    verify_file(archive, args.archive_sha256)
    if not os.access(tool, os.X_OK) or not work.is_dir() or not output.parent.is_dir():
        raise PublicationError('Tool/work/output parent must be prepared first')
    expanded = docker_archive_size(archive)
    required = 3 * expanded + data['minimum_free_gib'] * 1024**3
    for parent in (work, output.parent):
        if shutil.disk_usage(parent).free < required:
            raise PublicationError('Need three times expanded input plus free reserve')
    output.mkdir(mode=0o700, exist_ok=False)
    oci = output / 'image.oci.tar'
    # Trust only this explicitly admitted local build/export; this is not an
    # upstream signature assertion or a global insecure-policy override.
    conversion_policy = output / 'conversion-policy.json'
    write_json(conversion_policy, {'default': [{'type': 'reject'}], 'transports': {
        'docker-archive': {str(archive): [{'type': 'insecureAcceptAnything'}]}}})
    policy = output / 'publication-policy.json'
    write_json(policy, {'default': [{'type': 'reject'}], 'transports': {
        'oci-archive': {str(oci): [{'type': 'insecureAcceptAnything'}]}}})
    env = {k: v for k, v in os.environ.items() if k.lower() not in
           ('http_proxy', 'https_proxy', 'all_proxy', 'no_proxy')}
    with tempfile.TemporaryDirectory(prefix='.sunmoon-convert-', dir=work) as temporary:
        temp = Path(temporary)
        auth = temp / 'auth.json'
        write_json(auth, {'auths': {}})
        auth.chmod(0o600)
        registries = temp / 'registries.conf'
        registries.write_text('unqualified-search-registries = []\n')
        signatures = temp / 'registries.d'
        signatures.mkdir()
        env.update(REGISTRY_AUTH_FILE=str(auth), TMPDIR=str(temp), XDG_RUNTIME_DIR=str(temp),
                   XDG_CACHE_HOME=str(temp / 'cache'), XDG_DATA_HOME=str(temp / 'data'))
        base = [str(tool), '--tmpdir', str(temp), '--registries-conf', str(registries),
                '--registries.d', str(signatures), '--command-timeout', str(data['timeout_seconds']) + 's']
        receipt = temp / 'digest'
        verify_file(archive, args.archive_sha256)
        invoke(base + ['--policy', str(conversion_policy), 'copy', '--format', 'oci', '--all',
                       '--authfile', str(auth), '--digestfile', str(receipt),
                       'docker-archive:' + str(archive), 'oci-archive:' + str(oci)],
               env, data['timeout_seconds'] + 15)
        digest = receipt.read_text().strip()
        if not DIGEST.fullmatch(digest):
            raise PublicationError('Conversion did not return a manifest digest')
        raw = invoke(base + ['--policy', str(policy), 'inspect', '--raw', 'oci-archive:' + str(oci)],
                     env, data['timeout_seconds'] + 15)
        if 'sha256:' + hashlib.sha256(raw).hexdigest() != digest:
            raise PublicationError('Converted manifest differs from conversion receipt')
    verify_file(archive, args.archive_sha256)
    item = {'archive': str(oci), 'archive_sha256': file_hash(oci), 'archive_bytes': oci.stat().st_size,
            'manifest_digest': digest, 'destination': args.repository + '@' + digest}
    archive_size(item)
    batch = {**data, 'policy': {'path': str(policy), 'sha256': file_hash(policy)}, 'images': [item]}
    write_json(output / 'source.json', {'archive': str(archive), 'sha256': args.archive_sha256,
                                      'manifest_digest': digest, 'published': False,
                                      'upstream_signature_verified': False})
    batch_path = output / 'publication.json'
    write_json(batch_path, batch)
    load_batch(batch_path)
    print(json.dumps({'batch': str(batch_path), 'destination': item['destination'], 'published': False}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--settings', type=Path, required=True)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--archive-sha256', required=True)
    parser.add_argument('--repository', required=True, help='Full registry/project/repository, without tag')
    parser.add_argument('--output-directory', type=Path, required=True, help='New directory; parent must exist')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    data = settings(args.settings)
    absolute(str(args.archive))
    absolute(str(args.output_directory))
    checksum(args.archive_sha256)
    repository = args.repository.removeprefix(REGISTRY + '/')
    if (not args.repository.startswith(REGISTRY + '/') or '/' not in repository
            or not REPOSITORY.fullmatch(repository)):
        raise PublicationError('Use the approved registry and a repository without a tag/digest')
    if not args.apply:
        print(json.dumps({'apply': False, 'archive': str(args.archive), 'settings': data,
                          'output': str(args.output_directory), 'repository': args.repository,
                          'network': False, 'input_bytes_verified': False}, indent=2))
        return
    prepare(args, data)


if __name__ == '__main__':
    try:
        main()
    except PublicationError as error:
        raise SystemExit('Preparation stopped: ' + str(error)) from None
    except (OSError, ValueError, TypeError, KeyError, AttributeError, tarfile.TarError,
            subprocess.SubprocessError) as error:
        raise SystemExit('Preparation stopped: ' + type(error).__name__ +
                         '; inputs and incomplete output retained; no publication performed') from None
