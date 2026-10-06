#!/usr/bin/env python3
"""Verify Mongo Express through verified ingress TLS and HTTP basic authentication."""
import argparse
import base64
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
    user, password = secret['username'], secret['password']

    class Route(http.client.HTTPSConnection):
        def connect(self):
            raw = socket.create_connection(('127.0.0.1', int(args.port)), timeout=20)
            self.sock = context.wrap_socket(raw, server_hostname=origin.hostname)

    def request(auth=None):
        headers = {'Host': origin.netloc, 'Accept': 'text/html'}
        if auth:
            headers['Authorization'] = 'Basic ' + base64.b64encode((auth[0] + ':' + auth[1]).encode()).decode()
        conn = Route(origin.hostname, int(args.port), context=context, timeout=20)
        try:
            conn.request('GET', '/', headers=headers)
            response = conn.getresponse()
            raw = response.read(8 * 1024 * 1024 + 1)
            require(len(raw) <= 8 * 1024 * 1024, 'Oversized UI response')
            return response.status, raw
        finally:
            conn.close()

    require(request()[0] == 401, 'Anonymous Mongo Express access must be denied')
    require(request(auth=(user, 'invalid-ui-acceptance-password'))[0] == 401, 'Invalid credentials must be denied')
    status, body = request(auth=(user, password))
    require(status == 200 and b'mongo' in body.lower(), 'Operator cannot open Mongo Express')
    print(json.dumps({'passed': True, 'origin': args.origin, 'verified_ingress_port': int(args.port),
        'tls_chain_and_hostname': True, 'basic_auth': True, 'anonymous_and_bad_password_denied': True,
        'scope': 'Actual HTTPS basic-auth console; Mongo writes, browser rendering and host DNS require separate checks'}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'passed': False, 'reason': str(error)}))
        raise SystemExit(1)
