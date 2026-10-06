"""Private account files used by native Ansible tasks; no command-line entry point."""
from pathlib import Path
import os
import stat
import tempfile
import yaml


def require(value, label):
    if not value:
        raise RuntimeError(label)


def checked_path(value):
    path = Path(value)
    require(path.is_absolute() and '..' not in path.parts, 'Invalid private account path')
    require(str(path).startswith(('/etc/sunmoon/', '/mnt/sunmoon-data/backups/')), 'Account path outside private roots')
    for parent in reversed(path.parents):
        if parent.exists():
            s = parent.lstat()
            require(stat.S_ISDIR(s.st_mode) and not stat.S_ISLNK(s.st_mode), 'Redirected private account directory')
            # Linux system directories and the independently mounted data disk are root-owned.
            require(s.st_uid == 0 and s.st_mode & 0o022 == 0, 'Writable or foreign private account ancestor')
    if path.exists() or path.is_symlink():
        s = path.lstat()
        require(stat.S_ISREG(s.st_mode) and s.st_uid == 0 and stat.S_IMODE(s.st_mode) == 0o600, 'Unsafe private account file')
    return path


def read_private(value):
    path = checked_path(value)
    if not path.exists():
        return None
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, 'r', encoding='utf-8') as stream:
        return stream.read()


def extract(text, field):
    if text is None:
        return None
    if not field:
        return text
    value = yaml.safe_load(text)
    for key in field.split('.'):
        require(isinstance(value, dict) and key in value, 'Missing configured credential field')
        value = value[key]
    require(isinstance(value, str), 'Configured credential is not a string')
    return value


def validate_password(password, account):
    require(isinstance(password, str) and account['minimum_length'] <= len(password) <= account['maximum_length'], 'Human password length outside policy')
    require(not any(c in password for c in ('\r', '\n', '\x00')), 'Human password must be one literal value')
    if account.get('table_import'):
        require('|' not in password and '`' not in password, 'Development lookup password cannot contain a table delimiter')
    if account['adapter'] == 'casdoor':
        require(not any(c.isspace() for c in password), 'Casdoor does not permit password whitespace')
    if account['adapter'] == 'elasticsearch':
        require(password == password.strip(), 'Kibana initializer does not preserve edge whitespace')
    return password


def write_private(value, text):
    path = checked_path(value)
    missing = []
    parent = path.parent
    while not parent.exists():
        missing.append(parent);parent = parent.parent
    for directory in reversed(missing):
        directory.mkdir(mode=0o700)
    checked_path(value)
    require(stat.S_IMODE(path.parent.stat().st_mode) == 0o700, 'Private credential parent must be root-only')
    fd, temporary = tempfile.mkstemp(prefix='.account-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
        fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def describe(account):
    current_bytes = read_private(account['current_file'])
    current = extract(current_bytes, account['current_field'])
    backup_bytes = read_private(account['backup_file'])
    preset = read_private(account['initial_file']) if account.get('initial_file') else None
    if preset is not None:
        validate_password(preset, account)
    capability = {'view': True, 'initial_preset': account.get('initial_preset_supported', True),
                  'table_import': account['table_import'], 'protocol_check': account.get('protocol_check_supported', True),
                  'rotation': account.get('rotation_supported', account['adapter'] in ['harbor','casdoor'])}
    return dict(account, capabilities=capability, current_present=current is not None, backup_present=backup_bytes is not None,
                primary_backup_equal=current_bytes == backup_bytes if current_bytes is not None and backup_bytes is not None else None,
                initial_present=preset is not None, rotation_pending=current is not None and preset is not None and current != preset)


def table_password(path, account):
    source = Path(path)
    require(source.is_file() and not source.is_symlink(), 'Password lookup table is missing or redirected')
    rows = [line.split('|') for line in source.read_text().splitlines()
            if line.startswith('|') and len(line.split('|')) == 7 and line.split('|')[1].strip() == str(account['table_row'])]
    require(len(rows) == 1, 'Password table row is missing or duplicated')
    row = rows[0]
    username = row[3].strip().strip('`')
    require(username == account['username'].split('/')[-1], 'Password table account name does not match the approved mapping')
    cell = row[5].strip() or row[4].strip()
    require(cell.startswith('`') and cell.endswith('`') and '`' not in cell[1:-1], 'Use one backtick-delimited password in the selected table cell')
    return validate_password(cell[1:-1], account)


def import_table(path, accounts, replace=False):
    # Prepare every candidate and verify all destinations before the first write.
    candidates = []
    for account in accounts:
        if not account['table_import']:
            continue
        password = table_password(path, account)
        old = read_private(account['initial_file'])
        backup = read_private(account['initial_backup_file'])
        require(old is None or old == password or replace, 'Existing preset differs; an explicit preset replacement is required')
        require(backup is None or backup == old or backup == password or replace, 'Independent preset backup differs')
        candidates.append((account, password, old, backup))
    require(bool(candidates), 'No table-import account is selected')
    applied = []
    try:
        for account, password, old, backup in candidates:
            for key, prior in [('initial_file', old), ('initial_backup_file', backup)]:
                if prior != password:
                    write_private(account[key], password)
                    applied.append((account[key], prior))
    except Exception:
        for value, prior in reversed(applied):
            if prior is None:
                checked_path(value).unlink()
            else:
                write_private(value, prior)
        raise
    return [dict(object=a['object'], username=a['username'], table_row=a['table_row'], preset_changed=old != password,
                 live_account_changed=False) for a, password, old, backup in candidates]


def sync_table(path, account):
    """Owner-authorized development lookup only; caller has verified server state."""
    source = Path(path)
    require(source.is_file() and not source.is_symlink() and source.name == '密码修改表.md', 'Unexpected development lookup file')
    password = validate_password(extract(read_private(account['current_file']), account['current_field']), account)
    target = read_private(account['initial_file'])
    require('|' not in password and '`' not in password, 'Lookup table cannot represent this password literally; use private view')
    lines = source.read_text().splitlines(keepends=True)
    matches = [i for i,line in enumerate(lines) if line.startswith('|') and len(line.split('|')) == 7 and line.split('|')[1].strip() == str(account['table_row'])]
    require(len(matches) == 1,'Lookup row is absent or duplicated')
    i = matches[0]; columns=lines[i].rstrip('\n').split('|')
    require(columns[3].strip().strip('`') == account['username'].split('/')[-1], 'Lookup account identity differs')
    columns[4] = ' `'+password+'` '
    columns[5] = ' `'+target+'` ' if target is not None and target != password else ' '
    lines[i] = '|'.join(columns)+'\n'
    info = source.stat()
    fd, temporary = tempfile.mkstemp(prefix='.account-lookup-', dir=source.parent)
    try:
        with os.fdopen(fd,'w') as stream:
            stream.write(''.join(lines));stream.flush();os.fsync(stream.fileno())
        os.chmod(temporary,stat.S_IMODE(info.st_mode));os.chown(temporary,info.st_uid,info.st_gid)
        os.replace(temporary,source)
    finally:
        if os.path.exists(temporary):os.unlink(temporary)
    return {'object':account['object'],'table_row':account['table_row'],'actual_password_synchronized':True}


def restore_preset(account):
    """Restore a supplied first-install preset, never invent or overwrite one."""
    current = read_private(account['initial_file'])
    backup = read_private(account['initial_backup_file'])
    restored = current is None and backup is not None
    copied = current is not None and backup is None
    require(current is None or backup is None or current == backup, 'Initial preset and independent backup differ')
    if current is None and backup is not None:
        validate_password(backup, account)
        write_private(account['initial_file'], backup)
        current = backup
    if current is not None:
        validate_password(current, account)
        if backup is None:
            write_private(account['initial_backup_file'], current)
    return {'password':current or '', 'changed':restored or copied}
