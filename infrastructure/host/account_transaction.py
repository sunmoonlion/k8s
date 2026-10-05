"""Recoverable account/file transaction for native Ansible; no CLI or lifecycle."""
import contextlib
import fcntl
import json
import os
from account_files import checked_path, extract, read_private, require, validate_password, write_private
import yaml


@contextlib.contextmanager
def locked(account):
    path = checked_path(str(checked_path(account['current_file']).parent / '.account.lock'))
    fd = os.open(path, os.O_CREAT | os.O_NOFOLLOW | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield
    finally:
        os.close(fd)


def receipt_path(account, operation):
    require(operation and all(c.isalnum() or c in '-_' for c in operation) and len(operation) <= 80,
            'Invalid account operation identity')
    return str(checked_path(account['backup_file']).parent / 'rotations' / operation / (account['adapter'] + '.json'))


def load(account, operation):
    text = read_private(receipt_path(account, operation))
    require(text is not None, 'Rotation receipt missing; no remote change is permitted')
    record = json.loads(text)
    require(record['account'] == account, 'Rotation receipt belongs to another account or configuration')
    return record


def save(record, operation):
    write_private(receipt_path(record['account'], operation), json.dumps(record))


def password_text(original, field, password):
    if not field:
        return password
    document = yaml.safe_load(original)
    value = document
    keys = field.split('.')
    for key in keys[:-1]:
        value = value[key]
    value[keys[-1]] = password
    return yaml.safe_dump(document, sort_keys=False, allow_unicode=True)


def prepare(protocol, settings, account, operation):
    with locked(account):
        require(read_private(receipt_path(account, operation)) is None, 'Operation already exists; use its receipt to resume or recover')
        current = read_private(account['current_file'])
        require(current is not None, 'Restore current credentials before rotating')
        old = validate_password(extract(current, account['current_field']), account)
        target = read_private(account['initial_file'])
        require(target is not None, 'An explicit private target preset is required for rotation')
        new = validate_password(target, account)
        require(read_private(account['initial_backup_file']) == new, 'Target preset backup differs')
        require(old != new, 'Target already matches the current password; use account-check')
        require(protocol.inspect(settings, old) is not None, 'Existing credential rejected before rotation')
        backup = read_private(account['backup_file'])
        require(backup is None or backup == current, 'Existing independent credential backup differs')
        if backup is None:
            write_private(account['backup_file'], current)
        record = dict(account=account, old=old, new=new, current=current, backup=current,
                      desired=password_text(current, account['current_field'], new), state='prepared')
        save(record, operation)
        return {'prepared': True, 'receipt': receipt_path(account, operation), 'object': account['object']}


def apply(protocol, settings, account, operation):
    with locked(account):
        r = load(account, operation)
        require(r['state'] == 'prepared', 'Receipt is not prepared; inspect or roll back this operation')
        require(read_private(account['current_file']) == r['current'] and read_private(account['backup_file']) == r['backup'],
                'Private credentials changed after preparation')
        require(protocol.inspect(settings, r['old']) is not None, 'Old identity no longer authenticates')
        r['state'] = 'api-write-started'; save(r, operation)
        try:
            protocol.change(settings, r['old'], r['new'])
        except Exception:
            # A lost response does not authorize a second write. Read the account first.
            if protocol.inspect(settings, r['new']) is None:
                raise RuntimeError('Password write outcome needs recovery; inspect the private receipt') from None
        require(protocol.inspect(settings, r['new']) is not None, 'New credential does not authenticate')
        require(protocol.inspect(settings, r['old']) is None, 'Old credential was not rejected')
        r['state'] = 'api-verified'; save(r, operation)
        write_private(account['current_file'], r['desired'])
        write_private(account['backup_file'], r['desired'])
        r['state'] = 'files-updated'; save(r, operation)
        return {'object': account['object'], 'new_login_verified': True, 'old_login_rejected': True, 'private_backup_equal': True}


def rollback(protocol, settings, account, operation):
    with locked(account):
        r = load(account, operation)
        old_identity = protocol.inspect(settings, r['old'])
        if old_identity is None:
            require(protocol.inspect(settings, r['new']) is not None, 'Neither known credential works; preserve receipt for manual recovery')
            try:
                protocol.change(settings, r['new'], r['old'])
            except Exception:
                require(protocol.inspect(settings, r['old']) is not None, 'Rollback API outcome is unresolved; preserve receipt')
        require(protocol.inspect(settings, r['old']) is not None, 'Rollback identity did not authenticate')
        require(protocol.inspect(settings, r['new']) is None, 'Target credential still authenticates after rollback')
        write_private(account['current_file'], r['current'])
        write_private(account['backup_file'], r['backup'])
        r['state'] = 'rolled-back'; save(r, operation)
        return {'object': account['object'], 'rolled_back': True, 'old_login_verified': True}


def finalize(protocol, settings, account, operation):
    with locked(account):
        r = load(account, operation)
        require(r['state'] == 'files-updated', 'Runtime synchronization is not pending for this receipt')
        require(read_private(account['current_file']) == r['desired'] and read_private(account['backup_file']) == r['desired'],
                'Current and backup do not match the verified new password')
        require(protocol.inspect(settings, r['new']) is not None and protocol.inspect(settings, r['old']) is None,
                'Final account authentication differs')
        r['state'] = 'complete'; save(r, operation)
        return {'object': account['object'], 'rotation_complete': True, 'receipt': receipt_path(account, operation)}
