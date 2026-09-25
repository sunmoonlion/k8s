"""会合点 v1（0004-relay）。边缘上唯一的自研组件：三类出站客户的认证、配对、透传。无状态。

路径：
  /agent               代理控制通道。第一帧 hello；通过则 welcome，之后会合点用 {"type":"open","conn":ID} 让代理开数据流
  /agent-data?conn=ID  代理数据流。第一帧 hello（带 conn）
  /sandbox             沙箱数据流。第一帧 hello；配对到同一 user 的代理，之后逐消息透传
  /admin               工作台的管理通道（内网出站到边缘）。第一帧 hello role=admin + RELAY_ADMIN_TOKEN；之后
                       {"type":"set_tokens","user":U,"agent":A,"sandbox":S} / {"type":"revoke","user":U} / {"type":"list"}
                       / {"type":"set_public_key","pem":PEM} / {"type":"revoke_jti","jtis":[...]}
  GET /healthz         健康
认证（D10）：令牌是 JWT（三段）且会合点有工作台公钥（RELAY_JWT_PUBLIC_KEY / 管理通道推来）时就地验签：
      ES256、aud=relay、sub=hello.user、role=路径角色、exp 未过、jti 不在吊销表、iss 匹配（配了 RELAY_JWT_ISSUER 时）。
      不验签的退路：静态令牌表（TOKENS_FILE：{"user": {"agent": "...", "sandbox": "..."}}）加管理通道动态登记。
      登记、公钥、吊销表都写 RELAY_TOKENS_STATE 文件，重启后回读。吊销只按 jti 与用户，不回源。
版本成对：agent 与 sandbox 的 hello.codex 必须相同，否则拒绝配对（AT-28）。
协议版本：hello.proto 必须等于 RELAY_PROTOCOL。
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import secrets
import signal
import time
from dataclasses import dataclass, field
from http import HTTPStatus
from urllib.parse import parse_qs, urlparse

import websockets
from websockets.asyncio.server import ServerConnection, serve

RELAY_PROTOCOL = 1
RELAY_NAME = os.environ.get("RELAY_NAME", "relay-v1")
HELLO_TIMEOUT = float(os.environ.get("RELAY_HELLO_TIMEOUT", "10"))
OPEN_TIMEOUT = float(os.environ.get("RELAY_OPEN_TIMEOUT", "15"))
MAX_STREAMS_PER_USER = int(os.environ.get("RELAY_MAX_STREAMS_PER_USER", "8"))
ADMIN_TOKEN = os.environ.get("RELAY_ADMIN_TOKEN", "")
TOKENS_STATE = os.environ.get("RELAY_TOKENS_STATE", "")
JWT_PUBLIC_KEY = os.environ.get("RELAY_JWT_PUBLIC_KEY", "")
JWT_ISSUER = os.environ.get("RELAY_JWT_ISSUER", "")
USER_RE = __import__("re").compile(r"^[a-z0-9][a-z0-9-]{0,62}$")
log = logging.getLogger("relay")


class Reject(Exception):
    pass


# ---- D10：就地验工作台签发的 ES256 JWT（只依赖 cryptography；没装就只走静态表）----
def _b64url_decode(part: str) -> bytes:
    import base64
    return base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))


def looks_like_jwt(token: str) -> bool:
    return token.count(".") == 2 and all(token.split("."))


def load_public_key(pem: str):
    from cryptography.hazmat.primitives import serialization
    key = serialization.load_pem_public_key(pem.encode())
    from cryptography.hazmat.primitives.asymmetric import ec
    if not isinstance(key, ec.EllipticCurvePublicKey):
        raise ValueError("relay only accepts EC P-256 public keys")
    return key


def jwt_jti(token: str) -> str:
    """不验签地取 jti（只在 check() 已验过签之后用）；非 JWT 返回空串。"""
    if not looks_like_jwt(token):
        return ""
    try:
        claims = json.loads(_b64url_decode(token.split(".")[1]))
    except (ValueError, TypeError):
        return ""
    return str(claims.get("jti") or "") if isinstance(claims, dict) else ""


def verify_jwt(token: str, public_key, *, issuer: str = "") -> dict:
    """返回 claims；任何不符都 raise Reject。不做 aud/role/sub 的业务判断（调用方做）。"""
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature

    try:
        h, p, sig = token.split(".")
        header = json.loads(_b64url_decode(h))
        claims = json.loads(_b64url_decode(p))
        raw = _b64url_decode(sig)
    except (ValueError, TypeError):
        raise Reject("malformed jwt")
    if not isinstance(header, dict) or header.get("alg") != "ES256" or not isinstance(claims, dict):
        raise Reject("jwt alg not ES256")
    if len(raw) != 64:
        raise Reject("jwt signature length")
    r, s_ = int.from_bytes(raw[:32], "big"), int.from_bytes(raw[32:], "big")
    try:
        public_key.verify(encode_dss_signature(r, s_), f"{h}.{p}".encode(), ec.ECDSA(hashes.SHA256()))
    except InvalidSignature:
        raise Reject("jwt signature")
    try:
        exp = int(claims.get("exp", 0))
    except (TypeError, ValueError):
        raise Reject("jwt exp")
    if exp <= int(time.time()):
        raise Reject("jwt expired")
    if issuer and claims.get("iss") != issuer:
        raise Reject("jwt issuer")
    return claims


@dataclass
class Agent:
    ws: ServerConnection
    codex: str
    software: str
    streams: int = 0
    jti: str = ""  # JWT 令牌的 jti（静态表令牌为空）；按 jti 吊销时据此断开在线代理


@dataclass
class Relay:
    tokens: dict[str, dict[str, str]]
    agents: dict[str, Agent] = field(default_factory=dict)
    waiting: dict[str, tuple[str, asyncio.Future]] = field(default_factory=dict)
    stats: dict[str, int] = field(default_factory=lambda: {"paired": 0, "rejected": 0, "agent_up": 0})
    admin_token: str = ADMIN_TOKEN
    state_path: str = TOKENS_STATE
    public_key_pem: str = JWT_PUBLIC_KEY
    jwt_issuer: str = JWT_ISSUER
    revoked_jtis: set = field(default_factory=set)
    revoked_users: set = field(default_factory=set)
    _public_key: object = field(default=None, repr=False)

    def public_key(self):
        if self._public_key is None and self.public_key_pem:
            self._public_key = load_public_key(self.public_key_pem)
        return self._public_key

    # ---- 认证 ----
    def check(self, hello: dict, role: str) -> str:
        if hello.get("type") != "hello":
            raise Reject("first frame must be hello")
        if hello.get("proto") != RELAY_PROTOCOL:
            raise Reject(f"protocol {hello.get('proto')} != {RELAY_PROTOCOL}")
        if hello.get("role") != role:
            raise Reject(f"role {hello.get('role')} on {role} path")
        user = str(hello.get("user") or "")
        token = str(hello.get("token") or "")
        if not user:
            raise Reject("bad token")
        if looks_like_jwt(token) and self.public_key() is not None:
            claims = verify_jwt(token, self.public_key(), issuer=self.jwt_issuer)
            if claims.get("aud") != "relay" or claims.get("sub") != user or claims.get("role") != role:
                raise Reject("jwt claims")
            if str(claims.get("jti") or "") in self.revoked_jtis or user in self.revoked_users:
                raise Reject("token revoked")
        else:
            expected = self.tokens.get(user, {}).get(role)
            if not expected or not secrets.compare_digest(expected, token):
                raise Reject("bad token")
        if not hello.get("codex"):
            raise Reject("missing codex version")
        return user

    # ---- 三个入口 ----
    async def agent_control(self, ws: ServerConnection):
        hello = await self._hello(ws)
        try:
            user = self.check(hello, "agent")
        except Reject as e:
            await self._reject(ws, str(e)); return
        old = self.agents.get(user)
        if old is not None:
            log.info("agent replaced user=%s", user)
            try: await old.ws.close(code=4000, reason="replaced by a newer agent")
            except Exception: pass
        agent = Agent(ws=ws, codex=str(hello["codex"]), software=str(hello.get("software", "")),
                      jti=jwt_jti(str(hello.get("token") or "")) if self.public_key() is not None else "")
        self.agents[user] = agent
        self.stats["agent_up"] += 1
        await ws.send(json.dumps({"type": "welcome", "relay": RELAY_NAME, "proto": RELAY_PROTOCOL}))
        log.info("agent up user=%s codex=%s software=%s", user, agent.codex, agent.software)
        try:
            async for _ in ws:  # 控制通道上只期待 pong；其它忽略
                pass
        except websockets.ConnectionClosed:
            pass
        finally:
            if self.agents.get(user) is agent:
                del self.agents[user]
                log.info("agent down user=%s", user)

    async def agent_data(self, ws: ServerConnection, conn: str):
        hello = await self._hello(ws)
        try:
            user = self.check(hello, "agent")
        except Reject as e:
            await self._reject(ws, str(e)); return
        entry = self.waiting.get(conn)
        if entry is None or entry[0] != user or entry[1].done():
            await self._reject(ws, "unknown conn"); return
        entry[1].set_result(ws)
        await ws.wait_closed()

    async def sandbox(self, ws: ServerConnection):
        hello = await self._hello(ws)
        try:
            user = self.check(hello, "sandbox")
        except Reject as e:
            await self._reject(ws, str(e)); return
        agent = self.agents.get(user)
        if agent is None:
            await self._reject(ws, "agent offline"); return
        if str(hello["codex"]) != agent.codex:
            await self._reject(ws, f"codex version mismatch: sandbox {hello['codex']} vs agent {agent.codex}"); return
        if agent.streams >= MAX_STREAMS_PER_USER:
            await self._reject(ws, "too many streams"); return
        conn = secrets.token_hex(4)
        fut: asyncio.Future = asyncio.get_running_loop().create_future()
        self.waiting[conn] = (user, fut)
        try:
            await agent.ws.send(json.dumps({"type": "open", "conn": conn}))
            try:
                agent_ws: ServerConnection = await asyncio.wait_for(fut, OPEN_TIMEOUT)
            except asyncio.TimeoutError:
                await self._reject(ws, "agent did not open the stream"); return
        finally:
            self.waiting.pop(conn, None)
        agent.streams += 1
        self.stats["paired"] += 1
        await ws.send(json.dumps({"type": "welcome", "relay": RELAY_NAME, "proto": RELAY_PROTOCOL, "conn": conn}))
        log.info("paired user=%s conn=%s", user, conn)
        t0 = time.monotonic()
        try:
            await asyncio.gather(self._pipe(ws, agent_ws), self._pipe(agent_ws, ws))
        finally:
            agent.streams -= 1
            log.info("closed user=%s conn=%s after %.1fs", user, conn, time.monotonic() - t0)

    # ---- 工具 ----
    async def _hello(self, ws: ServerConnection) -> dict:
        try:
            raw = await asyncio.wait_for(ws.recv(), HELLO_TIMEOUT)
            return json.loads(raw)
        except Exception:
            return {}

    async def _reject(self, ws: ServerConnection, reason: str):
        self.stats["rejected"] += 1
        log.warning("reject: %s", reason)
        try:
            await ws.send(json.dumps({"type": "reject", "reason": reason}))
            await ws.close(code=4001, reason=reason[:120])
        except Exception:
            pass

    @staticmethod
    async def _pipe(src: ServerConnection, dst: ServerConnection):
        try:
            async for msg in src:
                await dst.send(msg)
        except websockets.ConnectionClosed:
            pass
        finally:
            try: await dst.close()
            except Exception: pass

    # ---- 路由 ----
    async def handler(self, ws: ServerConnection):
        u = urlparse(ws.request.path)
        if u.path == "/agent":
            await self.agent_control(ws)
        elif u.path == "/agent-data":
            conn = parse_qs(u.query).get("conn", [""])[0]
            await self.agent_data(ws, conn)
        elif u.path == "/sandbox":
            await self.sandbox(ws)
        elif u.path == "/admin":
            await self.handle_admin(ws)
        else:
            await ws.close(code=1008, reason="unknown path")

    # ---- 管理通道（工作台 → 会合点，动态登记每用户令牌）----
    def admin_apply(self, message: dict) -> dict:
        kind = message.get("type")
        if kind == "list":
            return {"type": "tokens", "users": sorted(self.tokens), "revoked_jtis": len(self.revoked_jtis),
                    "public_key": bool(self.public_key_pem)}
        if kind == "set_public_key":
            pem = message.get("pem")
            if not isinstance(pem, str) or "BEGIN PUBLIC KEY" not in pem:
                return {"type": "error", "reason": "pem must be a PEM public key"}
            try:
                self._public_key = load_public_key(pem)
            except Exception as exc:  # 坏钥不覆盖旧钥
                return {"type": "error", "reason": f"public key rejected: {type(exc).__name__}"}
            self.public_key_pem = pem
            self.persist_tokens()
            log.info("admin set public key")
            return {"type": "ok"}
        if kind == "revoke_jti":
            jtis = message.get("jtis")
            if not isinstance(jtis, list) or not all(isinstance(j, str) and j for j in jtis):
                return {"type": "error", "reason": "jtis must be a list of strings"}
            self.revoked_jtis.update(jtis)
            self.persist_tokens()
            # 撤换令牌要立刻生效：用被吊销令牌在线的代理当场断开（4003，代理收到后不再重连）
            closed = [u for u, a in self.agents.items() if a.jti and a.jti in self.revoked_jtis]
            for u in closed:
                agent = self.agents.pop(u)
                asyncio.get_running_loop().create_task(agent.ws.close(code=4003, reason="token revoked"))
            log.info("admin revoke jti count=%d closed_agents=%d", len(jtis), len(closed))
            return {"type": "ok", "revoked": len(jtis), "closed_agents": len(closed)}
        user = str(message.get("user") or "")
        if not USER_RE.match(user):
            return {"type": "error", "reason": "bad user"}
        if kind == "set_tokens":
            agent, sandbox = message.get("agent"), message.get("sandbox")
            if not (isinstance(agent, str) and isinstance(sandbox, str) and len(agent) >= 16 and len(sandbox) >= 16 and agent != sandbox):
                return {"type": "error", "reason": "tokens must be two distinct strings of at least 16 chars"}
            self.tokens[user] = {"agent": agent, "sandbox": sandbox}
            self.revoked_users.discard(user)
            self.persist_tokens()
            log.info("admin set tokens user=%s", user)
            return {"type": "ok", "user": user}
        if kind == "revoke":
            self.tokens.pop(user, None)
            self.revoked_users.add(user)  # JWT 不查表，靠这个拒到重新登记为止
            agent = self.agents.pop(user, None)
            self.persist_tokens()
            log.info("admin revoke user=%s agent_online=%s", user, agent is not None)
            if agent is not None:
                asyncio.get_running_loop().create_task(agent.ws.close(code=4003, reason="revoked"))
            return {"type": "ok", "user": user}
        return {"type": "error", "reason": f"unknown admin message {kind}"}

    def persist_tokens(self) -> None:
        if not self.state_path:
            return
        tmp = self.state_path + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"tokens": self.tokens, "revoked_jtis": sorted(self.revoked_jtis),
                       "revoked_users": sorted(self.revoked_users), "public_key_pem": self.public_key_pem}, f)
        os.replace(tmp, self.state_path)

    def load_state(self) -> None:
        """重启回读管理通道登记过的东西（令牌、吊销表、公钥）；静态表里的同名用户以静态为准。"""
        if not self.state_path or not os.path.exists(self.state_path):
            return
        with open(self.state_path) as f:
            state = json.load(f)
        if not isinstance(state, dict):
            return
        if "tokens" not in state:  # 旧格式：整个文件就是令牌表
            state = {"tokens": state}
        for user, entry in (state.get("tokens") or {}).items():
            self.tokens.setdefault(user, entry)
        self.revoked_jtis.update(state.get("revoked_jtis") or [])
        self.revoked_users.update(state.get("revoked_users") or [])
        if not self.public_key_pem and state.get("public_key_pem"):
            self.public_key_pem = state["public_key_pem"]

    async def handle_admin(self, ws: ServerConnection) -> None:
        hello = await self._hello(ws)
        if hello.get("type") != "hello" or hello.get("role") != "admin" or not self.admin_token or not secrets.compare_digest(str(hello.get("token") or ""), self.admin_token):
            self.stats["rejected"] += 1
            await ws.send(json.dumps({"type": "reject", "reason": "admin auth failed"}))
            await ws.close(code=4001, reason="admin auth failed")
            return
        await ws.send(json.dumps({"type": "welcome", "relay": RELAY_NAME, "proto": RELAY_PROTOCOL, "role": "admin"}))
        async for raw in ws:
            try:
                message = json.loads(raw)
            except (TypeError, ValueError):
                await ws.send(json.dumps({"type": "error", "reason": "not json"}))
                continue
            reply = self.admin_apply(message if isinstance(message, dict) else {})
            await ws.send(json.dumps(reply))

    def process_request(self, connection, request):
        if request.path == "/healthz":
            body = json.dumps({"ok": True, "relay": RELAY_NAME, "proto": RELAY_PROTOCOL, "agents": len(self.agents), **self.stats}).encode()
            return connection.respond(HTTPStatus.OK, body.decode() + "\n")
        return None


def load_tokens(path: str | None, state_path: str | None = None) -> dict[str, dict[str, str]]:
    if not path:
        raw = os.environ.get("RELAY_TOKENS_JSON", "{}")
        tokens = json.loads(raw)
    else:
        with open(path) as f:
            tokens = json.load(f)
    # 管理通道登记过的令牌（重启后回读）；静态表里的同名用户以静态为准
    if state_path:
        relay = Relay(tokens=tokens, state_path=state_path)
        relay.load_state()
        tokens = relay.tokens
    return tokens


async def main():
    logging.basicConfig(level=os.environ.get("RELAY_LOG", "INFO"), format="%(asctime)s %(levelname)s %(message)s")
    host = os.environ.get("RELAY_HOST", "127.0.0.1")
    port = int(os.environ.get("RELAY_PORT", "47100"))
    relay = Relay(tokens=load_tokens(os.environ.get("RELAY_TOKENS_FILE")))
    relay.load_state()  # 管理通道登记过的令牌、公钥、吊销表
    if relay.public_key_pem:
        relay.public_key()  # 坏钥在启动时就报
        log.info("jwt verification enabled issuer=%s", relay.jwt_issuer or "(any)")
    if not relay.tokens and not relay.admin_token:
        log.warning("no tokens configured and no admin token: every hello will be rejected")
    stop = asyncio.get_running_loop().create_future()
    for s in (signal.SIGINT, signal.SIGTERM):
        asyncio.get_running_loop().add_signal_handler(s, lambda: stop.done() or stop.set_result(None))
    async with serve(relay.handler, host, port, max_size=None, ping_interval=20, ping_timeout=20, process_request=relay.process_request):
        log.info("listening ws://%s:%d users=%d", host, port, len(relay.tokens))
        await stop
    log.info("stopped")


if __name__ == "__main__":
    asyncio.run(main())
