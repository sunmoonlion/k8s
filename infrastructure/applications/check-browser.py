"""Verify browser protocol and SSR against an explicit TLS entry; never print secrets."""
import http.client
from http.cookies import SimpleCookie
from datetime import datetime, timezone
import json
import secrets
import socket
import ssl
import sys
from urllib.parse import parse_qs, urlencode, urlsplit


# 管理员读得出的一张管理端列表（只读）。后端认管理角色（账 134）部署之后才加进来：
# knowlab、knowbench 随 qwen-005；knowfeed（/api/admin/security-requests）、
# knowbase（/api/admin/v1/knowledge/datasets）等各自下次部署时加
ADMIN_LISTS = {
    'knowlab': '/api/admin/v1/knowbot-drafts',
    'knowbench': '/api/admin/v1/workbench/missing-data',
}


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
    require(bool(settings['clients']) and set(settings['clients']) <= {'web', 'admin'}, 'Invalid selected frontend surfaces')
    require(settings['user_organization'] == 'sunmoonai' and settings['organization'] == 'built-in',
            'Unexpected identity organizations')
    provider_headers = {'Origin': settings['provider']}
    operator = Browser()

    def provider_api(path, data):
        status, _, body = operator.request(settings['provider'] + path, method='POST', data=data,
                                           headers=provider_headers)
        require(status == 200, 'Provider administration HTTP failure')
        return json.loads(body)

    # Web clients belong to the user organization, where the administrator cannot sign in
    # (SDD 0014). A throwaway member with a random password is created for this run only
    # and always deleted afterwards; nothing about it is printed or stored.
    member = None
    if 'web' in settings['clients']:
        signed_in = provider_api('/api/login', {'application': 'app-built-in', 'organization': 'built-in',
            'username': settings['username'], 'password': settings['password'], 'type': 'login'})
        require(signed_in.get('status') == 'ok', 'Provider administrator login failed')
        member = {'owner': settings['user_organization'], 'name': 'verify-' + secrets.token_hex(6),
                  'password': secrets.token_urlsafe(24)}
        added = provider_api('/api/add-user', {**member, 'type': 'normal-user', 'displayName': 'verification',
            'createdTime': datetime.now(timezone.utc).isoformat()})
        require(added.get('status') == 'ok' and added.get('data') == 'Affected', 'Verification member not created')
    try:
        install_issued = _check_surfaces(settings, Browser, member, outcomes)
    finally:
        if member is not None:
            removed = provider_api('/api/delete-user', {'owner': member['owner'], 'name': member['name']})
            require(removed.get('status') == 'ok', 'Verification member not removed')
    report = {'entry_port': settings['entry_port'], 'protocol_checks': outcomes,
        'web_member_organization': settings['user_organization'] if member else None,
        'browser_ui_clicks_verified': False, 'business_provider_configured': False}
    if settings['application'] == 'knowbench':
        report['install_command_issued'] = install_issued is True
    print(json.dumps(report))


def _check_surfaces(settings, Browser, member, outcomes):
    install_issued = None
    for surface in settings['clients']:
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
        if surface == 'admin' and member is not None:
            # The user organization must not obtain an authorization code from an admin client.
            status, _, body = Browser().request(settings['provider'] + '/api/login?' + urlencode(login_query),
                method='POST', data={'application': client['name'], 'organization': member['owner'],
                'username': member['name'], 'password': member['password'], 'type': 'code'},
                headers={'Origin': settings['provider']})
            require(status == 200 and json.loads(body).get('status') != 'ok', 'User organization reached admin client')
        account = ({'organization': member['owner'], 'username': member['name'], 'password': member['password']}
                   if surface == 'web' else {'organization': settings['organization'],
                   'username': settings['username'], 'password': settings['password']})
        status, _, body = browser.request(settings['provider'] + '/api/login?' + urlencode(login_query),
            method='POST', data={'application': client['name'], 'type': 'code', **account},
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
        require(session['authenticated'] and session['user']['app'] == settings['application'] and
                session['user']['surface'] == surface, surface + ': session identity mismatch')
        status, _, _ = browser.request(origin + '/zh-CN/dashboard')
        require(status == 200, surface + ': authenticated SSR failed')
        opposite = 'admin' if surface == 'web' else 'web'
        status, _, _ = browser.request(origin + '/api/auth/' + opposite + '/me')
        require(status == 401, surface + ': cross-surface session accepted')
        headers = {'Origin': origin, 'X-CSRF-Token': session['csrf_token']}
        permission_denied = admin_list_read = None
        # 管理员 = 白名单里的管理角色（admin、operator，待办 98）或带「应用名:admin」权限（账 134）。
        # 管理员读一张管理端列表（只读、不派任务），读得出才算管理端能用；不是管理员的，诊断接口必须 403
        privileged = surface == 'admin' and (
            settings['application'] + ':admin' in session['user']['scopes'] or
            bool(set(session['user'].get('roles') or []) & {'admin', 'operator'}))
        if privileged and settings['application'] in ADMIN_LISTS:
            status, _, _ = browser.request(origin + ADMIN_LISTS[settings['application']])
            require(status == 200, 'Administrator could not read the admin console list')
            admin_list_read = True
        if surface == 'admin' and not privileged:
            status, _, _ = browser.request(origin + '/api/admin/v1/diagnostics/tasks/ping',
                                          method='POST', headers=headers)
            require(status == 403, 'Unprivileged browser could invoke administrator diagnostic')
            permission_denied = True
        if surface == 'web' and settings['application'] in ('tpl', 'knowlab', 'knowmart'):  # 由模板实例化、还没有业务的应用
            status, _, body = browser.request(origin + '/api/web/v1/runs/00000000-0000-5000-8000-000000000001')
            require(status == 503 and json.loads(body).get('error', {}).get('code') == 'provider_unavailable',
                    'Production template unexpectedly exposes a reference business fixture')
        if surface == 'web' and settings['application'] == 'knowbench':
            status, _, body = browser.request(origin + '/api/workbench/agent/install-command',
                                              method='POST', headers=headers)
            if status == 404 and b'agent_download_unavailable' in body:
                # 安装包下载开关关着（0028 R5.3 上传、读回校验之前）：明确说「下载不可用」也算对，报告里记 install_issued: false
                install_issued = False
                status = None
            require(status in (200, None), 'Install command was not issued')
        if surface == 'web' and settings['application'] == 'knowbench' and install_issued is not False:
            issued = json.loads(body)
            command = issued.get('command')
            require(isinstance(command, str) and command.startswith("irm '"),
                    'Install command was not issued')
            try:
                expiry = datetime.fromisoformat(issued['expires_at'])
            except (KeyError, TypeError, ValueError):
                expiry = None
            require(isinstance(expiry, datetime), 'Install command expiry was not parseable')
            install_issued = True
        status, _, _ = browser.request(origin + '/api/auth/' + surface + '/logout',
                                       method='POST', headers={'Origin': origin})
        require(status == 403, surface + ': missing CSRF accepted')
        status, _, body = browser.request(origin + '/api/auth/' + surface + '/logout', method='POST', headers=headers)
        # 单点退出（0027 P1b）：本地会话已结束，回 200 带去 Casdoor 结束会话的地址；没配 Casdoor 的退出地址时回 204
        if status == 200:
            ended = urlsplit(json.loads(body).get('logout_url') or '')
            require(ended.scheme + '://' + ended.netloc == settings['provider'] and ended.path == '/api/logout',
                    surface + ': logout did not hand over to the provider')
        require(status in (200, 204), surface + ': logout rejected')
        status, _, _ = browser.request(origin + '/api/auth/' + surface + '/me')
        require(status == 401, surface + ': logged-out session accepted')
        outcomes[surface] = {'pkce_callback': True, 'authenticated_ssr': True,
            'secure_cookie': True, 'cross_surface_denied': True, 'csrf_required': True,
            'logout_revoked': True, 'unprivileged_admin_diagnostic_denied': permission_denied,
            'admin_list_read': admin_list_read,
            'user_organization_denied': True if surface == 'admin' and member is not None else None}
    return install_issued


if __name__ == '__main__':
    try:
        run(json.load(sys.stdin))
    except Exception as error:
        # HTTP URLs, credentials, cookies and responses must never be stringified.
        message = str(error) if type(error) is RuntimeError else type(error).__name__
        raise SystemExit('Browser verification failed: ' + message)
