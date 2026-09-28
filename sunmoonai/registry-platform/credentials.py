#!/usr/bin/env python3
"""Private registry credentials shared by host login and pull-secret generators.

docker-config is an internal encoder: its stdout contains a secret, never log it.
Cloud orchestration remains 未经实机验证. This module performs no network calls.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import stat

REGISTRY = 'harbor.sunmoonai.com:30443'


def read_private(path):
    path = Path(path)
    if not path.is_absolute():
        raise ValueError('Credentials require an absolute private file path')
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as handle:
        info = os.fstat(handle.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid()
                or stat.S_IMODE(info.st_mode) & 0o077 or info.st_size > 65536):
            raise ValueError('Credentials must be caller-owned, owner-only and at most 64 KiB')
        data = handle.read(65537)
        if len(data) > 65536:
            raise ValueError('Credentials exceed the size limit')
        return data


def validate(data, *, independent=False):
    if not isinstance(data, dict) or set(data) - {'registry', 'username', 'password', 'email'}:
        raise ValueError('Invalid credential fields')
    for key in ('registry', 'username', 'password'):
        value = data.get(key)
        if (not isinstance(value, str) or not value or any(c in value for c in '\r\n\0')
                or value == 'TODO_FILL_IN_HARBOR_PASSWORD'):
            raise ValueError(f'Invalid credential field: {key}')
    if ':' in data['username'] or data['username'].startswith('-'):
        raise ValueError('Invalid credential username')
    if independent and data['registry'] != REGISTRY:
        raise ValueError('Private credentials must target the approved independent registry')
    if 'email' in data and not isinstance(data['email'], str):
        raise ValueError('Invalid email field')
    return data


def load_credentials(path):
    try:
        data = json.loads(read_private(path))
    except (json.JSONDecodeError, UnicodeError):
        raise ValueError('Private credentials are not valid JSON') from None
    return validate(data, independent=True)


def docker_config(data):
    entry = {'username': data['username'], 'password': data['password'],
             'auth': base64.b64encode((data['username'] + ':' + data['password']).encode()).decode()}
    if data.get('email'):
        entry['email'] = data['email']
    return json.dumps({'auths': {data['registry']: entry}}, ensure_ascii=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('check', 'docker-config'))
    parser.add_argument('--file', type=Path)
    parser.add_argument('--base64', action='store_true')
    args = parser.parse_args()
    path = args.file or os.environ.get('REGISTRY_CREDENTIALS_FILE')
    if path:
        data = load_credentials(path)
    elif args.action == 'docker-config':
        # Compatibility input is explicit only. Never source deployment configs.
        data = validate({key: os.environ.get('SUNMOON_AUTH_' + key.upper(), '')
                         for key in ('registry', 'username', 'password', 'email')})
    else:
        parser.error('check requires --file or REGISTRY_CREDENTIALS_FILE')
    if args.action == 'check':
        print('Private registry credentials: format, target, owner and permissions passed; login not checked.')
    else:
        encoded = docker_config(data).encode()
        print(base64.b64encode(encoded).decode() if args.base64 else encoded.decode())


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit(f'Registry credentials failed: {exc}') from None
