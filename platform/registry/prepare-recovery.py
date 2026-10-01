#!/usr/bin/env python3
"""Verify a cold backup and render an isolated official Compose recovery copy.

No service lifecycle or deletion is performed here; Ansible owns those steps.
The source archive and live instance are read-only inputs.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import tarfile


def require(ok, message):
    if not ok:
        raise SystemExit(message)


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def private_json(path, value):
    with path.open('x') as stream:
        os.chmod(path, 0o600)
        json.dump(value, stream, indent=2)
        stream.write('\n')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--backup', required=True)
    p.add_argument('--sha256', required=True)
    p.add_argument('--destination', required=True)
    p.add_argument('--site', required=True)
    p.add_argument('--images-lock', required=True)
    p.add_argument('--files-lock', required=True)
    p.add_argument('--project', required=True)
    p.add_argument('--port', type=int, required=True)
    args = p.parse_args()
    site = json.loads(args.site)
    backup = Path(args.backup)
    dest = Path(args.destination)
    instance = Path(site['registry_instance_dir'])
    require(os.geteuid() == 0, 'Run through the privileged recovery playbook')
    require(backup.is_file() and not backup.is_symlink(), 'Backup must be a regular file')
    require(digest(backup) == args.sha256, 'Backup checksum mismatch')
    require(dest.parent == instance / 'recovery' and dest.name.startswith('rehearsal-'), 'Invalid recovery destination')
    require(not dest.exists() and not dest.is_symlink(), 'Recovery destination must be new')
    require(dest.parent.is_dir() and not dest.parent.is_symlink(), 'Recovery parent missing or linked')
    require(instance.resolve() == instance and dest.parent.resolve() == dest.parent, 'Linked recovery path rejected')
    require(args.project.startswith('sunmoon-recovery-') and args.project.replace('-', '').isalnum(), 'Invalid isolated project')
    require(args.port not in [80, 443, 30443, site['registry_https_port']] and 1024 < args.port < 65536, 'Invalid isolated port')
    roots = [site['registry_config_dir'].lstrip('/'), site['registry_runtime_dir'].lstrip('/'), str(instance / 'data').lstrip('/')]
    with tarfile.open(backup) as archive:
        members = archive.getmembers()
        names = set()
        for m in members:
            path = PurePosixPath(m.name)
            require(not path.is_absolute() and '..' not in path.parts, 'Unsafe archive path')
            require(m.name not in names, 'Duplicate archive path')
            names.add(m.name)
            require(m.isdir() or m.isfile(), 'Backup contains a link or special file')
            require(any(m.name == r or m.name.startswith(r + '/') for r in roots), 'Unexpected archive root')
        dest.mkdir(mode=0o700)
        tree = dest / 'tree'
        tree.mkdir(mode=0o700)
        # Fully trusted extraction only after the closed path/type/duplicate checks above.
        archive.extractall(tree, members=members, filter='fully_trusted')
        file_hashes = {}
        registry_hashes = {}
        for m in members:
            target = tree / m.name
            stat = target.stat()
            require(stat.st_uid == m.uid and stat.st_gid == m.gid and (stat.st_mode & 0o7777) == m.mode, 'Restored metadata differs: ' + m.name)
            if not m.isfile():
                continue
            expected = hashlib.file_digest(archive.extractfile(m), 'sha256').hexdigest()
            require(stat.st_size == m.size and digest(target) == expected, 'Restored bytes differ: ' + m.name)
            file_hashes[m.name] = expected
            if m.name.startswith(str(instance / 'data/registry').lstrip('/') + '/'):
                registry_hashes[m.name] = expected
        require(registry_hashes, 'Backup has no registry content')
    private_json(dest / 'restored-files.json', file_hashes)
    private_json(dest / 'registry-before.json', registry_hashes)
    runtime = tree / site['registry_runtime_dir'].lstrip('/')
    file_lock = json.loads(Path(args.files_lock).read_text())
    compose = runtime / 'docker-compose'
    compose_record = next(x for x in file_lock['files'] if x['id'] == 'compose')
    require(digest(compose) == compose_record['sha256'], 'Backed-up Compose differs from the release lock')
    # Rendering only: no service is started by config. Relative env files resolve inside the backup.
    result = subprocess.run([str(compose), '-p', args.project, '-f', str(runtime / 'docker-compose.yml'), '-f', str(runtime / 'compose.override.yaml'), 'config', '--format', 'json'], capture_output=True)
    require(result.returncode == 0, 'Copied Compose could not be rendered; no service started')
    model = json.loads(result.stdout)
    expected_services = {'log', 'core', 'jobservice', 'portal', 'postgresql', 'proxy', 'redis', 'registry', 'registryctl', 'trivy-adapter'}
    require(set(model['services']) == expected_services, 'Unexpected service set')
    require(not model.get('volumes') and not model.get('secrets') and not model.get('configs'), 'External storage/config rejected')
    allowed_images = {i['archive_reference'] for i in json.loads(Path(args.images_lock).read_text())['images']}
    for name, service in model['services'].items():
        require(service['image'] in allowed_images, 'Image not in release lock')
        require(not service.get('privileged') and not service.get('devices') and not service.get('network_mode'), 'Unsafe service isolation')
        service.pop('container_name', None)
        service['restart'] = 'no'
        service['pull_policy'] = 'never'
        service['ports'] = []
        service['networks'] = {'harbor': None}
        for volume in service.get('volumes', []):
            require(volume['type'] == 'bind', 'Non-bind mount rejected')
            source = Path(volume['source'])
            # Compose already resolves relative configuration binds under the copied tree.
            if source.is_relative_to(tree):
                source = Path('/') / source.relative_to(tree)
            allowed = [Path(site['registry_runtime_dir']), Path(site['registry_config_dir']), instance / 'data', instance / 'logs']
            require(any(source == r or r in source.parents for r in allowed), 'Mount outside recovery scope')
            copied = tree / str(source).lstrip('/')
            if source == instance / 'logs':
                copied.mkdir(parents=True, exist_ok=True)
            require(copied.exists() and copied.resolve() == copied, 'Missing or linked copied bind')
            volume['source'] = str(copied)
            volume.setdefault('bind', {})['create_host_path'] = False
    model['name'] = args.project
    model['networks'] = {'harbor': {'name': args.project + '_harbor', 'internal': True}, 'access': {'name': args.project + '_access'}}
    # Docker does not publish ports on an internal-only network. Only the proxy joins access.
    model['services']['proxy']['networks']['access'] = None
    endpoint = 'https://' + site['registry_hostname'] + ':' + str(args.port)
    require(model['services']['core']['environment']['EXT_ENDPOINT'] == 'https://' + site['registry_address'], 'Unexpected original endpoint')
    model['services']['core']['environment']['EXT_ENDPOINT'] = endpoint
    model['services']['proxy']['ports'] = [{'host_ip': '127.0.0.1', 'published': str(args.port), 'target': 8443, 'protocol': 'tcp'}]
    private_json(dest / 'compose.json', model)
    # Same backed-up read-only robot; only its registry address is adjusted for the isolated port.
    original_auth = json.loads((tree / site['registry_config_dir'].lstrip('/') / 'private/puller-auth.json').read_text())
    require(set(original_auth['auths']) == {site['registry_address']}, 'Unexpected backup pull identity')
    private_json(dest / 'puller-auth.json', {'auths': {site['registry_hostname'] + ':' + str(args.port): original_auth['auths'][site['registry_address']]}})
    receipt = {'backup_sha256': args.sha256, 'restored_files': len(file_hashes), 'registry_files': len(registry_hashes), 'project': args.project, 'endpoint': endpoint, 'binds_isolated': True, 'backend_network_internal': True, 'access_network_services': ['proxy'], 'compose': str(dest / 'compose.json')}
    private_json(dest / 'prepared.json', receipt)
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
