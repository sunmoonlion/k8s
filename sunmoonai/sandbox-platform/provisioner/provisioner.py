"""沙箱供给器（0003-sandbox，D9 按需拉起）。跑在 sandbox-pool 命名空间，只管这个命名空间。

一用户一个沙箱：PVC（CODEX_HOME，保留）、Secret（厂商 key、会合点令牌、能力令牌、知识 MCP 令牌）、Deployment、
Service、NetworkPolicy。工作台经内网 HTTP 调它（Bearer PROVISIONER_TOKEN）：
  PUT    /sandboxes/{user}   建或更新（幂等）；返回 app_server_url 与能力令牌（只在本次响应里）
  GET    /sandboxes/{user}   状态
  DELETE /sandboxes/{user}   删运行资源；PVC 默认保留（D18），?purge=1 才删
直接用 in-cluster ServiceAccount 调 API server（httpx），不装 kubernetes 客户端。key 只经内存进 Secret，不落日志。
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import secrets
from base64 import b64encode
from pathlib import Path
from typing import Any

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Query
from pydantic import BaseModel, Field

log = logging.getLogger("provisioner")

NAMESPACE = os.environ.get("SANDBOX_NAMESPACE", "sandbox-pool")
SANDBOX_IMAGE = os.environ.get("SANDBOX_IMAGE", "")
RELAY_URL = os.environ.get("RELAY_URL", "ws://relay.edge.svc.cluster.local:47100")
KNOWLEDGE_MCP_URL = os.environ.get("KNOWLEDGE_MCP_URL", "")
KNOWLEDGE_MCP_SHARED_TOKEN = os.environ.get("KNOWLEDGE_MCP_SHARED_TOKEN", "")  # 退路：工作台没配签名密钥时共用；否则 spec 里带按用户签的 JWT（D10）
ENVIRONMENT_ID = os.environ.get("SANDBOX_ENVIRONMENT_ID", "user-pc")
PROVISIONER_TOKEN = os.environ.get("PROVISIONER_TOKEN", "")
K8S_API = os.environ.get("K8S_API", "https://kubernetes.default.svc")
SA_DIR = Path(os.environ.get("K8S_SA_DIR", "/var/run/secrets/kubernetes.io/serviceaccount"))
PVC_SIZE = os.environ.get("SANDBOX_PVC_SIZE", "2Gi")
USER_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,40}$")


class SandboxSpec(BaseModel):
    model_provider: str = Field(default="", max_length=64)
    model: str = Field(default="", max_length=128)
    provider_base_url: str = Field(default="", max_length=512)
    model_key: str = Field(min_length=8, max_length=512)
    relay_token: str = Field(min_length=16, max_length=512)
    relay_user: str = Field(min_length=1, max_length=64)
    knowledge_mcp_token: str | None = Field(default=None, max_length=512)


def sandbox_name(user: str) -> str:
    if not USER_RE.match(user):
        raise HTTPException(status_code=422, detail="user must be a short lowercase DNS label")
    return f"sandbox-{user}"


def require_token(authorization: str | None = Header(default=None)) -> None:
    scheme, _, token = (authorization or "").partition(" ")
    if not PROVISIONER_TOKEN or scheme.lower() != "bearer" or not secrets.compare_digest(token, PROVISIONER_TOKEN):
        raise HTTPException(status_code=401, detail="provisioner token required")


class KubeClient:
    """够用的 API server 客户端：get / create / replace / delete 四个动作，命名空间固定。"""

    def __init__(self, base_url: str = K8S_API, token: str | None = None, verify: Any = None, transport: httpx.BaseTransport | None = None) -> None:
        if token is None and (SA_DIR / "token").is_file():
            token = (SA_DIR / "token").read_text().strip()
        if verify is None:
            ca = SA_DIR / "ca.crt"
            verify = str(ca) if ca.is_file() else True
        self.client = httpx.AsyncClient(
            base_url=base_url,
            headers={"Authorization": f"Bearer {token or ''}", "Accept": "application/json"},
            verify=verify,
            transport=transport,
            timeout=30,
        )

    @staticmethod
    def path(kind: str, name: str | None = None) -> str:
        group = {
            "secrets": "/api/v1",
            "persistentvolumeclaims": "/api/v1",
            "services": "/api/v1",
            "pods": "/api/v1",
            "deployments": "/apis/apps/v1",
            "networkpolicies": "/apis/networking.k8s.io/v1",
        }[kind]
        base = f"{group}/namespaces/{NAMESPACE}/{kind}"
        return f"{base}/{name}" if name else base

    async def get(self, kind: str, name: str) -> dict[str, Any] | None:
        r = await self.client.get(self.path(kind, name))
        if r.status_code == 404:
            return None
        r.raise_for_status()
        return r.json()

    async def list(self, kind: str, selector: str) -> list[dict[str, Any]]:
        r = await self.client.get(self.path(kind), params={"labelSelector": selector})
        r.raise_for_status()
        return r.json().get("items", [])

    async def apply(self, kind: str, body: dict[str, Any]) -> dict[str, Any]:
        name = body["metadata"]["name"]
        current = await self.get(kind, name)
        if current is None:
            r = await self.client.post(self.path(kind), json=body)
        else:
            body = {**body, "metadata": {**body["metadata"], "resourceVersion": current["metadata"]["resourceVersion"]}}
            if kind == "persistentvolumeclaims":
                return current  # PVC 不可变，存在即复用（D18 保留）
            if kind == "services" and current.get("spec", {}).get("clusterIP"):
                body["spec"]["clusterIP"] = current["spec"]["clusterIP"]
            r = await self.client.put(self.path(kind, name), json=body)
        r.raise_for_status()
        return r.json()

    async def delete(self, kind: str, name: str) -> bool:
        r = await self.client.request("DELETE", self.path(kind, name), json={"propagationPolicy": "Foreground"})
        if r.status_code == 404:
            return False
        r.raise_for_status()
        return True


def labels(user: str) -> dict[str, str]:
    return {"app": "sandbox", "user": user, "sunmoonai.com/managed-by": "sandbox-provisioner"}


def render(user: str, spec: SandboxSpec, app_server_token: str) -> dict[str, dict[str, Any]]:
    """从演示清单抽出来的模板；名字与标签按用户。"""
    name = sandbox_name(user)
    meta = lambda n: {"name": n, "namespace": NAMESPACE, "labels": labels(user)}  # noqa: E731
    data = {
        "model-key": spec.model_key,
        "relay-token": spec.relay_token,
        "app-server-token": app_server_token,
        "knowledge-token": spec.knowledge_mcp_token or KNOWLEDGE_MCP_SHARED_TOKEN or "",
    }
    secret = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": meta(name),
        "type": "Opaque",
        "data": {k: b64encode(v.encode()).decode() for k, v in data.items()},
    }
    pvc = {
        "apiVersion": "v1",
        "kind": "PersistentVolumeClaim",
        "metadata": meta(f"{name}-codex-home"),
        "spec": {"accessModes": ["ReadWriteOnce"], "resources": {"requests": {"storage": PVC_SIZE}}},
    }
    env = [
        {"name": "RELAY_URL", "value": RELAY_URL},
        {"name": "RELAY_USER", "value": spec.relay_user},
        {"name": "ENVIRONMENT_ID", "value": ENVIRONMENT_ID},
        {"name": "APP_SERVER_TOKEN_FILE", "value": "/secrets/app-server/token"},
        {"name": "RELAY_TOKEN", "valueFrom": {"secretKeyRef": {"name": name, "key": "relay-token"}}},
        {"name": "OPENAI_API_KEY", "valueFrom": {"secretKeyRef": {"name": name, "key": "model-key"}}},
    ]
    if spec.model_provider:
        env += [
            {"name": "MODEL_PROVIDER", "value": spec.model_provider},
            {"name": "MODEL", "value": spec.model},
            {"name": "PROVIDER_BASE_URL", "value": spec.provider_base_url},
        ]
    if KNOWLEDGE_MCP_URL and data["knowledge-token"]:
        env += [
            {"name": "KNOWLEDGE_MCP_URL", "value": KNOWLEDGE_MCP_URL},
            {"name": "KNOWLEDGE_MCP_TOKEN", "valueFrom": {"secretKeyRef": {"name": name, "key": "knowledge-token"}}},
        ]
    # Secret 内容变了才滚动：把摘要放进 pod 注解
    digest = hashlib.sha256(json.dumps(secret["data"], sort_keys=True).encode()).hexdigest()[:16]
    deployment = {
        "apiVersion": "apps/v1",
        "kind": "Deployment",
        "metadata": meta(name),
        "spec": {
            "replicas": 1,
            "strategy": {"type": "Recreate"},
            "selector": {"matchLabels": {"app": "sandbox", "user": user}},
            "template": {
                "metadata": {"labels": labels(user), "annotations": {"sunmoonai.com/secret-sha256": digest}},
                "spec": {
                    "securityContext": {"runAsUser": 10001, "runAsGroup": 10001, "fsGroup": 10001},
                    "containers": [
                        {
                            "name": "codex",
                            "image": SANDBOX_IMAGE,
                            "env": env,
                            "ports": [{"name": "app-server", "containerPort": 47800}],
                            "volumeMounts": [
                                {"name": "codex-home", "mountPath": "/data/codex"},
                                {"name": "app-server-token", "mountPath": "/secrets/app-server", "readOnly": True},
                            ],
                            "resources": {"requests": {"cpu": "100m", "memory": "256Mi"}, "limits": {"cpu": "1", "memory": "1Gi"}},
                            "readinessProbe": {"tcpSocket": {"port": 47800}, "initialDelaySeconds": 3},
                        }
                    ],
                    "volumes": [
                        {"name": "codex-home", "persistentVolumeClaim": {"claimName": f"{name}-codex-home"}},
                        {
                            "name": "app-server-token",
                            "secret": {"secretName": name, "items": [{"key": "app-server-token", "path": "token"}], "defaultMode": 0o400},
                        },
                    ],
                },
            },
        },
    }
    service = {
        "apiVersion": "v1",
        "kind": "Service",
        "metadata": meta(name),
        "spec": {"selector": {"app": "sandbox", "user": user}, "ports": [{"name": "app-server", "port": 47800, "targetPort": 47800}]},
    }
    policy = {
        "apiVersion": "networking.k8s.io/v1",
        "kind": "NetworkPolicy",
        "metadata": meta(name),
        "spec": {
            "podSelector": {"matchLabels": {"app": "sandbox", "user": user}},
            "policyTypes": ["Ingress", "Egress"],
            "ingress": [
                {
                    "from": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "app-platform-dev"}}}],
                    "ports": [{"protocol": "TCP", "port": 47800}],
                }
            ],
            "egress": [
                {
                    "to": [{"namespaceSelector": {}, "podSelector": {"matchLabels": {"k8s-app": "kube-dns"}}}],
                    "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}],
                },
                {"ports": [{"protocol": "TCP", "port": 443}]},
                {
                    "to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "app-platform-dev"}}}],
                    "ports": [{"protocol": "TCP", "port": 8000}],
                },
                {
                    "to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "edge"}}}],
                    "ports": [{"protocol": "TCP", "port": 47100}],
                },
            ],
        },
    }
    return {"secret": secret, "pvc": pvc, "deployment": deployment, "service": service, "policy": policy}


KINDS = {"secret": "secrets", "pvc": "persistentvolumeclaims", "deployment": "deployments", "service": "services", "policy": "networkpolicies"}


class Provisioner:
    def __init__(self, kube: KubeClient) -> None:
        self.kube = kube

    async def upsert(self, user: str, spec: SandboxSpec) -> dict[str, Any]:
        name = sandbox_name(user)
        existing = await self.kube.get("secrets", name)
        token = None
        if existing:
            import base64

            token = base64.b64decode(existing["data"].get("app-server-token", "")).decode() or None
        token = token or secrets.token_urlsafe(32)
        docs = render(user, spec, token)
        for key in ("secret", "pvc", "deployment", "service", "policy"):
            await self.kube.apply(KINDS[key], docs[key])
        status = await self.status(user)
        return {
            "user": user,
            "name": name,
            "app_server_url": f"ws://{name}.{NAMESPACE}.svc.cluster.local:47800",
            "app_server_token": token,
            "created": existing is None,
            **status,
        }

    async def status(self, user: str) -> dict[str, Any]:
        name = sandbox_name(user)
        deployment = await self.kube.get("deployments", name)
        if deployment is None:
            return {"status": "absent", "ready": False}
        st = deployment.get("status", {})
        ready = int(st.get("availableReplicas") or 0) >= 1
        pods = await self.kube.list("pods", f"app=sandbox,user={user}")
        phases = [p.get("status", {}).get("phase") for p in pods]
        return {"status": "ready" if ready else "starting", "ready": ready, "pods": phases}

    async def delete(self, user: str, purge: bool) -> dict[str, Any]:
        name = sandbox_name(user)
        removed = {}
        for key in ("deployment", "service", "policy", "secret"):
            removed[key] = await self.kube.delete(KINDS[key], name)
        removed["pvc"] = await self.kube.delete("persistentvolumeclaims", f"{name}-codex-home") if purge else False
        return {"user": user, "removed": removed, "pvc_kept": not purge}


def create_app(provisioner: Provisioner | None = None) -> FastAPI:
    app = FastAPI(title="sandbox-provisioner", docs_url=None, redoc_url=None, openapi_url=None)
    state = {"provisioner": provisioner}

    def get_provisioner() -> Provisioner:
        if state["provisioner"] is None:
            if not SANDBOX_IMAGE:
                raise HTTPException(status_code=503, detail="SANDBOX_IMAGE not configured")
            state["provisioner"] = Provisioner(KubeClient())
        return state["provisioner"]

    @app.get("/healthz")
    async def healthz() -> dict[str, Any]:
        return {"ok": True, "namespace": NAMESPACE, "image_configured": bool(SANDBOX_IMAGE)}

    @app.put("/sandboxes/{user}", dependencies=[Depends(require_token)])
    async def put_sandbox(user: str, spec: SandboxSpec, prov: Provisioner = Depends(get_provisioner)) -> dict[str, Any]:
        try:
            return await prov.upsert(user, spec)
        except httpx.HTTPStatusError as exc:
            log.error("kube api %s %s -> %s", exc.request.method, exc.request.url.path, exc.response.status_code)
            raise HTTPException(status_code=502, detail=f"kubernetes api returned {exc.response.status_code}") from exc

    @app.get("/sandboxes/{user}", dependencies=[Depends(require_token)])
    async def get_sandbox(user: str, prov: Provisioner = Depends(get_provisioner)) -> dict[str, Any]:
        return {"user": user, "name": sandbox_name(user), **await prov.status(user)}

    @app.delete("/sandboxes/{user}", dependencies=[Depends(require_token)])
    async def delete_sandbox(user: str, purge: bool = Query(default=False), prov: Provisioner = Depends(get_provisioner)) -> dict[str, Any]:
        return await prov.delete(user, purge)

    return app


app = create_app()
