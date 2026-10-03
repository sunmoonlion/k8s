"""Verify browser protocol and SSR against an explicit TLS entry; never print secrets."""
import http.client
from http.cookies import SimpleCookie
import json
import socket
import ssl
import sys
from urllib.parse import parse_qs, urlencode, urlsplit


def require(value, label):
    if not value:
        raise RuntimeError(label)


def run(settings):
    origins = {surface: client['origin'] for surface, client in settings['clients'].items()}
    allowed = {urlsplit(o).hostname for o in [settings['provider'], *origins.values()]}
    context = ssl.create_default_context(cafile=settings['ca_file'])

    class Connection(http.client.HTTPSConnection):
        def connect(self):
            self.sock = context.wrap_socket(
                socket.create_connection(('127.0.0.1', settings['entry_port']), timeout=15),
                server_hostname=self.host,
            )

    class Browser:
        def __init__(self):
            self.cookies = {}

        def request(self, url, method='GET', data=None, headers=None):
            target = urlsplit(url)
            require(target.scheme == 'https' and target.hostname in allowed and target.port == 30443,
                    'Unexpected protocol destination')
            connection = Connection(target.hostname, 30443, timeout=15, context=context)
            request_headers = {'Host': target.netloc, **(headers or {})}
            jar = self.cookies.get(target.hostname, {})
            if jar:
                request_headers['Cookie'] = '; '.join(k + '=' + v for k, v in jar.items())
            payload = json.dumps(data) if data is not None else None
            if payload is not None:
                request_headers['Content-Type'] = 'application/json'
            path = target.path + ('?' + target.query if target.query else '')
            try:
                connection.request(method, path, body=payload, headers=request_headers)
                response = connection.getresponse()
                body = response.read()
                pairs = response.getheaders()
                for key, value in pairs:
                    if key.lower() == 'set-cookie':
                        parsed = SimpleCookie()
                        parsed.load(value)
                        for name, cookie in parsed.items():
                            jar = self.cookies.setdefault(target.hostname, {})
                            if cookie['max-age'] == '0':
                                jar.pop(name, None)
                            else:
                                if name.endswith('_sid'):
                                    require(bool(cookie['secure']) and bool(cookie['httponly']) and
                                            cookie['samesite'].lower() == 'lax', 'Insecure session cookie')
                                jar[name] = cookie.value
                return response.status, {k.lower(): v for k, v in pairs}, body
            finally:
                connection.close()

    outcomes = {}
    for surface in ['web', 'admin']:
        client = settings['clients'][surface]
        origin = client['origin']
        browser = Browser()
        status, _, _ = browser.request(origin + '/zh-CN/login')
        require(status == 200, surface + ': login page unavailable')
        status, _, _ = browser.request(origin + '/api/auth/' + surface + '/me')
        require(status == 401, surface + ': anonymous session was accepted')
        status, headers, _ = browser.request(origin + '/api/auth/' + surface + '/login')
        require(status == 302, surface + ': login start failed')
        flags = headers.get('set-cookie', '').lower()
        require(all(flag in flags for flag in ['secure', 'httponly', 'samesite=lax']),
                surface + ': insecure transaction cookie')
        authorize = urlsplit(headers['location'])
        query = {key: values[0] for key, values in parse_qs(authorize.query).items()}
        require(authorize.scheme + '://' + authorize.netloc == settings['provider'] and
                query['client_id'] == client['client_id'] and query['code_challenge_method'] == 'S256',
                surface + ': unexpected authorization identity')
        aliases = {'client_id': 'clientId', 'response_type': 'responseType', 'redirect_uri': 'redirectUri'}
        login_query = {aliases.get(key, key): value for key, value in query.items()}
        status, _, body = browser.request(settings['provider'] + '/api/login?' + urlencode(login_query),
            method='POST', data={'application': client['name'], 'organization': settings['organization'],
            'username': settings['username'], 'password': settings['password'], 'type': 'code'},
            headers={'Origin': settings['provider']})
        require(status == 200, surface + ': provider login HTTP failure')
        response = json.loads(body)
        require(response.get('status') == 'ok' and isinstance(response.get('data'), str) and response['data'],
                surface + ': provider did not return an authorization code')
        callback = query['redirect_uri'] + '?' + urlencode({'code': response['data'], 'state': query['state']})
        status, headers, _ = browser.request(callback)
        require(status == 302 and 'error=' not in headers.get('location', ''), surface + ': callback rejected')
        status, _, body = browser.request(origin + '/api/auth/' + surface + '/me')
        require(status == 200, surface + ': authenticated session unavailable')
        session = json.loads(body)
        require(session['authenticated'] and session['user']['app'] == 'tpl' and
                session['user']['surface'] == surface, surface + ': session identity mismatch')
        status, _, _ = browser.request(origin + '/zh-CN/dashboard')
        require(status == 200, surface + ': authenticated SSR failed')
        opposite = 'admin' if surface == 'web' else 'web'
        status, _, _ = browser.request(origin + '/api/auth/' + opposite + '/me')
        require(status == 401, surface + ': cross-surface session accepted')
        headers = {'Origin': origin, 'X-CSRF-Token': session['csrf_token']}
        permission_denied = None
        if surface == 'admin' and 'tpl:admin' not in session['user']['scopes']:
            status, _, _ = browser.request(origin + '/api/admin/v1/diagnostics/tasks/ping',
                                          method='POST', headers=headers)
            require(status == 403, 'Unprivileged browser could invoke administrator diagnostic')
            permission_denied = True
        if surface == 'web':
            status, _, body = browser.request(origin + '/api/web/v1/runs/00000000-0000-5000-8000-000000000001')
            require(status == 503 and json.loads(body).get('error', {}).get('code') == 'provider_unavailable',
                    'Production template unexpectedly exposes a reference business fixture')
        status, _, _ = browser.request(origin + '/api/auth/' + surface + '/logout',
                                       method='POST', headers={'Origin': origin})
        require(status == 403, surface + ': missing CSRF accepted')
        status, _, _ = browser.request(origin + '/api/auth/' + surface + '/logout', method='POST', headers=headers)
        require(status == 204, surface + ': logout rejected')
        status, _, _ = browser.request(origin + '/api/auth/' + surface + '/me')
        require(status == 401, surface + ': logged-out session accepted')
        outcomes[surface] = {'pkce_callback': True, 'authenticated_ssr': True,
            'secure_cookie': True, 'cross_surface_denied': True, 'csrf_required': True,
            'logout_revoked': True, 'unprivileged_admin_diagnostic_denied': permission_denied}
    print(json.dumps({'entry_port': settings['entry_port'], 'protocol_checks': outcomes,
        'browser_ui_clicks_verified': False, 'business_provider_configured': False}))


if __name__ == '__main__':
    try:
        run(json.load(sys.stdin))
    except Exception as error:
        # HTTP URLs, credentials, cookies and responses must never be stringified.
        message = str(error) if type(error) is RuntimeError else type(error).__name__
        raise SystemExit('Browser verification failed: ' + message)
