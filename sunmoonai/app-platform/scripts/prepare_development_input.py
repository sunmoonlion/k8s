#!/usr/bin/env python3
"""Prepare the existing KIND development input from explicit local build artifacts.

Default plan reads metadata only. Apply hashes local archives, checks source and
registry manifests, then creates a NEW input file. No build/push/render/deploy.
This is KIND development preparation, not an enabled cloud production release.
"""
import argparse
import copy
import hashlib
import http.client
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile

import development_release as development

K8S_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(K8S_ROOT / 'sunmoonai/registry-platform'))
from client import config, check_registry
from images import Registry, ImageCheckError
from publish import (PublicationError, absolute, archive_size, file_hash,
                     load_batch, unique_object, verify_file)
from prepare_image import docker_archive_size


class PreparationError(RuntimeError):
    """Diagnostics formed only from local fixed messages."""


def read_json(path):
    path = absolute(str(path))
    if not path.is_file() or path.stat().st_size > 1024**2:
        raise PreparationError('Expected regular metadata file up to 1 MiB')
    return json.loads(path.read_bytes(), object_pairs_hook=unique_object)


def validate_input(value):
    required = {'kind', 'logical_app', 'migration_head', 'development_source_lock', 'images'}
    optional = {'runtime_identity_mode', 'runtime_identity_upgrade', 'artifact_evidence'}
    if (not isinstance(value, dict) or not required <= value.keys()
            or not set(value) <= required | optional
            or value['kind'] != 'kind-development-release-input'):
        raise PreparationError('Expected an existing development input, without unknown fields')
    development.validate({**value, 'architecture': development.ARCHITECTURE,
                          'formal_release': False, 'deployment_target': 'KIND',
                          'namespace': 'app-platform-dev', 'resource_app': value['logical_app']})


def verify_oci_config(item, image_id):
    """Bind the converted OCI manifest to the exported Docker config ID.

    Layer pulls and decompressed diffID validation remain separate acceptance.
    """
    with tarfile.open(item['archive'], 'r:*') as archive:
        manifest_member = archive.getmember('blobs/sha256/' + item['manifest_digest'].split(':')[1])
        if not manifest_member.isfile() or manifest_member.size > 4 * 1024**2:
            raise PreparationError('Invalid OCI manifest entry')
        raw = archive.extractfile(manifest_member).read()
        if 'sha256:' + hashlib.sha256(raw).hexdigest() != item['manifest_digest']:
            raise PreparationError('OCI manifest bytes differ from batch digest')
        manifest = json.loads(raw, object_pairs_hook=unique_object)
        descriptor = manifest.get('config', {})
        if manifest.get('schemaVersion') != 2 or descriptor.get('digest') != image_id:
            raise PreparationError('OCI conversion config differs from recorded build; cannot bind artifact automatically')
        config_member = archive.getmember('blobs/sha256/' + image_id.split(':')[1])
        if (not config_member.isfile() or config_member.size > 4 * 1024**2
                or config_member.size != descriptor.get('size')):
            raise PreparationError('Invalid OCI config entry')
        if 'sha256:' + hashlib.sha256(archive.extractfile(config_member).read()).hexdigest() != image_id:
            raise PreparationError('OCI config bytes differ from recorded build ID')


def artifact(value, app, component, verify):
    root = absolute(value)
    build_path = root / 'build.json'
    batch_path = root / 'oci/publication.json'
    source_path = root / 'oci/source.json'
    build, source = read_json(build_path), read_json(source_path)
    batch = load_batch(batch_path)
    if len(batch['images']) != 1:
        raise PreparationError('One component artifact must contain exactly one image')
    item = batch['images'][0]
    if (build.get('source_commit') != component['commit'] or build.get('platform') != 'linux/amd64'
            or build.get('tracked_tree_clean') is not True
            or not re.fullmatch(r'[a-f0-9]{40}', str(build.get('parent_commit')))
            or not re.fullmatch(r'sha256:[a-f0-9]{64}', str(build.get('docker_image_id')))
            or not re.fullmatch(r'[a-f0-9]{64}', str(build.get('dockerfile_sha256')))):
        raise PreparationError('Build metadata does not match the selected source/platform')
    expected_image = f"harbor.sunmoonai.com:30443/app-images/{component['path']}@{item['manifest_digest']}"
    if (item['destination'] != expected_image or item['archive'] != str(root / 'oci/image.oci.tar')
            or source.get('archive') != str(root / 'docker.tar')
            or not re.fullmatch(r'[a-f0-9]{64}', str(source.get('sha256')))
            or source.get('manifest_digest') != item['manifest_digest']):
        raise PreparationError('Artifact archive/source/destination mapping differs')
    record = {
        'source_commit': component['commit'], 'source_tree': component['tree'],
        'parent_commit': build['parent_commit'], 'dockerfile_sha256': build['dockerfile_sha256'],
        'docker_image_id': build['docker_image_id'], 'docker_archive_sha256': source['sha256'],
        'oci_archive_sha256': item['archive_sha256'], 'manifest_digest': item['manifest_digest'],
        'build_metadata_sha256': file_hash(build_path), 'publication_batch_sha256': file_hash(batch_path),
    }
    if verify:
        docker = root / 'docker.tar'
        verify_file(docker, source['sha256'])
        docker_archive_size(docker)
        # The Docker image ID hashes its config, not its registry manifest.
        with tarfile.open(docker, 'r:*') as archive:
            manifests = json.load(archive.extractfile('manifest.json'))
            member = archive.getmember(manifests[0]['Config'])
            if member.size > 4 * 1024**2:
                raise PreparationError('Docker image config exceeds limit')
            config_digest = hashlib.sha256(archive.extractfile(member).read()).hexdigest()
        if 'sha256:' + config_digest != build['docker_image_id']:
            raise PreparationError('Exported Docker config differs from the recorded build ID')
        archive_size(item)
        verify_oci_config(item, build['docker_image_id'])
        context = K8S_ROOT.parent / (app + '-app') / component['path']
        if file_hash(context / 'mybuild/Dockerfile') != build['dockerfile_sha256']:
            raise PreparationError('Build Dockerfile differs from selected source checkout')
        gitlink = subprocess.check_output(
            ['git', '-C', str(context.parent), 'rev-parse', build['parent_commit'] + ':' + component['path']],
            text=True, stderr=subprocess.PIPE, timeout=15).strip()
        if gitlink != component['commit']:
            raise PreparationError('Recorded parent revision does not select this component revision')
    return item['destination'], record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-input', required=True, type=Path)
    parser.add_argument('--artifact', required=True, action='append', metavar='ROLE=/absolute/component-directory',
                        help='backend/admin/web; repeat for rebuilt components only')
    parser.add_argument('--migration-head', required=True)
    parser.add_argument('--output', required=True, type=Path, help='New absolute JSON file; never overwrites a bundle')
    parser.add_argument('--registry-config', type=Path)
    parser.add_argument('--credentials-file', type=Path, help='Read-only registry identity for manifest checks')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    output = absolute(str(args.output))
    if output.exists() or not output.parent.is_dir():
        raise PreparationError('Output must be new, with an existing parent directory')
    base = read_json(args.base_input)
    validate_input(base)
    app = base['logical_app']
    lock_path = K8S_ROOT.parent / (app + '-app/development-source-lock.json')
    source_lock = read_json(lock_path)
    candidate = copy.deepcopy(base)
    candidate['development_source_lock'] = source_lock
    candidate['migration_head'] = args.migration_head
    # Validate new source-lock structure before looking up component records.
    candidate.pop('artifact_evidence', None)
    validate_input(candidate)
    previous = {c['path']: c for c in base['development_source_lock']['components']}
    components = {c['path']: c for c in source_lock['components']}
    requested = {}
    for specification in args.artifact:
        role, separator, directory = specification.partition('=')
        if not separator or role not in development.ROLES or role in requested:
            raise PreparationError('Use each backend/admin/web role at most once')
        requested[role] = directory
    evidence = copy.deepcopy(base.get('artifact_evidence', {}))
    for role, suffix in development.ROLES.items():
        component = components[app + '-' + suffix]
        if role in requested:
            image, record = artifact(requested[role], app, component, args.apply)
            candidate['images'][role] = image
            evidence[role] = record
        elif any(previous[component['path']][key] != component[key] for key in ('commit', 'tree')):
            raise PreparationError('Source changed for an unreplaced component; rebuild it or select a matching artifact')
    candidate['artifact_evidence'] = evidence
    validate_input(candidate)
    candidate_bytes = (json.dumps(candidate, ensure_ascii=False, indent=2) + '\n').encode()
    if args.apply:
        development.verify_source_input(candidate, K8S_ROOT)
        profile = config(args.registry_config)
        check_registry(profile)
        registry = Registry(profile, args.credentials_file)
        for image in candidate['images'].values():
            observed = registry.inspect(image)
            if observed['state'] != 'exists':
                raise PreparationError('A candidate image manifest is absent; publish its admitted batch first')
        # Recheck metadata/source after slow file hashing and network checks.
        if read_json(args.base_input) != base or read_json(lock_path) != source_lock:
            raise PreparationError('Release inputs changed during preparation')
        for role, directory in requested.items():
            image, record = artifact(directory, app, components[app + '-' + development.ROLES[role]], False)
            if record != evidence[role] or image != candidate['images'][role]:
                raise PreparationError('Artifact metadata changed during preparation')
        development.verify_source_input(candidate, K8S_ROOT)
        with output.open('xb') as stream:
            stream.write(candidate_bytes)
    print(json.dumps({'apply': args.apply, 'output': str(output), 'images': candidate['images'],
                      'rebuilt_roles': sorted(requested), 'input_sha256': hashlib.sha256(candidate_bytes).hexdigest(),
                      'reused_roles': sorted(set(development.ROLES) - requested.keys()),
                      'source_checks_completed': args.apply, 'supplied_artifact_checks_completed': args.apply,
                      'registry_manifests_checked': args.apply, 'layers_pulled': False,
                      'rendered': False, 'deployed': False}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except PreparationError as error:
        raise SystemExit('Development input preparation stopped: ' + str(error)) from None
    except (OSError, ValueError, TypeError, KeyError, AttributeError, PublicationError, ImageCheckError,
            http.client.HTTPException, tarfile.TarError, subprocess.SubprocessError) as error:
        raise SystemExit('Development input preparation stopped: ' + type(error).__name__ +
                         '; check explicit source/artifacts/registry; no deployment performed') from None
