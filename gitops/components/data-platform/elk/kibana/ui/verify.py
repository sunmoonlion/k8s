#!/usr/bin/env python3
"""Verify the Kibana login/session/read-only path through verified ingress TLS."""
import argparse
import base64
import http.client
from http.cookies import SimpleCookie
import json
import socket
import ssl
import sys
from urllib.parse import urlsplit
import uuid


def require(ok, reason):
    if not ok:
        raise RuntimeError(reason)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ['origin', 'port', 'ca', 'username', 'version', 'data-view-id']:
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

    def request(method, path, data=None, auth=None, cookie=None):
        require(path.startswith('/') and not path.startswith('//'), 'Unowned request path')
        headers = {'Host': origin.netloc, 'Content-Type': 'application/json',
                   'kbn-xsrf': 'sunmoon-ui-acceptance', 'kbn-version': args.version,
                   'Origin': args.origin, 'Referer': args.origin + '/login'}
        if auth:
            headers['Authorization'] = 'Basic ' + base64.b64encode((auth[0] + ':' + auth[1]).encode()).decode()
        if cookie:
            headers['Cookie'] = cookie
        conn = Route(origin.hostname, int(args.port), context=context, timeout=20)
        try:
            conn.request(method, path, body=None if data is None else json.dumps(data).encode(), headers=headers)
            response = conn.getresponse()
            raw = response.read(8 * 1024 * 1024 + 1)
            require(len(raw) <= 8 * 1024 * 1024, 'Oversized UI response')
            return response.status, dict(response.getheaders()), raw
        finally:
            conn.close()

    viewer = (args.username, secret['password'])
    status, headers, body = request('GET', '/login?next=%2Fapp%2Fdiscover')
    require(status == 200 and 'text/html' in headers.get('Content-Type', '') and b'kbn' in body.lower(), 'Login HTML is unavailable')
    path = '/api/data_views/data_view/' + args.data_view_id
    require(request('GET', path)[0] == 401, 'Anonymous data access must be denied')
    require(request('GET', path, auth=(args.username, 'invalid-ui-acceptance-password'))[0] == 401, 'Invalid credentials must be denied')
    status, headers, body = request('GET', path, auth=viewer)
    require(status == 200 and json.loads(body)['data_view']['id'] == args.data_view_id, 'Human reader cannot read the prepared view')
    require(request('GET', '/api/security/role', auth=viewer)[0] == 403, 'Human reader can administer roles')

    # A deliberately unique saved-object write must be denied. If unexpectedly
    # admitted, remove only this exact marker with the supplied administrator.
    marker = 'sunmoon-ui-acceptance-' + uuid.uuid4().hex
    status, _, body = request('POST', '/api/data_views/data_view',
        {'data_view': {'title': marker + '-*', 'name': marker, 'allowNoIndex': True}}, auth=viewer)
    if status == 200:
        view = json.loads(body).get('data_view', {})
        require(view.get('name') == marker and view.get('title') == marker + '-*' and view.get('id'), 'Unexpected write needs manual inspection')
        deleted = request('DELETE', '/api/data_views/data_view/' + view['id'], auth=('elastic', secret['admin_password']))[0]
        require(deleted in [200, 204], 'Unexpected probe object could not be removed')
        raise RuntimeError('Human reader unexpectedly created a saved object; exact probe removed')
    require(status == 403, 'Saved-object write denial not verified')

    login = {'providerType': 'basic', 'providerName': 'basic1',
             'currentURL': args.origin + '/login?next=%2Fapp%2Fdiscover',
             'params': {'username': args.username, 'password': secret['password']}}
    status, headers, _ = request('POST', '/internal/security/login', login)
    require(status == 200, 'Browser session login failed')
    cookies = SimpleCookie()
    cookies.load(headers.get('Set-Cookie', ''))
    require('sid' in cookies, 'Session cookie missing')
    sid = cookies['sid']
    require(bool(sid['secure']) and bool(sid['httponly']) and sid['samesite'].lower() == 'lax', 'Session cookie protections differ')
    cookie = 'sid=' + sid.value
    status, _, body = request('GET', path, cookie=cookie)
    require(status == 200 and json.loads(body)['data_view']['id'] == args.data_view_id, 'Browser session cannot read log view')
    status, headers, _ = request('GET', '/logout', cookie=cookie)
    require(status in [200, 302, 303], 'Browser logout failed')
    require(request('GET', path, cookie=cookie)[0] == 401, 'Logged-out session remained valid')
    print(json.dumps({'passed': True, 'origin': args.origin, 'verified_ingress_port': int(args.port),
        'tls_chain_and_hostname': True, 'login_html': True, 'basic_reader': True,
        'anonymous_and_bad_password_denied': True, 'role_admin_and_saved_object_write_denied': True,
        'secure_http_only_session': True, 'session_view_read': True, 'logout_revoked': True,
        'scope': 'Actual HTTPS login/session and permission APIs; browser rendering and host DNS require separate checks'}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'passed': False, 'reason': str(error)}))
        raise SystemExit(1)
