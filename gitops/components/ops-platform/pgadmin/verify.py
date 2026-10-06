#!/usr/bin/env python3
"""Verify the pgAdmin login page through verified ingress TLS."""
import argparse
import json
import socket
import ssl
import sys
from urllib.parse import urlsplit
import http.client


def require(ok, reason):
    if not ok:
        raise RuntimeError(reason)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ['origin', 'port', 'ca']:
        parser.add_argument('--' + key, required=True)
    args = parser.parse_args()
    origin = urlsplit(args.origin)
    require(origin.scheme == 'https' and origin.hostname and not origin.username and not origin.path, 'Invalid HTTPS origin')
    context = ssl.create_default_context(cafile=args.ca)
    require(context.check_hostname and context.verify_mode == ssl.CERT_REQUIRED, 'Verified TLS required')

    class Route(http.client.HTTPSConnection):
        def connect(self):
            raw = socket.create_connection(('127.0.0.1', int(args.port)), timeout=20)
            self.sock = context.wrap_socket(raw, server_hostname=origin.hostname)

    def request(path):
        require(path.startswith('/') and not path.startswith('//'), 'Unowned request path')
        conn = Route(origin.hostname, int(args.port), context=context, timeout=20)
        try:
            conn.request('GET', path, headers={'Host': origin.netloc, 'Accept': 'text/html'})
            response = conn.getresponse()
            raw = response.read(8 * 1024 * 1024 + 1)
            require(len(raw) <= 8 * 1024 * 1024, 'Oversized UI response')
            return response.status, {key.lower(): value for key, value in response.getheaders()}, raw
        finally:
            conn.close()

    status, headers, body = request('/login')
    require(status in [200, 302] and (b'pgadmin' in body.lower() or 'location' in headers), 'pgAdmin login page is unavailable')
    ping_status, _, ping_body = request('/misc/ping')
    require(ping_status == 200 and b'PING' in ping_body, 'pgAdmin ping is unavailable')
    print(json.dumps({'passed': True, 'origin': args.origin, 'verified_ingress_port': int(args.port),
        'tls_chain_and_hostname': True, 'login_html': True, 'ping': True,
        'scope': 'Actual HTTPS login page and ping; browser rendering, saved servers and host DNS require separate checks'}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'passed': False, 'reason': str(error)}))
        raise SystemExit(1)
