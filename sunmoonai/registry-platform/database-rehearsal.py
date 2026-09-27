#!/usr/bin/env python3
"""Local cold-backup PostgreSQL logical restore rehearsal; default is plan only.

No cloud execution, Harbor startup, source cluster access, network, ports, or deletion.
Requires explicit --apply as root for an owner-approved run. Stops only containers
created by this run and retains them and all data for final approved cleanup.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import time

IMAGE = 'bitnami/postgresql@sha256:dbd371582fbbb100b22b891e485f4559187362348c1d4b5d0a2191134807516b'
UUID = 'a28de356-4ba1-4a21-93f5-744b9b9d8be0'
BACKUP_SHA = 'd6eaee7507f5393613fe253298813c24627ff248162237d1c02b76847f1ae59d'
BACKUP_BYTES = 195020800
BASE = Path('/data/harbor/rehearsals')
GUARD = '/opt/sunmoon/admin/storage/storage-20260927-v2/check-storage-mounts.sh'
LABEL = 'sunmoonai.registry.pg-rehearsal'
PG = '/opt/bitnami/postgresql/bin/'
DEADLINE = None


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def run(command, *, timeout=30, stdin=None, output=None):
    # Errors never echo SQL, credentials, or database output to the terminal.
    if DEADLINE is not None:
        timeout = min(timeout, DEADLINE-time.monotonic())
        if timeout <= 0:
            raise RuntimeError('Rehearsal reached the 15 minute deadline')
    if output:
        with output.open('xb') as stream:
            p = subprocess.run(command, input=stdin, stdout=stream, stderr=subprocess.PIPE, timeout=timeout)
    else:
        p = subprocess.run(command, input=stdin, capture_output=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError(f'Command failed with exit {p.returncode}: {command[0]} (details withheld)')
    return p.stdout.decode() if not output else ''


def save(path, value):
    temporary = path.with_suffix('.new')
    with temporary.open('w') as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def validate_run_dir(path):
    if path.parent != BASE or not re.fullmatch(r'pg17-[0-9]{8}T[0-9]{6}Z', path.name):
        raise RuntimeError('Run directory must be /data/harbor/rehearsals/pg17-YYYYMMDDTHHMMSSZ')
    if path.resolve() != path:
        raise RuntimeError('Symlink run path refused')


def storage_guard():
    return json.loads(run(['bash', GUARD, '--layout', 'sunmoon-data', '--expected-uuid', UUID,
                          '--min-free-gib', '20', '--require-service-visibility']))


def inspect_image():
    image = json.loads(run(['docker', 'image', 'inspect', IMAGE]))[0]
    if image.get('Architecture') != 'amd64' or image.get('Os') != 'linux' or IMAGE not in image.get('RepoDigests', []):
        raise RuntimeError('Cached source image digest/platform mismatch; never pull automatically')
    volumes = set(image.get('Config', {}).get('Volumes', {}))
    if volumes != {'/bitnami/postgresql', '/docker-entrypoint-initdb.d', '/docker-entrypoint-preinitdb.d'}:
        raise RuntimeError('Image volume declarations changed; refuse unexpected anonymous volumes')
    if 'NSS_WRAPPER_LIB=/opt/bitnami/common/lib/libnss_wrapper.so' not in image.get('Config', {}).get('Env', []):
        raise RuntimeError('Expected Bitnami NSS wrapper is not declared')
    return {'reference': IMAGE, 'id': image['Id'], 'platform': 'linux/amd64'}


def validate_archive(archive):
    if archive.is_symlink() or archive.stat().st_size != BACKUP_BYTES or sha(archive) != BACKUP_SHA:
        raise RuntimeError('Frozen database archive differs from approved cold backup')
    names = set()
    with tarfile.open(archive) as tar:
        for member in tar:
            parts = PurePosixPath(member.name).parts
            if PurePosixPath(member.name).is_absolute() or '..' in parts or not (member.isfile() or member.isdir()):
                raise RuntimeError('Unsupported or unsafe database archive member')
            name = str(PurePosixPath(member.name))
            if name in names:
                raise RuntimeError('Duplicate archive member')
            names.add(name)
        if tar.extractfile('./data/PG_VERSION').read().strip() != b'17':
            raise RuntimeError('Cold backup is not PostgreSQL 17')


def extract_archive(archive, target):
    # A fresh private destination; no symlinks/hardlinks/devices accepted.
    with tarfile.open(archive) as tar:
        for member in tar:
            out = target / PurePosixPath(member.name)
            if member.isdir():
                out.mkdir(parents=True, exist_ok=True, mode=0o700)
            else:
                out.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                with tar.extractfile(member) as src, out.open('xb') as dst:
                    for block in iter(lambda: src.read(1024**2), b''):
                        dst.write(block)
            os.chown(out, 1001, 1001)
            os.chmod(out, 0o700 if member.isdir() else 0o600)


class Rehearsal:
    def __init__(self, root, backup):
        self.root, self.backup = root, backup
        self.state = {'schema': 1, 'run': root.name, 'created': [], 'completed': False,
                      'started_at': dt.datetime.now(dt.timezone.utc).isoformat(), 'phase': 'preflight'}

    def persist(self, phase):
        self.state['phase'] = phase
        save(self.root / 'state.json', self.state)

    def create(self, role, directory, entrypoint, arguments):
        name = 'sunmoon-' + self.root.name + '-' + role
        # Persist intent before create; interruption can then recover by exact name + label.
        entry = {'name': name, 'id': None, 'stopped': False}
        self.state['created'].append(entry)
        self.persist('creating-' + role)
        command = ['docker', 'create', '--name', name, '--label', LABEL+'='+self.root.name,
                   '--pull=never', '--network=none', '--restart=no', '--read-only', '--user', '1001:1001',
                   '--env', 'LD_PRELOAD=/opt/bitnami/common/lib/libnss_wrapper.so',
                   '--env', 'NSS_WRAPPER_PASSWD=/rehearsal-config/passwd',
                   '--env', 'NSS_WRAPPER_GROUP=/rehearsal-config/group',
                   '--cap-drop=ALL', '--security-opt=no-new-privileges', '--memory=1g', '--cpus=2', '--pids-limit=128',
                   '--log-driver=none', '--stop-timeout=20', '--shm-size=128m',
                   '--tmpfs', '/tmp:rw,nosuid,nodev,noexec,size=128m,mode=1777',
                   '--mount', 'type=bind,src='+str(directory)+',dst=/bitnami/postgresql',
                   '--mount', 'type=bind,src='+str(self.root/'config')+',dst=/rehearsal-config,readonly',
                   '--mount', 'type=bind,src='+str(self.root/'config')+',dst=/docker-entrypoint-initdb.d,readonly',
                   '--mount', 'type=bind,src='+str(self.root/'config')+',dst=/docker-entrypoint-preinitdb.d,readonly',
                   '--entrypoint', PG+entrypoint, IMAGE, *arguments]
        entry['id'] = run(command).strip()
        self.persist('created-' + role)
        spec = json.loads(run(['docker', 'inspect', entry['id']]))[0]
        if any(m['Type'] == 'volume' for m in spec['Mounts']) or spec['HostConfig']['NetworkMode'] != 'none' or spec['HostConfig'].get('PortBindings'):
            raise RuntimeError('Created container isolation differs; do not start')
        run(['docker', 'start', entry['id']])
        return entry['id']

    def psql(self, container, sql, database='registry'):
        return run(['docker', 'exec', '-i', container, PG+'psql', '-X', '-v', 'ON_ERROR_STOP=1',
                    '-h', '/tmp', '-U', 'postgres', '-d', database, '-At'], stdin=sql.encode(), timeout=120).strip()

    def ready(self, container):
        deadline = time.monotonic()+90
        while time.monotonic() < deadline:
            try:
                self.psql(container, 'SELECT 1;', 'postgres')
                return
            except RuntimeError:
                if run(['docker', 'inspect', '--format', '{{.State.Running}}', container]).strip() != 'true':
                    raise RuntimeError('New database container stopped before readiness') from None
                time.sleep(2)
        raise RuntimeError('Database readiness deadline exceeded')

    def inventory(self, container):
        version = self.psql(container, 'SHOW server_version_num;')
        if version != '170006':
            raise RuntimeError('Expected PostgreSQL 17.6 at runtime')
        tables = json.loads(self.psql(container, "SELECT coalesce(json_agg(x ORDER BY schemaname,tablename),'[]') FROM (SELECT schemaname,tablename,tableowner FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) x;"))
        def quote(value):
            return '"'+value.replace('"', '""')+'"'
        result = {'server_version_num': version, 'tables': []}
        for item in tables:
            table = quote(item['schemaname'])+'.'+quote(item['tablename'])
            # Canonical ordered rows are hashed in memory; no row content in evidence.
            cmd = ['docker', 'exec', '-i', container, PG+'psql', '-X', '-v', 'ON_ERROR_STOP=1', '-h', '/tmp', '-U', 'postgres', '-d', 'registry', '-At']
            sql = f'SET timezone=\'UTC\';\nCOPY (SELECT row_to_json(t)::text FROM {table} t ORDER BY row_to_json(t)::text COLLATE "C") TO STDOUT;'
            value = run(cmd, stdin=sql.encode(), timeout=120)
            count = int(self.psql(container, 'SELECT count(*) FROM '+table+';'))
            result['tables'].append({**item, 'rows': count, 'row_sha256': hashlib.sha256(value.encode()).hexdigest()})
        result['sequences'] = self.psql(container, "SELECT coalesce(json_agg(x ORDER BY schemaname,sequencename),'[]') FROM (SELECT schemaname,sequencename,sequenceowner,data_type,start_value,min_value,max_value,increment_by,cycle,cache_size,last_value FROM pg_sequences WHERE schemaname NOT IN ('pg_catalog','information_schema')) x;")
        result['extensions'] = self.psql(container, "SELECT coalesce(json_agg(x ORDER BY extname),'[]') FROM (SELECT extname,extversion FROM pg_extension) x;")
        result['sequence_states'] = []
        for sequence in json.loads(result['sequences']):
            name = quote(sequence['schemaname'])+'.'+quote(sequence['sequencename'])
            result['sequence_states'].append({'name': name, 'state': self.psql(container, 'SELECT last_value,is_called FROM '+name+';')})
        for key, sql in {
            'roles_sha256': "SELECT coalesce(json_agg(x ORDER BY rolname),'[]') FROM (SELECT rolname,rolsuper,rolinherit,rolcreaterole,rolcreatedb,rolcanlogin,rolreplication,rolconnlimit,rolpassword,rolvaliduntil,rolbypassrls FROM pg_authid WHERE rolname !~ '^pg_') x;",
            'database_metadata_sha256': "SELECT row_to_json(x) FROM (SELECT datname,pg_get_userbyid(datdba) AS owner,encoding,datcollate,datctype,datacl FROM pg_database WHERE datname='registry') x;",
            'large_objects_sha256': "SELECT coalesce(json_agg(x ORDER BY loid,pageno),'[]') FROM (SELECT loid,pageno,encode(data,'hex') AS data FROM pg_largeobject) x;",
        }.items():
            result[key] = hashlib.sha256(self.psql(container, sql).encode()).hexdigest()
        schema = run(['docker', 'exec', container, PG+'pg_dump', '-h', '/tmp', '-U', 'postgres', '--schema-only', 'registry'], timeout=120)
        # PostgreSQL 17.6 injects random psql restrict tokens, not schema content.
        schema = '\n'.join(line for line in schema.splitlines() if not line.startswith(('\\restrict ', '\\unrestrict ')))
        result['schema_sha256'] = hashlib.sha256(schema.encode()).hexdigest()
        return result

    def execute(self):
        global DEADLINE
        archive = self.backup/'volumes/database.tar'
        self.state['storage'] = storage_guard()
        self.state['image'] = inspect_image()
        validate_archive(archive)
        if self.root.exists():
            raise RuntimeError('Run already exists; use stop recovery, never overwrite data')
        # Refuse name collisions before recording ownership of any containers.
        existing = set(run(['docker', 'ps', '-a', '--format', '{{.Names}}']).splitlines())
        for role in ['source', 'init', 'target']:
            if 'sunmoon-'+self.root.name+'-'+role in existing:
                raise RuntimeError('Container name already exists')
        self.root.mkdir(parents=True, mode=0o700)
        self.persist('preparing-independent-directories')
        for name in ['source', 'target', 'config']:
            path = self.root/name
            path.mkdir(mode=0o700)
            os.chown(path, 1001, 1001)
        self.root.joinpath('config/postgresql.conf').write_text("listen_addresses = ''\nunix_socket_directories = '/tmp'\nhba_file = '/rehearsal-config/pg_hba.conf'\nident_file = '/rehearsal-config/pg_ident.conf'\nshared_preload_libraries = 'pgaudit'\nlogging_collector = off\nmax_connections = 30\n")
        self.root.joinpath('config/pg_hba.conf').write_text('local all postgres trust\n')
        self.root.joinpath('config/pg_ident.conf').write_text('')
        # The image has no passwd entry for UID 1001; reproduce its NSS mapping
        # explicitly while bypassing the entrypoint and keeping rootfs read-only.
        self.root.joinpath('config/passwd').write_text('postgres:x:1001:1001:PostgreSQL:/tmp:/bin/false\n')
        self.root.joinpath('config/group').write_text('postgres:x:1001:\n')
        for path in (self.root/'config').iterdir():
            os.chown(path, 1001, 1001)
            os.chmod(path, 0o400)
        extract_archive(archive, self.root/'source')
        DEADLINE = time.monotonic()+15*60
        try:
            source = self.create('source', self.root/'source', 'postgres', ['-D', '/bitnami/postgresql/data', '-c', 'config_file=/rehearsal-config/postgresql.conf'])
            self.ready(source)
            versions = {name: run(['docker', 'exec', source, PG+name, '--version']).strip()
                        for name in ['pg_dump', 'pg_dumpall', 'pg_restore']}
            if any(not re.search(r'\b17\.6\b', value) for value in versions.values()):
                raise RuntimeError('Logical export/restore tools must also be PostgreSQL 17.6')
            self.state['tool_versions'] = versions
            before = self.inventory(source)
            self.persist('source-ready-and-inventoried')
            dump = self.root/'registry.dump'
            run(['docker', 'exec', source, PG+'pg_dump', '-h', '/tmp', '-U', 'postgres', '-Fc', '--create', 'registry'], output=dump, timeout=180)
            globals_file = self.root/'globals.sql'
            run(['docker', 'exec', source, PG+'pg_dumpall', '-h', '/tmp', '-U', 'postgres', '--globals-only'], output=globals_file, timeout=60)
            self.persist('logical-exports-complete')
            init = self.create('init', self.root/'target', 'initdb', ['-D', '/bitnami/postgresql/data', '-U', 'postgres', '--auth-local=trust', '--auth-host=reject', '--locale=C', '--encoding=UTF8'])
            if run(['docker', 'wait', init], timeout=90).strip() != '0':
                raise RuntimeError('Empty target database initialization failed')
            target = self.create('target', self.root/'target', 'postgres', ['-D', '/bitnami/postgresql/data', '-c', 'config_file=/rehearsal-config/postgresql.conf'])
            self.ready(target)
            # initdb already creates postgres. Preserve ALTER ROLE/privileges/password hashes.
            globals_sql = globals_file.read_text().replace('CREATE ROLE postgres;\n', '')
            self.psql(target, globals_sql, 'postgres')
            with dump.open('rb') as stream:
                remaining = min(180, DEADLINE-time.monotonic())
                if remaining <= 0:
                    raise RuntimeError('Rehearsal deadline exceeded before restore')
                p = subprocess.run(['docker', 'exec', '-i', target, PG+'pg_restore', '--exit-on-error', '--create', '-h', '/tmp', '-U', 'postgres', '-d', 'postgres'], stdin=stream, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=remaining)
            if p.returncode:
                raise RuntimeError('Logical restore failed; output withheld, private inputs retained')
            self.persist('logical-restore-complete')
            after = self.inventory(target)
            if before != after:
                raise RuntimeError('Database table/row/sequence/extension reconciliation failed')
            save(self.root/'inventory.json', before)
            self.state.update({'completed': True, 'table_count': len(before['tables']),
                               'row_count': sum(t['rows'] for t in before['tables']),
                               'dump_sha256': sha(dump), 'globals_sha256': sha(globals_file),
                               'reconciled': ['table names and owners', 'row counts', 'ordered row SHA256', 'sequences and is_called', 'extensions', 'schema', 'roles and password hashes', 'database metadata', 'large objects'],
                               'harbor_application_verified': False})
            self.persist('database-reconciled')
        finally:
            DEADLINE = None  # Recovery must still run after the execution deadline.
            stop_owned(self.root, self.state)


def stop_owned(root, state):
    errors = []
    for entry in reversed(state['created']):
        ref = entry['id'] or entry['name']
        try:
            p = subprocess.run(['docker', 'inspect', ref], capture_output=True, text=True, timeout=30)
            if p.returncode:
                raise RuntimeError('Container identity unavailable; manual review required')
            actual = json.loads(p.stdout)[0]
            if actual['Name'].lstrip('/') != entry['name'] or actual['Config'].get('Labels', {}).get(LABEL) != root.name:
                raise RuntimeError('Container ownership mismatch')
            if actual['State']['Running']:
                run(['docker', 'stop', '--time', '20', actual['Id']], timeout=30)
            stopped = json.loads(run(['docker', 'inspect', actual['Id']]))[0]
            entry['stopped'] = not stopped['State']['Running']
        except (RuntimeError, OSError, subprocess.SubprocessError):
            errors.append(entry['name'])
    state['stop_errors'] = errors
    save(root/'state.json', state)
    if errors:
        raise RuntimeError('Some new rehearsal containers could not be stopped; consult private state.json')


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['check', 'run', 'stop'])
    parser.add_argument('--backup', type=Path, required=True)
    parser.add_argument('--run-dir', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    validate_run_dir(args.run_dir)
    if args.backup.resolve() != args.backup:
        raise RuntimeError('Backup must be an absolute nonsymlink path')
    if args.action == 'check':
        result = {'read_only': True, 'storage': storage_guard(), 'image': inspect_image()}
        validate_archive(args.backup/'volumes/database.tar')
        result.update({'archive_verified': True, 'archive_bytes': BACKUP_BYTES,
                       'archive_sha256': BACKUP_SHA, 'pgdata_major': '17'})
        print(json.dumps(result, indent=2))
        return
    plan = {'dry_run': not args.apply, 'action': args.action, 'run_dir': str(args.run_dir),
            'backup': str(args.backup), 'image': IMAGE, 'archive_sha256': BACKUP_SHA,
            'containers': 3, 'network': 'none', 'published_ports': [], 'delete': False,
            'source_cluster_contact': False, 'cloud_status': '未经实机验证；本入口仅本地冷备份数据库演练'}
    if not args.apply:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return
    if os.geteuid() != 0:
        raise RuntimeError('Explicit owner-approved apply requires root')
    if args.action == 'stop':
        # Recovery only stops owned containers; does not require data filesystem free space.
        mounted = json.loads(run(['findmnt', '--json', '--mountpoint', '/data/harbor', '--output', 'UUID,FSTYPE']))['filesystems']
        if len(mounted) != 1 or mounted[0].get('uuid') != UUID or mounted[0]['fstype'] != 'ext4':
            raise RuntimeError('Recovery state must reside on the expected data filesystem')
        state = json.loads((args.run_dir/'state.json').read_text())
        if state['run'] != args.run_dir.name:
            raise RuntimeError('State identity mismatch')
        stop_owned(args.run_dir, state)
    else:
        task = Rehearsal(args.run_dir, args.backup)
        task.execute()
        print(json.dumps({'completed': task.state['completed'], 'run_dir': str(args.run_dir),
                          'table_count': task.state['table_count'], 'row_count': task.state['row_count'],
                          'containers_stopped': all(c['stopped'] for c in task.state['created']),
                          'harbor_application_verified': False}))


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        raise SystemExit('[database-rehearsal] FAIL: '+str(exc)) from None
