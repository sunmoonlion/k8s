"""Literal HTTPS transport for native component account tasks; no proxies or CLI."""
import base64
import http.client
import json
import socket
import ssl
from http.cookies import SimpleCookie
from urllib.parse import urlencode


class Transport:
    def __init__(self, hostname, port, ca):
        self.hostname = hostname
        self.port = int(port)
        self.context = ssl.create_default_context(cafile=ca)
        self.cookies = {}

    def request(self, method, path, payload=None, credentials=None, form=False, origin=None):
        if not path.startswith('/') or path.startswith('//'):
            raise RuntimeError('Invalid account API path')
        headers = {}
        if credentials:
            headers['Authorization'] = 'Basic ' + base64.b64encode((credentials[0] + ':' + credentials[1]).encode()).decode()
        if self.cookies:
            headers['Cookie'] = '; '.join(k + '=' + v for k, v in self.cookies.items())
        if origin:
            headers['Origin'] = origin
        data = None
        if payload is not None:
            data = urlencode(payload) if form else json.dumps(payload)
            headers['Content-Type'] = 'application/x-www-form-urlencoded' if form else 'application/json'
        context, hostname, port = self.context, self.hostname, self.port
        class Connection(http.client.HTTPSConnection):
            def connect(self):
                raw = socket.create_connection(('127.0.0.1', port), timeout=20)
                self.sock = context.wrap_socket(raw, server_hostname=hostname)
        client = Connection(hostname, port, timeout=20, context=context)
        try:
            client.request(method, path, body=data, headers=headers)
            response = client.getresponse()
            body = response.read(4 * 1024 * 1024)
            for key, value in response.getheaders():
                if key.lower() == 'set-cookie':
                    jar = SimpleCookie(); jar.load(value)
                    for name, cookie in jar.items():
                        if cookie['max-age'] == '0':
                            self.cookies.pop(name, None)
                        else:
                            self.cookies[name] = cookie.value
            try:
                result = json.loads(body) if body else None
            except ValueError:
                result = None
            return response.status, result
        finally:
            client.close()
