#!/usr/bin/env python3
"""联调用的身份服务替身：只做服务间令牌这一件事。

发现文档、公钥集合、client_credentials 换令牌。密钥每次启动新生成，只在内存里。
它替代的是 Casdoor；两个后端走的是各自真实的取令牌、验令牌代码。
Casdoor 本身不在这次联调的范围内（同一条服务间关系在旧集群上用 Casdoor 跑过）。
"""

from __future__ import annotations

import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

from joserfc import jwt
from joserfc.jwk import RSAKey


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--clients", required=True, help="JSON 文件：client_id → {secret, subject, audience}")
    args = parser.parse_args()
    with open(args.clients, encoding="utf-8") as handle:
        clients = json.load(handle)
    issuer = f"http://127.0.0.1:{args.port}"
    key = RSAKey.generate_key(2048, parameters={"kid": "standin-1", "use": "sig", "alg": "RS256"})

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_: object) -> None:
            return

        def _send(self, status: int, body: dict) -> None:
            data = json.dumps(body).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self) -> None:  # noqa: N802
            if self.path == "/.well-known/openid-configuration":
                self._send(
                    200,
                    {
                        "issuer": issuer,
                        "authorization_endpoint": f"{issuer}/authorize",
                        "token_endpoint": f"{issuer}/token",
                        "jwks_uri": f"{issuer}/jwks",
                        "id_token_signing_alg_values_supported": ["RS256"],
                    },
                )
            elif self.path == "/jwks":
                self._send(200, {"keys": [key.as_dict(private=False)]})
            else:
                self._send(404, {"error": "not_found"})

        def do_POST(self) -> None:  # noqa: N802
            if self.path != "/token":
                self._send(404, {"error": "not_found"})
                return
            length = int(self.headers.get("Content-Length") or 0)
            form = {k: v[0] for k, v in parse_qs(self.rfile.read(length).decode()).items()}
            client = clients.get(form.get("client_id", ""))
            if (
                form.get("grant_type") != "client_credentials"
                or client is None
                or form.get("client_secret") != client["secret"]
            ):
                self._send(401, {"error": "invalid_client"})
                return
            now = int(time.time())
            claims = {
                "iss": issuer,
                "sub": client["subject"],
                "aud": [client["audience"]],
                "iat": now,
                "exp": now + 300,
                "scope": "openid",
            }
            token = jwt.encode({"alg": "RS256", "kid": "standin-1"}, claims, key)
            self._send(200, {"access_token": token, "token_type": "Bearer", "expires_in": 300})

    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
