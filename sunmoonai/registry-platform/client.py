#!/usr/bin/env python3
"""Host consumers of an independent registry; plans by default, no cluster lookup."""
import argparse
import hashlib
import http.client
import ipaddress
import json
import os
from pathlib import Path
import shutil
import ssl
import stat
import subprocess
import tempfile
from credentials import load_credentials, read_private, validate

MODULE = Path(__file__).resolve().parent
FIELDS = ('REGISTRY_ADDRESS', 'REGISTRY_CLIENT_ADDRESS', 'REGISTRY_CA_FILE',
          'REGISTRY_CA_SHA256', 'REGISTRY_CREDENTIALS_FILE')


def config(profile):
    env = dict(os.environ)
    if profile:
        env['REGISTRY_CONFIG_FILE'] = str(profile)
    if not env.get('REGISTRY_CONFIG_FILE'):
        env['CLUSTER'] = 'KIND'  # Explicit local client profile, not kubectl context.
    command = 'source "$1" >&2; registry_load_config >&2 || exit; printf "%s\\0" '
    command += ' '.join('"${' + name + ':-}"' for name in FIELDS)
    result = subprocess.run(['bash', '-e', '-c', command, 'registry-client',
                             str(MODULE / 'lib/config.sh')], env=env,
                            capture_output=True, check=False, timeout=10)
    # Config is trusted executable shell, but its diagnostics may contain secrets.
    if result.returncode:
        raise ValueError('Registry consumer configuration failed; check the selected profile')
    values = result.stdout.decode().split('\0')
    if len(values) != len(FIELDS) + 1 or values[-1]:
        raise ValueError('Unexpected configuration output')
    data = dict(zip(FIELDS, values[:-1]))
    if data['REGISTRY_ADDRESS'] != 'harbor.sunmoonai.com:30443':
        raise ValueError('Unapproved registry address')
    return data


def checked_ca(data):
    path = Path(data['REGISTRY_CA_FILE'])
    if not path.is_absolute() or not path.is_file() or path.is_symlink():
        raise ValueError('CA must be an existing absolute regular file')
    content = path.read_bytes()
    if hashlib.sha256(content).hexdigest() != data['REGISTRY_CA_SHA256']:
        raise ValueError('CA SHA256 differs from the selected profile')
    context = ssl.create_default_context(cafile=str(path))
    return content, context


def check_registry(data):
    _, context = checked_ca(data)
    host, port = data['REGISTRY_ADDRESS'].split(':')
    # Direct connection: the registry is internal. No HTTP(S)_PROXY is consulted.
    conn = http.client.HTTPSConnection(host, int(port), context=context, timeout=15)
    try:
        conn.request('GET', '/v2/')
        response = conn.getresponse()
        if response.status not in (200, 401):
            raise ValueError(f'Registry /v2/ returned HTTP {response.status}')
        if response.getheader('Docker-Distribution-Api-Version') != 'registry/2.0':
            raise ValueError('Endpoint did not identify itself as Registry v2')
    finally:
        conn.close()


def replace_public_file(path, content):
    """Atomic public-file update; refuse symlink traversal at system destinations."""
    if path.is_symlink() or any(p.is_symlink() for p in path.parents):
        raise ValueError('Refusing a symlink in the destination path')
    path.parent.mkdir(parents=True, exist_ok=True)
    previous = path.stat() if path.exists() else None
    fd, temporary = tempfile.mkstemp(prefix='.sunmoon-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
            os.fchmod(handle.fileno(), stat.S_IMODE(previous.st_mode) if previous else 0o644)
            if previous:
                os.fchown(handle.fileno(), previous.st_uid, previous.st_gid)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def setup_hosts(data):
    address = str(ipaddress.ip_address(data['REGISTRY_CLIENT_ADDRESS']))
    host = data['REGISTRY_ADDRESS'].split(':')[0]
    path = Path('/etc/hosts')
    lines = []
    for line in path.read_text().splitlines():
        body, separator, comment = line.partition('#')
        fields = body.split()
        if len(fields) > 1 and host.lower() in [x.lower() for x in fields[1:]]:
            aliases = [x for x in fields[1:] if x.lower() != host.lower()]
            if aliases:
                lines.append(' '.join([fields[0], *aliases]) + (' #' + comment if separator else ''))
            elif separator:
                lines.append('#' + comment)
        else:
            lines.append(line)
    lines.append(f'{address}\t{host} # SunMoon independent registry')
    replace_public_file(path, ('\n'.join(lines) + '\n').encode())


def setup_trust(data):
    content, _ = checked_ca(data)
    updater = shutil.which('update-ca-certificates')
    if not updater:
        raise ValueError('update-ca-certificates is required before changing trust')
    host = data['REGISTRY_ADDRESS'].split(':')[0]
    # Exact legacy aliases only; never match similarly prefixed registry domains.
    targets = [Path('/etc/docker/certs.d') / name / 'ca.crt'
               for name in (data['REGISTRY_ADDRESS'], host, host + ':443')]
    targets.append(Path('/usr/local/share/ca-certificates/sunmoonai-harbor-ca.crt'))
    for target in targets:
        if target.is_symlink() or any(p.is_symlink() for p in target.parents):
            raise ValueError('Refusing a symlink in a trust destination')
    for target in targets:
        replace_public_file(target, content)
    subprocess.run([updater], check=True)
    print('Trust files installed. Docker was not restarted; Docker pull acceptance remains required.')


def login(data, username, password_file, credentials_file):
    if credentials_file:
        if username or password_file:
            raise ValueError('Do not mix a credential bundle with separate login arguments')
        credential = load_credentials(credentials_file)
        username = credential['username']
        password = credential['password'].encode()
    elif username and password_file:
        password = read_private(password_file).rstrip(b'\r\n')
    else:
        raise ValueError('login --apply requires --username and --password-file')
    if not password or b'\n' in password or b'\r' in password or b'\0' in password:
        raise ValueError('Password file must contain one nonempty line')
    validate({'registry': data['REGISTRY_ADDRESS'], 'username': username,
              'password': password.decode()}, independent=True)
    check_registry(data)
    # Keep credentials out of argv, output and shell interpolation.
    result = subprocess.run(['docker', 'login', data['REGISTRY_ADDRESS'],
                             '--username', username, '--password-stdin'],
                            input=password + b'\n', capture_output=True, check=False, timeout=60)
    if result.returncode:
        raise ValueError('Docker login failed; check endpoint, trust and credentials')
    print('Docker login succeeded for the invoking user.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('hosts', 'trust', 'login', 'check'))
    parser.add_argument('--config', type=Path, help='Trusted independent registry shell profile')
    parser.add_argument('--username')
    parser.add_argument('--password-file', type=Path)
    parser.add_argument('--credentials-file', type=Path,
                        help='Private JSON bundle; otherwise REGISTRY_CREDENTIALS_FILE if set')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    data = config(args.config)
    if not args.apply:
        print(json.dumps({'apply': False, 'action': args.action, 'registry': data['REGISTRY_ADDRESS'],
                          'client_address': data['REGISTRY_CLIENT_ADDRESS'],
                          'ca_file': data['REGISTRY_CA_FILE'], 'ca_sha256': data['REGISTRY_CA_SHA256'],
                          'credentials_file': str(args.credentials_file or data['REGISTRY_CREDENTIALS_FILE']),
                          'effects': {'hosts': 'Update exact hostname in local /etc/hosts',
                                      'trust': 'Install pinned CA in three exact Docker directories and system trust',
                                      'login': 'Direct TLS preflight, then docker login with password stdin',
                                      'check': 'Direct TLS GET /v2/ without credentials'}[args.action],
                          'boundary': 'Local host only; no SSH, cluster API, daemon restart or proxy edits'}, indent=2))
        return
    if args.action in ('hosts', 'trust') and os.geteuid() != 0:
        raise ValueError('hosts/trust --apply must be run by root')
    if args.action == 'hosts':
        setup_hosts(data)
    elif args.action == 'trust':
        setup_trust(data)
    elif args.action == 'login':
        login(data, args.username, args.password_file,
              args.credentials_file or (None if args.username or args.password_file
                                        else data['REGISTRY_CREDENTIALS_FILE']))
    else:
        check_registry(data)
        print('Pinned CA, hostname, direct TLS and Registry v2 response verified.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError, http.client.HTTPException) as exc:
        raise SystemExit(f'Registry client failed: {exc}') from None
