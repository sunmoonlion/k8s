"""Cluster-side external Harbor consumption. Cloud 未经实机验证。

No Harbor lifecycle, login, private keys, registry uploads or service restart.
Checks never repair trust, hosts, images or services; the caller records audit logs.
Apply adds missing exact trust/hosts/image content.
"""
import base64
import fcntl
import hashlib
import http.client
import ipaddress
import json
import os
from pathlib import Path
import re
import socket
import ssl
import stat
import subprocess

from bundle import below, read_lock
from image_import import inspect_archive, import_items, references, ctr
from os_install import exact_file

DOMAIN = 'harbor.sunmoonai.com'
ADDRESS = DOMAIN + ':30443'
DIRECTORY = Path('/etc/containerd/certs.d') / ADDRESS


def image_records(manifest, data):
    child = data['ingress_image_lock']
    lock = read_lock(below(manifest.parent, child['path']), child['sha256'])
    result = lock['images']
    if (lock.get('complete') is not True or lock.get('platform') != 'linux/amd64' or len(result) != 1
            or result[0]['name'] != 'traefik' or result[0]['version'] != 'v3.5.2'):
        raise ValueError('Expected the existing Traefik v3.5.2 offline image only')
    return result


def profile_from_environment(nodes, connections, apply=False):
    get = lambda key: os.environ.get('SM_REGISTRY_' + key, '')
    profile = {'address': get('ADDRESS'), 'version': get('VERSION'), 'transport': get('TRANSPORT'),
               'ip': get('IP'), 'machine_id': get('MACHINE_ID'), 'ssh_host': get('SSH_HOST'),
               'ca_sha256': get('CA_SHA256'), 'sni_proxy': get('SNI_PROXY')}
    if profile['address'] != ADDRESS or profile['version'] != '2.13.2' or profile['transport'] != 'ssh' or profile['sni_proxy'] != 'false':
        raise ValueError('Cloud consumers require independent Harbor2.13.2:30443 without local SNI proxy')
    if apply:
        ip = ipaddress.IPv4Address(profile['ip'])
        if not any(ip in ipaddress.IPv4Network(net) for net in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')):
            raise ValueError('Explicit independent registry private IPv4 address required')
        if (str(ip) in {n['ip'] for n in nodes} or str(ip) in {c['host'].split('@', 1)[1] for c in connections.values()}
                or not re.fullmatch(r'[0-9a-f]{32}', profile['machine_id'])
                or profile['machine_id'] in {c['machine_id'] for c in connections.values()} or not profile['ssh_host']):
            raise ValueError('Registry must have a separately recorded host identity, not a cluster node')
        path = Path(get('CA_FILE')).expanduser()
        if not path.is_absolute() or path.resolve() != path or not path.is_file() or path.stat().st_size > 65536:
            raise ValueError('Explicit non-symlinked public CA file required')
        profile['ca_base64'] = base64.b64encode(path.read_bytes()).decode()
        ca_bytes(profile)
    return profile


def ca_bytes(profile):
    if profile['address'] != ADDRESS or profile['version'] != '2.13.2':
        raise ValueError('Unexpected registry address/version')
    raw = base64.b64decode(profile['ca_base64'], validate=True)
    if (not 0 < len(raw) <= 65536 or not re.fullmatch(r'[0-9a-f]{64}', profile['ca_sha256'])
            or hashlib.sha256(raw).hexdigest() != profile['ca_sha256']
            or not re.fullmatch(rb'(?:\s*-----BEGIN CERTIFICATE-----[A-Za-z0-9+/=\r\n]+-----END CERTIFICATE-----\s*)+', raw)):
        raise ValueError('Expected SHA-pinned public CA certificates only')
    ssl.create_default_context(cadata=raw.decode('ascii'))
    return raw


def endpoint_check(profile, ca):
    context = ssl.create_default_context(cadata=ca.decode('ascii'))
    # Direct configured private IP, SNI/hostname stays canonical. No proxy,
    # redirects, bearer-token request or Authorization header is used here.
    with socket.create_connection((profile['ip'], 30443), timeout=10) as plain:
        with context.wrap_socket(plain, server_hostname=DOMAIN) as sock:
            sock.sendall(('GET /v2/ HTTP/1.1\r\nHost: ' + ADDRESS + '\r\nConnection: close\r\n\r\n').encode())
            response = http.client.HTTPResponse(sock)
            response.begin()
            challenge = response.getheader('WWW-Authenticate', '')
            realm = re.search(r'\brealm="([^"]+)"', challenge)
            if (response.status != 401 or response.getheader('Docker-Distribution-Api-Version', '').lower() != 'registry/2.0'
                    or not challenge.lower().startswith('bearer ') or not realm
                    or realm.group(1) != 'https://' + ADDRESS + '/service/token'):
                raise ValueError('Registry TLS/authentication challenge differs; no credentials sent')
    return {'tls_verified': True, 'anonymous_status': 401, 'authentication_or_pull_verified': False}


def hosts_text(raw, ip):
    addresses = []
    for line in raw.decode('utf-8').splitlines():
        fields = line.partition('#')[0].split()
        if len(fields) > 1 and DOMAIN in {n.lower().rstrip('.') for n in fields[1:]}:
            addresses.append(str(ipaddress.ip_address(fields[0])))
    if addresses and set(addresses) != {ip}:
        raise ValueError('Existing Harbor hosts mapping conflicts; no lines removed')
    if addresses:
        return raw
    return raw + (b'\n' if raw and not raw.endswith(b'\n') else b'') + (ip + ' ' + DOMAIN + ' # sunmoon external registry\n').encode()


def file_preflight(path, desired=None):
    for parent in (path, *path.parents):
        if parent.resolve() != parent:
            raise ValueError('Symlinked registry trust/hosts path refused')
        if parent.exists():
            info = parent.stat()
            if info.st_uid != 0 or info.st_mode & 0o022:
                raise ValueError('Registry paths must be root-owned and not writable by others')
    if path.exists() and (not path.is_file() or (desired is not None and
            (path.read_bytes() != desired or stat.S_IMODE(path.stat().st_mode) != 0o644))):
        raise ValueError('Existing registry trust file differs; no overwrite')


def trust_files(ca):
    return {DIRECTORY / 'ca.crt': ca, DIRECTORY / 'hosts.toml': (
        'server = "https://' + ADDRESS + '"\n\n[host."https://' + ADDRESS + '"]\n'
        '  capabilities = ["pull", "resolve"]\n  ca = "' + str(DIRECTORY / 'ca.crt') + '"\n').encode()}


def execute(root, manifest, data, work, profile, action):
    if action not in ('registry-check', 'registry-apply', 'registry-verify'):
        raise ValueError('Unknown registry consumer operation')
    ca = ca_bytes(profile)
    ip = str(ipaddress.IPv4Address(profile['ip']))
    files = trust_files(ca)
    # containerd searches the underscore form before the colon form.
    preferred = DIRECTORY.parent / (DOMAIN + '_30443_')
    if preferred.exists() or preferred.is_symlink():
        raise ValueError('Higher-priority registry directory exists; retained for review')
    if DIRECTORY.exists() and (not DIRECTORY.is_dir() or {p.name for p in DIRECTORY.iterdir()} - {'ca.crt', 'hosts.toml'}):
        raise ValueError('Unexpected existing registry trust files retained')
    for path, raw in files.items():
        file_preflight(path, raw)
    hosts = Path('/etc/hosts')
    file_preflight(hosts)
    original = hosts.read_bytes()
    proposed = hosts_text(original, ip)
    records = image_records(manifest, data)
    actual = references()
    for item in records:
        inspect_archive(below(root, item['material_path']), item)
        for reference in (item['source'], item['reference']):
            if reference in actual and actual[reference] != item['platform_digest']:
                raise ValueError('Conflicting ingress image reference retained')
    health = endpoint_check(profile, ca)
    if action == 'registry-check':
        return {'preflight_passed': True, 'hosts_append_required': proposed != original, **health}
    if action == 'registry-apply':
        for path, raw in files.items():
            exact_file(path, raw, 0o644)
        # Append only, under an exclusive descriptor lock. Never replace or
        # truncate /etc/hosts; recheck inode and current mapping while locked.
        descriptor = os.open(hosts, os.O_RDWR | os.O_NOFOLLOW | os.O_APPEND)
        with os.fdopen(descriptor, 'r+b') as stream:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            st = os.fstat(stream.fileno())
            if not stat.S_ISREG(st.st_mode) or st.st_uid != 0 or st.st_mode & 0o022 or (st.st_dev, st.st_ino) != (hosts.stat().st_dev, hosts.stat().st_ino):
                raise ValueError('Hosts identity changed')
            current = stream.read()
            desired = hosts_text(current, ip)
            stream.write(desired[len(current):]); stream.flush(); os.fsync(stream.fileno())
        import_items(root, records, work)
    for path, raw in files.items():
        if not path.is_file() or path.read_bytes() != raw:
            raise ValueError('Registry trust file missing/different')
    if hosts_text(hosts.read_bytes(), ip) != hosts.read_bytes():
        raise ValueError('Registry hosts mapping absent')
    resolved = {str(ipaddress.ip_address(r[4][0])) for r in socket.getaddrinfo(DOMAIN, 30443, type=socket.SOCK_STREAM)}
    if resolved != {ip}:
        raise ValueError('Effective registry DNS differs from the declared host')
    actual = references()
    for item in records:
        if any(actual.get(ref) != item['platform_digest'] for ref in (item['source'], item['reference'])):
            raise ValueError('Ingress image missing/different; verify does not repair')
        if hashlib.sha256(ctr('content', 'get', item['platform_digest'])).hexdigest() != item['platform_digest'][7:]:
            raise ValueError('Ingress runtime manifest differs')
        for reference in (item['source'], item['reference']):
            cri = subprocess.run(['/usr/local/bin/crictl', 'inspecti', reference], check=True,
                                 capture_output=True, text=True, timeout=60)
            if not json.loads(cri.stdout).get('status', {}).get('id'):
                raise ValueError('CRI cannot resolve the pinned ingress image')
    return {'consumer_configured': True, 'ingress_images': len(records), 'registry_lifecycle_changed': False, **health}
