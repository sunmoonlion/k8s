#!/usr/bin/env python3
"""Bounded WSL candidate acceptance; starts/stops only owned new containers.

Default prints only. Existing 30443 is only read. No push, writes, old-node stop,
cleanup or cloud execution. Routing probes are not full application acceptance.
"""
import argparse
import datetime as dt
import fcntl
import hashlib
import http.client
import json
import os
from pathlib import Path
import socket
import ssl
import stat
import subprocess
import time

from host_prepare import docker, load as load_harbor, write
from host_runtime import Instance
from runtime_inspect import read
from sni_proxy import Proxy, load


def request(port, context, path):
    c = http.client.HTTPSConnection('harbor.sunmoonai.com', port, timeout=15, context=context)
    # Keep the canonical TLS name and HTTP Host, explicitly use loopback transport.
    c.sock = context.wrap_socket(socket.create_connection(('127.0.0.1', port), timeout=15),
                                 server_hostname='harbor.sunmoonai.com')
    certificate = hashlib.sha256(c.sock.getpeercert(binary_form=True)).hexdigest()
    try:
        c.request('GET', path, headers={'Host': 'harbor.sunmoonai.com:30443', 'Connection': 'close'})
        response = c.getresponse(); body = response.read(1024**2 + 1)
        if len(body) > 1024**2:
            raise ValueError('Acceptance response too large')
        return {'status': response.status, 'certificate_der_sha256': certificate,
                'challenge': response.getheader('WWW-Authenticate'),
                'api_version': response.getheader('Docker-Distribution-Api-Version'), 'body': body}
    finally:
        c.close()


def route_probe(name):
    # Generate a real ClientHello, then close after receiving initial server bytes.
    # We deliberately make no claim about backend certs/auth for unknown/no SNI.
    context = ssl.create_default_context()
    if name is None:
        # No hostname exists for a no-SNI ClientHello. CERT_REQUIRED remains on;
        # this probe only observes routing, never treats a handshake as verified.
        context.check_hostname = False
    incoming, outgoing = ssl.MemoryBIO(), ssl.MemoryBIO()
    tls = context.wrap_bio(incoming, outgoing, server_side=False, server_hostname=name)
    try:
        tls.do_handshake()
    except ssl.SSLWantReadError:
        pass
    with socket.create_connection(('127.0.0.1', 28443), timeout=10) as connection:
        connection.sendall(outgoing.read())
        return len(connection.recv(65536))


def upstreams(container, since):
    raw = docker('logs', '--since', since, container).decode()
    return [line.split()[0].removeprefix('upstream=') for line in raw.splitlines() if line.startswith('upstream=')]


def verify(proxy, harbor):
    if proxy.config['mode'] != 'candidate' or harbor.config['runtime']['platform'] != 'wsl':
        raise ValueError('Only local candidate verification is admitted')
    if proxy.inspect()['State']['Running'] or any(v == 'running' for v in harbor.check().values()):
        raise ValueError('Acceptance owns only initially stopped new services')
    context = ssl.create_default_context(cafile=str(harbor.root / 'ca-download/ca.crt'))
    old = request(30443, context, '/api/v2.0/health')
    if old['status'] != 200 or json.loads(old['body']).get('status') != 'healthy':
        raise ValueError('Old Harbor health precondition failed')
    since = dt.datetime.now(dt.timezone.utc).isoformat()
    result = None
    try:
        harbor.start()
        deadline = time.monotonic() + 180
        while True:
            try:
                direct = request(18443, context, '/v2/')
                if direct['status'] != 401:
                    raise ValueError('Harbor registry not ready')
                break
            except Exception:
                if time.monotonic() > deadline:
                    raise ValueError('Harbor readiness deadline') from None
                time.sleep(2)
        proxy.start()
        response = request(28443, context, '/v2/')
        expected = hashlib.sha256(ssl.PEM_cert_to_DER_cert(read(harbor.root / 'tls/server.crt').decode())).hexdigest()
        if (response['status'] != 401 or response['api_version'] != 'registry/2.0'
                or response['certificate_der_sha256'] != expected
                or direct['certificate_der_sha256'] != expected
                or 'realm="https://harbor.sunmoonai.com:30443/service/token"' not in (response['challenge'] or '')
                or response['challenge'] != direct['challenge']):
            raise ValueError('Candidate TLS/registry authentication realm differs')
        health = request(28443, context, '/api/v2.0/health')
        # Jobservice is intentionally stopped, so do not require overall healthy.
        if health['status'] not in (200, 503) or 'components' not in json.loads(health['body']):
            raise ValueError('Harbor health API did not traverse candidate')
        time.sleep(0.5)  # Let the preceding closed HTTP streams reach access_log.
        routes = []
        for name, upstream in [('harbor.sunmoonai.com', '127.0.0.1:18443'),
                               ('HARBOR.SUNMOONAI.COM', '127.0.0.1:18443'),
                               ('sunmoonai.com', '127.0.0.1:30443'),
                               ('unrecognized.invalid', '127.0.0.1:30443'),
                               ('harbor.sunmoonai.com.evil.invalid', '127.0.0.1:30443'),
                               (None, '127.0.0.1:30443')]:
            previous = len(upstreams(proxy.state['container_id'], since))
            received = route_probe(name)
            end = time.monotonic() + 5
            while True:
                observed = upstreams(proxy.state['container_id'], since)[previous:]
                if observed:
                    break
                if time.monotonic() >= end:
                    raise ValueError('No completed stream route observation')
                time.sleep(0.2)
            if observed != [upstream]:
                raise ValueError('Observed SNI routing differs from the exact/default mapping')
            routes.append({'sni': name, 'upstream': upstream, 'initial_response_bytes': received,
                           'backend_certificate_verified': False})
        # Syntax and compiled capability checks run in the existing owned container.
        probe = subprocess.run(['docker', '--host', 'unix:///var/run/docker.sock', 'exec',
                                proxy.state['container_id'], 'nginx', '-V'], capture_output=True, timeout=15)
        version = (probe.stdout + probe.stderr).decode()
        if probe.returncode or 'nginx/1.30.5' not in version or '--with-stream_ssl_preread_module' not in version:
            raise ValueError('NGINX version or preread module differs')
        result = {'completed': True, 'listen': '127.0.0.1:28443', 'nginx_version': '1.30.5',
                  'tls_certificate_der_sha256': expected, 'strict_ca_and_hostname': True,
                  'token_realm_preserved': True, 'anonymous_private_registry_status': response['status'],
                  'routes': routes, 'proxy_has_no_private_key_mounts': True,
                  'formal_port_switched': False, 'authenticated_push_pull_verified': False,
                  'long_transfer_or_application_routes_verified': False}
    finally:
        # Attempt both stops even if the first one fails. Retain all resources.
        try:
            proxy.stop()
        finally:
            harbor.stop()
    old_after = request(30443, context, '/api/v2.0/health')
    if (old_after['status'] != 200 or json.loads(old_after['body']).get('status') != 'healthy'
            or old_after['certificate_der_sha256'] != old['certificate_der_sha256']):
        raise ValueError('Old Harbor health/certificate changed')
    result.update({'candidate_and_new_harbor_stopped': True, 'old_harbor_healthy': True})
    write(proxy.root / ('acceptance-' + str(time.time_ns()) + '.json'), (json.dumps(result, indent=2) + '\n').encode())
    return result


def main():
    os.umask(0o077)
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config', required=True, type=Path); p.add_argument('--harbor-config', required=True, type=Path)
    p.add_argument('--apply', action='store_true'); args = p.parse_args()
    config = load(args.config); harbor = load_harbor(args.harbor_config.absolute())
    if not args.apply:
        print(json.dumps({'dry_run': True, 'proxy': config['deployment'], 'harbor': harbor['runtime']['deployment'],
                          'start_stop_new_only': True, 'external_entry_switched': False})); return
    fd = os.open('/data/harbor/.instance-preparation.lock', os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb+') as lock:
        if os.fstat(lock.fileno()).st_uid != 0 or stat.S_IMODE(os.fstat(lock.fileno()).st_mode) != 0o600:
            raise ValueError('Unsafe lifecycle lock')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        print(json.dumps(verify(Proxy(config), Instance(harbor)), indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('SNI acceptance stopped: ' + (str(error) if isinstance(error, ValueError)
                         else type(error).__name__ + '; private diagnostics withheld')) from None
