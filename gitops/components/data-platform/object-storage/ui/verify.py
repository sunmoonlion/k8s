#!/usr/bin/env python3
"""Verify the AIStor console through verified ingress TLS."""
import argparse
import http.client
import json
import socket
import ssl
import sys
from urllib.parse import urlsplit


def require(ok, reason):
    if not ok:
        raise RuntimeError(reason)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ['origin', 'port', 'ca']:
        parser.add_argument('--' + key, required=True)
    args = parser.parse_args()
    secret = json.load(sys.stdin)
    origin = urlsplit(args.origin)
    require(origin.scheme == 'https' and origin.hostname and not origin.username and not origin.path, 'Invalid HTTPS origin')
    context = ssl.create_default_context(cafile=args.ca)
    require(context.check_hostname and context.verify_mode == ssl.CERT_REQUIRED, 'Verified TLS required')

    class Route(http.client.HTTPSConnection):
        def connect(self):
            raw = socket.create_connection(('127.0.0.1', int(args.port)), timeout=20)
            self.sock = context.wrap_socket(raw, server_hostname=origin.hostname)

    def request(method, path, data=None):
        require(path.startswith('/') and not path.startswith('//'), 'Unowned request path')
        headers = {'Host': origin.netloc, 'Accept': 'text/html,application/json', 'Content-Type': 'application/json'}
        conn = Route(origin.hostname, int(args.port), context=context, timeout=20)
        try:
            body = None if data is None else json.dumps(data).encode()
            conn.request(method, path, body=body, headers=headers)
            response = conn.getresponse()
            raw = response.read(8 * 1024 * 1024 + 1)
            require(len(raw) <= 8 * 1024 * 1024, 'Oversized UI response')
            return response.status, {key.lower(): value for key, value in response.getheaders()}, raw
        finally:
            conn.close()

    status, headers, body = request('GET', '/')
    require(status == 200 and 'text/html' in headers.get('content-type', ''), 'Console HTML is unavailable')
    require(b'minio' in body.lower() or b'aistor' in body.lower() or b'console' in body.lower(), 'Console page identity missing')
    denied = request('POST', '/api/v1/login', {'accessKey': secret['root_user'], 'secretKey': 'invalid-ui-acceptance-password'})[0]
    require(denied in [401, 403], f'Invalid console credentials must be denied: HTTP {denied}')
    status, headers, _ = request('POST', '/api/v1/login', {'accessKey': secret['root_user'], 'secretKey': secret['root_password']})
    require(status in [200, 201, 204], f'Console login failed: HTTP {status}')
    print(json.dumps({'passed': True, 'origin': args.origin, 'verified_ingress_port': int(args.port),
        'tls_chain_and_hostname': True, 'login_html': True, 'console_login': True,
        'bad_password_denied': True,
        'scope': 'Actual HTTPS console page and login; S3 API stays in-cluster. Browser rendering and host DNS require separate checks'}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'passed': False, 'reason': str(error)}))
        raise SystemExit(1)
