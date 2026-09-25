"""供给器：对着一个假 API server 验幂等建立、令牌复用、删除保留 PVC、鉴权。"""

from __future__ import annotations

import base64
import json
import os
import sys
from pathlib import Path

import httpx
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.environ.setdefault("PROVISIONER_TOKEN", "prov-token-0123456789")
os.environ.setdefault("SANDBOX_IMAGE", "harbor.example/app-images/sandbox@sha256:" + "a" * 64)
os.environ.setdefault("KNOWLEDGE_MCP_URL", "http://knowledge-backend.app-platform-dev.svc.cluster.local:8000/api/mcp/knowledge")
import provisioner as target  # noqa: E402


class FakeApiServer:
    """内存里的命名空间对象表；POST 建、PUT 换、GET 取、DELETE 删，带 resourceVersion。"""

    def __init__(self) -> None:
        self.objects: dict[tuple[str, str], dict] = {}
        self.calls: list[str] = []
        self.rv = 0

    def handler(self, request: httpx.Request) -> httpx.Response:
        parts = request.url.path.strip("/").split("/")
        kind = parts[parts.index("namespaces") + 2]
        name = parts[parts.index("namespaces") + 3] if len(parts) > parts.index("namespaces") + 3 else None
        self.calls.append(f"{request.method} {kind}/{name or ''}")
        if request.method == "GET" and name is None:
            selector = dict(request.url.params).get("labelSelector", "")
            wanted = dict(kv.split("=") for kv in selector.split(",") if kv)
            items = [o for (k, _), o in self.objects.items() if k == kind and all(o["metadata"]["labels"].get(a) == b for a, b in wanted.items())]
            return httpx.Response(200, json={"items": items})
        if request.method == "GET":
            obj = self.objects.get((kind, name))
            return httpx.Response(200, json=obj) if obj else httpx.Response(404, json={"code": 404})
        if request.method == "POST":
            body = json.loads(request.content)
            self.rv += 1
            body["metadata"]["resourceVersion"] = str(self.rv)
            if kind == "deployments":
                body["status"] = {"availableReplicas": 1}
            if kind == "services":
                body["spec"]["clusterIP"] = "10.0.0.9"
            self.objects[(kind, body["metadata"]["name"])] = body
            return httpx.Response(201, json=body)
        if request.method == "PUT":
            body = json.loads(request.content)
            current = self.objects.get((kind, name))
            if current is None:
                return httpx.Response(404, json={"code": 404})
            if body["metadata"].get("resourceVersion") != current["metadata"]["resourceVersion"]:
                return httpx.Response(409, json={"code": 409})
            self.rv += 1
            body["metadata"]["resourceVersion"] = str(self.rv)
            body.setdefault("status", current.get("status", {}))
            self.objects[(kind, name)] = body
            return httpx.Response(200, json=body)
        if request.method == "DELETE":
            return httpx.Response(200, json={}) if self.objects.pop((kind, name), None) else httpx.Response(404, json={"code": 404})
        return httpx.Response(405)


@pytest.fixture
def stack():
    api = FakeApiServer()
    kube = target.KubeClient(base_url="https://kube.test", token="sa", verify=False, transport=httpx.MockTransport(api.handler))
    app = target.create_app(target.Provisioner(kube))
    return api, app


def spec(**over):
    return {"model_provider": "kimi", "model": "kimi-k3", "provider_base_url": "https://api.moonshot.cn/v1",
            "model_key": "sk-test-key-1234567890", "relay_token": "relay-sandbox-token-abc", "relay_user": "u-demo", **over}


@pytest.mark.anyio
async def test_put_is_idempotent_and_keeps_the_capability_token(stack):
    api, app = stack
    headers = {"Authorization": "Bearer prov-token-0123456789"}
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://p") as c:
        first = await c.put("/sandboxes/u-demo", json=spec(), headers=headers)
        assert first.status_code == 200, first.text
        body = first.json()
        assert body["created"] is True and body["status"] == "ready"
        assert body["app_server_url"] == "ws://sandbox-u-demo.sandbox-pool.svc.cluster.local:47800"
        token = body["app_server_token"]
        assert len(token) >= 32
        kinds = {k for k, _ in api.objects}
        assert kinds == {"secrets", "persistentvolumeclaims", "deployments", "services", "networkpolicies"}
        secret = api.objects[("secrets", "sandbox-u-demo")]
        assert base64.b64decode(secret["data"]["model-key"]).decode() == "sk-test-key-1234567890"
        assert base64.b64decode(secret["data"]["app-server-token"]).decode() == token
        dep = api.objects[("deployments", "sandbox-u-demo")]
        env = {e["name"]: e for e in dep["spec"]["template"]["spec"]["containers"][0]["env"]}
        assert env["OPENAI_API_KEY"]["valueFrom"]["secretKeyRef"]["key"] == "model-key"
        assert env["MODEL_PROVIDER"]["value"] == "kimi"
        assert "KNOWLEDGE_MCP_URL" not in env  # no knowledge token given and no shared token configured
        # second PUT with a rotated model key: same capability token, secret replaced, PVC untouched
        pvc_rv = api.objects[("persistentvolumeclaims", "sandbox-u-demo-codex-home")]["metadata"]["resourceVersion"]
        second = await c.put("/sandboxes/u-demo", json=spec(model_key="sk-rotated-key-0987654321"), headers=headers)
        assert second.json()["created"] is False
        assert second.json()["app_server_token"] == token
        assert base64.b64decode(api.objects[("secrets", "sandbox-u-demo")]["data"]["model-key"]).decode() == "sk-rotated-key-0987654321"
        assert api.objects[("persistentvolumeclaims", "sandbox-u-demo-codex-home")]["metadata"]["resourceVersion"] == pvc_rv
        # status
        st = await c.get("/sandboxes/u-demo", headers=headers)
        assert st.json()["status"] == "ready"
        # delete keeps the PVC unless purge
        gone = await c.delete("/sandboxes/u-demo", headers=headers)
        assert gone.json()["pvc_kept"] is True and ("persistentvolumeclaims", "sandbox-u-demo-codex-home") in api.objects
        assert ("deployments", "sandbox-u-demo") not in api.objects and ("secrets", "sandbox-u-demo") not in api.objects
        purged = await c.delete("/sandboxes/u-demo", params={"purge": "true"}, headers=headers)
        assert purged.json()["removed"]["pvc"] is True
        assert (await c.get("/sandboxes/u-demo", headers=headers)).json()["status"] == "absent"


@pytest.mark.anyio
async def test_auth_and_user_name_are_enforced(stack):
    _, app = stack
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://p") as c:
        assert (await c.put("/sandboxes/u-demo", json=spec())).status_code == 401
        assert (await c.put("/sandboxes/u-demo", json=spec(), headers={"Authorization": "Bearer nope"})).status_code == 401
        bad = await c.put("/sandboxes/Bad_User", json=spec(), headers={"Authorization": "Bearer prov-token-0123456789"})
        assert bad.status_code == 422
        short = await c.put("/sandboxes/u-demo", json=spec(model_key="short"), headers={"Authorization": "Bearer prov-token-0123456789"})
        assert short.status_code == 422
        assert (await c.get("/healthz")).json()["ok"] is True


def test_secret_digest_rolls_the_pod_only_when_secret_changes():
    a = target.render("u1", target.SandboxSpec(**spec()), "tok" * 12)
    b = target.render("u1", target.SandboxSpec(**spec()), "tok" * 12)
    c = target.render("u1", target.SandboxSpec(**spec(model_key="sk-other-key-1234567890")), "tok" * 12)
    ann = lambda d: d["deployment"]["spec"]["template"]["metadata"]["annotations"]["sunmoonai.com/secret-sha256"]  # noqa: E731
    assert ann(a) == ann(b) != ann(c)
    assert "sk-" not in json.dumps(a["deployment"])


def test_pod_template_is_readable_by_the_non_root_user():
    """KIND 07：Secret 0400 读不到、PVC 直接当 CODEX_HOME 时 chmod 失败。模板必须 0440 + fsGroup，PVC 挂 /data。"""
    import provisioner as p

    spec = p.SandboxSpec(
        model_provider="kimi", model="kimi-k3", provider_base_url="https://api.moonshot.cn/v1",
        model_key="sk-test-0123456789abcdef", relay_token="relay-token-0123456789", relay_user="u-abc",
    )
    docs = p.render("u-abc", spec, "cap-token-0123456789")
    dep = next(d for d in docs.values() if d.get("kind") == "Deployment")
    pod = dep["spec"]["template"]["spec"]
    assert pod["securityContext"]["fsGroup"] == 10001
    mounts = {m["name"]: m["mountPath"] for m in pod["containers"][0]["volumeMounts"]}
    assert mounts["codex-home"] == "/data"
    secret_vols = [v["secret"] for v in pod["volumes"] if "secret" in v]
    assert secret_vols and all(v["defaultMode"] == 0o440 for v in secret_vols)
