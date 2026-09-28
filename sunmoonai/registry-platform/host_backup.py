#!/usr/bin/env python3
"""Independent Harbor cold backup and new-instance restoration preparation.

Default prints only. This first adapter accepts reconciled READ-ONLY instances
that are already stopped. It briefly starts them for a fresh catalog, stops them,
exports PG17.6 with only PG running, then copies stopped registry/runtime state.
It does not freeze an existing production writer, switch ingress, send backups
off-machine, delete anything or install missing tools. Cloud 未经实机验证.
"""
import argparse
import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import tarfile
import time

import yaml
from host_prepare import BASE as INSTANCES, directory, docker, load, registry_copy, storage, verify_images, write
from host_runtime import Instance, save
from host_restore import pg
from host_verify import client
from runtime_config import OWNER, PG_BIN, validate_site
from runtime_inspect import read

BASE = Path('/data/harbor/backups')
SYSTEM_BASE = Path('/var/backups/sunmoon-harbor')
MUTABLE = ('core-data', 'job-logs', 'redis')


def mutable_paths(instance):
    # Scanner cache and managed job logs live on the same admitted data disk.
    return (*MUTABLE, *(('scanner',) if instance.prep.get('scanner') else ()),
            *(('writer-v1',) if instance.prep.get('writer') else ()))

MANIFEST_LIMIT = 64 * 1024**2


def save_manifest(path, value):
    if len(json.dumps(value, indent=2).encode()) + 1 > MANIFEST_LIMIT:
        raise ValueError('Backup file manifest exceeds the admitted 64 MiB bound')
    save(path, value)


def read_manifest(path):
    info = path.stat()
    if (path.resolve() != path or not stat.S_ISREG(info.st_mode) or info.st_uid != 0
            or info.st_mode & 0o077 or info.st_size > MANIFEST_LIMIT):
        raise ValueError('Unsafe or oversized private backup manifest')
    return json.loads(path.read_bytes())


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def backup_path(path):
    path = path.absolute()
    if (path.resolve() != path or path.parent not in (BASE, SYSTEM_BASE)
            or not re.fullmatch(r'host-[a-z0-9-]{1,60}', path.name)):
        raise ValueError('Backup needs one new explicit host-* directory in an admitted backup root')
    return path


def admit_capacity(config, destination, content_bytes):
    """Read-only admission; account for physical C space, not just WSL ext4 free."""
    destination = backup_path(destination)
    location = destination.parent
    while not location.exists():
        location = location.parent
    if location.resolve() != location:
        raise ValueError('Backup storage path is symlinked')
    required = content_bytes + 22 * 1024**3
    capacity = os.statvfs(location)
    free = capacity.f_bavail * capacity.f_frsize
    if free < required:
        raise ValueError('Complete frozen backup lacks filesystem space; no mode/service change performed')
    result = {'filesystem_free_bytes':free, 'required_filesystem_bytes':required,
              'backup_root':str(destination.parent)}
    if destination.parent == SYSTEM_BASE:
        if config['runtime']['platform'] != 'wsl' or location.stat().st_dev != Path('/').stat().st_dev:
            raise ValueError('System-disk backup adapter is WSL-only and requires the expected root filesystem')
        probe = Path(__file__).resolve().parents[1] / 'operations/space/windows_capacity.py'
        query = subprocess.run([sys.executable, '-B', str(probe)], capture_output=True, timeout=50)
        if query.returncode:
            raise ValueError('Physical Windows free-space read failed; no fallback to virtual free space')
        physical = json.loads(query.stdout.decode('utf-8-sig'))
        if any(type(physical.get(n)) is not int or physical[n] < 0 for n in
               ('CFreeBytes', 'DataVhdAllocatedBytes', 'remaining_data_growth_bytes')):
            raise ValueError('Physical capacity probe schema differs')
        future_growth = physical['remaining_data_growth_bytes']
        after = physical['CFreeBytes'] - future_growth - content_bytes - 2 * 1024**3
        if after < 50 * 1024**3:
            raise ValueError('Backup plus configured full data disk would violate the physical C reserve')
        result.update(physical, projected_c_free_after_backup_and_full_data_disk=after,
                      minimum_physical_c_free=50 * 1024**3)
    return result


def members(root, names):
    selected = set()
    for name in names:
        path = root / name
        if path.resolve() != path or not path.is_relative_to(root):
            raise ValueError('Backup source symlink/path refused')
        selected.add(path)
        if path.is_dir():
            selected.update(path.rglob('*'))
        parent = path.parent
        while parent != root:
            selected.add(parent); parent = parent.parent
    result = []
    for path in sorted(selected):
        info = path.lstat()
        if (path.resolve() != path or info.st_dev != root.stat().st_dev
                or not (stat.S_ISREG(info.st_mode) or stat.S_ISDIR(info.st_mode))):
            raise ValueError('Backup refuses links/special files/nested filesystems')
        result.append((path, info))
    return result


def archive_tree(root, names, target):
    files = {}; total = 0
    selected = members(root, names)
    with tarfile.open(target, 'x', format=tarfile.PAX_FORMAT) as archive:
        for path, before in selected:
            name = str(path.relative_to(root)); info = archive.gettarinfo(str(path), arcname=name)
            # Explicit regular entries avoid tar's automatic hardlink conversion.
            info.uname = ''; info.gname = ''
            if path.is_dir():
                archive.addfile(info)
                continue
            digest = sha(path); info.type = tarfile.REGTYPE; info.linkname = ''; info.size = before.st_size
            with path.open('rb') as stream:
                archive.addfile(info, stream)
            after = path.stat()
            if (before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns):
                raise ValueError('Stopped backup source changed while reading')
            files[name] = {'bytes': after.st_size, 'sha256': digest, 'uid': after.st_uid,
                           'gid': after.st_gid, 'mode': stat.S_IMODE(after.st_mode)}
            total += after.st_size
    with target.open('rb') as stream:
        os.fsync(stream.fileno())
    result = {'sha256': sha(target), 'bytes': target.stat().st_size, 'files': files, 'content_bytes': total}
    verify_tar(target, result)
    return result


def verify_tar(path, record):
    if (path.resolve() != path or path.stat().st_size != record['bytes'] or sha(path) != record['sha256']):
        raise ValueError('Backup archive identity differs')
    found = {}; names = set()
    with tarfile.open(path) as archive:
        for member in archive:
            name = PurePosixPath(member.name)
            if (name.is_absolute() or '..' in name.parts or str(name) in names
                    or not (member.isdir() or member.isfile())):
                raise ValueError('Unsafe or duplicate backup member')
            names.add(str(name))
            if member.isdir():
                continue
            expected = record['files'].get(str(name))
            with archive.extractfile(member) as stream:
                digest = hashlib.file_digest(stream, 'sha256').hexdigest()
            actual = {'bytes': member.size, 'sha256': digest, 'uid': member.uid,
                      'gid': member.gid, 'mode': member.mode}
            if actual != expected:
                raise ValueError('Backup member content/ownership differs')
            if 'blobs' in name.parts and name.name == 'data' and name.parent.name != digest:
                raise ValueError('Registry blob disagrees with its content digest path')
            found[str(name)] = actual
    if found != record['files']:
        raise ValueError('Backup file set differs')


def cold_backup(instance, root, credentials, registry_from=None):
    if instance.mode() != 'read-only' or instance.state.get('mode_transition_open'):
        raise ValueError('Freeze to verified readonly mode before cold backup')
    storage(instance.config, minimum_gib=20)
    instance.immutable()
    if not instance.state.get('read_only_acceptance', {}).get('completed'):
        raise ValueError('Read-only reconciled instance acceptance required')
    if any(v not in ('created', 'exited') for v in instance.check().values()):
        raise ValueError('This adapter requires source initially stopped; no implicit production freeze')
    if root.exists():
        raise ValueError('Existing backup retained; choose a new backup batch')
    for path in (root.parent,):
        if path.resolve() != path:
            raise ValueError('Symlink backup parent refused')
        if not path.exists():
            directory(path)
        if path.stat().st_uid != 0 or path.stat().st_mode & 0o077:
            raise ValueError('Private root-owned backup parent required')
    reused = verify_backup(registry_from) if registry_from is not None else None
    if reused is not None and not reused.get('restore_verified'):
        raise ValueError('Registry reuse requires an independently restored backup')
    backup_names = mutable_paths(instance) if reused is not None else ('registry', *mutable_paths(instance))
    source_bytes = sum(i.st_size for _, i in members(instance.root, backup_names) if stat.S_ISREG(i.st_mode))
    capacity_receipt = admit_capacity(instance.config, root, source_bytes)
    directory(root); directory(root / 'database'); directory(root / 'volumes')
    state = {'schema': 1, 'complete': False, 'source': instance.project,
             'source_runtime': instance.config['runtime'], 'storage_uuid': instance.config['storage_uuid'],
             'harbor_version': '2.13.2', 'database_version': '17.6', 'redis_version': '8.2.1',
             'source_started_stopped_for_catalog': False, 'logical_export_complete': False,
             'capacity_admission': capacity_receipt}
    save_manifest(root / 'backup.json', state)
    try:
        instance.start()
        deadline = time.monotonic() + 180
        while True:
            try:
                c = client(instance, credentials, time.monotonic() + 600)
                settings, _ = c.get('/configurations')
                if settings['read_only']['value'] is not True:
                    raise ValueError('Source must remain read-only')
                break
            except Exception:
                if time.monotonic() >= deadline:
                    raise ValueError('Source catalog readiness deadline') from None
                time.sleep(2)
        catalog = c.collect()
        write(root / 'catalog-before.json', (json.dumps(catalog) + '\n').encode())
    finally:
        instance.stop()
    state['source_started_stopped_for_catalog'] = True; save_manifest(root / 'backup.json', state)
    print('Fresh read-only catalog saved; source stopped, exporting PostgreSQL17.6 only', flush=True)
    database = instance.inspect('postgresql')['Id']
    inventory = pg.Rehearsal(root / 'database', root)
    try:
        docker('start', database); inventory.ready(database)
        before = inventory.inventory(database)
        for tool, arguments, filename in [
            ('pg_dump', ['-Fc', '--create', 'registry'], 'registry.dump'),
            ('pg_dumpall', ['--globals-only'], 'globals.sql')]:
            version = docker('exec', database, PG_BIN + tool, '--version').decode()
            if not re.search(r'\b17\.6\b', version):
                raise ValueError('Logical export tool must be PostgreSQL17.6')
            with (root / 'database' / filename).open('xb') as stream:
                process = subprocess.run(['docker', '--host', 'unix:///var/run/docker.sock', 'exec', database,
                    PG_BIN + tool, '-h', '/tmp', '-U', 'postgres', *arguments], stdout=stream,
                    stderr=subprocess.PIPE, timeout=180)
                stream.flush(); os.fsync(stream.fileno())
            if process.returncode:
                raise ValueError('Database export failed; private diagnostics withheld')
        if inventory.inventory(database) != before:
            raise ValueError('Database changed during isolated logical export')
        write(root / 'database/inventory.json', (json.dumps(before) + '\n').encode())
        write(root / 'database/state.json', b'{"completed":true,"kind":"isolated-logical-export","restore_verified":false}\n')
    finally:
        instance.stop()
    state['logical_export_complete'] = True; save_manifest(root / 'backup.json', state)
    instance.immutable()
    write(root / 'source-host-config.json', read(instance.root / 'host-config.json'))
    write(root / 'source-preparation.json', read(instance.root / 'preparation.json'))
    # Registry tar entries must be relative to the registry root (same restore format).
    registry_root = instance.root / 'registry'
    print('Source fully stopped; copying registry and private runtime, then rereading all archive content', flush=True)
    if reused is None:
        state['registry'] = archive_tree(registry_root, [p.name for p in registry_root.iterdir()], root / 'volumes/registry.tar')
    else:
        # Only immutable, fully revalidated archive bytes may share an inode.
        # The live registry never shares an inode with a backup archive.
        source_archive = registry_from / 'volumes/registry.tar'
        expected = reused['registry']; actual = {}
        for path, info in members(registry_root, [p.name for p in registry_root.iterdir()]):
            if stat.S_ISREG(info.st_mode):
                actual[str(path.relative_to(registry_root))] = {
                    'bytes': info.st_size, 'sha256': sha(path), 'uid': info.st_uid,
                    'gid': info.st_gid, 'mode': stat.S_IMODE(info.st_mode)}
        if actual != expected['files']:
            raise ValueError('Live registry differs; cannot reuse frozen archive')
        if (source_archive.resolve() != source_archive or not source_archive.is_file()
                or source_archive.stat().st_dev != (root / 'volumes').stat().st_dev
                or sha(source_archive) != expected['sha256']):
            raise ValueError('Registry archive identity/filesystem changed')
        os.link(source_archive, root / 'volumes/registry.tar', follow_symlinks=False)
        state['registry'] = copy.deepcopy(expected)
        state['registry_archive_reused_from'] = str(registry_from)
        state['registry_reuse_kind'] = 'Full self-contained immutable tar; hardlink, not live data'

    names = set(instance.prep['immutable_files']) | set(mutable_paths(instance))
    names.update(('config/core/certificates', 'config/shared/trust-certificates'))
    state['runtime'] = archive_tree(instance.root, names, root / 'runtime.tar')
    state['files'] = {str(p.relative_to(root)): {'sha256': sha(p), 'bytes': p.stat().st_size}
                      for p in root.rglob('*') if p.is_file() and p.name != 'backup.json'}
    state.update(complete=True, table_count=len(before['tables']), row_count=sum(t['rows'] for t in before['tables']),
                 catalog_summary=catalog['summary'], images=instance.prep['images'],
                 restore_verified=False, off_machine_copied=False)
    storage(instance.config, minimum_gib=20)
    save_manifest(root / 'backup.json', state)
    return {'complete': True, 'backup': str(root), 'registry_files': len(state['registry']['files']),
            'registry_bytes': state['registry']['content_bytes'], 'tables': state['table_count'],
            'rows': state['row_count'], 'source_stopped': True, 'restore_verified': False}


def verify_backup(root):
    if os.geteuid() != 0 or root.stat().st_uid != 0 or root.stat().st_mode & 0o077:
        raise ValueError('Private root-owned backup required')
    state = read_manifest(root / 'backup.json')
    if state.get('schema') != 1 or state.get('complete') is not True or state.get('database_version') != '17.6':
        raise ValueError('Incomplete or unsupported backup')
    required = {'catalog-before.json', 'source-host-config.json', 'source-preparation.json',
                'database/globals.sql', 'database/registry.dump', 'database/inventory.json',
                'database/state.json', 'volumes/registry.tar', 'runtime.tar'}
    if set(state['files']) != required:
        raise ValueError('Backup receipt must cover exactly all required parts')
    for name, record in state['files'].items():
        path = root / name
        if (not path.is_relative_to(root) or path.resolve() != path or not path.is_file()
                or path.stat().st_uid != 0 or path.stat().st_mode & 0o077
                or path.stat().st_size != record['bytes']):
            raise ValueError('Backup file identity differs')
        archive_record = {'volumes/registry.tar': state['registry'], 'runtime.tar': state['runtime']}.get(name)
        if archive_record is not None:
            if record != {k: archive_record[k] for k in ('sha256', 'bytes')}:
                raise ValueError('Backup archive receipts disagree')
            # verify_tar below checks both whole-tar SHA and every member;
            # do not add a third full read of a large archive here.
        elif sha(path) != record['sha256']:
            raise ValueError('Backup file SHA differs')
    verify_tar(root / 'volumes/registry.tar', state['registry'])
    verify_tar(root / 'runtime.tar', state['runtime'])
    return state


def restore_prepare(root, deployment):
    state = verify_backup(root)
    config = json.loads(read(root / 'source-host-config.json'))
    old_root = Path(config['runtime']['root']); target = INSTANCES / deployment
    config['runtime'].update(deployment=deployment, root=str(target), write_enabled=False)
    validate_site(config['runtime'])
    storage(config, minimum_gib=20)
    verify_images(state['images'])
    if target.exists():
        raise ValueError('Restore requires a new instance directory; never overwrite')
    free = os.statvfs(INSTANCES)
    required = state['registry']['content_bytes'] + state['runtime']['content_bytes'] + 22 * 1024**3
    if free.f_bavail * free.f_frsize < required:
        raise ValueError('Independent restore must retain 20 GiB plus 2 GiB database allowance')
    names = docker('ps', '-a', '--format', '{{.Names}}').decode().splitlines()
    if any(n.startswith(deployment + '-') for n in names):
        raise ValueError('Restoration container name collision')
    directory(target)
    # Extract only fully verified regular files/directories, never tar.extractall.
    with tarfile.open(root / 'runtime.tar') as archive:
        items = archive.getmembers()
        for item in sorted((i for i in items if i.isdir()), key=lambda i: len(PurePosixPath(i.name).parts)):
            path = target / item.name
            directory(path, item.uid, item.mode); os.chown(path, item.uid, item.gid)
        for item in (i for i in items if i.isfile()):
            path = target / item.name
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, item.mode)
            digest = hashlib.sha256()
            with os.fdopen(fd, 'wb') as destination, archive.extractfile(item) as source:
                for block in iter(lambda: source.read(1024**2), b''):
                    destination.write(block); digest.update(block)
                destination.flush(); os.fsync(destination.fileno())
                os.fchown(destination.fileno(), item.uid, item.gid); os.fchmod(destination.fileno(), item.mode)
            if digest.hexdigest() != state['runtime']['files'][item.name]['sha256']:
                raise ValueError('Runtime archive changed while restoring')
    directory(target / 'registry', 10000, 0o750); directory(target / 'database', 1001, 0o750)
    config.update(registry_archive=str(root / 'volumes/registry.tar'), registry_sha256=state['registry']['sha256'],
                  registry_bytes=state['registry']['bytes'], logical_export=str(root / 'database'),
                  logical_sha256={n: state['files']['database/' + n]['sha256'] for n in ('registry.dump', 'globals.sql')})
    # Compose is the admitted original; change only host paths/project identity.
    compose = yaml.safe_load(read(target / 'compose.yaml'))
    compose['name'] = deployment
    for role, service in compose['services'].items():
        service['container_name'] = deployment + '-' + role
        service['labels'][OWNER] = deployment
        for mount in service['volumes']:
            source = Path(mount['source'])
            if not source.is_relative_to(old_root):
                raise ValueError('Backup compose contains a mount outside original instance')
            mount['source'] = str(target / source.relative_to(old_root))
        for entry in service.get('env_file', []):
            source = Path(entry['path'])
            if not source.is_relative_to(old_root):
                raise ValueError('Backup env path outside original instance')
            entry['path'] = str(target / source.relative_to(old_root))
    for key, network in compose['networks'].items():
        network['name'] = deployment + ('-backend' if key == 'harbor' else '-frontend')
        network['labels'][OWNER] = deployment
    # Retain the original bytes from the backup before changing target paths.
    write(target / 'compose-from-backup.yaml', read(target / 'compose.yaml'))
    updated = yaml.safe_dump(compose, sort_keys=False).encode()
    write(target / 'compose-restored.new', updated); os.replace(target / 'compose-restored.new', target / 'compose.yaml')
    write(target / 'host-config-from-backup.json', read(target / 'host-config.json'))
    write(target / 'host-config-restored.new', (json.dumps(config, indent=2) + '\n').encode())
    os.replace(target / 'host-config-restored.new', target / 'host-config.json')
    registry = registry_copy(config, target)
    prep = json.loads(read(root / 'source-preparation.json'))
    prep = copy.deepcopy(prep); prep.update(runtime=config['runtime'], registry=registry,
        database_restored=False, containers_created=False, services_started=False, restored_from=str(root))
    if prep.get('writer'):
        writer_path = target / prep['writer']['compose']
        writer = yaml.safe_load(read(writer_path))
        writer_project = deployment + '-writer-v1'
        writer['name'] = writer_project
        for role, service in writer['services'].items():
            service['container_name'] = writer_project + '-' + role
            service['labels'][OWNER] = deployment
            for mount in service['volumes']:
                source = Path(mount['source'])
                if not source.is_relative_to(old_root):
                    raise ValueError('Writer backup mount outside source instance')
                mount['source'] = str(target / source.relative_to(old_root))
            for entry in service.get('env_file', []):
                source = Path(entry['path'])
                if not source.is_relative_to(old_root):
                    raise ValueError('Writer backup env outside source instance')
                entry['path'] = str(target / source.relative_to(old_root))
        writer['networks']['harbor']['name'] = deployment + '-backend'
        write(writer_path.with_name('compose-from-backup.yaml'), read(writer_path))
        write(writer_path.with_name('compose-restored.new'), yaml.safe_dump(writer, sort_keys=False).encode())
        os.replace(writer_path.with_name('compose-restored.new'), writer_path)
        prep['writer']['project'] = writer_project
        prep['immutable_files'][prep['writer']['compose']] = sha(writer_path)
    prep['immutable_files']['compose.yaml'] = sha(target / 'compose.yaml')
    prep['immutable_files']['host-config.json'] = sha(target / 'host-config.json')
    for name, digest in prep['immutable_files'].items():
        if sha(target / name) != digest:
            raise ValueError('Restored immutable runtime file differs')
    write(target / 'preparation.json', (json.dumps(prep, indent=2) + '\n').encode())
    storage(config, minimum_gib=20)
    return {'prepared': True, 'target_config': str(target / 'host-config.json'), 'registry': registry,
            'database_restored': False, 'services_started': False}


def main():
    os.umask(0o077)
    os.environ['DOCKER_HOST'] = 'unix:///var/run/docker.sock'; os.environ.pop('DOCKER_CONTEXT', None)
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('backup', 'verify', 'restore-prepare', 'record-restore'))
    p.add_argument('--backup', required=True, type=Path); p.add_argument('--config', type=Path)
    p.add_argument('--docker-credentials', type=Path); p.add_argument('--deployment')
    p.add_argument('--registry-from-backup', type=Path, help='Reuse identical immutable registry tar from verified/restored backup')
    p.add_argument('--apply', action='store_true'); args = p.parse_args()
    root = backup_path(args.backup)
    if not args.apply:
        print(json.dumps({'dry_run': True, 'action': args.action, 'backup': str(root),
                          'read_only_stopped_source_only': True, 'delete': False, 'off_machine_copy': False,
                          'registry_from_backup': str(args.registry_from_backup) if args.registry_from_backup else None})); return
    fd = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb+') as lock:
        if os.fstat(lock.fileno()).st_uid != 0 or stat.S_IMODE(os.fstat(lock.fileno()).st_mode) != 0o600:
            raise ValueError('Unsafe lifecycle lock')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.action == 'backup':
            if not args.config or not args.docker_credentials:
                raise ValueError('Explicit source config and private existing credentials required')
            result = cold_backup(Instance(load(args.config.absolute())), root, args.docker_credentials.absolute(),
                                 backup_path(args.registry_from_backup) if args.registry_from_backup else None)
        elif args.action == 'restore-prepare':
            if not args.deployment:
                raise ValueError('Explicit new deployment name required')
            result = restore_prepare(root, args.deployment)
        elif args.action == 'record-restore':
            if not args.config:
                raise ValueError('Explicit restored instance config required')
            record = verify_backup(root); instance = Instance(load(args.config.absolute()))
            if (Path(instance.config['registry_archive']) != root / 'volumes/registry.tar'
                    or Path(instance.config['logical_export']) != root / 'database'
                    or instance.prep.get('restored_from') != str(root)
                    or instance.config['registry_sha256'] != record['registry']['sha256']
                    or instance.config['logical_sha256'] != {
                        name: record['files']['database/' + name]['sha256'] for name in ('registry.dump', 'globals.sql')}
                    or not instance.state.get('database_reconciled')
                    or not instance.state.get('read_only_acceptance', {}).get('completed')
                    or (instance.prep.get('scanner') and not instance.state.get('scanner_acceptance', {}).get('passed'))
                    or (instance.prep.get('writer') and set(instance.state.get('writer_created', {})) != {'registry', 'registryctl', 'core'})
                    or any(v not in ('created', 'exited') for v in instance.check().values())):
                raise ValueError('An independently restored, reconciled, accepted, stopped instance is required')
            record.update(restore_verified=True, restore_instance=instance.project,
                          restore_acceptance=instance.state['read_only_acceptance'])
            if instance.prep.get('scanner'):
                record['restore_scanner_acceptance'] = instance.state['scanner_acceptance']
            if instance.prep.get('writer'):
                record['restore_writer_layout_verified'] = True
                record['restore_writer_push_verified'] = False
            save_manifest(root / 'backup.json', record)
            result = {'restore_verified': True, 'instance': instance.project}
        else:
            record = verify_backup(root)
            result = {'verified': True, 'registry_files': len(record['registry']['files']),
                      'restore_verified': record.get('restore_verified', False)}
        print(json.dumps(result, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Host backup operation stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld; partial files retained')) from None
