"""R6 下线旧对象（k8s/docs/rename.md R6）：info、knowledge 改名前留在集群和宿主上的东西，先列、再删、再列。

用法（本地机 k8s 仓根，bash；要 root，并进 PID 1 的挂载命名空间——数据盘只在那边可见，同 infrastructure/Makefile）：
  R6='sudo -n nsenter --target 1 --mount --wd=$PWD -- infrastructure/.venv/bin/python docs/rename-tools/r6_cleanup.py'
  $R6 list                              # 全部类别只列不删
  $R6 list postgresql                   # 只列一类
  $R6 delete postgresql --confirm postgresql   # 删一类：先列、按下面的清单删、再列

只删本文件里写死的旧名字（2026-10-15 从改名前的配置 4be661df 逐个抄出）；列出来但不在清单里的只标「不在清单，不删」，交 Opus 看。
每类删之前核归属记号（PostgreSQL 注释、RabbitMQ vhost 说明、Casdoor 服务应用说明、k8s 的旧阶段标签），对不上整类不删。
不打印任何口令、令牌、哈希；远端报错只报类别名。
"""

from __future__ import annotations

import argparse
import base64
import http.cookiejar
import json
import os
import re
import selectors
import shutil
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[2]
INFRA = REPO / "infrastructure"
TOOLS = INFRA / ".tools" / "bin"


def cfg(path: str) -> dict:
    return yaml.safe_load((REPO / path).read_text(encoding="utf-8")) or {}


SITE = cfg("infrastructure/environments/kind/site.yaml")
CLUSTER = SITE["cluster_name"]
DATA_NS, MSG_NS, APP_NS = SITE["data_namespace"], SITE["messaging_namespace"], SITE["app_namespace"]
KUBECONFIG = cfg("infrastructure/cluster/config.yaml")["cluster_kubeconfig"]
SERVICES_DIR = Path(cfg("infrastructure/services/config.yaml")["services_config_dir"])
REGISTRY = cfg("infrastructure/registry/config.yaml")
REGISTRY_DIR = Path(REGISTRY["registry_config_dir"])
RAGFLOW_PORT = cfg("gitops/components/data-platform/ragflow/config.yaml")["ragflow_port"]
CASDOOR_HOST = cfg("gitops/components/app-platform/auth-app/casdoor/config.yaml")["casdoor_hostname"]

# ---- 清单（改名前 4be661df 的配置）----
OLD_APPS = ("info", "knowledge")
OLD_STAGES = [f"info-{s}" for s in ("admin", "database", "migration", "redis", "rabbitmq", "identity", "runtime", "storage", "service-identity", "web")] + \
             [f"knowledge-{s}" for s in ("admin", "database", "migration", "redis", "rabbitmq", "identity", "runtime", "provider", "web")]
# 共享组件阶段里改了名的对象（新阶段不再声明它们，prune: false 不会删；旧阶段标签选不中）——R5.1 渲染比对与 4be661df 扫描得出
K8S_RENAMED_IN_SHARED = [
    ("services", APP_NS, "knowledge-tls", "traefik"),
    ("ingresses.networking.k8s.io", APP_NS, "knowledge-service-access", "traefik"),
    ("secrets", APP_NS, "investment-knowledge-service", "investment-runtime"),
]
PG_DATABASES = {"info": f"{CLUSTER}/info", "knowledge": f"{CLUSTER}/knowledge"}
PG_ROLES = {"info_runtime": f"{CLUSTER}/info", "info_migrator": f"{CLUSTER}/info",
            "knowledge_runtime": f"{CLUSTER}/knowledge", "knowledge_migrator": f"{CLUSTER}/knowledge"}
REDIS_USERS = ["info_runtime", "knowledge_runtime"]
REDIS_PATTERNS = ["info:*", "knowledge:*"]
MQ_VHOSTS = {"info": "sunmoon:info:managed-by-gitops", "knowledge": "sunmoon:knowledge:managed-by-gitops"}
MQ_USERS = ["info_runtime", "knowledge_runtime"]
S3_USERS = ["info_storage", "knowledge_source_reader"]
S3_POLICIES = ["info-originals", "knowledge-source-read"]
S3_BUCKETS = ["info-originals"]
RAGFLOW_DATASETS = [f"{CLUSTER}-knowledge-default"]
CASDOOR_APPS = {  # 名字 → (clientId, 说明里应有的记号或 None)
    "sunmoonai-info-web": (f"{CLUSTER}-info-web", None),
    "sunmoonai-info-admin": (f"{CLUSTER}-info-admin", None),
    "sunmoonai-knowledge-web": (f"{CLUSTER}-knowledge-web", None),
    "sunmoonai-knowledge-admin": (f"{CLUSTER}-knowledge-admin", None),
    "sunmoonai-info-knowledge-ingest": ("sunmoon-info-knowledge-ingest", "sunmoon:info:knowledge:managed-by-gitops"),
    "sunmoonai-investment-knowledge-retrieve": ("sunmoon-investment-knowledge-retrieve", "sunmoon:investment:knowledge:managed-by-gitops"),
}
CASDOOR_ORGS = ["sunmoon-workload-info-knowledge", "sunmoon-workload-investment-knowledge"]
PRIVATE_DIRS = [f"/etc/sunmoon/applications/{CLUSTER}/{a}" for a in OLD_APPS] + \
               [f"/mnt/sunmoon-data/backups/applications/{CLUSTER}/{a}" for a in OLD_APPS] + \
               [str(INFRA / ".build" / "components" / "app-platform" / f"{a}-app") for a in OLD_APPS]
HARBOR_PROJECT = "platform"
HARBOR_REPOS = [f"{a}-{c}" for a in OLD_APPS for c in ("backend", "web-frontend", "admin-frontend")]
OLD_NAME = re.compile(r"^(info|knowledge)([-_.]|$)")

JOB_NAMESPACES = (APP_NS, DATA_NS, MSG_NS)
CATEGORIES = ["k8s", "job-history", "postgresql", "redis", "rabbitmq", "object-storage", "ragflow", "casdoor", "private", "harbor", "harbor-gc"]


class Stop(Exception):
    pass


def require(ok, message):
    if not ok:
        raise Stop(message)


def env():
    e = {k: v for k, v in os.environ.items() if k.lower() not in ("http_proxy", "https_proxy", "all_proxy")}
    e["NO_PROXY"] = "*"
    return e


def run(argv, stdin=None, timeout=300, what=None):
    out = subprocess.run(argv, input=stdin, capture_output=True, text=True, timeout=timeout, env=env())
    if out.returncode != 0:
        raise Stop(f"{what or argv[0]} 失败（exit {out.returncode}）: {out.stderr.strip()[-400:]}")
    return out.stdout


def kube(*args, stdin=None, timeout=300):
    return run([str(TOOLS / "kubectl"), f"--kubeconfig={KUBECONFIG}", f"--context=kind-{CLUSTER}", "--request-timeout=60s", *args],
               stdin=stdin, timeout=timeout, what="kubectl " + " ".join(a for a in args[:3] if not a.startswith("-")))


def kexec(ns, target, container, script, stdin=None, timeout=300):
    args = ["-n", ns, "exec", "-i", target] + (["-c", container] if container else []) + ["--", "/bin/sh", "-ec", script]
    return kube(*args, stdin=stdin, timeout=timeout)


def private_yaml(path: Path) -> dict:
    require(path.is_file() and not path.is_symlink(), f"私有文件不在或是链接: {path}")
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


class Tunnel:
    """kubectl port-forward 到 127.0.0.1 的随机端口。"""

    def __init__(self, ns, service, port):
        self.argv = [str(TOOLS / "kubectl"), f"--kubeconfig={KUBECONFIG}", f"--context=kind-{CLUSTER}", "-n", ns,
                     "port-forward", "--address=127.0.0.1", f"service/{service}", f"0:{port}"]

    def __enter__(self):
        self.proc = subprocess.Popen(self.argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, env=env())
        deadline = time.monotonic() + 20
        with selectors.DefaultSelector() as sel:
            sel.register(self.proc.stdout, selectors.EVENT_READ)
            while time.monotonic() < deadline and self.proc.poll() is None:
                if sel.select(timeout=0.5):
                    m = re.search(r"Forwarding from 127\.0\.0\.1:(\d+)", self.proc.stdout.readline())
                    if m:
                        self.port = int(m.group(1))
                        return self
        self.__exit__()
        raise Stop("port-forward 没起来: " + " ".join(self.argv[-2:]))

    def __exit__(self, *exc):
        self.proc.terminate()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()


# ---------------------------------------------------------------- k8s
def k8s_types():
    names = kube("api-resources", "--namespaced=true", "--verbs=list,delete", "-o", "name").split()
    return [n for n in names if n.split(".")[0] not in ("events", "pods", "endpoints", "endpointslices", "replicasets", "controllerrevisions")]


def k8s_list():
    current = REPO / "gitops" / "clusters" / "kind" / "stages.yaml"
    live_stage_names = {d["metadata"]["name"] for d in yaml.safe_load_all(current.read_text()) if d}
    ks = json.loads(kube("-n", "flux-system", "get", "kustomizations.kustomize.toolkit.fluxcd.io", "-o", "json"))["items"]
    stages = []
    for k in ks:
        name = k["metadata"]["name"]
        if OLD_NAME.match(name):
            ready = next((c.get("status") for c in k.get("status", {}).get("conditions", []) if c.get("type") == "Ready"), "?")
            stages.append({"name": name, "ready": ready, "listed": name in OLD_STAGES, "in_current_stages": name in live_stage_names})
    selector = "kustomize.toolkit.fluxcd.io/namespace=flux-system,kustomize.toolkit.fluxcd.io/name in (" + ",".join(OLD_STAGES) + ")"
    objects, unlabeled = [], []
    for t in k8s_types():
        for item in json.loads(kube("get", t, "-A", "-l", selector, "-o", "json"))["items"]:
            m = item["metadata"]
            objects.append({"type": t, "namespace": m["namespace"], "name": m["name"], "stage": m["labels"]["kustomize.toolkit.fluxcd.io/name"]})
    for t, ns, name, stage in K8S_RENAMED_IN_SHARED:
        got = json.loads(kube("-n", ns, "get", t, "--field-selector", f"metadata.name={name}", "-o", "json"))["items"]
        for item in got:
            label = item["metadata"].get("labels", {}).get("kustomize.toolkit.fluxcd.io/name")
            objects.append({"type": t, "namespace": ns, "name": name, "stage": label, "renamed_in_shared": True,
                            "still_declared": still_declared(name), "expected_stage": label == stage})
    seen = {(o["type"], o["namespace"], o["name"]) for o in objects}
    for ns in (APP_NS, DATA_NS, MSG_NS, SITE["sandbox_namespace"], SITE["ingress_namespace"]):
        for t in ("deployments.apps", "jobs.batch", "services", "secrets", "configmaps", "networkpolicies.networking.k8s.io", "ingresses.networking.k8s.io", "serviceaccounts"):
            for item in json.loads(kube("-n", ns, "get", t, "-o", "json"))["items"]:
                if OLD_NAME.match(item["metadata"]["name"]) and (t, ns, item["metadata"]["name"]) not in seen:
                    unlabeled.append({"type": t, "namespace": ns, "name": item["metadata"]["name"], "listed": False})
    pods = [p["metadata"]["namespace"] + "/" + p["metadata"]["name"] for p in json.loads(kube(
        "get", "pods", "-A", "-l", "app.kubernetes.io/part-of in (info,knowledge)", "-o", "json"))["items"]]
    return {"flux_kustomizations": stages, "objects": objects, "unlabeled_same_prefix": unlabeled, "pods_part_of_old_apps": pods}


def still_declared(name):
    """现行 gitops 声明（含加密文件里明文的 metadata）里还有没有这个名字。"""
    out = subprocess.run(["git", "-C", str(REPO), "grep", "-l", "-w", "-F", name, "--", "gitops/components/**/*.yaml", "gitops/clusters/**/*.yaml"],
                         capture_output=True, text=True)
    return bool(out.stdout.strip())


def k8s_delete(found):
    for o in found["objects"]:
        if o.get("renamed_in_shared"):
            require(not o["still_declared"] and o["expected_stage"], f'{o["type"]}/{o["name"]} 仍在现行声明里或标签不是预期阶段，整类不删')
    bad = [s["name"] for s in found["flux_kustomizations"] if s["in_current_stages"]]
    require(not bad, "这些 Kustomization 还在现行 stages.yaml 里，整类不删: " + ", ".join(bad))
    names = [s["name"] for s in found["flux_kustomizations"] if s["listed"]]
    if names:  # deletionPolicy: Orphan——只删 Kustomization 本身，对象留下，下面再按标签删
        kube("-n", "flux-system", "delete", "kustomizations.kustomize.toolkit.fluxcd.io", *names, "--wait=true", "--timeout=120s")
    workloads = ("deployments.apps", "statefulsets.apps", "jobs.batch", "cronjobs.batch")
    for first in (True, False):
        by_ns = {}
        for o in found["objects"]:
            if (o["type"] in workloads) == first:
                by_ns.setdefault(o["namespace"], []).append(f'{o["type"]}/{o["name"]}')
        for ns, refs in sorted(by_ns.items()):
            kube("-n", ns, "delete", *refs, "--ignore-not-found", "--cascade=foreground", "--wait=true", "--timeout=300s", timeout=400)
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if not json.loads(kube("get", "pods", "-A", "-l", "app.kubernetes.io/part-of in (info,knowledge)", "-o", "json"))["items"]:
            return
        time.sleep(5)
    raise Stop("旧应用的 Pod 3 分钟内没有全部退出")


# ---------------------------------------------------------------- 历史 Job（所有者 2026-10-15 要求顺带清）
def declared_jobs():
    """现行 gitops 声明里的全部 Job（命名空间, 名字）——这些不能删：Flux 会重建并重跑，阶段健康检查与 application-check 也看它们。"""
    names = subprocess.run(["git", "-C", str(REPO), "ls-files", "gitops/components"], capture_output=True, text=True, check=True).stdout.split()
    out = set()
    for n in names:
        if n.endswith("/workload.yaml"):
            for d in yaml.safe_load_all((REPO / n).read_text(encoding="utf-8")):
                if isinstance(d, dict) and d.get("kind") == "Job":
                    out.add((d["metadata"].get("namespace", ""), d["metadata"]["name"]))
    return out


def jobs_list():
    keep = declared_jobs()
    require(len(keep) > 20, "现行声明里找到的 Job 太少，像是读错了仓，不往下做")
    history, kept, unfinished = [], 0, []
    for ns in JOB_NAMESPACES:
        for j in json.loads(kube("-n", ns, "get", "jobs.batch", "-o", "json"))["items"]:
            name = j["metadata"]["name"]
            if (ns, name) in keep:
                kept += 1
                continue
            done = any(c.get("type") == "Complete" and c.get("status") == "True" for c in j.get("status", {}).get("conditions", []))
            stage = j["metadata"].get("labels", {}).get("kustomize.toolkit.fluxcd.io/name", "")
            (history if done else unfinished).append({"namespace": ns, "name": name, "stage": stage})
    return {"declared_kept": kept, "history_completed": history, "not_completed_listed_only": [dict(u, listed=False) for u in unfinished]}


def jobs_delete(found):
    keep = declared_jobs()
    by_ns = {}
    for j in found["history_completed"]:
        require((j["namespace"], j["name"]) not in keep, f'{j["name"]} 在现行声明里，不删')
        by_ns.setdefault(j["namespace"], []).append("jobs.batch/" + j["name"])
    for ns, refs in sorted(by_ns.items()):
        for i in range(0, len(refs), 50):
            kube("-n", ns, "delete", *refs[i:i + 50], "--ignore-not-found", "--cascade=background", "--wait=true", "--timeout=300s", timeout=400)


# ---------------------------------------------------------------- PostgreSQL
PSQL = 'PGPASSWORD="$(cat /run/auth/password)" exec psql --no-psqlrc -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 -At -F "|" -f -'


def pg_list():
    sql = r"""
SELECT 'db', datname, coalesce(shobj_description(oid,'pg_database'),''), (SELECT count(*) FROM pg_stat_activity a WHERE a.datname=d.datname)::text,
       pg_size_pretty(pg_database_size(oid)) FROM pg_database d WHERE datname ~ '^(info|knowledge)([-_]|$)';
SELECT 'role', rolname, coalesce(shobj_description(oid,'pg_authid'),''), '', '' FROM pg_roles WHERE rolname ~ '^(info|knowledge)([-_]|$)';
"""
    rows = [r.split("|") for r in kexec(DATA_NS, "pod/postgresql-0", "postgresql", PSQL, stdin=sql).splitlines() if r]
    dbs = [{"name": r[1], "owner_mark": r[2], "connections": int(r[3]), "size": r[4], "listed": r[1] in PG_DATABASES} for r in rows if r[0] == "db"]
    roles = [{"name": r[1], "owner_mark": r[2], "listed": r[1] in PG_ROLES} for r in rows if r[0] == "role"]
    return {"databases": dbs, "roles": roles}


def pg_delete(found):
    for d in found["databases"]:
        require(not d["listed"] or d["owner_mark"] == PG_DATABASES[d["name"]], f'库 {d["name"]} 的归属注释不对，整类不删')
    for r in found["roles"]:
        require(not r["listed"] or r["owner_mark"] == PG_ROLES[r["name"]], f'角色 {r["name"]} 的归属注释不对，整类不删')
    sql = "".join(f'DROP DATABASE IF EXISTS "{d["name"]}" WITH (FORCE);\n' for d in found["databases"] if d["listed"])
    sql += "".join(f'DROP ROLE IF EXISTS "{r["name"]}";\n' for r in found["roles"] if r["listed"])
    if sql:
        kexec(DATA_NS, "pod/postgresql-0", "postgresql", PSQL, stdin=sql)


# ---------------------------------------------------------------- Redis
REDIS = 'export REDISCLI_AUTH="$(cat /run/auth/password)"; '


def redis_list():
    users = kexec(DATA_NS, "pod/redis-0", "redis", REDIS + "redis-cli ACL USERS").split()
    keys = {}
    for p in REDIS_PATTERNS:
        keys[p] = int(kexec(DATA_NS, "pod/redis-0", "redis", REDIS + f"redis-cli --scan --pattern '{p}' | wc -l").strip())
    return {"users": [{"name": u, "listed": u in REDIS_USERS} for u in users if OLD_NAME.match(u)], "keys": keys}


def redis_delete(found):
    for p in REDIS_PATTERNS:
        if found["keys"][p]:
            kexec(DATA_NS, "pod/redis-0", "redis", REDIS + f"redis-cli --scan --pattern '{p}' | xargs -r -n 500 redis-cli UNLINK >/dev/null", timeout=600)
    users = [u["name"] for u in found["users"] if u["listed"]]
    if users:
        kexec(DATA_NS, "pod/redis-0", "redis", REDIS + "redis-cli ACL DELUSER " + " ".join(users) + " && redis-cli ACL SAVE")


# ---------------------------------------------------------------- RabbitMQ
def mq(cmd):
    return json.loads(kexec(MSG_NS, "pod/rabbitmq-0", "rabbitmq", f"rabbitmqctl -q {cmd} --formatter json") or "[]")


def mq_list():
    vhosts = []
    for v in mq("list_vhosts name description"):
        if OLD_NAME.match(v["name"]):
            queues = mq(f"list_queues -p {v['name']} name messages")
            vhosts.append({"name": v["name"], "description": v.get("description", ""), "queues": queues, "listed": v["name"] in MQ_VHOSTS})
    users = [{"name": u["user"], "listed": u["user"] in MQ_USERS} for u in mq("list_users") if OLD_NAME.match(u["user"])]
    return {"vhosts": vhosts, "users": users}


def mq_delete(found):
    for v in found["vhosts"]:
        require(not v["listed"] or v["description"] == MQ_VHOSTS[v["name"]], f'vhost {v["name"]} 的说明不是本平台记号，整类不删')
    for v in found["vhosts"]:
        if v["listed"]:
            kexec(MSG_NS, "pod/rabbitmq-0", "rabbitmq", f"rabbitmqctl -q delete_vhost {v['name']}")
    for u in found["users"]:
        if u["listed"]:
            kexec(MSG_NS, "pod/rabbitmq-0", "rabbitmq", f"rabbitmqctl -q delete_user {u['name']}")


# ---------------------------------------------------------------- 对象存储
class S3:
    def __enter__(self):
        secret = private_yaml(SERVICES_DIR / "object-storage.yaml")
        self.tunnel = Tunnel(DATA_NS, "object-storage", 9000).__enter__()
        host = f"object-storage.{DATA_NS}.svc.cluster.local"
        self.folder = tempfile.mkdtemp(prefix="sunmoon-r6-s3-")
        ca = Path(self.folder) / "certs" / "CAs"
        ca.mkdir(parents=True, mode=0o700)
        shutil.copyfile(REGISTRY_DIR / "clients" / "ca.crt", ca / "platform.crt")
        conf = Path(self.folder) / "config.json"
        conf.write_text(json.dumps({"version": "10", "aliases": {"owned": {"url": f"https://{host}:{self.tunnel.port}", "accessKey": secret["root_user"],
                                                                           "secretKey": secret["root_password"], "api": "S3v4", "path": "on"}}}))
        conf.chmod(0o600)
        self.base = [str(TOOLS / "mc"), "--config-dir", self.folder, "--resolve", f"{host}:{self.tunnel.port}=127.0.0.1", "--json"]
        return self

    def __call__(self, *argv, timeout=120):
        out = subprocess.run(self.base + list(argv), capture_output=True, text=True, timeout=timeout, env=dict(env(), HOME="/nonexistent"))
        rows = [json.loads(line) for line in out.stdout.splitlines() if line.strip().startswith("{")]
        # AIStor mc 可能 exit 0 却回 status=error；报错只报操作名，不带远端原文
        require(out.returncode == 0 and all(r.get("status") != "error" for r in rows), "对象存储操作失败: " + " ".join(argv[:3]))
        return rows

    def __exit__(self, *exc):
        shutil.rmtree(self.folder, ignore_errors=True)
        self.tunnel.__exit__()


def s3_list():
    with S3() as mc:
        users = [r.get("accessKey") for r in mc("admin", "user", "ls", "owned")]
        policies = [r.get("policy") or r.get("name") for r in mc("admin", "policy", "ls", "owned")]
        buckets = [r.get("key", "").rstrip("/") for r in mc("ls", "owned")]
        shown = []
        for b in buckets:
            if re.search(r"(info|knowledge)", b):
                try:
                    du = mc("du", "--versions", f"owned/{b}")
                except Stop:  # 老版本 mc 没有 --versions，只报当前版本的量
                    du = mc("du", f"owned/{b}")
                shown.append({"name": b, "objects": du[-1].get("objects") if du else None, "bytes": du[-1].get("size") if du else None, "listed": b in S3_BUCKETS})
    return {"users": [{"name": u, "listed": u in S3_USERS} for u in users if u and OLD_NAME.match(u)],
            "policies": [{"name": p, "listed": p in S3_POLICIES} for p in policies if p and OLD_NAME.match(p)],
            "buckets": shown}


def s3_delete(found):
    with S3() as mc:
        for u in found["users"]:
            if u["listed"]:
                mc("admin", "user", "rm", "owned", u["name"])
        for p in found["policies"]:
            if p["listed"]:
                mc("admin", "policy", "rm", "owned", p["name"])
        for b in found["buckets"]:
            if b["listed"]:
                mc("rm", "--recursive", "--force", "--versions", f"owned/{b['name']}", timeout=1800)
                mc("rb", f"owned/{b['name']}")


# ---------------------------------------------------------------- RAGFlow
RAGFLOW_SCRIPT = r"""
import json,sys,requests
x=json.load(sys.stdin)
s=requests.Session();s.trust_env=False;s.verify='/run/tls/ca.crt';s.headers['Authorization']='Bearer '+x['token']
base=x['base'].rstrip('/')+'/api/v1'
def call(m,p,**k):
    r=s.request(m,base+p,timeout=60,**k);r.raise_for_status();d=r.json()
    assert d.get('code')==0,'provider refused';return d
try:
    rows=[];seen=0
    for page in range(1,101):
        d=call('GET','/datasets',params={'page':page,'page_size':100,'orderby':'create_time','desc':'false'})
        rows+=d['data'];seen+=len(d['data']);total=d.get('total_datasets',d.get('total'))
        if seen>=total or not d['data']:break
    if x['action']=='delete':
        ids=[r['id'] for r in rows if r['name'] in x['names']]
        if ids:call('DELETE','/datasets',json={'ids':ids})
        print(json.dumps({'deleted':len(ids)}))
    else:
        print(json.dumps([{'name':r['name'],'documents':r.get('document_count'),'chunks':r.get('chunk_count')} for r in rows]))
except Exception as e:
    print(json.dumps({'error':type(e).__name__}));sys.exit(1)
"""


def ragflow_call(action):
    token = private_yaml(SERVICES_DIR / "ragflow.yaml")["knowledge_token"]  # 共享服务私有文件里的既有键，改名不动
    payload = json.dumps({"token": token, "base": f"https://ragflow.{DATA_NS}.svc.cluster.local:{RAGFLOW_PORT}", "names": RAGFLOW_DATASETS, "action": action})
    return json.loads(kube("-n", DATA_NS, "exec", "-i", "deployment/ragflow-api", "--", "python", "-c", RAGFLOW_SCRIPT, stdin=payload))


def ragflow_list():
    # 只报带旧名的；新数据集 sunmoon-kind-knowbase-default 与验收用的不列，免得混进「不在清单」
    return {"datasets": [dict(d, listed=d["name"] in RAGFLOW_DATASETS) for d in ragflow_call("list") if re.search(r"(info|knowledge)", d["name"])]}


def ragflow_delete(found):
    if any(d["listed"] for d in found["datasets"]):
        ragflow_call("delete")


# ---------------------------------------------------------------- Casdoor
class Casdoor:
    def __enter__(self):
        password = private_yaml(SERVICES_DIR / "credentials.yaml")["service_credentials"]["casdoor_admin_password"]
        self.tunnel = Tunnel(APP_NS, "casdoor", 8000).__enter__()
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        self.api("POST", "/api/login", {"application": "app-built-in", "organization": "built-in", "username": "admin", "password": password, "type": "login"})
        return self

    def api(self, method, path, payload=None, params=None):
        url = f"http://127.0.0.1:{self.tunnel.port}{path}" + ("?" + urllib.parse.urlencode(params) if params else "")
        req = urllib.request.Request(url, method=method, data=json.dumps(payload).encode() if payload is not None else None,
                                     headers={"Origin": f"https://{CASDOOR_HOST}:30443", "Content-Type": "application/json"})
        try:
            with self.opener.open(req, timeout=20) as r:
                body = json.loads(r.read())
        except urllib.error.HTTPError as e:
            raise Stop(f"Casdoor {path} HTTP {e.code}")
        require(body.get("status") == "ok", f"Casdoor 拒绝 {path}")
        return body.get("data")

    def __exit__(self, *exc):
        self.tunnel.__exit__()


def casdoor_list():
    with Casdoor() as c:
        apps = []
        for a in c.api("GET", "/api/get-applications", params={"owner": "admin"}) or []:
            if re.search(r"(^|-)(info|knowledge)(-|$)", a["name"]):
                apps.append({"name": a["name"], "clientId": a.get("clientId"), "organization": a.get("organization"),
                             "description": a.get("description", ""), "listed": a["name"] in CASDOOR_APPS})
        orgs = []
        for o in c.api("GET", "/api/get-organizations", params={"owner": "admin"}) or []:
            if re.search(r"(^|-)(info|knowledge)(-|$)", o["name"]):
                users = c.api("GET", "/api/get-users", params={"owner": o["name"]}) or []
                orgs.append({"name": o["name"], "users": len(users), "listed": o["name"] in CASDOOR_ORGS})
    return {"applications": apps, "organizations": orgs}


def casdoor_delete(found):
    for a in found["applications"]:
        if a["listed"]:
            client_id, mark = CASDOOR_APPS[a["name"]]
            require(a["clientId"] == client_id and (mark is None or a["description"] == mark), f'Casdoor 应用 {a["name"]} 的 clientId/说明对不上，整类不删')
    for o in found["organizations"]:
        require(not o["listed"] or o["users"] == 0, f'组织 {o["name"]} 里有用户，整类不删')
    with Casdoor() as c:
        for a in found["applications"]:
            if a["listed"]:
                full = c.api("GET", "/api/get-application", params={"id": "admin/" + a["name"]})
                require(c.api("POST", "/api/delete-application", full) == "Affected", f'Casdoor 应用 {a["name"]} 没删掉')
        for o in found["organizations"]:
            if o["listed"]:
                full = c.api("GET", "/api/get-organization", params={"id": "admin/" + o["name"]})
                require(c.api("POST", "/api/delete-organization", full) == "Affected", f'Casdoor 组织 {o["name"]} 没删掉')


# ---------------------------------------------------------------- 私有目录
def private_list():
    out = []
    for d in PRIVATE_DIRS:
        p = Path(d)
        if p.is_symlink():
            out.append({"path": d, "state": "symlink"})
        elif p.is_dir():
            files = sum(len(f) for _, _, f in os.walk(p))
            size = run(["du", "-sh", d]).split()[0]
            out.append({"path": d, "state": "dir", "files": files, "size": size})
    return {"directories": out}


def private_delete(found):
    for d in found["directories"]:
        require(d["state"] == "dir" and d["path"] in PRIVATE_DIRS, f'{d["path"]} 不是清单里的普通目录，不删')
        shutil.rmtree(d["path"])


# ---------------------------------------------------------------- Harbor
def harbor(method, path, payload=None):
    password = (REGISTRY_DIR / "private" / "admin-password").read_text().strip()
    ctx = ssl.create_default_context(cafile=str(REGISTRY_DIR / "tls" / "ca.crt"))
    req = urllib.request.Request(f"https://127.0.0.1:{REGISTRY['registry_https_port']}/api/v2.0{path}", method=method,
                                 data=json.dumps(payload).encode() if payload is not None else None,
                                 headers={"Authorization": "Basic " + base64.b64encode(f"admin:{password}".encode()).decode(), "Content-Type": "application/json"})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), urllib.request.HTTPSHandler(context=ctx))
    try:
        with opener.open(req, timeout=60) as r:
            body = r.read()
            return json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        raise Stop(f"Harbor {method} {path.split('?')[0]} HTTP {e.code}")


def harbor_usage():
    return run(["du", "-sh", REGISTRY["registry_instance_dir"]], timeout=1800).split()[0]


def harbor_list():
    repos = []
    for page in range(1, 50):
        rows = harbor("GET", f"/projects/{HARBOR_PROJECT}/repositories?page={page}&page_size=100") or []
        repos += rows
        if len(rows) < 100:
            break
    shown = []
    for r in repos:
        short = r["name"].split("/", 1)[1]
        if OLD_NAME.match(short):
            shown.append({"name": short, "artifacts": r.get("artifact_count"), "listed": short in HARBOR_REPOS})
    return {"repositories": shown, "disk": harbor_usage()}


def harbor_delete(found):
    for r in found["repositories"]:
        if r["listed"]:
            harbor("DELETE", f"/projects/{HARBOR_PROJECT}/repositories/" + urllib.parse.quote(urllib.parse.quote(r["name"], safe=""), safe=""))


def gc_list():
    jobs = harbor("GET", "/system/gc?page=1&page_size=3") or []
    return {"recent_gc": [{"id": j["id"], "status": j.get("job_status"), "parameters": j.get("job_parameters"), "end": j.get("update_time")} for j in jobs],
            "disk": harbor_usage()}


def gc_delete(_found):
    # delete_untagged=false：investment、tpl 等按摘要部署的镜像多半没有标签，不能顺手清掉
    harbor("POST", "/system/gc/schedule", {"schedule": {"type": "Manual"}, "parameters": {"delete_untagged": False, "dry_run": False, "workers": 1}})
    deadline = time.monotonic() + 3600
    while time.monotonic() < deadline:
        time.sleep(10)
        job = (harbor("GET", "/system/gc?page=1&page_size=1") or [{}])[0]
        if job.get("job_status") in ("Success", "Error", "Stopped"):
            require(job["job_status"] == "Success", f'Harbor 垃圾回收结束状态 {job["job_status"]}（id {job["id"]}）')
            return
    raise Stop("Harbor 垃圾回收一小时没结束")


HANDLERS = {"k8s": (k8s_list, k8s_delete), "job-history": (jobs_list, jobs_delete), "postgresql": (pg_list, pg_delete), "redis": (redis_list, redis_delete),
            "rabbitmq": (mq_list, mq_delete), "object-storage": (s3_list, s3_delete), "ragflow": (ragflow_list, ragflow_delete),
            "casdoor": (casdoor_list, casdoor_delete), "private": (private_list, private_delete), "harbor": (harbor_list, harbor_delete),
            "harbor-gc": (gc_list, gc_delete)}


def show(category, found, title):
    print(f"===== {category} · {title}")
    print(json.dumps(found, ensure_ascii=False, indent=1))
    extras = [x for v in found.values() if isinstance(v, list) for x in v if isinstance(x, dict) and x.get("listed") is False]
    for x in extras:
        print(f"  ?? 不在清单，不删: {x.get('name') or x.get('path')}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("action", choices=["list", "delete"])
    ap.add_argument("categories", nargs="*")
    ap.add_argument("--confirm")
    a = ap.parse_args()
    require(os.geteuid() == 0, "要 root（见文件头的用法）")
    cats = a.categories or (CATEGORIES if a.action == "list" else [])
    require(all(c in CATEGORIES for c in cats), "类别只能是: " + ", ".join(CATEGORIES))
    if a.action == "delete":
        require(len(cats) == 1 and a.confirm == cats[0], "delete 一次只删一类，且 --confirm 要写同一个类别名")
    rc = 0
    for c in cats:
        lister, deleter = HANDLERS[c]
        try:
            found = lister()
            show(c, found, "删前" if a.action == "delete" else "现状")
            if a.action == "delete":
                deleter(found)
                show(c, lister(), "删后")
        except Stop as e:
            print(f"===== {c} · STOP: {e}")
            rc = 1
            if a.action == "delete":
                break
    print(f"exit={rc}")
    sys.exit(rc)


if __name__ == "__main__":
    main()
