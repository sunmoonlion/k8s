#!/usr/bin/env python3
"""Verify the relay health endpoint through verified ingress TLS."""
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
    origin = urlsplit(args.origin)
    require(origin.scheme == 'https' and origin.hostname and not origin.username and not origin.path, 'Invalid HTTPS origin')
    context = ssl.create_default_context(cafile=args.ca)
    require(context.check_hostname and context.verify_mode == ssl.CERT_REQUIRED, 'Verified TLS required')

    class Route(http.client.HTTPSConnection):
        def connect(self):
            raw = socket.create_connection(('127.0.0.1', int(args.port)), timeout=20)
            self.sock = context.wrap_socket(raw, server_hostname=origin.hostname)

    conn = Route(origin.hostname, int(args.port), context=context, timeout=20)
    try:
        conn.request('GET', '/healthz', headers={'Host': origin.netloc, 'Accept': 'application/json'})
        response = conn.getresponse()
        raw = response.read(8 * 1024 * 1024 + 1)
        require(len(raw) <= 8 * 1024 * 1024, 'Oversized health response')
        require(response.status == 200, 'Relay healthz is unavailable')
        body = json.loads(raw.decode())
        require(body.get('ok') is True and body.get('relay'), 'Relay healthz payload is incomplete')
    finally:
        conn.close()
    print(json.dumps({'passed': True, 'origin': args.origin, 'verified_ingress_port': int(args.port),
        'tls_chain_and_hostname': True, 'healthz': True,
        'scope': 'Actual HTTPS /healthz; agent pairing, JWT admin channel, browser and host DNS require separate checks'}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'passed': False, 'reason': str(error)}))
        raise SystemExit(1)
